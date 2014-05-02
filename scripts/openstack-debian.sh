#!/bin/bash
. /tmp/common.sh
set -x

# Remove isc-dhcp-client as it does not owrk properly with this right now,
# it will be replaced with pump for the time being
$apt remove isc-dhcp-client
$apt install pump cloud-utils cloud-init cloud-initramfs-growroot bash-completion
update-initramfs -u

# dpkg-reconfigure cloud-init and locales
debconf-set-selections /tmp/packages-preseed.cfg

mv -f /tmp/cloud.cfg /etc/cloud/cloud.cfg

$apt purge exim4*

# Setup utils for vagrant
$apt install sudo rsync curl less

# change GRUB so log tab and console tab in openstack work
if [ -e /etc/default/grub ] ; then
    sed -i -e 's/quiet/console=ttyS0,115200n8 console=tty0 quiet/' \
        /etc/default/grub
    update-grub
fi

# Make sure sudo works properly with openstack and vagrant
sed -i 's/env_reset/env_reset\nDefaults\t\!requiretty/' /etc/sudoers

# Fix networking to auto bring up eth0 and work correctly with cloud-init
sed -i 's/allow-hotplug eth0/auto eth0/' /etc/network/interfaces

$apt autoremove
$apt autoclean
$apt clean

rm -f /root/shutdown.sh
