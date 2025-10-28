# BLP File Corruption - Fix Guide

## Problem
Your BLP files are showing as "rainbow corruption" in-game, which means they're in an invalid format for WoW 3.3.5a.

## Why This Happens
- BLP files must be **BLP1 format** (not BLP2)
- Dimensions must be **power of 2** (256x256, 512x512, 1024x1024, etc.)
- Must use proper compression (DXT1, DXT3, or DXT5)
- WoW 3.3.5a doesn't support newer BLP formats

## Solution Options

### Option 1: Use BLPConverter (Recommended)
1. Download BLPConverter from: https://www.wowinterface.com/downloads/info14110
2. Convert your map images:
   - Input: Your source images (PNG/TGA/JPG)
   - Output format: **BLP1**
   - Compression: **DXT1** (for maps without alpha) or **DXT3/DXT5** (if you need transparency)
   - Mipmaps: **Generate**
   - Size: Must be power-of-2 (e.g., 512x512, 1024x1024)

### Option 2: Use WoW's Built-in Map Textures (Temporary Fix)
Until you get proper BLP files, we can use Blizzard's existing map textures.

### Option 3: Convert to TGA (Alternative)
WoW 3.3.5a also supports TGA files:
1. Convert your images to uncompressed 24-bit or 32-bit TGA
2. Rename: `AzsharaCrater1.tga`, etc.
3. Place in same folder as BLP files
4. Update addon to try TGA first, then BLP

## Quick Test

### Check if BLP files are readable:
```lua
/run local t = CreateFrame("Frame"):CreateTexture(); t:SetTexture("Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater1.blp"); print("Texture:", t:GetTexture() or "FAILED")
```

If output is "FAILED", the BLP is corrupted.

### Test with a known-good WoW texture:
```lua
/run local t = CreateFrame("Frame"):CreateTexture(); t:SetTexture("Interface\\WorldMap\\Azeroth\\Azeroth1"); print("Test:", t:GetTexture())
```

Should output the texture path successfully.

## How to Convert Your Maps

### Using Photoshop + BLP Plugin:
1. Install BLP plugin for Photoshop
2. Open your map image
3. Resize to power-of-2 dimensions:
   - Recommended: 1024x1024 per tile for quality
   - Or 512x512 for smaller file size
4. Save As -> BLP
5. Format: BLP1
6. Compression: DXT1

### Using GIMP + BLP Plugin:
1. Install GIMP BLP plugin
2. Open your map image
3. Resize canvas to power-of-2
4. Export as BLP1 with DXT1 compression

### Using Command-Line (ImageMagick + BLPConvert):
```bash
# Resize to 512x512 and convert
convert source.png -resize 512x512! temp.tga
blpconvert temp.tga output.blp --format=blp1 --compression=dxt1
```

## Current BLP File Analysis

Your files:
```
AzsharaCrater1.blp   88579 bytes
AzsharaCrater2.blp   44874 bytes  <- Different size, possibly different format
AzsharaCrater3.blp   44875 bytes
...
```

**Issue**: Inconsistent file sizes suggest mixed formats or corruption.

**Expected**: All tiles should be similar size if same dimensions/compression.

## Temporary Workaround

While fixing BLP files, I can modify the addon to:
1. Show error tiles (red question marks) where BLPs fail
2. Use placeholder textures
3. Fall back to showing standard Blizzard maps

## After Converting

1. Replace all BLP files in:
   - `DC-MapExtension\Textures\AzsharaCrater\`
   - `DC-MapExtension\Textures\Hyjal\`

2. Test in-game:
   ```
   /reload
   /dcmap debug
   ```

3. Open map - should see debug messages showing SUCCESS

## Need Help?

If you provide the **source images** (PNG/JPG/TGA), I can guide you through the exact conversion process.

Or if you have:
- WoW map editing tools (like Noggit)
- Original WMO/ADT files
- Map source files

...I can help configure the proper export settings.
