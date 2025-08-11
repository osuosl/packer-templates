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

Write-Output "Searching for virtio-win-gt-x64.msi on all drives..."

$msi = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    Get-ChildItem -Path "$($_.Root)" -Recurse -ErrorAction SilentlyContinue -Include virtio-win-gt-x64.msi
} | Select-Object -First 1

if ($msi) {
    Write-Output "Found installer at $($msi.FullName)"
    Start-Process msiexec.exe -ArgumentList "/i `"$($msi.FullName)`" /qn /norestart" -Wait -PassThru | Out-Null
    Write-Output "VirtIO guest tools installation completed."

    # Enable QEMU Guest Agent if it exists
    Try {
        Set-Service -Name qemu-ga -StartupType Automatic -ErrorAction Stop
        Start-Service qemu-ga
        Write-Output "QEMU Guest Agent service enabled."
    }
    Catch {
        Write-Output "QEMU Guest Agent service not found (may be normal depending on ISO version)."
    }
} else {
    Write-Output "ERROR: virtio-win-gt-x64.msi not found on any attached drive."
    Exit 1
}
