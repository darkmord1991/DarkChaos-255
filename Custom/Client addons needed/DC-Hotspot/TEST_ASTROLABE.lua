-- Quick Astrolabe test
-- Run in-game: /run dofile("Interface\\AddOns\\DC-Hotspot\\TEST_ASTROLABE.lua")

print("|cffFFD700Testing Astrolabe Conversion|r")
print(string.rep("-", 60))

local Ast = _G.HotspotDisplay_Astrolabe

if not Ast then
    print("|cffff0000✗ Astrolabe NOT loaded!|r")
    return
end

print("|cff00ff00✓ Astrolabe loaded|r")

-- Test each failing hotspot from your debug log
local tests = {
    { map = 37, x = 143, y = 986, name = "Azshara Crater #2" },
    { map = 530, x = 834.7, y = 2110.7, name = "Shadowmoon Valley #3" },
    { map = 571, x = 2916.3, y = 5044.4, name = "Borean Tundra #5" },
    { map = 571, x = 4404.7, y = 1277.2, name = "Howling Fjord #15" },
    { map = 0, x = -8128.4, y = -679.7, name = "Dun Morogh #1 (working)" },
}

for _, test in ipairs(tests) do
    print(string.format("\n|cffFFD700%s|r", test.name))
    print(string.format("  Input: Map %d, Coords (%.1f, %.1f)", test.map, test.x, test.y))
    
    -- Check bounds
    if Ast.MapBounds then
        local bounds = Ast.MapBounds[test.map]
        if bounds then
            print(string.format("  Bounds: X[%.0f to %.0f], Y[%.0f to %.0f]", 
                bounds.minX, bounds.maxX, bounds.minY, bounds.maxY))
        else
            print(string.format("  |cffff0000✗ No bounds for map %d|r", test.map))
        end
    end
    
    -- Try conversion
    if Ast.WorldCoordsToNormalized then
        local nx, ny = Ast.WorldCoordsToNormalized(test.map, test.x, test.y)
        if nx and ny then
            print(string.format("  |cff00ff00✓ Converted to: (%.4f, %.4f)|r", nx, ny))
        else
            print(string.format("  |cffff0000✗ Conversion returned nil|r"))
        end
    else
        print("  |cffff0000✗ WorldCoordsToNormalized not found|r")
    end
end

print("\n" .. string.rep("-", 60))
print("|cff00ff00Test complete!|r")
