control 'sudo' do
  describe package 'sudo' do
    it { should be_installed }
  end

  describe directory '/etc/sudoers.d' do
    it { should exist }
    its('mode') { should cmp '0750' }
    its('owner') { should cmp 'root' }
    its('group') { should cmp 'root' }
  end

  describe file '/etc/sudoers' do
    its('content') { should_not match /requiretty/ }
    its('content') { should match %r{^#includedir /etc/sudoers\.d$} }
  end

  describe command 'sudo -l' do
    its('stdout') { should_not match /requiretty/ }
  end
end
