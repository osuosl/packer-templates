packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
    windows-update = {
      version = ">= 0.14.1"
      source  = "github.com/rgl/windows-update"
    }
  }
}

variable "disk_size" {
  type    = string
  default = "51200"
}

variable "iso_url" {
  type    = string
  # Download url's found at https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise
  default = "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1742.240906-0331.ge_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso"
}

variable "winrm_timeout" {
  type    = string
  default = "6h"
}

locals {
  iso_target_path = "${path.root}/builds/iso/windows-11-${substr(sha256(var.iso_url), 0, 8)}.iso"
}

source "qemu" "windows_11" {
  accelerator       = "kvm"
  boot_wait         = "10s"
  cpus              = 4
  cpu_model         = "host"
  communicator      = "winrm"
  disk_interface    = "virtio-scsi"
  disk_size         = "${var.disk_size}"
  floppy_files          = [
    "answer_files/11/Autounattend.xml",
    "scripts/windows/install_virtio_drivers.ps1",
  ]
  format            = "qcow2"
  iso_checksum      = "755A90D43E826A74B9E1932A34788B898E028272439B777E5593DEE8D53622AE"
  iso_url           = "${var.iso_url}"
  iso_target_path   = local.iso_target_path
  memory            = 8192
  output_directory  = "output-windows_11"
  qemu_binary       = "qemu-kvm"
  qemuargs          = [
    ["-device", "qemu-xhci"],
    ["-device", "virtio-tablet"],
    ["-drive", "file=builds/iso/virtio-win.iso,media=cdrom,index=3"],
    ["-drive", "file=${abspath(local.iso_target_path)},media=cdrom,index=2"],
    ["-drive", "file=output-{{ .Name }}/{{ .Name }},if=virtio,cache=writeback,discard=ignore,format=qcow2,index=1"],
    ["-boot", "order=c,order=d"]
  ]
  shutdown_command  = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""
  shutdown_timeout  = "15m"
  vm_name           = "windows_11"
  headless          = true
  vnc_port_min      = 5901
  vnc_port_max      = 5901
  vnc_bind_address  = "0.0.0.0"
  winrm_password    = "Admin"
  winrm_timeout     = "${var.winrm_timeout}"
  winrm_username    = "Admin"
}

build {
  sources = ["source.qemu.windows_11"]

  # Windows Updates and scripts
  provisioner "powershell" {
    elevated_password = "Admin"
    elevated_user     = "Admin"
    scripts = [
      "scripts/windows/provision.ps1",
      "scripts/windows/remove-one-drive-and-teams.ps1",
      "scripts/windows/remove-apps.ps1",
      "scripts/windows/remove-capabilities.ps1",
      "scripts/windows/remove-features.ps1",
    ]
  }
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0 and IsHidden=0 and BrowseOnly=0 and AutoSelectOnWebSites=1"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
  }
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }
  provisioner "powershell" {
    elevated_password = "Admin"
    elevated_user     = "Admin"
    scripts           = [
      "scripts/windows/configure-power.ps1",
      "scripts/windows/disable-system-restore.ps1",
      "scripts/windows/disable-screensaver.ps1",
      "scripts/windows/ui-tweaks.ps1",
      "scripts/windows/install_openssh.ps1",
      "scripts/windows/enable-remote-desktop.ps1",
      "scripts/windows/eject-media.ps1"
    ]
  }
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }
  provisioner "powershell" {
    elevated_password = "Admin"
    elevated_user     = "Admin"
    scripts = [
      "scripts/windows/install_cloudbase_init.ps1",
      "scripts/windows/cleanup.ps1",
      "scripts/windows/optimize.ps1"
    ]
  }
}
