param(
    [string]$Hash
)

# Simple script to append a short git hash to HLBG.VERSION automatically.
# Usage (PowerShell):
#   $h = (git rev-parse --short HEAD); powershell -File build-tools/update_version_hash.ps1 -Hash $h
# Adjust path if running from repository root.

if (-not $Hash) {
    Write-Host "No hash provided; exiting." -ForegroundColor Yellow
    exit 1
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Join-Path $root '..' | Join-Path -ChildPath 'core'
$versionFile = Join-Path $addonRoot 'HLBG_Version.lua'

if (-not (Test-Path $versionFile)) {
    Write-Host "Version file not found: $versionFile" -ForegroundColor Red
    exit 2
}

$content = Get-Content $versionFile -Raw
# Match the VERSION assignment. Preserve prefix comment and replace only the string literal.
if ($content -match "HLBG.VERSION = '([0-9A-Za-z\.-]+)(\+g[0-9a-f]+)?'") {
    $base = $Matches[1]
    $newLine = "HLBG.VERSION = '$base+g$Hash'"
    $updated = $content -replace "HLBG.VERSION = '.*'", $newLine
    Set-Content -Path $versionFile -Value $updated -Encoding UTF8
    Write-Host "Updated HLBG.VERSION to $base+g$Hash" -ForegroundColor Green
} else {
    Write-Host "Could not locate HLBG.VERSION assignment" -ForegroundColor Red
    exit 3
}
