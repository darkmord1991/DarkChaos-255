--[[
    DC Addon Protocol v1.5.1
    Unified communication library for all DarkChaos addons
    
    Features:
    - Pipe-delimited message format (MODULE|OPCODE|args...)
    - JSON support for complex data structures (DEFAULT standard)
    - DC:Request() method for JSON-by-default messaging
    - Handler registration per module/opcode
    - Module wrappers: DC.AOE, DC.Hotspot, DC.Upgrade, DC.Spectator, etc.
    - Connection status and feature tracking
    - Debug mode with /dc debug
    - Settings panel with JSON editor for testing (/dc panel)
    
    v1.5.1 Changes:
    - Fixed SetColorTexture -> SetTexture for 3.3.5a compatibility
    - Added test response handlers (CORE 0x63, 0xFF)
    - Connection feedback message on handshake ACK
    
    v1.5.0 Changes:
    - Added settings panel with debug/testing interface
    - JSON text editor for sending custom messages
    - Quick preset buttons for common requests
    - Slash commands: /dc panel, /dcpanel, /dcprotocol
    
    v1.4.0 Changes:
    - Added DC:Request(module, opcode, data) - JSON format as standard
    - All module wrappers now use DC:Request()
    - All DC addons converted to JSON format
    
    Author: DarkChaos Development Team
    Date: November 29, 2025
]]
if DCAddonProtocol then return end

DCAddonProtocol = {
    PREFIX = "DC",
    VERSION = "2.0.1",
    Capability = {
        JSON_MESSAGES = 0x00000001,
        BATCH_MESSAGES = 0x00000002,
        TOOLTIP_NATIVE_RESPONSE = 0x00000100,
        BREAKING_NEWS_NATIVE = 0x00000200,
        ITEM_UPGRADE_NATIVE = 0x00000400,
        NPC_TOOLTIP_NATIVE = 0x00000800,
        MYTHICPLUS_HUD_NATIVE = 0x00001000,
        COLLECTION_TRANSMOG_STATE_NATIVE = 0x00002000,
        COLLECTION_ITEM_SETS_NATIVE = 0x00004000,
        PING_RELAY_NATIVE = 0x00008000,
        CLIENT_METADATA = 0x00010000,
        HLBG_LIVE_NATIVE = 0x00020000,
        SPECTATOR_LIVE_NATIVE = 0x00040000,
        COLLECTION_WAVE1_NATIVE = 0x00080000,
        GENERIC_NATIVE_ENVELOPE = 0x00100000,
        ITEM_TOOLTIP_REPLACEMENT_NATIVE = 0x00200000,
        SEASONAL_NATIVE = 0x00400000,
        HOTSPOT_NATIVE = 0x00800000,
        PRESTIGE_NATIVE = 0x01000000,
        WORLD_NATIVE = 0x02000000,
        GENERIC_MESSAGE_NATIVE = 0x04000000,
    },
    -- Capability flags (must stay in sync with server-side ProtocolVersion::Capability)
    BASE_CAPABILITIES = 3,
    CAPABILITIES = 3, -- Compatibility mirror; GetClientCapabilities() is authoritative.
    _handlers = {},
    _debug = false,
    _connected = false,
    _serverVersion = nil,
    _serverCaps = 0,
    _clientCaps = 0,
    _features = {},
    _handshakeSent = false,
    _handshakePending = false,
    _lastHandshakeTime = 0,
    _reconnectAttempts = 0,
    _maxReconnectAttempts = 5,

    -- Server context (season/phase)
    _serverContext = nil,
    _serverContextHandlers = {},
    _lastHandshakeAck = nil,

    -- CrossSystem event handlers
    _crossEventHandlers = {},
    
    -- Request tracking system
    _requestLog = {},           -- Circular buffer of request entries
    _requestLogMax = 100,       -- Max entries to keep
    _requestLogSeq = 0,
    _responseLog = {},          -- Circular buffer of response entries
    _responseLogMax = 100,
    _responseLogSeq = 0,
    _pendingRequests = {},      -- Requests waiting for response (keyed by requestId)
    _pendingRequestsLegacy = {},-- Legacy lookup by module_opcode

    -- ------------------------------------------------------------------
    -- Outbound throttle (see DC:_SendAddonWhisper)
    -- ------------------------------------------------------------------
    -- A protocol-level ceiling on addon-message rate. Addon whispers ride
    -- CMSG_MESSAGECHAT (0x095); the core rate-limits opcodes per world-second
    -- via `antidos_opcode_policies` (WorldSession::DosProtection::EvaluateOpcode)
    -- and its policies KICK. Our world DB currently has no row for 0x095, so a
    -- runaway module is "only" wasted bandwidth + server CPU today -- but adding
    -- that row later would silently turn every latent flood into a mass kick.
    -- This bucket makes the flood structurally impossible either way: no module
    -- can exceed `refillPerSec` sustained, no matter how broken its own logic.
    --
    -- Deliberately a rate CEILING, not a deduplicator: over-budget messages are
    -- QUEUED, never dropped (until the queue itself overflows). Nothing that
    -- would have gone out on an idle connection is delayed or lost, so this
    -- cannot silently swallow a genuine repeated command (two quick buys of the
    -- same item, say).
    --
    -- It is NOT a substitute for module-level restraint. Every message carries a
    -- unique RID that DC:LogRequest registers in _pendingRequests, so two "same"
    -- requests are never byte-identical and cannot be collapsed -- dropping one
    -- would strand its RID until _CheckRequestTimeouts reported a false timeout.
    -- The queue-level coalesce below is therefore only a safety net for true
    -- identical re-sends, not a dedupe of repeated requests. Semantic "should I
    -- even ask again" limits belong in the module, next to the meaning of the
    -- request (see qnav.AllowRequest in DC-QOS Navigation.lua).
    _throttle = {
        enabled = true,
        burst = 20,             -- bucket capacity (allows login/zone sync bursts)
        refillPerSec = 10,      -- sustained ceiling; keep <= any 0x095 antidos MaxAllowedCount
        maxQueue = 64,          -- queued messages before we start shedding
        tokens = 20,            -- current bucket level (starts full)
        lastRefill = nil,       -- GetTime() of last refill
        queue = {},             -- FIFO of pending payload strings
        stats = {
            sent = 0,           -- delivered to SendAddonMessage
            queued = 0,         -- deferred at least once
            coalesced = 0,      -- collapsed into an identical queued entry
            dropped = 0,        -- shed on queue overflow
            urgent = 0,         -- bypassed the bucket (handshake etc.)
        },
    },

    -- Request ID generator
    _requestIdCounter = 0,
    _requestIdEpoch = 0,        -- Epoch counter to prevent overflow collision
    
    -- Statistics tracking
    _stats = {
        totalRequests = 0,
        totalResponses = 0,
        totalTimeouts = 0,
        avgResponseTime = 0,
        moduleStats = {},
        sessionStart = 0,  -- Will be set to time() after load
    },
    _errorHandlers = {},
    _globalErrorHandlers = {},
    
    -- Performance optimization: logging is disabled by default
    -- Enable with DC:EnableLogging(true) or when debug panel is opened
    _loggingEnabled = false,

    -- SavedVariables-backed settings and net event log
    _settings = nil,
}

local DC = DCAddonProtocol
local DEFAULT_DB

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

local function CombineCapabilities(baseMask, extraMask)
    local left = tonumber(baseMask) or 0
    local right = tonumber(extraMask) or 0

    if bit and bit.bor then
        return bit.bor(left, right)
    end

    -- These capability families do not overlap, so addition is a safe fallback.
    return left + right
end

local function ParseBooleanLike(value)
    local valueType = type(value)

    if valueType == "boolean" then
        return true, value
    end

    if valueType == "number" then
        if value == 1 then
            return true, true
        end
        if value == 0 then
            return true, false
        end
        return false, nil
    end

    if valueType == "string" then
        local normalized = strlower(strtrim(value))
        if normalized == "1" or normalized == "true" or normalized == "yes" then
            return true, true
        end
        if normalized == "0" or normalized == "false" or normalized == "no" then
            return true, false
        end
    end

    return false, nil
end

local function DescribeHandshakeArg(value)
    if value == nil then
        return "<nil>"
    end

    if type(value) == "table" then
        return string.format(
            "{version=%s,compatible=%s,negotiatedCaps=%s}",
            tostring(value.version or value.v or "<nil>"),
            tostring(value.compatible),
            tostring(value.negotiatedCaps
                or value.negotiatedCapabilities
                or value.caps
                or value.capabilities
                or "<nil>"))
    end

    return tostring(value)
end

local DEFAULT_KEYSTONE_ITEM_LIST = {
    300313, 300314, 300315, 300316, 300317,
    300318, 300319, 300320, 300321, 300322,
    300323, 300324, 300325, 300326, 300327,
    300328, 300329, 300330, 300331,
}

local function NormalizeBufferCapacity(capacity, fallback, minimum)
    local normalized = tonumber(capacity)
    if normalized == nil then
        normalized = tonumber(fallback)
    end
    if normalized == nil then
        normalized = minimum or 1
    end

    normalized = math.floor(normalized)
    if normalized < (minimum or 1) then
        normalized = minimum or 1
    end

    return normalized
end

local function CreateCircularBuffer(capacity, fallback, minimum)
    return {
        entries = {},
        head = 1,
        count = 0,
        capacity = NormalizeBufferCapacity(capacity, fallback, minimum),
    }
end

local function IsCircularBuffer(buffer)
    return type(buffer) == "table"
        and type(buffer.entries) == "table"
        and type(buffer.head) == "number"
        and type(buffer.count) == "number"
        and type(buffer.capacity) == "number"
end

local function GetCircularBufferCount(buffer)
    if not IsCircularBuffer(buffer) then
        return 0
    end

    return math.max(0, math.floor(tonumber(buffer.count) or 0))
end

local function AppendCircularBuffer(buffer, entry)
    if not IsCircularBuffer(buffer) then
        return entry
    end

    local capacity = NormalizeBufferCapacity(buffer.capacity, 1, 1)
    local count = GetCircularBufferCount(buffer)

    if count < capacity then
        local index = ((buffer.head + count - 2) % capacity) + 1
        buffer.entries[index] = entry
        buffer.count = count + 1
    else
        buffer.entries[buffer.head] = entry
        buffer.head = (buffer.head % capacity) + 1
    end

    return entry
end

local function GetCircularBufferEntries(buffer, limit, newestFirst)
    local result = {}
    local count = GetCircularBufferCount(buffer)
    if count == 0 then
        return result
    end

    limit = tonumber(limit)
    if limit == nil or limit < 1 or limit > count then
        limit = count
    else
        limit = math.floor(limit)
    end

    local capacity = NormalizeBufferCapacity(buffer.capacity, count, 1)
    if newestFirst then
        for offset = 0, limit - 1 do
            local index = ((buffer.head + count - 2 - offset) % capacity) + 1
            result[#result + 1] = buffer.entries[index]
        end
        return result
    end

    local startOffset = count - limit
    for offset = startOffset, count - 1 do
        local index = ((buffer.head + offset - 1) % capacity) + 1
        result[#result + 1] = buffer.entries[index]
    end

    return result
end

local function EnsureCircularBuffer(buffer, capacity, newestFirst, fallback, minimum)
    local normalizedCapacity = NormalizeBufferCapacity(capacity, fallback, minimum)

    if IsCircularBuffer(buffer) then
        if buffer.capacity ~= normalizedCapacity then
            local preserved = GetCircularBufferEntries(
                buffer,
                math.min(GetCircularBufferCount(buffer), normalizedCapacity),
                false)

            buffer.entries = {}
            buffer.head = 1
            buffer.count = 0
            buffer.capacity = normalizedCapacity

            for i = 1, #preserved do
                AppendCircularBuffer(buffer, preserved[i])
            end
        end

        return buffer
    end

    local converted = CreateCircularBuffer(normalizedCapacity, normalizedCapacity, minimum)
    if type(buffer) ~= "table" then
        return converted
    end

    if newestFirst then
        local keep = math.min(#buffer, normalizedCapacity)
        for i = keep, 1, -1 do
            AppendCircularBuffer(converted, buffer[i])
        end
        return converted
    end

    local start = math.max(1, #buffer - normalizedCapacity + 1)
    for i = start, #buffer do
        AppendCircularBuffer(converted, buffer[i])
    end

    return converted
end

local function ClearCircularBuffer(buffer, capacity, fallback, minimum)
    local cleared = EnsureCircularBuffer(buffer, capacity, false, fallback, minimum)
    cleared.entries = {}
    cleared.head = 1
    cleared.count = 0
    return cleared
end

local function CopyKeystoneItemIdSet(target, items)
    if type(target) ~= "table" then
        target = {}
    end

    for key in pairs(target) do
        target[key] = nil
    end

    if type(items) ~= "table" then
        return target
    end

    if items[1] ~= nil then
        for _, itemId in ipairs(items) do
            local num = tonumber(itemId)
            if num and num > 0 then
                target[num] = true
            end
        end
        return target
    end

    for key, value in pairs(items) do
        local num = tonumber(key)
        if num and num > 0 and value then
            target[num] = true
        end
    end

    return target
end

function DC:GetDefaultKeystoneItemMap()
    return CopyKeystoneItemIdSet({}, DEFAULT_KEYSTONE_ITEM_LIST)
end

function DC:SetKeystoneItemIds(items)
    local source = items
    if type(source) ~= "table" or next(source) == nil then
        source = DEFAULT_KEYSTONE_ITEM_LIST
    end

    local target = self.KEYSTONE_ITEM_IDS
    if type(target) ~= "table" then
        target = {}
        self.KEYSTONE_ITEM_IDS = target
    end

    if source == target then
        return target
    end

    return CopyKeystoneItemIdSet(target, source)
end

function DC:_EnsureRequestLogBuffer()
    if not IsCircularBuffer(self._requestLog) then
        local maxId = tonumber(self._requestLogSeq) or 0
        if type(self._requestLog) == "table" then
            for i = 1, #self._requestLog do
                local entry = self._requestLog[i]
                local entryId = entry and tonumber(entry.id) or 0
                if entryId > maxId then
                    maxId = entryId
                end
            end
        end

        self._requestLog = EnsureCircularBuffer(self._requestLog,
            self._requestLogMax, true, 100, 10)
        self._requestLogSeq = maxId
        return self._requestLog
    end

    self._requestLog = EnsureCircularBuffer(self._requestLog,
        self._requestLogMax, true, 100, 10)
    return self._requestLog
end

function DC:_EnsureResponseLogBuffer()
    if not IsCircularBuffer(self._responseLog) then
        local maxId = tonumber(self._responseLogSeq) or 0
        if type(self._responseLog) == "table" then
            for i = 1, #self._responseLog do
                local entry = self._responseLog[i]
                local entryId = entry and tonumber(entry.id) or 0
                if entryId > maxId then
                    maxId = entryId
                end
            end
        end

        self._responseLog = EnsureCircularBuffer(self._responseLog,
            self._responseLogMax, true, 100, 10)
        self._responseLogSeq = maxId
        return self._responseLog
    end

    self._responseLog = EnsureCircularBuffer(self._responseLog,
        self._responseLogMax, true, 100, 10)
    return self._responseLog
end

function DC:_EnsureNetLogBuffer()
    if not self._settings then
        self:_InitDB()
    end
    if not self._settings then
        return CreateCircularBuffer(DEFAULT_DB and DEFAULT_DB.netLogMaxEntries or 200,
            200, 10)
    end

    self._settings.netLog = EnsureCircularBuffer(self._settings.netLog,
        self._settings.netLogMaxEntries,
        false,
        DEFAULT_DB and DEFAULT_DB.netLogMaxEntries or 200,
        10)
    return self._settings.netLog
end

function DC:GetRequestLogCount()
    return GetCircularBufferCount(self:_EnsureRequestLogBuffer())
end

function DC:GetResponseLogCount()
    return GetCircularBufferCount(self:_EnsureResponseLogBuffer())
end

function DC:GetNativeExtensionCapabilities()
    local getter = rawget(_G, "GetDCClientCapabilities")
    if type(getter) == "function" then
        local ok, capabilities = pcall(getter)
        if ok then
            return tonumber(capabilities) or 0
        end
    end

    local capabilities = 0
    if type(SetSpellTooltipEnrichmentEnabled) == "function"
        and type(ConfigureSpellTooltipEnrichment) == "function"
        and type(GetSpellTooltipEnrichmentStats) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.TOOLTIP_NATIVE_RESPONSE)
    end

    if type(RequestNativeItemUpgradeTooltip) == "function"
        and type(GetNativeItemUpgradeTooltipData) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.ITEM_UPGRADE_NATIVE)
    end

    if type(RequestNativeNpcTooltipInfo) == "function"
        and type(GetNativeNpcTooltipInfo) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.NPC_TOOLTIP_NATIVE)
    end

    if type(RequestNativeMythicPlusHud) == "function"
        and type(GetNativeMythicPlusHudSnapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.MYTHICPLUS_HUD_NATIVE)
    end

    if type(RequestNativeCollectionTransmogState) == "function"
        and type(GetNativeCollectionTransmogStateSnapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.COLLECTION_TRANSMOG_STATE_NATIVE)
    end

    if type(RequestNativeCollectionItemSets) == "function"
        and type(GetNativeCollectionItemSetsSnapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.COLLECTION_ITEM_SETS_NATIVE)
    end

    if type(RequestNativePingRelay) == "function"
        and type(GetNativePingRelaySnapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.PING_RELAY_NATIVE)
    end

    if type(RequestNativeHLBGLiveSnapshot) == "function"
        and type(GetNativeHLBGLiveSnapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.HLBG_LIVE_NATIVE)
    end

    if type(RequestNativeSpectatorLiveSnapshot) == "function"
        and type(GetNativeSpectatorLiveSnapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.SPECTATOR_LIVE_NATIVE)
    end

    if type(RequestNativeCollectionWave1) == "function"
        and type(GetNativeCollectionWave1Snapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.COLLECTION_WAVE1_NATIVE)
    end

    if type(RequestNativeSeasonal) == "function"
        and type(GetNativeSeasonalSnapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.SEASONAL_NATIVE)
    end

    if type(RequestNativeHotspot) == "function"
        and type(GetNativeHotspotSnapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.HOTSPOT_NATIVE)
    end

    if type(RequestNativePrestige) == "function"
        and type(GetNativePrestigeSnapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.PRESTIGE_NATIVE)
    end

    if type(RequestNativeWorldContent) == "function"
        and type(GetNativeWorldContentSnapshot) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.WORLD_NATIVE)
    end

    -- The generic DC native message bridge (one client poll fn) carries every
    -- module registered server-side over SMSG_DC_NATIVE_MESSAGE.
    if type(GetNativeDcMessage) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.GENERIC_MESSAGE_NATIVE)
    end

    if type(PollDCNativeEnvelope) == "function" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.GENERIC_NATIVE_ENVELOPE)
    end

    if self:GetNativeExtensionBuildFingerprint()
        or type(self:GetNativeExtensionDataRevisions()) == "table" then
        capabilities = CombineCapabilities(capabilities,
            self.Capability.CLIENT_METADATA)
    end

    return capabilities
