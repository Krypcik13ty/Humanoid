Install-Module -Name Microsoft.PowerShell.SecretStore -Repository PSGallery -Force
Install-Module -Name Microsoft.PowerShell.SecretManagement -Repository PSGallery -Force
Import-Module Microsoft.PowerShell.SecretStore
Import-Module Microsoft.PowerShell.SecretManagement
if($null -like $InstallPath) {$InstallPath = "C:\Humanoid"; new-item $InstallPath -ItemType Directory}
else {New-Item $InstallPath -ItemType Directory}
write-host "Set Password for Secret Storage - Store this password for troubleshooting!"
$credential = Get-Credential -UserName 'SecureStore'
$securePasswordPath = "$InstallPath\passwd.xml"
$credential.Password |  Export-Clixml -Path $securePasswordPath
Register-SecretVault -Name SecretStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
$password = Import-CliXml -Path $securePasswordPath
$storeConfiguration = @{
    Authentication = 'Password'
    PasswordTimeout = 3600
    Interaction = 'None'
    Password = $password
    Confirm = $false
}
Set-SecretStoreConfiguration @storeConfiguration
$password = Import-CliXml -Path "$InstallPath\passwd.xml"
Unlock-SecretStore -Password $password
$NoticeBox = read-Host "Set e-mail address where notifications should be sent"
Set-Secret -Name NoticeMail_ -Secret $NoticeBox
$SvcUsername = read-Host "Set Username for Humanoid Actions Service account"
Set-Secret -Name HumanoidUser_ -Secret $SvcUsername
$SvcPass = read-Host "Set Password for Humanoid Actions Service account - Store the password securely!"
Set-Secret -Name HumanoidService_ -Secret $SvcPass
$SMTP = read-Host "Set e-mail address for Humanoid Actions Mail account - Use full mail address, for example humanoidactions@outlook.com"
Set-Secret -Name HumanoidMail_ -Secret $SMTP
$SMTPPass = read-Host "Set password for Humanoid Actions Mail account - Store the password securely!"
Set-Secret -Name HumanoidMailPWD_ -Secret $SMTPPass
Copy-item -Path $PSScriptRoot\Humanoid* -Destination $InstallPath -Recurse -Force
Register-ScheduledTask -TaskName 'HumanoidService' -Xml (Get-Content "$PSScriptRoot\HumanoidService.xml" | Out-String) -Force
$Parameters = @{
    Name = "Humanoid"
    Path = "C:\Humanoid\HumanoidActions"
    FullAccess = "$SvcUsername"
}
Start-ScheduledTask -TaskName 'HumanoidService'
New-SMBShare @Parameters
write-host "Done!"