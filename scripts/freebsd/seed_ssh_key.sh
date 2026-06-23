#!/bin/sh -eux

# powerpc64le has no pkg repo and therefore no cloud-init, so OpenStack cannot
# inject an SSH key at boot. Seed the freebsd user with a static ("unmanaged")
# public key passed via SSH_AUTHORIZED_KEY so the deployed image is loginnable
# (sshd is hardened to key-only by cleanup_freebsd.sh). No-op if unset.
if [ -z "${SSH_AUTHORIZED_KEY:-}" ]; then
  echo "WARNING: SSH_AUTHORIZED_KEY is not set -- the freebsd user gets no key" >&2
  echo "WARNING: and sshd is key-only, so this image will not be loginnable." >&2
  echo "WARNING: set the ssh_authorized_key variable for the ppc64le templates." >&2
  exit 0
fi

mkdir -p /home/freebsd/.ssh
printf '%s\n' "$SSH_AUTHORIZED_KEY" >/home/freebsd/.ssh/authorized_keys
chmod 700 /home/freebsd/.ssh
chmod 600 /home/freebsd/.ssh/authorized_keys
chown -R freebsd:freebsd /home/freebsd/.ssh
