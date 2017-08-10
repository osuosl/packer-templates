#!/bin/bash

mkdir -p /etc/apt/sources.list.d
echo 'deb "http://packages.osuosl.org/repositories/apt/" jessie main' > /etc/apt/sources.list.d/osuosl.list

apt-get update
apt-get install --force-yes -y ppc64-diag
