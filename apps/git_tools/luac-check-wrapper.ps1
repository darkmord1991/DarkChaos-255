<#
luac-check-wrapper.ps1

Usage examples:
  # Auto-detect and run luacheck (if installed) or luac (if installed)
  powershell -NoProfile -ExecutionPolicy Bypass -File .\luac-check-wrapper.ps1

  # Run a specific command with arguments
  powershell -NoProfile -ExecutionPolicy Bypass -File .\luac-check-wrapper.ps1 luacheck --std lua53 src\addon\

  # Run luac explicitly and don't pause at the end
  powershell -NoProfile -ExecutionPolicy Bypass -File .\luac-check-wrapper.ps1 -NoPause luac -o out.luac input.lua

  # Run but keep the caller shell open (if you launched PowerShell with -NoExit, useful for debugging)
  powershell -NoProfile -ExecutionPolicy Bypass -File .\luac-check-wrapper.ps1 -NoExit luac -o out.luac input.lua

Description:
  - If no command is provided, the script tries to run 'luacheck' (preferred) then 'luac'.
  - Captures and preserves the executed command's exit code.
  - By default, when running in an interactive ConsoleHost, the wrapper prompts "Press Enter to close" to avoid the console closing instantly.
  - Use -NoPause to skip the prompt (useful for CI).
  - Use -NoExit to avoid calling exit at the end (useful if you already launched PowerShell with -NoExit).
#>

param(
    [switch]$NoPause,
    [switch]$NoExit,
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Cmd
)

function Write-Header {
    Write-Host "=== luac-check-wrapper ===" -ForegroundColor Cyan
}

function Try-Which {
    param($name)
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Path } else { return $null }
}

Write-Header

# Determine command to run
$exe = $null
$exeArgs = @()

if ($Cmd -and $Cmd.Count -gt 0) {
    $exe = $Cmd[0]
    if ($Cmd.Count -gt 1) {
        $exeArgs = $Cmd[1..($Cmd.Count - 1)]
    }
} else {
    # No explicit command: try to detect luacheck then luac
    $found = Try-Which "luacheck"
    if (-not $found) { $found = Try-Which "luac" }
    if ($found) {
        $exe = $found
        $exeArgs = @()  # you can modify defaults here if desired (e.g., add flags)
        Write-Host "Auto-detected command: $exe"
    } else {
        Write-Host "No command provided and neither 'luacheck' nor 'luac' found on PATH." -ForegroundColor Yellow
        Write-Host "Usage examples:" -ForegroundColor Gray
        Write-Host "  .\luac-check-wrapper.ps1 luacheck --std lua53 src\addon" -ForegroundColor Gray
        if (-not $NoPause -and $Host.Name -eq 'ConsoleHost' -and -not $NoExit) {
            Write-Host ""
            Read-Host -Prompt "Press Enter to close"
        }
        if (-not $NoExit) { exit 1 }
        return
    }
}

# Run the command and preserve output and exit code
$cmdLine = if ($exeArgs.Count -gt 0) { "$exe $($exeArgs -join ' ')" } else { "$exe" }
Write-Host "Running: $cmdLine" -ForegroundColor Green

# Execute the program and capture the exit code
$rc = 0
try {
    & $exe @exeArgs
    $rc = $LASTEXITCODE
    if ($rc -eq $null) { $rc = 0 }
} catch {
    Write-Host "Error while executing command:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    $rc = 1
}

Write-Host ""
Write-Host "Command exit code: $rc" -ForegroundColor Cyan

# Pause if interactive and not explicitly disabled
if (-not $NoPause -and $Host.Name -eq 'ConsoleHost' -and -not $NoExit) {
    Write-Host ""
    Read-Host -Prompt "Press Enter to close"
}

# If -NoExit was not requested, exit with the same exit code as the command
if (-not $NoExit) {
    exit $rc
}
