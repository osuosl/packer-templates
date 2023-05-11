variable "mirror" {
  type    = string
  default = "http://packages.osuosl.org/debian/ppc64"
}

variable "osuadmin_passwd" {
  type      = string
  sensitive = true
  default   = "$6$S3y2eCRW3c6SjK/l$ym9rE8J7IZvzkJ5SRMYkxp2PrZ98FNkGy/leHLZU0ATm/yQqCA3l74VNLGdMWKPnhJL4JiB7jBDxj5k3.aZlj1"
}

source "qemu" "debian-sid" {
  accelerator      = "kvm"
  boot_command     = [
      "c<wait>",
      "linux /install/vmlinux",
      " auto",
      " console-setup/ask_detect=false",
      " console-setup/layoutcode=us",
      " console-setup/modelcode=pc105",
      " debconf/frontend=noninteractive",
      " debian-installer=en_US.UTF-8",
      " fb=false",
      " kbd-chooser/method=us",
      " keyboard-configuration/xkb-keymap=us",
      " keyboard-configuration/layout=USA",
      " keyboard-configuration/variant=USA",
      " locale=en_US.UTF-8",
      " netcfg/get_hostname=packer",
      " netcfg/get_domain=local",
      " preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian-sid/preseed-ppc64.cfg",
      " url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian-sid/preseed-ppc64.cfg",
      "<enter><wait>",
      "initrd /install/initrd.gz",
      "<enter><wait>",
      "boot<enter>"
    ]
  boot_key_interval = "10ms"
  boot_wait        = "10s"
  disk_interface   = "virtio-scsi"
  disk_size        = 4096
  format           = "raw"
  headless         = true
  http_directory   = "http"
  iso_checksum     = "file:${var.mirror}/SHA256SUMS"
  iso_url          = "${var.mirror}/mini.iso"
  machine_type     = "pseries"
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
  vm_name          = "debian-sid"
}

build {
  sources = [
    "source.qemu.debian-sid"
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
