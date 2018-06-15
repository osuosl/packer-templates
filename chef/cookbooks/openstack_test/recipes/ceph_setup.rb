node.override['osl-docker']['service'] = { misc_opts: '--live-restore' }

chef_gem 'inifile' do
  compile_time true
end

include_recipe 'osl-docker'

docker_image 'osuosl/ceph' do
  action :pull
end

ceph_ip =
  if node['ipaddress'] == '10.0.2.15'
    '192.168.60.10'
  else
    node['ipaddress']
  end

ceph_network =
  if node['ipaddress'] == '10.0.2.15'
    '192.168.60.0/24'
  else
    '10.1.100.0/22'
  end

docker_container 'ceph' do
  repo 'osuosl/ceph'
  network_mode 'host'
  volumes ['/etc/ceph-docker:/etc/ceph']
  env [
    "MON_IP=#{ceph_ip}",
    "CEPH_PUBLIC_NETWORK=#{ceph_network}",
    'RGW_CIVETWEB_PORT=8000',
    'RESTAPI_PORT=8001'
  ]
  action :run
end

ruby_block 'save ceph demo secrets' do
  block do
    ceph_chef_save_fsid_secret(ceph_demo_fsid)
    ceph_chef_save_admin_secret(ceph_demo_admin_key)
    ceph_chef_save_mon_secret(ceph_demo_mon_key)
    node.default['ceph']['config']['global']['mon host'] = "#{ceph_ip}:6789"
  end
end

directory '/etc/ceph'

%w(
  ceph.client.admin.keyring
  ceph.mon.keyring
  monmap-ceph
).each do |l|
  link "/etc/ceph/#{l}" do
    to "/etc/ceph-docker/#{l}"
  end
end
