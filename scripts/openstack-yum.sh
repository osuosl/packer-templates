#!/bin/bash
. /tmp/common.sh
set -x
# install cloud packages
base_url="https://raw.github.com/flegmatik/centos-image-resize/master"
$yum install cloud-init cloud-utils cloud-utils-growpart

# Update initrd
wget -q ${base_url}/centos-image-mod.sh ${base_url}/init-part
bash centos-image-mod.sh
rm -f centos-image-mod.sh init-part
sed -i -e 's/console=/console=tty console=/' /boot/grub/grub.conf
sed -i -e 's/timeout=.*/timeout=0/' /boot/grub/grub.conf
cd /boot
ln -s boot .

# Make sure sudo works properly with openstack
sed -i "s/^.*requiretty/Defaults !requiretty/" /etc/sudoers
