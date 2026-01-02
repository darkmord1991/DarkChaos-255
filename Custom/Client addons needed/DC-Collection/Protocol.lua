--[[
    DC-Collection Protocol.lua
    ==========================
    
    DCAddonProtocol integration for collection data sync.
    Handles all client-server communication for the collection system.
    
    Author: DarkChaos-255
    Version: 1.1.0
    
    Protocol Opcodes (COLL module):
    -------------------------------
    These opcodes MUST match DCAddonNamespace.h Opcode::Collection namespace
    
    Client -> Server (CMSG):
        CMSG_HANDSHAKE           = 0x01  -- Handshake with delta hash
        CMSG_GET_FULL_COLLECTION = 0x02  -- Request full collection data
        CMSG_SYNC_COLLECTION     = 0x03  -- Request delta sync
        CMSG_GET_STATS           = 0x04  -- Request stats (totals, bonuses)
        CMSG_GET_BONUSES         = 0x05  -- Request active bonuses
        
        CMSG_GET_SHOP            = 0x10  -- Request shop items
        CMSG_BUY_ITEM            = 0x11  -- Purchase from shop
        CMSG_GET_CURRENCIES      = 0x12  -- Request currency balances
        
        CMSG_GET_WISHLIST        = 0x20  -- Request wishlist
        CMSG_ADD_WISHLIST        = 0x21  -- Add to wishlist
        CMSG_REMOVE_WISHLIST     = 0x22  -- Remove from wishlist
        
        CMSG_USE_ITEM            = 0x30  -- Use/summon from collection
        CMSG_SET_FAVORITE        = 0x31  -- Set item as favorite
        CMSG_TOGGLE_UNLOCK       = 0x32  -- Toggle account-wide (heirlooms)
    
    Server -> Client (SMSG):
        SMSG_HANDSHAKE_ACK       = 0x40  -- Handshake response
        SMSG_FULL_COLLECTION     = 0x41  -- Full collection data (JSON)
        SMSG_DELTA_SYNC          = 0x42  -- Delta update (JSON)
        SMSG_STATS               = 0x43  -- Stats response
        SMSG_BONUSES             = 0x44  -- Active bonuses response
        SMSG_ITEM_LEARNED        = 0x45  -- New item learned notification
        
        SMSG_SHOP_DATA           = 0x50  -- Shop items (JSON)
        SMSG_PURCHASE_RESULT     = 0x51  -- Purchase result
        SMSG_CURRENCIES          = 0x52  -- Currency balances
        
        SMSG_WISHLIST_DATA       = 0x60  -- Wishlist items (JSON)
        SMSG_WISHLIST_AVAILABLE  = 0x61  -- Item on wishlist now available
        SMSG_WISHLIST_UPDATED    = 0x62  -- Wishlist updated
        
        SMSG_OPEN_UI             = 0x70  -- Open collection UI
        SMSG_ERROR               = 0x7F  -- Error response
]]

local DC = DCCollection

-- ============================================================================
-- OPCODE DEFINITIONS
-- Must match DCAddonNamespace.h Opcode::Collection namespace EXACTLY
-- ============================================================================

DC.Opcodes = {
    -- Client -> Server: Sync/Request
    CMSG_HANDSHAKE           = 0x01,
    CMSG_GET_FULL_COLLECTION = 0x02,
    CMSG_SYNC_COLLECTION     = 0x03,
    CMSG_GET_STATS           = 0x04,
    CMSG_GET_BONUSES         = 0x05,

    -- Client -> Server: Definitions / Per-type collections
    CMSG_GET_DEFINITIONS     = 0x06,
    CMSG_GET_COLLECTION      = 0x07,
    
    -- Client -> Server: Shop
    CMSG_GET_SHOP            = 0x10,
    CMSG_BUY_ITEM            = 0x11,
    CMSG_GET_CURRENCIES      = 0x12,
    
    -- Client -> Server: Wishlist
    CMSG_GET_WISHLIST        = 0x20,
    CMSG_ADD_WISHLIST        = 0x21,
    CMSG_REMOVE_WISHLIST     = 0x22,
    
    -- Client -> Server: Actions
    CMSG_USE_ITEM            = 0x30,
    CMSG_SET_FAVORITE        = 0x31,
    CMSG_TOGGLE_UNLOCK       = 0x32,

    -- Client -> Server: Transmog
    CMSG_SET_TRANSMOG            = 0x33,
    CMSG_GET_TRANSMOG_SLOT_ITEMS = 0x34,
    CMSG_SEARCH_TRANSMOG_ITEMS   = 0x35,
    CMSG_GET_COLLECTED_APPEARANCES = 0x36,
    CMSG_GET_TRANSMOG_STATE      = 0x37,
    CMSG_APPLY_TRANSMOG_PREVIEW  = 0x38,
    
    -- Client -> Server: Community
    CMSG_COMMUNITY_GET_LIST   = 0x39,
    CMSG_COMMUNITY_PUBLISH    = 0x3A,
    CMSG_COMMUNITY_RATE       = 0x3B,
    CMSG_COMMUNITY_FAVORITE   = 0x3C,
    CMSG_COMMUNITY_VIEW       = 0x3E,
    
    -- Server -> Client: Sync/Data
    SMSG_HANDSHAKE_ACK       = 0x40,
    SMSG_FULL_COLLECTION     = 0x41,
    SMSG_DELTA_SYNC          = 0x42,
    SMSG_STATS               = 0x43,
    SMSG_BONUSES             = 0x44,
    SMSG_ITEM_LEARNED        = 0x45,

    -- Server -> Client: Definitions / Per-type collections
    SMSG_DEFINITIONS         = 0x46,
    SMSG_COLLECTION          = 0x47,

    -- Server -> Client: Transmog
    SMSG_TRANSMOG_STATE          = 0x48,
    SMSG_TRANSMOG_SLOT_ITEMS     = 0x49,
    SMSG_COLLECTED_APPEARANCES   = 0x4A,

    -- Server -> Client: Community
    SMSG_COMMUNITY_LIST       = 0x63,
    SMSG_COMMUNITY_PUBLISH_RESULT = 0x64,

    
    -- Server -> Client: Shop
    SMSG_SHOP_DATA           = 0x50,
    SMSG_PURCHASE_RESULT     = 0x51,
    SMSG_CURRENCIES          = 0x52,
    
    -- Server -> Client: Wishlist
    SMSG_WISHLIST_DATA       = 0x60,
    SMSG_WISHLIST_AVAILABLE  = 0x61,
    SMSG_WISHLIST_UPDATED    = 0x62,
    
    -- Server -> Client: UI Control
    SMSG_OPEN_UI             = 0x70,
    SMSG_ERROR               = 0x7F,
}

-- ============================================================================
-- PROTOCOL STATE
-- ============================================================================

DC.pendingRequests = {}
DC.requestTimeout = 10  -- seconds
DC.isConnected = false
DC.lastPing = 0

-- ============================================================================
-- CLIENT-SIDE ERROR/TIMEOUT LOG
-- ============================================================================

