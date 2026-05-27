-- ============================================================
-- DC-QoS: Server Communication Protocol
-- ============================================================
-- Handles communication with the DarkChaos server via DCAddonProtocol
-- Module ID: QOS
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Protocol Configuration
-- ============================================================
addon.protocol = {
    MODULE_ID = "QOS",
    connected = false,
    DC = nil,  -- DCAddonProtocol reference
    featureHandlers = {},
    lastFeatureData = {},
    nativeEnvelopeFrame = nil,
    nativeEnvelopePollElapsed = 0,
}

local protocol = addon.protocol

local SPELL_ENRICH_CACHE_TTL = 180
local SPELL_ENRICH_CACHE_MAX_SPELLS = 1200
local SPELL_ENRICH_CACHE_MAX_CONTEXTS_PER_SPELL = 8
local SPELL_ENRICH_CACHE_PRUNE_INTERVAL = 20
local NATIVE_ENVELOPE_POLL_INTERVAL = 0.10
local NATIVE_ENVELOPE_ACTION_RESPONSE = "response"
local FEATURE_SERVER_TIME = "server_time"
local FEATURE_PLAYER_STATS = "player_stats"
local lastSpellEnrichCachePruneAt = 0

local function DispatchFeatureData(self, featureKey, data)
    if type(self.lastFeatureData) ~= "table" then
        self.lastFeatureData = {}
    end
    self.lastFeatureData[featureKey] = data

    local handlers = self.featureHandlers[featureKey]

    if type(handlers) == "table" then
        for _, handler in ipairs(handlers) do
            pcall(handler, data)
        end
    end

    addon:FireEvent("QOS_FEATURE_DATA_RECEIVED", featureKey, data)
end

local SERVER_SETTINGS_PATH_MAP = {
    tooltipsEnabled = "tooltips.enabled",
    showItemId = "tooltips.showItemId",
    showItemLevel = "tooltips.showItemLevel",
    showNpcId = "tooltips.showNpcId",
    showSpellId = "tooltips.showSpellId",
    showSpellFamilyMetadata = "tooltips.showSpellFamilyMetadata",
    showGuildRank = "tooltips.showGuildRank",
    showTarget = "tooltips.showTarget",
    hideHealthBar = "tooltips.hideHealthBar",
    hideInCombat = "tooltips.hideInCombat",
    tooltipScale = "tooltips.scale",

    automationEnabled = "automation.enabled",
    autoRepair = "automation.autoRepair",
    autoRepairGuild = "automation.autoRepairGuild",
    autoSellJunk = "automation.autoSellJunk",
    autoDismount = "automation.autoDismount",
    autoAcceptSummon = "automation.autoAcceptSummon",
    autoAcceptResurrect = "automation.autoAcceptResurrect",
    autoDeclineDuels = "automation.autoDeclineDuels",
    autoAcceptQuests = "automation.autoAcceptQuests",
    autoTurnInQuests = "automation.autoTurnInQuests",

    chatEnabled = "chat.enabled",
    hideChannelNames = "chat.hideChannelNames",
    stickyChannels = "chat.stickyChannels",

    interfaceEnabled = "interface.enabled",
    combatPlates = "interface.combatPlates",
    questLevelText = "interface.questLevelText",
}