end

function DC:GetNativeExtensionBuildFingerprint()
    local getter = rawget(_G, "GetWotLKExtensionsBuildFingerprint")
    if type(getter) == "function" then
        local ok, fingerprint = pcall(getter)
        if ok and type(fingerprint) == "string" and fingerprint ~= "" then
            return fingerprint
        end
    end

    return nil
end

function DC:GetNativeExtensionDataRevisions()
    local getter = rawget(_G, "GetDCClientDataRevisions")
    if type(getter) ~= "function" then
        return nil
    end

    local ok, revisions = pcall(getter)
    if not ok or type(revisions) ~= "table" then
        return nil
    end

    -- The DLL values are per-session load counters (bumped on each LoadDB),
    -- not content revisions, so they can never match the server's required
    -- revision. Prefer the generator-embedded content revisions from the
    -- DC-Collection completeness manifest: the same values are stamped into
    -- the world DB (dc_client_data_revisions), so the handshake comparison
    -- succeeds exactly when the deployed client CDBC build is current.
    local collection = rawget(_G, "DCCollection")
    if type(collection) == "table" then
        local manifest = collection.COLLECTION_STATIC_MANIFEST
        if type(manifest) == "table" and
            type(manifest.dataRevisions) == "table" then
            for key, value in pairs(manifest.dataRevisions) do
                local numeric = tonumber(value)
                if numeric and numeric > 0 then
                    revisions[key] = numeric
                end
            end
        end
    end

    return revisions
end

function DC:GetNativeTooltipRuntimeSignature()
    local getter = rawget(_G, "GetSpellTooltipRuntimeSignature")
    if type(getter) == "function" then
        local ok, signature = pcall(getter)
        if ok and type(signature) == "string" and signature ~= "" then
            return signature
        end
    end

    return nil
end

function DC:GetClientCapabilities()
    local capabilities = CombineCapabilities(
        self.BASE_CAPABILITIES or self.CAPABILITIES or 0,
        self:GetNativeExtensionCapabilities())
    self.CAPABILITIES = capabilities
    self._clientCaps = capabilities
    return capabilities
end

function DC:HasClientCapability(capability)
    return HasCapabilityBit(self:GetClientCapabilities(), capability)
end

function DC:DescribeCapabilities(mask)
    local capabilities = tonumber(mask) or 0
    local parts = {}

    if HasCapabilityBit(capabilities, self.Capability.JSON_MESSAGES) then
        table.insert(parts, "JSON")
    end
    if HasCapabilityBit(capabilities, self.Capability.BATCH_MESSAGES) then
        table.insert(parts, "Batch")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.TOOLTIP_NATIVE_RESPONSE) then
        table.insert(parts, "NativeTooltip")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.BREAKING_NEWS_NATIVE) then
        table.insert(parts, "NativeBreakingNews")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.ITEM_UPGRADE_NATIVE) then
        table.insert(parts, "NativeItemUpgrade")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.NPC_TOOLTIP_NATIVE) then
        table.insert(parts, "NativeNpcTooltip")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.MYTHICPLUS_HUD_NATIVE) then
        table.insert(parts, "NativeMythicPlusHud")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.COLLECTION_TRANSMOG_STATE_NATIVE) then
        table.insert(parts, "NativeCollectionTransmogState")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.COLLECTION_ITEM_SETS_NATIVE) then
        table.insert(parts, "NativeCollectionItemSets")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.PING_RELAY_NATIVE) then
        table.insert(parts, "NativePingRelay")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.HLBG_LIVE_NATIVE) then
        table.insert(parts, "NativeHLBGLive")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.SPECTATOR_LIVE_NATIVE) then
        table.insert(parts, "NativeSpectatorLive")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.COLLECTION_WAVE1_NATIVE) then
        table.insert(parts, "NativeCollectionWave1")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.SEASONAL_NATIVE) then
        table.insert(parts, "NativeSeasonal")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.HOTSPOT_NATIVE) then
        table.insert(parts, "NativeHotspot")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.PRESTIGE_NATIVE) then
        table.insert(parts, "NativePrestige")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.WORLD_NATIVE) then
        table.insert(parts, "NativeWorld")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.GENERIC_MESSAGE_NATIVE) then
        table.insert(parts, "NativeGenericMessage")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.GENERIC_NATIVE_ENVELOPE) then
        table.insert(parts, "GenericNativeEnvelope")
    end
    if HasCapabilityBit(capabilities,
            self.Capability.CLIENT_METADATA) then
        table.insert(parts, "ClientMetadata")
    end

    if #parts == 0 then
        return "None"
    end

    return table.concat(parts, ", ")
end

local function SanitizeHandshakeText(value, maxLen)
    if type(value) ~= "string" then
        return nil
    end

    value = string.gsub(value, "|", "/")
    value = string.gsub(value, "%c", "")
    if value == "" then
        return nil
    end

    if maxLen and #value > maxLen then
        value = string.sub(value, 1, maxLen)
    end

    return value
end

function DC:GetHandshakeMetadataPayload()
    local metadata = { v = 1 }
    local hasFields = false

    local fingerprint = SanitizeHandshakeText(
        self:GetNativeExtensionBuildFingerprint(), 96)
    if fingerprint then
        metadata.b = fingerprint
        hasFields = true
    end

    local revisions = self:GetNativeExtensionDataRevisions()
    if type(revisions) == "table" then
        local compact = {}
        local function addRevision(compactKey, longKey)
            local value = tonumber(revisions[compactKey])
                or tonumber(revisions[longKey])
            if value and value > 0 then
                compact[compactKey] = value
            end
        end

        addRevision("cc", "collectionCategories")
        addRevision("cs", "collectionSources")
        addRevision("shop", "collectionShop")
        addRevision("set", "collectionSets")
        addRevision("xmog", "collectionTransmog")
        addRevision("iut", "itemUpgradeTiers")

        if next(compact) ~= nil then
            metadata.d = compact
            hasFields = true
        end
    end

    if not hasFields then
        return nil
    end

    return self:EncodeJSON(metadata)
end

function DC:GetHandshakeVersionString()
    return tostring(self.VERSION) .. "|" .. tostring(self:GetClientCapabilities())
end

local function ParseServerHandshakeBoolean(value)
    if value == true or value == 1 then
        return true
    end
    if value == false or value == 0 or value == nil then
        return false
    end
    if type(value) == "string" then
        local lowered = string.lower(value)
        return lowered == "1" or lowered == "true" or lowered == "yes"
            or lowered == "on"
    end
    return false
end

local function NormalizeServerDataFeatureStateEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local state = tostring(entry.state or entry.s or "")
    if state == "" then
        return nil
    end

    return {
        state = state,
        requiredRevision = tonumber(entry.requiredRevision or entry.rr) or 0,
        installedRevision = tonumber(entry.installedRevision or entry.ir) or 0,
        fallbackAllowed = ParseServerHandshakeBoolean(
            entry.fallbackAllowed or entry.fa),
        reason = tostring(entry.reason or entry.r or ""),
    }
end

local function ParseServerHandshakeMetadataPayload(payload)
    local decoded = nil
    if type(payload) == "table" then
        decoded = payload
    elseif type(payload) == "string" and payload ~= "" then
        local ok, parsed = pcall(function()
            return DC:DecodeJSON(payload)
        end)
        if ok and type(parsed) == "table" then
            decoded = parsed
        end
    end

    if type(decoded) ~= "table" then
        return nil
    end

    local normalizedStates = {}
    local featureStates = decoded.dataFeatureStates or decoded.f
    if type(featureStates) == "table" then
        for featureKey, entry in pairs(featureStates) do
            local normalized = NormalizeServerDataFeatureStateEntry(entry)
            if normalized then
                normalizedStates[tostring(featureKey)] = normalized
            end
        end
    end

    return {
        version = tonumber(decoded.v) or 0,
        dataFeatureStates = next(normalizedStates) and normalizedStates or nil,
        raw = type(payload) == "string" and payload or nil,
    }
end

function DC:GetCapabilitySnapshot()
    local nativeCaps = tonumber(self:GetNativeExtensionCapabilities()) or 0
    local clientCaps = tonumber(self:GetClientCapabilities()) or 0
    local negotiatedCaps = tonumber(self._serverCaps) or 0

    return {
        nativeCaps = nativeCaps,
        nativeBuildFingerprint = self:GetNativeExtensionBuildFingerprint(),
        nativeDataRevisions = self:GetNativeExtensionDataRevisions(),
        nativeTooltipRuntimeSignature = self:GetNativeTooltipRuntimeSignature(),
        clientCaps = clientCaps,
        negotiatedCaps = negotiatedCaps,
        handshake = tostring(self.VERSION) .. "|" .. tostring(clientCaps),
        handshakeMetadata = self:GetHandshakeMetadataPayload(),
        connected = self._connected and true or false,
        serverVersion = self._serverVersion,
        serverHandshakeMetadata = self._serverHandshakeMetadata,
        serverDataFeatureStates = self._serverDataFeatureStates,
        lastHandshakeAck = self._lastHandshakeAck,
    }
end

function DC:PrintCapabilityStatus()
    local snapshot = self:GetCapabilitySnapshot()

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r Capability snapshot")
    DEFAULT_CHAT_FRAME:AddMessage("  Connected: " .. (snapshot.connected and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    DEFAULT_CHAT_FRAME:AddMessage("  Handshake: |cff00ccff" .. tostring(snapshot.handshake) .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "  Native Caps: |cff00ccff0x%X|r (%s)",
        snapshot.nativeCaps,
        self:DescribeCapabilities(snapshot.nativeCaps)))
    if snapshot.nativeBuildFingerprint then
        DEFAULT_CHAT_FRAME:AddMessage(
            "  Native Build: |cff00ccff"
            .. tostring(snapshot.nativeBuildFingerprint)
            .. "|r")
    end
    if type(snapshot.nativeDataRevisions) == "table" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  Native Data Revisions: |cff00ccffcat=%s src=%s shop=%s set=%s xmog=%s tiers=%s|r",
            tostring(snapshot.nativeDataRevisions.collectionCategories or snapshot.nativeDataRevisions.cc or 0),
            tostring(snapshot.nativeDataRevisions.collectionSources or snapshot.nativeDataRevisions.cs or 0),
            tostring(snapshot.nativeDataRevisions.collectionShop or snapshot.nativeDataRevisions.shop or 0),
            tostring(snapshot.nativeDataRevisions.collectionSets or snapshot.nativeDataRevisions.set or 0),
            tostring(snapshot.nativeDataRevisions.collectionTransmog or snapshot.nativeDataRevisions.xmog or 0),
            tostring(snapshot.nativeDataRevisions.itemUpgradeTiers or snapshot.nativeDataRevisions.iut or 0)))
    end
    if snapshot.nativeTooltipRuntimeSignature then
        DEFAULT_CHAT_FRAME:AddMessage(
            "  Native Tooltip Runtime: |cff00ccff"
            .. tostring(snapshot.nativeTooltipRuntimeSignature)
            .. "|r")
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "  Client Caps: |cff00ccff0x%X|r (%s)",
        snapshot.clientCaps,
        self:DescribeCapabilities(snapshot.clientCaps)))
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "  Negotiated Caps: |cff00ccff0x%X|r (%s)",
        snapshot.negotiatedCaps,
        self:DescribeCapabilities(snapshot.negotiatedCaps)))
    if snapshot.serverVersion then
        DEFAULT_CHAT_FRAME:AddMessage("  Server Version: |cff00ccff" .. tostring(snapshot.serverVersion) .. "|r")
    end
    if type(snapshot.serverDataFeatureStates) == "table" then
        local policyParts = {}

        local function addPolicy(label, key)
            local state = snapshot.serverDataFeatureStates[key]
            if type(state) ~= "table" then
                return
            end

            policyParts[#policyParts + 1] = string.format(
                "%s=%s(req=%s installed=%s fallback=%s)",
                label,
                tostring(state.state or "unknown"),
                tostring(state.requiredRevision or 0),
                tostring(state.installedRevision or 0),
                tostring(state.fallbackAllowed == true))
        end

        addPolicy("cat", "collectionCategories")
        addPolicy("src", "collectionSources")
        addPolicy("shop", "collectionShop")
        addPolicy("set", "collectionSets")
        addPolicy("xmog", "collectionTransmog")

        if #policyParts > 0 then
            DEFAULT_CHAT_FRAME:AddMessage(
                "  Data Policy: |cff00ccff" .. table.concat(policyParts, " | ") .. "|r")
        end
    end
    if snapshot.lastHandshakeAck then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  ACK Parser: |cff00ccff%s|r raw2=%s raw3=%s raw4=%s",
            tostring(snapshot.lastHandshakeAck.parserMode or "unknown"),
            tostring(snapshot.lastHandshakeAck.rawArg2 or "<nil>"),
            tostring(snapshot.lastHandshakeAck.rawArg3 or "<nil>"),
            tostring(snapshot.lastHandshakeAck.rawArg4 or "<nil>")))
    end

    self:LogNetEvent("info", "caps", string.format(
        "snapshot native=0x%X client=0x%X negotiated=0x%X connected=%s server=%s",
        snapshot.nativeCaps,
        snapshot.clientCaps,
        snapshot.negotiatedCaps,
        tostring(snapshot.connected),
        tostring(snapshot.serverVersion or "nil")))
end

function DC:SendHandshake(reason)
    local why = tostring(reason or "manual")

    -- Single-flight: several boot paths (ADDON_LOADED, PLAYER_LOGIN) can each
    -- request a handshake within the same login; one per 2s is enough. Manual
    -- reconnects (slash command / settings button) always go through.
    local now = (type(GetTime) == "function" and GetTime()) or 0
    local isManual = string.find(why, "manual", 1, true) or why == "settings-panel"
    if now > 0 and not isManual and self._lastHandshakeSentAt
        and (now - self._lastHandshakeSentAt) < 2 then
        self:LogNetEvent("info", "handshake", "suppressed duplicate send reason=" .. why)
        return
    end
    if now > 0 then
        self._lastHandshakeSentAt = now
    end

    local snapshot = self:GetCapabilitySnapshot()
    local metadataBytes = snapshot.handshakeMetadata and #snapshot.handshakeMetadata or 0

    self:LogNetEvent("info", "handshake", string.format(
        "send reason=%s native=0x%X client=0x%X payload=%s metadataBytes=%d",
        why,
        snapshot.nativeCaps,
        snapshot.clientCaps,
        snapshot.handshake,
        metadataBytes))

    if snapshot.handshakeMetadata then
        self:Send("CORE", 1, snapshot.handshake, snapshot.handshakeMetadata)
        return
    end

    self:Send("CORE", 1, snapshot.handshake)
