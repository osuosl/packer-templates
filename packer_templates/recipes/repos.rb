if platform_family?('rhel')
  execute 'dnf makecache' do
    action :nothing
  end

  execute 'yum makecache' do
    action :nothing
  end

  execute 'import epel key' do
    command "rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-#{node['platform_version'].to_i}"
    action :nothing
  end

  if centos_stream_platform?
    filter_lines '/etc/yum.repos.d/CentOS-Stream-AppStream.repo' do
      filters(
        [
          { comment: [/^mirrorlist.*/, '#', ''] },
          { replace: [/^#baseurl.*/, 'baseurl=https://centos.osuosl.org/$stream/AppStream/$basearch/os/'] },
        ]
      )
      sensitive false
      notifies :run, 'execute[dnf makecache]', :immediately
    end

    filter_lines '/etc/yum.repos.d/CentOS-Stream-BaseOS.repo' do
      filters(
        [
          { comment: [/^mirrorlist.*/, '#', ''] },
          { replace: [/^#baseurl.*/, 'baseurl=https://centos.osuosl.org/$stream/BaseOS/$basearch/os/'] },
        ]
      )
      sensitive false
      notifies :run, 'execute[dnf makecache]', :immediately
    end

    filter_lines '/etc/yum.repos.d/CentOS-Stream-Extras.repo' do
      filters(
        [
          { comment: [/^mirrorlist.*/, '#', ''] },
          { replace: [/^#baseurl.*/, 'baseurl=https://centos.osuosl.org/$stream/extras/$basearch/os/'] },
        ]
      )
      sensitive false
      notifies :run, 'execute[dnf makecache]', :immediately
    end

    filter_lines '/etc/yum.repos.d/CentOS-Stream-HighAvailability.repo' do
      filters(
        [
          { comment: [/^mirrorlist.*/, '#', ''] },
          { replace: [/^#baseurl.*/, 'baseurl=https://centos.osuosl.org/$stream/HighAvailability/$basearch/os/'] },
        ]
      )
      notifies :run, 'execute[dnf makecache]', :immediately
    end

    filter_lines '/etc/yum.repos.d/CentOS-Stream-PowerTools.repo' do
      filters(
        [
          { comment: [/^mirrorlist.*/, '#', ''] },
          { replace: [/^#baseurl.*/, 'baseurl=https://centos.osuosl.org/$stream/PowerTools/$basearch/os/'] },
          { replace: [/^enabled=0$/, 'enabled=1'] },
        ]
      )
      sensitive false
      notifies :run, 'execute[dnf makecache]', :immediately
    end

    filter_lines '/etc/yum.repos.d/CentOS-Stream-RealTime.repo' do
      filters(
        [
          { comment: [/^mirrorlist.*/, '#', ''] },
          { replace: [/^#baseurl.*/, 'baseurl=https://centos.osuosl.org/$stream/RT/$basearch/os/'] },
        ]
      )
      sensitive false
      notifies :run, 'execute[dnf makecache]', :immediately
    end

    filter_lines '/etc/yum.repos.d/CentOS-Stream-ResilientStorage.repo' do
      filters(
        [
          { comment: [/^mirrorlist.*/, '#', ''] },
          { replace: [/^#baseurl.*/, 'baseurl=https://centos.osuosl.org/$stream/ResilientStorage/$basearch/os/'] },
        ]
      )
      sensitive false
      notifies :run, 'execute[dnf makecache]', :immediately
    end

    package %w(epel-release epel-next-release) do
      notifies :run, 'execute[import epel key]', :immediately
    end

    filter_lines '/etc/yum.repos.d/epel.repo' do
      filters(
        [
          { comment: [/^metalink.*repo=epel-\$releasever.*/, '#', ''] },
          { replace: [
              /^#baseurl=.*basearch$/,
              'baseurl=https://epel.osuosl.org/$releasever/Everything/$basearch/',
            ],
          },
        ]
      )
      sensitive false
      notifies :run, 'execute[dnf makecache]', :immediately
    end

    filter_lines '/etc/yum.repos.d/epel-modular.repo' do
      filters(
        [
          { comment: [/^metalink.*repo=epel-modular-\$releasever.*/, '#', ''] },
          { replace: [
              /^#baseurl=.*basearch$/,
              'baseurl=https://epel.osuosl.org/$releasever/Modular/$basearch/',
            ],
          },
        ]
      )
      sensitive false
      notifies :run, 'execute[dnf makecache]', :immediately
    end

    filter_lines '/etc/yum.repos.d/epel-next.repo' do
      filters(
        [
          { comment: [/^metalink.*repo=epel-next-8.*/, '#', ''] },
          { replace: [
              %r{^#baseurl=.*basearch/$},
              'baseurl=https://epel.osuosl.org/next/$releasever/Everything/$basearch/',
            ],
          },
        ]
      )
      sensitive false
      notifies :run, 'execute[dnf makecache]', :immediately
    end
  else
    filter_lines '/etc/yum.repos.d/CentOS-Base.repo' do
      filters(
        [
          { comment: [/^mirrorlist.*repo=os.*/, '#', ''] },
          { replace: [%r{^#baseurl=http://mirror.centos.org/centos/\$releasever/os/\$basearch/}, 'baseurl=https://centos.osuosl.org/$releasever/os/$basearch/'] },
          { comment: [/^mirrorlist.*repo=updates.*/, '#', ''] },
          { replace: [%r{#baseurl=http://mirror.centos.org/centos/\$releasever/updates/\$basearch/}, 'baseurl=https://centos.osuosl.org/$releasever/updates/$basearch/'] },
          { comment: [/^mirrorlist.*repo=extras.*/, '#', ''] },
          { replace: [%r{#baseurl=http://mirror.centos.org/centos/\$releasever/extras/\$basearch/}, 'baseurl=https://centos.osuosl.org/$releasever/extras/$basearch/'] },
        ]
      )
      sensitive false
      notifies :run, 'execute[yum makecache]', :immediately
    end

    package 'epel-release' do
      notifies :run, 'execute[import epel key]', :immediately
    end

    filter_lines '/etc/yum.repos.d/epel.repo' do
      filters(
        [
          { comment: [/^metalink.*repo=epel-7.*/, '#', ''] },
          { replace: [
              /^#baseurl=.*basearch$/,
              'baseurl=https://epel.osuosl.org/$releasever/$basearch/',
            ],
          },
        ]
      )
      sensitive false
      notifies :run, 'execute[yum makecache]', :immediately
    end
  end
elsif platform?('ubuntu')
  # Stop but not disable this service so it doesn't interfer while Chef is running
  service 'unattended-upgrades.service' do
    action :stop
  end

  service 'apt-daily-upgrade.timer' do
    action :stop
  end

  filter_lines '/etc/apt/sources.list' do
    filters(
      [
        { substitute: [
            %r{http://us\.archive\.ubuntu\.com/ubuntu},
            %r{http://us\.archive\.ubuntu\.com/ubuntu},
            'https://ubuntu.osuosl.org/ubuntu',
          ],
        },
      ]
    )
    sensitive false
    notifies :update, 'apt_update[packer]', :immediately
  end

  apt_update 'packer' do
    action :nothing
  end
end
