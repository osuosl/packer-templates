Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host
    Write-Host "ERROR: $_"
    ($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1' | Write-Host
    ($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1' | Write-Host
    Write-Host
    Write-Host 'Sleeping for 60m to give you time to look around the virtual machine before self-destruction...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}

# Last provisioner before sysprep: undo build-only settings that must not ship in the image

Write-Host 'Restoring a system-managed pagefile (cleanup.ps1 dropped it so the zero-fill could reclaim its space)...'
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name PagingFiles -Type MultiString -Value @('?:\pagefile.sys')

Write-Host 'Re-enabling UAC (disabled by Autounattend for the build)...'
$policies = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
Set-ItemProperty -Path $policies -Name EnableLUA -Type DWORD -Value 1
# With UAC on, local admins other than Administrator get a filtered token over WinRM unless this is set
Set-ItemProperty -Path $policies -Name LocalAccountTokenFilterPolicy -Type DWORD -Value 1

Write-Host 'Clearing the Admin autologon left by Autounattend...'
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $winlogon -Name AutoAdminLogon -Type String -Value '0'
@('DefaultPassword', 'AutoLogonCount') | ForEach-Object {
    Remove-ItemProperty -Path $winlogon -Name $_ -ErrorAction SilentlyContinue
}

# Mirrors cloudbase-init's SetSetupComplete.cmd: the service must not start during specialize or it reboots mid-setup
Write-Host 'Setting the cloudbase-init service to manual start; SetupComplete.cmd re-enables it after OOBE...'
Set-Service -Name cloudbase-init -StartupType Manual

Write-Host 'Removing SSH host keys so every instance generates its own on first boot...'
Stop-Service sshd -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\ssh\ssh_host_*" -Force -ErrorAction SilentlyContinue

# Sysprep refuses to run when an Appx package is installed for a user but no longer provisioned
Write-Host 'Removing per-user Appx packages that would block sysprep...'
Get-AppxPackage -AllUsers | Where-Object { -not $_.NonRemovable -and -not $_.IsFramework -and $_.SignatureKind -ne 'System' } | ForEach-Object {
    Write-Host "  $($_.PackageFullName)"
    try {
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
    } catch {
        Write-Host "  WARN failed to remove: $_"
    }
}

Write-Host 'Finalize complete; the template shutdown_command runs sysprep next.'