end

function DC:NextRequestId()
    self._requestIdCounter = (self._requestIdCounter or 0) + 1
    if self._requestIdCounter > 999999 then
        self._requestIdCounter = 1
        self._requestIdEpoch = (self._requestIdEpoch or 0) + 1
        if self._requestIdEpoch > 99 then
            self._requestIdEpoch = 0
        end
    end
    -- Format: timestamp-epoch-counter for guaranteed uniqueness
    local t = time() or 0
    local epoch = self._requestIdEpoch or 0
    return string.format("%d-%d-%d", t, epoch, self._requestIdCounter)
end

function DC:GetServerContext()
    return self._serverContext
end

function DC:RegisterServerContextHandler(handler)
    if type(handler) ~= "function" then return false end
    table.insert(self._serverContextHandlers, handler)
    if self._serverContext then
        self:_InvokeHandlerSafe("server-context", "CORE", 0x14, handler, self._serverContext)
    end
    return true
end

function DC:RegisterCrossEventHandler(handler)
    if type(handler) ~= "function" then return false end
    table.insert(self._crossEventHandlers, handler)
    return true
end

-- ============================================================================
-- RECONNECTION / HANDSHAKE MANAGEMENT
-- ============================================================================

function DC:_AttemptReconnect()
    if self._connected or self._handshakePending then
        return
    end
    
    self._handshakePending = true
    self._lastHandshakeTime = time()
    self._reconnectAttempts = (self._reconnectAttempts or 0) + 1
    
    if self._debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888[DC]|r Attempting reconnect (" .. self._reconnectAttempts .. "/" .. (self._maxReconnectAttempts or 5) .. ")...")
    end
    
    self:LogNetEvent("info", "reconnect", "Attempting handshake (attempt " .. self._reconnectAttempts .. ")")
    self:SendHandshake("reconnect-attempt")
    
    -- Clear pending flag after a timeout (in case server doesn't respond)
    -- This is handled in _CheckRequestTimeouts implicitly via the handshake request timing out
end

function DC:_OnHandshakeSuccess()
    self._connected = true
    self._handshakePending = false
    self._reconnectAttempts = 0
    self:LogNetEvent("info", "handshake", "Connected successfully to server v" .. (self._serverVersion or "?"))
end

function DC:_OnHandshakeFailed(reason)
    self._connected = false
    self._handshakePending = false
    self:LogNetEvent("error", "handshake", "Handshake failed: " .. (reason or "unknown"))
end

function DC:EnsureConnected()
    if not self._connected and not self._handshakePending then
        local now = time()
        if now - (self._lastHandshakeTime or 0) > 5 then
            self:_AttemptReconnect()
        end
    end
    return self._connected
end

-- ============================================================================
-- SAVED VARIABLES (Settings + NetLog)
-- ============================================================================

DEFAULT_DB = {
    -- Controls detailed request/response logging. Keep off by default for performance.
    loggingEnabled = false,

    -- Chat output controls
    chatOnError = true,
    chatOnRequestTimeout = true,
    chatOnChunkTimeout = true,

    -- Timeout thresholds
    requestTimeoutSec = 30,
    chunkTimeoutSec = 10,

    -- NetLog ring buffer
    netLogEnabled = true,
    netLogMaxEntries = 200,
}

function DC:_InitDB()
    DCAddonProtocolDB = DCAddonProtocolDB or {}
    for k, v in pairs(DEFAULT_DB) do
        if DCAddonProtocolDB[k] == nil then
            DCAddonProtocolDB[k] = v
        end
    end
    if type(DCAddonProtocolDB.netLog) ~= "table" then
        DCAddonProtocolDB.netLog = CreateCircularBuffer(
            DEFAULT_DB.netLogMaxEntries,
            DEFAULT_DB.netLogMaxEntries,
            10)
    end

    self._settings = DCAddonProtocolDB
    -- Apply persisted loggingEnabled on load.
    self._loggingEnabled = (DCAddonProtocolDB.loggingEnabled and true or false)
    self:_EnsureNetLogBuffer()
end

function DC:GetSetting(key)
    if not self._settings then
        self:_InitDB()
    end
    return self._settings and self._settings[key]
end

function DC:SetSetting(key, value)
    if not self._settings then
        self:_InitDB()
    end
    if not self._settings then return end
    self._settings[key] = value

    if key == "loggingEnabled" then
        self._loggingEnabled = value and true or false
    elseif key == "netLogMaxEntries" then
        self:_EnsureNetLogBuffer()
    end
end

function DC:LogNetEvent(level, tag, message, extra)
    if not self._settings then
        self:_InitDB()
    end
    if not (self._settings and self._settings.netLogEnabled) then
        return
    end

    local log = self:_EnsureNetLogBuffer()

    AppendCircularBuffer(log, {
        t = time(),
        level = tostring(level or "info"),
        tag = tostring(tag or ""),
        msg = tostring(message or ""),
        extra = extra,
    })
end

function DC:DumpNetLog(n)
    if not self._settings then
        self:_InitDB()
    end
    local log = self:_EnsureNetLogBuffer()
    local total = GetCircularBufferCount(log)
    if total == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r NetLog: (empty)")
        return
    end

    n = tonumber(n) or 20
    if n < 1 then n = 1 end
    if n > total then n = total end

    local entries = GetCircularBufferEntries(log, n, false)

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ccff[DC]|r NetLog: last %d/%d", n, total))
    for i = 1, #entries do
        local e = entries[i]
        local ts = (e and e.t and date("%H:%M:%S", e.t)) or "??:??:??"
        local lvl = (e and e.level) or "?"
        local tg = (e and e.tag and e.tag ~= "" and ("/" .. e.tag) or "") or ""
        local msg = (e and e.msg) or ""
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff888888[DC NetLog]|r %s [%s%s] %s", ts, lvl, tg, msg))
    end
end

function DC:ClearNetLog()
    if not self._settings then
        self:_InitDB()
    end
    if self._settings then
        self._settings.netLog = ClearCircularBuffer(
            self._settings.netLog,
            self._settings.netLogMaxEntries,
            DEFAULT_DB.netLogMaxEntries,
            10)
    end
end

function DC:_ChatNotifyTimeout(kind, module, opcode, ageSec)
    module = tostring(module or "?")
    opcode = tonumber(opcode) or 0
    ageSec = tonumber(ageSec) or 0
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff4444[DC] %s timeout:|r %s op=%d (age=%ds)", tostring(kind or "Request"), module, opcode, ageSec))
end

function DC:_CheckRequestTimeouts()
    -- Defensive initialization
    if not self._pendingRequests then
        self._pendingRequests = {}
        return
    end
    if not self._pendingRequestsLegacy then
        self._pendingRequestsLegacy = {}
    end
    if not self._stats then
        self._stats = { totalRequests = 0, totalResponses = 0, totalTimeouts = 0, avgResponseTime = 0, moduleStats = {}, sessionStart = time() }
    end

    local timeoutSec = tonumber(self:GetSetting("requestTimeoutSec")) or 30
    if timeoutSec < 3 then timeoutSec = 3 end

    local now = time()
    local keysToRemove = {}  -- Collect keys to remove (avoid modifying table during iteration)
    
    for key, entry in pairs(self._pendingRequests) do
        if entry and entry.status == "pending" then
            local age = now - (entry.timestamp or now)
            if age >= timeoutSec then
                entry.status = "timeout"
                entry.responseTime = age

                -- Stats
                if type(self.UpdateStats) == "function" then
                    self:UpdateStats("timeout", entry)
                else
                    self._stats.totalTimeouts = (self._stats.totalTimeouts or 0) + 1
                end

                -- NetLog + Chat
                self:LogNetEvent("timeout", "request", string.format("%s op=%d timed out", tostring(entry.module or "?"), tonumber(entry.opcode) or 0), {
                    module = entry.module,
                    opcode = entry.opcode,
                    age = age,
                })

                if self:GetSetting("chatOnRequestTimeout") then
                    self:_ChatNotifyTimeout("Request", entry.module, entry.opcode, age)
                end

                table.insert(keysToRemove, { key = key, legacyKey = entry._legacyKey })
            end
        end
    end
    
    -- Remove timed-out entries after iteration
    for _, item in ipairs(keysToRemove) do
        self._pendingRequests[item.key] = nil
        if item.legacyKey then
            self._pendingRequestsLegacy[item.legacyKey] = nil
        end
    end
end

-- Maximum chunks allowed per message (security: prevent memory exhaustion)
DC.MAX_CHUNKS_PER_MESSAGE = 2048  -- Supports large collection/transmog syncs
-- Maximum JSON payload size (security: prevent parsing abuse)
DC.MAX_JSON_PAYLOAD_SIZE = 524288  -- 512KB (supports large collection/transmog syncs)

function DC:_CleanupChunkBuffers()
    if not self._chunkBuffers then
        self._chunkBuffers = {}
        return
    end
    if not self._chunkMsgIds then
        self._chunkMsgIds = {}
    end

    local timeoutSec = tonumber(self:GetSetting("chunkTimeoutSec")) or 10
    if timeoutSec < 2 then timeoutSec = 2 end

    local now = time()
    for sender, buf in pairs(self._chunkBuffers) do
        if buf and buf.ts and (now - buf.ts) > timeoutSec then
            self._chunkBuffers[sender] = nil
            -- Also drop the msg-id bookkeeping for this sender: it was only
            -- freed on successful reassembly, so timed-out chunk streams
            -- leaked one _chunkMsgIds entry per sender+chunk-count forever.
            for baseKey in pairs(self._chunkMsgIds) do
                if string.find(baseKey, tostring(sender), 1, true) then
                    self._chunkMsgIds[baseKey] = nil
                end
            end
            self:LogNetEvent("timeout", "chunk", "Chunked message reassembly timed out", {
                sender = sender,
                received = buf.received,
                total = buf.total,
            })
            if self:GetSetting("chatOnChunkTimeout") then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff4444[DC] Chunk timeout:|r sender=%s (%d/%d)", tostring(sender), tonumber(buf.received) or 0, tonumber(buf.total) or 0))
            end
        end
    end
end

-- Ensure the addon-message prefix is registered (required for SendAddonMessage/CHAT_MSG_ADDON)
if type(RegisterAddonMessagePrefix) == "function" then
    pcall(RegisterAddonMessagePrefix, DC.PREFIX)
end

-- ============================================================================
-- ChatFrame Channel Name Protection (WoW 3.3.5a Bug Fix)
-- ============================================================================
-- Fixes: "bad argument #1 to 'format' (string expected, got nil)"
-- This occurs when ChatFrame.lua tries to format a channel message
-- but the channel name is nil (common after teleporting to a new map).
-- We hook ChatFrame_MessageEventHandler to protect against nil channel names.
-- ============================================================================
do
    local orig_ChatFrame_MessageEventHandler = ChatFrame_MessageEventHandler
    if orig_ChatFrame_MessageEventHandler then
        ChatFrame_MessageEventHandler = function(self, event, ...)
            -- Only process CHAT_MSG_CHANNEL and CHAT_MSG_CHANNEL_NOTICE events for protection
            if event == "CHAT_MSG_CHANNEL" then
                -- arg7 is the channel number, arg8 is the channel name in 3.3.5a
                local msg, sender, lang, channelString, _, _, channelNumber, channelName = ...
                
                -- If channel name is nil, the format() call in ChatFrame.lua will fail
                -- We can either skip the message entirely or provide a fallback
                if channelNumber and (not channelName or channelName == "") then
                    -- Try to get the channel name ourselves
                    local id, name = GetChannelName(channelNumber)
                    if not name or name == "" then
                        -- Channel not yet initialized, silently skip this message
                        -- It's usually just a join/leave message during teleport
                        return
                    end
                end
            elseif event == "CHAT_MSG_CHANNEL_NOTICE" then
                -- arg1 (notice type) is used to look up a global string in ChatFrame.lua
                -- If the global string is missing, format() will throw. Provide a safe fallback.
                local noticeType = ...
                if type(noticeType) == "string" and noticeType ~= "" then
                    local noticeKey = "CHAT_" .. noticeType .. "_NOTICE"
                    if not _G[noticeKey] then
                        -- Keep fallback format-token free so string.format never errors.
                        _G[noticeKey] = "Channel notice."
                    end

                    local noticeBNKey = noticeKey .. "_BN"
                    if not _G[noticeBNKey] then
                        _G[noticeBNKey] = _G[noticeKey]
                    end
                end
            end
            
            -- Call original handler
            return orig_ChatFrame_MessageEventHandler(self, event, ...)
        end
        DC._chatFrameProtected = true
    end
end

-- Module names for display (keys must match actual module codes)
DC.ModuleNames = {
    CORE = "Core",
    AOE = "AOE Loot",
    SPOT = "Hotspot",
    UPG = "Item Upgrade",
    SPEC = "Spectator",
    DUEL = "Phased Duels",
    MPLUS = "Mythic+",
    SEAS = "Seasonal",
    PRES = "Prestige",
    HLBG = "Hinterland BG",
    LBRD = "Leaderboards",
    WELC = "Welcome",
    GRPF = "Group Finder",
    GOMV = "GOMove",
    TELE = "Teleports",
    MPOI = "Map POIs",
    QNAV = "Quest Navigation",
    DENC = "Boss Tracker",
    EVNT = "Events",
    WRLD = "World",
    COLL = "Collection",
    QOS = "Quality of Service",
}

-- Shared Keystone item IDs mapping for client addons (faster inventory detection)
-- These are the default keystone item IDs (M+2 through M+20). The server will send
-- an updated list via SMSG_KEYSTONE_LIST on login if needed.
DC:SetKeystoneItemIds()

-- Shared scan tooltip accessor. If DCCentral exposes one (DCScanTooltip), use it; otherwise DC will lazily create a fallback.
function DC:GetScanTooltip()
    if self.ScanTooltip and type(self.ScanTooltip) == "table" then
        return self.ScanTooltip
    end
    -- Check for DCCentral provided tooltip first
    local globalTT = rawget(_G, "DCScanTooltip")
    if globalTT then
        self.ScanTooltip = globalTT
        return self.ScanTooltip
    end
    -- Create lazy fallback tooltip if not present
    if not self.ScanTooltip then
        local tt = CreateFrame("GameTooltip", "DCScanTooltip", nil, "GameTooltipTemplate")
        tt:SetOwner(WorldFrame, "ANCHOR_NONE")
        self.ScanTooltip = tt
    end
    return self.ScanTooltip
end

-- Ensure we link to the shared tooltip if present after addon load
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self)
        if rawget(_G, "DCScanTooltip") then
            DC.ScanTooltip = rawget(_G, "DCScanTooltip")
        end
    end)
end

