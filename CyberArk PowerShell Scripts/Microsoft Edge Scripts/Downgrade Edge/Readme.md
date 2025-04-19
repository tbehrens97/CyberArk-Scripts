# Microsoft Edge Version Management for CyberArk Servers

## Overview

This PowerShell script automates the process of verifying and managing the version of **Microsoft Edge** across active servers to ensure compatibility with specific target versions. It supports both **PSM** (Privileged Session Manager) and **CPM** (Credential Provider Manager) servers. 

Additionally, it includes functionality to downgrade **Microsoft Edge** if its version exceeds the specified `TargetEdgeVersion`, and sets the necessary registry keys to prevent unwanted updates.

## Features

- **Version Verification**: Checks the current version of **Microsoft Edge** on servers against a predefined target version (`TargetEdgeVersion`).
- **Automated Downgrade**: If Edge versions exceed the target, the script:
  - Stops all active instances of Edge.
  - Copies the appropriate MSI installer to the server.
  - Downgrades Edge to the target version silently using `msiexec`.
- **Registry Configuration**: Ensures proper registry settings to prevent further updates.
- **Clean-Up**: Removes any temporary files or registry entries post-installation.

## Prerequisites

To run this script, ensure you have:

- PowerShell version 5.1 or later.
- Administrative privileges on the target servers.
- WinRM properly configured on all servers for remote session creation.
- The target Edge MSI installer available in a local directory (`C:\Users\$env:username\Desktop`).

## Usage

### Step 1: Define the target version
Update the `$TargetEdgeVersion` variable with the desired version:

```powershell
$TargetEdgeVersion="133.0.3065.82"