#!/bin/bash
set -eux

# Clean pacman caches + orphaned packages (Arch equivalent of the apt/dnf cleanup;
# cinc/osl-unmanaged has no pacman support, so ArchPOWER is a scripts-only build).
pacman -Scc --noconfirm || true
orphans="$(pacman -Qtdq || true)"
if [ -n "$orphans" ]; then
  # shellcheck disable=SC2086
  pacman -Rns --noconfirm $orphans || true
fi

# Per-instance identity: delete SSH host keys (osl-firstboot regenerates unique ones
# on first boot, before sshd starts).
rm -f /etc/ssh/ssh_host_*

# Drop build-time leftovers.
rm -f /root/osl-chroot.sh
rm -rf /var/lib/systemd/random-seed
rm -f /etc/archpower-install.conf
find /var/log -type f -exec truncate -s0 {} \; 2>/dev/null || true

# Harden sshd to key-only for the shipped image: strip the permissive lines the
# installer added for the Packer build, then set the final policy (sshd uses the
# FIRST value per keyword). The arch user logs in via its seeded key.
sed -i -E '/^(PasswordAuthentication|PermitRootLogin|UseDNS)[[:space:]]/d' /etc/ssh/sshd_config
printf 'PasswordAuthentication no\nPermitRootLogin no\nUseDNS no\n' >>/etc/ssh/sshd_config
