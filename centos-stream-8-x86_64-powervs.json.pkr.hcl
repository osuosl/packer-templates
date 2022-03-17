source "vagrant" "centos-stream-8" {
  source_path           = "https://ftp.osuosl.org/pub/osl/vagrant/centos-stream-8.box"
  communicator          = "ssh"
  provider              = "virtualbox"
}

source "qemu" "centos-stream-8" {
  accelerator      = "kvm"
  boot_command     = [
    "<tab> text biosdevname=0 net.ifnames=0 ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos-stream-8/ks-x86_64.cfg<enter><wait>"
  ]
  boot_wait        = "10s"
  disk_interface   = "virtio-scsi"
  disk_size        = 4096
  format           = "raw"
  headless         = true
  http_directory   = "http"
  iso_checksum     = "file:https://centos.osuosl.org/8-stream/isos/x86_64/CHECKSUM"
  iso_url          = "${var.mirror}/8-stream/isos/x86_64/CentOS-Stream-8-x86_64-latest-dvd1.iso"
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
}

build {
  sources = [
    "source.vagrant.centos-stream-8",
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
    source = "chef/runlist/powervs.json"
    destination = "/tmp/cinc/dna.json"
  }

  provisioner "shell" {
    execute_command = "{{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    scripts         = [
      "scripts/common/converge-cinc.sh",
      "scripts/common/remove-cinc.sh",
      "scripts/common/minimize.sh"
    ]
  }
}

variable "mirror" {
  type    = string
  default = "https://centos.osuosl.org"
}
