-- ============================================================
-- DC-QoS: Tooltips Module
-- ============================================================
-- Enhanced tooltip functionality for items, NPCs, and spells
-- Adapted from Leatrix Plus for WoW 3.3.5a compatibility
-- ============================================================

local addon = DCQOS

-- Shared namespace for the split Tooltips files
-- (Tooltips_Items / Tooltips_Spells / Tooltips_Units / Tooltips_Settings)
local TT = {}
addon.TooltipsNS = TT

-- ============================================================
-- Module Configuration
-- ============================================================
local Tooltips = {
    displayName = "Tooltips",
    settingKey = "tooltips",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
}
TT.module = Tooltips

-- ============================================================
-- Local Variables
-- ============================================================
local GameLocale = GetLocale()
local colorBlindMode = GetCVar("colorblindMode")
TT.protocolCapabilityHookRegistered = false
TT.QueueSpellEnrichmentPrefetch = nil
TT.lastNativeBridgeSync = nil

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

function TT.TelemetryInc(bucket, key, amount)
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
function TT.GetServerBagFromClient(bag)
    -- Backpack is 0, other bags are 1-4 for regular, -1 for bank, 5-11 for bank bags
    if bag == 0 then return 255 end  -- INVENTORY_SLOT_BAG_0
    if bag == -2 then return 255 end  -- Equipped item slots on player paperdoll
    if bag >= 1 and bag <= 4 then return 18 + bag end  -- Regular bags (19-22)
    if bag == -1 then return 255 end  -- Bank main
    if bag >= 5 and bag <= 11 then return 62 + (bag - 5) end  -- Bank bags
    return bag
end

-- Convert client slot to server slot ID  
function TT.GetServerSlotFromClient(bag, slot)
    if bag == 0 then
        return 22 + slot  -- Backpack slots start at 23
    end
    return slot - 1  -- Other bags are 0-indexed on server
end

-- Cached GetItemInfo to reduce API calls
function TT.GetCachedItemInfo(itemLink)
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
    
    local serverBag = TT.GetServerBagFromClient(bag)
    local serverSlot = TT.GetServerSlotFromClient(bag, slot)
    local locationKey = BuildLocationKey(serverBag, serverSlot)
    
    -- Don't re-request if already pending, unless stale.
    local pendingAt = tonumber(pendingUpgradeRequests[locationKey]) or 0
    if pendingAt > 0 and (now - pendingAt) < UPGRADE_PENDING_TIMEOUT then
        return
    end
    if pendingAt > 0 and (now - pendingAt) >= UPGRADE_PENDING_TIMEOUT then
        pendingUpgradeRequests[locationKey] = nil
        TT.TelemetryInc("upgrade", "pendingTimeoutRecoveries")
    end
    
    -- Check cache
    local cached = itemUpgradeCache[locationKey]
    if cached and (now - cached.timestamp) < UPGRADE_CACHE_DURATION then
        return
    end
    
    pendingUpgradeRequests[locationKey] = now
    lastUpgradeRequest = now
    TT.TelemetryInc("upgrade", "requestsSent")

    if TT.ShouldUseNativeItemUpgradeBridge() then
        local ok, nativeErr = pcall(RequestNativeItemUpgradeTooltip,
            serverBag, serverSlot)
        if ok then
            TT.TelemetryInc("upgrade", "nativeRequestsSent")
            return
        end

        TT.TelemetryInc("upgrade", "nativeErrors")
        TT.TelemetryInc("upgrade", "nativeFallbacks")
        addon:Debug("Native item-upgrade request failed: " .. tostring(nativeErr))
    end

    addon.protocol:RequestItemUpgradeInfo(serverBag, serverSlot)
end

