platform = os.name
release = os.release
arch = os.arch
kernel_rel = inspec.command('uname -r').stdout

control 'cleanup' do
  # ssh should be the only thing listening
  describe port.where { protocol =~ /tcp/ && port != 22 && process !~ /rmcd/ && address !~ /^127|::1/ } do
    it { should_not be_listening }
  end

  # It's OK if dhclient is listening
  describe port.where { protocol =~ /udp/ && port != 68 && process !~ /dhclient|ntpdate|rmcd/ && address !~ /^127|::1/ } do
    it { should_not be_listening }
  end

  describe service 'rpcbind.socket' do
    it { should_not be_running }
    it { should_not be_enabled }
  end

  describe file '/etc/hosts' do
    it { should_not match /packer/ }
  end

  describe file '/etc/resolv.conf' do
    its('content') { should cmp "\n" }
  end

  case platform
  when 'centos'
    %w(gcc cpp kernel-devel kernel-headers).each do |pkg|
      describe package pkg do
        it { should_not be_installed }
      end
    end

    describe command 'rpm -qa' do
      its('stdout') { should_not match /iwl.*firmware/ }
    end

    describe directory '/etc/udev/rules.d/70-persistent-net.rules' do
      it { should_not exist }
    end

    describe file '/etc/udev/rules.d/70-persistent-net.rules' do
      it { should_not exist }
    end

    ifcfg_files =
      inspec.command('find /etc/sysconfig/network-scripts/ifcfg-*')
            .stdout.split("\n").reject { |f| File.basename(f).match('ifcfg-lo') }

    ifcfg_files.each do |f|
      describe file f do
        its('content') { should_not match /HWADDR/ }
        its('content') { should_not match /UUID/ }
      end
    end

    describe service 'firewalld.service' do
      it { should_not be_running }
      it { should_not be_enabled }
    end

    describe file '/var/cache/dnf/base.solv' do
      it { should_not exist }
    end

    describe file "/var/cache/yum/#{arch}/#{release.to_i}/timedhosts.txt" do
      it { should_not exist }
    end
  when 'ubuntu'
    %w(
      build-essential
      command-not-found
      fonts-ubuntu-console
      fonts-ubuntu-font-family-console
      friendly-recovery
      gcc
      g++
      installation-report
      landscape-common
      laptop-detect
      libc6-dev
      libx11-6
      libx11-data
      libxcb1
      libxext6
      libxmuu1
      make
      popularity-contest
      ppp
      pppconfig
      pppoeconf
      xauth
    ).each do |pkg|
      describe package pkg do
        it { should_not be_installed }
      end
    end

    [
      "linux-headers-#{kernel_rel.gsub('-generic', '')}",
      "linux-headers-#{kernel_rel}",
    ].each do |pkg|
      describe package pkg do
        it { should_not be_installed }
      end
    end

    describe service 'ufw.service' do
      it { should_not be_running }
      it { should_not be_enabled }
    end

    describe command 'apt-get -s autoremove | grep -q REMOVED' do
      its('exit_status') { should eq 1 }
    end

    %w(
      /lib/firmware
      /usr/share/doc/linux-firmware
    ).each do |d|
      describe command "find #{d} -type f" do
        its('exit_status') { should eq 0 }
        its('stdout') { should eq '' }
      end
    end

    describe command 'du -s /var/cache/apt/archives' do
      its('stdout') { should match /^(8|16)/ }
    end
  end
end
