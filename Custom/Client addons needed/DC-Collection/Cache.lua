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
-- REVISION TRACKING (UI performance)
-- ============================================================================
-- A cheap way for UI code to know whether definitions/collections changed
-- without doing deep table comparisons.

local function EnsureRevisions(self)
    if not self._revisions then
        self._revisions = { definitions = {}, collections = {} }
    end
end

function DC:_BumpDefinitionsRevision(typeName)
    EnsureRevisions(self)
    self._revisions.definitions[typeName] = (self._revisions.definitions[typeName] or 0) + 1
end

function DC:_BumpCollectionsRevision(typeName)
    EnsureRevisions(self)
    self._revisions.collections[typeName] = (self._revisions.collections[typeName] or 0) + 1
end

function DC:GetDefinitionsRevision(typeName)
    EnsureRevisions(self)
    return self._revisions.definitions[typeName] or 0
end

function DC:GetCollectionsRevision(typeName)
    EnsureRevisions(self)
    return self._revisions.collections[typeName] or 0
end

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

-- Cache freshness: consider data "fresh" if loaded within this many seconds.
-- This allows skipping redundant server requests on /reload or quick relog.
local CACHE_FRESH_SECONDS = 300  -- 5 minutes

-- Check if cached data is fresh enough to skip a full server sync.
-- Returns true if cache was saved within CACHE_FRESH_SECONDS ago.
function DC:IsCacheFresh()
    DCCollectionDB = DCCollectionDB or {}
    local lastSave = DCCollectionDB.lastSyncTime or 0
    if lastSave <= 0 then
        return false
    end
    local age = time() - lastSave
    return age < CACHE_FRESH_SECONDS
end