-- Group Finder Opcodes
DC.GroupFinderOpcodes = {
    -- Client -> Server: Listings
    CMSG_CREATE_LISTING      = 0x10,  -- Create a new group listing
    CMSG_SEARCH_LISTINGS     = 0x11,  -- Search for groups
    CMSG_APPLY_TO_GROUP      = 0x12,  -- Apply to join a group
    CMSG_CANCEL_APPLICATION  = 0x13,  -- Cancel pending application
    CMSG_ACCEPT_APPLICATION  = 0x14,  -- Leader accepts an applicant
    CMSG_DECLINE_APPLICATION = 0x15,  -- Leader declines an applicant
    CMSG_DELIST_GROUP        = 0x16,  -- Remove group listing
    CMSG_UPDATE_LISTING      = 0x17,  -- Update group listing
    CMSG_GET_MY_APPLICATIONS = 0x18,  -- Get my active applications

    -- Client -> Server: Auto-matchmaking queue (LFG-style)
    CMSG_QUEUE_JOIN              = 0x19,  -- Join the matchmaking queue
    CMSG_QUEUE_LEAVE             = 0x1A,  -- Leave the matchmaking queue
    CMSG_QUEUE_STATUS_REQUEST    = 0x1B,  -- Request current queue status
    CMSG_QUEUE_PROPOSAL_RESPONSE = 0x1C,  -- Accept/decline a match proposal
    CMSG_GET_QUEUE_CATALOG       = 0x1D,  -- Request mythic dungeon + raid catalog

    -- Client -> Server: Keystone & Difficulty
    CMSG_GET_MY_KEYSTONE     = 0x20,  -- Request player's keystone info
    CMSG_SET_DIFFICULTY      = 0x21,  -- Request difficulty change
    CMSG_GET_DUNGEON_LIST    = 0x22,  -- Get M+ dungeon list from DB
    CMSG_GET_RAID_LIST       = 0x23,  -- Get raid list from DB
    CMSG_GET_SYSTEM_INFO     = 0x24,  -- Get system config (rewards, etc)
    
    -- Client -> Server: Spectating
    CMSG_START_SPECTATE      = 0x25,  -- Request to spectate a run
    CMSG_STOP_SPECTATE       = 0x26,  -- Stop spectating
    CMSG_GET_SPECTATE_LIST   = 0x27,  -- Get available runs to spectate
    
    -- Client -> Server: Scheduled Events
    CMSG_CREATE_EVENT        = 0x60,  -- Create scheduled event
    CMSG_SIGNUP_EVENT        = 0x61,  -- Sign up for event
    CMSG_CANCEL_SIGNUP       = 0x62,  -- Cancel event signup
    CMSG_GET_SCHEDULED_EVENTS= 0x63,  -- Get upcoming events
    CMSG_GET_MY_SIGNUPS      = 0x64,  -- Get my event signups
    CMSG_CANCEL_EVENT        = 0x65,  -- Cancel event (leader only)
    
    -- Server -> Client: Listings
    SMSG_LISTING_CREATED     = 0x30,  -- Confirm listing created
    SMSG_SEARCH_RESULTS      = 0x31,  -- Search results
    SMSG_APPLICATION_STATUS  = 0x32,  -- Application accepted/declined
    SMSG_NEW_APPLICATION     = 0x33,  -- Leader: new applicant
    SMSG_GROUP_UPDATED       = 0x34,  -- Group composition changed
    SMSG_MY_APPLICATIONS     = 0x35,  -- List of my active applications

    -- Server -> Client: Auto-matchmaking queue (LFG-style)
    SMSG_QUEUE_JOINED          = 0x36,  -- Confirm joined the queue
    SMSG_QUEUE_LEFT            = 0x37,  -- Confirm left the queue
    SMSG_QUEUE_STATUS          = 0x38,  -- Queue status (counts/role needs)
    SMSG_QUEUE_PROPOSAL        = 0x39,  -- Match found -> ready check
    SMSG_QUEUE_PROPOSAL_UPDATE = 0x3A,  -- Proposal accept progress
    SMSG_QUEUE_PROPOSAL_FAILED = 0x3B,  -- Proposal failed (declined/timeout)
    SMSG_QUEUE_CATALOG         = 0x3C,  -- Mythic dungeon + raid catalog

    -- Server -> Client: Keystone & Difficulty
    SMSG_KEYSTONE_INFO       = 0x40,  -- Player's keystone data
    SMSG_DIFFICULTY_CHANGED  = 0x41,  -- Confirm difficulty changed
    SMSG_DUNGEON_LIST        = 0x42,  -- M+ dungeon list from DB
    SMSG_RAID_LIST           = 0x43,  -- Raid list from DB
    SMSG_SYSTEM_INFO         = 0x44,  -- System config (rewards, etc)
    
    -- Server -> Client: Spectating
    SMSG_SPECTATE_DATA       = 0x45,  -- Spectator live data
    SMSG_SPECTATE_LIST       = 0x47,  -- Available runs to spectate
    SMSG_SPECTATE_STARTED    = 0x48,  -- Spectating started
    SMSG_SPECTATE_ENDED      = 0x49,  -- Spectating ended
    SMSG_OPEN_UI             = 0x50,  -- Open the Group Finder UI
    
    -- Server -> Client: Scheduled Events
    SMSG_EVENT_CREATED       = 0x70,  -- Event created confirmation
    SMSG_EVENT_SIGNUP_RESULT = 0x71,  -- Signup result
    SMSG_SCHEDULED_EVENTS    = 0x72,  -- List of events
    SMSG_MY_SIGNUPS          = 0x73,  -- My event signups
    
    -- Server -> Client: Errors
    SMSG_ERROR               = 0x5F,  -- Error response
}

-- Log a request (only when logging is enabled for performance)
function DC:LogRequest(module, opcode, data, requestId)
    -- Fast path: skip logging if disabled (performance optimization)
    if not self._loggingEnabled then
        -- Still track basic stats for display
        self._stats.totalRequests = (self._stats.totalRequests or 0) + 1
        return nil
    end

    local requestLog = self:_EnsureRequestLogBuffer()
    self._requestLogSeq = (tonumber(self._requestLogSeq) or 0) + 1
    
    local entry = {
        id = self._requestLogSeq,
        timestamp = time(),
        timeStr = date("%H:%M:%S"),
        player = UnitName("player"),
        module = module,
        moduleName = self.ModuleNames[module] or module,
        opcode = opcode,
        data = data,
        requestId = requestId,
        status = "pending",
        responseTime = nil,
    }

    AppendCircularBuffer(requestLog, entry)
    
    -- Track pending request
    if requestId then
        self._pendingRequests[requestId] = entry
        local legacyKey = module .. "_" .. tostring(opcode)
        self._pendingRequestsLegacy[legacyKey] = requestId
        entry._legacyKey = legacyKey
    else
        local legacyKey = module .. "_" .. tostring(opcode)
        self._pendingRequests[legacyKey] = entry
        entry._legacyKey = legacyKey
    end
    
    -- Update statistics
    self:UpdateStats("request", entry)
    
    return entry
end

-- Log a response (only when logging is enabled for performance)
function DC:LogResponse(module, opcode, data, jsonStr, requestId)
    -- Fast path: skip logging if disabled (performance optimization)
    if not self._loggingEnabled then
        -- Still track basic stats for display
        self._stats.totalResponses = (self._stats.totalResponses or 0) + 1
        return nil
    end

    local responseLog = self:_EnsureResponseLogBuffer()
    self._responseLogSeq = (tonumber(self._responseLogSeq) or 0) + 1
    
    local entry = {
        id = self._responseLogSeq,
        timestamp = time(),
        timeStr = date("%H:%M:%S"),
        player = UnitName("player"),
        module = module,
        moduleName = self.ModuleNames[module] or module,
        opcode = opcode,
        data = data,
        jsonLength = jsonStr and #jsonStr or 0,  -- Use # instead of string.len
        requestId = requestId,
    }

    AppendCircularBuffer(responseLog, entry)
    
    -- Update statistics
    self:UpdateStats("response", entry)
    
    -- Check if this was a pending request (response opcode is usually request + 0x0F)
    -- e.g., CMSG 0x01 -> SMSG 0x10
    local pending = nil
    local resolvedRequestId = requestId
    if requestId then
        pending = self._pendingRequests[requestId]
    end
    if not pending then
        local requestOpcode = opcode - 0x0F
        if requestOpcode > 0 then
            local key = module .. "_" .. tostring(requestOpcode)
            local rid = self._pendingRequestsLegacy[key]
            if rid then
                resolvedRequestId = rid
                pending = self._pendingRequests[rid]
            else
                pending = self._pendingRequests[key]
            end
        end
    end
    if pending then
        pending.status = "completed"
        pending.responseTime = time() - pending.timestamp

        -- Update module avg response time
        local mod = module
        if self._stats.moduleStats[mod] then
            local stats = self._stats.moduleStats[mod]
            stats.totalResponseTime = stats.totalResponseTime + pending.responseTime
            stats.avgResponseTime = stats.totalResponseTime / stats.responses
        end

        if resolvedRequestId and self._pendingRequests[resolvedRequestId] then
            self._pendingRequests[resolvedRequestId] = nil
        end
        if pending._legacyKey and self._pendingRequestsLegacy[pending._legacyKey] then
            self._pendingRequestsLegacy[pending._legacyKey] = nil
        end
    end
    
    return entry
end

-- Enable or disable detailed logging (for performance)
function DC:EnableLogging(enabled)
    self:SetSetting("loggingEnabled", enabled and true or false)
    if enabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Detailed logging enabled")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Detailed logging disabled (performance mode)")
    end
end

-- Get request log for display
function DC:GetRequestLog(limit)
    return GetCircularBufferEntries(self:_EnsureRequestLogBuffer(), limit or 20, true)
end

-- Get response log for display
function DC:GetResponseLog(limit)
    return GetCircularBufferEntries(self:_EnsureResponseLogBuffer(), limit or 20, true)
end

-- Get pending requests
function DC:GetPendingRequests()
    local result = {}
    for key, entry in pairs(self._pendingRequests) do
        -- Check if request is stale (over 30 seconds)
        if time() - entry.timestamp > 30 then
            entry.status = "timeout"
        end
        table.insert(result, entry)
    end
    return result
end

-- Clear logs
function DC:ClearLogs()
    self._requestLog = ClearCircularBuffer(self._requestLog,
        self._requestLogMax, 100, 10)
    self._responseLog = ClearCircularBuffer(self._responseLog,
        self._responseLogMax, 100, 10)
    self._requestLogSeq = 0
    self._responseLogSeq = 0
    self._pendingRequests = {}
    self._pendingRequestsLegacy = {}
end

function DC:_InvokeHandlerSafe(handlerKind, module, opcode, handler, ...)
    if type(handler) ~= "function" then
        return false
    end

    local ok, err = pcall(handler, ...)
    if not ok then
        local errText = tostring(err or "unknown")
        self:LogNetEvent("error", "handler", "Handler execution failed", {
            kind = handlerKind,
            module = module,
            opcode = opcode,
            error = errText,
        })

        if self._debug or self:GetSetting("chatOnError") then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffff4444[DC]|r Handler error (" .. tostring(handlerKind)
                .. ") " .. tostring(module or "?")
                .. " op=" .. tostring(opcode or "?")
                .. ": " .. errText
            )
        end
    end

    return ok
end

-- Actually hand a payload to the game. The only caller that should reach this
-- directly is the throttle drain below (plus urgent bypasses).
function DC:_SendAddonWhisperNow(msg)
    if type(SendAddonMessage) ~= "function" then
        self:LogNetEvent("error", "send", "SendAddonMessage API unavailable")
        return false
    end

    local target = UnitName and UnitName("player")
    if not target or target == "" then
        self:LogNetEvent("error", "send", "Player target unavailable for addon whisper")
        return false
    end

    local ok, err = pcall(SendAddonMessage, self.PREFIX, msg, "WHISPER", target)
    if not ok then
        self:LogNetEvent("error", "send", "SendAddonMessage failed", {
            error = tostring(err or "unknown"),
            size = string.len(msg),
        })

        if self._debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[DC]|r SendAddonMessage failed: " .. tostring(err))
        end
        return false
    end

    self._throttle.stats.sent = self._throttle.stats.sent + 1
    return true
end

-- Refill the token bucket from elapsed wall time.
function DC:_ThrottleRefill()
    local t = self._throttle
    local now = GetTime and GetTime() or 0

    if not t.lastRefill then
        t.lastRefill = now
        return
    end

    local elapsed = now - t.lastRefill
    if elapsed <= 0 then
        return
    end
    t.lastRefill = now

    t.tokens = math.min(t.burst, (t.tokens or 0) + elapsed * (t.refillPerSec or 1))
end

-- Send as many queued payloads as the bucket currently affords. FIFO, so the
-- chunks of a chunked message stay contiguous and in order (SendChunked
-- enqueues them all synchronously).
function DC:_ThrottleDrain()
    local t = self._throttle
    if not t.enabled or #t.queue == 0 then
        return
    end

    self:_ThrottleRefill()

    while #t.queue > 0 and (t.tokens or 0) >= 1 do
        local msg = table.remove(t.queue, 1)
        t.tokens = t.tokens - 1
        self:_SendAddonWhisperNow(msg)
    end
end

