execute 'create-fake-eth1' do
  command <<-EOF
    modprobe dummy
    ip link set name eth1 dev dummy0
  EOF
  not_if 'ip a show dev eth1'
end
