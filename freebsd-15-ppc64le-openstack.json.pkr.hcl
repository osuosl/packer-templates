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
  default = "FreeBSD 15.0"
}

variable "mirror" {
  type    = string
  default = "https://download.freebsd.org/snapshots/powerpc/powerpc64/ISO-IMAGES/15.0/"
}

source "qemu" "freebsd-15" {
  boot_command      = []
  boot_key_interval = "30ms"
  boot_wait         = "1s"
  disk_interface    = "virtio-scsi"
  disk_size         = "4096"
  format            = "raw"
  headless          = true
  http_directory    = "http"
  iso_checksum      = "file:${var.mirror}/15.0/CHECKSUM.SHA256-FreeBSD-15.0-CURRENT-powerpc-powerpc64"
  iso_url           = "${var.mirror}/15.0/FreeBSD-15.0-CURRENT-powerpc-powerpc64-disc1.iso"
  machine_type      = "pseries"
  qemu_binary       = "qemu-kvm"
  qemuargs          = [
    [
        "-m",
        "2048M"
    ],
    [
        "-boot",
        "strict=on"
    ]
  ]
  ssh_password      = "freebsd"
  ssh_port          = 22
  ssh_username      = "freebsd"
  ssh_wait_timeout  = "10000s"
  vnc_bind_address  = "0.0.0.0"
  vnc_port_min      = 5901
  vnc_port_max      = 5901
  vm_name           = "freebsd-15"
}

build {
  sources = [
    "source.qemu.freebsd-15"
 ]

  provisioner "shell" {
    execute_command = "echo 'freebsd' | {{.Vars}} su -m root -c 'sh -eux {{.Path}}'"
    scripts         = [
        "scripts/freebsd/update_freebsd.sh",
        "scripts/freebsd/postinstall_freebsd.sh",
        "scripts/freebsd/sudoers_freebsd.sh",
        "scripts/freebsd/cleanup_freebsd.sh",
        "scripts/freebsd/minimize_freebsd.sh",
    ]
  }

}
