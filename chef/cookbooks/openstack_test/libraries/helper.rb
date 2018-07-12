def ceph_demo_fsid
  require 'inifile'
  wait_for_file('/etc/ceph-docker/ceph.conf')
  ceph_conf = IniFile.load('/etc/ceph-docker/ceph.conf')
  ceph_conf['global']['fsid']
end

def ceph_demo_admin_key
  require 'inifile'
  wait_for_file('/etc/ceph-docker/ceph.client.admin.keyring')
  admin_client = IniFile.load('/etc/ceph-docker/ceph.client.admin.keyring')
  admin_client['client.admin']['key']
end

def ceph_demo_mon_key
  require 'inifile'
  wait_for_file('/etc/ceph-docker/ceph.mon.keyring')
  mon_client = IniFile.load('/etc/ceph-docker/ceph.mon.keyring')
  mon_client['mon.']['key']
end

def wait_for_file(file)
  sleep(1) until File.exist?(file)
end
