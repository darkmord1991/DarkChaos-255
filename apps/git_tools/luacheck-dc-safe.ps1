<#
luacheck-dc-safe.ps1
Run luacheck on each .lua file under the given root with error-safe handling.
This version prevents the PowerShell window from closing on errors.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\luacheck-dc-safe.ps1 -Root "Custom\Client addons needed\DC-HotspotXP"
  
Or double-click this file to check default addons with interactive prompt.
#>

param(
    [string]$Root = "Custom\Client addons needed",
    [switch]$PauseOnExit = $true,
    [switch]$ShowSummary = $true
)

# Trap errors to prevent window from closing
$ErrorActionPreference = "Continue"

function Pause-OnExit {
    if ($PauseOnExit) {
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Ensure we always pause on exit (even on Ctrl+C)
trap {
    Write-Host "Script interrupted or error occurred: $_" -ForegroundColor Red
    Pause-OnExit
    exit 1
}

Write-Host "=== DC Addons LuaCheck (Safe Mode) ===" -ForegroundColor Cyan
Write-Host ""

# Check for luacheck
$luacheck = Get-Command luacheck -ErrorAction SilentlyContinue
if (-not $luacheck) {
    Write-Host "ERROR: luacheck not found on PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "To install luacheck, run: .\install-luacheck.ps1" -ForegroundColor Yellow
    Write-Host "Or install manually via: luarocks install luacheck" -ForegroundColor Yellow
    Pause-OnExit
    exit 2
}

Write-Host "Found luacheck at: $($luacheck.Path)" -ForegroundColor Green

# Check root path
if (-not (Test-Path $Root)) {
    Write-Host "ERROR: Root path not found: $Root" -ForegroundColor Red
    Pause-OnExit
    exit 2
}

Write-Host "Scanning for .lua files in: $Root" -ForegroundColor Cyan
Write-Host ""

# Find all .lua files
$files = Get-ChildItem -Path $Root -Recurse -Filter "*.lua" -File
if (-not $files -or $files.Count -eq 0) {
    Write-Host "No .lua files found under $Root" -ForegroundColor Yellow
    Pause-OnExit
    exit 0
}

Write-Host "Found $($files.Count) .lua file(s)" -ForegroundColor Cyan
Write-Host ""

# Track results
$results = @{
    Total = 0
    Clean = 0
    Warnings = 0
    Errors = 0
    Failed = @()
}

# Process each file
foreach ($f in $files) {
    $results.Total++
    $relPath = $f.FullName.Replace((Get-Location).Path + "\", "")
    
    Write-Host "[$($results.Total)/$($files.Count)] Checking: $relPath" -ForegroundColor Gray
    
    try {
        # Capture output
        $output = & $luacheck.Path $f.FullName 2>&1
        $exitCode = $LASTEXITCODE
        
        # Show output
        $output | ForEach-Object { Write-Host "  $_" }
        
        # Categorize result
        if ($exitCode -eq 0) {
            Write-Host "  ✓ OK" -ForegroundColor Green
            $results.Clean++
        } elseif ($exitCode -eq 1) {
            # Exit code 1 = warnings found
            Write-Host "  ⚠ Warnings found" -ForegroundColor Yellow
            $results.Warnings++
            $results.Failed += @{ File = $relPath; ExitCode = $exitCode }
        } else {
            # Exit code 2+ = errors
            Write-Host "  ✗ Errors found (exit code $exitCode)" -ForegroundColor Red
            $results.Errors++
            $results.Failed += @{ File = $relPath; ExitCode = $exitCode }
        }
    }
    catch {
        Write-Host "  ✗ Exception: $_" -ForegroundColor Red
        $results.Errors++
        $results.Failed += @{ File = $relPath; ExitCode = -1 }
    }
    
    Write-Host ""
}

# Show summary
if ($ShowSummary) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total files checked: $($results.Total)" -ForegroundColor White
    Write-Host "Clean (no issues):   $($results.Clean)" -ForegroundColor Green
    Write-Host "Warnings:            $($results.Warnings)" -ForegroundColor Yellow
    Write-Host "Errors:              $($results.Errors)" -ForegroundColor Red
    Write-Host ""
    
    if ($results.Failed.Count -gt 0) {
        Write-Host "Files with issues:" -ForegroundColor Yellow
        foreach ($item in $results.Failed) {
            $color = if ($item.ExitCode -eq 1) { "Yellow" } else { "Red" }
            Write-Host "  - $($item.File) (exit $($item.ExitCode))" -ForegroundColor $color
        }
        Write-Host ""
    }
    
    # Overall status
    if ($results.Errors -gt 0) {
        Write-Host "RESULT: FAILED (errors found)" -ForegroundColor Red
        $finalExitCode = 1
    } elseif ($results.Warnings -gt 0) {
        Write-Host "RESULT: PASSED (warnings only)" -ForegroundColor Yellow
        $finalExitCode = 0
    } else {
        Write-Host "RESULT: PASSED (all clean)" -ForegroundColor Green
        $finalExitCode = 0
    }
}

Pause-OnExit
exit $finalExitCode
