ppc64le = os.arch == 'ppc64le'
os_family = os.family
kernel_rel = inspec.command('uname -r').stdout
grub_path =
  case os_family
  when 'redhat'
    '/boot/grub2'
  when 'debian'
    '/boot/grub'
  end

control 'powervs' do
  case os_family
  when 'redhat'
    %w(
      cloud-init
      cloud-utils-growpart
      device-mapper-multipath
    ).each do |p|
      describe package p do
        it { should be_installed }
      end
    end

    describe yum.repo 'IBM_Power_Tools' do
      it { should exist }
      it { should be_enabled }
    end

    if ppc64le
      %w(
        devices.chrp.base.ServiceRM
        DynamicRM
        librtas
        powerpc-utils
        rsct.basic
        rsct.core
        rsct.core
        rsct.opt.storagerm
        src
      ).each do |p|
        describe package p do
          it { should be_installed }
        end
      end
    else
      describe package 'pipestat' do
        it { should be_installed }
      end
    end

    describe file '/etc/motd' do
      its('size') { should eq 0 }
    end

    describe file '/boot/grub2/grubenv' do
      if ppc64le
        its('content') { should match /^kernelopts=.*console=tty0 console=hvc0,115200n8 crashkernel=auto rd.shell rd.driver.pre=dm_multipath log_buf_len=1M $/ }
      else
        its('content') { should match /^kernelopts=.*console=tty0 console=ttyS0,115200n8 crashkernel=auto rd.shell rd.driver.pre=dm_multipath log_buf_len=1M $/ }
      end
    end

    describe command 'lsinitrd' do
      its('stdout') { should match %r{Arguments:.*--add 'multipath' --include '/etc/multipath' '/etc/multipath' --include '/etc/multipath.conf' '/etc/multipath.conf'} }
      its('stdout') { should match /^multipath$/ }
      its('stdout') { should match %r{usr/lib/modules/.*/dm-multipath.ko.xz} }
      if ppc64le
        %w(ibmveth ibmvfc ibmvscsi scsi_transport_fc scsi_transport_srp pseries-rng rpaphp rpadlpar_io).each do |m|
          its('stdout') { should match %r{usr/lib/modules/.*/#{m}.ko.xz} }
        end
      end
    end
  when 'debian'
    %w(
      cloud-guest-utils
      cloud-init
      multipath-tools
      multipath-tools-boot
    ).each do |p|
      describe package p do
        it { should be_installed }
      end
    end

    describe apt 'http://ppa.launchpad.net/ibmpackages/rsct/ubuntu' do
      it { should exist }
      it { should be_enabled }
    end

    if ppc64le
      %w(
        devices.chrp.base.servicerm
        dynamicrm
        librtas2
        powerpc-utils
        rsct.basic
        rsct.core
        rsct.core.utils
        rsct.opt.storagerm
        src
      ).each do |p|
        describe package p do
          it { should be_installed }
        end
      end
    end

    describe package "linux-modules-extra-#{kernel_rel}" do
      it { should be_installed }
    end

    describe command 'lsinitramfs /boot/initrd.img' do
      its('stdout') { should match %r{usr/lib/modules/.*/dm-multipath.ko} }
      if ppc64le
        %w(
          ibmveth
          ibmvfc
          ibmvscsi
          pseries-rng
          rpadlpar_io
          rpaphp
          scsi_dh_alua
          scsi_dh_emc
          scsi_dh_rdac
          scsi_transport_fc
        ).each do |m|
          its('stdout') { should match %r{usr/lib/modules/.*/#{m}.ko} }
        end
      end
    end
  end

  describe file '/etc/multipath.conf' do
    its('content') { should match /user_friendly_names yes/ }
    its('content') { should match /polling_interval 10/ }
    its('content') { should match /max_polling_interval 50/ }
    its('content') { should match /reassign_maps yes/ }
    its('content') { should match /failback immediate/ }
    its('content') { should match /rr_min_io 2000/ }
    its('content') { should match /no_path_retry 10/ }
    its('content') { should match /checker_timeout 30/ }
    its('content') { should match /find_multipaths smart/ }
  end

  describe service 'multipathd' do
    it { should be_enabled }
  end

  describe file '/etc/default/grub' do
    its('content') { should match /^GRUB_TIMEOUT=0$/ }
    case os_family
    when 'redhat'
      if ppc64le
        its('content') { should match /^GRUB_CMDLINE_LINUX="console=tty0 console=hvc0,115200n8 crashkernel=auto rd.shell rd.driver.pre=dm_multipath log_buf_len=1M"$/ }
      else
        its('content') { should match /^GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8 crashkernel=auto rd.shell rd.driver.pre=dm_multipath log_buf_len=1M"$/ }
      end
    when 'debian'
      if ppc64le
        its('content') { should match /^GRUB_CMDLINE_LINUX="console=tty0 console=hvc0,115200n8"$/ }
      else
        its('content') { should match /^GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"$/ }
      end
    end
  end

  describe file "#{grub_path}/grub.cfg" do
    its('content') { should match /set timeout=0/ }
    if os_family == 'debian'
      if ppc64le
        its('content') { should match /console=tty0 console=hvc0,115200n8/ }
      else
        its('content') { should match /console=tty0 console=ttyS0,115200n8/ }
      end
    end
  end

  describe file '/etc/cloud/cloud.cfg' do
    its('content') { should match /PowerVC/ }
  end

  describe file '/etc/cloud/ds-identify.cfg' do
    its('content') { should match /policy: search,found=all,maybe=all,notfound=disabled/ }
  end

  %w(
    cloud-init-local
    cloud-init
    cloud-config
    cloud-final
  ).each do |s|
    describe service s do
      it { should be_enabled }
      it { should_not be_running }
    end
  end
end
