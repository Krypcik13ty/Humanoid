net use \\$env:COMPUTERNAME\Humanoid$
$eventId = 4625
$logName = 'Security'
$select = "*[System[(EventID=$eventId)]]"
$query = [System.Diagnostics.Eventing.Reader.EventLogQuery]::new($logName, [System.Diagnostics.Eventing.Reader.PathType]::LogName, $select)
$watcher = [System.Diagnostics.Eventing.Reader.EventLogWatcher]::new($query)
$watcher.Enabled = $true
$action = {
    new-object psobject -Property @{
        platform = "Win"
        type = "Event"
        id = "4625"
        name = $env:COMPUTERNAME
        } | Export-Csv -Path "C:\temp\$env:computername"
copy-item C:\temp\
}
$job = Register-ObjectEvent -InputObject $watcher -EventName 'EventRecordWritten' -Action $action
Receive-Job $job