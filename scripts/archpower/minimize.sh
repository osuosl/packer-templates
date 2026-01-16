#!/bin/bash
# Minimize Archpower disk image

set -eux

# Zero out free space to allow better compression
dd if=/dev/zero of=/EMPTY bs=1M || true
rm -f /EMPTY

# Sync to ensure all changes are written
sync
