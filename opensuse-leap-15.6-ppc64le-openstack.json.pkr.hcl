packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "image_name" {
  type    = string
  default = "OpenSUSE Leap 15.6"
}

variable "mirror" {
  type    = string
  default = "http://download.opensuse.org"
}

source "qemu" "opensuse-15" {
  boot_command      = [
    "c<wait5>",
    "linux /boot/ppc64le/linux netsetup=dhcp install=cd:/ ",
    "lang=en_US autoyast=http://{{ .HTTPIP }}:{{ .HTTPPort }}/opensuse-leap-15.6/autoinst.xml ",
    "install=http://download.opensuse.org/ports/ppc/distribution/leap/15.6/repo/oss/ ",
    "textmode=1<enter> ",
    "initrd /boot/ppc64le/initrd<enter> ",
    "boot<enter> "
  ]
  boot_key_interval = "30ms"
  boot_wait         = "6s"
  disk_interface    = "virtio-scsi"
  disk_size         = "4096"
  format           = "raw"
  headless          = true
  http_directory    = "http"
  iso_checksum      = "file:https://download.opensuse.org/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-ppc64le-Media.iso.sha256"
  iso_url           = "${var.mirror}/ports/ppc/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-ppc64le-Media.iso"
  machine_type      = "pseries"
  qemu_binary       = "qemu-kvm"
  qemuargs          = [
    [
        "-m",
        "2048M"
    ],
    [
        "-boot",
        "strict=on"
    ]
  ]
  ssh_password      = "opensuse"
  ssh_port          = 22
  ssh_username      = "root"
  ssh_wait_timeout  = "10000s"
  vnc_bind_address  = "0.0.0.0"
  vnc_port_min      = 5901
  vnc_port_max      = 5901
  vm_name           = "opensuse-leap-15.6"
}

build {
  sources = [
    "source.qemu.opensuse-15"
 ]

  provisioner "shell" {
    execute_command = "{{ .Vars }} sudo -S -E sh '{{ .Path }}'"
    scripts         = [
        "scripts/common/sshd.sh",
        "scripts/opensuse/sudoers.sh",
        "scripts/opensuse/zypper-locks.sh",
        "scripts/opensuse/remove-dvd-source.sh",
        "scripts/opensuse/openstack.sh",
        "scripts/common/minimize.sh"
    ]
  }

}
