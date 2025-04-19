# Server Connectivity Validation Tool

## Overview

This PowerShell script automates the process of validating server connectivity across specified **PSM** (Privileged Session Manager) and **CPM** (Credential Provider Manager) servers. It dynamically reads server information from a CSV file and verifies access to critical ports based on the server's operating system.

## Features

- **Dynamic Server Input**:
  - Import server details from a CSV file for validation.
- **Multi-OS Support**:
  - Checks connectivity for **Windows**, **Linux**, **MSSQL**, **Oracle**, or custom-defined ports.
- **PSM and CPM Integration**:
  - Separately validates connectivity for both PSM and CPM servers.
- **Port Validation**:
  - Uses TCP connections to validate port accessibility (e.g., 3389, 445, 22, 1433, 1521).
- **Error Highlighting**:
  - Displays failed connections in red for easier troubleshooting.

## Prerequisites

Before running the script, ensure you have:

- **PowerShell version 5.1** or later.
- CSV file containing server information in the following format:

| Server       | OS       |
|--------------|----------|
| Server1      | Windows  |
| Server2      | Linux    |
| Server3      | MSSQL    |
| Server4      | Oracle   |
| Server5      | 8080     |

- Administrative privileges for accessing PSM and CPM servers.
- WinRM properly configured for remote sessions.

## Setup

### Step 1: Define PSM and CPM Servers
Update the `$PSMServers` and `$CPMServers` arrays with the respective server names:

```powershell
$PSMServers = @("PSMServer1", "PSMServer2", "PSMServer3")
$CPMServers = @("CPMServer1", "CPMServer2", "CPMServer3")