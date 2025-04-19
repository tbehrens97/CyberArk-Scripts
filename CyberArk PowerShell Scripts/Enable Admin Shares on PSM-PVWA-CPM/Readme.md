# AutoShareServer Configuration Script

## Overview

This PowerShell script automates the verification and configuration of the **AutoShareServer** registry key on a list of target servers. If the key is found to be disabled (`0`), the script updates it to `1` to enable administrative shares.

## Features

- **Multi-Server Processing**:
  - Works on a predefined list of servers specified in the `$Servers` array.
- **Registry Key Management**:
  - Verifies the current value of the **AutoShareServer** key.
  - Updates the key to enable administrative shares when necessary.
- **Remote Execution**:
  - Uses PowerShell remoting (`New-PSSession` and `Invoke-Command`) for efficient registry access and updates.

## Prerequisites

Before running this script, ensure:

- PowerShell version 5.1 or later is installed.
- The user has administrative privileges.
- WinRM (Windows Remote Management) is configured and enabled on the target servers.
- The list of servers in the `$Servers` array is accurate and accessible.

## Usage

### Step 1: Define the Server List
Update the `$Servers` array with the names of the target servers:

```powershell
$Servers = @("Server1", "Server2", "Server3", "Server4", "Server5")