local function ApplySettingByPath(path, value)
    if type(path) ~= "string" or path == "" then
        return
    end

    local current = addon.settings
    if type(current) ~= "table" then
        return
    end

    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        parts[#parts + 1] = part
    end

    if #parts == 0 then
        return
    end

    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(current[part]) ~= "table" then
            current[part] = {}
        end
        current = current[part]
    end

    current[parts[#parts]] = value
end

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
                local age = (receivedAt > 0) and (now - receivedAt) or (SPELL_ENRICH_CACHE_TTL + 1)
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
                    newest = math.max(newest, tonumber(enrichment and enrichment.receivedAt) or 0)
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

-- ============================================================
-- Opcodes (must match server-side dc_addon_qos.cpp)
-- ============================================================
protocol.Opcodes = {
    -- Client -> Server (0x01-0x0F)
    CMSG_SYNC_SETTINGS      = 0x01,  -- Request settings sync
    CMSG_UPDATE_SETTING     = 0x02,  -- Update a single setting
    CMSG_GET_ITEM_INFO      = 0x03,  -- Request custom item info (DB data)
    CMSG_GET_NPC_INFO       = 0x04,  -- Request custom NPC info (DB GUID, spawn info)
    CMSG_GET_SPELL_INFO     = 0x05,  -- Request custom spell info
    CMSG_REQUEST_FEATURE    = 0x06,  -- Request specific feature data
    CMSG_COLLECT_ALL_MAIL   = 0x07,  -- Request to collect all mail
    CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT = 0x08,  -- Request enriched spell tooltip line
    
    -- Server -> Client (0x10-0x1F)
    SMSG_SETTINGS_SYNC      = 0x10,  -- Full settings sync from server
    SMSG_SETTING_UPDATED    = 0x11,  -- Confirmation of setting update
    SMSG_ITEM_INFO          = 0x12,  -- Custom item information
    SMSG_NPC_INFO           = 0x13,  -- Custom NPC information (DB GUID, spawn info)
    SMSG_SPELL_INFO         = 0x14,  -- Custom spell information
    SMSG_FEATURE_DATA       = 0x15,  -- Feature-specific data
    SMSG_NOTIFICATION       = 0x16,  -- Server notification/message
    SMSG_SPELL_TOOLTIP_ENRICHMENT = 0x17,  -- requestId|spellId|contextHash|status|line
}

-- ============================================================
-- DCAddonProtocol Integration
-- ============================================================

-- Initialize protocol connection
function protocol:Initialize()
    local DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        addon:Debug("DCAddonProtocol not found, waiting...")
        return false
    end
    
    self.DC = DC
    self:RegisterHandlers()
    self.connected = true
    self:EnsureNativeEnvelopeDispatcher()
    addon:FireEvent("PROTOCOL_CONNECTED", self.MODULE_ID)
    
    addon:Debug("Protocol initialized - Module: " .. self.MODULE_ID)
    return true
end

-- Register message handlers
function protocol:RegisterHandlers()
    if not self.DC then return end
    
    local DC = self.DC
    local Ops = self.Opcodes
    
    -- Handle settings sync from server
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_SETTINGS_SYNC, function(...)
        self:HandleSettingsSync(...)
    end)
    
    -- Handle setting update confirmation
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_SETTING_UPDATED, function(...)
        self:HandleSettingUpdated(...)
    end)
    
    -- Handle custom item info response
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_ITEM_INFO, function(...)
        self:HandleItemInfo(...)
    end)
    
    -- Handle custom NPC info response
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_NPC_INFO, function(...)
        self:HandleNpcInfo(...)
    end)
    
    -- Handle custom spell info response
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_SPELL_INFO, function(...)
        self:HandleSpellInfo(...)
    end)

    -- Handle feature-specific response payloads on the addon lane.
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_FEATURE_DATA, function(...)
        self:HandleFeatureData(...)
    end)

    -- Handle spell tooltip enrichment response
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_SPELL_TOOLTIP_ENRICHMENT, function(...)
        self:HandleSpellTooltipEnrichment(...)
    end)
    
    -- Handle server notifications
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_NOTIFICATION, function(...)
        self:HandleNotification(...)
    end)
    
    addon:Debug("Registered " .. self.MODULE_ID .. " protocol handlers")
end

local function NormalizeNativeEnvelopePayload(self, feature, action, revision,
    payload, context)
    local data = {
        feature = tostring(feature or ""),
        action = tostring(action or ""),
        revision = tonumber(revision) or 0,
        context = context,
        payload = payload,
        transport = "native-envelope",
    }

    if data.action == NATIVE_ENVELOPE_ACTION_RESPONSE
        and type(payload) == "string"
        and payload ~= ""
        and self.DC
        and type(self.DC.DecodeJSON) == "function" then
        local ok, decoded = pcall(self.DC.DecodeJSON, self.DC, payload)
        if ok and type(decoded) == "table" then
            data.data = decoded
            for key, value in pairs(decoded) do
                if data[key] == nil then
                    data[key] = value
                end
            end
        end
    end

    return data
end

