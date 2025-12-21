--[[
    DC-Collection Cache.lua
    =======================
    
    Local caching of collection data in SavedVariables.
    Implements additive-only delta sync for optimal performance.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection

-- ============================================================================
-- CACHE STRUCTURE
-- ============================================================================

--[[
    SavedVariables structure:
    
    DCCollectionDB = {
        -- Settings (handled in Core.lua)
        
        -- Cache metadata
        cacheVersion = 1,
        lastSyncTime = timestamp,
        syncVersion = server_version,
        
        -- Cached definitions (rarely change)
        definitionCache = {
            mounts = { [spellId] = { name, icon, rarity, source, ... }, ... },
            pets = { ... },
            ...
        },
        
        -- Cached collections (additive only)
        collectionCache = {
            mounts = { [spellId] = { obtained_date, is_favorite, times_used }, ... },
            pets = { ... },
            ...
        },
        
        -- Cached currency
        currencyCache = { tokens = 0, emblems = 0 },
        
        -- Cached stats
        statsCache = { mounts = { owned = 0, total = 0 }, ... },
    }
]]

local CACHE_VERSION = 1

-- ============================================================================
-- LOAD CACHE
-- ============================================================================

function DC:LoadCache()
    DCCollectionDB = DCCollectionDB or {}
    
    -- Check cache version
    if DCCollectionDB.cacheVersion ~= CACHE_VERSION then
        self:Debug("Cache version mismatch, clearing cache")
        self:ClearCache()
        DCCollectionDB.cacheVersion = CACHE_VERSION
        return
    end
    
    -- Load definitions
    if DCCollectionDB.definitionCache then
        for collType, defs in pairs(DCCollectionDB.definitionCache) do
            self.definitions[collType] = defs
        end
        self:Debug("Loaded " .. self:CountDefinitions() .. " cached definitions")
    end
    
    -- Load collections
    if DCCollectionDB.collectionCache then
        for collType, items in pairs(DCCollectionDB.collectionCache) do
            self.collections[collType] = items
        end
        self:Debug("Loaded cached collections")
    end
    
    -- Load currency
    if DCCollectionDB.currencyCache then
        self.currency.tokens = DCCollectionDB.currencyCache.tokens or 0
        self.currency.emblems = DCCollectionDB.currencyCache.emblems or 0
    end
    
    -- Load stats
    if DCCollectionDB.statsCache then
        for collType, stats in pairs(DCCollectionDB.statsCache) do
            if self.stats[collType] then
                self.stats[collType].owned = stats.owned or 0
                self.stats[collType].total = stats.total or 0
            end
        end
    end
    
    -- Load mount speed bonus
    self.mountSpeedBonus = DCCollectionDB.mountSpeedBonus or 0
    
    -- Load wishlist
    if DCCollectionDB.wishlistCache then
        self.wishlist = DCCollectionDB.wishlistCache
    end
    
    self:Debug("Cache loaded successfully")
end

-- ============================================================================
-- SAVE CACHE
-- ============================================================================

function DC:SaveCache()
    DCCollectionDB = DCCollectionDB or {}
    DCCollectionDB.cacheVersion = CACHE_VERSION
    DCCollectionDB.lastSyncTime = time()
    
    -- Save definitions
    DCCollectionDB.definitionCache = {}
    for collType, defs in pairs(self.definitions) do
        DCCollectionDB.definitionCache[collType] = defs
    end
    
    -- Save collections
    DCCollectionDB.collectionCache = {}
    for collType, items in pairs(self.collections) do
        DCCollectionDB.collectionCache[collType] = items
    end
    
    -- Save currency
    DCCollectionDB.currencyCache = {
        tokens = self.currency.tokens,
        emblems = self.currency.emblems,
    }
    
    -- Save stats
    DCCollectionDB.statsCache = {}
    for collType, stats in pairs(self.stats) do
        DCCollectionDB.statsCache[collType] = {
            owned = stats.owned,
            total = stats.total,
        }
    end
    
    -- Save mount speed bonus
    DCCollectionDB.mountSpeedBonus = self.mountSpeedBonus
    
    -- Save wishlist
    DCCollectionDB.wishlistCache = self.wishlist
    
    self:Debug("Cache saved")
end

-- ============================================================================
-- CLEAR CACHE
-- ============================================================================

function DC:ClearCache()
    DCCollectionDB.definitionCache = nil
    DCCollectionDB.collectionCache = nil
    DCCollectionDB.currencyCache = nil
    DCCollectionDB.statsCache = nil
    DCCollectionDB.wishlistCache = nil
    DCCollectionDB.mountSpeedBonus = nil
    DCCollectionDB.lastSyncTime = 0
    DCCollectionDB.syncVersion = 0
    
    -- Clear in-memory data
    for collType in pairs(self.collections) do
        self.collections[collType] = {}
    end
    for collType in pairs(self.definitions) do
        self.definitions[collType] = {}
    end
    self.currency = { tokens = 0, emblems = 0 }
    self.wishlist = {}
    self.mountSpeedBonus = 0
    
    self:Print("Cache cleared")
end

-- ============================================================================
-- CACHE UPDATE FUNCTIONS
-- ============================================================================

-- Add a single item to collection cache
function DC:CacheAddItem(collectionType, itemId, itemData)
    self.collections[collectionType] = self.collections[collectionType] or {}
    self.collections[collectionType][itemId] = itemData
    
    -- Update stats
    if self.stats[collectionType] then
        self.stats[collectionType].owned = self:CountCollection(collectionType)
    end
    
    -- Mark for save
    self.cacheNeedsSave = true
end

-- Update item in collection (e.g., favorite status)
function DC:CacheUpdateItem(collectionType, itemId, updates)
    if self.collections[collectionType] and self.collections[collectionType][itemId] then
        for key, value in pairs(updates) do
            self.collections[collectionType][itemId][key] = value
        end
        self.cacheNeedsSave = true
    end
end

-- Add definition to cache
function DC:CacheAddDefinition(collectionType, itemId, defData)
    self.definitions[collectionType] = self.definitions[collectionType] or {}
    self.definitions[collectionType][itemId] = defData
    
    -- Update total stats
    if self.stats[collectionType] then
        self.stats[collectionType].total = self:CountDefinitions(collectionType)
    end
end

-- Batch update definitions
function DC:CacheMergeDefinitions(collectionType, definitions)
    self.definitions[collectionType] = self.definitions[collectionType] or {}
    
    local added = 0
    for itemId, defData in pairs(definitions) do
        if not self.definitions[collectionType][itemId] then
            added = added + 1
        end
        self.definitions[collectionType][itemId] = defData
    end
    
    if self.stats[collectionType] then
        self.stats[collectionType].total = self:CountDefinitions(collectionType)
    end
    
    self:Debug(string.format("Merged %d definitions for %s", added, collectionType))
end

-- Batch update collection
function DC:CacheMergeCollection(collectionType, items)
    self.collections[collectionType] = self.collections[collectionType] or {}
    
    local added = 0
    for itemId, itemData in pairs(items) do
        if not self.collections[collectionType][itemId] then
            added = added + 1
        end
        self.collections[collectionType][itemId] = itemData
    end
    
    if self.stats[collectionType] then
        self.stats[collectionType].owned = self:CountCollection(collectionType)
    end
    
    self:Debug(string.format("Merged %d items for %s collection", added, collectionType))
    self.cacheNeedsSave = true
end

-- Update currency cache
function DC:CacheUpdateCurrency(tokens, emblems)
    self.currency.tokens = tokens or self.currency.tokens
    self.currency.emblems = emblems or self.currency.emblems
    self.cacheNeedsSave = true
end

-- ============================================================================
-- DELTA SYNC
-- ============================================================================

-- Get last sync version for a collection type
function DC:GetSyncVersion(collectionType)
    DCCollectionDB.syncVersions = DCCollectionDB.syncVersions or {}
    return DCCollectionDB.syncVersions[collectionType] or 0
end

-- Set sync version after successful sync
function DC:SetSyncVersion(collectionType, version)
    DCCollectionDB.syncVersions = DCCollectionDB.syncVersions or {}
    DCCollectionDB.syncVersions[collectionType] = version
end

-- Get IDs of items we already have (for delta request)
function DC:GetCollectedIds(collectionType)
    local ids = {}
    if self.collections[collectionType] then
        for id in pairs(self.collections[collectionType]) do
            table.insert(ids, id)
        end
    end
    return ids
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function DC:CountCollection(collectionType)
    local count = 0
    if self.collections[collectionType] then
        for _ in pairs(self.collections[collectionType]) do
            count = count + 1
        end
    end
    return count
end

function DC:CountDefinitions(collectionType)
    if collectionType then
        local count = 0
        if self.definitions[collectionType] then
            for _ in pairs(self.definitions[collectionType]) do
                count = count + 1
            end
        end
        return count
    else
        -- Count all definitions
        local total = 0
        for _, defs in pairs(self.definitions) do
            for _ in pairs(defs) do
                total = total + 1
            end
        end
        return total
    end
end

-- Get definition for an item
function DC:GetDefinition(collectionType, itemId)
    if self.definitions[collectionType] then
        return self.definitions[collectionType][itemId]
    end
    return nil
end

-- Get collection item data
function DC:GetCollectionItem(collectionType, itemId)
    if self.collections[collectionType] then
        return self.collections[collectionType][itemId]
    end
    return nil
end

-- ============================================================================
-- TYPE CONVERSION HELPERS
-- ============================================================================

-- Lookup table for type name to ID conversion
local TYPE_NAME_TO_ID = {
    ["mounts"] = DC.CollectionType.MOUNT,
    ["mount"] = DC.CollectionType.MOUNT,
    ["pets"] = DC.CollectionType.PET,
    ["pet"] = DC.CollectionType.PET,
    ["toys"] = DC.CollectionType.TOY,
    ["toy"] = DC.CollectionType.TOY,
    ["heirlooms"] = DC.CollectionType.HEIRLOOM,
    ["heirloom"] = DC.CollectionType.HEIRLOOM,
    ["titles"] = DC.CollectionType.TITLE,
    ["title"] = DC.CollectionType.TITLE,
    ["transmog"] = DC.CollectionType.TRANSMOG,
    ["appearances"] = DC.CollectionType.TRANSMOG,
}

-- Reverse lookup for ID to name
local TYPE_ID_TO_NAME = {
    [DC.CollectionType.MOUNT] = "mounts",
    [DC.CollectionType.PET] = "pets",
    [DC.CollectionType.TOY] = "toys",
    [DC.CollectionType.HEIRLOOM] = "heirlooms",
    [DC.CollectionType.TITLE] = "titles",
    [DC.CollectionType.TRANSMOG] = "transmog",
}

-- Convert type name string to type ID
function DC:GetTypeIdFromName(typeName)
    if not typeName then return nil end
    return TYPE_NAME_TO_ID[string.lower(typeName)]
end

-- Convert type ID to type name string
function DC:GetTypeNameFromId(typeId)
    if not typeId then return nil end
    return TYPE_ID_TO_NAME[typeId]
end

-- ============================================================================
-- COLLECTION MANIPULATION
-- ============================================================================

-- Set entire collection for a type (replaces existing)
function DC:SetCollection(collectionType, items)
    self.collections[collectionType] = {}
    
    if items then
        for itemId, itemData in pairs(items) do
            -- Handle both array format and key-value format
            if type(itemData) == "table" then
                self.collections[collectionType][itemId] = itemData
            else
                -- Simple list of IDs
                self.collections[collectionType][itemData] = { owned = true }
            end
        end
    end
    
    -- Update stats
    if self.stats[collectionType] then
        self.stats[collectionType].owned = self:CountCollection(collectionType)
    end
    
    self.cacheNeedsSave = true
    self:Debug(string.format("Set collection type %d with %d items", 
        collectionType, self:CountCollection(collectionType)))
end

-- Add single item to collection
function DC:AddToCollection(collectionType, itemId, itemData)
    self.collections[collectionType] = self.collections[collectionType] or {}
    
    if not self.collections[collectionType][itemId] then
        self.collections[collectionType][itemId] = itemData or { owned = true }
        
        -- Update stats
        if self.stats[collectionType] then
            self.stats[collectionType].owned = self:CountCollection(collectionType)
        end
        
        self.cacheNeedsSave = true
        return true  -- Item was added
    end
    
    return false  -- Item already existed
end

-- Remove single item from collection
function DC:RemoveFromCollection(collectionType, itemId)
    if self.collections[collectionType] and self.collections[collectionType][itemId] then
        self.collections[collectionType][itemId] = nil
        
        -- Update stats
        if self.stats[collectionType] then
            self.stats[collectionType].owned = self:CountCollection(collectionType)
        end
        
        self.cacheNeedsSave = true
        return true  -- Item was removed
    end
    
    return false  -- Item didn't exist
end

-- ============================================================================
-- HASH COMPUTATION
-- Matches server-side GenerateCollectionHash in dc_addon_collection.cpp
-- ============================================================================

-- Compute hash of all collected item IDs for delta sync
function DC:ComputeCollectionHash()
    local hash = 0
    
    -- Iterate all collection types and their items
    for collectionType, items in pairs(self.collections) do
        for itemId in pairs(items) do
            -- Use same algorithm as server: Knuth's multiplicative hash
            -- hash = hash XOR (id * 2654435761 % 2^32)
            local idHash = bit.band(itemId * 2654435761, 0xFFFFFFFF)
            hash = bit.bxor(hash, idHash)
        end
    end
    
    return hash
end

-- ============================================================================
-- AUTO-SAVE TIMER
-- ============================================================================

local saveTimer = nil
local SAVE_INTERVAL = 60  -- Save every 60 seconds if needed

local function CheckAutoSave()
    if DC.cacheNeedsSave then
        DC:SaveCache()
        DC.cacheNeedsSave = false
    end
end

-- Start auto-save timer
local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= SAVE_INTERVAL then
        self.elapsed = 0
        CheckAutoSave()
    end
end)
