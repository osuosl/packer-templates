#!/bin/sh -eux

# cleanup orphaned packages and cache (powerpc64le has no pkg repo / no pkg db)
case "$(uname -m)" in
powerpc)
  :
  ;;
*)
  pkg autoremove --yes
  pkg clean --yes --all
  rm -f /var/db/pkg/repo-FreeBSD.sqlite
  ;;
esac

# Purge files we don't need any longer.
# freebsd-update working state from freebsd_update.sh: the downloaded patch store
# (files/), the <hash>-install staging and <hash>-rollback directories, and the
# fetched indexes -- can be large and is not needed in the image. Remove the whole
# working dir contents (the install/rollback entries are directories, and on
# powerpc64le freebsd-update never ran, so tolerate an empty/missing dir).
rm -rf /var/db/freebsd-update/* 2>/dev/null || true
rm -rf /boot/kernel.old;
rm -f /boot/kernel*/*.symbols;
rm -f /*.core;
rm -rf /var/cache/pkg;

# --- per-instance identity / build-artifact removal (run LAST) -------------
# Delete SSH host keys so each deployed instance regenerates unique ones on first
# boot (sshd / cloud-init regenerate missing keys automatically).
rm -f /etc/ssh/ssh_host_*

# Drop stored entropy, DHCP leases and shell history.
rm -rf /var/db/entropy/* 2>/dev/null || true
rm -f /var/db/dhclient.leases.* 2>/dev/null || true
rm -f /root/.history /home/*/.history 2>/dev/null || true

# Reset cloud-init state so it re-runs against OpenStack metadata on first boot
# (no-op on powerpc64le, where cloud-init is not installed).
rm -rf /var/lib/cloud/* 2>/dev/null || true

# Truncate logs.
find /var/log -type f -exec sh -c ': > "$1"' _ {} \; 2>/dev/null || true

# Tighten SSH to key-only for the final image. sshd uses the FIRST value for each
# keyword, so strip the permissive lines the installerconfig added for the build
# before appending the hardened ones. On amd64/arm64 cloud-init injects the key
# (ssh_pwauth: false); on powerpc64le the freebsd key is seeded by seed_ssh_key.sh.
sed -i '' -E '/^(PasswordAuthentication|PermitRootLogin|UseDNS)[[:space:]]/d' /etc/ssh/sshd_config
printf 'PasswordAuthentication no\nPermitRootLogin without-password\nUseDNS no\n' >>/etc/ssh/sshd_config

# Ensure first-boot services (growfs, host-key regen, cloud-init) run on deploy.
touch /firstboot
