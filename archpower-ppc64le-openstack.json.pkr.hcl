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
  default = "https://archlinuxpower.org/iso"
}

variable "osuadmin_passwd" {
  type      = string
  sensitive = true
  default   = "$6$S3y2eCRW3c6SjK/l$ym9rE8J7IZvzkJ5SRMYkxp2PrZ98FNkGy/leHLZU0ATm/yQqCA3l74VNLGdMWKPnhJL4JiB7jBDxj5k3.aZlj1"
}

source "qemu" "archpower" {
  accelerator      = "kvm"
  boot_command     = [
    # Wait for the boot menu and select default
    "<enter><wait60>",
    # Wait for shell prompt after boot, then login as root (no password)
    "root<enter><wait5>",
    # Set up networking (should be auto via DHCP on modern systems)
    "dhcpcd<enter><wait10>",
    # Download and run install script from HTTP server
    "curl -sSfL http://{{ .HTTPIP }}:{{ .HTTPPort }}/archpower/install.sh -o /root/install.sh<enter><wait5>",
    "chmod +x /root/install.sh<enter><wait>",
    "bash /root/install.sh<enter>"
  ]
  boot_key_interval = "30ms"
  boot_wait         = "10s"
  cpus              = 2
  disk_interface    = "virtio-scsi"
  disk_size         = 4096
  format            = "raw"
  headless          = true
  http_directory    = "http"
  iso_checksum      = "none"
  iso_url           = "${var.mirror}/archpower-current-powerpc64le.iso"
  machine_type      = "pseries"
  memory            = 2048
  qemu_binary       = "qemu-kvm"
  qemuargs          = [
    ["-m", "2048M"],
    ["-boot", "strict=on"]
  ]
  shutdown_command  = "/sbin/poweroff"
  ssh_password      = "osuadmin"
  ssh_port          = 22
  ssh_username      = "root"
  ssh_wait_timeout  = "10000s"
  vnc_bind_address  = "0.0.0.0"
  vnc_port_min      = 5901
  vnc_port_max      = 5901
  vm_name           = "archpower"
}

build {
  sources = [
    "source.qemu.archpower"
  ]

  provisioner "shell" {
    execute_command = "{{ .Vars }} bash '{{ .Path }}'"
    environment_vars = [
      "OSUADMIN_PASSWD=${var.osuadmin_passwd}"
    ]
    scripts = [
      "scripts/archpower/postinstall.sh",
      "scripts/archpower/cleanup.sh",
      "scripts/archpower/minimize.sh"
    ]
  }
}
