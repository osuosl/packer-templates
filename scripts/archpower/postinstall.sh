#!/bin/bash
# Post-installation configuration for Archpower
# Based on osl-unmanaged cookbook
# This runs after Packer connects via SSH

set -eux

#
# Install required packages
#
pacman -Syu --noconfirm
pacman -S --noconfirm \
    sudo \
    curl \
    rsync \
    vim \
    chrony \
    postfix \
    fail2ban \
    cloud-init \
    cloud-guest-utils \
    powerpc-utils

#
# SSH Configuration (from osl-unmanaged::ssh)
#
cat >> /etc/ssh/sshd_config <<SSHD
# OSL Unmanaged SSH Configuration
ChallengeResponseAuthentication no
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
ClientAliveInterval 60
GSSAPIAuthentication no
HostKeyAlgorithms +ssh-rsa
KbdInteractiveAuthentication no
KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAcceptedKeyTypes +ssh-rsa
UseDNS no
SSHD

#
# Sudo Configuration (from osl-unmanaged::sudo)
#
mkdir -p /etc/sudoers.d
chmod 750 /etc/sudoers.d
# Remove requiretty if present
sed -i '/requiretty/d' /etc/sudoers
# Ensure includedir is present
grep -q '#includedir /etc/sudoers.d' /etc/sudoers || echo '#includedir /etc/sudoers.d' >> /etc/sudoers

#
# osuadmin user (from osl-unmanaged::osuadmin)
#
useradd -m -d /var/lib/osuadmin -s /bin/bash osuadmin
mkdir -p /var/lib/osuadmin/.ssh
chmod 700 /var/lib/osuadmin/.ssh

# Set osuadmin password from environment variable if provided
if [ -n "${OSUADMIN_PASSWD:-}" ]; then
    usermod -p "${OSUADMIN_PASSWD}" osuadmin
    usermod -p "${OSUADMIN_PASSWD}" root
fi

# Set osuadmin sudoers
echo '%osuadmin ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/osuadmin

# Setup authorized_keys for osuadmin and root
cat > /var/lib/osuadmin/.ssh/authorized_keys <<KEYS
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnBjOARXUzKUzYmdYe2UdpUhoZgG2YeqS2mQF/YgNx7gJJbLn/v8GjV5efDGl0Ad2rW6CO30keN92V6U4oBs2W0+tFNyFScd8NYLPW+ijz7wtAuE4Vf2yJCXa8zFZzi2nTayIekufYsZvk55GhFUav1NFAh7EeQjBnFLck7wlnA6ENCYxIHFFtRRTYv3LCHdvfUtWuKbDim1UWxHufQj1q8ay732nV6RTzVwH4PDDCJjsgxMDcZqfRcRrQE3n98Bzkb/TAG22G3E2KOa+RTtwxRjaMs/ZKA9lV3MjeLUk8SQW9h64hiZB1tl5njVfhC6shtdgKZy/JUiV97IF+2NbBC2LQ/AsGgYUGkPwwR8SiFhzxy5lqrQo9eXVLs6NuM6Q9GdRfOhigxw9ukQPYu29z4Uq4EaWQgtszXmy5hwkPKA1gIEj6ZpYl2y481wGEdXBoK9m1avs0EVlhQ5pXKv1XAn2icqGsaiajSyqNeYRH87q25I+VKJcPCSW7uVDWm+sTFUWe++5hAcHym0QAzmCYwAqYBwdCZl8oepZUA7Szalqxu9Vdka/IjoKiTDJjWf8NWAMs8v6sOvymdzZD4+I3JFkPOrtG3m+Ex6dRB1BQ63Hzmjx+BuiUU95/YsYq5CwGOjkkr+O29HwOBnxfnDqakKULh9H/28Zftco2qUphLQ== osuosl unmanaged
KEYS

chown -R osuadmin:osuadmin /var/lib/osuadmin/.ssh
chmod 600 /var/lib/osuadmin/.ssh/authorized_keys

mkdir -p /root/.ssh
chmod 700 /root/.ssh
cp /var/lib/osuadmin/.ssh/authorized_keys /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

#
# Chrony Configuration (from osl-unmanaged::chrony)
#
grep -q '^port 0' /etc/chrony.conf || echo "port 0" >> /etc/chrony.conf
grep -q '^cmdport 0' /etc/chrony.conf || echo "cmdport 0" >> /etc/chrony.conf
systemctl enable chronyd

#
# Postfix Configuration (from osl-unmanaged::postfix)
#
# Configure postfix for local-only and relay through OSL SMTP
sed -i 's/^inet_interfaces.*/inet_interfaces = loopback-only/' /etc/postfix/main.cf
grep -q '^inet_interfaces' /etc/postfix/main.cf || echo 'inet_interfaces = loopback-only' >> /etc/postfix/main.cf
sed -i '/^relayhost/d' /etc/postfix/main.cf
echo 'relayhost = [smtp.osuosl.org]:25' >> /etc/postfix/main.cf
sed -i '/^myhostname/d' /etc/postfix/main.cf
sed -i '/^mydestination/d' /etc/postfix/main.cf
systemctl enable postfix

#
# Fail2ban Configuration (from osl-unmanaged::fail2ban)
#
cat > /etc/fail2ban/jail.local <<JAIL
[DEFAULT]
ignoreip = jumphost.osuosl.org nagios.osuosl.org nagios2.osuosl.org
findtime = 25d
bantime = 5d
maxretry = 5
destemail = root@osuosl.org
sendername = Fail2Ban
banaction = iptables-multiport
mta = sendmail
protocol = tcp
chain = INPUT

action_ = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
action_mw = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
              %(mta)s-whois[name=%(__name__)s, dest="%(destemail)s", protocol="%(protocol)s", chain="%(chain)s", sendername="%(sendername)s"]
action_mwl = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
               %(mta)s-whois-lines[name=%(__name__)s, dest="%(destemail)s", logpath=%(logpath)s, chain="%(chain)s", sendername="%(sendername)s"]

action = %(action_)s

[sshd]
enabled = true
filter = sshd
JAIL

systemctl enable fail2ban

#
# Cloud-init Configuration (from osl-unmanaged::openstack)
#
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/91_openstack_override.cfg <<CLOUDINIT
---
# Set the hostname in /etc/hosts so sudo doesn't complain
manage_etc_hosts: true
# Force only OpenStack being enabled but allow ConfigDrive and None
datasource_list: [OpenStack, None]
datasource:
  Ec2:
    metadata_urls: ['http://169.254.169.254']
    timeout: 5
    max_wait: 10
users:
  - default
  - name: root
    lock_passwd: true
CLOUDINIT

# Enable cloud-init services
systemctl enable cloud-init-local.service
systemctl enable cloud-init.service
systemctl enable cloud-config.service
systemctl enable cloud-final.service

#
# GRUB Configuration (from osl-unmanaged::openstack)
#
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
# Add console for ppc64le
sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="console=hvc0,115200n8 console=tty0"/' /etc/default/grub

# Regenerate GRUB config
grub-mkconfig -o /boot/grub/grub.cfg
