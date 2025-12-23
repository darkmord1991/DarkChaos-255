--[[
    DC-Collection UI/Wardrobe/WardrobeCore.lua
    ==========================================

    Wardrobe core: constants, state, shared helpers, slash commands, and events.

    This file is loaded after UI/WardrobeFrame.lua (entrypoint).
]]

local DC = DCCollection
if not DC then return end

local L = DC.L or {}

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

-- ============================================================================
-- CONSTANTS / DATA TABLES
-- ============================================================================

Wardrobe.FRAME_WIDTH = 1000
Wardrobe.FRAME_HEIGHT = 650
Wardrobe.MODEL_WIDTH = 250
Wardrobe.SLOT_SIZE = 36
Wardrobe.GRID_ICON_SIZE = 46
Wardrobe.GRID_COLS = 8
Wardrobe.GRID_ROWS = 4
Wardrobe.ITEMS_PER_PAGE = Wardrobe.GRID_COLS * Wardrobe.GRID_ROWS

Wardrobe.EQUIPMENT_SLOTS = {
    -- Left column (top to bottom)
    { key = "HeadSlot",      label = "Head",      invType = 1,  side = "left",  row = 1 },
    { key = "ShoulderSlot",  label = "Shoulder",  invType = 3,  side = "left",  row = 2 },
    { key = "BackSlot",      label = "Back",      invType = 16, side = "left",  row = 3 },
    { key = "ChestSlot",     label = "Chest",     invType = 5,  side = "left",  row = 4 },
    { key = "ShirtSlot",     label = "Shirt",     invType = 4,  side = "left",  row = 5 },
    { key = "TabardSlot",    label = "Tabard",    invType = 19, side = "left",  row = 6 },
    { key = "WristSlot",     label = "Wrist",     invType = 9,  side = "left",  row = 7 },

    -- Right column (top to bottom)
    { key = "HandsSlot",     label = "Hands",     invType = 10, side = "right", row = 1 },
    { key = "WaistSlot",     label = "Waist",     invType = 6,  side = "right", row = 2 },
    { key = "LegsSlot",      label = "Legs",      invType = 7,  side = "right", row = 3 },
    { key = "FeetSlot",      label = "Feet",      invType = 8,  side = "right", row = 4 },

    -- Bottom (weapons)
    { key = "MainHandSlot",      label = "Main Hand", invType = 13, side = "bottom", row = 1 },
    { key = "SecondaryHandSlot", label = "Off Hand",  invType = 14, side = "bottom", row = 2 },
    { key = "RangedSlot",        label = "Ranged",    invType = 15, side = "bottom", row = 3 },
}

