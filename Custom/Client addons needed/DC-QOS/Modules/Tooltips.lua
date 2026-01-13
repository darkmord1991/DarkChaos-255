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

-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\AddOns\\DC-QOS\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyle then return end
    frame.__dcLeaderboardsStyle = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    frame.__dcBg = bg
    frame.__dcTint = tint
end

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

-- Tooltip update throttle to prevent lag spikes
local lastTooltipUpdate = 0
local TOOLTIP_UPDATE_THROTTLE = 0.05  -- 50ms between updates
local itemInfoCache = {}  -- Cache GetItemInfo results
local ITEM_INFO_CACHE_DURATION = 60  -- 1 minute

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

-- Cached GetItemInfo to reduce API calls
local function GetCachedItemInfo(itemLink)
    if not itemLink then return nil end
    
    local cached = itemInfoCache[itemLink]
    if cached and (GetTime() - cached.time) < ITEM_INFO_CACHE_DURATION then
        return cached.name, cached.link, cached.quality, cached.level, cached.minLevel, 
               cached.type, cached.subType, cached.stackCount, cached.equipLoc
    end
    
    local name, link, quality, level, minLevel, itemType, subType, stackCount, equipLoc = GetItemInfo(itemLink)
    if name then
        itemInfoCache[itemLink] = {
            time = GetTime(),
            name = name,
            link = link,
            quality = quality,
            level = level,
            minLevel = minLevel,
            type = itemType,
            subType = subType,
            stackCount = stackCount,
            equipLoc = equipLoc
        }
    end
    
    return name, link, quality, level, minLevel, itemType, subType, stackCount, equipLoc
end

-- Request upgrade info from server (throttled)
local lastUpgradeRequest = 0
local UPGRADE_REQUEST_THROTTLE = 0.1  -- 100ms between requests

local function RequestUpgradeInfo(bag, slot, itemLink)
    if not addon.protocol or not addon.protocol.connected then
        return
    end
    
    -- Throttle requests
    local now = GetTime()
    if (now - lastUpgradeRequest) < UPGRADE_REQUEST_THROTTLE then
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
    if cached and (now - cached.timestamp) < UPGRADE_CACHE_DURATION then
        return
    end
    
    pendingUpgradeRequests[locationKey] = true
    lastUpgradeRequest = now
    
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
    
    -- Don't force refresh to avoid lag cascade
    -- Data will appear on next natural tooltip update
end

-- Register for upgrade info events
addon:RegisterEvent("ITEM_UPGRADE_INFO_RECEIVED", OnUpgradeInfoReceived)

-- Add upgrade/tier info to tooltip
local function AddUpgradeInfo(tooltip, bag, slot, itemLink)
    if not addon.settings.tooltips.showUpgradeInfo then return end
    if not itemLink then return end
    
    -- Skip if DC-ItemUpgrade is handling this tooltip
    if tooltip.__dcUpgradeProcessing or tooltip._dcItemUpgradeShown then
        return
    end
    
    -- Skip if DarkChaos_ItemUpgrade addon is loaded (it has its own tooltip handling)
    if DarkChaos_ItemUpgradeFrame then
        return
    end
    
    -- Only show for armor/weapons (use cached GetItemInfo)
    local _, _, quality, _, _, itemType, _, _, equipLoc = GetCachedItemInfo(itemLink)
    if not itemType then return end  -- Item not loaded yet
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
    TipDrag:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ApplyLeaderboardsStyle(TipDrag)
    
    -- Title text
    TipDrag.text = TipDrag:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    TipDrag.text:SetPoint("CENTER", 0, 0)
    TipDrag.text:SetText("Tooltip")
    
    -- Background handled by ApplyLeaderboardsStyle
    
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
    
    local origGameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
    GameTooltip_SetDefaultAnchor = function(tooltip, parent)
        local anchor = settings.anchor or 1
        
        if anchor == 1 then
            -- Default positioning
            origGameTooltip_SetDefaultAnchor(tooltip, parent)
        elseif anchor == 2 then
            -- Fixed overlay position
            origGameTooltip_SetDefaultAnchor(tooltip, parent) -- Set owner/default first
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 
                settings.cursorOffsetX or -13, 
                settings.cursorOffsetY or 94)
        elseif anchor == 3 then
            -- Cursor attached
            tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        elseif anchor == 4 then
            -- Cursor right with offset (Use ANCHOR_CURSOR with offsets)
            tooltip:SetOwner(parent, "ANCHOR_CURSOR", 
                settings.cursorOffsetX or 0, 
                settings.cursorOffsetY or 0)
        end
    end
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

    -- If the tooltip already shows item level (client or another addon), don't add a duplicate.
    local tipName = tooltip and tooltip.GetName and tooltip:GetName()
    if tipName and tooltip.NumLines then
        for i = 1, tooltip:NumLines() do
            local left = _G[tipName .. "TextLeft" .. i]
            if left and left.GetText then
                local text = left:GetText()
                if text then
                    -- Keep this intentionally simple: WotLK strings are typically "Item Level".
                    if string.find(text, "Item Level", 1, true) then
                        return
                    end
                end
            end
        end
    end
    
    local _, _, _, itemLevel = GetCachedItemInfo(itemLink)
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

    -- Prevent duplicates when multiple hooks fire for the same tooltip.
    local sid = tonumber(spellId)
    if not sid then return end
    if tooltip._dcqosSpellIdShown == sid then
        return
    end
    tooltip._dcqosSpellIdShown = sid
    
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("Spell ID:", "|cffffffff" .. sid .. "|r", 0.5, 0.5, 0.5)
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
    
    -- Don't force refresh to avoid lag
    -- Data will appear on next natural tooltip update
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
    
    -- Show Spawn (from server or parsed)
    if dbGuid then
        tooltip:AddDoubleLine("Spawn:", "|cffffffff" .. dbGuid .. "|r", 0.5, 0.5, 0.5)
    elseif cachedInfo == nil then
        tooltip:AddDoubleLine("Spawn:", "|cff888888Fetching...|r", 0.5, 0.5, 0.5)
    elseif localSpawnId then
        tooltip:AddDoubleLine("Spawn:", "|cffffff88~" .. localSpawnId .. "|r", 0.5, 0.5, 0.5)
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
        self._dcqosSpellIdShown = nil
    end)
    
    addon:Debug("Unit tooltip hooks installed")
