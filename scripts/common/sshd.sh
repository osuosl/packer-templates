#!/bin/bash

SSH_CONFIG=/etc/ssh/sshd_config

# Check if a directive exists:
#   yes: ensure it's correct
#   no: add it to the config
checkDirective() {
  grep -q "^$1" $SSH_CONFIG\
    && sed -i "s/^$1.*/$1 $2/Ig" $SSH_CONFIG\
    || echo "$1 $2" >> $SSH_CONFIG;
}

checkDirective UseDNS no
checkDirective PermitRootLogin no
checkDirective PasswordAuthentication no
checkDirective GSSAPIAuthentication no
checkDirective KbdInteractiveAuthentication no
checkDirective ChallengeResponseAuthentication no

