control 'ssh' do
  describe sshd_config do
    its('ChallengeResponseAuthentication') { should cmp 'no' }
    its('Ciphers') do
      should cmp 'chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr'
    end
    its('GSSAPIAuthentication') { should cmp 'no' }
    its('KbdInteractiveAuthentication') { should cmp 'no' }
    its('KexAlgorithms') do
      should cmp 'curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256'
    end
    its('PasswordAuthentication') { should cmp 'no' }
    its('PermitRootLogin') { should cmp 'no' }
    its('UseDNS') { should cmp 'no' }
  end
end
