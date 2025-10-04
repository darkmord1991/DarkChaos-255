param(
    [string]$RemoteHost = "",
    [string]$RemoteUser = "",
    [string]$RemotePassword = "",
    [string]$RemoteRepoPath = "",
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

# Robustly parse optional -PrivateKeyPath from raw args so the script doesn't fail
# if the flag is provided without a value (some task runners may pass an empty token).
$PrivateKeyPath = ""
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -ieq '-PrivateKeyPath') {
        if ($i + 1 -lt $args.Count -and ($args[$i+1] -notmatch '^-[A-Za-z]')) {
            $PrivateKeyPath = $args[$i+1]
        }
        else {
            # Flag present but no value provided: treat as empty string
            $PrivateKeyPath = ''
        }
        break
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
    
    # Determine changed files using git status so we can sync per-file (more robust than patch apply)
    Write-Log "Determining changed files via git status..." "INFO"
    $status = & git status --porcelain --untracked-files=normal
    if (-not $status) {
        Write-Log "No changes detected after all (race condition?). Nothing to sync." "INFO"
        exit 0
    }

    # Parse status lines (preserve leading characters like '.' in paths)
    $lines = $status -split "`n" | ForEach-Object { $_ } | Where-Object { $_ -ne '' }
    $toCopy = @()
    $toDelete = @()
    foreach ($line in $lines) {
        # Use regex to extract status code and path (preserves leading dots)
        if ($line -match '^(..)	?(?:\s+)?(.*)$') {
            $code = $matches[1].Trim()
            $rest = $matches[2]
        }
        else {
            # Fallback: skip malformed line
            Write-Log "Skipping malformed git status line: $line" "WARNING"
            continue
        }

        if ($code -eq 'D') {
            $toDelete += $rest
        }
        else {
            # additions, modifications, untracked, etc.
            # handle rename pattern like 'src -> dst'
            if ($rest -match ' -> ') {
                $parts = $rest -split ' -> '
                $toCopy += $parts[-1]
                $toDelete += $parts[0]
            }
            else {
                $toCopy += $rest
            }
        }
    }

    $toCopy = $toCopy | Where-Object { $_ -and $_ -ne '.' } | Select-Object -Unique
    $toDelete = $toDelete | Where-Object { $_ -and $_ -ne '.' } | Select-Object -Unique

    Write-Log "Files to copy: $($toCopy.Count)  files to delete: $($toDelete.Count)" "INFO"

    # Copy files one by one, creating directories on remote
    foreach ($f in $toCopy) {
        $localPath = Join-Path (Get-Location) $f
        if (-not (Test-Path $localPath)) {
            Write-Log "Skipping missing local file: $f" "WARNING"
            continue
        }
        $remoteDir = [System.IO.Path]::GetDirectoryName($f)
        if ($remoteDir -and $remoteDir -ne '') {
            $mkdirCmd = "mkdir -p '$RemoteRepoPath/$remoteDir'"
            if ($RemotePassword -and (Get-Command sshpass -ErrorAction SilentlyContinue)) {
                $env:SSHPASS = $RemotePassword
                & sshpass -e ssh $sshOptions $sshTarget $mkdirCmd
            }
            else {
                & ssh $sshOptions $sshTarget $mkdirCmd
            }
        }

        Write-Log "Copying $f to remote..." "INFO"
        if ($RemotePassword -and (Get-Command sshpass -ErrorAction SilentlyContinue)) {
            $env:SSHPASS = $RemotePassword
            & sshpass -e scp $sshOptions $localPath "${sshTarget}:${RemoteRepoPath}/$f"
        }
        else {
            & scp $sshOptions $localPath "${sshTarget}:${RemoteRepoPath}/$f"
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to upload file $f" "ERROR"
            exit 1
        }
    }

    # Remove deleted files on remote
    foreach ($rf in $toDelete) {
        Write-Log "Removing remote file: $rf" "INFO"
        $rmcmd = "rm -f '$RemoteRepoPath/$rf'"
        if ($RemotePassword -and (Get-Command sshpass -ErrorAction SilentlyContinue)) {
            $env:SSHPASS = $RemotePassword
            & sshpass -e ssh $sshOptions $sshTarget $rmcmd
        }
        else {
            & ssh $sshOptions $sshTarget $rmcmd
        }
    }

    Write-Log "Per-file sync complete. You may need to commit on remote if desired." "SUCCESS"

    # Optionally run remote build
    Write-Log "Starting remote build (UpdateWoWshort.sh)..." "INFO"
    $buildCmd = "cd $RemoteRepoPath && chmod +x UpdateWoWshort.sh; ./UpdateWoWshort.sh"
    if ($RemotePassword -and (Get-Command sshpass -ErrorAction SilentlyContinue)) {
        $env:SSHPASS = $RemotePassword
        & sshpass -e ssh $sshOptions $sshTarget $buildCmd
    }
    else {
        & ssh $sshOptions $sshTarget $buildCmd
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Remote build failed. Check remote logs." "ERROR"
        exit 1
    }
}
else {
    Write-Log "No local changes to sync." "INFO"
}

# Build on remote server using UpdateWoWshort.sh
Write-Log "Starting build on remote server (UpdateWoWshort.sh)..." "INFO"
$buildCmd = "cd $RemoteRepoPath && chmod +x UpdateWoWshort.sh; ./UpdateWoWshort.sh"

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