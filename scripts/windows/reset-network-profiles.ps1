# Clean up network connection registry entries from the build-time NIC so
# that the first NIC on a newly deployed VM gets assigned "Ethernet" (#1)
# instead of "Ethernet 2".
#
# During the Packer build the QEMU virtio NIC is still active (WinRM uses
# it), so it is NOT a ghost device yet.  Instead we remove the registry
# entries Windows consults when naming a newly enumerated adapter.  The
# running network stack is already loaded in memory and is unaffected.

Write-Host "Cleaning network connection registry entries..."

# 1. Remove per-connection profiles under the Network class key.
#    Windows checks these names when assigning "Ethernet", "Ethernet 2", etc.
$netConfigKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Network\{4D36E972-E325-11CE-BFC1-08002BE10318}"
if (Test-Path $netConfigKey) {
    $subkeys = Get-ChildItem -Path $netConfigKey -ErrorAction SilentlyContinue
    foreach ($subkey in $subkeys) {
        # Skip the "Descriptions" subkey — only remove per-connection entries
        if ($subkey.PSChildName -eq "Descriptions") { continue }
        $connPath = Join-Path $subkey.PSPath "Connection"
        if (Test-Path $connPath) {
            $name = (Get-ItemProperty -Path $connPath -Name "Name" -ErrorAction SilentlyContinue).Name
            Write-Host "  Removing network connection profile: $name [$($subkey.PSChildName)]"
            Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 2. Remove cached network list profiles (the "Unidentified network" etc. entries).
$netListProfiles = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles"
if (Test-Path $netListProfiles) {
    $profiles = Get-ChildItem -Path $netListProfiles -ErrorAction SilentlyContinue
    foreach ($profile in $profiles) {
        $desc = (Get-ItemProperty -Path $profile.PSPath -Name "Description" -ErrorAction SilentlyContinue).Description
        Write-Host "  Removing network list profile: $desc [$($profile.PSChildName)]"
        Remove-Item -Path $profile.PSPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 3. Remove network list signatures so the new NIC is not matched to old profiles.
$netListSigs = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures"
if (Test-Path $netListSigs) {
    Get-ChildItem -Path $netListSigs -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
            Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    Write-Host "  Cleared network list signatures."
}

Write-Host "Network connection cleanup complete."
