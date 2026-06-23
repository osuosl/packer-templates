#!/bin/bash
#
# Remaster an official FreeBSD disc1.iso into a custom install ISO that performs a
# fully unattended, OFFLINE install. Two things are embedded:
#
#   * /etc/installerconfig -- FreeBSD's installer auto-runs this at boot with zero
#     keystrokes (startbsdinstall(8)), so Packer's qemu builder needs no
#     boot_command (works even on serial-only QEMU pseries / ppc64le, where the VNC
#     boot_command cannot reach the console).
#   * the distribution sets (base.txz, kernel.txz, ...) into /usr/freebsd-dist.
#     Modern FreeBSD disc1.iso ships only a MANIFEST, not the .txz sets, so a stock
#     scripted install stops at the interactive "Mirror Selection" screen to fetch
#     them. We download the sets (verified against the on-ISO MANIFEST) and bake
#     them in, so bsdinstall finds them locally and never touches the network.
#
# Usage: bin/remaster_freebsd_iso.sh -t <freebsd-*-openstack.json.pkr.hcl>
#
# Reads `mirror` and `release` from the template, downloads + verifies the official
# disc1.iso, embeds the above, and writes
#   iso/FreeBSD-<release>-RELEASE-<archtoken>-custom.iso
# which the template's iso_url points at (iso_checksum = "none").
#
# FreeBSD ISOs are built with makefs(8) and embed their El Torito boot images
# OUTSIDE the directory tree, so a naive "xorriso -boot_image any replay" silently
# discards them and produces an unbootable ISO. We therefore rebuild the boot
# records explicitly per platform (see the case statement below).

set -euo pipefail

TEMPLATE=
ISO_DIR="iso"
INSTALLERCONFIG_DIR="installerconfig"

run_help() {
  echo "Usage: $0 -t path/to/freebsd-<ver>-<arch>-openstack.json.pkr.hcl"
  echo
  echo "  Remaster the official FreeBSD disc1.iso for <arch> into an offline,"
  echo "  unattended install ISO (embeds /etc/installerconfig + the dist sets)."
  exit "${1:-0}"
}

while getopts "ht:" opt; do
  case $opt in
    t) TEMPLATE="$OPTARG" ;;
    h) run_help 0 ;;
    *) run_help 1 ;;
  esac
done

[ -z "$TEMPLATE" ] && echo "Error: template not set (-t)" >&2 && run_help 1
[ -f "$TEMPLATE" ] && : || { echo "Error: template '$TEMPLATE' not found" >&2; exit 1; }

# Extract the default string value of `variable "<name>" { ... default = "X" ... }`
# (handles both single-line and multi-line variable blocks).
get_var() {
  sed -nE "/variable[[:space:]]+\"$1\"/,/^}/ s/.*default[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" "$TEMPLATE" \
    | head -1
}

base="$(basename "$TEMPLATE")"
case "$base" in
  *-x86_64-*)  ARCHTOKEN="amd64"                INSTALLERCONFIG="$INSTALLERCONFIG_DIR/freebsd.installerconfig.gpt" ;;
  *-aarch64-*) ARCHTOKEN="arm64-aarch64"        INSTALLERCONFIG="$INSTALLERCONFIG_DIR/freebsd.installerconfig.gpt" ;;
  *-ppc64le-*) ARCHTOKEN="powerpc-powerpc64le"  INSTALLERCONFIG="$INSTALLERCONFIG_DIR/freebsd.installerconfig.chrp" ;;
  *) echo "Error: cannot determine arch from template name '$base'" >&2; exit 1 ;;
esac

MIRROR="$(get_var mirror)"
RELEASE="$(get_var release)"
[ -z "$MIRROR" ]  && { echo "Error: could not read 'mirror' from $TEMPLATE"  >&2; exit 1; }
[ -z "$RELEASE" ] && { echo "Error: could not read 'release' from $TEMPLATE" >&2; exit 1; }
[ -f "$INSTALLERCONFIG" ] || { echo "Error: $INSTALLERCONFIG not found" >&2; exit 1; }

ISO_NAME="FreeBSD-${RELEASE}-RELEASE-${ARCHTOKEN}-disc1.iso"
CHECKSUM_NAME="CHECKSUM.SHA256-FreeBSD-${RELEASE}-RELEASE-${ARCHTOKEN}"
SRC_URL="${MIRROR}/${RELEASE}/${ISO_NAME}"
CHECKSUM_URL="${MIRROR}/${RELEASE}/${CHECKSUM_NAME}"