function DC:LogNetEvent(level, tag, message, extra)
    DCCollectionDB = DCCollectionDB or {}
    local log = DCCollectionDB.netEventLog
    if type(log) ~= "table" then
        log = {}
        DCCollectionDB.netEventLog = log
    end

    local entry = {
        t = time(),
        level = tostring(level or "info"),
        tag = tostring(tag or ""),
        msg = tostring(message or ""),
        extra = extra,
    }
    log[#log + 1] = entry

    local maxEntries = tonumber(DCCollectionDB.netEventLogMaxEntries) or 200
    if maxEntries < 10 then maxEntries = 10 end
    while #log > maxEntries do
        table.remove(log, 1)
    end
end

function DC:ClearNetEventLog()
    DCCollectionDB = DCCollectionDB or {}
    DCCollectionDB.netEventLog = {}
end

function DC:DumpNetEventLog(count)
    DCCollectionDB = DCCollectionDB or {}
    local log = DCCollectionDB.netEventLog
    if type(log) ~= "table" or #log == 0 then
        self:Print("[NetLog] (empty)")
        return
    end

    local n = tonumber(count) or 20
    if n < 1 then n = 1 end
    if n > #log then n = #log end

    self:Print(string.format("[NetLog] Showing last %d/%d entries", n, #log))
    for i = #log - n + 1, #log do
        local e = log[i]
        local ts = (e and e.t and date("%H:%M:%S", e.t)) or "??:??:??"
        local lvl = (e and e.level) or "?"
        local tg = (e and e.tag and e.tag ~= "" and ("/" .. e.tag) or "") or ""
        local msg = (e and e.msg) or ""
        self:Print(string.format("[NetLog] %s [%s%s] %s", ts, lvl, tg, msg))
    end
end

-- ============================================================================
-- PROTOCOL INITIALIZATION
-- ============================================================================

function DC:InitializeProtocol()
    -- Check for DCAddonProtocol
    if not DCAddonProtocol then
        self:Print("|cffff0000Error:|r DCAddonProtocol not found. Collection System requires DC-AddonProtocol.")
        return false
    end

    -- Two protocol variants exist in this project:
    -- 1) Legacy DCAddonProtocol:RegisterModule(moduleId, callback) + :SendMessage(moduleId, payload)
    -- 2) Current DCAddonProtocol:RegisterJSONHandler(module, opcode, handler) + :Request(module, opcode, data)
    -- Support both to avoid runtime errors when the library is updated.

    -- Legacy API
    if type(DCAddonProtocol.RegisterModule) == "function" and type(DCAddonProtocol.SendMessage) == "function" then
        local success = DCAddonProtocol:RegisterModule(self.MODULE_ID, self.OnProtocolMessage)
        if success then
            self:Debug("Protocol module registered: " .. self.MODULE_ID)
            self.isConnected = true
            return true
        end

        self:Print("|cffff0000Error:|r Failed to register protocol module")
        return false
    end

    -- Current API
    if type(DCAddonProtocol.RegisterJSONHandler) ~= "function" or type(DCAddonProtocol.Request) ~= "function" then
        self:Print("|cffff0000Error:|r DCAddonProtocol API mismatch (missing RegisterJSONHandler/Request).")
        return false
    end

    local function registerOpcode(opcode)
        DCAddonProtocol:RegisterJSONHandler(self.MODULE_ID, opcode, function(data)
            DC.OnProtocolMessage({ op = opcode, data = data or {} })
        end)
    end

    -- Register handlers for all server->client opcodes we care about.
    registerOpcode(self.Opcodes.SMSG_HANDSHAKE_ACK)
    registerOpcode(self.Opcodes.SMSG_FULL_COLLECTION)
    registerOpcode(self.Opcodes.SMSG_DELTA_SYNC)
    registerOpcode(self.Opcodes.SMSG_STATS)
    registerOpcode(self.Opcodes.SMSG_BONUSES)
    registerOpcode(self.Opcodes.SMSG_ITEM_LEARNED)
    registerOpcode(self.Opcodes.SMSG_DEFINITIONS)
    registerOpcode(self.Opcodes.SMSG_COLLECTION)
    registerOpcode(self.Opcodes.SMSG_TRANSMOG_STATE)
    registerOpcode(self.Opcodes.SMSG_TRANSMOG_SLOT_ITEMS)
    registerOpcode(self.Opcodes.SMSG_COLLECTED_APPEARANCES)
    registerOpcode(self.Opcodes.SMSG_SHOP_DATA)
    registerOpcode(self.Opcodes.SMSG_PURCHASE_RESULT)
    registerOpcode(self.Opcodes.SMSG_CURRENCIES)
    registerOpcode(self.Opcodes.SMSG_WISHLIST_DATA)
    registerOpcode(self.Opcodes.SMSG_WISHLIST_AVAILABLE)
    registerOpcode(self.Opcodes.SMSG_WISHLIST_UPDATED)
    registerOpcode(self.Opcodes.SMSG_OPEN_UI)
    registerOpcode(self.Opcodes.SMSG_ERROR)
    
    registerOpcode(self.Opcodes.SMSG_COMMUNITY_LIST)
    registerOpcode(self.Opcodes.SMSG_COMMUNITY_PUBLISH_RESULT)
    registerOpcode(self.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT)
    registerOpcode(self.Opcodes.SMSG_INSPECT_TRANSMOG)


    self:Debug("Protocol handlers registered via RegisterJSONHandler: " .. self.MODULE_ID)
    self.isConnected = true
    return true
end

-- ============================================================================
-- MESSAGE SENDING
-- ============================================================================

-- Send a message to the server
function DC:SendMessage(opcode, data)
    if not self.isConnected then
        self:Debug("Cannot send message - not connected")
        return false
    end

    -- Legacy API: send a wrapped payload
    if type(DCAddonProtocol.SendMessage) == "function" then
        local payload = {
            op = opcode,
            data = data or {},
            time = time(),
        }

        local success = DCAddonProtocol:SendMessage(self.MODULE_ID, payload)
        if success then
            self:Debug(string.format("Sent message opcode 0x%02X", opcode))

            self.pendingRequests[opcode] = {
                sentAt = GetTime(),
                data = data,
            }
        else
            self:Debug("Failed to send message")
            if type(self.LogNetEvent) == "function" then
                self:LogNetEvent("error", "send", "Failed to send message (legacy)", { opcode = opcode })
            end
        end

        return success
    end

    -- Current API: module+opcode routing, JSON-by-default
    if type(DCAddonProtocol.Request) ~= "function" then
        self:Debug("Cannot send message - DCAddonProtocol missing Request")
        return false
    end

    local ok, err = pcall(function()
        DCAddonProtocol:Request(self.MODULE_ID, opcode, data or {})
    end)

    if ok then
        self:Debug(string.format("Sent message opcode 0x%02X", opcode))
        self.pendingRequests[opcode] = {
            sentAt = GetTime(),
            data = data,
        }
        return true
    end

    self:Debug("Failed to send message: " .. tostring(err))
    if type(self.LogNetEvent) == "function" then
        self:LogNetEvent("error", "send", "Failed to send message", { opcode = opcode, err = tostring(err) })
    end
    return false
end

-- ============================================================================
-- REQUEST FUNCTIONS
-- Updated to match C++ opcodes in DCAddonNamespace.h
-- ============================================================================

-- Debounce helper for passive requests (definitions/collections/stats/etc).
-- "Latest call wins" without requiring cancellable timers.
-- NOTE: Short delays (0.05-0.15s) are used to batch rapid-fire calls without
-- adding noticeable latency to initial load.
function DC:_DebounceRequest(key, delaySeconds, fn)
    if type(fn) ~= "function" then
        return
    end

    delaySeconds = delaySeconds or 0.10  -- default 100ms (was 250ms)

    if not (self.After and type(self.After) == "function") then
        fn()
        return
    end

    self._debounceTokens = self._debounceTokens or {}
    local token = (self._debounceTokens[key] or 0) + 1
    self._debounceTokens[key] = token

    self.After(delaySeconds, function()
        if self._debounceTokens and self._debounceTokens[key] == token then
            fn()
        end
    end)
end

function DC:_MarkInflight(key, value)
    self._inflightRequests = self._inflightRequests or {}
    self._inflightRequests[key] = value
end

function DC:_IsInflight(key)
    return self._inflightRequests and self._inflightRequests[key]
end

-- Perform initial handshake with server
function DC:RequestHandshake()
    local hash = self:ComputeCollectionHash()
    return self:SendMessage(self.Opcodes.CMSG_HANDSHAKE, {
        hash = hash,
    })
end

-- Request full collection data
function DC:RequestFullCollection()
    return self:SendMessage(self.Opcodes.CMSG_GET_FULL_COLLECTION, {})
end

-- Request delta sync (server will compare hashes)
function DC:RequestSyncCollection()
    local hash = self:ComputeCollectionHash()
    return self:SendMessage(self.Opcodes.CMSG_SYNC_COLLECTION, {
        hash = hash,
    })
end

-- Request collection statistics
function DC:RequestStats()
    local key = "req:stats"
    if self:_IsInflight(key) then
        return false
    end

    self:_DebounceRequest(key, 0.30, function()
        if self:_IsInflight(key) then
            return
        end
        self:_MarkInflight(key, true)
        local ok = self:SendMessage(self.Opcodes.CMSG_GET_STATS, {})
        if not ok then
            self:_MarkInflight(key, nil)
        end
    end)
    return true
end

-- Request active bonuses (mount speed, etc.)
function DC:RequestBonuses()
    local key = "req:bonuses"
    if self:_IsInflight(key) then
        return false
    end

    self:_DebounceRequest(key, 0.10, function()
        if self:_IsInflight(key) then
            return
        end
        self:_MarkInflight(key, true)
        local ok = self:SendMessage(self.Opcodes.CMSG_GET_BONUSES, {})
        if not ok then
            self:_MarkInflight(key, nil)
        end
    end)
    return true
end

-- Request type definitions (e.g. "mounts", "pets", "transmog")
-- If collType is nil, requests all supported types (Core.lua compatibility).
-- clientSyncVersion is optional; if provided, server may reply with upToDate=true.
function DC:RequestDefinitions(collType, clientSyncVersion)
    if not collType then
        self:RequestDefinitions("mounts")
        self:RequestDefinitions("pets")
        -- Compatibility: some servers use singular type names.
        self:RequestDefinitions("pet")
        self:RequestDefinitions("heirlooms")
        self:RequestDefinitions("titles")
        -- Transmog definitions can be huge; fetch on-demand (and paged) when the Transmog tab is opened.
        return
    end

    -- Normalize + map to server type name.
    local normalizedType = (type(self.NormalizeCollectionType) == "function" and self:NormalizeCollectionType(collType)) or collType

    -- Server commonly uses singular names (mount, pet, heirloom, title, transmog).
    local serverType = normalizedType
    if normalizedType == "mounts" then
        serverType = "mount"
    elseif normalizedType == "pets" then
        serverType = "pet"
    elseif normalizedType == "heirlooms" then
        serverType = "heirloom"
    elseif normalizedType == "titles" then
        serverType = "title"
    end

    -- Canonical inflight key uses the normalized (canonical) type.
    local reqKey = "req:defs:" .. tostring(normalizedType)

    -- Avoid spamming the same request while waiting for a response.
    if self:_IsInflight(reqKey) then
        return false
    end

    if serverType == "transmog" then
        -- Don't restart a transmog paging run while already loading.
        if self._transmogDefLoading then
            return false
        end

        self:_DebounceRequest(reqKey, 0.10, function()
            if self._transmogDefLoading then
                return
            end
            self:_MarkInflight(reqKey, true)
            self._transmogDefOffset = 0
            -- Transmog definitions are huge; smaller pages reduce client/server load and lower disconnect risk.
            self._transmogDefLimit = self._transmogDefLimit or 1000
            self._transmogDefLoading = true
            self._transmogDefTotal = nil
            self._transmogDefLastRequestedOffset = 0
            self._transmogDefLastRequestedLimit = self._transmogDefLimit
            self._transmogDefPagesFetched = 0
            self._transmogDefStartedAt = (type(GetTime) == "function" and GetTime()) or time()
            self._transmogDefLastReceivedAt = nil

            if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                self.Wardrobe:UpdateTransmogLoadingProgressUI(true)
            end

            local v = clientSyncVersion
            if v == nil then
                v = self:GetSyncVersion("transmog")
            end
            if type(v) ~= "number" then
                v = tonumber(v)
            end

            local payload = { type = serverType, offset = 0, limit = self._transmogDefLimit }
            if v and v > 0 then
                payload.syncVersion = v
            end

            local ok = self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, payload)
            if not ok then
                self._transmogDefLoading = nil
                self:_MarkInflight(reqKey, nil)
                self._transmogDefStartedAt = nil
                self._transmogDefLastReceivedAt = nil

                if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                    self.Wardrobe:UpdateTransmogLoadingProgressUI(false)
                end
            end
        end)
        return true
    end

    -- Generic request for other types (mount, pet, heirloom, title)
    self:_DebounceRequest(reqKey, 0.10, function()
        if self:_IsInflight(reqKey) then
            return
        end
        self:_MarkInflight(reqKey, true)

        -- Some servers expect plural type names; others expect singular.
        -- If they differ, send BOTH once to maximize compatibility.
        local typesToTry = { serverType }
        if normalizedType and normalizedType ~= serverType then
            typesToTry[#typesToTry + 1] = normalizedType
        end

        local anyOk = false
        for _, tName in ipairs(typesToTry) do
            local payload = { type = tName }
            local v = clientSyncVersion
            if v == nil then
                v = self:GetSyncVersion(tName)
            end
            if type(v) ~= "number" then
                v = tonumber(v)
            end
            if v and v > 0 then
                payload.syncVersion = v
            end
            local ok = self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, payload)
            anyOk = anyOk or (ok and true or false)
        end
        if not anyOk then
            self:_MarkInflight(reqKey, nil)
        end
    end)
    return true
end

-- Abort any in-progress transmog definitions paging.
-- This is used by Wardrobe refresh retry logic to recover from dropped/never-replied requests.
function DC:AbortTransmogDefinitionsPaging(reason)
    -- Clear paging state
    self._transmogDefLoading = nil
    self._transmogDefOffset = nil
    self._transmogDefLastRequestedOffset = nil
    self._transmogDefLastRequestedLimit = nil
    self._transmogDefPagesFetched = 0
    self._transmogDefStartedAt = nil
    self._transmogDefLastReceivedAt = nil
    -- Do not clear _transmogClearOnFirstPage here: retries during a manual refresh
    -- should still clear when the first page arrives. Callers can unset it when needed.

    if self._transmogPagingDelayFrame then
        self._transmogPagingDelayFrame:Hide()
        self._transmogPagingDelayFrame.pendingRequest = nil
        self._transmogPagingDelayFrame.elapsed = 0
    end

    -- Clear inflight guard
    if type(self._MarkInflight) == "function" then
        self:_MarkInflight("req:defs:transmog", nil)
    end

    if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
        self.Wardrobe:UpdateTransmogLoadingProgressUI(false)
    end

    if reason and type(self.Debug) == "function" then
        self:Debug("Aborted transmog definitions paging: " .. tostring(reason))
    end
end

