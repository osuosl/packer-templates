#!/bin/bash
. /tmp/common.sh
set -x
# Add vagrant user
if [ ! -d ${rootfs}/home/vagrant ] ; then
    $run_cmd groupadd vagrant
    $run_cmd useradd -d /home/vagrant -s /bin/bash -m -g vagrant vagrant
fi

# Installing vagrant keys
mkdir ${rootfs}/home/vagrant/.ssh
chmod 700 ${rootfs}/home/vagrant/.ssh
wget -q --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O ${rootfs}/home/vagrant/.ssh/authorized_keys
$run_cmd chown -R vagrant /home/vagrant/.ssh

# Ensure passwords are correct
$run_cmd echo "root:vagrant" | chpasswd
$run_cmd echo "vagrant:vagrant" | chpasswd

if [ -f /etc/sudoers ] ; then
    sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
    sed -i "s/^\(.*env_keep = \"\)/\1PATH /" /etc/sudoers
    sed -i -e 's/%admin ALL=(ALL) ALL/%admin ALL=NOPASSWD:ALL/g' /etc/sudoers
    sed -i -e 's/%sudo.*ALL=.*ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers
fi
