#!/bin/bash
. /tmp/common.sh
set -x

# add epel repo
cat > /etc/yum.repos.d/epel.repo << EOM
[epel]
name=epel
baseurl=http://epel.osuosl.org/${OSRELEASE}/\$basearch
enabled=1
gpgcheck=0
EOM

