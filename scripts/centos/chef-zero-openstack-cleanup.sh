#!/bin/bash -eux
systemctl list-unit-files | egrep "(openstack|neutron)-" | awk '{print $1}' | \
  xargs systemctl disable
systemctl disable rabbitmq-server mariadb httpd
systemctl stop 'openstack-*' 'neutron-*' rabbitmq-server mariadb httpd
