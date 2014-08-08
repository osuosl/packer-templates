#!/bin/bash

# Helper script to run scripts packer would normally run
scripts_url="https://raw.githubusercontent.com/osuosl/packer-templates/master/scripts"
files_url="https://raw.githubusercontent.com/osuosl/packer-templates/master/files/ubuntu"
scripts="openstack-debian serial-hvc1 cleanup zerodisk"

function finish {
    rm -f /tmp/*.sh
    poweroff
}

# run finish function on exit
trap finish EXIT

wget -q -O /tmp/cloud.cfg ${files_url}/cloud-ppc64.cfg
wget -q -O /tmp/common.sh ${scripts_url}/common.sh

for script in $scripts ; do
    wget -q -O /tmp/${script}.sh ${scripts_url}/${script}.sh
    source /tmp/${script}.sh
done
