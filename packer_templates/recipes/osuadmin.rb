include_recipe 'packer_templates::sudo'

# OSU Admin user for support
user 'osuadmin' do
  home '/var/lib/osuadmin'
  shell '/bin/bash'
  password node['package_template']['osuadmin']['password']
  manage_home true
  sensitive true
end

directory '/var/lib/osuadmin/.ssh' do
  owner 'osuadmin'
  group 'osuadmin'
  mode '0700'
end

file '/etc/sudoers.d/osuadmin' do
  content '%osuadmin ALL=(ALL) NOPASSWD: ALL'
end

# Setup root user initially with our keys
user 'root' do
  password node['package_template']['osuadmin']['password']
  sensitive true
end

directory '/root/.ssh' do
  mode '0700'
end

cookbook_file '/var/lib/osuadmin/.ssh/authorized_keys' do
  source 'authorized_keys.unmanaged'
  owner 'osuadmin'
  group 'osuadmin'
  mode '0600'
end

cookbook_file '/root/.ssh/authorized_keys' do
  source 'authorized_keys.unmanaged'
  mode '0600'
end
