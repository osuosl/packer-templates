#!/bin/bash -eux
if [ -f "/bin/dnf" ] ; then
  dnf remove -y cinc yamllint
elif [ -f "/usr/bin/apt-get" ] ; then
  apt-get -y purge cinc yamllint
fi
rm -rf /tmp/cinc
