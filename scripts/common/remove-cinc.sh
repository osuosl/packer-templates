#!/bin/bash -eux
if [ -f "/bin/dnf" ] ; then
  dnf remove -y cinc
fi
rm -rf /tmp/cinc
