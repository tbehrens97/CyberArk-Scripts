
function Get-FileName($initialDirectory)
{   
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
    Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "PFX files (*.pfx)| *.pfx"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}


$FileName=Get-FileName

#get just file name with extension
$outputPath = $FileName
$outputFile = Split-Path $outputPath -leaf

#Get Cert password
$cred=Read-Host "Enter The Certificate Password" -AsSecureString

$CertData=Get-PfxData -FilePath $outputPath -Password $cred

$CertThumb=$CertData.EndEntityCertificates | select Thumbprint
#Cert thumprint
$CertThumbPrint=$CertThumb.Thumbprint


Set-Location -Path cert:\localMachine\my

Import-PfxCertificate -FilePath "C:\$outputFile" -Password $cred

Import-Module WebAdministration

Remove-Item -path 'IIS:\SslBindings\0.0.0.0!443' -Force

Get-Item "Cert:\LocalMachine\My\$Using:CertThumbPrint" | New-Item -path 'IIS:\SslBindings\0.0.0.0!443' -Force

iisreset