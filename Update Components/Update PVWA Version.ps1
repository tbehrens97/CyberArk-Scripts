#Be sure to place the PVWA zip in your Desktop folder
echo "Verify that the PVWA zip placed in the Desktop folder of the user that will be running the script!"

$PVWAVersion=Read-Host "Version of PVWA that will be deployed"

$AdminPass=Read-Host "Administrator Password" -AsSecureString

Unblock-File -Path "C:\users\$env:UserName\Desktop\Password Vault Web Access-Rls-v$PVWAVersion.zip"

Expand-Archive -Path "C:\users\$env:UserName\Desktop\Password Vault Web Access-Rls-v$PVWAVersion.zip"  -DestinationPath "C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion" -Force

##########################
$isUpgrade = "True"
##########################
$file = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml
$file | % { $_.Replace("false", $isUpgrade) } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml

$file = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml
$file | % { $_.Replace('<Parameter Name="isUpgrade" Value="false"/>', '<Parameter Name="isUpgrade" Value="true"/>') } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml


#Replace Default Username in Config File with Correct Username
##########################
$ConfigUsername = "ComanyName_Here"
##########################
$file1 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml
$file1 | % { $_.Replace("Windows User", $ConfigUsername) } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml


#Replace Default Company in Config File with Correct Company
##########################
$ConfigCompnay = "ComanyName_Here"
##########################
$file2 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml
$file2 | % { $_.Replace("My Company", $ConfigCompnay) } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml


##########################
$ConfigLocation = "C:\CyberArk\Password Vault Web Access\"
##########################
$file3 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml
$file3 | % { $_.Replace("C:\CyberArk\Password Vault Web Access\", $ConfigLocation) } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml

$file3 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml
$file3 | % { $_.Replace('<Parameter Name="configFilesPath" Value="C:\CyberArk\Password Vault Web Access"/>', '<Parameter Name="configFilesPath" Value="D:\CyberArk\Password Vault Web Access"/>') } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml


##########################
$Logon = "CyberArk;SAML"
##########################
$file4 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml
$file4 | % { $_.Replace("CyberArk;", $Logon) } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml

$file4 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml
$file4 | % { $_.Replace("CyberArk;", $Logon) } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml


##########################
$URL = "https://PVWA.domain.local/PasswordVault"
##########################
$file5 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml
$file5 | % { $_.Replace("https://127.0.0.1/PasswordVault", $URL) } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation\InstallationConfig.xml

$file5 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml
$file5 | % { $_.Replace("https://127.0.0.1/PasswordVault", $URL) } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml


##########################
$VaultIP="192.168.1.1,192.168.1.2"
##########################
$file6 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml
$file6 | % { $_.Replace("10.10.10.10", $VaultIP) } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml



#Hardening

##########################

##########################
$file6 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\PVWA_Hardening_Config.xml
$file6 | % { $_.Replace('ScriptName="PVWA_IIS_Registry_Shares.psm1" Enable="Yes"', 'ScriptName="PVWA_IIS_Registry_Shares.psm1" Enable="No"') } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\PVWA_Hardening_Config.xml

$file7 = Get-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\PVWA_Hardening_Config.xml
$file7 | % { $_.Replace('ScriptName="PVWA_PostInstallation.psm1"  Enable="Yes"', 'ScriptName="PVWA_PostInstallation.psm1"  Enable="No"') } | Set-Content C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\PVWA_Hardening_Config.xml


Compress-Archive -Path "C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\*" -DestinationPath "C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion.zip" -Force



 
$Servers = @(
"Server1"
"Server2"
"Server3"
"Server4"
)

foreach ($Server in $Servers){

Write-Host "Script running on $Server at" (Get-Date).ToString('hh:mm:ss tt') -ForegroundColor Black -BackgroundColor Magenta

$Session= New-PSSession -ComputerName $Server

Invoke-Command -Session $Session -ScriptBlock {iisreset /stop}

Invoke-Command -Session $Session -ScriptBlock {iisreset /stop}

Copy-Item "C:\Users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion.zip" -Destination "\\$server\C$\Users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion.zip" -Force

Invoke-Command -Session $Session -ScriptBlock {$PVWAVersion=$Using:PVWAVersion}

Invoke-Command -Session $Session -ScriptBlock {Expand-Archive -Path "C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion.zip"  -DestinationPath "C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion" -Force}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Installation"}

Invoke-Command -Session $Session -ScriptBlock {.\PVWAInstallation.ps1}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\Registration"}

Invoke-Command -Session $Session -ScriptBlock {.\PVWARegisterComponent.ps1 -spwdObj $Using:AdminPass}

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation"}

Invoke-Command -Session $Session -ScriptBlock {.\PVWA_Hardening.ps1}
<#
#Create folder for PVWA Version

$Folder = "D:\Scripts\Update PVWA Output\$PVWAVersion"
#"Test to see if folder [$Folder]  exists"
if (Test-Path -Path $Folder) {
    #do nothing
} else {
#Create Folder
(New-Item -Path "D:\Scripts\Update PVWA Output" -Name "$PVWAVersion" -ItemType "directory")
}

#Create folder per PVWA Server

$Folder = "D:\Scripts\Update PVWA Output\$PVWAVersion\$Server"
#"Test to see if folder [$Folder]  exists"
if (Test-Path -Path $Folder) {
    #do nothing
} else {
#Create Folder
(New-Item -Path "D:\Scripts\Update PVWA Output\$PVWAVersion" -Name "$Server" -ItemType "directory")
}

Copy-Item "\\$server\C$\Users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion\InstallationAutomation\*" -Destination "D:\Scripts\Update PVWA Output\$PVWAVersion\$Server" -Recurse -Force 
#>
start-sleep 5

Invoke-Command -Session $Session -ScriptBlock {Restart-Computer -Force}

}

Echo "Waiting 3min to delete files from PVWA Servers"

start-sleep 180

foreach ($Server in $Servers){

#Delete all the files
$Session= New-PSSession -ComputerName $Server

Write-Host "Deleting files on $Server" -ForegroundColor Black -BackgroundColor Magenta

Invoke-Command -Session $Session -ScriptBlock {$PVWAVersion=$Using:PVWAVersion}

Invoke-Command -Session $Session -ScriptBlock {Remove-Item "C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion" -Force -Recurse}

Invoke-Command -Session $Session -ScriptBlock {Remove-Item "C:\users\$env:UserName\Desktop\PasswordVaultWebAccess-Rls-v$PVWAVersion.zip" -Force -Recurse}

}
