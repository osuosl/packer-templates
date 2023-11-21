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

source "qemu" "almalinux-9-ganeti" {
  accelerator      = "kvm"
  boot_command     = [
    "<tab> text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9/ks-x86_64-ganeti.cfg<enter><wait>"
  ]
  boot_key_interval = "10ms"
  boot_wait        = "10s"
  cpu_model        = "host"
  disk_compression = true
  disk_interface   = "virtio-scsi"
  disk_size        = 5120
  format           = "qcow2"
  headless         = true
  http_directory   = "http"
  iso_checksum     = "file:https://almalinux.osuosl.org/9/isos/x86_64/CHECKSUM"
  iso_url          = "${var.mirror}/8/isos/x86_64/AlmaLinux-9-latest-x86_64-minimal.iso"
  qemu_binary      = "qemu-kvm"
  qemuargs         = [
    [
        "-m",
        "2048M"
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
  vm_name          = "almalinux-9-ganeti"
}

build {
  sources = [
    "source.qemu.almalinux-9-ganeti"
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
