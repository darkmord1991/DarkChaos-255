-- Simple test script to verify addon functionality
-- This simulates WoW environment for testing

-- Mock WoW globals
_G = _G or {}
SlashCmdList = SlashCmdList or {}
DEFAULT_CHAT_FRAME = {
    AddMessage = function(self, msg, r, g, b)
        print(string.format("[%.2f,%.2f,%.2f] %s", r or 1, g or 1, b or 1, msg))
    end
}

-- Mock frames
local MockFrame = {}
function MockFrame:new(name)
    local frame = {
        name = name,
        text = "",
        enabled = true,
        shown = true,
        itemLink = nil
    }
    function frame:SetText(text) self.text = text end
    function frame:GetText() return self.text end
    function frame:SetTextColor(r, g, b) end
    function frame:Enable() self.enabled = true end
    function frame:Disable() self.enabled = false end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:GetValue() return 0 end
    function frame:SetMinMaxValues(min, max) end
    function frame:SetValue(val) end
    return frame
end

-- Mock API functions
function GetItemInfo(itemLink)
    return "Test Item", itemLink, 4, 200, 80, "Armor", "Plate", 1, "INVTYPE_CHEST", "icon", 1000
end

function GetItemQualityColor(rarity)
    return 1, 1, 0, 1
end

function GetItemIcon(itemLink)
    return "icon"
end

function SetItemButtonTexture(button, texture) end
function GetTime() return 123456 end
function CreateFrame(type, name) return MockFrame:new(name) end
function getglobal(name) return _G[name] end

-- Load the addon
dofile("DarkChaos_ItemUpgrade.lua")

-- Simulate calling OnLoad to register slash commands
if _G.DarkChaos_ItemUpgrade_OnLoad then
    _G.DarkChaos_ItemUpgrade_OnLoad(nil)
end

print("=== Testing DarkChaos Item Upgrade Addon ===")

-- Test 1: Check if addon is globally exposed
if _G.DarkChaos_ItemUpgrade then
    print("✓ Addon table exposed globally")
else
    print("✗ Addon table not exposed globally")
end

-- Test 2: Check slash commands
if _G.SLASH_DCUPGRADE1 == "/dcupgrade" then
    print("✓ /dcupgrade slash command registered")
else
    print("✗ /dcupgrade slash command not registered")
end

if _G.SLASH_DCUPGRADE2 == "/itemupgrade" then
    print("✓ /itemupgrade slash command registered")
else
    print("✗ /itemupgrade slash command not registered")
end

if SlashCmdList and SlashCmdList.DCUPGRADE then
    print("✓ Slash command handler registered")
else
    print("✗ Slash command handler not registered")
end

-- Test 3: Check main functions exist
local functions_to_check = {
    "DarkChaos_ItemUpgrade_OnLoad",
    "DarkChaos_ItemUpgrade_ShowFrame",
    "DarkChaos_ItemUpgrade_UpdateUI",
    "DarkChaos_ItemUpgrade_OnSliderValueChanged",
    "DarkChaos_ItemUpgrade_OnUpgradeClick",
    "DarkChaos_ItemUpgrade_SelectItemByGuid",
    "DarkChaos_ItemUpgrade_UpdateCosts",
    "DarkChaos_ItemUpgrade_UpdateStatChanges"
}

local function_count = 0
for _, func_name in ipairs(functions_to_check) do
    if _G[func_name] and type(_G[func_name]) == "function" then
        function_count = function_count + 1
    else
        print("✗ Function " .. func_name .. " not found")
    end
end

print("✓ " .. function_count .. "/" .. #functions_to_check .. " functions found")

-- Test 4: Simulate item selection
print("\n=== Testing Item Selection ===")
local test_item_link = "|cff0070dd|Hitem:12345:0:0:0:0:0:0:0|h[Test Item]|h|r"
_G.DarkChaos_ItemUpgrade_SelectItemByGuid("test_guid_123", test_item_link)
print("✓ Item selection simulated")

print("\n=== Test Complete ===")