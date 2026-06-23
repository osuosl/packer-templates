#!/bin/sh -eux

# Shared by the amd64, arm64 and powerpc64le FreeBSD templates. The pkg-based
# steps (cloud-init + QEMU guest agent) are gated to amd64/arm64: FreeBSD builds
# no official powerpc64le packages, so pkg can't even bootstrap there. powerpc64le
# is a base-only image (ssh + growfs); its login key is seeded by seed_ssh_key.sh.
case "$(uname -m)" in
amd64 | arm64)
  # Base tooling + cloud-init + the QEMU guest agent (images upload with
  # hw_qemu_guest_agent=yes).
  pkg install -y curl ca_root_nss net/cloud-init qemu-guest-agent

  sysrc cloudinit_enable="YES"
  sysrc qemu_guest_agent_enable="YES"
  sysrc qemu_guest_agent_flags="-d -v -l /var/log/qemu-ga.log"

  # OpenStack cloud-init drop-in: ConfigDrive is the reliable path; OpenStack adds
  # the 169.254.169.254 metadata fallback. Root filesystem growth is handled by
  # FreeBSD's native growfs (below), NOT cloud-init growpart/resizefs, which
  # upstream excludes on BSD.
  mkdir -p /usr/local/etc/cloud/cloud.cfg.d
  cat >/usr/local/etc/cloud/cloud.cfg.d/99_openstack.cfg <<'CLOUD_CFG'
datasource_list: [ ConfigDrive, OpenStack, None ]
datasource:
  OpenStack:
    metadata_urls: [ "http://169.254.169.254" ]
    timeout: 10
    retries: 5
    apply_network_config: true
system_info:
  default_user:
    name: freebsd
    lock_passwd: true
    gecos: FreeBSD Default User
    groups: [ wheel ]
    sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
    shell: /bin/sh
  distro: freebsd
disable_root: true
ssh_pwauth: false
preserve_hostname: false
CLOUD_CFG
  ;;
*)
  # powerpc64le: no pkg repo, so no cloud-init / qemu-guest-agent.
  :
  ;;
esac

# Loader settings. NOTE: FreeBSD reads /boot/loader.conf, NOT /etc/loader.conf.
cat >>/boot/loader.conf <<LOADER_CONF
autoboot_delay="-1"
beastie_disable="YES"
loader_logo="none"
hw.memtest.tests="0"
LOADER_CONF

# Serial console so `nova console-log` works -- arch specific.
case "$(uname -m)" in
amd64)
  # x86: serial COM1 + VGA, multiplexed.
  printf 'boot_multicons="YES"\nconsole="comconsole,vidconsole"\ncomconsole_speed="115200"\n' >>/boot/loader.conf
  ;;
arm64)
  # aarch64 (QEMU virt): PL011 UART via ACPI SPCR; no VGA, use the EFI console.
  # comconsole_speed / hw.uart.console are not needed on virt.
  printf 'boot_multicons="YES"\nconsole="comconsole,efi"\n' >>/boot/loader.conf
  ;;
powerpc | *)
  # pseries OF/spapr (hvc0) console is auto-detected; comconsole_* are no-ops.
  :
  ;;
esac

cat >>/etc/make.conf <<MAKE_CONF
WITHOUT_X11="YES"
WITHOUT_GUI="YES"
MAKE_CONF

# OpenStack-relevant services (arch-neutral).
sysrc growfs_enable="YES"
sysrc ifconfig_DEFAULT="SYNCDHCP"
sysrc sshd_enable="YES"
sysrc ntpd_enable="YES"
sysrc ntpd_sync_on_start="YES"
sysrc clear_tmp_enable="YES"
sysrc dumpdev="AUTO"
sysrc sshd_rsa_enable="NO"
sysrc sendmail_enable="NONE"
sysrc sendmail_submit_enable="NO"
sysrc sendmail_outbound_enable="NO"
sysrc sendmail_msp_queue_enable="NO"

# Fast panic-reboot tuning (matches FreeBSD's official openstack.conf).
cat >>/etc/sysctl.conf <<SYSCTL_CONF
debug.trace_on_panic=1
debug.debugger_on_panic=0
kern.panic_reboot_wait_time=0
SYSCTL_CONF

/etc/periodic/weekly/310.locate || true
