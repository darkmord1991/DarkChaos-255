-- ============================================================
-- DC-QoS: Tooltips Module - Spells
-- Split out of Tooltips.lua; state is shared via DCQOS.TooltipsNS
-- ============================================================

local addon = DCQOS
local TT = addon.TooltipsNS
local Tooltips = TT.module

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

    if tooltip.GetName and tooltip.NumLines then
        local tipName = tooltip:GetName()
        if tipName and tipName ~= "" then
            for i = 1, tooltip:NumLines() do
                local left = _G[tipName .. "TextLeft" .. i]
                local text = left and left.GetText and left:GetText() or nil
                local normalized = tostring(text or "")
                normalized = normalized:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                normalized = normalized:gsub("%s+", " ")
                normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
                if string.lower(normalized) == "spell id:" then
                    tooltip._dcqosSpellIdShown = sid
                    return
                end
            end
        end
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
local spellEnrichmentRequestCounter = 0
TT.pendingSpellEnrichment = {}
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

function TT.NormalizeTooltipGuid(guid)
    if type(guid) ~= "string" or guid == "" then
        return nil
    end

    if string.sub(guid, 1, 2) ~= "0x" then
        return "0x" .. guid
    end

    return guid
end

function TT.GetNativeMouseoverTooltipGuid()
    if type(GetLastMouseoverGUIDHex) ~= "function" then
        return nil
    end

    local ok, guid = pcall(GetLastMouseoverGUIDHex)
    if not ok then
        return nil
    end

    guid = TT.NormalizeTooltipGuid(guid)
    if not guid then
        return nil
    end

    local entry = TT.ParseNpcFromGuid and select(1, TT.ParseNpcFromGuid(guid))
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

-- Server-side errors on native-bridge enrichment requests (observed live:
-- the addon JSON path answers the same spells fine). After a streak of
-- native errors, stop using the bridge for the rest of the session.
local nativeSpellEnrichmentErrorStreak = 0
local NATIVE_SPELL_ENRICH_ERROR_STREAK_LIMIT = 3

function TT.ShouldUseNativeSpellTooltipAddonBridge()
    if not HasNativeSpellTooltipAddonBridge() then
        return false
    end

    if not IsNativeSpellTooltipNegotiated() then
        return false
    end

    if nativeSpellEnrichmentErrorStreak >= NATIVE_SPELL_ENRICH_ERROR_STREAK_LIMIT then
        return false
    end

    local stats = CaptureNativeSpellTooltipStats()
    if stats ~= nil and (not stats.enabled or stats.sessionDisabled) then
        return false
    end

    return true
end

function TT.ShouldUseNativeItemUpgradeBridge()
    return HasNativeItemUpgradeBridge()
        and IsCapabilityNegotiated(NATIVE_ITEM_UPGRADE_CAPABILITY)
end

function TT.ShouldUseNativeNpcTooltipBridge()
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

