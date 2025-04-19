
$Servers = @(
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
)

Get-Date

$filesInfo = foreach ($Server in $Servers) {
    $Session = New-PSSession -ComputerName $Server

    Invoke-Command -Session $Session -ScriptBlock {
        $directoryPath = "C:\Program Files (x86)\CyberArk\PSM\CAPSM.exe" # Replace with the path to your directory

        $files = Get-ChildItem -Path $directoryPath

        if ($files) {
            foreach ($file in $files) {
                $fileVersion = $file.VersionInfo.FileVersion
                $fileProduct = $file.VersionInfo.ProductName

                [PSCustomObject]@{
                    Product = $fileProduct
                    Version = $fileVersion
                }
            }
        } else {
            [PSCustomObject]@{
                Server = $env:COMPUTERNAME
                FileName = "No files found in the directory."
                Version = ""
                Product = ""
            }
        }
    } | select * -exclude RunspaceID
}

$filesInfo | Format-Table -AutoSize