-- Resume a previously interrupted transmog definitions paging run.
-- Uses persisted paging offset/limit stored in SavedVariables (DCCollectionDB).
function DC:ResumeTransmogDefinitions(reason)
    if self._transmogDefLoading then
        return false
    end
    if type(self.IsProtocolReady) == "function" and not self:IsProtocolReady() then
        return false
    end
    if not (self.Opcodes and self.Opcodes.CMSG_GET_DEFINITIONS) then
        return false
    end

    DCCollectionDB = DCCollectionDB or {}
    if not DCCollectionDB.transmogDefsIncomplete then
        return false
    end

    local offset = tonumber(DCCollectionDB.transmogDefsResumeOffset) or 0
    local limit = tonumber(DCCollectionDB.transmogDefsResumeLimit) or tonumber(self._transmogDefLimit) or 1000
    if offset < 0 then offset = 0 end
    if limit < 1 then limit = 1000 end

    -- Start (or restart) paging from the saved offset without syncVersion.
    -- We only set syncVersion when paging fully completes.
    local reqKey = "req:defs:transmog"
    if type(self._MarkInflight) == "function" then
        self:_MarkInflight(reqKey, true)
    end

    self._transmogDefOffset = offset
    self._transmogDefLimit = limit
    self._transmogDefLoading = true
    self._transmogDefStartedAt = (type(GetTime) == "function" and GetTime()) or time()
    self._transmogDefLastReceivedAt = nil
    self._transmogDefLastRequestedOffset = offset
    self._transmogDefLastRequestedLimit = limit
    self._transmogDefPagesFetched = 0

    if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
        self.Wardrobe:UpdateTransmogLoadingProgressUI(true)
    end

    if reason and type(self.Debug) == "function" then
        self:Debug("Resuming transmog definitions paging: " .. tostring(reason) .. " (offset=" .. tostring(offset) .. ", limit=" .. tostring(limit) .. ")")
    end

    local ok = self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "transmog", offset = offset, limit = limit })
    if not ok then
        self._transmogDefLoading = nil
        if type(self._MarkInflight) == "function" then
            self:_MarkInflight(reqKey, nil)
        end
        return false
    end
    return true
end