local function NormalizeAddonFeaturePayload(rawPayload)
    if type(rawPayload) ~= "table" then
        return nil
    end

    local featureKey = tostring(rawPayload.feature or "")
    if featureKey == "" then
        return nil
    end

    local decoded = {}
    for key, value in pairs(rawPayload) do
        decoded[key] = value
    end

    local data = {
        feature = featureKey,
        action = tostring(rawPayload.action or ""),
        revision = tonumber(rawPayload.revision) or 0,
        context = rawPayload.context,
        payload = rawPayload.payload,
        transport = "addon-feature-data",
        data = decoded,
    }

    for key, value in pairs(decoded) do
        if data[key] == nil then
            data[key] = value
        end
    end

    return data
end

local function GetLastNativeEnvelopeFeatureData(self, feature)
    local getter = rawget(_G, "GetLastDCNativeEnvelope")
    if type(getter) ~= "function" then
        return nil
    end

    local ok, moduleId, cachedFeature, action, revision, payload, context =
        pcall(getter, self.MODULE_ID, feature)
    if not ok or moduleId == nil then
        return nil
    end

    if tostring(moduleId or "") ~= self.MODULE_ID then
        return nil
    end

    local featureKey = tostring(cachedFeature or feature or "")
    if featureKey == "" then
        return nil
    end

    return NormalizeNativeEnvelopePayload(self, featureKey, action,
        revision, payload, context)
end

function protocol:HandleFeatureData(...)
    local args = {...}
    local data = NormalizeAddonFeaturePayload(args[1])
    if not data then
        return
    end

    DispatchFeatureData(self, data.feature, data)
end

function protocol:HandleNativeEnvelope(moduleId, feature, action, revision,
    payload, context)
    if tostring(moduleId or "") ~= self.MODULE_ID then
        return false
    end

    local featureKey = tostring(feature or "")
    if featureKey == "" then
        return false
    end

    local data = NormalizeNativeEnvelopePayload(self, featureKey, action,
        revision, payload, context)
    DispatchFeatureData(self, featureKey, data)
    return true
end

function protocol:EnsureNativeEnvelopeDispatcher()
    if self.nativeEnvelopeFrame or type(PollDCNativeEnvelope) ~= "function" then
        return self.nativeEnvelopeFrame ~= nil
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(_, elapsed)
        self.nativeEnvelopePollElapsed = (self.nativeEnvelopePollElapsed or 0)
            + (elapsed or 0)
        if self.nativeEnvelopePollElapsed < NATIVE_ENVELOPE_POLL_INTERVAL then
            return
        end

        self.nativeEnvelopePollElapsed = 0

        for _ = 1, 8 do
            local ok, moduleId, feature, action, revision, payload, context =
                pcall(PollDCNativeEnvelope)
            if not ok or moduleId == nil then
                return
            end

            self:HandleNativeEnvelope(moduleId, feature, action, revision,
                payload, context)
        end
    end)
    frame:Show()

    self.nativeEnvelopeFrame = frame
    return true
end

function protocol:RegisterFeatureHandler(feature, handler)
    if type(feature) ~= "string" or feature == ""
        or type(handler) ~= "function" then
        return false
    end

    self.featureHandlers[feature] = self.featureHandlers[feature] or {}
    table.insert(self.featureHandlers[feature], handler)
    self:EnsureNativeEnvelopeDispatcher()
    return true
end

function protocol:UnregisterFeatureHandler(feature, handler)
    local handlers = self.featureHandlers[feature]
    if type(handlers) ~= "table" or type(handler) ~= "function" then
        return false
    end

    for index = #handlers, 1, -1 do
        if handlers[index] == handler then
            table.remove(handlers, index)
        end
    end

    if #handlers == 0 then
        self.featureHandlers[feature] = nil
    end

    return true
end

-- ============================================================
-- Message Sending
-- ============================================================

-- Send a message to the server
function protocol:Send(opcode, ...)
    if not self.DC or not self.connected then
        addon:Debug("Cannot send - protocol not connected")
        return false
    end
    
    self.DC:Send(self.MODULE_ID, opcode, ...)
    return true
end

