#!/bin/bash -eux

yum install -y dhcp-client

echo -en "[main]\ndhcp=dhclient\n" > /etc/NetworkManager/conf.d/dhcp.conf