-- Queue a payload the bucket could not afford right now.
function DC:_ThrottleEnqueue(msg)
    local t = self._throttle

    -- Coalesce byte-identical payloads still waiting: they have NOT been
    -- delivered, so collapsing them changes nothing the server would observe.
    -- Rare in practice (RIDs make most messages unique -- see the _throttle
    -- comment); this only catches true identical re-sends. Never collapses
    -- payloads that differ, so a distinct request is never lost.
    for i = 1, #t.queue do
        if t.queue[i] == msg then
            t.stats.coalesced = t.stats.coalesced + 1
            return true
        end
    end

    if #t.queue >= (t.maxQueue or 64) then
        -- Sustained overproduction: shed the oldest so the freshest state still
        -- gets through, and make the loss loud rather than silent.
        table.remove(t.queue, 1)
        t.stats.dropped = t.stats.dropped + 1
        self:LogNetEvent("warn", "send", "Outbound throttle queue full; dropped oldest message", {
            queued = #t.queue,
            dropped = t.stats.dropped,
            refillPerSec = t.refillPerSec,
        })
    end

    t.queue[#t.queue + 1] = msg
    t.stats.queued = t.stats.queued + 1
    return true
end

-- Public send entry point. `urgent` bypasses the bucket entirely -- reserved for
-- the handshake, which must not sit behind a backlog or the session never
-- establishes in the first place.
function DC:_SendAddonWhisper(msg, urgent)
    if type(msg) ~= "string" or msg == "" then
        self:LogNetEvent("error", "send", "Attempted to send empty addon payload")
        return false
    end

    local t = self._throttle

    if urgent then
        t.stats.urgent = t.stats.urgent + 1
        return self:_SendAddonWhisperNow(msg)
    end

    if not t.enabled then
        return self:_SendAddonWhisperNow(msg)
    end

    self:_ThrottleRefill()

    -- Anything already queued must stay ahead of this message (ordering), so a
    -- non-empty queue means we queue too even if a token happens to be free.
    if #t.queue == 0 and (t.tokens or 0) >= 1 then
        t.tokens = t.tokens - 1
        return self:_SendAddonWhisperNow(msg)
    end

    return self:_ThrottleEnqueue(msg)
end

-- Diagnostics: current bucket/queue state plus lifetime counters.
function DC:GetThrottleStats()
    local t = self._throttle
    return {
        enabled = t.enabled,
        burst = t.burst,
        refillPerSec = t.refillPerSec,
        tokens = math.floor((t.tokens or 0) * 10) / 10,
        queued = #t.queue,
        sent = t.stats.sent,
        deferred = t.stats.queued,
        coalesced = t.stats.coalesced,
        dropped = t.stats.dropped,
        urgent = t.stats.urgent,
    }
end

-- Tuning hook. Keep refillPerSec at or below the `antidos_opcode_policies`
-- MaxAllowedCount for opcode 0x095 if a row is ever added for it.
function DC:ConfigureThrottle(opts)
    if type(opts) ~= "table" then
        return
    end

    local t = self._throttle
    if opts.enabled ~= nil then t.enabled = opts.enabled and true or false end
    if tonumber(opts.burst) then t.burst = math.max(1, tonumber(opts.burst)) end
    if tonumber(opts.refillPerSec) then t.refillPerSec = math.max(0.1, tonumber(opts.refillPerSec)) end
    if tonumber(opts.maxQueue) then t.maxQueue = math.max(1, tonumber(opts.maxQueue)) end
    t.tokens = math.min(t.tokens or 0, t.burst)
end

function DC:RegisterHandler(module, opcode, handler)
    local key = module .. "_" .. tostring(opcode)
    if not self._handlers[key] then self._handlers[key] = {} end
    table.insert(self._handlers[key], handler)
end

function DC:UnregisterHandler(module, opcode, handler)
    local key = module .. "_" .. tostring(opcode)
    local h = self._handlers[key]
    if not h then return false end
    -- If specific handler is provided, try to remove it
    if handler then
        if type(h) == 'table' then
            for i = #h, 1, -1 do
                if h[i] == handler then
                    table.remove(h, i)
                end
            end
            if #h == 0 then self._handlers[key] = nil end
            return true
        elseif h == handler then
            self._handlers[key] = nil
            return true
        else
            return false
        end
    end
    -- If no specific handler, remove all handlers for this key
    self._handlers[key] = nil
    return true
end

function DC:RegisterErrorHandler(module, handler)
    if not DC._errorHandlers[module] then DC._errorHandlers[module] = {} end
    table.insert(DC._errorHandlers[module], handler)
end

function DC:RegisterGlobalErrorHandler(handler)
    table.insert(DC._globalErrorHandlers, handler)
end

function DC:RegisterJSONHandler(module, opcode, handler)
    local key = module .. "_" .. tostring(opcode) .. "_json"
    if not self._handlers[key] then self._handlers[key] = {} end
    table.insert(self._handlers[key], handler)
end

function DC:UnregisterJSONHandler(module, opcode, handler)
    local key = module .. "_" .. tostring(opcode) .. "_json"
    local h = self._handlers[key]
    if not h then return false end
    if handler then
        if type(h) == 'table' then
            for i = #h, 1, -1 do
                if h[i] == handler then
                    table.remove(h, i)
                end
            end
            if #h == 0 then self._handlers[key] = nil end
            return true
        elseif h == handler then
            self._handlers[key] = nil
            return true
        else
            return false
        end
    end
    self._handlers[key] = nil
    return true
end

-- =========================================================================
-- Native transport routing (dedicated WotLK-Extensions custom opcodes)
-- -------------------------------------------------------------------------
-- Modules that have a native bridge can transparently send requests over the
-- custom opcode and receive responses by polling, instead of the addon (chat)
-- protocol. Responses are funneled back through the same handler dispatch the
-- addon path uses, so module consumers (handlers registered via
-- RegisterHandler / RegisterJSONHandler) need no changes.
-- =========================================================================

-- Registry of modules with a native dedicated-opcode bridge. Each row maps a DC
-- module code to its capability bit and the global native request/poll function
-- names exposed by WotLK-Extensions. To migrate another module, add a row here
-- (and the matching server/client opcode + capability).
DC._nativeBridges = {
    { module = "SEAS", capability = DC.Capability.SEASONAL_NATIVE,
      requestFn = "RequestNativeSeasonal", pollFn = "GetNativeSeasonalSnapshot" },
    { module = "SPOT", capability = DC.Capability.HOTSPOT_NATIVE,
      requestFn = "RequestNativeHotspot", pollFn = "GetNativeHotspotSnapshot" },
    { module = "PRES", capability = DC.Capability.PRESTIGE_NATIVE,
      requestFn = "RequestNativePrestige", pollFn = "GetNativePrestigeSnapshot" },
    { module = "WRLD", capability = DC.Capability.WORLD_NATIVE,
      requestFn = "RequestNativeWorldContent",
      pollFn = "GetNativeWorldContentSnapshot" },
    -- Generic-bridge modules share the single RequestNativeDcMessage /
    -- GetNativeDcMessage pair (the module code travels in the payload), the
    -- single GENERIC_MESSAGE_NATIVE capability, and carry the canonical addon
    -- body ("J|<json>" or plain "<f1>|<f2>..."). Modules with their own
    -- dedicated bridge (MPLUS HUD, SPEC live) keep that bridge; only their
    -- request/response JsonMessage/Message sends route here.
    { module = "GRPF", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "UPG", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "AOE", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "MPLUS", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "TELE", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "EVNT", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "DUEL", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "LBRD", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "WELC", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "SPEC", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "GOMV", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "NPCM", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    -- These keep their dedicated bridge for hot flows (QOS ping, COLL wave1,
    -- HLBG live); only their request/response remainder routes generic.
    { module = "QOS", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "COLL", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "HLBG", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
    { module = "QPOP", capability = DC.Capability.GENERIC_MESSAGE_NATIVE,
      kind = "generic" },
}

-- Precomputed subset of _nativeBridges that own a dedicated poller (kind ~=
-- "generic"). _PollNativeResponses runs every frame, and only these few rows
-- matter to it -- walking all ~22 bridges per frame was wasted work.
DC._nativePollBridges = {}
for _, bridge in ipairs(DC._nativeBridges) do
    if bridge.kind ~= "generic" then
        DC._nativePollBridges[#DC._nativePollBridges + 1] = bridge
    end
end

local function ResolveGlobalFunction(name)
    local fn = rawget(_G, name)
    if type(fn) == "function" then
        return fn
    end
    return nil
end

function DC:_FindNativeBridge(module)
    for _, bridge in ipairs(self._nativeBridges or {}) do
        if bridge.module == module then
            return bridge
        end
    end
    return nil
end

-- True when the client exposes the bridge's native request+poll functions.
function DC:_NativeBridgeHasFns(bridge)
    if not bridge then
        return false
    end
    if bridge.kind == "generic" then
        return ResolveGlobalFunction("RequestNativeDcMessage") ~= nil
            and ResolveGlobalFunction("GetNativeDcMessage") ~= nil
    end
    return ResolveGlobalFunction(bridge.requestFn) ~= nil
        and ResolveGlobalFunction(bridge.pollFn) ~= nil
end

-- True when a module should use its native dedicated opcode: the client exposes
-- the native functions AND the server negotiated the matching capability.
function DC:_ShouldUseNativeBridge(bridge)
    if not self:_NativeBridgeHasFns(bridge) then
        return false
    end
    return HasCapabilityBit(tonumber(self._serverCaps) or 0, bridge.capability)
end

-- Try to send a JSON request over a native bridge. Returns true if it was sent
-- natively (caller must not also send it over the addon protocol).
function DC:_TryNativeSendJSON(module, opcode, json)
    local bridge = self:_FindNativeBridge(module)
    if not bridge or not self:_ShouldUseNativeBridge(bridge) then
        return false
    end
    local payload = (type(json) == "string" and json ~= "") and json or "{}"

    if bridge.kind == "generic" then
        local requestFn = ResolveGlobalFunction("RequestNativeDcMessage")
        if not requestFn then
            return false
        end
        -- Canonical addon body carries the JSON marker.
        requestFn(module, tonumber(opcode) or 0, "J|" .. payload)
        return true
    end

    local requestFn = ResolveGlobalFunction(bridge.requestFn)
    if not requestFn then
        return false
    end
    requestFn(tonumber(opcode) or 0, payload)
    return true
end

-- Dispatch a native JSON response through the same handler chain the addon
-- (CHAT_MSG_ADDON) path uses: JSON handler -> decoded handler.
function DC:_DispatchNativeJSON(module, opcode, jsonStr)
    jsonStr = (type(jsonStr) == "string" and jsonStr ~= "") and jsonStr or "{}"
    local data = self:DecodeJSON(jsonStr)
    if data == nil then
        local trimmed = string.gsub(jsonStr, "^%s*(.-)%s*$", "%1")
        if trimmed ~= "null" then
            self:LogNetEvent("error", "json",
                "Failed to decode native JSON payload",
                { module = module, opcode = opcode })
            return
        end
    end

    self:LogResponse(module, opcode, data, jsonStr, nil)

    local jsonKey = module .. "_" .. tostring(opcode) .. "_json"
    local jsonHandler = self._handlers[jsonKey]
    if jsonHandler then
        if type(jsonHandler) == "table" then
            for _, h in ipairs(jsonHandler) do
                self:_InvokeHandlerSafe("native-json", module, opcode, h, data, jsonStr)
            end
        else
            self:_InvokeHandlerSafe("native-json", module, opcode, jsonHandler, data, jsonStr)
        end
    else
        local key = module .. "_" .. tostring(opcode)
        local h = self._handlers[key]
        if h then
            if type(h) == "table" then
                for _, handler in ipairs(h) do
                    self:_InvokeHandlerSafe("native-decoded", module, opcode, handler, data)
                end
            else
                self:_InvokeHandlerSafe("native-decoded", module, opcode, h, data)
            end
        end
    end

end

-- Dispatch a generic-bridge native response. The body is the canonical addon
-- body: "J|<json>" (dispatched as JSON) or pipe-delimited positional fields
-- (dispatched as a plain message, mirroring the CHAT_MSG_ADDON path).
function DC:_DispatchNativeMessage(module, opcode, body)
    body = body or ""

    if string.sub(body, 1, 2) == "J|" then
        self:_DispatchNativeJSON(module, opcode, string.sub(body, 3))
        return
    end

    local fields = {}
    if body ~= "" then
        for field in string.gmatch(body .. "|", "([^|]*)|") do
            table.insert(fields, field)
        end
    end

    -- Core error / permission-denied: route to error handlers like the addon
    -- path, since these never reach a per-opcode handler.
    if opcode == self.Opcode.Core.SMSG_ERROR
        or opcode == self.Opcode.Core.SMSG_PERMISSION_DENIED then
        local errCode = tonumber(fields[1]) or 0
        local errMsg = fields[2] or ""
        local errHandlers = self._errorHandlers[module]
        if errHandlers then
            for _, h in ipairs(errHandlers) do
                self:_InvokeHandlerSafe("native-module-error", module, opcode,
                    h, errCode, errMsg, opcode)
            end
        end
        for _, h in ipairs(self._globalErrorHandlers) do
            self:_InvokeHandlerSafe("native-global-error", module, opcode, h,
                module, errCode, errMsg, opcode)
        end
        if self:GetSetting("chatOnError") then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[DC] Error:|r " .. module
                .. ": " .. (errMsg or "Unknown error"))
        end
        self:LogResponse(module, opcode, { errCode, errMsg }, nil, nil)
        return
    end

    self:LogResponse(module, opcode, fields, nil, nil)

    local key = module .. "_" .. tostring(opcode)
    local h = self._handlers[key]
    if type(h) == "table" then
        for _, handler in ipairs(h) do
            if type(handler) == "function" then
                self:_InvokeHandlerSafe("native-plain", module, opcode,
                    handler, unpack(fields))
            end
        end
    elseif type(h) == "function" then
        self:_InvokeHandlerSafe("native-plain", module, opcode, h,
            unpack(fields))
    end
end

-- Drain queued native responses for every registered bridge and dispatch them.
-- Called every frame from the OnUpdate loop; a cheap no-op when idle.
function DC:_PollNativeResponses()
    -- Dedicated per-module bridges (own request/poll fns, JSON payload).
    -- _nativePollBridges holds only the rows with dedicated pollers.
    for _, bridge in ipairs(self._nativePollBridges) do
        -- Cache the resolved DLL function (this runs every frame). Only cache
        -- once non-nil so we keep retrying until the DLL registers it.
        local pollFn = bridge._pollFnCached
        if not pollFn then
            pollFn = ResolveGlobalFunction(bridge.pollFn)
            if pollFn then bridge._pollFnCached = pollFn end
        end
        if pollFn then
            local guard = 0
            while guard < 16 do
                guard = guard + 1
                local revision, logicalOpcode, payload = pollFn()
                if not revision or not logicalOpcode then
                    break
                end
                self:_DispatchNativeJSON(bridge.module,
                    tonumber(logicalOpcode) or 0, payload or "{}")
            end
        end
    end

    -- Generic shared bridge: one queue, the module code travels in the payload.
    local genericPoll = self._genericPollFnCached
    if not genericPoll then
        genericPoll = ResolveGlobalFunction("GetNativeDcMessage")
        if genericPoll then self._genericPollFnCached = genericPoll end
    end
    if genericPoll then
        local guard = 0
        while guard < 32 do
            guard = guard + 1
            local revision, module, logicalOpcode, body = genericPoll()
            if not revision or not module or not logicalOpcode then
                break
            end
            self:_DispatchNativeMessage(module, tonumber(logicalOpcode) or 0,
                body or "")
        end
    end
end

-- Session-critical traffic that must never sit behind a throttle backlog:
-- the handshake and version check establish the connection in the first place,
-- and both are once-per-session, so bypassing the bucket costs nothing.
function DC:_IsUrgentMessage(module, opcode)
    if module ~= "CORE" then
        return false
    end
    local op = tonumber(opcode)
    return op == 0x01 or op == 0x02
end

function DC:Send(module, opcode, a1, a2, a3, a4, a5)
    local requestId = self:NextRequestId()
    local parts = {module, tostring(opcode), "RID:" .. tostring(requestId)}
    local args = {a1, a2, a3, a4, a5, nil}
    for i = 1, 5 do
        local v = args[i]
        if v ~= nil then
            if type(v) == "boolean" then
                table.insert(parts, v and "1" or "0")
            else
                table.insert(parts, tostring(v))
            end
        end
    end
    local msg = table.concat(parts, "|")
    
    -- Log request
    self:LogRequest(module, opcode, {a1, a2, a3, a4, a5}, requestId)
    
    if self._debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Sending: " .. msg)
    end
    return self:_SendAddonWhisper(msg, self:_IsUrgentMessage(module, opcode))
end

-- WoW 3.3.5a addon message size limit is 255 bytes
-- We use smaller chunks to leave room for chunk headers (INDEX|TOTAL|)
local MAX_ADDON_MSG_SIZE = 255
local CHUNK_HEADER_SIZE = 10  -- Reserve space for "99|99|" worst case

-- Send a raw message with chunking support for messages > 255 bytes
function DC:SendChunked(msg)
    if type(msg) ~= "string" then
        self:LogNetEvent("error", "send", "SendChunked received non-string payload")
        return false
    end

    local maxChunkDataSize = MAX_ADDON_MSG_SIZE - CHUNK_HEADER_SIZE
    
    if string.len(msg) <= MAX_ADDON_MSG_SIZE then
        -- No chunking needed for small messages
        if self._debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Sending (no chunk): " .. string.sub(msg, 1, 80))
        end
        return self:_SendAddonWhisper(msg)
    end
    
    -- Split into chunks
    local totalChunks = math.ceil(string.len(msg) / maxChunkDataSize)
    
    if self._debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Chunking message: " .. string.len(msg) .. " bytes -> " .. totalChunks .. " chunks")
    end
    
    for i = 0, totalChunks - 1 do
        local startPos = i * maxChunkDataSize + 1
        local endPos = math.min((i + 1) * maxChunkDataSize, string.len(msg))
        local chunkData = string.sub(msg, startPos, endPos)
        local chunk = tostring(i) .. "|" .. tostring(totalChunks) .. "|" .. chunkData
        
        if self._debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r   Chunk " .. i .. "/" .. totalChunks .. ": " .. string.len(chunk) .. " bytes")
        end
        
        if not self:_SendAddonWhisper(chunk) then
            return false
        end
    end

    return true
end

function DC:SendJSON(module, opcode, data)
    local json = self:EncodeJSON(data)
    if type(json) ~= "string" then
        self:LogNetEvent("error", "json", "Failed to encode JSON payload", {
            module = module,
            opcode = opcode,
        })
        return false
    end

    local requestId = self:NextRequestId()
    local msg = module .. "|" .. tostring(opcode) .. "|RID:" .. tostring(requestId) .. "|J|" .. json
    
    -- Log request
    self:LogRequest(module, opcode, data, requestId)

    if self._debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Sending JSON: " .. module .. " opcode=" .. tostring(opcode) .. " size=" .. string.len(msg))
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Data: " .. string.sub(json, 1, 200) .. (string.len(json) > 200 and "..." or ""))
    end

    -- Prefer the native dedicated opcode when the module/server support it.
    -- Responses arrive via DC:_PollNativeResponses and dispatch identically.
    if self:_TryNativeSendJSON(module, opcode, json) then
        if self._debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Routed " .. module .. " opcode=" .. tostring(opcode) .. " over native bridge")
        end
        return true
    end

    -- Use chunked sending for large messages
    return self:SendChunked(msg)
end

-- Standard request method - uses JSON format by default
-- data can be nil (empty request), a table (JSON object), or simple values
function DC:Request(module, opcode, data)
    if data == nil then
        -- Empty request - send minimal JSON object
        return self:SendJSON(module, opcode, {})
    elseif type(data) == "table" then
        -- Table data - send as JSON
        return self:SendJSON(module, opcode, data)
    else
        -- Simple value - wrap in object
        return self:SendJSON(module, opcode, { value = data })
    end
end

-- Alias for Request
DC.RequestJSON = DC.Request

-- JSON string escaping helper (security: proper escape sequences)
local function EscapeJSONString(s)
    -- Fast path: most strings (including every object key) need no escaping.
    -- The class covers everything the gsubs below touch: backslash, double
    -- quote, and %c (all control bytes, which includes \n, \r and \t).
    if not string.find(s, "[%c\\\"]") then
        return s
    end
    -- Order matters: escape backslash first to avoid double-escaping
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\"", "\\\"")
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    -- Control characters (0x00-0x1F) - escape as \uXXXX
    s = string.gsub(s, "%c", function(c)
        return string.format("\\u%04x", string.byte(c))
    end)
    return s
end

local JSON_MAX_ENCODE_DEPTH = 48

function DC:_EncodeJSONValue(val, seen, depth)
    if depth > JSON_MAX_ENCODE_DEPTH then
        self:LogNetEvent("error", "json", "JSON encode exceeded max nesting depth", {
            depth = depth,
        })
        return "null"
    end

    local t = type(val)
    if val == nil then return "null"
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "number" then return tostring(val)
    elseif t == "string" then return "\"" .. EscapeJSONString(val) .. "\""
    elseif t == "table" then
        if seen[val] then
            self:LogNetEvent("error", "json", "JSON encode cycle detected")
            return "null"
        end

        seen[val] = true
        local parts = {}
        local isArr = (val[1] ~= nil)
        if isArr then
            for i = 1, #val do
                parts[#parts + 1] = self:_EncodeJSONValue(val[i], seen, depth + 1)
            end
            seen[val] = nil
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                parts[#parts + 1] =
                    "\"" .. EscapeJSONString(tostring(k)) .. "\":"
                    .. self:_EncodeJSONValue(v, seen, depth + 1)
            end
            seen[val] = nil
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

function DC:EncodeJSON(val)
    return self:_EncodeJSONValue(val, {}, 0)
end

-- ============================================================
-- JSON decode. The parser is hoisted to file scope so the skipWhitespace /
-- parseValue closures and the ~20 byte constants are created ONCE at load,
-- not on every DecodeJSON call -- this removes per-sync GC churn. It is not
-- re-entrant (a decode fully completes before returning, which is how it is
-- used). Verified byte-for-byte identical to the previous per-call version.
-- ============================================================
local _jstr, _jpos, _jlen
local _jbyte, _jsub, _jfind = string.byte, string.sub, string.find
local J_SPACE, J_TAB, J_NL, J_CR = 32, 9, 10, 13
local J_QUOTE, J_COMMA, J_MINUS, J_COLON = 34, 44, 45, 58
local J_LB, J_BS, J_RB, J_LBR, J_RBR = 91, 92, 93, 123, 125
local J_0, J_9, J_t, J_f, J_n = 48, 57, 116, 102, 110

local function JsonSkipWS()
    local b = _jbyte(_jstr, _jpos)
    while b and (b == J_SPACE or b == J_TAB or b == J_NL or b == J_CR) do
        _jpos = _jpos + 1
        b = _jbyte(_jstr, _jpos)
    end
end

local function JsonParseValue()
    JsonSkipWS()
    if _jpos > _jlen then return nil end
    local b = _jbyte(_jstr, _jpos)
    if not b then return nil end

    -- String
    if b == J_QUOTE then
        _jpos = _jpos + 1
        local startPos = _jpos
        local endPos = _jfind(_jstr, '"', _jpos, true)
        local hasEscape = _jfind(_jstr, '\\', startPos, true)
        if not hasEscape or (endPos and hasEscape > endPos) then
            if endPos then
                local result = _jsub(_jstr, startPos, endPos - 1)
                _jpos = endPos + 1
                return result
            end
        end
        local parts = {}
        local partStart = _jpos
        while _jpos <= _jlen do
            local c = _jbyte(_jstr, _jpos)
            if c == J_BS and _jpos + 1 <= _jlen then
                if _jpos > partStart then parts[#parts + 1] = _jsub(_jstr, partStart, _jpos - 1) end
                local nextC = _jbyte(_jstr, _jpos + 1)
                if nextC == J_QUOTE then parts[#parts + 1] = '"'
                elseif nextC == J_BS then parts[#parts + 1] = '\\'
                elseif nextC == J_n then parts[#parts + 1] = '\n'
                elseif nextC == J_t then parts[#parts + 1] = '\t'
                elseif nextC == 114 then parts[#parts + 1] = '\r'
                else parts[#parts + 1] = _jsub(_jstr, _jpos + 1, _jpos + 1) end
                _jpos = _jpos + 2
                partStart = _jpos
            elseif c == J_QUOTE then
                if _jpos > partStart then parts[#parts + 1] = _jsub(_jstr, partStart, _jpos - 1) end
                _jpos = _jpos + 1
                return table.concat(parts)
            else
                _jpos = _jpos + 1
            end
        end
        return table.concat(parts)
    end

    -- Number
    if b == J_MINUS or (b >= J_0 and b <= J_9) then
        local startPos = _jpos
        local _, endPos = _jfind(_jstr, "^%-?%d+%.?%d*[eE]?[%+%-]?%d*", _jpos)
        if endPos then
            _jpos = endPos + 1
            return tonumber(_jsub(_jstr, startPos, endPos))
        end
        return nil
    end

    -- Object
    if b == J_LBR then
        _jpos = _jpos + 1
        local obj = {}
        JsonSkipWS()
        if _jbyte(_jstr, _jpos) == J_RBR then
            _jpos = _jpos + 1
            return obj
        end
        while _jpos <= _jlen do
            JsonSkipWS()
            local key = JsonParseValue()
            if type(key) ~= "string" then break end
            JsonSkipWS()
            if _jbyte(_jstr, _jpos) ~= J_COLON then break end
            _jpos = _jpos + 1
            local value = JsonParseValue()
            obj[key] = value
            JsonSkipWS()
            local sep = _jbyte(_jstr, _jpos)
            if sep == J_RBR then _jpos = _jpos + 1; break end
            if sep == J_COMMA then _jpos = _jpos + 1 end
        end
        return obj
    end

    -- Array
    if b == J_LB then
        _jpos = _jpos + 1
        local arr = {}
        local arrLen = 0
        JsonSkipWS()
        if _jbyte(_jstr, _jpos) == J_RB then
            _jpos = _jpos + 1
            return arr
        end
        while _jpos <= _jlen do
            local value = JsonParseValue()
            arrLen = arrLen + 1
            arr[arrLen] = value
            JsonSkipWS()
            local sep = _jbyte(_jstr, _jpos)
            if sep == J_RB then _jpos = _jpos + 1; break end
            if sep == J_COMMA then
                _jpos = _jpos + 1
            else
                -- Malformed/unexpected token (e.g. "[x]"). JsonParseValue()
                -- returned without advancing _jpos, so bail out instead of
                -- spinning forever (mirrors the object loop's break above).
                break
            end
        end
        return arr
    end

    -- true / false / null
    if b == J_t then
        if _jsub(_jstr, _jpos, _jpos + 3) == "true" then _jpos = _jpos + 4; return true end
    elseif b == J_f then
        if _jsub(_jstr, _jpos, _jpos + 4) == "false" then _jpos = _jpos + 5; return false end
    elseif b == J_n then
        if _jsub(_jstr, _jpos, _jpos + 3) == "null" then _jpos = _jpos + 4; return nil end
    end

    return nil
end

-- Pure-Lua JSON decode (the reference parser). Used directly when the native
-- parser is off, as the fallback when native declines, and as the source of
-- truth in verify mode.
function DC:_DecodeJSONLua(str)
    _jstr = str
    _jpos = 1
    _jlen = #str

    local result = JsonParseValue()
    JsonSkipWS()
    if _jpos <= _jlen then
        return nil
    end

    return result
end

local function JsonDeepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not JsonDeepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

function DC:_JsonVerifyMismatch(str, reason)
    self._jsonVerifyMismatches = (self._jsonVerifyMismatches or 0) + 1
    if self._jsonVerifyMismatches <= 25 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[DC json verify]|r " .. tostring(reason)
            .. " | len=" .. #str .. " | " .. string.sub(str, 1, 140))
        self:LogNetEvent("error", "jsonverify", tostring(reason), { len = #str })
    end
end

-- Native (DLL) JSON decode rollout. Mode is one of:
--   "off"    - use the Lua parser only (zero risk)
--   "verify" - parse with BOTH, deep-compare, log mismatches, return the Lua
--              result (safe). Use this on a test account to validate.
--   "on"     - use the native (C++) parser, fall back to Lua if it declines
--              (default: full-collection payloads parse in native code instead
--              of hitching a frame in the interpreted Lua parser at login).
-- Toggle with: /dc jsonnative off|verify|on
function DC:DecodeJSON(str)
    if not str or str == "" then return nil end

    -- Security: Reject oversized payloads
    if #str > (self.MAX_JSON_PAYLOAD_SIZE or 65536) then
        self:LogNetEvent("error", "json", "JSON payload too large: " .. #str .. " bytes (max " .. (self.MAX_JSON_PAYLOAD_SIZE or 65536) .. ")")
        return nil
    end

    local mode = self._jsonNativeMode
    if mode == nil then
        mode = (type(self.GetSetting) == "function" and self:GetSetting("jsonNativeMode")) or "on"
        self._jsonNativeMode = mode
    end

    if mode ~= "off" and type(DecodeJSONNative) == "function" then
        if mode == "verify" then
            local luaResult = self:_DecodeJSONLua(str)
            local pcallOk, nativeResult, nativeOk = pcall(DecodeJSONNative, str)
            if not pcallOk then
                self:_JsonVerifyMismatch(str, "native error: " .. tostring(nativeResult))
            elseif not nativeOk then
                self:_JsonVerifyMismatch(str, "native ok=false (would fall back)")
            elseif not JsonDeepEqual(nativeResult, luaResult) then
                self:_JsonVerifyMismatch(str, "value mismatch")
            end
            return luaResult
        else -- "on"
            local pcallOk, nativeResult, nativeOk = pcall(DecodeJSONNative, str)
            if pcallOk and nativeOk then
                return nativeResult
            end
            -- native declined or errored: fall through to the Lua parser
        end
    end

    return self:_DecodeJSONLua(str)
end

DC.JSON = { encode = function(v) return DC:EncodeJSON(v) end, decode = function(s) return DC:DecodeJSON(s) end }

-- Module identifiers, opcodes and the per-module convenience wrappers live in
-- DCOpcodes.lua, loaded immediately after this file. They are referenced only
-- from inside functions here, so definition order does not matter.

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
-- Track loading screens so we never dispatch native bridge responses while the
-- world/UI is being torn down or rebuilt (e.g. ReloadMap, zone change). Handlers
-- dispatched mid-reload can touch not-yet-valid world objects and hard-crash the
-- client; PLAYER_LEAVING_WORLD..PLAYER_ENTERING_WORLD brackets that window.
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnUpdate", function(self, elapsed)
    -- Drain native bridge responses every frame so the UI stays responsive
    -- (the 1s throttle below only gates the slower bookkeeping tasks). Skip
    -- while a loading screen is active - see PLAYER_LEAVING_WORLD below.
    if not DC._worldLoading and type(DC._PollNativeResponses) == "function" then
        DC:_PollNativeResponses()
    end

    -- Release throttled outbound messages as the token bucket refills. Runs
    -- every frame (not on the 1s bookkeeping tick) so a burst clears promptly;
    -- it is a no-op whenever the queue is empty, which is the normal case.
    if type(DC._ThrottleDrain) == "function" then
        DC:_ThrottleDrain()
    end

    DC._tick = (DC._tick or 0) + (elapsed or 0)
    if DC._tick < 1.0 then
        return
    end
    DC._tick = 0
    if type(DC._CheckRequestTimeouts) == "function" then
        DC:_CheckRequestTimeouts()
    end
    if type(DC._CleanupChunkBuffers) == "function" then
        DC:_CleanupChunkBuffers()
    end
    -- Auto-reconnect logic: if disconnected and haven't exceeded max attempts
    if not DC._connected and not DC._handshakePending then
        local now = time()
        local lastAttempt = DC._lastHandshakeTime or 0
        local attempts = DC._reconnectAttempts or 0
        local maxAttempts = DC._maxReconnectAttempts or 5
        -- Exponential backoff: 5s, 10s, 20s, 40s, 60s (capped)
        local delay = math.min(60, 5 * math.pow(2, attempts))
        if attempts < maxAttempts and (now - lastAttempt) >= delay then
            DC:_AttemptReconnect()
        end
    end
end)
frame:SetScript("OnEvent", function()
    if event == "PLAYER_LEAVING_WORLD" then
        -- Loading screen / map teardown begins: pause native response dispatch.
        DC._worldLoading = true
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- World is valid again: resume native response dispatch.
        DC._worldLoading = nil
        return
    end
    if event == "CHAT_MSG_ADDON" then
        -- Accept DC protocol whispers regardless of sender name.
        -- Some server packets can arrive with sender != UnitName("player"),
        -- and filtering on sender would drop all server->client messages.
        if arg1 == DC.PREFIX and (arg3 == "WHISPER" or arg3 == "WHISPER_INFORM" or not arg3) then
            -- Chunked payload support (server may split large messages into INDEX|TOTAL|DATA chunks)
            -- Reassemble before normal parsing.
            local payload = arg2 or ""
            do
                local idxStr, totalStr, dataPart = string.match(payload, "^(%d+)|(%d+)|(.*)$")
                if idxStr and totalStr then
                    local idx = tonumber(idxStr) or 0
                    local total = tonumber(totalStr) or 0
                    
                    -- Security: Reject messages with too many chunks (memory protection)
                    local maxChunks = DC.MAX_CHUNKS_PER_MESSAGE or 100
                    if total > maxChunks then
                        DC:LogNetEvent("error", "chunk", "Rejected chunked message: too many chunks (" .. total .. " > " .. maxChunks .. ")")
                        return
                    end
                    
                    if total > 0 and idx >= 0 and idx < total then
                        DC._chunkBuffers = DC._chunkBuffers or {}
                        DC._chunkMsgIds = DC._chunkMsgIds or {}  -- Lookup: sender_total -> msgId
                        local sender = arg4 or "_"
                        local now = time()
                        local baseKey = sender .. "_" .. total
                        
                        -- For chunk 0, extract MODULE|OPCODE to create unique key
                        -- Chunk 0 format: MODULE|OPCODE|J|data... or MODULE|OPCODE|data...
                        local msgId = nil
                        if idx == 0 then
                            local m, o = string.match(dataPart or "", "^([^|]+)|(%d+)")
                            if m and o then
                                msgId = m .. "_" .. o
                                -- Store msgId lookup for subsequent chunks
                                DC._chunkMsgIds[baseKey] = msgId
                            end
                        else
                            -- For non-chunk-0, look up the msgId from chunk 0
                            msgId = DC._chunkMsgIds[baseKey]
                        end
                        
                        -- Build full key (with msgId if available)
                        local bufKey = msgId and (baseKey .. "_" .. msgId) or baseKey

                        local buf = DC._chunkBuffers[bufKey]

                        -- Chunks can occasionally arrive before chunk 0; if that happened,
                        -- we buffered them under baseKey without a msgId. Migrate/merge them
                        -- once chunk 0 reveals the msgId to avoid splitting one message into
                        -- multiple buffers.
                        if msgId and bufKey ~= baseKey then
                            local fallbackBuf = DC._chunkBuffers[baseKey]
                            if fallbackBuf and fallbackBuf ~= buf then
                                if not buf then
                                    buf = fallbackBuf
                                    buf.msgId = msgId
                                    DC._chunkBuffers[bufKey] = buf
                                else
                                    buf.parts = buf.parts or {}
                                    buf.seen = buf.seen or {}
                                    for partIdx, partVal in pairs(fallbackBuf.parts or {}) do
                                        if buf.parts[partIdx] == nil then
                                            buf.parts[partIdx] = partVal
                                        end
                                    end
                                    for seenKey, seenVal in pairs(fallbackBuf.seen or {}) do
                                        if seenVal and not buf.seen[seenKey] then
                                            buf.seen[seenKey] = true
                                            buf.received = (buf.received or 0) + 1
                                        end
                                    end
                                    if fallbackBuf.ts and (not buf.ts or fallbackBuf.ts > buf.ts) then
                                        buf.ts = fallbackBuf.ts
                                    end
                                end

                                DC._chunkBuffers[baseKey] = nil
                            end
                        end

                        -- Reset buffer if stale
                        local staleSec = tonumber(DC:GetSetting("chunkTimeoutSec")) or 10
                        if staleSec < 2 then staleSec = 2 end
                        
                        if not buf or (buf.ts and now - buf.ts > staleSec) then
                            buf = { total = total, parts = {}, received = 0, seen = {}, ts = now, msgId = msgId }
                            DC._chunkBuffers[bufKey] = buf
                        else
                            buf.ts = now
                        end

                        local key = tostring(idx)
                        if not buf.seen[key] then
                            buf.seen[key] = true
                            buf.received = (buf.received or 0) + 1
                        end
                        buf.parts[idx + 1] = dataPart or ""

                        if buf.received >= total then
                            -- Use table.concat to avoid O(n^2) string growth and extra allocations.
                            payload = table.concat(buf.parts, "", 1, total)
                            DC._chunkBuffers[bufKey] = nil
                            if bufKey ~= baseKey then
                                DC._chunkBuffers[baseKey] = nil
                            end
                            DC._chunkMsgIds[baseKey] = nil  -- Cleanup msgId lookup
                        else
                            -- Wait for more chunks
                            return
                        end
                    end
                end
            end

            local parts = {}
            for p in string.gmatch(payload, "([^|]+)") do table.insert(parts, p) end
            
            if #parts >= 2 then
                local module = parts[1]
                local opcode = tonumber(parts[2]) or 0
                local dataStart = 3
                local requestId = nil
                if parts[3] and (string.sub(parts[3], 1, 4) == "RID:" or string.sub(parts[3], 1, 4) == "RID=") then
                    requestId = string.sub(parts[3], 5)
                    dataStart = 4
                end
                
                -- Debug output
                if DC._debug then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Received: " .. module .. " opcode=" .. opcode .. " parts=" .. #parts)
                end
                
                -- Early: detect core error codes (SMSG_ERROR / SMSG_PERMISSION_DENIED)
                if opcode == DC.Opcode.Core.SMSG_ERROR or opcode == DC.Opcode.Core.SMSG_PERMISSION_DENIED then
                    -- Parse error payload
                    local errCode = tonumber(parts[dataStart]) or 0
                    local errMsg = parts[dataStart + 1] or ""
                    -- Call module-specific error handlers
                    local errHandlers = DC._errorHandlers[module]
                    if errHandlers then
                        for _, h in ipairs(errHandlers) do
                            DC:_InvokeHandlerSafe("module-error", module, opcode, h, errCode, errMsg, opcode)
                        end
                    end
                    -- Call global error handlers
                    for _, h in ipairs(DC._globalErrorHandlers) do
                        DC:_InvokeHandlerSafe("global-error", module, opcode, h, module, errCode, errMsg, opcode)
                    end
                    -- Default behavior: display error in chat (configurable)
                    DC:LogNetEvent("error", "server", module .. ": " .. tostring(errMsg or "Unknown error"), {
                        module = module,
                        opcode = opcode,
                        code = errCode,
                    })
                    if DC:GetSetting("chatOnError") then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[DC] Error:|r " .. module .. ": " .. (errMsg or "Unknown error"))
                    end
                    -- Log response
                    DC:LogResponse(module, opcode, {errCode, errMsg}, nil, requestId)
                    return
                end

                -- Check if this is a JSON message (format: MODULE|OPCODE|J|{json}
                -- or MODULE|OPCODE|1|{json}). Guard against plain numeric payloads
                -- where the first data field can also be "1".
                local marker = parts[dataStart]
                local nextToken = parts[dataStart + 1]
                local isNumericJsonMarker = marker == "1"
                    and type(nextToken) == "string"
                    and (string.sub(nextToken, 1, 1) == "{" or string.sub(nextToken, 1, 1) == "[")
                local isJson = #parts >= (dataStart + 1) and (marker == "J" or isNumericJsonMarker)
                if isJson then
                    -- JSON message - reconstruct JSON (in case it had | in it)
                    local jsonParts = {}
                    for i = dataStart + 1, #parts do
                        table.insert(jsonParts, parts[i])
                    end
                    local jsonStr = table.concat(jsonParts, "|")
                    local data = DC:DecodeJSON(jsonStr)

                    if data == nil then
                        local trimmed = string.gsub(jsonStr, "^%s+", "")
                        trimmed = string.gsub(trimmed, "%s+$", "")
                        if trimmed ~= "null" then
                            DC:LogNetEvent("error", "json", "Failed to decode JSON payload", {
                                module = module,
                                opcode = opcode,
                                size = string.len(jsonStr or ""),
                            })
                            if DC._debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[DC]|r JSON decode failed for " .. tostring(module) .. " opcode=" .. tostring(opcode) .. " size=" .. tostring(string.len(jsonStr or "")))
                            end
                            return
                        end
                    end
                    
                    -- Log response
                    DC:LogResponse(module, opcode, data, jsonStr, requestId)
                    
                    if DC._debug then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r JSON: " .. string.sub(jsonStr, 1, 200) .. (string.len(jsonStr) > 200 and "..." or ""))
                    end
                    
                    -- Try JSON-specific handler first
                    local jsonKey = module .. "_" .. opcode .. "_json"
                    local jsonHandler = DC._handlers[jsonKey]
                    if jsonHandler then
                        if type(jsonHandler) == 'table' then
                            if DC._debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handler(s) found: " .. jsonKey .. " (" .. tostring(#jsonHandler) .. ")")
                            end
                            for _, _h in ipairs(jsonHandler) do
                                DC:_InvokeHandlerSafe("json", module, opcode, _h, data, jsonStr)
                            end
                        else
                            if DC._debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handler found: " .. jsonKey)
                            end
                            DC:_InvokeHandlerSafe("json", module, opcode, jsonHandler, data, jsonStr)
                        end
                    else
                        -- Fall back to regular handler with decoded data
                        local key = module .. "_" .. opcode
                        local h = DC._handlers[key]
                        if h then 
                            if type(h) == 'table' then
                                if DC._debug then
                                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handler(s) found: " .. key .. " (" .. tostring(#h) .. ")")
                                end
                                for _, handler in ipairs(h) do
                                    DC:_InvokeHandlerSafe("decoded", module, opcode, handler, data)
                                end
                            else
                                if DC._debug then
                                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handler found: " .. key)
                                end
                                DC:_InvokeHandlerSafe("decoded", module, opcode, h, data)
                            end
                        elseif DC._debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cffff6600[DC]|r No handler for: " .. key)
                        end
                    end
                else
                    -- Regular message - log it too
                    DC:LogResponse(module, opcode, {parts[dataStart], parts[dataStart + 1], parts[dataStart + 2]}, nil, requestId)
                    
                    local key = module .. "_" .. opcode
                    local h = DC._handlers[key]
                    local handlerArgs = {}
                    for i = dataStart, #parts do
                        table.insert(handlerArgs, parts[i])
                    end

                    if type(h) == 'table' then
                        if DC._debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Handler(s) found: " .. key .. " (" .. tostring(#h) .. ")")
                        end
                        for _, handler in ipairs(h) do
                            if type(handler) == 'function' then
                                DC:_InvokeHandlerSafe("plain", module, opcode, handler, unpack(handlerArgs))
                            end
                        end
                    elseif type(h) == 'function' then
                        if DC._debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Handler found: " .. key)
                        end
                        DC:_InvokeHandlerSafe("plain", module, opcode, h, unpack(handlerArgs))
                    elseif DC._debug then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff6600[DC]|r No handler for: " .. key)
                    end
                    -- handlers already dispatched above
                end
            end
        end
    elseif event == "ADDON_LOADED" then
        if arg1 == "DC-AddonProtocol" or arg1 == "DCAddonProtocol" then
            if IsLoggedIn and IsLoggedIn() then
                DC._handshakeSent = false
                DC:SendHandshake("addon-loaded")
            end
        end
    elseif event == "PLAYER_LOGIN" then
        DC:_InitDB()
        DC._stats.sessionStart = time()
        DC:SendHandshake("player-login")
    end
end)

SLASH_DC1 = "/dc"
SlashCmdList["DC"] = function(msg)
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do
        table.insert(args, word)
    end
    local cmd = string.lower(args[1] or "")
    
    if cmd == "json" then
        local t = {name = "Test", level = 80, nested = {a = 1, b = 2}}
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Encode: " .. DC:EncodeJSON(t))
        local decoded = DC:DecodeJSON('{"name":"Player","level":80,"items":[1,2,3]}')
        if decoded then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Decode: name=" .. tostring(decoded.name) .. ", items=" .. tostring(decoded.items and #decoded.items or 0))
        end
    elseif cmd == "jsonnative" then
        local m = string.lower(args[2] or "")
        if m == "on" or m == "off" or m == "verify" then
            DC._jsonNativeMode = m
            DC._jsonVerifyMismatches = 0
            if type(DC.SetSetting) == "function" then DC:SetSetting("jsonNativeMode", m) end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r JSON native parser mode: " .. m
                .. (type(DecodeJSONNative) == "function" and "" or " |cffff4444(DLL function missing!)|r"))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Usage: /dc jsonnative off|verify|on")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r   current=" .. tostring(DC._jsonNativeMode or "off")
                .. ", verify mismatches=" .. tostring(DC._jsonVerifyMismatches or 0)
                .. ", DLL=" .. tostring(type(DecodeJSONNative) == "function"))
        end
    elseif cmd == "sendjson" then
        DC:SendJSON("CORE", 99, {action = "test", timestamp = time()})
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Sent JSON test")
    elseif cmd == "throttle" then
        local sub = string.lower(args[2] or "")
        if sub == "on" or sub == "off" then
            DC:ConfigureThrottle({ enabled = (sub == "on") })
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Outbound throttle: " .. sub)
        elseif sub == "rate" and tonumber(args[3]) then
            DC:ConfigureThrottle({ refillPerSec = tonumber(args[3]) })
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Outbound throttle rate: "
                .. tostring(DC._throttle.refillPerSec) .. "/s")
        else
            local s = DC:GetThrottleStats()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Outbound throttle: "
                .. (s.enabled and "|cff00ff00on|r" or "|cffff4444off|r")
                .. "  ceiling=" .. tostring(s.refillPerSec) .. "/s  burst=" .. tostring(s.burst))
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r   tokens=" .. tostring(s.tokens)
                .. "  queued=" .. tostring(s.queued)
                .. "  sent=" .. tostring(s.sent))
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r   deferred=" .. tostring(s.deferred)
                .. "  coalesced=" .. tostring(s.coalesced)
                .. "  dropped=" .. (s.dropped > 0
                    and ("|cffff4444" .. tostring(s.dropped) .. "|r") or "0")
                .. "  urgent=" .. tostring(s.urgent))
            if s.dropped > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[DC]|r   dropped > 0 means a module is"
                    .. " overproducing - find it before raising the rate.")
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Usage: /dc throttle [on|off|rate <n>]")
        end
    elseif cmd == "native" or cmd == "seas" or cmd == "seasonal" then
        -- Native dedicated-opcode round-trip test for a bridged module. Reports
        -- the transport decision, then fires that module's read requests and
        -- prints the responses (dispatched identically whether native or addon).
        local moduleArg = (cmd == "native") and string.upper(args[2] or "")
            or "SEAS"
        local testSpecs = {
            SEAS = { req = { 0x01, 0x03, 0x02 },
                resp = { [0x10] = "current", [0x12] = "progress",
                    [0x11] = "rewards" } },
            SPOT = { req = { 0x01 },
                resp = { [0x10] = "hotspotList" } },
            PRES = { req = { 0x01, 0x02 },
                resp = { [0x10] = "info", [0x11] = "bonuses" } },
            WRLD = { req = { 0x01 },
                resp = { [0x10] = "content", [0x11] = "update" } },
            GRPF = { req = { 0x22, 0x23, 0x24 },
                resp = { [0x42] = "dungeonList", [0x43] = "raidList",
                    [0x44] = "systemInfo" } },
            UPG = { req = { 0x08, 0x09 },
                resp = { [0x18] = "packageList", [0x19] = "tierConfig" } },
            AOE = { req = { 0x06, 0x03, 0x08 },
                resp = { [0x11] = "settings", [0x10] = "stats",
                    [0x14] = "qualityStats" } },
            MPLUS = { req = { 0x01, 0x02, 0x03 },
                resp = { [0x10] = "keyInfo", [0x11] = "affixes",
                    [0x12] = "bestRuns" } },
            TELE = { req = { 0x01 },
                resp = { [0x10] = "teleList" } },
            DUEL = { req = { 0x01, 0x02 },
                resp = { [0x10] = "stats", [0x11] = "leaderboard" } },
            LBRD = { req = { 0x02 },
                resp = { [0x11] = "categories" } },
            WELC = { req = { 0x01, 0x02 },
                resp = { [0x11] = "serverInfo", [0x12] = "faq" } },
            SPEC = { req = { 0x03 },
                resp = { [0x12] = "runList" } },
        }
        local spec = testSpecs[moduleArg]
        if not spec then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffff4444[DC]|r Usage: /dc native <MODULE> (SEAS SPOT PRES WRLD GRPF UPG AOE MPLUS TELE DUEL LBRD WELC SPEC)")
            return
        end

        local bridge = DC:_FindNativeBridge(moduleArg)
        local hasFns = DC:_NativeBridgeHasFns(bridge)
        local negotiated = bridge ~= nil and HasCapabilityBit(
            tonumber(DC._serverCaps) or 0, bridge.capability) or false
        local willUseNative = bridge ~= nil
            and DC:_ShouldUseNativeBridge(bridge)
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff00ccff[DC %s test]|r nativeFns=%s negotiated=%s -> transport=%s",
            moduleArg, tostring(hasFns), tostring(negotiated),
            willUseNative and "|cff00ff00NATIVE|r" or "|cffffcc00ADDON|r"))

        DC._nativeTestHooked = DC._nativeTestHooked or {}
        if not DC._nativeTestHooked[moduleArg] then
            DC._nativeTestHooked[moduleArg] = true
            for op, label in pairs(spec.resp) do
                local capturedLabel = string.format("%s(0x%X)", label, op)
                -- Handle both JSON (single table) and plain (positional) forms.
                DC:RegisterHandler(moduleArg, op, function(...)
                    local n = select("#", ...)
                    local first = ...
                    local text
                    if n <= 1 and type(first) == "table" then
                        text = DC:EncodeJSON(first or {})
                    else
                        local parts = {}
                        for i = 1, n do
                            parts[i] = tostring(select(i, ...))
                        end
                        text = table.concat(parts, ", ")
                    end
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC " .. moduleArg
                        .. " test]|r " .. capturedLabel .. ": " .. text)
                end)
            end
        end

        for _, op in ipairs(spec.req) do
            DC:Request(moduleArg, op, {})
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff00ccff[DC %s test]|r fired %d request(s); watch for responses above.",
            moduleArg, #spec.req))
    elseif cmd == "debug" then
        DC._debug = not DC._debug
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Debug mode: " .. (DC._debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif cmd == "netlog" then
        local n = tonumber(args[2]) or 20
        DC:DumpNetLog(n)
    elseif cmd == "netlogclear" then
        DC:ClearNetLog()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r NetLog cleared")
    elseif cmd == "timeout" then
        local sec = tonumber(args[2])
        if sec then
            DC:SetSetting("requestTimeoutSec", sec)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Request timeout set to " .. tostring(sec) .. "s")
        else
            DEFAULT_CHAT_FRAME:AddMessage("Usage: /dc timeout <seconds>")
        end
    elseif cmd == "chaterrors" then
        local v = string.lower(args[2] or "")
        if v == "on" or v == "1" or v == "true" then
            DC:SetSetting("chatOnError", true)
        elseif v == "off" or v == "0" or v == "false" then
            DC:SetSetting("chatOnError", false)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Chat on error: " .. (DC:GetSetting("chatOnError") and "ON" or "OFF"))
    elseif cmd == "chattimeouts" then
        local v = string.lower(args[2] or "")
        if v == "on" or v == "1" or v == "true" then
            DC:SetSetting("chatOnRequestTimeout", true)
        elseif v == "off" or v == "0" or v == "false" then
            DC:SetSetting("chatOnRequestTimeout", false)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Chat on request timeout: " .. (DC:GetSetting("chatOnRequestTimeout") and "ON" or "OFF"))
    elseif cmd == "chatchunks" then
        local v = string.lower(args[2] or "")
        if v == "on" or v == "1" or v == "true" then
            DC:SetSetting("chatOnChunkTimeout", true)
        elseif v == "off" or v == "0" or v == "false" then
            DC:SetSetting("chatOnChunkTimeout", false)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Chat on chunk timeout: " .. (DC:GetSetting("chatOnChunkTimeout") and "ON" or "OFF"))
    elseif cmd == "netlogenable" then
        local v = string.lower(args[2] or "")
        if v == "on" or v == "1" or v == "true" then
            DC:SetSetting("netLogEnabled", true)
        elseif v == "off" or v == "0" or v == "false" then
            DC:SetSetting("netLogEnabled", false)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r NetLog: " .. (DC:GetSetting("netLogEnabled") and "ON" or "OFF"))
    elseif cmd == "caps" or cmd == "capabilities" then
        DC:PrintCapabilityStatus()
    elseif cmd == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r v" .. DC.VERSION)
        DEFAULT_CHAT_FRAME:AddMessage("  Connected: " .. (DC._connected and "|cff00ff00Yes|r" or "|cffff0000No|r"))
        if DC._serverVersion then
            DEFAULT_CHAT_FRAME:AddMessage("  Server Version: " .. DC._serverVersion)
        end
        DEFAULT_CHAT_FRAME:AddMessage("  Client Caps: " .. DC:DescribeCapabilities(DC:GetClientCapabilities()))
        DEFAULT_CHAT_FRAME:AddMessage("  Negotiated Caps: " .. DC:DescribeCapabilities(DC._serverCaps or 0))
        DEFAULT_CHAT_FRAME:AddMessage("  Handlers: " .. DC:CountHandlers())
        DEFAULT_CHAT_FRAME:AddMessage("  Debug: " .. (DC._debug and "ON" or "OFF"))
    elseif cmd == "reconnect" then
        DC._connected = false
        DC._handshakeSent = false
        DC:SendHandshake("manual-reconnect")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handshake sent")
    elseif cmd == "handlers" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Registered handlers (key: count):")
        for key, value in pairs(DC._handlers) do
            if type(value) == 'table' then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  - %s: %d", key, #value))
            else
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  - %s: 1", key))
            end
        end
    elseif cmd == "unregister" then
        local m = args[2] or ""
        local oArg = args[3]
        local o = nil
        if oArg then
            o = tonumber(oArg)
            if not o then
                -- Try hex 0xNN format
                local s = string.lower(oArg)
                if s:match("^0x[0-9a-f]+$") then
                    o = tonumber(oArg:sub(3), 16)
                else
                    o = oArg -- fallback: treat as string opcode
                end
            end
        end
        local jsonflag = args[4]
        if m == "" or not o then
            DEFAULT_CHAT_FRAME:AddMessage("Usage: /dc unregister <MODULE> <OPCODE> [json]")
        else
            if jsonflag == "json" then
                if DC:UnregisterJSONHandler(m, o) then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("Unregistered JSON handlers for %s:%s", m, tostring(o)))
                else
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("No JSON handlers found for %s:%s", m, tostring(o)))
                end
            else
                if DC:UnregisterHandler(m, o) then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("Unregistered handlers for %s:%s", m, tostring(o)))
                else
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("No handlers found for %s:%s", m, tostring(o)))
                end
            end
        end
    elseif cmd == "panel" or cmd == "settings" or cmd == "config" then
        DC:OpenOptionsPanel("SettingsPanel")
    elseif cmd == "log" or cmd == "logs" then
        if DC:EnsureUIAddon() then
            DC:ShowLogPanel()
        end
    elseif cmd == "requests" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Recent Requests:")
        local requests = DC:GetRequestLog(10)
        if #requests == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  (no requests logged)")
        else
            for _, req in ipairs(requests) do
                local statusColor = req.status == "completed" and "|cff00ff00" or (req.status == "timeout" and "|cffff0000" or "|cffffff00")
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%s] %s %s op=%d %s%s|r",
                    req.timeStr, req.moduleName, req.module, req.opcode, statusColor, req.status))
            end
        end
    elseif cmd == "responses" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Recent Responses:")
        local responses = DC:GetResponseLog(10)
        if #responses == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  (no responses logged)")
        else
            for _, resp in ipairs(responses) do
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%s] %s %s op=%d len=%d",
                    resp.timeStr, resp.moduleName, resp.module, resp.opcode, resp.jsonLength or 0))
            end
        end
    elseif cmd == "pending" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Pending Requests:")
        local pending = DC:GetPendingRequests()
        if #pending == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  (no pending requests)")
        else
            for _, req in ipairs(pending) do
                local age = time() - req.timestamp
                local ageColor = age > 10 and "|cffff0000" or "|cffffff00"
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s op=%d %s%ds ago|r",
                    req.moduleName, req.opcode, ageColor, age))
            end
        end
    elseif cmd == "clearlog" or cmd == "clearlogs" then
        DC:ClearLogs()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Logs cleared")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc status - Show connection status")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc debug - Toggle debug mode")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc reconnect - Resend handshake")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc handlers - List registered handlers (key: count)")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc unregister <MODULE> <OPCODE> [json] - Unregister handlers (use 'json' for JSON handlers)")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc json - Test JSON encode/decode")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc native <MODULE> - Native bridge round-trip test (SEAS SPOT PRES WRLD GRPF UPG AOE MPLUS TELE DUEL LBRD WELC SPEC; /dc seas = SEAS)")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc panel - Open settings/debug panel")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc log - Open request/response log panel")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc requests - Show recent requests")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc responses - Show recent responses")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc pending - Show pending requests")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc clearlog - Clear all logs")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc caps - Show native/client/negotiated capability masks")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc netlog [n] - Show recent NetLog entries")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc netlogclear - Clear NetLog")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc timeout <sec> - Set request timeout")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc chaterrors on|off - Chat prints for server errors")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc chattimeouts on|off - Chat prints for request timeouts")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc chatchunks on|off - Chat prints for chunk timeouts")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc netlogenable on|off - Enable/disable NetLog")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/dcdiag|r - Open diagnostics panel (run tests)")
    end
