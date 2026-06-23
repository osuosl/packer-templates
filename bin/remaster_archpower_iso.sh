#!/bin/bash
#
# Remaster the official ArchPOWER ppc64 (big-endian) install ISO into a custom ISO
# that performs a fully unattended install. ArchPOWER has no debian-installer /
# anaconda autoinstaller, and QEMU pseries is serial-only (Packer's VNC boot_command
# cannot reach it), so -- like the FreeBSD ppc64le templates -- we bake the installer
# into the boot media and leave boot_command empty.
#
# What we inject into the ISO's live root (airootfs):
#   * /usr/local/bin/archpower-install.sh  <- installerconfig/archpower.install.sh
#   * /etc/systemd/system/archpower-autoinstall.service  (+ enabled via a
#     multi-user.target.wants symlink) -- runs the installer on boot. archiso's own
#     script= / autologin autorun is gated to /dev/tty1 and does NOT fire on the
#     pseries serial console (/dev/hvc0), so we use our own unit instead.
#   * /etc/archpower-install.conf  (MIRROR=<template mirror var>)
# We also lower the GRUB menu timeout. The stock grub.cfg already defaults
# (set default=1) to the `console=hvc0` serial entry, so no console edit is needed.
#
# Usage: bin/remaster_archpower_iso.sh -t <archpower-*-openstack.json.pkr.hcl>
#
# Reads `release` and `mirror` from the template, downloads + GPG-verifies the
# official ISO, and writes iso/archpower-<release>-powerpc64-custom.iso (the template
# points iso_url at it with iso_checksum = "none").
#
# !!! ON-NODE VALIDATION REQUIRED !!!  This has been authored from a byte-level
# inspection of archpower-current-powerpc64.iso but NOT yet boot-tested. The ISO is
# a grub-mkrescue (CHRP + Apple Partition Map/HFS) image with NO El Torito catalog,
# so it is rebuilt with grub2-mkrescue/grub-mkrescue (xorriso "replay" cannot
# reconstruct it). The AlmaLinux/RHEL build host needs: grub2-tools-extra
# (grub2-mkrescue), grub2-ppc64le-modules (the powerpc-ieee1275 platform, native on
# a ppc64le POWER node), squashfs-tools, fakeroot (EPEL), xorriso and gnupg2. See
# docs/archpower.md.

set -euo pipefail

TEMPLATE=
ISO_DIR="iso"
INSTALLER_SRC="installerconfig/archpower.install.sh"
ISO_SITE="https://archlinuxpower.org/iso"
GRUB_PPC_DIR="/usr/lib/grub/powerpc-ieee1275"
# ArchPOWER ISO signing key: Alexander Baldeck (ArchPOWER) / kth5. The PINNED
# fingerprint is the trust anchor; keys/archpower.asc is bundled so the verify is
# hermetic (no keyserver at build time). Confirm this fingerprint against the one
# published at archlinuxpower.org before relying on it.
ARCHPOWER_KEY_FPR="D201F92AE42528456537C3F9B96775F34689694C"
ARCHPOWER_KEY_FILE="keys/archpower.asc"

run_help() {
  echo "Usage: $0 -t path/to/archpower-<arch>-openstack.json.pkr.hcl"
  echo
  echo "  Remaster the official ArchPOWER powerpc64 (BE) ISO into an unattended"
  echo "  install ISO (injects the installer + an autorun systemd unit)."
  exit "${1:-0}"
}

while getopts "ht:" opt; do
  case $opt in
    t) TEMPLATE="$OPTARG" ;;
    h) run_help 0 ;;
    *) run_help 1 ;;
  esac
done

[ -z "$TEMPLATE" ] && { echo "Error: template not set (-t)" >&2; run_help 1; }
[ -f "$TEMPLATE" ] || { echo "Error: template '$TEMPLATE' not found" >&2; exit 1; }
[ -f "$INSTALLER_SRC" ] || { echo "Error: $INSTALLER_SRC not found" >&2; exit 1; }

# Extract default of: variable "<name>" { ... default = "X" ... } (same helper as
# bin/remaster_freebsd_iso.sh).
get_var() {
  sed -nE "/variable[[:space:]]+\"$1\"/,/^}/ s/.*default[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" "$TEMPLATE" \
    | head -1
}

