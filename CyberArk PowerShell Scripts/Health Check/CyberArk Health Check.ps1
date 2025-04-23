clear
<#
#>
$PSMServers = @(

"Server1"
"Server2"
"Server3"
"Server4"
"Server5"
)

$CPMServers=@(

"Server1"
"Server2"
"Server3"
"Server4"
"Server5"


)

$PVWAServers=@(
#PVWA

"Server1"
"Server2"
"Server3"
"Server4"
"Server5"

)

$AAMServers=@(
#AAM
"Server1"
"Server2"
"Server3"
"Server4"
"Server5"
)

#>
$PSMPServers = @(
"Server1"
"Server2"
"Server3"
"Server4"
"Server5"
)

foreach ($Server in $PSMServers){
$Session = New-PSSession -ComputerName $Server

$PSMService=Invoke-Command -Session $Session -ScriptBlock {Get-Service -Name "CyberArk*"}

if($PSMService.Status -eq 'Running'){
write-host "The PSM Service on $server is" $PSMService.Status -ForegroundColor Green

}
else{
write-host "The PSM Service on $server is" $PSMService.Status -ForegroundColor Red

$PSMStart=Read-Host "Would you like to try to start the service on $server? y/n"

if($PSMStart -eq "y"){

Invoke-Command -Session $Session -ScriptBlock {Start-Service -DisplayName "CyberArk*"}

$PSMService=Invoke-Command -Session $Session -ScriptBlock {Get-Service -Name "CyberArk*"}

if($PSMService.Status -eq 'Running'){
write-host "The PSM Service on $server is up and" $PSMService.Status -ForegroundColor Green
}

else{
write-host "The PSM Service on $server is" $PSMService.Status -ForegroundColor Red
Echo "Looks like the service was not able to be started" -ForegroundColor Red
}



}


}

Clear-Variable -Name "PSMService"
}

echo ""

foreach ($Server in $CPMServers){
$Session = New-PSSession -ComputerName $Server

$CPMService=Invoke-Command -Session $Session -ScriptBlock {Get-Service -Name "CyberArk Password Manager"}

if($CPMService.Status -eq 'Running'){
write-host "The CPM Service on $server is" $CPMService.Status -ForegroundColor Green

}
else{
write-host "The CPM Service on $server is" $CPMService.Status -ForegroundColor Red

$CPMStart=Read-Host "Would you like to try to start the service on $server? y/n"

if($CPMStart -eq "y"){

Invoke-Command -Session $Session -ScriptBlock {Start-Service -Name "CyberArk Password Manager"}

$CPMService=Invoke-Command -Session $Session -ScriptBlock {Get-Service -Name "CyberArk Password Manager"}

if($CPMService.Status -eq 'Running'){
write-host "The CPM Service on $server is" $CPMService.Status -ForegroundColor Green
}

else{
write-host "The CPM Service on $server is" $CPMService.Status -ForegroundColor Red
write-host "Looks like the service was not able to be started" -ForegroundColor Red
}
}


}
Clear-Variable -Name "CPMService"

}

echo ""

foreach ($Server in $PVWAServers){
$PVWAStatus=curl -Uri "https://$Server/PasswordVault/v10" -TimeoutSec 30

if($PVWAStatus.StatusCode -ne 200){

write-host "The PVWA Server $Server is offline"  -ForegroundColor Red


$PVWAIISReset=Read-Host "Would you like to try to restart the IIS service on $server? y/n"
if($PVWAIISReset -eq "y"){
$Session = New-PSSession -ComputerName $Server
Invoke-Command -Session $Session -ScriptBlock {iisreset}
Invoke-Command -Session $Session -ScriptBlock {iisreset}
}
}

else{
write-host "The PVWA Server $Server is online" -ForegroundColor Green
}
Clear-Variable -Name "PVWAStatus"
}


echo ""


foreach ($Server in $AAMServers){
$AAMStatus=curl -Uri "https://$Server/AIMWebService/V1.1/AIM.asmx"

$Session = New-PSSession -ComputerName $Server

$AAMService=Invoke-Command -Session $Session -ScriptBlock {Get-Service -name "CyberArk Application Password Provider"}


if($AAMStatus.StatusCode -ne 200 -and $AAMService.Status -ne 'Running'){

write-host "The AAM Server $Server is offline"  -ForegroundColor Red


$AAMIISReset=Read-Host "Would you like to try to restart the IIS service and AAM Service on $server? y/n"
if($AAMIISReset -eq "y"){
$Session = New-PSSession -ComputerName $Server
Invoke-Command -Session $Session -ScriptBlock {Restart-Service -Name "CyberArk Application Password Provider" -Force}
Invoke-Command -Session $Session -ScriptBlock {iisreset}
Invoke-Command -Session $Session -ScriptBlock {iisreset}
}
}


else{
write-host "The AAM Server $Server is online" -ForegroundColor Green
}

}

echo ""

#Use AAM to log into PSMP servers as Linux needs Username and Password
$UseAAM = Read-Host "Use AAM to get password? Y/N"
if ($UseAAM -eq "Y") {
    # Use AAM to log into PSMP servers as Linux needs Username and Password
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")

    $URL = "AAMServer"
    $APPID = "AAM-APP-ID"
    $SAFE = "AAM-SAFE"
    $ACCOUNTOBJECTNAME = "AccountObjectName"
    $Reason = "CyberArk Check PSMP Health"

    $response = Invoke-RestMethod "https://$URL/AIMWebServiceWindows/api/Accounts?AppID=$APPID&Safe=$SAFE&Object=$ACCOUNTOBJECTNAME&Reason=$Reason" -Method 'GET' -Headers $headers -UseDefaultCredentials

    # Username
    $UserName = $response[0].UserName

    # Password
    $Password = $response[0].Content

    $User = $UserName
    $PWord = ConvertTo-SecureString "$Password" -AsPlainText -Force
    $UserCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    Clear-Variable "Password"
} else {
    $UserCred = Get-Credential -Message "PSMP username"
}


foreach ($Server in $PSMPServers){

#Vaildate that the user has a home folder on the server
$Session=New-SSHSession -ComputerName $Server -Credential $Credential -AcceptKey -ConnectionTimeout 60
$PSMPService=Invoke-SSHCommand -SSHSession $Session -Command "sudo systemctl status psmpsrv" -TimeOut 30

$IsActive=$null
$IsActive=$PSMPService.Output | Select-String "Active: active"

if($IsActive -ne $null){
Write-host "The PSMP Service $Server is running" -ForegroundColor Green
}
else{
Write-host "The PSMP Server $Server is offline" -ForegroundColor Red

$PSMPService.Output
}
Clear-Variable "IsActive"
Clear-Variable "PSMPService"
}



Read-Host -Prompt "Press Enter to exit"