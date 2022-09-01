case node['platform_family']
when 'debian'
  apt_update 'network'
  package %w(network-manager isc-dhcp-client)

  filter_lines '/etc/NetworkManager/NetworkManager.conf' do
    filters(
      [
        { after: [/\[main\]$/, 'dhcp=internal'] },
        { after: [/\[main\]$/, 'dns=default'] },
        { after: [/\[main\]$/, 'rc-manager=netconfig'] },
        { after: [/\[main\]$/, 'systemd-resolved=false'] },
        { missing: ["[keyfile]\nunmanaged-devices=interface-name:ibmveth3", :after] },
      ]
    )
    sensitive false
    notifies :restart, 'service[NetworkManager]'
  end

  %w(
    90_dpkg
    99-installer
    curtin-preserve-sources
    subiquity-disable-cloudinit-networking
  ).each do |f|
    file "/etc/cloud/cloud.cfg.d/#{f}.cfg" do
      action :delete
    end
  end

  file '/etc/netplan/00-installer-config.yaml' do
    action :delete
    notifies :restart, 'service[NetworkManager]'
  end

  file '/etc/netplan/01-network-manager.yaml' do
    content <<~EOF
      network:
        version: 2
        renderer: NetworkManager
    EOF
    notifies :restart, 'service[NetworkManager]'
    notifies :run, 'execute[netplan apply]', :immediately
  end

  execute 'netplan apply' do
    command 'netplan generate && netplan apply'
    action :nothing
  end

  replace_or_add 'disable DNSStubListener' do
    path '/etc/systemd/resolved.conf'
    pattern '^#DNSStubListener.*'
    line 'DNSStubListener=no'
    sensitive false
    notifies :restart, 'service[NetworkManager]'
  end

  # https://bugs.launchpad.net/ubuntu/+source/isc-dhcp/+bug/1905800
  filter_lines '/etc/apparmor.d/sbin.dhclient' do
    filters(
      [
        { after: [/# NetworkManager$/, '  /run/NetworkManager/dhclient{,6}-*.pid lrw,'] },
        { after: [/# NetworkManager$/, '  owner /proc/*/task/** rw,'] },
      ]
    )
    sensitive false
    notifies :restart, 'service[NetworkManager]'
    notifies :restart, 'service[systemd-networkd]'
    notifies :reload, 'service[apparmor]', :immediately
  end

  file '/etc/resolv.conf' do
    manage_symlink_source
    only_if { ::File.symlink?('/etc/resolv.conf') }
    notifies :restart, 'service[NetworkManager]', :immediately
    notifies :run, 'execute[nmcli up]', :immediately
    action :delete
  end

  execute 'cloud-init clean' do
    only_if { ::File.exist?('/var/lib/cloud/data/instance-id') }
  end

  execute 'nmcli up' do
    command "nmcli c up #{node['network']['default_interface']}"
    action :nothing
  end

  service 'systemd-resolved.service' do
    action [:stop, :disable]
  end

  service 'NetworkManager' do
    action [:enable, :start]
  end

  service 'apparmor' do
    action :nothing
  end

  service 'systemd-networkd' do
    action :nothing
  end
when 'rhel'
  package 'dhcp-client'

  file '/etc/NetworkManager/conf.d/dhcp.conf' do
    content "[main]\ndhcp=internal\n"
  end
end
