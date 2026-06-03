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
        CMSG_GET_SHOP_HISTORY    = 0x13  -- Request purchase history
        
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
        SMSG_SHOP_HISTORY        = 0x5B  -- Purchase history (JSON)
        
        SMSG_WISHLIST_DATA       = 0x60  -- Wishlist items (JSON)
        SMSG_WISHLIST_AVAILABLE  = 0x61  -- Item on wishlist now available
        SMSG_WISHLIST_UPDATED    = 0x62  -- Wishlist updated
        
        SMSG_OPEN_UI             = 0x70  -- Open collection UI
        SMSG_ERROR               = 0x7F  -- Error response
]]

local DC = DCCollection

-- Initialize Protocol namespace
DC.Protocol = DC.Protocol or {}

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
    CMSG_GET_DEFINITIONS     = 0x06,
    CMSG_GET_COLLECTION      = 0x07,
    CMSG_GET_ITEM_SETS       = 0x08,
    
    -- Client -> Server: Outfits
    CMSG_SAVE_OUTFIT         = 0x39,
    CMSG_DELETE_OUTFIT       = 0x3A,
    CMSG_GET_SAVED_OUTFITS   = 0x3B,

    -- Client -> Server: Inspection
    CMSG_INSPECT_TRANSMOG     = 0x3D,

    -- Client -> Server: Shop
    CMSG_GET_SHOP            = 0x10,
    CMSG_BUY_ITEM            = 0x11,
    CMSG_GET_CURRENCIES      = 0x12,
    CMSG_GET_SHOP_HISTORY    = 0x13,
    
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
    
    -- Client -> Server: Community (0x53+ range to avoid collision with Outfit opcodes)
    CMSG_COMMUNITY_GET_LIST   = 0x53,
    CMSG_COMMUNITY_PUBLISH    = 0x54,
    CMSG_COMMUNITY_RATE       = 0x55,
    CMSG_COMMUNITY_FAVORITE   = 0x56,
    CMSG_COMMUNITY_VIEW       = 0x57,
    CMSG_COPY_COMMUNITY_OUTFIT = 0x58, -- Copy community outfit to personal account collection
    CMSG_COMMUNITY_UPDATE     = 0x59, -- Update community outfit (owner only)
    CMSG_COMMUNITY_DELETE     = 0x5A, -- Delete community outfit (owner only)
    
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
    SMSG_ITEM_SETS               = 0x4B,
    SMSG_SAVED_OUTFITS           = 0x4C,

    -- Server -> Client: Community
    SMSG_COMMUNITY_LIST       = 0x63,
    SMSG_COMMUNITY_PUBLISH_RESULT = 0x64,
    SMSG_COMMUNITY_FAVORITE_RESULT = 0x65,
    SMSG_INSPECT_TRANSMOG      = 0x66,
    SMSG_COMMUNITY_UPDATE_RESULT = 0x67,
    SMSG_COMMUNITY_DELETE_RESULT = 0x68,

    
    -- Server -> Client: Shop
    SMSG_SHOP_DATA           = 0x50,
    SMSG_PURCHASE_RESULT     = 0x51,
    SMSG_CURRENCIES          = 0x52,
    SMSG_SHOP_HISTORY        = 0x5B,
    
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
DC.callbacks = DC.callbacks or {}

local COLLECTION_WAVE1_NATIVE_CAPABILITY = 0x00080000
local NATIVE_COLLECTION_WAVE1_POLL_INTERVAL = 0.10
local lastNativeCollectionWave1Revision = 0
local nativeCollectionWave1PollFrame = nil
local NATIVE_SAVED_OUTFITS_POLL_INTERVAL = 0.10
local lastNativeSavedOutfitsRevision = 0
local nativeSavedOutfitsPollFrame = nil
local NATIVE_COMMUNITY_POLL_INTERVAL = 0.10
local lastNativeCommunityRevision = 0
local nativeCommunityPollFrame = nil
local COLLECTION_TRANSMOG_STATE_NATIVE_CAPABILITY = 0x00002000
local NATIVE_TRANSMOG_STATE_POLL_INTERVAL = 0.10
local lastNativeTransmogStateRevision = 0
local nativeTransmogStatePollFrame = nil
local COLLECTION_ITEM_SETS_NATIVE_CAPABILITY = 0x00004000
local NATIVE_ITEM_SETS_POLL_INTERVAL = 0.10
local lastNativeItemSetsRevision = 0
local nativeItemSetsPollFrame = nil

DC._collectionTransportDiagnostics = DC._collectionTransportDiagnostics or {}

local function GetTransportTimestamp()
    if type(time) == "function" then
        return time()
    end

    return 0
end

local function EnsureCollectionTransportDiagnostics()
    local diagnostics = DC._collectionTransportDiagnostics
    if type(diagnostics) ~= "table" then
        diagnostics = {}
        DC._collectionTransportDiagnostics = diagnostics
    end

    diagnostics.collectionWave1 = diagnostics.collectionWave1 or {}
    diagnostics.shop = diagnostics.shop or {}
    diagnostics.currencies = diagnostics.currencies or {}
    diagnostics.shopHistory = diagnostics.shopHistory or {}
    diagnostics.wishlist = diagnostics.wishlist or {}
    diagnostics.purchaseResult = diagnostics.purchaseResult or {}
    diagnostics.savedOutfits = diagnostics.savedOutfits or {}
    diagnostics.community = diagnostics.community or {}
    diagnostics.transmogState = diagnostics.transmogState or {}
    diagnostics.itemSets = diagnostics.itemSets or {}
    return diagnostics
end

local function RefreshCollectionTransportUi()
    if DC.MainFrame and type(DC.MainFrame.IsShown) == "function"
        and DC.MainFrame:IsShown()
        and type(DC.UpdateHeader) == "function" then
        DC:UpdateHeader()
    end
end

local function GetCollectionOpcodeLabel(opcode)
    opcode = tonumber(opcode) or 0

    if opcode == DC.Opcodes.CMSG_HANDSHAKE
        or opcode == DC.Opcodes.SMSG_HANDSHAKE_ACK then
        return "handshake"
    end
    if opcode == DC.Opcodes.CMSG_GET_FULL_COLLECTION
        or opcode == DC.Opcodes.SMSG_FULL_COLLECTION then
        return "full"
    end
    if opcode == DC.Opcodes.CMSG_SYNC_COLLECTION
        or opcode == DC.Opcodes.SMSG_DELTA_SYNC then
        return "sync"
    end
    if opcode == DC.Opcodes.CMSG_GET_STATS
        or opcode == DC.Opcodes.SMSG_STATS then
        return "stats"
    end
    if opcode == DC.Opcodes.CMSG_GET_BONUSES
        or opcode == DC.Opcodes.SMSG_BONUSES then
        return "bonuses"
    end
    if opcode == DC.Opcodes.CMSG_GET_COLLECTION
        or opcode == DC.Opcodes.SMSG_COLLECTION then
        return "collection"
    end
    if opcode == DC.Opcodes.CMSG_GET_SHOP
        or opcode == DC.Opcodes.SMSG_SHOP_DATA then
        return "shop"
    end
    if opcode == DC.Opcodes.CMSG_BUY_ITEM
        or opcode == DC.Opcodes.SMSG_PURCHASE_RESULT then
        return "purchase"
    end
    if opcode == DC.Opcodes.CMSG_GET_CURRENCIES
        or opcode == DC.Opcodes.SMSG_CURRENCIES then
        return "currencies"
    end
    if opcode == DC.Opcodes.CMSG_GET_SHOP_HISTORY
        or opcode == DC.Opcodes.SMSG_SHOP_HISTORY then
        return "shop_history"
    end
    if opcode == DC.Opcodes.CMSG_GET_WISHLIST
        or opcode == DC.Opcodes.SMSG_WISHLIST_DATA then
        return "wishlist"
    end
    if opcode == DC.Opcodes.CMSG_ADD_WISHLIST then
        return "wishlist_add"
    end
    if opcode == DC.Opcodes.CMSG_REMOVE_WISHLIST then
        return "wishlist_remove"
    end
    if opcode == DC.Opcodes.SMSG_WISHLIST_AVAILABLE then
        return "wishlist_available"
    end
    if opcode == DC.Opcodes.SMSG_WISHLIST_UPDATED then
        return "wishlist_updated"
    end
    if opcode == DC.Opcodes.CMSG_GET_TRANSMOG_STATE
        or opcode == DC.Opcodes.SMSG_TRANSMOG_STATE then
        return "transmog_state"
    end
    if opcode == DC.Opcodes.CMSG_GET_ITEM_SETS
        or opcode == DC.Opcodes.SMSG_ITEM_SETS then
        return "item_sets"
    end
    if opcode == DC.Opcodes.CMSG_GET_SAVED_OUTFITS then
        return "get_saved_outfits"
    end
    if opcode == DC.Opcodes.SMSG_SAVED_OUTFITS then
        return "saved_outfits"
    end
    if opcode == DC.Opcodes.CMSG_COMMUNITY_GET_LIST then
        return "community_get_list"
    end
    if opcode == DC.Opcodes.SMSG_COMMUNITY_LIST then
        return "community_list"
    end
    if opcode == DC.Opcodes.CMSG_COMMUNITY_PUBLISH then
        return "community_publish"
    end
    if opcode == DC.Opcodes.SMSG_COMMUNITY_PUBLISH_RESULT then
        return "community_publish_result"
    end
    if opcode == DC.Opcodes.CMSG_COMMUNITY_RATE then
        return "community_rate"
    end
    if opcode == DC.Opcodes.CMSG_COMMUNITY_FAVORITE then
        return "community_favorite"
    end
    if opcode == DC.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT then
        return "community_favorite_result"
    end
    if opcode == DC.Opcodes.CMSG_COMMUNITY_VIEW then
        return "community_view"
    end
    if opcode == DC.Opcodes.CMSG_COPY_COMMUNITY_OUTFIT then
        return "community_copy_outfit"
    end
    if opcode == DC.Opcodes.CMSG_COMMUNITY_UPDATE then
        return "community_update"
    end
    if opcode == DC.Opcodes.SMSG_COMMUNITY_UPDATE_RESULT then
        return "community_update_result"
    end
    if opcode == DC.Opcodes.CMSG_COMMUNITY_DELETE then
        return "community_delete"
    end
    if opcode == DC.Opcodes.SMSG_COMMUNITY_DELETE_RESULT then
        return "community_delete_result"
    end

    return string.format("0x%02X", opcode)
end

local function UpdateCollectionTransportChannel(channelKey, updater)
    local diagnostics = EnsureCollectionTransportDiagnostics()
    local channel = diagnostics[channelKey]
    updater(channel)
    RefreshCollectionTransportUi()
end

local function RecordCollectionTransportRequest(channelKey, transport, opcode,
    payloadBytes, options)
    options = options or {}

    UpdateCollectionTransportChannel(channelKey, function(channel)
        channel.lastRequestAt = GetTransportTimestamp()
        channel.lastRequestTransport = tostring(transport or "addon")
        channel.lastRequestOpcode = tonumber(opcode) or 0
        channel.lastRequestLabel = GetCollectionOpcodeLabel(opcode)
        channel.lastRequestPayloadBytes = tonumber(payloadBytes) or 0
        channel.awaitingReply = options.expectsReply ~= false
        channel.lastError = nil
    end)
end

local function RecordCollectionTransportReply(channelKey, transport, opcode,
    revision, payloadBytes, options)
    options = options or {}

    UpdateCollectionTransportChannel(channelKey, function(channel)
        local matchedRequest = options.matchedRequest
        if matchedRequest == nil then
            matchedRequest = channel.awaitingReply == true
                and (tonumber(channel.lastRequestAt) or 0) > 0
        end

        channel.lastReplyAt = GetTransportTimestamp()
        channel.lastReplyTransport = tostring(transport or "addon")
        channel.lastReplyOpcode = tonumber(opcode) or 0
        channel.lastReplyLabel = GetCollectionOpcodeLabel(opcode)
        channel.lastReplyRevision = tonumber(revision) or 0
        channel.lastReplyPayloadBytes = tonumber(payloadBytes) or 0
        channel.lastReplyMatchedRequest = matchedRequest == true
        if matchedRequest == true or channel.awaitingReply ~= true then
            channel.awaitingReply = false
        end
        channel.lastError = nil
    end)
end

local function RecordCollectionTransportError(channelKey, phase, reason)
    UpdateCollectionTransportChannel(channelKey, function(channel)
        channel.awaitingReply = false
        channel.lastError = string.format("%s: %s", tostring(phase or "error"),
            tostring(reason or "unknown"))
        channel.lastErrorAt = GetTransportTimestamp()
    end)
end

local function GetCollectionTransportChannelRevision(channel)
    channel = type(channel) == "table" and channel or {}

    return tonumber(channel.lastReplyRevision)
        or tonumber(channel.lastRevision) or 0
end

local function ClassifyCollectionTransportChannel(channel)
    channel = type(channel) == "table" and channel or {}

    local requestAt = tonumber(channel.lastRequestAt) or 0
    local replyAt = tonumber(channel.lastReplyAt) or 0
    local revision = GetCollectionTransportChannelRevision(channel)
    local awaitingReply = channel.awaitingReply == true

    if awaitingReply and requestAt > 0
        and (replyAt <= 0 or replyAt < requestAt) then
        return "pending", "request sent; awaiting reply"
    end

    if replyAt > 0 then
        if channel.lastReplyMatchedRequest == false then
            return "observed", "reply observed without local request"
        end

        return "reply", "reply received"
    end

    if revision > 0 then
        return "cached", "cached snapshot present"
    end

    return "idle", "not requested yet"
end

local function GetCollectionTransportLastRequestOpcode(channelKey)
    local diagnostics = EnsureCollectionTransportDiagnostics()
    local channel = diagnostics[channelKey]
    if type(channel) ~= "table" then
        return 0
    end

    return tonumber(channel.lastRequestOpcode) or 0
end

local function GetCollectionWave1ResponseChannelKey(logicalOpcode)
    logicalOpcode = tonumber(logicalOpcode) or 0

    if logicalOpcode == DC.Opcodes.SMSG_SHOP_DATA then
        return "shop"
    end
    if logicalOpcode == DC.Opcodes.SMSG_CURRENCIES then
        return "currencies"
    end
    if logicalOpcode == DC.Opcodes.SMSG_SHOP_HISTORY then
        return "shopHistory"
    end
    if logicalOpcode == DC.Opcodes.SMSG_PURCHASE_RESULT then
        return "purchaseResult"
    end
    if logicalOpcode == DC.Opcodes.SMSG_WISHLIST_DATA
        or logicalOpcode == DC.Opcodes.SMSG_WISHLIST_AVAILABLE
        or logicalOpcode == DC.Opcodes.SMSG_WISHLIST_UPDATED then
        return "wishlist"
    end

    return nil
end

local function IsMatchingCollectionWave1ChannelResponse(channelKey,
    requestOpcode, logicalOpcode)
    channelKey = tostring(channelKey or "")
    requestOpcode = tonumber(requestOpcode) or 0
    logicalOpcode = tonumber(logicalOpcode) or 0

    if channelKey == "shop" then
        return requestOpcode == DC.Opcodes.CMSG_GET_SHOP
            and logicalOpcode == DC.Opcodes.SMSG_SHOP_DATA
    end

    if channelKey == "currencies" then
        return requestOpcode == DC.Opcodes.CMSG_GET_CURRENCIES
            and logicalOpcode == DC.Opcodes.SMSG_CURRENCIES
    end

    if channelKey == "shopHistory" then
        return requestOpcode == DC.Opcodes.CMSG_GET_SHOP_HISTORY
            and logicalOpcode == DC.Opcodes.SMSG_SHOP_HISTORY
    end

    if channelKey == "purchaseResult" then
        return requestOpcode == DC.Opcodes.CMSG_BUY_ITEM
            and logicalOpcode == DC.Opcodes.SMSG_PURCHASE_RESULT
    end

    if channelKey == "wishlist" then
        if requestOpcode == DC.Opcodes.CMSG_GET_WISHLIST then
            return logicalOpcode == DC.Opcodes.SMSG_WISHLIST_DATA
        end

        if requestOpcode == DC.Opcodes.CMSG_ADD_WISHLIST
            or requestOpcode == DC.Opcodes.CMSG_REMOVE_WISHLIST then
            return logicalOpcode == DC.Opcodes.SMSG_WISHLIST_UPDATED
        end
    end

    return false
end

local function GetCollectionTransportLogChannel(channelKey)
    if channelKey == "shopHistory" then
        return "shop-history"
    end
    if channelKey == "purchaseResult" then
        return "purchase-result"
    end

    return tostring(channelKey or "collection-wave1")
end

local function RecordAddonCollectionChannelReply(channelKey, opcode, options)
    options = options or {}
    if options.matchedRequest == nil then
        options.matchedRequest = IsMatchingCollectionWave1ChannelResponse(
            channelKey, GetCollectionTransportLastRequestOpcode(channelKey),
            opcode)
    end

    RecordCollectionTransportReply(channelKey, "addon", opcode, 0, 0,
        options)
end

local function LogCollectionTransportEvent(level, channel, message, extra)
    if type(DC.LogNetEvent) ~= "function" then
        return
    end

    extra = extra or {}
    extra.channel = channel
    DC:LogNetEvent(level, "bridge", message, extra)
end

local function TrackAddonCollectionProtocolReply(opcode)
    opcode = tonumber(opcode) or 0

    if opcode == DC.Opcodes.SMSG_HANDSHAKE_ACK
        or opcode == DC.Opcodes.SMSG_FULL_COLLECTION
        or opcode == DC.Opcodes.SMSG_DELTA_SYNC
        or opcode == DC.Opcodes.SMSG_STATS
        or opcode == DC.Opcodes.SMSG_BONUSES
        or opcode == DC.Opcodes.SMSG_COLLECTION then
        RecordCollectionTransportReply("collectionWave1", "addon", opcode, 0,
            0)
        return
    end

    if opcode == DC.Opcodes.SMSG_TRANSMOG_STATE then
        RecordCollectionTransportReply("transmogState", "addon", opcode, 0,
            0)
        return
    end

    if opcode == DC.Opcodes.SMSG_ITEM_SETS then
        RecordCollectionTransportReply("itemSets", "addon", opcode, 0, 0)
        return
    end

    if opcode == DC.Opcodes.SMSG_SAVED_OUTFITS then
        RecordCollectionTransportReply("savedOutfits", "addon", opcode, 0,
            0)
        return
    end

    if opcode == DC.Opcodes.SMSG_SHOP_DATA then
        RecordAddonCollectionChannelReply("shop", opcode)
        return
    end

    if opcode == DC.Opcodes.SMSG_CURRENCIES then
        RecordAddonCollectionChannelReply("currencies", opcode)
        return
    end

    if opcode == DC.Opcodes.SMSG_SHOP_HISTORY then
        RecordAddonCollectionChannelReply("shopHistory", opcode)
        return
    end

    if opcode == DC.Opcodes.SMSG_PURCHASE_RESULT then
        RecordAddonCollectionChannelReply("purchaseResult", opcode)
        return
    end

    if opcode == DC.Opcodes.SMSG_WISHLIST_DATA
        or opcode == DC.Opcodes.SMSG_WISHLIST_UPDATED then
        RecordAddonCollectionChannelReply("wishlist", opcode)
        return
    end

    if opcode == DC.Opcodes.SMSG_WISHLIST_AVAILABLE then
        RecordAddonCollectionChannelReply("wishlist", opcode,
            { matchedRequest = false })
        return
    end

    if opcode == DC.Opcodes.SMSG_COMMUNITY_LIST
        or opcode == DC.Opcodes.SMSG_COMMUNITY_PUBLISH_RESULT
        or opcode == DC.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT
        or opcode == DC.Opcodes.SMSG_COMMUNITY_UPDATE_RESULT
        or opcode == DC.Opcodes.SMSG_COMMUNITY_DELETE_RESULT then
        RecordCollectionTransportReply("community", "addon", opcode, 0, 0)
    end
end

local function HasCapabilityBit(mask, capability)
    mask = tonumber(mask) or 0
    capability = tonumber(capability) or 0
    if capability <= 0 then
        return false
    end

    local band = nil
    if type(bit) == "table" and type(bit.band) == "function" then
        band = bit.band
    elseif type(bit32) == "table" and type(bit32.band) == "function" then
        band = bit32.band
    end

    if band then
        return band(mask, capability) ~= 0
    end

    return (mask % (capability * 2)) >= capability
end

local function GetCollectionCentralProtocol()
    local central = rawget(_G, "DCAddonProtocol")
    if type(central) ~= "table" then
        return nil
    end

    return central
end

local function GetCollectionCapabilitySnapshot()
    local central = GetCollectionCentralProtocol()
    if not central or type(central.GetCapabilitySnapshot) ~= "function" then
        return nil
    end

    local ok, snapshot = pcall(function()
        return central:GetCapabilitySnapshot()
    end)
    if not ok or type(snapshot) ~= "table" then
        return nil
    end

    return snapshot
end

local function HasNativeCollectionWave1Bridge()
    return type(RequestNativeCollectionWave1) == "function"
        and type(GetNativeCollectionWave1Snapshot) == "function"
end

local function ShouldUseNativeCollectionWave1Bridge()
    if not HasNativeCollectionWave1Bridge() then
        return false
    end

    local snapshot = GetCollectionCapabilitySnapshot()
    if type(snapshot) ~= "table" then
        return false
    end

    return HasCapabilityBit(snapshot.clientCaps,
            COLLECTION_WAVE1_NATIVE_CAPABILITY)
        and HasCapabilityBit(snapshot.negotiatedCaps,
            COLLECTION_WAVE1_NATIVE_CAPABILITY)
end

local function HasNativeCollectionSavedOutfitsBridge()
    return type(RequestNativeCollectionSavedOutfits) == "function"
        and type(GetNativeCollectionSavedOutfitsSnapshot) == "function"
end

local function ShouldUseNativeCollectionSavedOutfitsBridge()
    return HasNativeCollectionSavedOutfitsBridge()
        and ShouldUseNativeCollectionWave1Bridge()
end

local function HasNativeCollectionCommunityBridge()
    return type(RequestNativeCollectionCommunity) == "function"
        and type(GetNativeCollectionCommunitySnapshot) == "function"
end

local function ShouldUseNativeCollectionCommunityBridge()
    return HasNativeCollectionCommunityBridge()
        and ShouldUseNativeCollectionWave1Bridge()
end

local function IsNativeCollectionCommunityResponse(logicalOpcode)
    logicalOpcode = tonumber(logicalOpcode) or 0

    return logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_LIST
        or logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_PUBLISH_RESULT
        or logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT
        or logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_UPDATE_RESULT
        or logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_DELETE_RESULT
end

local function IsMatchingNativeCollectionCommunityResponse(requestOpcode,
    logicalOpcode)
    requestOpcode = tonumber(requestOpcode) or 0
    logicalOpcode = tonumber(logicalOpcode) or 0

    if requestOpcode == DC.Opcodes.CMSG_COMMUNITY_GET_LIST then
        return logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_LIST
    end
    if requestOpcode == DC.Opcodes.CMSG_COMMUNITY_PUBLISH then
        return logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_PUBLISH_RESULT
    end
    if requestOpcode == DC.Opcodes.CMSG_COMMUNITY_FAVORITE then
        return logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT
    end
    if requestOpcode == DC.Opcodes.CMSG_COMMUNITY_UPDATE then
        return logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_UPDATE_RESULT
    end
    if requestOpcode == DC.Opcodes.CMSG_COMMUNITY_DELETE then
        return logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_DELETE_RESULT
    end

    return false
end

local function GetNativeCollectionWave1RequestState(channelKey)
    if channelKey == "shop" then
        return DC._nativeShopLastRequest
    end
    if channelKey == "currencies" then
        return DC._nativeCurrenciesLastRequest
    end
    if channelKey == "shopHistory" then
        return DC._nativeShopHistoryLastRequest
    end
    if channelKey == "wishlist" then
        return DC._nativeWishlistLastRequest
    end
    if channelKey == "purchaseResult" then
        return DC._nativePurchaseResultLastRequest
    end

    return nil
end

local function SetNativeCollectionWave1RequestState(channelKey, requestState)
    if channelKey == "shop" then
        DC._nativeShopLastRequest = requestState
        return
    end
    if channelKey == "currencies" then
        DC._nativeCurrenciesLastRequest = requestState
        return
    end
    if channelKey == "shopHistory" then
        DC._nativeShopHistoryLastRequest = requestState
        return
    end
    if channelKey == "wishlist" then
        DC._nativeWishlistLastRequest = requestState
        return
    end
    if channelKey == "purchaseResult" then
        DC._nativePurchaseResultLastRequest = requestState
        return
    end
end

local function EncodeNativeCollectionWave1Payload(data)
    local payload = data
    if payload == nil then
        payload = {}
    end

    local central = GetCollectionCentralProtocol()
    if not central or type(central.EncodeJSON) ~= "function" then
        return nil
    end

    local ok, encoded = pcall(function()
        return central:EncodeJSON(payload)
    end)
    if not ok or type(encoded) ~= "string" then
        return nil
    end

    return encoded
end

local function DecodeNativeCollectionWave1Payload(payload)
    if type(payload) ~= "string" or payload == "" then
        return nil
    end

    local central = GetCollectionCentralProtocol()
    if not central or type(central.DecodeJSON) ~= "function" then
        return nil
    end

    local ok, decoded = pcall(function()
        return central:DecodeJSON(payload)
    end)
    if not ok or type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

