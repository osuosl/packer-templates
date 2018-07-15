apt-get -y install pump cloud-utils cloud-init cloud-initramfs-growroot \
    bash-completion

# Speed up cloud-init by only using OpenStack and a specific metadata url
cat >> /etc/cloud/cloud.cfg.d/91_openstack_override.cfg << EOF
# Set the hostname in /etc/hosts so sudo doesn't complain
manage_etc_hosts: true
# Force only OpenStack being enabled
datasource_list: ['OpenStack']
datasource:
  Ec2:
    metadata_urls: [ 'http://169.254.169.254' ]
    timeout: 5
    max_wait: 10
EOF

# Remove default datasource_list
rm -f /etc/cloud/cloud.cfg.d/90_dpkg.cfg
