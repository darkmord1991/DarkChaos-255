# Hotspot Map XP+ Display Implementation Guide

**Date:** October 17, 2025  
**Purpose:** Guide for implementing "XP+" text display on maps (Project Ascension style)

---

## Overview

The DarkChaos Hotspots System currently provides **server-side** markers (GameObjects, auras, announcements). To achieve the **map text overlay** showing "XP+" like Project Ascension requires a **client-side addon**.

### What Works Now (Server-Side Only)

✅ **Visual GameObject Markers** - Flag/barrel icons visible on map/minimap  
✅ **Cloud Aura** - Visual effect when entering hotspot  
✅ **Buff Icon** - Flag icon in buff bar while in hotspot  
✅ **World Announcements** - Chat messages about hotspot locations  
✅ **XP Bonus** - Actual +100% XP from kills in hotspot

### What Requires Client Addon

❌ **"XP+" Text Overlay** - Custom text drawn on map interface  
❌ **Dynamic XP Percentage** - Showing exact bonus (e.g., "+100%")  
❌ **Hotspot Radius Circle** - Visual circle on map showing hotspot area  
❌ **Distance Indicators** - "1200 yards away" type displays

---

## Server-Side Configuration

### Current Implementation

The server spawns GameObjects at hotspot locations:

```conf
# ac_hotspots.conf
Hotspots.SpawnVisualMarker = 1                    # Enable GameObject spawning
Hotspots.MarkerGameObjectEntry = 179976           # GameObject ID (flag, barrel, etc.)
```

### Available GameObject Markers

Different GameObjects display differently on maps:

| GameObject ID | Name | Map Display | Notes |
|---------------|------|-------------|-------|
| 179976 | Alliance Flag | Blue flag icon | Default, highly visible |
| 179964 | Horde Flag | Red flag icon | Visible to Horde players |
| 180746 | Ale Keg | Barrel icon | Neutral, less prominent |
| 176491 | Meeting Stone | Stone icon | Visible but subtle |
| 191080 | Crystal | Glowing icon | Eye-catching |

**Recommendation:** Use 179976 (Alliance Flag) or 179964 (Horde Flag) for best visibility.

---

## Client Addon Implementation

### Architecture Overview

```
Server (C++)                          Client (Lua Addon)
─────────────                         ──────────────────
Spawn GameObject                      Detect nearby objects
  └─ at (x, y, z)        ──────>     Check GameObject IDs
  └─ with entry ID                      └─ Match hotspot marker ID
                                        └─ Get coordinates
World Announcements       ──────>     Parse chat messages
  └─ "Hotspot in..."                    └─ Extract map/zone info
                                    
Buff Aura (23768)         ──────>     Check player buffs
  └─ Applied in range                   └─ If buff exists, player in hotspot
                                    
                                      Draw on Map UI
                                        └─ Use LibMapPing or similar
                                        └─ Draw "XP+" text at coords
                                        └─ Draw radius circle (optional)
```

### Required Addon Components

#### 1. **GameObject Detection**

```lua
-- Scan nearby GameObjects for hotspot markers
local HOTSPOT_MARKER_ID = 179976  -- Must match server config

function ScanForHotspots()
    local hotspots = {}
    
    -- Iterate through visible GameObjects
    for i = 1, GetNumMapLandmarks() do
        local name, description, textureIndex, x, y = GetMapLandmarkInfo(i)
        
        -- Check if this is our hotspot marker
        -- (GameObject ID detection requires client inspection)
        if IsHotspotMarker(name, description) then
            table.insert(hotspots, {
                x = x,
                y = y,
                expires = GetHotspotExpireTime()
            })
        end
    end
    
    return hotspots
end
```

#### 2. **Map Text Overlay**

```lua
-- Draw "XP+" text on map at hotspot locations
function DrawHotspotOverlay(frame, mapID)
    local hotspots = GetActiveHotspots()
    
    for _, hotspot in ipairs(hotspots) do
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        text:SetPoint("CENTER", frame, "TOPLEFT", hotspot.x * frame:GetWidth(), 
                      -hotspot.y * frame:GetHeight())
        text:SetText("|cFFFFD700XP+|r")
        text:SetTextColor(1, 0.84, 0)  -- Gold color
        
        -- Optional: Add XP percentage
        text:SetText(string.format("|cFFFFD700XP+%d%%|r", GetHotspotBonus()))
    end
end
```

