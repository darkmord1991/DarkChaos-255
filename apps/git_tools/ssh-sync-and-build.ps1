param(
    [string]$RemoteHost = "",
    [string]$RemoteUser = "",
    [string]$RemotePassword = "",
    [string]$RemoteRepoPath = "",
    [string]$PrivateKeyPath = "",
    [string]$PubKeyPath = "",
    [switch]$InstallKey,
    [switch]$BuildOnly,
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

# PrivateKeyPath is now an explicit named parameter in param() above.

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

function Install-PublicKey {
    param([string]$LocalPubKeyPath)

    if (-not (Test-Path $LocalPubKeyPath)) {
        Write-Log "Public key file not found: $LocalPubKeyPath" "ERROR"
        exit 1
    }

    $tmpRemote = "/tmp/ssh_pubkey_$(Get-Random).pub"

    # Build a local ssh target for use inside this function (don't rely on global $sshTarget)
    $localSshTarget = "${RemoteUser}@${RemoteHost}"

    Write-Log "Uploading public key to remote temporary file $tmpRemote" "INFO"
    # Inline scp invocation (use same options as Invoke-ScpFile)
    $scpArgs = @()
    if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) {
        $scpArgs += "-i"
        $scpArgs += $PrivateKeyPath
    }
    $scpArgs += "-o"; $scpArgs += "StrictHostKeyChecking=no"
    $scpArgs += "-o"; $scpArgs += "UserKnownHostsFile=NUL"
    $scpArgs += "-o"; $scpArgs += "IdentitiesOnly=yes"
    $scpArgs += "-o"; $scpArgs += "PreferredAuthentications=publickey"
    $scpArgs += "-o"; $scpArgs += "BatchMode=yes"

    $remoteTarget = "${RemoteUser}@${RemoteHost}:$tmpRemote"
    Write-Log "SCP CMD: scp $($scpArgs -join ' ') `"$LocalPubKeyPath`" $remoteTarget" "INFO"
    & scp @scpArgs $LocalPubKeyPath $remoteTarget
    $scpExit = $LASTEXITCODE
    if ($scpExit -ne 0) {
        Write-Log "Failed to upload public key to remote (scp exit $scpExit)." "ERROR"
        exit $scpExit
    }

    # Append to authorized_keys safely and fix permissions, convert CRLF
    # We check for duplicates and only append the key if it isn't already present.
            $checkCmd = "mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; if grep -F -x -f `"$tmpRemote`" ~/.ssh/authorized_keys >/dev/null 2>&1; then echo EXISTS; else cat `"$tmpRemote`" >> ~/.ssh/authorized_keys; fi; rm -f `"$tmpRemote`"; perl -pi -e 's/\r\n/\n/g' ~/.ssh/authorized_keys 2>/dev/null || true; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys; chown -R ${RemoteUser}:${RemoteUser} ~/.ssh || true"

    Write-Log "Applying public key on remote and fixing permissions (dedup check)..." "INFO"
    # Create a temporary local script to run on the remote (avoids complex quoting)
    $localScript = Join-Path $env:TEMP "install_ssh_key_$(Get-Random).sh"
                # Build the remote helper script as an array of lines to avoid quoting pitfalls
                $lines = @()
                $lines += '#!/bin/sh'
                $lines += 'set -e'
                $lines += 'mkdir -p ~/.ssh'
                $lines += 'touch ~/.ssh/authorized_keys'
                $lines += "fp_new=$(ssh-keygen -lf '$tmpRemote' 2>/dev/null | awk '{print $2}')"
                $lines += 'if [ -z "$fp_new" ]; then'
                $lines += '  echo FP_ERR'
                $lines += '  exit 1'
                $lines += 'fi'
                $lines += 'exists=0'
                $lines += 'while IFS= read -r line || [ -n "$line" ]; do'
                $lines += '  [ -z "$line" ] && continue'
                $lines += '  echo "$line" > /tmp/one_key.pub'
                $lines += '  fp=$(ssh-keygen -lf /tmp/one_key.pub 2>/dev/null | awk "{print $2}")'
                $lines += '  if [ "$fp" = "$fp_new" ]; then'
                $lines += '    exists=1'
                $lines += '    break'
                $lines += '  fi'
                $lines += 'done < ~/.ssh/authorized_keys'
                $lines += 'rm -f /tmp/one_key.pub'
                $lines += 'if [ $exists -eq 1 ]; then'
                $lines += "  rm -f '$tmpRemote'"
                $lines += '  echo EXISTS'
                $lines += '  exit 0'
                $lines += 'fi'
                $lines += "cat '$tmpRemote' >> ~/.ssh/authorized_keys"
                $lines += "awk '!seen[\$0]++' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys"
                $lines += "rm -f '$tmpRemote'"
                $lines += "perl -pi -e 's/\r\n/\n/g' ~/.ssh/authorized_keys 2>/dev/null || true"
                $lines += 'chmod 700 ~/.ssh || true'
                $lines += 'chmod 600 ~/.ssh/authorized_keys || true'
                $lines += "chown -R ${RemoteUser}:${RemoteUser} ~/.ssh || true"
                $lines += 'echo APPENDED'

                $scriptContent = ($lines -join "`n")

    Set-Content -Path $localScript -Value $scriptContent -NoNewline
    # Upload the helper script
    $remoteScript = "/tmp/install_ssh_key_$(Get-Random).sh"
    Write-Log "Uploading remote runner script $remoteScript" "INFO"
    $scpArgs = @()
    if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) {
        $scpArgs += "-i"; $scpArgs += $PrivateKeyPath
    }
    $scpArgs += "-o"; $scpArgs += "StrictHostKeyChecking=no"
    $scpArgs += "-o"; $scpArgs += "UserKnownHostsFile=NUL"
    $scpArgs += "-o"; $scpArgs += "IdentitiesOnly=yes"
    $scpArgs += "-o"; $scpArgs += "PreferredAuthentications=publickey"
    $scpArgs += "-o"; $scpArgs += "BatchMode=yes"
    $remoteTargetScript = "${RemoteUser}@${RemoteHost}:$remoteScript"
    & scp @scpArgs $localScript $remoteTargetScript
    $scpRc = $LASTEXITCODE
    Remove-Item -Path $localScript -ErrorAction SilentlyContinue
    if ($scpRc -ne 0) {
        Write-Log "Failed to upload remote runner script (scp exit $scpRc)." "ERROR"
        exit $scpRc
    }

    Write-Log "Executing remote runner script..." "INFO"
    # Build full ssh command and run it via cmd.exe to avoid PowerShell argument parsing quirks
    # Build ssh argument array and run via PowerShell to avoid parsing issues
    $sshArgs = @()
    if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) { $sshArgs += '-i'; $sshArgs += $PrivateKeyPath }
    $sshArgs += '-o'; $sshArgs += 'StrictHostKeyChecking=no'
    $sshArgs += '-o'; $sshArgs += 'UserKnownHostsFile=NUL'
    $sshArgs += '-o'; $sshArgs += 'IdentitiesOnly=yes'
    $sshArgs += '-o'; $sshArgs += 'PreferredAuthentications=publickey'
    $sshArgs += '-o'; $sshArgs += 'BatchMode=yes'
    $sshArgs += $localSshTarget
    $sshArgs += 'bash'
    $sshArgs += $remoteScript

    $out = & ssh @sshArgs 2>&1
    $rc = $LASTEXITCODE
    # Attempt cleanup regardless
    $cleanupArgs = @()
    if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) { $cleanupArgs += '-i'; $cleanupArgs += $PrivateKeyPath }
    $cleanupArgs += '-o'; $cleanupArgs += 'StrictHostKeyChecking=no'
    $cleanupArgs += '-o'; $cleanupArgs += 'UserKnownHostsFile=NUL'
    $cleanupArgs += '-o'; $cleanupArgs += 'IdentitiesOnly=yes'
    $cleanupArgs += '-o'; $cleanupArgs += 'PreferredAuthentications=publickey'
    $cleanupArgs += '-o'; $cleanupArgs += 'BatchMode=yes'
    $cleanupArgs += $localSshTarget
    $cleanupArgs += 'rm'; $cleanupArgs += '-f'; $cleanupArgs += $remoteScript
    & ssh @cleanupArgs > $null 2>&1

    if ($rc -ne 0) {
        # If helper failed but printed FP_ERR, fall back to line-based append/dedupe
        if ($out -match 'FP_ERR') {
            Write-Log "Remote does not support fingerprint check; falling back to line-based dedupe." "WARNING"
            # Build a simple fallback script (append+awk dedupe)
            $fbLines = @()
            $fbLines += '#!/bin/sh'
            $fbLines += 'set -e'
            $fbLines += 'mkdir -p ~/.ssh'
            $fbLines += 'touch ~/.ssh/authorized_keys'
            $fbLines += "cat '$tmpRemote' >> ~/.ssh/authorized_keys"
            $fbLines += "awk '!seen[\$0]++' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys"
            $fbLines += "rm -f '$tmpRemote'"
            $fbLines += "perl -pi -e 's/\r\n/\n/g' ~/.ssh/authorized_keys 2>/dev/null || true"
            $fbLines += 'chmod 700 ~/.ssh || true'
            $fbLines += 'chmod 600 ~/.ssh/authorized_keys || true'
            $fbLines += "chown -R ${RemoteUser}:${RemoteUser} ~/.ssh || true"
            $fbLines += 'echo APPENDED'
            $fbScript = ($fbLines -join "`n")
            $localFb = Join-Path $env:TEMP "install_ssh_key_fb_$(Get-Random).sh"
            Set-Content -Path $localFb -Value $fbScript -NoNewline
            $remoteFb = "/tmp/install_ssh_key_fb_$(Get-Random).sh"
            & scp @scpArgs $localFb "${RemoteUser}@${RemoteHost}:$remoteFb"
            $scpRc2 = $LASTEXITCODE
            Remove-Item -Path $localFb -ErrorAction SilentlyContinue
            if ($scpRc2 -ne 0) {
                Write-Log "Failed to upload fallback runner script (scp exit $scpRc2)." "ERROR"
                exit $scpRc2
            }
            $sshArgsFb = @()
            if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) { $sshArgsFb += '-i'; $sshArgsFb += $PrivateKeyPath }
            $sshArgsFb += '-o'; $sshArgsFb += 'StrictHostKeyChecking=no'
            $sshArgsFb += '-o'; $sshArgsFb += 'UserKnownHostsFile=NUL'
            $sshArgsFb += '-o'; $sshArgsFb += 'IdentitiesOnly=yes'
            $sshArgsFb += '-o'; $sshArgsFb += 'PreferredAuthentications=publickey'
            $sshArgsFb += '-o'; $sshArgsFb += 'BatchMode=yes'
            $sshArgsFb += $localSshTarget
            $sshArgsFb += 'bash'
            $sshArgsFb += $remoteFb
            $outFb = & ssh @sshArgsFb 2>&1
            $rcFb = $LASTEXITCODE
            & ssh @cleanupArgs > $null 2>&1
            if ($rcFb -ne 0) {
                Write-Log "Fallback remote key install failed (exit $rcFb): $outFb" "ERROR"
                exit $rcFb
            }
            Write-Log "Public key appended and authorized_keys deduplicated (fallback)." "SUCCESS"
        }
        else {
            Write-Log "Remote key install failed (exit $rc): $out" "ERROR"
            exit $rc
        }
    }

    if ($out -match 'APPENDED') {
        Write-Log "Public key appended and authorized_keys deduplicated." "SUCCESS"
    }
    else {
        Write-Log "Public key operation completed; output: $out" "INFO"
    }

    Write-Log "Verifying key-based login..." "INFO"
    # Verify by trying an ssh -i using the private key path if provided
    if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) {
        $verify = & ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -i $PrivateKeyPath "${RemoteUser}@${RemoteHost}" echo key-ok 2>&1
        if ($LASTEXITCODE -eq 0 -and $verify -match 'key-ok') {
            Write-Log "Key-based auth verified successfully." "SUCCESS"
            exit 0
        }
        else {
            Write-Log "Verification failed; you may need to run ssh -vvv to debug." "WARNING"
            exit 1
        }
    }
    else {
        Write-Log "PrivateKeyPath not provided; please test connection manually." "INFO"
        exit 0
    }
}