-- Check if we have any cached definitions (meaning cache isn't empty).
-- Returns false if critical definitions are missing/empty (transmog, mounts, companions).
function DC:HasCachedDefinitions()
    if not self.definitions then
        return false
    end

    -- Transmog definitions are critical for wardrobe/outfits - if they're empty, force a refresh.
    local transmogDefs = self.definitions.transmog
    if type(transmogDefs) ~= "table" or not next(transmogDefs) then
        -- No transmog definitions - don't consider cache "valid" for heavy requests.
        return false
    end

    -- Mounts and companions are also critical - check them too.
    local mountDefs = self.definitions.mounts or self.definitions.mount
    local companionDefs = self.definitions.companions or self.definitions.companion or self.definitions.pets or self.definitions.pet
    
    if type(mountDefs) ~= "table" or not next(mountDefs) then
        self:Debug("HasCachedDefinitions: mounts definitions missing")
        return false
    end
    
    if type(companionDefs) ~= "table" or not next(companionDefs) then
        self:Debug("HasCachedDefinitions: companions definitions missing")
        return false
    end

    return true
end

-- ============================================================================
-- DATA PACKING (Optimized Storage)
-- ============================================================================
-- Pack transmog definition into a compact string to save disk space and write time.
-- Format: name^icon^quality^displayId^inventoryType^class^subclass^visualSlot^itemId^spellId

local DELIMITER = "^"

-- Keep the in-memory transmog definitions packed as delimiter-separated strings
-- to avoid huge per-entry Lua table overhead.
local DEFAULT_TRANSMOG_UNPACK_CACHE_MAX = 512

local function PackTransmogDefinition(def)
    if type(def) ~= "table" then return def end
    
    return table.concat({
        def.name or "",
        def.icon or "",
        def.quality or def.rarity or "1",
        def.displayId or "",
        def.inventoryType or "",
        def.class or "",
        def.subclass or "",
        def.visualSlot or "",
        def.itemId or "",
        def.spellId or "",

        -- Optional fields used by some UIs. Store as strings to keep packing simple.
        def.itemIdsTotal or def.item_ids_total or def.itemIds_count or def.itemIdsCount or "",
        (type(def.itemIds) == "table" and table.concat(def.itemIds, ",")) or def.itemIds or def.item_ids or "",
        def.source or ""
    }, DELIMITER)
end

-- Unpack string back into a table
local function UnpackTransmogDefinition(str)
    if type(str) ~= "string" then return str end
    
    -- Fast split
    local parts = { strsplit(DELIMITER, str) }
    
    local itemIds = nil
    if parts[12] and parts[12] ~= "" then
        itemIds = { strsplit(",", parts[12]) }
        for i = 1, #itemIds do
            itemIds[i] = tonumber(itemIds[i]) or itemIds[i]
        end
    end

    return {
        name = (parts[1] ~= "" and parts[1]) or nil,
        icon = (parts[2] ~= "" and parts[2]) or nil,
        quality = tonumber(parts[3]) or 1,
        rarity = tonumber(parts[3]) or 1, -- alias
        displayId = tonumber(parts[4]),
        inventoryType = tonumber(parts[5]),
        class = (parts[6] ~= "" and parts[6]) or nil,
        subclass = (parts[7] ~= "" and parts[7]) or nil,
        visualSlot = tonumber(parts[8]),
        itemId = tonumber(parts[9]),
        spellId = tonumber(parts[10]),

        itemIdsTotal = (parts[11] ~= "" and tonumber(parts[11])) or nil,
        itemIds = itemIds,
        source = (parts[13] ~= "" and parts[13]) or nil,
    }
end

-- Parse only the commonly-used fields from a packed transmog definition string.
-- Returns: name, icon, quality, displayId, inventoryType, class, subclass, visualSlot, itemId, spellId, itemIdsTotal, itemIdsStr, source
function DC:ParsePackedTransmogDefinition(str)
    if type(str) ~= "string" then
        return nil
    end
    return strsplit(DELIMITER, str)
end

local function GetTransmogUnpackCacheMax()
    if DCCollectionDB and DCCollectionDB.transmogUnpackCacheMax ~= nil then
        local v = tonumber(DCCollectionDB.transmogUnpackCacheMax)
        if v and v >= 32 then
            return math.floor(v)
        end
    end
    return DEFAULT_TRANSMOG_UNPACK_CACHE_MAX
end

function DC:_GetUnpackedTransmogDefinition(id, packed)
    if not id or type(packed) ~= "string" then
        return nil
    end

    self._transmogDefUnpackCache = self._transmogDefUnpackCache or {}
    local cached = self._transmogDefUnpackCache[id]
    if cached then
        return cached
    end

    local def = UnpackTransmogDefinition(packed)
    if type(def) ~= "table" then
        return def
    end

    local maxSize = GetTransmogUnpackCacheMax()
    self._transmogDefUnpackRing = self._transmogDefUnpackRing or {}
    self._transmogDefUnpackRingPos = (self._transmogDefUnpackRingPos or 0) + 1
    if self._transmogDefUnpackRingPos > maxSize then
        self._transmogDefUnpackRingPos = 1
    end

    local pos = self._transmogDefUnpackRingPos
    local oldId = self._transmogDefUnpackRing[pos]
    if oldId ~= nil then
        self._transmogDefUnpackCache[oldId] = nil
    end

    self._transmogDefUnpackRing[pos] = id
    self._transmogDefUnpackCache[id] = def
    return def
end

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
            -- Keep transmog packed in memory to reduce RAM.
            if collType == "transmog" then
                local packedDefs = {}
                for id, data in pairs(defs) do
                    if type(data) == "table" then
                        packedDefs[id] = PackTransmogDefinition(data)
                    else
                        packedDefs[id] = data
                    end
                end
                self.definitions[collType] = packedDefs
            else
                self.definitions[collType] = defs
            end
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

    -- Load per-character transmog state
    if DCCollectionCharDB and DCCollectionCharDB.transmogState then
        self.transmogState = DCCollectionCharDB.transmogState
    end

    -- Load per-character transmog itemIds (fake entries used for icon + TryOn)
    if DCCollectionCharDB and DCCollectionCharDB.transmogItemIds then
        self.transmogItemIds = DCCollectionCharDB.transmogItemIds
    end

    -- Load outfits (scope selectable)
    local scope = (DCCollectionDB and DCCollectionDB.outfitsScope) or "char"
    if scope == "account" then
        if DCCollectionDB and DCCollectionDB.outfits then
            self.outfits = DCCollectionDB.outfits
        end
    else
        if DCCollectionCharDB and DCCollectionCharDB.outfits then
            self.outfits = DCCollectionCharDB.outfits
        end
    end

    -- If we loaded actual definitions, mark data as ready so the UI can show immediately.
    if self:HasCachedDefinitions() then
        self.isDataReady = true
        self:Debug("Cache has definitions; isDataReady = true")
    end
    
    self:Debug("Cache loaded successfully")
end

-- ============================================================================
-- SAVE CACHE
-- ============================================================================

function DC:SaveCache()
    -- Skip saving if nothing has changed (dirty tracking)
    -- Note: On logout we always save to be safe, caller sets cacheNeedsSave = true
    if not self.cacheNeedsSave then
        self:Debug("Cache unchanged, skipping save")
        return
    end

    DCCollectionDB = DCCollectionDB or {}
    DCCollectionDB.cacheVersion = CACHE_VERSION
    DCCollectionDB.lastSyncTime = time()
    
    -- Save definitions - use direct reference instead of copying
    -- (tables are passed by reference in Lua, so this is efficient)
    
    -- OPTIMIZATION: Pack large datasets (transmog) into strings BEFORE saving.
    -- This drastically reduces file size and write time (solving slow logout)
    -- while keeping the data persistent (solving re-download needs).
    local defsToSave = {}
    if self.definitions then
        for k, v in pairs(self.definitions) do
            if k == "transmog" then -- Only pack transmog for now
                local packedTransmog = {}
                for id, def in pairs(v) do
                    packedTransmog[id] = PackTransmogDefinition(def)
                end
                defsToSave[k] = packedTransmog
            else
                 -- Save other definitions (mounts, pets, itemSets) as normal tables.
                 -- They are not large enough to cause logout freezes.
                 defsToSave[k] = v
            end
        end
    end
    DCCollectionDB.definitionCache = defsToSave
    
    -- Save collections - direct reference
    DCCollectionDB.collectionCache = self.collections
    
    -- Save currency
    DCCollectionDB.currencyCache = {
        tokens = self.currency.tokens,
        emblems = self.currency.emblems,
    }
    
    -- Save stats - direct reference
    DCCollectionDB.statsCache = self.stats
    
    -- Save mount speed bonus
    DCCollectionDB.mountSpeedBonus = self.mountSpeedBonus
    
    -- Save wishlist
    DCCollectionDB.wishlistCache = self.wishlist
    
    self.cacheNeedsSave = false
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
    DCCollectionDB.syncVersions = nil
    
    -- Clear in-memory data
    for collType in pairs(self.collections) do
        self.collections[collType] = {}
    end
    for collType in pairs(self.definitions) do
        self.definitions[collType] = {}
    end

    -- Keep transmog alias consistent for Wardrobe/protocol callers.
    self._transmogDefinitions = self.definitions.transmog
    self.currency = { tokens = 0, emblems = 0 }
    self.wishlist = {}
    self.mountSpeedBonus = 0
    
    self:Print("Cache cleared")
end

-- ============================================================================
-- CACHE UPDATE FUNCTIONS
-- ============================================================================

local function NormalizeType(self, collectionType)
    if not collectionType then
        return nil
    end

    if type(collectionType) == "number" then
        return self:GetTypeNameFromId(collectionType)
    end

    local t = string.lower(tostring(collectionType))

    -- Normalize server/client variations to the canonical keys used by this addon.
    -- Many code paths assume plural keys (mounts/pets/heirlooms/titles).
    if t == "mount" then return "mounts" end
    if t == "pet" then return "pets" end
    if t == "heirloom" then return "heirlooms" end
    if t == "title" then return "titles" end
    if t == "appearances" or t == "appearance" then return "transmog" end

    return t
end

-- Expose the type normalization used by the cache layer so UI/protocol code can
-- consistently map server/client variants to the canonical keys.
function DC:NormalizeCollectionType(collectionType)
    return NormalizeType(self, collectionType)
end

local function NormalizeId(id)
    if id == nil then
        return nil
    end

    if type(id) == "number" then
        return id
    end

    return tonumber(id) or id
end

-- Add a single item to collection cache
function DC:CacheAddItem(collectionType, itemId, itemData)
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return
    end

    local normalizedId = NormalizeId(itemId)
    self.collections[typeName] = self.collections[typeName] or {}
    self.collections[typeName][normalizedId] = itemData

    self:_BumpCollectionsRevision(typeName)
    
    -- Update stats
    if self.stats[typeName] then
        self.stats[typeName].owned = self:CountCollection(typeName)
    end
    
    -- Mark for save
    self.cacheNeedsSave = true
end

-- Update item in collection (e.g., favorite status)
function DC:CacheUpdateItem(collectionType, itemId, updates)
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return
    end

    local normalizedId = NormalizeId(itemId)
    if self.collections[typeName] and self.collections[typeName][normalizedId] then
        for key, value in pairs(updates) do
            self.collections[typeName][normalizedId][key] = value
        end
        self:_BumpCollectionsRevision(typeName)
        self.cacheNeedsSave = true
    end
end

-- Add definition to cache
function DC:CacheAddDefinition(collectionType, itemId, defData)
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return
    end

    local normalizedId = NormalizeId(itemId)
    self.definitions[typeName] = self.definitions[typeName] or {}

    if typeName == "transmog" then
        self.definitions[typeName][normalizedId] = PackTransmogDefinition(defData)
    else
        self.definitions[typeName][normalizedId] = defData
    end

    self:_BumpDefinitionsRevision(typeName)
    
    -- Update total stats
    if self.stats[typeName] then
        self.stats[typeName].total = self:CountDefinitions(typeName)
    end
end

-- Batch update definitions
function DC:CacheMergeDefinitions(collectionType, definitions)
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return
    end

    self.definitions[typeName] = self.definitions[typeName] or {}

    -- For transmog, a few UI/protocol paths still read from DC._transmogDefinitions.
    -- Keep that pointing at the same table as DC.definitions.transmog.
    if typeName == "transmog" then
        if type(self._transmogDefinitions) == "table" and self._transmogDefinitions ~= self.definitions[typeName] then
            self.definitions[typeName] = self._transmogDefinitions
        else
            self._transmogDefinitions = self.definitions[typeName]
        end
    end
    
    local added = 0
    for itemId, defData in pairs(definitions) do
        local normalizedId = NormalizeId(itemId)
        if not self.definitions[typeName][normalizedId] then
            added = added + 1
        end
        if typeName == "transmog" then
            self.definitions[typeName][normalizedId] = PackTransmogDefinition(defData)
        else
            self.definitions[typeName][normalizedId] = defData
        end
    end

    if added > 0 then
        self:_BumpDefinitionsRevision(typeName)
    end
    
    if self.stats[typeName] and added > 0 then
        self.stats[typeName].total = (self.stats[typeName].total or 0) + added
    end
    
    self:Debug(string.format("Merged %d definitions for %s", added, typeName))
    if added > 0 then
        self.cacheNeedsSave = true
    end
end

-- Batch update collection
function DC:CacheMergeCollection(collectionType, items)
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return
    end

    self.collections[typeName] = self.collections[typeName] or {}
    
    local added = 0
    for itemId, itemData in pairs(items) do
        local normalizedId = NormalizeId(itemId)
        if not self.collections[typeName][normalizedId] then
            added = added + 1
        end
        self.collections[typeName][normalizedId] = itemData
    end

    if added > 0 then
        self:_BumpCollectionsRevision(typeName)
    end
    
    if self.stats[typeName] and added > 0 then
        self.stats[typeName].owned = (self.stats[typeName].owned or 0) + added
    end
    
    self:Debug(string.format("Merged %d items for %s collection", added, typeName))
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
    local typeName = NormalizeType(self, collectionType)
    return DCCollectionDB.syncVersions[typeName or collectionType] or 0
end

-- Set sync version after successful sync
function DC:SetSyncVersion(collectionType, version)
    DCCollectionDB.syncVersions = DCCollectionDB.syncVersions or {}
    local typeName = NormalizeType(self, collectionType)
    DCCollectionDB.syncVersions[typeName or collectionType] = version
end

-- Get IDs of items we already have (for delta request)
function DC:GetCollectedIds(collectionType)
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return {}
    end

    local ids = {}
    if self.collections[typeName] then
        for id in pairs(self.collections[typeName]) do
            table.insert(ids, id)
        end
    end
    return ids
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function DC:CountCollection(collectionType)
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return 0
    end

    local count = 0
    if self.collections[typeName] then
        for _ in pairs(self.collections[typeName]) do
            count = count + 1
        end
    end
    return count
end

function DC:CountDefinitions(collectionType)
    if collectionType then
        local typeName = NormalizeType(self, collectionType)
        if not typeName then
            return 0
        end

        local count = 0
        if self.definitions[typeName] then
            for _ in pairs(self.definitions[typeName]) do
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
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return nil
    end

    local normalizedId = NormalizeId(itemId)
    if self.definitions[typeName] then
        local v = self.definitions[typeName][normalizedId]
        if typeName == "transmog" and type(v) == "string" then
            return self:_GetUnpackedTransmogDefinition(normalizedId, v)
        end
        return v
    end
    return nil
end

-- Get collection item data
function DC:GetCollectionItem(collectionType, itemId)
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return nil
    end

    local normalizedId = NormalizeId(itemId)
    if self.collections[typeName] then
        return self.collections[typeName][normalizedId]
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
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return
    end

    self.collections[typeName] = {}
    
    if items then
        for itemId, itemData in pairs(items) do
            local normalizedId = NormalizeId(itemId)
            -- Handle both array format and key-value format
            if type(itemData) == "table" then
                self.collections[typeName][normalizedId] = itemData
            else
                -- Simple list of IDs
                self.collections[typeName][NormalizeId(itemData)] = { owned = true }
            end
        end
    end
    
    -- Update stats
    if self.stats[typeName] then
        self.stats[typeName].owned = self:CountCollection(typeName)
    end

    self:_BumpCollectionsRevision(typeName)
    
    self.cacheNeedsSave = true
    self:Debug(string.format("Set collection %s with %d items", 
        typeName, self:CountCollection(typeName)))
end

-- Add single item to collection
function DC:AddToCollection(collectionType, itemId, itemData)
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return false
    end

    local normalizedId = NormalizeId(itemId)
    self.collections[typeName] = self.collections[typeName] or {}
    
    if not self.collections[typeName][normalizedId] then
        self.collections[typeName][normalizedId] = itemData or { owned = true }

        self:_BumpCollectionsRevision(typeName)
        
        -- Update stats
        if self.stats[typeName] then
            self.stats[typeName].owned = self:CountCollection(typeName)
        end
        
        self.cacheNeedsSave = true
        return true  -- Item was added
    end
    
    return false  -- Item already existed
end

-- Remove single item from collection
function DC:RemoveFromCollection(collectionType, itemId)
    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return false
    end

    local normalizedId = NormalizeId(itemId)
    if self.collections[typeName] and self.collections[typeName][normalizedId] then
        self.collections[typeName][normalizedId] = nil

        self:_BumpCollectionsRevision(typeName)
        
        -- Update stats
        if self.stats[typeName] then
            self.stats[typeName].owned = self:CountCollection(typeName)
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
-- AUTO-SAVE (event-driven, not constant OnUpdate)
-- ============================================================================

local SAVE_INTERVAL = 60  -- Save every 60 seconds if needed
local autoSaveScheduled = false

local function ScheduleAutoSave()
    if autoSaveScheduled then
        return
    end
    autoSaveScheduled = true

    -- Use DC.After if available, otherwise create a simple timer frame.
    if DC.After and type(DC.After) == "function" then
        DC.After(SAVE_INTERVAL, function()
            autoSaveScheduled = false
            if DC.cacheNeedsSave then
                DC:SaveCache()
            end
        end)
    else
        local timerFrame = CreateFrame("Frame")
        timerFrame.elapsed = 0
        timerFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= SAVE_INTERVAL then
                self:Hide()
                self:SetScript("OnUpdate", nil)
                autoSaveScheduled = false
                if DC.cacheNeedsSave then
                    DC:SaveCache()
                end
            end
        end)
    end
