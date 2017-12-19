#!/bin/bash

# Delete X11 libraries
apt-get -y purge libx11-data xauth libxmuu1 libxcb1 libx11-6 libxext6;

# Delete oddities
apt-get -y purge popularity-contest installation-report friendly-recovery laptop-detect;

# Delete services we don't need installed by default
apt-get -y purge exim4-base rpcbind

apt-get -y autoremove;
apt-get -y clean;

# Remove caches
find /var/cache -type f -exec rm -rf {} \;

# delete any logs that have built up during the install
find /var/log/ -name *.log -exec rm -f {} \;