function TT.TryConsumeNativeUpgradeInfo(serverBag, serverSlot)
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
        TT.TelemetryInc("upgrade", "nativeErrors")
        addon:Debug("Native item-upgrade poll failed: " .. tostring(itemId))
        return false
    end

    if itemId == nil then
        return false
    end

    TT.TelemetryInc("upgrade", "nativeResponsesReady")
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
    TT.TelemetryInc("upgrade", "responsesReceived")
    
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
function TT.AddUpgradeInfo(tooltip, bag, slot, itemLink)
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
    local _, _, quality, _, _, itemType, _, _, equipLoc = TT.GetCachedItemInfo(itemLink)
    if not itemType then return end  -- Item not loaded yet
    if quality == 7 then return end  -- Skip heirlooms (handled separately)
    if itemType ~= "Armor" and itemType ~= "Weapon" then return end
    if equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_QUIVER" then return end
    
    local serverBag = TT.GetServerBagFromClient(bag)
    local serverSlot = TT.GetServerSlotFromClient(bag, slot)
    local locationKey = BuildLocationKey(serverBag, serverSlot)

    if TT.ShouldUseNativeItemUpgradeBridge() then
        TT.TryConsumeNativeUpgradeInfo(serverBag, serverSlot)
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
    local serverBag = TT.GetServerBagFromClient(bag)
    local serverSlot = TT.GetServerSlotFromClient(bag, slot)
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
    TT.RegisterProtocolCapabilityHook()
    
    -- Setup tooltip anchor positioning
    SetTooltipAnchor()

        -- Invalidate the spell-name→max-rank cache whenever the player learns a new
        -- spell rank or changes talents (cache is rebuilt lazily on next tooltip).
        addon:RegisterEvent("SPELLS_CHANGED", function()
            TT.InvalidateSpellNameCache()
            TT.QueueSpellEnrichmentPrefetch(1.5)
        end)
        addon:RegisterEvent("PLAYER_TALENT_UPDATE", function()
            TT.InvalidateSpellNameCache()
            TT.QueueSpellEnrichmentPrefetch(1.5)
        end)
    
    -- Hook item tooltips
    TT.HookItemTooltips()
    
    -- Hook unit tooltips
    TT.HookUnitTooltips()
    
    -- Hook spell tooltips
    TT.HookSpellTooltips()

    TT.EnsureNativeTooltipPollFrame()

    TT.SyncNativeSpellTooltipBridge("module-enable")
    
    -- Setup health bar hiding
    TT.SetupHealthBarHiding()

    -- Ensure one early background warmup run even if zone-in event timing is
    -- missed due module load order.
    TT.QueueSpellEnrichmentPrefetch(2)

    -- Kill tracker (NPC tooltips)
    if not TT.killTrackerFrame then
        TT.killTrackerFrame = CreateFrame("Frame")
        TT.killTrackerFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "COMBAT_LOG_EVENT_UNFILTERED" then
                TT.HandleCombatLogEvent(...)
            end
        end)
    end
    TT.killTrackerFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- Listen for scale changes
    addon:RegisterEvent("SETTING_CHANGED", function(path, value)
        if path == "tooltips.scale" then
            SetTooltipScale()
        elseif path == "tooltips.enabled" or path == "communication.enabled" then
            TT.SyncNativeSpellTooltipBridge("setting-changed:" .. tostring(path))
        end
    end)

    -- Pre-warm spell enrichment cache after zone-in so first hovers are instant.
    -- Delay 5 s to allow the server addon-protocol connection to establish.
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        TT.SyncNativeSpellTooltipBridge("player-entering-world")
        TT.QueueSpellEnrichmentPrefetch(5)
    end)

    -- Also prefetch as soon as the protocol connects (no hover needed).
    addon:RegisterEvent("PROTOCOL_CONNECTED", function(moduleId)
        if moduleId == "QOS" then
            TT.SyncNativeSpellTooltipBridge("protocol-connected:" .. tostring(moduleId))
            TT.QueueSpellEnrichmentPrefetch(1)
        end
    end)
end

function Tooltips.OnDisable()
    addon:Debug("Tooltips module disabling")
    -- Note: Hooks cannot be removed, but we check enabled state in each hook
    if type(SetSpellTooltipEnrichmentEnabled) == "function" then
        pcall(SetSpellTooltipEnrichmentEnabled, false)
    end
    if TT.killTrackerFrame then
        TT.killTrackerFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
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

function Tooltips.GetLastShapeshiftTooltipDebug()
    local src = Tooltips._lastShapeshiftTooltipDebug
    if type(src) ~= "table" then
        return nil
    end

    local out = {}
    for k, v in pairs(src) do
        out[k] = tonumber(v) or v
    end
    return out
end

function Tooltips.GetNativeBridgeSnapshot()
    return TT.GetNativeSpellTooltipBridgeSnapshot()
end
