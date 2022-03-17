package 'sudo'

directory '/etc/sudoers.d' do
  mode '0750'
end

delete_lines 'remove requiretty' do
  path '/etc/sudoers'
  pattern /^.*requiretty/
end

append_if_no_line 'enable includedir' do
  path '/etc/sudoers'
  line '#includedir /etc/sudoers.d'
end
