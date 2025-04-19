$Servers = @(
    "Server1"
    "Server2"
    "Server3"
    "Server4"
    "Server5"

)

foreach ($Server in $Servers) {
    $Session = New-PSSession -ComputerName $Server

    $GetAutoShareNum = Invoke-Command -Session $Session -ScriptBlock {Get-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\LanmanServer\Parameters -Name "AutoShareServer"} -ErrorAction SilentlyContinue

    if ($GetAutoShareNum.AutoShareServer -eq 0) {
        Invoke-Command -Session $Session -ScriptBlock {Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\LanmanServer\Parameters -Name "AutoShareServer" -Value 1}
        echo "$Server has been updated to 1"
    } else {
        echo "$Server does not need to be updated"
    }
}