Wardrobe.SLOT_FILTERS = {
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head",     invTypes = { [1] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder", invTypes = { [3] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",    invTypes = { [5] = true, [20] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shirt",    invTypes = { [4] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Tabard",   invTypes = { [19] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists",   invTypes = { [9] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands",    invTypes = { [10] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",    invTypes = { [6] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs",     invTypes = { [7] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",     invTypes = { [8] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",    invTypes = { [16] = true } }, -- Back uses chest icon
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand", invTypes = { [13] = true, [17] = true, [21] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand", invTypes = { [14] = true, [22] = true, [23] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged",   invTypes = { [15] = true, [25] = true, [26] = true } },
}

Wardrobe.VISUAL_SLOTS = {
    HeadSlot = 283,
    ShoulderSlot = 287,
    ShirtSlot = 289,
    ChestSlot = 291,
    WaistSlot = 293,
    LegsSlot = 295,
    FeetSlot = 297,
    WristSlot = 299,
    HandsSlot = 301,
    BackSlot = 311,
    MainHandSlot = 313,
    SecondaryHandSlot = 315,
    RangedSlot = 317,
    TabardSlot = 319,
}

-- ============================================================================
-- STATE DEFAULTS
-- ============================================================================

Wardrobe.currentTab = Wardrobe.currentTab or "items" -- "items", "sets", "outfits"
Wardrobe.selectedSlot = Wardrobe.selectedSlot or nil
Wardrobe.selectedSlotFilter = Wardrobe.selectedSlotFilter or nil
Wardrobe.currentPage = Wardrobe.currentPage or 1
Wardrobe.totalPages = Wardrobe.totalPages or 1
Wardrobe.searchText = Wardrobe.searchText or ""
Wardrobe.appearanceList = Wardrobe.appearanceList or {}
Wardrobe.collectedCount = Wardrobe.collectedCount or 0
Wardrobe.totalCount = Wardrobe.totalCount or 0
Wardrobe.transmogDisabled = Wardrobe.transmogDisabled or false
Wardrobe.spellVisualsDisabled = Wardrobe.spellVisualsDisabled or false
Wardrobe.showUncollected = (Wardrobe.showUncollected ~= nil) and Wardrobe.showUncollected or true

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================

function Wardrobe:SafeGetText(key, fallback)
    if L and L[key] and L[key] ~= "" then
        return L[key]
    end
    return fallback
end

function Wardrobe:GetSlotIcon(slotKey)
    local invSlotId = GetInventorySlotInfo(slotKey)
    if invSlotId then
        local itemId = GetInventoryItemID("player", invSlotId)
        if itemId then
            local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemId)
            if texture then
                return texture
            end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Wardrobe:IsAppearanceCollected(itemId)
    if not DC or not DC.collections or not DC.collections.transmog then
        return false
    end
    return DC.collections.transmog[itemId] ~= nil
end

function Wardrobe:IsWishlistedTransmog(itemId)
    if not itemId or not DC or type(DC.wishlist) ~= "table" then
        return false
    end

    local transmogTypeId = nil
    if type(DC.GetTypeIdFromName) == "function" then
        transmogTypeId = DC:GetTypeIdFromName("transmog")
    end

    for _, wish in ipairs(DC.wishlist) do
        if type(wish) == "table" then
            local wishEntry = tonumber(wish.entryId or wish.entry_id or wish.itemId or wish.item_id) or (wish.entryId or wish.entry_id or wish.itemId or wish.item_id)
            if wishEntry == itemId then
                if transmogTypeId == nil then
                    return true
                end
                local wishType = wish.type or wish.typeId or wish.type_id
                if wishType == nil or tonumber(wishType) == tonumber(transmogTypeId) then
                    return true
                end
            end
        end
    end

    return false
end

function Wardrobe:HookItemTooltip()
    if self.tooltipHooked then return end

    local function AddCollectedLine(tooltip, itemId)
        if not itemId or itemId == 0 then return end

        if self:IsAppearanceCollected(itemId) then
            tooltip:AddLine(" ")
            tooltip:AddLine("You've collected this appearance", 0.1, 1, 0.1)
            tooltip:Show()
        end
    end

    GameTooltip:HookScript("OnTooltipSetItem", function(tip)
        local _, itemLink = tip:GetItem()
        if itemLink then
            local itemId = tonumber(string.match(itemLink, "item:(%d+)"))
            AddCollectedLine(tip, itemId)
        end
    end)

    if ItemRefTooltip then
        ItemRefTooltip:HookScript("OnTooltipSetItem", function(tip)
            local _, itemLink = tip:GetItem()
            if itemLink then
                local itemId = tonumber(string.match(itemLink, "item:(%d+)"))
                AddCollectedLine(tip, itemId)
            end
        end)
    end

    self.tooltipHooked = true
end

-- ============================================================================
-- SHOW / HIDE
-- ============================================================================

function Wardrobe:Show()
    local frame = self:CreateFrame()
    if not frame then return end

    if DC.MainFrame and DC.MainFrame:IsShown() then
        local point, relativeTo, relativePoint, xOfs, yOfs = DC.MainFrame:GetPoint()
        if point then
            frame:ClearAllPoints()
            frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
        end
        DC.MainFrame:Hide()
    end

    if DC and DC.RequestDefinitions then
        DC:RequestDefinitions("transmog")
        DC:RequestDefinitions("itemSets")
    end
    if DC and DC.RequestCollection then
        DC:RequestCollection("transmog")
    end
    if DC and DC.RequestWishlist then
        DC:RequestWishlist()
    end

    if frame.model then
        frame.model:SetUnit("player")
        frame.model:SetFacing(0)
    end

    self:SelectTab("items")

    self:UpdateSlotButtons()
    self:UpdateOutfitSlots()

    frame:Show()
end

function Wardrobe:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Wardrobe:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- ============================================================================
-- SLASH COMMAND
-- ============================================================================

SLASH_DCWARDROBE1 = "/wardrobe"
SLASH_DCWARDROBE2 = "/transmog"
SlashCmdList["DCWARDROBE"] = function()
    Wardrobe:Toggle()
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:SetScript("OnEvent", function()
    if Wardrobe.frame and Wardrobe.frame:IsShown() then
        Wardrobe:UpdateSlotButtons()
        Wardrobe:UpdateModel()
    end
end)
