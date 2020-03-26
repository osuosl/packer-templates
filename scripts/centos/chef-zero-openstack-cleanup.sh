#!/bin/bash -eux
systemctl list-unit-files | egrep "(openstack|neutron)-" | awk '{print $1}' | \
  xargs systemctl disable
systemctl disable ceph-mon@controller ceph-mgr@controller ceph-osd@*
systemctl stop 'openstack-*' 'neutron-*' ceph-mon@controller \
  ceph-mgr@controller ceph-osd@*
rm -rf /var/lib/ceph/*/* /etc/ceph/* /var/tmp/crush_map_decompressed
yum remove -y chef
rm -rf /opt/chef
