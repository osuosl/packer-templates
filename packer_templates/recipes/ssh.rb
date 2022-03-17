packer_sshd_config.each do |key, value|
  replace_or_add key do
    path '/etc/ssh/sshd_config'
    pattern "^#{key}.*"
    line "#{key} #{value}"
    notifies :restart, 'service[sshd]'
  end
end

service 'sshd' do
  action [:enable, :start]
end
