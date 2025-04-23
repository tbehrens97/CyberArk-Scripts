# PFX Certificate Deployment and RDP Configuration Script

## Overview

This PowerShell script automates the deployment of a **PFX certificate** to a list of specified servers, configures the certificate for **RDP (Remote Desktop Protocol)** connections, and cleans up temporary files used during the process.

## Features

- **Certificate Handling**:
  - Prompts the user to select a `.pfx` certificate file interactively.
  - Imports the certificate to the `LocalMachine\My` certificate store on target servers.
  - Configures the RDP service (`RDP-tcp`) to use the imported certificate.

- **Automation Across Servers**:
  - Automatically handles certificate deployment across multiple servers.
  - Cleans up temporary files on each server after configuration.

## Prerequisites

Before running this script, ensure:

- PowerShell version 5.1 or later is installed.
- Administrative privileges are available on the local machine and all target servers.
- WinRM (Windows Remote Management) is enabled on the target servers.
- The `.pfx` certificate file is accessible and the password is known.

## Setup

### Step 1: Define Server List
Update the `$Servers` array with the names of the target servers:

```powershell
$Servers = @(
    "Server1",
    "Server2",
    "Server3",
    "Server4",
    "Server5"
)
