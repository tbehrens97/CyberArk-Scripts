#Created by Trevor Behrens June 2024



$UserCred=Get-Credential -credential $Env:UserName

function Get-FileName($initialDirectory)
{   
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
    Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "PSMP Zip (*.zip)| PrivilegedSessionManagerSSHProxy*.zip"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

#Gets the whole Path
$FileName=Get-FileName

#get just file name with extension
$outputPath = $FileName
$outputFile = Split-Path $outputPath -leaf

$FilenameNoDotZip=([io.fileinfo]"$FileName").basename

#read Zip folder to get RPM CARK Version file
Add-Type -assembly "system.io.compression.filesystem"

$CARK_Version=[io.compression.zipfile]::OpenRead("$FileName").Entries.Name | Select-String CARKpsmp

if($CARK_Version -eq $null){
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


#Gets The full path without .zip C:\Users\T1ADM-CyberArk08\Desktop\PrivilegedSessionManagerSSHProxy-RHELinux8-Intel64-Rls-v14.4
$FileNameBase= $resultPath

#lowercase Username
$usernamelower=$UserCred.UserName.ToLower()


#####Edit me if needed!
$VaultIPs='X.X.X.X,Y.Y.Y.Y'




$FileNameNoExten=[io.path]::GetFileNameWithoutExtension($outputPath)

#new password for root
#$newPasswd = Read-Host -Prompt "New Password for root" -AsSecureString

#CyberArk Administrator password
$AdminUserCred=Get-Credential -credential Administrator
$AdminBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminUserCred.Password)
$AdminPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($AdminBSTR)

$ActiveServers = @(
<#
"PSMP.domain.local"
"PSMP2.domain.local"
#>

)

$ErrorActionPreference = "Stop"



foreach ($Server in $ActiveServers){

#Vaildate that the user has a home folder on the server
$Session=New-SSHSession -ComputerName $Server -Credential $UserCred -AcceptKey -ConnectionTimeout 120
Invoke-SSHCommand -SSHSession $Session -Command "echo Hello World"

Write-Host "Deleting logs this may take some time"  (Get-Date).ToString('hh:mm:ss tt') -ForegroundColor Black -BackgroundColor Magenta

Invoke-SSHCommand -SSHSession $Session -Command "sudo systemctl stop psmpsrv"

Invoke-SSHCommand -SSHSession $Session -Command "sudo rm -rf /var/opt/CARKpsmp/logs/*"

Invoke-SSHCommand -SSHSession $Session -Command "sudo find /var/tmp -name 'PrivateArkEx*' -type d -mtime +2 -print -exec rm -r {} + -depth" -TimeOut 360


#For this to work you may have to "rename" C:\Windows\Microsoft.NET\assembly\GAC_64\Renci.SshNet\v4.0_10.0.0.0__31bf3856ad364e35\Renci.SshNet.dll so that it does not get used
$StreamSession=New-SSHShellStream -SSHSession $Session
<#
#Change root password
$command = "sudo passwd root"
$StreamSession.WriteLine("$command")
Start-Sleep -Seconds 7
#pass in current password
$StreamSession.WriteLine([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($newPasswd)))
Start-Sleep -Seconds 3
#pass in current password
$StreamSession.WriteLine([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($newPasswd)))
Start-Sleep -Seconds 3
# Clear buffer, should see "password updated" message
$StreamSession.Read()
#>

echo "Copying $outputFile to $Server"


Set-SCPItem -ComputerName $Server -Path $FileName -Destination "/home/$usernamelower" -Credential $UserCred -AcceptKey
#Set-SCPItem -ComputerName $Server -Path D:\Software\RPM-GPG-KEY-CyberArk -Destination "/home/$usernamelower" -Credential $UserCred -AcceptKey
#Invoke-SSHCommand -SSHSession $Session -Command "sudo rpm --import RPM-GPG-KEY-CyberArk"
$LinuxUser=$usernamelower


#New Dir
Invoke-SSHCommand -SSHSession $Session -Command "mkdir -p ~/$FileNameNoExten"

#unzip new files

Invoke-SSHCommand -SSHSession $Session -Command "unzip -o ~/$outputFile -d ~/$FileNameNoExten" -ShowStandardOutputStream



#create Cred File
#Invoke-SSHCommand -SSHSession $Session -Command "chmod +x ~/$FileNameNoExten/CreateCredFile"
#Invoke-SSHCommand -SSHSession $Session -Command "~/$FileNameNoExten/CreateCredFile ~/$FileNameNoExten/user.cred password -username administrator -password $AdminPass -entropyfile" -ShowStandardOutputStream


#Invoke-SSHCommand -SSHSession $Session -Command "sed -i 's/<Folder Path>/\/home\/$LinuxUser\/$FilenameNoDotZip/g' ~/$FileNameNoExten/psmpparms.sample"
Invoke-SSHCommand -SSHSession $Session -Command "sed -i 's/AcceptCyberArkEULA=No/AcceptCyberArkEULA=Yes/g' ~/$FileNameNoExten/psmpparms.sample"

#Invoke-SSHCommand -SSHSession $Session -Command "sed -i 's/#UpdateCredFile=Inferred/UpdateCredFile=Yes/g' ~/$FileNameNoExten/psmpparms.sample" #Probably only needed once

#Invoke-SSHCommand -SSHSession $Session -Command "sed -i 's/#ADBridgeUpdateCredFile=Inferred/ADBridgeUpdateCredFile=Yes/g' ~/$FileNameNoExten/psmpparms.sample" #Probably only needed once

#Invoke-SSHCommand -SSHSession $Session -Command "sed -i 's/1.1.1.1/$VaultIPs/g' ~/$FileNameNoExten/vault.ini"

#update Hostname
#$shorthostname = $Server.Split(".")[0].ToLower()#Probably only needed once
#Invoke-SSHCommand -SSHSession $Session -Command "sudo hostnamectl set-hostname $shorthostname"#Probably only needed once
 
#move psmpparms file to correct location

Invoke-SSHCommand -SSHSession $Session -Command "yes | sudo cp -rf ~/$FileNameNoExten/psmpparms.sample /var/tmp/psmpparms"

#Upgrade PSMP using sudo
Invoke-SSHCommand -SSHSession $Session -Command "sudo rpm -Uvh ~/$FileNameNoExten/$CARK_Version" -ShowStandardOutputStream -TimeOut 360

Invoke-SSHCommand -SSHSession $Session -Command "sudo /opt/CARKpsmp/bin/createcredfile ~/$FileNameNoExten/user.cred password -username administrator -password $AdminPass -entropyfile" -ShowStandardOutputStream
<#
#Invoke-SSHCommand -SSHSession $Session -Command "sudo /opt/CARKpsmp/bin/createcredfile /etc/opt/CARKpsmp/vault/psmpappuser.cred password -username PSMPApp_$shorthostname -password $AdminPass -entropyfile" -ShowStandardOutputStream #Probably only needed once

#Invoke-SSHCommand -SSHSession $Session -Command "sudo /opt/CARKpsmp/bin/createcredfile /etc/opt/CARKpsmp/vault/psmpgwuser.cred password -username PSMPGW_$shorthostname -password $AdminPass -entropyfile" -ShowStandardOutputStream #Probably only needed once

#Invoke-SSHCommand -SSHSession $Session -Command "sudo /opt/CARKpsmp/bin/createcredfile /etc/opt/CARKpsmpadb/vault/psmpadbridgeserveruser.cred password -username PSMP_ADB_$shorthostname -password $AdminPass -entropyfile" -ShowStandardOutputStream #Probably only needed once

Invoke-SSHCommand -SSHSession $Session -Command "sudo rpm -Uvh --force ~/$FileNameNoExten/$CARK_Version" -ShowStandardOutputStream -TimeOut 360 #Probably only needed once

Start-Sleep 5

$reboot="sudo reboot"#Probably only needed once
$StreamSession.WriteLine("$reboot") #Probably only needed once

Start-Sleep 40

$Session=New-SSHSession -ComputerName $Server -Credential $UserCred -AcceptKey

Invoke-SSHCommand -SSHSession $Session -Command "sudo rpm -Uvh --force ~/$FileNameNoExten/$CARK_Version" -ShowStandardOutputStream -TimeOut 360 #Probably only needed once

#>

Invoke-SSHCommand -SSHSession $Session -Command "sudo /opt/CARKpsmp/bin/psmp_setup.sh --finalize --credfile ~/$FileNameNoExten/user.cred" -ShowStandardOutputStream -TimeOut 360

Invoke-SSHCommand -SSHSession $Session -Command "sudo rm -rf ~/$FileNameNoExten"

Invoke-SSHCommand -SSHSession $Session -Command "sudo rm -rf ~/$FileNameNoExten.zip"

Invoke-SSHCommand -SSHSession $Session -Command "sudo systemctl enable psmpsrv"

Invoke-SSHCommand -SSHSession $Session -Command "sudo sed -i 's/#Subsystem/Subsystem/g' /etc/ssh/sshd_config"

$StreamSession=New-SSHShellStream -SSHSession $Session

$reboot="sudo reboot"
$StreamSession.WriteLine("$reboot")
}