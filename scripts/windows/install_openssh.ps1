# --- Script Configuration and Error Handling ---
Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

# This trap block will catch any terminating errors and provide detailed debug info.
trap {
    Write-Host
    Write-Host "ERROR: An error occurred on line $($_.InvocationInfo.ScriptLineNumber)."
    Write-Host "ERROR DETAIL: $_"
    ($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR STACK: $1' | Write-Host
    ($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1' | Write-Host
    Write-Host
    Write-Host 'Pausing for 60 minutes for debugging before exiting...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}

# --- Script Configuration ---
$SSHDPort = "22"
$EnablePasswordAuthentication = $false
$ConfigureFirewall = $true

Write-Host "Starting OpenSSH Server installation and configuration script for Windows Server 2019/2022."

# --- Install OpenSSH Server using Windows Capability (Correct method for 2019 and 2022) ---
Write-Host "Checking if OpenSSH Server is already installed..."
try {
    $sshServer = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($sshServer.State -eq 'Installed') {
        Write-Host "OpenSSH Server is already installed."
    } else {
        Write-Host "Installing OpenSSH Server as a Windows Capability..."
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Write-Host "OpenSSH Server installed successfully."
    }
} catch {
    Write-Host "ERROR: Failed to install the OpenSSH Server Windows Capability."
    throw $_
}

# --- Configure and Start SSHD Service ---
Write-Host "Configuring and starting the SSHD service."
Set-Service -Name sshd -StartupType Automatic
Write-Host "SSHD service set to start automatically."

if ((Get-Service -Name sshd).Status -ne 'Running') {
    Start-Service -Name sshd
    Write-Host "SSHD service started."
} else {
    Write-Host "SSHD service is already running."
}

# --- Configure Firewall Rule ---
if ($ConfigureFirewall) {
    Write-Host "Configuring Windows Firewall to allow SSH connections on port $SSHDPort."
    $ruleName = "OpenSSH-Server-Inbound-Rule-$SSHDPort"
    # The path to the executable for the built-in OpenSSH feature
    $sshExePath = "C:\Windows\System32\OpenSSH\sshd.exe"

    if (!(Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -LocalPort $SSHDPort -Protocol TCP -Action Allow -Program $sshExePath
        Write-Host "Firewall rule '$ruleName' created successfully."
    } else {
        Write-Host "Firewall rule '$ruleName' already exists. Ensuring it is enabled and configured correctly."
        Set-NetFirewallRule -DisplayName $ruleName -Enabled True -LocalPort $SSHDPort -Program $sshExePath
    }
} else {
    Write-Host "Firewall configuration skipped as requested."
}

# --- Apply sshd_config Recommended Settings ---
Write-Host "Applying settings to sshd_config."
$sshdConfigPath = "$env:ProgramData\ssh\sshd_config"

if (Test-Path $sshdConfigPath) {
    Copy-Item $sshdConfigPath "$sshdConfigPath.bak" -Force
    Write-Host "Backed up original sshd_config to $sshdConfigPath.bak."
} else {
    Write-Host "Warning: sshd_config not found at $sshdConfigPath. It will be created."
    if (-not (Test-Path (Split-Path $sshdConfigPath))) {
        New-Item -ItemType Directory -Path (Split-Path $sshdConfigPath) -Force
    }
    Set-Content -Path $sshdConfigPath -Value ""
}

$configContent = Get-Content $sshdConfigPath -Raw

Write-Host "Removing default 'Match Group administrators' block from sshd_config if it exists..."
$matchBlockRegex = '(?im)^\s*Match Group administrators\s*\r?\n\s*AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys\s*'
$configContent = $configContent -replace $matchBlockRegex, ''

Write-Host "Disabling PasswordAuthentication (key-based auth is more secure)."
$configContent = $configContent -replace '(?im)^#?\s*PasswordAuthentication\s+yes', 'PasswordAuthentication no'
if ($configContent -notmatch '(?im)^PasswordAuthentication\s+no') { $configContent += "`nPasswordAuthentication no" }

# Write the modified configuration back to the file
Set-Content -Path $sshdConfigPath -Value $configContent.Trim() -Force
Write-Host "sshd_config updated successfully."

# --- Restart Service to Apply Changes ---
Write-Host "Restarting SSHD service to apply new configurations."
Restart-Service -Name sshd
Write-Host "SSHD service restarted."
Write-Host "OpenSSH Server installation and configuration script finished."