local function DispatchNativeCollectionWave1Message(logicalOpcode, data)
    if logicalOpcode == DC.Opcodes.SMSG_HANDSHAKE_ACK then
        DC:HandleHandshakeAck(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_FULL_COLLECTION then
        DC:HandleFullCollection(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_DELTA_SYNC then
        DC:HandleDeltaSync(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_STATS then
        DC:HandleStats(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_BONUSES then
        DC:HandleBonuses(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_COLLECTION then
        DC:HandleCollection(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_SHOP_DATA then
        DC:HandleShopData(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_PURCHASE_RESULT then
        DC:HandlePurchaseResult(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_CURRENCIES then
        DC:HandleCurrencies(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_SHOP_HISTORY then
        DC:HandleShopHistory(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_WISHLIST_DATA then
        DC:HandleWishlistData(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_WISHLIST_AVAILABLE then
        DC:HandleWishlistAvailable(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_WISHLIST_UPDATED then
        DC:HandleWishlistUpdated(data)
        return true
    end

    if logicalOpcode == DC.Opcodes.SMSG_SAVED_OUTFITS then
        DC:OnMsg_SavedOutfits(data)
        return true
    end

    if IsNativeCollectionCommunityResponse(logicalOpcode) then
        if logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_LIST then
            DC:HandleCommunityList(data)
            return true
        end
        if logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_PUBLISH_RESULT then
            DC:HandleCommunityPublishResult(data)
            return true
        end
        if logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT then
            DC:HandleCommunityFavoriteResult(data)
            return true
        end
        if logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_UPDATE_RESULT then
            DC:HandleCommunityUpdateResult(data)
            return true
        end
        if logicalOpcode == DC.Opcodes.SMSG_COMMUNITY_DELETE_RESULT then
            DC:HandleCommunityDeleteResult(data)
            return true
        end
    end

    if type(DC.Debug) == "function" then
        DC:Debug("Ignoring unsupported native collection wave1 opcode: "
            .. tostring(logicalOpcode))
    end

    return false
end

local function ConsumeNativeCollectionWave1Snapshot()
    if not ShouldUseNativeCollectionWave1Bridge() then
        return false
    end

    local ok, revision, logicalOpcode, payload =
        pcall(GetNativeCollectionWave1Snapshot)
    if not ok or revision == nil then
        return false
    end

    revision = tonumber(revision) or 0
    logicalOpcode = tonumber(logicalOpcode) or 0
    local payloadBytes = type(payload) == "string" and string.len(payload) or 0
    if revision <= 0 or revision == lastNativeCollectionWave1Revision
        or logicalOpcode <= 0 then
        return false
    end

    lastNativeCollectionWave1Revision = revision

    local decoded = DecodeNativeCollectionWave1Payload(payload)
    if type(decoded) ~= "table" then
        RecordCollectionTransportError("collectionWave1", "decode",
            "invalid native payload")
        LogCollectionTransportEvent("error", "collection-wave1",
            "Collection wave1 native snapshot decode failed",
            { opcode = logicalOpcode, revision = revision })
        return false
    end

    if logicalOpcode == DC.Opcodes.SMSG_SAVED_OUTFITS then
        if type(DC._nativeSavedOutfitsLastRequest) == "table" then
            return true
        end

        RecordCollectionTransportReply("savedOutfits", "native",
            logicalOpcode, revision, payloadBytes,
            { matchedRequest = false })
        LogCollectionTransportEvent("info", "saved-outfits",
            "Collection saved-outfits native snapshot observed <- saved_outfits",
            {
                opcode = logicalOpcode,
                revision = revision,
                payloadBytes = payloadBytes,
            })

        local handled = DispatchNativeCollectionWave1Message(logicalOpcode,
            decoded)
        if not handled then
            RecordCollectionTransportError("savedOutfits", "dispatch",
                "unsupported opcode " .. tostring(logicalOpcode))
        end

        return handled
    end

    if IsNativeCollectionCommunityResponse(logicalOpcode) then
        if type(DC._nativeCommunityLastRequest) == "table" then
            return true
        end

        RecordCollectionTransportReply("community", "native",
            logicalOpcode, revision, payloadBytes,
            { matchedRequest = false })
        LogCollectionTransportEvent("info", "community",
            "Collection community native snapshot observed <- "
                .. GetCollectionOpcodeLabel(logicalOpcode),
            {
                opcode = logicalOpcode,
                revision = revision,
                payloadBytes = payloadBytes,
            })

        local handled = DispatchNativeCollectionWave1Message(logicalOpcode,
            decoded)
        if not handled then
            RecordCollectionTransportError("community", "dispatch",
                "unsupported opcode " .. tostring(logicalOpcode))
        end

        return handled
    end

    local channelKey = GetCollectionWave1ResponseChannelKey(logicalOpcode)
    if channelKey then
        local nativeReq = GetNativeCollectionWave1RequestState(channelKey)
        local matchedRequest = false
        if type(nativeReq) == "table" then
            matchedRequest = IsMatchingCollectionWave1ChannelResponse(
                channelKey, nativeReq.requestOpcode, logicalOpcode)
        end

        RecordCollectionTransportReply(channelKey, "native",
            logicalOpcode, revision, payloadBytes,
            { matchedRequest = matchedRequest })

        if matchedRequest then
            SetNativeCollectionWave1RequestState(channelKey, nil)
            LogCollectionTransportEvent("info",
                GetCollectionTransportLogChannel(channelKey),
                "Collection " .. tostring(channelKey)
                    .. " native response <- "
                    .. GetCollectionOpcodeLabel(logicalOpcode),
                {
                    opcode = logicalOpcode,
                    revision = revision,
                    payloadBytes = payloadBytes,
                })
        else
            LogCollectionTransportEvent("info",
                GetCollectionTransportLogChannel(channelKey),
                "Collection " .. tostring(channelKey)
                    .. " native snapshot observed <- "
                    .. GetCollectionOpcodeLabel(logicalOpcode),
                {
                    opcode = logicalOpcode,
                    revision = revision,
                    payloadBytes = payloadBytes,
                })
        end

        local handled = DispatchNativeCollectionWave1Message(logicalOpcode,
            decoded)
        if not handled then
            RecordCollectionTransportError(channelKey, "dispatch",
                "unsupported opcode " .. tostring(logicalOpcode))
        end

        return handled
    end

    RecordCollectionTransportReply("collectionWave1", "native",
        logicalOpcode, revision, payloadBytes)
    LogCollectionTransportEvent("info", "collection-wave1",
        "Collection wave1 native response <- "
            .. GetCollectionOpcodeLabel(logicalOpcode),
        {
            opcode = logicalOpcode,
            revision = revision,
            payloadBytes = payloadBytes,
        })

    local handled = DispatchNativeCollectionWave1Message(logicalOpcode, decoded)
    if not handled then
        RecordCollectionTransportError("collectionWave1", "dispatch",
            "unsupported opcode " .. tostring(logicalOpcode))
    end

    return handled
end

local function EnsureNativeCollectionWave1PollFrame()
    if nativeCollectionWave1PollFrame then
        return
    end

    nativeCollectionWave1PollFrame = CreateFrame("Frame")
    nativeCollectionWave1PollFrame.elapsed = 0
    nativeCollectionWave1PollFrame:SetScript("OnUpdate", function(self,
        elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < NATIVE_COLLECTION_WAVE1_POLL_INTERVAL then
            return
        end

        self.elapsed = 0
        -- Drain all queued messages in one tick so rapid-fire server responses
        -- (e.g. 13 DeltaSync replies on a LAN server) don't pile up and stall
        -- the progress bar for seconds. Cap at 64 to match the C++ queue max.
        local drained = 0
        while ConsumeNativeCollectionWave1Snapshot() and drained < 64 do
            drained = drained + 1
        end
    end)
end

local function ConsumeNativeCollectionSavedOutfitsSnapshot()
    if not ShouldUseNativeCollectionSavedOutfitsBridge() then
        return false
    end

    local nativeReq = DC._nativeSavedOutfitsLastRequest
    if type(nativeReq) ~= "table" then
        return false
    end

    local ok, revision, payload = pcall(GetNativeCollectionSavedOutfitsSnapshot)
    if not ok or revision == nil then
        return false
    end

    revision = tonumber(revision) or 0
    local payloadBytes = type(payload) == "string" and string.len(payload) or 0
    if revision <= 0 or revision == lastNativeSavedOutfitsRevision then
        return false
    end

    lastNativeSavedOutfitsRevision = revision

    local decoded = DecodeNativeCollectionWave1Payload(payload)
    if type(decoded) ~= "table" then
        RecordCollectionTransportError("savedOutfits", "decode",
            "invalid native payload")
        LogCollectionTransportEvent("error", "saved-outfits",
            "Collection saved-outfits native snapshot decode failed",
            { opcode = DC.Opcodes.SMSG_SAVED_OUTFITS, revision = revision })
        DC._nativeSavedOutfitsLastRequest = nil
        return false
    end

    RecordCollectionTransportReply("savedOutfits", "native",
        DC.Opcodes.SMSG_SAVED_OUTFITS, revision, payloadBytes)
    LogCollectionTransportEvent("info", "saved-outfits",
        "Collection saved-outfits native response <- saved_outfits",
        {
            opcode = DC.Opcodes.SMSG_SAVED_OUTFITS,
            revision = revision,
            payloadBytes = payloadBytes,
        })
    DC._nativeSavedOutfitsLastRequest = nil
    DC:OnMsg_SavedOutfits(decoded)
    return true
end

local function EnsureNativeCollectionSavedOutfitsPollFrame()
    if nativeSavedOutfitsPollFrame then
        return
    end

    nativeSavedOutfitsPollFrame = CreateFrame("Frame")
    nativeSavedOutfitsPollFrame.elapsed = 0
    nativeSavedOutfitsPollFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < NATIVE_SAVED_OUTFITS_POLL_INTERVAL then
            return
        end

        self.elapsed = 0
        ConsumeNativeCollectionSavedOutfitsSnapshot()
    end)
end

local function ConsumeNativeCollectionCommunitySnapshot()
    if not ShouldUseNativeCollectionCommunityBridge() then
        return false
    end

    local nativeReq = DC._nativeCommunityLastRequest
    if type(nativeReq) ~= "table" then
        return false
    end

    local ok, revision, logicalOpcode, payload =
        pcall(GetNativeCollectionCommunitySnapshot)
    if not ok or revision == nil then
        return false
    end

    revision = tonumber(revision) or 0
    logicalOpcode = tonumber(logicalOpcode) or 0
    local payloadBytes = type(payload) == "string" and string.len(payload) or 0
    if revision <= 0 or revision == lastNativeCommunityRevision
        or logicalOpcode <= 0 then
        return false
    end

    lastNativeCommunityRevision = revision

    local decoded = DecodeNativeCollectionWave1Payload(payload)
    if type(decoded) ~= "table" then
        RecordCollectionTransportError("community", "decode",
            "invalid native payload")
        LogCollectionTransportEvent("error", "community",
            "Collection community native snapshot decode failed",
            { opcode = logicalOpcode, revision = revision })
        DC._nativeCommunityLastRequest = nil
        return false
    end

    local requestOpcode = tonumber(nativeReq.requestOpcode) or 0
    local matchedRequest = IsMatchingNativeCollectionCommunityResponse(
        requestOpcode, logicalOpcode)
    local requestOwner = tostring(nativeReq.owner or "collection")

    if matchedRequest then
        RecordCollectionTransportReply("community", "native",
            logicalOpcode, revision, payloadBytes)
        LogCollectionTransportEvent("info", "community",
            "Collection community native response <- "
                .. GetCollectionOpcodeLabel(logicalOpcode),
            {
                opcode = logicalOpcode,
                revision = revision,
                payloadBytes = payloadBytes,
            })

        DC._nativeCommunityLastRequest = nil
        if requestOwner == "transport-refresh" then
            return true
        end
    else
        RecordCollectionTransportReply("community", "native",
            logicalOpcode, revision, payloadBytes,
            { matchedRequest = false })
        LogCollectionTransportEvent("info", "community",
            "Collection community native snapshot observed <- "
                .. GetCollectionOpcodeLabel(logicalOpcode),
            {
                opcode = logicalOpcode,
                revision = revision,
                payloadBytes = payloadBytes,
            })
    end

    local handled = DispatchNativeCollectionWave1Message(logicalOpcode,
        decoded)
    if not handled then
        RecordCollectionTransportError("community", "dispatch",
            "unsupported opcode " .. tostring(logicalOpcode))
    end

    return handled
end

local function EnsureNativeCollectionCommunityPollFrame()
    if nativeCommunityPollFrame then
        return
    end

    nativeCommunityPollFrame = CreateFrame("Frame")
    nativeCommunityPollFrame.elapsed = 0
    nativeCommunityPollFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < NATIVE_COMMUNITY_POLL_INTERVAL then
            return
        end

        self.elapsed = 0
        ConsumeNativeCollectionCommunitySnapshot()
    end)
end

local function SendCollectionCommunityRequest(logicalOpcode, data, options)
    options = options or {}
    local allowAddonFallback = options.allowAddonFallback ~= false
    local requestOwner = tostring(options.owner or "collection")
    local responseOpcode = tonumber(options.responseOpcode) or 0
    local expectsReply = responseOpcode > 0
    local sentAt = tonumber(options.sentAt) or 0
    if sentAt == 0 and type(GetTime) == "function" then
        sentAt = GetTime() or 0
    end

    if ShouldUseNativeCollectionCommunityBridge() then
        EnsureNativeCollectionCommunityPollFrame()

        local payload = EncodeNativeCollectionWave1Payload(data or {})
        if type(payload) == "string" then
            RecordCollectionTransportRequest("community", "native",
                logicalOpcode, string.len(payload),
                { expectsReply = expectsReply })
            local ok, err = pcall(RequestNativeCollectionCommunity,
                logicalOpcode, payload)
            if ok then
                if expectsReply then
                    DC._nativeCommunityLastRequest = {
                        requestOpcode = logicalOpcode,
                        owner = requestOwner,
                    }
                else
                    DC._nativeCommunityLastRequest = nil
                end
                LogCollectionTransportEvent("info", "community",
                    "Collection community native request -> "
                        .. GetCollectionOpcodeLabel(logicalOpcode),
                    {
                        opcode = logicalOpcode,
                        payloadBytes = string.len(payload),
                    })
                return true, "native"
            end

            DC._nativeCommunityLastRequest = nil
            RecordCollectionTransportError("community", "request",
                tostring(err))
            LogCollectionTransportEvent("error", "community",
                "Collection community native request failed",
                { opcode = logicalOpcode, err = tostring(err) })

            if type(DC.Debug) == "function" then
                DC:Debug("RequestNativeCollectionCommunity failed: "
                    .. tostring(err))
            end

            if not allowAddonFallback then
                return false
            end
        else
            RecordCollectionTransportError("community", "encode",
                "payload encode failed")
            LogCollectionTransportEvent("error", "community",
                "Collection community native payload encode failed",
                { opcode = logicalOpcode })

            if not allowAddonFallback then
                return false
            end
        end
    elseif not allowAddonFallback then
        RecordCollectionTransportError("community", "request",
            "native bridge unavailable")
        return false
    end

    RecordCollectionTransportRequest("community", "addon",
        logicalOpcode, 0, { expectsReply = expectsReply })
    LogCollectionTransportEvent("info", "community",
        "Collection community addon request -> "
            .. GetCollectionOpcodeLabel(logicalOpcode),
        { opcode = logicalOpcode })
    local ok = DC:SendMessage(logicalOpcode, data or {})

    if ok and responseOpcode > 0 then
        local opcodeHex = string.format("0x%02X", responseOpcode)
        ScheduleAwaitResponseDiagnostic(DC, {
            requestOpcode = logicalOpcode,
            responseOpcode = responseOpcode,
            sentAt = sentAt,
            timeoutSec = 2.0,
            awaitMessage = "Awaiting community response (" .. opcodeHex
                .. ")",
            timeoutMessage = "[Net] Await timeout for community response ("
                .. opcodeHex .. "); request may have been dropped or rate-limited",
        })
    end

    return ok, "addon"
end

local function SendCommunityCopyOutfitRequest(communityOutfitId, options)
    options = options or {}

    local ok, transport = SendCollectionCommunityRequest(
        DC.Opcodes.CMSG_COPY_COMMUNITY_OUTFIT,
        { id = communityOutfitId },
        {
            allowAddonFallback = options.allowAddonFallback,
            owner = "community-copy",
        })
    if not ok then
        return false
    end

    RecordCollectionTransportRequest("savedOutfits",
        transport or "addon",
        DC.Opcodes.CMSG_COPY_COMMUNITY_OUTFIT, 0)
    if ShouldUseNativeCollectionSavedOutfitsBridge() then
        EnsureNativeCollectionSavedOutfitsPollFrame()
        DC._nativeSavedOutfitsLastRequest = {
            owner = "community-copy",
        }
    else
        DC._nativeSavedOutfitsLastRequest = nil
    end

    return true
end

local function SendCollectionWave1Request(logicalOpcode, data, options)
    options = options or {}
    local allowAddonFallback = options.allowAddonFallback ~= false

    if ShouldUseNativeCollectionWave1Bridge() then
        EnsureNativeCollectionWave1PollFrame()

        local payload = EncodeNativeCollectionWave1Payload(data or {})
        if type(payload) == "string" then
            RecordCollectionTransportRequest("collectionWave1", "native",
                logicalOpcode, string.len(payload))
            local ok, err = pcall(RequestNativeCollectionWave1,
                logicalOpcode, payload)
            if ok then
                LogCollectionTransportEvent("info", "collection-wave1",
                    "Collection wave1 native request -> "
                        .. GetCollectionOpcodeLabel(logicalOpcode),
                    {
                        opcode = logicalOpcode,
                        payloadBytes = string.len(payload),
                    })
                return true
            end

            RecordCollectionTransportError("collectionWave1", "request",
                tostring(err))
            LogCollectionTransportEvent("error", "collection-wave1",
                "Collection wave1 native request failed",
                { opcode = logicalOpcode, err = tostring(err) })

            if type(DC.Debug) == "function" then
                DC:Debug("RequestNativeCollectionWave1 failed: "
                    .. tostring(err))
            end

            if not allowAddonFallback then
                return false
            end
        elseif type(DC.Debug) == "function" then
            RecordCollectionTransportError("collectionWave1", "encode",
                "payload encode failed")
            LogCollectionTransportEvent("error", "collection-wave1",
                "Collection wave1 native payload encode failed",
                { opcode = logicalOpcode })
            DC:Debug("Failed to encode native collection wave1 request payload")

            if not allowAddonFallback then
                return false
            end
        end
    elseif not allowAddonFallback then
        RecordCollectionTransportError("collectionWave1", "request",
            "native bridge unavailable")
        return false
    end

    RecordCollectionTransportRequest("collectionWave1", "addon",
        logicalOpcode, 0)
    LogCollectionTransportEvent("info", "collection-wave1",
        "Collection wave1 addon request -> "
            .. GetCollectionOpcodeLabel(logicalOpcode),
        { opcode = logicalOpcode })
    return DC:SendMessage(logicalOpcode, data or {})
end

local function SendOwnedCollectionWave1Request(channelKey, logicalOpcode,
    data, options)
    options = options or {}

    local allowAddonFallback = options.allowAddonFallback ~= false
    local responseOpcode = tonumber(options.responseOpcode) or 0
    local expectsReply = options.expectsReply
    if expectsReply == nil then
        expectsReply = responseOpcode > 0
    end

    local requestOwner = tostring(options.owner or "collection")
    local sentAt = tonumber(options.sentAt) or 0
    if sentAt == 0 and type(GetTime) == "function" then
        sentAt = GetTime() or 0
    end

    local logChannel = GetCollectionTransportLogChannel(channelKey)

    if ShouldUseNativeCollectionWave1Bridge() then
        EnsureNativeCollectionWave1PollFrame()

        local payload = EncodeNativeCollectionWave1Payload(data or {})
        if type(payload) == "string" then
            RecordCollectionTransportRequest(channelKey, "native",
                logicalOpcode, string.len(payload),
                { expectsReply = expectsReply })
            local ok, err = pcall(RequestNativeCollectionWave1,
                logicalOpcode, payload)
            if ok then
                if expectsReply then
                    SetNativeCollectionWave1RequestState(channelKey, {
                        requestOpcode = logicalOpcode,
                        owner = requestOwner,
                    })
                else
                    SetNativeCollectionWave1RequestState(channelKey, nil)
                end

                LogCollectionTransportEvent("info", logChannel,
                    "Collection " .. tostring(channelKey)
                        .. " native request -> "
                        .. GetCollectionOpcodeLabel(logicalOpcode),
                    {
                        opcode = logicalOpcode,
                        payloadBytes = string.len(payload),
                    })
                return true, "native"
            end

            SetNativeCollectionWave1RequestState(channelKey, nil)
            RecordCollectionTransportError(channelKey, "request",
                tostring(err))
            LogCollectionTransportEvent("error", logChannel,
                "Collection " .. tostring(channelKey)
                    .. " native request failed",
                { opcode = logicalOpcode, err = tostring(err) })

            if type(DC.Debug) == "function" then
                DC:Debug("RequestNativeCollectionWave1 failed for "
                    .. tostring(channelKey) .. ": " .. tostring(err))
            end

            if not allowAddonFallback then
                return false
            end
        else
            SetNativeCollectionWave1RequestState(channelKey, nil)
            RecordCollectionTransportError(channelKey, "encode",
                "payload encode failed")
            LogCollectionTransportEvent("error", logChannel,
                "Collection " .. tostring(channelKey)
                    .. " native payload encode failed",
                { opcode = logicalOpcode })

            if not allowAddonFallback then
                return false
            end
        end
    elseif not allowAddonFallback then
        SetNativeCollectionWave1RequestState(channelKey, nil)
        RecordCollectionTransportError(channelKey, "request",
            "native bridge unavailable")
        return false
    end

    RecordCollectionTransportRequest(channelKey, "addon", logicalOpcode, 0,
        { expectsReply = expectsReply })
    LogCollectionTransportEvent("info", logChannel,
        "Collection " .. tostring(channelKey) .. " addon request -> "
            .. GetCollectionOpcodeLabel(logicalOpcode),
        { opcode = logicalOpcode })
    local ok = DC:SendMessage(logicalOpcode, data or {})

    if not ok then
        RecordCollectionTransportError(channelKey, "request",
            "addon send failed")
        return false
    end

    if expectsReply and responseOpcode > 0 then
        local opcodeHex = string.format("0x%02X", responseOpcode)
        ScheduleAwaitResponseDiagnostic(DC, {
            requestOpcode = logicalOpcode,
            responseOpcode = responseOpcode,
            sentAt = sentAt,
            timeoutSec = 2.0,
            awaitMessage = "Awaiting " .. tostring(channelKey)
                .. " response (" .. opcodeHex .. ")",
            timeoutMessage = "[Net] Await timeout for "
                .. tostring(channelKey) .. " response (" .. opcodeHex
                .. "); request may have been dropped or rate-limited",
        })
    end

    return true, "addon"
end

local function SendCollectionSavedOutfitsRequest(offset, limit, options)
    options = options or {}

    local allowAddonFallback = options.allowAddonFallback ~= false
    local requestOwner = tostring(options.owner or "collection")
    local sentAt = tonumber(options.sentAt) or 0
    if sentAt == 0 and type(GetTime) == "function" then
        sentAt = GetTime() or 0
    end

    offset = tonumber(offset) or 0
    limit = tonumber(limit) or 6
    if offset < 0 then
        offset = 0
    end
    if limit < 1 then
        limit = 1
    elseif limit > 50 then
        limit = 50
    end

    local payload = {
        offset = offset,
        limit = limit,
    }

    if ShouldUseNativeCollectionSavedOutfitsBridge() then
        EnsureNativeCollectionSavedOutfitsPollFrame()

        local encodedPayload = EncodeNativeCollectionWave1Payload(payload)
        local payloadBytes = type(encodedPayload) == "string"
            and string.len(encodedPayload) or 0
        RecordCollectionTransportRequest("savedOutfits", "native",
            DC.Opcodes.CMSG_GET_SAVED_OUTFITS, payloadBytes)
        local ok, err = pcall(RequestNativeCollectionSavedOutfits, offset,
            limit)
        if ok then
            DC._nativeSavedOutfitsLastRequest = {
                offset = offset,
                limit = limit,
                owner = requestOwner,
            }
            LogCollectionTransportEvent("info", "saved-outfits",
                "Collection saved-outfits native request -> saved_outfits",
                { opcode = DC.Opcodes.CMSG_GET_SAVED_OUTFITS })
            return true
        end

        DC._nativeSavedOutfitsLastRequest = nil
        RecordCollectionTransportError("savedOutfits", "request",
            tostring(err))
        LogCollectionTransportEvent("error", "saved-outfits",
            "Collection saved-outfits native request failed",
            {
                opcode = DC.Opcodes.CMSG_GET_SAVED_OUTFITS,
                err = tostring(err),
            })
        if type(DC.Debug) == "function" then
            DC:Debug("RequestNativeCollectionSavedOutfits failed: "
                .. tostring(err))
        end

        if not allowAddonFallback then
            return false
        end
    elseif not allowAddonFallback then
        RecordCollectionTransportError("savedOutfits", "request",
            "native bridge unavailable")
        return false
    end

    RecordCollectionTransportRequest("savedOutfits", "addon",
        DC.Opcodes.CMSG_GET_SAVED_OUTFITS, 0)
    LogCollectionTransportEvent("info", "saved-outfits",
        "Collection saved-outfits addon request -> saved_outfits",
        { opcode = DC.Opcodes.CMSG_GET_SAVED_OUTFITS })
    local ok = DC:SendMessage(DC.Opcodes.CMSG_GET_SAVED_OUTFITS, payload)

    if ok then
        ScheduleAwaitResponseDiagnostic(DC, {
            requestOpcode = DC.Opcodes.CMSG_GET_SAVED_OUTFITS,
            responseOpcode = DC.Opcodes.SMSG_SAVED_OUTFITS,
            sentAt = sentAt,
            timeoutSec = 2.0,
            awaitMessage = "Awaiting outfits response (0x4C)",
            timeoutMessage = "[Net] Await timeout for outfits response (0x4C); request may have been dropped or rate-limited",
        })
    end

    return ok
end

local function HasNativeCollectionTransmogStateBridge()
    return type(RequestNativeCollectionTransmogState) == "function"
        and type(GetNativeCollectionTransmogStateSnapshot) == "function"
end

local function ShouldUseNativeCollectionTransmogStateBridge()
    if not HasNativeCollectionTransmogStateBridge() then
        return false
    end

    local snapshot = GetCollectionCapabilitySnapshot()
    if type(snapshot) ~= "table" then
        return false
    end

    return HasCapabilityBit(snapshot.clientCaps,
            COLLECTION_TRANSMOG_STATE_NATIVE_CAPABILITY)
        and HasCapabilityBit(snapshot.negotiatedCaps,
            COLLECTION_TRANSMOG_STATE_NATIVE_CAPABILITY)
end

local function DecodeNativeCollectionTransmogState(payload)
    if type(payload) ~= "string" or payload == "" then
        return nil
    end

    local central = GetCollectionCentralProtocol()
    if not central or type(central.DecodeJSON) ~= "function" then
        return nil
    end

    local ok, decoded = pcall(function()
        return central:DecodeJSON(payload)
    end)
    if not ok or type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

local function ConsumeNativeCollectionTransmogStateSnapshot()
    if not ShouldUseNativeCollectionTransmogStateBridge() then
        return false
    end

    local ok, revision, payload = pcall(GetNativeCollectionTransmogStateSnapshot)
    if not ok or revision == nil then
        return false
    end

    revision = tonumber(revision) or 0
    local payloadBytes = type(payload) == "string" and string.len(payload) or 0
    if revision <= 0 or revision == lastNativeTransmogStateRevision then
        return false
    end

    lastNativeTransmogStateRevision = revision

    local decoded = DecodeNativeCollectionTransmogState(payload)
    if type(decoded) ~= "table" then
        RecordCollectionTransportError("transmogState", "decode",
            "invalid native payload")
        LogCollectionTransportEvent("error", "transmog-state",
            "Collection transmog-state native snapshot decode failed",
            { opcode = DC.Opcodes.SMSG_TRANSMOG_STATE, revision = revision })
        DC._nativeTransmogStateLastRequest = nil
        return false
    end

    local matchedRequest = type(DC._nativeTransmogStateLastRequest) == "table"
    RecordCollectionTransportReply("transmogState", "native",
        DC.Opcodes.SMSG_TRANSMOG_STATE, revision, payloadBytes,
        { matchedRequest = matchedRequest })
    if matchedRequest then
        LogCollectionTransportEvent("info", "transmog-state",
            "Collection transmog-state native response <- transmog_state",
            {
                opcode = DC.Opcodes.SMSG_TRANSMOG_STATE,
                revision = revision,
                payloadBytes = payloadBytes,
            })
        DC._nativeTransmogStateLastRequest = nil
    else
        LogCollectionTransportEvent("info", "transmog-state",
            "Collection transmog-state native snapshot observed <- transmog_state",
            {
                opcode = DC.Opcodes.SMSG_TRANSMOG_STATE,
                revision = revision,
                payloadBytes = payloadBytes,
            })
    end

    DC:HandleTransmogState(decoded)
    return true
end

local function EnsureNativeCollectionTransmogStatePollFrame()
    if nativeTransmogStatePollFrame then
        return
    end

    nativeTransmogStatePollFrame = CreateFrame("Frame")
    nativeTransmogStatePollFrame.elapsed = 0
    nativeTransmogStatePollFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < NATIVE_TRANSMOG_STATE_POLL_INTERVAL then
            return
        end

        self.elapsed = 0
        ConsumeNativeCollectionTransmogStateSnapshot()
    end)
end

local function SendCollectionTransmogStateRequest(reason, options)
    options = options or {}
    local allowAddonFallback = options.allowAddonFallback ~= false
    local requestReason = tostring(reason or "collection_transmog_state")

    if ShouldUseNativeCollectionTransmogStateBridge() then
        EnsureNativeCollectionTransmogStatePollFrame()

        RecordCollectionTransportRequest("transmogState", "native",
            DC.Opcodes.CMSG_GET_TRANSMOG_STATE, 0)
        local ok, err = pcall(RequestNativeCollectionTransmogState,
            requestReason)
        if ok then
            DC._nativeTransmogStateLastRequest = {
                reason = requestReason,
            }
            LogCollectionTransportEvent("info", "transmog-state",
                "Collection transmog-state native request -> transmog_state",
                { opcode = DC.Opcodes.CMSG_GET_TRANSMOG_STATE })
            return ok
        end

        DC._nativeTransmogStateLastRequest = nil
        RecordCollectionTransportError("transmogState", "request",
            tostring(err))
        LogCollectionTransportEvent("error", "transmog-state",
            "Collection transmog-state native request failed",
            {
                opcode = DC.Opcodes.CMSG_GET_TRANSMOG_STATE,
                err = tostring(err),
            })
        if type(DC.Debug) == "function" then
            DC:Debug("RequestNativeCollectionTransmogState failed: "
                .. tostring(err))
        end

        if not allowAddonFallback then
            return false
        end
    elseif not allowAddonFallback then
        RecordCollectionTransportError("transmogState", "request",
            "native bridge unavailable")
        return false
    end

    RecordCollectionTransportRequest("transmogState", "addon",
        DC.Opcodes.CMSG_GET_TRANSMOG_STATE, 0)
    DC._nativeTransmogStateLastRequest = nil
    LogCollectionTransportEvent("info", "transmog-state",
        "Collection transmog-state addon request -> transmog_state",
        { opcode = DC.Opcodes.CMSG_GET_TRANSMOG_STATE })
    return DC:SendMessage(DC.Opcodes.CMSG_GET_TRANSMOG_STATE, {})
end

local function HasNativeCollectionItemSetsBridge()
    return type(RequestNativeCollectionItemSets) == "function"
        and type(GetNativeCollectionItemSetsSnapshot) == "function"
end

local function ShouldUseNativeCollectionItemSetsBridge()
    if not HasNativeCollectionItemSetsBridge() then
        return false
    end

    local snapshot = GetCollectionCapabilitySnapshot()
    if type(snapshot) ~= "table" then
        return false
    end

    return HasCapabilityBit(snapshot.clientCaps,
            COLLECTION_ITEM_SETS_NATIVE_CAPABILITY)
        and HasCapabilityBit(snapshot.negotiatedCaps,
            COLLECTION_ITEM_SETS_NATIVE_CAPABILITY)
end

local function DecodeNativeCollectionItemSets(payload)
    if type(payload) ~= "string" or payload == "" then
        return nil
    end

    local central = GetCollectionCentralProtocol()
    if not central or type(central.DecodeJSON) ~= "function" then
        return nil
    end

    local ok, decoded = pcall(function()
        return central:DecodeJSON(payload)
    end)
    if not ok or type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

local function ConsumeNativeCollectionItemSetsSnapshot()
    if not ShouldUseNativeCollectionItemSetsBridge() then
        return false
    end

    local ok, revision, payload = pcall(GetNativeCollectionItemSetsSnapshot)
    if not ok or revision == nil then
        return false
    end

    revision = tonumber(revision) or 0
    local payloadBytes = type(payload) == "string" and string.len(payload) or 0
    if revision <= 0 or revision == lastNativeItemSetsRevision then
        return false
    end

    lastNativeItemSetsRevision = revision

    local decoded = DecodeNativeCollectionItemSets(payload)
    if type(decoded) ~= "table" then
        RecordCollectionTransportError("itemSets", "decode",
            "invalid native payload")
        LogCollectionTransportEvent("error", "item-sets",
            "Collection item-sets native snapshot decode failed",
            { opcode = DC.Opcodes.SMSG_ITEM_SETS, revision = revision })
        return false
    end

    local nativeReq = DC._nativeItemSetsLastRequest
    local isOwnedSnapshot = DC._itemSetsLoading
        or (type(nativeReq) == "table"
            and (nativeReq.owner == "collection"
                or nativeReq.owner == "transport-refresh"))
    if not isOwnedSnapshot then
        RecordCollectionTransportReply("itemSets", "native",
            DC.Opcodes.SMSG_ITEM_SETS, revision, payloadBytes,
            { matchedRequest = false })
        LogCollectionTransportEvent("info", "item-sets",
            "Collection item-sets native snapshot observed <- item_sets",
            {
                opcode = DC.Opcodes.SMSG_ITEM_SETS,
                revision = revision,
                payloadBytes = payloadBytes,
            })
        DC:OnMsg_ItemSets(decoded)
        return true
    end

    RecordCollectionTransportReply("itemSets", "native",
        DC.Opcodes.SMSG_ITEM_SETS, revision, payloadBytes)
    LogCollectionTransportEvent("info", "item-sets",
        "Collection item-sets native response <- item_sets",
        {
            opcode = DC.Opcodes.SMSG_ITEM_SETS,
            revision = revision,
            payloadBytes = payloadBytes,
        })

    if type(nativeReq) == "table" and nativeReq.owner == "transport-refresh"
        and not DC._itemSetsLoading then
        DC._nativeItemSetsLastRequest = nil
        return true
    end

    DC:OnMsg_ItemSets(decoded)
    return true
end

local function EnsureNativeCollectionItemSetsPollFrame()
    if nativeItemSetsPollFrame then
        return
    end

    nativeItemSetsPollFrame = CreateFrame("Frame")
    nativeItemSetsPollFrame.elapsed = 0
    nativeItemSetsPollFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < NATIVE_ITEM_SETS_POLL_INTERVAL then
            return
        end

        self.elapsed = 0
        ConsumeNativeCollectionItemSetsSnapshot()
    end)
end

local function SendItemSetsRequest(payload, options)
    payload = payload or {}
    options = options or {}

    local allowAddonFallback = options.allowAddonFallback ~= false
    local requestOwner = tostring(options.owner or "collection")

    if ShouldUseNativeCollectionItemSetsBridge() then
        local offset = tonumber(payload.offset) or 0
        local limit = tonumber(payload.limit) or tonumber(DC._itemSetsLimit) or 50
        local syncVersion = tonumber(payload.syncVersion or payload.version) or 0
        local packed = payload.packed
        local packedFlag = 1
        if packed == false or packed == 0 or packed == "0" then
            packedFlag = 0
        end

        DC._nativeItemSetsLastRequest = {
            offset = offset,
            limit = limit,
            syncVersion = syncVersion,
            packed = packedFlag,
            owner = requestOwner,
        }

        EnsureNativeCollectionItemSetsPollFrame()

        RecordCollectionTransportRequest("itemSets", "native",
            DC.Opcodes.CMSG_GET_ITEM_SETS, 0)
        local ok, err = pcall(RequestNativeCollectionItemSets,
            offset, limit, syncVersion, packedFlag)
        if ok then
            LogCollectionTransportEvent("info", "item-sets",
                "Collection item-sets native request -> item_sets",
                {
                    opcode = DC.Opcodes.CMSG_GET_ITEM_SETS,
                    offset = offset,
                    limit = limit,
                    syncVersion = syncVersion,
                })
            return ok
        end

        RecordCollectionTransportError("itemSets", "request", tostring(err))
        LogCollectionTransportEvent("error", "item-sets",
            "Collection item-sets native request failed",
            {
                opcode = DC.Opcodes.CMSG_GET_ITEM_SETS,
                err = tostring(err),
                offset = offset,
                limit = limit,
                syncVersion = syncVersion,
            })
        if not ok and type(DC.Debug) == "function" then
            DC:Debug("RequestNativeCollectionItemSets failed: "
                .. tostring(err))
        end

        DC._nativeItemSetsLastRequest = nil
        if not allowAddonFallback then
            return false
        end
    elseif not allowAddonFallback then
        RecordCollectionTransportError("itemSets", "request",
            "native bridge unavailable")
        return false
    end

    RecordCollectionTransportRequest("itemSets", "addon",
        DC.Opcodes.CMSG_GET_ITEM_SETS, 0)
    LogCollectionTransportEvent("info", "item-sets",
        "Collection item-sets addon request -> item_sets",
        { opcode = DC.Opcodes.CMSG_GET_ITEM_SETS })
    return DC:SendMessage(DC.Opcodes.CMSG_GET_ITEM_SETS, payload)
end

function DC:RefreshCollectionTransport()
    local itemSetsLimit = tonumber(self._itemSetsLimit) or 50
    if itemSetsLimit < 10 then
        itemSetsLimit = 10
    elseif itemSetsLimit > 200 then
        itemSetsLimit = 200
    end

    local collectionHash = 0
    if type(self.ComputeCollectionHash) == "function" then
        collectionHash = tonumber(self:ComputeCollectionHash()) or 0
    else
        collectionHash = tonumber(self.collectionHash) or 0
    end

    local results = {
        collectionWave1 = SendCollectionWave1Request(
            self.Opcodes.CMSG_HANDSHAKE,
            { hash = collectionHash },
            { allowAddonFallback = false }),
        shop = SendOwnedCollectionWave1Request("shop",
            self.Opcodes.CMSG_GET_SHOP,
            {
                category = "all",
                omitStatic = (type(self.ShouldUseLocalCollectionShopMetadata) == "function"
                    and self:ShouldUseLocalCollectionShopMetadata()) and 1 or nil,
            },
            {
                allowAddonFallback = false,
                owner = "transport-refresh",
                responseOpcode = self.Opcodes.SMSG_SHOP_DATA,
            }),
        currencies = SendOwnedCollectionWave1Request("currencies",
            self.Opcodes.CMSG_GET_CURRENCIES,
            {},
            {
                allowAddonFallback = false,
                owner = "transport-refresh",
                responseOpcode = self.Opcodes.SMSG_CURRENCIES,
            }),
        shopHistory = SendOwnedCollectionWave1Request("shopHistory",
            self.Opcodes.CMSG_GET_SHOP_HISTORY,
            {
                limit = 1,
                offset = 0,
            },
            {
                allowAddonFallback = false,
                owner = "transport-refresh",
                responseOpcode = self.Opcodes.SMSG_SHOP_HISTORY,
            }),
        wishlist = SendOwnedCollectionWave1Request("wishlist",
            self.Opcodes.CMSG_GET_WISHLIST,
            {},
            {
                allowAddonFallback = false,
                owner = "transport-refresh",
                responseOpcode = self.Opcodes.SMSG_WISHLIST_DATA,
            }),
        community = SendCollectionCommunityRequest(
            self.Opcodes.CMSG_COMMUNITY_GET_LIST,
            {
                offset = 0,
                limit = 1,
                filter = "all",
                sort = "newest",
            },
            {
                allowAddonFallback = false,
                owner = "transport-refresh",
                responseOpcode = self.Opcodes.SMSG_COMMUNITY_LIST,
            }),
        transmogState = SendCollectionTransmogStateRequest(
            "collection_transport_refresh",
            { allowAddonFallback = false }),
        itemSets = SendItemSetsRequest({
            offset = 0,
            limit = itemSetsLimit,
            syncVersion = 0,
            packed = 1,
        }, {
            allowAddonFallback = false,
            owner = "transport-refresh",
        }),
    }

    RefreshCollectionTransportUi()
    return results
end

function DC:GetCollectionTransportDiagnostics()
    local diagnostics = EnsureCollectionTransportDiagnostics()

    local function CopyChannel(channelKey, available, negotiated, revision)
        local source = diagnostics[channelKey] or {}
        local copy = {}
        for key, value in pairs(source) do
            copy[key] = value
        end

        copy.available = available and true or false
        copy.negotiated = negotiated and true or false
        copy.lastRevision = tonumber(revision) or 0
        copy.revision = GetCollectionTransportChannelRevision(copy)
        copy.hasRequest = (tonumber(copy.lastRequestAt) or 0) > 0
        copy.hasReply = (tonumber(copy.lastReplyAt) or 0) > 0
        copy.hasCachedSnapshot = copy.revision > 0 and not copy.hasReply
        copy.statusKey, copy.statusLabel =
            ClassifyCollectionTransportChannel(copy)
        return copy
    end

    return {
        collectionWave1 = CopyChannel("collectionWave1",
            HasNativeCollectionWave1Bridge(),
            ShouldUseNativeCollectionWave1Bridge(),
            lastNativeCollectionWave1Revision),
        shop = CopyChannel("shop",
            HasNativeCollectionWave1Bridge(),
            ShouldUseNativeCollectionWave1Bridge(),
            0),
        currencies = CopyChannel("currencies",
            HasNativeCollectionWave1Bridge(),
            ShouldUseNativeCollectionWave1Bridge(),
            0),
        shopHistory = CopyChannel("shopHistory",
            HasNativeCollectionWave1Bridge(),
            ShouldUseNativeCollectionWave1Bridge(),
            0),
        wishlist = CopyChannel("wishlist",
            HasNativeCollectionWave1Bridge(),
            ShouldUseNativeCollectionWave1Bridge(),
            0),
        purchaseResult = CopyChannel("purchaseResult",
            HasNativeCollectionWave1Bridge(),
            ShouldUseNativeCollectionWave1Bridge(),
            0),
        savedOutfits = CopyChannel("savedOutfits",
            HasNativeCollectionSavedOutfitsBridge(),
            ShouldUseNativeCollectionSavedOutfitsBridge(),
            lastNativeSavedOutfitsRevision),
        community = CopyChannel("community",
            HasNativeCollectionCommunityBridge(),
            ShouldUseNativeCollectionCommunityBridge(),
            lastNativeCommunityRevision),
        transmogState = CopyChannel("transmogState",
            HasNativeCollectionTransmogStateBridge(),
            ShouldUseNativeCollectionTransmogStateBridge(),
            lastNativeTransmogStateRevision),
        itemSets = CopyChannel("itemSets",
            HasNativeCollectionItemSetsBridge(),
            ShouldUseNativeCollectionItemSetsBridge(),
            lastNativeItemSetsRevision),
    }
end

function DC:GetCollectionTransportSummary()
    local diagnostics = self:GetCollectionTransportDiagnostics()

    local function Summarize(label, channel)
        channel = channel or {}
        local mode = channel.negotiated and "N" or "A"
        local text = label .. ":" .. mode

        local statusKey = channel.statusKey or "idle"
        if statusKey == "pending" then
            text = text .. "/pending"
        elseif statusKey == "observed" then
            text = text .. "/observed"
        elseif statusKey == "cached" then
            text = text .. "/cached"
        elseif statusKey == "idle" then
            text = text .. "/idle"
        else
            local lastLabel = channel.lastReplyLabel or channel.lastRequestLabel
            if type(lastLabel) == "string" and lastLabel ~= "" then
                text = text .. "/" .. lastLabel
            else
                text = text .. "/reply"
            end
        end

        local revision = GetCollectionTransportChannelRevision(channel)
        if revision > 0 then
            text = text .. " r" .. tostring(revision)
        end

        if type(channel.lastError) == "string" and channel.lastError ~= "" then
            text = text .. " !"
        end

        return text
    end

    return "Bridge  "
        .. Summarize("W1", diagnostics.collectionWave1) .. "  "
        .. Summarize("Shop", diagnostics.shop) .. "  "
        .. Summarize("Cur", diagnostics.currencies) .. "  "
        .. Summarize("Hist", diagnostics.shopHistory) .. "  "
        .. Summarize("Wish", diagnostics.wishlist) .. "  "
        .. Summarize("Buy", diagnostics.purchaseResult) .. "  "
        .. Summarize("Outfits", diagnostics.savedOutfits) .. "  "
        .. Summarize("Community", diagnostics.community) .. "  "
        .. Summarize("TS", diagnostics.transmogState) .. "  "
        .. Summarize("Sets", diagnostics.itemSets)
end

local function ClearPagingDelayFrame(frame)
    if not frame then
        return
    end

    frame.pendingRequest = nil
    frame.elapsed = 0
    frame:Hide()
end

local function EnsurePagingDelayFrame(owner, fieldName, options)
    local frame = owner[fieldName]
    if frame then
        return frame
    end

    frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame.pendingRequest = nil
    frame:SetScript("OnUpdate", function(delayFrame, elapsed)
        delayFrame.elapsed = (delayFrame.elapsed or 0) + (elapsed or 0)

        local interval = tonumber(options.interval) or 0.2
        if type(options.getInterval) == "function" then
            interval = tonumber(options.getInterval(owner, delayFrame)) or interval
        end

        if delayFrame.elapsed < interval then
            return
        end

        local request = delayFrame.pendingRequest
        if not request then
            ClearPagingDelayFrame(delayFrame)
            return
        end

        if type(options.canSend) == "function" and
           not options.canSend(owner, delayFrame, request) then
            delayFrame.elapsed = 0
            return
        end

        delayFrame.pendingRequest = nil
        delayFrame.elapsed = 0
        delayFrame:Hide()

        if type(options.sendRequest) == "function" then
            options.sendRequest(owner, request)
        end
    end)

    owner[fieldName] = frame
    return frame
end

local function QueuePagingDelayRequest(owner, fieldName, request, options)
    local frame = EnsurePagingDelayFrame(owner, fieldName, options)
    frame.pendingRequest = request
    frame.elapsed = 0
    frame:Show()
    return frame
end

local function ResetPagingDelayTimer(owner, fieldName)
    local frame = owner and owner[fieldName]
    if not frame then
        return
    end

    frame.elapsed = 0
end

local function CancelPagingDelayRequest(owner, fieldName)
    local frame = owner and owner[fieldName]
    if not frame then
        return
    end

    ClearPagingDelayFrame(frame)
end

local function GetTransmogPagingVisibilityState(owner)
    local wardrobeVisible = (owner.Wardrobe and owner.Wardrobe.frame and owner.Wardrobe.frame:IsShown())
    if wardrobeVisible and owner.Wardrobe and
       (owner.Wardrobe.currentTab == "outfits" or owner.Wardrobe.currentTab == "community") then
        wardrobeVisible = false
    end

    local mainFrameVisible = (owner.MainFrame and owner.MainFrame:IsShown()) and true or false
    local mainTabVisible = (mainFrameVisible and (owner.activeTab == "wardrobe" or owner.activeTab == "transmog")) and true or false
    local collectionUiVisible = mainFrameVisible

    local allowBackground = false
    if type(owner.IsBackgroundWardrobeSyncEnabled) == "function" then
        allowBackground = owner:IsBackgroundWardrobeSyncEnabled() and true or false
    elseif DCCollectionDB and DCCollectionDB.backgroundWardrobeSync then
        allowBackground = true
    end

    local isManualRefresh = owner.Wardrobe and owner.Wardrobe.isRefreshing

    return wardrobeVisible, mainTabVisible, collectionUiVisible, allowBackground, isManualRefresh
end

local function GetTransmogPagingDelayInterval(owner)
    local wardrobeVisible, mainTabVisible, collectionUiVisible =
        GetTransmogPagingVisibilityState(owner)

    local interval = owner._transmogPagingInterval or 0.75
    if not (wardrobeVisible or mainTabVisible or collectionUiVisible) then
        interval = math.max(interval, 1.25)
    end

    return interval
end

local function CanSendTransmogPagingRequest(owner)
    local now = (type(GetTime) == "function" and GetTime()) or
        (type(time) == "function" and time()) or 0
    local pauseUntil = tonumber(owner._pauseTransmogPagingUntil or 0) or 0
    if pauseUntil > 0 and now > 0 and now < pauseUntil then
        return false
    end

    local wardrobeVisible, mainTabVisible, collectionUiVisible, allowBackground, isManualRefresh =
        GetTransmogPagingVisibilityState(owner)

    if not (wardrobeVisible or mainTabVisible or collectionUiVisible or isManualRefresh) and
       not allowBackground then
        return false
    end

    return true
end

local TRANSMOG_PAGING_DELAY_OPTIONS = {
    interval = 0.75,
    getInterval = function(owner)
        return GetTransmogPagingDelayInterval(owner)
    end,
    canSend = function(owner)
        return CanSendTransmogPagingRequest(owner)
    end,
    sendRequest = function(owner, request)
        owner:SendMessage(owner.Opcodes.CMSG_GET_DEFINITIONS, {
            type = "transmog",
            offset = request.offset,
            limit = request.limit,
        })
    end,
}

local ITEM_SETS_PAGING_DELAY_OPTIONS = {
    interval = 0.2,
    sendRequest = function(_, request)
        SendItemSetsRequest({
            offset = request.offset,
            limit = request.limit,
            packed = 1,
        })
    end,
}

local function ScheduleAwaitResponseDiagnostic(owner, options)
    if not owner or type(owner.After) ~= "function" or type(options) ~= "table" then
        return
    end

    local requestOpcode = tonumber(options.requestOpcode) or 0
    local responseOpcode = tonumber(options.responseOpcode) or 0
    local sentAt = tonumber(options.sentAt) or 0
    local timeoutSec = tonumber(options.timeoutSec) or 2.0
    local awaitMessage = tostring(options.awaitMessage or "Awaiting response")
    local timeoutMessage = tostring(options.timeoutMessage or (awaitMessage .. " timed out"))

    owner._awaitDiagnostics = owner._awaitDiagnostics or {}
    local stateKey = tostring(responseOpcode)
    local state = owner._awaitDiagnostics[stateKey] or {}
    local token = (tonumber(state.token) or 0) + 1
    state.token = token

    local now = sentAt
    if now <= 0 then
        now = (type(GetTime) == "function" and GetTime()) or
            (type(time) == "function" and time()) or 0
    end

    local lastAwaitLoggedAt = tonumber(state.awaitLoggedAt) or 0
    if type(owner.LogNetEvent) == "function" and
       (now <= 0 or lastAwaitLoggedAt <= 0 or (now - lastAwaitLoggedAt) >= 1.0) then
        owner:LogNetEvent("info", "await", awaitMessage, {
            opcode = requestOpcode,
            responseOpcode = responseOpcode,
        })
        state.awaitLoggedAt = now
    end

    owner._awaitDiagnostics[stateKey] = state

    owner.After(timeoutSec, function()
        local liveState = owner._awaitDiagnostics and owner._awaitDiagnostics[stateKey]
        if type(liveState) ~= "table" or tonumber(liveState.token) ~= token then
            return
        end

        owner._lastRecvOpcodeAt = owner._lastRecvOpcodeAt or {}
        local lastRecvAt = tonumber(owner._lastRecvOpcodeAt[responseOpcode] or 0) or 0
        if sentAt > 0 and lastRecvAt >= sentAt then
            return
        end

        local pending = owner.pendingRequests and owner.pendingRequests[requestOpcode]
        local pendingSentAt = tonumber(pending and pending.sentAt or 0) or 0
        if sentAt > 0 and pendingSentAt > sentAt then
            return
        end

        local warnAt = (type(GetTime) == "function" and GetTime()) or
            (type(time) == "function" and time()) or 0
        local lastWarnAt = tonumber(liveState.warnedAt) or 0
        if warnAt > 0 and lastWarnAt > 0 and (warnAt - lastWarnAt) < timeoutSec then
            return
        end

        liveState.warnedAt = warnAt

        if type(owner.LogNetEvent) == "function" then
            owner:LogNetEvent("warn", "await", timeoutMessage, {
                opcode = requestOpcode,
                responseOpcode = responseOpcode,
                timeoutSec = timeoutSec,
            })
        end
        if type(owner.Debug) == "function" then
            owner:Debug(timeoutMessage)
        end
    end)
end

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

        local extra = (e and e.extra) or nil
        local op = extra and extra.opcode
        local opTxt = ""
        if op ~= nil then
            op = tonumber(op) or op
            if type(op) == "number" then
                opTxt = string.format(" opcode=0x%02X", op)
            else
                opTxt = " opcode=" .. tostring(op)
            end
        end

        self:Print(string.format("[NetLog] %s [%s%s]%s %s", ts, lvl, tg, opTxt, msg))
    end
end

-- ============================================================================
-- PROTOCOL INITIALIZATION
-- ============================================================================

function DC:InitializeProtocol()
    if self.isConnected then
        return true
    end

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
    registerOpcode(self.Opcodes.SMSG_SHOP_HISTORY)
    registerOpcode(self.Opcodes.SMSG_WISHLIST_DATA)
    registerOpcode(self.Opcodes.SMSG_WISHLIST_AVAILABLE)
    registerOpcode(self.Opcodes.SMSG_WISHLIST_UPDATED)
    registerOpcode(self.Opcodes.SMSG_OPEN_UI)
    registerOpcode(self.Opcodes.SMSG_ERROR)
    
    registerOpcode(self.Opcodes.SMSG_COMMUNITY_LIST)
    registerOpcode(self.Opcodes.SMSG_COMMUNITY_PUBLISH_RESULT)
    registerOpcode(self.Opcodes.SMSG_COMMUNITY_UPDATE_RESULT)
    registerOpcode(self.Opcodes.SMSG_COMMUNITY_DELETE_RESULT)
    registerOpcode(self.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT)
    registerOpcode(self.Opcodes.SMSG_INSPECT_TRANSMOG)
    registerOpcode(self.Opcodes.SMSG_ITEM_SETS)
    registerOpcode(self.Opcodes.SMSG_SAVED_OUTFITS)

    -- Diagnostics: also register the request opcodes used by Wardrobe (Outfits/Community).
    -- If these are ever received client-side, it typically means the server did NOT handle the message
    -- and the whisper got echoed back to the player as a normal addon whisper.
    registerOpcode(self.Opcodes.CMSG_GET_SAVED_OUTFITS)
    registerOpcode(self.Opcodes.CMSG_COMMUNITY_GET_LIST)


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
        if type(self.LogNetEvent) == "function" then
            self:LogNetEvent("warn", "send", "Cannot send message - not connected", { opcode = opcode })
        end
        -- Surface this even when debugMode is off (throttled).
        local now = (type(GetTime) == "function") and GetTime() or 0
        if not self._lastNotConnectedWarnAt or (now - self._lastNotConnectedWarnAt) > 5 then
            self._lastNotConnectedWarnAt = now
            self:Print(string.format("[Net] Not connected; cannot send opcode 0x%02X", tonumber(opcode) or 0))
        end
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

            if type(self.LogNetEvent) == "function" then
                self:LogNetEvent("info", "send", string.format("Sent opcode 0x%02X", tonumber(opcode) or 0), { opcode = opcode })
            end

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
        if type(self.LogNetEvent) == "function" then
            self:LogNetEvent("info", "send", string.format("Sent opcode 0x%02X", tonumber(opcode) or 0), { opcode = opcode })
        end
        self.pendingRequests[opcode] = {
            sentAt = GetTime(),
            data = data,
        }
        return true
    end

    self:Debug("Failed to send message: " .. tostring(err))
    self:Print(string.format("[Net] Send failed for opcode 0x%02X: %s", tonumber(opcode) or 0, tostring(err)))
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

function DC:BeginSyncProgress(mode, plannedSteps)
    self._syncProgressHideToken = (self._syncProgressHideToken or 0) + 1

    local progress = {
        mode = mode or "sync",
        active = true,
        total = 0,
        completed = 0,
        currentKey = nil,
        currentLabel = nil,
        steps = {},
    }

    if type(plannedSteps) == "table" then
        for _, step in ipairs(plannedSteps) do
            if type(step) == "table" and step.key then
                local key = tostring(step.key)
                if not progress.steps[key] then
                    progress.steps[key] = {
                        label = tostring(step.label or key),
                        done = false,
                    }
                    progress.total = progress.total + 1
                end
            end
        end
    end

    self._syncProgress = progress
    self:RefreshSyncProgressUI(true)
end

function DC:_EnsureSyncProgressState()
    if type(self._syncProgress) ~= "table" then
        self:BeginSyncProgress("adhoc")
    end
    return self._syncProgress
end

function DC:_EnsureSyncProgressStep(stepKey, label)
    if not stepKey then
        return nil
    end

    local progress = self:_EnsureSyncProgressState()
    local key = tostring(stepKey)
    local step = progress.steps[key]
    if not step then
        step = {
            label = tostring(label or key),
            done = false,
        }
        progress.steps[key] = step
        progress.total = (progress.total or 0) + 1
    elseif label and label ~= "" then
        step.label = tostring(label)
    end

    if (progress.total or 0) < (progress.completed or 0) then
        progress.total = progress.completed
    end

    return key, step, progress
end

function DC:StartSyncProgressStep(stepKey, label)
    local key, step, progress = self:_EnsureSyncProgressStep(stepKey, label)
    if not key then
        return
    end

    progress.active = true
    progress.currentKey = key
    progress.currentLabel = step.label or tostring(label or key)
    self:RefreshSyncProgressUI(true)
end

function DC:CompleteSyncProgressStep(stepKey, label)
    local key, step, progress = self:_EnsureSyncProgressStep(stepKey, label)
    if not key then
        return
    end

    if step and not step.done then
        step.done = true
        progress.completed = (progress.completed or 0) + 1
    end

    if key == progress.currentKey then
        progress.currentLabel = step.label or progress.currentLabel
    end

    if (progress.total or 0) <= 0 then
        progress.total = progress.completed
    end

    if (progress.completed or 0) >= (progress.total or 0) then
        progress.active = nil
        self:RefreshSyncProgressUI(true)

        local token = (self._syncProgressHideToken or 0) + 1
        self._syncProgressHideToken = token
        if self.After and type(self.After) == "function" then
            self.After(1.25, function()
                if self._syncProgressHideToken ~= token then
                    return
                end
                self._syncProgress = nil
                self:RefreshSyncProgressUI(false)
            end)
        else
            self._syncProgress = nil
            self:RefreshSyncProgressUI(false)
        end
    else
        self:RefreshSyncProgressUI(true)
    end
end

function DC:AbortSyncProgress()
    self._syncProgressHideToken = (self._syncProgressHideToken or 0) + 1
    self._syncProgress = nil
    self:RefreshSyncProgressUI(false)
end

function DC:GetSyncProgressSnapshot()
    local progress = self._syncProgress
    if type(progress) ~= "table" then
        return nil
    end

    return {
        active = progress.active and true or false,
        mode = progress.mode,
        total = tonumber(progress.total) or 0,
        completed = tonumber(progress.completed) or 0,
        currentLabel = progress.currentLabel or progress.currentKey,
    }
end

function DC:_GetSyncProgressStagePrefix(stepKey)
    local key = tostring(stepKey or "")

    if string.sub(key, 1, 5) == "defs:" then
        if key == "defs:transmog" then
            return "|TInterface\\Icons\\INV_Chest_Cloth_17:12:12:0:0|t [APP]"
        end
        return "|TInterface\\Icons\\INV_Misc_Book_09:12:12:0:0|t [DEF]"
    elseif string.sub(key, 1, 5) == "coll:" then
        if key == "coll:transmog" then
            return "|TInterface\\Icons\\INV_Chest_Cloth_17:12:12:0:0|t [WRD]"
        end
        return "|TInterface\\Icons\\INV_Chest_Cloth_17:12:12:0:0|t [COL]"
    elseif key == "currency" then
        return "|TInterface\\Icons\\INV_Misc_Coin_01:12:12:0:0|t [CUR]"
    elseif key == "stats" then
        return "|TInterface\\Icons\\INV_Misc_Note_01:12:12:0:0|t [STAT]"
    elseif key == "shop" then
        return "|TInterface\\Icons\\INV_Misc_Coin_02:12:12:0:0|t [SHOP]"
    elseif key == "wishlist" then
        return "|TInterface\\Icons\\INV_Misc_Note_05:12:12:0:0|t [WISH]"
    elseif key == "handshake" then
        return "|TInterface\\Icons\\Spell_Holy_SealOfMight:12:12:0:0|t [HS]"
    end

    return "|TInterface\\Buttons\\UI-GuildButton-PublicNote-Up:12:12:0:0|t [SYNC]"
end

function DC:_GetSyncProgressDisplayLabel(stepKey, currentLabel)
    local key = tostring(stepKey or "")
    local label = tostring(currentLabel or stepKey or "collection data")

    label = string.gsub(label, "transmog", "wardrobe appearances")

    if string.sub(key, 1, 5) == "defs:" then
        label = string.gsub(label, "^definitions:%s*", "")
    elseif string.sub(key, 1, 5) == "coll:" then
        label = string.gsub(label, "^collection:%s*", "")
    end

    return label
end

function DC:RefreshSyncProgressUI(forceShow)
    if not (self.MainFrame and self.MainFrame.topLoadBar and self.MainFrame.topLoadText) then
        return
    end

    local bar = self.MainFrame.topLoadBar
    local text = self.MainFrame.topLoadText
    local progress = self._syncProgress

    if type(progress) ~= "table" then
        if not forceShow then
            bar:Hide()
        end
        return
    end

    local total = tonumber(progress.total) or 0
    local completed = tonumber(progress.completed) or 0

    if total < completed then
        total = completed
    end
    if total <= 0 then
        total = 1
    end
    if completed < 0 then
        completed = 0
    end
    if completed > total then
        completed = total
    end

    local pct = math.floor((completed / total) * 100)
    local stageKey = progress.currentKey
    local label = self:_GetSyncProgressDisplayLabel(stageKey,
        progress.currentLabel or progress.currentKey or "collection data")
    local prefix = self:_GetSyncProgressStagePrefix(stageKey)

    bar:Show()
    bar:SetMinMaxValues(0, total)
    bar:SetValue(completed)

    if progress.active then
        text:SetText(string.format("Syncing %s %s (%d/%d, %d%%)",
            prefix,
            tostring(label),
            completed,
            total,
            pct))
    else
        text:SetText(string.format("Sync complete (%d/%d)", completed, total))
    end
end

-- Track the first transmog definitions page so dropped initial responses don't
-- leave paging stuck with no visible protocol timeout.
function DC:_EnsureTransmogFirstPageWatchdog()
    if self._transmogFirstPageWatchdogFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(f, elapsed)
        f.elapsed = (f.elapsed or 0) + (elapsed or 0)
        if f.elapsed < 1.0 then
            return
        end
        f.elapsed = 0

        if not DC._transmogDefAwaitingFirstPage then
            f:Hide()
            return
        end

        local now = (type(GetTime) == "function" and GetTime()) or (type(time) == "function" and time()) or 0
        local startedAt = tonumber(DC._transmogDefStartedAt or 0) or 0
        if now <= 0 or startedAt <= 0 then
            return
        end

        local timeoutSec = tonumber(DC._transmogFirstPageTimeoutSec) or 15
        if (now - startedAt) < timeoutSec then
            return
        end

        local retryCount = tonumber(DC._transmogFirstPageRetryCount) or 0
        if retryCount >= 2 then
            if type(DC.LogNetEvent) == "function" then
                DC:LogNetEvent("error", "wardrobe", "Transmog first page timed out (max retries reached)", {
                    retries = retryCount,
                })
            end
            if type(DC.AbortTransmogDefinitionsPaging) == "function" then
                DC:AbortTransmogDefinitionsPaging("first_page_timeout_max_retries")
            else
                DC._transmogDefLoading = nil
                DC._transmogDefAwaitingFirstPage = nil
            end
            f:Hide()
            return
        end

        DC._transmogFirstPageRetryCount = retryCount + 1
        if type(DC.LogNetEvent) == "function" then
            DC:LogNetEvent("warn", "wardrobe", "Transmog first page timed out; retrying", {
                retry = DC._transmogFirstPageRetryCount,
            })
        end

        -- Adaptive fallback: reduce page size after first-page timeout so oversized
        -- transmog payloads can still complete on strict clients/transports.
        do
            local currentLimit = tonumber(DC._transmogDefLimit) or 250
            if currentLimit > 50 then
                local nextLimit = math.floor(currentLimit / 2)
                if nextLimit < 50 then
                    nextLimit = 50
                end
                if nextLimit < currentLimit then
                    DC._transmogDefLimit = nextLimit
                    if type(DC.LogNetEvent) == "function" then
                        DC:LogNetEvent("warn", "wardrobe", "Reducing transmog first-page limit after timeout", {
                            oldLimit = currentLimit,
                            newLimit = nextLimit,
                            retry = DC._transmogFirstPageRetryCount,
                        })
                    end
                end
            end
        end

        if type(DC.AbortTransmogDefinitionsPaging) == "function" then
            DC:AbortTransmogDefinitionsPaging("first_page_timeout_retry")
        else
            DC._transmogDefLoading = nil
            DC._transmogDefAwaitingFirstPage = nil
        end

        if type(DC.RequestDefinitions) == "function" then
            DC:RequestDefinitions("transmog", 0)
        end

        f:Hide()
    end)

    self._transmogFirstPageWatchdogFrame = frame
end

function DC:_StartTransmogFirstPageWatchdog()
    self:_EnsureTransmogFirstPageWatchdog()
    if self._transmogFirstPageWatchdogFrame then
        self._transmogFirstPageWatchdogFrame.elapsed = 0
        self._transmogFirstPageWatchdogFrame:Show()
    end
end

function DC:_StopTransmogFirstPageWatchdog(resetRetries)
    if self._transmogFirstPageWatchdogFrame then
        self._transmogFirstPageWatchdogFrame:Hide()
        self._transmogFirstPageWatchdogFrame.elapsed = 0
    end
    self._transmogDefAwaitingFirstPage = nil
    if resetRetries then
        self._transmogFirstPageRetryCount = 0
    end
end

-- Perform initial handshake with server
function DC:RequestHandshake()
    local hash = self:ComputeCollectionHash()
    self._lastHandshakeHash = hash
    if type(self.GetHandshakeCollectionSnapshot) == "function" then
        local snapshot = self:GetHandshakeCollectionSnapshot()
        self._lastHandshakeCounts = snapshot and snapshot.counts or nil
    else
        self._lastHandshakeCounts = nil
    end
    if type(self._syncProgress) == "table" then
        self:StartSyncProgressStep("handshake", "handshake")
    end

    local ok = SendCollectionWave1Request(self.Opcodes.CMSG_HANDSHAKE, {
        hash = hash,
    })
    if not ok and type(self._syncProgress) == "table" then
        self:CompleteSyncProgressStep("handshake", "handshake (failed)")
    end
    return ok
end

-- Request full collection data
function DC:RequestFullCollection()
    return SendCollectionWave1Request(self.Opcodes.CMSG_GET_FULL_COLLECTION,
        {})
end

-- Request delta sync (server will compare hashes)
function DC:RequestSyncCollection()
    local hash = self:ComputeCollectionHash()
    return SendCollectionWave1Request(self.Opcodes.CMSG_SYNC_COLLECTION, {
        hash = hash,
    })
end

-- Request collection statistics
function DC:RequestStats()
    local key = "req:stats"
    local progressKey = "stats"
    local progressLabel = "stats"
    if self:_IsInflight(key) then
        return false
    end

    local now = (type(GetTime) == "function" and GetTime()) or
        (type(time) == "function" and time()) or 0
    local lastReceivedAt = tonumber(self._statsLastReceivedAt) or 0
    if now > 0 and lastReceivedAt > 0 and (now - lastReceivedAt) < 3.0 then
        if type(self._syncProgress) == "table" then
            self:CompleteSyncProgressStep(progressKey, progressLabel)
        end
        return true
    end

    self:_DebounceRequest(key, 0.30, function()
        if self:_IsInflight(key) then
            -- A previous request is still in flight; complete the progress step
            -- so the sync bar doesn't get stuck waiting for a second response.
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep(progressKey, progressLabel)
            end
            return
        end
        if type(self._syncProgress) == "table" then
            self:StartSyncProgressStep(progressKey, progressLabel)
        end
        self:_MarkInflight(key, true)

        -- Bump watchdog token so any leftover timer from a previous request is
        -- cancelled when it fires and sees a mismatched token.
        self._statsWatchdogToken = (self._statsWatchdogToken or 0) + 1
        local watchdogToken = self._statsWatchdogToken

        local ok = SendCollectionWave1Request(self.Opcodes.CMSG_GET_STATS,
            {})
        if not ok then
            self:_MarkInflight(key, nil)
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep(progressKey,
                    progressLabel .. " (failed)")
            end
        elseif self.After and type(self.After) == "function" then
            -- Watchdog: if the server doesn't respond within 10 s (e.g. the
            -- response was overwritten in the single-slot native bridge before
            -- the Lua poll frame consumed it), force-complete the step so the
            -- sync bar is not permanently stuck at 12/13.
            self.After(10.0, function()
                if (self._statsWatchdogToken or 0) ~= watchdogToken then
                    return
                end
                if not self:_IsInflight(key) then
                    return
                end
                self:_MarkInflight(key, nil)
                if type(self._syncProgress) == "table" then
                    self:CompleteSyncProgressStep(progressKey, progressLabel)
                end
            end)
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
        local ok = SendCollectionWave1Request(self.Opcodes.CMSG_GET_BONUSES,
            {})
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
        -- Use canonical server type names to avoid double-sending and rate-limit pressure.
        self:RequestDefinitions("mount")
        self:RequestDefinitions("pet")
        self:RequestDefinitions("heirloom")
        self:RequestDefinitions("title")
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
    local progressKey = "defs:" .. tostring(normalizedType)
    local progressLabel = "definitions: " .. tostring(normalizedType)

    if normalizedType == "transmog" and
       type(self.GetCollectionDataFeaturePolicy) == "function" then
        local policy = self:GetCollectionDataFeaturePolicy("transmog")
        if type(policy) == "table" and
           (policy.state == "DISABLED_STALE_CLIENT_DATA" or
            policy.state == "DISABLED_UNSUPPORTED_CLIENT") then
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep(progressKey,
                    progressLabel .. " (disabled)")
            end
            self:Print(string.format(
                "[Collection] Transmog definitions disabled (%s).",
                tostring(policy.reason or policy.state)))
            return false
        end
    end

    if type(self.HasLocalCollectionDefinitions) == "function" and
       self:HasLocalCollectionDefinitions(normalizedType) then
        if type(self._syncProgress) == "table" then
            self:CompleteSyncProgressStep(progressKey, progressLabel .. " (local)")
        end
        self:Debug(string.format("RequestDefinitions(%s): using local CDBC metadata",
            tostring(serverType)))
        return true
    end

    -- Avoid spamming the same request while waiting for a response.
    if self:_IsInflight(reqKey) then
        return false
    end

    if serverType == "transmog" then
        local forceTransmogRequest = (tonumber(clientSyncVersion) == 0)

        -- Guard against background re-polls after we already confirmed
        -- transmog definitions are current. Manual refreshes pass
        -- clientSyncVersion=0 and bypass this cooldown.
        if not forceTransmogRequest and type(self._HasAnyTransmogDefinitions) == "function" and
           self:_HasAnyTransmogDefinitions() then
            local now = (type(GetTime) == "function" and GetTime()) or
                (type(time) == "function" and time()) or 0
            local lastConfirmed = tonumber(self._transmogDefsConfirmedCurrentAt) or 0
            local cooldownSec = tonumber(self._transmogDefsAutoRequestCooldownSec) or 180
            if now > 0 and lastConfirmed > 0 and (now - lastConfirmed) < cooldownSec then
                return false
            end
        end

        -- Don't restart a transmog paging run while already loading.
        if self._transmogDefLoading then
            return false
        end

        self:_DebounceRequest(reqKey, 0.10, function()
            if self._transmogDefLoading then
                return
            end
            if type(self._syncProgress) == "table" then
                self:StartSyncProgressStep(progressKey, progressLabel)
            end
            self:_MarkInflight(reqKey, true)
            self._transmogDefOffset = 0
            -- Transmog definitions are huge; keep pages small to avoid client freezes and server hitching.
            self._transmogDefLimit = tonumber(self._transmogDefLimit) or 250
            if self._transmogDefLimit < 50 then self._transmogDefLimit = 50 end
            if self._transmogDefLimit > 250 then self._transmogDefLimit = 250 end
            self._transmogDefLoading = true
            self._transmogDefTotal = nil
            self._transmogDefLastRequestedOffset = 0
            self._transmogDefLastRequestedLimit = self._transmogDefLimit
            self._transmogDefPagesFetched = 0
            self._transmogDefStartedAt = (type(GetTime) == "function" and GetTime()) or time()
            self._transmogDefLastReceivedAt = nil
            self._transmogDefAwaitingFirstPage = true
            self._transmogFirstPageRetryCount = 0
            self:_StartTransmogFirstPageWatchdog()

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
            if v and v > 0 and self:_HasAnyTransmogDefinitions() then
                payload.syncVersion = v
            end

            local ok = self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, payload)
            if not ok then
                self._transmogDefLoading = nil
                self:_StopTransmogFirstPageWatchdog(false)
                self:_MarkInflight(reqKey, nil)
                self._transmogDefStartedAt = nil
                self._transmogDefLastReceivedAt = nil

                if type(self._syncProgress) == "table" then
                    self:CompleteSyncProgressStep(progressKey, progressLabel .. " (failed)")
                end

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

        -- Short-circuit: if the server already told us its syncVersion via the
        -- handshake ACK AND our local version matches AND we already have
        -- cached definitions for this type, skip the request entirely.
        if type(self._serverSyncVersions) == "table" then
            local serverVer
            if normalizedType == "mounts" or serverType == "mount" then
                serverVer = tonumber(self._serverSyncVersions.mounts or self._serverSyncVersions.mount)
            elseif normalizedType == "pets" or serverType == "pet" then
                serverVer = tonumber(self._serverSyncVersions.pets or self._serverSyncVersions.pet)
            elseif normalizedType == "heirlooms" or serverType == "heirloom" then
                serverVer = tonumber(self._serverSyncVersions.heirlooms or self._serverSyncVersions.heirloom)
            elseif normalizedType == "titles" or serverType == "title" then
                serverVer = tonumber(self._serverSyncVersions.titles or self._serverSyncVersions.title)
            end

            if serverVer and serverVer > 0 then
                local localVer = tonumber(self:GetSyncVersion(serverType)) or 0
                local hasCached = false
                if type(self.definitions) == "table" then
                    local bucket = self.definitions[normalizedType] or self.definitions[serverType]
                    if type(bucket) == "table" and next(bucket) ~= nil then
                        hasCached = true
                    end
                end
                if localVer == serverVer and hasCached then
                    if type(self._syncProgress) == "table" then
                        self:CompleteSyncProgressStep(progressKey, progressLabel .. " (cached)")
                    end
                    self:Debug(string.format("RequestDefinitions(%s): up-to-date (v=%d), skipping", tostring(serverType), serverVer))
                    return
                end
            end
        end

        if type(self._syncProgress) == "table" then
            self:StartSyncProgressStep(progressKey, progressLabel)
        end
        self:_MarkInflight(reqKey, true)

        local payload = { type = serverType }
        local v = clientSyncVersion
        if v == nil then
            v = self:GetSyncVersion(serverType)
        end
        if type(v) ~= "number" then
            v = tonumber(v)
        end
        if v and v > 0 then
            payload.syncVersion = v
        end

        local ok = self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, payload)
        if not ok then
            self:_MarkInflight(reqKey, nil)
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep(progressKey, progressLabel .. " (failed)")
            end
        end
    end)
    return true
end

-- Abort any in-progress transmog definitions paging.
-- This is used by Wardrobe refresh retry logic to recover from dropped/never-replied requests.
function DC:AbortTransmogDefinitionsPaging(reason)
    -- Clear paging state
    self._transmogDefLoading = nil
    self:_StopTransmogFirstPageWatchdog(false)
    self._transmogDefOffset = nil
    self._transmogDefLastRequestedOffset = nil
    self._transmogDefLastRequestedLimit = nil
    self._transmogDefPagesFetched = 0
    self._transmogDefStartedAt = nil
    self._transmogDefLastReceivedAt = nil
    -- Do not clear _transmogClearOnFirstPage here: retries during a manual refresh
    -- should still clear when the first page arrives. Callers can unset it when needed.

    CancelPagingDelayRequest(self, "_transmogPagingDelayFrame")

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

    if type(self.HasLocalCollectionDefinitions) == "function" and
       self:HasLocalCollectionDefinitions("transmog") then
        DCCollectionDB = DCCollectionDB or {}
        DCCollectionDB.transmogDefsIncomplete = nil
        DCCollectionDB.transmogDefsResumeOffset = nil
        DCCollectionDB.transmogDefsResumeLimit = nil
        DCCollectionDB.transmogDefsResumeTotal = nil
        DCCollectionDB.transmogDefsResumeUpdatedAt = nil
        return false
    end

    DCCollectionDB = DCCollectionDB or {}
    if not DCCollectionDB.transmogDefsIncomplete then
        return false
    end

    local offset = tonumber(DCCollectionDB.transmogDefsResumeOffset) or 0
    local limit = tonumber(DCCollectionDB.transmogDefsResumeLimit) or tonumber(self._transmogDefLimit) or 250
    if offset < 0 then offset = 0 end
    if limit < 50 then limit = 50 end
    if limit > 250 then limit = 250 end

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

    self._transmogDefAwaitingFirstPage = true
    self._transmogFirstPageRetryCount = 0
    self:_StartTransmogFirstPageWatchdog()

    if reason and type(self.Debug) == "function" then
        self:Debug("Resuming transmog definitions paging: " .. tostring(reason) .. " (offset=" .. tostring(offset) .. ", limit=" .. tostring(limit) .. ")")
    end

    local ok = self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "transmog", offset = offset, limit = limit })
    if not ok then
        self._transmogDefLoading = nil
        self:_StopTransmogFirstPageWatchdog(false)
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
        -- Use canonical server type names to avoid double-sending and rate-limit pressure.
        self:RequestCollection("mount")
        self:RequestCollection("pet")
        self:RequestCollection("heirloom")
        self:RequestCollection("title")
        self:RequestCollection("transmog")
        return
    end

    local normalizedType = (type(self.NormalizeCollectionType) == "function" and self:NormalizeCollectionType(collType)) or collType

    if normalizedType == "transmog" and type(self.RequestCollectedAppearances) == "function" then
        return self:RequestCollectedAppearances()
    end

    -- Server commonly uses singular names.
    local serverType = normalizedType
    if normalizedType == "mounts" then serverType = "mount"
    elseif normalizedType == "pets" then serverType = "pet"
    elseif normalizedType == "heirlooms" then serverType = "heirloom"
    elseif normalizedType == "titles" then serverType = "title"
    end

    if serverType ~= "transmog" then
        local now = (type(GetTime) == "function" and GetTime()) or
            (type(time) == "function" and time()) or 0
        local lastReceivedAt = 0
        if type(self._collectionLastReceivedAt) == "table" then
            lastReceivedAt = tonumber(
                self._collectionLastReceivedAt[normalizedType] or
                self._collectionLastReceivedAt[serverType]) or 0
        end
        if serverType == "title" and lastReceivedAt <= 0 then
            lastReceivedAt = tonumber(self._titleCollectionLastReceivedAt) or 0
        end
        if now > 0 and lastReceivedAt > 0 and (now - lastReceivedAt) < 3.0 then
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep("coll:" .. tostring(normalizedType),
                    "collection: " .. tostring(normalizedType))
            end
            return true
        end
    end

    local reqKey = "req:coll:" .. tostring(normalizedType)
    local progressKey = "coll:" .. tostring(normalizedType)
    local progressLabel = "collection: " .. tostring(normalizedType)
    if self:_IsInflight(reqKey) then
        return false
    end

    self:_DebounceRequest(reqKey, 0.10, function()
        if self:_IsInflight(reqKey) then
            return
        end
        if type(self._syncProgress) == "table" then
            self:StartSyncProgressStep(progressKey, progressLabel)
        end
        self:_MarkInflight(reqKey, true)

        local ok = SendCollectionWave1Request(
            self.Opcodes.CMSG_GET_COLLECTION, { type = serverType })
        if not ok then
            self:_MarkInflight(reqKey, nil)
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep(progressKey, progressLabel .. " (failed)")
            end
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
        if type(self._syncProgress) == "table" then
            self:StartSyncProgressStep("shop", "shop data")
        end
        self:_MarkInflight(reqKey, true)
        local payload = {
            category = category or "all",
        }

        if type(self.ShouldUseLocalCollectionShopMetadata) == "function" and
           self:ShouldUseLocalCollectionShopMetadata() then
            payload.omitStatic = 1
        end

        local ok = SendOwnedCollectionWave1Request("shop",
            self.Opcodes.CMSG_GET_SHOP, payload, {
                owner = "shop",
                responseOpcode = self.Opcodes.SMSG_SHOP_DATA,
            })
        if not ok then
            self:_MarkInflight(reqKey, nil)
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep("shop", "shop data (failed)")
            end
        end
    end)
    return true
end

-- Request purchase history
function DC:RequestShopHistory(limit, offset)
    limit = tonumber(limit) or 50
    offset = tonumber(offset) or 0

    if limit < 1 then limit = 1 end
    if limit > 200 then limit = 200 end
    if offset < 0 then offset = 0 end

    local reqKey = "req:shopHistory"
    if self:_IsInflight(reqKey) then
        return false
    end

    self:_DebounceRequest(reqKey, 0.15, function()
        if self:_IsInflight(reqKey) then
            return
        end

        self:_MarkInflight(reqKey, true)
        local ok = SendOwnedCollectionWave1Request("shopHistory",
            self.Opcodes.CMSG_GET_SHOP_HISTORY,
            {
                limit = limit,
                offset = offset,
            },
            {
                owner = "shop-history",
                responseOpcode = self.Opcodes.SMSG_SHOP_HISTORY,
            })

        if not ok then
            self:_MarkInflight(reqKey, nil)
        end
    end)

    return true
end

-- Request shop purchase
function DC:RequestBuyItem(shopId)
    return SendOwnedCollectionWave1Request("purchaseResult",
        self.Opcodes.CMSG_BUY_ITEM,
        {
            shopId = shopId,
        },
        {
            owner = "shop-purchase",
            responseOpcode = self.Opcodes.SMSG_PURCHASE_RESULT,
        })
end

-- Request currency balance
function DC:RequestCurrencies()
    local reqKey = "req:currency"
    local progressKey = "currency"
    local progressLabel = "currency"

    if self:_IsInflight(reqKey) then
        return false
    end

    local now = (type(GetTime) == "function" and GetTime()) or
        (type(time) == "function" and time()) or 0
    local lastReceivedAt = tonumber(self._currencyLastReceivedAt) or 0
    if now > 0 and lastReceivedAt > 0 and (now - lastReceivedAt) < 3.0 then
        if type(self._syncProgress) == "table" then
            self:CompleteSyncProgressStep(progressKey, progressLabel)
        end
        return true
    end

    self:_DebounceRequest(reqKey, 0.20, function()
        if self:_IsInflight(reqKey) then
            return
        end

        self:_MarkInflight(reqKey, true)
        if type(self._syncProgress) == "table" then
            self:StartSyncProgressStep(progressKey, progressLabel)
        end

        local ok = SendOwnedCollectionWave1Request("currencies",
            self.Opcodes.CMSG_GET_CURRENCIES, {}, {
                owner = "currencies",
                responseOpcode = self.Opcodes.SMSG_CURRENCIES,
            })
        if not ok then
            self:_MarkInflight(reqKey, nil)
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep(progressKey,
                    progressLabel .. " (failed)")
            end
        end
    end)

    return true
end

-- Request wishlist
function DC:RequestWishlist(force)
    local reqKey = "req:wishlist"
    local progressKey = "wishlist"
    local progressLabel = "wishlist"

    if self:_IsInflight(reqKey) then
        return false
    end

    local now = (type(GetTime) == "function" and GetTime()) or
        (type(time) == "function" and time()) or 0
    local lastReceivedAt = tonumber(self._wishlistLastReceivedAt) or 0
    if not force and now > 0 and lastReceivedAt > 0 and (now - lastReceivedAt) < 5.0 and
        type(self.wishlist) == "table" then
        if type(self._syncProgress) == "table" then
            self:CompleteSyncProgressStep(progressKey, progressLabel)
        end
        return true
    end

    self:_DebounceRequest(reqKey, 0.10, function()
        if self:_IsInflight(reqKey) then
            return
        end

        if type(self._syncProgress) == "table" then
            self:StartSyncProgressStep(progressKey, progressLabel)
        end

        self:_MarkInflight(reqKey, true)
        local ok = SendOwnedCollectionWave1Request("wishlist",
            self.Opcodes.CMSG_GET_WISHLIST, {}, {
                owner = "wishlist",
                responseOpcode = self.Opcodes.SMSG_WISHLIST_DATA,
            })
        if not ok then
            self:_MarkInflight(reqKey, nil)
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep(progressKey,
                    progressLabel .. " (failed)")
            end
        end
    end)

    return true
end

-- Add to wishlist
function DC:RequestAddWishlist(collectionType, entryId)
    local typeId = type(collectionType) == "number" and collectionType or self:GetTypeIdFromName(collectionType)
    if not typeId or typeId == 0 then
        return
    end

    return SendOwnedCollectionWave1Request("wishlist",
        self.Opcodes.CMSG_ADD_WISHLIST,
        {
            type = typeId,
            entryId = tonumber(entryId) or entryId,
        },
        {
            owner = "wishlist-update",
            responseOpcode = self.Opcodes.SMSG_WISHLIST_UPDATED,
        })
end

-- Remove from wishlist
function DC:RequestRemoveWishlist(collectionType, entryId)
    local typeId = type(collectionType) == "number" and collectionType or self:GetTypeIdFromName(collectionType)
    if not typeId or typeId == 0 then
        return
    end

    return SendOwnedCollectionWave1Request("wishlist",
        self.Opcodes.CMSG_REMOVE_WISHLIST,
        {
            type = typeId,
            entryId = tonumber(entryId) or entryId,
        },
        {
            owner = "wishlist-update",
            responseOpcode = self.Opcodes.SMSG_WISHLIST_UPDATED,
        })
end

-- Use/summon collection item (mount, pet, toy)
function DC:RequestUseItem(collectionType, entryId)
    local typeId = type(collectionType) == "number" and collectionType or self:GetTypeIdFromName(collectionType)
    local normalizedEntryId = tonumber(entryId) or entryId
    return self:SendMessage(self.Opcodes.CMSG_USE_ITEM, {
        type = typeId or 0,
        entryId = normalizedEntryId,
    })
end

-- Request Item Sets (sets tab)
-- Request Item Sets (removed duplicate)

-- =============================================================================
-- Outfit Saving Protocol
-- =============================================================================

local function InvalidateSavedOutfitsCache()
    DCCollectionCharDB = DCCollectionCharDB or {}
    DCCollectionCharDB.savedOutfits = nil
    DCCollectionCharDB.savedOutfitsPages = nil
    DCCollectionCharDB.savedOutfitsOffset = nil
    DCCollectionCharDB.savedOutfitsLimit = nil
    DCCollectionCharDB.savedOutfitsTotal = nil
    DCCollectionCharDB.savedOutfitsMeta = nil
end

function DC.Protocol:SaveOutfit(id, name, icon, items)
    -- Any save invalidates cached paging/index views.
    DC.db = DC.db or {}
    DC.db.outfitsPages = nil
    DC.db.outfitsBySignature = nil
    InvalidateSavedOutfitsCache()

    local data = {
        id = id,
        name = name or "Outfit",
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        items = items or {}
    }
    DC:SendMessage(DC.Opcodes.CMSG_SAVE_OUTFIT, data)
end

function DC.Protocol:DeleteOutfit(id)
    DC.db = DC.db or {}
    DC.db.outfitsPages = nil
    DC.db.outfitsBySignature = nil
    InvalidateSavedOutfitsCache()
    DC:SendMessage(DC.Opcodes.CMSG_DELETE_OUTFIT, { id = id })
end

function DC.Protocol:RequestSavedOutfits()
    return self:RequestSavedOutfitsPage(0, 6)
end

function DC.Protocol:RequestSavedOutfitsPage(offset, limit)
    local sentAt = (type(GetTime) == "function") and GetTime() or 0

    -- Temporarily pause transmog paging so this small request is less likely to be starved/dropped.
    -- Some transports/servers rate-limit addon messages; large paging runs can dominate the channel.
    local now = sentAt
    if now == 0 and type(time) == "function" then
        now = time() or 0
    end
    DC._pauseTransmogPagingUntil = now + 3.0
    ResetPagingDelayTimer(DC, "_transmogPagingDelayFrame")

    return SendCollectionSavedOutfitsRequest(offset or 0, limit or 6,
        { sentAt = sentAt })
end

function DC:RequestItemSets(force)
    local defs = self.definitions or DC.definitions
    if defs then
        if type(defs.itemsets) ~= "table" and type(defs.itemSets) == "table" then defs.itemsets = defs.itemSets end
        if type(defs.itemSets) ~= "table" and type(defs.itemsets) == "table" then defs.itemSets = defs.itemsets end
    end

    if not force and type(self.HasLocalCollectionItemSets) == "function" and
       self:HasLocalCollectionItemSets() then
        self.itemSetsLoaded = true
        return true
    end

    if self.itemSetsLoaded and not force then
        return true
    end

    -- Avoid restarting the paging run while one is already in progress.
    if self._itemSetsLoading and not force then
        return
    end

    -- Avoid running item set paging in parallel with transmog paging.
    -- Some protocol transports only tolerate one large/paged transfer at a time.
    if self._transmogDefLoading and not force then
        self._deferItemSetsUntilTransmogComplete = true
        return
    end

    -- If item sets are already present from SavedVariables cache, validate via syncVersion
    -- to avoid unnecessary re-downloads but still refresh after server updates/locale changes.
    local cached = defs and (defs.itemsets or defs.itemSets)
    local hasCached = (not force and type(cached) == "table" and next(cached) ~= nil)

    self._itemSetsLoading = true
    self._itemSetsOffset = 0
    self._itemSetsLimit = tonumber(self._itemSetsLimit) or 50
    if self._itemSetsLimit < 10 then self._itemSetsLimit = 10 end
    if self._itemSetsLimit > 200 then self._itemSetsLimit = 200 end

    local payload = { offset = self._itemSetsOffset, limit = self._itemSetsLimit, packed = 1 }
    if hasCached and type(self.GetSyncVersion) == "function" then
        local v = tonumber(self:GetSyncVersion("itemsets")) or 0
        if v ~= 0 then
            payload.syncVersion = v
        end
    end

    return SendItemSetsRequest(payload)
end

-- Copy a community outfit to the player's personal account collection
function DC.Protocol:CopyCommunityOutfitToAccount(communityOutfitId)
    return SendCommunityCopyOutfitRequest(communityOutfitId)
end

function DC:OnMsg_SavedOutfits(data)
    if not data then
        self:Debug("Saved outfits response missing data")
        return
    end

    local outfitsList = data.outfits or data.savedOutfits or data.list
    if type(outfitsList) ~= "table" then
        self:Debug("Saved outfits response missing outfits list")
        return
    end

    if outfitsList[1] and type(outfitsList[1].items) ~= "table" then
        self:Debug("Saved outfits payload requires item parsing (" .. type(outfitsList[1].items) .. ")")
    end
    
    DC.db = DC.db or {}
    DC.db.outfits = {}
    DC.db.outfitsPages = DC.db.outfitsPages or {}
    DC.db.outfitsBySignature = DC.db.outfitsBySignature or {}

    -- Paging metadata (optional). Some servers do not echo offset/limit in the response;
    -- in that case, fall back to the last request parameters.
    local req = self.pendingRequests and self.pendingRequests[self.Opcodes.CMSG_GET_SAVED_OUTFITS]
    local reqData = (req and req.data) or self._nativeSavedOutfitsLastRequest
    local respOffset = tonumber(data.offset)
    local respLimit = tonumber(data.limit)
    local offset = respOffset
    local limit = respLimit
    if reqData then
        local reqOffset = tonumber(reqData.offset)
        local reqLimit = tonumber(reqData.limit)
        if offset == nil and reqOffset ~= nil then
            offset = reqOffset
        elseif offset == 0 and reqOffset ~= nil and reqOffset > 0 then
            -- Some servers incorrectly echo offset=0 for every page; prefer the requested offset.
            offset = reqOffset
        end
        if limit == nil and reqLimit ~= nil then
            limit = reqLimit
        end
    end
    offset = offset or 0
    limit = limit or 6

    DC.db.outfitsOffset = offset
    DC.db.outfitsLimit = limit
    DC.db.outfitsTotal = tonumber(data.total) or nil

    -- Cache parsed items strings to avoid repeated gmatch() parsing when the server
    -- re-sends the same outfits list after save/delete.
    self._outfitItemsParseCache = self._outfitItemsParseCache or {}
    
    local pageOutfits = {}

    for _, outfit in ipairs(outfitsList) do
        -- Server sends 'items' as either a table or a JSON string from DB.
        -- Parse it if needed.
        local slots = outfit.items
        if type(slots) == "string" and slots ~= "" then
            local cached = self._outfitItemsParseCache[slots]
            if cached then
                slots = cached
            else
                -- Try to parse JSON-ish string like {"ChestSlot":48691,...}
                local parsed = {}
                local success = pcall(function()
                    for k, v in slots:gmatch('"?([^":,{}]+)"?%s*:%s*(%d+)') do
                        parsed[k] = tonumber(v)
                    end
                end)
                if success and next(parsed) then
                    self._outfitItemsParseCache[slots] = parsed
                    slots = parsed
                end
            end
        end
        
        outfit.slots = slots

        -- Build a signature index so the wardrobe can pin the equipped outfit on page 1.
        if Wardrobe and type(Wardrobe.SerializeSlotsToJsonString) == "function" and type(slots) == "table" then
            local sig = Wardrobe.SerializeSlotsToJsonString(slots)
            if sig and sig ~= "" then
                DC.db.outfitsBySignature[sig] = outfit
            end
        end

        table.insert(pageOutfits, outfit)
    end

    -- Cache this page by offset so we can prefetch pages without breaking the visible page.
    DC.db.outfitsPages[offset] = pageOutfits

    -- Keep legacy field for the most recently received page.
    DC.db.outfits = pageOutfits
    
    -- Cache metadata for next session
    DC.db.outfitsMeta = DC.db.outfitsMeta or {}
    DC.db.outfitsMeta.lastSync = time()
    DC.db.outfitsMeta.total = DC.db.outfitsTotal

    DCCollectionCharDB = DCCollectionCharDB or {}
    DCCollectionCharDB.savedOutfits = pageOutfits
    DCCollectionCharDB.savedOutfitsPages = DC.db.outfitsPages
    DCCollectionCharDB.savedOutfitsOffset = DC.db.outfitsOffset
    DCCollectionCharDB.savedOutfitsLimit = DC.db.outfitsLimit
    DCCollectionCharDB.savedOutfitsTotal = DC.db.outfitsTotal
    DCCollectionCharDB.savedOutfitsMeta = DC.db.outfitsMeta
    
    self:Debug("Received " .. #DC.db.outfits .. " saved outfits from server")

    -- UI may not have finished creating the outfits grid yet; mark pending and attempt refresh.
    if DC.Wardrobe then
        DC.Wardrobe._pendingOutfitsRefresh = true
        if DC.Wardrobe.RefreshOutfitsGrid then
            DC.Wardrobe:RefreshOutfitsGrid()
        end
    end

    -- Allow transmog paging to continue after we get a response.
    self._nativeSavedOutfitsLastRequest = nil
    self._pauseTransmogPagingUntil = nil
end

function DC:RequestCommunityList(offset, limit, filter, sort)
    local sentAt = (type(GetTime) == "function") and GetTime() or 0

    -- Temporarily pause transmog paging so this small request is less likely to be starved/dropped.
    local now = sentAt
    if now == 0 and type(time) == "function" then
        now = time() or 0
    end
    self._pauseTransmogPagingUntil = now + 3.0
    ResetPagingDelayTimer(self, "_transmogPagingDelayFrame")

    local ok = SendCollectionCommunityRequest(
        self.Opcodes.CMSG_COMMUNITY_GET_LIST, {
        offset = offset or 0,
        limit = limit or 50,
        filter = filter or "all",
        sort = sort or "newest",
        }, {
            owner = "collection",
            responseOpcode = self.Opcodes.SMSG_COMMUNITY_LIST,
            sentAt = sentAt,
        })

    return ok
end

function DC:RequestCommunityFavorite(outfitId, add)
    return SendCollectionCommunityRequest(self.Opcodes.CMSG_COMMUNITY_FAVORITE, {
        id = outfitId,
        add = add
    }, {
        owner = "collection",
        responseOpcode = self.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT,
    })
end

function DC:RequestCommunityPublish(name, items, tags)
    local payload = {
        name = name,
        items = items,
    }
    if tags and tags ~= "" then
        payload.tags = tags
    end
    return SendCollectionCommunityRequest(self.Opcodes.CMSG_COMMUNITY_PUBLISH,
        payload, {
            owner = "collection",
            responseOpcode = self.Opcodes.SMSG_COMMUNITY_PUBLISH_RESULT,
        })
end

function DC:RequestCommunityRate(id, value)
    local voteValue = tonumber(value) or 1
    if voteValue >= 0 then
        voteValue = 1
    else
        voteValue = -1
    end

    return SendCollectionCommunityRequest(self.Opcodes.CMSG_COMMUNITY_RATE, {
        id = id,
        value = voteValue,
    }, {
        owner = "collection",
    })
end

function DC:RequestCommunityUpdate(id, name, items, tags)
    local payload = {
        id = id,
        name = name,
        items = items,
    }
    if tags and tags ~= "" then
        payload.tags = tags
    end
    return SendCollectionCommunityRequest(self.Opcodes.CMSG_COMMUNITY_UPDATE,
        payload, {
            owner = "collection",
            responseOpcode = self.Opcodes.SMSG_COMMUNITY_UPDATE_RESULT,
        })
end

function DC:RequestCommunityDelete(id)
    return SendCollectionCommunityRequest(self.Opcodes.CMSG_COMMUNITY_DELETE, {
        id = id
    }, {
        owner = "collection",
        responseOpcode = self.Opcodes.SMSG_COMMUNITY_DELETE_RESULT,
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
    local numericEntryId = tonumber(entryId) or entryId

    self._lastTitleRequest = {
        rawEntryId = entryId,
        entryId = numericEntryId,
        sentAt = (type(GetTime) == "function") and GetTime() or 0,
    }

    self:Debug(string.format(
        "[TitleDebug] RequestSetTitle raw=%s numeric=%s",
        tostring(entryId),
        tostring(numericEntryId)
    ))

    if type(self.LogNetEvent) == "function" then
        self:LogNetEvent("info", "title", "RequestSetTitle", {
            rawEntryId = entryId,
            entryId = numericEntryId,
        })
    end

    return self:RequestUseItem("titles", numericEntryId)
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
    local reqKey = "req:coll:transmog"
    local progressKey = "coll:transmog"
    local progressLabel = "collection: transmog"

    if type(self.HasCurrentTransmogOwnedState) == "function" and
        self:HasCurrentTransmogOwnedState() then
        if type(self._syncProgress) == "table" then
            self:CompleteSyncProgressStep(progressKey, progressLabel)
        end
        return true
    end

    if self:_IsInflight(reqKey) then
        return false
    end

    self:_DebounceRequest(reqKey, 0.10, function()
        if self:_IsInflight(reqKey) then
            return
        end
        if type(self._syncProgress) == "table" then
            self:StartSyncProgressStep(progressKey, progressLabel)
        end
        self:_MarkInflight(reqKey, true)

        local ok = self:SendMessage(self.Opcodes.CMSG_GET_COLLECTED_APPEARANCES, {
            syncVersion = self:_GetTransmogOwnedSyncVersion(),
        })
        if not ok then
            self:_MarkInflight(reqKey, nil)
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep(progressKey, progressLabel .. " (failed)")
            end
        end
    end)

    return true
end

-- Request current transmog state for all slots
function DC:RequestTransmogState()
    return SendCollectionTransmogStateRequest("collection_transmog_state")
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

-- Apply multiple equipment-slot changes at once (preferred for outfits).
-- entries: { { slot = 0..18, appearanceId = displayId, clear = bool }, ... }
function DC:ApplyTransmogBatchByEquipmentSlot(entries)
    return self:SendMessage(self.Opcodes.CMSG_APPLY_TRANSMOG_PREVIEW, {
        byEquipSlot = true,
        entries = entries or {},
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
DC.RequestShopHistoryData = function(self, limit, offset) return self:RequestShopHistory(limit, offset) end

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

    if type(self.LogNetEvent) == "function" then
        self:LogNetEvent("info", "recv", string.format("Received opcode 0x%02X", tonumber(opcode) or 0), { opcode = opcode })
    end

    TrackAddonCollectionProtocolReply(opcode)

    -- Diagnostics: if we ever receive our OWN request opcodes, the server did not handle the message
    -- and it got echoed back as a normal addon whisper.
    if opcode == self.Opcodes.CMSG_GET_SAVED_OUTFITS or opcode == self.Opcodes.CMSG_COMMUNITY_GET_LIST then
        local now = (type(GetTime) == "function") and GetTime() or 0
        if not self._lastLoopbackWarnAt or (now - self._lastLoopbackWarnAt) > 2 then
            self._lastLoopbackWarnAt = now
            self:Print(string.format("[Net] Loopback detected for opcode 0x%02X (server did not handle it)", tonumber(opcode) or 0))
        end
        if type(self.LogNetEvent) == "function" then
            self:LogNetEvent("warn", "loopback", "Loopback (server unhandled)", { opcode = opcode })
        end
    end

    -- Track last-received timestamp per opcode (used by request timeouts).
    self._lastRecvOpcodeAt = self._lastRecvOpcodeAt or {}
    self._lastRecvOpcodeAt[opcode] = (type(GetTime) == "function") and GetTime() or time()
    
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
    elseif opcode == self.Opcodes.SMSG_ITEM_SETS then
        self:OnMsg_ItemSets(data)
    elseif opcode == self.Opcodes.SMSG_SAVED_OUTFITS then
        self:OnMsg_SavedOutfits(data)
    elseif opcode == self.Opcodes.SMSG_SHOP_DATA then
        self:HandleShopData(data)
    elseif opcode == self.Opcodes.SMSG_PURCHASE_RESULT then
        self:HandlePurchaseResult(data)
    elseif opcode == self.Opcodes.SMSG_CURRENCIES then
        self:HandleCurrencies(data)
    elseif opcode == self.Opcodes.SMSG_SHOP_HISTORY then
        self:HandleShopHistory(data)
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
    elseif opcode == self.Opcodes.SMSG_COMMUNITY_UPDATE_RESULT then
        self:HandleCommunityUpdateResult(data)
    elseif opcode == self.Opcodes.SMSG_COMMUNITY_DELETE_RESULT then
        self:HandleCommunityDeleteResult(data)
    elseif opcode == self.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT then
        self:HandleCommunityFavoriteResult(data)
    elseif opcode == self.Opcodes.SMSG_INSPECT_TRANSMOG then
        self:HandleInspectTransmog(data)
    else
        self:Debug(string.format("Unknown opcode: 0x%02X", opcode))
        if type(self.LogNetEvent) == "function" then
            self:LogNetEvent("warn", "recv", "Unknown opcode", { opcode = opcode })
        end
    end
end

-- ============================================================================
-- RESPONSE HANDLERS
-- Updated to match new protocol
-- ============================================================================

-- Request to toggle favorite status
function DC:RequestCommunityFavorite(outfitID, add)
    return SendCollectionCommunityRequest(self.Opcodes.CMSG_COMMUNITY_FAVORITE,
        {
            id = outfitID,
            add = add,
        }, {
            owner = "collection",
            responseOpcode = self.Opcodes.SMSG_COMMUNITY_FAVORITE_RESULT,
        })
end

-- Request to view (increment view count)
function DC:RequestCommunityView(outfitID)
    return SendCollectionCommunityRequest(self.Opcodes.CMSG_COMMUNITY_VIEW, {
        id = outfitID,
    }, {
        owner = "collection",
    })
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

    local function normalizeSlotMap(tbl)
        if type(tbl) ~= "table" then
            return {}
        end

        local out = {}
        local hasStringSlotKey = false
        local minNumKey = nil

        for k, v in pairs(tbl) do
            if type(k) == "string" then
                local nk = tonumber(k)
                if nk ~= nil then
                    hasStringSlotKey = true
                    out[tostring(nk)] = v
                end
            elseif type(k) == "number" then
                minNumKey = (minNumKey == nil) and k or math.min(minNumKey, k)
            end
        end

        if hasStringSlotKey then
            for k, v in pairs(tbl) do
                if type(k) == "number" then
                    out[tostring(k)] = out[tostring(k)] or v
                end
            end
            return out
        end

        local shift = 0
        if minNumKey ~= nil and minNumKey == 1 then
            shift = -1
        end

        for k, v in pairs(tbl) do
            if type(k) == "number" then
                out[tostring(k + shift)] = v
            end
        end
        return out
    end

    self.inspectTarget = data and data.target or nil
    self.inspectTransmogItemIds = normalizeSlotMap(data and data.slots)

    -- UX hint (throttled): teach users where the inspect actions live.
    do
        local now = (GetTime and GetTime()) or 0
        local target = tostring(self.inspectTarget or "")
        local lastAt = tonumber(self._lastInspectHintAt or 0) or 0
        local lastTarget = tostring(self._lastInspectHintTarget or "")

        -- Show at most once per target per ~15s to avoid spam.
        if (now == 0 or (now - lastAt) > 15) or (target ~= "" and target ~= lastTarget) then
            self._lastInspectHintAt = now
            self._lastInspectHintTarget = target

            if self.Print then
                self:Print("Inspect cached. Use InspectFrame buttons: Preview / Copy Outfit.")
            end
        end
    end

    if self.TransmogBorders and type(self.TransmogBorders.UpdateInspectBorders) == "function" then
        pcall(function() self.TransmogBorders:UpdateInspectBorders("target") end)
    end

    if type(self.PreviewInspectData) == "function" then
        self:PreviewInspectData(data)
        return
    end

    if type(self.PreviewLastInspectedAppearance) == "function" then
        self:PreviewLastInspectedAppearance(true)
    end
end

-- ============================================================================
-- INSPECT HELPERS (PREVIEW + COPY)
-- ============================================================================

local INSPECT_EQUIP_SLOT_TO_KEY = {
    [0] = "HeadSlot",
    [2] = "ShoulderSlot",
    [3] = "ShirtSlot",
    [4] = "ChestSlot",
    [5] = "WaistSlot",
    [6] = "LegsSlot",
    [7] = "FeetSlot",
    [8] = "WristSlot",
    [9] = "HandsSlot",
    [14] = "BackSlot",
    [15] = "MainHandSlot",
    [16] = "SecondaryHandSlot",
    [17] = "RangedSlot",
    [18] = "TabardSlot",
}

function DC:PreviewLastInspectedAppearance(silent)
    local slots = self.inspectTransmogItemIds
    if type(slots) ~= "table" or not next(slots) then
        if not silent and self.Print then
            self:Print("No inspect appearance cached yet.")
        end
        return
    end

    if DressUpModel and DressUpModel.Undress then
        if DressUpFrame and DressUpFrame.Show then
            DressUpFrame:Show()
        end
        DressUpModel:Undress()
    end

    for _, itemId in pairs(slots) do
        local id = tonumber(itemId)
        if id and id > 0 then
            local link = "item:" .. tostring(id)
            if DressUpModel and DressUpModel.TryOn then
                pcall(function() DressUpModel:TryOn(link) end)
            elseif DressUpItemLink then
                pcall(function() DressUpItemLink(link) end)
            end
        end
    end
end

function DC:CopyLastInspectedAppearanceToOutfit(outfitName)
    local name = tostring(outfitName or "")
    if name == "" then
        if self.Print then
            self:Print("Please enter an outfit name.")
        end
        return
    end

    local slots = self.inspectTransmogItemIds
    if type(slots) ~= "table" or not next(slots) then
        if self.Print then
            self:Print("No inspect appearance cached yet.")
        end
        return
    end

    local out = {}
    local icon = "Interface\\Icons\\INV_Misc_QuestionMark"

    local function tryIconFromEquipSlot(equipSlot)
        local itemId = tonumber(slots[tostring(equipSlot)] or 0) or 0
        if itemId > 0 and type(GetItemInfo) == "function" then
            local tex = select(10, GetItemInfo(itemId))
            if tex and tex ~= "" then
                return tex
            end
        end
        return nil
    end

    icon = tryIconFromEquipSlot(4) or tryIconFromEquipSlot(0) or icon
    icon = string.gsub(icon, "\\\\", "/")

    for equipSlotStr, itemId in pairs(slots) do
        local equipSlot = tonumber(equipSlotStr)
        local slotKey = equipSlot and INSPECT_EQUIP_SLOT_TO_KEY[equipSlot] or nil
        local id = tonumber(itemId)
        if slotKey and id and id > 0 then
            out[slotKey] = id
        end
    end

    if not next(out) then
        if self.Print then
            self:Print("Inspect payload had no usable slots.")
        end
        return
    end

    if self.Protocol and type(self.Protocol.SaveOutfit) == "function" then
        self.Protocol:SaveOutfit(0, name, icon, out)
        if type(self.Protocol.RequestSavedOutfits) == "function" then
            self.Protocol:RequestSavedOutfits()
        end
        if self.Print then
            self:Print("Copied inspected appearance to outfit: " .. name)
        end
    elseif self.Print then
        self:Print("Error: Outfit protocol not ready.")
    end
end

function DC:CopyLastInspectedAppearanceToOutfitPrompt()
    if type(StaticPopupDialogs) ~= "table" then
        return
    end

    if not StaticPopupDialogs["DC_COPY_INSPECT_OUTFIT"] then
        StaticPopupDialogs["DC_COPY_INSPECT_OUTFIT"] = {
            text = "Copy inspected appearance as an outfit",
            button1 = "Save",
            button2 = (DC.L and DC.L["CANCEL"]) or "Cancel",
            hasEditBox = true,
            maxLetters = 40,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            OnShow = function(popup)
                if popup.editBox and popup.editBox.SetText then
                    popup.editBox:SetText("Inspect Outfit")
                    if popup.editBox.HighlightText then
                        popup.editBox:HighlightText()
                    end
                end
            end,
            OnAccept = function(popup)
                local txt = popup.editBox and popup.editBox.GetText and popup.editBox:GetText() or ""
                DC:CopyLastInspectedAppearanceToOutfit(txt)
            end,
            EditBoxOnEnterPressed = function(popup)
                local txt = popup.editBox and popup.editBox.GetText and popup.editBox:GetText() or ""
                DC:CopyLastInspectedAppearanceToOutfit(txt)
                popup:Hide()
            end,
        }
    end

    StaticPopup_Show("DC_COPY_INSPECT_OUTFIT")
end

-- Handle handshake acknowledgement
local TRANSMOG_OWNED_SYNC_KEY = "transmog_owned"

function DC:_SetServerOwnedSyncVersion(collectionType, version)
    local normalizedType = (type(self.NormalizeCollectionType) == "function" and
        self:NormalizeCollectionType(collectionType)) or collectionType
    local numericVersion = tonumber(version)

    if not normalizedType or numericVersion == nil then
        return nil
    end

    self._serverOwnedSyncVersions = self._serverOwnedSyncVersions or {}
    self._serverOwnedSyncVersions[normalizedType] = numericVersion
    return numericVersion
end

function DC:_RememberOwnedSyncVersions(syncVersions)
    if type(syncVersions) ~= "table" then
        return
    end

    for key, value in pairs(syncVersions) do
        self:_SetServerOwnedSyncVersion(key, value)
    end
end

function DC:_GetServerOwnedSyncVersion(collectionType)
    local normalizedType = (type(self.NormalizeCollectionType) == "function" and
        self:NormalizeCollectionType(collectionType)) or collectionType

    if not normalizedType or type(self._serverOwnedSyncVersions) ~= "table" then
        return nil
    end

    return tonumber(self._serverOwnedSyncVersions[normalizedType])
end

function DC:_GetTransmogOwnedSyncVersion()
    if type(self.GetSyncVersion) ~= "function" then
        return 0
    end

    return tonumber(self:GetSyncVersion(TRANSMOG_OWNED_SYNC_KEY)) or 0
end

function DC:_SetTransmogOwnedSyncVersion(version)
    local numericVersion = tonumber(version)
    if numericVersion == nil then
        return nil
    end

    self:_SetServerOwnedSyncVersion("transmog", numericVersion)
    if type(self.SetSyncVersion) == "function" then
        self:SetSyncVersion(TRANSMOG_OWNED_SYNC_KEY, numericVersion)
    end

    return numericVersion
end

function DC:HasCurrentTransmogOwnedState(serverVersion)
    local numericServerVersion = tonumber(serverVersion)
    if numericServerVersion == nil then
        numericServerVersion = self:_GetServerOwnedSyncVersion("transmog")
    end
    if numericServerVersion == nil then
        return false
    end

    if self:_GetTransmogOwnedSyncVersion() ~= numericServerVersion then
        return false
    end

    local collection = self.collections and self.collections.transmog
    if type(collection) ~= "table" then
        return false
    end

    if numericServerVersion > 0 then
        return next(collection) ~= nil or
            (type(self.collectedAppearances) == "table" and next(self.collectedAppearances) ~= nil)
    end

    return true
end

function DC:HandleHandshakeAck(data)
    self:Debug("Handshake acknowledged")
    
    self.serverHash = data.serverHash
    self.isConnected = true
    self._handshakeAcked = true

    if ShouldUseNativeCollectionWave1Bridge() then
        EnsureNativeCollectionWave1PollFrame()
    end
    if ShouldUseNativeCollectionTransmogStateBridge() then
        EnsureNativeCollectionTransmogStatePollFrame()
    end
    if ShouldUseNativeCollectionItemSetsBridge() then
        EnsureNativeCollectionItemSetsPollFrame()
    end

    if type(self._syncProgress) == "table" then
        self:CompleteSyncProgressStep("handshake", "handshake")
    end

    -- Store per-type server syncVersions so RequestInitialData / RequestDefinitions
    -- can short-circuit when the local cache is already up to date.
    if type(data.syncVersions) == "table" then
        self._serverSyncVersions = {}
        for k, v in pairs(data.syncVersions) do
            local num = tonumber(v)
            if num then
                self._serverSyncVersions[k] = num
                -- If our local syncVersion already matches the server's, we can
                -- safely bump/confirm the locally stored version too. If it
                -- differs, RequestDefinitions will send the old value and the
                -- server will respond with either a fresh payload or an
                -- upToDate ack.
                if type(self.GetSyncVersion) == "function" and type(self.SetSyncVersion) == "function" then
                    local local_v = tonumber(self:GetSyncVersion(k)) or 0
                    if local_v == 0 and num > 0 then
                        -- Intentionally don't set here: we haven't validated local cache
                        -- matches that version. Let the normal request roundtrip confirm.
                    end
                end
            end
        end
    end

    if type(self._RememberOwnedSyncVersions) == "function" then
        self:_RememberOwnedSyncVersions(data.ownedSyncVersions)
    end

    local pendingInitialData = self._pendingInitialDataAfterHandshake
    if pendingInitialData then
        self._pendingInitialDataAfterHandshake = nil
    end
    
    if data.needsSync then
        self:Debug("Server indicates full sync needed")
        self:Debug(string.format(
            "Handshake hash mismatch client=%s server=%s total=%s",
            tostring(self._lastHandshakeHash or 0),
            tostring(data.serverHash or 0),
            tostring(data.totalItems or 0)))
        if type(self._lastHandshakeCounts) == "table" then
            self:Debug(string.format(
                "Handshake local counts mounts=%s pets=%s heirlooms=%s titles=%s",
                tostring(self._lastHandshakeCounts.mounts or 0),
                tostring(self._lastHandshakeCounts.pets or 0),
                tostring(self._lastHandshakeCounts.heirlooms or 0),
                tostring(self._lastHandshakeCounts.titles or 0)))
        end
        if pendingInitialData then
            self._pendingInitialDataAfterFullCollection = pendingInitialData
        end
        self:RequestFullCollection()
    else
        self:Debug("Collection is in sync with server")

        local receivedAt = (type(GetTime) == "function" and GetTime()) or
            (type(time) == "function" and time()) or 0
        self._collectionLastReceivedAt = self._collectionLastReceivedAt or {}
        self._collectionLastReceivedAt.mounts = receivedAt
        self._collectionLastReceivedAt.pets = receivedAt
        self._collectionLastReceivedAt.heirlooms = receivedAt
    end

    -- Request the rest of the initial data (definitions, currencies, shop, etc.)
    if type(self.RequestInitialData) == "function" then
        -- Handshake can arrive after ADDON_LOADED/PLAYER_LOGIN already kicked off init.
        -- Avoid duplicate request spikes.
        if pendingInitialData and not data.needsSync then
            self:RequestInitialData(true, pendingInitialData.forceRefresh == true)
        elseif not self._initialDataRequested then
            self:RequestInitialData(true)
        end
    end
    
    -- Fire callback
    if self.callbacks.onHandshakeAck then
        self.callbacks.onHandshakeAck(data)
    end
end

local function BuildCollectedAppearancesCollection(self, appearances, items)
    local authoritative = {}

    if type(appearances) == "table" then
        local count = 0
        for rawKey, value in pairs(appearances) do
            local candidate = value
            if type(value) == "boolean" or type(value) == "table" then
                candidate = rawKey
            end

            local displayId = tonumber(candidate) or candidate
            if displayId and displayId ~= 0 and not authoritative[displayId] then
                authoritative[displayId] = { owned = true }
                count = count + 1
            end
        end

        if count > 0 then
            return authoritative, count, "appearances"
        end
    end

    if type(items) == "table" then
        local mapped = 0
        for rawKey, value in pairs(items) do
            local candidate = value
            if type(value) == "boolean" or type(value) == "table" then
                candidate = rawKey
            end

            local itemId = tonumber(candidate) or candidate
            local displayId = itemId
            if self.Wardrobe and
               type(self.Wardrobe.GetAppearanceDisplayIdForItemId) == "function" then
                displayId = self.Wardrobe:GetAppearanceDisplayIdForItemId(itemId)
            end

            displayId = tonumber(displayId) or displayId
            if displayId and displayId ~= 0 and not authoritative[displayId] then
                authoritative[displayId] = { owned = true }
                mapped = mapped + 1
            end
        end

        if mapped > 0 then
            return authoritative, mapped, "items"
        end
    end

    return authoritative, 0, "empty"
end

function DC:_SyncCollectedAppearancesFromCollection(items)
    local collected = {}

    if type(items) == "table" then
        for rawId in pairs(items) do
            local displayId = tonumber(rawId) or rawId
            if displayId and displayId ~= 0 then
                collected[displayId] = true
            end
        end
    end

    self.collectedAppearances = collected
    return collected
end

-- Handle full collection data
function DC:HandleFullCollection(data)
    self:Debug("Received full collection data")
    local transmogDeferred = data and
        (data.transmogDeferred == true or data.transmog_deferred == true)
    local transmogOwnedSyncVersion = nil
    local receivedAt = (type(GetTime) == "function" and GetTime()) or time()

    if type(self._RememberOwnedSyncVersions) == "function" then
        self:_RememberOwnedSyncVersions(data and data.ownedSyncVersions)
        transmogOwnedSyncVersion = self:_GetServerOwnedSyncVersion("transmog")
    end

    -- Server can ack with an empty payload when the client's local hash
    -- already matches (CMSG_SYNC_COLLECTION short-circuit). Bail early.
    if data and (data.upToDate == true or data.up_to_date == true) and
       (data.collections == nil or (type(data.collections) == "table" and next(data.collections) == nil)) then
        self._fullCollectionReceivedAt = (type(GetTime) == "function" and GetTime()) or time()
        self._pendingCollectionHash = nil
        if data.hash then
            self.collectionHash = data.hash
        end
        if self.callbacks.onCollectionReceived then
            self.callbacks.onCollectionReceived(data)
        end
        return
    end

    if data.collections then
        self._collectionLastReceivedAt = self._collectionLastReceivedAt or {}
        for typeName, items in pairs(data.collections) do
            local typeId = self:GetTypeIdFromName(typeName)
            if typeId then
                self:SetCollection(typeId, items)
            end

            local collType = (type(self.NormalizeCollectionType) == "function" and
                self:NormalizeCollectionType(typeName)) or typeName
            if collType then
                self._collectionLastReceivedAt[collType] = receivedAt
                if collType == "titles" then
                    self._titleCollectionAuthoritative = true
                    self._titleCollectionLastReceivedAt = receivedAt
                    if DCCollectionDB then
                        DCCollectionDB.titleCollectionAuthoritative = true
                        DCCollectionDB.titleCollectionLastReceivedAt = time()
                    end
                end
            end
        end

        if type(data.collections.transmog) == "table" and
           type(self._SyncCollectedAppearancesFromCollection) == "function" then
            self:_SyncCollectedAppearancesFromCollection(
                self.collections and self.collections.transmog or data.collections.transmog)
        end
    end

    if data.stats then
        self.stats = data.stats
        self.stats.toys = nil
    end

    if data.bonuses then
        self.bonuses = data.bonuses
    end

    local transmogOwnedCurrent = false
    if transmogDeferred and type(self.HasCurrentTransmogOwnedState) == "function" then
        transmogOwnedCurrent = self:HasCurrentTransmogOwnedState(transmogOwnedSyncVersion)
    end

    if data.hash and (not transmogDeferred or transmogOwnedCurrent) then
        self.collectionHash = data.hash
        self._pendingCollectionHash = nil
    elseif data.hash then
        self._pendingCollectionHash = data.hash
    end

    self._fullCollectionReceivedAt = receivedAt

    if transmogDeferred then
        if transmogOwnedCurrent then
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep("coll:transmog", "collection: transmog")
            end
            self:Debug("Collected appearances are up to date; skipping refresh")
        elseif type(self.RequestCollectedAppearances) == "function" then
            self:RequestCollectedAppearances()
        end
    end

    if self.callbacks.onCollectionReceived then
        self.callbacks.onCollectionReceived(data)
    end

    local pendingInitialData = self._pendingInitialDataAfterFullCollection
    if pendingInitialData then
        self._pendingInitialDataAfterFullCollection = nil
        if type(self.RequestInitialData) == "function" then
            self:RequestInitialData(true, pendingInitialData.forceRefresh == true)
        end
    end

    if self.MainFrame and self.MainFrame:IsShown() then
        if type(self.RequestRefreshCurrentTab) == "function" then
            self:RequestRefreshCurrentTab()
        else
            self:RefreshCurrentTab()
        end
    end

    if self.Wardrobe and type(self.Wardrobe.InvalidateRandomizerCache) == "function" then
        self.Wardrobe:InvalidateRandomizerCache()
    end
end

function DC:HandleDeltaSync(data)
    self:Debug("Received delta sync")

    if data.added then
        for typeName, items in pairs(data.added) do
            local typeId = self:GetTypeIdFromName(typeName)
            if typeId then
                for _, itemId in ipairs(items) do
                    self:AddToCollection(typeId, itemId)
                    if typeName == "transmog" then
                        self.collectedAppearances = self.collectedAppearances or {}
                        self.collectedAppearances[itemId] = true
                    end
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
                    if typeName == "transmog" and self.collectedAppearances then
                        self.collectedAppearances[itemId] = nil
                    end
                end
            end
        end
    end

    if data.hash then
        self.collectionHash = data.hash
        self._pendingCollectionHash = nil
    end

    if self.callbacks.onDeltaSync then
        self.callbacks.onDeltaSync(data)
    end

    if self.Wardrobe and type(self.Wardrobe.InvalidateRandomizerCache) == "function" then
        self.Wardrobe:InvalidateRandomizerCache()
    end
end

-- Handle stats response
function DC:HandleStatsLegacy(data)
    self:Debug("Received stats")

    self._statsLastReceivedAt = (type(GetTime) == "function" and GetTime()) or
        (type(time) == "function" and time()) or 0
    self:_MarkInflight("req:stats", nil)
    if type(self._syncProgress) == "table" then
        self:CompleteSyncProgressStep("stats", "stats")
    end
    
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

    if type(self.SetRecentAdditions) == "function" then
        self:SetRecentAdditions(self.recentAdditions)
    elseif DCCollectionDB then
        DCCollectionDB.recentAdditions = self.recentAdditions
        DCCollectionDB.recentAdditionsUpdatedAt = time()
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

    if self.Wardrobe and type(self.Wardrobe.InvalidateRandomizerCache) == "function" then
        self.Wardrobe:InvalidateRandomizerCache()
    end
end

-- Handle shop data
function DC:HandleShopData(data)
    self:Debug("Received shop data")

    -- Release shop inflight guard (category can vary; clear common keys).
    self._inflightRequests = self._inflightRequests or {}
    self._inflightRequests["req:shop:all"] = nil
    self._inflightRequests["req:shop:default"] = nil
    self._inflightRequests["req:shop:" .. tostring(data.category or "all")] = nil
    if type(self._syncProgress) == "table" then
        self:CompleteSyncProgressStep("shop", "shop data")
    end

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

    local function ResolveShopTypeName(rawType)
        local typeName = self:GetTypeNameFromId(rawType)
        if type(typeName) == "string" then
            typeName = string.lower(typeName)
        end

        if (not typeName or typeName == "") and type(rawType) == "string" then
            typeName = string.lower(rawType)
        end

        -- Canonicalize singular forms.
        if typeName == "mount" then return "mounts" end
        if typeName == "pet" then return "pets" end
        if typeName == "heirloom" then return "heirlooms" end
        if typeName == "title" then return "titles" end
        if typeName == "appearance" or typeName == "appearances" then return "transmog" end

        if typeName and typeName ~= "" then
            return typeName
        end

        -- Server may send numeric type IDs.
        local n = tonumber(rawType)
        if n == 1 then return "mounts" end
        if n == 2 then return "pets" end
        if n == 3 then return "bonus" end
        if n == 4 then return "heirlooms" end
        if n == 5 then return "titles" end
        if n == 6 then return "transmog" end
        if n == 7 then return "item_sets" end

        return nil
    end

    local function ResolveLegacyShopItemType(typeName, rawType)
        -- Shop UI expects these legacy values for badges/filters.
        if typeName == "bonus" then
            return 1
        elseif typeName == "mounts" then
            return 2
        elseif typeName == "pets" then
            return 3
        elseif typeName == "heirlooms" then
            return 5
        elseif typeName == "transmog" then
            return 6
        elseif typeName == "item_sets" then
            return 6
        end

        local n = tonumber(rawType)
        if n then
            return n
        end
        return 1
    end

    local function IsNumericIconValue(value)
        if type(value) ~= "string" then
            return false
        end

        local trimmed = string.match(value, "^%s*(.-)%s*$")
        if not trimmed or trimmed == "" then
            return false
        end

        return tonumber(trimmed) ~= nil
    end

    local function IsNumericIconPath(texturePath)
        if type(texturePath) ~= "string" then
            return false
        end

        local normalized = string.gsub(texturePath, "/", "\\")
        local lowerPath = string.lower(normalized)
        return string.match(lowerPath, "^interface\\icons\\%d+$") ~= nil
    end

    local function NormalizeShopIcon(textureValue)
        if IsNumericIconValue(textureValue) then
            return nil
        end

        local normalized = self:NormalizeTexturePath(textureValue, nil)
        if IsNumericIconPath(normalized) then
            return nil
        end

        return normalized
    end

    local needsMountDefinitions = false

    for _, it in ipairs(rawItems) do
        local collTypeId = it.type
        local shopId = it.shopId or it.id or it.shop_id
        local entryId = it.entryId or it.entry_id or it.entry
        local shopStatic = nil

        if type(self.GetLocalShopMetadata) == "function" then
            shopStatic = self:GetLocalShopMetadata(shopId, collTypeId, entryId)
        end

        if (collTypeId == nil or collTypeId == "") and shopStatic then
            collTypeId = shopStatic.collectionType
        end
        if (entryId == nil or entryId == "") and shopStatic then
            entryId = shopStatic.entryId
        end

        local typeName = ResolveShopTypeName(
            collTypeId or (shopStatic and shopStatic.collectionTypeName))
        if (not typeName or typeName == "") and shopStatic then
            typeName = ResolveShopTypeName(
                shopStatic.collectionTypeName or shopStatic.collectionType)
        end

        local legacyItemType = ResolveLegacyShopItemType(
            typeName,
            collTypeId or (shopStatic and shopStatic.collectionType))
        local definition = nil

        if typeName and entryId and type(self.GetDefinition) == "function" then
            definition = self:GetDefinition(typeName, entryId)
        end

        local featured = it.featured
        if featured == nil and shopStatic then
            featured = shopStatic.featured
        end

        local card = {
            -- Common (used by MainFrame cards)
            type = "shop",
            shopId = shopId,
            collectionTypeId = collTypeId,
            collectionTypeName = typeName,
            entryId = entryId,
            appearanceId = it.appearanceId or it.appearance_id or
                (shopStatic and shopStatic.appearanceId),
            itemId = it.itemId or it.itemID or it.item_id or
                (shopStatic and shopStatic.itemId),
            spellId = it.spellId or it.spellID or it.spell or
                (shopStatic and shopStatic.spellId),
            displayId = it.displayId or it.display_id or
                (shopStatic and shopStatic.displayId),
            creatureId = it.creatureId or it.creature_id or
                (shopStatic and shopStatic.creatureId),
            definition = definition,
            priceTokens = it.priceTokens or it.costTokens or it.price_tokens or
                (shopStatic and shopStatic.priceTokens) or 0,
            priceEmblems = it.priceEmblems or it.costEmblems or it.price_emblems or
                (shopStatic and shopStatic.priceEmblems) or 0,
            discount = it.discount or (shopStatic and shopStatic.discount) or 0,
            stock = it.stock or (shopStatic and shopStatic.stock),
            featured = featured,
            owned = it.owned or false,
            collected = it.owned or false,
            rarity = tonumber(it.rarity) or
                (shopStatic and tonumber(shopStatic.rarity)) or 0,
            source = (shopStatic and shopStatic.sourceText) or "Shop",
            name = it.name or (shopStatic and shopStatic.name),
            icon = nil, -- resolved below

            -- ShopModule/ShopUI expected schema
            id = shopId,
            itemType = legacyItemType,
            costTokens = it.costTokens or it.priceTokens or it.cost_tokens or it.price_tokens or
                (shopStatic and shopStatic.priceTokens) or 0,
            costEmblems = it.costEmblems or it.priceEmblems or it.cost_emblems or it.price_emblems or
                (shopStatic and shopStatic.priceEmblems) or 0,
            isFeatured = (it.isFeatured ~= nil and it.isFeatured) or
                featured or false,
            purchased = it.purchased or it.owned or false,
            purchaseCount = it.purchaseCount or it.purchase_count or 0,
            maxPurchases = it.maxPurchases or it.max_purchases,
            description = it.description or (shopStatic and shopStatic.sourceText),
        }

        if shopStatic then
            card.itemId = card.itemId or shopStatic.itemId
            card.spellId = card.spellId or shopStatic.spellId
            card.appearanceId = card.appearanceId or shopStatic.appearanceId
            card.displayId = card.displayId or shopStatic.displayId
            card.creatureId = card.creatureId or shopStatic.creatureId
            if (not card.name or card.name == "") and shopStatic.name then
                card.name = shopStatic.name
            end
            if (not card.rarity or card.rarity <= 0) and shopStatic.rarity then
                card.rarity = tonumber(shopStatic.rarity) or card.rarity
            end
            if shopStatic.icon then
                local staticIcon = NormalizeShopIcon(shopStatic.icon)
                if staticIcon then
                    card.icon = staticIcon
                end
            end
        end

        -- Fill missing identifiers from definitions when available.
        if definition then
            card.itemId = card.itemId or definition.itemId or definition.itemID or definition.item_id
            card.spellId = card.spellId or definition.spellId or definition.spellID or definition.spell_id
            card.displayId = card.displayId or definition.displayId or definition.display_id or definition.creatureDisplayId
            if (not card.name or card.name == "") and definition.name then
                card.name = definition.name
            end
            if (not card.rarity or card.rarity <= 0) and definition.rarity then
                card.rarity = definition.rarity
            end
            if definition.icon then
                local defIcon = NormalizeShopIcon(definition.icon)
                if defIcon then
                    card.icon = defIcon
                end
            end
        end

        -- Server may send an icon name (e.g. "INV_...") or a full texture path.
        local serverIcon = it.icon
        local normalizedServerIcon = NormalizeShopIcon(serverIcon)
        
        -- Resolve icon from server data or game API
        if typeName == "mounts" then
            -- Prefer spellId for mounts (some servers send spellId separately)
            local spellId = card.spellId or card.entryId
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
            local itemIdToUse = card.itemId or card.entryId
            if (not card.icon or card.icon == "Interface\\Icons\\INV_Misc_QuestionMark") and itemIdToUse and GetItemInfo then
                local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemIdToUse)
                if texture then card.icon = texture end
                if name and (not card.name or card.name == "") then card.name = name end
                if quality then card.rarity = quality end
            end
        elseif typeName == "pets" or typeName == "heirlooms" or typeName == "transmog" then
            -- Use GetItemInfo for items (returns texture as 10th value)
            local itemIdToUse = card.itemId or card.entryId
            if itemIdToUse and GetItemInfo then
                local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemIdToUse)
                if texture then card.icon = texture end
                if name and (not card.name or card.name == "") then card.name = name end
                if quality then card.rarity = quality end
            end

            -- Pets can also be represented via spells.
            if (not card.icon or card.icon == "Interface\\Icons\\INV_Misc_QuestionMark") then
                local spellId = card.spellId or card.entryId
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
        card.icon = NormalizeShopIcon(card.icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
        card.name = card.name or "Shop Item"
        if not card.rarity or card.rarity <= 0 then
            card.rarity = 2
        end

        if typeName == "mounts" and ((not card.itemId) or card.icon == "Interface\\Icons\\INV_Misc_QuestionMark") then
            needsMountDefinitions = true
        end

        -- Keep cost mirrors in sync (some UIs use price*, ShopUI uses cost*).
        if (not card.priceTokens or card.priceTokens == 0) and card.costTokens then
            card.priceTokens = card.costTokens
        end
        if (not card.priceEmblems or card.priceEmblems == 0) and card.costEmblems then
            card.priceEmblems = card.costEmblems
        end

        table.insert(mapped, card)
    end

    if needsMountDefinitions and type(self.RequestDefinitions) == "function" then
        local now = (type(GetTime) == "function" and GetTime()) or (type(time) == "function" and time()) or 0
        local last = tonumber(self._lastShopMountDefsRequestAt or 0) or 0
        if now <= 0 or (now - last) >= 10 then
            self._lastShopMountDefsRequestAt = now
            self:RequestDefinitions("mounts", 0)
        end
    end

    self.shopItems = mapped
    self.cacheNeedsSave = true
    if type(self.ScheduleCacheAutoSave) == "function" then
        self:ScheduleCacheAutoSave()
    end
    
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

    -- If Shop UI is currently visible, repaint immediately.
    if self.ShopUI and self.ShopUI.IsShown and self.ShopUI:IsShown() and type(self.UpdateShopUI) == "function" then
        self:UpdateShopUI()
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

    local function IsNumericIconPath(texturePath)
        if type(texturePath) ~= "string" then
            return false
        end

        local normalized = string.gsub(texturePath, "/", "\\")
        local lowerPath = string.lower(normalized)
        return string.match(lowerPath, "^interface\\icons\\%d+$") ~= nil
    end

    local function NormalizeCandidateIcon(textureValue)
        local normalized = self:NormalizeTexturePath(textureValue, nil)
        if IsNumericIconPath(normalized) then
            return nil
        end
        return normalized
    end

    local function CardNeedsShopRefresh(card)
        if not card then
            return false
        end

        if not card.name or card.name == "" or card.name == "Shop Item" then
            return true
        end

        if not card.icon or card.icon == "" or card.icon == "Interface\\Icons\\INV_Misc_QuestionMark" then
            return true
        end

        if IsNumericIconPath(card.icon) then
            return true
        end

        return false
    end
    
    local needsRefresh = false
    local unresolved = 0
    for _, card in ipairs(self.shopItems) do
        if CardNeedsShopRefresh(card) then
            local typeName = card.collectionTypeName
            local itemIdToUse = card.itemId or card.entryId
            local definition = card.definition

            if (not definition) and typeName and card.entryId and type(self.GetDefinition) == "function" then
                definition = self:GetDefinition(typeName, card.entryId)
                if definition then
                    card.definition = definition
                end
            end

            if definition then
                card.itemId = card.itemId or definition.itemId or definition.itemID or definition.item_id
                card.spellId = card.spellId or definition.spellId or definition.spellID or definition.spell_id
                itemIdToUse = card.itemId or itemIdToUse

                if (card.name == "Shop Item" or card.name == "") and definition.name then
                    card.name = definition.name
                    needsRefresh = true
                end

                if CardNeedsShopRefresh(card) and definition.icon then
                    local defIcon = NormalizeCandidateIcon(definition.icon)
                    if defIcon then
                        card.icon = defIcon
                        needsRefresh = true
                    end
                end
            end
            
            if typeName == "mounts" then
                local spellId = card.spellId or card.entryId
                local tex = spellId and GetSpellTexture and GetSpellTexture(spellId)
                if tex then 
                    card.icon = tex
                    needsRefresh = true
                end
                if GetSpellInfo then
                    local name = spellId and GetSpellInfo(spellId)
                    if name and card.name == "Shop Item" then 
                        card.name = name
                        needsRefresh = true
                    end
                end
                if CardNeedsShopRefresh(card) and itemIdToUse and GetItemInfo then
                    local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemIdToUse)
                    if texture then
                        card.icon = texture
                        needsRefresh = true
                    end
                    if name and card.name == "Shop Item" then
                        card.name = name
                        needsRefresh = true
                    end
                    if quality then
                        card.rarity = quality
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

        if CardNeedsShopRefresh(card) then
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
    
    if needsRefresh then
        if self.ShopUI and self.ShopUI.IsShown and self.ShopUI:IsShown() and type(self.UpdateShopUI) == "function" then
            self:UpdateShopUI()
        end

        if self.MainFrame and self.MainFrame:IsShown() and self.activeTab == "shop" then
            if type(self.RequestRefreshCurrentTab) == "function" then
                self:RequestRefreshCurrentTab()
            else
                self:RefreshCurrentTab()
            end
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

        -- Optimistically mark purchased cards so state updates immediately.
        local function CanonicalShopTypeName(rawType)
            local t = self:GetTypeNameFromId(rawType)
            if type(t) == "string" then
                t = string.lower(t)
            end

            if (not t or t == "") and type(rawType) == "string" then
                t = string.lower(rawType)
            end

            if t == "mount" then return "mounts" end
            if t == "pet" then return "pets" end
            if t == "heirloom" then return "heirlooms" end
            if t == "title" then return "titles" end
            if t == "appearance" or t == "appearances" then return "transmog" end
            return t
        end

        local purchasedType = CanonicalShopTypeName(data.type)
        local purchasedEntryId = tonumber(data.entryId or data.entry_id)
        if purchasedType and purchasedEntryId and type(self.shopItems) == "table" then
            for _, card in ipairs(self.shopItems) do
                local cardType = CanonicalShopTypeName(card.collectionTypeName or card.collectionTypeId or card.itemType)
                local cardEntryId = tonumber(card.entryId or card.entry_id or card.entry)
                if cardType == purchasedType and cardEntryId == purchasedEntryId then
                    card.purchased = true
                    card.owned = true
                    card.collected = true
                end
            end
        end

        self._currencyLastReceivedAt = 0
        if type(self.RequestCurrencies) == "function" then
            self:RequestCurrencies()
        end

        if type(self.RequestShopHistory) == "function" then
            self:RequestShopHistory()
        end

        if type(self.RequestShopItems) == "function" then
            self:RequestShopItems()
        end

        if type(self.RefreshShopIcons) == "function" then
            self._shopIconRefreshAttempts = nil
            if self.After and type(self.After) == "function" then
                self.After(0.10, function()
                    self:RefreshShopIcons()
                end)
            else
                self:RefreshShopIcons()
            end
        end

        if self.ShopUI and self.ShopUI.IsShown and self.ShopUI:IsShown() and type(self.UpdateShopUI) == "function" then
            self:UpdateShopUI()
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
    self._currencyLastReceivedAt = (type(GetTime) == "function" and GetTime()) or
        (type(time) == "function" and time()) or 0
    if type(self._syncProgress) == "table" then
        self:CompleteSyncProgressStep("currency", "currency")
    end

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

-- Handle shop purchase history
function DC:HandleShopHistory(data)
    self:Debug("Received shop purchase history")

    self:_MarkInflight("req:shopHistory", nil)

    local items = data.items or data.entries or {}
    if type(items) ~= "table" then
        items = {}
    end

    self.purchaseHistory = items
    self.purchaseHistoryMeta = {
        count = tonumber(data.count) or #items,
        total = tonumber(data.total) or #items,
        limit = tonumber(data.limit) or #items,
        offset = tonumber(data.offset) or 0,
    }

    if self.callbacks.onShopHistoryReceived then
        self.callbacks.onShopHistoryReceived(data)
    end

    if self.ShopUI and self.ShopUI.IsShown and self.ShopUI:IsShown() and type(self.UpdateShopUI) == "function" then
        self:UpdateShopUI()
    end
end

-- Handle wishlist data
function DC:HandleWishlistData(data)
    self:Debug("Received wishlist")

    self._wishlistLastReceivedAt =
        (type(GetTime) == "function" and GetTime()) or
        (type(time) == "function" and time()) or 0
    self:_MarkInflight("req:wishlist", nil)
    if type(self._syncProgress) == "table" then
        self:CompleteSyncProgressStep("wishlist", "wishlist")
    end

    local rawWishlist = data.items or data.wishlist or data.list or {}
    if type(self.NormalizeWishlistItems) == "function" then
        self.wishlist = self:NormalizeWishlistItems(rawWishlist)
    else
        self.wishlist = rawWishlist
    end

    self.wishlistCount = data.count or #self.wishlist
    self.wishlistMaxItems = data.maxItems or 25

    DCCollectionDB = DCCollectionDB or {}
    DCCollectionDB.wishlistCache = self.wishlist

    if type(self.RefreshWishlistUI) == "function" then
        self:RefreshWishlistUI()
    end

    if type(self.PetJournal) == "table" and self.PetJournal.frame and self.PetJournal.frame:IsShown() and
        self.PetJournal.selectedPet and type(self.PetJournal.SelectPet) == "function" then
        self.PetJournal:SelectPet(self.PetJournal.selectedPet)
    end

    if type(self.MountJournal) == "table" and self.MountJournal.frame and self.MountJournal.frame:IsShown() and
        self.MountJournal.selectedMount and type(self.MountJournal.SelectMount) == "function" then
        self.MountJournal:SelectMount(self.MountJournal.selectedMount)
    end
    
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
        self._wishlistLastReceivedAt = 0
        self:RequestWishlist(true)
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

    local hasPerSlot = (type(data) == "table" and type(data.perSlot) == "table")
    if hasPerSlot then
        -- Keep normal chat clean; detailed per-slot reasons go to dcdebug.
        self:Print("|cffff0000Error:|r " .. errorMsg .. " |cff888888(details in dcdebug)|r")
    else
        self:Print("|cffff0000Error:|r " .. errorMsg)
    end

    -- Title apply diagnostics: surface recent title request context.
    local titleReq = self._lastTitleRequest
    if type(titleReq) == "table" then
        local now = (type(GetTime) == "function") and GetTime() or 0
        local age = now - (tonumber(titleReq.sentAt) or 0)
        local msgLower = string.lower(tostring(errorMsg or ""))
        local titleRelated = string.find(msgLower, "title", 1, true) ~= nil

        if titleRelated or age <= 6 then
            self:Print(string.format(
                "|cffffcc00[TitleDebug]|r request raw=%s numeric=%s age=%.1fs error=%s",
                tostring(titleReq.rawEntryId),
                tostring(titleReq.entryId),
                age,
                tostring(errorMsg)
            ))

            if string.find(msgLower, "title not in collection", 1, true) or
                (titleRelated and string.find(msgLower, "not in collection", 1, true)) then
                local titles = self.collections and self.collections.titles
                local staleId = tonumber(titleReq.entryId)
                local removed = false

                if titles and staleId then
                    if titles[staleId] ~= nil then
                        titles[staleId] = nil
                        removed = true
                    end

                    local staleIdStr = tostring(staleId)
                    if titles[staleIdStr] ~= nil then
                        titles[staleIdStr] = nil
                        removed = true
                    end
                end

                if removed and type(self._BumpCollectionsRevision) == "function" then
                    self:_BumpCollectionsRevision("titles")
                end

                if removed then
                    self.cacheNeedsSave = true
                end

                if type(self.RequestCollection) == "function" then
                    self:RequestCollection("title")
                end
            end

            if type(self.LogNetEvent) == "function" then
                self:LogNetEvent("error", "title", "Title apply failed", {
                    requestedRaw = titleReq.rawEntryId,
                    requestedEntryId = titleReq.entryId,
                    ageSeconds = age,
                    code = errorCode,
                    error = errorMsg,
                })
            end
        end
    end

    -- Mark pending outfit apply as having received a server error (to avoid duplicate messages)
    if self.Wardrobe and self.Wardrobe._pendingApplyOutfit then
        self.Wardrobe._pendingApplyOutfit.hadServerError = true
    end

    -- Optional structured details (used for transmog apply diagnostics).
    if hasPerSlot then
        local order = {}
        for k in pairs(data.perSlot) do
            table.insert(order, k)
        end
        table.sort(order, function(a, b)
            return tonumber(a) < tonumber(b)
        end)

        local SLOT_NAMES = {
            [0] = "Head", [1] = "Neck", [2] = "Shoulder", [3] = "Shirt", [4] = "Chest",
            [5] = "Waist", [6] = "Legs", [7] = "Feet", [8] = "Wrist", [9] = "Hands",
            [10] = "Finger1", [11] = "Finger2", [12] = "Trinket1", [13] = "Trinket2",
            [14] = "Back", [15] = "MainHand", [16] = "OffHand", [17] = "Ranged", [18] = "Tabard",
        }

        self:Debug("Transmog apply details:")
        for _, slotKey in ipairs(order) do
            local slotNum = tonumber(slotKey)
            local slotName = SLOT_NAMES[slotNum] or ("Slot " .. tostring(slotKey))
            local reason = data.perSlot[slotKey]
            if type(reason) == "table" then
                reason = reason.reason or reason.status or reason.message or "unknown"
            end
            self:Debug(string.format(" - %s: %s", slotName, tostring(reason)))
        end
    end

    if type(self.LogNetEvent) == "function" then
        self:LogNetEvent("error", "server", errorMsg, { code = errorCode })
    end
    
    -- Fire callback
    if self.callbacks.onError then
        self.callbacks.onError(data)
    end
end

-- Schedule a delayed refresh for transmog icons after items are cached
function DC:_ScheduleTransmogIconRefresh()
    if self._transmogIconRefreshFrame then
        -- Already scheduled
        return
    end

    local f = CreateFrame("Frame")
    f.elapsed = 0
    f.attempts = 0
    f:SetScript("OnUpdate", function(frame, dt)
        frame.elapsed = (frame.elapsed or 0) + (dt or 0)
        if frame.elapsed < 0.15 then
            return
        end
        frame.elapsed = 0
        frame.attempts = (frame.attempts or 0) + 1

        -- Check if all items are now cached
        local allCached = true
        local itemIds = DC.transmogItemIds or {}
        for _, itemId in pairs(itemIds) do
            local id = tonumber(itemId)
            if id and id > 0 then
                if not GetItemInfo(id) then
                    allCached = false
                    break
                end
            end
        end

        -- Refresh UI if all cached or after max attempts
        if allCached or frame.attempts >= 20 then
            frame:SetScript("OnUpdate", nil)
            DC._transmogIconRefreshFrame = nil

            -- Refresh slot buttons with now-cached icons (use IsVisible for embedded mode)
            local wardrobeVisible = DC.Wardrobe and DC.Wardrobe.frame and
                ((DC.Wardrobe.frame.IsVisible and DC.Wardrobe.frame:IsVisible()) or
                 (DC.Wardrobe.frame.IsShown and DC.Wardrobe.frame:IsShown()))
            if wardrobeVisible then
                if type(DC.Wardrobe.UpdateSlotButtons) == "function" then
                    pcall(function() DC.Wardrobe:UpdateSlotButtons() end)
                end
                -- Also refresh the outfits grid if on that tab
                if DC.Wardrobe.currentTab == "outfits" and type(DC.Wardrobe.RefreshOutfitsGrid) == "function" then
                    pcall(function() DC.Wardrobe:RefreshOutfitsGrid() end)
                end
            end

            local transmogUIVisible = DC.TransmogUI and DC.TransmogUI.frame and
                ((DC.TransmogUI.frame.IsVisible and DC.TransmogUI.frame:IsVisible()) or
                 (DC.TransmogUI.frame.IsShown and DC.TransmogUI.frame:IsShown()))
            if transmogUIVisible then
                if type(DC.TransmogUI.UpdateSlotButtons) == "function" then
                    pcall(function() DC.TransmogUI:UpdateSlotButtons() end)
                end
            end
        end
    end)

    self._transmogIconRefreshFrame = f
end

function DC:HandleTransmogState(data)
    local function normalizeSlotMap(tbl)
        if type(tbl) ~= "table" then
            return {}
        end

        local out = {}
        local hasStringSlotKey = false
        local minNumKey = nil
        local maxNumKey = nil

        for k, v in pairs(tbl) do
            if type(k) == "string" then
                local nk = tonumber(k)
                if nk ~= nil then
                    hasStringSlotKey = true
                    out[tostring(nk)] = v
                end
            elseif type(k) == "number" then
                minNumKey = (minNumKey == nil) and k or math.min(minNumKey, k)
                maxNumKey = (maxNumKey == nil) and k or math.max(maxNumKey, k)
            end
        end

        -- If the decoder already gave us string slot keys ("0", "1", ...), those are authoritative.
        if hasStringSlotKey then
            for k, v in pairs(tbl) do
                if type(k) == "number" then
                    out[tostring(k)] = out[tostring(k)] or v
                end
            end
            return out
        end

        -- Otherwise, handle numeric-key tables.
        -- Some JSON decoders convert {"0":x,"1":y} into an array-like table { [1]=x, [2]=y, ... }.
        local shift = 0
        if minNumKey ~= nil and minNumKey == 1 then
            shift = -1
        end

        for k, v in pairs(tbl) do
            if type(k) == "number" then
                out[tostring(k + shift)] = v
            end
        end
        return out
    end

    local state = normalizeSlotMap(data.state)
    local itemIds = normalizeSlotMap(data.itemIds)

    self.transmogState = state
    self.transmogItemIds = itemIds  -- Store item entries for TryOn/outfit save
    self._transmogStateLastReceivedAt =
        (type(GetTime) == "function" and GetTime()) or
        (type(time) == "function" and time()) or 0

    DCCollectionCharDB = DCCollectionCharDB or {}
    DCCollectionCharDB.transmogState = state
    DCCollectionCharDB.transmogItemIds = itemIds

    -- Pre-cache all transmog item IDs so their icons are available
    local needsDelayedRefresh = false
    for _, itemId in pairs(itemIds) do
        local id = tonumber(itemId)
        if id and id > 0 then
            local name = GetItemInfo(id)
            if not name then
                needsDelayedRefresh = true
            end
        end
    end

    -- Refresh UI if open
    if self.UI and self.UI.mainFrame and self.UI.mainFrame:IsShown() then
        self.UI:RefreshCurrentTab()
    end

    -- Refresh Wardrobe slot buttons (use IsVisible() to handle embedded mode where parent shows the frame)
    local wardrobeVisible = self.Wardrobe and self.Wardrobe.frame and 
        ((self.Wardrobe.frame.IsVisible and self.Wardrobe.frame:IsVisible()) or 
         (self.Wardrobe.frame.IsShown and self.Wardrobe.frame:IsShown()))
    if wardrobeVisible then
        if type(self.Wardrobe.UpdateSlotButtons) == "function" then
            pcall(function() self.Wardrobe:UpdateSlotButtons() end)
        end

        if type(self.Wardrobe.UpdateModel) == "function" then
            pcall(function() self.Wardrobe:UpdateModel() end)
        end
    end

    -- If some transmog items weren't cached, schedule a delayed refresh
    if needsDelayedRefresh then
        self:_ScheduleTransmogIconRefresh()
    end

    -- Retry a deferred outfit save once we have transmog state.
    if self.Wardrobe and self.Wardrobe._pendingSaveOutfitName and type(self.Wardrobe.SaveCurrentOutfit) == "function" then
        local n = self.Wardrobe._pendingSaveOutfitName
        self.Wardrobe._pendingSaveOutfitName = nil
        pcall(function() self.Wardrobe:SaveCurrentOutfit(n) end)
    end

    if self.Wardrobe and type(self.Wardrobe.InvalidateRandomizerCache) == "function" then
        self.Wardrobe:InvalidateRandomizerCache()
    end

    if self.Wardrobe and type(self.Wardrobe.OnTransmogStateReceived) == "function" then
        pcall(function() self.Wardrobe:OnTransmogStateReceived(state) end)
    end

    -- Refresh Transmog UI (if used) and borders even when no inventory events fire.
    if self.TransmogUI and type(self.TransmogUI.OnTransmogStateReceived) == "function" then
        pcall(function() self.TransmogUI:OnTransmogStateReceived(state, itemIds) end)
    end

    if self.TransmogBorders and type(self.TransmogBorders.UpdateCharacterBorders) == "function" then
        pcall(function() self.TransmogBorders:UpdateCharacterBorders() end)
    end

    if type(self.MaybeApplyLastOutfitOnLogin) == "function" then
        pcall(function() self:MaybeApplyLastOutfitOnLogin(state) end)
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
    local syncVersion = tonumber(data.syncVersion or data.version)

    if syncVersion ~= nil and type(self._SetTransmogOwnedSyncVersion) == "function" then
        self:_SetTransmogOwnedSyncVersion(syncVersion)
    end

    if data and (data.upToDate == true or data.up_to_date == true) then
        self.collections = self.collections or {}
        self.collections.transmog = self.collections.transmog or {}
        self.collectedAppearances = self.collectedAppearances or {}

        if self._pendingCollectionHash then
            self.collectionHash = self._pendingCollectionHash
            self._pendingCollectionHash = nil
        end

        self:_MarkInflight("req:coll:transmog", nil)
        if type(self._syncProgress) == "table" then
            self:CompleteSyncProgressStep("coll:transmog", "collection: transmog")
        end

        self:Debug("Collected appearances are up to date")

        if self.callbacks.onCollectedAppearances then
            self.callbacks.onCollectedAppearances(self.collectedAppearances)
        end
        return
    end

    local authoritative, count, mode = BuildCollectedAppearancesCollection(self,
        appearances, items)

    if type(self.SetCollection) == "function" then
        self:SetCollection("transmog", authoritative)
    else
        self.collections = self.collections or {}
        self.collections.transmog = authoritative
    end

    if type(self._SyncCollectedAppearancesFromCollection) == "function" then
        self:_SyncCollectedAppearancesFromCollection(authoritative)
    end

    if self._pendingCollectionHash then
        self.collectionHash = self._pendingCollectionHash
        self._pendingCollectionHash = nil
    end

    self:_MarkInflight("req:coll:transmog", nil)
    if type(self._syncProgress) == "table" then
        self:CompleteSyncProgressStep("coll:transmog", "collection: transmog")
    end

    if mode == "appearances" then
        self:Debug(string.format("Received %d collected appearances", count))
    elseif mode == "items" then
        self:Debug(string.format("Received collected appearances via items (mapped %d)", count))
    else
        self:Debug("Received 0 collected appearances")
    end

    if self.MainFrame and self.MainFrame:IsShown() then
        if type(self.RequestRefreshCurrentTab) == "function" then
            self:RequestRefreshCurrentTab()
        else
            self:RefreshCurrentTab()
        end
    end

    if self.Wardrobe and self.Wardrobe.frame and self.Wardrobe.frame:IsShown() then
        if type(self.Wardrobe.RequestDataRefreshDebounced) == "function" then
            self.Wardrobe:RequestDataRefreshDebounced("collected_appearances")
        elseif type(self.Wardrobe.RefreshGrid) == "function" then
            self.Wardrobe:RefreshGrid()
        end
    end

    if self.Wardrobe and type(self.Wardrobe.InvalidateRandomizerCache) == "function" then
        self.Wardrobe:InvalidateRandomizerCache()
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

-- Returns true if we currently have any transmog definitions cached locally.
-- This prevents getting stuck when the cache is empty but a saved syncVersion still matches.
function DC:_HasAnyTransmogDefinitions()
    local defs = nil
    if type(self.definitions) == "table" then
        defs = self.definitions.transmog
    end
    if type(defs) ~= "table" then
        defs = self._transmogDefinitions
    end
    if type(defs) ~= "table" then
        return false
    end
    return next(defs) ~= nil
end

function DC:HandleDefinitions(data)
    local rawType = data.type
    local collType = (type(self.NormalizeCollectionType) == "function" and self:NormalizeCollectionType(rawType)) or rawType
    local defsProgressKey = "defs:" .. tostring(collType)
    local defsProgressLabel = "definitions: " .. tostring(collType)
    if type(self._syncProgress) == "table" then
        self:StartSyncProgressStep(defsProgressKey, defsProgressLabel)
    end
    
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
        self:_StopTransmogFirstPageWatchdog(false)
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

    -- When transmog definitions are updated, clear the Wardrobe's itemId->displayId cache
    -- so it gets rebuilt with the new data.
    if collType == "transmog" and DC.Wardrobe and type(DC.Wardrobe.ClearItemIdToDisplayIdCache) == "function" then
        DC.Wardrobe:ClearItemIdToDisplayIdCache()
    end

    if collType == "transmog" and type(self._HasAnyTransmogDefinitions) == "function" and
       self:_HasAnyTransmogDefinitions() then
        self.definitionsLoaded = true
        if self.Wardrobe then
            self.Wardrobe.definitionsLoaded = true
        end
    end

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

    -- Mount preview diagnostics: surface when server definitions are missing model/display hints.
    if collType == "mounts" then
        local total = 0
        local missing = 0
        local samples = {}

        for id, def in pairs(definitions or {}) do
            total = total + 1
            local displayId = nil
            local creatureId = nil

            if type(def) == "table" then
                displayId = tonumber(def.previewDisplayId or def.preview_display_id or def.displayId or def.display_id or def.creatureDisplayId or def.creature_display_id or def.modelId or def.model_id)
                creatureId = tonumber(def.previewCreatureId or def.preview_creature_id or def.creatureId or def.creature_id or def.creatureID or def.entryId or def.entry_id or def.entry)
            end

            if not displayId and not creatureId then
                missing = missing + 1
                if #samples < 6 then
                    table.insert(samples, tostring(id))
                end
            end
        end

        if total > 0 then
            self:Debug(string.format("Mount defs preview data: missing=%d/%d", missing, total))
        end

        if missing > 0 then
            local now = (type(GetTime) == "function" and GetTime()) or (type(time) == "function" and time()) or 0
            local shouldPrint = true
            if now > 0 and self._lastMountDefsMissingWarnAt and (now - self._lastMountDefsMissingWarnAt) < 30 then
                shouldPrint = false
            end
            if now > 0 then
                self._lastMountDefsMissingWarnAt = now
            end

            if shouldPrint then
                self:Print(string.format("|cffffcc00[Mount Preview]|r %d/%d mount definitions have no model data. Example spell IDs: %s",
                    missing,
                    total,
                    (#samples > 0 and table.concat(samples, ", ") or "n/a")))
            end

            if type(self.LogNetEvent) == "function" then
                self:LogNetEvent("warn", "mount", "Mount definitions missing preview model data", {
                    missing = missing,
                    total = total,
                    examples = samples,
                })
            end
        end
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
        if type(DC.Wardrobe.RequestDataRefreshDebounced) == "function" then
            DC.Wardrobe:RequestDataRefreshDebounced("definitions_" .. tostring(collType))
        elseif DC.Wardrobe.currentTab == "sets" then
            DC.Wardrobe:RefreshSetsGrid()
        else
            DC.Wardrobe:RefreshGrid()
        end
    end
    
    self:Debug(string.format("Received %d definitions for %s", 
        self:TableCount(definitions), collType))

    -- Transmog definitions can be very large; server may send them in pages.
    if collType == "transmog" then
        local receivedCount = self:TableCount(definitions)
        local totalFromServer = tonumber(data.total or data.count) or 0

        if upToDate == true or upToDate == 1 or upToDate == "1" then
            DCCollectionDB = DCCollectionDB or {}
            DCCollectionDB.transmogDefsIncomplete = nil
            DCCollectionDB.transmogDefsResumeOffset = nil
            DCCollectionDB.transmogDefsResumeLimit = nil
            DCCollectionDB.transmogDefsResumeTotal = nil
            DCCollectionDB.transmogDefsResumeUpdatedAt = nil

            -- Server says definitions are up-to-date.
            -- If local cache is empty, force a full download once.
            -- Only warn about server misconfiguration when the server explicitly reports total=0.
            if not self:_HasAnyTransmogDefinitions() then
                if totalFromServer == 0 then
                    -- Server's transmog index is empty (or not built yet) - likely a server-side issue.
                    self:Print("|cffff6600[Warning]|r Server has no transmog definitions. "
                        .. "Wardrobe features may not work correctly. "
                        .. "Server admin should check that item_template is populated.")
                    self._transmogDefLoading = nil
                    self:_MarkInflight("req:defs:transmog", nil)
                    if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                        self.Wardrobe:UpdateTransmogLoadingProgressUI(false)
                    end
                    if type(self._syncProgress) == "table" then
                        self:CompleteSyncProgressStep(defsProgressKey, defsProgressLabel)
                    end
                    return
                end

                -- Local cache empty but server has data - force a full download once.
                if not self._transmogDefsForcedFullDownload then
                    self._transmogDefsForcedFullDownload = true
                    self:Debug("Transmog definitions reported up-to-date but local cache is empty; forcing full download")
                    self._transmogDefLoading = nil
                    self:_MarkInflight("req:defs:transmog", nil)
                    if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                        self.Wardrobe:UpdateTransmogLoadingProgressUI(false)
                    end
                    self:RequestDefinitions("transmog", 0)
                    return
                end
            end

            self:Debug("Transmog definitions up-to-date; skipping download")
            self._transmogDefLoading = nil
            self:_MarkInflight("req:defs:transmog", nil)
            self._transmogDefsConfirmedCurrentAt =
                (type(GetTime) == "function" and GetTime()) or
                (type(time) == "function" and time()) or 0
            if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                self.Wardrobe:UpdateTransmogLoadingProgressUI(false)
            end
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep(defsProgressKey, defsProgressLabel)
            end
            return
        end

        -- Slow down paging to avoid disconnects on some servers/clients.
        -- Default to 0.75s unless overridden elsewhere.
        self._transmogPagingInterval = self._transmogPagingInterval or 0.75

        local requestedOffset = tonumber(data.offset or data.off) or tonumber(self._transmogDefLastRequestedOffset) or 0
        local requestedLimit = tonumber(data.limit or data.lim) or tonumber(self._transmogDefLastRequestedLimit) or tonumber(self._transmogDefLimit) or 250
        if requestedLimit < 50 then requestedLimit = 50 end
        if requestedLimit > 250 then requestedLimit = 250 end
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

            if type(self._syncProgress) == "table" then
                local loadedSoFar = self:TableCount(self.definitions and self.definitions.transmog)
                local totalKnown = tonumber(self._transmogDefTotal)
                if totalKnown and totalKnown > 0 then
                    self:StartSyncProgressStep(defsProgressKey,
                        string.format("definitions: transmog (%d/%d items)", loadedSoFar, totalKnown))
                else
                    self:StartSyncProgressStep(defsProgressKey,
                        string.format("definitions: transmog (%d items)", loadedSoFar))
                end
            end

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
                if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                    self.Wardrobe:UpdateTransmogLoadingProgressUI(false)
                end
                if type(self._syncProgress) == "table" then
                    self:CompleteSyncProgressStep(defsProgressKey, defsProgressLabel .. " (stopped)")
                end
                return
            end

            QueuePagingDelayRequest(self, "_transmogPagingDelayFrame", {
                offset = nextOffset,
                limit = requestedLimit,
            }, TRANSMOG_PAGING_DELAY_OPTIONS)

            if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                self.Wardrobe:UpdateTransmogLoadingProgressUI(true)
            end
        else
            -- Paging complete: commit syncVersion only now (prevents upToDate when we only had partial data).
            if self._pendingSyncVersions and self._pendingSyncVersions.transmog ~= nil then
                self:SetSyncVersion("transmog", self._pendingSyncVersions.transmog)
                self._pendingSyncVersions.transmog = nil
            elseif type(self._serverSyncVersions) == "table" then
                local serverVersion = tonumber(
                    self._serverSyncVersions.transmog or
                    self._serverSyncVersions.appearances)
                if serverVersion and serverVersion > 0 and self:_HasAnyTransmogDefinitions() then
                    self:SetSyncVersion("transmog", serverVersion)
                end
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
            self:_StopTransmogFirstPageWatchdog(true)
            self._transmogDefsConfirmedCurrentAt =
                (type(GetTime) == "function" and GetTime()) or
                (type(time) == "function" and time()) or 0

            -- Clear any deferred item set load.
            -- Item sets should be fetched on-demand (Sets tab) to avoid large transfers starving other UI.
            self._deferItemSetsUntilTransmogComplete = nil

            if self.Wardrobe and type(self.Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                self.Wardrobe:UpdateTransmogLoadingProgressUI(false)
            end
            if type(self._syncProgress) == "table" then
                self:CompleteSyncProgressStep(defsProgressKey, defsProgressLabel)
            end
        end
    elseif type(self._syncProgress) == "table" then
        self:CompleteSyncProgressStep(defsProgressKey, defsProgressLabel)
    end
end

function DC:HandleCollection(data)
    local rawType = data.type
    local collType = (type(self.NormalizeCollectionType) == "function" and self:NormalizeCollectionType(rawType)) or rawType
    local collProgressKey = "coll:" .. tostring(collType)
    local collProgressLabel = "collection: " .. tostring(collType)
    local items = data.items or {}
    local receivedAt = (type(GetTime) == "function" and GetTime()) or
        (type(time) == "function" and time()) or 0

    self._collectionLastReceivedAt = self._collectionLastReceivedAt or {}
    self._collectionLastReceivedAt[collType] = receivedAt

    if collType == "titles" then
        self._titleCollectionAuthoritative = true
        self._titleCollectionLastReceivedAt = receivedAt
        if DCCollectionDB then
            DCCollectionDB.titleCollectionAuthoritative = true
            DCCollectionDB.titleCollectionLastReceivedAt = time()
        end
    end

    -- Some servers/bridges return arrays instead of id->entry maps.
    -- Normalize arrays to map form so CacheMergeCollection stores by entry id.
    if type(items) == "table" and #items > 0 then
        local mapped = {}
        for _, entry in ipairs(items) do
            local entryId = nil
            local entryData = nil

            if type(entry) == "table" then
                entryId = entry.id or entry.entryId or entry.entry_id
                entryData = entry
            else
                entryId = entry
                entryData = { owned = true }
            end

            if entryId ~= nil then
                mapped[entryId] = entryData
            end
        end

        if next(mapped) ~= nil then
            items = mapped
        end
    end
    
    if collType == "titles" and type(self.SetCollection) == "function" then
        -- Title collection is authoritative from server. Replace stale local keys,
        -- but preserve per-item local metadata (favorite/active flags) when possible.
        local current = (self.collections and self.collections.titles) or {}
        local authoritative = {}

        for itemId, itemData in pairs(items) do
            local normalizedId = tonumber(itemId) or itemId
            local existing = current[normalizedId] or current[tostring(normalizedId)]
            local merged = {}

            if type(existing) == "table" then
                for k, v in pairs(existing) do
                    merged[k] = v
                end
            end

            if type(itemData) == "table" then
                for k, v in pairs(itemData) do
                    merged[k] = v
                end
            end

            if next(merged) == nil then
                merged.owned = true
            end

            authoritative[normalizedId] = merged
        end

        self:SetCollection(collType, authoritative)
    else
        self:CacheMergeCollection(collType, items)
    end

    if collType == "transmog" and type(self._SyncCollectedAppearancesFromCollection) == "function" then
        self:_SyncCollectedAppearancesFromCollection(
            self.collections and self.collections.transmog or items)
    end
    if collType == "titles" and self.TitleModule and
       type(self.TitleModule.OnAuthoritativeCollectionUpdated) == "function" then
        self.TitleModule:OnAuthoritativeCollectionUpdated()
    end
    -- Cache will be saved by auto-save timer or on logout

    -- Release inflight guard for this type.
    self:_MarkInflight("req:coll:" .. tostring(collType), nil)
    if collType == "pets" then
        self:_MarkInflight("req:coll:pet", nil)
        self:_MarkInflight("req:coll:pets", nil)
    end
    if type(self._syncProgress) == "table" then
        self:CompleteSyncProgressStep(collProgressKey, collProgressLabel)
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
        if type(DC.Wardrobe.RequestDataRefreshDebounced) == "function" then
            DC.Wardrobe:RequestDataRefreshDebounced("collection_" .. tostring(collType))
        else
            DC.Wardrobe:RefreshGrid()
        end
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
    return self:HandleCurrencies(data)
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
    self:HandleWishlistData(data)
end

function DC:HandleTitleSet(data)
    if data.success then
        -- Title set successfully
    else
        self:Print("|cffff0000" .. (data.error or DC.L["ERR_TITLE_NOT_OWNED"]) .. "|r")
    end
end

function DC:HandleStats(data)
    self._statsLastReceivedAt = (type(GetTime) == "function" and GetTime()) or
        (type(time) == "function" and time()) or 0
    self:_MarkInflight("req:stats", nil)

    if type(self._syncProgress) == "table" then
        self:CompleteSyncProgressStep("stats", "stats")
    end

    -- Store raw stats for legacy compatibility
    local sawServerTitleStats = false
    for rawType, stats in pairs(data.stats or {}) do
        if type(stats) == "table" then
            local collType =
                (type(self.NormalizeCollectionType) == "function" and
                    self:NormalizeCollectionType(rawType)) or rawType

            if collType == "titles" then
                sawServerTitleStats = true
            end

            if self.stats[collType] then
                self.stats[collType].owned =
                    tonumber(stats.owned or stats.collected) or 0
                self.stats[collType].total = tonumber(stats.total) or 0
            end
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
    for rawType, stats in pairs(statsData) do
        if type(stats) == "table" and
            (stats.owned ~= nil or stats.collected ~= nil or
                stats.total ~= nil) then
            local collType =
                (type(self.NormalizeCollectionType) == "function" and
                    self:NormalizeCollectionType(rawType)) or rawType

            if collType == "titles" then
                sawServerTitleStats = true
            end

            self.collectionStats[collType] = {
                collected = tonumber(stats.owned or stats.collected) or 0,
                total = tonumber(stats.total) or 0,
            }

            if self.stats[collType] then
                self.stats[collType].owned =
                    self.collectionStats[collType].collected
                self.stats[collType].total =
                    self.collectionStats[collType].total
            end
        end
    end

    self._titleStatsFromServer = sawServerTitleStats and true or nil

    -- Fallback only when server did not provide title stats in this payload.
    if (not sawServerTitleStats) and self.TitleModule and
        type(self.TitleModule.GetStats) == "function" then
        local ok, titleStats = pcall(self.TitleModule.GetStats,
            self.TitleModule)
        if ok and type(titleStats) == "table" then
            local owned = tonumber(titleStats.owned) or 0
            local total = tonumber(titleStats.total) or 0

            self.stats.titles = self.stats.titles or { owned = 0, total = 0 }
            self.stats.titles.owned = owned
            self.stats.titles.total = total

            self.collectionStats.titles = {
                collected = owned,
                total = total,
            }
        end
    end
    
    -- Handle recent additions if included
    if data.recent then
        if type(self.SetRecentAdditions) == "function" then
            self:SetRecentAdditions(data.recent)
        else
            self.recentAdditions = data.recent
            if DCCollectionDB then
                DCCollectionDB.recentAdditions = data.recent
                DCCollectionDB.recentAdditionsUpdatedAt = time()
            end
        end
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

    if collType == "transmog" then
        self.collectedAppearances = self.collectedAppearances or {}
        self.collectedAppearances[itemId] = true
    end
    
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

-- NOTE: DC:HandleError is defined earlier with richer handling.
-- Keep only one implementation to avoid accidentally ignoring server-provided `error` fields.

-- ============================================================================
-- SYNC FUNCTIONS
-- ============================================================================

-- Full sync - request all data
function DC:FullSync()
    self:Print(DC.L["SYNC_STARTED"] or "Syncing collection data...")

    self:BeginSyncProgress("full-sync", {
        { key = "defs:mounts", label = "definitions: mounts" },
        { key = "defs:pets", label = "definitions: pets" },
        { key = "defs:heirlooms", label = "definitions: heirlooms" },
        { key = "defs:transmog", label = "definitions: transmog" },
        { key = "defs:titles", label = "definitions: titles" },
        { key = "coll:mounts", label = "collection: mounts" },
        { key = "coll:pets", label = "collection: pets" },
        { key = "coll:heirlooms", label = "collection: heirlooms" },
        { key = "coll:transmog", label = "collection: transmog" },
        { key = "coll:titles", label = "collection: titles" },
        { key = "shop", label = "shop data" },
        { key = "currency", label = "currency" },
        { key = "stats", label = "stats" },
        { key = "wishlist", label = "wishlist" },
    })
    
    -- Request definitions for all types
    for _, collType in ipairs({"mounts", "pets", "heirlooms", "transmog", "titles"}) do
        self:RequestDefinitions(collType)
        self:RequestCollection(collType)
    end
    
    -- Request additional data
    self:RequestShopItems()
    self:RequestCurrency()
    self:RequestStats()
    self:RequestWishlist()
end

-- Delta sync - only request changes
function DC:DeltaSync()
    self:Debug("Starting delta sync...")

    self:BeginSyncProgress("delta-sync", {
        { key = "defs:mounts", label = "definitions: mounts" },
        { key = "defs:pets", label = "definitions: pets" },
        { key = "defs:heirlooms", label = "definitions: heirlooms" },
        { key = "defs:transmog", label = "definitions: transmog" },
        { key = "defs:titles", label = "definitions: titles" },
        { key = "coll:mounts", label = "collection: mounts" },
        { key = "coll:pets", label = "collection: pets" },
        { key = "coll:heirlooms", label = "collection: heirlooms" },
        { key = "coll:transmog", label = "collection: transmog" },
        { key = "coll:titles", label = "collection: titles" },
        { key = "shop", label = "shop data" },
        { key = "currency", label = "currency" },
        { key = "stats", label = "stats" },
    })
    
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
    
    self:RequestShopItems()
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
    self:RequestAchievements()
end

-- ============================================================================
-- HANDLERS: Item Sets (SMSG_ITEM_SETS)
-- ============================================================================

function DC:OnMsg_ItemSets(data)
    if not data then
        return
    end

    local staticState = self._localCollectionCDBC
    if type(staticState) == "table" then
        staticState.itemSetsSource = "runtime"
        staticState.authoritativeItemSets = false
        staticState.setsLoaded = true
    end

    DC.definitions = DC.definitions or {}
    DC.definitions.itemsets = DC.definitions.itemsets or {}
    DC.definitions.itemSets = DC.definitions.itemsets

    -- Some servers do not echo offset/limit; fall back to the last request parameters.
    local req = self.pendingRequests and self.pendingRequests[self.Opcodes.CMSG_GET_ITEM_SETS]
    local nativeReq = self._nativeItemSetsLastRequest
    if type(nativeReq) ~= "table" or nativeReq.owner ~= "collection" then
        nativeReq = nil
    end

    local reqData = (req and req.data) or nativeReq
    if self.pendingRequests then
        self.pendingRequests[self.Opcodes.CMSG_GET_ITEM_SETS] = nil
    end

    if not self._itemSetsLoading and reqData == nil then
        self:Debug("Ignoring unsolicited item sets response (no active paging run)")
        return
    end

    local offset = tonumber(data.offset)
    local limit = tonumber(data.limit)
    if reqData then
        local reqOffset = tonumber(reqData.offset)
        local reqLimit = tonumber(reqData.limit)
        if offset == nil and reqOffset ~= nil then
            offset = reqOffset
        elseif offset == 0 and reqOffset ~= nil and reqOffset > 0 then
            -- Some servers incorrectly echo offset=0 for every page; prefer the requested offset.
            offset = reqOffset
        end
        if limit == nil and reqLimit ~= nil then
            limit = reqLimit
        end
    end
    offset = offset or 0
    limit = limit or tonumber(self._itemSetsLimit) or 50
    local total = tonumber(data.total) or nil
    local hasMore = data.hasMore
    if hasMore == nil then hasMore = data.more end
    if hasMore == nil then hasMore = data.has_more end
    hasMore = (hasMore == true or hasMore == 1 or hasMore == "1")

    local upToDate = data.upToDate
    if upToDate == nil then upToDate = data.up_to_date end
    upToDate = (upToDate == true or upToDate == 1 or upToDate == "1")

    local syncVersion = tonumber(data.syncVersion or data.version) or nil

    -- If the server says our cached payload is current, keep existing tables.
    if upToDate and offset == 0 then
        if syncVersion ~= nil and type(self.SetSyncVersion) == "function" then
            self:SetSyncVersion("itemsets", syncVersion)
        end

        self._itemSetsLoading = nil
        self._nativeItemSetsLastRequest = nil
        self.itemSetsLoaded = true
        return
    end

    -- Capture syncVersion at the start of a paging run; commit only when complete.
    if offset == 0 and syncVersion ~= nil then
        self._pendingSyncVersions = self._pendingSyncVersions or {}
        self._pendingSyncVersions.itemsets = syncVersion
    end

    -- Clear only when starting a fresh paging run.
    if offset == 0 then
        wipe(DC.definitions.itemsets)
    end

    -- Packed payload format (reduces JSON key overhead):
    -- data = { packed=1, data="<lines>", ... }
    -- line format: id;urlenc(name);item1,item2,item3
    local isPacked = (data.packed == true or data.packed == 1 or data.packed == "1")
    local packedData = isPacked and data.data or nil

    local function UrlDecode(s)
        if type(s) ~= "string" or s == "" then
            return s
        end
        s = s:gsub("%%(%x%x)", function(hex)
            return string.char(tonumber(hex, 16))
        end)
        return s
    end

    local count = 0
    local added = 0
    if type(packedData) == "string" and packedData ~= "" then
        for line in packedData:gmatch("[^\n]+") do
            local idStr, nameEnc, itemsCsv = line:match("^(%d+);([^;]*);?(.*)$")
            local setId = tonumber(idStr)
            if setId then
                local name = UrlDecode(nameEnc or "")
                if name == "" then
                    name = "Set " .. setId
                end

                local items = {}
                if itemsCsv and itemsCsv ~= "" then
                    for num in itemsCsv:gmatch("%d+") do
                        items[#items + 1] = tonumber(num)
                    end
                end

                local isNew = (DC.definitions.itemsets[setId] == nil)
                DC.definitions.itemsets[setId] = {
                    ID = setId,
                    name = name,
                    items = items,
                }
                count = count + 1
                if isNew then
                    added = added + 1
                end
            end
        end
    elseif type(data.sets) == "table" then
        for _, set in ipairs(data.sets) do
            if set.id and set.items then
                local isNew = (DC.definitions.itemsets[set.id] == nil)
                -- Store definition
                DC.definitions.itemsets[set.id] = {
                    ID = set.id,
                    name = set.name or ("Set " .. set.id),
                    items = set.items,
                }
                count = count + 1
                if isNew then
                    added = added + 1
                end
            end
        end
    else
        return
    end

    self:Debug("Received " .. count .. " item sets definitions.")
    
    -- Paging support: request remaining pages.
    -- If the server ignores paging and keeps returning the same page, stop to prevent infinite loops.
    if hasMore and offset > 0 and added == 0 then
        local respOffset = tonumber(data.offset)
        local reqOffset = reqData and tonumber(reqData.offset) or nil
        if respOffset == nil or (respOffset == 0 and reqOffset ~= nil and reqOffset > 0) then
            hasMore = false
        end
    end

    if hasMore then
        local nextOffset = tonumber(data.nextOffset or data.next_offset) or (offset + limit)
        self._itemSetsOffset = nextOffset
        self._itemSetsLimit = limit

        QueuePagingDelayRequest(self, "_itemSetsPagingDelayFrame", {
            offset = nextOffset,
            limit = limit,
        }, ITEM_SETS_PAGING_DELAY_OPTIONS)
        return
    end

    self._itemSetsLoading = nil
    self._nativeItemSetsLastRequest = nil
    self.itemSetsLoaded = true -- Mark as loaded to prevent re-requesting

    if self._pendingSyncVersions and self._pendingSyncVersions.itemsets ~= nil and type(self.SetSyncVersion) == "function" then
        self:SetSyncVersion("itemsets", self._pendingSyncVersions.itemsets)
        self._pendingSyncVersions.itemsets = nil
    end

    if DC.Print then
        local totalCached = 0
        for _ in pairs(DC.definitions.itemsets or {}) do
            totalCached = totalCached + 1
        end
        DC:Print("[PROTOCOL] Cached " .. totalCached .. " item sets.")
    end

    -- Trigger UI update if Wardrobe is loaded
    if DC.Wardrobe and DC.Wardrobe.RefreshSetsGrid then
        DC.Wardrobe:RefreshSetsGrid()
    end
end


-- ============================================================================
-- COMMUNITY OUTFITS HANDLERS
-- ============================================================================

function DC:HandleCommunityList(data)
    local outfits = data.outfits or {}
    
    if DC.Print then
        if DC.Debug then DC:Debug("HandleCommunityList received " .. (outfits and #outfits or "nil") .. " outfits") end
    end
    
    -- Store in DC.db for Wardrobe Community tab
    if not self.db then self.db = {} end
    self.db.communityOutfits = outfits
    
    -- Notify CommunityUI (standalone)
    if self.CommunityUI and self.CommunityUI.OnListReceived then
        self.CommunityUI:OnListReceived(outfits)
    end
    
    -- Notify Wardrobe Community grid
    if self.Wardrobe and self.Wardrobe.RefreshCommunityGrid then
        self.Wardrobe:RefreshCommunityGrid()
    end

    -- Allow transmog paging to continue after we get a response.
    self._pauseTransmogPagingUntil = nil
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
    if isAdd == nil then
        isAdd = data.is_favorite
    end
    
    if self.CommunityUI and self.CommunityUI.OnFavoriteResult then
        self.CommunityUI:OnFavoriteResult(outfitId, isAdd)
    end
end

function DC:HandleCommunityUpdateResult(data)
    local success = data.success
    local errMsg = data.error
    local outfitId = data.id
    
    if success then
        self:Print("Community outfit updated successfully!")
        -- Refresh community list
        if self.RequestCommunityList then
            self:RequestCommunityList(0, 50, "all", "newest")
        end
    else
        self:Print("|cffff0000Failed to update outfit: " .. (errMsg or "Unknown error") .. "|r")
    end
    
    -- Notify UI
    if self.CommunityUI and self.CommunityUI.OnUpdateResult then
        self.CommunityUI:OnUpdateResult(success, outfitId, errMsg)
    end
end

function DC:HandleCommunityDeleteResult(data)
    local success = data.success
    local errMsg = data.error
    local outfitId = data.id
    
    if success then
        self:Print("Community outfit deleted.")
        -- Refresh community list
        if self.RequestCommunityList then
            self:RequestCommunityList(0, 50, "all", "newest")
        end
    else
        self:Print("|cffff0000Failed to delete outfit: " .. (errMsg or "Unknown error") .. "|r")
    end
    
    -- Notify UI
    if self.CommunityUI and self.CommunityUI.OnDeleteResult then
        self.CommunityUI:OnDeleteResult(success, outfitId, errMsg)
    end
end


