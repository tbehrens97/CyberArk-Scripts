

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
    $Reason = "CyberArk Update PSMP"

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
    $UserCred = Get-Credential -credential $Env:UserName
}

function Get-FileName($initialDirectory) {   
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "PSMP Zip (*.zip)| PrivilegedSessionManagerSSHProxy*.zip"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

# Gets the whole Path
$FileName = Get-FileName

# Get just file name with extension
$outputPath = $FileName
$outputFile = Split-Path $outputPath -leaf

$FilenameNoDotZip = ([io.fileinfo]"$FileName").basename

# Read Zip folder to get RPM CARK Version file
Add-Type -assembly "system.io.compression.filesystem"

$CARK_Version = [io.compression.zipfile]::OpenRead("$FileName").Entries.Name | Select-String CARKpsmp

if ($CARK_Version -eq $null) {
    echo "Please check that you have selected the correct zip file"
    Break
}

# Define the file path
$filePath = $FileName

# Use Get-Item to retrieve the item
$item = Get-Item -Path $filePath

# Get the full path of the item
$fullPath = $item.FullName

# Get the directory path
$directoryPath = Split-Path -Path $fullPath

# Get the file name without the extension
$fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($fullPath)

# Combine the directory path and the file name without the extension
$resultPath = Join-Path -Path $directoryPath -ChildPath $fileNameWithoutExtension

# Gets The full path without .zip C:\Users\$env:username\Desktop\PrivilegedSessionManagerSSHProxy-RHELinux8-Intel64-Rls-v14.4
$FileNameBase = $resultPath

# Lowercase Username
$usernamelower = $UserCred.UserName.ToLower()

##### Edit me if needed!
$VaultIPs = '192.168.1.1,192.168.1.2'

$FileNameNoExten = [io.path]::GetFileNameWithoutExtension($outputPath)

# New password for root
$newPasswd = Read-Host -Prompt "New Password for root" -AsSecureString

# CyberArk Administrator password
$AdminUserCred = Get-Credential -credential Administrator
$AdminBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminUserCred.Password)
$AdminPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($AdminBSTR)

$ActiveServers = @(
    "Server1"
    "Server2"
    "Server3"
)

$ErrorActionPreference = "Stop"



foreach ($Server in $ActiveServers){

#Vaildate that the user has a home folder on the server
$Session=New-SSHSession -ComputerName $Server -Credential $UserCred -AcceptKey
Invoke-SSHCommand -SSHSession $Session -Command "echo Hello World"

Write-Host "Deleting logs this may take some time"  (Get-Date).ToString('hh:mm:ss tt') -ForegroundColor Black -BackgroundColor Magenta

Invoke-SSHCommand -SSHSession $Session -Command "sudo systemctl stop psmpsrv"

Invoke-SSHCommand -SSHSession $Session -Command "sudo rm -rf /var/opt/CARKpsmp/logs/*"

Invoke-SSHCommand -SSHSession $Session -Command "sudo find /var/tmp -name 'PrivateArkEx*' -type d -mtime +2 -print -exec rm -r {} + -depth" -TimeOut 360


#For this to work you may have to "rename" C:\Windows\Microsoft.NET\assembly\GAC_64\Renci.SshNet\v4.0_10.0.0.0__31bf3856ad364e35\Renci.SshNet.dll so that it does not get used
$StreamSession=New-SSHShellStream -SSHSession $Session
#Change root password
$command = "sudo passwd root"
$StreamSession.WriteLine("$command")
Start-Sleep -Seconds 3
#pass in current password
$StreamSession.WriteLine([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($newPasswd)))
Start-Sleep -Seconds 3
#pass in current password
$StreamSession.WriteLine([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($newPasswd)))
Start-Sleep -Seconds 3
# Clear buffer, should see "password updated" message
$StreamSession.Read()


echo "Copying $outputFile to $Server"


Set-SCPItem -ComputerName $Server -Path $FileName -Destination "/home/$usernamelower" -Credential $UserCred -AcceptKey -ConnectionTimeout 120
#Set-SCPItem -ComputerName $Server -Path D:\Software\RPM-GPG-KEY-CyberArk -Destination "/home/$usernamelower" -Credential $UserCred -AcceptKey -ConnectionTimeout 60
#Invoke-SSHCommand -SSHSession $Session -Command "sudo rpm --import ~/RPM-GPG-KEY-CyberArk"
$LinuxUser=$usernamelower


#New Dir
Invoke-SSHCommand -SSHSession $Session -Command "mkdir -p ~/$FileNameNoExten"

#unzip new files

Invoke-SSHCommand -SSHSession $Session -Command "unzip -o ~/$outputFile -d ~/$FileNameNoExten" -ShowStandardOutputStream



#create Cred File
Invoke-SSHCommand -SSHSession $Session -Command "chmod +x ~/$FileNameNoExten/CreateCredFile"
Invoke-SSHCommand -SSHSession $Session -Command "~/$FileNameNoExten/CreateCredFile ~/$FileNameNoExten/user.cred password -username administrator -password $AdminPass -entropyfile" -ShowStandardOutputStream


Invoke-SSHCommand -SSHSession $Session -Command "sed -i 's/<Folder Path>/\/home\/$LinuxUser\/$FilenameNoDotZip/g' ~/$FileNameNoExten/psmpparms.sample"
Invoke-SSHCommand -SSHSession $Session -Command "sed -i 's/AcceptCyberArkEULA=No/AcceptCyberArkEULA=Yes/g' ~/$FileNameNoExten/psmpparms.sample"
Invoke-SSHCommand -SSHSession $Session -Command "sed -i 's/1.1.1.1/$VaultIPs/g' ~/$FileNameNoExten/vault.ini"


#move psmpparms file to correct location

Invoke-SSHCommand -SSHSession $Session -Command "yes | sudo cp -rf ~/$FileNameNoExten/psmpparms.sample /var/tmp/psmpparms"

#Upgrade PSMP using sudo
Invoke-SSHCommand -SSHSession $Session -Command "sudo rpm -Uvh ~/$FileNameNoExten/$CARK_Version" -ShowStandardOutputStream -TimeOut 360

Invoke-SSHCommand -SSHSession $Session -Command "sudo sed -i 's/#Subsystem/Subsystem/g' /etc/ssh/sshd_config"

Invoke-SSHCommand -SSHSession $Session -Command "sudo systemctl enable psmpsrv"

Invoke-SSHCommand -SSHSession $Session -Command "rm -rf ~/$FileNameNoExten"

$reboot="sudo reboot"
$StreamSession.WriteLine("$reboot")
}
