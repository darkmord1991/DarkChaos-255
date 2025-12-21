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
    CMSG_SET_TRANSMOG        = 0x33,
    
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
    SMSG_TRANSMOG_STATE      = 0x48,
    
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
    
    -- Register our module
    local success = DCAddonProtocol:RegisterModule(self.MODULE_ID, self.OnProtocolMessage)
    if success then
        self:Debug("Protocol module registered: " .. self.MODULE_ID)
        self.isConnected = true
    else
        self:Print("|cffff0000Error:|r Failed to register protocol module")
        return false
    end
    
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
    
    -- Build message payload
    local payload = {
        op = opcode,
        data = data or {},
        time = time(),
    }
    
    -- Send via DCAddonProtocol
    local success = DCAddonProtocol:SendMessage(self.MODULE_ID, payload)
    if success then
        self:Debug(string.format("Sent message opcode 0x%02X", opcode))
        
        -- Track pending request
        self.pendingRequests[opcode] = {
            sentAt = GetTime(),
            data = data,
        }
    else
        self:Debug("Failed to send message")
    end
    
    return success
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
        self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "toys" })
        self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "heirlooms" })
        self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "titles" })
        return self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "transmog" })
    end

    return self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = collType })
end

-- Request type collection items (e.g. "mounts", "pets", "transmog")
-- If collType is nil, requests all supported types.
function DC:RequestCollection(collType)
    if not collType then
        self:SendMessage(self.Opcodes.CMSG_GET_COLLECTION, { type = "mounts" })
        self:SendMessage(self.Opcodes.CMSG_GET_COLLECTION, { type = "pets" })
        self:SendMessage(self.Opcodes.CMSG_GET_COLLECTION, { type = "toys" })
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
    
    if data.needsSync then
        self:Debug("Server indicates full sync needed")
        self:RequestFullCollection()
    else
        self:Debug("Collection is in sync with server")
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
function DC:HandleStats(data)
    self:Debug("Received stats")
    
    if data.stats then
        self.stats = data.stats
    end
    
    -- Fire callback
    if self.callbacks.onStatsReceived then
        self.callbacks.onStatsReceived(data.stats)
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
            rarity = 2,
            source = "Shop",
        }

        -- Resolve name/icon from definitions (or item cache for transmog)
        if typeName and self.definitions[typeName] then
            local defKey = it.entryId
            if typeName == "transmog" and it.appearanceId then
                defKey = it.appearanceId
            end

            local def = self.definitions[typeName][defKey]
            if def then
                card.name = def.name
                card.icon = def.icon
                card.definition = def
            end
        end

        if (not card.icon or card.icon == "") and typeName == "transmog" and it.itemId and GetItemInfo then
            local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(it.itemId)
            if texture then
                card.icon = texture
            end
            if quality then
                card.rarity = quality
            end
        end

        if not card.name or card.name == "" then
            if typeName == "transmog" and it.itemId and GetItemInfo then
                local name, _, quality = GetItemInfo(it.itemId)
                if name then
                    card.name = name
                end
                if quality then
                    card.rarity = quality
                end
            end
        end

        card.icon = card.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        card.name = card.name or "Shop Item"

        table.insert(mapped, card)
    end

    self.shopItems = mapped
    
    -- Fire callback
    if self.callbacks.onShopDataReceived then
        self.callbacks.onShopDataReceived(data)
    end

    -- Refresh MainFrame if open
    if self.MainFrame and self.MainFrame:IsShown() then
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

    self.currency.tokens = data.tokens or 0
    self.currency.emblems = data.emblems or 0
    
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

function DC:HandleToyUsed(data)
    if data.success then
        -- Toy used successfully, update cooldown
        local itemId = data.itemId
        if self.collections.toys and self.collections.toys[itemId] then
            self.collections.toys[itemId].lastUsed = time()
        end
    else
        self:Print("|cffff0000" .. (data.error or DC.L["ERR_ON_COOLDOWN"]) .. "|r")
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
    
    -- Notify UI
    if self.MainFrame and self.MainFrame:IsShown() then
        self.MainFrame:UpdateStatsDisplay()
    end
end

function DC:HandleAchievements(data)
    self.achievements = data.achievements or {}
    
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
    for _, collType in ipairs({"mounts", "pets", "toys", "heirlooms", "transmog", "titles"}) do
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
    for _, collType in ipairs({"mounts", "pets", "toys", "heirlooms", "transmog", "titles"}) do
        local lastVersion = self:GetSyncVersion(collType)
        if lastVersion > 0 then
            self:RequestDefinitions(collType, lastVersion)
        else
            self:RequestDefinitions(collType)
        end
    end
    
    -- Always request collection (server handles delta)
    for _, collType in ipairs({"mounts", "pets", "toys", "heirlooms", "transmog", "titles"}) do
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
function DC:ShowToast(collType, itemName, icon)
    -- Simple chat notification for now
    -- Can be enhanced with a custom frame later
    local typeStr = DC.L["TAB_" .. string.upper(collType)] or collType
    self:Print(string.format("|cff00ff00New %s:|r %s", typeStr, itemName))
end

-- Check achievements after collection update
function DC:CheckAchievements(collType)
    -- Request achievement update from server
    self:RequestAchievements()
end
