# DC-MapExtension Testing Guide

## Quick Fix Applied

### Issues Fixed:
1. **Zone Detection**: Changed from using `GetCurrentMapZone()` (returns index) to `GetZoneText()` (returns name)
2. **Azshara Crater**: Now checks Map ID 37, 614, AND zone name "Azshara Crater"
3. **Hyjal**: Now checks zone name "Hyjal" OR map ID 9002
4. **Better Debugging**: Enhanced status command shows all detection info

## Testing Steps

### 1. Reload the Addon
```
/reload
```

### 2. Enable Debug Mode
```
/dcmap debug
```

### 3. Check Current Status
```
/dcmap status
```

This will show:
- Current Map ID
- Zone Name (what GetZoneText() returns)
- Real Zone (what GetRealZoneText() returns)
- Whether Azshara or Hyjal is detected
- Stitch frame status

### 4. Test Azshara Crater

**Teleport to Azshara Crater:**
```
.go xyz 138.609 1005.68 295.082 37 268
```

**Open World Map (M key)**

**Expected Results:**
- Debug message: "Azshara detected via map ID: 37" (or zone name)
- Debug message: "Custom map type detected: azshara"
- Debug message: "Map changed from nil to azshara"
- Debug message: "Loaded 12 tiles for azshara"
- Debug message: "Custom map shown: azshara"
- **Map should show Azshara Crater tiles** (no more blank/rainbow)

**Check with:**
```
/dcmap status
```

Should show:
- Custom Map Detected: azshara
- IsAzsharaCrater(): YES
- Stitch Frame: Visible

### 5. Test Hyjal

**Teleport to Hyjal:**
```
.go xyz 4625.88 -3840.54 943.678 1 616
```

**Open World Map (M key)**

**Expected Results:**
- Debug message: "Hyjal detected via zone name: Hyjal" (or similar)
- Debug message: "Custom map type detected: hyjal"
- Debug message: "Map changed from azshara to hyjal"
- Debug message: "Loaded 12 tiles for hyjal"
- Debug message: "Custom map shown: hyjal"
- **Map should show Hyjal tiles**

**Check with:**
```
/dcmap status
```

Should show:
- Custom Map Detected: hyjal
- IsHyjal(): YES
- Stitch Frame: Visible

### 6. Test Normal Zone

**Teleport to Stormwind:**
```
.go xyz -8913.23 554.633 93.7944 0
```

**Open World Map (M key)**

**Expected Results:**
- Debug message: "Not in custom zone, hiding overlay"
- Normal Blizzard map tiles visible
- No custom overlay

## Troubleshooting

### If Azshara Still Not Detected:

1. Check what zone name the game returns:
```
/dcmap status
```
Look at "Zone Name:" - might be localized (German/French/etc)

2. Manually check the zone:
```lua
/run print("Zone:", GetZoneText(), "Map:", GetCurrentMapAreaID())
```

3. If zone name is different, we may need to add alternate names

### If Tiles Still Don't Load:

1. Check if BLP files exist:
```
/dcmap status
```
Then look in chat for tile loading messages

2. Verify file paths in folder:
```
Interface\AddOns\DC-MapExtension\Textures\AzsharaCrater\
Interface\AddOns\DC-MapExtension\Textures\Hyjal\
```

3. Check for Lua errors:
```
/console scriptErrors 1
```

### If Player Dot Not Showing:

1. Make sure it's enabled:
```
Interface -> Addons -> DC-MapExtension -> Show Player Position
```

2. Check if GetPlayerMapPosition returns valid data:
```lua
/run local x,y = GetPlayerMapPosition("player"); print("X:", x, "Y:", y)
```

## Common Commands

```
/dcmap show      - Enable maps
/dcmap hide      - Disable maps
/dcmap debug     - Toggle debug
/dcmap status    - Show diagnostics
/dcmap reload    - Force refresh
```

## Expected Output (Debug Mode)

### When entering Azshara:
```
[DC-MapExt] UpdateMap check - MapID: 37 Zone: Azshara Crater Continent: 0
[DC-MapExt] Azshara detected via map ID: 37
[DC-MapExt] Custom map type detected: azshara
[DC-MapExt] Map changed from nil to azshara
[DC-MapExt] Loading tiles for azshara - Frame size: 683 x 512
[DC-MapExt] Tile size: 170.75 x 170.67
[DC-MapExt] Tile 1 loaded: Interface\AddOns\DC-MapExtension\Textures\AzsharaCrater\AzsharaCrater1.blp at 0 0
[DC-MapExt] Tile 2 loaded: Interface\AddOns\DC-MapExtension\Textures\AzsharaCrater\AzsharaCrater2.blp at 170.75 0
... (tiles 3-12)
[DC-MapExt] Loaded 12 tiles for azshara
[DC-MapExt] Custom map shown: azshara
```

### When entering Hyjal:
```
[DC-MapExt] UpdateMap check - MapID: 1 Zone: Hyjal Continent: 1
[DC-MapExt] Hyjal detected via zone name: Hyjal
[DC-MapExt] Custom map type detected: hyjal
[DC-MapExt] Map changed from azshara to hyjal
[DC-MapExt] Loading tiles for hyjal - Frame size: 683 x 512
... (similar tile loading messages)
[DC-MapExt] Loaded 12 tiles for hyjal
[DC-MapExt] Custom map shown: hyjal
```

### When entering normal zone:
```
[DC-MapExt] UpdateMap check - MapID: 14 Zone: Durotar Continent: 1
[DC-MapExt] Not in custom zone, hiding overlay
```

## Success Criteria

✅ Azshara Crater shows proper tiles (not blank/rainbow)  
✅ Hyjal shows proper tiles  
✅ Player position marker (green arrow) visible and moving  
✅ Normal zones show standard Blizzard maps  
✅ No Lua errors  
✅ Settings work in Interface Options panel  
✅ No /reload needed when changing settings  

## Need Help?

If issues persist:
1. Copy output of `/dcmap status`
2. Copy debug messages when entering the zone
3. Check `/console scriptErrors 1` for Lua errors
4. Verify BLP files exist in Textures folders