#### 3. **Buff Detection Method**

```lua
-- Simpler approach: Check if player has hotspot buff
local HOTSPOT_BUFF_ID = 23768  -- Must match server config

function PlayerInHotspot()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if spellId == HOTSPOT_BUFF_ID then
            return true
        end
    end
    return false
end

-- When player has buff, highlight their current position on map
function UpdatePlayerHotspotIndicator()
    if PlayerInHotspot() then
        local x, y = GetPlayerMapPosition("player")
        DrawXPIndicatorAt(x, y)
    end
end
```

#### 4. **World Announcement Parsing**

```lua
-- Parse world chat for hotspot announcements
local function OnChatMessage(self, event, message, sender, ...)
    if string.match(message, "%[Hotspot%]") then
        -- Parse: "A new XP Hotspot has appeared in Eastern Kingdoms! (+100% XP)"
        local mapName, xpBonus = string.match(message, "appeared in (.+)! %((%+%d+%%%%) XP%)")
        
        if mapName and xpBonus then
            RegisterNewHotspot(mapName, xpBonus)
            UpdateMapDisplay()
        end
    end
end

ChatFrame:RegisterEvent("CHAT_MSG_SYSTEM")
ChatFrame:SetScript("OnEvent", OnChatMessage)
```

### Recommended Libraries

#### **HereBeDragons** - Map coordinate library
- Converts world coordinates to map display positions
- Handles different map zoom levels
- GitHub: `https://github.com/Nevcairiel/HereBeDragons`

```lua
local HBD = LibStub("HereBeDragons-2.0")
local pins = LibStub("HereBeDragons-Pins-2.0")

-- Place a pin on the map at hotspot location
function PlaceHotspotPin(mapID, x, y)
    local icon = CreateFrame("Frame")
    -- Setup icon texture, size, etc.
    
    pins:AddWorldMapIconMap(icon, mapID, x, y, 3)  -- 3 = show on continent maps too
end
```

#### **LibMapPing** - Custom map pings/markers
- Place custom icons on map
- Draw shapes (circles for hotspot radius)
- Handle map zoom/pan

```lua
local LMP = LibStub("LibMapPing-1.0")

function PingHotspot(x, y)
    LMP:PlaceMapIconByCoord(mapID, x, y, "Interface\\AddOns\\HotspotAddon\\xp_icon.tga")
end
```

### Example Addon Structure

```
HotspotMapDisplay/
├── HotspotMapDisplay.toc
├── Core.lua
├── MapDisplay.lua
├── Config.lua
├── Libs/
│   ├── HereBeDragons/
│   └── LibMapPing/
└── Textures/
    ├── xp_icon.tga
    └── hotspot_circle.tga
```

**HotspotMapDisplay.toc:**
```toc
## Interface: 30300
## Title: Hotspot Map Display
## Notes: Shows XP hotspot locations on map with "XP+" text
## Author: DarkChaos Team
## Version: 1.0
## Dependencies: Blizzard_WorldMap

Libs\HereBeDragons\HereBeDragons-2.0.lua
Libs\HereBeDragons\HereBeDragons-Pins-2.0.lua

Config.lua
Core.lua
MapDisplay.lua
```