-- Send JSON message
function protocol:SendJson(opcode, data)
    if not self.DC or not self.connected then
        addon:Debug("Cannot send - protocol not connected")
        return false
    end

    -- DC-AddonProtocol exposes SendJSON (capital JSON). Keep this wrapper name
    -- for backwards-compat with the rest of DC-QOS.
    if type(self.DC.SendJSON) == "function" then
        self.DC:SendJSON(self.MODULE_ID, opcode, data)
    elseif type(self.DC.SendJson) == "function" then
        self.DC:SendJson(self.MODULE_ID, opcode, data)
    else
        addon:Debug("DCAddonProtocol missing SendJSON/SendJson")
        return false
    end
    return true
end

function protocol:RequestFeature(feature, payload)
    if type(feature) ~= "string" or feature == "" then
        return false
    end

    local request = type(payload) == "table" and payload or {}
    request.feature = feature
    return self:SendJson(self.Opcodes.CMSG_REQUEST_FEATURE, request)
end

function protocol:GetFeatureData(feature)
    if type(feature) ~= "string" or feature == "" then
        return nil
    end

    if type(self.lastFeatureData) ~= "table" then
        self.lastFeatureData = {}
    end

    local cache = self.lastFeatureData
    local cached = cache[feature]
    local nativeCached = GetLastNativeEnvelopeFeatureData(self, feature)

    if nativeCached then
        local cachedRevision = tonumber(cached and cached.revision) or 0
        local nativeRevision = tonumber(nativeCached.revision) or 0

        if not cached or nativeRevision >= cachedRevision then
            cache[feature] = nativeCached
            return nativeCached
        end
    end

    return cached
end

function protocol:RequestServerTime(payload)
    return self:RequestFeature(FEATURE_SERVER_TIME, payload)
end

function protocol:GetServerTimeState()
    return self:GetFeatureData(FEATURE_SERVER_TIME)
end

function protocol:RequestPlayerStats(payload)
    return self:RequestFeature(FEATURE_PLAYER_STATS, payload)
end

function protocol:GetPlayerStatsState()
    return self:GetFeatureData(FEATURE_PLAYER_STATS)
end

-- Request settings sync from server
function protocol:RequestSync()
    return self:Send(self.Opcodes.CMSG_SYNC_SETTINGS)
end

-- Update a setting on the server
function protocol:UpdateSetting(settingPath, value)
    return self:SendJson(self.Opcodes.CMSG_UPDATE_SETTING, {
        path = settingPath,
        value = value,
    })
end

-- Request custom item info from server
function protocol:RequestItemInfo(itemId)
    return self:Send(self.Opcodes.CMSG_GET_ITEM_INFO, itemId)
end

-- Request custom NPC info from server (DB GUID)
function protocol:RequestNpcInfo(npcGuid)
    return self:Send(self.Opcodes.CMSG_GET_NPC_INFO, npcGuid)
end

-- Request custom spell info from server
function protocol:RequestSpellInfo(spellId)
    return self:Send(self.Opcodes.CMSG_GET_SPELL_INFO, spellId)
end

-- Request server-enriched spell tooltip line
-- Payload order must remain aligned with server:
-- requestId, spellId, contextHash
function protocol:RequestSpellTooltipEnrichment(requestId, spellId, contextHash, useJson)
    local reqId = tonumber(requestId) or 0
    local sId = tonumber(spellId) or 0
    local ctxHash = tonumber(contextHash) or 0

    if reqId <= 0 or sId <= 0 or ctxHash <= 0 then
        addon:Debug("RequestSpellTooltipEnrichment rejected (invalid requestId/spellId/contextHash)")
        return false
    end

    if useJson then
        return self:SendJson(self.Opcodes.CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT, {
            requestId = reqId,
            spellId = sId,
            contextHash = ctxHash,
        })
    end

    return self:Send(self.Opcodes.CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT, reqId, sId, ctxHash)
end

-- Request item upgrade info from server (tier, upgrade level, etc.)
function protocol:RequestItemUpgradeInfo(bag, slot)
    return self:SendJson(self.Opcodes.CMSG_GET_ITEM_INFO, {
        bag = bag,
        slot = slot,
        type = "upgrade",  -- Specifies we want upgrade data, not just basic info
    })
end

