#!/bin/bash -eux

yum -y install epel-release

# use our mirror
sed -i -e 's/^\(mirrorlist.*\)/#\1/g' /etc/yum.repos.d/epel.repo
sed -i -e 's/^#baseurl=.*pub\/epel\/.*\/$basearch$/baseurl=http:\/\/epel.osuosl.org\/$releasever\/$basearch\//' \
  /etc/yum.repos.d/epel.repo
