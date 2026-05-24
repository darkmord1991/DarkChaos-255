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
local protocolCapabilityHookRegistered = false
local QueueSpellEnrichmentPrefetch
local lastNativeBridgeSync

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
local UPGRADE_PENDING_TIMEOUT = 4.0

local telemetry = {
    startedAt = GetTime and GetTime() or 0,
    spell = {
        requestsSent = 0,
        requestSendFailures = 0,
        nativeRequestsSent = 0,
        nativeResponsesReady = 0,
        nativeErrors = 0,
        nativeFallbacks = 0,
        clientDescriptionMissingExport = 0,
        clientDescriptionCallError = 0,
        clientDescriptionNilReturn = 0,
        clientDescriptionEmptyBody = 0,
        clientDescriptionPlaceholderRejected = 0,
        responsesReceived = 0,
        responsesSuccess = 0,
        responsesError = 0,
        responsesWithoutPending = 0,
        responsesRemappedByRequestId = 0,
        responseRequestIdMismatch = 0,
        pendingTimeoutRecoveries = 0,
        skippedRenderModeDisabled = 0,
        prefetchRuns = 0,
        prefetchRequestsSent = 0,
    },
    upgrade = {
        requestsSent = 0,
        responsesReceived = 0,
        pendingTimeoutRecoveries = 0,
        nativeRequestsSent = 0,
        nativeResponsesReady = 0,
        nativeErrors = 0,
        nativeFallbacks = 0,
    },
    npc = {
        requestsSent = 0,
        responsesReceived = 0,
        pendingTimeoutRecoveries = 0,
        nativeRequestsSent = 0,
        nativeResponsesReady = 0,
        nativeErrors = 0,
        nativeFallbacks = 0,
    },
}

local function TelemetryInc(bucket, key, amount)
    if type(telemetry[bucket]) ~= "table" then return end
    local delta = tonumber(amount) or 1
    telemetry[bucket][key] = (tonumber(telemetry[bucket][key]) or 0) + delta
end

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
    if bag == -2 then return 255 end  -- Equipped item slots on player paperdoll
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
    
    -- Don't re-request if already pending, unless stale.
    local pendingAt = tonumber(pendingUpgradeRequests[locationKey]) or 0
    if pendingAt > 0 and (now - pendingAt) < UPGRADE_PENDING_TIMEOUT then
        return
    end
    if pendingAt > 0 and (now - pendingAt) >= UPGRADE_PENDING_TIMEOUT then
        pendingUpgradeRequests[locationKey] = nil
        TelemetryInc("upgrade", "pendingTimeoutRecoveries")
    end
    
    -- Check cache
    local cached = itemUpgradeCache[locationKey]
    if cached and (now - cached.timestamp) < UPGRADE_CACHE_DURATION then
        return
    end
    
    pendingUpgradeRequests[locationKey] = now
    lastUpgradeRequest = now
    TelemetryInc("upgrade", "requestsSent")

    if ShouldUseNativeItemUpgradeBridge() then
        local ok, nativeErr = pcall(RequestNativeItemUpgradeTooltip,
            serverBag, serverSlot)
        if ok then
            TelemetryInc("upgrade", "nativeRequestsSent")
            return
        end

        TelemetryInc("upgrade", "nativeErrors")
        TelemetryInc("upgrade", "nativeFallbacks")
        addon:Debug("Native item-upgrade request failed: " .. tostring(nativeErr))
    end

    addon.protocol:RequestItemUpgradeInfo(serverBag, serverSlot)
end

local function TryConsumeNativeUpgradeInfo(serverBag, serverSlot)
    local locationKey = BuildLocationKey(serverBag, serverSlot)
    if not pendingUpgradeRequests[locationKey]
        or type(GetNativeItemUpgradeTooltipData) ~= "function" then
        return false
    end

    local ok,
        itemId,
        tier,
        upgradeLevel,
        maxUpgrade,
        statMultiplier,
        baseIlvl,
        upgradedIlvl,
        errorMessage = pcall(GetNativeItemUpgradeTooltipData,
            serverBag, serverSlot)

    if not ok then
        TelemetryInc("upgrade", "nativeErrors")
        addon:Debug("Native item-upgrade poll failed: " .. tostring(itemId))
        return false
    end

    if itemId == nil then
        return false
    end

    TelemetryInc("upgrade", "nativeResponsesReady")
    addon:FireEvent("ITEM_UPGRADE_INFO_RECEIVED", {
        bag = serverBag,
        slot = serverSlot,
        itemId = tonumber(itemId) or 0,
        tier = tonumber(tier) or 0,
        upgradeLevel = tonumber(upgradeLevel) or 0,
        maxUpgrade = tonumber(maxUpgrade) or 0,
        statMultiplier = tonumber(statMultiplier) or 1.0,
        baseIlvl = tonumber(baseIlvl) or 0,
        upgradedIlvl = tonumber(upgradedIlvl) or 0,
        error = type(errorMessage) == "string" and errorMessage ~= ""
            and errorMessage or nil,
    })
    return true
end

