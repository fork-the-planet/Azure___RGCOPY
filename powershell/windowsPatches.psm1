# powershell\windowsPatches.psm1 --->

# create log directory
$logDir = 'C:\Packages\Plugins\WindowsUpdate'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

# add full control
$acl = Get-Acl $logDir
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Everyone",
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl -Path $logDir -AclObject $acl

# set log file name
$logFile = "$logDir\WindowsUpdate__$(Get-Date -Format 'yyyy-MM-dd__HH-mm-ss').log"

# Install PSWindowsUpdate module if not already installed
$installed = Get-Module -ListAvailable -Name 'PSWindowsUpdate'
$installed | Select-Object Name, Version            | Tee-Object -FilePath $logFile -Append
" "                                                 | Tee-Object -FilePath $logFile -Append
if (!$installed) {
    "Installing PSWindowsUpdate module"             | Tee-Object -FilePath $logFile -Append
    Install-PackageProvider -Name 'NuGet' -Force                                    | Out-Null
    Install-Module -Name 'PSWindowsUpdate' -Force -AllowClobber -ErrorAction 'Stop' | Out-Null
}
Import-Module PSWindowsUpdate -ErrorAction 'SilentlyContinue'

# Install Windows updates
"$(get-date) Starting Windows updates"              | Tee-Object -FilePath $logFile -Append
$updates = Install-WindowsUpdate `
            -AcceptAll `
            -IgnoreReboot `
            -ErrorAction 'SilentlyContinue'
$updates | Format-Table KB, Result, Title           | Tee-Object -FilePath $logFile -Append
"$(get-date) Finished Windows updates"              | Tee-Object -FilePath $logFile -Append

# Check reboot status
"REBOOT_REQUIRED='$(Get-WURebootStatus -silent)'" | Tee-Object -FilePath $logFile -Append
