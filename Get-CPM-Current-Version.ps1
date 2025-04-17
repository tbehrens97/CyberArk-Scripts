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
    "Server9"
)

Get-Date

foreach ($Server in $Servers) {
    $Session = New-PSSession -ComputerName $Server

    Invoke-Command -Session $Session -ScriptBlock {Get-WmiObject -Class Win32_Product | where vendor -eq "Cyber-Ark Software Ltd." | select Name, Version}

    $CPMService = Invoke-Command -Session $Session -ScriptBlock {Get-Service -Name "CyberArk Password Manager"}

    if ($CPMService.Status -eq 'Running') {
        write-host "The CPM Service on $Server is" $CPMService.Status -ForegroundColor Green
    } else {
        write-host "The CPM Service on $Server is" $CPMService.Status -ForegroundColor Magenta
    }
}