end

function DC:CountHandlers()
    local count = 0
    for key, value in pairs(self._handlers) do
        if type(value) == 'table' then
            count = count + #value
        else
            count = count + 1
        end
    end
    return count
end

-- The settings, testing and diagnostics panels live in the LoadOnDemand
-- companion addon DC-AddonProtocolUI (Panels.lua). See DC:EnsureUIAddon below.
-- ============================================================
-- On-demand UI
-- ============================================================
-- The settings, testing, diagnostics and log panels live in the LoadOnDemand
-- companion addon DC-AddonProtocolUI. Every DC addon depends on this file, so
-- keeping ~1,500 lines of options UI here meant every player loaded four
-- panels in order to open none of them.
--
-- The slash commands stay here so they always exist; they pull the UI in on
-- first use.

function DC:EnsureUIAddon()
    if type(IsAddOnLoaded) == "function" and IsAddOnLoaded("DC-AddonProtocolUI") then
        return true
    end
    if type(LoadAddOn) ~= "function" then
        return false
    end

    local loaded, reason = LoadAddOn("DC-AddonProtocolUI")
    if not loaded then
        local reasons = {
            [0] = "unknown error",
            [1] = "addon disabled",
            [2] = "addon missing",
            [3] = "addon too old or too new",
            [4] = "dependency missing",
            [5] = "addon insecure",
        }
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffff4444[DC]|r Could not load DC-AddonProtocolUI - "
                .. (reasons[reason] or "unknown")
                .. ". It must be installed as a top-level addon folder, "
                .. "beside DC-AddonProtocol.")
        end
        return false
    end
    return true
