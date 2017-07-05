#!/bin/bash -eux

echo "UseDNS no" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "GSSAPIAuthentication no" >> /etc/ssh/sshd_config
echo "KbdInteractiveAuthentication no" >> /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication .*/PasswordAuthentication no/Ig' /etc/ssh/sshd_config
sed -i 's/ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/Ig' /etc/ssh/sshd_config
