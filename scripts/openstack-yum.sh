#!/bin/bash
. /tmp/common.sh
set -x

# install cloud packages
$yum update
if [ "$(uname -m)" == "ppc64" ] ; then
    # install custom cloud-init to work around RH bug #1025071
    $yum install http://ftp.osuosl.org/pub/osl/openpower/rpms/cloud-init-0.7.2-7.fc20.noarch.rpm
    $yum install cloud-utils cloud-utils-growpart
else
    $yum install cloud-init cloud-utils dracut-modules-growroot
    dracut -f
fi

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

    rm -f anaconda* install.log* shutdown.sh
fi

# Don't edit grub on ppc64
if [ "$(uname -m)" != "ppc64" ] ; then
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
fi

# Make sure sudo works properly with openstack
sed -i "s/^.*requiretty$/Defaults !requiretty/" /etc/sudoers
