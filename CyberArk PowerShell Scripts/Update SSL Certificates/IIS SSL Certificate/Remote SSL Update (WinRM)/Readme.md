# PFX Certificate Deployment and IIS SSL Configuration Script

## Overview

This PowerShell script automates the process of deploying **PFX certificates** across multiple servers, configuring IIS SSL bindings, and resetting the IIS service to apply the changes. It ensures that outdated bindings are removed and the new certificate is used for secure connections.

## Features

- **Certificate Handling**:
  - Prompts the user to select a `.pfx` certificate file interactively.
  - Imports the certificate into the `LocalMachine\My` certificate store on target servers.
  - Automatically retrieves and utilizes the certificate's thumbprint.

- **IIS Binding Management**:
  - Removes existing SSL bindings for `0.0.0.0:443`.
  - Configures IIS to use the newly deployed certificate for SSL.
  - Restarts IIS to apply the changes.

- **Automation Across Servers**:
  - Streamlines the deployment process across multiple servers defined in the script.

## Prerequisites

Before running this script, ensure you have:

- PowerShell version 5.1 or later installed.
- Administrative privileges on the local machine and all target servers.
- WinRM (Windows Remote Management) enabled on the target servers.
- A `.pfx` certificate file with its password.

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
