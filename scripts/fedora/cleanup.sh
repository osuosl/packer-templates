#!/bin/bash -eux
if [ -x /usr/bin/dnf ] ; then
  echo "using dnf"
  dnf -y remove gcc cpp kernel-devel kernel-headers rpcbind postfix
  dnf -y clean all
else
  echo "using yum"
  yum -y remove gcc cpp kernel-devel kernel-headers rpcbind postfix
  yum -y clean all
fi

echo "port 0" >> /etc/chrony.conf
echo "cmdport 0" >> /etc/chrony.conf

rm -rf VBoxGuestAdditions_*.iso VBoxGuestAdditions_*.iso.?
rm -f /tmp/chef*rpm
