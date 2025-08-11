# --- Script Configuration and Error Handling ---
Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

# This is required to ensure Invoke-WebRequest can connect to modern secure servers.
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
$DownloadUrl = "https://www.cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
$InstallerPath = "$env:TEMP\CloudbaseInitSetup_Stable_x64.msi"

Write-Host "Starting Cloudbase-Init installation script."

# --- Check if Cloudbase-Init is already installed ---
Write-Host "Checking if Cloudbase-Init is already installed..."
$service = Get-Service -Name "cloudbase-init" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "Cloudbase-Init service is already present. Skipping installation."
    exit 0
}

# --- Download Cloudbase-Init Installer ---
Write-Host "Attempting to download Cloudbase-Init from: $DownloadUrl"
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing
    Write-Host "Successfully downloaded Cloudbase-Init to $InstallerPath."
} catch {
    Write-Host "ERROR: Failed to download Cloudbase-Init installer."
    throw $_ # Re-throw the exception to trigger the trap block
}


# --- Install Cloudbase-Init Silently ---
# MSI arguments for silent installation:
# /qn           - Quiet mode, no UI
# /L*v          - Verbose logging
# LOGGINGSERIALPORTNAME="COM1" - Sets the serial port for logging (for OpenStack console)
# RUNSERVICEASLOCALSYSTEM=1    - Runs the service under the LocalSystem account
# SYSPREP_INSTALL=1            - Integrates with Sysprep for image generalization
# REBOOT=ReallySuppress        - Suppresses reboots during installation
$msiArgs = @(
    "/qn"
    "/L*v `"$env:TEMP\CloudbaseInit_InstallLog.log`""
    "LOGGINGSERIALPORTNAME=`"COM1`""
    "RUNSERVICEASLOCALSYSTEM=1"
    "SYSPREP_INSTALL=1"
    "REBOOT=ReallySuppress"
)

Write-Host "Starting Cloudbase-Init silent installation."
Write-Host "Executing installer with arguments: $($msiArgs -join ' ')"

try {
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$InstallerPath`" $($msiArgs -join ' ')" -Wait -PassThru -NoNewWindow

    # Check the installer's exit code ---
    if ($process.ExitCode -eq 0) {
        Write-Host "Cloudbase-Init installation completed successfully (Exit Code: 0)."
    } elseif ($process.ExitCode -eq 3010) {
        Write-Host "Cloudbase-Init installation completed successfully, but a reboot is required (Exit Code: 3010)."
    } else {
        # Throw an error if the installer failed. This will trigger the trap block.
        throw "Cloudbase-Init installation failed with exit code: $($process.ExitCode). Check the log at `"$env:TEMP\CloudbaseInit_InstallLog.log`" for details."
    }
} catch {
    Write-Host "ERROR: An exception occurred during the installation process."
    throw $_
}

# --- Cleanup ---
Write-Host "Deleting downloaded installer: $InstallerPath"
Remove-Item $InstallerPath -Force -ErrorAction Stop
Write-Host "Installer deleted successfully."
Write-Host "Cloudbase-Init installation script finished."
