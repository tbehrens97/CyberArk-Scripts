# PSMSAPHANAStudioDispatcher

CyberArk-compatible dispatcher launcher for SAP HANA Studio.

This tool is designed for PSM connection components where SAP HANA Studio must be started with system parameters, common first-run popups must be handled, and the SAP DB password must be entered automatically.

## Features

- Starts SAP HANA Studio with:
  - `-data` (workspace path)
  - `-noPwdStore`
  - `-h` (host)
  - `-n` (instance number)
  - `-u` (database user)
- Integrates with CyberArk dispatcher utilities:
  - logs to PSM via `LogWrite`
  - reports launched process PID via `SendPID`
  - finalizes dispatcher via `FinalizeDispatcher`
- Handles common UI prompts:
  - SAP HANA Studio Launcher (default launch)
  - Secure Storage password hint prompt (selects No)
  - Password Recovery setup prompt (cancels)
- Focuses password field and types password in SAP login dialog.

## Prerequisites

- Windows PSM server.
- SAP HANA Studio installed (example path: `D:\SAP4HANA\hdbstudio.exe`).
- CyberArk dispatcher dependencies available.

## Required Files

Place all of these in the same PSM Components folder:

- `PSMSAPHANAStudioDispatcher.exe`
- `PSMDispatcherUtilsManaged.dll`
- `PSMDispatcherUtils.dll`
- `PSMGenericClientDriver.dll`

The dispatcher performs a startup dependency check and exits with an explicit error if any required DLL is missing.

## Default Workspace Behavior

If `--workspace` is not provided, the dispatcher uses a per-user path (not shared):

`%LOCALAPPDATA%\CyberArk\hdbstudio\workspace`

This avoids multiple users sharing the same workspace at the same time.

## CyberArk Command (Recommended)

Use this as the Client Dispatcher command in the connection component:

```text
"{PSMComponentsFolder}\PSMSAPHANAStudioDispatcher.exe" --studio-path "D:\SAP4HANA\hdbstudio.exe" --host "{Address}" --instance "{systemnumber}" --user "{UserName}" --password "{Password}" --password-window-title "Database User Logon" --wait-ms 20000 --window-title "SAP HANA Studio"
```

Notes:

- `--instance "{systemnumber}"` maps CyberArk systemnumber to SAP `-n`.
- You can remove `--workspace` to keep per-user default behavior.

## Optional Arguments

- `--studio-path <path>`: Full path to `hdbstudio.exe`.
- `--workspace <path>`: Override default per-user workspace.
- `--host <hostname>`: SAP host.
- `--instance <instanceNo>`: SAP instance number.
- `--systemnumber <instanceNo>`: Alias style accepted by component mappings.
- `--user <dbUser>`: SAP DB user.
- `--password <password>`: Password to type in logon dialog.
- `--password-window-title <title|title2>`: Pipe-delimited title match list.
- `--wait-ms <milliseconds>`: Wait timeout for login/popup handling.
- `--window-title <title>`: Main window title hint.

## Build From Source

This project is commonly built as x86 because CyberArk managed/native dispatcher dependencies are x86.

```powershell
Set-Location "C:\Users\behret\Downloads\VS Code\CyberArkHanaDispatcher"
& "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe /platform:x86 /optimize+ /out:PSMSAPHANAStudioDispatcher.exe /reference:System.Windows.Forms.dll /reference:'.\vendor\PSMDispatcherUtilsManaged.dll' Program.cs
```

## Troubleshooting

### Dispatcher timeout in CyberArk

- Ensure the EXE and all 3 DLLs are in the same PSM Components folder.
- Confirm PSM can load x86 dependencies.
- Verify the component command line matches this README.

### Password dialog is not detected

- Adjust `--password-window-title` to the exact title in your environment.
- Increase `--wait-ms` if login dialog appears slowly.

### SAP popup still appears

- Confirm this launcher command includes `-noPwdStore` (already built in).
- Validate launcher has focus permissions in PSM session.

## Security Note

If possible, rely on CyberArk session property injection rather than hard-coded cleartext credentials. Keep logs and component configuration aligned with your organization policy.
