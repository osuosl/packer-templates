#!/bin/bash -eux
if [ -x /usr/bin/dnf ] ; then
  echo "using dnf"
  dnf -y remove gcc cpp kernel-devel kernel-headers
  dnf -y clean all
else
  echo "using yum"
  yum -y remove gcc cpp kernel-devel kernel-headers
  yum -y clean all
fi
rm -rf VBoxGuestAdditions_*.iso VBoxGuestAdditions_*.iso.?
rm -f /tmp/chef*rpm
