# CyberArk PSMP Update and Maintenance Script

## Overview

This PowerShell script streamlines the process of maintaining and updating CyberArk's **Privileged Session Manager SSH Proxy (PSMP)** on Linux servers. It automates tasks such as retrieving credentials using **AAM**, updating configuration files, cleaning logs, and upgrading PSMP securely.

## Features

1. **Credential Management**:
   - Retrieves credentials securely using **AAM** (Application Access Manager) with TLS 1.2.
   - Supports manual credential entry for flexibility.

2. **File Handling**:
   - Retrieves and processes the PSMP zip file dynamically.
   - Automatically unpacks, updates, and deploys configuration files on the target servers.

3. **Server Maintenance**:
   - Clears logs and temporary files from PSMP directories.
   - Updates and validates essential files (e.g., `psmpparms`, `vault.ini`).

4. **PSMP Upgrade**:
   - Automates RPM-based upgrades of PSMP with error handling.
   - Enables PSMP service and ensures SSH configuration is properly set.

5. **Post-Update Actions**:
   - Reboots target servers to apply changes.

## Prerequisites

Before running this script, ensure you have:

- PowerShell version 5.1 or later installed.
- sudo access to the Linux servers.
- The PSMP zip file (`PrivilegedSessionManagerSSHProxy*.zip`) available locally.
- Necessary GPG keys (`RPM-GPG-KEY-CyberArk`) available locally. https://community.cyberark.com/s/public-key
- To access PSMP servers https://github.com/darkoperator/Posh-SSH/tree/master must be installed


## Setup

### Step 1: Define Active Servers
Update the `$ActiveServers` array with the names of the servers:

```powershell
$ActiveServers = @("Server1", "Server2", "Server3")