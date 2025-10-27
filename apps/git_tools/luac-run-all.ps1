<#
luac-run-all.ps1

Run luac in parse-only mode (-p) across all .lua files under the specified root.
Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\luac-run-all.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .\luac-run-all.ps1 -Root "Custom\Client addons needed"
#>

param(
    [string]$Root = "Custom\Client addons needed"
)

Write-Host "Running luac -p for all .lua files under: $Root" -ForegroundColor Cyan

if (-not (Test-Path $Root)) {
    Write-Host "Root path not found: $Root" -ForegroundColor Red
    exit 2
}

$files = Get-ChildItem -Path $Root -Recurse -Filter "*.lua" -File
if (-not $files -or $files.Count -eq 0) {
    Write-Host "No .lua files found under $Root" -ForegroundColor Yellow
    exit 0
}

foreach ($f in $files) {
    Write-Host "Checking: $($f.FullName)" -ForegroundColor Gray
    & luac -p $f.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "luac returned non-zero for: $($f.FullName)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host "All .lua files parsed successfully." -ForegroundColor Green

# Now run luacheck if available for linting/style warnings
Write-Host ""; Write-Host "Checking for luacheck..." -ForegroundColor Cyan
$luacheck = (Get-Command luacheck -ErrorAction SilentlyContinue)
if ($luacheck) {
    Write-Host "luacheck found at: $($luacheck.Path) - running lint checks..." -ForegroundColor Green
    # Build an array of full paths to pass to luacheck
    $paths = $files | ForEach-Object { $_.FullName }
    if ($paths.Count -gt 0) {
        # Avoid extremely long command-lines by running luacheck in batches.
        # Windows/PowerShell can fail when a command line becomes too long when passing thousands of files.
        $batchSize = 200
        $hadIssues = $false
        for ($i = 0; $i -lt $paths.Count; $i += $batchSize) {
            $end = [math]::Min($i + $batchSize - 1, $paths.Count - 1)
            $batch = $paths[$i..$end]
            Write-Host "Running luacheck on files $i..$end (count: $($batch.Count))" -ForegroundColor Gray
            # Call luacheck using the full path returned by Get-Command to avoid PATH/shim quoting issues on Windows
            if ($luacheck.Path) {
                & $luacheck.Path @batch
            } else {
                & luacheck @batch
            }
            if ($LASTEXITCODE -ne 0) {
                Write-Host "luacheck reported issues in batch starting at index $i (exit code $LASTEXITCODE)" -ForegroundColor Red
                $hadIssues = $true
                break
            }
        }
        if ($hadIssues) {
            exit $LASTEXITCODE
        } else {
            Write-Host "luacheck: no issues found." -ForegroundColor Green
        }
    } else {
        Write-Host "No files to lint for luacheck." -ForegroundColor Yellow
    }
} else {
    Write-Host "luacheck not found on PATH; skipping lint step." -ForegroundColor Yellow
}

Write-Host "All checks passed." -ForegroundColor Green
exit 0
