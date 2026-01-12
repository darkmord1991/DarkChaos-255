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
    -- NOTE: Equipment slots are 0-based (EQUIPMENT_SLOT_*), matching server state keys.
    [0]  = "HeadSlot",      -- Head
    [2]  = "ShoulderSlot",  -- Shoulder
    [4]  = "ChestSlot",     -- Chest
    [5]  = "WaistSlot",     -- Waist
    [6]  = "LegsSlot",      -- Legs
    [7]  = "FeetSlot",      -- Feet
    [8]  = "WristSlot",     -- Wrist
    [9]  = "HandsSlot",     -- Hands
    [14] = "BackSlot",      -- Back
    [15] = "MainHandSlot",  -- Main Hand
    [16] = "SecondaryHandSlot", -- Off Hand
    [17] = "RangedSlot",    -- Ranged
    [18] = "TabardSlot",    -- Tabard
}

-- Maps equipment slot IDs to inspect frame slot names
local EQUIP_SLOT_TO_INSPECT_FRAME = {
    -- NOTE: Equipment slots are 0-based (EQUIPMENT_SLOT_*), matching server inspect payload keys.
    [0]  = "HeadSlot",      -- Head
    [2]  = "ShoulderSlot",  -- Shoulder
    [4]  = "ChestSlot",     -- Chest
    [5]  = "WaistSlot",     -- Waist
    [6]  = "LegsSlot",      -- Legs
    [7]  = "FeetSlot",      -- Feet
    [8]  = "WristSlot",     -- Wrist
    [9]  = "HandsSlot",     -- Hands
    [14] = "BackSlot",      -- Back
    [15] = "MainHandSlot",  -- Main Hand
    [16] = "SecondaryHandSlot", -- Off Hand
    [17] = "RangedSlot",    -- Ranged
    [18] = "TabardSlot",    -- Tabard
}

local function EnsureInspectActionButtons()
    if not InspectFrame then
        return
    end

    if InspectFrame.__dcInspectTransmogButtonsCreated then
        return
    end
    InspectFrame.__dcInspectTransmogButtonsCreated = true

    local preview = CreateFrame("Button", nil, InspectFrame, "UIPanelButtonTemplate")
    preview:SetSize(78, 22)
    preview:SetPoint("TOPRIGHT", InspectFrame, "TOPRIGHT", -42, -40)
    preview:SetText("Preview")
    preview:SetScript("OnClick", function()
        if DC and type(DC.PreviewLastInspectedAppearance) == "function" then
            DC:PreviewLastInspectedAppearance()
        end
    end)
    InspectFrame.__dcInspectPreviewButton = preview

    local copy = CreateFrame("Button", nil, InspectFrame, "UIPanelButtonTemplate")
    copy:SetSize(92, 22)
    copy:SetPoint("RIGHT", preview, "LEFT", -6, 0)
    copy:SetText("Copy Outfit")
    copy:SetScript("OnClick", function()
        if DC and type(DC.CopyLastInspectedAppearanceToOutfitPrompt) == "function" then
            DC:CopyLastInspectedAppearanceToOutfitPrompt()
        end
    end)
    InspectFrame.__dcInspectCopyButton = copy
end

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

    EnsureInspectActionButtons()

    -- Server-provided inspect payload stores fakeEntry (item entry) keyed by 0-based equipment slot.
    local inspectItemIds = DC and DC.inspectTransmogItemIds or nil
    if type(inspectItemIds) ~= "table" then
        self:ClearInspectBorders()
        return
    end

    for equipSlot, border in pairs(inspectBorders) do
        if border then
            local itemId = inspectItemIds[tostring(equipSlot)]
            local hasTransmog = itemId and tonumber(itemId) and tonumber(itemId) > 0
            if hasTransmog then
                border:Show()
            else
                border:Hide()
            end
        end
    end
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

local function OnInspectFrameShow()
    -- Best-effort: request server-side inspect transmog data for the currently inspected unit.
    if not DC or type(DC.RequestInspectTarget) ~= "function" then
        return
    end

    local unit = (InspectFrame and InspectFrame.unit) or "target"
    if unit and UnitExists(unit) and UnitIsPlayer(unit) then
        pcall(function() DC:RequestInspectTarget(unit) end)
    end
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
            EnsureInspectActionButtons()
            
            -- Hook inspect frame events
            if InspectFrame then
                InspectFrame:HookScript("OnHide", OnInspectFrameHide)
                InspectFrame:HookScript("OnShow", OnInspectFrameShow)
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
