#!/bin/bash
. /tmp/common.sh
set -x

# install puppet
if [ "$OS" == "centos" ] ; then
    URL="http://yum.puppetlabs.com/el/${OSRELEASE}"
    cat > /etc/yum.repos.d/epel.repo << EOM
[epel]
name=epel
baseurl=http://epel.osuosl.org/${OSRELEASE}/\$basearch
enabled=1
gpgcheck=0
EOM
else
    URL="http://yum.puppetlabs.com/fedora/f${OSRELEASE}"
fi

cat > /etc/yum.repos.d/puppetlabs.repo << EOM
[puppetlabs]
name=puppetlabs
baseurl=${URL}/products/\$basearch
enabled=1
gpgcheck=0

[puppetlabs-deps]
name=puppetlabs-deps
baseurl=${URL}/dependencies/\$basearch
enabled=1
gpgcheck=0
EOM

$yum install puppet facter bash-completion
echo "set background=dark" >> /etc/vimrc

