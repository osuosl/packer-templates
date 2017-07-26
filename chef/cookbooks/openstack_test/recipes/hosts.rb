hostsfile_entry node['osl-openstack']['bind_service'] do
  hostname 'controller.example.com'
  action :append
end
