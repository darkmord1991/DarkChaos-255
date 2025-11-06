-- WoWLua Test Script for DC-ItemUpgrade Stats Debugging
-- Copy/paste this into WoWLua to test tooltip scanning

-- Test 1: Basic tooltip scanning
local function TestTooltipScan()
    print("=== Testing Tooltip Scan ===")
    
    -- Get item from cursor or equipped item
    local itemLink = GetInventoryItemLink("player", 10) -- Hands slot
    if not itemLink then
        print("ERROR: No item in hands slot. Equip an item or hold one on cursor")
        return
    end
    
    print("Testing with item:", itemLink)
    
    -- Create tooltip
    local tooltip = CreateFrame("GameTooltip", "TestTooltip", UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)
    
    print("Tooltip has", tooltip:NumLines(), "lines")
    
    -- Scan all lines
    for i = 1, tooltip:NumLines() do
        local leftText = _G["TestTooltipTextLeft" .. i]
        local rightText = _G["TestTooltipTextRight" .. i]
        
        if leftText then
            local text = leftText:GetText()
            if text then
                print(string.format("Line %d (Left): %s", i, text))
            end
        end
        
        if rightText then
            local text = rightText:GetText()
            if text then
                print(string.format("Line %d (Right): %s", i, text))
            end
        end
    end
    
    tooltip:Hide()
end

-- Test 2: Check what GetItemInfo returns
local function TestGetItemInfo()
    print("=== Testing GetItemInfo ===")
    
    local itemLink = GetInventoryItemLink("player", 10)
    if not itemLink then
        print("ERROR: No item in hands slot")
        return
    end
    
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, 
          itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemLink)
    
    print("Name:", itemName)
    print("ItemLevel:", itemLevel)
    print("MinLevel:", itemMinLevel)
    print("Type:", itemType)
    print("SubType:", itemSubType)
    print("EquipLoc:", itemEquipLoc)
    print("Rarity:", itemRarity)
end

-- Test 3: Check GetItemStats
local function TestGetItemStats()
    print("=== Testing GetItemStats ===")
    
    local itemLink = GetInventoryItemLink("player", 10)
    if not itemLink then
        print("ERROR: No item in hands slot")
        return
    end
    
    local stats = GetItemStats(itemLink)
    if stats then
        print("Stats table found:")
        for k, v in pairs(stats) do
            print(string.format("  %s = %s", tostring(k), tostring(v)))
        end
    else
        print("No stats table returned")
    end
end

-- Test 4: Check if DC-ItemUpgrade frame exists
local function TestFrameExists()
    print("=== Testing Frame Existence ===")
    
    local frame = _G.DarkChaos_ItemUpgradeFrame
    if frame then
        print("Main frame exists:", frame:GetName())
        print("Frame visible:", frame:IsVisible())
        
        local statsFrame = _G.DarkChaos_ItemUpgradeFrameCurrentPanelStatsValue
        if statsFrame then
            print("Stats frame exists:", statsFrame:GetName())
            local text = statsFrame:GetText()
            print("Current text:", text or "(nil)")
        else
            print("Stats frame NOT found")
        end
    else
        print("Main frame NOT found - addon not loaded?")
    end
end

-- Run all tests
print("\n======================")
print("DC-ItemUpgrade Diagnostics")
print("======================\n")

TestFrameExists()
print("\n")
TestGetItemInfo()
print("\n")
TestTooltipScan()
print("\n")
TestGetItemStats()

print("\n======================")
print("Tests Complete")
print("======================")
