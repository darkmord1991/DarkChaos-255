# HLBG Cleanup Script
# This script removes all unnecessary files and keeps only the clean versions

Write-Host "Cleaning up HLBG addon files..." -ForegroundColor Green

$addonPath = "c:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255\Custom\Client addons needed\HinterlandAffixHUD"

# Files to keep (essentials only)
$keepFiles = @(
    "HinterlandAffixHUD_Clean.toc",
    "HinterlandAffixHUD_Clean.lua", 
    "HLBG_AIO_Client.lua",
    "README.md"
)

# Get all HLBG files
$allFiles = Get-ChildItem -Path $addonPath -Name "HLBG*" -File
$allTocFiles = Get-ChildItem -Path $addonPath -Name "*.toc" -File

Write-Host "Found $($allFiles.Count) HLBG files and $($allTocFiles.Count) TOC files" -ForegroundColor Yellow

# Remove old files (backup first)
$backupPath = "$addonPath\Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

Write-Host "Creating backup in: $backupPath" -ForegroundColor Cyan

foreach ($file in $allFiles) {
    $fullPath = Join-Path $addonPath $file
    if (Test-Path $fullPath) {
        # Backup
        Copy-Item $fullPath "$backupPath\$file" -Force
        
        # Remove if not essential
        if ($file -notin $keepFiles) {
            Remove-Item $fullPath -Force
            Write-Host "Removed: $file" -ForegroundColor Red
        } else {
            Write-Host "Kept: $file" -ForegroundColor Green
        }
    }
}

# Handle TOC files
foreach ($tocFile in $allTocFiles) {
    $fullPath = Join-Path $addonPath $tocFile.Name
    if ($tocFile.Name -notin $keepFiles -and $tocFile.Name -ne "HinterlandAffixHUD.toc") {
        Copy-Item $fullPath "$backupPath\$($tocFile.Name)" -Force
        Remove-Item $fullPath -Force
        Write-Host "Removed TOC: $($tocFile.Name)" -ForegroundColor Red
    }
}

# Remove documentation files that are redundant
$docsToRemove = @("CHANGELOG.md", "IMPLEMENTATION_GUIDE.md", "LOAD_ORDER.md", "TROUBLESHOOTING.md", "UI_FIXES_CHANGELOG.md")
foreach ($doc in $docsToRemove) {
    $fullPath = Join-Path $addonPath $doc
    if (Test-Path $fullPath) {
        Copy-Item $fullPath "$backupPath\$doc" -Force
        Remove-Item $fullPath -Force
        Write-Host "Removed doc: $doc" -ForegroundColor Red
    }
}

Write-Host "`nCleanup complete!" -ForegroundColor Green
Write-Host "Backup created at: $backupPath" -ForegroundColor Cyan
Write-Host "Files remaining:" -ForegroundColor Yellow
Get-ChildItem -Path $addonPath -Name -File | Sort-Object