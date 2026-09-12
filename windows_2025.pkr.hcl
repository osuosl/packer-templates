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
  # Evaluation media: see docs/windows.md for the 180-day licensing caveat
  # Download url's found at https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025
  default = "https://software-static.download.prss.microsoft.com/dbazure/998969d5-f34g-4e03-ac9d-1f9786c66749/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
}

variable "winrm_timeout" {
  type    = string
  default = "6h"
}

locals {
  iso_target_path = "${path.root}/builds/iso/windows-2025-${substr(sha256(var.iso_url), 0, 8)}.iso"
}

source "qemu" "windows_2025" {
  accelerator       = "kvm"
  boot_wait         = "10s"
  cpus              = 4
  cpu_model         = "host"
  communicator      = "winrm"
  disk_interface    = "virtio-scsi"
  disk_size         = "${var.disk_size}"
  floppy_files          = [
    "answer_files/2025/Autounattend.xml",
    "scripts/windows/install_virtio_drivers.ps1",
  ]
  format            = "qcow2"
  iso_checksum      = "7b052573ba7894c9924e3e87ba732ccd354d18cb75a883efa9b900ea125bfd51"
  iso_url           = "${var.iso_url}"
  iso_target_path   = local.iso_target_path
  memory            = 8192
  output_directory  = "output-windows_2025"
  qemu_binary       = "qemu-kvm"
  qemuargs          = [
    ["-device", "qemu-xhci"],
    ["-device", "virtio-tablet"],
    ["-drive", "file=builds/iso/virtio-win.iso,media=cdrom,index=3"],
    ["-drive", "file=${abspath(local.iso_target_path)},media=cdrom,index=2"],
    ["-drive", "file=output-{{ .Name }}/{{ .Name }},if=virtio,cache=writeback,discard=ignore,format=qcow2,index=1"],
    ["-boot", "order=c,order=d"]
  ]
  # Sysprep must be the last WinRM command: after generalize WinRM refuses new shells, but the one running sysprep keeps working
  shutdown_command  = "C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /oobe /shutdown /quiet /unattend:C:\\Windows\\Setup\\Scripts\\sysprep-unattend.xml"
  shutdown_timeout  = "30m"
  vm_name           = "windows_2025"
  headless          = true
  vnc_port_min      = 5901
  vnc_port_max      = 5901
  vnc_bind_address  = "0.0.0.0"
  winrm_password    = "Admin"
  winrm_timeout     = "${var.winrm_timeout}"
  winrm_username    = "Admin"
}

build {
  sources = ["source.qemu.windows_2025"]

  # Initial provisioning only — no component store modifications before updates
  provisioner "powershell" {
    elevated_password = "Admin"
    elevated_user     = "Admin"
    scripts = [
      "scripts/windows/provision.ps1",
    ]
  }
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }
  # Clear Windows Update download cache before patching
  provisioner "powershell" {
    elevated_password = "Admin"
    elevated_user     = "Admin"
    inline = [
      "Write-Host 'Clearing Windows Update cache...'",
      "Stop-Service wuauserv -Force",
      "Stop-Service bits -Force",
      "Remove-Item -Path C:\\Windows\\SoftwareDistribution\\Download\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Start-Service bits",
      "Start-Service wuauserv",
    ]
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
  # All component store modifications AFTER updates to avoid corrupting WinSxS
  provisioner "powershell" {
    elevated_password = "Admin"
    elevated_user     = "Admin"
    scripts = [
      "scripts/windows/remove-one-drive-and-teams.ps1",
      "scripts/windows/remove-apps.ps1",
      "scripts/windows/remove-capabilities.ps1",
      "scripts/windows/remove-features.ps1",
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
    ]
  }
  # Reboot so the pagefile dropped by cleanup.ps1 is gone before optimize.ps1 zero-fills
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }
  # Hardens WinRM on the first boot of each deployed instance (see the script header)
  provisioner "file" {
    source      = "scripts/windows/SetupComplete.cmd"
    destination = "C:\\Windows\\Setup\\Scripts\\SetupComplete.cmd"
  }
  # Shared sysprep answer file used by the shutdown_command
  provisioner "file" {
    source      = "answer_files/sysprep/Unattend.xml"
    destination = "C:\\Windows\\Setup\\Scripts\\sysprep-unattend.xml"
  }
  provisioner "powershell" {
    elevated_password = "Admin"
    elevated_user     = "Admin"
    scripts = [
      "scripts/windows/optimize.ps1",
      "scripts/windows/finalize.ps1",
    ]
  }

  post-processor "shell-local" {
    inline = ["qemu-img convert -O qcow2 -c output-windows_2025/windows_2025 output-windows_2025/windows_2025-compressed.qcow2"]
  }
}
