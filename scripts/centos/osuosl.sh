#!/bin/bash -eux

# Use OSL for repos
if [ -f /etc/yum.repos.d/CentOS-Stream-AppStream.repo ] ; then
  # CentOS Stream 8
  BASE="Stream-BaseOS"
  sed -i -e 's/^\(mirrorlist.*\)/#\1/g' /etc/yum.repos.d/CentOS-Stream-AppStream.repo
  sed -i -e 's/^\(mirrorlist.*\)/#\1/g' /etc/yum.repos.d/CentOS-Stream-Extras.repo
  sed -i -e 's/^#baseurl=.*$contentdir\/$stream\/BaseOS\/$basearch\/os\//baseurl=http:\/\/centos.osuosl.org\/$stream\/BaseOS\/$basearch\/os\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$contentdir\/$stream\/AppStream\/$basearch\/os\//baseurl=http:\/\/centos.osuosl.org\/$stream\/AppStream\/$basearch\/os\//g' /etc/yum.repos.d/CentOS-Stream-AppStream.repo
  sed -i -e 's/^#baseurl=.*$contentdir\/$stream\/extras\/$basearch\/os\//baseurl=http:\/\/centos.osuosl.org\/$stream\/extras\/$basearch\/os\//g' /etc/yum.repos.d/CentOS-Stream-Extras.repo
elif [ -f /etc/yum.repos.d/CentOS-Linux-AppStream.repo ] ; then
  # EL8
  BASE="Linux-BaseOS"
  sed -i -e 's/^\(mirrorlist.*\)/#\1/g' /etc/yum.repos.d/CentOS-Linux-AppStream.repo
  sed -i -e 's/^\(mirrorlist.*\)/#\1/g' /etc/yum.repos.d/CentOS-Linux-Extras.repo
  sed -i -e 's/^#baseurl=.*$contentdir\/$releasever\/BaseOS\/$basearch\/os\//baseurl=http:\/\/centos.osuosl.org\/$releasever\/BaseOS\/$basearch\/os\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$contentdir\/$releasever\/AppStream\/$basearch\/os\//baseurl=http:\/\/centos.osuosl.org\/$releasever\/AppStream\/$basearch\/os\//g' /etc/yum.repos.d/CentOS-Linux-AppStream.repo
  sed -i -e 's/^#baseurl=.*$contentdir\/$releasever\/extras\/$basearch\/os\//baseurl=http:\/\/centos.osuosl.org\/$releasever\/extras\/$basearch\/os\//g' /etc/yum.repos.d/CentOS-Linux-Extras.repo
else
  # EL7
  BASE="Base"
fi

sed -i -e 's/^\(mirrorlist.*\)/#\1/g' /etc/yum.repos.d/CentOS-${BASE}.repo

# For EL8 this is always the case, for EL7, only on x86
if [ -f /etc/yum.repos.d/CentOS-Linux-AppStream.repo -o "$(uname -m)" == "x86_64" ] ; then
  sed -i -e 's/^#baseurl=.*$releasever\/os\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/os\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$releasever\/updates\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/updates\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$releasever\/addons\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/addons\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$releasever\/extras\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/extras\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$releasever\/centosplus\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/centosplus\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$releasever\/contrib\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/contrib\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
# EL7 aarch64 and ppc64le need centos-altarch
else
  sed -i -e 's/^#baseurl=.*$releasever\/os\/$basearch\//baseurl=http\:\/\/centos-altarch.osuosl.org\/$releasever\/os\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$releasever\/updates\/$basearch\//baseurl=http\:\/\/centos-altarch.osuosl.org\/$releasever\/updates\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$releasever\/addons\/$basearch\//baseurl=http\:\/\/centos-altarch.osuosl.org\/$releasever\/addons\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$releasever\/extras\/$basearch\//baseurl=http\:\/\/centos-altarch.osuosl.org\/$releasever\/extras\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$releasever\/centosplus\/$basearch\//baseurl=http\:\/\/centos-altarch.osuosl.org\/$releasever\/centosplus\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
  sed -i -e 's/^#baseurl=.*$releasever\/contrib\/$basearch\//baseurl=http\:\/\/centos-altarch.osuosl.org\/$releasever\/contrib\/$basearch\//g' /etc/yum.repos.d/CentOS-${BASE}.repo
fi
