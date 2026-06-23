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
  default = "ArchPOWER ppc64 BE"
}

# ArchPOWER is a rolling release. Pin to a dated ISO snapshot for reproducible
# builds (e.g. "2026.02.01"); "current" tracks the latest rolling ISO.
variable "release" {
  type    = string
  default = "current"
}

# pacman repo base, used by the in-guest installer (powerpc64 = big-endian).
variable "mirror" {
  type    = string
  default = "https://repo.archlinuxpower.org"
}

# Custom ISO = official archpower-<release>-powerpc64.iso with an unattended
# installer baked in, built by bin/remaster_archpower_iso.sh (invoked automatically
# by bin/build_image.sh). QEMU pseries is serial-only (no VGA) so Packer's VNC
# boot_command cannot drive it; the remastered ISO auto-runs the installer at boot,
# so boot_command is empty. See docs/archpower.md. Builds only on a POWER KVM node.
variable "iso_url" {
  type    = string
  default = "iso/archpower-current-powerpc64-custom.iso"
}

# ArchPOWER has NO cloud-init (not packaged), so OpenStack cannot inject an SSH key.
# Seed the arch user with a static ("unmanaged") public key to make the image
# loginnable (sshd is hardened to key-only). Set this in your var-file, e.g.:
#   ssh_authorized_key = "ssh-ed25519 AAAA... osl-archpower-ppc64"
variable "ssh_authorized_key" {
  type    = string
  default = ""
}

source "qemu" "archpower" {
  # POWER is bi-endian: KVM-HV runs this big-endian pseries guest at full speed on a
  # little-endian ppc64le KVM host (same as the centos-7-ppc64 / debian-sid-ppc64 BE
  # templates). The big-endian-ness comes from the booted ISO, not a QEMU flag.
  qemu_binary  = "qemu-kvm"
  machine_type = "pseries"
  accelerator  = "kvm"
  format       = "raw"
  headless     = true

  iso_url      = var.iso_url
  iso_checksum = "none" # locally built; source ISO is gpg-verified during remaster

  disk_interface = "virtio-scsi" # => guest disk /dev/sda
  net_device     = "virtio-net"
  disk_size      = 8192

  boot_command = [] # the remastered ISO auto-runs installerconfig/archpower.install.sh
  qemuargs = [
    ["-m", "2048M"],
    ["-boot", "strict=on"] # CD on first boot only; post-install reboot boots the disk
  ]

  ssh_username     = "root"
  ssh_password     = "osuadmin"
  ssh_port         = 22
  ssh_wait_timeout = "10000s"

  shutdown_command = "/sbin/halt -h -p"

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5901
  vnc_port_max     = 5901
  vm_name          = "archpower-ppc64"
}

build {
  sources = [
    "source.qemu.archpower"
  ]

  provisioner "shell" {
    # Packer connects as root, so no sudo wrapper is needed.
    execute_command  = "{{ .Vars }} bash '{{ .Path }}'"
    environment_vars = ["SSH_AUTHORIZED_KEY=${var.ssh_authorized_key}"]
    scripts = [
      "scripts/common/sshd.sh",
      "scripts/archpower/openstack.sh",
      "scripts/archpower/sudoers.sh",
      "scripts/archpower/seed_ssh_key.sh",
      "scripts/archpower/cleanup.sh",
      "scripts/common/minimize.sh",
    ]
  }
}
