variable "mirror" {
  type    = string
  default = "https://ftp-osl.osuosl.org/pub/centos"
}

source "virtualbox-iso" "centos-7" {
  guest_os_type         = "RedHat_64"
  hard_drive_interface  = "sata"
  boot_command          = [
    "<tab> ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos-7/ks-x86_64-vagrant.cfg<enter><wait>"
    ]
  boot_wait             = "10s"
  disk_size             = 65536
  memory                = 2048
  headless              = true
  guest_additions_path  = "VBoxGuestAdditions_{{.Version}}.iso"
  virtualbox_version_file = ".vbox_version"
  http_directory        = "http"
  iso_checksum          = "file:https://centos.osuosl.org/7/isos/x86_64/sha256sum.txt"
  iso_url               = "${var.mirror}/7/isos/x86_64/CentOS-7-x86_64-NetInstall-2009.iso"
  output_directory      = "packer-centos-7-x86_64-vagrant"
  shutdown_command      = "echo 'vagrant'|sudo -S /sbin/halt -h -p"
  ssh_password          = "vagrant"
  ssh_port              = 22
  ssh_username          = "vagrant"
  ssh_wait_timeout      = "10000s"
  vm_name               = "packer-centos-7-x86_64-vagrant"
}

build {
  sources = ["source.virtualbox-iso.centos-7"]

  provisioner "shell" {
    execute_command = "echo 'vagrant' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    scripts         = [
      "scripts/common/virtualbox.sh",
      "scripts/common/vagrant.sh",
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
