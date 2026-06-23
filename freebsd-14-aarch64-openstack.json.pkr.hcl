packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "image_name" {
  type    = string
  default = "FreeBSD 14.4"
}

variable "mirror" {
  type    = string
  default = "https://download.freebsd.org/ftp/releases/arm64/aarch64/ISO-IMAGES"
}

variable "release" {
  type    = string
  default = "14.4"
}

# Custom ISO = official disc1.iso + embedded /etc/installerconfig, built by
# bin/remaster_freebsd_iso.sh (invoked automatically by bin/build_image.sh).
# bsdinstall auto-runs the embedded installerconfig, so boot_command is empty --
# this also sidesteps the arm64 VNC boot_command stall (hashicorp/packer#11061).
# NOTE: aarch64 builds only on a native aarch64 KVM node (needs qemu-system-aarch64
# and /usr/share/AAVMF/*.fd).
variable "iso_url" {
  type    = string
  default = "iso/FreeBSD-14.4-RELEASE-arm64-aarch64-custom.iso"
}

source "qemu" "freebsd-14" {
  accelerator  = "kvm"
  qemu_binary  = "qemu-kvm"
  machine_type = "virt,gic-version=max"
  cpu_model    = "host"
  format       = "raw"
  headless     = true
  memory       = 2048
  cpus         = 2

  efi_boot          = true
  efi_firmware_code = "/usr/share/AAVMF/AAVMF_CODE.fd"
  efi_firmware_vars = "/usr/share/AAVMF/AAVMF_VARS.fd"
  efi_drop_efivars  = true

  iso_url      = var.iso_url
  iso_checksum = "none" # locally built; source ISO is verified during remaster

  disk_interface = "virtio-scsi" # => guest disk da0 (matches OpenStack hw_disk_bus=scsi)
  net_device     = "virtio-net"  # => NIC vtnet0
  disk_size      = 6144

  boot_command = [] # bsdinstall auto-runs the embedded /etc/installerconfig
  qemuargs = [
    ["-boot", "strict=on"], # CD on first boot only; post-install reboot boots the disk
    ["-monitor", "none"]
  ]

  ssh_username     = "freebsd"
  ssh_password     = "freebsd"
  ssh_port         = 22
  ssh_wait_timeout = "10000s"

  shutdown_command = "echo 'freebsd' | su -m root -c 'shutdown -p now'"

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5901
  vnc_port_max     = 5901
  vm_name          = "freebsd-14"
}

build {
  sources = [
    "source.qemu.freebsd-14"
  ]

  provisioner "shell" {
    execute_command = "echo 'freebsd' | {{.Vars}} su -m root -c 'sh -eux {{.Path}}'"
    scripts = [
      "scripts/freebsd/update_freebsd.sh",
      "scripts/freebsd/freebsd_update.sh",
      "scripts/freebsd/postinstall_freebsd.sh",
      "scripts/freebsd/sudoers_freebsd.sh",
      "scripts/freebsd/cleanup_freebsd.sh",
      "scripts/freebsd/minimize_freebsd.sh",
    ]
  }
}
