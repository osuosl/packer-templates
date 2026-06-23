#!/bin/bash
#
# OSL unattended ArchPOWER (ppc64 BIG-ENDIAN / ELFv2) installer.
#
# Embedded into a remastered ArchPOWER install ISO by bin/remaster_archpower_iso.sh
# and auto-run on the live boot by archpower-autoinstall.service (the remaster
# script injects both this file and that unit into the ISO's airootfs).
#
# Why a scripted install: ArchPOWER has no debian-installer/anaconda/autoyast-style
# autoinstaller (so this repo's boot_command + http/<distro>/ preseed mechanism
# cannot be reused), and QEMU pseries is serial-only -- Packer's VNC boot_command
# cannot reach the console. So, like the FreeBSD ppc64le templates, we bake an
# unattended installer into custom media and leave Packer's boot_command empty.
#
# This installs a minimal, BOOTABLE base system onto the VM disk so that after the
# post-install reboot the disk boots unattended and sshd comes up for Packer to
# connect (root / osuadmin -- build only) and run the scripts/archpower/*
# provisioners. EVERYTHING needed for that first disk boot must happen here:
#   * grub for Open Firmware (powerpc-ieee1275) written into a PReP boot partition
#     -- SLOF reads the PReP partition directly; there is no BIOS/EFI on pseries.
#   * an initramfs that contains the virtio-scsi modules (the root disk is attached
#     via virtio-scsi; an autodetect-trimmed initramfs would be unbootable).
#   * the pseries Open Firmware serial console, hvc0.
#
# Target disk is /dev/sda: the template uses disk_interface = "virtio-scsi", which
# enumerates as sd* on pseries (matching the existing centos-7-ppc64 /
# debian-sid-ppc64 templates, whose autoinstallers also target sda).

set -euo pipefail
# Output goes to the autorun unit's StandardOutput=journal+console, so it lands in
# both `journalctl -u archpower-autoinstall` and on the console -- do NOT redirect
# to /dev/hvc0 here (that hid the failure reason from the journal).

DISK="/dev/sda"
PREP="${DISK}1"
ROOT="${DISK}2"
BUILD_ROOT_PW="osuadmin"       # build-only; cleanup.sh hardens sshd back to key-only

# Optional overrides (e.g. MIRROR=...) baked in from the template's `mirror` var by
# the remaster script.
[ -r /etc/archpower-install.conf ] && . /etc/archpower-install.conf
MIRROR="${MIRROR:-https://repo.archlinuxpower.org}"

# Idempotency guard: if SLOF re-boots the CD after a successful install (a pseries
# boot-order quirk -- see docs/archpower.md, fix with -prom-env boot-device=disk),
# do NOT wipe the good install. Fail fast instead of looping.
if blkid -L archpower-root >/dev/null 2>&1; then
  echo "==> existing ArchPOWER install found on ${DISK}; refusing to reinstall." >&2
  echo "==> SLOF booted the CD again -- set -prom-env boot-device=disk. Halting." >&2
  systemctl poweroff
  exit 0
fi

echo "==> OSL ArchPOWER unattended install starting on ${DISK}"

