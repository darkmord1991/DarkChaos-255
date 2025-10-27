<#
luacheck-dc-run.ps1
Run luacheck on each .lua file under the given root, invoking the explicit luacheck executable path to avoid quoting/shim issues.
Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\luacheck-dc-run.ps1 -Root "Custom\Client addons needed\DCHotspotXP"
#>

param(
    [string]$Root = "Custom\Client addons needed\DCHotspotXP"
)

Write-Host "Running luacheck for .lua files under: $Root" -ForegroundColor Cyan

$luacheck = Get-Command luacheck -ErrorAction SilentlyContinue
if (-not $luacheck) {
    Write-Host "luacheck not found on PATH" -ForegroundColor Red
    exit 2
}

if (-not (Test-Path $Root)) {
    Write-Host "Root path not found: $Root" -ForegroundColor Red
    exit 2
}

$files = Get-ChildItem -Path $Root -Recurse -Filter "*.lua" -File
if (-not $files -or $files.Count -eq 0) {
    Write-Host "No .lua files found under $Root" -ForegroundColor Yellow
    exit 0
}

$hadIssues = $false
foreach ($f in $files) {
    Write-Host "Running luacheck on: $($f.FullName)" -ForegroundColor Gray
    & $luacheck.Path $f.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "luacheck reported issues for: $($f.FullName) (exit $LASTEXITCODE)" -ForegroundColor Red
        $hadIssues = $true
    }
}

if ($hadIssues) { exit 1 } else { Write-Host "luacheck: no issues found." -ForegroundColor Green; exit 0 }
