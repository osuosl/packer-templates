#!/bin/bash -eux
mkdir -p /tmp/chef && sudo chown -R centos:centos /tmp/chef
mkdir -p /tmp/config && sudo chown -R centos:centos /tmp/config
mkdir -p /etc/chef && sudo chown -R centos:centos /etc/chef
mkdir -p /tmp/packer-chef-client/{cookbooks,roles,data_bags} && sudo chown -R centos:centos /tmp/packer-chef-client
mkdir -p /etc/chef/ohai/hints
touch /etc/chef/ohai/hints/openstack.json
