@echo off
rem Runs once after sysprep OOBE on each deployed instance, before the first logon.
rem Last step re-enables the cloudbase-init service that finalize.ps1 set to manual so it could not run during specialize.
rem Drops the unencrypted WinRM HTTP listener that only the Packer build needs; cloudbase-init creates an HTTPS listener on 5986.
rem winrm is winrm.cmd, so CALL is required or the batch file ends after the first line.
net start winrm >nul 2>&1
call winrm delete winrm/config/listener?Address=*+Transport=HTTP
call winrm set winrm/config/service @{AllowUnencrypted="false"}
netsh advfirewall firewall delete rule name="Port 5985"
netsh advfirewall firewall set rule group="Windows Remote Management" new enable=no
sc config cloudbase-init start= auto
net start cloudbase-init
