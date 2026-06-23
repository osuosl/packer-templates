#!/bin/bash
set -eux

# Deploy login user. With no cloud-init there is no per-instance user creation, so
# (like the FreeBSD ppc64le images' "freebsd" user) we ship a static "arch" account
# in the wheel group. seed_ssh_key.sh installs its authorized_keys; sshd is key-only.
id arch >/dev/null 2>&1 || useradd -m -G wheel -s /bin/bash arch

install -d -m 0750 /etc/sudoers.d
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers.d/10-wheel
