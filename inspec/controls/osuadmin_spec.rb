control 'osuadmin' do
  describe user 'osuadmin' do
    it { should exist }
    its('group') { should cmp 'osuadmin' }
    its('shell') { should cmp '/bin/bash' }
  end

  describe directory '/var/lib/osuadmin/.ssh' do
    it { should exist }
    its('mode') { should cmp '0700' }
    its('owner') { should cmp 'osuadmin' }
    its('group') { should cmp 'osuadmin' }
  end

  describe file '/var/lib/osuadmin/.ssh/authorized_keys' do
    it { should exist }
    its('mode') { should cmp '0600' }
    its('owner') { should cmp 'osuadmin' }
    its('group') { should cmp 'osuadmin' }
    its('content') { should match /o2qUphLQ== osuosl unmanaged/ }
  end

  describe command 'sudo -U osuadmin -l' do
    its('stdout') { should match /\(ALL\) NOPASSWD: ALL/ }
  end

  # Root
  describe directory '/root/.ssh' do
    it { should exist }
    its('mode') { should cmp '0700' }
    its('owner') { should cmp 'root' }
    its('group') { should cmp 'root' }
  end

  describe file '/root/.ssh/authorized_keys' do
    it { should exist }
    its('mode') { should cmp '0600' }
    its('owner') { should cmp 'root' }
    its('group') { should cmp 'root' }
    its('content') { should match /o2qUphLQ== osuosl unmanaged/ }
  end
end
