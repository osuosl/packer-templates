node.override['osl-docker']['service'] = { misc_opts: '--live-restore' }

chef_gem 'inifile' do
  compile_time true
end

execute 'enable-dummy-nics' do
  command 'modprobe dummy numdummies=1'
end

execute 'create-fake-eth1' do
  command 'ip link set name eth1 dev dummy0'
  not_if 'ip a show dev eth1'
end

execute 'add-ip-192.168.100.1' do
  command 'ip addr add 192.168.100.1/24 dev eth1'
  not_if 'ip a show dev eth1 | grep 192.168.100.1'
end

cookbook_file '/etc/rc.d/rc.local' do
  mode '755'
end

include_recipe 'osl-docker'

docker_image 'osuosl/ceph' do
  action :pull
end

docker_container 'ceph' do
  repo 'osuosl/ceph'
  network_mode 'host'
  restart_policy 'always'
  volumes ['/etc/ceph-docker:/etc/ceph']
  env [
    'MON_IP=192.168.100.1',
    "CEPH_PUBLIC_NETWORK=192.168.100.1/24",
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
    node.default['ceph']['config']['global']['mon host'] = '192.168.100.1:6789'
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