-- Handle upgrade info from server
local function OnUpgradeInfoReceived(data)
    if not data then return end
    TelemetryInc("upgrade", "responsesReceived")
    
    local locationKey = BuildLocationKey(data.bag, data.slot)
    pendingUpgradeRequests[locationKey] = nil

    if data.error then
        itemUpgradeCache[locationKey] = nil
        return
    end
    
    itemUpgradeCache[locationKey] = {
        timestamp = GetTime(),
        upgradeLevel = data.upgradeLevel or 0,
        maxUpgrade = data.maxUpgrade or 0,
        tier = data.tier or 0,
        statMultiplier = data.statMultiplier or 1.0,
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

    if ShouldUseNativeItemUpgradeBridge() then
        TryConsumeNativeUpgradeInfo(serverBag, serverSlot)
    end
    
    -- Check cache
    local cached = itemUpgradeCache[locationKey]
    if cached and (GetTime() - (tonumber(cached.timestamp) or 0)) >= UPGRADE_CACHE_DURATION then
        itemUpgradeCache[locationKey] = nil
        cached = nil
    end
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

    -- On patched native clients, item IDs are rendered from C++ tooltip code.
    -- Appending a second Lua-owned line here can visibly blink when the native
    -- async item snapshot path redraws the tooltip without re-entering these hooks.
    if type(GetDCClientCapabilities) == "function" then
        return
    end
    
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
local SPELL_ENRICH_CACHE_TTL = 180
local SPELL_ENRICH_CACHE_MAX_SPELLS = 1200
local SPELL_ENRICH_CACHE_MAX_CONTEXTS_PER_SPELL = 8
local SPELL_ENRICH_CACHE_PRUNE_INTERVAL = 20
local NATIVE_CLIENT_SPELL_ROWS_OK_TTL = 60
local NATIVE_CLIENT_SPELL_ROWS_ERR_TTL = 10
local NATIVE_TOOLTIP_CAPABILITY = 0x00000100
local NATIVE_ITEM_UPGRADE_CAPABILITY = 0x00000400
local NATIVE_NPC_TOOLTIP_CAPABILITY = 0x00000800
local NATIVE_TOOLTIP_TIMEOUT_MS = math.floor(SPELL_TOOLTIP_ENRICHMENT_PENDING_TTL * 1000)
local NATIVE_TOOLTIP_MIN_INTERVAL_MS = math.floor(SPELL_TOOLTIP_ENRICHMENT_MIN_SEND_INTERVAL * 1000)
local NATIVE_TOOLTIP_MAX_TIMEOUTS = 3
local NATIVE_SPELL_TOOLTIP_STATUS_UNAVAILABLE = 0
local NATIVE_SPELL_TOOLTIP_STATUS_PENDING = 1
local NATIVE_SPELL_TOOLTIP_STATUS_READY = 2
local NATIVE_SPELL_TOOLTIP_STATUS_TIMED_OUT = 3
local NATIVE_SPELL_TOOLTIP_STATUS_DISABLED = 4

local spellEnrichmentRequestCounter = 0
local pendingSpellEnrichment = {}
local pendingSpellEnrichmentByRequestId = {}
local lastSpellEnrichmentAttemptAt = {}
local lastSpellEnrichmentSendAt = 0
local lastSpellEnrichmentPruneAt = 0
local lastSpellEnrichCachePruneAt = 0
local nativeClientSpellRowsCache = {}

local function PruneSpellEnrichmentCache(now)
    if not addon.tooltipCache or type(addon.tooltipCache.spellEnrichment) ~= "table" then
        return
    end

    now = tonumber(now) or 0
    if now <= 0 then
        return
    end

    if lastSpellEnrichCachePruneAt > 0
        and (now - lastSpellEnrichCachePruneAt) < SPELL_ENRICH_CACHE_PRUNE_INTERVAL then
        return
    end

    local buckets = addon.tooltipCache.spellEnrichment
    local spellCount = 0
    local spellIds = {}

    for spellId, contextBucket in pairs(buckets) do
        if type(contextBucket) ~= "table" then
            buckets[spellId] = nil
        else
            spellCount = spellCount + 1
            spellIds[#spellIds + 1] = spellId

            local contextEntries = {}
            for contextHash, enrichment in pairs(contextBucket) do
                local receivedAt = enrichment and tonumber(enrichment.receivedAt) or 0
                local age = (receivedAt > 0) and (now - receivedAt)
                    or (SPELL_ENRICH_CACHE_TTL + 1)
                if age > SPELL_ENRICH_CACHE_TTL then
                    contextBucket[contextHash] = nil
                else
                    contextEntries[#contextEntries + 1] = {
                        contextHash = contextHash,
                        receivedAt = receivedAt,
                    }
                end
            end

            if #contextEntries == 0 then
                buckets[spellId] = nil
                spellCount = spellCount - 1
            elseif #contextEntries > SPELL_ENRICH_CACHE_MAX_CONTEXTS_PER_SPELL then
                table.sort(contextEntries, function(a, b)
                    return (a.receivedAt or 0) > (b.receivedAt or 0)
                end)

                for i = SPELL_ENRICH_CACHE_MAX_CONTEXTS_PER_SPELL + 1, #contextEntries do
                    contextBucket[contextEntries[i].contextHash] = nil
                end
            end
        end
    end

    if spellCount > SPELL_ENRICH_CACHE_MAX_SPELLS then
        local keep = {}
        for _, spellId in ipairs(spellIds) do
            local bucket = buckets[spellId]
            if type(bucket) == "table" then
                local newest = 0
                for _, enrichment in pairs(bucket) do
                    newest = math.max(newest,
                        tonumber(enrichment and enrichment.receivedAt) or 0)
                end
                keep[#keep + 1] = { spellId = spellId, newest = newest }
            end
        end

        table.sort(keep, function(a, b)
            return (a.newest or 0) > (b.newest or 0)
        end)

        for i = SPELL_ENRICH_CACHE_MAX_SPELLS + 1, #keep do
            buckets[keep[i].spellId] = nil
        end
    end

    lastSpellEnrichCachePruneAt = now
end

local function HasCapabilityBit(mask, capability)
    mask = tonumber(mask) or 0
    capability = tonumber(capability) or 0

    if capability <= 0 then
        return false
    end

    if bit and bit.band then
        return bit.band(mask, capability) ~= 0
    end

    return (mask % (capability * 2)) >= capability
end

local function GetClientCapabilityMask()
    local protocol = type(DCAddonProtocol) == "table" and DCAddonProtocol or nil
    if protocol and type(protocol.GetClientCapabilities) == "function" then
        local ok, capabilities = pcall(protocol.GetClientCapabilities, protocol)
        if ok then
            return tonumber(capabilities) or 0
        end
    end

    return 0
end

local function GetProtocolCapabilitySnapshot()
    local protocol = type(DCAddonProtocol) == "table" and DCAddonProtocol or nil
    if not protocol or type(protocol.GetCapabilitySnapshot) ~= "function" then
        return nil
    end

    local ok, snapshot = pcall(protocol.GetCapabilitySnapshot, protocol)
    if not ok or type(snapshot) ~= "table" then
        return nil
    end

    return snapshot
end

local function IsCapabilityNegotiated(capability)
    local snapshot = GetProtocolCapabilitySnapshot()
    if not snapshot or not snapshot.connected then
        return false
    end

    return HasCapabilityBit(tonumber(snapshot.negotiatedCaps) or 0,
        capability)
end

local function HasNativeSpellTooltipBridge()
    if type(SetSpellTooltipEnrichmentEnabled) ~= "function"
        or type(ConfigureSpellTooltipEnrichment) ~= "function"
        or type(GetSpellTooltipEnrichmentStats) ~= "function" then
        return false
    end

    local capabilities = GetClientCapabilityMask()
    if capabilities > 0 then
        return HasCapabilityBit(capabilities, NATIVE_TOOLTIP_CAPABILITY)
    end

    return true
end

local function IsNativeSpellTooltipNegotiated()
    return IsCapabilityNegotiated(NATIVE_TOOLTIP_CAPABILITY)
end

local function HasNativeSpellTooltipAddonBridge()
    if type(RequestNativeSpellTooltipEnrichment) ~= "function"
        or type(PollNativeSpellTooltipEnrichment) ~= "function" then
        return false
    end

    local capabilities = GetClientCapabilityMask()
    if capabilities > 0 then
        return HasCapabilityBit(capabilities, NATIVE_TOOLTIP_CAPABILITY)
    end

    return true
end

local function HasNativeItemUpgradeBridge()
    if type(RequestNativeItemUpgradeTooltip) ~= "function"
        or type(GetNativeItemUpgradeTooltipData) ~= "function" then
        return false
    end

    local capabilities = GetClientCapabilityMask()
    if capabilities > 0 then
        return HasCapabilityBit(capabilities, NATIVE_ITEM_UPGRADE_CAPABILITY)
    end

    return true
end

local function NormalizeTooltipGuid(guid)
    if type(guid) ~= "string" or guid == "" then
        return nil
    end

    if string.sub(guid, 1, 2) ~= "0x" then
        return "0x" .. guid
    end

    return guid
end

local function GetNativeMouseoverTooltipGuid()
    if type(GetLastMouseoverGUIDHex) ~= "function" then
        return nil
    end

    local ok, guid = pcall(GetLastMouseoverGUIDHex)
    if not ok then
        return nil
    end

    guid = NormalizeTooltipGuid(guid)
    if not guid then
        return nil
    end

    local entry = ParseNpcFromGuid and select(1, ParseNpcFromGuid(guid))
    if not entry then
        return nil
    end

    return guid
end

local function HasNativeNpcTooltipBridge()
    if type(RequestNativeNpcTooltipInfo) ~= "function"
        or type(GetNativeNpcTooltipInfo) ~= "function" then
        return false
    end

    local capabilities = GetClientCapabilityMask()
    if capabilities > 0 then
        return HasCapabilityBit(capabilities, NATIVE_NPC_TOOLTIP_CAPABILITY)
    end

    return true
end

local function CoerceNativeBoolean(value)
    local valueType = type(value)

    if valueType == "boolean" then
        return value
    end

    if valueType == "number" then
        return value ~= 0
    end

    if valueType == "string" then
        local numeric = tonumber(value)
        if numeric ~= nil then
            return numeric ~= 0
        end

        local normalized = string.lower(value)
        if normalized == "true" then
            return true
        end
        if normalized == "false" then
            return false
        end
    end

    return value ~= nil and value ~= false
end

local function CaptureNativeSpellTooltipStats()
    if type(GetSpellTooltipEnrichmentStats) ~= "function" then
        return nil, "missing-native-stats-export"
    end

    local ok,
        enabled,
        sessionDisabled,
        timeoutMs,
        minRequestIntervalMs,
        maxConsecutiveTimeouts,
        consecutiveTimeouts,
        totalTimeouts,
        staleResponses,
        acceptedResponses,
        rejectedResponses = pcall(GetSpellTooltipEnrichmentStats)

    if not ok then
        return nil, tostring(enabled)
    end

    return {
        enabled = CoerceNativeBoolean(enabled),
        sessionDisabled = CoerceNativeBoolean(sessionDisabled),
        timeoutMs = tonumber(timeoutMs) or 0,
        minRequestIntervalMs = tonumber(minRequestIntervalMs) or 0,
        maxConsecutiveTimeouts = tonumber(maxConsecutiveTimeouts) or 0,
        consecutiveTimeouts = tonumber(consecutiveTimeouts) or 0,
        totalTimeouts = tonumber(totalTimeouts) or 0,
        staleResponses = tonumber(staleResponses) or 0,
        acceptedResponses = tonumber(acceptedResponses) or 0,
        rejectedResponses = tonumber(rejectedResponses) or 0,
    }, nil
end

local function ShouldUseNativeSpellTooltipBridge()
    if not HasNativeSpellTooltipBridge() then
        return false
    end

    if not IsNativeSpellTooltipNegotiated() then
        return false
    end

    local stats = CaptureNativeSpellTooltipStats()
    if stats ~= nil then
        if not stats.enabled or stats.sessionDisabled then
            return false
        end
    end

    return true
end

local function ShouldUseNativeSpellTooltipAddonBridge()
    if not HasNativeSpellTooltipAddonBridge() then
        return false
    end

    if not IsNativeSpellTooltipNegotiated() then
        return false
    end

    local stats = CaptureNativeSpellTooltipStats()
    if stats ~= nil and (not stats.enabled or stats.sessionDisabled) then
        return false
    end

    return true
end

local function ShouldUseNativeItemUpgradeBridge()
    return HasNativeItemUpgradeBridge()
        and IsCapabilityNegotiated(NATIVE_ITEM_UPGRADE_CAPABILITY)
end

local function ShouldUseNativeNpcTooltipBridge()
    return HasNativeNpcTooltipBridge()
        and IsCapabilityNegotiated(NATIVE_NPC_TOOLTIP_CAPABILITY)
end

local function CaptureNativeSpellTooltipRawState()
    if type(GetSpellTooltipEnrichmentRawState) ~= "function" then
        return nil, "missing-native-raw-export"
    end

    local ok,
        enabled,
        sessionDisabled,
        pendingTimedOut,
        hasResult,
        cachedResultCount,
        pendingRequestId,
        pendingSpellId,
        pendingContextHash,
        consecutiveTimeouts,
        totalTimeouts,
        staleResponses,
        acceptedResponses,
        rejectedResponses = pcall(GetSpellTooltipEnrichmentRawState)

    if not ok then
        return nil, tostring(enabled)
    end

    return {
        enabled = CoerceNativeBoolean(enabled),
        sessionDisabled = CoerceNativeBoolean(sessionDisabled),
        pendingTimedOut = CoerceNativeBoolean(pendingTimedOut),
        hasResult = CoerceNativeBoolean(hasResult),
        cachedResultCount = tonumber(cachedResultCount) or 0,
        pendingRequestId = tonumber(pendingRequestId) or 0,
        pendingSpellId = tonumber(pendingSpellId) or 0,
        pendingContextHash = tonumber(pendingContextHash) or 0,
        consecutiveTimeouts = tonumber(consecutiveTimeouts) or 0,
        totalTimeouts = tonumber(totalTimeouts) or 0,
        staleResponses = tonumber(staleResponses) or 0,
        acceptedResponses = tonumber(acceptedResponses) or 0,
        rejectedResponses = tonumber(rejectedResponses) or 0,
    }, nil
end

local function CaptureNativeSpellTooltipDebugString()
    if type(GetSpellTooltipEnrichmentDebugString) ~= "function" then
        return nil, "missing-native-debug-string-export"
    end

    local ok, debugString = pcall(GetSpellTooltipEnrichmentDebugString)
    if not ok then
        return nil, tostring(debugString)
    end

    if type(debugString) ~= "string" or debugString == "" then
        return nil, "empty-native-debug-string"
    end

    return debugString, nil
end

local function SyncNativeSpellTooltipBridge(reason)
    reason = tostring(reason or "sync")

    if not HasNativeSpellTooltipBridge() then
        lastNativeBridgeSync = {
            reason = reason,
            attemptedAt = time() or 0,
            desiredEnabled = false,
            tooltipsEnabled = false,
            communicationEnabled = false,
            negotiated = false,
            configureOk = false,
            toggleOk = false,
            readbackError = "missing-native-bridge-exports",
        }
        return false
    end

    local tooltipsEnabled = addon.settings
        and addon.settings.tooltips
        and addon.settings.tooltips.enabled
        and true or false
    local communicationEnabled = addon.settings
        and addon.settings.communication
        and addon.settings.communication.enabled
        and true or false
    local negotiated = IsNativeSpellTooltipNegotiated()
    local enabled = tooltipsEnabled
        and communicationEnabled
        and negotiated

    local configureOk, configureErr = pcall(ConfigureSpellTooltipEnrichment,
        NATIVE_TOOLTIP_TIMEOUT_MS,
        NATIVE_TOOLTIP_MIN_INTERVAL_MS,
        NATIVE_TOOLTIP_MAX_TIMEOUTS)

    local resetOk = true
    local resetErr = nil
    local toggleOk = true
    local toggleErr = nil

    if enabled then
        resetOk, resetErr = pcall(SetSpellTooltipEnrichmentEnabled, false)
        toggleOk, toggleErr = pcall(SetSpellTooltipEnrichmentEnabled, true)
    else
        toggleOk, toggleErr = pcall(SetSpellTooltipEnrichmentEnabled, false)
    end

    local stats, statsError = CaptureNativeSpellTooltipStats()
    local readbackEnabled = nil
    local readbackSessionDisabled = nil

    if stats ~= nil then
        readbackEnabled = stats.enabled and true or false
        readbackSessionDisabled = stats.sessionDisabled and true or false
    end

    lastNativeBridgeSync = {
        reason = reason,
        attemptedAt = time() or 0,
        desiredEnabled = enabled and true or false,
        tooltipsEnabled = tooltipsEnabled,
        communicationEnabled = communicationEnabled,
        negotiated = negotiated and true or false,
        configureOk = configureOk and true or false,
        configureError = configureOk and nil or tostring(configureErr),
        resetOk = resetOk and true or false,
        resetError = resetOk and nil or tostring(resetErr),
        toggleOk = toggleOk and true or false,
        toggleError = toggleOk and nil or tostring(toggleErr),
        readbackEnabled = readbackEnabled,
        readbackSessionDisabled = readbackSessionDisabled,
        readbackAcceptedResponses = stats and stats.acceptedResponses or nil,
        readbackRejectedResponses = stats and stats.rejectedResponses or nil,
        readbackStaleResponses = stats and stats.staleResponses or nil,
        readbackError = statsError,
    }

    return configureOk and toggleOk
end

local function RegisterProtocolCapabilityHook()
    if protocolCapabilityHookRegistered then
        return
    end

    local protocol = type(DCAddonProtocol) == "table" and DCAddonProtocol or nil
    if not protocol or type(protocol.RegisterCrossEventHandler) ~= "function" then
        return
    end

    protocol:RegisterCrossEventHandler(function(eventData)
        if type(eventData) ~= "table" or eventData.type ~= "core-handshake" then
            return
        end

        SyncNativeSpellTooltipBridge("core-handshake")

        if HasCapabilityBit(tonumber(eventData.negotiatedCaps) or 0,
            NATIVE_TOOLTIP_CAPABILITY) then
            QueueSpellEnrichmentPrefetch(1)
        end
    end)
    protocolCapabilityHookRegistered = true
end

local function GetNativeSpellTooltipBridgeSnapshot()
    local exportsPresent = type(SetSpellTooltipEnrichmentEnabled) == "function"
        and type(ConfigureSpellTooltipEnrichment) == "function"
        and type(GetSpellTooltipEnrichmentStats) == "function"
    local capabilitySnapshot = nil
    local protocol = type(DCAddonProtocol) == "table" and DCAddonProtocol or nil

    if protocol and type(protocol.GetCapabilitySnapshot) == "function" then
        local ok, snapshot = pcall(protocol.GetCapabilitySnapshot, protocol)
        if ok and type(snapshot) == "table" then
            capabilitySnapshot = snapshot
        end
    end

    local clientMask = tonumber((capabilitySnapshot and capabilitySnapshot.clientCaps)
        or GetClientCapabilityMask()) or 0
    local negotiatedMask = tonumber(capabilitySnapshot
        and capabilitySnapshot.negotiatedCaps) or 0

    local stats = nil
    local statsError = nil
    if exportsPresent then
        stats, statsError = CaptureNativeSpellTooltipStats()
    end

    local rawState = nil
    local rawStateError = nil
    if exportsPresent then
        rawState, rawStateError = CaptureNativeSpellTooltipRawState()
    end

    local rawDebugString = nil
    local rawDebugStringError = nil
    if exportsPresent then
        rawDebugString, rawDebugStringError =
            CaptureNativeSpellTooltipDebugString()
    end

    return {
        exportsPresent = exportsPresent,
        addonTransportExportsPresent =
            type(RequestNativeSpellTooltipEnrichment) == "function"
            and type(PollNativeSpellTooltipEnrichment) == "function",
        itemUpgradeExportsPresent =
            type(RequestNativeItemUpgradeTooltip) == "function"
            and type(GetNativeItemUpgradeTooltipData) == "function",
        npcTooltipExportsPresent =
            type(RequestNativeNpcTooltipInfo) == "function"
            and type(GetNativeNpcTooltipInfo) == "function",
        rawExportPresent = type(GetSpellTooltipEnrichmentRawState) == "function",
        rawDebugStringPresent = type(GetSpellTooltipEnrichmentDebugString) == "function",
        bridgeAvailable = HasNativeSpellTooltipBridge(),
        clientMask = clientMask,
        negotiatedMask = negotiatedMask,
        clientCapability = HasCapabilityBit(clientMask,
            NATIVE_TOOLTIP_CAPABILITY),
        negotiatedCapability = HasCapabilityBit(negotiatedMask,
            NATIVE_TOOLTIP_CAPABILITY),
        connected = capabilitySnapshot and capabilitySnapshot.connected and true
            or false,
        serverVersion = capabilitySnapshot and capabilitySnapshot.serverVersion,
        handshakeParserMode = capabilitySnapshot
            and capabilitySnapshot.lastHandshakeAck
            and capabilitySnapshot.lastHandshakeAck.parserMode,
        handshakeRawArg2 = capabilitySnapshot
            and capabilitySnapshot.lastHandshakeAck
            and capabilitySnapshot.lastHandshakeAck.rawArg2,
        handshakeRawArg3 = capabilitySnapshot
            and capabilitySnapshot.lastHandshakeAck
            and capabilitySnapshot.lastHandshakeAck.rawArg3,
        handshakeRawArg4 = capabilitySnapshot
            and capabilitySnapshot.lastHandshakeAck
            and capabilitySnapshot.lastHandshakeAck.rawArg4,
        nativeBuildFingerprint = capabilitySnapshot
            and capabilitySnapshot.nativeBuildFingerprint,
        nativeTooltipRuntimeSignature = capabilitySnapshot
            and capabilitySnapshot.nativeTooltipRuntimeSignature,
        lastBridgeSync = lastNativeBridgeSync,
        stats = stats,
        statsError = statsError,
        rawState = rawState,
        rawStateError = rawStateError,
        rawDebugString = rawDebugString,
        rawDebugStringError = rawDebugStringError,
    }
end

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

local function HasUnresolvedSpellPlaceholder(text)
    if type(text) ~= "string" or text == "" then
        return false
    end

    -- Common unresolved transport/template tokens from server descriptions.
    -- Examples: "$<percent>", "$s1", "$m2".
    if text:find("%$<[^>]+>") then return true end
    if text:find("%$[a-zA-Z]+%d+") then return true end
    return false
end

local function GetClientSpellDescription(spellId)
    local sid = tonumber(spellId)
    if not sid or sid <= 0 then
        return nil
    end

    if type(GetSpellDescription) ~= "function" then
        TelemetryInc("spell", "clientDescriptionMissingExport")
        return nil
    end

    local ok, description = pcall(function()
        return GetSpellDescription(sid)
    end)
    if not ok then
        TelemetryInc("spell", "clientDescriptionCallError")
        return nil
    end

    if description == nil then
        TelemetryInc("spell", "clientDescriptionNilReturn")
        return nil
    end

    if type(description) ~= "string" then
        TelemetryInc("spell", "clientDescriptionCallError")
        return nil
    end

    description = description:gsub("\r\n", "\n"):gsub("\r", "\n")
    description = description:gsub("^%s+", ""):gsub("%s+$", "")
    if description == "" then
        TelemetryInc("spell", "clientDescriptionEmptyBody")
        return nil
    end

    -- This client export can return raw Blizzard-style placeholders like $s1
    -- or $d for stance/presence/stealth spells. Showing that body is better
    -- than dropping the tooltip text entirely; only reject transport-only
    -- placeholder payloads such as $<percent>.
    if description:find("%$<[^>]+>") then
        TelemetryInc("spell", "clientDescriptionPlaceholderRejected")
        return nil
    end

    return description
end

local function HasNativeSpellTooltipRowsExport()
    return type(GetNativeSpellTooltipRows) == "function"
end

local function SetNativeSpellRowsRequestContext(tooltip, source, primaryIndex, secondary)
    if not tooltip then
        return
    end

    local numericPrimary = tonumber(primaryIndex)
    tooltip._dcqosNativeRowsSource = type(source) == "string" and source ~= ""
        and source or nil
    tooltip._dcqosNativeRowsPrimaryIndex = numericPrimary and numericPrimary > 0
        and numericPrimary or nil
    tooltip._dcqosNativeRowsSecondary = type(secondary) == "string" and secondary ~= ""
        and secondary or nil
end

local function EncodeNativeAuraRowsSecondary(unit, filter)
    local unitToken = type(unit) == "string" and unit ~= "" and unit or nil
    if not unitToken then
        return nil
    end

    local auraFilter = type(filter) == "string" and filter ~= ""
        and filter or nil
    if auraFilter then
        return unitToken .. "\t" .. auraFilter
    end

    return unitToken
end

local function ResolveNativeSpellRowsRequestContext(tooltip)
    if not tooltip then
        return { source = "hyperlink" }
    end

    local source = type(tooltip._dcqosNativeRowsSource) == "string"
        and tooltip._dcqosNativeRowsSource or "hyperlink"
    local primaryIndex = tonumber(tooltip._dcqosNativeRowsPrimaryIndex) or 0
    local secondary = type(tooltip._dcqosNativeRowsSecondary) == "string"
        and tooltip._dcqosNativeRowsSecondary or nil

    if source == "spellbook" and primaryIndex > 0 and secondary then
        return {
            source = source,
            primaryIndex = primaryIndex,
            secondary = secondary,
        }
    end

    if source == "unitaura" and primaryIndex > 0 and secondary then
        return {
            source = source,
            primaryIndex = primaryIndex,
            secondary = secondary,
        }
    end

    if (source == "shapeshift" or source == "petaction")
        and primaryIndex > 0 then
        return {
            source = source,
            primaryIndex = primaryIndex,
        }
    end

    return { source = "hyperlink" }
end

local function BuildNativeSpellTooltipRowsCacheKey(spellId, contextHash, request)
    request = type(request) == "table" and request or {}
    return table.concat({
        tostring(tonumber(spellId) or 0),
        tostring(tonumber(contextHash) or 0),
        tostring(request.source or "hyperlink"),
        tostring(tonumber(request.primaryIndex) or 0),
        tostring(request.secondary or ""),
    }, ":")
end

local function HasMeaningfulNativeSpellTooltipRows(rows)
    if type(rows) ~= "table" then
        return false
    end

    local meaningfulCount = 0
    local hasDoubleLine = false

    for _, rawEntry in ipairs(rows) do
        local entry = rawEntry
        if type(entry) ~= "table" then
            entry = { left = tostring(rawEntry or "") }
        end

        local left = NormalizeTooltipTextValue(entry.left or "")
        local right = NormalizeTooltipTextValue(entry.right or "")
        if left ~= "" or right ~= "" then
            if left ~= "spell id:" and not left:find("^server:") then
                meaningfulCount = meaningfulCount + 1
                if right ~= "" then
                    hasDoubleLine = true
                end
            end
        end
    end

    return hasDoubleLine or meaningfulCount >= 2
end

local function GetNativeClientSpellTooltipRows(tooltip, spellId, contextHash)
    local sid = tonumber(spellId)
    if not sid or sid <= 0 or not HasNativeSpellTooltipRowsExport() then
        return nil
    end

    local request = ResolveNativeSpellRowsRequestContext(tooltip)
    local cacheKey = BuildNativeSpellTooltipRowsCacheKey(sid, contextHash,
        request)
    local now = GetTime and GetTime() or 0
    local cached = nativeClientSpellRowsCache[cacheKey]
    if cached and now > 0 then
        local ttl = cached.ok and NATIVE_CLIENT_SPELL_ROWS_OK_TTL
            or NATIVE_CLIENT_SPELL_ROWS_ERR_TTL
        if (now - (tonumber(cached.checkedAt) or 0)) <= ttl then
            if cached.ok and type(cached.rows) == "table" then
                TelemetryInc("spell", "clientRowsCacheHit")
                return cached.rows
            end
            return nil
        end
    end

    local ok, rows = pcall(GetNativeSpellTooltipRows, sid, request.source,
        request.primaryIndex, request.secondary)
    if not ok then
        TelemetryInc("spell", "clientRowsCallError")
        nativeClientSpellRowsCache[cacheKey] = {
            ok = false,
            checkedAt = now,
        }
        addon:Debug("Native spell tooltip row probe failed: " .. tostring(rows))
        return nil
    end

    local hasRows = HasMeaningfulNativeSpellTooltipRows(rows)
    TelemetryInc("spell", hasRows and "clientRowsSatisfied" or "clientRowsEmpty")
    nativeClientSpellRowsCache[cacheKey] = {
        ok = hasRows,
        checkedAt = now,
        rows = hasRows and rows or nil,
    }
    return hasRows and rows or nil
end

local function RenderNativeClientSpellTooltipRows(tooltip, rows)
    if not tooltip or type(rows) ~= "table" or type(tooltip.AddLine) ~= "function" then
        return false
    end

    local existing = BuildExistingTooltipTextSet(tooltip)
    local addedAny = false

    local function resolveLineColor(entry, prefix)
        local r = tonumber(entry[prefix .. "R"])
        local g = tonumber(entry[prefix .. "G"])
        local b = tonumber(entry[prefix .. "B"])
        if r and g and b then
            return r, g, b
        end

        local classification = tostring(entry.classification or "")
        if classification == "body" then
            return 1.0, 0.82, 0.0
        end
        if classification == "subtext" or classification == "meta-pair" then
            return 0.8, 0.8, 0.8
        end
        if classification == "warning" then
            return 1.0, 0.12, 0.12
        end
        if classification == "success" then
            return 0.25, 1.0, 0.25
        end
        return 1.0, 1.0, 1.0
    end

    for _, rawEntry in ipairs(rows) do
        local entry = rawEntry
        if type(entry) ~= "table" then
            entry = { left = tostring(rawEntry or "") }
        end

        local left = tostring(entry.left or "")
        local right = entry.right ~= nil and tostring(entry.right) or nil
        local leftNorm = NormalizeTooltipTextValue(left)
        local rightNorm = NormalizeTooltipTextValue(right or "")
        local key = leftNorm .. "||" .. rightNorm

        if leftNorm ~= ""
            and leftNorm ~= "spell id:"
            and not leftNorm:find("^server:")
            and not existing[key]
            and not existing[leftNorm] then
            local leftR, leftG, leftB = resolveLineColor(entry, "left")
            local rightR, rightG, rightB = resolveLineColor(entry, "right")
            local classification = tostring(entry.classification or "")

            if not addedAny then
                tooltip:AddLine(" ")
            end

            if right and right ~= "" and type(tooltip.AddDoubleLine) == "function" then
                tooltip:AddDoubleLine(left, right,
                    leftR, leftG, leftB,
                    rightR, rightG, rightB)
            else
                tooltip:AddLine(left, leftR, leftG, leftB, true)
            end

            addedAny = true
            existing[key] = true
            existing[leftNorm] = true
            if rightNorm ~= "" then
                existing[rightNorm] = true
            end
        end
    end

    return addedAny
end

local function AddClientSpellDescriptionLines(tooltip, description)
    if not tooltip or type(description) ~= "string" or description == ""
        or type(tooltip.AddLine) ~= "function" then
        return false
    end

    local existing = BuildExistingTooltipTextSet(tooltip)
    local addedAny = false

    for line in string.gmatch(description, "([^\n]+)") do
        local text = tostring(line or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local normalized = NormalizeTooltipTextValue(text)
        if normalized ~= "" and not existing[normalized] then
            if not addedAny then
                tooltip:AddLine(" ")
            end

            tooltip:AddLine(text, 1.0, 0.82, 0.0, true)
            existing[normalized] = true
            addedAny = true
        end
    end

    return addedAny
end

local function EnrichmentHasUnresolvedBodyPlaceholders(enrichment)
    if type(enrichment) ~= "table" or type(enrichment.lines) ~= "table" then
        return false
    end

    for _, rawEntry in ipairs(enrichment.lines) do
        local entry = rawEntry
        if type(entry) ~= "table" then
            entry = { left = tostring(rawEntry or "") }
        end

        local kind = entry.kind
        if kind == nil or kind == "body" then
            local left = tostring(entry.left or "")
            local right = entry.right ~= nil and tostring(entry.right) or ""
            if HasUnresolvedSpellPlaceholder(left) or HasUnresolvedSpellPlaceholder(right) then
                return true
            end
        end
    end

    return false
end

local function HasRenderableEnrichmentLines(enrichment, renderMode)
    if type(enrichment) ~= "table" or type(enrichment.lines) ~= "table" then
        return false
    end

    for _, rawEntry in ipairs(enrichment.lines) do
        local entry = rawEntry
        if type(entry) ~= "table" then
            entry = { left = tostring(rawEntry or "") }
        end

        local left = tostring(entry.left or "")
        local right = entry.right ~= nil and tostring(entry.right) or nil
        local kind = entry.kind

        if not (renderMode == "replace-native-description" and kind ~= "body")
            and not (renderMode == "append-nonbody" and kind == "body")
            and not IsRawServerMetadataLine(left)
            and not IsRawServerMetadataLine(right or "")
            and not HasUnresolvedSpellPlaceholder(left)
            and not HasUnresolvedSpellPlaceholder(right or "") then
            local leftNorm = NormalizeTooltipTextValue(left)
            if leftNorm ~= "" then
                return true
            end
        end
    end

    return false
end

local SPELL_TOOLTIP_SOURCE_TAG_MAX_AGE = 0.75

local function MarkSpellTooltipSource(tooltip, source)
    if not tooltip then return end
    tooltip._dcqosSpellSource = source
    tooltip._dcqosSpellSourceAt = GetTime and GetTime() or 0
end

local function IsActionTooltipOwner(owner)
    if type(owner) ~= "table" then
        return false
    end

    if owner.action ~= nil then
        return true
    end

    local ownerName = owner.GetName and owner:GetName() or ""
    if ownerName == "" then
        return false
    end

    if ownerName:find("^ActionButton%d+$")
        or ownerName:find("^MultiBar.+Button%d+$")
        or ownerName:find("^BonusActionButton%d+$")
        or ownerName:find("^PetActionButton%d+$")
        or ownerName:find("^ShapeshiftButton%d+$")
        or ownerName:find("^VehicleMenuBarActionButton%d+$")
        or ownerName:find("^PossessButton%d+$") then
        return true
    end

    return false
end

local function IsSpellbookTooltipOwner(owner)
    if type(owner) ~= "table" then
        return false
    end

    local ownerName = owner.GetName and owner:GetName() or ""
    if ownerName == "" then
        return false
    end

    if ownerName:find("SpellBook")
        or ownerName:find("^SpellButton%d+$")
        or ownerName:find("^PetSpellButton%d+$") then
        return true
    end

    return false
end

local function InferSpellTooltipSource(tooltip)
    if not tooltip or type(tooltip.GetOwner) ~= "function" then
        return "blizzlike"
    end

    local owner = tooltip:GetOwner()
    if IsSpellbookTooltipOwner(owner) then
        return "spellbook"
    end
    if IsActionTooltipOwner(owner) then
        return "action"
    end

    return "blizzlike"
end

local function ResolveSpellTooltipSource(tooltip)
    if not tooltip then
        return "blizzlike"
    end

    local source = tooltip._dcqosSpellSource
    local sourceAt = tonumber(tooltip._dcqosSpellSourceAt) or 0
    local now = GetTime and GetTime() or 0
    if (source == "action" or source == "spellbook" or source == "blizzlike"
        or source == "aura")
        and sourceAt > 0
        and (now - sourceAt) <= SPELL_TOOLTIP_SOURCE_TAG_MAX_AGE then
        return source
    end

    source = InferSpellTooltipSource(tooltip)
    MarkSpellTooltipSource(tooltip, source)
    return source
end

local function GetSpellTooltipRenderMode(tooltip, clientDescription)
    local source = tooltip and tooltip._dcqosSpellSource or nil
    if source == "action" then
        if type(clientDescription) == "string" and clientDescription ~= "" then
            return "append-nonbody"
        end
        return "full"
    end
    if source == "aura" then
        if type(clientDescription) == "string" and clientDescription ~= "" then
            return "append-nonbody"
        end
        return "full"
    end
    if source == "spellbook" then
        if type(clientDescription) == "string" and clientDescription ~= "" then
            return "append-nonbody"
        end
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
            local reqId = pending and tonumber(pending.requestId) or 0
            if reqId > 0 and pendingSpellEnrichmentByRequestId[reqId] == key then
                pendingSpellEnrichmentByRequestId[reqId] = nil
            end
            pendingSpellEnrichment[key] = nil
        end
    end

    for reqId, mappedKey in pairs(pendingSpellEnrichmentByRequestId) do
        if not pendingSpellEnrichment[mappedKey] then
            pendingSpellEnrichmentByRequestId[reqId] = nil
        end
    end

    for key, attemptAt in pairs(lastSpellEnrichmentAttemptAt) do
        if (tonumber(attemptAt) or 0) <= 0 or (now - attemptAt) > SPELL_TOOLTIP_TRACKING_STALE_TTL then
            lastSpellEnrichmentAttemptAt[key] = nil
        end
    end

    lastSpellEnrichmentPruneAt = now
end

local function StoreSpellTooltipEnrichmentResult(data)
    local requestId = tonumber(data and data.requestId) or 0
    local spellId = tonumber(data and data.spellId) or 0
    local contextHash = tonumber(data and data.contextHash) or 0
    local status = tonumber(data and data.status) or 0
    local line = tostring(data and data.line or "")

    local enrichment = {
        requestId = requestId,
        spellId = spellId,
        contextHash = contextHash,
        status = status,
        line = line,
        lines = type(data and data.lines) == "table" and data.lines or nil,
        title = data and data.title,
        source = data and data.source,
        receivedAt = GetTime(),
    }

    if status == 0 and (type(enrichment.lines) ~= "table" or #enrichment.lines == 0)
        and line ~= "" then
        enrichment.lines = {
            { left = line, kind = "body" }
        }
    end

    if addon.tooltipCache and spellId > 0 and contextHash > 0 then
        PruneSpellEnrichmentCache(GetTime())
        addon.tooltipCache.spellEnrichment = addon.tooltipCache.spellEnrichment or {}
        addon.tooltipCache.spellEnrichment[spellId] = addon.tooltipCache.spellEnrichment[spellId] or {}
        addon.tooltipCache.spellEnrichment[spellId][contextHash] = enrichment
    end

    return enrichment
end

local function TryConsumeNativeSpellTooltipEnrichment(spellId, contextHash)
    if type(PollNativeSpellTooltipEnrichment) ~= "function" then
        return false
    end

    local sid = tonumber(spellId) or 0
    local ctx = tonumber(contextHash) or 0
    if sid <= 0 or ctx <= 0 then
        return false
    end

    local key = BuildSpellEnrichmentKey(sid, ctx)
    local pending = pendingSpellEnrichment[key]
    if not pending then
        return false
    end

    local ok, nativeStatus, line, structuredLines =
        pcall(PollNativeSpellTooltipEnrichment, sid, ctx)
    if not ok then
        TelemetryInc("spell", "nativeErrors")
        addon:Debug("Native spell tooltip poll failed: " .. tostring(nativeStatus))
        return false
    end

    nativeStatus = tonumber(nativeStatus) or NATIVE_SPELL_TOOLTIP_STATUS_UNAVAILABLE
    if nativeStatus == NATIVE_SPELL_TOOLTIP_STATUS_PENDING
        or nativeStatus == NATIVE_SPELL_TOOLTIP_STATUS_UNAVAILABLE then
        return false
    end

    if nativeStatus == NATIVE_SPELL_TOOLTIP_STATUS_READY then
        TelemetryInc("spell", "nativeResponsesReady")
        addon:FireEvent("SPELL_TOOLTIP_ENRICHMENT_RECEIVED",
            StoreSpellTooltipEnrichmentResult({
                requestId = pending.requestId,
                spellId = sid,
                contextHash = ctx,
                status = 0,
                line = type(line) == "string" and line or "",
                lines = type(structuredLines) == "table" and structuredLines or nil,
                source = "native-v2",
            }))
        return true
    end

    TelemetryInc("spell", "nativeErrors")
    addon:FireEvent("SPELL_TOOLTIP_ENRICHMENT_RECEIVED",
        StoreSpellTooltipEnrichmentResult({
            requestId = pending.requestId,
            spellId = sid,
            contextHash = ctx,
            status = 1,
            line = type(line) == "string" and line or "",
            source = "native-v2-error",
        }))
    return true
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
            and not (renderMode == "append-nonbody" and kind == "body")
            and not IsRawServerMetadataLine(left)
            and not IsRawServerMetadataLine(right or "")
            and not HasUnresolvedSpellPlaceholder(left)
            and not HasUnresolvedSpellPlaceholder(right or "") then
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
    local hasNativeRowsExport = HasNativeSpellTooltipRowsExport()
    if not hasNativeRowsExport and (not addon.protocol or not addon.protocol.connected) then return false end

    local sid = tonumber(spellId)
    if not sid or sid <= 0 then return false end

    local tooltipSource = ResolveSpellTooltipSource(tooltip)
    local nativeSpellTooltipNegotiated = IsNativeSpellTooltipNegotiated()
    local nativeSpellTooltipAddonAvailable = tooltipSource ~= "spellbook"
        and nativeSpellTooltipNegotiated
        and HasNativeSpellTooltipAddonBridge()
    local useNativeAddonTransport = tooltipSource ~= "spellbook"
        and ShouldUseNativeSpellTooltipAddonBridge()

    if tooltipSource == "spellbook" and nativeSpellTooltipNegotiated
        and not hasNativeRowsExport then
        return false
    end

    local contextHash = BuildSpellTooltipContextHash(sid)
    local key = BuildSpellEnrichmentKey(sid, contextHash)
    local now = GetTime()
    local clientDescription = nil
    local renderMode = GetSpellTooltipRenderMode(tooltip, nil)

    if renderMode ~= "disabled" then
        clientDescription = GetClientSpellDescription(sid)
        renderMode = GetSpellTooltipRenderMode(tooltip, clientDescription)
    end

    if renderMode == "disabled" then
        TelemetryInc("spell", "skippedRenderModeDisabled")
        return false
    end

    PruneSpellEnrichmentTracking(now)

    tooltip._dcqosActiveSpellKey = key

    if renderMode == "append-nonbody"
        and type(clientDescription) == "string"
        and clientDescription ~= ""
        and tooltip._dcqosClientDescriptionShownKey ~= key then
        AddClientSpellDescriptionLines(tooltip, clientDescription)
        tooltip._dcqosClientDescriptionShownKey = key
    end

    if tooltip._dcqosSpellEnrichmentShownKey == key then
        return true  -- already shown from a previous render this session
    end

    local nativeRows = GetNativeClientSpellTooltipRows(tooltip, sid, contextHash)
    if nativeRows then
        local renderedNativeRows = RenderNativeClientSpellTooltipRows(tooltip,
            nativeRows)
        TelemetryInc("spell", renderedNativeRows and "clientRowsRendered"
            or "clientRowsAlreadyPresent")
        tooltip._dcqosSpellEnrichmentShownKey = key
        return true
    end

    local cached = addon.GetSpellTooltipEnrichment and addon:GetSpellTooltipEnrichment(sid, contextHash) or nil
    local cachedAge = cached and (now - (tonumber(cached.receivedAt) or now)) or nil

    local renderedFromCache = false
    if cached and cached.status == 0 and cachedAge and cachedAge <= SPELL_TOOLTIP_ENRICHMENT_OK_TTL then
        if renderMode == "replace-native-description"
            and tooltip._dcqosNativeDescriptionStrippedKey ~= key
            and HasRenderableEnrichmentLines(cached, renderMode) then
            StripNativeSpellDescriptionLines(tooltip)
            tooltip._dcqosNativeDescriptionStrippedKey = key
        end

        renderedFromCache = RenderSpellEnrichmentLines(tooltip, cached, renderMode)
        if renderedFromCache or (renderMode == "append-nonbody"
            and not HasRenderableEnrichmentLines(cached, renderMode)) then
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
            local reqId = pending and tonumber(pending.requestId) or 0
            if reqId > 0 and pendingSpellEnrichmentByRequestId[reqId] == key then
                pendingSpellEnrichmentByRequestId[reqId] = nil
            end
            pendingSpellEnrichment[key] = nil
            TelemetryInc("spell", "pendingTimeoutRecoveries")
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
        pendingSpellEnrichmentByRequestId[requestId] = key
        lastSpellEnrichmentAttemptAt[key] = now
        lastSpellEnrichmentSendAt = now
        TelemetryInc("spell", "requestsSent")

        local ok = false
        if useNativeAddonTransport then
            local nativeOk, nativeErr = pcall(RequestNativeSpellTooltipEnrichment,
                sid, contextHash)
            if nativeOk then
                TelemetryInc("spell", "nativeRequestsSent")
                ok = true
            else
                TelemetryInc("spell", "nativeErrors")
                addon:Debug("Native spell tooltip request failed: " .. tostring(nativeErr))
            end
        end

        if not ok and not nativeSpellTooltipAddonAvailable then
            ok = addon:RequestSpellTooltipEnrichment(requestId, sid, contextHash, false)
        end
        if not ok then
            pendingSpellEnrichment[key] = nil
            pendingSpellEnrichmentByRequestId[requestId] = nil
            TelemetryInc("spell", "requestSendFailures")
            return false  -- request failed, no callback expected
        end
        return nil  -- request sent; callback will deliver lines and Spell ID
    end
end

local function OnSpellTooltipEnrichmentReceived(data)
    if type(data) ~= "table" then return end
    TelemetryInc("spell", "responsesReceived")

    local sid = tonumber(data.spellId) or 0
    local contextHash = tonumber(data.contextHash) or 0
    if sid <= 0 or contextHash <= 0 then return end

    local key = BuildSpellEnrichmentKey(sid, contextHash)
    local pending = pendingSpellEnrichment[key]
    local responseReqId = tonumber(data.requestId) or 0

    if not pending and responseReqId > 0 then
        local mappedKey = pendingSpellEnrichmentByRequestId[responseReqId]
        if mappedKey then
            pending = pendingSpellEnrichment[mappedKey]
            if pending then
                key = mappedKey
                TelemetryInc("spell", "responsesRemappedByRequestId")

                local _, mappedContext = string.match(mappedKey, "^(%d+):(%d+)$")
                local mappedCtxNum = tonumber(mappedContext)
                if mappedCtxNum and mappedCtxNum > 0 then
                    contextHash = mappedCtxNum
                    data.contextHash = mappedCtxNum
                end
            end
        end
    end

    if not pending and responseReqId > 0 then
        TelemetryInc("spell", "responsesWithoutPending")
    end

    if pending then
        if responseReqId > 0 then
            if responseReqId ~= pending.requestId then
                TelemetryInc("spell", "responseRequestIdMismatch")
                return
            end
            pendingSpellEnrichmentByRequestId[responseReqId] = nil
            pendingSpellEnrichment[key] = nil
        end
    end

    local status = tonumber(data.status) or 0
    if status == 0 then
        TelemetryInc("spell", "responsesSuccess")
    else
        TelemetryInc("spell", "responsesError")
    end

    -- Clear retry backoff on any response so immediate re-render stays snappy.
    lastSpellEnrichmentAttemptAt[key] = nil

    if GameTooltip and GameTooltip:IsShown() and GameTooltip._dcqosActiveSpellKey == key then
        if status == 0 then
            -- Avoid duplicate redraw churn if repeated responses arrive
            -- for the same active tooltip key.
            if GameTooltip._dcqosSpellEnrichmentShownKey == key then
                return
            end

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
local lastSpellPrefetchQueuedAt = 0
local StartSpellEnrichmentPrefetch

QueueSpellEnrichmentPrefetch = function(delay)
    if IsNativeSpellTooltipNegotiated() or HasNativeSpellTooltipRowsExport() then
        return
    end

    local now = GetTime and GetTime() or 0
    if now > 0 and lastSpellPrefetchQueuedAt > 0 and (now - lastSpellPrefetchQueuedAt) < 2.0 then
        return
    end
    lastSpellPrefetchQueuedAt = now
    if type(StartSpellEnrichmentPrefetch) == "function" then
        addon:DelayedCall(delay or 1, StartSpellEnrichmentPrefetch)
    end
end

StartSpellEnrichmentPrefetch = function()
    if IsNativeSpellTooltipNegotiated() or HasNativeSpellTooltipRowsExport() then return end
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

    TelemetryInc("spell", "prefetchRuns")

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
                TelemetryInc("spell", "prefetchRequestsSent")
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

local function ResolveAuraTooltipSpellId(tooltip)
    if not tooltip then
        return nil
    end

    local spellId = nil
    if type(tooltip.GetSpell) == "function" then
        local _, _, directSpellId = tooltip:GetSpell()
        spellId = tonumber(directSpellId)
    end

    if (not spellId or spellId <= 0) then
        spellId = ResolveSpellIdFromTooltipName(tooltip)
    end

    return spellId
end

local function TrackAuraTooltipContext(tooltip, unit, index, filter, isDebuff)
    if not tooltip then
        return
    end

    MarkSpellTooltipSource(tooltip, "aura")

    local auraIndex = tonumber(index)
    local secondary = EncodeNativeAuraRowsSecondary(unit, filter)
    if auraIndex and auraIndex > 0 and secondary then
        SetNativeSpellRowsRequestContext(tooltip, "unitaura", auraIndex,
            secondary)
    else
        SetNativeSpellRowsRequestContext(tooltip, "hyperlink")
    end

    local spellId = nil
    local unitToken = type(unit) == "string" and unit ~= "" and unit or nil
    if unitToken and auraIndex and auraIndex > 0 then
        local auraName = nil
        if isDebuff and type(UnitDebuff) == "function" then
            auraName = select(1, UnitDebuff(unitToken, auraIndex, filter))
            spellId = tonumber(select(11, UnitDebuff(unitToken, auraIndex,
                filter)))
        elseif not isDebuff and type(UnitBuff) == "function" then
            auraName = select(1, UnitBuff(unitToken, auraIndex, filter))
            spellId = tonumber(select(11, UnitBuff(unitToken, auraIndex,
                filter)))
        elseif type(UnitAura) == "function" then
            auraName = select(1, UnitAura(unitToken, auraIndex, filter))
            spellId = tonumber(select(11, UnitAura(unitToken, auraIndex,
                filter)))
        end

        if (not spellId or spellId <= 0) and auraName and auraName ~= "" then
            spellId = ResolveSpellIdFromTooltipName(nil, auraName)
        end
    end

    if (not spellId or spellId <= 0) then
        spellId = ResolveAuraTooltipSpellId(tooltip)
    end
    if spellId and spellId > 0 then
        tooltip._dcqosResolvedSpellId = spellId
        EnhanceSpellTooltip(tooltip, spellId)
    end
end

-- ============================================================
-- NPC ID in Tooltips (with DB GUID from server)
-- ============================================================
local npcInfoCache = {}       -- Cache server-provided NPC info
local pendingNpcRequests = {} -- Track pending requests
local NPC_INFO_CACHE_DURATION = 300
local NPC_INFO_PENDING_TIMEOUT = 5.0
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
    guid = NormalizeTooltipGuid(guid)
    if not guid then return end
    local now = GetTime()

    local pendingAt = tonumber(pendingNpcRequests[guid]) or 0
    if pendingAt > 0 and (now - pendingAt) < NPC_INFO_PENDING_TIMEOUT then
        return
    end
    if pendingAt > 0 and (now - pendingAt) >= NPC_INFO_PENDING_TIMEOUT then
        pendingNpcRequests[guid] = nil
        TelemetryInc("npc", "pendingTimeoutRecoveries")
    end

    local cached = npcInfoCache[guid]
    if cached and (now - (tonumber(cached.timestamp) or 0)) < NPC_INFO_CACHE_DURATION then
        return
    end
    if cached then
        npcInfoCache[guid] = nil
    end
    
    pendingNpcRequests[guid] = now
    TelemetryInc("npc", "requestsSent")

    if addon.protocol and addon.protocol.connected then
        if ShouldUseNativeNpcTooltipBridge() then
            local ok, nativeDispatched = pcall(RequestNativeNpcTooltipInfo,
                guid)
            if ok and nativeDispatched ~= false then
                TelemetryInc("npc", "nativeRequestsSent")
                return
            end

            TelemetryInc("npc", "nativeFallbacks")
            if not ok then
                TelemetryInc("npc", "nativeErrors")
                addon:Debug("Native NPC tooltip request failed: "
                    .. tostring(nativeDispatched))
            else
                addon:Debug("Native NPC tooltip request not dispatched; falling back to addon protocol")
            end
        end

        addon.protocol:RequestNpcInfo(guid)
    end
end

local function TryConsumeNativeNpcInfo(guid)
    guid = NormalizeTooltipGuid(guid)
    if not guid or not pendingNpcRequests[guid]
        or type(GetNativeNpcTooltipInfo) ~= "function" then
        return false
    end

    local ok, entry, spawnId, dbGuid, errorMessage =
        pcall(GetNativeNpcTooltipInfo, guid)
    if not ok then
        TelemetryInc("npc", "nativeErrors")
        addon:Debug("Native NPC tooltip poll failed: " .. tostring(entry))
        return false
    end

    if entry == nil then
        return false
    end

    TelemetryInc("npc", "nativeResponsesReady")
    addon:FireEvent("NPC_INFO_RECEIVED", {
        guid = guid,
        entry = tonumber(entry) or 0,
        spawnId = tonumber(spawnId) or 0,
        dbGuid = tonumber(dbGuid) or 0,
        error = type(errorMessage) == "string" and errorMessage ~= ""
            and errorMessage or nil,
    })
    return true
end

-- Handle NPC info received from server
local function OnNpcInfoReceived(npcData)
    if not npcData or not npcData.guid then return end
    TelemetryInc("npc", "responsesReceived")
    
    local guid = npcData.guid
    -- Normalize GUID to match UnitGUID format (0x prefix)
    if string.sub(guid, 1, 2) ~= "0x" then
        guid = "0x" .. guid
    end
    
    pendingNpcRequests[guid] = nil

    if npcData.error then
        npcInfoCache[guid] = nil
        return
    end

    npcInfoCache[guid] = {
        timestamp = GetTime(),
        spawnId = npcData.spawnId,
        entry = npcData.entry,
        dbGuid = npcData.dbGuid or npcData.spawnGuid,
    }
    
    -- Don't force refresh to avoid lag
    -- Data will appear on next natural tooltip update
end

-- Register for NPC info events
addon:RegisterEvent("NPC_INFO_RECEIVED", OnNpcInfoReceived)

local function AddNpcId(tooltip, unit, guidOverride)
    if not addon.settings.tooltips.showNpcId then return end
    if not unit and not guidOverride then return end
    if unit and UnitIsPlayer(unit) then return end
    
    local guid = guidOverride or UnitGUID(unit)
    guid = NormalizeTooltipGuid(guid)
    if not guid then return end
    
    -- Avoid duplicate lines
    if tooltip._dcqosNpcGuid == guid then return end
    tooltip._dcqosNpcGuid = guid
    
    -- Parse local NPC info
    local entry, localSpawnId = ParseNpcFromGuid(guid)
    local unitName = unit and UnitName(unit) or nil
    if entry and unitName then
        CacheNpcNameByEntry(entry, unitName)
    end
    
    -- Check server cache for more accurate info
    if ShouldUseNativeNpcTooltipBridge() then
        TryConsumeNativeNpcInfo(guid)
    end

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

local nativeTooltipPollFrame = nil
local nativeTooltipPollElapsed = 0
local NATIVE_TOOLTIP_POLL_INTERVAL = 0.05

local function RefreshTrackedTooltip(tooltip)
    if not tooltip or tooltip ~= GameTooltip or not tooltip.IsShown or not tooltip:IsShown() then
        return false
    end

    local refreshKind = tooltip._dcqosRefreshKind
    if refreshKind == "bag" and tooltip.SetBagItem then
        local bag = tonumber(tooltip._dcqosRefreshBag)
        local slot = tonumber(tooltip._dcqosRefreshSlot)
        if bag ~= nil and slot ~= nil then
            tooltip:SetBagItem(bag, slot)
            return true
        end
    elseif refreshKind == "inventory" and tooltip.SetInventoryItem then
        local unit = tooltip._dcqosRefreshUnit
        local slot = tonumber(tooltip._dcqosRefreshSlot)
        if unit and slot ~= nil and UnitExists(unit) then
            tooltip:SetInventoryItem(unit, slot)
            return true
        end
    elseif refreshKind == "unit" and tooltip.SetUnit then
        local unit = tooltip._dcqosRefreshUnit
        if unit and UnitExists(unit) then
            tooltip:SetUnit(unit)
            return true
        end
    end

    return false
end

local function PollActiveNativeTooltipData(tooltip)
    if not tooltip or tooltip ~= GameTooltip or not tooltip.IsShown or not tooltip:IsShown() then
        return false
    end

    local refreshed = false
    local refreshKind = tooltip._dcqosRefreshKind

    if refreshKind == "bag" and ShouldUseNativeItemUpgradeBridge() then
        local bag = tonumber(tooltip._dcqosRefreshBag)
        local slot = tonumber(tooltip._dcqosRefreshSlot)
        if bag ~= nil and slot ~= nil then
            local serverBag = GetServerBagFromClient(bag)
            local serverSlot = GetServerSlotFromClient(bag, slot)
            if TryConsumeNativeUpgradeInfo(serverBag, serverSlot) then
                refreshed = RefreshTrackedTooltip(tooltip) or refreshed
            end
        end
    elseif refreshKind == "inventory" and ShouldUseNativeItemUpgradeBridge() then
        local unit = tooltip._dcqosRefreshUnit
        local slot = tonumber(tooltip._dcqosRefreshSlot)
        if unit == "player" and slot ~= nil then
            local serverBag = GetServerBagFromClient(-2)
            local serverSlot = GetServerSlotFromClient(-2, slot)
            if TryConsumeNativeUpgradeInfo(serverBag, serverSlot) then
                refreshed = RefreshTrackedTooltip(tooltip) or refreshed
            end
        end
    elseif refreshKind == "unit" and ShouldUseNativeNpcTooltipBridge() then
        local unit = tooltip._dcqosRefreshUnit
        local guid = unit and UnitExists(unit) and UnitGUID(unit) or nil
        if guid and TryConsumeNativeNpcInfo(guid) then
            refreshed = RefreshTrackedTooltip(tooltip) or refreshed
        end
    end

    if ShouldUseNativeSpellTooltipAddonBridge() then
        local key = tooltip._dcqosActiveSpellKey
        local spellId, contextHash = nil, nil
        if type(key) == "string" then
            spellId, contextHash = string.match(key, "^(%d+):(%d+)$")
        end
        if spellId and contextHash and pendingSpellEnrichment[key]
            and TryConsumeNativeSpellTooltipEnrichment(tonumber(spellId), tonumber(contextHash)) then
            refreshed = true
        end
    end

    return refreshed
end

local function EnsureNativeTooltipPollFrame()
    if nativeTooltipPollFrame then
        return
    end

    nativeTooltipPollFrame = CreateFrame("Frame")
    nativeTooltipPollFrame:SetScript("OnUpdate", function(_, elapsed)
        nativeTooltipPollElapsed = nativeTooltipPollElapsed + (tonumber(elapsed) or 0)
        if nativeTooltipPollElapsed < NATIVE_TOOLTIP_POLL_INTERVAL then
            return
        end

        nativeTooltipPollElapsed = 0
        PollActiveNativeTooltipData(GameTooltip)
    end)
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
        self._dcqosRefreshKind = "bag"
        self._dcqosRefreshBag = bag
        self._dcqosRefreshSlot = slot
        self._dcqosRefreshUnit = nil
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
            AddItemTooltipDetails(self, itemLink)
            AddUpgradeInfo(self, bag, slot, itemLink)
        end
    end)

    HookTooltipMethodOnce("_dcqosHookedSetInventoryItem", "SetInventoryItem", function(self, unit, slot, ...)
        self._dcqosRefreshKind = "inventory"
        self._dcqosRefreshUnit = unit
        self._dcqosRefreshBag = nil
        self._dcqosRefreshSlot = slot
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

    local function ResetTooltipTransientState(self)
        self._dcqosNpcGuid = nil
        self._dcqosUpgradeShown = nil
        self._dcqosRefreshKind = nil
        self._dcqosRefreshBag = nil
        self._dcqosRefreshSlot = nil
        self._dcqosRefreshUnit = nil
        self._dcqosRefreshNpcGuid = nil
        self._dcqosResolvedSpellId = nil
        self._dcqosSpellSource = nil
        self._dcqosSpellSourceAt = nil
        self._dcqosSpellIdShown = nil
        self._dcqosLastEnhancedSpellId = nil
        self._dcqosLastEnhancedSpellAt = nil
        self._dcqosActiveSpellKey = nil
        self._dcqosClientDescriptionShownKey = nil
        self._dcqosSpellEnrichmentShownKey = nil
        self._dcqosNativeDescriptionStrippedKey = nil
        self._dcqosPendingSpellIdForBottom = nil
        self._dcqosNpcKillShown = nil
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
                self._dcqosRefreshKind = "unit"
                self._dcqosRefreshUnit = unit
                self._dcqosRefreshBag = nil
                self._dcqosRefreshSlot = nil
                self._dcqosRefreshNpcGuid = nil
                EnhanceUnitTooltip(self, unit)
            else
                local guid = GetNativeMouseoverTooltipGuid()
                if guid then
                    self._dcqosRefreshKind = nil
                    self._dcqosRefreshUnit = nil
                    self._dcqosRefreshBag = nil
                    self._dcqosRefreshSlot = nil
                    self._dcqosRefreshNpcGuid = guid
                    AddNpcId(self, nil, guid)
                end
            end
        end)
    end
    
    -- Reset NPC GUID flag and upgrade flag when tooltip is cleared
    if not GameTooltip._dcqosHookedOnTooltipCleared then
        GameTooltip._dcqosHookedOnTooltipCleared = true
        GameTooltip:HookScript("OnTooltipCleared", function(self)
            ResetTooltipTransientState(self)
        end)
    end

    if not GameTooltip._dcqosHookedOnHide then
        GameTooltip._dcqosHookedOnHide = true
        GameTooltip:HookScript("OnHide", function(self)
            ResetTooltipTransientState(self)
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

local function ResolveSpellIdFromTooltipName(tooltip, fallbackName)
    local spellName = fallbackName

    if (not spellName or spellName == "") and tooltip and type(tooltip.GetName) == "function" then
        local tipName = tooltip:GetName()
        if tipName and tipName ~= "" then
            local header = _G[tipName .. "TextLeft1"]
            if header and header.GetText then
                spellName = header:GetText()
            end
        end
    end

    if type(spellName) ~= "string" or spellName == "" then
        return nil
    end

    local sid = FindCurrentRankSpellIdByName(spellName)
    sid = tonumber(sid)
    if sid and sid > 0 then
        return sid
    end

    return nil
end

local function ResolveShapeshiftSpellId(formIndex, button)
    local idx = tonumber(formIndex)
    if not idx or idx <= 0 or type(GetShapeshiftFormInfo) ~= "function" then
        return nil
    end

    local buttonSpellId = type(button) == "table"
        and tonumber(button.spellId or button.spellID) or nil
    if buttonSpellId and buttonSpellId > 0 then
        return buttonSpellId
    end

    local actionSlot = type(button) == "table" and tonumber(button.action) or nil
    if actionSlot and actionSlot > 0 and type(GetActionInfo) == "function" then
        local actionType, actionValue, _, actionSpellId = GetActionInfo(actionSlot)
        if actionType == "spell" then
            local resolvedActionSpellId = tonumber(actionSpellId)
                or tonumber(actionValue)
            if resolvedActionSpellId and resolvedActionSpellId > 0 then
                return resolvedActionSpellId
            end
        end
    end

    local formTexture, formName, _, _, directSpellId = GetShapeshiftFormInfo(idx)
    directSpellId = tonumber(directSpellId)
    if directSpellId and directSpellId > 0 then
        return directSpellId
    end

    local sid = ResolveSpellIdFromTooltipName(nil, formName)
    sid = tonumber(sid)
    if sid and sid > 0 then
        return sid
    end

    if type(GetNumSpellTabs) ~= "function" or type(GetSpellTabInfo) ~= "function"
        or type(GetSpellBookItemName) ~= "function" then
        return nil
    end

    local tabCount = tonumber(GetNumSpellTabs()) or 0
    for tabIndex = 1, tabCount do
        local _, _, offset, numSlots = GetSpellTabInfo(tabIndex)
        offset = tonumber(offset) or 0
        numSlots = tonumber(numSlots) or 0
        for slot = offset + 1, offset + numSlots do
            local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
            local bookSid = GetSpellIdFromBookSlot(slot, BOOKTYPE_SPELL)
            bookSid = tonumber(bookSid)
            if name and formName and name == formName then
                if bookSid and bookSid > 0 then
                    return bookSid
                end
            end

            if formTexture and bookSid and bookSid > 0 then
                local bookTexture = nil
                if type(GetSpellBookItemTexture) == "function" then
                    bookTexture = GetSpellBookItemTexture(slot, BOOKTYPE_SPELL)
                end
                if (not bookTexture or bookTexture == "")
                    and type(GetSpellTexture) == "function" then
                    bookTexture = GetSpellTexture(bookSid)
                end

                if bookTexture and bookTexture == formTexture then
                    return bookSid
                end
            end
        end
    end

    return nil
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

    -- This client fork can throw C-side nil errors on SetHyperlink for
    -- spell links (similar to SetAction/SetSpell instability). Keep
    -- item hyperlink support, but never issue spell hyperlinks here.
    if string.find(hyperlink, "^spell:") then
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

local function AddUniqueTooltipLine(tooltip, existing, text, r, g, b, wrap)
    if not tooltip or type(tooltip.AddLine) ~= "function" then
        return false
    end

    local normalized = NormalizeTooltipTextValue(text)
    if normalized == "" or existing[normalized] then
        return false
    end

    tooltip:AddLine(text, r or 1.0, g or 1.0, b or 1.0, wrap)
    existing[normalized] = true
    return true
end

local function FormatSpellRangeText(minRange, maxRange)
    local low = tonumber(minRange) or 0
    local high = tonumber(maxRange) or 0
    if high <= 0 then
        return nil
    end

    low = math.floor(low + 0.5)
    high = math.floor(high + 0.5)
    if low > 0 and low < high then
        return string.format("%d-%d yd range", low, high)
    end

    return string.format("%d yd range", high)
end

local function FormatSpellCastTimeText(castTimeMs)
    local castTime = tonumber(castTimeMs) or 0
    if castTime <= 0 then
        return "Instant cast"
    end

    local seconds = castTime / 1000
    if math.abs(seconds - math.floor(seconds)) < 0.001 then
        return string.format("%d sec cast", math.floor(seconds))
    end

    return string.format("%.1f sec cast", seconds)
end

local function AddFallbackSpellBookLines(tooltip, tooltipData)
    if not tooltip or type(tooltipData) ~= "table" then
        return
    end

    local spellId = tonumber(tooltipData.spellId)
    local existing = BuildExistingTooltipTextSet(tooltip)

    if spellId and spellId > 0 and type(GetSpellInfo) == "function" then
        local _, _, _, castTimeMs, minRange, maxRange = GetSpellInfo(spellId)
        local rangeText = FormatSpellRangeText(minRange, maxRange)
        if rangeText then
            AddUniqueTooltipLine(tooltip, existing, rangeText, 0.8, 0.8, 0.8, true)
        end

        local passive = false
        if type(IsPassiveSpell) == "function"
            and tooltipData.bookSlot and tooltipData.bookType then
            local ok, result = pcall(function()
                return IsPassiveSpell(tooltipData.bookSlot, tooltipData.bookType)
            end)
            passive = ok and result and true or false
        end

        if passive then
            AddUniqueTooltipLine(tooltip, existing, PASSIVE or "Passive", 0.8, 0.8, 0.8, true)
        else
            AddUniqueTooltipLine(tooltip, existing, FormatSpellCastTimeText(castTimeMs), 0.8, 0.8, 0.8, true)
        end
    end

    if spellId and spellId > 0 then
        local description = GetClientSpellDescription(spellId)
        if description then
            AddClientSpellDescriptionLines(tooltip, description)
        end
    end
end

local function SetFallbackActionTooltip(button)
    if not GameTooltip or not button then
        return
    end

    SetNativeSpellRowsRequestContext(GameTooltip, nil)

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
        MarkSpellTooltipSource(GameTooltip, "action")
        local sid, bookSlot, bookType, spellName = ResolveActionSpellData(action, id, actionSubType)
        local resolvedId = tonumber(sid) or tonumber(id)
        if bookSlot and bookType then
            SetNativeSpellRowsRequestContext(GameTooltip, "spellbook", bookSlot,
                bookType)
        else
            SetNativeSpellRowsRequestContext(GameTooltip, "hyperlink")
        end

        if not wroteText and resolvedId and resolvedId > 0 then
            -- Safe native spell body fallback: avoids SetAction/SetSpell while
            -- still allowing client-side tooltip description rendering.
            wroteText = TrySetTooltipHyperlink(GameTooltip, "spell:" .. tostring(resolvedId))
        end

        if not wroteText and (not spellName or spellName == "") and resolvedId and type(GetSpellInfo) == "function" then
            spellName = GetSpellInfo(resolvedId)
        end

        if not wroteText and spellName and spellName ~= "" then
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
        MarkSpellTooltipSource(GameTooltip, "action")
        SetNativeSpellRowsRequestContext(GameTooltip, "hyperlink")

        local companionKind = tostring(actionSubType or "")
        companionKind = string.upper(companionKind)

        local _, companionName, companionSpellId
        if companionKind == "MOUNT" then
            _, companionName, companionSpellId = GetCompanionInfo("MOUNT", id)
        elseif companionKind == "CRITTER" then
            _, companionName, companionSpellId = GetCompanionInfo("CRITTER", id)
        else
            -- Unknown subtype on this client/fork: probe both pools.
            _, companionName, companionSpellId = GetCompanionInfo("MOUNT", id)
            if (not companionName or companionName == "") then
                local _, critterName, critterSpellId = GetCompanionInfo("CRITTER", id)
                companionName = critterName
                companionSpellId = critterSpellId
            end
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
        MarkSpellTooltipSource(GameTooltip, nil)
        SetNativeSpellRowsRequestContext(GameTooltip, nil)
        if TrySetTooltipHyperlink(GameTooltip, "item:" .. tostring(id)) then
            wroteText = true
        end
    end

    if not wroteText and actionType == "item" and id and type(GetItemInfo) == "function" then
        MarkSpellTooltipSource(GameTooltip, nil)
        SetNativeSpellRowsRequestContext(GameTooltip, nil)
        local itemName = GetItemInfo(id)
        if itemName and itemName ~= "" then
            GameTooltip:SetText(itemName)
            wroteText = true
        end
    elseif not wroteText and actionType == "macro" and id and type(GetMacroInfo) == "function" then
        MarkSpellTooltipSource(GameTooltip, nil)
        SetNativeSpellRowsRequestContext(GameTooltip, nil)
        local macroName = GetMacroInfo(id)
        if macroName and macroName ~= "" then
            GameTooltip:SetText(macroName)
            wroteText = true
        end
    end

    if not wroteText and type(GetActionText) == "function" then
        MarkSpellTooltipSource(GameTooltip, nil)
        SetNativeSpellRowsRequestContext(GameTooltip, nil)
        local actionText = GetActionText(action)
        if actionText and actionText ~= "" then
            GameTooltip:SetText(actionText)
            wroteText = true
        end
    end

    -- Some stance/presence/form paths can present a spell-name tooltip without
    -- exposing a direct spell action id. Recover via tooltip header text.
    if wroteText then
        local recoveredSid = ResolveSpellIdFromTooltipName(GameTooltip)
        recoveredSid = tonumber(recoveredSid)
        if recoveredSid and recoveredSid > 0 then
            MarkSpellTooltipSource(GameTooltip, "action")
            GameTooltip._dcqosResolvedSpellId = recoveredSid
            EnhanceSpellTooltip(GameTooltip, recoveredSid)
        end
    end

    if not wroteText then
        MarkSpellTooltipSource(GameTooltip, nil)
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

local function ResolveSpellBookTooltipData(button)
    if type(button) ~= "table"
        or type(button.GetID) ~= "function"
        or type(SpellBook_GetSpellID) ~= "function"
        or type(SpellBookFrame) ~= "table" then
        return nil
    end

    local buttonId = tonumber(button:GetID())
    if not buttonId or buttonId <= 0 then
        return nil
    end

    local bookType = SpellBookFrame.bookType
    if bookType ~= BOOKTYPE_SPELL and bookType ~= BOOKTYPE_PET then
        return nil
    end

    local bookSlot, displaySlot = SpellBook_GetSpellID(buttonId)
    bookSlot = tonumber(bookSlot)
    displaySlot = tonumber(displaySlot)

    local effectiveSlot = bookSlot or displaySlot
    if not effectiveSlot or effectiveSlot <= 0 then
        return nil
    end

    local spellName, spellRank
    if type(GetSpellBookItemName) == "function" then
        if bookSlot and bookSlot > 0 then
            spellName, spellRank = GetSpellBookItemName(bookSlot, bookType)
        end
        if (not spellName or spellName == "")
            and displaySlot and displaySlot > 0 and displaySlot ~= bookSlot then
            spellName, spellRank = GetSpellBookItemName(displaySlot, bookType)
        end
    end

    local spellId = nil
    if bookSlot and bookSlot > 0 then
        spellId = GetSpellIdFromBookSlot(bookSlot, bookType)
    end
    if (not spellId or spellId <= 0)
        and displaySlot and displaySlot > 0 and displaySlot ~= bookSlot then
        spellId = GetSpellIdFromBookSlot(displaySlot, bookType)
    end
    if (not spellId or spellId <= 0)
        and bookType == BOOKTYPE_SPELL
        and spellName and spellName ~= "" then
        spellId = FindCurrentRankSpellIdByName(spellName)
    end
    spellId = tonumber(spellId)

    if (spellId and spellId > 0) and (not spellName or spellName == "")
        and type(GetSpellInfo) == "function" then
        spellName, spellRank = GetSpellInfo(spellId)
    end

    if (not spellName or spellName == "") and (not spellId or spellId <= 0) then
        return nil
    end

    return {
        bookSlot = effectiveSlot,
        displaySlot = displaySlot,
        bookType = bookType,
        spellId = spellId,
        spellName = spellName,
        spellRank = spellRank,
    }
end

local function SetFallbackSpellBookTooltip(button)
    if not GameTooltip or type(button) ~= "table" then
        return false
    end

    local tooltipData = ResolveSpellBookTooltipData(button)
    if not tooltipData then
        if GameTooltip.Hide then
            GameTooltip:Hide()
        end
        button.UpdateTooltip = nil
        return false
    end

    if type(GameTooltip.SetOwner) == "function" then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    end

    MarkSpellTooltipSource(GameTooltip, "spellbook")
    GameTooltip._dcqosResolvedSpellId = tooltipData.spellId
    SetNativeSpellRowsRequestContext(GameTooltip, "spellbook",
        tooltipData.bookSlot, tooltipData.bookType)

    local wroteTooltip = false
    if tooltipData.spellName and tooltipData.spellName ~= "" then
        GameTooltip:SetText(tooltipData.spellName)
        if tooltipData.spellRank and tooltipData.spellRank ~= "" then
            GameTooltip:AddLine(tooltipData.spellRank, 0.8, 0.8, 0.8)
        end
        AddFallbackSpellBookLines(GameTooltip, tooltipData)
        wroteTooltip = true
    end

    if wroteTooltip and tooltipData.spellId and tooltipData.spellId > 0 then
        EnhanceSpellTooltip(GameTooltip, tooltipData.spellId)
        button.UpdateTooltip = nil
        button.updateTooltip = nil
        GameTooltip:Show()
        return true
    end

    if GameTooltip.Hide then
        GameTooltip:Hide()
    end
    button.UpdateTooltip = nil
    return false
end

local function SetFallbackShapeshiftTooltip(button)
    if not GameTooltip then
        return
    end

    if type(button) == "table" then
        button.UpdateTooltip = nil
        button.updateTooltip = nil
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

    MarkSpellTooltipSource(GameTooltip, "action")
    SetNativeSpellRowsRequestContext(GameTooltip, "shapeshift", formIndex)
    local spellId = ResolveShapeshiftSpellId(formIndex, button)
    if (not spellId or spellId <= 0) and type(GameTooltip.GetSpell) == "function" then
        local _, _, directSpellId = GameTooltip:GetSpell()
        spellId = tonumber(directSpellId)
    end
    if (not spellId or spellId <= 0) then
        spellId = ResolveSpellIdFromTooltipName(GameTooltip)
    end
    if spellId and spellId > 0 then
        local contextHash = BuildSpellTooltipContextHash(spellId)
        local key = BuildSpellEnrichmentKey(spellId, contextHash)
        local nativeRows = GetNativeClientSpellTooltipRows(GameTooltip,
            spellId, contextHash)
        local renderedNativeRows = nativeRows
            and RenderNativeClientSpellTooltipRows(GameTooltip, nativeRows)
            or false

        GameTooltip._dcqosClientDescriptionShownKey = nil
        GameTooltip._dcqosSpellEnrichmentShownKey = nil
        GameTooltip._dcqosNativeDescriptionStrippedKey = nil
        GameTooltip._dcqosPendingSpellIdForBottom = nil
        GameTooltip._dcqosSpellIdShown = nil

        if renderedNativeRows then
            GameTooltip._dcqosSpellEnrichmentShownKey = key
        else
            local description = GetClientSpellDescription(spellId)
            if type(description) == "string" and description ~= "" then
                AddClientSpellDescriptionLines(GameTooltip, description)
                GameTooltip._dcqosClientDescriptionShownKey = key
            end
        end

        TrySetTooltipHyperlink(GameTooltip, "spell:" .. tostring(spellId))
        GameTooltip._dcqosResolvedSpellId = spellId
        EnhanceSpellTooltip(GameTooltip, spellId)
    end

    GameTooltip:Show()
end

local function SetFallbackCompanionTooltip(button)
    if not GameTooltip or type(button) ~= "table" then
        return
    end

    local spellId = tonumber(button.spellID)
    if not spellId or spellId <= 0 then
        return
    end

    if type(GameTooltip.SetOwner) == "function" then
        if GameTooltip_SetDefaultAnchor and GetCVar and GetCVar("UberTooltips") == "1" then
            GameTooltip_SetDefaultAnchor(GameTooltip, button)
        else
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        end
    end

    local spellName, spellRank = type(GetSpellInfo) == "function" and GetSpellInfo(spellId) or nil, nil
    if type(GetSpellInfo) == "function" then
        _, spellRank = GetSpellInfo(spellId)
    end

    if spellName and spellName ~= "" then
        GameTooltip:SetText(spellName)
        if spellRank and spellRank ~= "" then
            GameTooltip:AddLine(spellRank, 0.8, 0.8, 0.8)
        end
        GameTooltip._dcqosResolvedSpellId = spellId
        MarkSpellTooltipSource(GameTooltip, "action")
        SetNativeSpellRowsRequestContext(GameTooltip, "hyperlink")
        EnhanceSpellTooltip(GameTooltip, spellId)
        GameTooltip:Show()
        return
    end

    if GameTooltip.Hide then
        GameTooltip:Hide()
    end
end

local function SafeShapeshiftButtonOnEnter(self)
    EnsureGameTooltipActionMethods()

    local button = self
    if type(button) ~= "table" then
        button = this
    end

    if type(button) ~= "table" then
        return
    end

    local formIndex
    if type(button.GetID) == "function" then
        formIndex = button:GetID()
    end

    if not formIndex or formIndex <= 0 then
        return
    end

    local blizzardOnEnter = addon._dcqosOriginalShapeshiftButtonOnEnter
        or ShapeshiftButton_OnEnter

    if type(blizzardOnEnter) == "function" and blizzardOnEnter ~= SafeShapeshiftButtonOnEnter then
        local ok, result = pcall(function()
            return blizzardOnEnter(button)
        end)

        if ok then
            MarkSpellTooltipSource(GameTooltip, "action")
            SetNativeSpellRowsRequestContext(GameTooltip, "shapeshift",
                formIndex)
            local spellId = ResolveShapeshiftSpellId(formIndex, button)
            if (not spellId or spellId <= 0) and GameTooltip and type(GameTooltip.GetSpell) == "function" then
                local _, _, directSpellId = GameTooltip:GetSpell()
                spellId = tonumber(directSpellId)
            end
            if (not spellId or spellId <= 0) then
                spellId = ResolveSpellIdFromTooltipName(GameTooltip)
            end
            if spellId and spellId > 0 then
                local contextHash = BuildSpellTooltipContextHash(spellId)
                local key = BuildSpellEnrichmentKey(spellId, contextHash)
                local nativeRows = GetNativeClientSpellTooltipRows(
                    GameTooltip, spellId, contextHash)
                local renderedNativeRows = nativeRows
                    and RenderNativeClientSpellTooltipRows(GameTooltip,
                        nativeRows) or false

                GameTooltip._dcqosClientDescriptionShownKey = nil
                GameTooltip._dcqosSpellEnrichmentShownKey = nil
                GameTooltip._dcqosNativeDescriptionStrippedKey = nil
                GameTooltip._dcqosPendingSpellIdForBottom = nil
                GameTooltip._dcqosSpellIdShown = nil

                if renderedNativeRows then
                    GameTooltip._dcqosSpellEnrichmentShownKey = key
                else
                    local description = GetClientSpellDescription(spellId)
                    if type(description) == "string" and description ~= "" then
                        AddClientSpellDescriptionLines(GameTooltip,
                            description)
                        GameTooltip._dcqosClientDescriptionShownKey = key
                    end
                end

                TrySetTooltipHyperlink(GameTooltip, "spell:" .. tostring(spellId))
                GameTooltip._dcqosResolvedSpellId = spellId
                EnhanceSpellTooltip(GameTooltip, spellId)
            end
            button.UpdateTooltip = nil
            button.updateTooltip = nil
            return result
        end

        addon:Debug("Blizzard shapeshift tooltip failed; using fallback: " .. tostring(result))
    end

    button.UpdateTooltip = nil
    SetFallbackShapeshiftTooltip(button)
end

function SafeSpellButtonOnEnter(self)
    EnsureGameTooltipActionMethods()

    local button = self
    if type(button) ~= "table" then
        button = this
    end

    if type(button) ~= "table" then
        return
    end

    SetFallbackSpellBookTooltip(button)
end

local function InstallShapeshiftOnEnterGuards()
    local maxButtons = tonumber(NUM_SHAPESHIFT_SLOTS) or 10
    for i = 1, maxButtons do
        local button = _G["ShapeshiftButton" .. i]
        if button then
            local onEnter = type(button.GetScript) == "function"
                and button:GetScript("OnEnter") or nil

            if onEnter ~= SafeShapeshiftButtonOnEnter then
                button:SetScript("OnEnter", SafeShapeshiftButtonOnEnter)
            end

            button.UpdateTooltip = nil
            button.updateTooltip = nil

            button._dcqosSafeOnEnterInstalled = true
        end
    end
end

local function HookSpellTooltips()
    local function resolveAuraBarOwnerContext(owner)
        if type(owner) ~= "table" then
            return nil, nil, nil
        end

        local ownerName = owner.GetName and owner:GetName() or ""
        if ownerName == "" or not ownerName:find("^BuffButton%d+$") then
            return nil, nil, nil
        end

        local auraIndex = tonumber(owner.buffIndex)
        if not auraIndex or auraIndex <= 0 then
            auraIndex = type(owner.GetID) == "function"
                and tonumber(owner:GetID()) or tonumber(owner.id)
        end
        if not auraIndex or auraIndex <= 0 then
            return nil, nil, nil
        end

        local auraFilter = type(owner.filter) == "string" and owner.filter ~= ""
            and owner.filter or (owner.debuff and "HARMFUL" or "HELPFUL")
        return auraIndex, auraFilter, owner.debuff and true or false
    end

    local function trackAuraBarButtonTooltip(button)
        if type(button) ~= "table" or not GameTooltip then
            return
        end

        local auraIndex, auraFilter, isDebuff =
            resolveAuraBarOwnerContext(button)
        if not auraIndex or auraIndex <= 0 then
            return
        end

        addon:DelayedCall(0, function()
            if not GameTooltip or not GameTooltip.IsShown
                or not GameTooltip:IsShown() then
                return
            end

            TrackAuraTooltipContext(GameTooltip, "player", auraIndex,
                auraFilter, isDebuff)
            GameTooltip:Show()
        end)
    end

    local function installAuraBarOnEnterHooks()
        local maxButtons = tonumber(BUFF_MAX_DISPLAY) or 32
        for i = 1, maxButtons do
            local button = _G["BuffButton" .. i]
            if button and not button._dcqosAuraTooltipHooked
                and type(button.HookScript) == "function" then
                button:HookScript("OnEnter", trackAuraBarButtonTooltip)
                button._dcqosAuraTooltipHooked = true
            end
        end
    end

    EnsureGameTooltipActionMethods()
    InstallShapeshiftOnEnterGuards()
    installAuraBarOnEnterHooks()

    if not addon._dcqosShapeshiftGuardRefreshFrame then
        local refreshFrame = CreateFrame("Frame")
        addon._dcqosShapeshiftGuardRefreshFrame = refreshFrame
        refreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        refreshFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
        refreshFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
        refreshFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
        refreshFrame:SetScript("OnEvent", function()
            EnsureGameTooltipActionMethods()
            InstallShapeshiftOnEnterGuards()
        end)
    end

    if not addon._dcqosAuraBarRefreshFrame then
        local refreshFrame = CreateFrame("Frame")
        addon._dcqosAuraBarRefreshFrame = refreshFrame
        refreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        refreshFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
        refreshFrame:RegisterEvent("UNIT_AURA")
        refreshFrame:SetScript("OnEvent", function(_, event, unit)
            if event == "UNIT_AURA" and unit ~= "player" then
                return
            end
            installAuraBarOnEnterHooks()
        end)
    end

    if not addon._dcqosHookedBuffFrameUpdate and hooksecurefunc
        and type(BuffFrame_Update) == "function" then
        addon._dcqosHookedBuffFrameUpdate = true
        hooksecurefunc("BuffFrame_Update", function()
            installAuraBarOnEnterHooks()
        end)
    end

    if not GameTooltip._dcqosHookedAuraBarOnShow then
        GameTooltip._dcqosHookedAuraBarOnShow = true
        GameTooltip:HookScript("OnShow", function(self)
            local owner = type(self.GetOwner) == "function"
                and self:GetOwner() or nil
            local auraIndex, auraFilter, isDebuff =
                resolveAuraBarOwnerContext(owner)
            if not auraIndex then
                return
            end

            TrackAuraTooltipContext(self, "player", auraIndex, auraFilter,
                isDebuff)
        end)
    end

    if not addon._dcqosHookedShapeshiftBarUpdate and hooksecurefunc
        and type(ShapeshiftBar_Update) == "function" then
        addon._dcqosHookedShapeshiftBarUpdate = true
        hooksecurefunc("ShapeshiftBar_Update", function()
            EnsureGameTooltipActionMethods()
            InstallShapeshiftOnEnterGuards()
        end)
    end

    -- Revalidate critical methods before Blizzard's OnEnter handlers call SetAction/SetShapeshift.
    if not GameTooltip._dcqosHookedSetOwner and hooksecurefunc and GameTooltip.SetOwner then
        GameTooltip._dcqosHookedSetOwner = true
        hooksecurefunc(GameTooltip, "SetOwner", function(self, owner)
            if self == GameTooltip then
                EnsureGameTooltipActionMethods()
                PrimeTooltipActionSpellId(self, owner)
                if IsActionTooltipOwner(owner) then
                    MarkSpellTooltipSource(self, "action")
                elseif IsSpellbookTooltipOwner(owner) then
                    MarkSpellTooltipSource(self, "spellbook")
                end
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

            local sid, bookSlot, bookType = ResolveActionSpellData(actionSlot,
                id, actionSubType)
            sid = tonumber(sid)
            if not sid or sid <= 0 then
                return
            end

            self._dcqosResolvedSpellId = sid
            if bookSlot and bookType then
                SetNativeSpellRowsRequestContext(self, "spellbook", bookSlot,
                    bookType)
            else
                SetNativeSpellRowsRequestContext(self, "hyperlink")
            end
            MarkSpellTooltipSource(self, "action")
        end)
    end

    if not GameTooltip._dcqosHookedSetShapeshift and hooksecurefunc and GameTooltip.SetShapeshift then
        GameTooltip._dcqosHookedSetShapeshift = true
        hooksecurefunc(GameTooltip, "SetShapeshift", function(self, index, ...)
            MarkSpellTooltipSource(self, "action")
            SetNativeSpellRowsRequestContext(self, "shapeshift", index)
            local spellId = ResolveShapeshiftSpellId(index)
            if (not spellId or spellId <= 0) and type(self.GetSpell) == "function" then
                local _, _, directSpellId = self:GetSpell()
                spellId = tonumber(directSpellId)
            end
            if (not spellId or spellId <= 0) then
                spellId = ResolveSpellIdFromTooltipName(self)
            end
            if spellId and spellId > 0 then
                TrySetTooltipHyperlink(self, "spell:" .. tostring(spellId))
                self._dcqosResolvedSpellId = spellId
                EnhanceSpellTooltip(self, spellId)
            end
        end)
    end

    if not GameTooltip._dcqosHookedSetPetAction and hooksecurefunc and GameTooltip.SetPetAction then
        GameTooltip._dcqosHookedSetPetAction = true
        hooksecurefunc(GameTooltip, "SetPetAction", function(self, ...)
            MarkSpellTooltipSource(self, "action")
            SetNativeSpellRowsRequestContext(self, "petaction",
                tonumber(select(1, ...)))
            if type(self.GetSpell) == "function" then
                local _, _, spellId = self:GetSpell()
                spellId = tonumber(spellId)
                if (not spellId or spellId <= 0) then
                    spellId = ResolveSpellIdFromTooltipName(self)
                end
                if spellId and spellId > 0 then
                    self._dcqosResolvedSpellId = spellId
                    EnhanceSpellTooltip(self, spellId)
                end
            end
        end)
    end

    if not GameTooltip._dcqosHookedSetUnitBuff and hooksecurefunc and GameTooltip.SetUnitBuff then
        GameTooltip._dcqosHookedSetUnitBuff = true
        hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, unit, index, filter, ...)
            TrackAuraTooltipContext(self, unit, index, filter or "HELPFUL",
                false)
        end)
    end

    if not GameTooltip._dcqosHookedSetUnitDebuff and hooksecurefunc and GameTooltip.SetUnitDebuff then
        GameTooltip._dcqosHookedSetUnitDebuff = true
        hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, unit, index, filter, ...)
            TrackAuraTooltipContext(self, unit, index, filter or "HARMFUL",
                true)
        end)
    end

    if not GameTooltip._dcqosHookedSetUnitAura and hooksecurefunc and GameTooltip.SetUnitAura then
        GameTooltip._dcqosHookedSetUnitAura = true
        hooksecurefunc(GameTooltip, "SetUnitAura", function(self, unit, index, filter, ...)
            local filterText = type(filter) == "string" and filter or nil
            local isDebuff = filterText and string.find(string.upper(filterText),
                "HARMFUL", 1, true) and true or false
            TrackAuraTooltipContext(self, unit, index, filter, isDebuff)
        end)
    end

    if not GameTooltip._dcqosHookedSetPlayerBuff and hooksecurefunc and GameTooltip.SetPlayerBuff then
        GameTooltip._dcqosHookedSetPlayerBuff = true
        hooksecurefunc(GameTooltip, "SetPlayerBuff", function(self, index, filter, ...)
            TrackAuraTooltipContext(self, "player", index,
                type(filter) == "string" and filter or nil, false)
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

    if type(SpellButton_OnEnter) == "function" and not addon._dcqosWrappedSpellButtonOnEnter then
        addon._dcqosWrappedSpellButtonOnEnter = true
        local originalSpellButtonOnEnter = SpellButton_OnEnter
        addon._dcqosOriginalSpellButtonOnEnter = originalSpellButtonOnEnter
        SpellButton_OnEnter = function(...)
            return SafeSpellButtonOnEnter(...)
        end
    end

    if type(ShapeshiftButton_OnEnter) == "function" and not addon._dcqosWrappedShapeshiftButtonOnEnter then
        addon._dcqosWrappedShapeshiftButtonOnEnter = true
        local originalShapeshiftButtonOnEnter = ShapeshiftButton_OnEnter
        addon._dcqosOriginalShapeshiftButtonOnEnter = originalShapeshiftButtonOnEnter
        ShapeshiftButton_OnEnter = function(...)
            return SafeShapeshiftButtonOnEnter(...)
        end
    end

    if type(CompanionButton_OnEnter) == "function" and not addon._dcqosWrappedCompanionButtonOnEnter then
        addon._dcqosWrappedCompanionButtonOnEnter = true
        local originalCompanionButtonOnEnter = CompanionButton_OnEnter
        addon._dcqosOriginalCompanionButtonOnEnter = originalCompanionButtonOnEnter
        CompanionButton_OnEnter = function(...)
            EnsureGameTooltipActionMethods()
            local button = select(1, ...)
            if type(button) ~= "table" then
                button = this
            end

            -- Native companion tooltip path uses SetHyperlink in
            -- PetPaperDollFrame and can hard-error on some client forks.
            -- Use stable fallback rendering for mount/pet companion buttons.
            if button then
                button.UpdateTooltip = CompanionButton_OnEnter
            end
            SetFallbackCompanionTooltip(button)
        end
    end

    -- Most spell tooltips (action buttons, racials, etc.) fire this script.
    -- This is the most reliable way to capture spell IDs in 3.3.5a.
    if not GameTooltip._dcqosHookedOnTooltipSetSpell then
        GameTooltip._dcqosHookedOnTooltipSetSpell = true
        GameTooltip:HookScript("OnTooltipSetSpell", function(self)
            local source = ResolveSpellTooltipSource(self)
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

            -- Keep unsupported/unknown tooltip contexts blizzlike and only
            -- append lightweight info (Spell ID) without body replacement.
            if source ~= "action" and source ~= "spellbook" and source ~= "aura" then
                MarkSpellTooltipSource(self, "blizzlike")
                SetNativeSpellRowsRequestContext(self, "hyperlink")
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

            MarkSpellTooltipSource(self, "spellbook")
            SetNativeSpellRowsRequestContext(self, "spellbook", spellBook,
                spellBookType)

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

            if not spellId or spellId <= 0 then
                SetNativeSpellRowsRequestContext(self, "hyperlink")
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
    RegisterProtocolCapabilityHook()
    
    -- Setup tooltip anchor positioning
    SetTooltipAnchor()

        -- Invalidate the spell-name→max-rank cache whenever the player learns a new
        -- spell rank or changes talents (cache is rebuilt lazily on next tooltip).
        addon:RegisterEvent("SPELLS_CHANGED", function()
            InvalidateSpellNameCache()
            QueueSpellEnrichmentPrefetch(1.5)
        end)
        addon:RegisterEvent("PLAYER_TALENT_UPDATE", function()
            InvalidateSpellNameCache()
            QueueSpellEnrichmentPrefetch(1.5)
        end)
    
    -- Hook item tooltips
    HookItemTooltips()
    
    -- Hook unit tooltips
    HookUnitTooltips()
    
    -- Hook spell tooltips
    HookSpellTooltips()

    EnsureNativeTooltipPollFrame()

    SyncNativeSpellTooltipBridge("module-enable")
    
    -- Setup health bar hiding
    SetupHealthBarHiding()

    -- Ensure one early background warmup run even if zone-in event timing is
    -- missed due module load order.
    QueueSpellEnrichmentPrefetch(2)

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
        elseif path == "tooltips.enabled" or path == "communication.enabled" then
            SyncNativeSpellTooltipBridge("setting-changed:" .. tostring(path))
        end
    end)

    -- Pre-warm spell enrichment cache after zone-in so first hovers are instant.
    -- Delay 5 s to allow the server addon-protocol connection to establish.
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        SyncNativeSpellTooltipBridge("player-entering-world")
        QueueSpellEnrichmentPrefetch(5)
    end)

    -- Also prefetch as soon as the protocol connects (no hover needed).
    addon:RegisterEvent("PROTOCOL_CONNECTED", function(moduleId)
        if moduleId == "QOS" then
            SyncNativeSpellTooltipBridge("protocol-connected:" .. tostring(moduleId))
            QueueSpellEnrichmentPrefetch(1)
        end
    end)
end

function Tooltips.OnDisable()
    addon:Debug("Tooltips module disabling")
    -- Note: Hooks cannot be removed, but we check enabled state in each hook
    if type(SetSpellTooltipEnrichmentEnabled) == "function" then
        pcall(SetSpellTooltipEnrichmentEnabled, false)
    end
    if killTrackerFrame then
        killTrackerFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end

function Tooltips.GetTelemetrySnapshot()
    local now = GetTime and GetTime() or 0
    local uptime = 0
    if telemetry.startedAt and now and now > telemetry.startedAt then
        uptime = now - telemetry.startedAt
    end

    local function copyTable(src)
        local out = {}
        for k, v in pairs(src or {}) do
            out[k] = tonumber(v) or v
        end
        return out
    end

    return {
        uptime = uptime,
        spell = copyTable(telemetry.spell),
        upgrade = copyTable(telemetry.upgrade),
        npc = copyTable(telemetry.npc),
    }
end

function Tooltips.GetNativeBridgeSnapshot()
    return GetNativeSpellTooltipBridgeSnapshot()
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
