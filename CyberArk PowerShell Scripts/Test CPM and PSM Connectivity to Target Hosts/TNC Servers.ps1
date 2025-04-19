clear

$PSMServers = @(
#PSM Server names here
#Server1
#Server2
#Server3.....
)

$CPMServers=@(
#CPM Server names here
#Server1
#Server2
#Server3.....
)

function Get-FileName($initialDirectory)
{   
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
    Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    #$OpenFileDialog.filter = "All files (*.*)| *.*"
    $OpenFileDialog.filter = "CSV Files (*.csv)| *.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}


$FileName=Get-FileName

$ServerList= Import-Csv $FileName
clear


foreach ($Server in $ServerList){

$ServerName=$Server.Server
$ServerPort=$Server.OS

foreach ($PSMServer in $PSMServers){

$Session = New-PSSession -ComputerName $PSMServer

if ($Server.OS -eq "Windows" ){

$TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", 3389).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "PSM Server $PSMServer was able to acccess the server $ServerName on port 3389"
    }
    Else{
    Write-Host "PSM Server $PSMServer was NOT able to acccess the server $ServerName on port 3389" -ForegroundColor red
    }

    $TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", 445).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "PSM Server $PSMServer was able to acccess the server $ServerName on port 445"
    }
    Else{
    Write-Host "PSM Server $PSMServer was NOT able to acccess the server $ServerName on port 445" -ForegroundColor red
    }

}
if ($Server.OS -eq "Linux" ){

$TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", 22).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "PSM Server $PSMServer was able to acccess the server $ServerName on port 22"
    }
    Else{
    Write-Host "PSM Server $PSMServer was NOT able to acccess the server $ServerName on port 22" -ForegroundColor red
    }

}

if ($Server.OS -eq "MSSQL" ){

$TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", 1433).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "PSM Server $PSMServer was able to acccess the server $ServerName on port 1433"
    }
    Else{
    Write-Host "PSM Server $PSMServer was NOT able to acccess the server $ServerName on port 1433" -ForegroundColor red
    }

}

if ($Server.OS -eq "Oracle" ){

$TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", 1521).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "PSM Server $PSMServer was able to acccess the server $ServerName on port 1521"
    }
    Else{
    Write-Host "PSM Server $PSMServer was NOT able to acccess the server $ServerName on port 1521" -ForegroundColor red
    }

}

if ($Server.OS -match "^\d+$") {

$TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", $Using:ServerPort).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "PSM Server $PSMServer was able to acccess the server $ServerName on port $ServerPort"
    }
    Else{
    Write-Host "PSM Server $PSMServer was NOT able to acccess the server $ServerName on port $ServerPort" -ForegroundColor red
    }
}


}


foreach ($CPMServer in $CPMServers){

$Session = New-PSSession -ComputerName $CPMServer

if ($Server.OS -eq "Windows" ){

$TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", 445).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "CPM Server $CPMServer was able to acccess the server $ServerName on port 445"
    }
    Else{
    Write-Host "CPM Server $CPMServer was NOT able to acccess the server $ServerName on port 445" -ForegroundColor red
    }

}
if ($Server.OS -eq "Linux" ){

$TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", 22).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "CPM Server $CPMServer was able to acccess the server $ServerName on port 22"
    }
    Else{
    Write-Host "CPM Server $CPMServer was NOT able to acccess the server $ServerName on port 22" -ForegroundColor red
    }

}

if ($Server.OS -eq "MSSQL" ){

$TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", 1433).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "CPM Server $CPMServer was able to acccess the server $ServerName on port 1433"
    }
    Else{
    Write-Host "CPM Server $CPMServer was NOT able to acccess the server $ServerName on port 1433" -ForegroundColor red
    }

}

if ($Server.OS -eq "Oracle" ){

$TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", 1521).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "CPM Server $CPMServer was able to acccess the server $ServerName on port 1521"
    }
    Else{
    Write-Host "CPM Server $CPMServer was NOT able to acccess the server $ServerName on port 1521" -ForegroundColor red
    }

}

if ($Server.OS -match "^\d+$"){

$TestConnection = Invoke-Command -Session $Session -ScriptBlock {(New-Object System.Net.Sockets.TcpClient).ConnectAsync("$Using:ServerName", $Using:ServerPort).Wait(200)}
    if ($TestConnection -eq 'True'){
    Write-Host "CPM Server $CPMServer was able to acccess the server $ServerName on port $ServerPort"
    }
    Else{
    Write-Host "CPM Server $CPMServer was NOT able to acccess the server $ServerName on port $ServerPort" -ForegroundColor red
    }



}

}
}
