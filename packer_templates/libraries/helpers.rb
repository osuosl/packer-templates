module PackerTemplates
  module Cookbook
    module Helpers
      def packer_sshd_config
        {
          'ChallengeResponseAuthentication' => 'no',
          'Ciphers' => 'chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr',
          'GSSAPIAuthentication' => 'no',
          'KbdInteractiveAuthentication' => 'no',
          'KexAlgorithms' => 'curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256',
          'PasswordAuthentication' => 'no',
          'PermitRootLogin' => 'no',
          'UseDNS' => 'no',
        }
      end

      def ifcfg_files
        Dir['/etc/sysconfig/network-scripts/ifcfg-*'].reject { |f| File.basename(f).match('ifcfg-lo') }
      end

      def openstack_pkgs
        pkgs = []
        if platform_family?('rhel')
          pkgs = %w(
            cloud-init
            cloud-utils-growpart
            gdisk
          )
          pkgs << 'ppc64-diag' if node['kernel']['machine'] == 'ppc64le'
        else
          pkgs = %w(
            cloud-utils
            cloud-init
            cloud-initramfs-growroot
          )
          pkgs << 'powerpc-utils' if node['kernel']['machine'] == 'ppc64le'
        end
        pkgs.sort
      end

      def powervs_pkgs
        if platform_family?('rhel')
          %w(
            cloud-init
            cloud-utils-growpart
            device-mapper-multipath
          )
        else
          %w(
            cloud-guest-utils
            cloud-init
            multipath-tools
            multipath-tools-boot
          )
        end
      end

      def ibm_pkgs
        if node['kernel']['machine'] == 'ppc64le'
          if platform_family?('rhel')
            %w(
              devices.chrp.base.ServiceRM
              DynamicRM
              librtas
              powerpc-utils
              rsct.basic
              rsct.core
              rsct.opt.storagerm
              src
            )
          else
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
            )
          end
        elsif node['kernel']['machine'] == 'x86_64'
          if platform_family?('rhel')
            'pipestat'
          else
            []
          end
        end
      end

      def openstack_grub_cmdline
        if platform_family?('rhel')
          case node['kernel']['machine']
          when 'ppc64le'
            'GRUB_CMDLINE_LINUX="console=hvc0,115200n8 console=tty0 crashkernel=auto rhgb quiet"'
          else
            'GRUB_CMDLINE_LINUX="console=ttyS0,115200n8 console=tty0 crashkernel=auto rhgb quiet"'
          end
        else
          case node['kernel']['machine']
          when 'ppc64le'
            'GRUB_CMDLINE_LINUX="console=hvc0,115200n8 console=tty0"'
          else
            'GRUB_CMDLINE_LINUX="console=ttyS0,115200n8 console=tty0"'
          end
        end
      end

      def openstack_grub_mkconfig
        if node['kernel']['machine'] == 'aarch64'
          'grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg'
        else
          'grub2-mkconfig -o /boot/grub2/grub.cfg'
        end
      end

      def powervs_grub_cmdline
        if platform_family?('rhel')
          case node['kernel']['machine']
          when 'ppc64le'
            'GRUB_CMDLINE_LINUX="console=tty0 console=hvc0,115200n8 crashkernel=auto rd.shell rd.driver.pre=dm_multipath log_buf_len=1M"'
          else
            'GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8 crashkernel=auto rd.shell rd.driver.pre=dm_multipath log_buf_len=1M"'
          end
        else
          case node['kernel']['machine']
          when 'ppc64le'
            'GRUB_CMDLINE_LINUX="console=tty0 console=hvc0,115200n8"'
          else
            'GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"'
          end
        end
      end

      def powervs_modules
        %w(
          ibmveth
          ibmvfc
          ibmvscsi
          pseries_rng
          rpadlpar_io
          rpaphp
          scsi_dh_alua
          scsi_dh_emc
          scsi_dh_rdac
          scsi_transport_fc
          scsi_transport_srp
        )
      end

      def cleanup_pkgs
        if platform_family?('rhel')
          %w(gcc cpp kernel-devel kernel-headers)
        elsif platform_family?('debian')
          if platform?('ubuntu')
            case node['platform_version']
            when '20.04'
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
              )
            when '22.04'
              %w(
                build-essential
                command-not-found
                fonts-ubuntu-console
                friendly-recovery
                gcc
                g++
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
              )
            end
          end
        end
      end

      def chrony_conf
        if platform_family?('rhel')
          '/etc/chrony.conf'
        else
          '/etc/chrony/chrony.conf'
        end
      end

      def apt_reinstall_pkgs
        require 'mixlib/shellout'

        reinstall_pkgs = Mixlib::ShellOut.new('dpkg-query -S /lib/firmware')
        reinstall_pkgs.run_command
        reinstall_pkgs.error!
        reinstall_pkgs.stdout.gsub(/:.*/, '').split(',')
      end
    end
  end
end
Chef::DSL::Recipe.include ::PackerTemplates::Cookbook::Helpers
Chef::Resource.include ::PackerTemplates::Cookbook::Helpers
