# Quick conversion script for Hyjal Summit map
# Save your Hyjal Summit image and update the $SourceImage path below

param(
    [string]$SourceImage = "C:\Users\flori\Desktop\WoW Server\hyjal_summit.png"
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$converterScript = Join-Path $scriptPath "convert_map_to_tiles.ps1"

Write-Host "=== Converting Hyjal Summit Map ===" -ForegroundColor Cyan
Write-Host "Source: $SourceImage"
Write-Host ""

if (-not (Test-Path $SourceImage)) {
    Write-Host "ERROR: Source image not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please save your Hyjal Summit image to one of these locations:" -ForegroundColor Yellow
    Write-Host "  1. C:\Users\flori\Desktop\WoW Server\hyjal_summit.png" -ForegroundColor Gray
    Write-Host "  2. Or specify path: .\convert_hyjal.ps1 -SourceImage 'C:\path\to\image.png'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "You can download the Hyjal Summit map from:" -ForegroundColor Cyan
    Write-Host "  https://wowwiki-archive.fandom.com/wiki/Hyjal_Summit" -ForegroundColor Gray
    exit 1
}

# Run the main conversion script
& $converterScript -SourceImage $SourceImage -MapName "Hyjal" -OutputFolder (Join-Path $scriptPath "Textures\Hyjal")

Write-Host ""
Write-Host "=== Hyjal Summit Conversion Complete ===" -ForegroundColor Green
Write-Host "Files created in: Textures\Hyjal\" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: /reload in-game and visit Hyjal Summit (Zone 616)" -ForegroundColor Yellow
