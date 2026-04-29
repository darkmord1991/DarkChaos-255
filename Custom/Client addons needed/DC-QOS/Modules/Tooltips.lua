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

-- Use shared CLASS_COLORS from Core.lua (addon.CLASS_COLORS)
local RaidColors = addon.CLASS_COLORS

-- Localized class names
local ClassNamesMale = LOCALIZED_CLASS_NAMES_MALE
local ClassNamesFemale = LOCALIZED_CLASS_NAMES_FEMALE

-- Level string for parsing
local LevelString = string.lower(TOOLTIP_UNIT_LEVEL:gsub("%%s", ".+"))

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
    if addon._dcqosTooltipAnchorHooked then
        return
    end

    if type(GameTooltip_SetDefaultAnchor) ~= "function" then
        return
    end

    addon._dcqosTooltipAnchorHooked = true
    
    local origGameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
    GameTooltip_SetDefaultAnchor = function(tooltip, parent)
        local settings = addon.settings and addon.settings.tooltips or {}
        if settings.enabled == false then
            return origGameTooltip_SetDefaultAnchor(tooltip, parent)
        end

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

local SPELL_TOOLTIP_CONTEXT_SEED = 2166136261
local SPELL_TOOLTIP_CONTEXT_PRIME = 16777619
local SPELL_TOOLTIP_HASH_MOD = 4294967296
local SPELL_TOOLTIP_ENRICHMENT_OK_TTL = 20
local SPELL_TOOLTIP_ENRICHMENT_ERR_TTL = 6
local SPELL_TOOLTIP_ENRICHMENT_PENDING_TTL = 4.0
local SPELL_TOOLTIP_ENRICHMENT_MIN_SEND_INTERVAL = 0.35
local SPELL_TOOLTIP_TRACKING_PRUNE_INTERVAL = 20
local SPELL_TOOLTIP_TRACKING_STALE_TTL = 120

local spellEnrichmentRequestCounter = 0
local pendingSpellEnrichment = {}
local lastSpellEnrichmentAttemptAt = {}
local lastSpellEnrichmentSendAt = 0
local lastSpellEnrichmentPruneAt = 0

local function BuildSpellEnrichmentKey(spellId, contextHash)
    return tostring(tonumber(spellId) or 0) .. ":" .. tostring(tonumber(contextHash) or 0)
end

local function MixSpellTooltipContext(hash, value)
    hash = (hash + (tonumber(value) or 0)) % SPELL_TOOLTIP_HASH_MOD
    -- Lua 5.1 doubles can only represent integers exactly up to 2^53.
    -- hash (up to 2^32-1) * prime (~2^24) can exceed 2^53 and lose precision,
    -- so use 16-bit halves to keep intermediates exact.
    local lo = hash % 65536
    local hi = math.floor(hash / 65536)
    hash = (((hi * SPELL_TOOLTIP_CONTEXT_PRIME) % 65536) * 65536
            + lo * SPELL_TOOLTIP_CONTEXT_PRIME) % SPELL_TOOLTIP_HASH_MOD
    return hash
end

local function BuildSpellTooltipContextHash(spellId)
    local hash = SPELL_TOOLTIP_CONTEXT_SEED
    local _, _, classId = UnitClass("player")

    hash = MixSpellTooltipContext(hash, spellId)
    hash = MixSpellTooltipContext(hash, UnitLevel("player") or 0)
    hash = MixSpellTooltipContext(hash, classId or 0)
    hash = MixSpellTooltipContext(hash, (GetShapeshiftForm and GetShapeshiftForm()) or 0)
    hash = MixSpellTooltipContext(hash, (GetActiveTalentGroup and GetActiveTalentGroup()) or 0)

    if hash == 0 then
        hash = 1
    end

    return hash
end

local function NextSpellEnrichmentRequestId()
    spellEnrichmentRequestCounter = spellEnrichmentRequestCounter + 1
    if spellEnrichmentRequestCounter > 2147483000 then
        spellEnrichmentRequestCounter = 1
    end
    return spellEnrichmentRequestCounter
end

