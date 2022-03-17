apt_update 'chrony'

package 'chrony'

append_if_no_line 'Add port 0' do
  path chrony_conf
  line 'port 0'
  notifies :restart, 'service[chronyd]'
end

append_if_no_line 'Add cmdport 0' do
  path chrony_conf
  line 'cmdport 0'
  notifies :restart, 'service[chronyd]'
end

service 'chronyd' do
  action [:enable, :start]
end
