# CyberArk Scripts and Utilities

A collection of community-maintained scripts and utilities for CyberArk PAM administration, PSM connection components, and session recording workflows.

> These tools are not official CyberArk products. Review and test every script in a non-production environment before using it in an operational vault or PSM environment.

## Contents

### PowerShell scripts

The [`CyberArk PowerShell Scripts`](CyberArk%20PowerShell%20Scripts) directory contains scripts for common administration and maintenance tasks:

- Enable administrative shares on PSM, PVWA, and CPM servers
- Retrieve current CPM, PSM, PSMP, and PVWA component versions
- Run CyberArk component health checks
- Repair PSMP installations
- Test CPM and PSM connectivity to target hosts
- Update CPM, PSM, PSMP, and PVWA versions
- Update IIS and RDP SSL certificates locally or through WinRM
- Unhide PSM drives
- Manage Microsoft Edge and Edge WebDriver versions

Each task has its own directory and, where available, a local README with prerequisites and usage details.

### SAP HANA Studio dispatcher

[`CyberArkPSMHanaDispatcher`](CyberArkPSMHanaDispatcher) is a .NET dispatcher launcher for starting SAP HANA Studio from a CyberArk PSM connection component. It passes connection properties, handles common first-run dialogs, and reports process state to the PSM dispatcher utilities.

See the [dispatcher README](CyberArkPSMHanaDispatcher/README.md) for required DLLs, the CyberArk command line, build instructions, and troubleshooting.

### PSM Recording Viewer

[`PSM-Recording-Viewer`](PSM-Recording-Viewer) is a local, standard-library-only Python web application for browsing and playing CyberArk PSM, PSM for SSH, and OPM recordings through the PAM Self-Hosted REST API.

It can optionally use `ffmpeg` to transcode legacy ScreenPressor recordings into browser-playable MP4 files and identify idle periods in recordings.

See the [PSM Recording Viewer README](PSM-Recording-Viewer/README.md) for authentication, installation, command-line options, and security guidance.

## Requirements

Requirements vary by utility. Typical prerequisites include:

- Windows PowerShell 5.1 or later for the PowerShell scripts
- Administrative rights on managed servers
- Network access to CyberArk components and target systems
- .NET Framework and CyberArk dispatcher dependencies for the SAP HANA dispatcher
- Python 3.8 or later for the recording viewer
- `ffmpeg` for in-browser playback of legacy recordings

Always check the README in the specific project or script directory before running a tool.

## Getting started

Clone the repository, then open the directory for the utility you want to use:

```powershell
git clone https://github.com/<your-org>/CyberArk-Scripts.git
Set-Location CyberArk-Scripts
```

For PowerShell scripts, review the script parameters and server lists, confirm the execution policy and permissions in your environment, and run PowerShell with the required administrative rights.

For the recording viewer, follow the [quick start instructions](PSM-Recording-Viewer/README.md#quick-start).

## Security considerations

- Do not commit passwords, API tokens, private keys, certificates, or production configuration.
- Treat command-line credentials and session data as sensitive.
- Keep the recording viewer bound to `127.0.0.1` unless remote access is deliberately configured and protected.
- Use CyberArk session property injection or another approved secret-management method instead of hard-coded credentials.
- Validate changes against your organization's CyberArk, Windows, and change-management policies.

## Repository layout

```text
CyberArk PowerShell Scripts/   PowerShell administration and maintenance tools
CyberArkPSMHanaDispatcher/     SAP HANA Studio PSM dispatcher
PSM-Recording-Viewer/          Local Python recording viewer
```

## License

Individual utilities may have their own licensing terms. See the [PSM Recording Viewer license](PSM-Recording-Viewer/LICENSE) and the README in each component directory for project-specific information.
