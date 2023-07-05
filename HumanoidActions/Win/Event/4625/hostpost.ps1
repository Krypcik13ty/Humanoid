#Prosty przykład akcji wysyłanej do Hypervisor'a.

param(
    [string]$VMName
)
get-vm $VMName | get-vmnetworkadapter | Connect-VMNetworkAdapter -SwitchName "Forensics"
