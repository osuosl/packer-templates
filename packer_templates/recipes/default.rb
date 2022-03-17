#
# Cookbook:: packer_templates
# Recipe:: default
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
include_recipe 'packer_templates::repos'
include_recipe 'packer_templates::ssh'
include_recipe 'packer_templates::sudo'
include_recipe 'packer_templates::osuadmin'
include_recipe 'packer_templates::network'
include_recipe 'packer_templates::chrony'

package 'postfix'

replace_or_add 'inet_interfaces' do
  path '/etc/postfix/main.cf'
  pattern /^inet_interfaces/
  line 'inet_interfaces = loopback-only'
  notifies :restart, 'service[postfix]'
end

replace_or_add 'relayhost' do
  path '/etc/postfix/main.cf'
  pattern /^relayhost/
  line 'relayhost = [smtp.osuosl.org]:25'
  notifies :restart, 'service[postfix]'
end

delete_lines 'myhostname' do
  path '/etc/postfix/main.cf'
  pattern /^myhostname/
  notifies :restart, 'service[postfix]'
end

delete_lines 'mydestination' do
  path '/etc/postfix/main.cf'
  pattern /^mydestination/
  notifies :restart, 'service[postfix]'
end

service 'postfix' do
  action [:enable, :start]
end

if platform_family?('rhel')
  node.default['dnf-automatic']['conf']['emitters']['emit_via'] = 'motd'

  include_recipe 'dnf-automatic'
elsif platform_family?('debian')
  filter_lines '/etc/apt/apt.conf.d/50unattended-upgrades' do
    filters(
      [
        { after: [/-infra-security/, "\t\"${distro_id}:${distro_codename}-updates\";"] },
      ]
    )
    sensitive false
  end
end
