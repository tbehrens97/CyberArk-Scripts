
$Servers = @(

"PSMServer1"
"PSMServer2"
"PSMServer3"
"PSMServer4"
)


$CPMServers = @(
#CPM
"CPMServer1"
"CPMServer2"
"CPMServer3"
)


function cut {
  param(
    [Parameter(ValueFromPipeline=$True)] [string]$inputobject,
    [string]$delimiter='\s+',
    [string[]]$field
  )

  process {
    if ($field -eq $null) { $inputobject -split $delimiter } else {
      ($inputobject -split $delimiter)[$field] }
  }
}
#current day
$CurrentDay=Get-Date -Format yyyy-MM-dd

#For every server listed above check chrome version and edge driver if diffrent download correct version
foreach ($Server in $Servers){

$Session= New-PSSession -ComputerName $Server

$EdgeVersion=Invoke-Command -Session $Session -ScriptBlock {(Get-Item (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe').'(Default)').VersionInfo}

$version=$EdgeVersion.ProductVersion

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Program Files (x86)\CyberArk\PSM\Components"}

$WebDriverVersion=Invoke-Command -Session $Session -ScriptBlock {msedgedriver.exe /v} | cut -f 3 -d " "

if($WebDriverVersion -eq $null){
$WebDriverVersion=1
}

#echo $version

#echo $WebDriverVersion


if ($version -eq $WebDriverVersion){
#Do nothing
Echo "$Server already has a matching webdriver version (Webdriver version is $WebDriverVersion and Edge version is $version)"
}

else{
Try{
Echo "$Server has webdriver version $WebDriverVersion but edge version is $version"
Echo "Downloading latest Webdriver version to match Edge"
#Download the correct Edge Driver
Invoke-WebRequest -uri https://msedgedriver.azureedge.net/$version/edgedriver_win32.zip -OutFile C:\users\$env:UserName\downloads\Edge_Driver\edgedriver_win32$Server.zip #-Proxy "Proxy.domain.local"
}
Catch{
Echo "Can not connect to internet to download webdriver"
}
Expand-Archive -Path "C:\users\$env:UserName\downloads\Edge_Driver\edgedriver_win32$Server.zip"  -DestinationPath "C:\users\$env:UserName\downloads\Edge_Driver\edgedriver_win32$Server" -Force 

Echo "Copying Webdriver to $Server"

Copy-Item "C:\users\$env:UserName\downloads\Edge_Driver\edgedriver_win32$Server\msedgedriver.exe" -Destination "\\$server\D$\Program Files (x86)\CyberArk\PSM\Components\msedgedriver.exe" -Force 

#Rerun Applocker should not be needed
<#
Invoke-Command -Session $Session -ScriptBlock {import-module AppLocker}

Copy-Item "C:\Scripts\clear.xml" -Destination "\\$server\D$\clear.xml" -Force 

Echo "Clearing applocker rules from $Server"

Invoke-Command -Session $Session -ScriptBlock {Set-AppLockerPolicy -XMLPolicy "C:\clear.xml"}

Remove-Item "\\$server\D$\clear.xml" -Force

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Program Files (x86)\CyberArk\PSM\Hardening"}
Invoke-Command -Session $Session -ScriptBlock {.\PSMConfigureAppLocker.ps1 -dllblacklist}
#>
#check Version Match Again

$EdgeVersion=Invoke-Command -Session $Session -ScriptBlock {(Get-Item (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe').'(Default)').VersionInfo}

$version=$EdgeVersion.ProductVersion

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Program Files (x86)\CyberArk\PSM\Components"}

$WebDriverVersion=Invoke-Command -Session $Session -ScriptBlock {msedgedriver.exe /v} | cut -f 3 -d " "

Echo "$Server has been updated and should now have a matching webdriver version (Webdriver version is $WebDriverVersion and Edge version is $version)"


}

}



foreach ($Server in $CPMServers){

$Session= New-PSSession -ComputerName $Server

$EdgeVersion=Invoke-Command -Session $Session -ScriptBlock {(Get-Item (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe').'(Default)').VersionInfo}

$version=$EdgeVersion.ProductVersion

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Program Files (x86)\CyberArk\Password Manager\bin"}

$WebDriverVersion=Invoke-Command -Session $Session -ScriptBlock {./msedgedriver.exe /v} | cut -f 3 -d " "

#echo $version

#echo $WebDriverVersion


if ($version -eq $WebDriverVersion){
#Do nothing
Echo "$Server already has a matching webdriver version (Webdriver version is $WebDriverVersion and Edge version is $version)"
}

else{
Try{
Echo "$Server has webdriver version $WebDriverVersion but edge version is $version"
Echo "Downloading latest Webdriver version to match Edge"
#Download the correct Edge Driver
Invoke-WebRequest -uri https://msedgedriver.azureedge.net/$version/edgedriver_win32.zip -OutFile C:\users\$env:UserName\downloads\Edge_Driver\edgedriver_win32$Server.zip -Proxy http://zscaler.nationalgrid.com
}
Catch{
Echo "Can not connect to internet to download webdriver"
}
Expand-Archive -Path "C:\users\$env:UserName\downloads\Edge_Driver\edgedriver_win32$Server.zip"  -DestinationPath "C:\users\$env:UserName\downloads\Edge_Driver\edgedriver_win32$Server" -Force 

Echo "Copying Webdriver to $Server"

Copy-Item "C:\users\$env:UserName\downloads\Edge_Driver\edgedriver_win32$Server\msedgedriver.exe" -Destination "\\$server\D$\Program Files (x86)\CyberArk\Password Manager\bin\msedgedriver.exe" -Force 


$EdgeVersion=Invoke-Command -Session $Session -ScriptBlock {(Get-Item (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe').'(Default)').VersionInfo}

$version=$EdgeVersion.ProductVersion

Invoke-Command -Session $Session -ScriptBlock {Set-Location "C:\Program Files (x86)\CyberArk\Password Manager\bin"}

$WebDriverVersion=Invoke-Command -Session $Session -ScriptBlock {./msedgedriver.exe /v} | cut -f 3 -d " "

Echo "$Server has been updated and should now have a matching webdriver version (Webdriver version is $WebDriverVersion and Edge version is $version)"


}

}






Remove-Item "C:\users\$env:UserName\downloads\Edge_Driver\*" -Force -Recurse
