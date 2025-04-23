# PFX Certificate Import and IIS SSL Binding Script

## Overview

This PowerShell script simplifies the process of importing a **PFX certificate** into the `LocalMachine\My` certificate store and binding it to IIS SSL (`0.0.0.0:443`) for secure web connections. It automates essential tasks such as certificate import, retrieval of its thumbprint, configuration of IIS bindings, and service reset.

## Features

- **Interactive File Selection**:
  - Prompts the user to select a `.pfx` certificate file using a file dialog.
  
- **Certificate Import**:
  - Imports the `.pfx` file into the `LocalMachine\My` certificate store.
  - Retrieves and utilizes the certificate's SHA1 thumbprint automatically.

- **IIS Binding Management**:
  - Removes existing SSL bindings for `0.0.0.0:443`.
  - Associates the imported certificate with IIS SSL bindings.

- **Service Reset**:
  - Resets IIS to apply the updated SSL bindings.

## Prerequisites

To use this script, ensure:

- PowerShell version 5.1 or later is installed.
- Administrative privileges are available.
- The `.pfx` certificate file and its password are accessible.

## Usage

### Step 1: Place the Certificate File
Ensure the `.pfx` certificate file is located in a directory accessible to the script.