if ($InstallKey) {
    if (-not $PubKeyPath) {
        Write-Log "When using -InstallKey you must provide -PubKeyPath (path to public key file)" "ERROR"
        exit 1
    }
    Install-PublicKey -LocalPubKeyPath $PubKeyPath
}

Write-Log "Starting SSH sync and build process..." "INFO"
Write-Log "Remote: $RemoteUser@${RemoteHost}:$RemoteRepoPath" "INFO"

if ($BuildOnly) {
    Write-Log "BuildOnly mode enabled: remote update scripts that start services will be skipped; only build/install will run." "WARNING"
}

# Check if we have SSH client available
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Log "SSH client not found. Please install OpenSSH or Git for Windows." "ERROR"
    exit 1
}

# Prepare SSH connection string
$sshOptions = @()
if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) {
    $sshOptions += "-i"
    $sshOptions += $PrivateKeyPath
    Write-Log "Using SSH private key: $PrivateKeyPath" "INFO"
}

$sshOptions += "-o"
$sshOptions += "StrictHostKeyChecking=no"
$sshOptions += "-o"
$sshOptions += "UserKnownHostsFile=NUL"

$sshTarget = "${RemoteUser}@${RemoteHost}"

# Test SSH connection
Write-Log "Testing SSH connection..." "INFO"

