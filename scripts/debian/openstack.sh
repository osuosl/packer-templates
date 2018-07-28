#!/bin/bash -eux
apt-get -y install pump cloud-utils cloud-init cloud-initramfs-growroot bash-completion

cat >> /etc/cloud/cloud.cfg.d/91_openstack_override.cfg << EOF
# Set the hostname in /etc/hosts so sudo doesn't complain
manage_etc_hosts: true
EOF
