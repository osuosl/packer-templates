#!/bin/bash -eux

grep -q "^UseDNS" /etc/ssh/sshd_config\
  && sed -i 's/UseDNS .*/UseDNS no/Ig' /etc/ssh/sshd_config\
  || echo "UseDNS no" >> /etc/ssh/sshd_config;

grep -q "^PermitRootLogin" /etc/ssh/sshd_config\
  && sed -i 's/PermitRootLogin .*/PermitRootLogin no/Ig' /etc/ssh/sshd_config\
  || echo "PermitRootLogin no" >> /etc/ssh/sshd_config;

grep -q "^GSSAPIAuthentication" /etc/ssh/sshd_config\
  && sed -i 's/GSSAPIAuthentication .*/GSSAPIAuthentication no/Ig' /etc/ssh/sshd_config\
  || echo "GSSAPIAuthentication no" >> /etc/ssh/sshd_config;

grep -q "^KbdInteractiveAuthentication" /etc/ssh/sshd_config\
  && sed -i 's/KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/Ig' /etc/ssh/sshd_config\
  || echo "KbdInteractiveAuthentication no" >> /etc/ssh/sshd_config;

grep -q "^ChallengeResponseAuthentication" /etc/ssh/sshd_config\
  && sed -i 's/ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/Ig' /etc/ssh/sshd_config\
  || echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config;
