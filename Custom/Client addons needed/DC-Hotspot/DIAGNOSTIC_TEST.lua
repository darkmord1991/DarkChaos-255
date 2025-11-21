-- DC-Hotspot Diagnostic Test
-- Paste this entire block into the game chat (or use /run with each section)

-- Test 1: Check if addon is loaded
if DC_DebugUtils then
    print("|cff00ff00✓ DC_DebugUtils loaded|r")
else
    print("|cffff0000✗ DC_DebugUtils NOT loaded|r")
end

if HotspotDisplay_Astrolabe then
    print("|cff00ff00✓ HotspotDisplay_Astrolabe loaded|r")
else
    print("|cffff0000✗ HotspotDisplay_Astrolabe NOT loaded|r")
end

-- Test 2: Check addon state
local addon = select(2, ...)
if not addon then
    -- Try to get it from global
    for i=1, GetNumAddOns() do
        local name = GetAddOnInfo(i)
        if name == "DC-Hotspot" then
            addon = _G["DC-Hotspot"]
            break
        end
    end
end

if addon and addon.Core and addon.Core.state then
    local state = addon.Core.state
    print("|cff00ff00✓ Addon state exists|r")
    
    -- Count hotspots
    local count = 0
    for id, hs in pairs(state.hotspots) do
        count = count + 1
        print(string.format("  Hotspot %d: map=%s, zone=%s, x=%.1f, y=%.1f", 
            id, tostring(hs.map), tostring(hs.zoneId), hs.x or 0, hs.y or 0))
    end
    print(string.format("|cffFFD700Total hotspots: %d|r", count))
    
    -- Check settings
    if state.db then
        print("|cff00ff00✓ Settings loaded|r")
        print(string.format("  showWorldPins: %s", tostring(state.db.showWorldPins)))
        print(string.format("  showMinimapPins: %s", tostring(state.db.showMinimapPins)))
        print(string.format("  debug: %s", tostring(state.db.debug)))
    else
        print("|cffff0000✗ Settings NOT loaded|r")
    end
else
    print("|cffff0000✗ Addon state NOT found|r")
end

-- Test 3: Check coordinate conversion
if HotspotDisplay_Astrolabe then
    print("\n|cffFFD700Testing coordinate conversion:|r")
    local Ast = HotspotDisplay_Astrolabe
    
    -- Duskwood hotspot from your chat: ID 31, Map 0, Pos (-4739.6, -2712.5)
    local mapId, x, y = 0, -4739.6, -2712.5
    
    if Ast.MapBounds and Ast.MapBounds[mapId] then
        local bounds = Ast.MapBounds[mapId]
        print(string.format("  Map %d bounds: X[%.0f to %.0f], Y[%.0f to %.0f]", 
            mapId, bounds.minX, bounds.maxX, bounds.minY, bounds.maxY))
    end
    
    if Ast.WorldCoordsToNormalized then
        local nx, ny = Ast.WorldCoordsToNormalized(mapId, x, y)
        if nx and ny then
            print(string.format("  World (%.1f, %.1f) → Normalized (%.4f, %.4f)", x, y, nx, ny))
            if nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
                print("  |cff00ff00✓ Coordinates in valid range|r")
            else
                print("  |cffff0000✗ Coordinates OUT OF RANGE!|r")
            end
        else
            print("  |cffff0000✗ Conversion returned nil|r")
        end
    end
end

-- Test 4: Check world pin creation
if addon and addon.Pins then
    local Pins = addon.Pins
    if Pins.worldPins then
        local pinCount = 0
        for id, pin in pairs(Pins.worldPins) do
            pinCount = pinCount + 1
        end
        print(string.format("\n|cffFFD700World pins created: %d|r", pinCount))
        
        if pinCount > 0 then
            for id, pin in pairs(Pins.worldPins) do
                local visible = pin:IsShown() and "visible" or "hidden"
                print(string.format("  Pin %d: %s", id, visible))
            end
        end
    end
end

print("\n|cff00ff00Diagnostic complete!|r")
