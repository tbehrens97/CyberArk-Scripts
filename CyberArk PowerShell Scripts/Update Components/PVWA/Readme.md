# CyberArk PVWA Deployment and Configuration Script

## Overview

This PowerShell script streamlines the deployment and upgrade of **CyberArk Password Vault Web Access (PVWA)** across multiple servers. It automates critical tasks such as unzipping installation files, updating configuration settings, running installation scripts, and executing post-installation hardening steps.

## Features

1. **Versioned Deployment**:
   - Dynamically prompts for PVWA version to ensure precise deployment.
   - Supports both fresh installations and upgrades.

2. **Automated Configuration Updates**:
   - Updates configuration files with custom parameters (e.g., company name, usernames, URLs, and vault IPs).
   - Modifies settings for hardening and logon mechanisms.

3. **Multi-Server Support**:
   - Executes PVWA deployment on a list of predefined servers.
   - Automates file transfers and installation script execution remotely.

4. **Post-Installation Tasks**:
   - Runs hardening scripts for enhanced security.
   - Cleans up temporary files on each server.

## Prerequisites

Ensure the following are in place before running the script:

- PowerShell version 5.1 or later.
- The PVWA zip file (`Password Vault Web Access-Rls-v[VERSION].zip`) is located in the `Desktop` folder of the user executing the script.
- Proper administrative credentials to perform remote installations and access registry/configurations.

## Usage

### Step 1: Prepare the Deployment
- Place the required PVWA zip file in the `Desktop` folder.
- Define key variables within the script:
  - **Version**: Enter the version number of PVWA during execution.
  - **Company Name and Username**: Replace placeholder values in `$ConfigUsername` and `$ConfigCompany`.
  - **Vault IPs**: Update the `$VaultIP` variable with the appropriate IPs.

### Step 2: Define Target Servers
- Update the `$Servers` array with the list of servers where PVWA will be deployed:

```powershell
$Servers = @("Server1", "Server2", "Server3", "Server4")