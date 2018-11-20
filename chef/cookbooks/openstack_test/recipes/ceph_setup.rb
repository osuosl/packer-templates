cookbook_file '/var/tmp/crush_map_decompressed'

# This allows us to make ceph happy on a single node for testing
execute 'update crush map' do
  cwd '/var/tmp'
  command <<-EOF
    crushtool -c crush_map_decompressed -o new_crush_map_compressed
    ceph osd setcrushmap -i new_crush_map_compressed
  EOF
  creates '/var/tmp/new_crush_map_compressed'
end
