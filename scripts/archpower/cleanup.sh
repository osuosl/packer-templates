#!/bin/bash
# Clean up Archpower system before image creation
# Based on osl-unmanaged::cleanup

set -eux

# Clear pacman cache
pacman -Scc --noconfirm

# Remove machine-specific files
rm -f /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Clear logs
find /var/log -type f -exec truncate -s 0 {} \;
journalctl --vacuum-time=1s || true

# Clear temporary files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clear bash history
rm -f /root/.bash_history
rm -f /var/lib/osuadmin/.bash_history
history -c || true

# Remove SSH host keys (will be regenerated on first boot)
rm -f /etc/ssh/ssh_host_*

# Clear cloud-init state (will run fresh on first boot)
rm -rf /var/lib/cloud/*

# Remove any network persistent rules
rm -f /etc/udev/rules.d/70-persistent-net.rules

# Sync filesystem
sync
