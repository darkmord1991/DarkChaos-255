# Install DC-MapExtension textures to WoW client Interface folder
# This script copies map tiles to where WoW actually looks for them

param(
    [string]$WoWClientPath = "C:\Users\flori\Desktop\WoW Server\3.3.5a Client"
)

Write-Host "=== DC-MapExtension Texture Installer ===" -ForegroundColor Cyan
Write-Host ""

# Find WoW.exe to locate client
if (-not (Test-Path $WoWClientPath)) {
    Write-Host "ERROR: WoW client not found at: $WoWClientPath" -ForegroundColor Red
    Write-Host "Please specify the correct path:" -ForegroundColor Yellow
    Write-Host "  .\install_to_client.ps1 -WoWClientPath 'C:\Path\To\WoW'" -ForegroundColor Gray
    exit 1
}

$InterfacePath = Join-Path $WoWClientPath "Interface\WorldMap"
if (-not (Test-Path $InterfacePath)) {
    Write-Host "ERROR: Interface\WorldMap folder not found!" -ForegroundColor Red
    Write-Host "Expected at: $InterfacePath" -ForegroundColor Gray
    exit 1
}

Write-Host "WoW Client: $WoWClientPath" -ForegroundColor Green
Write-Host "Installing to: $InterfacePath" -ForegroundColor Green
Write-Host ""

# Get addon path
$AddonPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceTextures = Join-Path $AddonPath "Textures"

if (-not (Test-Path $SourceTextures)) {
    Write-Host "ERROR: Textures folder not found in addon!" -ForegroundColor Red
    exit 1
}

# Copy Azshara Crater
$AzsharaSource = Join-Path $SourceTextures "AzsharaCrater"
$AzsharaDest = Join-Path $InterfacePath "AzsharaCrater"

if (Test-Path $AzsharaSource) {
    Write-Host "Installing Azshara Crater maps..." -ForegroundColor Yellow
    
    # Create destination folder
    New-Item -ItemType Directory -Force -Path $AzsharaDest | Out-Null
    
    # Copy TGA files (or BLP if no TGA exists)
    $copiedCount = 0
    for ($i = 1; $i -le 12; $i++) {
        $tgaFile = Join-Path $AzsharaSource "AzsharaCrater$i.tga"
        $blpFile = Join-Path $AzsharaSource "AzsharaCrater$i.blp"
        
        if (Test-Path $tgaFile) {
            Copy-Item $tgaFile $AzsharaDest -Force
            $copiedCount++
            Write-Host "  [OK] Copied AzsharaCrater$i.tga" -ForegroundColor Green
        } elseif (Test-Path $blpFile) {
            Copy-Item $blpFile $AzsharaDest -Force
            $copiedCount++
            Write-Host "  [OK] Copied AzsharaCrater$i.blp" -ForegroundColor Green
        }
    }
    Write-Host "  Total: $copiedCount files copied" -ForegroundColor Cyan
} else {
    Write-Host "WARNING: AzsharaCrater textures not found" -ForegroundColor Yellow
}

Write-Host ""

# Copy Hyjal
$HyjalSource = Join-Path $SourceTextures "Hyjal"
$HyjalDest = Join-Path $InterfacePath "Hyjal"

if (Test-Path $HyjalSource) {
    Write-Host "Installing Hyjal maps..." -ForegroundColor Yellow
    
    # Create destination folder
    New-Item -ItemType Directory -Force -Path $HyjalDest | Out-Null
    
    # Copy TGA files (or BLP if no TGA exists)
    $copiedCount = 0
    for ($i = 1; $i -le 12; $i++) {
        $tgaFile = Join-Path $HyjalSource "Hyjal$i.tga"
        $blpFile = Join-Path $HyjalSource "Hyjal$i.blp"
        
        if (Test-Path $tgaFile) {
            Copy-Item $tgaFile $HyjalDest -Force
            $copiedCount++
            Write-Host "  [OK] Copied Hyjal$i.tga" -ForegroundColor Green
        } elseif (Test-Path $blpFile) {
            Copy-Item $blpFile $HyjalDest -Force
            $copiedCount++
            Write-Host "  [OK] Copied Hyjal$i.blp" -ForegroundColor Green
        }
    }
    Write-Host "  Total: $copiedCount files copied" -ForegroundColor Cyan
} else {
    Write-Host "WARNING: Hyjal textures not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Map tiles installed to WoW client Interface folder." -ForegroundColor Cyan
Write-Host "The addon will now detect and use these maps automatically!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Start WoW" -ForegroundColor Gray
Write-Host "2. /reload if already in-game" -ForegroundColor Gray
Write-Host "3. Open map in Azshara Crater or Hyjal" -ForegroundColor Gray
Write-Host "4. Type /dcmap status to verify" -ForegroundColor Gray
