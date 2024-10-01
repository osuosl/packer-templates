#!/bin/sh -eux

# Install curl and ca_root_nss
pkg install -y curl ca_root_nss py39-cloud-init;

# Avoid pausing at the boot screen
cat >>/etc/loader.conf << LOADER_CONF
autoboot_delay="-1"
beastie_disable="YES"
loader_logo="none"
hw.memtest.tests="0"
LOADER_CONF

echo 'Disable X11 in make.conf because Vagrants VMs are (usually) headless'
cat >>/etc/make.conf << MAKE_CONF
WITHOUT_X11="YES"
WITHOUT_GUI="YES"
MAKE_CONF

echo 'Enable cloud-init'
cat >>/etc/rc.conf << RC_CONF
cloudinit_enable="YES"
RC_CONF

echo 'Update the locate DB'
/etc/periodic/weekly/310.locate
