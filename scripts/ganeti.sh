#!/bin/bash
. /tmp/common.sh
set -x

# Setup ganeti
if [ -f /etc/debian_version ] ; then
    $apt install vim git-core lvm2 aptitude nfs-common parted

    # Setting editors
    update-alternatives --set editor /usr/bin/vim.basic

    # Configure LVM
    echo "configuring LVM"
    swapoff -a
    parted /dev/sda -- rm 2
    parted /dev/sda -- mkpart primary ext2 15GB -1s
    parted /dev/sda -- toggle 2 lvm
    pvcreate /dev/sda2
    vgcreate ganeti /dev/sda2
    lvcreate -L 512M -n swap ganeti
    mkswap -f /dev/ganeti/swap
    sed -i -e 's/sda5/ganeti\/swap/' /etc/fstab
elif [ -f /etc/redhat-release ] ; then
    $yum install git vim nfs-utils
fi

# Modify 127.0.1.1 host entry as it confuses ganeti during initialization
sed -i -e 's/127.0.1.1\(.*\)/33.33.33.11 \1 /' /etc/hosts

# Install ganeti deps
git clone -q git://github.com/ramereth/vagrant-ganeti.git
cd vagrant-ganeti
git submodule -q update --init
ln -s $(pwd) /vagrant
puppet apply --modulepath=modules modules/ganeti_tutorial/nodes/install-deps.pp
cd
rm -rf vagrant-ganeti
rm -f /vagrant

