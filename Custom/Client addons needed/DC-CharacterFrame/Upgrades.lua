--[[
    DC-CharacterFrame / Upgrades.lua
    ================================
    DC-ItemUpgrade integration:
      * sidebar pane 4 "Upgrades": every equipped slot with its item level and
        upgrade progress; click a row to open the upgrade window on that item;
        buttons for the standard and heirloom upgrade windows
      * item level badge on each equipment slot (upgraded items in green)
      * retires the three icon buttons the older addons bolted onto the frame
        (item upgrade, heirloom upgrade, collection) - their functions now live
        in the sidebar and the outfit dropdown

    Everything is optional: without DC-ItemUpgrade the tab is disabled and
    the badges fall back to the plain item level.
]]

local DCCF = DCCharacterFrame

local BAG_EQUIPPED = 255

local function IU()
    return rawget(_G, "DarkChaos_ItemUpgrade")
end

-- Row order: armour top to bottom, then jewellery, then weapons.
local PANE_SLOTS = {
    { id = 1,  name = "Head" },      { id = 2,  name = "Neck" },     { id = 3,  name = "Shoulder" },
    { id = 15, name = "Back" },      { id = 5,  name = "Chest" },    { id = 9,  name = "Wrist" },
    { id = 10, name = "Hands" },     { id = 6,  name = "Waist" },    { id = 7,  name = "Legs" },
    { id = 8,  name = "Feet" },      { id = 11, name = "Ring 1" },   { id = 12, name = "Ring 2" },
    { id = 13, name = "Trinket 1" }, { id = 14, name = "Trinket 2" }, { id = 16, name = "Main Hand" },
    { id = 17, name = "Off Hand" },  { id = 18, name = "Ranged" },
}

local NO_BADGE_SLOTS = { [0] = true, [4] = true, [19] = true }   -- ammo, shirt, tabard

