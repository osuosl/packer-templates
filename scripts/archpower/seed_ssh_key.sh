#!/bin/bash
set -eux

# ArchPOWER has no cloud-init, so OpenStack cannot inject an SSH key at boot. Seed
# the arch user with a static ("unmanaged") public key passed via SSH_AUTHORIZED_KEY
# so the deployed image is loginnable (sshd is hardened to key-only by cleanup.sh).
# No-op if unset -- same pattern as scripts/freebsd/seed_ssh_key.sh.
if [ -z "${SSH_AUTHORIZED_KEY:-}" ]; then
  echo "WARNING: SSH_AUTHORIZED_KEY is not set -- the arch user gets no key" >&2
  echo "WARNING: and sshd is key-only, so this image will not be loginnable." >&2
  echo "WARNING: set the ssh_authorized_key variable for the archpower template." >&2
  exit 0
fi

install -d -m 0700 -o arch -g arch /home/arch/.ssh
printf '%s\n' "$SSH_AUTHORIZED_KEY" >/home/arch/.ssh/authorized_keys
chmod 600 /home/arch/.ssh/authorized_keys
chown arch:arch /home/arch/.ssh/authorized_keys