local function NormalizeTooltipTextValue(text)
    local value = tostring(text or "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("|T.-|t", "")
    value = value:gsub("%s+", " ")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return string.lower(value)
end

local function BuildExistingTooltipTextSet(tooltip)
    local existing = {}
    if not tooltip or type(tooltip.GetName) ~= "function" or type(tooltip.NumLines) ~= "function" then
        return existing
    end

    local tipName = tooltip:GetName()
    if not tipName or tipName == "" then
        return existing
    end

    for i = 1, tooltip:NumLines() do
        local leftLine = _G[tipName .. "TextLeft" .. i]
        local rightLine = _G[tipName .. "TextRight" .. i]
        local left = leftLine and leftLine.GetText and leftLine:GetText() or ""
        local right = rightLine and rightLine.GetText and rightLine:GetText() or ""

        local leftNorm = NormalizeTooltipTextValue(left)
        local rightNorm = NormalizeTooltipTextValue(right)
        if leftNorm ~= "" then
            existing[leftNorm] = true
        end
        if rightNorm ~= "" then
            existing[rightNorm] = true
        end
        if leftNorm ~= "" or rightNorm ~= "" then
            existing[leftNorm .. "||" .. rightNorm] = true
        end
    end

    return existing
end

local function IsRawServerMetadataLine(text)
    local norm = NormalizeTooltipTextValue(text)
    if norm == "" then return false end
    if norm:find("^server%-v%d") then return true end
    if norm:find("ctx=") and norm:find("spell=") then return true end
    return false
end

local function GetSpellTooltipRenderMode(tooltip)
    local source = tooltip and tooltip._dcqosSpellSource or nil
    if source == "action" then
        return "full"
    end
    if source == "spellbook" then
        return "replace-native-description"
    end
    return "disabled"
end

local function StripNativeSpellDescriptionLines(tooltip)
    if not tooltip or type(tooltip.GetName) ~= "function" or type(tooltip.NumLines) ~= "function" then
        return
    end

    local tipName = tooltip:GetName()
    if not tipName or tipName == "" then
        return
    end

    for i = 1, tooltip:NumLines() do
        local leftLine = _G[tipName .. "TextLeft" .. i]
        local rightLine = _G[tipName .. "TextRight" .. i]
        local leftText = leftLine and leftLine.GetText and leftLine:GetText() or nil
        local rightText = rightLine and rightLine.GetText and rightLine:GetText() or nil

        -- Native spell body lines are typically yellow and left-only. Remove
        -- those so server body text replaces (instead of appends to) native.
        if leftLine and leftText and leftText ~= "" and (not rightText or rightText == "")
            and leftLine.GetTextColor then
            local r, g, b = leftLine:GetTextColor()
            if (r or 0) > 0.88 and (g or 0) > 0.70 and (b or 1) < 0.35 then
                leftLine:SetText("")
            end
        end
    end
end

local function PruneSpellEnrichmentTracking(now)
    now = tonumber(now) or 0
    if now <= 0 then return end
    if lastSpellEnrichmentPruneAt > 0
        and (now - lastSpellEnrichmentPruneAt) < SPELL_TOOLTIP_TRACKING_PRUNE_INTERVAL then
        return
    end

    for key, pending in pairs(pendingSpellEnrichment) do
        local sentAt = pending and tonumber(pending.sentAt) or 0
        if sentAt <= 0 or (now - sentAt) > SPELL_TOOLTIP_TRACKING_STALE_TTL then
            pendingSpellEnrichment[key] = nil
        end
    end

    for key, attemptAt in pairs(lastSpellEnrichmentAttemptAt) do
        if (tonumber(attemptAt) or 0) <= 0 or (now - attemptAt) > SPELL_TOOLTIP_TRACKING_STALE_TTL then
            lastSpellEnrichmentAttemptAt[key] = nil
        end
    end

    lastSpellEnrichmentPruneAt = now
end

local function RenderSpellEnrichmentLines(tooltip, enrichment, renderMode)
    if not tooltip or type(enrichment) ~= "table" or type(tooltip.AddLine) ~= "function" then
        return false
    end

    local lines = enrichment.lines
    if type(lines) ~= "table" or #lines == 0 then
        return false
    end

    local existing = BuildExistingTooltipTextSet(tooltip)
    local addedAny = false

    for _, rawEntry in ipairs(lines) do
        local entry = rawEntry
        if type(entry) ~= "table" then
            entry = { left = tostring(rawEntry or "") }
        end

        local left = tostring(entry.left or "")
        local right = entry.right ~= nil and tostring(entry.right) or nil
        local kind = entry.kind

        if not (renderMode == "replace-native-description" and kind ~= "body")
            and not IsRawServerMetadataLine(left)
            and not IsRawServerMetadataLine(right or "") then
            local leftNorm = NormalizeTooltipTextValue(left)
            local rightNorm = NormalizeTooltipTextValue(right or "")
            local key = leftNorm .. "||" .. rightNorm

            if leftNorm ~= "" and not existing[key] and not existing[leftNorm] then
                if not addedAny then
                    tooltip:AddLine(" ")
                end

                if right and right ~= "" and type(tooltip.AddDoubleLine) == "function" then
                    tooltip:AddDoubleLine(left, right, 1.0, 1.0, 1.0)
                else
                    if kind == "body" then
                        tooltip:AddLine(left, 1.0, 0.82, 0.0, true)
                    elseif kind == "meta" then
                        tooltip:AddLine(left, 0.75, 0.75, 0.75, true)
                    else
                        tooltip:AddLine(left, 1.0, 1.0, 1.0, true)
                    end
                end

                addedAny = true
                existing[key] = true
                existing[leftNorm] = true
                if rightNorm ~= "" then
                    existing[rightNorm] = true
                end
            end
        end
    end

    return addedAny
end

-- Returns:
--   true  = enrichment rendered synchronously from cache (or already shown)
--   false = enrichment unavailable (not connected, disabled, rate-limited after error)
--   nil   = request just sent or already in-flight; callback will deliver lines
local function AddSpellTooltipEnrichment(tooltip, spellId)
    if not tooltip or not spellId then return false end
    if not addon.settings or not addon.settings.tooltips or not addon.settings.tooltips.enabled then return false end
    if not addon.settings.communication or not addon.settings.communication.enabled then return false end
    if not addon.protocol or not addon.protocol.connected then return false end

    local sid = tonumber(spellId)
    if not sid or sid <= 0 then return false end

    local contextHash = BuildSpellTooltipContextHash(sid)
    local key = BuildSpellEnrichmentKey(sid, contextHash)
    local now = GetTime()
    local renderMode = GetSpellTooltipRenderMode(tooltip)

    if renderMode == "disabled" then
        return false
    end

    PruneSpellEnrichmentTracking(now)

    tooltip._dcqosActiveSpellKey = key

    if tooltip._dcqosSpellEnrichmentShownKey == key then
        return true  -- already shown from a previous render this session
    end

    local cached = addon.GetSpellTooltipEnrichment and addon:GetSpellTooltipEnrichment(sid, contextHash) or nil
    local cachedAge = cached and (now - (tonumber(cached.receivedAt) or now)) or nil

    if renderMode == "replace-native-description"
        and tooltip._dcqosNativeDescriptionStrippedKey ~= key then
        StripNativeSpellDescriptionLines(tooltip)
        tooltip._dcqosNativeDescriptionStrippedKey = key
    end

    local renderedFromCache = false
    if cached and cached.status == 0 and cachedAge and cachedAge <= SPELL_TOOLTIP_ENRICHMENT_OK_TTL then
        renderedFromCache = RenderSpellEnrichmentLines(tooltip, cached, renderMode)
        if renderedFromCache then
            tooltip._dcqosSpellEnrichmentShownKey = key
            return true  -- rendered synchronously from cache
        end
    end

    -- Do not render line-only legacy payloads such as "server-v1 spell=...".
    -- Returns nil when a request is in-flight (callback will deliver lines).
    -- Returns false when unavailable so caller can show Spell ID immediately.
    if not renderedFromCache then
        local pending = pendingSpellEnrichment[key]
        if pending and (now - (pending.sentAt or 0)) > SPELL_TOOLTIP_ENRICHMENT_PENDING_TTL then
            pendingSpellEnrichment[key] = nil
            pending = nil
        end

        -- Already waiting for a server response; callback will deliver lines.
        if pending then
            return nil
        end

        -- Tooltip refreshes can fire frequently while hovering action buttons.
        -- If a previous attempt got an error, honour the backoff and show Spell ID now.
        local lastAttemptAt = tonumber(lastSpellEnrichmentAttemptAt[key])
        if lastAttemptAt and (now - lastAttemptAt) < SPELL_TOOLTIP_ENRICHMENT_ERR_TTL then
            return false
        end

        -- Global pacing guard - cannot send right now; show Spell ID immediately.
        if (now - (tonumber(lastSpellEnrichmentSendAt) or 0)) < SPELL_TOOLTIP_ENRICHMENT_MIN_SEND_INTERVAL then
            return false
        end

        local requestId = NextSpellEnrichmentRequestId()
        pendingSpellEnrichment[key] = {
            requestId = requestId,
            sentAt = now,
        }
        lastSpellEnrichmentAttemptAt[key] = now
        lastSpellEnrichmentSendAt = now

        local ok = addon:RequestSpellTooltipEnrichment(requestId, sid, contextHash, false)
        if not ok then
            pendingSpellEnrichment[key] = nil
            return false  -- request failed, no callback expected
        end
        return nil  -- request sent; callback will deliver lines and Spell ID
    end
end

local function OnSpellTooltipEnrichmentReceived(data)
    if type(data) ~= "table" then return end

    local sid = tonumber(data.spellId) or 0
    local contextHash = tonumber(data.contextHash) or 0
    if sid <= 0 or contextHash <= 0 then return end

    local key = BuildSpellEnrichmentKey(sid, contextHash)
    local pending = pendingSpellEnrichment[key]
    if pending then
        local responseReqId = tonumber(data.requestId) or 0
        if responseReqId > 0 and responseReqId ~= pending.requestId then
            return
        end
        pendingSpellEnrichment[key] = nil
    end

    -- Clear retry backoff on any response so immediate re-render stays snappy.
    lastSpellEnrichmentAttemptAt[key] = nil

    if GameTooltip and GameTooltip:IsShown() and GameTooltip._dcqosActiveSpellKey == key then
        local status = tonumber(data.status) or 0
        if status == 0 then
            GameTooltip._dcqosSpellEnrichmentShownKey = nil
            AddSpellTooltipEnrichment(GameTooltip, sid)
            -- If Spell ID was deferred for this spell (cold-cache path), add it at the bottom now.
            local pendingSid = tonumber(GameTooltip._dcqosPendingSpellIdForBottom)
            if pendingSid == sid then
                GameTooltip._dcqosPendingSpellIdForBottom = nil
                GameTooltip._dcqosSpellIdShown = nil  -- reset guard so it re-adds at the bottom
                AddSpellId(GameTooltip, sid)
            end
            GameTooltip:Show()
        else
            -- Non-success responses (e.g. no data/temporary error) should not
            -- immediately retrigger requests while the same tooltip remains open.
            GameTooltip._dcqosSpellEnrichmentShownKey = key
            -- Enrichment unavailable: show deferred Spell ID now.
            local pendingSid = tonumber(GameTooltip._dcqosPendingSpellIdForBottom)
            if pendingSid == sid then
                GameTooltip._dcqosPendingSpellIdForBottom = nil
                AddSpellId(GameTooltip, pendingSid)
            end
        end
    end
end

addon:RegisterEvent("SPELL_TOOLTIP_ENRICHMENT_RECEIVED", OnSpellTooltipEnrichmentReceived)

-- ============================================================
-- Spell Enrichment Prefetch (warms cache at login / zone-in)
-- ============================================================
local spellPrefetchFrame = nil

local function StartSpellEnrichmentPrefetch()
    if not addon.settings or not addon.settings.tooltips or not addon.settings.tooltips.enabled then return end
    if not addon.settings.communication or not addon.settings.communication.enabled then return end
    if type(GetNumSpellTabs) ~= "function" or type(GetSpellTabInfo) ~= "function"
        or type(GetSpellBookItemInfo) ~= "function" then
        return
    end

    -- Build a deduplicated list of all spellbook spell IDs.
    local seen = {}
    local queue = {}
    local tabCount = tonumber(GetNumSpellTabs()) or 0
    for tabIndex = 1, tabCount do
        local _, _, offset, numSlots = GetSpellTabInfo(tabIndex)
        offset = tonumber(offset) or 0
        numSlots = tonumber(numSlots) or 0
        for i = 1, numSlots do
            local spellType, entryId = GetSpellBookItemInfo(offset + i, BOOKTYPE_SPELL)
            if spellType == "SPELL" and entryId and entryId > 0 and not seen[entryId] then
                seen[entryId] = true
                queue[#queue + 1] = entryId
            end
        end
    end

    if #queue == 0 then return end

    if not spellPrefetchFrame then
        spellPrefetchFrame = CreateFrame("Frame")
    end

    local queueIdx = 0
    local tickElapsed = 0
    local giveUpAt = GetTime() + 180  -- abandon if never connected within 3 min

    spellPrefetchFrame:SetScript("OnUpdate", function(self, delta)
        local now = GetTime()
        if now > giveUpAt then
            self:SetScript("OnUpdate", nil)
            return
        end
        -- Wait until the server connection is established.
        if not addon.protocol or not addon.protocol.connected then return end

        tickElapsed = tickElapsed + delta
        if tickElapsed < SPELL_TOOLTIP_ENRICHMENT_MIN_SEND_INTERVAL then return end
        tickElapsed = 0

        -- Advance through the queue; skip already-fresh entries.
        while queueIdx < #queue do
            queueIdx = queueIdx + 1
            local sid = queue[queueIdx]
            local contextHash = BuildSpellTooltipContextHash(sid)
            local key = BuildSpellEnrichmentKey(sid, contextHash)
            local cached = addon.GetSpellTooltipEnrichment and addon:GetSpellTooltipEnrichment(sid, contextHash)
            local cachedAge = cached and (now - (tonumber(cached.receivedAt) or now)) or nil

            if cached and cached.status == 0 and cachedAge and cachedAge <= SPELL_TOOLTIP_ENRICHMENT_OK_TTL then
                -- Already fresh, skip.
            elseif pendingSpellEnrichment[key] then
                -- Already in-flight, skip.
            else
                -- Respect shared global pacing so tooltip hovers are not starved.
                if (now - (tonumber(lastSpellEnrichmentSendAt) or 0)) < SPELL_TOOLTIP_ENRICHMENT_MIN_SEND_INTERVAL then
                    queueIdx = queueIdx - 1  -- retry this entry next tick
                    return
                end
                local requestId = NextSpellEnrichmentRequestId()
                pendingSpellEnrichment[key] = { requestId = requestId, sentAt = now }
                lastSpellEnrichmentAttemptAt[key] = now
                lastSpellEnrichmentSendAt = now
                addon:RequestSpellTooltipEnrichment(requestId, sid, contextHash, false)
                return  -- one per tick
            end
        end

        -- Queue exhausted.
        self:SetScript("OnUpdate", nil)
    end)
end

local function EnhanceSpellTooltip(tooltip, spellId)
    if not tooltip then return end
    local sid = tonumber(spellId)
    if sid and sid > 0 then
        local now = GetTime and GetTime() or 0
        local lastSid = tonumber(tooltip._dcqosLastEnhancedSpellId)
        local lastAt = tonumber(tooltip._dcqosLastEnhancedSpellAt) or 0
        -- Multiple hooks (SetHyperlink/OnTooltipSetSpell/SetSpell) may fire for
        -- the same tooltip update burst; suppress duplicate enrich calls.
        if lastSid == sid and (now - lastAt) < 0.05 then
            return
        end
        tooltip._dcqosLastEnhancedSpellId = sid
        tooltip._dcqosLastEnhancedSpellAt = now
    end
    local enrichResult = AddSpellTooltipEnrichment(tooltip, spellId)
    if enrichResult == nil then
        -- Request is in-flight; defer Spell ID to be added when the response arrives.
        tooltip._dcqosPendingSpellIdForBottom = sid
    else
        -- Enrichment rendered (true), unavailable (false) — add Spell ID now.
        AddSpellId(tooltip, spellId)
    end
end

-- ============================================================
-- NPC ID in Tooltips (with DB GUID from server)
-- ============================================================
local npcInfoCache = {}       -- Cache server-provided NPC info
local pendingNpcRequests = {} -- Track pending requests
local npcKillCountsByEntry = nil
local npcKillCountsByName = nil
local killTrackerFrame = nil

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

local function NormalizeNpcName(name)
    name = tostring(name or "")
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("|T.-|t", "")
    return string.lower(name)
end

local function GetKillStores()
    if addon and addon.db and addon.db.npcKillStats then
        local stats = addon.db.npcKillStats
        local account = stats.account
        local charKey = addon.GetCharacterKey and addon:GetCharacterKey() or (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Unknown")
        local character = stats.characters and stats.characters[charKey]
        if not account then
            account = { byEntry = {}, byName = {}, nameByEntry = {} }
            stats.account = account
        end
        if not stats.characters then
            stats.characters = {}
        end
        if not character then
            character = { byEntry = {}, byName = {}, nameByEntry = {} }
            stats.characters[charKey] = character
        end
        return account, character
    end
    return nil, nil
end

local function CacheNpcNameByEntry(entry, name)
    if not entry or not name or name == "" then return end
    local account, character = GetKillStores()
    if not account or not character then return end
    account.nameByEntry[entry] = name
    character.nameByEntry[entry] = name
end

local function IncrementNpcKill(entry, name)
    local account, character = GetKillStores()
    if not account or not character then
        return
    end

    if entry then
        account.byEntry[entry] = (account.byEntry[entry] or 0) + 1
        character.byEntry[entry] = (character.byEntry[entry] or 0) + 1
        if name and name ~= "" then
            account.nameByEntry[entry] = name
            character.nameByEntry[entry] = name
        end
    end

    if name and name ~= "" then
        local key = NormalizeNpcName(name)
        if key ~= "" then
            account.byName[key] = (account.byName[key] or 0) + 1
            character.byName[key] = (character.byName[key] or 0) + 1
        end
    end
end

local function GetNpcKillCounts(entry, name)
    local account, character = GetKillStores()
    if not account or not character then
        return 0, 0
    end

    local key = (name and name ~= "") and NormalizeNpcName(name) or nil

    local charCount = 0
    local acctCount = 0

    if entry then
        charCount = character.byEntry[entry] or 0
        acctCount = account.byEntry[entry] or 0
    elseif key and key ~= "" then
        charCount = character.byName[key] or 0
        acctCount = account.byName[key] or 0
    end

    return charCount, acctCount
end

local function HandleCombatLogEvent(...)
    if not addon.settings.tooltips.showNpcKillCount then
        return
    end

    local subevent = select(2, ...)
    if subevent ~= "PARTY_KILL" then
        return
    end

    local sourceGUID, sourceName, sourceFlags
    local destGUID, destName, destFlags

    -- 3.3.5a layout: timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags
    -- Modern layout: timestamp, subevent, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags
    if type(select(3, ...)) == "boolean" then
        sourceGUID = select(4, ...)
        sourceName = select(5, ...)
        sourceFlags = select(6, ...)
        destGUID = select(8, ...)
        destName = select(9, ...)
        destFlags = select(10, ...)
    else
        sourceGUID = select(3, ...)
        sourceName = select(4, ...)
        sourceFlags = select(5, ...)
        destGUID = select(6, ...)
        destName = select(7, ...)
        destFlags = select(8, ...)
    end

    if not destGUID then return end

    local playerGUID = UnitGUID("player")
    local petGUID = UnitGUID("pet")
    local vehicleGUID = UnitGUID("vehicle")

    local isMine = (sourceGUID and (sourceGUID == playerGUID or sourceGUID == petGUID or sourceGUID == vehicleGUID))
    if not isMine and sourceFlags and COMBATLOG_OBJECT_AFFILIATION_MINE and bit and bit.band then
        isMine = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0)
    end
    if not isMine and sourceName then
        local playerName = UnitName("player")
        local petName = UnitName("pet")
        local vehicleName = UnitName("vehicle")
        if (playerName and sourceName == playerName)
            or (petName and sourceName == petName)
            or (vehicleName and sourceName == vehicleName) then
            isMine = true
        end
    end
    if not isMine then return end

    local entry = ParseNpcFromGuid(destGUID)
    IncrementNpcKill(entry, destName)
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
    local unitName = UnitName(unit)
    if entry and unitName then
        CacheNpcNameByEntry(entry, unitName)
    end
    
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

local function AddNpcKillCount(tooltip, unit)
    if not addon.settings.tooltips.showNpcKillCount then return end
    if not unit then return end
    if UnitIsPlayer(unit) then return end

    local canAttack = UnitCanAttack("player", unit)
    local reaction = UnitReaction(unit, "player")
    if not canAttack and (reaction == nil or reaction >= 5) then
        return
    end

    local guid = UnitGUID(unit)
    if not guid then return end

    local entry = ParseNpcFromGuid(guid)
    local name = UnitName(unit)
    local charCount, acctCount = GetNpcKillCounts(entry, name)

    local key = entry or name or guid
    if tooltip._dcqosNpcKillShown == key then return end
    tooltip._dcqosNpcKillShown = key

    tooltip:AddDoubleLine("Kills (Char):", "|cffffffff" .. tostring(charCount or 0) .. "|r", 0.5, 0.5, 0.5)
    tooltip:AddDoubleLine("Kills (Account):", "|cffffffff" .. tostring(acctCount or 0) .. "|r", 0.5, 0.5, 0.5)
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
        AddNpcKillCount(tooltip, unit)
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
    local function AddItemTooltipDetails(self, itemLink)
        if not itemLink then
            return
        end

        AddItemId(self, itemLink)
        AddItemLevel(self, itemLink)
        self:Show()
    end

    local function HookTooltipMethodOnce(flagName, methodName, handler)
        if GameTooltip[flagName] then
            return
        end
        if not hooksecurefunc or not GameTooltip[methodName] then
            return
        end

        GameTooltip[flagName] = true
        hooksecurefunc(GameTooltip, methodName, handler)
    end

    HookTooltipMethodOnce("_dcqosHookedSetBagItem", "SetBagItem", function(self, bag, slot, ...)
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
            AddItemTooltipDetails(self, itemLink)
            AddUpgradeInfo(self, bag, slot, itemLink)
        end
    end)

    HookTooltipMethodOnce("_dcqosHookedSetInventoryItem", "SetInventoryItem", function(self, unit, slot, ...)
        local itemLink = GetInventoryItemLink(unit, slot)
        if itemLink then
            AddItemTooltipDetails(self, itemLink)
            if unit == "player" then
                AddUpgradeInfo(self, -2, slot, itemLink)  -- -2 = equipment
            end
        end
    end)

    HookTooltipMethodOnce("_dcqosHookedSetHyperlink", "SetHyperlink", function(self, link, ...)
        if link and link:find("item:") then
            AddItemTooltipDetails(self, link)
        end
    end)

    HookTooltipMethodOnce("_dcqosHookedSetMerchantItem", "SetMerchantItem", function(self, slot, ...)
        AddItemTooltipDetails(self, GetMerchantItemLink(slot))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetLootItem", "SetLootItem", function(self, slot, ...)
        AddItemTooltipDetails(self, GetLootSlotLink(slot))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetQuestItem", "SetQuestItem", function(self, questType, slot, ...)
        AddItemTooltipDetails(self, GetQuestItemLink(questType, slot))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetQuestLogItem", "SetQuestLogItem", function(self, questType, slot, ...)
        AddItemTooltipDetails(self, GetQuestLogItemLink(questType, slot))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetAuctionItem", "SetAuctionItem", function(self, auctionType, index, ...)
        AddItemTooltipDetails(self, GetAuctionItemLink(auctionType, index))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetCraftItem", "SetCraftItem", function(self, skill, slot, ...)
        AddItemTooltipDetails(self, GetCraftItemLink(slot))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetTradeSkillItem", "SetTradeSkillItem", function(self, skill, slot, ...)
        local itemLink
        if slot then
            itemLink = GetTradeSkillReagentItemLink(skill, slot)
        else
            itemLink = GetTradeSkillItemLink(skill)
        end
        AddItemTooltipDetails(self, itemLink)
    end)
    
    addon:Debug("Item tooltip hooks installed")
end

-- ============================================================
-- Unit Tooltip Hooks
-- ============================================================
local function HookUnitTooltips()
    if GameTooltip._dcqosHookedOnTooltipSetUnit and GameTooltip._dcqosHookedOnTooltipCleared then
        return
    end

    -- Hook OnTooltipSetUnit
    if not GameTooltip._dcqosHookedOnTooltipSetUnit then
        GameTooltip._dcqosHookedOnTooltipSetUnit = true
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
    end
    
    -- Reset NPC GUID flag and upgrade flag when tooltip is cleared
    if not GameTooltip._dcqosHookedOnTooltipCleared then
        GameTooltip._dcqosHookedOnTooltipCleared = true
        GameTooltip:HookScript("OnTooltipCleared", function(self)
            self._dcqosNpcGuid = nil
            self._dcqosUpgradeShown = nil
            self._dcqosResolvedSpellId = nil
            self._dcqosSpellSource = nil
            self._dcqosSpellIdShown = nil
            self._dcqosLastEnhancedSpellId = nil
            self._dcqosLastEnhancedSpellAt = nil
            self._dcqosActiveSpellKey = nil
            self._dcqosSpellEnrichmentShownKey = nil
            self._dcqosNativeDescriptionStrippedKey = nil
            self._dcqosNpcKillShown = nil
        end)
    end
    
    addon:Debug("Unit tooltip hooks installed")
end

-- ============================================================
-- Spell Tooltip Hooks
-- ============================================================
local function ResolveTooltipMethod(tooltipFrame, methodName)
    if not tooltipFrame or type(methodName) ~= "string" then
        return nil
    end

    if type(tooltipFrame[methodName]) == "function" then
        return tooltipFrame[methodName]
    end

    local mt = getmetatable(tooltipFrame)
    local indexTable = mt and mt.__index
    if type(indexTable) == "table" then
        local candidate = indexTable[methodName]
        if type(candidate) == "function" then
            return candidate
        end
    elseif type(indexTable) == "function" then
        local ok, fn = pcall(indexTable, tooltipFrame, methodName)
        if ok and type(fn) == "function" then
            return fn
        end
    end

    return nil
end

local function SafeFallbackSetAction(self)
    if self and self.Hide then
        self:Hide()
    end
end

local function SafeFallbackSetShapeshift(self, index)
    if self and self.SetText and GetShapeshiftFormInfo and type(index) == "number" then
        local _, formName = GetShapeshiftFormInfo(index)
        if formName and formName ~= "" then
            self:SetText(formName)
            return
        end
    end

    if self and self.Hide then
        self:Hide()
    end
end

local function EnsureGameTooltipMethod(methodName, fallback)
    if not GameTooltip or type(methodName) ~= "string" then
        return
    end

    if type(GameTooltip[methodName]) == "function" then
        return
    end

    local recovered = ResolveTooltipMethod(GameTooltip, methodName)
        or ResolveTooltipMethod(ItemRefTooltip, methodName)
        or ResolveTooltipMethod(ShoppingTooltip1, methodName)
        or ResolveTooltipMethod(ShoppingTooltip2, methodName)

    if type(recovered) == "function" then
        rawset(GameTooltip, "_dcqosWrapped" .. methodName, nil)
        rawset(GameTooltip, methodName, recovered)
        addon:Debug("Recovered GameTooltip." .. methodName)
        return
    end

    if type(fallback) == "function" then
        rawset(GameTooltip, "_dcqosWrapped" .. methodName, nil)
        rawset(GameTooltip, methodName, fallback)
        addon:Debug("GameTooltip." .. methodName .. " missing; installed safe fallback")
    end
end

local function EnsureGameTooltipActionMethods()
    EnsureGameTooltipMethod("SetAction", SafeFallbackSetAction)
    EnsureGameTooltipMethod("SetShapeshift", SafeFallbackSetShapeshift)

    -- Recover from older builds that accidentally assigned numeric values to
    -- UpdateTooltip and broke GameTooltip's OnUpdate path.
    if GameTooltip and type(rawget(GameTooltip, "UpdateTooltip")) ~= "function" then
        rawset(GameTooltip, "UpdateTooltip", nil)
    end
end

local function ResolveActionButtonFromArgs(...)
    local button = select(1, ...)
    if type(button) == "table" and button.action then
        return button
    end

    if type(this) == "table" and this.action then
        return this
    end

    return nil
end

local function GetSpellIdFromBookSlot(slot, bookType)
    local index = tonumber(slot)
    if not index or index <= 0 or type(bookType) ~= "string" then
        return nil
    end

    if type(GetSpellLink) == "function" then
        local link = GetSpellLink(index, bookType)
        if type(link) == "string" and link ~= "" then
            local sid = tonumber(link:match("spell:(%d+)"))
            if sid and sid > 0 then
                return sid
            end
        end
    end

    if type(GetSpellBookItemInfo) == "function" then
        local spellType, entryId = GetSpellBookItemInfo(index, bookType)
        if spellType == "SPELL" then
            local sid = tonumber(entryId)
            if sid and sid > 0 then
                return sid
            end
        end
    end

    return nil
end

local function FindSpellBookSlotBySpellId(spellId, bookType)
    local sid = tonumber(spellId)
    if not sid or sid <= 0 then
        return nil
    end

    if type(GetNumSpellTabs) ~= "function" or type(GetSpellTabInfo) ~= "function"
        or type(GetSpellBookItemInfo) ~= "function" then
        return nil
    end

    local tabCount = tonumber(GetNumSpellTabs()) or 0
    for tabIndex = 1, tabCount do
        local _, _, offset, numSlots = GetSpellTabInfo(tabIndex)
        offset = tonumber(offset) or 0
        numSlots = tonumber(numSlots) or 0

        for slot = offset + 1, offset + numSlots do
            local bookSid = GetSpellIdFromBookSlot(slot, bookType)
            if bookSid and bookSid == sid then
                return slot
            end
        end
    end

    return nil
end

-- Scans the player spellbook to find the current known rank of a spell by its
-- base name. In 3.3.5a the spellbook only stores the current learned rank, so
-- the first matching entry returns the correct current-rank spell ID. This
-- corrects forks where GetActionSpell/GetActionInfo return rank-1 IDs.
-- Cache mapping lower-case spell name → {sid=maxRankSpellId, slot=spellbookSlot}.
-- Built lazily on first use; invalidated when the player's spellbook changes so
-- that newly-learned ranks are picked up correctly.
local _spellNameMaxRankCache = nil

local function InvalidateSpellNameCache()
    _spellNameMaxRankCache = nil
end

local function BuildSpellNameCache()
    _spellNameMaxRankCache = {}
    if type(GetNumSpellTabs) ~= "function" or type(GetSpellTabInfo) ~= "function"
        or type(GetSpellBookItemInfo) ~= "function"
        or type(GetSpellBookItemName) ~= "function" then
        return
    end
    local tabCount = tonumber(GetNumSpellTabs()) or 0
    for tabIndex = 1, tabCount do
        local _, _, offset, numSlots = GetSpellTabInfo(tabIndex)
        offset = tonumber(offset) or 0
        numSlots = tonumber(numSlots) or 0
        for slot = offset + 1, offset + numSlots do
            local sid = GetSpellIdFromBookSlot(slot, BOOKTYPE_SPELL)
            if sid and sid > 0 then
                local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
                if name then
                    local lname = strlower(name)
                    -- Extract numeric rank so we keep the highest rank per name.
                    -- On standard 3.3.5a only one entry exists per name; on
                    -- 255 servers all ranks may be present — we want the max.
                    local rankNum = 0
                    if type(GetSpellInfo) == "function" then
                        local _, rankStr = GetSpellInfo(sid)
                        if rankStr and rankStr ~= "" then
                            local n = tonumber(rankStr:match("%d+"))
                            if n then rankNum = n end
                        end
                    end
                    local existing = _spellNameMaxRankCache[lname]
                    if (not existing)
                        or (rankNum > (existing.rankNum or 0))
                        or (rankNum == (existing.rankNum or 0) and sid > (existing.sid or 0))
                        or (rankNum == (existing.rankNum or 0)
                            and sid == (existing.sid or 0)
                            and slot > (existing.slot or 0)) then
                        _spellNameMaxRankCache[lname] = {sid = sid, slot = slot, rankNum = rankNum}
                    end
                end
            end
        end
    end
end

-- Finds the spell ID of the player's current (highest-learned) rank of a spell.
-- Returns spellId, spellbookSlot or nil, nil.
local function FindCurrentRankSpellIdByName(spellName)
    if type(spellName) ~= "string" or spellName == "" then
        return nil, nil
    end
    if not _spellNameMaxRankCache then
        BuildSpellNameCache()
    end
    local entry = _spellNameMaxRankCache[strlower(spellName)]
    if entry then
        return entry.sid, entry.slot
    end
    return nil, nil
end

local function ResolveSpellFromBookSlot(slot, bookType)
    local index = tonumber(slot)
    if not index or index <= 0 or type(bookType) ~= "string" then
        return nil, nil
    end

    local sid = GetSpellIdFromBookSlot(index, bookType)
    if not sid or sid <= 0 then
        return nil, nil
    end

    local spellName
    if type(GetSpellBookItemName) == "function" then
        spellName = GetSpellBookItemName(index, bookType)
    end

    return sid, spellName
end

local function ResolveActionSpellData(action, actionSpellValue, actionSubType)
    local raw = tonumber(actionSpellValue)
    local hasRaw = raw and raw > 0

    -- GetActionSpell is the most authoritative source for the current-rank spell
    -- on an action button. Check it first before any spellbook probing so that
    -- low-valued raw IDs (e.g. 53 = Backstab Rank 1) are not misresolved when
    -- the action bar actually holds a higher rank.
    if type(GetActionSpell) == "function" and type(action) == "number" and action > 0 then
        local ok, actionSpellId = pcall(function()
            return GetActionSpell(action)
        end)
        local actionSid = ok and tonumber(actionSpellId) or nil
        if actionSid and actionSid > 0 then
            -- Upgrade to the player's current known rank via spellbook name lookup.
            -- On forks where GetActionSpell returns rank-1 spell IDs, this corrects
            -- the ID to whatever rank the player has learned (e.g. 53 -> 48657).
            if type(GetSpellInfo) == "function" then
                local baseName = GetSpellInfo(actionSid)
                if baseName then
                    local upgradedSid, upgradedSlot = FindCurrentRankSpellIdByName(baseName)
                    if upgradedSid and upgradedSid > 0 then
                        local upgradedName = GetSpellInfo(upgradedSid) or baseName
                        return upgradedSid, upgradedSlot, BOOKTYPE_SPELL, upgradedName
                    end
                end
            end

            local slot, bookType
            if BOOKTYPE_SPELL then
                slot = FindSpellBookSlotBySpellId(actionSid, BOOKTYPE_SPELL)
                if slot then
                    bookType = BOOKTYPE_SPELL
                end
            end
            if not slot and BOOKTYPE_PET then
                slot = FindSpellBookSlotBySpellId(actionSid, BOOKTYPE_PET)
                if slot then
                    bookType = BOOKTYPE_PET
                end
            end

            local spellName = type(GetSpellInfo) == "function" and GetSpellInfo(actionSid) or nil
            return actionSid, slot, bookType, spellName
        end
    end

    if not hasRaw then
        return nil, nil, nil, nil
    end

    -- Slot resolution should only happen when subtype explicitly points to a
    -- spellbook source; probing raw values as slots can map wrong actions.
    if type(actionSubType) == "string" and actionSubType ~= "" then
        local sid, spellName = ResolveSpellFromBookSlot(raw, actionSubType)
        if sid then
            return sid, raw, actionSubType, spellName
        end
    end

    -- Fall back to treating the action value as a direct spell ID.
    -- First try to upgrade to the current known rank via spellbook name lookup.
    if type(GetSpellInfo) == "function" then
        local baseName = GetSpellInfo(raw)
        if baseName then
            local upgradedSid, upgradedSlot = FindCurrentRankSpellIdByName(baseName)
            if upgradedSid and upgradedSid > 0 then
                local upgradedName = GetSpellInfo(upgradedSid) or baseName
                return upgradedSid, upgradedSlot, BOOKTYPE_SPELL, upgradedName
            end
        end
    end

    local spellName
    if type(GetSpellInfo) == "function" then
        spellName = GetSpellInfo(raw)
    end

    local slot, bookType
    if BOOKTYPE_SPELL then
        slot = FindSpellBookSlotBySpellId(raw, BOOKTYPE_SPELL)
        if slot then
            bookType = BOOKTYPE_SPELL
        end
    end

    if not slot and BOOKTYPE_PET then
        slot = FindSpellBookSlotBySpellId(raw, BOOKTYPE_PET)
        if slot then
            bookType = BOOKTYPE_PET
        end
    end

    -- Last resort when direct ID was not found in spell chains: interpret raw
    -- as slot in common books only after direct-ID attempts have failed.
    if not spellName then
        if BOOKTYPE_SPELL then
            local sid, slotName = ResolveSpellFromBookSlot(raw, BOOKTYPE_SPELL)
            if sid then
                return sid, raw, BOOKTYPE_SPELL, slotName
            end
        end
        if BOOKTYPE_PET then
            local sid, slotName = ResolveSpellFromBookSlot(raw, BOOKTYPE_PET)
            if sid then
                return sid, raw, BOOKTYPE_PET, slotName
            end
        end
    end

    return raw, slot, bookType, spellName
end

local function PrimeTooltipActionSpellId(tooltip, button)
    if not tooltip then
        return nil
    end

    tooltip._dcqosResolvedSpellId = nil

    if type(button) ~= "table" then
        return nil
    end

    local action = button.action
    if (not action or action <= 0) and type(ActionButton_GetPagedID) == "function" then
        local ok, pagedAction = pcall(function()
            return ActionButton_GetPagedID(button)
        end)
        if ok and type(pagedAction) == "number" then
            action = pagedAction
        end
    end

    if not action or action <= 0 or type(GetActionInfo) ~= "function" then
        return nil
    end

    local actionType, id, actionSubType = GetActionInfo(action)
    if actionType ~= "spell" or not id then
        return nil
    end

    local sid = ResolveActionSpellData(action, id, actionSubType)
    sid = tonumber(sid)
    if sid and sid > 0 then
        tooltip._dcqosResolvedSpellId = sid
        return sid
    end

    return nil
end

local function TrySetTooltipHyperlink(tooltip, hyperlink)
    if not tooltip or type(hyperlink) ~= "string" or hyperlink == "" then
        return false
    end

    if type(tooltip.SetHyperlink) ~= "function" then
        return false
    end

    local ok = pcall(function()
        tooltip:SetHyperlink(hyperlink)
    end)
    return ok
end

local function SetFallbackActionTooltip(button)
    if not GameTooltip or not button then
        return
    end

    PrimeTooltipActionSpellId(GameTooltip, button)

    local action = button.action
    if (not action or action <= 0) and type(ActionButton_GetPagedID) == "function" then
        local ok, pagedAction = pcall(function()
            return ActionButton_GetPagedID(button)
        end)
        if ok and type(pagedAction) == "number" then
            action = pagedAction
        end
    end

    if not action or action <= 0 then
        if GameTooltip.Hide then
            GameTooltip:Hide()
        end
        return
    end

    if type(GameTooltip.SetOwner) == "function" then
        if GameTooltip_SetDefaultAnchor and GetCVar and GetCVar("UberTooltips") == "1" then
            GameTooltip_SetDefaultAnchor(GameTooltip, button)
        else
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        end
    end

    local wroteText = false
    -- Avoid SetAction here: on some clients/forks it can throw transient
    -- C-side nil errors right after login/loading screens.

    local actionType, id, actionSubType
    if type(GetActionInfo) == "function" then
        actionType, id, actionSubType = GetActionInfo(action)
    end

    if not wroteText and actionType == "spell" and id then
        GameTooltip._dcqosSpellSource = "action"
        local sid, _, _, spellName = ResolveActionSpellData(action, id, actionSubType)
        local resolvedId = tonumber(sid) or tonumber(id)

        if (not spellName or spellName == "") and resolvedId and type(GetSpellInfo) == "function" then
            spellName = GetSpellInfo(resolvedId)
        end

        if spellName and spellName ~= "" then
            GameTooltip:SetText(spellName)
            if resolvedId and type(GetSpellInfo) == "function" then
                local _, spellRank = GetSpellInfo(resolvedId)
                if spellRank and spellRank ~= "" then
                    GameTooltip:AddLine(spellRank, 0.8, 0.8, 0.8)
                end
            end
            GameTooltip._dcqosResolvedSpellId = resolvedId
            EnhanceSpellTooltip(GameTooltip, resolvedId)
            wroteText = true
        end
    elseif not wroteText and actionType == "companion" and id and type(GetCompanionInfo) == "function" then
        GameTooltip._dcqosSpellSource = "action"

        local _, companionName, companionSpellId = GetCompanionInfo("MOUNT", id)
        if (not companionName or companionName == "") then
            local _, critterName, critterSpellId = GetCompanionInfo("CRITTER", id)
            companionName = critterName
            companionSpellId = critterSpellId
        end

        local resolvedId = tonumber(companionSpellId)
        if companionName and companionName ~= "" then
            GameTooltip:SetText(companionName)
            if resolvedId and resolvedId > 0 then
                GameTooltip._dcqosResolvedSpellId = resolvedId
                EnhanceSpellTooltip(GameTooltip, resolvedId)
            end
            wroteText = true
        end
    elseif not wroteText and actionType == "item" and id then
        GameTooltip._dcqosSpellSource = nil
        if TrySetTooltipHyperlink(GameTooltip, "item:" .. tostring(id)) then
            wroteText = true
        end
    end

    if not wroteText and actionType == "item" and id and type(GetItemInfo) == "function" then
        GameTooltip._dcqosSpellSource = nil
        local itemName = GetItemInfo(id)
        if itemName and itemName ~= "" then
            GameTooltip:SetText(itemName)
            wroteText = true
        end
    elseif not wroteText and actionType == "macro" and id and type(GetMacroInfo) == "function" then
        GameTooltip._dcqosSpellSource = nil
        local macroName = GetMacroInfo(id)
        if macroName and macroName ~= "" then
            GameTooltip:SetText(macroName)
            wroteText = true
        end
    end

    if not wroteText and type(GetActionText) == "function" then
        GameTooltip._dcqosSpellSource = nil
        local actionText = GetActionText(action)
        if actionText and actionText ~= "" then
            GameTooltip:SetText(actionText)
            wroteText = true
        end
    end

    if not wroteText then
        GameTooltip._dcqosSpellSource = nil
        GameTooltip:SetText(ACTIONBAR_LABEL or "Action")
    end

    if button then
        if type(rawget(button, "UpdateTooltip")) ~= "function" then
            rawset(button, "UpdateTooltip", nil)
        end
        -- FrameXML expects UpdateTooltip to stay a function; the timer field is lowercase.
        button.updateTooltip = TOOLTIP_UPDATE_TIME
    end
    GameTooltip:Show()
end

local function SetFallbackShapeshiftTooltip(button)
    if not GameTooltip then
        return
    end

    local formIndex
    if button and type(button.GetID) == "function" then
        formIndex = button:GetID()
    elseif type(this) == "table" and type(this.GetID) == "function" then
        formIndex = this:GetID()
    end

    if not formIndex or formIndex <= 0 then
        return
    end

    if type(GameTooltip.SetOwner) == "function" then
        if GameTooltip_SetDefaultAnchor and GetCVar and GetCVar("UberTooltips") == "1" and button then
            GameTooltip_SetDefaultAnchor(GameTooltip, button)
        elseif button then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        end
    end

    SafeFallbackSetShapeshift(GameTooltip, formIndex)

    GameTooltip:Show()
end

local function HookSpellTooltips()
    EnsureGameTooltipActionMethods()

    -- Revalidate critical methods before Blizzard's OnEnter handlers call SetAction/SetShapeshift.
    if not GameTooltip._dcqosHookedSetOwner and hooksecurefunc and GameTooltip.SetOwner then
        GameTooltip._dcqosHookedSetOwner = true
        hooksecurefunc(GameTooltip, "SetOwner", function(self, owner)
            if self == GameTooltip then
                EnsureGameTooltipActionMethods()
                PrimeTooltipActionSpellId(self, owner)
            end
        end)
    end

    if not GameTooltip._dcqosHookedSetAction and hooksecurefunc and GameTooltip.SetAction then
        GameTooltip._dcqosHookedSetAction = true
        hooksecurefunc(GameTooltip, "SetAction", function(self, action)
            local actionSlot = tonumber(action)
            if not actionSlot or actionSlot <= 0 or type(GetActionInfo) ~= "function" then
                return
            end

            local actionType, id, actionSubType = GetActionInfo(actionSlot)
            if actionType ~= "spell" or not id then
                return
            end

            local sid = ResolveActionSpellData(actionSlot, id, actionSubType)
            sid = tonumber(sid)
            if not sid or sid <= 0 then
                return
            end

            self._dcqosResolvedSpellId = sid
        end)
    end

    -- Replace ActionButton tooltip path with a robust fallback that avoids
    -- direct GameTooltip:SetAction calls, which can hard-error on some forks.
    if type(ActionButton_SetTooltip) == "function" and not addon._dcqosWrappedActionButtonSetTooltip then
        addon._dcqosWrappedActionButtonSetTooltip = true
        ActionButton_SetTooltip = function(...)
            EnsureGameTooltipActionMethods()
            local button = ResolveActionButtonFromArgs(...)
            SetFallbackActionTooltip(button)
        end
    end

    if type(ShapeshiftButton_OnEnter) == "function" and not addon._dcqosWrappedShapeshiftButtonOnEnter then
        addon._dcqosWrappedShapeshiftButtonOnEnter = true
        local originalShapeshiftButtonOnEnter = ShapeshiftButton_OnEnter
        ShapeshiftButton_OnEnter = function(...)
            EnsureGameTooltipActionMethods()
            local ok, result = pcall(originalShapeshiftButtonOnEnter, ...)
            if ok then
                return result
            end

            addon:Debug("ShapeshiftButton_OnEnter failed; using fallback: " .. tostring(result))
            local button = select(1, ...)
            if type(button) ~= "table" then
                button = this
            end
            SetFallbackShapeshiftTooltip(button)
        end
    end

    -- Most spell tooltips (action buttons, racials, etc.) fire this script.
    -- This is the most reliable way to capture spell IDs in 3.3.5a.
    if not GameTooltip._dcqosHookedOnTooltipSetSpell then
        GameTooltip._dcqosHookedOnTooltipSetSpell = true
        GameTooltip:HookScript("OnTooltipSetSpell", function(self)
            local source = self._dcqosSpellSource
            if source ~= "action" and source ~= "spellbook" then
                return
            end
            local name, rank, spellId = self:GetSpell()
            spellId = tonumber(spellId)
            -- Primary: find the player's highest-learned rank via the spellbook
            -- name cache. This is correct on both standard 3.3.5a (one entry per
            -- name) and 255 servers where all ranks appear in the book.
            if name and name ~= "" then
                local bookSid = FindCurrentRankSpellIdByName(name)
                if bookSid then spellId = bookSid end
            end
            -- Last resort: pre-resolved spell ID set by action-bar hooks.
            -- Only used when the spellbook lookup yielded nothing (e.g. NPC
            -- abilities not in the player's book).
            if not spellId or spellId <= 0 then
                local resolvedSpellId = tonumber(self._dcqosResolvedSpellId)
                if resolvedSpellId and resolvedSpellId > 0 then
                    spellId = resolvedSpellId
                end
            end
            EnhanceSpellTooltip(self, spellId)
            self:Show()
        end)
    end

    -- Hook SetSpell (action bar) without overriding the native method,
    -- to avoid breaking ActionButton tooltip internals.
    if not GameTooltip._dcqosHookedSetSpell and hooksecurefunc and GameTooltip.SetSpell then
        GameTooltip._dcqosHookedSetSpell = true
        hooksecurefunc(GameTooltip, "SetSpell", function(self, spellBook, spellBookType, ...)
            if spellBookType ~= BOOKTYPE_SPELL and spellBookType ~= BOOKTYPE_PET then
                return
            end

            self._dcqosSpellSource = "spellbook"

            local spellId

            -- 1) Native GetSpell() — dc-wotlkextensions may return a spellId.
            local nativeName, _, directSpellId = self:GetSpell()
            spellId = tonumber(directSpellId)

            -- 2) GetSpellBookItemInfo on the slot argument: when SetSpell is
            -- called with a real spellbook slot this returns the correct
            -- current-rank spell ID.
            if (not spellId or spellId <= 0)
                and spellBook and spellBookType then
                spellId = GetSpellIdFromBookSlot(spellBook, spellBookType)
            end

            -- 3) Spellbook name scan: find the highest-learned rank by the
            -- tooltip's spell name (works even when argument is a raw spell ID).
            if (not spellId or spellId <= 0) and nativeName and nativeName ~= "" then
                local bookSid = FindCurrentRankSpellIdByName(nativeName)
                if bookSid then spellId = bookSid end
            end

            -- 4) Last resort: pre-resolved ID from action-bar hooks.
            if not spellId or spellId <= 0 then
                local resolvedSpellId = tonumber(self._dcqosResolvedSpellId)
                if resolvedSpellId and resolvedSpellId > 0 then
                    spellId = resolvedSpellId
                end
            end

            EnhanceSpellTooltip(self, spellId)
            self:Show()
        end)
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

        -- Invalidate the spell-name→max-rank cache whenever the player learns a new
        -- spell rank or changes talents (cache is rebuilt lazily on next tooltip).
        addon:RegisterEvent("SPELLS_CHANGED", InvalidateSpellNameCache)
        addon:RegisterEvent("PLAYER_TALENT_UPDATE", InvalidateSpellNameCache)
    
    -- Hook item tooltips
    HookItemTooltips()
    
    -- Hook unit tooltips
    HookUnitTooltips()
    
    -- Hook spell tooltips
    HookSpellTooltips()
    
    -- Setup health bar hiding
    SetupHealthBarHiding()

    -- Kill tracker (NPC tooltips)
    if not killTrackerFrame then
        killTrackerFrame = CreateFrame("Frame")
        killTrackerFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "COMBAT_LOG_EVENT_UNFILTERED" then
                HandleCombatLogEvent(...)
            end
        end)
    end
    killTrackerFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- Listen for scale changes
    addon:RegisterEvent("SETTING_CHANGED", function(path, value)
        if path == "tooltips.scale" then
            SetTooltipScale()
        end
    end)

    -- Pre-warm spell enrichment cache after zone-in so first hovers are instant.
    -- Delay 5 s to allow the server addon-protocol connection to establish.
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        addon:DelayedCall(5, StartSpellEnrichmentPrefetch)
    end)
end

function Tooltips.OnDisable()
    addon:Debug("Tooltips module disabling")
    -- Note: Hooks cannot be removed, but we check enabled state in each hook
    if killTrackerFrame then
        killTrackerFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
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

    -- Show NPC Kill Count
    local npcKillCb = addon:CreateCheckbox(parent)
    npcKillCb:SetPoint("TOPLEFT", 16, yOffset)
    npcKillCb.Text:SetText("Show NPC Kill Count")
    npcKillCb:SetChecked(settings.showNpcKillCount)
    npcKillCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showNpcKillCount", self:GetChecked())
    end)
    AddSettingTooltip(npcKillCb, "Show NPC Kill Count",
        "Displays how many of the same NPC you have killed (per-character and per-account). Counts only kills credited to you (including your pet/vehicle). Tracked by entry ID when available and caches names per entry.")
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
