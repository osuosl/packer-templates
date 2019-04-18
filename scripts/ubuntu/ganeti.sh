apt-get -y install pump cloud-utils cloud-init cloud-initramfs-growroot \
    bash-completion
systemctl enable cloud-init cloud-init-local
rm -f /etc/netplan/01-netcfg.yaml
# No timeout for grub menu
sed -i -e 's/^GRUB_TIMEOUT.*/GRUB_TIMEOUT=0/' /etc/default/grub
# # Write out the config
update-grub
