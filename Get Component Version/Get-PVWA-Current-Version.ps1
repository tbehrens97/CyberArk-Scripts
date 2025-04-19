clear
$Servers = @(
    "Server1"
    "Server2"
    "Server3"
    "Server4"
    "Server5"
    "Server6"
    "Server7"
    "Server8"
)

Get-Date

$PVWAServers = foreach ($Server in $Servers) {
    $Session = New-PSSession -ComputerName $Server

    Invoke-Command -Session $Session -ScriptBlock {Get-WmiObject -Class Win32_Product | where vendor -eq CyberArk | select Name, Version} | select * -exclude RunspaceID
}

$PVWAServers | Format-Table -AutoSize
