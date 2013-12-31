#!/bin/sh

if [ -d /var/log/firstboot ] ; then
  # Get user pub key from metadata server
  mkdir -p /root/.ssh
  echo >> /root/.ssh/authorized_keys
  curl -m 10 -s http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key | grep 'ssh-rsa' >> /root/.ssh/authorized_keys
  echo "AUTHORIZED_KEYS:"
  echo "************************"
  cat /root/.ssh/authorized_keys
  echo "************************"
  
  # Set hostname as given by the metadata server
  curl -m 10 http://169.254.169.254/latest/meta-data/public-hostname | grep novalocal > /etc/hostname
  hostname -F /etc/hostname

  # Regenerate host ssh key
  ssh-keygen -A
  /etc/init.d/ssh restart

  # Remove the firstboot marker
  rm -rf /var/log/firstboot
fi
