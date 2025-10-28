# Convert full map image to tiled BLP files for WoW 3.3.5a
# This script splits a large map image into 4x3 tiles and converts to BLP1 format

param(
    [string]$SourceImage = "C:\Users\flori\Desktop\WoW Server\azshara_crater.png",
    [string]$OutputFolder = "$PSScriptRoot\Textures\AzsharaCrater",
    [string]$MapName = "AzsharaCrater",
    [int]$TileRows = 3,
    [int]$TileCols = 4,
    [int]$TileSize = 512  # Power of 2: 256, 512, 1024
)

$magick = "C:\Users\flori\Desktop\WoW Server\ImageMagick-7.1.2-7-portable-Q16-x64\magick.exe"
$blpConverter = "C:\Users\flori\Desktop\WoW Server\BLPConverter.exe"  # You'll need this

Write-Host "=== WoW Map Tile Converter ===" -ForegroundColor Cyan
Write-Host "Source: $SourceImage"
Write-Host "Output: $OutputFolder"
Write-Host "Tiles: $TileCols x $TileRows"
Write-Host "Size per tile: ${TileSize}x${TileSize}"
Write-Host ""

# Check if source exists
if (-not (Test-Path $SourceImage)) {
    Write-Host "ERROR: Source image not found: $SourceImage" -ForegroundColor Red
    exit 1
}

# Check if ImageMagick exists
if (-not (Test-Path $magick)) {
    Write-Host "ERROR: ImageMagick not found: $magick" -ForegroundColor Red
    exit 1
}

# Create temp and output folders
$tempFolder = Join-Path $PSScriptRoot "temp_tiles"
New-Item -ItemType Directory -Force -Path $tempFolder | Out-Null
New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null

Write-Host "Step 1: Getting source image dimensions..." -ForegroundColor Yellow
$identify = & $magick identify -format "%w %h" $SourceImage
$dimensions = $identify -split " "
$sourceWidth = [int]$dimensions[0]
$sourceHeight = [int]$dimensions[1]
Write-Host "  Source image: ${sourceWidth}x${sourceHeight}" -ForegroundColor Green

# Calculate total size needed (must be divisible by tile count)
$totalWidth = $TileCols * $TileSize
$totalHeight = $TileRows * $TileSize
Write-Host "  Target total: ${totalWidth}x${totalHeight}" -ForegroundColor Green

Write-Host ""
Write-Host "Step 2: Resizing and preparing image..." -ForegroundColor Yellow
$resizedImage = Join-Path $tempFolder "resized.png"

# Resize to exact dimensions, maintaining aspect ratio with padding if needed
& $magick $SourceImage `
    -resize "${totalWidth}x${totalHeight}^" `
    -gravity center `
    -extent "${totalWidth}x${totalHeight}" `
    -background "#8B7355" `
    $resizedImage

if (-not (Test-Path $resizedImage)) {
    Write-Host "ERROR: Failed to resize image" -ForegroundColor Red
    exit 1
}
Write-Host "  Resized image created" -ForegroundColor Green

Write-Host ""
Write-Host "Step 3: Splitting into tiles..." -ForegroundColor Yellow

$tileIndex = 1
for ($row = 0; $row -lt $TileRows; $row++) {
    for ($col = 0; $col -lt $TileCols; $col++) {
        $x = $col * $TileSize
        $y = $row * $TileSize
        
        $tgaFile = Join-Path $tempFolder "${MapName}${tileIndex}.tga"
        
        Write-Host "  Creating tile $tileIndex (row $row, col $col) at ${x},${y}..." -ForegroundColor Gray
        
        # Extract tile and save as uncompressed TGA (WoW compatible)
        & $magick $resizedImage `
            -crop "${TileSize}x${TileSize}+${x}+${y}" `
            +repage `
            -depth 24 `
            -define tga:image-origin=bottom-left `
            -compress none `
            "TGA:$tgaFile"
        
        if (Test-Path $tgaFile) {
            $fileSize = (Get-Item $tgaFile).Length
            Write-Host "    [OK] Tile $tileIndex created ($fileSize bytes)" -ForegroundColor Green
        } else {
            Write-Host "    [FAIL] Failed to create tile $tileIndex" -ForegroundColor Red
        }
        
        $tileIndex++
    }
}

Write-Host ""
Write-Host "Step 4: Converting TGA to BLP (if BLPConverter available)..." -ForegroundColor Yellow

# Check if BLP converter is available
if (Test-Path $blpConverter) {
    Write-Host "  BLPConverter found - converting to BLP1..." -ForegroundColor Green
    
    for ($i = 1; $i -le 12; $i++) {
        $tgaFile = Join-Path $tempFolder "${MapName}${i}.tga"
        $blpFile = Join-Path $OutputFolder "${MapName}${i}.blp"
        
        if (Test-Path $tgaFile) {
            & $blpConverter $tgaFile $blpFile --format=blp1 --compression=dxt1
            Write-Host "    [OK] Converted tile $i to BLP" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  BLPConverter not found - copying TGA files instead" -ForegroundColor Yellow
    Write-Host "  WoW 3.3.5a supports TGA files directly!" -ForegroundColor Cyan
    
    # Copy TGA files to output folder
    for ($i = 1; $i -le 12; $i++) {
        $tgaFile = Join-Path $tempFolder "${MapName}${i}.tga"
        $outputTga = Join-Path $OutputFolder "${MapName}${i}.tga"
        
        if (Test-Path $tgaFile) {
            Copy-Item $tgaFile $outputTga -Force
            Write-Host "    [OK] Copied tile $i as TGA" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "  NOTE: Using TGA format. To use BLP:" -ForegroundColor Yellow
    Write-Host "  1. Download BLPConverter from: https://github.com/Kanma/BLPConverter" -ForegroundColor Gray
    Write-Host "  2. Place BLPConverter.exe at: $blpConverter" -ForegroundColor Gray
    Write-Host "  3. Run this script again" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Step 5: Cleaning up..." -ForegroundColor Yellow
# Remove-Item -Recurse -Force $tempFolder
Write-Host "  Temp files kept in: $tempFolder" -ForegroundColor Gray

Write-Host ""
Write-Host "=== COMPLETE ===" -ForegroundColor Green
Write-Host "Tiles created in: $OutputFolder" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Update DC-MapExtension Core.lua to use .tga extension" -ForegroundColor Gray
Write-Host "2. Or convert TGA files to BLP1 format" -ForegroundColor Gray
Write-Host "3. /reload in-game and test with /dcmap blptest" -ForegroundColor Gray
Write-Host ""

# List created files
Write-Host "Created files:" -ForegroundColor Cyan
Get-ChildItem $OutputFolder | ForEach-Object {
    $size = "{0:N0}" -f $_.Length
    Write-Host "  $($_.Name) - $size bytes" -ForegroundColor Gray
}
