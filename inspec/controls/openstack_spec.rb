ppc64le = os.arch == 'ppc64le'
aarch64 = os.arch == 'aarch64'
os_family = os.family
os_name = os.name
grub_path =
  case os_family
  when 'redhat'
    if aarch64
      '/boot/efi/EFI/centos'
    else
      '/boot/grub2'
    end
  when 'debian'
    '/boot/grub'
  end
openstack = input('openstack', value: false)

control 'openstack' do
  only_if { openstack }
  case os_family
  when 'redhat'
    %w(
      cloud-init
      cloud-utils-growpart
      gdisk
    ).each do |p|
      describe package p do
        it { should be_installed }
      end
    end

    describe package 'ppc64-diag' do
      it { should be_installed }
    end if ppc64le

    describe file '/boot/grub2/grubenv' do
      if ppc64le
        its('content') { should match /^kernelopts=.* console=hvc0,115200n8 console=tty0 crashkernel=auto rhgb quiet $/ }
      else
        its('content') { should match /^kernelopts=.* console=ttyS0,115200n8 console=tty0 crashkernel=auto rhgb quiet $/ }
      end
    end

  when 'debian'
    %w(
      cloud-utils
      cloud-init
      cloud-initramfs-growroot
    ).each do |p|
      describe package p do
        it { should be_installed }
      end
    end

    describe package 'powerpc-utils' do
      it { should be_installed }
    end if ppc64le
  end

  describe file '/etc/default/grub' do
    its('content') { should match /^GRUB_TIMEOUT=0$/ }
    case os_family
    when 'redhat'
      if ppc64le
        its('content') { should match /^GRUB_CMDLINE_LINUX="console=hvc0,115200n8 console=tty0 crashkernel=auto rhgb quiet"$/ }
      else
        its('content') { should match /GRUB_CMDLINE_LINUX="console=ttyS0,115200n8 console=tty0 crashkernel=auto rhgb quiet"$/ }
      end
    when 'debian'
      if ppc64le
        its('content') { should match /^GRUB_CMDLINE_LINUX="console=hvc0,115200n8 console=tty0"$/ }
      else
        its('content') { should match /^GRUB_CMDLINE_LINUX="console=ttyS0,115200n8 console=tty0"$/ }
      end
    end
  end

  describe file "#{grub_path}/grub.cfg" do
    its('content') { should match /set timeout=0/ }
    if os_family == 'debian'
      if ppc64le
        its('content') { should match /console=hvc0,115200n8 console=tty0/ }
      else
        its('content') { should match /console=ttyS0,115200n8 console=tty0/ }
      end
    end
  end

  describe file '/etc/cloud/cloud.cfg' do
    case os_name
    when 'centos'
      its('content') { should_not match /name: cloud-user/ }
      its('content') { should match /name: centos/ }
    when 'ubuntu'
      its('content') { should match %r{primary: https://ubuntu.osuosl.org/ubuntu} }
    end
  end

  describe file '/etc/cloud/cloud.cfg.d/91_openstack_override.cfg' do
    its('content') { should match /datasource_list: \['OpenStack'\]/ }
    its('content') { should match %r{metadata_urls: \[ 'http://169.254.169.254' \]} }
  end

  %w(
    cloud-init-local
    cloud-init
    cloud-config
    cloud-final
  ).each do |s|
    describe service s do
      it { should be_enabled }
      it { should_not be_running } unless os.name == 'ubuntu'
    end
  end
end
