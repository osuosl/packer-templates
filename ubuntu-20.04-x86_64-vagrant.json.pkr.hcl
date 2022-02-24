variable "mirror" {
  type    = string
  default = "https://ftp-osl.osuosl.org/pub/ubuntu-releases"
}

source "virtualbox-iso" "ubuntu-2004" {
  guest_os_type         = "Ubuntu_64"
  hard_drive_interface  = "sata"
  boot_command          = [
      " <wait5>",
      "<esc><wait>",
      "<f6><wait>",
      "<esc><wait>",
      "<bs><bs><bs><bs><wait>",
      " autoinstall",
      " ds=nocloud-net",
      ";s=http://{{.HTTPIP}}:{{.HTTPPort}}/ubuntu-20.04/",
      " ---",
      "<enter>"
    ]
  boot_wait             = "5s"
  disk_size             = 65536
  memory                = 2048
  headless              = true
  guest_additions_path  = "VBoxGuestAdditions_{{.Version}}.iso"
  virtualbox_version_file = ".vbox_version"
  http_directory        = "http"
  iso_checksum          = "file:https://ubuntu.osuosl.org/releases/20.04/SHA256SUMS"
  iso_url               = "${var.mirror}/20.04/ubuntu-20.04.3-live-server-amd64.iso"
  output_directory      = "packer-ubuntu-20.04-x86_64-vagrant"
  shutdown_command      = "echo 'vagrant'|sudo -S /sbin/halt -h -p"
  ssh_password          = "vagrant"
  ssh_port              = 22
  ssh_username          = "vagrant"
  ssh_wait_timeout      = "10000s"
  vm_name               = "packer-ubuntu-20.04-x86_64-vagrant"
}

build {
  sources = ["source.virtualbox-iso.ubuntu-2004"]

  provisioner "shell" {
    execute_command = "echo 'vagrant' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    scripts         = [
      "scripts/common/virtualbox.sh",
      "scripts/common/vagrant.sh",
      "scripts/ubuntu/vagrant.sh",
      "scripts/common/minimize.sh"
    ]
  }

  post-processors {
    post-processor "vagrant" {
      keep_input_artifact = true
      provider_override   = "virtualbox"
    }
  }

}
