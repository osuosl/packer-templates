#!/bin/bash -eux

echo "UseDNS no" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "GSSAPIAuthentication no" >> /etc/ssh/sshd_config
sed -i '/KbdInteractiveAuthentication/d; ${p;s/.*/KbdInteractiveAuthentication no/}' /etc/ssh/sshd_config
sed -i '/PermitRootLogin/d; ${p;s/.*/PermitRootLogin no/}' /etc/ssh/sshd_config
sed -i '/ChallengeResponseAuthentication/d; ${p;s/.*/ChallengeResponseAuthentication no/}' /etc/ssh/sshd_config
