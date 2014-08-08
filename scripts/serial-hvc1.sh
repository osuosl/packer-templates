#!/bin/bash
. /tmp/common.sh
set -x

# Setup second serial console on ppc guests for troubleshooting

# systemd
if [ -e /usr/lib/systemd/system/serial-getty\@.service ] ; then
  ln -s /usr/lib/systemd/system/serial-getty\@.service \
    /etc/systemd/system/getty.target.wants/serial-getty\@hvc1.service
  systemctl daemon-reload
# upstart
elif [ -e /etc/init/hvc0.conf ] ; then
  cat << EOF >> /etc/init/hvc1.conf
# hvc1 - getty
#
# This service maintains a getty on hvc1 from the point the system is
# started until it is shut down again.

start on stopped rc RUNLEVEL=[2345] and (
            not-container or
            container CONTAINER=lxc or
            container CONTAINER=lxc-libvirt)

stop on runlevel [!2345]

respawn
exec /sbin/getty -L hvc1 9600 vt100
EOF
# inittab
elif [ -e /etc/inittab -a -n "$(grep hvc0 /etc/inittab)" ] ; then
  echo "h1:23:respawn:/sbin/getty -L hvc1 9600 vt100" >> /etc/inittab
fi