**Core.lua (Basic Example):**
```lua
local ADDON_NAME = "HotspotMapDisplay"
local HotspotDB = {}

-- Configuration (must match server)
local HOTSPOT_MARKER_GO_ID = 179976
local HOTSPOT_BUFF_SPELL_ID = 23768
local XP_BONUS_PERCENT = 100  -- Could parse from announcements

-- Initialize
local function OnLoad()
    print("|cFFFFD700[Hotspot Display]|r Loaded! Map markers enabled.")
    HookWorldMapFrame()
end

-- Hook into WorldMapFrame updates
local function HookWorldMapFrame()
    hooksecurefunc(WorldMapFrame, "Show", function()
        UpdateHotspotDisplay()
    end)
end

-- Main update function
function UpdateHotspotDisplay()
    ClearOldMarkers()
    
    -- Method 1: Scan for GameObject markers
    ScanGameObjects()
    
    -- Method 2: Check if player in hotspot (has buff)
    if UnitBuff("player", "Sayge's Dark Fortune of Strength") then
        local x, y = GetPlayerMapPosition("player")
        DrawHotspotMarker(x, y, true)  -- true = player is here
    end
    
    -- Draw all known hotspots
    for _, hotspot in pairs(HotspotDB) do
        if not hotspot.expired then
            DrawHotspotMarker(hotspot.x, hotspot.y, false)
        end
    end
end

-- Draw "XP+" text on map
function DrawHotspotMarker(mapX, mapY, isPlayerLocation)
    local frame = WorldMapFrame
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    text:SetText(string.format("|cFFFFD700XP+%d%%|r", XP_BONUS_PERCENT))
    
    -- Position on map (convert 0-1 coordinates to frame positions)
    local pixelX = mapX * frame:GetWidth()
    local pixelY = -mapY * frame:GetHeight()
    text:SetPoint("CENTER", frame, "TOPLEFT", pixelX, pixelY)
    
    if isPlayerLocation then
        -- Add pulsing animation for current hotspot
        text:SetTextColor(1, 1, 0)  -- Yellow
    else
        text:SetTextColor(1, 0.84, 0)  -- Gold
    end
end

-- Event handler for world announcements
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
EventFrame:SetScript("OnEvent", function(self, event, message)
    if string.match(message, "%[Hotspot%]") and string.match(message, "appeared") then
        -- Parse announcement and add to database
        -- Example: "A new XP Hotspot has appeared in Eastern Kingdoms!"
        ParseHotspotAnnouncement(message)
    elseif string.match(message, "%[Hotspot%]") and string.match(message, "expired") then
        -- Mark hotspots as expired
        MarkAllHotspotsExpired()
    end
end)

-- Initialize addon
OnLoad()
```

---

## Alternative Approaches

### Option 1: Server-Only (Current Implementation)
**Pros:**
- No client modification required
- Works immediately with GameObject markers
- All players see markers automatically

**Cons:**
- No "XP+" text overlay on map
- Limited to GameObject icon display
- Cannot show exact XP percentage on map

### Option 2: GameObject + Tooltip Enhancement
**Pros:**
- Tooltips can show "XP Hotspot +100%" when hovering
- No addon required
- Server-side implementation

**Cons:**
- Players must hover over marker to see info
- Not visible at a glance like text overlay

**Implementation:**
```cpp
// In ac_hotspots.cpp, add GameObject tooltip
if (go->Create(...))
{
    go->SetRespawnTime(sHotspotsConfig.duration * MINUTE);
    // Set custom tooltip text
    std::string tooltip = "XP Hotspot: +" + std::to_string(sHotspotsConfig.experienceBonus) + "% XP";
    // Note: GameObject tooltips are limited in customization
    map->AddToMap(go);
}
```

### Option 3: Full Client Addon (Recommended for Ascension-Style Display)
**Pros:**
- Full control over map display
- Can show "XP+", percentage, radius circles
- Dynamic updates and animations
- Best visual experience

**Cons:**
- Players must install addon
- Requires addon development
- Addon distribution/maintenance

**Recommendation:** This is what Project Ascension uses.

### Option 4: Modified Client (Advanced)
**Pros:**
- Built into client, no addon needed
- Can modify any UI element
- Professional integration

**Cons:**
- Requires client patching
- Players must download custom client
- Complex distribution

---

## Step-by-Step Implementation

### Phase 1: Server-Side (Complete ✅)
1. ✅ Spawn GameObjects at hotspot locations
2. ✅ Configure GameObject entry (flag, barrel, etc.)
3. ✅ Apply buff aura to players in hotspot
4. ✅ Send world announcements

### Phase 2: Basic Addon (Minimal XP+ Display)
1. Create addon skeleton with .toc file
2. Hook WorldMapFrame updates
3. Detect hotspot buff on player
4. Draw "XP+" text at player position when buff active
5. Test and package

**Estimated Time:** 2-4 hours for basic version