end

-- Opens one of the interface-options panels by field name, loading the UI
-- addon first. The double call works around a 3.3.5 bug where the first
-- OpenToCategory only scrolls the category list.
function DC:OpenOptionsPanel(which)
    if not self:EnsureUIAddon() then
        return
    end
    local panel = self[which]
    if not panel then
        return
    end
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end

-- Slash command to open settings
SLASH_DCPANEL1 = "/dcpanel"
SLASH_DCPANEL2 = "/dcprotocol"
SlashCmdList["DCPANEL"] = function()
    DC:OpenOptionsPanel("SettingsPanel")
end

-- Slash command for diagnostics
SLASH_DCDIAG1 = "/dcdiag"
SLASH_DCDIAG2 = "/dcdiagnostics"
SlashCmdList["DCDIAG"] = function()
    DC:OpenOptionsPanel("DiagnosticsPanel")
end

-- Debug print helper
function DC:DebugPrint(...)
    if not self._debug then return end
    local parts = {}
    for i = 1, select("#", ...) do
        table.insert(parts, tostring(select(i, ...)))
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[DC Debug]|r " .. table.concat(parts, " "))
end

-- Check if connected to server
function DC:IsConnected()
    return self._connected
end

-- Get server feature availability
function DC:HasFeature(feature)
    return self._features[feature] == true
