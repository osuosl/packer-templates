apt-get -y install pump cloud-utils cloud-init cloud-initramfs-growroot \
    bash-completion
# No timeout for grub menu
sed -i -e 's/^GRUB_TIMEOUT.*/GRUB_TIMEOUT=0/' /etc/default/grub
# # Write out the config
update-grub