### Phase 3: Advanced Addon (Full Features)
1. Integrate HereBeDragons library
2. Parse world announcements to track all hotspots
3. Draw "XP+" at all hotspot locations (not just player's)
4. Add radius circles showing hotspot range
5. Add timers showing expiration countdown
6. Add minimap integration
7. Add configuration panel

**Estimated Time:** 8-16 hours for full-featured version

### Phase 4: Polish & Distribution
1. Add textures/icons for visual appeal
2. Create configuration UI
3. Package addon with dependencies
4. Write installation guide
5. Test across different clients (3.3.5a builds)
6. Distribute via repository/website

---

## Testing Checklist

### Server-Side Testing
- [ ] GameObject spawns at hotspot location
- [ ] GameObject visible on map/minimap
- [ ] GameObject despawns when hotspot expires
- [ ] Multiple hotspots don't overlap visually
- [ ] Different GameObject IDs display correctly

### Addon Testing
- [ ] "XP+" text displays on map
- [ ] Text positioned correctly at hotspot coordinates
- [ ] Text updates when hotspot expires
- [ ] Text visible at different map zoom levels
- [ ] Works on all maps (EK, Kalimdor, Outland, Northrend)
- [ ] No FPS drop with multiple hotspots
- [ ] Compatible with other map addons

---

## Recommended GameObject IDs for Map Display

Tested GameObjects that show well on maps:

### Best Options (Highly Visible)
- **179976** - Alliance Flag (Blue flag icon) ⭐ **Recommended**
- **179964** - Horde Flag (Red flag icon) ⭐ **Recommended**
- **180746** - Ale Keg (Barrel icon)

### Alternative Options
- **176491** - Meeting Stone (Stone icon, neutral)
- **191080** - Crystal (Glowing crystal icon)
- **181275** - Campfire (Fire icon, warm feel)
- **186949** - Bonfire (Larger fire icon)

### Custom Options (Requires DB Entry)
Create custom GameObject entry in your database:
```sql
INSERT INTO gameobject_template (entry, type, displayId, name, IconName, size, ...)
VALUES (999001, 5, 6673, 'XP Hotspot Marker', 'Interact', 2.0, ...);
```
Then use `Hotspots.MarkerGameObjectEntry = 999001`

---

## Troubleshooting

### Problem: GameObject doesn't show on map
**Solutions:**
- Try different GameObject IDs (some don't have map icons)
- Check GameObject scale/size (too small = not visible)
- Verify GameObject is in GO_STATE_READY state
- Check map zoom level (some icons only show when zoomed in)

### Problem: Addon doesn't detect hotspots
**Solutions:**
- Verify buff spell ID matches server config (23768)
- Check GameObject entry ID matches server config (179976)
- Use `/dump UnitBuff("player", 1)` to inspect buffs
- Enable Lua error display: `/console scriptErrors 1`

### Problem: Text appears in wrong location
**Solutions:**
- Verify coordinate conversion (0-1 range to pixel positions)
- Account for map zoom level and scroll position
- Use HereBeDragons library for accurate positioning
- Test on different map sizes (continent vs zone maps)

---

## Resources

### Libraries
- **HereBeDragons**: https://github.com/Nevcairiel/HereBeDragons
- **LibMapPing**: https://www.wowace.com/projects/libmapping
- **LibSharedMedia**: Font/texture library

### References
- **WoW AddOn Development**: https://wowpedia.fandom.com/wiki/AddOn_programming
- **Map API**: https://wowpedia.fandom.com/wiki/Widget_API
- **GameObject IDs**: https://wotlk.evowow.com/?objects

### Example Addons
- **Cartographer**: Map enhancement addon
- **GatherMate2**: Resource location tracking (similar concept)
- **HandyNotes**: Custom map icons/notes

---

## Conclusion

### Current Server Status
The Hotspots system provides **GameObject visual markers** that appear on maps/minimaps. Players see flag/barrel icons at hotspot locations.

### For "XP+" Text Overlay
A **client addon is required**, similar to Project Ascension's implementation. This guide provides the foundation for creating such an addon.

### Next Steps
1. **Test current implementation** - Verify GameObject markers work
2. **Decide on approach** - GameObject-only vs full addon
3. **Develop addon** (if desired) - Use this guide as reference
4. **Distribute to players** - Package and provide installation instructions

---

**Contact:** DarkChaos Development Team  
**Version:** 1.0 (October 17, 2025)  
**License:** GNU AGPL v3
