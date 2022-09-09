variable "mirror" {
  type    = string
  default = "https://ubuntu.osuosl.org/releases/20.04"
}

variable "osuadmin_passwd" {
  type      = string
  sensitive = true
  default   = "$6$S3y2eCRW3c6SjK/l$ym9rE8J7IZvzkJ5SRMYkxp2PrZ98FNkGy/leHLZU0ATm/yQqCA3l74VNLGdMWKPnhJL4JiB7jBDxj5k3.aZlj1"
}

source "qemu" "ubuntu-2004" {
  accelerator      = "kvm"
  boot_command     = [
      "<esc><wait><enter>",
      "<f6><wait>",
      "<esc><wait>",
      "<bs><bs><bs><bs><bs><wait>",
      " autoinstall",
      " ds=nocloud-net",
      ";s=http://{{.HTTPIP}}:{{.HTTPPort}}/ubuntu-20.04/",
      " ---",
      "<enter><wait5>"
    ]
  boot_wait        = "3s"
  disk_interface   = "virtio-scsi"
  disk_size        = 4096
  format           = "raw"
  headless         = true
  http_directory   = "http"
  iso_checksum     = "file:https://ubuntu.osuosl.org/releases/20.04/SHA256SUMS"
  iso_url          = "${var.mirror}/ubuntu-20.04.5-live-server-amd64.iso"
  qemu_binary      = "qemu-kvm"
  qemuargs         = [
    [
      "-m",
      "2048M"
    ],
    [
      "-boot",
      "strict=on"
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
  vm_name          = "ubuntu-2004"
}

build {
  sources = [
    "source.qemu.ubuntu-2004"
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
    source = "inspec"
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
