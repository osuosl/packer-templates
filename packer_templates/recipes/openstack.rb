#
# Cookbook:: packer_templates
# Recipe:: openstack
#
# Copyright:: 2022, Oregon State University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
apt_update 'openstack' if platform_family?('debian')

include_recipe 'packer_templates::default'

package openstack_pkgs

replace_or_add 'GRUB_TIMEOUT' do
  path '/etc/default/grub'
  pattern /^GRUB_TIMEOUT=.*/
  line 'GRUB_TIMEOUT=0'
  sensitive false
  notifies :run, 'execute[rebuild initramfs]'
end

replace_or_add 'GRUB_CMDLINE_LINUX' do
  path '/etc/default/grub'
  pattern /^GRUB_CMDLINE_LINUX=.*/
  sensitive false
  replace_only true
  line openstack_grub_cmdline
  notifies :run, 'execute[rebuild initramfs]'
end

if platform_family?('rhel')
  replace_or_add 'cloud-user' do
    path '/etc/cloud/cloud.cfg'
    pattern /name: cloud-user$/
    sensitive false
    replace_only true
    line '    name: centos'
  end
elsif platform?('ubuntu')
  replace_or_add 'package_mirrors_primary' do
    path '/etc/cloud/cloud.cfg'
    pattern %r{primary: http://archive.ubuntu.com/ubuntu}
    sensitive false
    replace_only true
    line '         primary: https://ubuntu.osuosl.org/ubuntu'
  end
end

cookbook_file '/etc/cloud/cloud.cfg.d/91_openstack_override.cfg'

execute 'rebuild initramfs' do
  if platform_family?('rhel')
    command openstack_grub_mkconfig
  else
    command 'update-grub'
  end
  live_stream true
  action :nothing
end