RELEASE="$(get_var release)"; RELEASE="${RELEASE:-current}"
MIRROR="$(get_var mirror)";   MIRROR="${MIRROR:-https://repo.archlinuxpower.org}"

# current ISOs live at /iso/, dated snapshots under /iso/stable/.
if [ "$RELEASE" = "current" ]; then
  ISO_NAME="archpower-current-powerpc64.iso"
  SRC_URL="${ISO_SITE}/${ISO_NAME}"
else
  ISO_NAME="archpower-${RELEASE}-powerpc64.iso"
  SRC_URL="${ISO_SITE}/stable/${ISO_NAME}"
fi
SIG_URL="${SRC_URL}.sig"

SRC_ISO="${ISO_DIR}/${ISO_NAME}"
SRC_SIG="${ISO_DIR}/${ISO_NAME}.sig"
OUT_ISO="${ISO_DIR}/archpower-${RELEASE}-powerpc64-custom.iso"

mkdir -p "$ISO_DIR"

download() { # url dest -- removes a partial file on failure (curl <7.83 has no
            # --remove-on-error, e.g. AlmaLinux 8's curl 7.61)
  if command -v curl >/dev/null 2>&1; then curl -fSL -o "$2" "$1" || { rm -f "$2"; return 1; }
  else wget -O "$2" "$1" || { rm -f "$2"; return 1; }; fi
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' is required ($2)" >&2; exit 1; }; }
need unsquashfs "squashfs-tools"
need mksquashfs "squashfs-tools"
need fakeroot   "fakeroot (AlmaLinux: in EPEL)"
need xorriso    "xorriso/libisoburn"
# GRUB tools are grub2-* on AlmaLinux/RHEL, grub-* on Arch/Debian. Pick whichever.
GRUB_MKRESCUE="$(command -v grub2-mkrescue || command -v grub-mkrescue || true)"
[ -n "$GRUB_MKRESCUE" ] || { echo "Error: grub2-mkrescue/grub-mkrescue not found -- install grub2-tools-extra (AlmaLinux) or grub (Arch/Debian)" >&2; exit 1; }
[ -d "$GRUB_PPC_DIR" ] || { echo "Error: $GRUB_PPC_DIR not found -- install the powerpc-ieee1275 grub modules (AlmaLinux: grub2-ppc64le-modules; native on a POWER host)" >&2; exit 1; }

WORK="$(mktemp -d "${ISO_DIR}/remaster.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "==> Remastering $ISO_NAME (release $RELEASE)"

# 1. Download the source ISO (cache across runs).
[ -f "$SRC_ISO" ] || { echo "--> downloading $SRC_URL"; download "$SRC_URL" "$SRC_ISO"; }

# 2. Verify the detached PGP signature. This is why the custom ISO can safely use
#    iso_checksum = "none". Requires the ArchPOWER signing key in your keyring (see
#    docs/archpower.md). Set ARCHPOWER_GPG_SKIP_VERIFY=1 to bypass (not recommended).
if [ "${ARCHPOWER_GPG_SKIP_VERIFY:-0}" = "1" ]; then
  echo "WARNING: skipping GPG verification of $ISO_NAME (ARCHPOWER_GPG_SKIP_VERIFY=1)" >&2
else
  need gpg "to verify the ISO signature, or set ARCHPOWER_GPG_SKIP_VERIFY=1"
  echo "--> downloading $SIG_URL"
  download "$SIG_URL" "$SRC_SIG"

  # Verify in a throwaway keyring under $WORK (cleaned by the EXIT trap) so we
  # neither depend on nor pollute the host's ~/.gnupg, and trust is scoped to the
  # pinned ArchPOWER key. --no-autostart keeps gpg from launching dirmngr on the
  # local operations (only the recv-keys fallback needs the network).
  export GNUPGHOME="$WORK/gnupg"
  mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
  if [ -f "$ARCHPOWER_KEY_FILE" ]; then
    echo "--> importing bundled signing key ($ARCHPOWER_KEY_FILE)"
    gpg --no-autostart --batch --quiet --import "$ARCHPOWER_KEY_FILE"
  else
    echo "--> $ARCHPOWER_KEY_FILE missing; fetching key $ARCHPOWER_KEY_FPR from keyserver"
    gpg --batch --quiet --keyserver "${ARCHPOWER_KEYSERVER:-hkps://keyserver.ubuntu.com}" \
        --recv-keys "$ARCHPOWER_KEY_FPR" \
      || { echo "Error: could not obtain the ArchPOWER key (bundle it at $ARCHPOWER_KEY_FILE, or set ARCHPOWER_GPG_SKIP_VERIFY=1)" >&2; exit 1; }
  fi

  # The pinned fingerprint is the trust anchor: bail unless exactly it is present.
  gpg --no-autostart --batch --with-colons --fingerprint 2>/dev/null \
      | grep -q "fpr:::::::::${ARCHPOWER_KEY_FPR}:" \
    || { echo "Error: pinned ArchPOWER key $ARCHPOWER_KEY_FPR not in keyring after import" >&2; exit 1; }

  # Require a GOOD signature from exactly the pinned key. VALIDSIG carries the
  # primary-key fingerprint, so a valid signature made by any OTHER key is rejected.
  status="$(gpg --no-autostart --batch --status-fd 1 --verify "$SRC_SIG" "$SRC_ISO" 2>/dev/null || true)"
  if printf '%s\n' "$status" | grep -q "^\[GNUPG:\] VALIDSIG .*${ARCHPOWER_KEY_FPR}"; then
    echo "--> signature OK (signed by $ARCHPOWER_KEY_FPR)"
  elif printf '%s\n' "$status" | grep -q '^\[GNUPG:\] BADSIG'; then
    # Definitively corrupt content -- purge so the next run re-downloads.
    echo "Error: BAD GPG signature for $ISO_NAME (corrupt download); purging cache." >&2
    rm -f "$SRC_ISO" "$SRC_SIG"
    exit 1
  else
    echo "Error: $ISO_NAME is not validly signed by the pinned ArchPOWER key." >&2
    printf '%s\n' "$status" >&2
    exit 1
  fi
fi

# Preserve the source volume id: grub.cfg's archisolabel=/search --label depends on
# it, so a changed label won't find the live media.
VOLID="$(xorriso -indev "$SRC_ISO" -pvd_info 2>/dev/null | sed -n 's/^Volume Id[[:space:]]*:[[:space:]]*//p' | head -1)"
[ -n "$VOLID" ] || { echo "Error: could not read volume id from $SRC_ISO" >&2; exit 1; }
echo "--> source volume id: $VOLID"

TREE="$WORK/tree"
rm -f "$OUT_ISO"

# 3. Extract the ISO9660 file tree.
echo "--> extracting ISO tree"
xorriso -osirrox on -indev "$SRC_ISO" -extract / "$TREE" >/dev/null 2>&1
chmod -R u+rwX "$TREE"

SFS_DIR="$TREE/arch/ppc64"          # confirmed on the real ISO (arch dir = ppc64)
SFS="$SFS_DIR/airootfs.sfs"
[ -f "$SFS" ] || { echo "Error: $SFS not found (unexpected ISO layout)" >&2; exit 1; }

# 4. Unpack the live root, inject our installer + autorun unit, repack. Done under
#    fakeroot so root:root ownership and setuid bits are preserved in the new sfs
#    (no big-endian binary is executed -- squashfs/xorriso are endian-neutral).
echo "--> injecting unattended installer into airootfs"
UNIT_SRC="$WORK/archpower-autoinstall.service"
cat >"$UNIT_SRC" <<'UNIT'
[Unit]
Description=OSL unattended ArchPOWER install
After=pacman-init.service systemd-networkd.service network-online.target
Wants=network-online.target
ConditionPathExists=/usr/local/bin/archpower-install.sh

[Service]
Type=oneshot
ExecStart=/usr/local/bin/archpower-install.sh
StandardOutput=journal+console
StandardError=journal+console
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT

fakeroot -- bash -euo pipefail <<FAKEROOT
SQ="$WORK/squashfs-root"
rm -rf "\$SQ"
unsquashfs -d "\$SQ" "$SFS" >/dev/null
install -D -m 0755 -o root -g root "$INSTALLER_SRC" "\$SQ/usr/local/bin/archpower-install.sh"
install -D -m 0644 -o root -g root "$UNIT_SRC"       "\$SQ/etc/systemd/system/archpower-autoinstall.service"
install -d -m 0755 -o root -g root "\$SQ/etc/systemd/system/multi-user.target.wants"
ln -sf ../archpower-autoinstall.service \
   "\$SQ/etc/systemd/system/multi-user.target.wants/archpower-autoinstall.service"
# Disable sshd in the LIVE installer env. archiso runs its own sshd; while our
# install runs (minutes) Packer would hit it as root/osuadmin and exhaust its SSH
# handshake attempts on auth failures before the install reboots into the disk.
# Masked here, Packer instead gets connection-refused and waits for the INSTALLED
# system's sshd (root/osuadmin) after the reboot. Affects only the live env.
ln -sf /dev/null "\$SQ/etc/systemd/system/sshd.service"
ln -sf /dev/null "\$SQ/etc/systemd/system/sshd.socket"
rm -f "\$SQ/etc/systemd/system/multi-user.target.wants/sshd.service" \
      "\$SQ/etc/systemd/system/sockets.target.wants/sshd.socket"
printf 'MIRROR=%s\n' "$MIRROR" > "\$SQ/etc/archpower-install.conf"
chmod 0644 "\$SQ/etc/archpower-install.conf"
rm -f "$SFS"
# Match the stock image: squashfs, xz, 1 MiB blocks (no x86 BCJ filter on ppc).
mksquashfs "\$SQ" "$SFS" -noappend -comp xz -b 1M >/dev/null
rm -rf "\$SQ"
FAKEROOT

# 5. Regenerate the airootfs checksum (defensive: stock boot entries don't enable
#    checksum=, but keep it consistent in case ArchPOWER turns it on later).
( cd "$SFS_DIR" && sha512sum airootfs.sfs > airootfs.sha512 )

# 6. Hands-off boot on the VGA console so the install is visible on Packer's VNC
#    (this QEMU pseries guest has a VGA adapter). The stock grub.cfg defaults to the
#    serial (console=hvc0) entry, which hides install output on hvc0. Select the
#    non-serial entry (default=0), drop the timeout, and pin console=tty0 (entry 0
#    has no console= and would otherwise fall back to hvc0). NOTE: this is the LIVE
#    installer's console only; the DEPLOYED image keeps console=hvc0 (set by the
#    in-guest installer) so OpenStack's `nova console-log` works.
GRUBCFG="$TREE/boot/grub/grub.cfg"
# Hard-require it: grub-mkrescue does NOT synthesize a menu, so a missing grub.cfg
# would silently yield a menu-less, non-bootable ISO with a clean exit.
[ -f "$GRUBCFG" ] || { echo "Error: $GRUBCFG not found (unexpected ISO layout)" >&2; exit 1; }
sed -i \
  -e 's/^set default=.*/set default=0/' \
  -e 's/^set timeout=.*/set timeout=1/' \
  -e '/vmlinuz-linux-ppc64/ s/$/ console=tty0/' \
  "$GRUBCFG"

# 7. Rebuild the bootable ISO. This image is CHRP + Apple Partition Map/HFS produced
#    by grub-mkrescue (NO El Torito), so we regenerate it the same way rather than
#    replaying boot records. Drop the boot scaffolding grub-mkrescue re-creates, but
#    keep grub.cfg + the /arch payload.
echo "--> rebuilding ISO with $(basename "$GRUB_MKRESCUE") (volid $VOLID)"
rm -rf "$TREE/boot/grub/powerpc-ieee1275" "$TREE/boot/grub/powerpc.elf" \
       "$TREE/boot/grub/i386-pc" "$TREE/System" "$TREE/ppc" \
       "$TREE/mach_kernel" "$TREE"/.disk* 2>/dev/null || true
"$GRUB_MKRESCUE" -d "$GRUB_PPC_DIR" -o "$OUT_ISO" --volid "$VOLID" "$TREE"

[ -f "$OUT_ISO" ] || { echo "Error: failed to produce $OUT_ISO" >&2; exit 1; }
echo "==> wrote $OUT_ISO"
