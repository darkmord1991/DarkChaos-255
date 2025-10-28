# 🔧 DC-MapExtension Installation Instructions

## ⚠️ CRITICAL: Maps Must Be In WoW Client Folder!

**The addon was NOT working because WoW loads map textures from the CLIENT folder, not from addon folders!**

This is how Blizzard's own maps work (checked in MPQ extracts) - all map tiles are in:
```
<WoW Client>\Interface\WorldMap\<MapName>\
```

## 📋 Manual Installation (Easiest Method)

### Step 1: Locate Your WoW Client
Find your WoW 3.3.5a installation folder (the one containing `Wow.exe`).

Example locations:
- `C:\Program Files (x86)\World of Warcraft`
- `C:\Games\World of Warcraft`
- `D:\World of Warcraft`

### Step 2: Copy Map Files

1. **For Azshara Crater:**
   - Source: `DC-MapExtension\Textures\AzsharaCrater\*.blp`
   - Destination: `<WoW Client>\Interface\WorldMap\AzsharaCrater\`
   
   Create the `AzsharaCrater` folder if it doesn't exist, then copy all 12 BLP files.

2. **For Hyjal:**
   - Source: `DC-MapExtension\Textures\Hyjal\*.blp`
   - Destination: `<WoW Client>\Interface\WorldMap\Hyjal\`
   
   Create the `Hyjal` folder if it doesn't exist, then copy all 12+ BLP files.

### Step 3: Install the Addon
Copy the entire `DC-MapExtension` folder to:
```
<WoW Client>\Interface\AddOns\DC-MapExtension\
```

### Step 4: Launch WoW
1. Start WoW 3.3.5a
2. At character selection, click "AddOns" button
3. Ensure "DC-MapExtension" is enabled
4. Login to character

### Step 5: Test
1. Teleport to Azshara Crater or Hyjal Summit
2. Press `M` to open world map
3. Type `/dcmap status` to verify detection
4. The custom map should now display correctly!

---

## 🤖 Automatic Installation (PowerShell Script)

### Option 1: Using install_to_client.ps1

Run this in PowerShell:
```powershell
cd "path\to\DC-MapExtension"
.\install_to_client.ps1 -WoWClientPath "C:\Path\To\Your\WoW"
```

The script will automatically copy all map files to the correct locations.

---

## 🔍 Why This Was Necessary

### The Problem:
- **Addon path**: `Interface\AddOns\DC-MapExtension\Textures\...` ❌ (Doesn't work!)
- **Correct path**: `Interface\WorldMap\AzsharaCrater\...` ✅ (Works!)

### The Discovery:
1. Checked MPQ extracts at `G:\WoW Boost MPQ extract\Interface\WorldMap\`
2. Found Blizzard's AzsharaCrater and Hyjal map files
3. Confirmed file structure: `Interface\WorldMap\<MapName>\<MapName>1.blp` through `<MapName>12.blp`
4. Realized WoW hard-codes map texture paths to `Interface\WorldMap\`

### The Fix:
- ✅ Copied correct BLP files from MPQ extract (fixed file size issues)
- ✅ Updated Core.lua to use `Interface\WorldMap\` paths (not addon paths)
- ✅ Created installer script to copy files to WoW client folder

---

## 📦 File Verification

### Azshara Crater - Correct File Sizes:
```
AzsharaCrater1.blp  - 88,580 bytes
AzsharaCrater2.blp  - 44,876 bytes
AzsharaCrater3.blp  - 44,876 bytes
AzsharaCrater4.blp  - 88,580 bytes
AzsharaCrater5.blp  - 88,580 bytes
AzsharaCrater6.blp  - 44,876 bytes
AzsharaCrater7.blp  - 44,876 bytes
AzsharaCrater8.blp  - 88,580 bytes
AzsharaCrater9.blp  - 88,580 bytes
AzsharaCrater10.blp - 88,580 bytes
AzsharaCrater11.blp - 88,580 bytes
AzsharaCrater12.blp - 88,580 bytes
```

If your files don't match these sizes, they're corrupted! Use the ones in the addon's `Textures` folder (now copied from MPQ extract).

---

## 🎮 In-Game Commands

- `/dcmap debug` - Toggle debug mode
- `/dcmap status` - Show current zone and map detection
- `/dcmap show` - Show custom maps
- `/dcmap hide` - Hide custom maps
- `/dcmap blptest` - Test if texture files can load

---

## 🐛 Troubleshooting

### Maps Still Not Showing?
1. **Verify files are in WoW client folder** (not just addon folder!)
   - Check: `<WoW Client>\Interface\WorldMap\AzsharaCrater\AzsharaCrater1.blp` exists
   - Check: `<WoW Client>\Interface\WorldMap\Hyjal\Hyjal1.blp` exists

2. **Enable debug mode**: `/dcmap debug`
   - Look for "Azshara detected" or "Hyjal detected" messages
   - Check what map ID is shown

3. **Restart WoW completely** (not just /reload)

4. **Check Interface Options**:
   - Press `Esc` → Interface → AddOns → DC-MapExtension
   - Ensure "Enable Custom Maps" is checked

### Still Rainbow Corruption?
- Files are still in wrong location or wrong format
- Make sure you copied files from `Textures` folder in addon (these are now correct from MPQ extract)

---

## 📝 Technical Notes

### Zone Detection:
- **Azshara Crater**: Map ID 37, 614, or zone name contains "Azshara Crater"
- **Hyjal Summit**: Map ID 616, 9002, or zone name contains "Hyjal"

### Texture Format:
- **Format**: BLP1 (extracted from official MPQ files)
- **Compression**: DXT1/DXT5
- **Tile Count**: 12 tiles in 4x3 grid
- **Tile Size**: 256x256 pixels

### Why Not Addon Path?
WoW's texture loading system has hard-coded paths for map files. The game specifically looks in:
```
Interface\WorldMap\<MapName>\
```

This is the same path used for all Blizzard maps like Karazhan, BlackTemple, etc.
