# SAP HANA Studio PSM Dispatcher — Server Deployment Guide

End-to-end build for running SAP HANA Studio under CyberArk PSM on an AppLocker-hardened
server, with no DLLs written into the shadow user profile.

Perform every step in an **elevated** PowerShell session on each PSM server.

---

## 1. Assumptions

| Item | Value |
|---|---|
| HANA Studio install | `C:\SAP4HANA` |
| Studio executable | `C:\SAP4HANA\hdbstudio.exe` |
| Shadow user group | `PSMShadowUsers` (local group on each PSM server) |
| PSM components folder | `C:\Program Files (x86)\CyberArk\PSM\Components` |
| Dispatcher executable | `PSMSAPHANAStudioDispatcher.exe` |

If your install path differs, substitute it everywhere below and pass `--studio-path` to
the dispatcher.

---

## 2. Why these steps are needed

AppLocker denies DLL execution from user-writable locations. SAP HANA Studio (Eclipse)
normally unpacks native libraries at runtime into:

* `%USERPROFILE%\.swt\lib\win32\x86_64\` — SWT natives
* `<configuration>\org.eclipse.osgi\...\.cp\` — SWT natives
* `%TEMP%\jna-<hash>\jna<random>.dll` — JNA native

All three are inside the shadow profile and are blocked, producing
`UnsatisfiedLinkError: ... This program is blocked by group policy` (`0x800704EC`).

The fix is to pre-stage those DLLs in `C:\SAP4HANA`, point the JVM at them, and give each
session its own configuration area, `user.home` and keyring inside the allowed tree.

---

## 3. Build and deploy the dispatcher

Built with the .NET Framework compiler; no .NET SDK required.

```powershell
Set-Location '<repo>\CyberArkHanaDispatcher'

& "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" `
    /nologo /target:exe /platform:x86 /optimize+ `
    /out:PSMSAPHANAStudioDispatcher.exe `
    /reference:System.Windows.Forms.dll /reference:Accessibility.dll `
    Program.cs
```

Copy the result to the PSM components folder:

```powershell
Copy-Item .\PSMSAPHANAStudioDispatcher.exe `
          'C:\Program Files (x86)\CyberArk\PSM\Components\' -Force
```

---

## 4. Create the folder structure

```powershell
New-Item 'C:\SAP4HANA\sessions' -ItemType Directory -Force | Out-Null
```

| Folder | Purpose | Access needed |
|---|---|---|
| `C:\SAP4HANA` | Install tree and staged natives | Read / Execute |
| `C:\SAP4HANA\sessions` | Per-session config, home, keyring | Modify |
| `C:\SAP4HANA\p2` | p2 profile registry lock | Modify |

The dispatcher creates and purges `sessions\ses-<timestamp>-<pid>` automatically. If
`C:\SAP4HANA\sessions` does not exist, the per-session behaviour is silently skipped.

---

## 5. Set permissions

```powershell
# Lock down the tree, then open only the two folders that must be writable
icacls 'C:\SAP4HANA' /inheritance:r `
    /grant 'SYSTEM:(OI)(CI)F' `
           'Administrators:(OI)(CI)F' `
           '.\PSMShadowUsers:(OI)(CI)RX'

icacls 'C:\SAP4HANA\sessions' /grant '.\PSMShadowUsers:(OI)(CI)M'
icacls 'C:\SAP4HANA\p2'       /grant '.\PSMShadowUsers:(OI)(CI)M'
```

Verify:

```powershell
icacls 'C:\SAP4HANA'          | Select-String 'PSMShadowUsers'
icacls 'C:\SAP4HANA\sessions' | Select-String 'PSMShadowUsers'
icacls 'C:\SAP4HANA\p2'       | Select-String 'PSMShadowUsers'
```

> `.\PSMShadowUsers` forces resolution to the **local** group. Without the `.\` prefix a
> domain principal of the same name could be matched instead.

---

## 6. Stage the SWT natives

Save as `Stage-SwtNatives.ps1` and run elevated.

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem

$dest   = 'C:\SAP4HANA'
$staged = 0

Get-ChildItem "$dest\plugins" -Filter 'org.eclipse.swt.win32.win32.x86_64_*.jar' |
  ForEach-Object {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($_.FullName)
    try {
        foreach ($entry in $zip.Entries) {
            if ($entry.Name -like '*.dll') {
                $target = Join-Path $dest $entry.Name
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
                Write-Host "Staged $($entry.Name)"
                $staged++
            }
        }
    } finally { $zip.Dispose() }
}

if ($staged -eq 0) { Write-Warning 'No SWT natives found - check the plugins folder.' }
```

Verify:

