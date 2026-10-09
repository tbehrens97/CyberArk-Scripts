# PSMSAPHANAStudioDispatcher

CyberArk-compatible dispatcher launcher for SAP HANA Studio.

This tool is designed for PSM connection components where SAP HANA Studio must be started with system parameters, common first-run popups must be handled, and the SAP DB password must be entered automatically.

## Features

- Starts SAP HANA Studio with:
  - `-data` (workspace path)
  - `-noPwdStore`
  - no `-h`, `-n` or `-u` connection arguments
- Opens the **Add System** wizard by pressing the Systems view toolbar button, then clicks and types:
  - Host Name (`host:port`)
  - Instance Number
  - Mode: Single container / Multiple containers
  - Tenant database + Name, or System database
  - Next, then User Name and Password, then Finish
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

## Runtime Files (CyberArk Integration)

For full CyberArk dispatcher integration on PSM, place all of these in the same PSM Components folder:

- `PSMSAPHANAStudioDispatcher.exe`
- `PSMDispatcherUtilsManaged.dll`
- `PSMDispatcherUtils.dll`
- `PSMGenericClientDriver.dll`

Build does not require these DLLs. They are only needed at runtime when you want CyberArk session-property and PID handshake integration.

## Default Workspace Behavior

If `--workspace` is not provided, every run gets its own workspace folder under:

`%LOCALAPPDATA%\CyberArk\hdbstudio\sessions\ws-<yyyyMMdd-HHmmss>-<pid>`

Before the new workspace is created, all previous session folders (and the old
`%LOCALAPPDATA%\CyberArk\hdbstudio\workspace` path) are deleted. Folders still locked by a
running SAP HANA Studio instance are skipped and removed on a later run.

Because each session starts with an empty Systems view, the Add System wizard never reports
"System ... already exists". If a duplicate is still detected, the dispatcher cancels the wizard
and logs on to the existing entry instead.

Passing `--workspace <path>` keeps that exact folder and disables all cleanup.

## CyberArk Command (Recommended)

Use this as the Client Dispatcher command in the connection component:

```text
"{PSMComponentsFolder}\PSMSAPHANAStudioDispatcher.exe" --studio-path "D:\SAP4HANA\hdbstudio.exe" --host "{Address}" --port "{Port}" --instance "{systemnumber}" --database "{Database}" --mode tenant --user "{UserName}" --password "{Password}" --wait-ms 30000
```

CyberArk variable mapping used by the wizard:

| Wizard field | Value |
| --- | --- |
| Host Name | `{Address}:{Port}` |
| Instance Number | `{systemnumber}` |
| Mode | Multiple containers |
| Tenant database Name | `{Database}` |
| User Name | `{UserName}` |
| Password | `{Password}` |

Notes:

- `--instance "{systemnumber}"` is typed into the wizard Instance Number field.
- Omit `--port` to leave Host Name without a port suffix.
- Use `--mode system` (or `--database SYSTEMDB`) to select System database.
- Use `--mode single` for single-container systems.
- You can remove `--workspace` to get a clean, auto-deleted per-session workspace.

## Optional Arguments

- `--studio-path <path>`: Full path to `hdbstudio.exe`.
- `--workspace <path>`: Use a fixed workspace instead of the per-session one (disables cleanup).
- `--host <hostname>`: SAP host.
- `--instance <instanceNo>`: SAP instance number.
- `--systemnumber <instanceNo>`: Alias style accepted by component mappings.
- `--user <dbUser>`: SAP DB user.
- `--database <tenantDb>`: Tenant database name typed into the wizard Name field.
- `--tenant <tenantDb>`: Alias of `--database`.
- `--port <portNo>`: SQL port appended to Host Name as `host:port` (valid range 1-65535).
- `--mode <single|multiple|tenant|system>`: Container mode selection in the wizard.
- `--password <password>`: Password to type in logon dialog.
- `--password-window-title <title|title2>`: Pipe-delimited title match list.
- `--wait-ms <milliseconds>`: Wait timeout for login/popup handling.
- `--window-title <title>`: Main window title hint.

## Build From Source

This project can be built without CyberArk DLL references.

```powershell
Set-Location "C:\Users\behret\Downloads\VS Code\CyberArkHanaDispatcher copy"
& "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe /platform:x86 /optimize+ /out:PSMSAPHANAStudioDispatcher.exe /reference:System.Windows.Forms.dll /reference:Accessibility.dll Program.cs
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
