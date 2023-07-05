try{
    Import-Module Microsoft.PowerShell.SecretStore
    Import-Module Microsoft.PowerShell.SecretManagement
}
catch {
    Install-Module Microsoft.Powershell.SecretStore -Force
    Install-Module Microsoft.Powershell.SecretManagement -Force
    Import-Module Microsoft.PowerShell.SecretStore
    Import-Module Microsoft.PowerShell.SecretManagement
}
$filewatcher = New-Object System.IO.FileSystemWatcher
"$(Get-Date) Attempting to initiate" >> $PSScriptRoot\logfile.txt
$filewatcher.path = "$PSScriptRoot\HumanoidActions"
$filewatcher.IncludeSubdirectories = $true
$filewatcher.EnableRaisingEvents = $true
$writeaction = { 
    #setup
    "$(Get-Date) unlocking Secret Storage and pulling secrets." >> $PSSCriptRoot\logfile.txt
    $password = Import-CliXml -Path $PSScriptRoot\passwd.xml
    Unlock-SecretStore -Password $password
    $NoticeBox = Get-Secret -Name NoticeMail_ -AsPlainText
    $PWord = Get-Secret -Name HumanoidService_
    $Mail = Get-Secret -Name HumanoidMail_ -AsPlainText
    $SMTPPass = Get-Secret -Name HumanoidMailPWD_
    $UserName = Get-Secret -Name HumanoidUser_ -AsPlainText
    $ServiceCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Pword
    $MailCreds =  New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Mail, $SMTPPass
    $path = $Event.SourceEventArgs.FullPath
    $content = Import-CSV $path
    #actual action
    $changeType = $Event.SourceEventArgs.ChangeType
    $logline = “$(Get-Date) $($content.type) $($content.id) has been noted on $($content.name)" 
    $logline >> $PSSCriptRoot\logfile.txt
    if((test-path "$PSScriptRoot\HumanoidActions\$($content.platform)\$($content.type)\$($content.id)\hostpre.ps1")){
        if ((get-VM -Name $content.name) -notlike $null){
            "Trying locally host pre-action" >> $PSSCriptRoot\logfile.txt
            powershell $PSScriptRoot\HumanoidActions\$($content.platform)\$($content.type)\$($content.id)\hostpre.ps1 "$($content.name)"
        } else {
            try {
                "running pre-script on remote agent"  >> $PSSCriptRoot\logfile.txt
                invoke-command -UseSSL -ComputerName $content.host -FilePath "$PSScriptRoot\HumanoidActions\$($content.platform)\$($content.type)\$($content.id)\hostpre.ps1" -Credential $ServiceCreds
                "First host action has been finished." >> $PSSCriptRoot\logfile.txt
            } catch {
                "Host prescript has failed" >> $PSSCriptRoot\logfile.txt
            }
        }
    }
    if((test-path "$PSScriptRoot\HumanoidActions\$($content.platform)\$($content.type)\$($content.id)\action.ps1") -and (Test-Connection -count 1 -Quiet -IPv4 -TargetName "$($content.name)")){
        try{
            start-sleep -Seconds 3
            Invoke-Command -UseSSL -FilePath "$PSScriptRoot\HumanoidActions\$($content.platform)\$($content.type)\$($content.id)\action.ps1" -ComputerName $content.name -Credential $ServiceCreds -ErrorAction Stop
            "On-VM action has been completed."  >> $PSSCriptRoot\logfile.txt
            
        }
        catch {"Something went wrong with on-VM exectution "  >> $PSSCriptRoot\logfile.txt}
    }
    else {
        if(Test-Connection -IPv4 -count 1 -Quiet -TargetName $($content.name)){
            "there's no action for event $($content.id)" >> $PSSCriptRoot\logfile.txt
        } else {
            "Target $($content.name) is unreachable"  >> $PSSCriptRoot\logfile.txt
        }
    }
    start-sleep -Seconds 3
    "Starting on-host post-script execution"
    if(test-path "$PSScriptRoot\HumanoidActions\$($content.platform)\$($content.type)\$($content.id)\hostpost.ps1"){
        if ((get-VM -Name $content.name) -notlike $null){
            "Trying to run postscript locally"  >> $PSSCriptRoot\logfile.txt
            powershell $PSScriptRoot\HumanoidActions\$($content.platform)\$($content.type)\$($content.id)\hostpost.ps1 "$($content.name)"
        } else {
            "Trying to run postscript remotely" >> $PSSCriptRoot\logfile.txt
            try{
            invoke-command -ComputerName $content.host -FilePath "$PSScriptRoot\HumanoidActions\$($content.platform)\$($content.type)\$($content.id)\hostpost.ps1" -Credential $ServiceCreds -UseSSL
            } catch {
                "failed remote execution"  >> $PSSCriptRoot\logfile.txt
            }
        }
        "Second host action on $($content.host) has been completed" >> $PSSCriptRoot\logfile.txt
    }
    "Sending mail message"  >> $PSSCriptRoot\logfile.txt
    Send-MailMessage -From "HumanoidActions@outlook.com" -Credential $MailCreds -Subject "Action for event $($content.id) done on $($content.name)" -Body (Get-Content -Raw "$PSScriptRoot\HumanoidActions\$($content.platform)\$($content.type)\$($content.id)\subject.txt") -to $NoticeBox -SmtpServer "smtp-mail.outlook.com" -Port 587 -UseSSL -WarningAction SilentlyContinue
    "Pager sent to $NoticeBox" >> $PSSCriptRoot\logfile.txt
    remove-item $path -Force
    "$(Get-Date) Finished action" >> $PSSCriptRoot\logfile.txt
}
Register-ObjectEvent $filewatcher “Created” -Action $writeaction
"$(Get-Date) Service is running" >> $PSScriptRoot\logfile.txt
