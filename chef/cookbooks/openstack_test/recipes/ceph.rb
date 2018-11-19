%w(
  volumes
  images
  backups
  vms
).each do |p|
  ceph_chef_pool p do
    pg_num 32
    pgp_num 32
  end
  execute "rbd pool init #{p}"
end

secrets = openstack_credential_secrets

ceph_chef_client 'glance' do
  caps(
    mon: 'profile rbd',
    osd: 'profile rbd pool=images'
  )
  group 'ceph'
  key secrets['ceph']['image_token']
  keyname 'client.glance'
  filename '/etc/ceph/ceph.client.glance.keyring'
end

ceph_chef_client 'cinder' do
  caps(
    mon: 'profile rbd',
    osd: 'profile rbd pool=volumes, profile rbd pool=vms, profile rbd pool=images'
  )
  group 'ceph'
  key secrets['ceph']['block_token']
  keyname 'client.cinder'
  filename '/etc/ceph/ceph.client.cinder.keyring'
end

ceph_chef_client 'cinder-backup' do
  caps(
    mon: 'profile rbd',
    osd: 'profile rbd pool=backups'
  )
  group 'ceph'
  key secrets['ceph']['block_backup_token']
  keyname 'client.cinder-backup'
  filename '/etc/ceph/ceph.client.cinder-backup.keyring'
end
