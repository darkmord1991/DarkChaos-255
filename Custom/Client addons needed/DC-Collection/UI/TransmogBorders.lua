--[[
    DC-Collection UI/TransmogBorders.lua
    ====================================
    
    Displays visual borders on Character and Inspect frames to indicate
    which equipment slots have active transmogs.
    
    Inspired by Thiesant's transmog system border feature.
]]

local DC = DCCollection
if not DC then return end

DC.TransmogBorders = DC.TransmogBorders or {}
local TransmogBorders = DC.TransmogBorders

-- ============================================================================
-- SETTINGS
-- ============================================================================

TransmogBorders.Settings = {
    showCharacterBorders = true,  -- Show borders on character frame (C)
    showInspectBorders = true,    -- Show borders on inspect frame
    borderColor = {0.1, 0.8, 1.0, 0.8}, -- Cyan color (R, G, B, A)
}

-- ============================================================================
-- SLOT MAPPING
-- ============================================================================

-- Maps equipment slot IDs to character frame slot names
local EQUIP_SLOT_TO_CHAR_FRAME = {
    [1]  = "HeadSlot",      -- Head
    [3]  = "ShoulderSlot",  -- Shoulder
    [5]  = "ChestSlot",     -- Chest
    [6]  = "WaistSlot",     -- Waist
    [7]  = "LegsSlot",      -- Legs
    [8]  = "FeetSlot",      -- Feet
    [9]  = "WristSlot",     -- Wrist
    [10] = "HandsSlot",     -- Hands
    [15] = "BackSlot",      -- Back
    [16] = "MainHandSlot",  -- Main Hand
    [17] = "SecondaryHandSlot", -- Off Hand
    [18] = "RangedSlot",    -- Ranged
}

-- Maps equipment slot IDs to inspect frame slot names
local EQUIP_SLOT_TO_INSPECT_FRAME = {
    [1]  = "HeadSlot",      -- Head
    [3]  = "ShoulderSlot",  -- Shoulder
    [5]  = "ChestSlot",     -- Chest
    [6]  = "WaistSlot",     -- Waist
    [7]  = "LegsSlot",      -- Legs
    [8]  = "FeetSlot",      -- Feet
    [9]  = "WristSlot",     -- Wrist
    [10] = "HandsSlot",     -- Hands
    [15] = "BackSlot",      -- Back
    [16] = "MainHandSlot",  -- Main Hand
    [17] = "SecondaryHandSlot", -- Off Hand
    [18] = "RangedSlot",    -- Ranged
}

-- ============================================================================
-- BORDER CREATION
-- ============================================================================

local charBorders = {}
local inspectBorders = {}

local function CreateBorderFrame(parent, slotFrame)
    if not slotFrame then return nil end
    
    local border = CreateFrame("Frame", nil, slotFrame)
    border:SetAllPoints(slotFrame)
    border:SetFrameLevel(slotFrame:GetFrameLevel() + 2)
    
    -- Create border texture
    local tex = border:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(unpack(TransmogBorders.Settings.borderColor))
    border.texture = tex
    
    border:Hide()
    return border
end

-- ============================================================================
-- CHARACTER FRAME BORDERS
-- ============================================================================

function TransmogBorders:CreateCharacterBorders()
    if not CharacterFrame then return end
    
    for slotID, frameName in pairs(EQUIP_SLOT_TO_CHAR_FRAME) do
        local slotFrame = _G["Character" .. frameName]
        if slotFrame and not charBorders[slotID] then
            charBorders[slotID] = CreateBorderFrame(CharacterFrame, slotFrame)
        end
    end
end

function TransmogBorders:UpdateCharacterBorders()
    if not self.Settings.showCharacterBorders then
        self:ClearCharacterBorders()
        return
    end
    
    -- Get transmog state for player
    local transmogState = DC.transmogState or {}
    
    for slotID, border in pairs(charBorders) do
        if border then
            local hasTransmog = transmogState[tostring(slotID)] and tonumber(transmogState[tostring(slotID)]) > 0
            if hasTransmog then
                border:Show()
            else
                border:Hide()
            end
        end
    end
end

function TransmogBorders:ClearCharacterBorders()
    for _, border in pairs(charBorders) do
        if border then
            border:Hide()
        end
    end
end

-- ============================================================================
-- INSPECT FRAME BORDERS
-- ============================================================================

function TransmogBorders:CreateInspectBorders()
    if not InspectFrame then return end
    
    for slotID, frameName in pairs(EQUIP_SLOT_TO_INSPECT_FRAME) do
        local slotFrame = _G["Inspect" .. frameName]
        if slotFrame and not inspectBorders[slotID] then
            inspectBorders[slotID] = CreateBorderFrame(InspectFrame, slotFrame)
        end
    end
end

function TransmogBorders:UpdateInspectBorders(unit)
    if not self.Settings.showInspectBorders then
        self:ClearInspectBorders()
        return
    end
    
    -- Note: Inspect borders require server-side data
    -- For now, just clear them since we don't have access to other players' transmog state
    -- This could be extended with server communication in the future
    self:ClearInspectBorders()
end

function TransmogBorders:ClearInspectBorders()
    for _, border in pairs(inspectBorders) do
        if border then
            border:Hide()
        end
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

local function OnCharacterFrameShow()
    TransmogBorders:UpdateCharacterBorders()
end

local function OnCharacterFrameHide()
    TransmogBorders:ClearCharacterBorders()
end

local function OnInspectReady(event, unit)
    TransmogBorders:UpdateInspectBorders(unit)
end

local function OnInspectFrameHide()
    TransmogBorders:ClearInspectBorders()
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function TransmogBorders:Initialize()
    -- Wait for frames to be available
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    
    frame:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Blizzard_InspectUI" then
            TransmogBorders:CreateInspectBorders()
            
            -- Hook inspect frame events
            if InspectFrame then
                InspectFrame:HookScript("OnHide", OnInspectFrameHide)
            end
            
            self:UnregisterEvent("ADDON_LOADED")
        elseif event == "PLAYER_LOGIN" then
            -- Create character frame borders
            TransmogBorders:CreateCharacterBorders()
            
            -- Hook character frame events
            if CharacterFrame then
                CharacterFrame:HookScript("OnShow", OnCharacterFrameShow)
                CharacterFrame:HookScript("OnHide", OnCharacterFrameHide)
            end
        elseif event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then
            -- Update borders when transmogs change
            if CharacterFrame and CharacterFrame:IsShown() then
                TransmogBorders:UpdateCharacterBorders()
            end
        end
    end)
end

-- Initialize on load
TransmogBorders:Initialize()