```powershell
Get-ChildItem 'C:\SAP4HANA' -Filter 'swt-*.dll' | Select-Object Name, Length
```

You should see `swt-win32-*.dll`, `swt-gdip-*.dll`, `swt-wgl-*.dll` and
`swt-osversion-win32-*.dll`.

---

## 7. Stage the JNA native

`jnidispatch.dll` is often nested inside another jar, so search recursively.
Save as `Stage-JnaNative.ps1`.

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem

$dest   = 'C:\SAP4HANA'
$target = Join-Path $dest 'jnidispatch.dll'
$staged = $false

function Find-JniDispatch {
    param([System.IO.Compression.ZipArchive]$Zip, [string]$Origin)
    foreach ($e in $Zip.Entries) {
        if ($e.Name -eq 'jnidispatch.dll' -and
            $e.FullName -match 'win32-x86-64|win32-amd64|win32-x86_64') {
            [pscustomobject]@{ Entry = $e; Origin = $Origin; Path = $e.FullName }
        }
        elseif ($e.Name -like '*.jar') {
            $ms = New-Object System.IO.MemoryStream
            $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $ms.Position = 0
            try {
                $inner = New-Object System.IO.Compression.ZipArchive($ms, 'Read')
                Find-JniDispatch -Zip $inner -Origin "$Origin!$($e.FullName)"
            } catch { }
        }
    }
}

Get-ChildItem $dest -Recurse -Filter '*.jar' -ErrorAction SilentlyContinue | ForEach-Object {
    if ($staged) { return }
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($_.FullName)
        try {
            $hit = Find-JniDispatch -Zip $zip -Origin $_.FullName | Select-Object -First 1
            if ($hit) {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($hit.Entry, $target, $true)
                Write-Host "Staged jnidispatch.dll from $($hit.Origin) ($($hit.Path))"
                $staged = $true
            }
        } finally { $zip.Dispose() }
    } catch { }
}

if (-not $staged) { Write-Warning 'jnidispatch.dll not found - use the fallback below.' }
```

### Fallback: recover the already-unpacked copy

JNA unpacks successfully and only the *load* is blocked, so the file exists on disk after
any launch attempt. Log on with your **own admin account**, run
`C:\SAP4HANA\hdbstudio.exe` once, then:

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Temp\jna-*" -Recurse -Filter '*.dll' -Force |
  Sort-Object Length -Descending | Select-Object -First 1 |
  Copy-Item -Destination 'C:\SAP4HANA\jnidispatch.dll' -Force
```

> Use your own profile, not a `PSM-*` profile — shadow profiles are deleted at logoff.

Confirm it is 64-bit (`8664`, not `014C`):

```powershell
$fs = [IO.File]::OpenRead('C:\SAP4HANA\jnidispatch.dll')
$br = New-Object IO.BinaryReader($fs)
$fs.Position = 0x3C; $pe = $br.ReadInt32(); $fs.Position = $pe + 4
'{0:X4}' -f $br.ReadUInt16()
$br.Close(); $fs.Close()
```

---

## 8. Edit `C:\SAP4HANA\hdbstudio.ini`

Add the three lines at the end of the `-vmargs` block. Do **not** add `-configuration` or
`-Duser.home` here — the dispatcher supplies per-session values and a shared `user.home`
causes DPAPI keyring failures.

```
-startup
plugins/org.eclipse.equinox.launcher_1.7.100.v20251111-0406.jar
--launcher.library
plugins/org.eclipse.equinox.launcher.win32.win32.x86_64_1.3.0.v20260203-2149
--launcher.defaultAction
openFile
--launcher.appendVmargs
-vm
plugins/com.sap.ide.sapjvm.jre.win32.x86_64_210.9.0/jre/bin
-pluginCustomization
C:/SAP4HANA/plugin_customization.ini
-vmargs
-XX:CompileCommand=quiet
-XX:CompileCommand=exclude org.eclipse.jdt.internal.core.dom.rewrite.ASTRewriteAnalyzer::getExtendedRange
-Xmx1024m
-Dfile.encoding=UTF-8
--add-exports=java.base/sun.security.action=ALL-UNNAMED
-Xms256m
-XX:MetaspaceSize=512m
-XX:+HeapDumpOnOutOfMemoryError
-Dorg.eclipse.ecf.provider.filetransfer.excludeContributors=org.eclipse.ecf.provider.filetransfer.httpclientjava
-Djdk.http.auth.tunneling.disabledSchemes=
-Declipse.platform.mergeTrust=true
-Dswt.library.path=C:\SAP4HANA
-Djna.boot.library.path=C:\SAP4HANA
```

