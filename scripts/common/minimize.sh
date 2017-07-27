#!/bin/sh -eux

# Whiteout the swap partition to reduce box size 
# Swap is disabled till reboot 
readonly swapuuid=$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
readonly swappart=$(readlink -f /dev/disk/by-uuid/"$swapuuid")
/sbin/swapoff "$swappart" || echo "swapoff failed, ignoring"
dd if=/dev/zero of="$swappart" bs=1M || echo "dd exit code $? is suppressed" 
/sbin/mkswap -U "$swapuuid" "$swappart" || echo "mkswap failed, ignoring"
rm -rf /tmp/*

dd if=/dev/zero of=/EMPTY bs=1M || echo "dd exit code $? is suppressed" 
rm -f /EMPTY
# Block until the empty file has been removed, otherwise, Packer
# will try to kill the box while the disk is still full and that's bad
sync
