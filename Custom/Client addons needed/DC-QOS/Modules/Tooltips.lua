-- ============================================================
-- DC-QoS: Tooltips Module
-- ============================================================
-- Enhanced tooltip functionality for items, NPCs, and spells
-- Adapted from Leatrix Plus for WoW 3.3.5a compatibility
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local Tooltips = {
    displayName = "Tooltips",
    settingKey = "tooltips",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
}

-- ============================================================
-- Local Variables
-- ============================================================
local GameLocale = GetLocale()
local colorBlindMode = GetCVar("colorblindMode")

-- Raid class colors for player tooltips
local RaidColors = {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73 },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45 },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41 },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00 },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23 },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87 },
    ["MAGE"]        = { r = 0.41, g = 0.80, b = 0.94 },
    ["WARLOCK"]     = { r = 0.58, g = 0.51, b = 0.79 },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04 },
}

-- Localized class names
local ClassNamesMale = LOCALIZED_CLASS_NAMES_MALE
local ClassNamesFemale = LOCALIZED_CLASS_NAMES_FEMALE

-- Level string for parsing
local LevelString = string.lower(TOOLTIP_UNIT_LEVEL:gsub("%%s", ".+"))

-- Tooltip text cache for performance
local tooltipTextCache = {}

-- ============================================================
-- Item Upgrade/Tier Info Cache
-- ============================================================
-- Cache for item upgrade data from server
local itemUpgradeCache = {}
local pendingUpgradeRequests = {}
local UPGRADE_CACHE_DURATION = 300  -- 5 minutes

-- Tier color definitions (matches DC-ItemUpgrade)
local TIER_COLORS = {
    [0] = "|cff888888",  -- No tier (gray)
    [1] = "|cff00ff00",  -- Tier 1 (green)
    [2] = "|cff0070dd",  -- Tier 2 (blue)
    [3] = "|cffa335ee",  -- Tier 3 (purple/heirloom)
    [4] = "|cffff8000",  -- Tier 4 (orange/legendary)
    [5] = "|cffe6cc80",  -- Tier 5 (artifact)
}

-- Build item location key for caching
local function BuildLocationKey(bag, slot)
    return string.format("%d:%d", bag or 0, slot or 0)
end

-- Convert client bag to server bag ID
local function GetServerBagFromClient(bag)
    -- Backpack is 0, other bags are 1-4 for regular, -1 for bank, 5-11 for bank bags
    if bag == 0 then return 255 end  -- INVENTORY_SLOT_BAG_0
    if bag >= 1 and bag <= 4 then return 18 + bag end  -- Regular bags (19-22)
    if bag == -1 then return 255 end  -- Bank main
    if bag >= 5 and bag <= 11 then return 62 + (bag - 5) end  -- Bank bags
    return bag
end

-- Convert client slot to server slot ID  
local function GetServerSlotFromClient(bag, slot)
    if bag == 0 then
        return 22 + slot  -- Backpack slots start at 23
    end
    return slot - 1  -- Other bags are 0-indexed on server
end

-- Request upgrade info from server
local function RequestUpgradeInfo(bag, slot, itemLink)
    if not addon.protocol or not addon.protocol.connected then
        return
    end
    
    local serverBag = GetServerBagFromClient(bag)
    local serverSlot = GetServerSlotFromClient(bag, slot)
    local locationKey = BuildLocationKey(serverBag, serverSlot)
    
    -- Don't re-request if pending
    if pendingUpgradeRequests[locationKey] then
        return
    end
    
    -- Check cache
    local cached = itemUpgradeCache[locationKey]
    if cached and (GetTime() - cached.timestamp) < UPGRADE_CACHE_DURATION then
        return
    end
    
    pendingUpgradeRequests[locationKey] = true
    
    -- Request via protocol
    addon.protocol:RequestItemUpgradeInfo(serverBag, serverSlot)
end

-- Handle upgrade info from server
local function OnUpgradeInfoReceived(data)
    if not data then return end
    
    local locationKey = BuildLocationKey(data.bag, data.slot)
    pendingUpgradeRequests[locationKey] = nil
    
    itemUpgradeCache[locationKey] = {
        timestamp = GetTime(),
        upgradeLevel = data.upgradeLevel or 0,
        maxUpgrade = data.maxUpgrade or 0,
        tier = data.tier or 0,
        statMultiplier = data.statMultiplier or 1.0,
        baseEntry = data.baseEntry,
        currentEntry = data.currentEntry,
        baseIlvl = data.baseIlvl,
        upgradedIlvl = data.upgradedIlvl,
    }
    
    -- Refresh tooltip if still showing this item
    if GameTooltip:IsShown() then
        local _, link = GameTooltip:GetItem()
        if link then
            -- Force tooltip refresh
            GameTooltip:Show()
        end
    end
