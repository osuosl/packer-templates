#!/bin/bash -eux
# These were only needed for building VMware/Virtualbox extensions:

zypper -n rm -u gcc make kernel-default-devel kernel-devel

# Clean up network interface persistence
rm -f /etc/udev/rules.d/70-persistent-net.rules;
touch /etc/udev/rules.d/75-persistent-net-generator.rules;

rm -f /var/lib/wicked/lease*

# delete any logs that have built up during the install
find /var/log/ -name *.log -exec rm -f {} \;

truncate -s 0 /etc/machine-id
if test -f /var/lib/dbus/machine-id
then
  truncate -s 0 /var/lib/dbus/machine-id  # if not symlinked to "/etc/machine-id"
fi

m -f /var/lib/systemd/random-seed