function TT.SyncNativeSpellTooltipBridge(reason)
    reason = tostring(reason or "sync")

    if not HasNativeSpellTooltipBridge() then
        TT.lastNativeBridgeSync = {
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

    TT.lastNativeBridgeSync = {
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

function TT.RegisterProtocolCapabilityHook()
    if TT.protocolCapabilityHookRegistered then
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

        TT.SyncNativeSpellTooltipBridge("core-handshake")

        if HasCapabilityBit(tonumber(eventData.negotiatedCaps) or 0,
            NATIVE_TOOLTIP_CAPABILITY) then
            TT.QueueSpellEnrichmentPrefetch(1)
        end
    end)
    TT.protocolCapabilityHookRegistered = true
end

function TT.GetNativeSpellTooltipBridgeSnapshot()
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
        lastBridgeSync = TT.lastNativeBridgeSync,
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
        TT.TelemetryInc("spell", "clientDescriptionMissingExport")
        return nil
    end

    local ok, description = pcall(function()
        return GetSpellDescription(sid)
    end)
    if not ok then
        TT.TelemetryInc("spell", "clientDescriptionCallError")
        return nil
    end

    if description == nil then
        TT.TelemetryInc("spell", "clientDescriptionNilReturn")
        return nil
    end

    if type(description) ~= "string" then
        TT.TelemetryInc("spell", "clientDescriptionCallError")
        return nil
    end

    description = description:gsub("\r\n", "\n"):gsub("\r", "\n")
    description = description:gsub("^%s+", ""):gsub("%s+$", "")
    if description == "" then
        TT.TelemetryInc("spell", "clientDescriptionEmptyBody")
        return nil
    end

    -- This client export can return raw Blizzard-style placeholders like $s1
    -- or $d for stance/presence/stealth spells. Showing that body is better
    -- than dropping the tooltip text entirely; only reject transport-only
    -- placeholder payloads such as $<percent>.
    if description:find("%$<[^>]+>") then
        TT.TelemetryInc("spell", "clientDescriptionPlaceholderRejected")
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
                TT.TelemetryInc("spell", "clientRowsCacheHit")
                return cached.rows
            end
            return nil
        end
    end

    local ok, rows = pcall(GetNativeSpellTooltipRows, sid, request.source,
        request.primaryIndex, request.secondary)
    if not ok then
        TT.TelemetryInc("spell", "clientRowsCallError")
        nativeClientSpellRowsCache[cacheKey] = {
            ok = false,
            checkedAt = now,
        }
        addon:Debug("Native spell tooltip row probe failed: " .. tostring(rows))
        return nil
    end

    local hasRows = HasMeaningfulNativeSpellTooltipRows(rows)
    TT.TelemetryInc("spell", hasRows and "clientRowsSatisfied" or "clientRowsEmpty")
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
        -- Buff/debuff tooltips already carry the aura's own description and
        -- remaining time; appending the (different) full spell description
        -- plus cost/cast lines bloats a small frame. Keep them native-only
        -- (EnhanceSpellTooltip still adds the Spell ID line).
        return "disabled"
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

    for key, pending in pairs(TT.pendingSpellEnrichment) do
        local sentAt = pending and tonumber(pending.sentAt) or 0
        if sentAt <= 0 or (now - sentAt) > SPELL_TOOLTIP_TRACKING_STALE_TTL then
            local reqId = pending and tonumber(pending.requestId) or 0
            if reqId > 0 and pendingSpellEnrichmentByRequestId[reqId] == key then
                pendingSpellEnrichmentByRequestId[reqId] = nil
            end
            TT.pendingSpellEnrichment[key] = nil
        end
    end

    for reqId, mappedKey in pairs(pendingSpellEnrichmentByRequestId) do
        if not TT.pendingSpellEnrichment[mappedKey] then
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

function TT.TryConsumeNativeSpellTooltipEnrichment(spellId, contextHash)
    if type(PollNativeSpellTooltipEnrichment) ~= "function" then
        return false
    end

    local sid = tonumber(spellId) or 0
    local ctx = tonumber(contextHash) or 0
    if sid <= 0 or ctx <= 0 then
        return false
    end

    local key = BuildSpellEnrichmentKey(sid, ctx)
    local pending = TT.pendingSpellEnrichment[key]
    if not pending then
        return false
    end

    local ok, nativeStatus, line, structuredLines =
        pcall(PollNativeSpellTooltipEnrichment, sid, ctx)
    if not ok then
        TT.TelemetryInc("spell", "nativeErrors")
        addon:Debug("Native spell tooltip poll failed: " .. tostring(nativeStatus))
        return false
    end

    nativeStatus = tonumber(nativeStatus) or 0
    if nativeStatus == 1 or nativeStatus == 0 then  -- PENDING or UNAVAILABLE
        return false
    end

    if nativeStatus == 2 then  -- READY
        TT.TelemetryInc("spell", "nativeResponsesReady")
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

    TT.TelemetryInc("spell", "nativeErrors")
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
    -- A locally rendered cast line (AddSpellStatLines) can differ from the
    -- server's by rounding/haste; text dedupe alone would then show both.
    local existingHasCastLine = false
    for existingKey in pairs(existing) do
        if existingKey == "instant cast" or existingKey:find(" sec cast$") then
            existingHasCastLine = true
            break
        end
    end

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
            local isDuplicateCastLine = existingHasCastLine
                and (leftNorm == "instant cast" or leftNorm:find(" sec cast$"))

            if leftNorm ~= "" and not existing[key] and not existing[leftNorm]
                and not isDuplicateCastLine then
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
        and TT.ShouldUseNativeSpellTooltipAddonBridge()

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
        TT.TelemetryInc("spell", "skippedRenderModeDisabled")
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
        TT.TelemetryInc("spell", renderedNativeRows and "clientRowsRendered"
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
        local pending = TT.pendingSpellEnrichment[key]
        if pending and (now - (pending.sentAt or 0)) > SPELL_TOOLTIP_ENRICHMENT_PENDING_TTL then
            local reqId = pending and tonumber(pending.requestId) or 0
            if reqId > 0 and pendingSpellEnrichmentByRequestId[reqId] == key then
                pendingSpellEnrichmentByRequestId[reqId] = nil
            end
            TT.pendingSpellEnrichment[key] = nil
            TT.TelemetryInc("spell", "pendingTimeoutRecoveries")
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
        TT.pendingSpellEnrichment[key] = {
            requestId = requestId,
            sentAt = now,
            transport = "addon",
        }
        pendingSpellEnrichmentByRequestId[requestId] = key
        lastSpellEnrichmentAttemptAt[key] = now
        lastSpellEnrichmentSendAt = now
        TT.TelemetryInc("spell", "requestsSent")

        local ok = false
        if useNativeAddonTransport then
            local nativeOk, nativeErr = pcall(RequestNativeSpellTooltipEnrichment,
                sid, contextHash)
            if nativeOk then
                TT.TelemetryInc("spell", "nativeRequestsSent")
                TT.pendingSpellEnrichment[key].transport = "native"
                ok = true
            else
                TT.TelemetryInc("spell", "nativeErrors")
                addon:Debug("Native spell tooltip request failed: " .. tostring(nativeErr))
            end
        end

        if not ok and not nativeSpellTooltipAddonAvailable then
            ok = addon:RequestSpellTooltipEnrichment(requestId, sid, contextHash, false)
        end
        if not ok then
            TT.pendingSpellEnrichment[key] = nil
            pendingSpellEnrichmentByRequestId[requestId] = nil
            TT.TelemetryInc("spell", "requestSendFailures")
            return false  -- request failed, no callback expected
        end
        return nil  -- request sent; callback will deliver lines and Spell ID
    end
end

local function OnSpellTooltipEnrichmentReceived(data)
    if type(data) ~= "table" then return end
    TT.TelemetryInc("spell", "responsesReceived")

    local sid = tonumber(data.spellId) or 0
    local contextHash = tonumber(data.contextHash) or 0
    if sid <= 0 or contextHash <= 0 then return end

    local key = BuildSpellEnrichmentKey(sid, contextHash)
    local pending = TT.pendingSpellEnrichment[key]
    local responseReqId = tonumber(data.requestId) or 0

    if not pending and responseReqId > 0 then
        local mappedKey = pendingSpellEnrichmentByRequestId[responseReqId]
        if mappedKey then
            pending = TT.pendingSpellEnrichment[mappedKey]
            if pending then
                key = mappedKey
                TT.TelemetryInc("spell", "responsesRemappedByRequestId")

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
        TT.TelemetryInc("spell", "responsesWithoutPending")
    end

    if pending then
        if responseReqId > 0 then
            if responseReqId ~= pending.requestId then
                TT.TelemetryInc("spell", "responseRequestIdMismatch")
                return
            end
            pendingSpellEnrichmentByRequestId[responseReqId] = nil
            TT.pendingSpellEnrichment[key] = nil
        end
    end

    local status = tonumber(data.status) or 0
    if status == 0 then
        TT.TelemetryInc("spell", "responsesSuccess")
        if pending and pending.transport == "native" then
            nativeSpellEnrichmentErrorStreak = 0
        end
    else
        TT.TelemetryInc("spell", "responsesError")

        -- Native-bridge requests can fail server-side while the addon JSON
        -- path answers the same spells fine (observed live: spellbook works,
        -- action/companion tooltips stay bare). Retry once over the addon
        -- transport; the streak counter parks the bridge for the session.
        if pending and pending.transport == "native" then
            nativeSpellEnrichmentErrorStreak = nativeSpellEnrichmentErrorStreak + 1
            if not pending.addonRetry
                and addon.RequestSpellTooltipEnrichment
                and addon.protocol and addon.protocol.connected then
                local retryRequestId = NextSpellEnrichmentRequestId()
                if addon:RequestSpellTooltipEnrichment(retryRequestId, sid,
                    contextHash, false) then
                    TT.pendingSpellEnrichment[key] = {
                        requestId = retryRequestId,
                        sentAt = GetTime(),
                        transport = "addon",
                        addonRetry = true,
                    }
                    pendingSpellEnrichmentByRequestId[retryRequestId] = key
                    lastSpellEnrichmentSendAt = GetTime()
                    lastSpellEnrichmentAttemptAt[key] = nil
                    TT.TelemetryInc("spell", "nativeErrorAddonRetries")
                    -- Leave the open tooltip un-finalized; the retry response
                    -- re-renders it through the normal path.
                    return
                end
            end
        end
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

TT.QueueSpellEnrichmentPrefetch = function(delay)
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

    TT.TelemetryInc("spell", "prefetchRuns")

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
            elseif TT.pendingSpellEnrichment[key] then
                -- Already in-flight, skip.
            else
                -- Respect shared global pacing so tooltip hovers are not starved.
                if (now - (tonumber(lastSpellEnrichmentSendAt) or 0)) < SPELL_TOOLTIP_ENRICHMENT_MIN_SEND_INTERVAL then
                    queueIdx = queueIdx - 1  -- retry this entry next tick
                    return
                end
                local requestId = NextSpellEnrichmentRequestId()
                TT.pendingSpellEnrichment[key] = { requestId = requestId, sentAt = now }
                lastSpellEnrichmentAttemptAt[key] = now
                lastSpellEnrichmentSendAt = now
                TT.TelemetryInc("spell", "prefetchRequestsSent")
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
    TT.AddMountInfo(tooltip, spellId)
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
        -- SetUnitBuff/Aura already laid the tooltip out; without a re-Show
        -- the appended Spell ID line renders outside the backdrop.
        if type(tooltip.Show) == "function" and tooltip:IsShown() then
            tooltip:Show()
        end
    end
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

function TT.InvalidateSpellNameCache()
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

    if type(GetNumSpellTabs) == "function"
        and type(GetSpellTabInfo) == "function"
        and type(GetSpellBookItemName) == "function" then
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
    end

    local lowerFormName = type(formName) == "string" and strlower(formName) or nil
    local knownFormSpellIds = lowerFormName and {
        ["stealth"] = {1787, 1786, 1785, 1784},
        ["battle stance"] = {2457},
        ["defensive stance"] = {71},
        ["berserker stance"] = {2458},
        ["blood presence"] = {48266},
        ["frost presence"] = {48263},
        ["unholy presence"] = {48265},
        ["bear form"] = {5487},
        ["dire bear form"] = {9634},
        ["cat form"] = {768},
        ["prowl"] = {9913, 6783, 5215},
        ["travel form"] = {783},
        ["aquatic form"] = {1066},
        ["moonkin form"] = {24858},
        ["tree of life"] = {33891},
        ["flight form"] = {33943},
        ["swift flight form"] = {40120},
        ["ghost wolf"] = {2645},
        ["shadowform"] = {15473},
        ["metamorphosis"] = {47241},
    }
    local candidateIds = knownFormSpellIds and knownFormSpellIds[lowerFormName]
    if candidateIds then
        if type(GetSpellInfo) == "function" then
            for _, candidateId in ipairs(candidateIds) do
                local candidateName = GetSpellInfo(candidateId)
                if candidateName and strlower(candidateName) == lowerFormName then
                    return candidateId
                end
            end
        end

        return candidateIds[1]
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

-- Server GetPowerTypeLabel equivalents (keep text identical for dedupe).
local SPELL_POWER_TYPE_LABELS = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [4] = "Happiness",
    [5] = "Rune",
    [6] = "Runic Power",
}

-- Native rows from hyperlink-style contexts can be description-only; only a
-- cast-time line proves the row set carries the cost/range/cast stat block.
local function NativeRowsContainStatLines(rows)
    if type(rows) ~= "table" then
        return false
    end

    for _, rawEntry in ipairs(rows) do
        local entry = rawEntry
        if type(entry) ~= "table" then
            entry = { left = tostring(rawEntry or "") }
        end
        local leftNorm = NormalizeTooltipTextValue(entry.left or "")
        if leftNorm == "instant cast" or leftNorm:find(" sec cast$") then
            return true
        end
    end

    return false
end

-- True when the stat block will be drawn by another layer: native client
-- rows that actually resolve for THIS tooltip's request context AND carry
-- stat lines, or fresh cached server enrichment lines (both already include
-- cost/range/cast, plus cooldown/duration the Lua API cannot read). The rows
-- export existing is NOT enough on its own: action/hyperlink contexts can
-- come back empty or body-only even when spellbook contexts work, and then
-- nothing would draw the stats.
local function WillEnrichmentProvideStatLines(tooltip, spellId)
    local sid = tonumber(spellId)
    if not sid or sid <= 0 then
        return false
    end

    local contextHash = BuildSpellTooltipContextHash(sid)

    if HasNativeSpellTooltipRowsExport() then
        local rows = GetNativeClientSpellTooltipRows(tooltip, sid, contextHash)
        if rows and NativeRowsContainStatLines(rows) then
            return true
        end
    end

    if not addon.GetSpellTooltipEnrichment then
        return false
    end
    if not addon.settings or not addon.settings.tooltips
        or not addon.settings.tooltips.enabled
        or not addon.settings.communication
        or not addon.settings.communication.enabled then
        return false
    end

    local cached = addon:GetSpellTooltipEnrichment(sid, contextHash)
    if not cached or tonumber(cached.status) ~= 0
        or type(cached.lines) ~= "table" or #cached.lines == 0 then
        return false
    end

    local age = GetTime() - (tonumber(cached.receivedAt) or 0)
    return age <= SPELL_TOOLTIP_ENRICHMENT_OK_TTL
end

-- Locally rendered stat block (cost | range double line + cast time line),
-- shaped exactly like the server enrichment rows so the enrichment dedupe
-- (BuildExistingTooltipTextSet keys) suppresses the server copies when they
-- arrive later. Keeps action-bar and spellbook tooltips carrying mana/range/
-- cast time even when enrichment is cold or unavailable.
local function AddSpellStatLines(tooltip, spellId, existing)
    local sid = tonumber(spellId)
    if not tooltip or not sid or sid <= 0
        or type(GetSpellInfo) ~= "function" then
        return
    end

    -- 3.3.5 GetSpellInfo: name, rank, icon, cost, isFunnel, powerType,
    -- castTime (ms), minRange, maxRange.
    local name, _, _, cost, _, powerType, castTimeMs, minRange, maxRange =
        GetSpellInfo(sid)
    if not name or name == "" then
        return
    end

    existing = existing or BuildExistingTooltipTextSet(tooltip)

    local costText
    cost = tonumber(cost) or 0
    if cost > 0 then
        local label = SPELL_POWER_TYPE_LABELS[tonumber(powerType) or 0] or "Mana"
        costText = string.format("%d %s", cost, label)
    end
    local rangeText = FormatSpellRangeText(minRange, maxRange)

    if costText and rangeText and type(tooltip.AddDoubleLine) == "function" then
        local leftNorm = NormalizeTooltipTextValue(costText)
        local rightNorm = NormalizeTooltipTextValue(rangeText)
        local key = leftNorm .. "||" .. rightNorm
        if not existing[key] and not existing[leftNorm] then
            tooltip:AddDoubleLine(costText, rangeText,
                1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
            existing[key] = true
            existing[leftNorm] = true
            existing[rightNorm] = true
        end
    elseif costText then
        AddUniqueTooltipLine(tooltip, existing, costText, 1.0, 1.0, 1.0, false)
    elseif rangeText then
        AddUniqueTooltipLine(tooltip, existing, rangeText, 1.0, 1.0, 1.0, false)
    end

    AddUniqueTooltipLine(tooltip, existing,
        FormatSpellCastTimeText(castTimeMs), 1.0, 1.0, 1.0, false)
end

local function AddFallbackSpellBookLines(tooltip, tooltipData)
    if not tooltip or type(tooltipData) ~= "table" then
        return
    end

    local spellId = tonumber(tooltipData.spellId)
    local existing = BuildExistingTooltipTextSet(tooltip)

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
    end

    if spellId and spellId > 0 then
        local description = GetClientSpellDescription(spellId)
        if description then
            AddClientSpellDescriptionLines(tooltip, description)
        end

        -- Body first, stat block after: matches the action-bar tooltip layout
        -- (hyperlink bodies cannot be split) so both render identically.
        if not passive and not WillEnrichmentProvideStatLines(tooltip, spellId) then
            AddSpellStatLines(tooltip, spellId, existing)
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
            if wroteText and not WillEnrichmentProvideStatLines(GameTooltip, resolvedId) then
                -- Hyperlink bodies carry no cost/range/cast block; add it so
                -- action tooltips match the spellbook rendering.
                AddSpellStatLines(GameTooltip, resolvedId)
            end
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
            if resolvedId and not WillEnrichmentProvideStatLines(GameTooltip, resolvedId) then
                AddSpellStatLines(GameTooltip, resolvedId)
            end
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
        return false
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
        Tooltips._lastShapeshiftTooltipDebug = {
            path = "fallback-shapeshift",
            reason = "missing-form-index",
        }
        return false
    end

    local formTexture, formName, _, _, directSpellId
    if type(GetShapeshiftFormInfo) == "function" then
        formTexture, formName, _, _, directSpellId = GetShapeshiftFormInfo(formIndex)
    end

    local buttonName
    if type(button) == "table" and type(button.GetName) == "function" then
        buttonName = button:GetName()
    end

    local actionSlot = type(button) == "table" and tonumber(button.action) or nil
    local actionType, actionValue, actionSubType, actionSpellId
    if actionSlot and actionSlot > 0 and type(GetActionInfo) == "function" then
        actionType, actionValue, actionSubType, actionSpellId = GetActionInfo(actionSlot)
    end

    if type(GameTooltip.SetOwner) == "function" then
        if GameTooltip_SetDefaultAnchor and GetCVar and GetCVar("UberTooltips") == "1" and button then
            GameTooltip_SetDefaultAnchor(GameTooltip, button)
        elseif button then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        end
    end

    if type(GameTooltip.ClearLines) == "function" then
        GameTooltip:ClearLines()
    end

    local nativeSetShapeshift = ResolveTooltipMethod(GameTooltip, "SetShapeshift")
    local nativeSetShapeshiftOk = false
    if type(nativeSetShapeshift) == "function" then
        local previousSuppress = GameTooltip._dcqosSuppressSpellHooks
        GameTooltip._dcqosSuppressSpellHooks = true
        nativeSetShapeshiftOk = pcall(function()
            nativeSetShapeshift(GameTooltip, formIndex)
        end)
        GameTooltip._dcqosSuppressSpellHooks = previousSuppress
    end

    if not nativeSetShapeshiftOk then
        SafeFallbackSetShapeshift(GameTooltip, formIndex)
    end

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

    local nativeSetSpellByIdOk = false
    local clientDescriptionShown = false
    local clientDescriptionLength = 0

    if spellId and spellId > 0 then
        local nativeSetSpellById = ResolveTooltipMethod(GameTooltip,
            "SetSpellByID")
        if type(nativeSetSpellById) == "function" then
            local previousSuppress = GameTooltip._dcqosSuppressSpellHooks
            GameTooltip._dcqosSuppressSpellHooks = true
            nativeSetSpellByIdOk = pcall(function()
                nativeSetSpellById(GameTooltip, spellId)
            end)
            GameTooltip._dcqosSuppressSpellHooks = previousSuppress
        end

        if (not nativeSetSpellByIdOk)
            and type(formName) == "string" and formName ~= "" then
            GameTooltip:SetText(formName)
        end

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
                clientDescriptionLength = string.len(description)
                clientDescriptionShown = AddClientSpellDescriptionLines(
                    GameTooltip, description)
                GameTooltip._dcqosClientDescriptionShownKey = key
            end
        end

        TrySetTooltipHyperlink(GameTooltip, "spell:" .. tostring(spellId))
        GameTooltip._dcqosResolvedSpellId = spellId
        EnhanceSpellTooltip(GameTooltip, spellId)
    end

    local tooltipLines = nil
    if type(GameTooltip.NumLines) == "function" then
        tooltipLines = GameTooltip:NumLines()
    end

    Tooltips._lastShapeshiftTooltipDebug = {
        path = "fallback-shapeshift",
        buttonName = buttonName,
        formIndex = formIndex,
        formName = formName,
        formTexture = formTexture,
        buttonSpellId = type(button) == "table"
            and tonumber(button.spellId or button.spellID) or nil,
        actionSlot = actionSlot,
        actionType = actionType,
        actionValue = actionValue,
        actionSubType = actionSubType,
        actionSpellId = actionSpellId,
        directSpellId = directSpellId,
        resolvedSpellId = spellId,
        nativeSetShapeshift = nativeSetShapeshiftOk,
        nativeSetSpellByID = nativeSetSpellByIdOk,
        clientDescriptionShown = clientDescriptionShown,
        clientDescriptionLength = clientDescriptionLength,
        tooltipLines = tooltipLines,
        time = type(GetTime) == "function" and GetTime() or nil,
    }

    GameTooltip:Show()
    return true
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

    button.UpdateTooltip = nil
    button.updateTooltip = nil
    return SetFallbackShapeshiftTooltip(button)
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

function TT.HookSpellTooltips()
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
            if self._dcqosSuppressSpellHooks then
                return
            end

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

            local nativeSetSpellByIdOk = false
            local clientDescriptionShown = false
            local clientDescriptionLength = 0
            if spellId and spellId > 0 then
                local nativeSetSpellById = ResolveTooltipMethod(self,
                    "SetSpellByID")
                if type(nativeSetSpellById) == "function" then
                    local previousSuppress = self._dcqosSuppressSpellHooks
                    self._dcqosSuppressSpellHooks = true
                    nativeSetSpellByIdOk = pcall(function()
                        nativeSetSpellById(self, spellId)
                    end)
                    self._dcqosSuppressSpellHooks = previousSuppress
                end

                local contextHash = BuildSpellTooltipContextHash(spellId)
                local key = BuildSpellEnrichmentKey(spellId, contextHash)
                local nativeRows = GetNativeClientSpellTooltipRows(self,
                    spellId, contextHash)
                local renderedNativeRows = nativeRows
                    and RenderNativeClientSpellTooltipRows(self, nativeRows)
                    or false

                if renderedNativeRows then
                    self._dcqosSpellEnrichmentShownKey = key
                else
                    local description = GetClientSpellDescription(spellId)
                    if type(description) == "string" and description ~= "" then
                        clientDescriptionLength = string.len(description)
                        clientDescriptionShown = AddClientSpellDescriptionLines(
                            self, description)
                        self._dcqosClientDescriptionShownKey = key
                    end
                end

                TrySetTooltipHyperlink(self, "spell:" .. tostring(spellId))
                self._dcqosResolvedSpellId = spellId
                EnhanceSpellTooltip(self, spellId)
            end

            local formTexture, formName, _, _, directFormSpellId
            if type(GetShapeshiftFormInfo) == "function" then
                formTexture, formName, _, _, directFormSpellId =
                    GetShapeshiftFormInfo(index)
            end

            local tooltipLines = nil
            if type(self.NumLines) == "function" then
                tooltipLines = self:NumLines()
            end

            Tooltips._lastShapeshiftTooltipDebug = {
                path = "setshapeshift-hook",
                formIndex = index,
                formName = formName,
                formTexture = formTexture,
                directSpellId = directFormSpellId,
                resolvedSpellId = spellId,
                nativeSetSpellByID = nativeSetSpellByIdOk,
                clientDescriptionShown = clientDescriptionShown,
                clientDescriptionLength = clientDescriptionLength,
                tooltipLines = tooltipLines,
                time = type(GetTime) == "function" and GetTime() or nil,
            }
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
            if self._dcqosSuppressSpellHooks then
                return
            end

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
            if self._dcqosSuppressSpellHooks then
                return
            end

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
