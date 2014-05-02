#!/bin/bash

# Helper script to run scripts packer would normally run
scripts_url="https://raw.githubusercontent.com/osuosl/packer-templates/master/scripts"
files_url="https://raw.githubusercontent.com/osuosl/packer-templates/master/files/debian"
scripts="openstack-debian cleanup zerodisk"
files="cloud.cfg packages-preseed.cfg"

function finish {
    rm -f /tmp/*.sh
    poweroff
}

# run finish function on exit
trap finish EXIT

for file in $files ; do
    wget -q -O /tmp/${file} ${files_url}/${file}
done

wget -q -O /tmp/common.sh ${scripts_url}/common.sh

for script in $scripts ; do
    wget -q -O /tmp/${script}.sh ${scripts_url}/${script}.sh
    source /tmp/${script}.sh
done
