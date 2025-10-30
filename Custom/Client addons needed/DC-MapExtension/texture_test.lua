-- Texture Test Script
-- Tests if Azshara Crater textures can be loaded

print("|cFF00FF00=== DC-MapExtension Texture Test ===|r")

local testPaths = {
    "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater1",
    "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater2",
    "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater12",
    "Interface\\WorldMap\\Hyjal\\Hyjal1",
    "Interface\\WorldMap\\Hyjal\\Hyjal12",
}

-- Create a test frame to try loading textures
local testFrame = CreateFrame("Frame", "DCMapTextureTestFrame", UIParent)
testFrame:SetSize(100, 100)
testFrame:Hide()

for i, path in ipairs(testPaths) do
    local tex = testFrame:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    
    -- Try to load the texture
    tex:SetTexture(path)
    local result = tex:GetTexture()
    
    if result and result ~= "" then
        print("|cFF00FF00FOUND:|r " .. path)
        print("  -> " .. tostring(result))
    else
        print("|cFFFF0000MISSING:|r " .. path)
    end
    
    tex:SetTexture(nil)
end

print("\n|cFFFFFF00Note:|r Textures must be in your WoW client folder:")
print("  World of Warcraft/Interface/WorldMap/AzsharaCrater/*.blp")
print("  World of Warcraft/Interface/WorldMap/Hyjal/*.blp")
print("|cFF00FF00=== End Test ===|r")
