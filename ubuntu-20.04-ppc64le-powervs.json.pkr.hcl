variable "mirror" {
  type    = string
  default = "https://cdimage.ubuntu.com/ubuntu-server/focal/daily-live/current"
}

source "qemu" "ubuntu-2004" {
  accelerator      = "kvm"
  boot_command     = [
      "<wait>",
      "c<enter>",
      "linux /casper/vmlinux quiet",
      " autoinstall",
      " \"ds=nocloud-net",
      ";s=http://{{.HTTPIP}}:{{.HTTPPort}}/ubuntu-20.04/\"",
      " ---",
      "<enter><wait>",
      "initrd /casper/initrd.gz",
      "<enter><wait>",
      "boot<enter><wait>"
    ]
  boot_wait        = "6s"
  disk_interface   = "virtio-scsi"
  disk_size        = 4096
  format           = "raw"
  headless         = true
  http_directory   = "http"
  iso_checksum     = "file:https://cdimage.ubuntu.com/ubuntu-server/focal/daily-live/current/SHA256SUMS"
  iso_url          = "${var.mirror}/focal-live-server-ppc64el.iso"
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

  post-processor "shell-local" {
    environment_vars = [
        "IMAGE_NAME=ubuntu-2004",
        "OS_DESCRIPTION=Ubuntu 20.04",
        "OS_ID=93",
        "OS_TYPE=ubuntu",
        "OUTPUT_DIR=output-ubuntu-2004",
        "TARGET_SIZE=10"
    ]   
    script = "post-processors/ova.sh"
  }
}