end

-- Register for upgrade info events
addon:RegisterEvent("ITEM_UPGRADE_INFO_RECEIVED", OnUpgradeInfoReceived)

-- Add upgrade/tier info to tooltip
local function AddUpgradeInfo(tooltip, bag, slot, itemLink)
    if not addon.settings.tooltips.showUpgradeInfo then return end
    if not itemLink then return end
    
    -- Only show for armor/weapons
    local _, _, quality, _, _, itemType, _, _, equipLoc = GetItemInfo(itemLink)
    if quality == 7 then return end  -- Skip heirlooms (handled separately)
    if itemType ~= "Armor" and itemType ~= "Weapon" then return end
    if equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_QUIVER" then return end
    
    local serverBag = GetServerBagFromClient(bag)
    local serverSlot = GetServerSlotFromClient(bag, slot)
    local locationKey = BuildLocationKey(serverBag, serverSlot)
    
    -- Check cache
    local cached = itemUpgradeCache[locationKey]
    if not cached then
        -- Request from server
        RequestUpgradeInfo(bag, slot, itemLink)
        return
    end
    
    -- Don't show if no upgrades possible
    if cached.maxUpgrade <= 0 and cached.upgradeLevel <= 0 then
        return
    end
    
    -- Prevent duplicate lines
    if tooltip._dcqosUpgradeShown == locationKey then
        return
    end
    tooltip._dcqosUpgradeShown = locationKey
    
    local current = cached.upgradeLevel or 0
    local maxUpgrade = cached.maxUpgrade or 0
    local tier = cached.tier or 0
    local statMultiplier = cached.statMultiplier or 1.0
    local totalBonus = (statMultiplier - 1.0) * 100
    
    -- Add separator
    tooltip:AddLine(" ")
    
    -- Show upgrade level with progress color
    local progressColor = TIER_COLORS[tier] or "|cffffcc00"
    if current >= maxUpgrade then
        progressColor = "|cff00ff00"  -- Green for maxed
    elseif current == 0 then
        progressColor = "|cff888888"  -- Gray for not upgraded
    end
    
    tooltip:AddLine(string.format("%sUpgrade Level %d / %d  Tier %d|r", progressColor, current, maxUpgrade, tier))
    
    -- Show stat bonus if upgraded
    if totalBonus > 0 then
        tooltip:AddLine(string.format("|cff00ff00+%.1f%% All Stats|r", totalBonus))
    end
    
    -- Show item level difference if available
    if cached.baseIlvl and cached.upgradedIlvl and cached.upgradedIlvl > cached.baseIlvl then
        tooltip:AddLine(string.format("|cff888888Base iLvl: %d -> Upgraded: %d|r", cached.baseIlvl, cached.upgradedIlvl))
    end
    
    -- Show current entry if different from base (indicates modified item)
    if cached.currentEntry and cached.baseEntry and cached.currentEntry ~= cached.baseEntry then
        tooltip:AddLine(string.format("|cff666666Upgraded Entry: %d|r", cached.currentEntry))
    end
end

-- Clear upgrade cache for a slot (call when item moves/changes)
local function ClearUpgradeCache(bag, slot)
    local serverBag = GetServerBagFromClient(bag)
    local serverSlot = GetServerSlotFromClient(bag, slot)
    local locationKey = BuildLocationKey(serverBag, serverSlot)
    itemUpgradeCache[locationKey] = nil
    pendingUpgradeRequests[locationKey] = nil
end

-- Export functions for other modules
Tooltips.ClearUpgradeCache = ClearUpgradeCache
Tooltips.RequestUpgradeInfo = RequestUpgradeInfo

-- ============================================================
-- Tooltip Position Anchor
-- ============================================================
local TipDrag = nil  -- Drag frame for positioning