# Distribution sets live next to the ISO-IMAGES dir, under <ver>-RELEASE/.
DISTSITE="${MIRROR%/ISO-IMAGES}/${RELEASE}-RELEASE"
# Which sets to bake in -- read straight from the installerconfig's DISTRIBUTIONS.
DISTS="$(sed -nE 's/^DISTRIBUTIONS=\"?([^\"]*)\"?.*/\1/p' "$INSTALLERCONFIG" | head -1)"
[ -n "$DISTS" ] || DISTS="kernel.txz base.txz"

SRC_ISO="${ISO_DIR}/${ISO_NAME}"
SRC_SUMS="${ISO_DIR}/${CHECKSUM_NAME}"
OUT_ISO="${ISO_DIR}/FreeBSD-${RELEASE}-RELEASE-${ARCHTOKEN}-custom.iso"
DIST_CACHE="${ISO_DIR}/dist-${ARCHTOKEN}-${RELEASE}"

mkdir -p "$ISO_DIR"

download() { # url dest
  if command -v curl >/dev/null 2>&1; then curl -fSL -o "$2" "$1"
  elif command -v fetch >/dev/null 2>&1; then fetch -o "$2" "$1"
  else wget -O "$2" "$1"; fi
}

sha256_of() { # file -> hex digest on stdout
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else sha256 -q "$1"; fi
}

# Download a distribution set into the cache (if absent) and verify it against the
# on-ISO MANIFEST so the baked-in sets match the release exactly.
#   fetch_dist <dist> <manifest-file>
fetch_dist() {
  local dist="$1" manifest="$2" want got
  if [ ! -f "$DIST_CACHE/$dist" ]; then
    echo "--> fetching dist $dist from $DISTSITE"
    download "$DISTSITE/$dist" "$DIST_CACHE/$dist"
  fi
  want="$(awk -v f="$dist" '$1==f{print $2}' "$manifest" 2>/dev/null || true)"
  got="$(sha256_of "$DIST_CACHE/$dist")"
  if [ -n "$want" ] && [ "$want" != "$got" ]; then
    echo "Error: dist $dist checksum mismatch (want $want, got $got)" >&2
    rm -f "$DIST_CACHE/$dist"
    exit 1
  fi
}

# Make bsdinstall's unattended auto-run non-interactive on a serial console:
# startbsdinstall(8) prompts "Console type [vt100]:" and blocks on a `read` when
# kbdcontrol(1) reports no syscons (i.e. serial-only arm64/ppc64le) BEFORE it
# checks for /etc/installerconfig. Drop the blocking read so it defaults to vt100
# and proceeds straight to the scripted install. No-op on a VGA console.
patch_startbsdinstall() {
  [ -f "$1" ] || return 0
  sed -i 's/^\([[:space:]]*\)read TERM$/\1TERM=vt100  # OSL: do not block unattended serial install/' "$1"
}

echo "==> Remastering $ISO_NAME (release $RELEASE, $ARCHTOKEN)"

# Download the source ISO + checksum (cache the ISO across runs).
[ -f "$SRC_ISO" ] || { echo "--> downloading $SRC_URL"; download "$SRC_URL" "$SRC_ISO"; }
echo "--> downloading $CHECKSUM_URL"
download "$CHECKSUM_URL" "$SRC_SUMS"

# Verify the source ISO against the official CHECKSUM (this is why the custom ISO
# can safely use iso_checksum = "none" in the template).
EXPECTED="$(sed -nE "s/.*\(${ISO_NAME}\) = ([0-9a-fA-F]+).*/\1/p" "$SRC_SUMS" | head -1)"
[ -n "$EXPECTED" ] || { echo "Error: no checksum for $ISO_NAME in $SRC_SUMS" >&2; exit 1; }
ACTUAL="$(sha256_of "$SRC_ISO")"
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "Error: checksum mismatch for $SRC_ISO" >&2
  echo "  expected $EXPECTED" >&2
  echo "  actual   $ACTUAL"   >&2
  rm -f "$SRC_ISO"
  exit 1
fi
echo "--> checksum OK"

command -v xorriso >/dev/null 2>&1 || { echo "Error: xorriso is required" >&2; exit 1; }

# The custom ISO must keep the source volume label: the install media mounts / as
# /dev/iso9660/<LABEL> (see /etc/fstab on the media), so a changed label won't boot.
VOLID="$(xorriso -indev "$SRC_ISO" -pvd_info 2>/dev/null | sed -n 's/^Volume Id[[:space:]]*:[[:space:]]*//p' | head -1)"
[ -n "$VOLID" ] || { echo "Error: could not read volume id from $SRC_ISO" >&2; exit 1; }

