ubuntu_version="`lsb_release -r | awk '{print $2}'`";
major_version="`echo $ubuntu_version | awk -F. '{print $1}'`";

if [ "$major_version" -ge "20" ] ; then
  apt-get -y install cloud-utils cloud-init cloud-initramfs-growroot bash-completion
else
  apt-get -y install pump cloud-utils cloud-init cloud-initramfs-growroot bash-completion
fi

systemctl enable cloud-init cloud-init-local
