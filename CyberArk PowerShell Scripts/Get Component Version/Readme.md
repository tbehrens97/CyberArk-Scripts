# CyberArk Service and Software Checker

## Overview

This PowerShell script is designed to automate the process of checking multiple servers for:
- Installed software from CyberArk: PSM,CPM,PVWA,and PSMP.
- The status of the component service.

It provides a quick overview of whether the PSM,CPM,PVWA,and PSMP service is running on each server in your specified list.

## Features

- Scans a list of predefined servers.
- Checks for software from a specific vendor.
- Verifies the status of a targeted service.
- Displays the results with color-coded output for easy readability.

## Prerequisites

Before running the script, ensure you have:

- PowerShell version 5.1 or later.
- The necessary permissions to create remote sessions (WinRM configured on the target servers).
- Access to the servers listed in the `$Servers` array.
- To access PSMP servers https://github.com/darkoperator/Posh-SSH/tree/master must be installed