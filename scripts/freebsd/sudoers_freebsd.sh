#!/bin/sh -eux

pkg install -y sudo;
echo "freebsd ALL=(ALL) NOPASSWD: ALL" >>/usr/local/etc/sudoers;
