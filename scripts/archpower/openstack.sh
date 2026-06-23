#!/bin/bash
set -eux

# OpenStack guest bits for the ArchPOWER ppc64 BE base image. ArchPOWER has NO
# cloud-init package, so (like the FreeBSD ppc64le images) there is no metadata
# datasource: the login key is seeded statically by seed_ssh_key.sh and the root
# filesystem is grown on first boot by the osl-firstboot unit below (growpart),
# rather than by cloud-init growpart/resizefs.

# cloud-guest-utils (growpart) and qemu-guest-agent are installed by the ISO
# installer's pacstrap (same transaction as base -- no `pacman -Sy` partial upgrade
# here). Enable the guest agent (images upload with hw_qemu_guest_agent=yes;
# bin/upload.sh). Service name has varied across versions; tolerate either.
systemctl enable qemu-guest-agent.service 2>/dev/null \
  || systemctl enable qemu-ga.service 2>/dev/null || true

# First-boot oneshot: regenerate SSH host keys (removed by cleanup.sh for
# per-instance uniqueness) and grow the root filesystem to the flavor disk.
install -d -m 0755 /usr/local/sbin
cat >/usr/local/sbin/osl-firstboot <<'FB'
#!/bin/sh
set -e

# Regenerate SSH host keys if missing so each deployed instance is unique.
[ -e /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -A

# Grow the root partition + filesystem to fill the OpenStack flavor disk.
root_src=$(findmnt -no SOURCE /)
case "$root_src" in
  /dev/*) ;;
  *) exit 0 ;;
esac
pk=$(lsblk -no PKNAME "$root_src" 2>/dev/null || true)
pn=$(printf '%s' "$root_src" | grep -o '[0-9]*$')
if [ -n "$pk" ] && [ -n "$pn" ]; then
  growpart "/dev/$pk" "$pn" || true
  resize2fs "$root_src" || true
fi
FB
chmod +x /usr/local/sbin/osl-firstboot

cat >/etc/systemd/system/osl-firstboot.service <<'UNIT'
[Unit]
Description=OSL first boot (regen SSH host keys + grow root)
ConditionPathExists=!/var/lib/osl-firstboot-done
After=systemd-remount-fs.service
Before=sshd.service systemd-user-sessions.service
DefaultDependencies=no

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/osl-firstboot
ExecStartPost=/usr/bin/touch /var/lib/osl-firstboot-done

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable osl-firstboot.service
