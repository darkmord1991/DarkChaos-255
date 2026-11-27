<#!
.SYNOPSIS
Checks addon startup hazards that plain luac/luacheck scans miss.

.DESCRIPTION
Runs tools/check_addon_startup.py and preserves the exit code for task usage.
#>

param(
    [string]$Root = "Custom\Client addons needed",
    [string[]]$Addon = @(),
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command py -ErrorAction SilentlyContinue
}

if (-not $python) {
    Write-Host "ERROR: python or py was not found on PATH." -ForegroundColor Red
    exit 2
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$scriptPath = Join-Path $repoRoot "tools\check_addon_startup.py"

if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: startup checker script not found: $scriptPath" -ForegroundColor Red
    exit 2
}

Push-Location $repoRoot
try {
    $arguments = @($scriptPath, "--root", $Root)
    $normalizedAddons = @()
    foreach ($value in $Addon) {
        foreach ($piece in ($value -split ",")) {
            $name = $piece.Trim()
            if ($name) {
                $normalizedAddons += $name
            }
        }
    }

    foreach ($name in $normalizedAddons) {
        $arguments += "--addon"
        $arguments += $name
    }

    & $python.Path @arguments
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if (-not $NoPause -and $exitCode -ne 0) {
    Read-Host "Press Enter to exit"
}

exit $exitCode