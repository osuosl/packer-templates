platform = os.name
release = os.release

control 'default' do
  describe service 'postfix' do
    it { should be_enabled }
    it { should be_running }
  end

  describe port 25 do
    it { should be_listening }
    its('addresses') { should_not include '0.0.0.0' }
    its('addresses') { should_not include '::' }
    its('addresses') { should include '127.0.0.1' }
    its('addresses') { should include '::1' }
  end

  describe postfix_conf do
    its('inet_interfaces') { should cmp 'loopback-only' }
    its('relayhost') { should cmp '[smtp.osuosl.org]:25' }
  end

  case platform
  when 'centos'
    case release.to_i
    when 8
      describe service 'dnf-automatic.timer' do
        it { should be_enabled }
        it { should be_running }
      end

      describe ini '/etc/dnf/automatic.conf' do
        its('emitters.emit_via') { should cmp 'motd' }
      end
    when 7
      describe service 'yum-cron' do
        it { should be_enabled }
        it { should be_running }
      end
    end
  end
end
