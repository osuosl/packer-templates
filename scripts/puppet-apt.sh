#!/bin/bash
. /tmp/common.sh
set -x
# install puppet
puppet_release="puppetlabs-release-${OSRELEASE}.deb"
wget -q http://apt.puppetlabs.com/${puppet_release}
dpkg -i $puppet_release
rm $puppet_release

$apt update
$apt install puppet facter curl rubygems
