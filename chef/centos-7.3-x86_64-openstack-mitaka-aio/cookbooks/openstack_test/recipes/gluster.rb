include_recipe 'base::glusterfs'
package 'openstack-glance'
package 'glusterfs-server'
service 'glusterd' do
  action [:enable, :start]
end
directory '/data/openstack-glance' do
  user node['openstack']['image']['user']
  group node['openstack']['image']['group']
  recursive true
end
execute 'create gluster glance volume' do
  command <<-EOH
    gluster volume create openstack-glance #{node['openstack_test']['gluster_host']}:/data/openstack-glance force
    gluster volume start openstack-glance
  EOH
  not_if 'gluster volume status openstack-glance'
end

node.default['osl-openstack']['image']['glance_vol'] = "#{node['openstack_test']['gluster_host']}:/openstack-glance"
