packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.2"
    }
  }
}

variable "mirror" {
  type    = string
  default = "https://centos-stream.osuosl.org"
}

variable "release" {
  type    = string
  default = "latest"
}

variable "osuadmin_passwd" {
  type      = string
  sensitive = true
  default   = "$6$S3y2eCRW3c6SjK/l$ym9rE8J7IZvzkJ5SRMYkxp2PrZ98FNkGy/leHLZU0ATm/yQqCA3l74VNLGdMWKPnhJL4JiB7jBDxj5k3.aZlj1"
}

source "qemu" "centos-stream-10" {
  accelerator      = "kvm"
  boot_command     = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff><wait><spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos-stream-10/ks-ppc64le.cfg",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
  boot_key_interval = "30ms"
  boot_wait         = "6s"
  cpus              = 2
  disk_interface    = "virtio-scsi"
  disk_size         = 4096
  format            = "raw"
  headless          = true
  http_directory    = "http"
  iso_checksum      = "file:https://centos-stream.osuosl.org/10-stream/BaseOS/ppc64le/iso/SHA256SUM"
  iso_url           = "${var.mirror}/10-stream/BaseOS/ppc64le/iso/CentOS-Stream-10-${var.release}-ppc64le-boot.iso"
  machine_type      = "pseries"
  memory            = 2048
  qemu_binary       = "qemu-kvm"
  shutdown_command  = "/sbin/halt -h -p"
  ssh_password      = "osuadmin"
  ssh_port          = 22
  ssh_username      = "root"
  ssh_wait_timeout  = "10000s"
  vnc_bind_address  = "0.0.0.0"
  vnc_port_min      = 5901
  vnc_port_max      = 5901
  vm_name           = "centos-stream-10"
}

build {
  sources = [
    "source.qemu.centos-stream-10"
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