local SLOT_KEYS = {
    [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [15] = "BackSlot", [5] = "ChestSlot",
    [9] = "WristSlot", [10] = "HandsSlot", [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot",
    [11] = "Finger0Slot", [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot",
    [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot",
}

-- ---------------------------------------------------------------------------
-- Upgrade cache access
-- ---------------------------------------------------------------------------

function DCCF:GetSlotUpgradeInfo(slotId)
    local iu = IU()
    if not iu or type(DarkChaos_ItemUpgrade_GetCachedDataForLocation) ~= "function" then
        return nil
    end
    local data = DarkChaos_ItemUpgrade_GetCachedDataForLocation(iu.BAG_EQUIPPED or BAG_EQUIPPED, slotId - 1)
    if not data then
        return nil
    end
    return {
        current = tonumber(data.currentUpgrade) or 0,
        max = tonumber(data.maxUpgrade) or 0,
        itemLevel = tonumber(data.upgradedItemLevel) or 0,
        baseLevel = tonumber(data.baseItemLevel) or 0,
        tier = tonumber(data.tier) or 0,
    }
end

local function IsHeirloom(itemId)
    local iu = IU()
    return iu and type(iu.IsHeirloomItemId) == "function" and iu.IsHeirloomItemId(itemId) or false
end

function DCCF:OpenUpgradeWindow(mode, slotId)
    local iu = IU()
    if not iu or type(iu.ToggleUpgradeFrame) ~= "function" then
        self:Print("DC-ItemUpgrade is not loaded.")
        return
    end
    if DarkChaos_ItemUpgradeFrame and DarkChaos_ItemUpgradeFrame:IsShown() then
        DarkChaos_ItemUpgradeFrame:Hide()
    end
    -- ToggleUpgradeFrame prints its own combat / instance refusal.
    if not iu.ToggleUpgradeFrame(mode) then
        return
    end
    if slotId and type(DarkChaos_ItemUpgrade_SelectItemBySlot) == "function" then
        DarkChaos_ItemUpgrade_SelectItemBySlot(iu.BAG_EQUIPPED or BAG_EQUIPPED, slotId)
    end
end

-- ---------------------------------------------------------------------------
-- Slot badges
-- ---------------------------------------------------------------------------

function DCCF:UpdateSlotItemLevel(btn)
    local fs = btn.dccfLevel
    if not fs then
        fs = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        fs:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        fs:SetJustifyH("RIGHT")
        btn.dccfLevel = fs
    end
    local id = btn:GetID()
    if not self.db.showSlotItemLevel or NO_BADGE_SLOTS[id] then
        fs:Hide()
        return
    end
    local link = GetInventoryItemLink("player", id)
    if not link then
        fs:Hide()
        return
    end
    local _, _, _, level = GetItemInfo(link)
    local info = self:GetSlotUpgradeInfo(id)
    if info and info.itemLevel > 0 then
        level = info.itemLevel
    end
    if not level or level <= 0 then
        fs:Hide()
        return
    end
    fs:SetText(level)
    if info and info.current > 0 then
        fs:SetTextColor(0.2, 1, 0.2)
    else
        fs:SetTextColor(1, 1, 1)
    end
    fs:Show()
end

-- ---------------------------------------------------------------------------
-- Upgrades pane
-- ---------------------------------------------------------------------------

local ROW_H = 26

local function BuildUpgradesPane(parent)
    local pane = DCCF.CreateListPane(parent, {
        name = "DCCharacterUpgradesPane",
        rowHeight = ROW_H,
        numRows = 12,
        createRow = function(listPane, i)
            local row = CreateFrame("Button", nil, listPane)
            row:SetWidth(DCCF.LIST_ROW_W)
            row:SetHeight(ROW_H)
            DCCF.SkinListRow(row, 14)
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetWidth(20)
            icon:SetHeight(20)
            icon:SetPoint("LEFT", 4, 0)
            row.Icon = icon
            local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            name:SetWidth(84)
            name:SetHeight(ROW_H)
            name:SetJustifyH("LEFT")
            row.Name = name
            local level = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            level:SetPoint("RIGHT", row, "RIGHT", -36, 0)
            level:SetJustifyH("RIGHT")
            row.Level = level
            local progress = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            progress:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            progress:SetWidth(30)
            progress:SetJustifyH("RIGHT")
            row.Progress = progress

            row:SetScript("OnClick", function(self)
                if self.slotId and self.hasItem then
                    PlaySound("igMainMenuOptionCheckBoxOn")
                    DCCF:OpenUpgradeWindow(self.isHeirloom and "HEIRLOOM" or "STANDARD", self.slotId)
                end
            end)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.slotId and self.hasItem then
                    GameTooltip:SetInventoryItem("player", self.slotId)
                    GameTooltip:AddLine(" ")
                    if self.isHeirloom then
                        GameTooltip:AddLine("|cff00ff00Click|r to open the Heirloom Upgrade window.", 0.8, 0.8, 0.8)
                    else
                        GameTooltip:AddLine("|cff00ff00Click|r to open the Item Upgrade window.", 0.8, 0.8, 0.8)
                    end
                else
                    GameTooltip:SetText(self.slotName or "", 1, 1, 1)
                    GameTooltip:AddLine("Nothing equipped.", 0.6, 0.6, 0.6)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            return row
        end,
        updateRow = function(row, index)
            local slot = PANE_SLOTS[index]
            local slotId = slot.id
            row.slotId = slotId
            row.slotName = slot.name
            local link = GetInventoryItemLink("player", slotId)
            row.hasItem = link ~= nil
            if index % 2 == 0 then
                row.Stripe:Show()
            else
                row.Stripe:Hide()
            end
            if not link then
                local _, slotTexture = GetInventorySlotInfo(SLOT_KEYS[slotId])
                row.Icon:SetTexture(slotTexture)
                row.Icon:SetVertexColor(0.5, 0.5, 0.5)
                row.Name:SetText(GRAY_FONT_COLOR_CODE .. slot.name .. FONT_COLOR_CODE_CLOSE)
                row.Level:SetText("")
                row.Progress:SetText("")
                row.isHeirloom = false
                return
            end
            local itemName, _, quality, level = GetItemInfo(link)
            local itemId = tonumber(string.match(link, "item:(%d+)"))
            local info = DCCF:GetSlotUpgradeInfo(slotId)
            if info and info.itemLevel > 0 then
                level = info.itemLevel
            end
            row.isHeirloom = IsHeirloom(itemId)
            row.Icon:SetTexture(GetInventoryItemTexture("player", slotId))
            row.Icon:SetVertexColor(1, 1, 1)
            local color = quality and ITEM_QUALITY_COLORS[quality]
            local hex = color and color.hex or "|cffffffff"
            row.Name:SetText(hex .. (itemName or slot.name) .. FONT_COLOR_CODE_CLOSE)
            row.Level:SetText(level and level > 0 and level or "")
            if info and info.max > 0 then
                if info.current >= info.max then
                    row.Progress:SetText(GREEN_FONT_COLOR_CODE .. info.current .. "/" .. info.max .. FONT_COLOR_CODE_CLOSE)
                else
                    row.Progress:SetText(NORMAL_FONT_COLOR_CODE .. info.current .. "/" .. info.max .. FONT_COLOR_CODE_CLOSE)
                end
            elseif row.isHeirloom then
                row.Progress:SetText("|cffe6cc80" .. "HL" .. FONT_COLOR_CODE_CLOSE)
            else
                row.Progress:SetText(GRAY_FONT_COLOR_CODE .. "-" .. FONT_COLOR_CODE_CLOSE)
            end
        end,
        getCount = function()
            return #PANE_SLOTS
        end,
    })
    pane:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -31)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)
    DCCF.upgradesPane = pane

    local standard = CreateFrame("Button", "DCCharacterUpgradesStandardButton", pane, "UIPanelButtonTemplate")
    standard:SetWidth(87)
    standard:SetHeight(22)
    standard:SetPoint("BOTTOMLEFT", pane, "TOPLEFT", 0, 4)
    standard:SetText("Item Upgrade")
    standard:SetScript("OnClick", function()
        DCCF:OpenUpgradeWindow("STANDARD")
    end)
    standard:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Item Upgrade", 1, 1, 1)
        GameTooltip:AddLine("Open the standard Item Upgrade window.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    standard:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local heirloom = CreateFrame("Button", "DCCharacterUpgradesHeirloomButton", pane, "UIPanelButtonTemplate")
    heirloom:SetWidth(87)
    heirloom:SetHeight(22)
    heirloom:SetPoint("LEFT", standard, "RIGHT", 0, 0)
    heirloom:SetText("Heirloom")
    heirloom:SetScript("OnClick", function()
        DCCF:OpenUpgradeWindow("HEIRLOOM")
    end)
    heirloom:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Heirloom Upgrade", 1, 0.82, 0)
        GameTooltip:AddLine("Open the Heirloom Upgrade window.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    heirloom:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    function pane.Refresh()
        pane.Update()
    end
    pane:SetScript("OnShow", pane.Refresh)
    return pane
end

function DCCF:RefreshUpgradesPane()
    local pane = self.upgradesPane
    if pane and pane:IsVisible() then
        pane.Refresh()
    end
end

DCCF:RegisterSidebar({
    key = "upgrades",
    name = "Item Upgrades",
    icon = "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\Icons\\ItemUpgrade_64.tga",
    build = BuildUpgradesPane,
    IsActive = function() return IU() ~= nil end,
    disabledTooltip = "DC-ItemUpgrade is not loaded.",
    onShow = function(pane) pane.Refresh() end,
})

-- ---------------------------------------------------------------------------
-- Retire the old character-frame icon buttons
-- ---------------------------------------------------------------------------

local RETIRED_BUTTONS = {
    "DC_ItemUpgrade_CharFrameButton",
    "DC_ItemUpgrade_HeirloomButton",
    "DC_Collection_CharFrameButton",
}

local function RetireOldButtons()
    -- An older DC-QOS without the superseded check would still build its
    -- stats side panel; keep it and its toggle out of the way.
    for _, name in ipairs({ "DCQoSExtendedStatsFrame", "DCQoSExtendedStatsToggle", "DCQoSExtendedStatsSettings" }) do
        local f = _G[name]
        if f and not f.dccfRetired then
            f.dccfRetired = true
            f:Hide()
            f.Show = function() end
        end
    end
    local pending = false
    for _, name in ipairs(RETIRED_BUTTONS) do
        local btn = _G[name]
        if btn then
            if not btn.dccfRetired then
                btn.dccfRetired = true
                btn:Hide()
                -- DC-QOS ExtendedStats re-shows and re-parents these; keep them gone.
                btn.Show = function() end
            end
        else
            pending = true
        end
    end
    return pending
end

function DCCF:BuildUpgrades()
    -- The collection button is created on PLAYER_LOGIN as well; retry briefly.
    if RetireOldButtons() then
        local retry = CreateFrame("Frame")
        retry.elapsed = 0
        retry.tries = 0
        retry:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed < 1 then
                return
            end
            self.elapsed = 0
            self.tries = self.tries + 1
            if not RetireOldButtons() or self.tries >= 5 then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end

    local function RefreshFromUpgradeCache()
        if PaperDollFrame:IsShown() then
            DCCF:RefreshUpgradesPane()
            DCCF:UpdateAllSlotOverlays()
            DCCF:UpdateItemLevelDisplay()
        end
    end

    if type(DarkChaos_ItemUpgrade_HandleJsonItemInfo) == "function" then
        hooksecurefunc("DarkChaos_ItemUpgrade_HandleJsonItemInfo", RefreshFromUpgradeCache)
    end

    -- A successful upgrade changes the cache without an item-info response, so
    -- hooking only the handler above left this pane one purchase behind: it kept
    -- showing e.g. "298  14/15" for an item that was already 15/15.
    if type(DarkChaos_ItemUpgrade_OnUpgradeCacheChanged) == "function" then
        hooksecurefunc("DarkChaos_ItemUpgrade_OnUpgradeCacheChanged", RefreshFromUpgradeCache)
    end
end