# 1. Wait for the live ISO's DHCP (systemd-networkd) so pacstrap can reach the repo.
echo "--> waiting for network"
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null "$MIRROR" 2>/dev/null \
     || ping -c1 -W2 repo.archlinuxpower.org >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Point pacman at the chosen mirror (the live env's mirrorlist is copied into the
# target by pacstrap, so this covers both). $repo/$arch are pacman vars (literal
# here); on a powerpc64 BE system $arch resolves to powerpc64.
printf 'Server = %s/$repo/$arch\n' "$MIRROR" >/etc/pacman.d/mirrorlist

# 2. Partition: MBR (msdos) with an ~32 MiB PReP boot partition (type 0x41) first,
#    then an ext4 root that fills the rest. MBR not GPT -- SLOF/pseries GPT booting
#    is historically unreliable, and the existing *-ppc64 templates use MBR+PReP.
#    PReP must be >=12 MiB for modern grub-ieee1275 (the old "1 MiB" advice fails).
echo "--> partitioning ${DISK} (PReP + ext4 root)"
wipefs -a "$DISK" || true
parted -s "$DISK" mklabel msdos
parted -s "$DISK" mkpart primary 1MiB 33MiB
parted -s "$DISK" set 1 prep on
parted -s "$DISK" set 1 boot on
parted -s "$DISK" mkpart primary ext4 33MiB 100%
partprobe "$DISK" || true
sleep 2

dd if=/dev/zero of="$PREP" bs=1M count=32 conv=fsync   # grub refuses a non-empty PReP
mkfs.ext4 -F -L archpower-root "$ROOT"

# 3. pacstrap a minimal base + the OpenStack guest bits in ONE transaction:
#    cloud-guest-utils provides growpart for the first-boot grow-root, and
#    qemu-guest-agent backs the image's hw_qemu_guest_agent=yes. Installing them
#    here (not via a later `pacman -Sy` provisioner) avoids a partial upgrade on
#    this rolling distro. NO cloud-init (not packaged for ArchPOWER) and NO
#    container tooling -- this is a base OS image.
mount "$ROOT" /mnt
echo "--> pacstrap base system"
# ArchPOWER's ppc64 kernel package is linux-ppc64 (there is no plain "linux").
pacstrap -K /mnt base linux-ppc64 mkinitcpio grub openssh sudo \
  cloud-guest-utils qemu-guest-agent

genfstab -U /mnt >>/mnt/etc/fstab

# 4. Configure the installed system + install the bootloader inside the chroot.
#    Unquoted heredoc: ${PREP} and ${BUILD_ROOT_PW} expand now (build-time values);
#    no runtime $ refs are needed inside the chroot script.
cat >/mnt/root/osl-chroot.sh <<CHROOT
#!/bin/bash
set -euo pipefail

# Locale / time / hostname
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc || true
echo 'en_US.UTF-8 UTF-8' >>/etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >/etc/locale.conf
echo 'archpower' >/etc/hostname

# pacman keyring (pacstrap -K initialised an empty one) so the shipped image can
# install/verify packages -- the provisioners and Go CI need a working pacman.
pacman-key --init
pacman-key --populate

# Networking: NIC-name-agnostic DHCP via systemd-networkd + resolved.
cat >/etc/systemd/network/80-dhcp.network <<NET
[Match]
Name=en* eth*
[Network]
DHCP=yes
NET
systemctl enable systemd-networkd systemd-resolved systemd-timesyncd sshd

# Serial getty on the pseries Open Firmware console.
systemctl enable serial-getty@hvc0.service

# Build-only root login so Packer connects after the reboot. sshd is hardened back
# to key-only for the shipped image by scripts/common/sshd.sh + archpower/cleanup.sh.
echo "root:${BUILD_ROOT_PW}" | chpasswd
printf 'PermitRootLogin yes\nPasswordAuthentication yes\nUseDNS no\n' >>/etc/ssh/sshd_config

# Initramfs WITHOUT the autodetect hook, with the virtio-scsi modules forced in, so
# the deployed guest can always find its (virtio-scsi) root disk.
sed -i 's/^MODULES=.*/MODULES=(virtio_pci virtio_scsi sd_mod)/' /etc/mkinitcpio.conf
sed -i 's/\bautodetect //' /etc/mkinitcpio.conf
mkinitcpio -P

# GRUB for Open Firmware / pseries: write core.elf into the PReP partition.
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
sed -i 's#^GRUB_CMDLINE_LINUX_DEFAULT=.*#GRUB_CMDLINE_LINUX_DEFAULT="console=hvc0"#' /etc/default/grub
grub-install --target=powerpc-ieee1275 --no-nvram --boot-directory=/boot ${PREP}
grub-mkconfig -o /boot/grub/grub.cfg
CHROOT

chmod +x /mnt/root/osl-chroot.sh
arch-chroot /mnt /root/osl-chroot.sh
rm -f /mnt/root/osl-chroot.sh

sync
umount -R /mnt || true

echo "==> install complete; rebooting into the installed system"
systemctl reboot
