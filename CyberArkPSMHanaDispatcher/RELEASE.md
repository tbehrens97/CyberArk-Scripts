# PSMSAPHANAStudioDispatcher Release

## Asset

- PSMSAPHANAStudioDispatcher.exe

## Purpose

Launches SAP HANA Studio for CyberArk PSM sessions, passes host/instance/user via startup arguments, handles common startup popups, and types the password in the SAP login dialog.

## Runtime Requirements

For full CyberArk integration, keep these files in the same folder as the EXE:

- PSMDispatcherUtilsManaged.dll
- PSMDispatcherUtils.dll
- PSMGenericClientDriver.dll

Note: DLLs are not required to build the EXE, only for full CyberArk runtime integration.

## Recommended CyberArk Command

"{PSMComponentsFolder}\PSMSAPHANAStudioDispatcher.exe" --studio-path "D:\SAP4HANA\hdbstudio.exe" --host "{Address}" --instance "{systemnumber}" --user "{UserName}" --password "{Password}" --password-window-title "Database User Logon" --wait-ms 20000 --window-title "SAP HANA Studio"

## Default Workspace

If `--workspace` is not provided, the EXE uses:

%LOCALAPPDATA%\CyberArk\hdbstudio\workspace
