clear


function Get-FileName($initialDirectory)
{   
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
    Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "PSM Zip (*.zip)| Privileged Session Manager-Rls-v*.zip"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

#Gets the whole Path #C:\Users\UserName\Desktop\Privileged Access Manager Self-Hosted_14.4_1738004326579\Privileged Session Manager\Privileged Session Manager-Rls-v14.4.zip
$FileName=Get-FileName

#Get Administrator Password
$AdminPass=Read-Host "Administrator Password" -AsSecureString

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






#get just file name with extension #Privileged Session Manager-Rls-v14.4.zip
$outputFile = Split-Path $FileName -leaf


#Privileged Session Manager-Rls-v14.4
$FilenameNoDotZip=([io.fileinfo]"$FileName").basename


#Gets The full path without .zip C:\Users\UserName\Desktop\PrivilegedSessionManagerSSHProxy-RHELinux8-Intel64-Rls-v14.4
$FileNameBase= $resultPath


Copy-Item -Path "$FileName" -Destination "$FileName-ORG.zip" -Force
Expand-Archive -Path "$FileName" -DestinationPath "$FileNameBase" -Force
Remove-Item -Path "$FileName" -Force


#Replace Default Username in Config File with Correct Username
##########################
$ConfigUsername = "ComanyName_Here"
##########################
$file = Get-Content "$FileNameBase\InstallationAutomation\Installation\InstallationConfig.xml"
$file | % { $_.Replace("Windows User", "$ConfigUsername") } | Set-Content "$FileNameBase\InstallationAutomation\Installation\InstallationConfig.xml"


#Replace Default Company in Config File with Correct Company
##########################
$ConfigCompnay = "ComanyName_Here"
##########################
$file = Get-Content "$FileNameBase\InstallationAutomation\Installation\InstallationConfig.xml"
$file | % { $_.Replace("Windows User", "$ConfigCompnay") } | Set-Content "$FileNameBase\InstallationAutomation\Installation\InstallationConfig.xml"


##########################
$ConfigLocation = "C:\Program Files (x86)\CyberArk"
##########################
$file = Get-Content "$FileNameBase\InstallationAutomation\Installation\InstallationConfig.xml"
$file | % { $_.Replace("C:\Program Files (x86)\CyberArk", "$ConfigLocation") } | Set-Content "$FileNameBase\InstallationAutomation\Installation\InstallationConfig.xml"


##########################
$ConfigLocationRecording = "C:\Program Files (x86)\CyberArk\PSM\Recordings"
##########################
$file = Get-Content "$FileNameBase\InstallationAutomation\Installation\InstallationConfig.xml"
$file | % { $_.Replace("C:\Program Files (x86)\CyberArk\PSM\Recordings", "$ConfigLocationRecording") } | Set-Content "$FileNameBase\InstallationAutomation\Installation\InstallationConfig.xml"





##########################
$WinCertificate = '"ReduceWinCertificateWaitTime.psm1" Enable="Yes"'
##########################
$file1 = Get-Content "$FileNameBase\InstallationAutomation\PostInstallation\PostInstallationConfig.xml"
$file1 | % { $_.Replace('"ReduceWinCertificateWaitTime.psm1" Enable="No"', "$WinCertificate") } | Set-Content "$FileNameBase\InstallationAutomation\PostInstallation\PostInstallationConfig.xml"



#We run it on a diffrent step
##########################
$RunAppLocker = 'ScriptName="SetupAppLockerRules.psm1"  Enable="No"'
##########################
$file2 = Get-Content "$FileNameBase\InstallationAutomation\Hardening\HardeningConfig.xml"
$file2 | % { $_.Replace('ScriptName="SetupAppLockerRules.psm1"  Enable="Yes"', "$RunAppLocker") } | Set-Content "$FileNameBase\InstallationAutomation\Hardening\HardeningConfig.xml"

#We run it on a diffrent step
##########################
$RunHardening = 'ScriptName="RunTheHardeningScript.psm1"  Enable="No"'
##########################
$file2 = Get-Content "$FileNameBase\InstallationAutomation\Hardening\HardeningConfig.xml"
$file2 | % { $_.Replace('ScriptName="RunTheHardeningScript.psm1"  Enable="Yes"', "$RunHardening") } | Set-Content "$FileNameBase\InstallationAutomation\Hardening\HardeningConfig.xml"


##########################
$VaultIP = '"vaultip" Value="192.168.1.1,192.168.1.2"'
##########################
$file3 = Get-Content "$FileNameBase\InstallationAutomation\Registration\RegistrationConfig.xml"
$file3 | % { $_.Replace('"vaultip" Value="1.1.1.1"', "$VaultIP") } | Set-Content "$FileNameBase\InstallationAutomation\Registration\RegistrationConfig.xml"


##########################
$EULA = '"accepteula" Value="Yes"'
##########################
$file3 = Get-Content "$FileNameBase\InstallationAutomation\Registration\RegistrationConfig.xml"
$file3 | % { $_.Replace('"accepteula" Value="no"', "$EULA") } | Set-Content "$FileNameBase\InstallationAutomation\Registration\RegistrationConfig.xml"



##########################
$PVWAAPI = '"apigwhost" Value="PVWA.domain.local"'
##########################
$file3 = Get-Content "$FileNameBase\InstallationAutomation\Registration\RegistrationConfig.xml"
$file3 | % { $_.Replace('"apigwhost" Value=""', "$PVWAAPI") } | Set-Content "$FileNameBase\InstallationAutomation\Registration\RegistrationConfig.xml"



Compress-Archive -Path "$FileNameBase\*" -DestinationPath "$FileNameBase.zip" -Force


$ActiveServers = @(

"Server1"
"Server2"
"Server3"
"Server4"


)



foreach ($Server in $ActiveServers){

Write-Host "Script running on $Server at" (Get-Date).ToString('hh:mm:ss tt') -ForegroundColor Black -BackgroundColor Magenta

$Session= New-PSSession -ComputerName $Server

$AppLockerArchive=Invoke-Command -Session $Session -ScriptBlock {$Folder = "C:\Program Files (x86)\CyberArk\PSM\Hardening\AppLockerArchive"}

#Create Folder AppLockerArchive if one does not exist
Invoke-Command -Session $Session -ScriptBlock {if (Test-Path -Path $Folder){}Else{[void](New-Item -Path "C:\Program Files (x86)\CyberArk\PSM\Hardening" -Name "AppLockerArchive" -ItemType "directory" -Force)}}

#move org xml file to archive and date it 
Invoke-Command -Session $Session -ScriptBlock {$CurrentDay=Get-Date -Format yyyy-MM-dd}
Invoke-Command -Session $Session -ScriptBlock {Copy-Item "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMConfigureAppLocker.xml" -Destination "C:\Program Files (x86)\CyberArk\PSM\Hardening\AppLockerArchive\PSMConfigureAppLocker_$CurrentDay.xml" -Force}

echo "Copying $outputFile to $Server"

Copy-Item "$FileName" -Destination "\\$server\C$\Users\$env:UserName\Desktop\$outputFile" -Force

Invoke-Command -Session $Session -ScriptBlock {$outputFile=$Using:outputFile}

Invoke-Command -Session $Session -ScriptBlock {$FilenameNoDotZip=$Using:FilenameNoDotZip}

Invoke-Command -Session $Session -ScriptBlock {Expand-Archive -Path "C:\users\$env:UserName\Desktop\$outputFile"  -DestinationPath "C:\users\$env:UserName\Desktop\$FilenameNoDotZip" -Force}

Invoke-Command -Session $Session -ScriptBlock {Stop-Service -DisplayName "CyberArk*"}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\users\$env:UserName\Desktop\$FilenameNoDotZip\InstallationAutomation"}

Invoke-Command -Session $Session -ScriptBlock {.\Execute-Stage.ps1 .\Installation\InstallationConfig.XML silent -modeOfOperation Upgrade}
#wait 6 min. #the above command restarts the computer
Write-Host "$server restarted at" (Get-Date).ToString('hh:mm:ss tt') -ForegroundColor Black -BackgroundColor Magenta
Start-Sleep 360

$Session= New-PSSession -ComputerName $Server

Invoke-Command -Session $Session -ScriptBlock {$outputFile=$Using:outputFile}

Invoke-Command -Session $Session -ScriptBlock {$FilenameNoDotZip=$Using:FilenameNoDotZip}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\users\$env:UserName\Desktop\$FilenameNoDotZip\InstallationAutomation"}

Write-Host "Running PostInstallation and HardeningConfig on $server at" (Get-Date).ToString('hh:mm:ss tt') -ForegroundColor Black -BackgroundColor Magenta

Invoke-Command -Session $Session -ScriptBlock {.\Execute-Stage.ps1 .\PostInstallation\PostInstallationConfig.XML}

Invoke-Command -Session $Session -ScriptBlock {.\Execute-Stage.ps1 .\Hardening\HardeningConfig.XML}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Program Files (x86)\CyberArk\PSM\Hardening"}

#Set more Variables Fix the Default PSMHardening.ps1 and PSMConfigureAppLocker.ps1

Invoke-Command -Session $Session -ScriptBlock {
##########################
$SupportWebApp = '$SUPPORT_WEB_APPLICATIONS          = $true'
##########################
$file3 = Get-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMHardening.ps1"
$file3 | % { $_.Replace('$SUPPORT_WEB_APPLICATIONS          = $false', "$SupportWebApp") } | Set-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMHardening.ps1"

##########################
$DomainPSMUser = '$Global:PSM_CONNECT_USER           = "Domain\PSMConnect"'
##########################
$file3 = Get-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMHardening.ps1"
$file3 | % { $_.Replace('$Global:PSM_CONNECT_USER           = "$COMPUTER\PSMConnect"', "$DomainPSMUser") } | Set-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMHardening.ps1"

##########################
$DomainAdminPSMUser = '$Global:PSM_ADMIN_CONNECT_USER     = "Domain\PSMAdminConnect"'
##########################
$file3 = Get-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMHardening.ps1"
$file3 | % { $_.Replace('$Global:PSM_ADMIN_CONNECT_USER     = "$COMPUTER\PSMAdminConnect"', "$DomainAdminPSMUser") } | Set-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMHardening.ps1"

##########################
$ShouldRemove = '			   $shouldRemove = "no"'
##########################
$file3 = Get-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMHardening.ps1"
$file3 | % { $_.Replace('			   $shouldRemove = read-host -prompt "Would you like to remove all members of this group? (yes/no)"', "$ShouldRemove") } | Set-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMHardening.ps1"


##########################
$DomainPSMUserAPP = '$Global:PSM_CONNECT                 = "Domain\PSMConnect"'
##########################
$file3 = Get-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMConfigureAppLocker.ps1"
$file3 | % { $_.Replace('$Global:PSM_CONNECT                 = "PSMConnect"', "$DomainPSMUserAPP") } | Set-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMConfigureAppLocker.ps1"

##########################
$DomainAdminPSMUserAPP = '$Global:PSM_ADMIN_CONNECT           = "Domain\PSMAdminConnect"'
##########################
$file3 = Get-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMConfigureAppLocker.ps1"
$file3 | % { $_.Replace('$Global:PSM_ADMIN_CONNECT           = "PSMAdminConnect"', "$DomainAdminPSMUserAPP") } | Set-Content "C:\Program Files (x86)\CyberArk\PSM\Hardening\PSMConfigureAppLocker.ps1"

}

Invoke-Command -Session $Session -ScriptBlock {.\PSMConfigureAppLocker.ps1}

Invoke-Command -Session $Session -ScriptBlock {.\PSMHardening.ps1}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\users\$env:UserName\Desktop\$FilenameNoDotZip\InstallationAutomation"}

Write-Host "Running RegistrationConfig on $server at" (Get-Date).ToString('hh:mm:ss tt') -ForegroundColor Black -BackgroundColor Magenta

Invoke-Command -Session $Session -ScriptBlock {.\Execute-Stage.ps1 .\Registration\RegistrationConfig.XML -spwdObj $Using:AdminPass -modeOfOperation Upgrade}

<#
#Create folder for PSM Version

$Folder = "C:\Scripts\Update PSM Output\$FilenameNoDotZip"
#"Test to see if folder [$Folder]  exists"
if (Test-Path -Path $Folder) {
    #do nothing
} else {
#Create Folder
(New-Item -Path "C:\Scripts\Update PSM Output" -Name "$FilenameNoDotZip" -ItemType "directory")
}

#Create folder per PSM Server

$Folder = "C:\Scripts\Update PSM Output\$FilenameNoDotZip\$Server"
#"Test to see if folder [$Folder]  exists"
if (Test-Path -Path $Folder) {
    #do nothing
} else {
#Create Folder
(New-Item -Path "C:\Scripts\Update PSM Output\$FilenameNoDotZip" -Name "$Server" -ItemType "directory")
}

Copy-Item "\\$server\C$\users\$env:UserName\Desktop\$FilenameNoDotZip\InstallationAutomation\*" -Destination "C:\Scripts\Update PSM Output\$FilenameNoDotZip\$Server" -Recurse -Force 
#>
start-sleep 5


<#
#########PSM Health Check
#Copy dotnet-core-uninstall-1.7.550802.msi
Copy-Item "C:\Software\dotnet-core-uninstall-1.7.550802.msi" -Destination "\\$server\C$\dotnet-core-uninstall-1.7.550802.msi"
Echo "Running dotnet-core-uninstall"
Invoke-Command -Session $Session -ScriptBlock {
$MSI="C:\dotnet-core-uninstall-1.7.550802.msi"
Start-Process msiexec.exe -ArgumentList "/i $MSI /quiet /norestart" -Wait
Start-Sleep 5
Remove-Item $MSI
}


################
$NewDotNet="C:\Software\dotnet-hosting-8.0.14-win.exe"
################
$NewDotNetVersionNumber = ($NewDotNet -split '[^\d\.]+' | Where-Object { $_ -ne '' }) -join '.'
$NewDotNetVersionNumber = $NewDotNetVersionNumber.TrimEnd('.')
$exeDotNetFile = [System.IO.Path]::GetFileName($NewDotNet)

#Uninstall all old versions
Invoke-Command -Session $Session -ScriptBlock {
Set-Location "C:\Program Files (x86)\dotnet-core-uninstall\"
.\dotnet-core-uninstall.exe remove --hosting-bundle --all-below $Using:NewDotNetVersionNumber --yes
.\dotnet-core-uninstall.exe remove --aspnet-runtime --all-below $Using:NewDotNetVersionNumber --yes
.\dotnet-core-uninstall.exe remove --runtime --all-below $Using:NewDotNetVersionNumber --yes
Start-Sleep 5
}

#Copy New dotnet-hosting
Echo "Running dotnet-hosting install"
Copy-Item "$NewDotNet" -Destination "\\$server\C$\$exeDotNetFile"
Invoke-Command -Session $Session -ScriptBlock {
$installerPath = "C:\$Using:exeDotNetFile"
Start-Process -FilePath $installerPath -ArgumentList "/quiet /norestart" -Wait
Start-Sleep 5
Remove-Item $installerPath
iisreset
iisreset
}

#Start service if not started
Invoke-Command -Session $Session -ScriptBlock {
# Define the service name
$serviceName = "CyberArk*"

# Get the service status
$service = Get-Service -DisplayName $serviceName -ErrorAction SilentlyContinue

if ($service -eq $null) {
    Write-Output "Service '$serviceName' does not exist."
} elseif ($service.Status -ne 'Running') {
    Write-Output "Service '$serviceName' is not running. Attempting to start it..."
    Start-Service -DisplayName $serviceName
    if ((Get-Service -DisplayName $serviceName).Status -eq 'Running') {
        Write-Output "Service '$serviceName' started successfully."
    } else {
        Write-Output "Failed to start service '$serviceName'."
    }
} else {
    Write-Output "Service '$serviceName' is already running."
}

}

#Health Check script
Copy-Item "C:\Software\HealthCheck-v1.5.zip" -Destination "\\$server\C$\HealthCheck-v1.5.zip"
Invoke-Command -Session $Session -ScriptBlock {
Expand-Archive -Path "C:\HealthCheck-v1.5.zip" -DestinationPath "C:\PSMHealthCheck" -Force
Set-Location C:\PSMHealthCheck
./HealthCheck.ps1 -scriptMode Uninstall -installPath "C:\Program Files (x86)\CyberArk\PSM"
./HealthCheck.ps1 -installPath "C:\Program Files (x86)\CyberArk\PSM"
Remove-Item "C:\HealthCheck-v1.5.zip" -Force -Recurse
}
Start-Sleep 5

#enable Admin Shares if its disabled
Invoke-Command -Session $Session -ScriptBlock {Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\LanmanServer\Parameters -Name "AutoShareServer" -Value 1}
echo "$Server AutoShareServer has been updated to 1"

Invoke-Command -Session $Session -ScriptBlock {Restart-Computer -Force}

}
#>

Write-Host "Waiting 3min to delete files from PSM Servers" (Get-Date).ToString('hh:mm:ss tt') -ForegroundColor Black -BackgroundColor Magenta

start-sleep 180

foreach ($Server in $ActiveServers){
#Delete all the files
$Session= New-PSSession -ComputerName $Server


Write-Host "Deleting files on $Server" -ForegroundColor Black -BackgroundColor Magenta

Invoke-Command -Session $Session -ScriptBlock {$FilenameNoDotZip=$Using:FilenameNoDotZip}

Invoke-Command -Session $Session -ScriptBlock {$outputFile=$Using:outputFile}

Invoke-Command -Session $Session -ScriptBlock {Remove-Item "C:\users\$env:UserName\Desktop\$FilenameNoDotZip\" -Force -Recurse}

Invoke-Command -Session $Session -ScriptBlock {Remove-Item "C:\users\$env:UserName\Desktop\$outputFile" -Force -Recurse}

Invoke-Command -Session $Session -ScriptBlock {Remove-Item "C:\PSMHealthCheck" -Force -Recurse}

}


Copy-Item -Path "$FileName-ORG.zip" -Destination "$FileName" -Force
#Remove Extraced Zip
Remove-Item $FileNameBase -Force -Recurse

Remove-Item "$FileName-ORG.zip" -Force
