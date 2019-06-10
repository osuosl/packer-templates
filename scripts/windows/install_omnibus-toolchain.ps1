. { iwr -useb https://omnitruck.chef.io/install.ps1 } | iex; install -project chef -version 14

$directories = "cache", "cookbooks", "tmp"
$cookbooks = "omnibus", "windows", "mingw", "build-essential", "chef-sugar",
             "chef-ingredient", "git", "homebrew", "remote_install", "seven_zip", "wix"

foreach ($directory in $directories) {
    New-Item -Path "C:\chef" -Name "$directory" -ItemType "directory"
}

foreach ($cookbook in $cookbooks) {
    Invoke-WebRequest -OutFile C:\chef\tmp\$cookbook.tar.gz https://supermarket.chef.io/cookbooks/$cookbook/download
    C:\opscode\chef\bin\tar.exe -xzC C:\chef\cookbooks -f C:\chef\tmp\$cookbook.tar.gz
}

C:\opscode\chef\bin\chef-solo.bat -o 'recipe[omnibus]'

C:\opscode\chef\embedded\bin\sed.exe -i -e 's/Get-ChildItem env://' C:\omnibus\load-omnibus-toolchain.ps1

choco.exe install rsync -y

C:\omnibus\load-omnibus-toolchain.ps1

$app = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name like '%Chef Client%'"
$app.Uninstall()

Remove-Item -Recurse -Force C:\chef*.*
Remove-Item C:\Windows\Temp\*.msi
Remove-Item C:\Windows\Temp\*.zip
