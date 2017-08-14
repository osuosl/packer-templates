apt-get -y install pump cloud-utils cloud-init cloud-initramfs-growroot \
    bash-completion

# Speed up cloud-init by only using Ec2 and a specific metadata url
cat >> /etc/cloud/cloud.cfg.d/91_Ec2_override.cfg << EOF

# Force only Ec2 being enabled
datasource_list: ['Ec2']
datasource:
  Ec2:
    metadata_urls: [ 'http://169.254.169.254' ]
    timeout: 5 # (defaults to 50 seconds)
    max_wait: 10 # (defaults to 120 seconds)
EOF

# Remove default datasource_list
rm -f /etc/cloud/cloud.cfg.d/90_dpkg.cfg
