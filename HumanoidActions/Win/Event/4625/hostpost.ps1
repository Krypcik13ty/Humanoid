param(
    [string]$VMName
)
get-vm $VMName | get-vmnetworkadapter | Connect-VMNetworkAdapter -SwitchName "Forensics"