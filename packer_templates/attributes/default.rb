default['packer_templates']['sshd_config'] = {
  'UseDNS' => 'no',
  'PermitRootLogin' => 'no',
  'PasswordAuthentication' => 'no',
  'GSSAPIAuthentication' => 'no',
  'KbdInteractiveAuthentication' => 'no',
  'ChallengeResponseAuthentication' => 'no',
  'Ciphers' => 'chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr',
  'KexAlgorithms' => 'curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256',
}
default['package_template']['osuadmin']['password'] = '$6$S3y2eCRW3c6SjK/l$ym9rE8J7IZvzkJ5SRMYkxp2PrZ98FNkGy/leHLZU0ATm/yQqCA3l74VNLGdMWKPnhJL4JiB7jBDxj5k3.aZlj1'
default['package_template']['clean']['packages'] = true
