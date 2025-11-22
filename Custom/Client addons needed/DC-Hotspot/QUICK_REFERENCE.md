# DC-Hotspot Quick Reference

## 🔧 What Was Fixed
1. **Syntax error** - Missing `end` statement causing load failure
2. **Coordinate bug** - World coords (-6467, -3117) not converting to normalized (0-1) range
3. **Debug system** - Now reads from settings and shows coordinate conversion

## 🚀 Quick Start

### In-Game Commands
```
/dchotspot          - Toggle hotspot list window
/dchotspot config   - Open settings panel
/dcdebugstats       - Show debug statistics
```

### Enable Debug Mode
1. Type `/dchotspot config`
2. Check "Debug mode"
3. Open world map - you'll see coordinate conversion in chat

### Test Coordinate Conversion
```lua
/run dofile("Interface\\AddOns\\DC-Hotspot\\TEST_COORDS.lua")
```

## 📍 Your Current Hotspots (from server log)

| ID | Map | Zone | Coords | Map Name |
|----|-----|------|--------|----------|
| 23 | 1 | 17 | (-6467, -3117) | The Barrens |
| 26 | 1 | 17 | (-6088, -3468) | The Barrens |
| 22 | 0 | 10 | (-4242, -2608) | Duskwood |
| 25 | 530 | 3520 | (2418, 2064) | Shadowmoon Valley |
| 20 | 1 | 331 | (-2789, -4665) | Ashenvale |
| 27 | 0 | 85 | (-10714, 1144) | Tirisfal Glades |
| 28 | 1 | 141 | (9372, 1870) | Teldrassil |
| 29 | 0 | 1 | (-8872, -644) | Dun Morogh |

## 🗺️ How to See Pins

1. **Open World Map** (`M` key)
2. **Navigate to matching zone** (e.g., The Barrens for IDs 23, 26)
3. **Pins should appear** with XP bonus labels
4. **Hover over pin** to see tooltip with details

### For Minimap
- Pins auto-show when you're in same zone as hotspot
- Uses relative positioning from your location

## 🐛 Troubleshooting

### "No pins visible"
1. Check settings: `/dchotspot config`
   - ✓ Show world map pins
   - ✓ Show minimap pins
2. Enable debug mode
3. Open world map - check chat for debug output

### Debug Output Should Show
```
[DC-Hotspot] UpdateWorldPins - Active map: 1 Hotspots: 15
[DC-Hotspot]   Processing hotspot 23 map: 1 zone: 17 pos: -6467.3 -3117.1
[DC-Hotspot]     Normalized coords: 0.2222 0.3681
```

### "Coordinates out of range"
- Map bounds may need adjustment in `HotspotDisplay_Astrolabe.lua`
- Run TEST_COORDS.lua to see if conversion is working

## 🎯 Expected Behavior

### When Hotspot Spawns
1. **Popup banner** appears (4 seconds)
2. **Chat message**: "[Hotspot] The Barrens (+100% XP)"
3. **Raid warning** (yellow text across screen)
4. **Sound** plays (if configured)

### When Opening World Map
1. Pins appear for all hotspots on current map
2. Shows "+100% XP" label below each pin
3. Tooltip on hover shows details + time remaining

### When on Minimap
1. Small pins appear for nearby hotspots
2. Relative positioning from player location
3. Tooltip on hover shows basic info

## 📊 Coordinate Conversion Flow

```
Server Message:
  "HOTSPOT_ADDON|id:23|map:1|zone:17|x:-6467.3|y:-3117.1|dur:480"
       ↓
Core.lua: ParsePayloadString()
  Extracts: id=23, map=1, x=-6467.3, y=-3117.1
       ↓
Core.lua: BuildHotspotRecord()
  Creates hotspot object with world coords
       ↓
Pins.lua: NormalizeCoords()
  Uses Astrolabe.WorldCoordsToNormalized(1, -6467.3, -3117.1)
  Bounds: X[-12000 to 12000], Y[-12000 to 12000]
  Result: nx = 0.2222, ny = 0.3681
       ↓
Pins.lua: UpdateWorldPins()
  Converts to pixels: px = nx * mapWidth, py = ny * mapHeight
  Places pin on map
```

## 📝 Settings Reference

| Setting | Default | Description |
|---------|---------|-------------|
| Show minimap pins | ✓ | Display on minimap |
| Show world map pins | ✓ | Display on world map |
| Show world pin labels | ✓ | Show "+100% XP" text |
| Show spawn popup | ✓ | Banner notification |
| Announce in chat | ✓ | Chat message on spawn |
| Announce expiry | ✓ | Chat message on expire |
| Pin icon style | Spell | Icon appearance |
| Debug mode | ✗ | Show diagnostic output |

## 🔄 Next Steps

1. Copy addon to: `<WoW>/Interface/AddOns/DC-Hotspot/`
2. Launch WoW or `/reload`
3. Type `/dchotspot config` → enable debug
4. Open world map to The Barrens
5. Look for pins at the coordinates above
6. Check chat for debug output showing coordinate conversion

If pins appear correctly, disable debug mode. If not, share the debug output!
