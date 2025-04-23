# PFX Certificate Import and RDP Configuration Script

## Overview

This PowerShell script simplifies the process of importing a `.pfx` certificate into the local machine's certificate store and configuring it for use with **Remote Desktop Protocol (RDP)**. The script also retrieves the certificate's thumbprint and binds it to the RDP service, ensuring secure connections.

## Features

- **Interactive File Selection**:
  - Prompts the user to select a `.pfx` certificate file using a dialog box.
  
- **Certificate Import**:
  - Imports the certificate into the `LocalMachine\My` certificate store.
  - Automatically retrieves the certificate's thumbprint for configuration.

- **RDP Configuration**:
  - Associates the imported certificate with the RDP service (`RDP-tcp`) using the thumbprint.

## Prerequisites

To run this script, ensure:

- PowerShell version 5.1 or later is installed.
- Administrative privileges are available.
- The `.pfx` certificate file and its password are known.

## Usage

### Step 1: Place the Certificate File
Ensure the `.pfx` certificate file is stored in a location accessible to the script.
