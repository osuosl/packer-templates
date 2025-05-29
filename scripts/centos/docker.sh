#!/bin/bash -eux
dnf install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
cat <<EOF > /etc/docker/daemon.json
{
  "experimental": true,
  "live-restore": true
}
EOF
systemctl enable docker
