<#
fix-lua-whitespace.ps1
Trim trailing whitespace and remove whitespace-only lines from .lua files under a root.
By default this operates on 'Custom\Client addons needed' and excludes common vendor folders.
Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\fix-lua-whitespace.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .\fix-lua-whitespace.ps1 -Root "Custom\Client addons needed" -WhatIf
#>

param(
    [string]$Root = "Custom\Client addons needed",
    [switch]$WhatIf
)

$exclusions = @(
    '\\Libs\\',
    '\\Ace3\\',
    '\\Archive\\',
    '\\Mapster\\',
    '\\WDM\\',
    '\\GatherMate\\'
)

function Is-ExcludedPath($path) {
    foreach ($e in $exclusions) {
        if ($path -like "*$e*") { return $true }
    }
    return $false
}

if (-not (Test-Path $Root)) { Write-Host "Root not found: $Root" -ForegroundColor Red; exit 2 }

$files = Get-ChildItem -Path $Root -Recurse -Filter "*.lua" -File | Where-Object { -not (Is-ExcludedPath $_.FullName) }
if (-not $files -or $files.Count -eq 0) { Write-Host "No non-vendor .lua files found under $Root" -ForegroundColor Yellow; exit 0 }

$modified = 0
foreach ($f in $files) {
    $text = Get-Content -Raw -Encoding UTF8 -Path $f.FullName
    # Remove trailing whitespace on each line
    $new = ($text -split "\r?\n") | ForEach-Object { $_ -replace '\s+$', '' } | Where-Object { $_ -ne '' } | Out-String
    # Out-String appends final newline; ensure consistent encoding
    if ($new -ne $text) {
        if ($WhatIf) {
            Write-Host "Would modify: $($f.FullName)" -ForegroundColor Yellow
        } else {
            Set-Content -Path $f.FullName -Value $new -Encoding UTF8
            Write-Host "Fixed whitespace: $($f.FullName)" -ForegroundColor Green
            $modified++
        }
    }
}
Write-Host "Whitespace-fix complete. Files modified: $modified" -ForegroundColor Cyan
exit 0
