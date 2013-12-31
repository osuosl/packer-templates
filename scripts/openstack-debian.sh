#!/bin/bash
. /tmp/common.sh
set -x

# Remove isc-dhcp-client as it does not owrk properly with this right now,
# it will be replaced with pump for the time being
$apt remove isc-dhcp-client
$apt install pump

# Fix issue where debian doesn't set locale correctly
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true

debconf-set-selections /root/locale-preseed.cfg

$apt update
$apt install cloud-utils git ca-certificates bash-completion

git clone https://github.com/flegmatik/linux-rootfs-resize.git
cd linux-rootfs-resize
chmod +x install
bash install
cd
rm -rf linux-rootfs-resize
update-grub

$apt purge git exim4

# Setup utils for vagrant
$apt install sudo rsync curl less

# change GRUB so log tab and console tab in openstack work
sed -i -e 's/quiet/console=ttyS0,115200n8 console=tty0 quiet/' /etc/default/grub
update-grub

# Make sure sudo works properly with openstack
sed -i 's/env_reset/env_reset\nDefaults\t\!requiretty/' /etc/sudoers

# Setup rc.local to setup host ssh-keys
# as well as get user public key from server
sed -i '/exit 0/d' /etc/rc.local
cat << EOF >> /etc/rc.local

# Take care of first boot setup
sh /etc/firstboot.sh

exit 0
EOF

$apt clean
rm -f /root/shutdown.sh

mkdir /var/log/firstboot
