#!/bin/bash -eux
apt-get -y install cloud-utils cloud-init cloud-initramfs-growroot \
  bash-completion parted

if [ -e /etc/default/grub ] ; then
  # output bootup to serial
  sed -i -e \
    's/GRUB_CMDLINE_LINUX=\"\(.*\)/GRUB_CMDLINE_LINUX=\"console=ttyS0,115200n8 console=tty0 \1/g' \
    /etc/default/grub
  # No timeout for grub menu
  sed -i -e 's/^GRUB_TIMEOUT.*/GRUB_TIMEOUT=0/' /etc/default/grub
  # No fancy boot screen
  grep -q rhgb /etc/default/grub && sed -e 's/rhgb //' /etc/default/grub
  # Debian doesn't create BOOTAA64.EFI by default, so do it manually so the VM
  # can boot properly.
  if [[ ! -e /boot/efi/EFI/BOOT/BOOTAA64.EFI && "$(uname -m)" == "aarch64" ]] ; then
    mkdir -p /boot/efi/EFI/BOOT
    cp /boot/efi/EFI/debian/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI
  fi
  # Write out the config
  update-grub
fi

cat >> /etc/cloud/cloud.cfg.d/91_openstack_override.cfg << EOF
# Set the hostname in /etc/hosts so sudo doesn't complain
manage_etc_hosts: true
EOF
