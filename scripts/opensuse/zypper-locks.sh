#!/bin/sh -eux

# Wait until the system is fully booted
while ! systemctl is-system-running --quiet; do
  echo "Waiting for the system to fully boot..."
  sleep 1
done

echo "System has fully booted. Proceeding with further commands..."

# remove zypper locks on removed packages to avoid later dependency problems
zypper --non-interactive rl \*
