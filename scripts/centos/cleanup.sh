#!/bin/bash -eux

# should output one of 'redhat' 'centos' 'oraclelinux'
distro="`rpm -qf --queryformat '%{NAME}' /etc/redhat-release | cut -f 1 -d '-'`"

# Remove development and kernel source packages
yum -y remove gcc cpp kernel-devel kernel-headers;
yum -y clean all;
rm -f /tmp/chef*rpm

# Clean up network interface persistence
rm -f /etc/udev/rules.d/70-persistent-net.rules;
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules;
rm -rf /dev/.udev/;

for ndev in `ls -1 /etc/sysconfig/network-scripts/ifcfg-*`; do
    if [ "`basename $ndev`" != "ifcfg-lo" ]; then
        sed -i '/^HWADDR/d' "$ndev";
        sed -i '/^UUID/d' "$ndev";
    fi
done

# delete any logs that have built up during the install
find /var/log/ -name *.log -exec rm -f {} \;

# remove previous kernels that yum preserved for rollback
yum install -y yum-utils
package-cleanup --oldkernels --count=1 -y

# Remove EPEL remove if it exists
yum -y remove epel-release

# We don't need nfs or postfix installed by default
if [ -e /etc/keystone ] ; then
  echo "VM has OpenStack installed, skipping removing postfix/rpcbind..."
else
  yum -y remove rpcbind postfix
fi

echo "port 0" >> /etc/chrony.conf
echo "cmdport 0" >> /etc/chrony.conf

chkconfig kdump off