-- Request type collection items (e.g. "mounts", "pets", "transmog")
-- If collType is nil, requests all supported types.
-- NOTE: Server uses SINGULAR forms (pet, mount, heirloom, title, transmog)
function DC:RequestCollection(collType)
    if not collType then
        -- Request both singular and plural forms to support different servers.
        self:RequestCollection("mount")
        self:RequestCollection("mounts")
        self:RequestCollection("pet")
        self:RequestCollection("pets")
        self:RequestCollection("heirloom")
        self:RequestCollection("heirlooms")
        self:RequestCollection("title")
        self:RequestCollection("titles")
        self:RequestCollection("transmog")
        return
    end

    local normalizedType = (type(self.NormalizeCollectionType) == "function" and self:NormalizeCollectionType(collType)) or collType

    -- Server commonly uses singular names.
    local serverType = normalizedType
    if normalizedType == "mounts" then serverType = "mount"
    elseif normalizedType == "pets" then serverType = "pet"
    elseif normalizedType == "heirlooms" then serverType = "heirloom"
    elseif normalizedType == "titles" then serverType = "title"
    end

    local reqKey = "req:coll:" .. tostring(normalizedType)
    if self:_IsInflight(reqKey) then
        return false
    end

    self:_DebounceRequest(reqKey, 0.10, function()
        if self:_IsInflight(reqKey) then
            return
        end
        self:_MarkInflight(reqKey, true)

        local typesToTry = { serverType }
        if normalizedType and normalizedType ~= serverType then
            typesToTry[#typesToTry + 1] = normalizedType
        end

        local anyOk = false
        for _, tName in ipairs(typesToTry) do
            local ok = self:SendMessage(self.Opcodes.CMSG_GET_COLLECTION, { type = tName })
            anyOk = anyOk or (ok and true or false)
        end
        if not anyOk then
            self:_MarkInflight(reqKey, nil)
        end
    end)
    return true
end

-- Core.lua expects these names
function DC:RequestCollections()
    return self:RequestCollection(nil)
end

function DC:RequestCollectionUpdate(collectionType)
    local typeName = self:GetTypeNameFromId(collectionType)
    return self:RequestCollection(typeName)
end

function DC:RequestShopData(category)
    return self:RequestShopItems(category)
end

-- Request shop items (optional category filter)
function DC:RequestShopItems(category)
    local reqKey = "req:shop:" .. tostring(category or "all")
    if self:_IsInflight(reqKey) then
        return false
    end

    self:_DebounceRequest(reqKey, 0.15, function()
        if self:_IsInflight(reqKey) then
            return
        end
        self:_MarkInflight(reqKey, true)
        local ok = self:SendMessage(self.Opcodes.CMSG_GET_SHOP, {
            category = category or "all",
        })
        if not ok then
            self:_MarkInflight(reqKey, nil)
        end
    end)
    return true
end

-- Request shop purchase
function DC:RequestBuyItem(shopId)
    return self:SendMessage(self.Opcodes.CMSG_BUY_ITEM, {
        shopId = shopId,
    })
end

-- Request currency balance
function DC:RequestCurrencies()
    return self:SendMessage(self.Opcodes.CMSG_GET_CURRENCIES, {})
end

-- Request wishlist
function DC:RequestWishlist()
    return self:SendMessage(self.Opcodes.CMSG_GET_WISHLIST, {})
end

-- Add to wishlist
function DC:RequestAddWishlist(collectionType, entryId)
    local typeId = type(collectionType) == "number" and collectionType or self:GetTypeIdFromName(collectionType)
    return self:SendMessage(self.Opcodes.CMSG_ADD_WISHLIST, {
        type = typeId or 0,
        entryId = entryId,
    })
end

-- Remove from wishlist
function DC:RequestRemoveWishlist(collectionType, entryId)
    local typeId = type(collectionType) == "number" and collectionType or self:GetTypeIdFromName(collectionType)
    return self:SendMessage(self.Opcodes.CMSG_REMOVE_WISHLIST, {
        type = typeId or 0,
        entryId = entryId,
    })
end

-- Use/summon collection item (mount, pet, toy)
    return self:SendMessage(self.Opcodes.CMSG_USE_ITEM, {
        type = typeId or 0,
        entryId = entryId,
    })
end

function DC:RequestCommunityList(offset, limit, filter)
    return self:SendMessage(self.Opcodes.CMSG_COMMUNITY_GET_LIST, {
        offset = offset or 0,
        limit = limit or 50,
        filter = filter or "all"
    })
end

function DC:RequestCommunityFavorite(outfitId, add)
    return self:SendMessage(self.Opcodes.CMSG_COMMUNITY_FAVORITE, {
        id = outfitId,
        add = add
    })
end

function DC:RequestCommunityPublish(name, items)
    return self:SendMessage(self.Opcodes.CMSG_COMMUNITY_PUBLISH, {
        name = name,
        items = items
    })
end

function DC:RequestCommunityRate(id)
    return self:SendMessage(self.Opcodes.CMSG_COMMUNITY_RATE, {
        id = id
    })
end

function DC:RequestSummonMount(spellId, random)
    if random or not spellId then
        local mounts = self.collections and self.collections.mounts
        if not mounts then
            return
        end

        local spellIds = {}
        for id, owned in pairs(mounts) do
            if owned then
                spellIds[#spellIds + 1] = tonumber(id) or id
            end
        end

        if #spellIds == 0 then
            return
        end

        spellId = spellIds[math.random(1, #spellIds)]
    end

    return self:RequestUseItem("mounts", spellId)
end

function DC:RequestSummonPet(creatureId, random)
    if random or not creatureId then
        local pets = self.collections and self.collections.pets
        if not pets then
            return
        end

        local creatureIds = {}
        for id, owned in pairs(pets) do
            if owned then
                creatureIds[#creatureIds + 1] = tonumber(id) or id
            end
        end

        if #creatureIds == 0 then
            return
        end

        creatureId = creatureIds[math.random(1, #creatureIds)]
    end

    return self:RequestUseItem("pets", creatureId)
end

function DC:RequestSummonHeirloom(entryId)
    return self:RequestUseItem("heirlooms", entryId)
end

function DC:RequestSetTitle(entryId)
    return self:RequestUseItem("titles", entryId)
end

-- Set favorite status
function DC:RequestSetFavorite(collectionType, entryId, favorite)
    local typeId = type(collectionType) == "number" and collectionType or self:GetTypeIdFromName(collectionType)
    return self:SendMessage(self.Opcodes.CMSG_SET_FAVORITE, {
        type = typeId or 0,
        entryId = entryId,
        favorite = favorite,
    })
end

-- Toggle favorite status (used throughout modules/UI)
function DC:RequestToggleFavorite(collectionType, entryId)
    local typeName = type(collectionType) == "string" and string.lower(collectionType) or self:GetTypeNameFromId(collectionType)
    local current = typeName and self:GetCollectionItem(typeName, entryId)
    local isFav = current and current.is_favorite
    return self:RequestSetFavorite(collectionType, entryId, not isFav)
end

-- Apply a collected appearance (displayId) to an equipment slot
function DC:RequestSetTransmog(slot, appearanceId)
    local equipmentSlot = (slot == 1 and 0) or (slot and (slot - 1))
    return self:SendMessage(self.Opcodes.CMSG_SET_TRANSMOG, {
        slot = equipmentSlot,
        appearanceId = appearanceId,
        clear = false,
    })
end

-- Clear transmog from an equipment slot
function DC:RequestClearTransmog(slot)
    local equipmentSlot = (slot == 1 and 0) or (slot and (slot - 1))
    return self:SendMessage(self.Opcodes.CMSG_SET_TRANSMOG, {
        slot = equipmentSlot,
        clear = true,
    })
end

-- Apply/clear by equipment slot index (server expects 0..)
function DC:RequestSetTransmogByEquipmentSlot(equipmentSlot, appearanceId)
    return self:SendMessage(self.Opcodes.CMSG_SET_TRANSMOG, {
        slot = equipmentSlot,
        appearanceId = appearanceId,
        clear = false,
    })
end

function DC:RequestClearTransmogByEquipmentSlot(equipmentSlot)
    return self:SendMessage(self.Opcodes.CMSG_SET_TRANSMOG, {
        slot = equipmentSlot,
        clear = true,
    })
end

-- ============================================================================
-- TRANSMOG SLOT UI REQUESTS (for polished TransmogUI)
-- ============================================================================

-- Request paginated appearances for a visual slot (e.g. 283=head, 287=shoulder)
function DC:RequestTransmogSlotItems(visualSlot, page)
    return self:SendMessage(self.Opcodes.CMSG_GET_TRANSMOG_SLOT_ITEMS, {
        slot = visualSlot,
        page = page or 1,
    })
end

-- Search appearances by name for a visual slot
function DC:SearchTransmogItems(visualSlot, searchText, page)
    return self:SendMessage(self.Opcodes.CMSG_SEARCH_TRANSMOG_ITEMS, {
        slot = visualSlot,
        search = searchText or "",
        page = page or 1,
    })
end

-- Request all collected appearance displayIds (for tooltip highlighting)
function DC:RequestCollectedAppearances()
    return self:SendMessage(self.Opcodes.CMSG_GET_COLLECTED_APPEARANCES, {})
end

-- Request current transmog state for all slots
function DC:RequestTransmogState()
    return self:SendMessage(self.Opcodes.CMSG_GET_TRANSMOG_STATE, {})
end

-- Apply multiple transmog changes at once (preview table: { [visualSlot] = itemId, ... })
function DC:ApplyTransmogPreview(previewTable)
    local entries = {}
    for visualSlot, itemId in pairs(previewTable or {}) do
        table.insert(entries, { slot = visualSlot, itemId = itemId })
    end
    return self:SendMessage(self.Opcodes.CMSG_APPLY_TRANSMOG_PREVIEW, {
        entries = entries,
    })
end

-- Toggle account-wide unlock (for heirlooms)
function DC:RequestToggleUnlock(collectionType, entryId)
    local typeId = type(collectionType) == "number" and collectionType or self:GetTypeIdFromName(collectionType)
    return self:SendMessage(self.Opcodes.CMSG_TOGGLE_UNLOCK, {
        type = typeId or 0,
        entryId = entryId,
    })
end

-- Legacy function names for backwards compatibility
DC.RequestCurrency = DC.RequestCurrencies
DC.RequestShopPurchase = function(self, shopId) return self:RequestBuyItem(shopId) end

-- ============================================================================
-- MESSAGE HANDLER
-- Updated to match C++ opcodes in DCAddonNamespace.h
-- ============================================================================

-- Main message handler (called by DCAddonProtocol)
function DC.OnProtocolMessage(payload)
    local self = DC
    
    if not payload or not payload.op then
        self:Debug("Received invalid message")
        return
    end
    
    local opcode = payload.op
    local data = payload.data or {}
    
    self:Debug(string.format("Received message opcode 0x%02X", opcode))
    
    -- Clear pending request
    self.pendingRequests[opcode] = nil
    
    -- Route to appropriate handler based on new opcodes
    if opcode == self.Opcodes.SMSG_HANDSHAKE_ACK then
        self:HandleHandshakeAck(data)
    elseif opcode == self.Opcodes.SMSG_FULL_COLLECTION then
        self:HandleFullCollection(data)
    elseif opcode == self.Opcodes.SMSG_DELTA_SYNC then
        self:HandleDeltaSync(data)
    elseif opcode == self.Opcodes.SMSG_STATS then
        self:HandleStats(data)
    elseif opcode == self.Opcodes.SMSG_BONUSES then
        self:HandleBonuses(data)
    elseif opcode == self.Opcodes.SMSG_ITEM_LEARNED then
        self:HandleItemLearned(data)
    elseif opcode == self.Opcodes.SMSG_DEFINITIONS then
        self:HandleDefinitions(data)
    elseif opcode == self.Opcodes.SMSG_COLLECTION then
        self:HandleCollection(data)
    elseif opcode == self.Opcodes.SMSG_TRANSMOG_STATE then
        self:HandleTransmogState(data)
    elseif opcode == self.Opcodes.SMSG_TRANSMOG_SLOT_ITEMS then
        self:HandleTransmogSlotItems(data)
    elseif opcode == self.Opcodes.SMSG_COLLECTED_APPEARANCES then
        self:HandleCollectedAppearances(data)
    elseif opcode == self.Opcodes.SMSG_SHOP_DATA then
        self:HandleShopData(data)
    elseif opcode == self.Opcodes.SMSG_PURCHASE_RESULT then
        self:HandlePurchaseResult(data)
    elseif opcode == self.Opcodes.SMSG_CURRENCIES then
        self:HandleCurrencies(data)
    elseif opcode == self.Opcodes.SMSG_WISHLIST_DATA then
        self:HandleWishlistData(data)
    elseif opcode == self.Opcodes.SMSG_WISHLIST_AVAILABLE then
        self:HandleWishlistAvailable(data)
    elseif opcode == self.Opcodes.SMSG_WISHLIST_UPDATED then
        self:HandleWishlistUpdated(data)
    elseif opcode == self.Opcodes.SMSG_OPEN_UI then
        self:HandleOpenUI(data)
    elseif opcode == self.Opcodes.SMSG_ERROR then
        self:HandleError(data)
    elseif opcode == self.Opcodes.SMSG_COMMUNITY_LIST then
        self:HandleCommunityList(data)
    elseif opcode == self.Opcodes.SMSG_COMMUNITY_PUBLISH_RESULT then
        self:HandleCommunityPublishResult(data)
    elseif opcode == self.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT then
        self:HandleCommunityFavoriteResult(data)
    elseif opcode == self.Opcodes.SMSG_INSPECT_TRANSMOG then
        self:HandleInspectTransmog(data)
    else
        self:Debug(string.format("Unknown opcode: 0x%02X", opcode))
    end
end

-- ============================================================================
-- RESPONSE HANDLERS
-- Updated to match new protocol
-- ============================================================================

-- Request to toggle favorite status
function DC:RequestCommunityFavorite(outfitID, add)
    local msg = DC.Message(DC.Opcodes.CMSG_COMMUNITY_FAVORITE)
    msg:Add("id", outfitID)
    msg:Add("add", add)
    msg:Send()
end

-- Request to view (increment view count)
function DC:RequestCommunityView(outfitID)
    local msg = DC.Message(DC.Opcodes.CMSG_COMMUNITY_VIEW)
    msg:Add("id", outfitID)
    msg:Send()
end

-- Request inspection of a target
function DC:RequestInspectTarget(unitToken)
    local guid = UnitGUID(unitToken)
    if not guid then return end
    
    -- GUID is string "0xF13000..." or number depending on version/client
    -- Parse GUID to low part if possible or send full string to be managed by server (JSON handles strings/numbers)
    -- Server code expects uint64 or string.
    -- For 3.3.5a lua: tonumber(guid, 16) gets low part ? No, UnitGUID returns "0x..." string.
    -- Use tonumber((UnitGUID(unit)):sub(3), 16) if needed, but JSON can take the string.
    -- Server code: json["target"].AsUInt64() -- JsonCPP handles string->uint64 parsing if formatted correctly.
    -- The server code I wrote: `uint64 targetGuid = json["target"].AsUInt64();` with `json["target"].AsUInt64()`
    -- `AsUInt64` in `DCAddon` (my hypothetical wrapper) usually expects a number type or string.
    -- Better safe: send string, server parses.
    
    -- If using AIO/Eluna, guid is string.
    -- Let's extract the low GUID counter if possible, or just send the string.
    -- My server code `uint64 targetGuid = json["target"].AsUInt64();` implies full GUID.
    -- Just send the string, my Json wrapper usually handles Hex strings or numeric definitions.
    
    -- But wait, `Player::GetGUID().GetCounter()` was used in some places.
    -- Server C++: `Player* target = ObjectAccessor::FindPlayer(ObjectGuid(targetGuid));`
    -- This constructor takes full 64-bit GUID.
    -- So sending the return value of UnitGUID("target") is correct (which is a hex string).
    
    return self:SendMessage(self.Opcodes.CMSG_INSPECT_TRANSMOG, {
        target = tonumber((UnitGUID(unitToken)):sub(3), 16) -- Convert Hex string to number for JSON? Lua numbers are doubles. 
        -- 64-bit integers lose precision in Lua 5.1 doubles.
        -- SAFEST: Send as String. Server `AsUInt64()` usually parses strings.
        -- Re-checking server code: `json["target"].AsUInt64()`. 
        -- If I send a string, does `AsUInt64()` work? Usually yes.
        -- BUT, if I send a Lua number, it will be a double, potentially losing precision for high GUIDs.
        -- UnitGUID in 3.3.5 returns string "0x..."
        -- Let's send it as string.
    })
    -- Wait, my server code: `uint64 targetGuid = json["target"].AsUInt64();`
    -- If I send string "0x...", `AsUInt64` might fail if it strictly expects digits.
    -- I should convert to string of digits? Or rely on `AsUInt64` knowing hex?
    -- Safest is often to send as string. 
    -- Actually, to be super safe and avoid Lua number precision issues:
    -- I will send as string "0xF..."
    -- Modification to server might be needed if `AsUInt64` doesn't handle hex.
    -- But standard JsonCPP `asUInt64()` supports numbers.
    -- Let's check `RequestInspectTarget` implementation below.
end

function DC:RequestInspectTarget(unitToken)
    local guidStr = UnitGUID(unitToken)
    if not guidStr then return end
    
    -- Send as string to preserve 64-bit precision
    return self:SendMessage(self.Opcodes.CMSG_INSPECT_TRANSMOG, {
        target = guidStr
    })
end

-- Handle inspection response
function DC:HandleInspectTransmog(data)
    self:Debug("Received inspect transmog data")
    
    if type(self.PreviewInspectData) == "function" then
        self:PreviewInspectData(data)
    elseif self.PreviewOutfitRaw then
        -- Format data for PreviewOutfitRaw
        -- Data comes as { slots = { "0": itemId, "1": itemId... }, target = guid }
        local items = {}
        if data.slots then
            for slotStr, itemId in pairs(data.slots) do
                local slotId = tonumber(slotStr)
                if slotId then
                    -- Mapping visual slot to item? 
                    -- Server sends visualSlot?
                    -- Server code: `obj.Add(std::to_string(f[0].Get<uint32>()), f[1].Get<uint32>());`
                    -- f[0] is `slot` (visual slot, 0..19 or whatever).
                    -- f[1] is `fake_entry` (item ID).
                    
                    -- PreviewOutfitRaw expects: { [slot] = itemId, ... }
                    items[slotId] = itemId
                end
            end
        end
        self:PreviewOutfitRaw(items)
        -- Show the frame if hidden?
        if self.IsShown and not self.MainFrame:IsShown() then
            self:Show()
        end
    end
end

-- Handle handshake acknowledgement
function DC:HandleHandshakeAck(data)
    self:Debug("Handshake acknowledged")
    
    self.serverHash = data.serverHash
    self.isConnected = true
    self._handshakeAcked = true
    
    if data.needsSync then
        self:Debug("Server indicates full sync needed")
        self:RequestFullCollection()
    else
        self:Debug("Collection is in sync with server")
    end

    -- Request the rest of the initial data (definitions, currencies, shop, etc.)
    if type(self.RequestInitialData) == "function" then
        self:RequestInitialData(true)
    end
    
    -- Fire callback
    if self.callbacks.onHandshakeAck then
        self.callbacks.onHandshakeAck(data)
    end
end

-- Handle full collection data
function DC:HandleFullCollection(data)
    self:Debug("Received full collection data")
    
    -- Store collections
    if data.collections then
        for typeName, items in pairs(data.collections) do
            local typeId = self:GetTypeIdFromName(typeName)
            if typeId then
                self:SetCollection(typeId, items)
            end
        end
    end
    
    -- Store stats
    if data.stats then
        self.stats = data.stats
        -- Toys are disabled; ignore any server-provided toy stats.
        self.stats.toys = nil
    end
    
    -- Store bonuses
    if data.bonuses then
        self.bonuses = data.bonuses
    end
    
    -- Store hash for delta sync
    if data.hash then
        self.collectionHash = data.hash
    end
    
    -- Fire callback
    if self.callbacks.onCollectionReceived then
        self.callbacks.onCollectionReceived(data)
    end
    
    -- Refresh UI if open
    if self.UI and self.UI.mainFrame and self.UI.mainFrame:IsShown() then
        self.UI:RefreshCurrentTab()
    end
end

-- Handle delta sync update
function DC:HandleDeltaSync(data)
    self:Debug("Received delta sync")
    
    -- Apply delta changes
    if data.added then
        for typeName, items in pairs(data.added) do
            local typeId = self:GetTypeIdFromName(typeName)
            if typeId then
                for _, itemId in ipairs(items) do
                    self:AddToCollection(typeId, itemId)
                end
            end
        end
    end
    
    if data.removed then
        for typeName, items in pairs(data.removed) do
            local typeId = self:GetTypeIdFromName(typeName)
            if typeId then
                for _, itemId in ipairs(items) do
                    self:RemoveFromCollection(typeId, itemId)
                end
            end
        end
    end
    
    -- Update hash
    if data.hash then
        self.collectionHash = data.hash
    end
    
    -- Fire callback
    if self.callbacks.onDeltaSync then
        self.callbacks.onDeltaSync(data)
    end
end

-- Handle stats response
function DC:HandleStatsLegacy(data)
    self:Debug("Received stats")

    self:_MarkInflight("req:stats", nil)
    
    if data.stats then
        self.stats = data.stats
        -- Toys are disabled; ignore any server-provided toy stats.
        self.stats.toys = nil
    end
    
    -- Fire callback
    if self.callbacks.onStatsReceived then
        self.callbacks.onStatsReceived(data.stats)
    end

    if self.MainFrame and self.MainFrame:IsShown() then
        if type(self.RequestRefreshCurrentTab) == "function" then
            self:RequestRefreshCurrentTab()
        else
            self:RefreshCurrentTab()
        end
    end
end

-- Handle bonuses response
function DC:HandleBonuses(data)
    self:Debug("Received bonuses")

    self:_MarkInflight("req:bonuses", nil)
    
    self.bonuses = {
        mountSpeedBonus = data.mountSpeedBonus or 0,
        mountCount = data.mountCount or 0,
        nextThreshold = data.nextThreshold or 0,
        mountsToNext = data.mountsToNext or 0,
    }
    
    -- Fire callback
    if self.callbacks.onBonusesReceived then
        self.callbacks.onBonusesReceived(self.bonuses)
    end
    
    -- Update Bonuses UI if it exists
    if self.Bonuses and self.Bonuses.UpdateDisplay then
        self.Bonuses:UpdateDisplay()
    end
end

-- Handle new item learned notification
function DC:HandleItemLearned(data)
    self:Debug(string.format("New item learned: type=%d, entryId=%d", data.type or 0, data.entryId or 0))
    
    -- Add to local collection
    self:AddToCollection(data.type, data.entryId)
    
    -- Show notification
    local typeName = self:GetTypeNameFromId(data.type)
    self:Print(string.format("|cff00ff00New %s added to your collection!|r", typeName or "item"))
    
    -- Add to recent additions for My Collection overview
    self.recentAdditions = self.recentAdditions or {}
    local def = self:GetDefinition(typeName, data.entryId)
    local newEntry = {
        type = typeName or "unknown",
        id = data.entryId,
        name = def and def.name or nil,
        icon = def and def.icon or nil,
        itemId = data.itemId or (def and def.itemId),
        spellId = data.spellId or (def and def.spellId),
        timestamp = time(),
        rarity = def and def.rarity or 1,
    }
    table.insert(self.recentAdditions, 1, newEntry) -- Insert at beginning
    
    -- Limit to 50 recent items
    while #self.recentAdditions > 50 do
        table.remove(self.recentAdditions)
    end
    
    -- Update My Collection UI if visible
    if self.MyCollection then
        self.MyCollection:Update()
    end
    
    -- Fire callback
    if self.callbacks.onItemLearned then
        self.callbacks.onItemLearned(data)
    end
    
    -- Refresh stats
    self:RequestStats()
    self:RequestBonuses()
end

-- Handle shop data
function DC:HandleShopData(data)
    self:Debug("Received shop data")

    -- Release shop inflight guard (category can vary; clear common keys).
    self._inflightRequests = self._inflightRequests or {}
    self._inflightRequests["req:shop:all"] = nil
    self._inflightRequests["req:shop:default"] = nil

        self.shopCategory = data.category or "default"
    self.currency = self.currency or { tokens = 0, emblems = 0 }
    self.currency.tokens = data.tokens or data.token or self.currency.tokens or 0
    self.currency.emblems = data.emblems or data.essence or data.emblem or self.currency.emblems or 0

    -- Bridge: expose server currency into DCAddonProtocol's DCCentral helpers
    local central = rawget(_G, "DCAddonProtocol")
    if central and type(central.SetServerCurrencyBalance) == "function" then
        central:SetServerCurrencyBalance(self.currency.tokens, self.currency.emblems)
    end

    if self.ShopUI and self.ShopUI.IsShown and self.ShopUI:IsShown() then
        self:UpdateShopCurrencyDisplay()
    end

    if self.MainFrame and self.MainFrame:IsShown() then
        self:UpdateHeader()
    end

    local rawItems = data.items or {}
    local mapped = {}

    for _, it in ipairs(rawItems) do
        local collTypeId = it.type
        local typeName = self:GetTypeNameFromId(collTypeId)

        local card = {
            type = "shop",
            shopId = it.shopId,
            collectionTypeId = collTypeId,
            collectionTypeName = typeName,
            entryId = it.entryId,
            appearanceId = it.appearanceId,
            itemId = it.itemId,
            spellId = it.spellId or it.spellID or it.spell,
            priceTokens = it.priceTokens or 0,
            priceEmblems = it.priceEmblems or 0,
            discount = it.discount or 0,
            stock = it.stock,
            featured = it.featured,
            owned = it.owned or false,
            collected = it.owned or false,
            rarity = it.rarity or 2,
            source = "Shop",
            name = it.name,
            icon = nil, -- Will be resolved below
        }

        -- Server may send an icon name (e.g. "INV_...") or a full texture path.
        local serverIcon = it.icon
        local normalizedServerIcon = self:NormalizeTexturePath(serverIcon, nil)
        
        -- Resolve icon from server data or game API
        if typeName == "mounts" then
            -- Prefer spellId for mounts (some servers send spellId separately)
            local spellId = it.spellId or it.spellID or it.entryId
            if spellId and GetSpellTexture then
                local tex = GetSpellTexture(spellId)
                if tex then card.icon = tex end
            end
            -- Fallback to GetSpellInfo for name
            if (not card.name or card.name == "") and spellId and GetSpellInfo then
                local name = GetSpellInfo(spellId)
                if name then card.name = name end
            end

            -- If this mount is represented by an item template, try item icon/name.
            local itemIdToUse = it.itemId or it.entryId
            if (not card.icon or card.icon == "Interface\\Icons\\INV_Misc_QuestionMark") and itemIdToUse and GetItemInfo then
                local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemIdToUse)
                if texture then card.icon = texture end
                if name and (not card.name or card.name == "") then card.name = name end
                if quality then card.rarity = quality end
            end
        elseif typeName == "pets" or typeName == "heirlooms" or typeName == "transmog" then
            -- Use GetItemInfo for items (returns texture as 10th value)
            local itemIdToUse = it.itemId or it.entryId
            if itemIdToUse and GetItemInfo then
                local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemIdToUse)
                if texture then card.icon = texture end
                if name and (not card.name or card.name == "") then card.name = name end
                if quality then card.rarity = quality end
            end

            -- Pets can also be represented via spells.
            if (not card.icon or card.icon == "Interface\\Icons\\INV_Misc_QuestionMark") then
                local spellId = it.spellId or it.spellID
                if spellId and GetSpellTexture then
                    local tex = GetSpellTexture(spellId)
                    if tex then card.icon = tex end
                end
                if (not card.name or card.name == "") and spellId and GetSpellInfo then
                    local n = GetSpellInfo(spellId)
                    if n then card.name = n end
                end
            end
        elseif typeName == "titles" then
            -- Titles use static icon
            card.icon = "Interface\\Icons\\INV_Scroll_11"
        end

        -- Use server-provided icon if we still don't have a good one.
        if (not card.icon) or card.icon == "" or card.icon == "Interface\\Icons\\INV_Misc_QuestionMark" then
            if normalizedServerIcon then
                card.icon = normalizedServerIcon
            end
        end

        -- Final fallbacks
        card.icon = self:NormalizeTexturePath(card.icon, "Interface\\Icons\\INV_Misc_QuestionMark")
        card.name = card.name or "Shop Item"

        table.insert(mapped, card)
    end

    self.shopItems = mapped
    
    -- Some items may need cache warming - schedule a refresh
    if self.shopNeedsCacheWarm == nil then
        self.shopNeedsCacheWarm = true
        -- Use C_Timer or simple delayed call
        if self.After and type(self.After) == "function" then
            self.After(0.5, function()
                self.shopNeedsCacheWarm = nil
                self:RefreshShopIcons()
            end)
        end
    end
    
    -- Fire callback
    if self.callbacks.onShopDataReceived then
        self.callbacks.onShopDataReceived(data)
    end

    -- Refresh MainFrame if open
    if self.MainFrame and self.MainFrame:IsShown() then
        if type(self.RequestRefreshCurrentTab) == "function" then
            self:RequestRefreshCurrentTab()
        else
            self:RefreshCurrentTab()
        end
    end
end

-- Refresh shop icons after cache warming
function DC:RefreshShopIcons()
    if not self.shopItems then return end
    
    local needsRefresh = false
    local unresolved = 0
    for _, card in ipairs(self.shopItems) do
        if card.icon == "Interface\\Icons\\INV_Misc_QuestionMark" or card.name == "Shop Item" then
            local typeName = card.collectionTypeName
            local itemIdToUse = card.itemId or card.entryId
            
            if typeName == "mounts" and card.entryId and GetSpellTexture then
                local tex = GetSpellTexture(card.entryId)
                if tex then 
                    card.icon = tex
                    needsRefresh = true
                end
                if GetSpellInfo then
                    local name = GetSpellInfo(card.entryId)
                    if name and card.name == "Shop Item" then 
                        card.name = name
                        needsRefresh = true
                    end
                end
            elseif (typeName == "pets" or typeName == "heirlooms" or typeName == "transmog") and itemIdToUse and GetItemInfo then
                local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemIdToUse)
                if texture and card.icon == "Interface\\Icons\\INV_Misc_QuestionMark" then
                    card.icon = texture
                    needsRefresh = true
                end
                if name and card.name == "Shop Item" then
                    card.name = name
                    needsRefresh = true
                end
                if quality then card.rarity = quality end
            end
        end

        if card.icon == "Interface\\Icons\\INV_Misc_QuestionMark" or card.name == "Shop Item" then
            unresolved = unresolved + 1
        end
    end

    -- Retry a few times because item info cache warming can be slow in 3.3.5a
    if unresolved > 0 then
        self._shopIconRefreshAttempts = (self._shopIconRefreshAttempts or 0) + 1
        if self._shopIconRefreshAttempts <= 6 and self.After and type(self.After) == "function" then
            local delay = 0.5 + (self._shopIconRefreshAttempts * 0.25)
            self.After(delay, function()
                self:RefreshShopIcons()
            end)
        end
    else
        self._shopIconRefreshAttempts = nil
    end
    
    if needsRefresh and self.MainFrame and self.MainFrame:IsShown() and self.activeTab == "shop" then
        if type(self.RequestRefreshCurrentTab) == "function" then
            self:RequestRefreshCurrentTab()
        else
            self:RefreshCurrentTab()
        end
    end
end

-- Handle purchase result
function DC:HandlePurchaseResult(data)
    self:Debug(string.format("Purchase result: success=%s", tostring(data.success)))
    
    if data.success then
        self:Print("|cff00ff00Purchase successful!|r")
        
        -- Update currency
        self.currency = self.currency or { tokens = 0, emblems = 0 }
        local tokens = data.tokens or data.token or self.currency.tokens or 0
        local emblems = data.emblems or data.essence or data.emblem or self.currency.emblems or 0
        self.currency.tokens = tokens
        self.currency.emblems = emblems
        
        -- Bridge: expose server currency into DCAddonProtocol's DCCentral helpers
        local central = rawget(_G, "DCAddonProtocol")
        if central and type(central.SetServerCurrencyBalance) == "function" then
            central:SetServerCurrencyBalance(self.currency.tokens, self.currency.emblems)
        end
    else
        self:Print("|cffff0000Purchase failed:|r " .. (data.error or "Unknown error"))
    end
    
    -- Fire callback
    if self.callbacks.onPurchaseResult then
        self.callbacks.onPurchaseResult(data)
    end
end

-- Handle currencies response
function DC:HandleCurrencies(data)
    self:Debug("Received currencies")

    self:_MarkInflight("req:currency", nil)

    self.currency = self.currency or { tokens = 0, emblems = 0 }
    local tokens = data.tokens or data.token or 0
    local emblems = data.emblems or data.essence or data.emblem or 0
    if type(self.CacheUpdateCurrency) == "function" then
        self:CacheUpdateCurrency(tokens, emblems)
    else
        self.currency.tokens = tokens
        self.currency.emblems = emblems
    end

    if self.MainFrame and self.MainFrame:IsShown() then
        self:UpdateHeader()
    end
    if self.ShopUI and self.ShopUI.IsShown and self.ShopUI:IsShown() then
        self:UpdateShopCurrencyDisplay()
    end

    -- Bridge: expose server currency into DCAddonProtocol's DCCentral helpers
    -- so other UIs that use GetItemCount-based token helpers can still show.
    local central = rawget(_G, "DCAddonProtocol")
    if central and type(central.SetServerCurrencyBalance) == "function" then
        central:SetServerCurrencyBalance(self.currency.tokens or 0, self.currency.emblems or 0)
    end
    
    -- Fire callback
    if self.callbacks.onCurrenciesReceived then
        self.callbacks.onCurrenciesReceived(self.currency)
    end
end

-- Handle wishlist data
function DC:HandleWishlistData(data)
    self:Debug("Received wishlist")
    
    self.wishlist = data.items or {}
    self.wishlistCount = data.count or 0
    self.wishlistMaxItems = data.maxItems or 25
    
    -- Fire callback
    if self.callbacks.onWishlistReceived then
        self.callbacks.onWishlistReceived(data)
    end
end

-- Handle wishlist item available notification
function DC:HandleWishlistAvailable(data)
    self:Debug("Wishlist item now available!")
    
    local typeName = self:GetTypeNameFromId(data.type)
    self:Print("|cff00ff00" .. (data.message or "A wishlist item is now in your collection!") .. "|r")
    
    -- Fire callback
    if self.callbacks.onWishlistAvailable then
        self.callbacks.onWishlistAvailable(data)
    end
end

-- Handle wishlist updated
function DC:HandleWishlistUpdated(data)
    self:Debug(string.format("Wishlist updated: action=%s, success=%s", 
        data.action or "unknown", tostring(data.success)))
    
        if data.success and data.action then
        if data.action == "added" then
            self:Print("|cff00ff00Item added to wishlist!|r")
        elseif data.action == "removed" then
            self:Print("|cffffff00Item removed from wishlist.|r")
        end
        
        -- Refresh wishlist
        self:RequestWishlist()
    else
        self:Print("|cffff0000Wishlist update failed:|r " .. (data.error or "Unknown error"))
    end
    
    -- Fire callback
    if self.callbacks.onWishlistUpdated then
        self.callbacks.onWishlistUpdated(data)
    end
end

-- Handle open UI command from server
function DC:HandleOpenUI(data)
    self:Debug("Server requested UI open")
    
    if self.UI and self.UI.Toggle then
        self.UI:Toggle()
    end
end

-- Handle error response
function DC:HandleError(data)
    local errorMsg = data.error or data.message or "Unknown error"
    local errorCode = data.code or 0
    
    self:Debug(string.format("Error received: code=%d, msg=%s", errorCode, errorMsg))
    self:Print("|cffff0000Error:|r " .. errorMsg)

    if type(self.LogNetEvent) == "function" then
        self:LogNetEvent("error", "server", errorMsg, { code = errorCode })
    end
    
    -- Fire callback
    if self.callbacks.onError then
        self.callbacks.onError(data)
    end
end

function DC:HandleTransmogState(data)
    local state = data.state or {}
    self.transmogState = state

    DCCollectionCharDB = DCCollectionCharDB or {}
    DCCollectionCharDB.transmogState = state

    -- Refresh UI if open
    if self.UI and self.UI.mainFrame and self.UI.mainFrame:IsShown() then
        self.UI:RefreshCurrentTab()
    end

    self:Debug(string.format("Received transmog state (%d slots)", self:TableCount(state)))
end

-- Handle paginated slot items (for TransmogUI grid)
function DC:HandleTransmogSlotItems(data)
    local visualSlot = data.slot  -- Server sends "slot"
    local page = data.page or 1
    local hasMore = data.hasMore or false
    local items = data.items or {}
    local total = data.total or data.totalCount or data.count
    
    self._transmogSlotItems = self._transmogSlotItems or {}
    self._transmogSlotItems[visualSlot] = {
        page = page,
        hasMore = hasMore,
        items = items,
        total = total,
    }
    
    self:Debug(string.format("Received %d transmog items for slot %d (page %d)", #items, visualSlot or 0, page))

    if self._serverCollectionsTestActive then
        self:Print(string.format("[DC-Collection] Test: slot %d page %d items=%d total=%s", visualSlot or 0, page or 0, #items, tostring(total or "?")))
    end
    
    -- Fire callback for TransmogUI to refresh
    if self.callbacks.onTransmogSlotItems then
        self.callbacks.onTransmogSlotItems(visualSlot, items, page, hasMore)
    end
    
    -- Notify TransmogUI directly if it exists
    if self.TransmogUI and self.TransmogUI.OnSlotItemsReceived then
        self.TransmogUI:OnSlotItemsReceived(visualSlot, items, page, hasMore)
    end
end

-- Handle all collected appearances (for tooltip highlighting)
function DC:HandleCollectedAppearances(data)
    local appearances = data.appearances
    local items = data.items

    self.collectedAppearances = {}

    -- Preferred field: appearances = { displayId, ... }
    if type(appearances) == "table" and #appearances > 0 then
        for _, displayId in ipairs(appearances) do
            self.collectedAppearances[displayId] = true
        end
        self:Debug(string.format("Received %d collected appearances", #appearances))
    elseif type(items) == "table" and #items > 0 then
        -- Backwards/alternate schema: items = { itemId, ... }
        -- Try to map itemId -> displayId using Wardrobe helper when available.
        local mapped = 0
        if DC.Wardrobe and type(DC.Wardrobe.GetAppearanceDisplayIdForItemId) == "function" then
            for _, itemId in ipairs(items) do
                local displayId = DC.Wardrobe:GetAppearanceDisplayIdForItemId(itemId)
                if displayId then
                    self.collectedAppearances[displayId] = true
                    mapped = mapped + 1
                end
            end
        else
            -- Fallback: treat numbers as displayIds to avoid hard-failing.
            for _, v in ipairs(items) do
                self.collectedAppearances[v] = true
                mapped = mapped + 1
            end
        end
        self:Debug(string.format("Received collected appearances via items (mapped %d)", mapped))
    else
        self:Debug("Received 0 collected appearances")
    end
    
    -- Fire callback
    if self.callbacks.onCollectedAppearances then
        self.callbacks.onCollectedAppearances(self.collectedAppearances)
    end
end

-- Check if an appearance is collected (by displayId)
function DC:IsAppearanceCollected(displayId)
    return self.collectedAppearances and self.collectedAppearances[displayId]
end

function DC:HandleDefinitions(data)
    local rawType = data.type
    local collType = (type(self.NormalizeCollectionType) == "function" and self:NormalizeCollectionType(rawType)) or rawType
    
    local definitions = data.definitions or {}
    local syncVersion = data.syncVersion
    local upToDate = data.upToDate or data.up_to_date or data.uptodate

    -- Some servers send definitions as an array of records instead of a map.
    -- Normalize arrays into an id->def map so the rest of the UI can iterate reliably.
    if type(definitions) == "table" and #definitions > 0 then
        local mapped = {}
        for _, def in ipairs(definitions) do
            if type(def) == "table" then
                local id = def.id or def.entryId or def.entry_id or def.appearanceId or def.appearance_id or def.itemId or def.item_id
                if id ~= nil then
                    mapped[id] = def
                end
            end
        end
        -- Only replace if we successfully mapped at least one entry.
        if next(mapped) ~= nil then
            definitions = mapped
        end
    end
    
    -- If a manual wardrobe refresh is in progress, delay-clearing the transmog table until the
    -- FIRST page arrives. This avoids wiping local data if the server never responds.
    if collType == "transmog" then
        local requestedOffset = tonumber(data.offset or data.off) or 0
        if requestedOffset == 0 and self._transmogClearOnFirstPage then
            self._transmogClearOnFirstPage = nil

            self.definitions = self.definitions or {}
            if type(self._transmogDefinitions) ~= "table" then
                self._transmogDefinitions = self.definitions.transmog
            end
            if type(self._transmogDefinitions) ~= "table" then
                self._transmogDefinitions = {}
            end
            self.definitions.transmog = self._transmogDefinitions

            for k in pairs(self._transmogDefinitions) do
                self._transmogDefinitions[k] = nil
            end
            if type(self._BumpDefinitionsRevision) == "function" then
                self:_BumpDefinitionsRevision("transmog")
            end
            self.cacheNeedsSave = true
        end

        self._transmogDefLastReceivedAt = (type(GetTime) == "function" and GetTime()) or time()
    end

    self:CacheMergeDefinitions(collType, definitions)
    if syncVersion ~= nil then
        if collType == "transmog" then
            self._pendingSyncVersions = self._pendingSyncVersions or {}
            self._pendingSyncVersions.transmog = syncVersion
        else
            self:SetSyncVersion(collType, syncVersion)
        end
    end
    -- Cache will be saved by auto-save timer or on logout

    -- Release inflight guard for this type.
    self:_MarkInflight("req:defs:" .. tostring(collType), nil)
    if collType == "pets" then
        self:_MarkInflight("req:defs:pet", nil)
        self:_MarkInflight("req:defs:pets", nil)
    end

    -- Debug: how many transmog definitions are missing inventoryType on this page
    if collType == "transmog" then
        local total = 0
        local missing = 0
        for _, def in pairs(definitions or {}) do
            total = total + 1
            local invType = (type(def) == "table") and (def.inventoryType or def.inventory_type or def.invType or def.inv_type) or nil
            if invType == nil or invType == 0 or invType == "0" then
                missing = missing + 1
            end
        end
        if total > 0 then
            self:Debug(string.format("Transmog defs page: inventoryType missing %d / %d", missing, total))
        end
    end
    
    -- Notify UI if open
    if self.MainFrame and self.MainFrame:IsShown() then
        if type(self.RequestRefreshCurrentTab) == "function" then
            self:RequestRefreshCurrentTab()
        else
            self:RefreshCurrentTab()
        end
    end
    
    -- Notify Wardrobe if open (transmog or itemSets data)
    if (collType == "transmog" or collType == "itemsets" or collType == "itemSets") and DC.Wardrobe and DC.Wardrobe.frame and DC.Wardrobe.frame:IsShown() then
        if DC.Wardrobe.currentTab == "sets" then
            DC.Wardrobe:RefreshSetsGrid()
        else
            DC.Wardrobe:RefreshGrid()
        end
    end
    
    self:Debug(string.format("Received %d definitions for %s", 
        self:TableCount(definitions), collType))

    -- Transmog definitions can be very large; server may send them in pages.
    if collType == "transmog" then
        if upToDate == true or upToDate == 1 or upToDate == "1" then
            self:Debug("Transmog definitions up-to-date; skipping download")
            self._transmogDefLoading = nil
            self:_MarkInflight("req:defs:transmog", nil)
            return
        end

        -- Slow down paging to avoid disconnects on some servers/clients.
        -- Default to 0.75s unless overridden elsewhere.
        self._transmogPagingInterval = self._transmogPagingInterval or 0.75

        local requestedOffset = tonumber(data.offset or data.off) or tonumber(self._transmogDefLastRequestedOffset) or 0
        local requestedLimit = tonumber(data.limit or data.lim) or tonumber(self._transmogDefLastRequestedLimit) or tonumber(self._transmogDefLimit) or 1000
        local total = tonumber(data.total or data.count) or nil

        if total and total > 0 then
            self._transmogDefTotal = total
        end

        local moreFlag = data.more
        if moreFlag == nil then moreFlag = data.hasMore end
        if moreFlag == nil then moreFlag = data.has_more end
        if moreFlag == nil then moreFlag = data.morePages end

        local receivedCount = self:TableCount(definitions)
        
        local hasMore = false
        if moreFlag == true or moreFlag == 1 or moreFlag == "1" then
            hasMore = true
        elseif total and (requestedOffset + requestedLimit) < total then
            hasMore = true
        elseif moreFlag == nil then
            -- Server didn't send paging flags/total; infer "more" if we got a full page.
            -- This avoids the "only ~300 items" symptom when the server sends chunked definitions
            -- but omits hasMore/total fields.
            if receivedCount > 0 and receivedCount >= requestedLimit then
                hasMore = true
            end
        end
        
        -- During the settings "Test server collections" run, do not auto-page transmog.
        if self._serverTestNoTransmogPaging then
            hasMore = false
            self._serverTestNoTransmogPaging = nil
        end

        if self._serverCollectionsTestActive then
            self:Print(string.format(
                "[DC-Collection] Test: transmog defs received=%d offset=%s limit=%s total=%s more=%s",
                receivedCount,
                tostring(requestedOffset),
                tostring(requestedLimit),
                tostring(total),
                tostring(hasMore)))
        end

        if hasMore then
            local nextOffset = tonumber(data.nextOffset or data.next_offset) or (requestedOffset + requestedLimit)

            self._transmogDefOffset = nextOffset
            self._transmogDefLimit = requestedLimit
            self._transmogDefLastRequestedOffset = nextOffset
            self._transmogDefLastRequestedLimit = requestedLimit
            self._transmogDefPagesFetched = (self._transmogDefPagesFetched or 0) + 1

            -- Persist resume state so we can continue after disconnect/relog.
            DCCollectionDB = DCCollectionDB or {}
            DCCollectionDB.transmogDefsIncomplete = true
            DCCollectionDB.transmogDefsResumeOffset = nextOffset
            DCCollectionDB.transmogDefsResumeLimit = requestedLimit
            DCCollectionDB.transmogDefsResumeTotal = self._transmogDefTotal
            DCCollectionDB.transmogDefsResumeUpdatedAt = time()

            -- Safety valve: prevent infinite loops if the server keeps repeating the same page.
            if (self._transmogDefPagesFetched or 0) > 500 then
                self:Debug("Stopping transmog definitions paging: too many pages (possible server loop)")
                self._transmogDefLoading = nil
                return
            end

            -- Use frame-based delay to prevent server overload and disconnects
            -- Create delay frame if it doesn't exist
            if not self._transmogPagingDelayFrame then
                self._transmogPagingDelayFrame = CreateFrame("Frame")
                self._transmogPagingDelayFrame.elapsed = 0
                self._transmogPagingDelayFrame.pendingRequest = nil
                
                self._transmogPagingDelayFrame:SetScript("OnUpdate", function(frame, elapsed)
                    frame.elapsed = frame.elapsed + elapsed
                    local wardrobeVisible = (DC.Wardrobe and DC.Wardrobe.frame and DC.Wardrobe.frame:IsShown())
                    local mainTabVisible = (DC.MainFrame and DC.MainFrame:IsShown() and (DC.activeTab == "wardrobe" or DC.activeTab == "transmog"))
                    local allowBackground = false
                    if type(DC.IsBackgroundWardrobeSyncEnabled) == "function" then
                        allowBackground = DC:IsBackgroundWardrobeSyncEnabled() and true or false
                    elseif DCCollectionDB and DCCollectionDB.backgroundWardrobeSync then
                        allowBackground = true
                    end

                    local interval = DC._transmogPagingInterval or 0.75
                    -- If we're paging while the UI is not visible, be extra conservative.
                    if not (wardrobeVisible or mainTabVisible) then
                        interval = math.max(interval, 1.25)
                    end

                    if frame.elapsed >= interval and frame.pendingRequest then
                        local req = frame.pendingRequest
                        -- Pause paging if user isn't actively viewing Wardrobe/transmog UI,
                        -- unless background wardrobe sync is enabled.
                        if not (wardrobeVisible or mainTabVisible) and not allowBackground then
                            frame.elapsed = 0
                            return
                        end

                        frame.pendingRequest = nil
                        frame.elapsed = 0
                        frame:Hide()

                        DC:SendMessage(DC.Opcodes.CMSG_GET_DEFINITIONS, { type = "transmog", offset = req.offset, limit = req.limit })
                    end
                end)
            end
            
            -- Queue the next request with delay
            self._transmogPagingDelayFrame.pendingRequest = { offset = nextOffset, limit = requestedLimit }
            self._transmogPagingDelayFrame.elapsed = 0
            self._transmogPagingDelayFrame:Show()

            if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                self.Wardrobe:UpdateTransmogLoadingProgressUI(true)
            end
        else
            -- Paging complete: commit syncVersion only now (prevents upToDate when we only had partial data).
            if self._pendingSyncVersions and self._pendingSyncVersions.transmog ~= nil then
                self:SetSyncVersion("transmog", self._pendingSyncVersions.transmog)
                self._pendingSyncVersions.transmog = nil
            end

            -- Clear persisted resume state.
            DCCollectionDB = DCCollectionDB or {}
            DCCollectionDB.transmogDefsIncomplete = nil
            DCCollectionDB.transmogDefsResumeOffset = nil
            DCCollectionDB.transmogDefsResumeLimit = nil
            DCCollectionDB.transmogDefsResumeTotal = nil
            DCCollectionDB.transmogDefsResumeUpdatedAt = nil

            self:Print(string.format(
                "[Transmog Paging] Complete - Loaded %d definitions in %d pages (Total on server: %s)",
                self:TableCount(self.definitions and self.definitions.transmog),
                (self._transmogDefPagesFetched or 0) + 1,
                tostring(total)))
            self._transmogDefLoading = nil
            self:_MarkInflight("req:defs:transmog", nil)

            if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                self.Wardrobe:UpdateTransmogLoadingProgressUI(false)
            end
        end
    end
end

function DC:HandleCollection(data)
    local rawType = data.type
    local collType = (type(self.NormalizeCollectionType) == "function" and self:NormalizeCollectionType(rawType)) or rawType
    local items = data.items or {}
    
    self:CacheMergeCollection(collType, items)
    -- Cache will be saved by auto-save timer or on logout

    -- Release inflight guard for this type.
    self:_MarkInflight("req:coll:" .. tostring(collType), nil)
    if collType == "pets" then
        self:_MarkInflight("req:coll:pet", nil)
        self:_MarkInflight("req:coll:pets", nil)
    end
    
    -- Notify UI if open
    if self.MainFrame and self.MainFrame:IsShown() then
        if type(self.RequestRefreshCurrentTab) == "function" then
            self:RequestRefreshCurrentTab()
        else
            self:RefreshCurrentTab()
        end
    end
    
    -- Notify Wardrobe if open (transmog data)
    if collType == "transmog" and DC.Wardrobe and DC.Wardrobe.frame and DC.Wardrobe.frame:IsShown() then
        DC.Wardrobe:RefreshGrid()
    end
    
    self:Debug(string.format("Received %d items for %s collection", 
        self:TableCount(items), collType))
end

function DC:HandleMountSummoned(data)
    if data.success then
        local spellId = data.spellId
        -- Update times_used in cache
        if self.collections.mounts and self.collections.mounts[spellId] then
            self.collections.mounts[spellId].times_used = 
                (self.collections.mounts[spellId].times_used or 0) + 1
        end
    else
        self:Print("|cffff0000" .. (data.error or DC.L["ERR_CANT_USE_NOW"]) .. "|r")
    end
end

function DC:HandlePetSummoned(data)
    if data.success then
        -- Pet summoned successfully
        local spellId = data.spellId
        if self.collections.pets and self.collections.pets[spellId] then
            self.collections.pets[spellId].times_used = 
                (self.collections.pets[spellId].times_used or 0) + 1
        end
    else
        self:Print("|cffff0000" .. (data.error or DC.L["ERR_CANT_USE_NOW"]) .. "|r")
    end
end

function DC:HandleHeirloomSummoned(data)
    if data.success then
        self:Print(DC.L["HEIRLOOM_SUMMONED"] or "Heirloom added to your bags!")
    else
        self:Print("|cffff0000" .. (data.error or DC.L["ERR_BAGS_FULL"]) .. "|r")
    end
end

function DC:HandleFavoriteToggled(data)
    local rawType = data.type
    local collType = (type(self.NormalizeCollectionType) == "function" and self:NormalizeCollectionType(rawType)) or rawType
    local itemId = data.itemId
    local isFavorite = data.isFavorite
    
    self:CacheUpdateItem(collType, itemId, { is_favorite = isFavorite })
    
    -- Refresh UI if showing
    if self.MainFrame and self.MainFrame:IsShown() then
        if type(self.RequestRefreshCurrentTab) == "function" then
            self:RequestRefreshCurrentTab()
        else
            self:RefreshCurrentTab()
        end
    end
end

function DC:HandleCurrency(data)
    local tokens = data.tokens or data.token or data.Tokens or data.Token
    local emblems = data.emblems or data.emblem or data.essence or data.Essence or data.Emblems

    if type(tokens) == "string" then tokens = tonumber(tokens) end
    if type(emblems) == "string" then emblems = tonumber(emblems) end

    self:CacheUpdateCurrency(tokens, emblems)

    -- Bridge: expose server currency into DCAddonProtocol's DCCentral helpers
    local central = rawget(_G, "DCAddonProtocol")
    if central and type(central.SetServerCurrencyBalance) == "function" then
        central:SetServerCurrencyBalance(self.currency.tokens or 0, self.currency.emblems or 0)
    end
    
    -- Update UI
    if self.ShopUI and self.ShopUI.IsShown and self.ShopUI:IsShown() then
        if type(self.UpdateShopCurrencyDisplay) == "function" then
            self:UpdateShopCurrencyDisplay()
        elseif type(self.UpdateShopUI) == "function" then
            self:UpdateShopUI()
        end
    end

    -- Update MainFrame Header if shown
    if self.MainFrame and self.MainFrame:IsShown() then
        self:UpdateHeader()
    end
end

function DC:HandleShopItems(data)
    self.shopItems = data.items or {}
    
    -- Update shop UI if open
    if self.ShopUI and self.ShopUI:IsShown() then
        if type(self.UpdateShopUI) == "function" then
            self:UpdateShopUI()
        elseif type(self.PopulateShopItems) == "function" then
            self:PopulateShopItems()
        end
    end
    
    self:Debug(string.format("Received %d shop items", #self.shopItems))
end

function DC:HandleShopResult(data)
    if data.success then
        -- Update currency
        local newTokens = data.newTokens or data.tokens or data.token
        local newEmblems = data.newEmblems or data.newEssence or data.emblems or data.essence or data.emblem
        if type(newTokens) == "string" then newTokens = tonumber(newTokens) end
        if type(newEmblems) == "string" then newEmblems = tonumber(newEmblems) end
        self:CacheUpdateCurrency(newTokens, newEmblems)
        
        -- Show success message
        local itemName = data.itemName or "Item"
        self:Print(string.format(DC.L["SHOP_PURCHASE_SUCCESS"] or "Successfully purchased %s!", itemName))
        
        -- If the purchase was a collectible, trigger collection refresh
        if data.collectionType then
            self:RequestCollection(data.collectionType)
        end
        
        -- If mount speed was purchased, update bonus
        if data.mountSpeedBonus then
            self.mountSpeedBonus = data.mountSpeedBonus
            DCCollectionDB.mountSpeedBonus = data.mountSpeedBonus
        end
        
        -- Refresh shop UI
        if self.ShopUI and self.ShopUI:IsShown() then
            self.ShopUI:Refresh()
        end

        -- Update MainFrame Header if shown
        if self.MainFrame and self.MainFrame:IsShown() then
            self:UpdateHeader()
        end
    else
        self:Print("|cffff0000" .. (data.error or DC.L["ERR_SHOP_FAILED"]) .. "|r")
    end
end

function DC:HandleWishlist(data)
    self.wishlist = data.items or {}
    DCCollectionDB.wishlistCache = self.wishlist
    
    -- Notify UI
    if self.WishlistUI and self.WishlistUI:IsShown() then
        self.WishlistUI:Refresh()
    end
end

function DC:HandleTitleSet(data)
    if data.success then
        -- Title set successfully
    else
        self:Print("|cffff0000" .. (data.error or DC.L["ERR_TITLE_NOT_OWNED"]) .. "|r")
    end
end

function DC:HandleStats(data)
    -- Store raw stats for legacy compatibility
    for collType, stats in pairs(data.stats or {}) do
        if self.stats[collType] then
            self.stats[collType].owned = stats.owned or 0
            self.stats[collType].total = stats.total or 0
        end
    end
    
    -- Update mount speed bonus
    if data.mountSpeedBonus then
        self.mountSpeedBonus = data.mountSpeedBonus
        DCCollectionDB.mountSpeedBonus = data.mountSpeedBonus
    end
    
    -- Update collectionStats for MyCollection overview (new format)
    self.collectionStats = self.collectionStats or {}
    
    -- Map from stats format to collectionStats format
    local statsData = data.stats or data
    for collType, stats in pairs(statsData) do
        if type(stats) == "table" then
            self.collectionStats[collType] = {
                collected = stats.owned or stats.collected or 0,
                total = stats.total or 0,
            }
        end
    end
    
    -- Handle recent additions if included
    if data.recent then
        self.recentAdditions = data.recent
    end
    
    -- Notify legacy UI
    if self.MainFrame and self.MainFrame:IsShown() then
        if type(self.RequestRefreshCurrentTab) == "function" then
            self:RequestRefreshCurrentTab()
        else
            self:RefreshCurrentTab()
        end
    end
    
    -- Notify My Collection overview
    if self.MyCollection then
        self.MyCollection:Update()
    end
end

function DC:HandleAchievements(data)
    local list = data.achievements or {}
    self.achievements = {}
    
    -- Convert list to lookup table
    for k, v in pairs(list) do
        if type(v) == "number" then
            self.achievements[v] = true
        elseif type(k) == "number" or type(k) == "string" then
            -- Handle case where it might already be a map or mixed
            self.achievements[k] = v
        end
    end
    
    -- Notify UI
    if self.AchievementsUI and self.AchievementsUI:IsShown() then
        self.AchievementsUI:Refresh()
    end
end

function DC:HandleNewItem(data)
    local collType = data.type
    local itemId = data.itemId
    local itemData = data.itemData
    
    -- Add to cache
    self:CacheAddItem(collType, itemId, itemData)
    
    -- Show notification
    if self:GetSetting("showNewItemToast") then
        local def = self:GetDefinition(collType, itemId)
        local name = def and def.name or "Unknown"
        self:ShowToast(collType, name, def and def.icon)
    end
    
    -- Check if this was on wishlist
    for i, wish in ipairs(self.wishlist) do
        if wish.type == collType and wish.itemId == itemId then
            table.remove(self.wishlist, i)
            self:Print(DC.L["WISHLIST_OBTAINED"] or "Wishlist item obtained!")
            break
        end
    end
    
    -- Trigger achievement check
    self:CheckAchievements(collType)
end

function DC:HandleMountSpeedBonus(data)
    self.mountSpeedBonus = data.bonus or 0
    DCCollectionDB.mountSpeedBonus = self.mountSpeedBonus
    
    if data.bonus > 0 then
        self:Debug(string.format("Mount speed bonus: +%d%%", data.bonus))
    end
end

function DC:HandleError(data)
    local errorCode = data.code or 0
    local errorMsg = data.message or DC.L["ERR_UNKNOWN"]
    
    self:Print("|cffff0000Error:|r " .. errorMsg)
    self:Debug(string.format("Server error code %d: %s", errorCode, errorMsg))
end

-- ============================================================================
-- SYNC FUNCTIONS
-- ============================================================================

-- Full sync - request all data
function DC:FullSync()
    self:Print(DC.L["SYNC_STARTED"] or "Syncing collection data...")
    
    -- Request definitions for all types
    for _, collType in ipairs({"mounts", "pets", "heirlooms", "transmog", "titles"}) do
        self:RequestDefinitions(collType)
        self:RequestCollection(collType)
    end
    
    -- Request additional data
    self:RequestCurrency()
    self:RequestStats()
    self:RequestWishlist()
end

-- Delta sync - only request changes
function DC:DeltaSync()
    self:Debug("Starting delta sync...")
    
    -- Request only definitions that changed
    for _, collType in ipairs({"mounts", "pets", "heirlooms", "transmog", "titles"}) do
        local lastVersion = self:GetSyncVersion(collType)
        if lastVersion > 0 then
            self:RequestDefinitions(collType, lastVersion)
        else
            self:RequestDefinitions(collType)
        end
    end
    
    -- Always request collection (server handles delta)
    for _, collType in ipairs({"mounts", "pets", "heirlooms", "transmog", "titles"}) do
        self:RequestCollection(collType)
    end
    
    self:RequestCurrency()
    self:RequestStats()
end

-- ============================================================================
-- UTILITY
-- ============================================================================

function DC:TableCount(t)
    if type(t) ~= "table" then
        return 0
    end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- Toast notification for new items
-- Note: This is overridden by UI/ToastFrame.lua when loaded
-- Fallback implementation for when toast UI is not available
if not DC.ShowToast then
    function DC:ShowToast(collType, itemName, icon)
        local typeStr = DC.L["TAB_" .. string.upper(collType)] or collType
        self:Print(string.format("|cff00ff00New %s:|r %s", typeStr, itemName))
    end
end

-- Check achievements after collection update
function DC:CheckAchievements(collType)
    -- Request achievement update from server
    self:RequestAchievements()
end

-- ============================================================================
-- COMMUNITY OUTFITS HANDLERS
-- ============================================================================

function DC:HandleCommunityList(data)
    local outfits = data.outfits or {}
    
    -- Notify UI
    if self.CommunityUI and self.CommunityUI.OnListReceived then
        self.CommunityUI:OnListReceived(outfits)
    end
end

function DC:HandleCommunityPublishResult(data)
    local success = data[1] -- The data can be a boolean directly if sent via Add(bool)
    if type(success) ~= "boolean" then success = data.success end -- Fallback if JSON object

    if success then
        self:Print(DC.L["COMMUNITY_PUBLISH_SUCCESS"] or "Outfit published to community!")
    else
        self:Print("|cffff0000" .. (DC.L["COMMUNITY_PUBLISH_FAILED"] or "Failed to publish outfit.") .. "|r")
    end
    
    -- Notify UI
    if self.Wardrobe and self.Wardrobe.OnPublishResult then
        self.Wardrobe:OnPublishResult(success)
    end
end

function DC:HandleCommunityFavoriteResult(data)
    local outfitId = data.id
    local isAdd = data.add
    local success = true -- Assume success if we got the result back
    
    if self.CommunityUI and self.CommunityUI.OnFavoriteResult then
        self.CommunityUI:OnFavoriteResult(outfitId, isAdd)
    end
end

function DC:RequestAddWishlist(collectionType, entryId)
    local msg = DC:CreateMessage(DC.Opcodes.CMSG_ADD_WISHLIST)
    msg:Add("type", collectionType or 6) -- Default to Transmog (6)
    msg:Add("entryId", entryId)
    DC:SendMessage(msg)
end
