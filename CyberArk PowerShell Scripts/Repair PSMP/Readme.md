# CyberArk PSMP Upgrade and Maintenance Script

## Overview

This PowerShell script automates the maintenance and upgrade process of **CyberArk PSMP** (Privileged Session Manager SSH Proxy) on Linux servers. It handles log cleanup, RPM upgrades, credential creation, and configuration adjustments—streamlining system administration tasks with robust error handling and user input options.

## Features

- **Credential Management**:
  - Option to retrieve credentials securely using **AAM** (Application Access Manager).
  - Support for manual credential entry.
- **File Management**:
  - Automatically reads zip archives to identify the required RPM file for PSMP upgrades.
  - Transfers necessary files securely to target servers.
- **Log Cleanup**:
  - Deletes logs older than 2 days from `/var/tmp` and `/var/opt/CARKpsmp/logs`.
- **PSMP Installation and Configuration**:
  - Installs the PSMP RPM package.
  - Adjusts configuration files (`psmpparms`, `vault.ini`, etc.).
  - Imports necessary GPG keys.
- **SSH Server Adjustments**:
  - Enables SSH subsystem directives in `sshd_config`.
  - Restarts and enables PSMP services post-upgrade.

## Prerequisites

Before running the script, ensure you have:

- **PowerShell version 5.1** or later.
- Administrative privileges on the Linux servers.
- CyberArk RPM files located locally.
- Necessary GPG keys (`RPM-GPG-KEY-CyberArk`) available locally. https://community.cyberark.com/s/public-key 

## Usage

### Step 1: Define Active Servers
Update the `$ActiveServers` array with the server names:

```powershell
$ActiveServers = @("Server1", "Server2")

$VaultIPs = '192.168.1.1,192.168.1.2,192.168.1.3,192.168.1.4'