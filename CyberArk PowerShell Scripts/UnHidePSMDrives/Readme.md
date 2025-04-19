# PowerShell Script: Admin Verification and Drive Visibility

## Overview

This script ensures that PowerShell is run with administrative privileges and performs the following tasks:
- Verifies if the session is in administrator mode.
- Elevates the session if not already in admin mode.
- Checks the registry for hidden drives and unhides them if necessary.

## Features

1. **Admin Mode Verification**:
   - Confirms whether the script is running with administrative privileges.
   - Attempts to re-launch itself in elevated mode if it's not already elevated.

2. **Drive Visibility Fix**:
   - Checks the `NoDrives` registry key under `HKCU`.
   - Resets the value to `0` if drives are hidden.
   - Prompts the user to sign out and back in for changes to take effect.

## Prerequisites

To use this script, ensure:
- PowerShell version 5.1 or later is installed.
- The user has permissions to modify registry keys.

## Usage

### Step 1: Run the Script
Execute the script in PowerShell. If the session isn't elevated, the script will re-launch with administrative privileges.

```powershell
.\UnHidePSMDrives.ps1