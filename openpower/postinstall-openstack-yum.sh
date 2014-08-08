#!/bin/bash

# Helper script to run scripts packer would normally run
url="https://raw.githubusercontent.com/osuosl/packer-templates/master/scripts/"
files="openstack-yum cloud-init-systemd cleanup zerodisk"

function finish {
    rm -f /tmp/*.sh
    poweroff
}

# run finish function on exit
trap finish EXIT

wget -q -O /tmp/common.sh ${url}/common.sh

for file in $files ; do
    wget -q -O /tmp/${file}.sh ${url}/${file}.sh
    source /tmp/${file}.sh
done