WORK="$(mktemp -d "${ISO_DIR}/remaster.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$DIST_CACHE"
rm -f "$OUT_ISO"
echo "--> embedding /etc/installerconfig + dist sets [$DISTS] (volume '$VOLID')"

case "$ARCHTOKEN" in
amd64 | arm64-aarch64)
  # amd64/arm64 use El Torito with a hidden, embedded EFI System Partition image.
  # Pull the boot images out, extract the tree, add our files + dist sets, and
  # rebuild with the EFI image re-attached as an appended 0xEF partition.
  BOOTIMG="$WORK/bootimg"
  TREE="$WORK/tree"
  mkdir -p "$BOOTIMG"
  xorriso -osirrox on -indev "$SRC_ISO" -extract_boot_images "$BOOTIMG/" >/dev/null 2>&1
  xorriso -osirrox on -indev "$SRC_ISO" -extract / "$TREE" >/dev/null 2>&1
  chmod -R u+rwX "$TREE"
  install -m 0644 "$INSTALLERCONFIG" "$TREE/etc/installerconfig"
  patch_startbsdinstall "$TREE/usr/libexec/bsdinstall/startbsdinstall"
  for dist in $DISTS; do
    fetch_dist "$dist" "$TREE/usr/freebsd-dist/MANIFEST"
    install -m 0644 "$DIST_CACHE/$dist" "$TREE/usr/freebsd-dist/$dist"
  done

  UEFI_IMG="$(ls "$BOOTIMG"/eltorito_img*_uefi.img 2>/dev/null | head -1 || true)"
  [ -n "$UEFI_IMG" ] || { echo "Error: no UEFI boot image extracted from $SRC_ISO" >&2; exit 1; }

  if [ "$ARCHTOKEN" = "amd64" ]; then
    # BIOS (El Torito -> /boot/cdboot) + UEFI (appended ESP).
    xorriso -as mkisofs -V "$VOLID" -r -l \
      -b boot/cdboot -no-emul-boot \
      -eltorito-alt-boot -e '--interval:appended_partition_2:all::' -no-emul-boot \
      -append_partition 2 0xef "$UEFI_IMG" \
      -o "$OUT_ISO" "$TREE"
  else
    # arm64 is UEFI-only (no BIOS cdboot).
    xorriso -as mkisofs -V "$VOLID" -r -l \
      -e '--interval:appended_partition_2:all::' -no-emul-boot \
      -append_partition 2 0xef "$UEFI_IMG" \
      -o "$OUT_ISO" "$TREE"
  fi
  ;;
powerpc-powerpc64le)
  # QEMU pseries / CHRP: the boot equipment (/ppc/bootinfo.txt, /ppc/chrp/loader,
  # CHRP system area) is real tree files, so xorriso can replay it. Patch
  # startbsdinstall, add the installerconfig + dist sets via -map; replay last.
  xorriso -osirrox on -indev "$SRC_ISO" \
    -extract /usr/libexec/bsdinstall/startbsdinstall "$WORK/startbsdinstall" >/dev/null 2>&1
  xorriso -osirrox on -indev "$SRC_ISO" \
    -extract /usr/freebsd-dist/MANIFEST "$WORK/MANIFEST" >/dev/null 2>&1
  chmod u+rw "$WORK/startbsdinstall"
  patch_startbsdinstall "$WORK/startbsdinstall"
  DISTMAPS=()
  for dist in $DISTS; do
    fetch_dist "$dist" "$WORK/MANIFEST"
    DISTMAPS+=( -map "$DIST_CACHE/$dist" "/usr/freebsd-dist/$dist" )
  done
  xorriso -indev "$SRC_ISO" -outdev "$OUT_ISO" \
    -map "$INSTALLERCONFIG" /etc/installerconfig \
    -map "$WORK/startbsdinstall" /usr/libexec/bsdinstall/startbsdinstall \
    "${DISTMAPS[@]}" \
    -boot_image any replay || true # replay reports SORRY on some media but still writes
  ;;
*)
  echo "Error: unsupported arch token '$ARCHTOKEN'" >&2
  exit 1
  ;;
esac

[ -f "$OUT_ISO" ] || { echo "Error: failed to produce $OUT_ISO" >&2; exit 1; }
echo "==> wrote $OUT_ISO"
