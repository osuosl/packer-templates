#!/bin/bash

# Helper script to run scripts packer would normally run
url="https://raw.githubusercontent.com/osuosl/packer-templates/master/scripts/"
files="openstack-yum cleanup zerodisk"

wget -q -O /tmp/common.sh ${url}/common.sh

for file in $files ; do
    wget -q -O /tmp/${file}.sh ${url}/${file}.sh
    source /tmp/${file}.sh
done

rm -f /tmp/*.sh /root/postinstall-openstack-yum.sh
poweroff
