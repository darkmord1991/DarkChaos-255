<#
install-luacheck.ps1
Attempts to install luacheck on Windows by trying available package managers in order:
  1) luarocks (if present)
  2) scoop (install luacheck or luarocks)
  3) chocolatey (install luacheck or luarocks)

The script is conservative: it will stop on first successful install and prints clear instructions if automatic install isn't possible.
Run with: powershell -NoProfile -ExecutionPolicy Bypass -File .\install-luacheck.ps1
#>

Write-Host "=== install-luacheck ===" -ForegroundColor Cyan

function Try-Command { param($name) $c = Get-Command $name -ErrorAction SilentlyContinue; return $c }

$luacheckCmd = Try-Command "luacheck"
if ($luacheckCmd) {
    Write-Host "luacheck is already on PATH at: $($luacheckCmd.Path)" -ForegroundColor Green
    exit 0
}

$luarocksCmd = Try-Command "luarocks"
$scoopCmd = Try-Command "scoop"
$chocoCmd = Try-Command "choco"

# Helper to run a command and return exit code
function Run-Capture { param([string]$exe, [string[]]$args) 
    try {
        Write-Host "Running: $exe $($args -join ' ')" -ForegroundColor Yellow
        & $exe @args
        $rc = $LASTEXITCODE
        if ($rc -eq $null) { $rc = 0 }
        return $rc
    } catch {
        Write-Host "Command failed: $_" -ForegroundColor Red
        return 1
    }
}

# 1) Try luarocks if available
if ($luarocksCmd) {
    Write-Host "Found luarocks at: $($luarocksCmd.Path). Installing luacheck via luarocks..." -ForegroundColor Cyan
    $rc = Run-Capture $luarocksCmd.Path @("install","luacheck")
    if ($rc -eq 0) {
        Write-Host "luacheck installed successfully via luarocks." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "luarocks install luacheck failed (exit $rc)." -ForegroundColor Red
    }
}

# 2) Try scoop if present
if ($scoopCmd) {
    Write-Host "Scoop detected. Trying 'scoop install luacheck'..." -ForegroundColor Cyan
    $rc = Run-Capture $scoopCmd.Path @("install","luacheck")
    if ($rc -eq 0) {
        Write-Host "luacheck installed successfully via scoop." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "scoop install luacheck failed or not available in buckets (exit $rc). Trying to install luarocks via scoop..." -ForegroundColor Yellow
        $rc2 = Run-Capture $scoopCmd.Path @("install","luarocks")
        if ($rc2 -eq 0) {
            Write-Host "luarocks installed via scoop, attempting 'luarocks install luacheck'..." -ForegroundColor Cyan
            $luarocksCmd = Try-Command "luarocks"
            if ($luarocksCmd) {
                $rc3 = Run-Capture $luarocksCmd.Path @("install","luacheck")
                if ($rc3 -eq 0) { Write-Host "luacheck installed successfully via luarocks (scoop)." -ForegroundColor Green; exit 0 }
            }
        } else {
            Write-Host "scoop couldn't install luarocks (exit $rc2)." -ForegroundColor Yellow
        }
    }
}

# 3) Try chocolatey
if ($chocoCmd) {
    Write-Host "Chocolatey detected. Trying 'choco install luacheck -y'..." -ForegroundColor Cyan
    $rc = Run-Capture $chocoCmd.Path @("install","luacheck","-y")
    if ($rc -eq 0) { Write-Host "luacheck installed successfully via chocolatey." -ForegroundColor Green; exit 0 }
    else {
        Write-Host "choco install luacheck failed (exit $rc). Trying 'choco install luarocks -y'..." -ForegroundColor Yellow
        $rc2 = Run-Capture $chocoCmd.Path @("install","luarocks","-y")
        if ($rc2 -eq 0) {
            Write-Host "luarocks installed via chocolatey, attempting 'luarocks install luacheck'..." -ForegroundColor Cyan
            $luarocksCmd = Try-Command "luarocks"
            if ($luarocksCmd) {
                $rc3 = Run-Capture $luarocksCmd.Path @("install","luacheck")
                if ($rc3 -eq 0) { Write-Host "luacheck installed successfully via luarocks (choco)." -ForegroundColor Green; exit 0 }
            }
        } else { Write-Host "choco couldn't install luarocks (exit $rc2)." -ForegroundColor Yellow }
    }
}

# If we reached here, automatic install failed or no package manager available
Write-Host "Automatic install did not succeed or no suitable package manager found." -ForegroundColor Red
Write-Host "Manual options:" -ForegroundColor Cyan
Write-Host "  * Install Lua and LuaRocks, then run: luarocks install luacheck" -ForegroundColor Gray
Write-Host "  * If you use Scoop: try 'scoop install luacheck' or add the appropriate bucket and try again." -ForegroundColor Gray
Write-Host "  * If you use Chocolatey: try 'choco install luacheck' or install luarocks then run luarocks install luacheck." -ForegroundColor Gray
Write-Host "If you want, I can attempt more specific steps (install Lua/LuaRocks first)." -ForegroundColor Cyan

exit 2
