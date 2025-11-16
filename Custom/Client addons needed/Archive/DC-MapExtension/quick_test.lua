-- Quick test script for DC-MapExtension
-- Use this to quickly verify the addon state

-- Test 1: Check addon loaded
if not _G.DCMapExtension then
    print("|cFFFF0000ERROR: DCMapExtension not loaded!|r")
    return
end

local addon = _G.DCMapExtension

-- Test 2: Show current state
print("|cFF00FF00=== DC-MapExtension Quick Test ===|r")
print("Current Map: " .. tostring(addon.currentMap or "none"))
print("Forced Map: " .. tostring(addon.forcedMap or "none"))
print("Stitch Frame: " .. tostring(addon.stitchFrame and "YES" or "NO"))
print("Player Dot: " .. tostring(addon.playerDot and "YES" or "NO"))

if addon.playerDot then
    print("  - Dot Shown: " .. tostring(addon.playerDot:IsShown()))
    print("  - Dot Alpha: " .. string.format("%.2f", addon.playerDot:GetAlpha()))
    local parent = addon.playerDot:GetParent()
    print("  - Dot Parent: " .. (parent and parent:GetName() or "NONE"))
end

-- Test 3: Check tiles
print("\nTile Status:")
local tileCount = 0
local shownCount = 0
for i = 1, 16 do
    local tile = _G["WorldMapDetailTile" .. i]
    if tile then
        tileCount = tileCount + 1
        if tile:IsShown() then
            shownCount = shownCount + 1
            local tex = tile:GetTexture()
            if tex then
                local shortName = tex:match("[^\\]+$") or tex
                print("  Tile " .. i .. ": SHOWN - " .. shortName)
            else
                print("  Tile " .. i .. ": SHOWN - NO TEXTURE")
            end
        end
    end
end
print("Total tiles: " .. tileCount .. ", Shown: " .. shownCount)

-- Test 4: GPS Data
print("\nGPS Data:")
print("  Map: " .. tostring(addon.gpsData.mapId))
print("  Zone: " .. tostring(addon.gpsData.zoneId))
print("  Normalized: (" .. string.format("%.3f", addon.gpsData.nx) .. ", " .. string.format("%.3f", addon.gpsData.ny) .. ")")
local age = GetTime() - addon.gpsData.lastUpdate
print("  Age: " .. string.format("%.1f", age) .. "s")

print("|cFF00FF00=== End Test ===|r")
