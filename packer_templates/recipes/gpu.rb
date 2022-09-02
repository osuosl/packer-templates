#
# Cookbook:: packer_templates
# Recipe:: gpu
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

driver_version =
  if ENV['NVIDIA_DRIVER_VERSION'].nil?
    'latest'
  else
    ENV['NVIDIA_DRIVER_VERSION']
  end

cuda_version =
  if ENV['CUDA_DRIVER_VERSION'].nil?
    'latest'
  else
    ENV['CUDA_DRIVER_VERSION']
  end

execute 'add cuda repo' do
  command <<~EOF
    dnf config-manager \
      --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/#{node['kernel']['machine']}/cuda-rhel8.repo
    dnf clean all
  EOF
  creates '/etc/yum.repos.d/cuda-rhel8.repo'
  only_if { platform_family?('rhel') && node['platform_version'].to_i == 8 }
end

osl_nvidia_driver driver_version do
  add_repos false
end

osl_cuda cuda_version do
  add_repos false
end
