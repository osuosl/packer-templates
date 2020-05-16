ubuntu_version="`lsb_release -r | awk '{print $2}'`";
major_version="`echo $ubuntu_version | awk -F. '{print $1}'`";

if [ "$major_version" -ge "20" ] ; then
  apt-get -y install cloud-utils cloud-init cloud-initramfs-growroot bash-completion
else
  apt-get -y install pump cloud-utils cloud-init cloud-initramfs-growroot bash-completion
fi

if [ -e /etc/yaboot.conf ] ; then
  sed -i 's/append\=\"/append\=\"net\.ifnames\=0 biosdevname\=0\ /' /etc/yaboot.conf
fi

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
    cp /boot/efi/EFI/ubuntu/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI
  fi
  # Write out the config
  update-grub
fi

# Speed up cloud-init by only using OpenStack and a specific metadata url
cat >> /etc/cloud/cloud.cfg.d/91_openstack_override.cfg << EOF
# Set the hostname in /etc/hosts so sudo doesn't complain
manage_etc_hosts: true
# Force only OpenStack being enabled
datasource_list: ['OpenStack']
datasource:
  Ec2:
    metadata_urls: [ 'http://169.254.169.254' ]
    timeout: 5
    max_wait: 10
EOF

# Remove default datasource_list
rm -f /etc/cloud/cloud.cfg.d/90_dpkg.cfg