Optional hardening, **only after** step 7 succeeded — it turns a silent fallback into a
hard failure, which is what you want in production:

```
-Djna.nounpack=true
```

Optional, if Edge/WebView2 cannot be unblocked in AppLocker:

```
-Dorg.eclipse.swt.browser.DefaultType=ie
```

> `--launcher.appendVmargs` is present, so command-line `-vmargs` from the dispatcher are
> **appended** to this block rather than replacing it. The dispatcher detects this and
> avoids duplicating entries.

---

## 9. Create `C:\SAP4HANA\plugin_customization.ini`

Sets default preferences for every new workspace, including manual launches.

```
org.eclipse.equinox.p2.ui.sdk.scheduler/enabled=false
org.eclipse.ui/showIntro=false
org.eclipse.core.net/proxiesEnabled=false
org.eclipse.core.net/systemProxiesEnabled=false
```

---

## 10. AppLocker policy

Save as `sap-hana-applocker.xml`.

```xml
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FilePathRule Id="4f2a1c10-0001-4a11-9c01-000000000001" Name="SAP HANA Studio - install tree (EXE)" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="C:\SAP4HANA\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="4f2a1c10-0001-4a11-9c01-000000000002" Name="Edge WebView2 Runtime (EXE)" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\Microsoft\EdgeWebView\Application\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="4f2a1c10-0001-4a11-9c01-000000000003" Name="Edge Core (EXE)" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\Microsoft\EdgeCore\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="4f2a1c10-0001-4a11-9c01-000000000004" Name="Edge Application (EXE)" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\Microsoft\Edge\Application\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="4f2a1c10-0001-4a11-9c01-000000000005" Name="CyberArk PSM Components (EXE)" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\CyberArk\PSM\Components\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="4f2a1c10-0003-4a11-9c01-000000000001" Name="Deny - SAP HANA writable areas (EXE)" Description="" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions><FilePathCondition Path="C:\SAP4HANA\p2\*" /></Conditions>
    </FilePathRule>
  </RuleCollection>

  <RuleCollection Type="Dll" EnforcementMode="Enabled">
    <FilePathRule Id="4f2a1c10-0002-4a11-9c01-000000000001" Name="SAP HANA Studio - install tree (DLL)" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="C:\SAP4HANA\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="4f2a1c10-0002-4a11-9c01-000000000002" Name="Edge WebView2 Runtime (DLL)" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\Microsoft\EdgeWebView\Application\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="4f2a1c10-0002-4a11-9c01-000000000003" Name="Edge Core (DLL)" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\Microsoft\EdgeCore\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="4f2a1c10-0002-4a11-9c01-000000000004" Name="Edge Application (DLL)" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\Microsoft\Edge\Application\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="4f2a1c10-0003-4a11-9c01-000000000002" Name="Deny - SAP HANA p2 writable area (DLL)" Description="" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions><FilePathCondition Path="C:\SAP4HANA\p2\*" /></Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
```

Apply (local policy; for domain deployment paste the same rules into the GPO via GPMC):

```powershell
Set-AppLockerPolicy -XmlPolicy .\sap-hana-applocker.xml -Merge
gpupdate /force
Restart-Service AppIDSvc -Force
```

Check the existing enforcement mode **before** merging — the XML above enables the `Dll`
collection, which would switch it on server-wide if it is currently off:

```powershell
(Get-AppLockerPolicy -Effective).RuleCollections |
  Select-Object RuleCollectionType, EnforcementMode
```

If `Dll` is `NotConfigured` and you want it to stay that way, change
`Type="Dll" EnforcementMode="Enabled"` to `EnforcementMode="NotConfigured"`.

---

## 11. CyberArk PSM connection component

Client application command line:

```
"{PSMComponentsFolder}\PSMSAPHANAStudioDispatcher.exe" --studio-path "C:\SAP4HANA\hdbstudio.exe" --host "{Address}" --port "{Port}" --instance "{systemnumber}" --database "{Database}" --mode tenant --user "{UserName}" --password "{Password}" --wait-ms 30000
```

Key switches:

| Switch | Meaning |
|---|---|
| `--studio-path` | Explicit path to `hdbstudio.exe` |
| `--mode` | `single`, `multiple`, `tenant` or `system` |
| `--wait-ms` | Per-step wait for windows and wizard pages (default 15000) |
| `--startup-delay-ms` | Settle time before automation begins (default 8000) |
| `--workspace` | Fixed workspace folder; disables per-session workspace cleanup |
| `--configuration` | Overrides the per-session configuration area |
| `--swt-library-path` | Overrides the staged-native folder |

Run the executable with no arguments to print full usage.

---

## 12. Verification

