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
    return false
end

-- ============================================================================
-- REQUEST FUNCTIONS
-- Updated to match C++ opcodes in DCAddonNamespace.h
-- ============================================================================

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
    return self:SendMessage(self.Opcodes.CMSG_GET_STATS, {})
end

-- Request active bonuses (mount speed, etc.)
function DC:RequestBonuses()
    return self:SendMessage(self.Opcodes.CMSG_GET_BONUSES, {})
end

-- Request type definitions (e.g. "mounts", "pets", "transmog")
-- If collType is nil, requests all supported types (Core.lua compatibility).
function DC:RequestDefinitions(collType)
    if not collType then
        self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "mounts" })
        self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "pets" })
        self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "heirlooms" })
        self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "titles" })
        -- Transmog definitions can be huge; fetch on-demand (and paged) when the Transmog tab is opened.
        return
    end

    if collType == "transmog" then
        self._transmogDefOffset = 0
        self._transmogDefLimit = self._transmogDefLimit or 200
        self._transmogDefLoading = true
        return self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "transmog", offset = 0, limit = self._transmogDefLimit })
    end

    return self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = collType })
end

-- Request type collection items (e.g. "mounts", "pets", "transmog")
-- If collType is nil, requests all supported types.
function DC:RequestCollection(collType)
    if not collType then
        self:SendMessage(self.Opcodes.CMSG_GET_COLLECTION, { type = "mounts" })
        self:SendMessage(self.Opcodes.CMSG_GET_COLLECTION, { type = "pets" })
        self:SendMessage(self.Opcodes.CMSG_GET_COLLECTION, { type = "heirlooms" })
        self:SendMessage(self.Opcodes.CMSG_GET_COLLECTION, { type = "titles" })
        return self:SendMessage(self.Opcodes.CMSG_GET_COLLECTION, { type = "transmog" })
    end

    return self:SendMessage(self.Opcodes.CMSG_GET_COLLECTION, { type = collType })
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
    return self:SendMessage(self.Opcodes.CMSG_GET_SHOP, {
        category = category or "all",
    })
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
function DC:RequestUseItem(collectionType, entryId)
    local typeId = type(collectionType) == "number" and collectionType or self:GetTypeIdFromName(collectionType)
    return self:SendMessage(self.Opcodes.CMSG_USE_ITEM, {
        type = typeId or 0,
        entryId = entryId,
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
    else
        self:Debug(string.format("Unknown opcode: 0x%02X", opcode))
    end
end

-- ============================================================================
-- RESPONSE HANDLERS
-- Updated to match new protocol
-- ============================================================================

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
        self:RefreshCurrentTab()
    end
end

-- Handle bonuses response
function DC:HandleBonuses(data)
    self:Debug("Received bonuses")
    
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

    self.shopCategory = data.category
    self.currency.tokens = data.tokens or 0
    self.currency.emblems = data.emblems or 0

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

        -- Server sends icon as displayInfoId or spellIconId string - resolve to actual texture
        local serverIcon = it.icon
        
        -- Resolve icon from server data or game API
        if typeName == "mounts" then
            -- Server sends spell icon ID; use GetSpellTexture for mounts
            if it.entryId and GetSpellTexture then
                local tex = GetSpellTexture(it.entryId)
                if tex then card.icon = tex end
            end
            -- Fallback to GetSpellInfo for name
            if (not card.name or card.name == "") and it.entryId and GetSpellInfo then
                local name = GetSpellInfo(it.entryId)
                if name then card.name = name end
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
        elseif typeName == "titles" then
            -- Titles use static icon
            card.icon = "Interface\\Icons\\INV_Scroll_11"
        end

        -- Final fallbacks
        card.icon = card.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        card.name = card.name or "Shop Item"

        table.insert(mapped, card)
    end

    self.shopItems = mapped
    
    -- Some items may need cache warming - schedule a refresh
    if self.shopNeedsCacheWarm == nil then
        self.shopNeedsCacheWarm = true
        -- Use C_Timer or simple delayed call
        if self.After and type(self.After) == "function" then
            self:After(0.5, function()
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
        self:RefreshCurrentTab()
    end
end

-- Refresh shop icons after cache warming
function DC:RefreshShopIcons()
    if not self.shopItems then return end
    
    local needsRefresh = false
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
    end
    
    if needsRefresh and self.MainFrame and self.MainFrame:IsShown() and self.activeTab == "shop" then
        self:RefreshCurrentTab()
    end
end

-- Handle purchase result
function DC:HandlePurchaseResult(data)
    self:Debug(string.format("Purchase result: success=%s", tostring(data.success)))
    
    if data.success then
        self:Print("|cff00ff00Purchase successful!|r")
        
        -- Update currency
        self.currency = self.currency or { tokens = 0, emblems = 0 }
        self.currency.tokens = data.tokens or self.currency.tokens or 0
        self.currency.emblems = data.emblems or self.currency.emblems or 0
        
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

    self.currency = self.currency or { tokens = 0, emblems = 0 }
    if type(self.CacheUpdateCurrency) == "function" then
        self:CacheUpdateCurrency(data.tokens or 0, data.emblems or 0)
    else
        self.currency.tokens = data.tokens or 0
        self.currency.emblems = data.emblems or 0
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
    
    if data.success then
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
    
    self._transmogSlotItems = self._transmogSlotItems or {}
    self._transmogSlotItems[visualSlot] = {
        page = page,
        hasMore = hasMore,
        items = items,
    }
    
    self:Debug(string.format("Received %d transmog items for slot %d (page %d)", #items, visualSlot or 0, page))
    
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
    local appearances = data.appearances or {}
    self.collectedAppearances = {}
    
    for _, displayId in ipairs(appearances) do
        self.collectedAppearances[displayId] = true
    end
    
    self:Debug(string.format("Received %d collected appearances", #appearances))
    
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
    local collType = data.type
    local definitions = data.definitions or {}
    local syncVersion = data.syncVersion
    
    self:CacheMergeDefinitions(collType, definitions)
    self:SetSyncVersion(collType, syncVersion)
    self:SaveCache()
    
    -- Notify UI if open
    if self.MainFrame and self.MainFrame:IsShown() then
        self:RefreshCurrentTab()
    end
    
    self:Debug(string.format("Received %d definitions for %s", 
        self:TableCount(definitions), collType))

    -- Transmog definitions can be very large; server may send them in pages.
    if collType == "transmog" and data.more then
        local nextOffset = (data.offset or 0) + (data.limit or 0)
        local limit = data.limit or (self._transmogDefLimit or 200)

        self._transmogDefOffset = nextOffset
        self._transmogDefLimit = limit

        if type(self.After) == "function" then
            self:After(0.05, function()
                self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "transmog", offset = nextOffset, limit = limit })
            end)
        else
            self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "transmog", offset = nextOffset, limit = limit })
        end
    elseif collType == "transmog" then
        self._transmogDefLoading = nil
    end
end

function DC:HandleCollection(data)
    local collType = data.type
    local items = data.items or {}
    
    self:CacheMergeCollection(collType, items)
    self:SaveCache()
    
    -- Notify UI if open
    if self.MainFrame and self.MainFrame:IsShown() then
        self:RefreshCurrentTab()
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
    local collType = data.type
    local itemId = data.itemId
    local isFavorite = data.isFavorite
    
    self:CacheUpdateItem(collType, itemId, { is_favorite = isFavorite })
    
    -- Refresh UI if showing
    if self.MainFrame and self.MainFrame:IsShown() then
        self:RefreshCurrentTab()
    end
end

function DC:HandleCurrency(data)
    self:CacheUpdateCurrency(data.tokens, data.emblems)
    
    -- Update UI
    if self.ShopUI and self.ShopUI:IsShown() then
        self.ShopUI:UpdateCurrencyDisplay()
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
        self.ShopUI:Refresh()
    end
    
    self:Debug(string.format("Received %d shop items", #self.shopItems))
end

function DC:HandleShopResult(data)
    if data.success then
        -- Update currency
        self:CacheUpdateCurrency(data.newTokens, data.newEmblems)
        
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
        self:RefreshCurrentTab()
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
