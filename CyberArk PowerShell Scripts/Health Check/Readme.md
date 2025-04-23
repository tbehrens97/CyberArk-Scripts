# CyberArk System Health Check Script

## Overview

This PowerShell script automates health checks and basic troubleshooting for CyberArk components across multiple servers, including:

- **PSM (Privileged Session Manager)**
- **CPM (Credential Provider Manager)**
- **PVWA (Password Vault Web Access)**
- **AAM (Application Access Manager)**
- **PSMP (Privileged Session Manager SSH Proxy)**

The script verifies service statuses, checks online availability, and optionally restarts services to resolve issues.

## Features

- **Service Monitoring**:
  - Checks the status of CyberArk-related services (e.g., `CyberArk Password Manager`, `CyberArk Application Password Provider`).
  - Verifies availability of components using network requests and service checks.

- **Service Recovery**:
  - Prompts the user to restart services if they are found to be offline.

- **Interactive Troubleshooting**:
  - Provides detailed feedback and user prompts for resolving issues.
  - Handles IIS resets for PVWA and AAM components.

- **AAM Integration**:
  - Securely retrieves credentials for Linux PSMP servers using **AAM (Application Access Manager)**.

- **SSH and Service Validation**:
  - Validates `psmpsrv` service status for Linux servers using SSH.

## Prerequisites

### Required Tools and Configurations
- PowerShell version 5.1 or later.
- Administrative privileges on the target servers.
- Network access to all servers listed in the script.

### Required Modules
- **PSSession**: Used for remote Windows server management.
- **SSH**: Utilized for accessing and managing Linux PSMP servers.
- To access PSMP servers https://github.com/darkoperator/Posh-SSH/tree/master must be installed

## Usage

### Step 1: Define Server Lists
Update the arrays in the script with the appropriate server names:

```powershell
$PSMServers = @("Server1", "Server2", "Server3", "Server4", "Server5")
$CPMServers = @("Server1", "Server2", "Server3", "Server4", "Server5")
$PVWAServers = @("Server1", "Server2", "Server3", "Server4", "Server5")
$AAMServers = @("Server1", "Server2", "Server3", "Server4", "Server5")
$PSMPServers = @("Server1", "Server2", "Server3", "Server4", "Server5")