```powershell
# Staged natives present
Get-ChildItem 'C:\SAP4HANA' -Filter 'swt-*.dll'
Get-ChildItem 'C:\SAP4HANA' -Filter 'jnidispatch.dll'

# Nothing leaking into shadow profiles (should return nothing)
Get-ChildItem 'C:\Users\PSM-*\.swt',
              'C:\Users\PSM-*\.eclipse',
              'C:\Users\PSM-*\AppData\Local\Temp\jna-*' -ErrorAction SilentlyContinue

# No AppLocker denials (8004 = blocked, 8007 = audit-only)
Get-WinEvent -LogName 'Microsoft-Windows-AppLocker/EXE and DLL' -MaxEvents 100 |
  Where-Object Id -in 8004,8007 |
  Select-Object TimeCreated, Id, Message | Format-List
```

Then open **two concurrent PSM sessions** and confirm both reach the Systems view and that
`C:\SAP4HANA\sessions` contains one `ses-*` folder per live session.

---

## 13. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `UnsatisfiedLinkError: swt-*.dll ... blocked by group policy` | SWT natives not staged | Section 6 + `-Dswt.library.path` |
| `UnsatisfiedLinkError: %TEMP%\jna-*\jna*.dll ... blocked by group policy` | JNA native not staged | Section 7 + `-Djna.boot.library.path` |
| `Aborting Edge initialization after 5 retries with result -2147023636` | WebView2 blocked (`0x800704EC`) | Allow Edge paths (section 10) or set `-Dorg.eclipse.swt.browser.DefaultType=ie` |
| `'Update Job' ... Profile not locked: ...\.lock (Access is denied)` | `C:\SAP4HANA\p2` not writable | `icacls` grant in section 5 |
| `Win32Exception: Key not valid for use in specified state` | Shared DPAPI keyring across shadow users | Per-session `user.home` (section 4); delete old `.eclipse\org.eclipse.equinox.security` |
| `Exception in Decorator ... com.sun.jna.Native` | JNA native missing | Non-fatal; fix via section 7 |
| Welcome page covers the Systems toolbar | Intro not suppressed | `plugin_customization.ini` (section 9) |
| System already exists in folder '/' | Reused workspace | Ensure per-session workspace is active (no `--workspace`) |

Error codes `0x800704EC` / `-2147023636` both decode to
`ERROR_ACCESS_DISABLED_BY_POLICY`.

Studio log for deeper diagnosis:

```powershell
Get-ChildItem 'C:\Users\PSM-*\AppData\Local\CyberArk\hdbstudio\sessions\ws-*\.metadata\.log' |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1 |
  Get-Content -Tail 60
```

---

## 14. After a HANA Studio or Edge upgrade

Versioned filenames change, so repeat:

1. `Stage-SwtNatives.ps1` — the `swt-osversion-win32-<version>.dll` suffix changes.
2. `Stage-JnaNative.ps1` — only if the JNA version changed.
3. Update the `-startup`, `--launcher.library` and `-vm` lines in `hdbstudio.ini`, which
   the installer rewrites; re-add the `-pluginCustomization` and `-D` lines.
4. Re-run the AppLocker verification in section 12.

---

## 15. Security considerations

* `C:\SAP4HANA\sessions` and `C:\SAP4HANA\p2` are **user-writable inside an
  AppLocker-allowed path**. That is a policy-bypass vector: a session user could drop a DLL
  there and have it execute. The `p2` deny rules in section 10 close that half. For
  `sessions`, prefer narrowing the allow rules to `C:\SAP4HANA\plugins\*`,
  `C:\SAP4HANA\features\*` and `C:\SAP4HANA\*.dll`, then adding publisher-based allows for
  whatever legitimately extracts under `sessions`.
* Prefer **publisher** rules over path rules wherever the binaries are signed:

  ```powershell
  Get-ChildItem 'C:\SAP4HANA' -Recurse -Include *.exe,*.dll |
    Get-AppLockerFileInformation |
    New-AppLockerPolicy -RuleType Publisher,Hash -User Everyone `
                        -RuleNamePrefix 'SAP HANA Studio' -Optimize -Xml |
    Out-File .\sap-hana-publisher.xml -Encoding utf8
  ```

* Keep **deny** rules scoped to `Everyone` (`S-1-1-0`) even when allow rules are scoped to
  `PSMShadowUsers`, so other non-admin accounts are covered.
* `PSMShadowUsers` is a **local** group, so its SID differs per server. Use path rules with
  `Everyone` if a single GPO targets multiple PSM servers.
* The dispatcher receives the account password on its command line from PSM. Do not add it
  to scheduled tasks, scripts or logs, and never run the dispatcher manually with
  `--password` on a shared host.
