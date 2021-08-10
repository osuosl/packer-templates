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
checkDirective Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
checkDirective KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com
