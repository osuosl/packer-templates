include_recipe 'packer_templates::default'

package powervs_pkgs

if platform_family?('rhel')
  remote_file "#{Chef::Config[:file_cache_path]}/ibm-power-repo.rpm" do
    source 'http://public.dhe.ibm.com/software/server/POWER/Linux/yum/download/ibm-power-repo-latest.noarch.rpm'
    not_if { ::File.exist?('/opt/ibm/lop/configure') }
  end

  package 'ibm-power-repo' do
    source "#{Chef::Config[:file_cache_path]}/ibm-power-repo.rpm"
    not_if { ::File.exist?('/opt/ibm/lop/configure') }
  end

  file "#{Chef::Config[:file_cache_path]}/ibm-power-repo.rpm" do
    action :delete
  end

  file '/etc/motd' do
    content ''
  end

  yum_repository 'IBM_Power_Tools' do
    baseurl 'https://public.dhe.ibm.com/software/server/POWER/Linux/yum/OSS/RHEL/$releasever/$basearch'
    gpgkey 'file:///opt/ibm/lop/gpg/RPM-GPG-KEY-ibm-power'
  end
else
  apt_repository 'IBM_Power_Tools' do
    uri 'ppa:ibmpackages/rsct'
  end
end

package ibm_pkgs

package "linux-modules-extra-#{node['kernel']['release']}" if platform_family?('debian')

cookbook_file '/etc/multipath.conf'

service 'multipathd' do
  action :enable
end

replace_or_add 'GRUB_TIMEOUT' do
  path '/etc/default/grub'
  pattern /^GRUB_TIMEOUT.*/
  line 'GRUB_TIMEOUT=0'
  sensitive false
  notifies :run, 'execute[rebuild initramfs]'
end

replace_or_add 'GRUB_CMDLINE_LINUX' do
  path '/etc/default/grub'
  pattern /^GRUB_CMDLINE_LINUX=.*/
  sensitive false
  replace_only true
  line powervs_grub_cmdline
  notifies :run, 'execute[rebuild initramfs]'
end

if platform_family?('rhel')
  file '/etc/dracut.conf.d/10-multipath.conf' do
    content 'force_drivers+=" dm-multipath "'
    notifies :run, 'execute[rebuild initramfs]'
  end

  file '/etc/dracut.conf.d/99-powervm.conf' do
    content "force_drivers+=\" #{powervs_modules.join(' ')} \""
    notifies :run, 'execute[rebuild initramfs]'
    only_if { node['kernel']['machine'] == 'ppc64le' }
  end
elsif platform_family?('debian')
  powervs_modules.each do |m|
    append_if_no_line m do
      path '/etc/initramfs-tools/modules'
      line m
      sensitive false
      notifies :run, 'execute[rebuild initramfs]'
    end
  end

  replace_or_add 'initramfs modules-dep' do
    path '/etc/initramfs-tools/initramfs.conf'
    pattern /^MODULES=.*/
    line 'MODULES=dep'
    sensitive false
    notifies :run, 'execute[rebuild initramfs]'
  end
end

execute 'rebuild initramfs' do
  if platform_family?('rhel')
    command <<~EOF
      dracut --regenerate-all --force
      dracut --kver #{node['kernel']['release']} --force --add multipath \
        --include /etc/multipath /etc/multipath --include /etc/multipath.conf /etc/multipath.conf
      grub2-mkconfig -o /boot/grub2/grub.cfg
    EOF
  else
    command 'update-initramfs -u && update-grub'
  end
  live_stream true
  action :nothing
end

template '/etc/cloud/cloud.cfg'

file '/etc/cloud/ds-identify.cfg' do
  content 'policy: search,found=all,maybe=all,notfound=disabled'
end

%w(
  cloud-init-local
  cloud-init
  cloud-config
  cloud-final
).each do |s|
  service s do
    action [:stop, :enable]
  end
end

include_recipe 'packer_templates::cleanup'