local function CreateTipDragFrame()
    if TipDrag then return end
    
    TipDrag = CreateFrame("Frame", "DCQoSTipDrag", UIParent)
    TipDrag:SetToplevel(true)
    TipDrag:SetClampedToScreen(true)
    TipDrag:SetSize(130, 64)
    TipDrag:Hide()
    TipDrag:SetFrameStrata("TOOLTIP")
    TipDrag:SetMovable(true)
    TipDrag:EnableMouse(true)
    TipDrag:RegisterForDrag("LeftButton")
    TipDrag:SetBackdropColor(0.0, 0.5, 1.0)
    TipDrag:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    
    -- Title text
    TipDrag.text = TipDrag:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    TipDrag.text:SetPoint("CENTER", 0, 0)
    TipDrag.text:SetText("Tooltip")
    
    -- Background texture
    TipDrag.bg = TipDrag:CreateTexture(nil, "BACKGROUND")
    TipDrag.bg:SetAllPoints()
    TipDrag.bg:SetTexture(0.0, 0.5, 1.0, 0.5)
    
    -- Drag handlers
    local startX, startY
    TipDrag:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then
            startX, startY = self:GetCenter()
            self:StartMoving()
        elseif btn == "RightButton" then
            self:Hide()
        end
    end)
    
    TipDrag:SetScript("OnMouseUp", function(self, btn)
        if btn == "LeftButton" then
            self:StopMovingOrSizing()
            local endX, endY = self:GetCenter()
            local settings = addon.settings.tooltips
            settings.cursorOffsetX = (settings.cursorOffsetX or 0) + (endX - startX)
            settings.cursorOffsetY = (settings.cursorOffsetY or 0) + (endY - startY)
            addon:SaveSettings()
        end
    end)
end

-- ============================================================
-- Tooltip Anchor Positioning
-- ============================================================
local function SetTooltipAnchor()
    local settings = addon.settings.tooltips
    if not settings.enabled then return end
    
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        local anchor = settings.anchor or 1
        
        if anchor == 1 then
            -- Default positioning
            return
        elseif anchor == 2 then
            -- Fixed overlay position
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 
                settings.cursorOffsetX or -13, 
                settings.cursorOffsetY or 94)
        elseif anchor == 3 then
            -- Cursor attached
            tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        elseif anchor == 4 then
            -- Cursor right with offset
            tooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 
                settings.cursorOffsetX or 0, 
                settings.cursorOffsetY or 0)
        end
    end)
end

-- ============================================================
-- Tooltip Scale
-- ============================================================
local function SetTooltipScale()
    local settings = addon.settings.tooltips
    local scale = settings.scale or 1.0
    
    -- Apply scale to various tooltip frames
    local tooltipFrames = {
        GameTooltip,
        FriendsTooltip,
        ItemRefTooltip,
        ItemRefShoppingTooltip1,
        ItemRefShoppingTooltip2,
        ShoppingTooltip1,
        ShoppingTooltip2,
        AutoCompleteBox,
        NamePlateTooltip,
    }
    
    for _, frame in ipairs(tooltipFrames) do
        if frame then
            frame:SetScale(scale)
        end
    end
    
    if TipDrag then
        TipDrag:SetScale(scale)
    end
end

-- ============================================================
-- Item ID in Tooltips
-- ============================================================
local function AddItemId(tooltip, itemLink)
    if not addon.settings.tooltips.showItemId then return end
    if not itemLink then return end
    
    -- Extract item ID from link
    local itemId = itemLink:match("item:(%d+)")
    if itemId then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Item ID:", "|cffffffff" .. itemId .. "|r", 0.5, 0.5, 0.5)
    end
end

-- ============================================================
-- Item Level in Tooltips
-- ============================================================
local function AddItemLevel(tooltip, itemLink)
    if not addon.settings.tooltips.showItemLevel then return end
    if not itemLink then return end
    
    local _, _, _, itemLevel = GetItemInfo(itemLink)
    if itemLevel and itemLevel > 0 then
        tooltip:AddDoubleLine("Item Level:", "|cffffffff" .. itemLevel .. "|r", 0.5, 0.5, 0.5)
    end
end

-- ============================================================
-- Spell ID in Tooltips
-- ============================================================
local function AddSpellId(tooltip, spellId)
    if not addon.settings.tooltips.showSpellId then return end
    if not spellId then return end
    
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("Spell ID:", "|cffffffff" .. spellId .. "|r", 0.5, 0.5, 0.5)
end

-- ============================================================
-- NPC ID in Tooltips (with DB GUID from server)
-- ============================================================
local npcInfoCache = {}       -- Cache server-provided NPC info
local pendingNpcRequests = {} -- Track pending requests

