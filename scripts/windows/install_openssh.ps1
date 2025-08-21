# --- Script Configuration and Error Handling ---
Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

# --- Universal Fix: Force the use of TLS 1.2 for all web requests ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

Write-Host "Starting Universal OpenSSH Server installation script."

# --- OS Version Detection and Version-Specific Installation ---
$OSBuild = [System.Environment]::OSVersion.Version.Build
$sshExePath = "" # Initialize variable

# Server 2019 build number is 17763. Anything newer uses the modern method.
if ($OSBuild -ge 17763) {
    # --- METHOD 1: Windows Server 2019 / 2022 ---
    Write-Host "Modern OS (Build $OSBuild) detected. Installing via Windows Capability..."
    try {
        $sshServer = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
        if ($sshServer.State -eq 'Installed') {
            Write-Host "OpenSSH Server is already installed."
        } else {
            Write-Host "Installing OpenSSH Server as a Windows Capability..."
            Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
            Write-Host "OpenSSH Server installed successfully."
        }
        $sshExePath = "C:\Windows\System32\OpenSSH\sshd.exe"
    } catch {
        Write-Host "ERROR: Failed to install the OpenSSH Server Windows Capability."
        throw $_
    }
} else {
    # --- METHOD 2: Windows Server 2016 ---
    Write-Host "Legacy OS (Build $OSBuild) detected. Installing via MSI download..."
    try {
        if (Test-Path "$env:ProgramFiles\OpenSSH\sshd.exe") {
            Write-Host "OpenSSH seems to be already installed. Skipping installation."
        } else {
            $downloadUrl = "https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.5.0.0p1-Beta/OpenSSH-Server-MSI.msi"
            $installerPath = "$env:TEMP\OpenSSH-Server-MSI.msi"

            Write-Host "Downloading OpenSSH MSI from $downloadUrl..."
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

            Write-Host "Installing OpenSSH from MSI..."
            $msiArgs = "/i `"$installerPath`" /quiet /norestart"
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
                throw "OpenSSH MSI installation failed with exit code: $($process.ExitCode)."
            }
            Write-Host "OpenSSH Server installed successfully."
            Remove-Item $installerPath -Force
        }
        $sshExePath = "C:\Program Files\OpenSSH\sshd.exe"
    } catch {
        Write-Host "ERROR: Failed to install OpenSSH from the official MSI."
        throw $_
    }
}


# --- Common Configuration for ALL OS Versions ---

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
Write-Host "Configuring Windows Firewall to allow SSH connections on port $SSHDPort."
$ruleName = "OpenSSH-Server-Inbound-Rule-$SSHDPort"
if (!(Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -LocalPort $SSHDPort -Protocol TCP -Action Allow -Program $sshExePath
    Write-Host "Firewall rule '$ruleName' created successfully."
} else {
    Write-Host "Firewall rule '$ruleName' already exists. Ensuring it is enabled and configured correctly."
    Set-NetFirewallRule -DisplayName $ruleName -Enabled True -LocalPort $SSHDPort -Program $sshExePath
}

# --- Apply sshd_config Recommended Settings ---
Write-Host "Applying settings to sshd_config."
$sshdConfigPath = "$env:ProgramData\ssh\sshd_config"

if (Test-Path $sshdConfigPath) {
    Copy-Item $sshdConfigPath "$sshdConfigPath.bak" -Force
    Write-Host "Backed up original sshd_config to $sshdConfigPath.bak."
} else {
    Write-Host "Warning: sshd_config not found. It will be created."
    if (-not (Test-Path (Split-Path $sshdConfigPath))) { New-Item -ItemType Directory -Path (Split-Path $sshdConfigPath) -Force }
    Set-Content -Path $sshdConfigPath -Value ""
}

$configContent = Get-Content $sshdConfigPath -Raw

Write-Host "Removing default 'Match Group administrators' block from sshd_config if it exists..."
$matchBlockRegex = '(?im)^\s*Match Group administrators\s*\r?\n\s*AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys\s*'
$configContent = $configContent -replace $matchBlockRegex, ''

# Always disable password authentication for better security
Write-Host "Disabling PasswordAuthentication (key-based auth is more secure)."
$configContent = $configContent -replace '(?im)^#?\s*PasswordAuthentication\s+yes', 'PasswordAuthentication no'
if ($configContent -notmatch '(?im)^PasswordAuthentication\s+no') { $configContent += "`nPasswordAuthentication no" }

Set-Content -Path $sshdConfigPath -Value $configContent.Trim() -Force
Write-Host "sshd_config updated successfully."

# --- Restart Service to Apply Changes ---
Write-Host "Restarting SSHD service to apply new configurations."
Restart-Service -Name sshd
Write-Host "SSHD service restarted."
Write-Host "OpenSSH Server installation and configuration script finished."
