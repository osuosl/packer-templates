# ArchPOWER ppc64 (big-endian) OpenStack image

Packer template for an **ArchPOWER `powerpc64` (big-endian, ELFv2)** OpenStack base
image. Built to replace the aging Debian-unstable Go CI VMs (RT #34885): Go is
moving `linux/ppc64` from ELFv1 to ELFv2 ([golang/go#76244](https://github.com/golang/go/issues/76244)),
and ArchPOWER ships an ELFv2 big-endian userland with the upstream Go ELFv2 fix
already in its `base` repo.

| Template | Arch | Build node |
|---|---|---|
| `archpower-ppc64-openstack.json.pkr.hcl` | ppc64 **big-endian** (`powerpc64`) | **POWER KVM** (ppc64le host) |

> **ppc64 here is BIG-ENDIAN**, distinct from the `ppc64le` templates. ArchPOWER's
> pacman architecture for it is **`powerpc64`** (little-endian is `powerpc64le`);
> repos are flat `base` / `testing` at `https://repo.archlinuxpower.org/$repo/$arch`.

## Build node: big-endian guest on a little-endian host

POWER is bi-endian, so **KVM-HV runs this big-endian `pseries` guest at full
hardware speed on a little-endian ppc64le KVM host** — exactly as the existing
big-endian `centos-7-ppc64` / `debian-sid-ppc64` templates already build on the
POWER nodes. The guest's endianness comes from the booted ISO/kernel (the `MSR[LE]`
bit), not from any QEMU machine flag, so the template's QEMU settings
(`qemu_binary = "qemu-kvm"`, `machine_type = "pseries"`, `accelerator = "kvm"`) are
identical to the ppc64le templates. TCG emulation on x86 also works but is far too
slow for a full image build.

## How the unattended install works

Packer's QEMU builder can only type a `boot_command` over **VNC**, which does not
work on serial-only QEMU `pseries`. And unlike the other distros here, ArchPOWER has
**no debian-installer / anaconda / autoyast autoinstaller**, so this repo's
`boot_command` + `http/<distro>/` preseed-or-kickstart mechanism cannot be reused.

Instead — like the FreeBSD ppc64le templates — the install is baked into custom
media and `boot_command` is left empty:

1. `bin/remaster_archpower_iso.sh -t <template>` downloads the official
   `archpower-<release>-powerpc64.iso`, **GPG-verifies** it against its `.sig`, and
   remasters it to inject an unattended installer into the live environment:
   `installerconfig/archpower.install.sh` plus a systemd unit that auto-runs it at
   boot. The ISO is a `grub-mkrescue` image (CHRP + Apple Partition Map/HFS, **no El
   Torito**), so it is rebuilt with `grub2-mkrescue` rather than an `xorriso` replay.
   It writes `iso/archpower-<release>-powerpc64-custom.iso`, which the template's
   `iso_url` points at (`iso_checksum = "none"`, since the source ISO was already
   verified). `bin/build_image.sh` runs this automatically for `archpower-*`
   templates.

   **AlmaLinux/RHEL build-host packages:** `grub2-tools-extra` (`grub2-mkrescue`),
   `grub2-ppc64le-modules` (the `powerpc-ieee1275` platform), `squashfs-tools`,
   `fakeroot` (EPEL), `xorriso`, `gnupg2`. The script auto-detects `grub2-mkrescue`
   vs `grub-mkrescue`, so it also works on an Arch/Debian host.

   **ArchPOWER signing key (automatic):** verification is self-contained — the
   script imports ArchPOWER's public key from the bundled `keys/archpower.asc` into a
   throwaway keyring and requires a good signature from the **pinned** fingerprint
   `D201F92AE42528456537C3F9B96775F34689694C` (Alexander Baldeck / kth5). The pinned
   fingerprint in `bin/remaster_archpower_iso.sh` is the trust anchor; confirm it
   against the one published at archlinuxpower.org. If `keys/archpower.asc` is ever
   removed, the script falls back to fetching that exact fingerprint from a keyserver
   (`ARCHPOWER_KEYSERVER`, default `hkps://keyserver.ubuntu.com`). To bypass
   verification entirely (e.g. a throwaway test build), set
   `ARCHPOWER_GPG_SKIP_VERIFY=1`.

2. Packer boots the **custom ISO** with an empty `boot_command`. The injected
   installer runs `installerconfig/archpower.install.sh`, which:
   - partitions `/dev/sda` (`disk_interface = "virtio-scsi"`) as **MBR** with an
     ~32 MiB **PReP boot partition** (type `0x41`) first and an ext4 root filling
     the rest. MBR + PReP (not GPT) because SLOF/pseries GPT booting is unreliable;
     the existing `centos-7-ppc64` / `debian-sid-ppc64` autoinstallers use the same
     layout.
   - `pacstrap`s a minimal base (`base linux-ppc64 mkinitcpio grub openssh sudo`,
     plus `cloud-guest-utils` + `qemu-guest-agent`) — **no
     cloud-init** (not packaged for ArchPOWER) and **no containers** (base OS only).
   - installs **grub for Open Firmware** into the PReP partition
     (`grub-install --target=powerpc-ieee1275 --no-nvram /dev/sda1`), sets the
     **`hvc0`** serial console, and rebuilds the initramfs **without the
     `autodetect` hook** (forcing in `virtio_scsi`) so the deployed guest can always
     find its virtio-scsi root disk.
   - sets a build-only root password and a permissive sshd so Packer can connect
     after the reboot, then reboots.

   The remaster also **masks sshd in the live environment** — archiso runs its own
   sshd, and during the multi-minute install Packer would otherwise hammer it as
   `root`/`osuadmin` and exhaust its SSH handshake attempts on auth failures before
   the install reboots. Masked, Packer just gets connection-refused and waits.

3. The post-install reboot boots the **disk** (`-boot strict=on`); sshd comes up and
   Packer connects as `root` / `osuadmin` to run the `scripts/archpower/*`
   provisioners (and the shared `scripts/common/sshd.sh` + `minimize.sh`), then
   halts. `bin/build_image.sh` converts the raw output to `qcow2` + `raw`, and
   `bin/upload.sh` / `bin/deploy_wrapper.rb` publish it to Glance as the image_name
   (`ArchPOWER ppc64 BE`), disk-format `raw`.

## No cloud-init: static key + first-boot grow-root

ArchPOWER does not package cloud-init, so OpenStack cannot inject an SSH key or grow
the disk. As with the FreeBSD ppc64le images:

- **Login:** the templates take an **`ssh_authorized_key`** variable;
  `scripts/archpower/seed_ssh_key.sh` writes it to the static `arch` user's
  `~/.ssh/authorized_keys` (the user is created by `scripts/archpower/sudoers.sh`,
  in `wheel` with NOPASSWD sudo). sshd is hardened to key-only. Set it in your
  var-file, e.g. `ssh_authorized_key = "ssh-ed25519 AAAA... osl"`; without it the
  image has no usable login.
- **Disk growth + host keys:** `scripts/archpower/openstack.sh` installs an
  `osl-firstboot` systemd oneshot that, on the deployed instance's first boot,
  regenerates the (build-stripped) SSH host keys and runs `growpart` + `resize2fs`
  (`cloud-guest-utils`) to fill the flavor disk. Ensure the OpenStack flavor /
  image min-disk exceeds the built image size (`disk_size = 8192`, i.e. 8 GB).

## Reproducibility

ArchPOWER is a rolling, single-maintainer distro. The `release` / `iso_url` vars
default to the `-current-` rolling ISO; **pin a dated snapshot** (e.g.
`release = "2026.02.01"`) for reproducible builds, and consider mirroring ArchPOWER
under `packages.osuosl.org` (point the `mirror` var at it) for build stability.
Container tooling (docker/podman) and Go for `powerpc64` live in ArchPOWER's repos
(`testing` and `base` respectively) but are intentionally **not** installed here.

## Verification status

Built and validated for syntax (`packer fmt` / `packer validate -syntax-only`); the
full build has **not** yet been run end-to-end on a POWER node. Confirm on the
ppc64le KVM build node:

- the remastered ISO boots under QEMU `pseries`/SLOF and auto-runs the installer
  over the `hvc0` serial console (use the SLOF/CHRP-bootable `powerpc64` ISO, not
  the `iso/petitboot/` variant);
- `grub-install --target=powerpc-ieee1275` into the PReP partition produces a disk
  that SLOF boots, and the post-install reboot boots `/dev/sda` rather than
  re-entering the CD installer (if it loops, set the boot order explicitly, e.g.
  `-prom-env "boot-device=disk"`, or detach the CD);
- the initramfs (built without `autodetect`) contains the virtio-scsi modules;
- `osl-firstboot` grows the root filesystem on a deployed instance with no
  cloud-init present.
