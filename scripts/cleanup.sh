#!/bin/bash
. /tmp/common.sh
set -x
# cleanup
if [ -f /etc/debian_version ] ; then
    # Removing leftover leases and persistent rules
    echo "cleaning up dhcp leases"
    rm /var/lib/dhcp3/*

    # Make sure Udev doesn't block our network
    # http://6.ptmc.org/?p=164
    echo "cleaning up udev rules"
    rm /etc/udev/rules.d/70-persistent-net.rules
    mkdir /etc/udev/rules.d/70-persistent-net.rules
    rm -rf /dev/.udev/
    rm /lib/udev/rules.d/75-persistent-net-generator.rules

    # remove annoying resolvconf package
    DEBIAN_FRONTEND=noninteractive apt-get -y remove resolvconf

    echo "Adding a 2 sec delay to the interface up, to make the dhclient happy"
    echo "pre-up sleep 2" >> /etc/network/interfaces
    # Remove all kernels except the current version
    dpkg-query -l 'linux-image-[0-9]*' | grep ^ii | awk '{print $2}' | \
        grep -v $(uname -r) | xargs -r apt-get -y remove
    apt-get -y clean all
elif [ -f /etc/redhat-release ] ; then
    # Exclude upgrading kernels
    if [ "$OS" == "centos" ] ; then
        sed -i -e 's/\[updates\]/\[updates\]\nexclude=kernel*/' \
            /etc/yum.repos.d/CentOS-Base.repo
    else
        sed -i -e 's/\[updates\]/\[updates\]\nexclude=kernel*/' \
            /etc/yum.repos.d/fedora-updates.repo
    fi
    # Remove all kernels except the current version
    rpm -qa | grep ^kernel-[0-9].* | sort | grep -v $(uname -r) | \
        xargs -r yum -y remove
    yum -y clean all
fi
rm /tmp/common.sh
