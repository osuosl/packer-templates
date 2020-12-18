#!/bin/bash -eux
if [ -e /usr/bin/dnf ] ; then
  dnf -y install cloud-init cloud-utils-growpart
else
  yum -y install cloud-init cloud-utils cloud-utils-growpart
fi

# Fix cloud-init on ganeti systems
# https://forums.opensuse.org/showthread.php/531216-Cloud-init-does-not-run?p=2868334#post2868334
systemctl disable cloud-config.service cloud-final.service cloud-init-local.service cloud-init.service
sed -i -e 's/WantedBy=cloud-init.target/WantedBy=multi-user.target/' /usr/lib/systemd/system/cloud-*.service
systemctl daemon-reload
systemctl enable cloud-config.service cloud-final.service cloud-init-local.service cloud-init.service

dracut -f

if [ -e /boot/grub/grub.conf ] ; then
  sed -i -e 's/^timeout=.*/timeout=0/' /boot/grub/grub.conf
  cd /boot
  ln -s boot .
elif [ -e /etc/default/grub ] ; then
  # No timeout for grub menu
  sed -i -e 's/^GRUB_TIMEOUT.*/GRUB_TIMEOUT=0/' /etc/default/grub
  # No fancy boot screen
  grep -q rhgb /etc/default/grub && sed -e 's/rhgb //' /etc/default/grub
  # Write out the config
  grub2-mkconfig -o /boot/grub2/grub.cfg
fi
