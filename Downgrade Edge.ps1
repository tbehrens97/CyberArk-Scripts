

$TargetEdgeVersion="133.0.3065.82"

$ActiveServers = @(
    #PSM
    "Server1-PSM"
    "Server2-PSM"
    "Server3-PSM"
    "Server4-PSM"

    #CPM
    "Server1-CPM"
    "Server2-CPM"
    "Server3-CPM"
)

foreach ($Server in $ActiveServers) {
    $Session = New-PSSession -ComputerName $Server
    $EdgeVersion = Invoke-Command -Session $Session -ScriptBlock {(Get-Item (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe').'(Default)').VersionInfo}

    if ($EdgeVersion.ProductVersion -gt $TargetEdgeVersion) {
        Echo "Copying Edge MSI to $Server"
        Copy-Item "C:\Users\$env:username\Desktop\MicrosoftEdgeEnterpriseX86.msi" -Destination "\\$server\C$\MicrosoftEdgeEnterpriseX86.msi"
        Invoke-Command -Session $Session -ScriptBlock {Get-Process "msedge" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue}
        echo "Running downgrade for Edge on $Server"
        start-sleep 2
        Invoke-Command -Session $Session -ScriptBlock {msiexec /I C:\MicrosoftEdgeEnterpriseX86.msi /qn ALLOWDOWNGRADE=1}
        start-sleep 2
        Invoke-Command -Session $Session -ScriptBlock {Remove-Item C:\MicrosoftEdgeEnterpriseX86.msi}
        Invoke-Command -Session $Session -ScriptBlock {$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate";$keyName = "RollbackToTargetVersion{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}";if (-not (Test-Path $registryPath)) {New-Item -Path $registryPath -Force};Set-ItemProperty -Path $registryPath -Name $keyName -Value 1}
        Invoke-Command -Session $Session -ScriptBlock {$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate";$keyName = "TargetVersionOverride{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}";if (-not (Test-Path $registryPath)) {New-Item -Path $registryPath -Force};$targetVersion = $Using:TargetEdgeVersion;Set-ItemProperty -Path $registryPath -Name $keyName -Value $targetVersion}
        Invoke-Command -Session $Session -ScriptBlock {$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate";$keyName = "Update{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}";if (-not (Test-Path $registryPath)) {New-Item -Path $registryPath -Force};Set-ItemProperty -Path $registryPath -Name $keyName -Value 0}
        Invoke-Command -Session $Session -ScriptBlock {gpupdate /force}
    } else {
        Echo "Edge is already downgraded on $Server"
        $Session = New-PSSession -ComputerName $Server
        Invoke-Command -Session $Session -ScriptBlock {$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate";$keyName = "RollbackToTargetVersion{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}";if (-not (Test-Path $registryPath)) {New-Item -Path $registryPath -Force};Set-ItemProperty -Path $registryPath -Name $keyName -Value 1}
        Invoke-Command -Session $Session -ScriptBlock {$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate";$keyName = "TargetVersionOverride{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}";if (-not (Test-Path $registryPath)) {New-Item -Path $registryPath -Force};$targetVersion = $Using:TargetEdgeVersion;Set-ItemProperty -Path $registryPath -Name $keyName -Value $targetVersion}
        Invoke-Command -Session $Session -ScriptBlock {$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate";$keyName = "Update{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}";if (-not (Test-Path $registryPath)) {New-Item -Path $registryPath -Force};Set-ItemProperty -Path $registryPath -Name $keyName -Value 0}
        Invoke-Command -Session $Session -ScriptBlock {gpupdate /force}
    }
}

foreach ($Server in $ActiveServers) {
    $Session = New-PSSession -ComputerName $Server
    Invoke-Command -Session $Session -ScriptBlock {
        $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
        $keyName1 = "RollbackToTargetVersion{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}"
        $keyName2 = "TargetVersionOverride{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}"
        $keyName3 = "Update{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}"

        if (Test-Path $registryPath) {
            Remove-ItemProperty -Path $registryPath -Name $keyName1 -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $registryPath -Name $keyName2 -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $registryPath -Name $keyName3 -ErrorAction SilentlyContinue
        }
    }
    Echo "Stopping edge on $Server"
    Invoke-Command -Session $Session -ScriptBlock {Get-Process "msedge" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue}
    Echo "Copying edge to $Server"
    Copy-Item "C:\Users\$env:username\Desktop\MicrosoftEdgeEnterpriseX86.msi" -Destination "\\$server\C$\MicrosoftEdgeEnterpriseX86.msi"
    Echo "Installing edge on $Server"
    Invoke-Command -Session $Session -ScriptBlock {msiexec /I C:\MicrosoftEdgeEnterpriseX86.msi /qn}
    Invoke-Command -Session $Session -ScriptBlock {Remove-Item C:\MicrosoftEdgeEnterpriseX86.msi}
    Echo ""
}

.\UpdateEdgeWebDriver.ps1
