
$Servers = @(

"Server1"
"Server2"
"Server3"
"Server4"
"Server5"
#>
)

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

foreach ($Server in $Servers){
$Session = New-PSSession -ComputerName $Server

Copy-Item "$FileName" -Destination "C:\" -ToSession $Session -Force

Invoke-Command -Session $Session -ScriptBlock {Set-Location -Path cert:\localMachine\my}

Invoke-Command -Session $Session -ScriptBlock {Import-PfxCertificate -FilePath "C:\$Using:outputFile" -Password $Using:cred}

Invoke-Command -Session $Session -ScriptBlock {$tsgs = gwmi -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'"}

Invoke-Command -Session $Session -ScriptBlock {swmi -path $tsgs.__path -argument @{SSLCertificateSHA1Hash="$($Using:CertThumbPrint)"}}

Invoke-Command -Session $Session -ScriptBlock {Remove-Item "C:\$Using:outputFile"}


}