-- Parse NPC IDs from GUID (3.3.5a format)
local function ParseNpcFromGuid(guid)
    if not guid or type(guid) ~= "string" then
        return nil, nil
    end
    
    -- Handle 3.3.5a Hex GUIDs (e.g., 0xF130001234005678)
    if guid:find("^0x") then
        local hex = guid:sub(3)
        if #hex >= 12 then
            -- 3.3.5a Layout: High(variable) - Entry(24 bits) - Low(24 bits)
            -- Last 6 chars = Low GUID (Spawn ID)
            -- Previous 6 chars = Entry ID
            local spawnHex = hex:sub(-6)
            local entryHex = hex:sub(-12, -7)
            local highHex = hex:sub(1, -13)
            
            -- Check for Creature (F130), Vehicle (F150), or Pet (F140)
            if highHex:find("^F1") then
                local entry = tonumber(entryHex, 16)
                local spawnId = tonumber(spawnHex, 16)
                return entry, spawnId
            end
        end
    end
    
    -- Fallback: string-based parsing (Creature-0-0000-0-0000-Entry-SpawnId)
    local parts = {}
    for token in string.gmatch(guid, "[^%-]+") do
        parts[#parts + 1] = token
    end
    
    local unitType = parts[1]
    if unitType ~= "Creature" and unitType ~= "Vehicle" and unitType ~= "Pet" then
        return nil, nil
    end
    
    local entry = tonumber(parts[#parts - 1])
    local spawnHex = parts[#parts]
    local spawnId = tonumber(spawnHex, 16) or tonumber(spawnHex)
    
    return entry, spawnId
end

-- Request NPC info from server
local function RequestNpcInfo(guid)
    if not guid then return end
    if pendingNpcRequests[guid] then return end
    if npcInfoCache[guid] then return end
    
    pendingNpcRequests[guid] = true
    
    -- Use DC-QoS protocol to request NPC info
    if addon.protocol and addon.protocol.connected then
        addon.protocol:RequestNpcInfo(guid)
    end
end

-- Handle NPC info received from server
local function OnNpcInfoReceived(npcData)
    if not npcData or not npcData.guid then return end
    
    local guid = npcData.guid
    -- Normalize GUID to match UnitGUID format (0x prefix)
    if string.sub(guid, 1, 2) ~= "0x" then
        guid = "0x" .. guid
    end
    
    pendingNpcRequests[guid] = nil
    npcInfoCache[guid] = {
        spawnId = npcData.spawnId,
        entry = npcData.entry,
        dbGuid = npcData.dbGuid,
    }
    
    -- Refresh tooltip if showing this unit
    if GameTooltip:IsShown() then
        local _, unit = GameTooltip:GetUnit()
        if unit then
            local currentGuid = UnitGUID(unit)
            if currentGuid and string.lower(currentGuid) == string.lower(guid) then
                -- Force tooltip refresh
                GameTooltip:Hide()
                GameTooltip:SetUnit(unit)
            end
        end
    end
end

-- Register for NPC info events
addon:RegisterEvent("NPC_INFO_RECEIVED", OnNpcInfoReceived)

local function AddNpcId(tooltip, unit)
    if not addon.settings.tooltips.showNpcId then return end
    if not unit then return end
    if UnitIsPlayer(unit) then return end
    
    local guid = UnitGUID(unit)
    if not guid then return end
    
    -- Avoid duplicate lines
    if tooltip._dcqosNpcGuid == guid then return end
    tooltip._dcqosNpcGuid = guid
    
    -- Parse local NPC info
    local entry, localSpawnId = ParseNpcFromGuid(guid)
    
    -- Check server cache for more accurate info
    local cachedInfo = npcInfoCache[guid]
    local dbGuid = nil
    
    if cachedInfo then
        if cachedInfo.entry then entry = cachedInfo.entry end
        if cachedInfo.spawnId then localSpawnId = cachedInfo.spawnId end
        dbGuid = cachedInfo.dbGuid or cachedInfo.spawnId
    else
        -- Request from server
        RequestNpcInfo(guid)
    end
    
    -- Add separator
    tooltip:AddLine(" ")
    
    -- Show Entry ID
    if entry then
        tooltip:AddDoubleLine("Entry:", "|cffffffff" .. entry .. "|r", 0.5, 0.5, 0.5)
    end
    
    -- Show DB GUID (from server or parsed)
    if dbGuid then
        tooltip:AddDoubleLine("DB GUID:", "|cffffffff" .. dbGuid .. "|r", 0.5, 0.5, 0.5)
    elseif cachedInfo == nil then
        tooltip:AddDoubleLine("DB GUID:", "|cff888888Fetching...|r", 0.5, 0.5, 0.5)
    elseif localSpawnId then
        tooltip:AddDoubleLine("DB GUID:", "|cffffff88~" .. localSpawnId .. "|r", 0.5, 0.5, 0.5)
    end
    
    -- Show raw GUID if debug mode
    if addon.settings.communication and addon.settings.communication.debugMode then
        tooltip:AddDoubleLine("GUID:", "|cff666666" .. guid .. "|r", 0.3, 0.3, 0.3)
    end
end

-- ============================================================
-- Unit Tooltip Enhancement
-- ============================================================
local function EnhanceUnitTooltip(tooltip, unit)
    local settings = addon.settings.tooltips
    if not settings.enabled then return end
    
    -- Hide in combat if enabled
    if settings.hideInCombat and UnitAffectingCombat("player") then
        if not settings.showWithShift or not IsShiftKeyDown() then
            tooltip:Hide()
            return
        end
    end
    
    local name, realm = UnitName(unit)
    local isPlayer = UnitIsPlayer(unit)
    local level = UnitLevel(unit)
    local reaction = UnitReaction(unit, "player")
    
    -- Show NPC ID for non-players
    if not isPlayer then
        AddNpcId(tooltip, unit)
    end
    
    -- Show target if enabled
    if settings.showTarget then
        local target = unit .. "target"
        if UnitExists(target) then
            local targetName = UnitName(target)
            local targetReaction = UnitReaction(target, "player")
            
            local targetColor = "|cffffffff"
            if UnitIsUnit(target, "player") then
                targetColor = "|cffff0000"
                targetName = ">> YOU <<"
            elseif targetReaction then
                if targetReaction >= 5 then
                    targetColor = "|cff00ff00"  -- Friendly
                elseif targetReaction <= 2 then
                    targetColor = "|cffff0000"  -- Hostile
                else
                    targetColor = "|cffffff00"  -- Neutral
                end
            end
            
            tooltip:AddLine(" ")
            tooltip:AddDoubleLine("Target:", targetColor .. (targetName or "Unknown") .. "|r", 0.5, 0.5, 0.5)
        end
    end
    
    -- Show guild rank for players
    if isPlayer and settings.showGuildRank then
        local guildName, guildRank = GetGuildInfo(unit)
        if guildName and guildRank then
            local isMyGuild = UnitIsInMyGuild(unit)
            if isMyGuild or settings.showGuildRank then
                -- Guild rank is already shown by default tooltip, 
                -- but we ensure it's colored appropriately
            end
        end
    end
    
    tooltip:Show()
end

-- ============================================================
-- Item Tooltip Hooks
-- ============================================================
local function HookItemTooltips()
    -- Hook SetBagItem
    local origSetBagItem = GameTooltip.SetBagItem
    GameTooltip.SetBagItem = function(self, bag, slot, ...)
        local result = origSetBagItem(self, bag, slot, ...)
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
            AddItemId(self, itemLink)
            AddItemLevel(self, itemLink)
            AddUpgradeInfo(self, bag, slot, itemLink)
            self:Show()
        end
        return result
    end
    
    -- Hook SetInventoryItem (equipped items)
    local origSetInventoryItem = GameTooltip.SetInventoryItem
    GameTooltip.SetInventoryItem = function(self, unit, slot, ...)
        local result = origSetInventoryItem(self, unit, slot, ...)
        local itemLink = GetInventoryItemLink(unit, slot)
        if itemLink then
            AddItemId(self, itemLink)
            AddItemLevel(self, itemLink)
            -- For equipped items, use special bag ID (equipment slots)
            if unit == "player" then
                AddUpgradeInfo(self, -2, slot, itemLink)  -- -2 = equipment
            end
            self:Show()
        end
        return result
    end
    
    -- Hook SetHyperlink
    local origSetHyperlink = GameTooltip.SetHyperlink
    GameTooltip.SetHyperlink = function(self, link, ...)
        local result = origSetHyperlink(self, link, ...)
        if link and link:find("item:") then
            AddItemId(self, link)
            AddItemLevel(self, link)
            self:Show()
        elseif link and link:find("spell:") then
            local spellId = link:match("spell:(%d+)")
            AddSpellId(self, spellId)
            self:Show()
        end
        return result
    end
    
    -- Hook SetMerchantItem
    local origSetMerchantItem = GameTooltip.SetMerchantItem
    GameTooltip.SetMerchantItem = function(self, slot, ...)
        local result = origSetMerchantItem(self, slot, ...)
        local itemLink = GetMerchantItemLink(slot)
        if itemLink then
            AddItemId(self, itemLink)
            AddItemLevel(self, itemLink)
            self:Show()
        end
        return result
    end
    
    -- Hook SetLootItem
    local origSetLootItem = GameTooltip.SetLootItem
    GameTooltip.SetLootItem = function(self, slot, ...)
        local result = origSetLootItem(self, slot, ...)
        local itemLink = GetLootSlotLink(slot)
        if itemLink then
            AddItemId(self, itemLink)
            AddItemLevel(self, itemLink)
            self:Show()
        end
        return result
    end
    
    -- Hook SetQuestItem
    local origSetQuestItem = GameTooltip.SetQuestItem
    GameTooltip.SetQuestItem = function(self, questType, slot, ...)
        local result = origSetQuestItem(self, questType, slot, ...)
        local itemLink = GetQuestItemLink(questType, slot)
        if itemLink then
            AddItemId(self, itemLink)
            AddItemLevel(self, itemLink)
            self:Show()
        end
        return result
    end
    
    -- Hook SetQuestLogItem
    local origSetQuestLogItem = GameTooltip.SetQuestLogItem
    GameTooltip.SetQuestLogItem = function(self, questType, slot, ...)
        local result = origSetQuestLogItem(self, questType, slot, ...)
        local itemLink = GetQuestLogItemLink(questType, slot)
        if itemLink then
            AddItemId(self, itemLink)
            AddItemLevel(self, itemLink)
            self:Show()
        end
        return result
    end
    
    -- Hook SetAuctionItem
    local origSetAuctionItem = GameTooltip.SetAuctionItem
    GameTooltip.SetAuctionItem = function(self, auctionType, index, ...)
        local result = origSetAuctionItem(self, auctionType, index, ...)
        local itemLink = GetAuctionItemLink(auctionType, index)
        if itemLink then
            AddItemId(self, itemLink)
            AddItemLevel(self, itemLink)
            self:Show()
        end
        return result
    end
    
    -- Hook SetCraftItem
    local origSetCraftItem = GameTooltip.SetCraftItem
    GameTooltip.SetCraftItem = function(self, skill, slot, ...)
        local result = origSetCraftItem(self, skill, slot, ...)
        local itemLink = GetCraftItemLink(slot)
        if itemLink then
            AddItemId(self, itemLink)
            AddItemLevel(self, itemLink)
            self:Show()
        end
        return result
    end
    
    -- Hook SetTradeSkillItem
    local origSetTradeSkillItem = GameTooltip.SetTradeSkillItem
    GameTooltip.SetTradeSkillItem = function(self, skill, slot, ...)
        local result = origSetTradeSkillItem(self, skill, slot, ...)
        local itemLink
        if slot then
            itemLink = GetTradeSkillReagentItemLink(skill, slot)
        else
            itemLink = GetTradeSkillItemLink(skill)
        end
        if itemLink then
            AddItemId(self, itemLink)
            AddItemLevel(self, itemLink)
            self:Show()
        end
        return result
    end
    
    addon:Debug("Item tooltip hooks installed")
end

-- ============================================================
-- Unit Tooltip Hooks
-- ============================================================
local function HookUnitTooltips()
    -- Hook OnTooltipSetUnit
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        local _, unit = self:GetUnit()
        
        -- Fallback: mouseover when GetUnit returns nil
        if not unit or not UnitExists(unit) then
            if UnitExists("mouseover") then
                unit = "mouseover"
            end
        end
        
        -- Fallback: mouse focus attribute
        if not unit or not UnitExists(unit) then
            local focus = GetMouseFocus and GetMouseFocus()
            if focus and focus.GetAttribute then
                local u = focus:GetAttribute("unit")
                if u and UnitExists(u) then
                    unit = u
                end
            end
        end
        
        if unit then
            EnhanceUnitTooltip(self, unit)
        end
    end)
    
    -- Reset NPC GUID flag and upgrade flag when tooltip is cleared
    GameTooltip:HookScript("OnTooltipCleared", function(self)
        self._dcqosNpcGuid = nil
        self._dcqosUpgradeShown = nil
    end)
    
    addon:Debug("Unit tooltip hooks installed")
end

-- ============================================================
-- Spell Tooltip Hooks
-- ============================================================
local function HookSpellTooltips()
    -- Hook SetSpell (action bar)
    local origSetSpell = GameTooltip.SetSpell
    if origSetSpell then
        GameTooltip.SetSpell = function(self, spellBook, spellBookType, ...)
            local result = origSetSpell(self, spellBook, spellBookType, ...)
            local _, _, _, _, _, _, spellId = GetSpellInfo(spellBook, spellBookType)
            AddSpellId(self, spellId)
            self:Show()
            return result
        end
    end
    
    -- Hook SetUnitBuff
    local origSetUnitBuff = GameTooltip.SetUnitBuff
    if origSetUnitBuff then
        GameTooltip.SetUnitBuff = function(self, unit, index, filter, ...)
            local result = origSetUnitBuff(self, unit, index, filter, ...)
            local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index, filter)
            if spellId then
                AddSpellId(self, spellId)
                self:Show()
            end
            return result
        end
    end
    
    -- Hook SetUnitDebuff
    local origSetUnitDebuff = GameTooltip.SetUnitDebuff
    if origSetUnitDebuff then
        GameTooltip.SetUnitDebuff = function(self, unit, index, filter, ...)
            local result = origSetUnitDebuff(self, unit, index, filter, ...)
            local name, _, _, _, _, _, _, _, _, _, spellId = UnitDebuff(unit, index, filter)
            if spellId then
                AddSpellId(self, spellId)
                self:Show()
            end
            return result
        end
    end
    
    addon:Debug("Spell tooltip hooks installed")
end

-- ============================================================
-- Health Bar Hiding
-- ============================================================
local function SetupHealthBarHiding()
    if addon.settings.tooltips.hideHealthBar then
        local tipHide = GameTooltip.Hide
        GameTooltipStatusBar:HookScript("OnShow", function()
            GameTooltipStatusBar:Hide()
        end)
        GameTooltipStatusBar:Hide()
    end
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function Tooltips.OnInitialize()
    addon:Debug("Tooltips module initializing")
    
    -- Create drag frame for positioning
    CreateTipDragFrame()
    
    -- Set initial scale
    SetTooltipScale()
end

function Tooltips.OnEnable()
    addon:Debug("Tooltips module enabling")
    
    -- Setup tooltip anchor positioning
    SetTooltipAnchor()
    
    -- Hook item tooltips
    HookItemTooltips()
    
    -- Hook unit tooltips
    HookUnitTooltips()
    
    -- Hook spell tooltips
    HookSpellTooltips()
    
    -- Setup health bar hiding
    SetupHealthBarHiding()
    
    -- Listen for scale changes
    addon:RegisterEvent("SETTING_CHANGED", function(path, value)
        if path == "tooltips.scale" then
            SetTooltipScale()
        end
    end)
end

function Tooltips.OnDisable()
    addon:Debug("Tooltips module disabling")
    -- Note: Hooks cannot be removed, but we check enabled state in each hook
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================

-- Helper function to add tooltip explanation to a checkbox
local function AddSettingTooltip(checkbox, title, description)
    checkbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        GameTooltip:AddLine(description, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Tooltips.CreateSettings(parent)
    local settings = addon.settings.tooltips
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Tooltip Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure tooltip enhancements including item IDs, NPC IDs, upgrade info, and positioning.")
    desc:SetWidth(parent:GetWidth() - 32)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- ID Display Section
    -- ============================================================
    local idHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    idHeader:SetPoint("TOPLEFT", 16, yOffset)
    idHeader:SetText("ID Display")
    yOffset = yOffset - 25
    
    -- Show Item ID
    local itemIdCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    itemIdCb:SetPoint("TOPLEFT", 16, yOffset)
    itemIdCb.Text:SetText("Show Item ID")
    itemIdCb:SetChecked(settings.showItemId)
    itemIdCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showItemId", self:GetChecked())
    end)
    AddSettingTooltip(itemIdCb, "Show Item ID", 
        "Displays the item's database ID in tooltips. Useful for database lookups, bug reports, and item identification. Item IDs are unique identifiers used by the game engine.")
    yOffset = yOffset - 25
    
    -- Show Item Level
    local itemLevelCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    itemLevelCb:SetPoint("TOPLEFT", 16, yOffset)
    itemLevelCb.Text:SetText("Show Item Level")
    itemLevelCb:SetChecked(settings.showItemLevel)
    itemLevelCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showItemLevel", self:GetChecked())
    end)
    AddSettingTooltip(itemLevelCb, "Show Item Level",
        "Shows the item level (ilvl) in tooltips. Item level indicates the power level of gear and is used to calculate stats. Higher ilvl generally means better stats.")
    yOffset = yOffset - 25
    
    -- Show Upgrade Info
    local upgradeInfoCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    upgradeInfoCb:SetPoint("TOPLEFT", 16, yOffset)
    upgradeInfoCb.Text:SetText("Show Upgrade Info")
    upgradeInfoCb:SetChecked(settings.showUpgradeInfo ~= false)
    upgradeInfoCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showUpgradeInfo", self:GetChecked())
    end)
    AddSettingTooltip(upgradeInfoCb, "Show Upgrade Info",
        "Displays upgrade tier and level information for items. Shows current upgrade progress (e.g. 'Level 5/15 Tier 2'), stat bonuses from upgrades (+X% All Stats), and modified item level. Requires server communication.")
    yOffset = yOffset - 25
    
    -- Show NPC ID
    local npcIdCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    npcIdCb:SetPoint("TOPLEFT", 16, yOffset)
    npcIdCb.Text:SetText("Show NPC ID")
    npcIdCb:SetChecked(settings.showNpcId)
    npcIdCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showNpcId", self:GetChecked())
    end)
    AddSettingTooltip(npcIdCb, "Show NPC ID",
        "Shows the Entry ID and Database GUID for NPCs in tooltips. Entry ID identifies the NPC type, while DB GUID identifies the specific spawn. Essential for reporting bugs or referencing specific creatures.")
    yOffset = yOffset - 25
    
    -- Show Spell ID
    local spellIdCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    spellIdCb:SetPoint("TOPLEFT", 16, yOffset)
    spellIdCb.Text:SetText("Show Spell ID")
    spellIdCb:SetChecked(settings.showSpellId)
    spellIdCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showSpellId", self:GetChecked())
    end)
    AddSettingTooltip(spellIdCb, "Show Spell ID",
        "Displays the spell's database ID in tooltips. Useful for macro creation, WeakAuras, and identifying custom server spells. Shown for abilities, buffs, debuffs, and item enchants.")
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Unit Tooltip Section
    -- ============================================================
    local unitHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    unitHeader:SetPoint("TOPLEFT", 16, yOffset)
    unitHeader:SetText("Unit Tooltips")
    yOffset = yOffset - 25
    
    -- Show Guild Rank
    local guildRankCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    guildRankCb:SetPoint("TOPLEFT", 16, yOffset)
    guildRankCb.Text:SetText("Show Guild Ranks")
    guildRankCb:SetChecked(settings.showGuildRank)
    guildRankCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showGuildRank", self:GetChecked())
    end)
    AddSettingTooltip(guildRankCb, "Show Guild Ranks",
        "Displays the guild rank of players in their tooltips. Shows the player's position in their guild hierarchy. Useful for identifying guild officers and members.")
    yOffset = yOffset - 25
    
    -- Show Target
    local targetCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    targetCb:SetPoint("TOPLEFT", 16, yOffset)
    targetCb.Text:SetText("Show Unit Target")
    targetCb:SetChecked(settings.showTarget)
    targetCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showTarget", self:GetChecked())
    end)
    AddSettingTooltip(targetCb, "Show Unit Target",
        "Shows who or what the moused-over unit is currently targeting. Color-coded: Green for friendly targets, Red for hostile targets, Yellow for neutral. Displays '>> YOU <<' in red if the unit is targeting you.")
    yOffset = yOffset - 25
    
    -- Hide Health Bar
    local healthBarCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    healthBarCb:SetPoint("TOPLEFT", 16, yOffset)
    healthBarCb.Text:SetText("Hide Health Bar")
    healthBarCb:SetChecked(settings.hideHealthBar)
    healthBarCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.hideHealthBar", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    AddSettingTooltip(healthBarCb, "Hide Health Bar",
        "Removes the health bar from unit tooltips for a cleaner look. The health percentage will still be shown as text. Requires a UI reload (/reload) to take effect.")
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Combat Section
    -- ============================================================
    local combatHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    combatHeader:SetPoint("TOPLEFT", 16, yOffset)
    combatHeader:SetText("Combat Behavior")
    yOffset = yOffset - 25
    
    -- Hide in Combat
    local hideCombatCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    hideCombatCb:SetPoint("TOPLEFT", 16, yOffset)
    hideCombatCb.Text:SetText("Hide Tooltips in Combat")
    hideCombatCb:SetChecked(settings.hideInCombat)
    hideCombatCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.hideInCombat", self:GetChecked())
    end)
    AddSettingTooltip(hideCombatCb, "Hide Tooltips in Combat",
        "Automatically hides unit tooltips while you are in combat. Reduces screen clutter during fights and can improve performance. Use with 'Show with Shift' to override when needed.")
    yOffset = yOffset - 25
    
    -- Show with Shift
    local shiftCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    shiftCb:SetPoint("TOPLEFT", 36, yOffset)
    shiftCb.Text:SetText("Show with Shift key in combat")
    shiftCb:SetChecked(settings.showWithShift)
    shiftCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showWithShift", self:GetChecked())
    end)
    AddSettingTooltip(shiftCb, "Show with Shift in Combat",
        "When 'Hide in Combat' is enabled, holding Shift will temporarily show tooltips. This allows you to check enemy info during fights when you need it.")
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Scale Slider
    -- ============================================================
    local scaleHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleHeader:SetPoint("TOPLEFT", 16, yOffset)
    scaleHeader:SetText("Tooltip Scale")
    yOffset = yOffset - 25
    
    local scaleSlider = CreateFrame("Slider", "DCQoSTooltipScaleSlider", parent, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 20, yOffset)
    scaleSlider:SetWidth(200)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetValue(settings.scale or 1.0)
    scaleSlider.Low:SetText("50%")
    scaleSlider.High:SetText("200%")
    scaleSlider.Text:SetText(string.format("%.0f%%", (settings.scale or 1.0) * 100))
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        self.Text:SetText(string.format("%.0f%%", value * 100))
        addon:SetSetting("tooltips.scale", value)
    end)
    scaleSlider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Tooltip Scale", 1, 0.82, 0)
        GameTooltip:AddLine("Adjusts the size of all tooltips. 100% is the default size. Increase for larger, easier to read tooltips, or decrease to reduce screen clutter.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    scaleSlider:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Tooltips", Tooltips)
