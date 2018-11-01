#!/bin/bash -eux

echo 'APT::Default-Release "stable";' > /etc/apt/apt.conf.d/99defaultrelease

cat > /etc/apt/sources.list.d/testing.list <<EOF
deb http://deb.debian.org/debian testing main contrib non-free
deb-src http://deb.debian.org/debian testing main contrib non-free
EOF

apt-get -y update
apt-get -y install -t testing linux-image-powerpc64le
