#!/bin/bash
# Archpower Linux automated installation script for Packer
# Based on https://github.com/kth5/archpower/wiki/Installation-%7C-KVM-or-PReP
# This script does minimal installation to get SSH access for Packer provisioning

set -eux

# Configuration
ROOT_DISK="/dev/sda"
PREP_PART="${ROOT_DISK}1"
ROOT_PART="${ROOT_DISK}2"
SWAP_PART="${ROOT_DISK}3"
MOUNT_POINT="/mnt"
ROOT_PASSWORD="osuadmin"
HOSTNAME="archpower"

# Wait for disk to be available
sleep 5

# Partition the disk using fdisk
# Create MBR partition table with:
#  1. PPC PReP Boot partition (32MB) - bootable
#  2. Root partition (rest minus swap)
#  3. Swap partition (2GB)
fdisk "${ROOT_DISK}" <<EOF
o
n
p
1

+32M
t
41
a
n
p
2

-2G
n
p
3


t
3
82
w
EOF

# Wait for partition changes to propagate
sleep 2
partprobe "${ROOT_DISK}"
sleep 2

# Format partitions
mkfs.ext4 -F "${ROOT_PART}"
mkswap "${SWAP_PART}"
swapon "${SWAP_PART}"

# Mount root partition
mount "${ROOT_PART}" "${MOUNT_POINT}"

# Initialize pacman keyring
pacman-key --init
pacman-key --populate archpower

# Install minimal base system for Packer to connect
pacstrap "${MOUNT_POINT}" base linux grub openssh dhcpcd

# Generate fstab
genfstab -U "${MOUNT_POINT}" >> "${MOUNT_POINT}/etc/fstab"

# Configure the system via arch-chroot
arch-chroot "${MOUNT_POINT}" /bin/bash <<CHROOT
set -eux

# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "${HOSTNAME}" > /etc/hostname

# Configure hosts file
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# Set root password (for Packer SSH connection)
echo "root:${ROOT_PASSWORD}" | chpasswd

# Enable SSH with root login for Packer provisioning
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl enable sshd

# Enable DHCP for network
systemctl enable dhcpcd

# Generate initramfs
mkinitcpio -P

# Configure and install GRUB for PPC PReP Boot
grub-mkconfig -o /boot/grub/grub.cfg
grub-install "${PREP_PART}"

CHROOT

# Unmount and sync
sync
umount -R "${MOUNT_POINT}"
swapoff "${SWAP_PART}"

# Reboot into the installed system
reboot
