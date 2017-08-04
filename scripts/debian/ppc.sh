#!/bin/bash

set -e

# Install build dependencies
sudo apt-get -y update
sudo apt-get -y install build-essential bison flex devscripts \
	debhelper dh-autoreconf libsqlite3-dev librtasevent-dev \
	librtas-dev libsgutils2-dev iprutils libncurses5-dev

mkdir -p build
cd build

# Usage: downloadAndInstall <orig url> <debian url>
function downloadAndInstall {
  TEMPDIR=$(echo $1 | sed 's/_.*//' | sed 's/.*\///')
  mkdir -p $TEMPDIR
  cd $TEMPDIR
  wget $1
  tar xf $(echo $1 | sed 's/.*\///')
  cd */
  wget $2
  tar xf $(echo $2 | sed 's/.*\///')
  rm -f $(echo $2 | sed 's/.*\///')
  debuild -us -uc
  cd ..
  sudo dpkg -i *.deb
  cd ..
}

downloadAndInstall \
  "http://archive.ubuntu.com/ubuntu/pool/universe/libs/libservicelog/libservicelog_1.1.14.orig.tar.gz" \
  "http://archive.ubuntu.com/ubuntu/pool/universe/libs/libservicelog/libservicelog_1.1.14-0ubuntu1.debian.tar.gz"

downloadAndInstall \
  "http://archive.ubuntu.com/ubuntu/pool/universe/libv/libvpd/libvpd_2.2.3.orig.tar.gz" \
  "http://archive.ubuntu.com/ubuntu/pool/universe/libv/libvpd/libvpd_2.2.3-0ubuntu2.debian.tar.gz"

downloadAndInstall \
  "http://archive.ubuntu.com/ubuntu/pool/universe/s/servicelog/servicelog_1.1.12.orig.tar.gz" \
  "http://archive.ubuntu.com/ubuntu/pool/universe/s/servicelog/servicelog_1.1.12-0ubuntu1.debian.tar.gz"

downloadAndInstall \
  "http://http.debian.net/debian/pool/main/l/lsvpd/lsvpd_1.7.7.orig.tar.gz" \
  "http://http.debian.net/debian/pool/main/l/lsvpd/lsvpd_1.7.7-1.debian.tar.xz"

downloadAndInstall \
  "http://archive.ubuntu.com/ubuntu/pool/universe/p/ppc64-diag/ppc64-diag_2.6.4.orig.tar.gz" \
  "http://archive.ubuntu.com/ubuntu/pool/universe/p/ppc64-diag/ppc64-diag_2.6.4-0ubuntu4.debian.tar.gz"

cd ..
rm -rf build
