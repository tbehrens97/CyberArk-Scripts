

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
    $Reason = "CyberArk Clear PSMP Var Log"

    $response = Invoke-RestMethod "https://$URL/AIMWebService/api/Accounts?AppID=$APPID&Safe=$SAFE&Object=$ACCOUNTOBJECTNAME&Reason=$Reason" -Method 'GET' -Headers $headers -UseDefaultCredentials

    # Username
    $UserName = $response[0].UserName

    # Password
    $Password = $response[0].Content

    $User = $UserName
    $PWord = ConvertTo-SecureString "$Password" -AsPlainText -Force
    $UserCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    Clear-Variable "Password"
} else {
    $UserCred = Get-Credential -credential $Env:UserName
}

Get-Date

$ActiveServers = @(
    "Server1"
    "Server2"
    "Server3"
    "Server4"
    "Server5"
    "Server6"
    "Server7"
    "Server8"
    "Server9"
    "Server10"
    "Server11"
    "Server12"
    "Server13"
    "Server14"
    "Server15"
    "Server16"
    "Server17"
    "Server18"
)

foreach ($Server in $ActiveServers) {
    # Validate that the user has a home folder on the server
    $Session = New-SSHSession -ComputerName $Server -Credential $UserCred -AcceptKey -ConnectionTimeout 180
    $PSMPVersion = Invoke-SSHCommand -SSHSession $Session -Command "sudo rpm -qa | grep CARK"

    write-host "On server $Server CyberArk Version is" $PSMPVersion.Output
}
