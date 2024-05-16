packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "mirror" {
  type    = string
  default = "http://cvo.almalinux.osuosl.org"
}

variable "osuadmin_passwd" {
  type      = string
  sensitive = true
  default   = "$6$S3y2eCRW3c6SjK/l$ym9rE8J7IZvzkJ5SRMYkxp2PrZ98FNkGy/leHLZU0ATm/yQqCA3l74VNLGdMWKPnhJL4JiB7jBDxj5k3.aZlj1"
}

source "qemu" "almalinux-9" {
  accelerator      = "kvm"
  boot_command     = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz text ",
    "inst.stage2=hd:LABEL=AlmaLinux-9-4-aarch64-dvd ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9/ks-aarch64.cfg<enter>",
    "initrd /images/pxeboot/initrd.img<enter>",
    "boot<enter><wait>"
  ]
  boot_key_interval = "30ms"
  boot_wait        = "10s"
  disk_interface   = "virtio-scsi"
  disk_size        = 4096
  format           = "raw"
  headless         = true
  http_directory   = "http"
  iso_checksum     = "file:https://almalinux.osuosl.org/9/isos/aarch64/CHECKSUM"
  iso_url          = "${var.mirror}/9/isos/aarch64/AlmaLinux-9.4-aarch64-minimal.iso"
  qemu_binary      = "qemu-kvm"
  qemuargs         = [
    [
      "-m",
      "2048M"
    ],
    [
      "-machine",
      "gic-version=max,accel=kvm"
    ],
    [
      "-cpu",
      "host"
    ],
    [
      "-boot",
      "strict=on"
    ],
    [
      "-bios",
      "/usr/share/AAVMF/AAVMF_CODE.fd"
    ],
    [
      "-monitor",
      "none"
    ]
  ]
  shutdown_command = "/sbin/halt -h -p"
  ssh_password     = "osuadmin"
  ssh_port         = 22
  ssh_username     = "root"
  ssh_wait_timeout = "10000s"
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5901
  vnc_port_max     = 5901
  vm_name          = "almalinux-9"
}

build {
  sources = [
    "source.qemu.almalinux-9"
  ]

  provisioner "shell-local" {
    scripts = [
      "scripts/common/berks-vendor.sh"
    ]
  }

  provisioner "shell" {
    execute_command = "{{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    scripts         = [
      "scripts/common/install-cinc.sh"
    ]
  }

  provisioner "file" {
    source = "cookbooks"
    destination = "/tmp/cinc/"
  }

  provisioner "file" {
    source = "chef/client.rb"
    destination = "/tmp/cinc/client.rb"
  }

  provisioner "file" {
    source = "chef/runlist/openstack.json"
    destination = "/tmp/cinc/dna.json"
  }

  provisioner "shell" {
    execute_command = "{{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    environment_vars = [
      "OSUADMIN_PASSWD=${var.osuadmin_passwd}"
    ]
    scripts         = [
      "scripts/common/converge-cinc.sh",
      "scripts/common/remove-cinc.sh",
      "scripts/common/minimize.sh"
    ]
  }
}
