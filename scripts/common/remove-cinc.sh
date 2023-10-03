#!/bin/bash -eux
if [ -f "/bin/dnf" ] ; then
  dnf remove -y cinc
elif [ -f "/bin/yum" ] ; then
  yum remove -y cinc
elif [ -f "/usr/bin/apt-get" ] ; then
  apt-get -y purge cinc
fi
rm -rf /tmp/cinc
