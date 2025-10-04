# SSH Sync and Build System

This directory contains tools for synchronizing local changes to a remote build server and executing builds via SSH.

## Files

- `ssh-sync-and-build.ps1` - Main sync and build script
- `credential-manager.ps1` - Secure credential storage utility
- `ssh-config.json` - Stored SSH configuration (auto-generated)
- `build-credentials.json` - Encrypted credentials storage (auto-generated)

## Quick Setup

1. **First-time setup with credentials storage:**
   ```powershell
   # Store your SSH password securely
   .\apps\git_tools\credential-manager.ps1 -Action set -Key "ssh-password" -Secure
   
   # Configure SSH connection (saves settings for future use)
   .\apps\git_tools\ssh-sync-and-build.ps1 -RemoteHost "your-server.com" -RemoteUser "your-username" -RemoteRepoPath "/path/to/repo" -RemotePassword "your-password"
   ```

2. **Use VS Code Tasks:**
   - **Ctrl+Shift+P** → "Tasks: Run Task"
   - Choose "AzerothCore: Setup SSH Credentials" (one-time setup)
   - Choose "AzerothCore: Sync + Build (stored credentials)" (daily use)

## VS Code Task Options

### Standard Tasks
- **AzerothCore: Sync changed + Build** - Prompts for all connection details each time
- **AzerothCore: Sync + Build (stored credentials)** - Uses saved credentials, fastest option
- **AzerothCore: Build (local)** - Local build only
- **AzerothCore: Setup SSH Credentials** - Initial password setup

## Script Usage

### SSH Sync and Build Script
```powershell
# Basic usage with prompts
.\ssh-sync-and-build.ps1 -RemoteHost "server.com" -RemoteUser "username" -RemoteRepoPath "/path/to/repo"

# With stored credentials
.\ssh-sync-and-build.ps1 -UseStoredCredentials -RemotePassword "password"

# With SSH private key
.\ssh-sync-and-build.ps1 -RemoteHost "server.com" -RemoteUser "username" -RemoteRepoPath "/path/to/repo" -PrivateKeyPath "C:\path\to\key.pem"
```

### Credential Manager
```powershell
# Store password securely
.\credential-manager.ps1 -Action set -Key "ssh-password" -Secure

# Retrieve password
.\credential-manager.ps1 -Action get -Key "ssh-password"

# List all stored credentials
.\credential-manager.ps1 -Action list

# Remove credential
.\credential-manager.ps1 -Action remove -Key "ssh-password"
```

## How It Works

1. **Sync Process:**
   - Detects local Git changes using `git status --porcelain`
   - Creates a patch file of unstaged changes
   - Uploads patch to remote server via SCP
   - Applies patch on remote server using `git apply`

2. **Build Process:**
   - Executes `./acore.sh compiler build` on remote server
   - Streams output back to local terminal
   - Returns proper exit codes for build status

3. **Security:**
   - Passwords encrypted using Windows DPAPI
   - SSH keys supported for passwordless authentication
   - Connection settings saved for convenience
   - Credentials only accessible by current user account

## Prerequisites

- **SSH Client:** Git for Windows or OpenSSH
- **Optional:** sshpass for automated password authentication
- **PowerShell:** Version 5.1 or later
- **Remote Server:** Linux build server with AzerothCore setup

## Troubleshooting

### SSH Connection Issues
```powershell
# Test SSH connection manually
ssh username@server.com "echo 'Connection test'"

# Check if SSH client is available
Get-Command ssh
```

### Password Authentication
- If sshpass is not available, you'll be prompted for password manually
- Consider using SSH keys for better security and automation
- Windows Subsystem for Linux (WSL) can provide sshpass if needed

### Build Failures
- Check remote server has sufficient disk space
- Verify remote repo path is correct
- Ensure remote server has all build dependencies installed

## Example Workflow

1. Make local changes to your code
2. Press **Ctrl+Shift+P** in VS Code
3. Type "Tasks: Run Task"
4. Select "AzerothCore: Sync + Build (stored credentials)"
5. Wait for sync and build completion
6. Check build results in terminal output

The system automatically handles:
- Detecting what files changed locally
- Creating and applying patches
- Building on remote server
- Reporting success/failure status

## Security Notes

- Credentials are encrypted per-user using Windows DPAPI
- SSH keys are recommended over passwords for production use
- Credential files are excluded from Git (add to .gitignore)
- Only current Windows user can decrypt stored passwords