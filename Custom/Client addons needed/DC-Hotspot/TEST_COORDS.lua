-- Test coordinate conversion for DC-Hotspot
-- Run this in-game with: /run LoadAddOn("DC-Hotspot"); dofile("Interface\\AddOns\\DC-Hotspot\\TEST_COORDS.lua")

local Ast = _G.HotspotDisplay_Astrolabe

if not Ast then
    print("ERROR: HotspotDisplay_Astrolabe not loaded")
    return
end

print("|cff00ff00DC-Hotspot Coordinate Test|r")
print("=" .. string.rep("-", 60))

-- Test data from your server messages
local testHotspots = {
    { id = 23, map = 1, zone = 17, x = -6467.3, y = -3117.1, name = "The Barrens" },
    { id = 26, map = 1, zone = 17, x = -6088.6, y = -3468.1, name = "The Barrens" },
    { id = 22, map = 0, zone = 10, x = -4242.2, y = -2608.9, name = "Duskwood" },
    { id = 25, map = 530, zone = 3520, x = 2418.9, y = 2064.6, name = "Shadowmoon Valley" },
}

for _, hotspot in ipairs(testHotspots) do
    print(string.format("\n|cffFFD700Hotspot %d (%s)|r", hotspot.id, hotspot.name))
    print(string.format("  Map: %d, World Coords: (%.1f, %.1f)", hotspot.map, hotspot.x, hotspot.y))
    
    if Ast.WorldCoordsToNormalized then
        local nx, ny = Ast.WorldCoordsToNormalized(hotspot.map, hotspot.x, hotspot.y)
        if nx and ny then
            print(string.format("  |cff00ff00Normalized: (%.4f, %.4f)|r", nx, ny))
            
            -- Check if coords are in valid range
            if nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
                print("  |cff00ff00✓ Coordinates are valid for map display|r")
            else
                print("  |cffff0000✗ Coordinates OUT OF RANGE!|r")
            end
        else
            print("  |cffff0000✗ Failed to normalize coordinates|r")
        end
    else
        print("  |cffff0000✗ WorldCoordsToNormalized function not available|r")
    end
    
    -- Check if map bounds exist
    if Ast.MapBounds and Ast.MapBounds[hotspot.map] then
        local bounds = Ast.MapBounds[hotspot.map]
        print(string.format("  Map bounds: X[%.0f to %.0f], Y[%.0f to %.0f]", 
            bounds.minX, bounds.maxX, bounds.minY, bounds.maxY))
    else
        print("  |cffff0000✗ No map bounds defined for map " .. hotspot.map .. "|r")
    end
end

print("\n" .. string.rep("-", 60))
print("|cff00ff00Test complete. Check if coordinates are in valid range.|r")
