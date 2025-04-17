
#Be sure to place the CPM zip in your Desktop folder
Echo "Verify that the CPM zip placed in the Desktop folder of the user that will be running the script!"`n

$CPMVersion=Read-Host "Version of CPM that will be deployed"

$AdminPass=Read-Host "Administrator Password" -AsSecureString

Unblock-File -Path "C:\users\$env:UserName\Desktop\Central Policy Manager-Rls-v$CPMVersion.zip"

Expand-Archive -Path "C:\users\$env:UserName\Desktop\Central Policy Manager-Rls-v$CPMVersion.zip"  -DestinationPath "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion" -Force

##########################
$isUpgrade = "True"
##########################
$file = Get-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Installation\InstallationConfig.xml
$file | % { $_.Replace("false", $isUpgrade) } | Set-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Installation\InstallationConfig.xml

$file = Get-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml
$file | % { $_.Replace('"isUpgrade" Value = "false"', '"isUpgrade" Value = "True"') } | Set-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml


#Replace Default Username in Config File with Correct Username
##########################
$ConfigUsername = "CompanyName_Here"
##########################
$file1 = Get-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Installation\InstallationConfig.xml
$file1 | % { $_.Replace("Windows User", $ConfigUsername) } | Set-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Installation\InstallationConfig.xml


#Replace Default Company in Config File with Correct Company
##########################
$ConfigCompnay = "CompanyName_Here"
##########################
$file2 = Get-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Installation\InstallationConfig.xml
$file2 | % { $_.Replace("My Company", $ConfigCompnay) } | Set-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Installation\InstallationConfig.xml


##########################
$ConfigLocation = "C:\Program Files (x86)\CyberArk\"
##########################
$file3 = Get-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Installation\InstallationConfig.xml
$file3 | % { $_.Replace("C:\Program Files (x86)\CyberArk\", $ConfigLocation) } | Set-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Installation\InstallationConfig.xml

$file3 = Get-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml
$file3 | % { $_.Replace("C:\Program Files (x86)\CyberArk\", $ConfigLocation) } | Set-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml


##########################
$VaultIP="192.168.1.1"
##########################
$file4 = Get-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml
$file4 | % { $_.Replace("10.10.10.10", $VaultIP) } | Set-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml

##########################
$PM="PasswordTest"#Does not matter since this is an upgrade
##########################
$file5 = Get-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml
$file5 | % { $_.Replace("PasswordManager", $PM) } | Set-Content C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml

#In 12.2.8 the file is misspelled
$IsFileMisspelled=Test-Path -Path "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterCommponent.ps1"

If($IsFileMisspelled){
Rename-Item -Path "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterCommponent.ps1" -NewName "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration\CPMRegisterComponent.ps1" -Force
}


Compress-Archive -Path "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\*" -DestinationPath "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion.zip" -Force



 
$ActiveServers = @(
"ActiveCPMServer1"
"ActiveCPMServer2"
"ActiveCPMServer3"
"ActiveCPMServer4"
)

foreach ($Server in $ActiveServers){


$Session= New-PSSession -ComputerName $Server

Copy-Item "C:\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion.zip" -Destination "\\$server\C$\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion.zip" -Force

Invoke-Command -Session $Session -ScriptBlock {$CPMVersion=$Using:CPMVersion}

#Create Folder Archive if one does not exist


Invoke-Command -Session $Session -ScriptBlock {
$Folder = "D:\Program Files (x86)\CyberArk\Password Manager\bin\Archive"
    if (Test-Path -Path $Folder) {
        
    } else {
        New-Item -Path $Folder -ItemType "directory" -Force
        
    }
}

#move org xml file to archive and date it 
Invoke-Command -Session $Session -ScriptBlock {$CurrentDay=Get-Date -Format yyyy-MM-dd}
Invoke-Command -Session $Session -ScriptBlock {Copy-Item "D:\Program Files (x86)\CyberArk\Password Manager\bin\UnixProcess.ini" -Destination "D:\Program Files (x86)\CyberArk\Password Manager\bin\Archive\UnixProcess_$CurrentDay.ini" -Force}
Invoke-Command -Session $Session -ScriptBlock {Copy-Item "D:\Program Files (x86)\CyberArk\Password Manager\bin\UnixPrompts.ini" -Destination "D:\Program Files (x86)\CyberArk\Password Manager\bin\Archive\UnixPrompts_$CurrentDay.ini" -Force}





Invoke-Command -Session $Session -ScriptBlock {Expand-Archive -Path "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion.zip"  -DestinationPath "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion" -Force}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Installation"}

Invoke-Command -Session $Session -ScriptBlock {.\CPMInstallation.ps1}

#wait 6 min. #the above command restarts the computer
Write-Host "$server restarted at" (Get-Date).ToString('hh:mm:ss tt') -ForegroundColor Black -BackgroundColor Magenta
Start-Sleep 360

$Session= New-PSSession -ComputerName $Server

Invoke-Command -Session $Session -ScriptBlock {$CPMVersion=$Using:CPMVersion}

Invoke-Command -Session $Session -ScriptBlock {$CurrentDay=Get-Date -Format yyyy-MM-dd}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Registration"}

Invoke-Command -Session $Session -ScriptBlock {.\CPMRegisterComponent.ps1 -spwdObj $Using:AdminPass}

Invoke-Command -Session $Session -ScriptBlock {Copy-Item "D:\Program Files (x86)\CyberArk\Password Manager\bin\UnixProcess.ini" -Destination "D:\Program Files (x86)\CyberArk\Password Manager\bin\Archive\UnixProcess_ORG_$CPMVersion.ini" -Force}
Invoke-Command -Session $Session -ScriptBlock {Copy-Item "D:\Program Files (x86)\CyberArk\Password Manager\bin\UnixPrompts.ini" -Destination "D:\Program Files (x86)\CyberArk\Password Manager\bin\Archive\UnixPrompts_ORG_$CPMVersion.ini" -Force}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation"}

Invoke-Command -Session $Session -ScriptBlock {.\CPM_In_Domain_Hardening.ps1}

Invoke-Command -Session $Session -ScriptBlock {Copy-Item "D:\Program Files (x86)\CyberArk\Password Manager\bin\Archive\UnixProcess_$CurrentDay.ini" -Destination "D:\Program Files (x86)\CyberArk\Password Manager\bin\UnixProcess.ini" -Force}
Invoke-Command -Session $Session -ScriptBlock {Copy-Item "D:\Program Files (x86)\CyberArk\Password Manager\bin\Archive\UnixPrompts_$CurrentDay.ini" -Destination "D:\Program Files (x86)\CyberArk\Password Manager\bin\UnixPrompts.ini" -Force}


<#Uncomment if you push logs from the CPM to the machine you are running it on
$Folder = "D:\Scripts\Update CPM Output\$CPMVersion"
#"Test to see if folder [$Folder]  exists"
if (Test-Path -Path $Folder) {
    #do nothing
} else {
#Create Folder
(New-Item -Path "D:\Scripts\Update CPM Output" -Name "$CPMVersion" -ItemType "directory")
}

#Create folder per CPM Server

$Folder = "D:\Scripts\Update CPM Output\$CPMVersion\$Server"
#"Test to see if folder [$Folder]  exists"
if (Test-Path -Path $Folder) {
    #do nothing
} else {
#Create Folder
(New-Item -Path "D:\Scripts\Update CPM Output\$CPMVersion" -Name "$Server" -ItemType "directory")
}

Copy-Item "\\$server\C$\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\*" -Destination "D:\Scripts\Update CPM Output\$CPMVersion\$Server" -Recurse -Force 
#>
start-sleep 5

Invoke-Command -Session $Session -ScriptBlock {Restart-Computer -Force}

}

Echo "Waiting 3min to delete files from CPM Servers"

start-sleep 180

foreach ($Server in $ActiveServers){

#Delete all the files
$Session= New-PSSession -ComputerName $Server

Write-Host "Deleting files on $Server" -ForegroundColor Black -BackgroundColor Magenta

Invoke-Command -Session $Session -ScriptBlock {$CPMVersion=$Using:CPMVersion}

Invoke-Command -Session $Session -ScriptBlock {Remove-Item "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion" -Force -Recurse}

Invoke-Command -Session $Session -ScriptBlock {Remove-Item "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion.zip" -Force -Recurse}

}


# Does not Run CPM registration
$PassiveServers = @(
"PassiveCPMServer1"
"PassiveCPMServer2"
"PassiveCPMServer3"
"PassiveCPMServer4"
)

foreach ($Server in $PassiveServers){


$Session= New-PSSession -ComputerName $Server

Copy-Item "C:\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion.zip" -Destination "\\$server\C$\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion.zip" -Force

Invoke-Command -Session $Session -ScriptBlock {$CPMVersion=$Using:CPMVersion}

Invoke-Command -Session $Session -ScriptBlock {Expand-Archive -Path "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion.zip"  -DestinationPath "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion" -Force}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\Installation"}

Invoke-Command -Session $Session -ScriptBlock {.\CPMInstallation.ps1}

#wait 6 min. #the above command restarts the computer
Write-Host "$server restarted at" (Get-Date).ToString('hh:mm:ss tt') -ForegroundColor Black -BackgroundColor Magenta
Start-Sleep 360

$Session= New-PSSession -ComputerName $Server

Invoke-Command -Session $Session -ScriptBlock {$CPMVersion=$Using:CPMVersion}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation"}

Invoke-Command -Session $Session -ScriptBlock {.\CPM_In_Domain_Hardening.ps1}


Invoke-Command -Session $Session -ScriptBlock{Stop-Service -Name 'CyberArk Password Manager'}

Invoke-Command -Session $Session -ScriptBlock{Stop-Service -Name 'CyberArk Central Policy Manager Scanner'}


Invoke-Command -Session $Session -ScriptBlock{Set-Service -Name 'CyberArk Password Manager' -StartupType Manual}

Invoke-Command -Session $Session -ScriptBlock{Set-Service -Name 'CyberArk Central Policy Manager Scanner' -StartupType Manual}


<#Uncomment if you push logs from the CPM to the machine you are running it on
$Folder = "D:\Scripts\Update CPM Output\$CPMVersion"
#"Test to see if folder [$Folder]  exists"
if (Test-Path -Path $Folder) {
    #do nothing
} else {
#Create Folder
(New-Item -Path "D:\Scripts\Update CPM Output" -Name "$CPMVersion" -ItemType "directory")
}

#Create folder per CPM Server

$Folder = "D:\Scripts\Update CPM Output\$CPMVersion\$Server"
#"Test to see if folder [$Folder]  exists"
if (Test-Path -Path $Folder) {
    #do nothing
} else {
#Create Folder
(New-Item -Path "D:\Scripts\Update CPM Output\$CPMVersion" -Name "$Server" -ItemType "directory")
}

Copy-Item "\\$server\C$\Users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion\InstallationAutomation\*" -Destination "D:\Scripts\Update CPM Output\$CPMVersion\$Server" -Recurse -Force 
#>

Invoke-Command -Session $Session -ScriptBlock{Restart-Computer -Force}

}

Echo "Waiting 3min to delete files from CPM Servers"

start-sleep 180

foreach ($Server in $PassiveServers){

#Delete all the files
$Session= New-PSSession -ComputerName $Server

Write-Host "Deleting files on $Server" -ForegroundColor Black -BackgroundColor Magenta

Invoke-Command -Session $Session -ScriptBlock {$CPMVersion=$Using:CPMVersion}

Invoke-Command -Session $Session -ScriptBlock {Remove-Item "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion" -Force -Recurse}

Invoke-Command -Session $Session -ScriptBlock {Remove-Item "C:\users\$env:UserName\Desktop\CentralPolicyManager-Rls-v$CPMVersion.zip" -Force -Recurse}

}
