#!/bin/bash
. /tmp/common.sh
set -x

if [ "$OS" == "centos" ] ; then
    # Setup the cloud-init repo for cloud-init 0.7.x
    cat << EOF >> /etc/yum.repos.d/cloud-init.repo
[cloud-init]
Name=Cloud Init Repo
baseurl=http://repos.fedorapeople.org/repos/openstack/cloud-init/epel-6/
gpgcheck=0
enabled=1
EOF
fi

# install cloud packages
$yum update
$yum install cloud-init cloud-utils cloud-utils-growpart git

if [ "$OS" == "centos" ] ; then
    # Change default user to centos and add to wheel
    # Also make it so that we use proper cloud-init
    # configuration.
    sed -ni '/system_info.*/q;p' /etc/cloud/cloud.cfg
    cat << EOF >> /etc/cloud/cloud.cfg
system_info:
  distro: rhel
  default_user:
    name: centos
    groups: [wheel]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
  paths:
    cloud_dir: /var/lib/cloud
    templates_dir: /etc/cloud/templates
  ssh_svcname: sshd

# vim:syntax=yaml
EOF

    # Update initrd
    git clone https://github.com/flegmatik/linux-rootfs-resize.git
    cd linux-rootfs-resize
    chmod +x install
    bash install
    cd
    rm -rf linux-rootfs-resize
    rm -f anaconda* install.log* shutdown.sh
fi

$yum erase git
if [ -e /boot/grub/grub.conf ] ; then
    sed -i -e 's/rhgb.*/console=ttyS0,115200n8 console=tty0 quiet/' /boot/grub/grub.conf
    cd /boot
    ln -s boot .
elif [ -e /etc/default/grub ] ; then
    sed -i -e \
        's/GRUB_CMDLINE_LINUX=\"\(.*\)/GRUB_CMDLINE_LINUX=\"console=ttyS0,115200n8 console=tty0 quiet \1/g' \
        /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg
fi

# Make sure sudo works properly with openstack
sed -i "s/^.*requiretty$/Defaults !requiretty/" /etc/sudoers