end

-- Register built-in handlers for CORE module
DC:RegisterHandler("CORE", 0x10, function(...)
    local arg1, arg2, arg3, arg4 = ...
    local parserMode = "unknown"
    local serverHandshakeMetadata = nil

    -- Handle both JSON format (arg1 = table) and pipe format (arg1 = version string)
    local version, compatible, negotiatedCaps, features
    if type(arg1) == "table" then
        parserMode = "json"
        local hasCompatibleFlag, parsedCompatible = ParseBooleanLike(arg1.compatible)
        version = arg1.version or arg1.v or "1.0.0"
        features = arg1.features
        compatible = hasCompatibleFlag and parsedCompatible
            or (arg1.compatible ~= false)
        negotiatedCaps = tonumber(arg1.negotiatedCaps
            or arg1.negotiatedCapabilities
            or arg1.caps
            or arg1.capabilities
            or 0) or 0
        serverHandshakeMetadata = ParseServerHandshakeMetadataPayload(
            arg1.handshakeMetadata or arg1.metadata or arg1.m or arg1)
    else
        version = arg1 or "1.0.0"
        local hasArg2CompatibleFlag, parsedArg2Compatible = ParseBooleanLike(arg2)
        local hasArg3CompatibleFlag, parsedArg3Compatible = ParseBooleanLike(arg3)
        if arg4 ~= nil and hasArg3CompatibleFlag then
            -- Server ACK currently arrives as: version, serverCaps, compatible, negotiatedCaps
            parserMode = "pipe-new-servercaps"
            compatible = parsedArg3Compatible
            negotiatedCaps = tonumber(arg4) or 0
        elseif hasArg2CompatibleFlag then
            -- New server ACK: version, compatible(bool), negotiatedCaps(number)
            parserMode = "pipe-new"
            compatible = parsedArg2Compatible
            negotiatedCaps = tonumber(arg3) or 0
        elseif arg3 ~= nil then
            parserMode = "pipe-new-fallback"
            compatible = true
            negotiatedCaps = tonumber(arg3) or 0
        else
            -- Legacy ACK: version, features
            parserMode = "pipe-legacy"
            compatible = true
            negotiatedCaps = 0
            features = arg2
        end
        serverHandshakeMetadata = ParseServerHandshakeMetadataPayload(arg4)
    end

    DC._serverVersion = tostring(version)
    DC._serverCaps = negotiatedCaps or 0
    DC._serverHandshakeMetadata = serverHandshakeMetadata
    DC._serverDataFeatureStates = serverHandshakeMetadata
        and serverHandshakeMetadata.dataFeatureStates or nil
    DC._lastHandshakeAck = {
        parserMode = parserMode,
        rawArg1 = DescribeHandshakeArg(arg1),
        rawArg2 = DescribeHandshakeArg(arg2),
        rawArg3 = DescribeHandshakeArg(arg3),
        rawArg4 = DescribeHandshakeArg(arg4),
        compatible = compatible and true or false,
        negotiatedCaps = tonumber(negotiatedCaps) or 0,
        serverHandshakeMetadata = serverHandshakeMetadata,
        receivedAt = time() or 0,
    }

    DC:LogNetEvent("info", "handshake", string.format(
        "ack mode=%s server=%s compatible=%s negotiated=0x%X client=0x%X raw2=%s raw3=%s raw4=%s",
        tostring(parserMode),
        tostring(version),
        tostring(compatible),
        tonumber(negotiatedCaps) or 0,
        tonumber(DC:GetClientCapabilities()) or 0,
        tostring(DC._lastHandshakeAck.rawArg2),
        tostring(DC._lastHandshakeAck.rawArg3),
        tostring(DC._lastHandshakeAck.rawArg4)))
    
    if compatible then
        DC:_OnHandshakeSuccess()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r Connected to server v" .. tostring(version))
    else
        DC:_OnHandshakeFailed("Version mismatch")
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[DC Protocol]|r Protocol version mismatch (client v" .. tostring(DC.VERSION) .. "). Please update your DC addons.")
        return
    end
    
    DC:DebugPrint("Handshake ACK received, server v" .. tostring(version) .. " compatible=" .. tostring(compatible) .. " caps=" .. tostring(negotiatedCaps))

    if features then
        if type(features) == "table" then
            for _, feat in ipairs(features) do
                DC._features[feat] = true
            end
        elseif type(features) == "string" then
            for feat in string.gmatch(features, "([^,]+)") do
                DC._features[feat] = true
            end
        end
    end

    local handshakeEvent = {
        type = "core-handshake",
        serverVersion = DC._serverVersion,
        connected = DC._connected and true or false,
        compatible = compatible and true or false,
        clientCaps = tonumber(DC:GetClientCapabilities()) or 0,
        negotiatedCaps = tonumber(DC._serverCaps) or 0,
        parserMode = parserMode,
        serverDataFeatureStates = DC._serverDataFeatureStates,
        rawArg2 = DC._lastHandshakeAck.rawArg2,
        rawArg3 = DC._lastHandshakeAck.rawArg3,
        rawArg4 = DC._lastHandshakeAck.rawArg4,
    }
    for _, handler in ipairs(DC._crossEventHandlers or {}) do
        DC:_InvokeHandlerSafe("cross-event", "CORE", 0x10, handler, handshakeEvent)
    end
    
    -- Update settings panel if open
    if DC._statusText then
        local connected = "|cff00ff00Connected|r"
        local handlers = DC:CountHandlers()
        local debug = DC._debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        DC._statusText:SetText(
            "Status: " .. connected .. "\n" ..
            "Client Version: |cff00ccff" .. DC.VERSION .. "|r\n" ..
            "Server Version: |cff00ccff" .. DC._serverVersion .. "|r\n" ..
            "Client Caps: |cff00ccff" .. DC:DescribeCapabilities(DC:GetClientCapabilities()) .. "|r\n" ..
            "Negotiated Caps: |cff00ccff" .. DC:DescribeCapabilities(DC._serverCaps or 0) .. "|r\n" ..
            "Handlers: |cffffff00" .. handlers .. "|r\n" ..
            "Debug Mode: " .. debug
        )
    end
end)

DC:RegisterHandler("CORE", 0x12, function(...)
    local features = {...}
    DC:DebugPrint("Feature list received:", table.concat(features, ", "))
    for _, feat in ipairs(features) do
        DC._features[feat] = true
    end
end)

DC:RegisterHandler("CORE", 0x14, function(data)
    if type(data) ~= "table" then return end
    DC._serverContext = {
        seasonId = tonumber(data.seasonId) or 0,
        seasonName = data.seasonName or data.name,
        phaseMask = tonumber(data.phaseMask) or 1,
    }
    for _, handler in ipairs(DC._serverContextHandlers or {}) do
        DC:_InvokeHandlerSafe("server-context", "CORE", 0x14, handler, DC._serverContext)
    end
end)

DC:RegisterHandler("CORE", 0x15, function(data)
    if type(data) ~= "table" then return end
    for _, handler in ipairs(DC._crossEventHandlers or {}) do
        DC:_InvokeHandlerSafe("cross-event", "CORE", 0x15, handler, data)
    end
end)

-- Test response handler (opcode 0x63 = 99 decimal) - for debug panel testing
DC:RegisterHandler("CORE", 0x63, function(...)
    local args = {...}
    if type(args[1]) == "table" then
        -- JSON response
        local json = args[1]
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Test Response]|r Received JSON response from server:")
        for k, v in pairs(json) do
            DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00" .. tostring(k) .. "|r = " .. tostring(v))
        end
    else
        -- Pipe-delimited response
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Test Response]|r Server replied: " .. table.concat(args, ", "))
    end
end)

-- SMSG_KEYSTONE_LIST: update client-side keystone mapping from server
DC:RegisterHandler("MPLUS", 0x17, function(data)
    -- Expect JSON payload: { items = [300313, 300314, ...] }
    if type(data) ~= 'table' then
        return
    end
    if data.items then
        -- Support string-encoded arrays (server may send JSON encoded string) and table arrays
        local itemsTbl = nil
        if type(data.items) == 'table' then
            itemsTbl = data.items
        elseif type(data.items) == 'string' then
            -- Try to decode JSON string to a table
            local ok, decoded = pcall(function() return DC:DecodeJSON(data.items) end)
            if ok and type(decoded) == 'table' then
                itemsTbl = decoded
            else
                -- Fallback: parse comma-separated numbers
                itemsTbl = {}
                for num in string.gmatch(data.items, '(%d+)') do
                    table.insert(itemsTbl, tonumber(num))
                end
            end
        end
        if itemsTbl and type(itemsTbl) == 'table' then
            DC:SetKeystoneItemIds(itemsTbl)
            if DC._debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Keystone ID list updated from server (" .. tostring(#itemsTbl) .. " items)")
            end
        end
    end
end)

-- Generic echo handler for any module test (opcode 0xFF)
DC:RegisterHandler("CORE", 0xFF, function(...)
    local args = {...}
    if type(args[1]) == "table" then
        local json = args[1]
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Echo]|r Server echoed back:")
        DEFAULT_CHAT_FRAME:AddMessage("  " .. DC:EncodeJSON(json))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Echo]|r " .. table.concat(args, "|"))
    end
end)

-- ============================================================
-- Request/Response Log Panel (Leaderboard Style)
-- ============================================================

-- Statistics tracking - initialize sessionStart
DC._stats.sessionStart = time()

-- Update statistics when logging
function DC:UpdateStats(entryType, entry)
    if entryType == "request" then
        self._stats.totalRequests = self._stats.totalRequests + 1
        
        -- Per-module stats
        local mod = entry.module or "UNKNOWN"
        if not self._stats.moduleStats[mod] then
            self._stats.moduleStats[mod] = {
                requests = 0,
                responses = 0,
                timeouts = 0,
                totalResponseTime = 0,
                avgResponseTime = 0,
            }
        end
        self._stats.moduleStats[mod].requests = self._stats.moduleStats[mod].requests + 1
        
    elseif entryType == "response" then
        self._stats.totalResponses = self._stats.totalResponses + 1
        
        local mod = entry.module or "UNKNOWN"
        if self._stats.moduleStats[mod] then
            self._stats.moduleStats[mod].responses = self._stats.moduleStats[mod].responses + 1
        end
        
    elseif entryType == "timeout" then
        self._stats.totalTimeouts = self._stats.totalTimeouts + 1
        
        local mod = entry.module or "UNKNOWN"
        if self._stats.moduleStats[mod] then
            self._stats.moduleStats[mod].timeouts = self._stats.moduleStats[mod].timeouts + 1
        end
    end
end

-- The request/response log panel lives in the LoadOnDemand companion addon
-- DC-AddonProtocolUI (LogPanel.lua). Opened via `/dc log`, which calls
-- DC:EnsureUIAddon() first. DC:UpdateStats above stays here: it runs on the
-- logging path for every request, whether or not the viewer is ever opened.

function DC:CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r v" .. DC.VERSION .. " loaded" .. (DC._chatFrameProtected and " (ChatFrame protected)" or ""))
