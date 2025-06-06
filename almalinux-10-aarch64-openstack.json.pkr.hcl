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
  default = "http://cvo.almalinux.osuosl.org"
}

variable "osuadmin_passwd" {
  type      = string
  sensitive = true
  default   = "$6$S3y2eCRW3c6SjK/l$ym9rE8J7IZvzkJ5SRMYkxp2PrZ98FNkGy/leHLZU0ATm/yQqCA3l74VNLGdMWKPnhJL4JiB7jBDxj5k3.aZlj1"
}

source "qemu" "almalinux-10" {
  accelerator      = "kvm"
  boot_command     = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff><wait><spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10/ks-aarch64.cfg",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
  boot_key_interval = "30ms"
  boot_wait         = "10s"
  cpus              = 2
  cpu_model         = "host"
  disk_interface    = "virtio-scsi"
  disk_size         = 4096
  efi_boot          = true
  efi_firmware_code = "/usr/share/AAVMF/AAVMF_CODE.fd"
  efi_firmware_vars = "/usr/share/AAVMF/AAVMF_VARS.fd"
  efi_drop_efivars  = true
  format            = "raw"
  headless          = true
  http_directory    = "http"
  iso_checksum      = "file:https://almalinux.osuosl.org/10/isos/aarch64/CHECKSUM"
  iso_url           = "${var.mirror}/10/isos/aarch64/AlmaLinux-10-latest-aarch64-minimal.iso"
  machine_type      = "virt,gic-version=max"
  memory            = 2048
  qemu_binary       = "qemu-kvm"
  qemuargs          = [
    [
      "-boot",
      "strict=on"
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
  vm_name          = "almalinux-10"
}

build {
  sources = [
    "source.qemu.almalinux-10"
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
