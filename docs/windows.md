# Windows images

Templates: `windows_2025.pkr.hcl`, `windows_2022.pkr.hcl`, `windows_2019.pkr.hcl`,
`windows_11.pkr.hcl`.
They share `answer_files/<version>/Autounattend.xml` and everything under
`scripts/windows/`.

## Building

```sh
./bin/get_virtio-win-iso.sh          # once, fetches builds/iso/virtio-win.iso
packer init windows_2022.pkr.hcl
packer build windows_2022.pkr.hcl
```

The template's `shutdown_command` runs `sysprep /generalize /oobe /shutdown`
with the shared answer file `answer_files/sysprep/Unattend.xml`. It has to be
the shutdown command rather than a provisioner: once generalize has run, WinRM
refuses to open new shells, but the shell already running sysprep keeps working
long enough to return. After the VM powers off a `shell-local` post-processor
writes a compressed copy:

```
output-windows_2022/windows_2022                  # raw builder output (fully allocated)
output-windows_2022/windows_2022-compressed.qcow2 # upload this one
```

Upload with the qcow2 disk format and the Windows-specific properties:

```sh
./bin/upload.sh -t qcow2 -f output-windows_2022/windows_2022-compressed.qcow2 \
  -n "Windows Server 2022" -o "--property os_type=windows --property os_distro=windows"
```

## Licensing: these are evaluation images

All four templates install from Microsoft's public **evaluation** ISOs with no
product key and activation skipped. Evaluation installs are licensed for 180 days on Server and 90 days on Windows 11.
After that Windows warns, then shuts the VM down every hour. `slmgr /rearm` can
extend the period a limited number of times, but this is not a production license.

To run a deployed instance in production, convert the edition and activate it
against a KMS host (or use a MAK):

```powershell
# Server 2022 Standard (use the matching KMS client key for other editions)
DISM /Online /Set-Edition:ServerStandard /ProductKey:VDYBN-27WPP-V4HQT-9VMD4-VMK7H /AcceptEula
Restart-Computer
slmgr /skms kms.example.org:1688
slmgr /ato
```

The conversion could be baked into the build instead; it was left out on purpose
until a licensing decision is made.

## What happens on first boot of an instance

1. The specialize pass runs cloudbase-init once with its unattend config
   (hostname, MTU, disk extension) and Setup reboots on its exit code. The
   cloudbase-init service is set to manual during the build so it cannot start
   during specialize; a service-driven reboot there breaks Setup with "The
   computer restarted unexpectedly".
2. After OOBE, `C:\Windows\Setup\Scripts\SetupComplete.cmd` removes the
   unencrypted WinRM HTTP listener that the Packer build used, disables its
   firewall rules, then sets the cloudbase-init service back to automatic and
   starts it. It then applies the OpenStack metadata: `Admin` password (retrieve
   with `nova get-password`), SSH public key for `Admin`, and a WinRM HTTPS
   listener on 5986.
3. OpenSSH server starts and generates fresh host keys (the build deletes them).
4. UAC is on and the build-time autologon is gone.

## Installing roles and features later

The build only strips the features listed in `scripts/windows/remove-features.ps1`
and the capabilities in `remove-capabilities.ps1`; everything else keeps its
payload so `Install-WindowsFeature` works offline. `cleanup.ps1` fails the build
if `Containers` or `Microsoft-Hyper-V` lose their payload.

Hyper-V inside an instance additionally needs nested virtualization exposed by
the compute flavor. Windows containers with process isolation do not.

## Debugging a failed build

Run `packer build -on-error=abort windows_2022.pkr.hcl` so a failure keeps the VM
and output directory. The console is on VNC port 5901 (Admin / Admin). A sysprep
failure shows up as "Timeout while waiting for machine to shut down"; the reason
is in `C:\Windows\System32\Sysprep\Panther\setuperr.log` (the MRTGeneralize
"Failed ConnectServer" line there is expected on Server and harmless).

## Known limits

- All provisioned Appx packages are removed during the build (`remove-apps.ps1`)
  and `finalize.ps1` removes the per-user copies so sysprep does not refuse to
  run. On Windows 11 that means no Store, winget, Terminal or Notepad in the
  image; Server 2025/2022/2019 ship no Store apps so they are unaffected.
- Sysprep generalize consumes one rearm, which also restarts the evaluation
  clock on each deployed instance.
- Windows 11 is the Enterprise evaluation; there is no edition conversion path
  without Enterprise volume-license media.
- The Windows Update provisioner runs until no updates remain, so build time
  depends on how far behind the ISO is.
