variable "mirror" {
  type    = string
  default = "http://centos.osuosl.org"
}

variable "osuadmin_passwd" {
  type      = string
  sensitive = true
  default   = "$6$S3y2eCRW3c6SjK/l$ym9rE8J7IZvzkJ5SRMYkxp2PrZ98FNkGy/leHLZU0ATm/yQqCA3l74VNLGdMWKPnhJL4JiB7jBDxj5k3.aZlj1"
}

source "qemu" "centos-stream-8" {
  accelerator      = "kvm"
  boot_command     = [
    "c<wait5><wait10>",
    "linux /ppc/ppc64/vmlinuz ro ",
    "inst.stage2=hd:LABEL=CentOS-Stream-8-ppc64le-dvd ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos-stream-8/ks-ppc64le.cfg<enter>",
    "initrd /ppc/ppc64/initrd.img<enter>",
    "boot<enter><wait>"
  ]
  boot_wait        = "6s"
  disk_interface   = "virtio-scsi"
  disk_size        = 20480
  format           = "qcow2"
  disk_compression = true
  headless         = true
  http_directory   = "http"
  iso_checksum     = "file:https://centos.osuosl.org/8-stream/isos/ppc64le/CHECKSUM"
  iso_url          = "${var.mirror}/8-stream/isos/ppc64le/CentOS-Stream-8-ppc64le-latest-dvd1.iso"
  machine_type     = "pseries"
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
  vm_name          = "centos-stream-8"
}

build {
  sources = [
    "source.qemu.centos-stream-8"
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
    source = "chef/runlist/gpu.json"
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
