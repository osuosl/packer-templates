variable "mirror" {
  type    = string
  default = "http://debian.osuosl.org/debian-cdimage"
}

variable "release" {
  type    = string
  default = "12.9.0"
}

variable "osuadmin_passwd" {
  type      = string
  sensitive = true
  default   = "$6$S3y2eCRW3c6SjK/l$ym9rE8J7IZvzkJ5SRMYkxp2PrZ98FNkGy/leHLZU0ATm/yQqCA3l74VNLGdMWKPnhJL4JiB7jBDxj5k3.aZlj1"
}

source "qemu" "debian-12" {
  accelerator      = "kvm"
  boot_command     = [
      "<esc><wait>",
      "install",
      " auto",
      " console-keymaps-at/keymap=us",
      " console-setup/ask_detect=false",
      " debconf/frontend=noninteractive",
      " debian-installer=en_US.UTF-8",
      " fb=false",
      " grub-installer/bootdev=/dev/sda",
      " kbd-chooser/method=us",
      " keyboard-configuration/xkb-keymap=us",
      " locale=en_US.UTF-8",
      " netcfg/get_domain=local",
      " netcfg/get_hostname=packer",
      " preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian-12/preseed.cfg",
      " url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian-12/preseed.cfg",
      "<enter>"
    ]
  boot_key_interval = "30ms"
  boot_wait        = "5s"
  disk_interface   = "virtio-scsi"
  disk_size        = 4096
  format           = "raw"
  headless         = true
  http_directory   = "http"
  iso_checksum     = "file:${var.mirror}/${var.release}/amd64/iso-cd/SHA256SUMS"
  iso_url          = "${var.mirror}/${var.release}/amd64/iso-cd/debian-${var.release}-amd64-netinst.iso"
  qemu_binary      = "qemu-kvm"
  qemuargs         = [
    [ "-m", "2048M" ],
    [ "-boot", "strict=on" ]
  ]
  shutdown_command = "/sbin/halt -h -p"
  ssh_password     = "osuadmin"
  ssh_port         = 22
  ssh_username     = "root"
  ssh_wait_timeout = "10000s"
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5901
  vnc_port_max     = 5901
  vm_name          = "debian-12"
}

build {
  sources = [
    "source.qemu.debian-12"
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
