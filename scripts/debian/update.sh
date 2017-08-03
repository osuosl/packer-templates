#!/bin/sh -eux

apt-get -y update;
apt-get -y upgrade;

if [ -d /etc/init ]; then
    # update package index on boot
    cat <<EOF >/etc/init/refresh-apt.conf;
description "update package index"
start on networking
task
exec /usr/bin/apt-get update
EOF
fi
