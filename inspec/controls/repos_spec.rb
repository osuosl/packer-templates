platform = os.name
release = os.release
arch = os.arch

control 'repos' do
  case platform
  when 'ubuntu'
    case arch
    when 'x86_64'
      describe apt 'https://ubuntu.osuosl.org/ubuntu' do
        it { should exist }
        it { should be_enabled }
      end
    when 'ppc64le'
      describe apt 'http://ports.ubuntu.com/ubuntu-ports/' do
        it { should exist }
        it { should be_enabled }
      end
    end
  when 'centos'
    case release.to_i
    when 8
      describe yum.repo 'appstream' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://centos.osuosl.org/8-stream/AppStream/#{arch}/os/" }
      end

      describe yum.repo 'baseos' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://centos.osuosl.org/8-stream/BaseOS/#{arch}/os/" }
      end

      describe yum.repo 'epel' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://epel.osuosl.org/8/Everything/#{arch}/" }
      end

      describe yum.repo 'epel-modular' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://epel.osuosl.org/8/Modular/#{arch}/" }
      end

      describe yum.repo 'epel-next' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://epel.osuosl.org/next/8/Everything/#{arch}/" }
      end

      describe yum.repo 'extras' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://centos.osuosl.org/8-stream/extras/#{arch}/os/" }
      end

      describe yum.repo 'powertools' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://centos.osuosl.org/8-stream/PowerTools/#{arch}/os/" }
      end
    when 7
      describe yum.repo 'base' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://centos.osuosl.org/7/os/#{arch}/" }
      end

      describe yum.repo 'extras' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://centos.osuosl.org/7/extras/#{arch}/" }
      end

      describe yum.repo 'updates' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://centos.osuosl.org/7/updates/#{arch}/" }
      end

      describe yum.repo 'epel' do
        it { should exist }
        it { should be_enabled }
        its('baseurl') { should cmp "https://epel.osuosl.org/7/#{arch}/" }
      end
    end
  end
end