end

-- Hook into cacheNeedsSave to schedule auto-save when data becomes dirty.
local origCacheAddItem = DC.CacheAddItem
function DC:CacheAddItem(...)
    local result = origCacheAddItem(self, ...)
    if self.cacheNeedsSave then
        ScheduleAutoSave()
    end
    return result
end

local origCacheUpdateItem = DC.CacheUpdateItem
function DC:CacheUpdateItem(...)
    local result = origCacheUpdateItem(self, ...)
    if self.cacheNeedsSave then
        ScheduleAutoSave()
    end
    return result
end

local origCacheMergeCollection = DC.CacheMergeCollection
function DC:CacheMergeCollection(...)
    local result = origCacheMergeCollection(self, ...)
    if self.cacheNeedsSave then
        ScheduleAutoSave()
    end
    return result
end

local origCacheMergeDefinitions = DC.CacheMergeDefinitions
function DC:CacheMergeDefinitions(...)
    local result = origCacheMergeDefinitions(self, ...)
    if self.cacheNeedsSave then
        ScheduleAutoSave()
    end
    return result
end

local origCacheUpdateCurrency = DC.CacheUpdateCurrency
function DC:CacheUpdateCurrency(...)
    local result = origCacheUpdateCurrency(self, ...)
    if self.cacheNeedsSave then
        ScheduleAutoSave()
    end
    return result
end