end

-- ============================================================
-- Spell Tooltip Hooks
-- ============================================================
local function HookSpellTooltips()
    -- Most spell tooltips (action buttons, racials, etc.) fire this script.
    -- This is the most reliable way to capture spell IDs in 3.3.5a.
    if not GameTooltip._dcqosHookedOnTooltipSetSpell then
        GameTooltip._dcqosHookedOnTooltipSetSpell = true
        GameTooltip:HookScript("OnTooltipSetSpell", function(self)
            local name, rank, spellId = self:GetSpell()
            if not spellId and name then
                -- WotLK fallback: resolve by name.
                spellId = select(7, GetSpellInfo(name))
            end
            AddSpellId(self, spellId)
            self:Show()
        end)
    end

    -- Hook SetSpell (action bar)
    local origSetSpell = GameTooltip.SetSpell
    if origSetSpell then
        GameTooltip.SetSpell = function(self, spellBook, spellBookType, ...)
            local result = origSetSpell(self, spellBook, spellBookType, ...)
            -- In 3.3.5a, spellBook/spellBookType are spellbook indices, not GetSpellInfo args.
            local spellName
            if GetSpellBookItemName then
                spellName = GetSpellBookItemName(spellBook, spellBookType)
            end
            local spellId
            if spellName then
                spellId = select(7, GetSpellInfo(spellName))
            end
            if not spellId then
                local name, _, id = self:GetSpell()
                spellId = id or (name and select(7, GetSpellInfo(name)))
            end
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
            -- WotLK UnitBuff doesn't reliably return spellId; resolve via tooltip spell.
            local name, _, spellId = self:GetSpell()
            if not spellId and name then
                spellId = select(7, GetSpellInfo(name))
            end
            AddSpellId(self, spellId)
            self:Show()
            return result
        end
    end
    
    -- Hook SetUnitDebuff
    local origSetUnitDebuff = GameTooltip.SetUnitDebuff
    if origSetUnitDebuff then
        GameTooltip.SetUnitDebuff = function(self, unit, index, filter, ...)
            local result = origSetUnitDebuff(self, unit, index, filter, ...)
            -- WotLK UnitDebuff doesn't reliably return spellId; resolve via tooltip spell.
            local name, _, spellId = self:GetSpell()
            if not spellId and name then
                spellId = select(7, GetSpellInfo(name))
            end
            AddSpellId(self, spellId)
            self:Show()
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
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
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
    local itemIdCb = addon:CreateCheckbox(parent)
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
    local itemLevelCb = addon:CreateCheckbox(parent)
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
    local upgradeInfoCb = addon:CreateCheckbox(parent)
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
    local npcIdCb = addon:CreateCheckbox(parent)
    npcIdCb:SetPoint("TOPLEFT", 16, yOffset)
    npcIdCb.Text:SetText("Show NPC ID")
    npcIdCb:SetChecked(settings.showNpcId)
    npcIdCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showNpcId", self:GetChecked())
    end)
    AddSettingTooltip(npcIdCb, "Show NPC ID",
        "Shows the Entry ID and Spawn for NPCs in tooltips. Entry ID identifies the NPC type, while Spawn identifies the specific creature spawn. Useful for reporting bugs or referencing specific creatures.")
    yOffset = yOffset - 25
    
    -- Show Spell ID
    local spellIdCb = addon:CreateCheckbox(parent)
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
    local guildRankCb = addon:CreateCheckbox(parent)
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
    local targetCb = addon:CreateCheckbox(parent)
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
    local healthBarCb = addon:CreateCheckbox(parent)
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
    local hideCombatCb = addon:CreateCheckbox(parent)
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
    local shiftCb = addon:CreateCheckbox(parent)
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
    
    local scaleSlider = addon:CreateSlider(parent, "DCQoSTooltipScaleSlider")
    scaleSlider:SetPoint("TOPLEFT", 20, yOffset)
    scaleSlider:SetWidth(200)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.05)
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