function Invoke-SshCommand {
    param([string]$RemoteCommand)
    $sshArgs = @()
    if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) {
        $sshArgs += "-i"
        $sshArgs += $PrivateKeyPath
    }
    $sshArgs += "-o"; $sshArgs += "StrictHostKeyChecking=no"
    $sshArgs += "-o"; $sshArgs += "UserKnownHostsFile=NUL"
    $sshArgs += "-o"; $sshArgs += "IdentitiesOnly=yes"
    $sshArgs += "-o"; $sshArgs += "PreferredAuthentications=publickey"
    # Prevent ssh from falling back to password prompts; fail instead
    $sshArgs += "-o"; $sshArgs += "BatchMode=yes"
    $sshArgs += $sshTarget
    $sshArgs += $RemoteCommand

    $cmdPreview = "ssh " + ($sshArgs -join ' ')
    Write-Log "SSH CMD: $cmdPreview" "INFO"

    if ($RemotePassword -and (Get-Command sshpass -ErrorAction SilentlyContinue)) {
        $env:SSHPASS = $RemotePassword
        & sshpass -e ssh @sshArgs
    }
    else {
        & ssh @sshArgs
    }
    return $LASTEXITCODE
}

function Invoke-ScpFile {
    param([string]$LocalPath, [string]$RemotePath)

    $scpArgs = @()
    if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) {
        $scpArgs += "-i"
        $scpArgs += $PrivateKeyPath
    }
    $scpArgs += "-o"; $scpArgs += "StrictHostKeyChecking=no"
    $scpArgs += "-o"; $scpArgs += "UserKnownHostsFile=NUL"
    $scpArgs += "-o"; $scpArgs += "IdentitiesOnly=yes"
    $scpArgs += "-o"; $scpArgs += "PreferredAuthentications=publickey"
    $scpArgs += "-o"; $scpArgs += "BatchMode=yes"

    # Build remote target with explicit quoting to handle spaces
    $quotedRemote = $sshTarget + ':' + '"' + $RemotePath + '"'

    $cmdPreview = "scp " + ($scpArgs -join ' ') + " `"$LocalPath`" $quotedRemote"
    Write-Log "SCP CMD: $cmdPreview" "INFO"

    if ($RemotePassword -and (Get-Command sshpass -ErrorAction SilentlyContinue)) {
        $env:SSHPASS = $RemotePassword
        & sshpass -e scp @scpArgs $LocalPath $quotedRemote
    }
    else {
        & scp @scpArgs $LocalPath $quotedRemote
    }
    return $LASTEXITCODE
}

$testExit = Invoke-SshCommand "true"
if ($testExit -ne 0) {
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
        if ($line -match '^(..)\t?(?:\s+)?(.*)$') {
            $code = $matches[1].Trim()
            $rest = $matches[2].Trim()
            # Strip surrounding quotes if present (git encloses paths with spaces in quotes)
            if ($rest.StartsWith('"') -and $rest.EndsWith('"')) { $rest = $rest.Substring(1, $rest.Length - 2) }
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
                $src = $parts[0].Trim()
                $dst = $parts[-1].Trim()
                if ($src.StartsWith('"') -and $src.EndsWith('"')) { $src = $src.Substring(1, $src.Length - 2) }
                if ($dst.StartsWith('"') -and $dst.EndsWith('"')) { $dst = $dst.Substring(1, $dst.Length - 2) }
                $toCopy += $dst
                $toDelete += $src
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
        $fClean = $f.Trim()
        if ($fClean.StartsWith('"') -and $fClean.EndsWith('"')) { $fClean = $fClean.Substring(1, $fClean.Length - 2) }
        $localPath = Join-Path (Get-Location) $fClean
        if (-not (Test-Path $localPath)) {
            Write-Log "Skipping missing local file: $fClean" "WARNING"
            continue
        }
        $remoteDir = [System.IO.Path]::GetDirectoryName($fClean)
        if ($remoteDir -and $remoteDir -ne '') {
            $remoteDirUnix = $remoteDir -replace '\\','/'
            $mkdirCmd = "mkdir -p '$RemoteRepoPath/$remoteDirUnix'"
            $mkdirExit = Invoke-SshCommand $mkdirCmd
            if ($mkdirExit -ne 0) {
                Write-Log "Failed to create remote directory $remoteDir" "ERROR"
                exit 1
            }
        }

        Write-Log "Copying $fClean to remote..." "INFO"
        $remotePath = "$RemoteRepoPath/$fClean" -replace '\\','/'
        $scpExit = Invoke-ScpFile $localPath $remotePath

        if ($scpExit -ne 0) {
            Write-Log "Failed to upload file $fClean" "ERROR"
            exit 1
        }
    }

    # Remove deleted files on remote
    foreach ($rf in $toDelete) {
        $rfClean = $rf.Trim()
        if ($rfClean.StartsWith('"') -and $rfClean.EndsWith('"')) { $rfClean = $rfClean.Substring(1, $rfClean.Length - 2) }
        Write-Log "Removing remote file: $rfClean" "INFO"
        $rmcmd = "rm -f '$RemoteRepoPath/$rfClean'"
        $rmExit = Invoke-SshCommand $rmcmd
        if ($rmExit -ne 0) {
            Write-Log "Failed to remove remote file $rfClean" "WARNING"
        }
    }

    Write-Log "Per-file sync complete. You may need to commit on remote if desired." "SUCCESS"

    # Optionally run remote build
    Write-Log "Starting remote build..." "INFO"
    $candidates = @()
    # candidate: UpdateWoWshort.sh in user's home (prioritized)
    $candidates += "/home/$RemoteUser/UpdateWoWshort.sh"
    # candidate: UpdateWoWshort.sh in repo root
    $candidates += "$RemoteRepoPath/UpdateWoWshort.sh"
    # candidate: updateWoW.sh (common alternate) in user's home
    $candidates += "/home/$RemoteUser/updateWoW.sh"
    # candidate: UpdateWoW.sh in repo root
    $candidates += "$RemoteRepoPath/UpdateWoW.sh"

    $found = $null
    foreach ($candidate in $candidates) {
        Write-Log "Checking remote build candidate: $candidate" "INFO"
        $testCmd = "test -f '$candidate' && echo exists || echo missing"
        $out = & ssh -i $PrivateKeyPath -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o PreferredAuthentications=publickey -o BatchMode=yes $sshTarget $testCmd 2>&1
        if ($out -match 'exists') {
            $found = $candidate
            break
        }
    }

    if ($found) {
        if ($BuildOnly) {
            Write-Log "Found build script at $found but BuildOnly is set - skipping remote update script to avoid service starts." "INFO"
            $fallbackCmd = "cd $RemoteRepoPath; ./acore.sh compiler build"
            $fallbackExit = Invoke-SshCommand $fallbackCmd
            if ($fallbackExit -ne 0) {
                Write-Log "Fallback build failed with exit code $fallbackExit" "ERROR"
                exit $fallbackExit
            }
        }
        else {
            Write-Log "Found build script at $found - running it" "INFO"
            $chmodCmd = "chmod +x '$found'"
            $chmodExit = Invoke-SshCommand $chmodCmd
            if ($chmodExit -ne 0) {
                Write-Log "Failed to chmod +x $found (exit $chmodExit)" "ERROR"
                exit $chmodExit
            }
            $execCmd = "'$found'"
            $execExit = Invoke-SshCommand $execCmd
            if ($execExit -ne 0) {
                Write-Log "Remote build script ran but returned exit code $execExit" "ERROR"
                exit $execExit
            }
        }
    }
    else {
        Write-Log "No build script found in known locations; falling back to ./acore.sh compiler build in repo" "WARNING"
        $fallbackCmd = "cd $RemoteRepoPath; ./acore.sh compiler build"
        $fallbackExit = Invoke-SshCommand $fallbackCmd
        if ($fallbackExit -ne 0) {
            Write-Log "Fallback build failed with exit code $fallbackExit" "ERROR"
            exit $fallbackExit
        }
    }
}
else {
    Write-Log "No local changes to sync." "INFO"
}

Write-Log "SSH sync and build process completed successfully!" "SUCCESS"