-- Request server to collect all mail
function protocol:RequestCollectAllMail()
    return self:Send(self.Opcodes.CMSG_COLLECT_ALL_MAIL)
end

-- ============================================================
-- Message Handlers
-- ============================================================

-- Handle full settings sync from server
function protocol:HandleSettingsSync(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        -- JSON format - merge server settings
        local serverSettings = args[1]
        local applied = false

        for key, value in pairs(serverSettings) do
            if type(value) == "table" and type(addon.settings[key]) == "table" then
                for subKey, subValue in pairs(value) do
                    addon.settings[key][subKey] = subValue
                    applied = true
                end
            else
                local path = SERVER_SETTINGS_PATH_MAP[key] or key
                ApplySettingByPath(path, value)
                applied = true
            end
        end

        if applied then
            addon:SaveSettings()
        end
        addon:FireEvent("SETTINGS_SYNCED", serverSettings)
        addon:Debug("Settings synced from server")
    end
end

-- Handle setting update confirmation
function protocol:HandleSettingUpdated(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        local data = args[1]
        addon:Debug("Setting confirmed: " .. tostring(data.path) .. " = " .. tostring(data.value))
        addon:FireEvent("SETTING_CONFIRMED", data.path, data.value)
    end
end

-- Handle custom item info from server
function protocol:HandleItemInfo(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        local itemData = args[1]
        addon:FireEvent("ITEM_INFO_RECEIVED", itemData)
        
        -- Check if this is upgrade info or an upgrade lookup error (bag/slot scoped)
        if itemData.upgradeLevel ~= nil or itemData.tier ~= nil
            or (itemData.bag ~= nil and itemData.slot ~= nil) then
            addon:FireEvent("ITEM_UPGRADE_INFO_RECEIVED", itemData)
        end
        
        -- Cache for tooltip display
        if itemData.itemId and addon.tooltipCache then
            addon.tooltipCache.items[itemData.itemId] = itemData
        end
    end
end

-- Handle custom NPC info from server (DB GUID, spawn info)
function protocol:HandleNpcInfo(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        local npcData = args[1]
        addon:FireEvent("NPC_INFO_RECEIVED", npcData)
        
        -- Cache for tooltip display (skip explicit error payloads)
        if npcData.guid and not npcData.error and addon.tooltipCache then
            addon.tooltipCache.npcs[npcData.guid] = npcData
        end
    end
end

-- Handle custom spell info from server
function protocol:HandleSpellInfo(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        local spellData = args[1]
        addon:FireEvent("SPELL_INFO_RECEIVED", spellData)
        
        -- Cache for tooltip display
        if spellData.spellId and addon.tooltipCache then
            addon.tooltipCache.spells[spellData.spellId] = spellData
        end
    end
end

-- Handle spell tooltip enrichment response
-- Response field order:
-- requestId, spellId, contextHash, status, line
-- Status codes:
-- 0 = success, 1 = spell-not-found, 2 = invalid-request, 3 = no-enrichment-data
function protocol:HandleSpellTooltipEnrichment(...)
    local args = {...}
    local data

    if type(args[1]) == "table" then
        -- JSON format fallback support
        data = args[1]
    else
        data = {
            requestId = tonumber(args[1]) or 0,
            spellId = tonumber(args[2]) or 0,
            contextHash = tonumber(args[3]) or 0,
            status = tonumber(args[4]) or 0,
            line = args[5] or "",
        }
    end

    local requestId = tonumber(data.requestId) or 0
    local spellId = tonumber(data.spellId) or 0
    local contextHash = tonumber(data.contextHash) or 0
    local status = tonumber(data.status) or 0
    local line = tostring(data.line or "")

    local enrichment = {
        requestId = requestId,
        spellId = spellId,
        contextHash = contextHash,
        status = status,
        line = line,
        lines = type(data.lines) == "table" and data.lines or nil,
        title = data.title,
        source = data.source,
        receivedAt = GetTime(),
    }

    -- Compatibility bridge: some transports deliver only the legacy `line`
    -- field (no structured `lines[]` payload). Convert it so tooltip rendering
    -- paths still show body text.
    if status == 0 and (type(enrichment.lines) ~= "table" or #enrichment.lines == 0)
        and line ~= "" then
        enrichment.lines = {
            { left = line, kind = "body" }
        }
    end

    -- Cache by spell/context for tooltip consumers.
    if addon.tooltipCache and spellId > 0 and contextHash > 0 then
        PruneSpellEnrichmentCache(GetTime())
        addon.tooltipCache.spellEnrichment = addon.tooltipCache.spellEnrichment or {}
        addon.tooltipCache.spellEnrichment[spellId] = addon.tooltipCache.spellEnrichment[spellId] or {}
        addon.tooltipCache.spellEnrichment[spellId][contextHash] = enrichment
    end

    addon:FireEvent("SPELL_TOOLTIP_ENRICHMENT_RECEIVED", enrichment)
end

-- Handle server notification
function protocol:HandleNotification(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        local notification = args[1]
        local msgType = notification.type or "info"
        local message = notification.message or ""
        
        if msgType == "error" then
            addon:Print("|cffff0000Error:|r " .. message, true)
        elseif msgType == "warning" then
            addon:Print("|cffffd700Warning:|r " .. message, true)
        else
            addon:Print(message, true)
        end
        
        addon:FireEvent("NOTIFICATION_RECEIVED", notification)
    end
end

-- ============================================================
-- Tooltip Data Cache
-- ============================================================
addon.tooltipCache = {
    items = {},
    npcs = {},
    spells = {},
    spellEnrichment = {},
}

-- ============================================================
-- Event Hooks
-- ============================================================

-- Try to initialize on player login
addon:RegisterEvent("PLAYER_LOGIN", function()
    addon:DelayedCall(1, function()
        if not protocol.connected then
            protocol:Initialize()
        end
        
        -- Request initial sync
        if protocol.connected then
            protocol:RequestSync()
        end
    end)
end)

-- Re-try connection on entering world
addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if not protocol.connected then
        addon:DelayedCall(2, function()
            if protocol:Initialize() then
                protocol:RequestSync()
            end
        end)
    end
end)

-- Sync setting changes to server
addon:RegisterEvent("SETTING_CHANGED", function(path, value)
    if addon.settings.communication and addon.settings.communication.autoSync then
        protocol:UpdateSetting(path, value)
    end
end)

-- ============================================================
-- Public API
-- ============================================================

-- Expose protocol functions
function addon:IsConnected()
    return protocol.connected
end

function addon:SyncWithServer()
    return protocol:RequestSync()
end

function addon:RequestItemInfo(itemId)
    return protocol:RequestItemInfo(itemId)
end

function addon:RequestNpcInfo(npcGuid)
    return protocol:RequestNpcInfo(npcGuid)
end

function addon:RequestSpellInfo(spellId)
    return protocol:RequestSpellInfo(spellId)
end

function addon:RequestFeature(feature, payload)
    return protocol:RequestFeature(feature, payload)
end

function addon:GetFeatureData(feature)
    return protocol:GetFeatureData(feature)
end

function addon:RequestServerTime(payload)
    return protocol:RequestServerTime(payload)
end

function addon:GetServerTimeState()
    return protocol:GetServerTimeState()
end

function addon:RequestPlayerStats(payload)
    return protocol:RequestPlayerStats(payload)
end

function addon:GetPlayerStatsState()
    return protocol:GetPlayerStatsState()
end

function addon:RegisterFeatureHandler(feature, handler)
    return protocol:RegisterFeatureHandler(feature, handler)
end

function addon:UnregisterFeatureHandler(feature, handler)
    return protocol:UnregisterFeatureHandler(feature, handler)
end

function addon:RequestSpellTooltipEnrichment(requestId, spellId, contextHash, useJson)
    return protocol:RequestSpellTooltipEnrichment(requestId, spellId, contextHash, useJson)
end

function addon:GetSpellTooltipEnrichment(spellId, contextHash)
    if not addon.tooltipCache or not addon.tooltipCache.spellEnrichment then
        return nil
    end

    local spellBucket = addon.tooltipCache.spellEnrichment[tonumber(spellId) or 0]
    if not spellBucket then
        return nil
    end

    return spellBucket[tonumber(contextHash) or 0]
end
