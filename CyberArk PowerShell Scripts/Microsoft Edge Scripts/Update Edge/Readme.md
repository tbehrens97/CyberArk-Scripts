# Microsoft Edge WebDriver Version Manager for CyberArk Servers

## Overview

This PowerShell script automates the process of ensuring that the **Microsoft Edge** browser version matches the **msedgedriver.exe** version on both CyberArk **PSM** (Privileged Session Manager) and **CPM** (Credential Provider Manager) servers. This helps prevent compatibility issues and ensures smooth operation of browser-related tasks.

## Features

- Checks the Microsoft Edge version installed on target servers.
- Compares it with the installed `msedgedriver.exe` version.
- Automatically downloads and deploys the correct WebDriver version if there's a mismatch.
- Supports both **PSM** and **CPM** server configurations.
- Uses color-coded and verbose output for ease of tracking.

## Prerequisites

Before using this script, make sure:

- **PowerShell version 5.1** or later is installed.
- WinRM is configured for remote sessions.
- You have administrative privileges to access and modify the target servers.
- Internet access is available on the machine running the script to download WebDriver files.

## Setup

1. Update the `$Servers` array with the names of your **PSM** servers.
2. Update the `$CPMServers` array with the names of your **CPM** servers.

### Example Arrays

```powershell
$Servers = @("PSMServer1", "PSMServer2", "PSMServer3")
$CPMServers = @("CPMServer1", "CPMServer2", "CPMServer3")