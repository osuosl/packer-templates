apt-get -y install pump cloud-utils cloud-init cloud-initramfs-growroot \
    bash-completion

# Ignore warning about datasources
mkdir -p /etc/cloud/cloud.cfg.d
cat <<EOF >/etc/cloud/cloud.cfg.d/99-warnings.cfg;
#cloud-config
warnings:
  dsid_missing_source: off
EOF
