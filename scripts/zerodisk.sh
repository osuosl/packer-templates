#!/bin/bash
set -x
# Zero out the free space to save space in the final image:
dd if=/dev/zero of=/EMPTY bs=1M
sync
rm -f /EMPTY
sync
exit
