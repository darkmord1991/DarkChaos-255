param(
    [string]$RemoteHost = "",
    [string]$RemoteUser = "",
    [string]$RemotePassword = "",
    [string]$RemoteRepoPath = "",
    [string]$PrivateKeyPath = "",
    [switch]$UseStoredCredentials
)

# Configuration file path
$configPath = "$PSScriptRoot\ssh-config.json"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-StoredCredentials {
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            return $config
        }
        catch {
            Write-Log "Failed to read stored credentials: $_" "ERROR"
            return $null
        }
    }
    return $null
}

function Save-Credentials {
    param(
        [string]$RemoteHostName,
        [string]$User,
        [string]$RepoPath,
        [string]$KeyPath = ""
    )
    
    $config = @{
        RemoteHost = $RemoteHostName
        RemoteUser = $User
        RemoteRepoPath = $RepoPath
        PrivateKeyPath = $KeyPath
        LastUpdated = (Get-Date).ToString()
    }
    
    try {
        $config | ConvertTo-Json | Set-Content $configPath
        Write-Log "Credentials saved to $configPath" "SUCCESS"
    }
    catch {
        Write-Log "Failed to save credentials: $_" "ERROR"
    }
}

# Load stored credentials if requested
if ($UseStoredCredentials) {
    $stored = Get-StoredCredentials
    if ($stored) {
        $RemoteHost = $stored.RemoteHost
        $RemoteUser = $stored.RemoteUser
        $RemoteRepoPath = $stored.RemoteRepoPath
        $PrivateKeyPath = $stored.PrivateKeyPath
        Write-Log "Using stored credentials for ${RemoteUser}@${RemoteHost}" "SUCCESS"
    }
    else {
        Write-Log "No stored credentials found. Please run with parameters first." "ERROR"
        exit 1
    }
}

# Validate required parameters
if (-not $RemoteHost -or -not $RemoteUser -or -not $RemoteRepoPath) {
    Write-Log "Missing required parameters. Usage:" "ERROR"
    Write-Log "  -RemoteHost: SSH server hostname/IP" "ERROR"
    Write-Log "  -RemoteUser: SSH username" "ERROR"
    Write-Log "  -RemoteRepoPath: Absolute path to repo on remote server" "ERROR"
    Write-Log "  -RemotePassword: SSH password (optional if using key)" "ERROR"
    Write-Log "  -PrivateKeyPath: Path to SSH private key (optional)" "ERROR"
    Write-Log "  -UseStoredCredentials: Use previously saved credentials" "ERROR"
    exit 1
}

# Save credentials for future use (excluding password)
if (-not $UseStoredCredentials) {
    Save-Credentials -RemoteHostName $RemoteHost -User $RemoteUser -RepoPath $RemoteRepoPath -KeyPath $PrivateKeyPath
}

Write-Log "Starting SSH sync and build process..." "INFO"
Write-Log "Remote: $RemoteUser@${RemoteHost}:$RemoteRepoPath" "INFO"

# Check if we have SSH client available
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Log "SSH client not found. Please install OpenSSH or Git for Windows." "ERROR"
    exit 1
}

# Prepare SSH connection string
$sshOptions = @()
if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) {
    $sshOptions += "-i"
    $sshOptions += "`"$PrivateKeyPath`""
    Write-Log "Using SSH private key: $PrivateKeyPath" "INFO"
}

$sshOptions += "-o"
$sshOptions += "StrictHostKeyChecking=no"
$sshOptions += "-o"
$sshOptions += "UserKnownHostsFile=NUL"

$sshTarget = "${RemoteUser}@${RemoteHost}"

# Test SSH connection
Write-Log "Testing SSH connection..." "INFO"
if ($RemotePassword) {
    # Use sshpass if available, otherwise warn about manual password entry
    if (Get-Command sshpass -ErrorAction SilentlyContinue) {
        $env:SSHPASS = $RemotePassword
        $testResult = & sshpass -e ssh $sshOptions $sshTarget "echo 'Connection test successful'"
    }
    else {
        Write-Log "sshpass not available. You may need to enter password manually." "WARNING"
        $testResult = & ssh $sshOptions $sshTarget "echo 'Connection test successful'"
    }
}
else {
    $testResult = & ssh $sshOptions $sshTarget "echo 'Connection test successful'"
}

if ($LASTEXITCODE -ne 0) {
    Write-Log "SSH connection test failed. Please check your credentials and network connectivity." "ERROR"
    exit 1
}

Write-Log "SSH connection successful!" "SUCCESS"

# Get local changes to sync
Write-Log "Checking for local changes..." "INFO"
$localChanges = git status --porcelain
if ($localChanges) {
    Write-Log "Found local changes to sync:" "INFO"
    $localChanges | ForEach-Object { Write-Log "  $_" "INFO" }
    
    # Create a patch of local changes
    $patchFile = "$env:TEMP\azeroth-sync-$(Get-Date -Format 'yyyyMMdd-HHmmss').patch"
    git diff > $patchFile
    
    if ((Get-Content $patchFile).Count -gt 0) {
        Write-Log "Created patch file: $patchFile" "INFO"
        
        # Copy patch to remote server
        Write-Log "Uploading patch to remote server..." "INFO"
        if ($RemotePassword -and (Get-Command sshpass -ErrorAction SilentlyContinue)) {
            $env:SSHPASS = $RemotePassword
            & sshpass -e scp $sshOptions $patchFile "${sshTarget}:${RemoteRepoPath}/local-changes.patch"
        }
        else {
            & scp $sshOptions $patchFile "${sshTarget}:${RemoteRepoPath}/local-changes.patch"
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to upload patch file." "ERROR"
            exit 1
        }
        
        # Apply patch on remote server
        Write-Log "Applying changes on remote server..." "INFO"
        $applyCmd = "cd $RemoteRepoPath && git apply local-changes.patch && rm local-changes.patch"
        
        if ($RemotePassword -and (Get-Command sshpass -ErrorAction SilentlyContinue)) {
            $env:SSHPASS = $RemotePassword
            & sshpass -e ssh $sshOptions $sshTarget $applyCmd
        }
        else {
            & ssh $sshOptions $sshTarget $applyCmd
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to apply changes on remote server." "ERROR"
            exit 1
        }
        
        Write-Log "Changes successfully synced to remote server!" "SUCCESS"
        
        # Clean up local patch file
        Remove-Item $patchFile -ErrorAction SilentlyContinue
    }
}
else {
    Write-Log "No local changes to sync." "INFO"
}

# Build on remote server
Write-Log "Starting build on remote server..." "INFO"
$buildCmd = "cd $RemoteRepoPath && ./acore.sh compiler build"

if ($RemotePassword -and (Get-Command sshpass -ErrorAction SilentlyContinue)) {
    $env:SSHPASS = $RemotePassword
    & sshpass -e ssh $sshOptions $sshTarget $buildCmd
}
else {
    & ssh $sshOptions $sshTarget $buildCmd
}

if ($LASTEXITCODE -eq 0) {
    Write-Log "Remote build completed successfully!" "SUCCESS"
}
else {
    Write-Log "Remote build failed with exit code $LASTEXITCODE" "ERROR"
    exit $LASTEXITCODE
}

Write-Log "SSH sync and build process completed successfully!" "SUCCESS"