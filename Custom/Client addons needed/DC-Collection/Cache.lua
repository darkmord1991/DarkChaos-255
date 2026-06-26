--[[
    DC-Collection Cache.lua
    =======================
    
    Local caching of collection data in SavedVariables.
    Implements additive-only delta sync for optimal performance.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

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
local TITLE_CACHE_FRESH_SECONDS = 30 * 60
local SAVED_OUTFITS_CACHE_FRESH_SECONDS = 30 * 60

local function IsAbsoluteTimestampFresh(timestamp, maxAgeSeconds)
    local savedAt = tonumber(timestamp) or 0
    if savedAt <= 0 then
        return false
    end

    local age = time() - savedAt
    return age >= 0 and age < maxAgeSeconds
end

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
    -- When the catalog is served natively it always counts as present.
    if not (type(self.HasNativeTransmogCatalog) == "function" and
            self:HasNativeTransmogCatalog()) then
        local transmogDefs = self.definitions.transmog
        if type(transmogDefs) ~= "table" or not next(transmogDefs) then
            -- No transmog definitions - don't consider cache "valid" for heavy requests.
            return false
        end
    end

    -- Mounts and companions are also critical - check them too.
    local mountDefs = self.definitions.mounts or self.definitions.mount
    local companionDefs = self.definitions.companions or self.definitions.companion or self.definitions.pets or self.definitions.pet
    
    if type(mountDefs) ~= "table" or not next(mountDefs) then
        self:Debug("HasCachedDefinitions: mounts definitions missing")
        return false
    end

    -- Schema migration: mount definitions now carry riding speed fields
    -- (speed/groundSpeed/flySpeed). Every real mount has at least one speed
    -- aura, so a cache where NO mount has any speed field predates the
    -- schema -- treat it as stale to force a refetch.
    do
        local hasAnySpeed = false
        for _, def in pairs(mountDefs) do
            if type(def) == "table"
                and (def.speed or def.groundSpeed or def.flySpeed) then
                hasAnySpeed = true
                break
            end
        end
        if not hasAnySpeed then
            self:Debug("HasCachedDefinitions: mount definitions predate speed fields")
            return false
        end
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

function DC:_InvalidateTransmogDefinitionLookup()
    self._transmogDefinitionAliasLookup = nil
end

-- ============================================================================
-- NATIVE (DLL) TRANSMOG CATALOG
-- ============================================================================
-- The transmog appearance catalog is served from the WotLKExtensions DLL
-- (DCCollectionTransmog.cdbc) via indexed/paged accessors. When available we
-- keep the catalog in the DLL instead of materialising it into Lua tables
-- (definitions.transmog + alias lookups), which previously cost hundreds of MB
-- of addon memory. See QueryDCCollectionTransmog / GetDCCollectionTransmog* and
-- SetDCCollectionTransmogCollected in the DLL (CustomLua.cpp).

function DC:HasNativeTransmogCatalog()
    return self._transmogNativeCatalog == true
        and type(QueryDCCollectionTransmog) == "function"
end

-- Normalise a DLL appearance row into the def shape the addon expects from
-- GetDefinition (itemIds as a number array; rarity/quality both present).
function DC:_NativeTransmogRowToDef(row)
    if type(row) ~= "table" then
        return nil
    end

    local itemIds = row.itemIds
    if type(itemIds) == "string" and itemIds ~= "" then
        local t = {}
        for s in string.gmatch(itemIds, "[^,]+") do
            local n = tonumber(s)
            if n then
                t[#t + 1] = n
            end
        end
        row.itemIds = t
    elseif type(itemIds) ~= "table" then
        row.itemIds = nil
    end

    if row.rarity == nil then row.rarity = row.quality end
    if row.quality == nil then row.quality = row.rarity end
    return row
end

-- Push the player's collected transmog keys to the DLL so native queries can
-- compute collected/uncollected state. Cheap; only re-pushed when the
-- collections revision changes (or when forced after a collection update).
function DC:_SyncNativeTransmogCollected(force)
    if type(SetDCCollectionTransmogCollected) ~= "function" then
        return
    end

    local rev = 0
    if type(self.GetCollectionsRevision) == "function" then
        rev = self:GetCollectionsRevision("transmog") or 0
    end
    if not force and self._nativeTransmogCollectedRev == rev then
        return
    end

    local col = self.collections and
        (self.collections.transmog or self.collections.wardrobe)
    local parts = {}
    if type(col) == "table" then
        for key in pairs(col) do
            local n = tonumber(key)
            if n then
                parts[#parts + 1] = n
            end
        end
    end

    pcall(SetDCCollectionTransmogCollected, table.concat(parts, ","))
    self._nativeTransmogCollectedRev = rev
end

local function ShouldPreferTransmogAlias(currentDef, candidateDef)
    if type(candidateDef) ~= "table" then
        return false
    end

    if type(currentDef) ~= "table" then
        return true
    end

    local candidateQuality = tonumber(candidateDef.quality or candidateDef.rarity) or 0
    local currentQuality = tonumber(currentDef.quality or currentDef.rarity) or 0
    if candidateQuality ~= currentQuality then
        return candidateQuality > currentQuality
    end

    local candidateItemId = tonumber(candidateDef.itemId or candidateDef.item_id) or 0
    local currentItemId = tonumber(currentDef.itemId or currentDef.item_id) or 0
    if candidateItemId <= 0 then
        return false
    end
    if currentItemId <= 0 then
        return true
    end

    return candidateItemId < currentItemId
end

function DC:_EnsureTransmogDefinitionAliasLookup()
    if type(self._transmogDefinitionAliasLookup) == "table" then
        return self._transmogDefinitionAliasLookup
    end

    local defs = nil
    if type(self.definitions) == "table" then
        defs = self.definitions.transmog
    end
    if type(defs) ~= "table" then
        defs = self._transmogDefinitions
    end
    if type(defs) ~= "table" then
        return nil
    end

    local lookup = {
        byDisplayId = {},
        byItemId = {},
    }

    for defKey, rawDef in pairs(defs) do
        local def = rawDef
        if type(rawDef) == "string" then
            def = self:_GetUnpackedTransmogDefinition(defKey, rawDef)
        end

        if type(def) == "table" then
            local displayId = tonumber(def.displayId or def.displayID or def.display_id or def.appearanceId or def.appearance_id)
            if displayId and displayId > 0 then
                local current = lookup.byDisplayId[displayId]
                if not current or ShouldPreferTransmogAlias(current.def, def) then
                    lookup.byDisplayId[displayId] = { raw = rawDef, def = def }
                end
            end

            local itemId = tonumber(def.itemId or def.item_id) or 0
            if itemId > 0 and not lookup.byItemId[itemId] then
                lookup.byItemId[itemId] = { raw = rawDef, def = def }
            end

            if type(def.itemIds) == "table" then
                for _, candidateId in ipairs(def.itemIds) do
                    candidateId = tonumber(candidateId) or 0
                    if candidateId > 0 and not lookup.byItemId[candidateId] then
                        lookup.byItemId[candidateId] = { raw = rawDef, def = def }
                    end
                end
            end
        end
    end

    self._transmogDefinitionAliasLookup = lookup
    return lookup
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
        -- If the DLL serves the transmog catalog, don't even load the (possibly
        -- stale, multi-MB) persisted copy - it would only be dropped moments
        -- later by BootstrapLocalCollectionCDBC. Avoids a first-login RAM spike.
        local nativeTransmog = type(QueryDCCollectionTransmog) == "function"
            and type(GetDCCollectionTransmogCount) == "function"
        for collType, defs in pairs(DCCollectionDB.definitionCache) do
            -- Keep transmog packed in memory to reduce RAM.
            if collType == "transmog" then
                if not nativeTransmog then
                    local packedDefs = {}
                    for id, data in pairs(defs) do
                        if type(data) == "table" then
                            packedDefs[id] = PackTransmogDefinition(data)
                        else
                            packedDefs[id] = data
                        end
                    end
                    self.definitions[collType] = packedDefs
                end
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

    self._titleCollectionAuthoritative =
        DCCollectionDB.titleCollectionAuthoritative == true
    self._titleCollectionLastReceivedAt =
        tonumber(DCCollectionDB.titleCollectionLastReceivedAt) or 0
    if self._titleCollectionLastReceivedAt > 0 then
        self._collectionLastReceivedAt = self._collectionLastReceivedAt or {}
        self._collectionLastReceivedAt.titles = self._titleCollectionLastReceivedAt
    end
    
    -- Load currency
    if DCCollectionDB.currencyCache then
        self.currency.tokens = DCCollectionDB.currencyCache.tokens or 0
        self.currency.emblems = DCCollectionDB.currencyCache.emblems or 0

        local central = rawget(_G, "DCAddonProtocol")
        if central and type(central.SetServerCurrencyBalance) == "function" then
            central:SetServerCurrencyBalance(
                self.currency.tokens or 0,
                self.currency.emblems or 0)
        end
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

    if DCCollectionDB.shopItemsCache then
        self.shopItems = DCCollectionDB.shopItemsCache
        self.shopCategory = DCCollectionDB.shopCategoryCache or "default"
    end

    local cachedTitleCount = 0
    if type(self.CountCollection) == "function" then
        cachedTitleCount = tonumber(self:CountCollection("titles")) or 0
    end
    local cachedTitleOwned = tonumber(
        DCCollectionDB.statsCache and
        DCCollectionDB.statsCache.titles and
        DCCollectionDB.statsCache.titles.owned) or 0

    if self._titleCollectionAuthoritative ~= true and
       cachedTitleCount == cachedTitleOwned then
        self._titleCollectionAuthoritative = true
    end

    if self._titleCollectionAuthoritative == true and
       IsAbsoluteTimestampFresh(
           DCCollectionDB.titleCollectionLastReceivedAt,
           TITLE_CACHE_FRESH_SECONDS) then
        local runtimeReceivedAt = (type(GetTime) == "function" and GetTime()) or
            (type(time) == "function" and time()) or 0
        self._titleCollectionLastReceivedAt = runtimeReceivedAt
        self._collectionLastReceivedAt = self._collectionLastReceivedAt or {}
        self._collectionLastReceivedAt.titles = runtimeReceivedAt
    end
    
    -- Load mount speed bonus
    self.mountSpeedBonus = DCCollectionDB.mountSpeedBonus or 0
    
    -- Load wishlist
    if DCCollectionDB.wishlistCache then
        if type(self.NormalizeWishlistItems) == "function" then
            self.wishlist = self:NormalizeWishlistItems(DCCollectionDB.wishlistCache)
        else
            self.wishlist = DCCollectionDB.wishlistCache
        end
    end

    -- Load per-character transmog state
    if DCCollectionCharDB and DCCollectionCharDB.transmogState then
        self.transmogState = DCCollectionCharDB.transmogState
    end

    -- Load per-character transmog itemIds (fake entries used for icon + TryOn)
    if DCCollectionCharDB and DCCollectionCharDB.transmogItemIds then
        self.transmogItemIds = DCCollectionCharDB.transmogItemIds
    end

    -- Normalize cached transmog maps (some decoders/older saves may shift numeric keys).
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

        local shift = (minNumKey == 1) and -1 or 0
        for k, v in pairs(tbl) do
            if type(k) == "number" then
                out[tostring(k + shift)] = v
            end
        end
        return out
    end

    if self.transmogState then
        self.transmogState = normalizeSlotMap(self.transmogState)
    end
    if self.transmogItemIds then
        self.transmogItemIds = normalizeSlotMap(self.transmogItemIds)
    end

    local savedOutfitsMeta = DCCollectionCharDB and DCCollectionCharDB.savedOutfitsMeta
    if IsAbsoluteTimestampFresh(
        savedOutfitsMeta and savedOutfitsMeta.lastSync,
        SAVED_OUTFITS_CACHE_FRESH_SECONDS) then
        local cachedPages = DCCollectionCharDB and DCCollectionCharDB.savedOutfitsPages
        local cachedOutfits = DCCollectionCharDB and DCCollectionCharDB.savedOutfits
        local normalizedPages = nil

        if type(cachedPages) == "table" then
            normalizedPages = {}
            for pageOffset, page in pairs(cachedPages) do
                if type(page) == "table" then
                    local numericOffset = tonumber(pageOffset)
                    if numericOffset ~= nil then
                        normalizedPages[numericOffset] = page
                    else
                        normalizedPages[pageOffset] = page
                    end
                end
            end
        end

        if type(normalizedPages) == "table" or type(cachedOutfits) == "table" then
            DC.db = DC.db or {}
            DC.db.outfitsPages = normalizedPages or { [0] = cachedOutfits }
            DC.db.outfitsOffset = tonumber(DCCollectionCharDB and DCCollectionCharDB.savedOutfitsOffset) or 0
            DC.db.outfitsLimit = tonumber(DCCollectionCharDB and DCCollectionCharDB.savedOutfitsLimit) or 6
            DC.db.outfitsTotal = tonumber(DCCollectionCharDB and DCCollectionCharDB.savedOutfitsTotal)
                or (type(cachedOutfits) == "table" and #cachedOutfits)
                or 0
            DC.db.outfitsMeta = savedOutfitsMeta

            local cachedPage = DC.db.outfitsPages[DC.db.outfitsOffset]
            if type(cachedPage) ~= "table" then
                for pageOffset, page in pairs(DC.db.outfitsPages) do
                    if type(page) == "table" then
                        cachedPage = page
                        DC.db.outfitsOffset = tonumber(pageOffset) or 0
                        break
                    end
                end
            end

            DC.db.outfits = (type(cachedPage) == "table" and cachedPage)
                or (type(cachedOutfits) == "table" and cachedOutfits)
                or {}

            if Wardrobe and type(Wardrobe.SerializeSlotsToJsonString) == "function" then
                DC.db.outfitsBySignature = {}
                for _, page in pairs(DC.db.outfitsPages) do
                    if type(page) == "table" then
                        for _, outfit in ipairs(page) do
                            local slots = outfit and (outfit.slots or outfit.items)
                            if type(slots) == "table" then
                                local sig = Wardrobe.SerializeSlotsToJsonString(slots)
                                if sig and sig ~= "" then
                                    DC.db.outfitsBySignature[sig] = outfit
                                end
                            end
                        end
                    end
                end
            end

            self:Debug("Loaded fresh saved outfits cache")
        end
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
    -- Definition types served from the DLL/DBC at startup (local-cdbc / native)
    -- must NOT be persisted: they reload from the client cdbc every launch, so
    -- persisting them only bloats SavedVariables (the catalog was ~95% of the
    -- file) and triplicates the shared item-set table (itemsets/itemSets/sets
    -- are one shared reference at runtime but serialise to 3 independent copies).
    local skipPersist = {}
    local cdbcState = self._localCollectionCDBC
    if type(cdbcState) == "table" then
        if type(cdbcState.definitionSources) == "table" then
            for k, src in pairs(cdbcState.definitionSources) do
                if src == "local-cdbc" or src == "native-dll" then
                    skipPersist[k] = true
                end
            end
        end
        if cdbcState.itemSetsSource == "local-cdbc" then
            skipPersist.itemsets = true
            skipPersist.itemSets = true
            skipPersist.sets = true
        end
    end
    if self:HasNativeTransmogCatalog() then
        skipPersist.transmog = true
    end

    local defsToSave = {}
    if self.definitions then
        for k, v in pairs(self.definitions) do
            if skipPersist[k] then
                -- served from the DLL/DBC; nothing to persist
            elseif k == "transmog" then -- Only pack transmog for now
                local packedTransmog = {}
                for id, def in pairs(v) do
                    packedTransmog[id] = PackTransmogDefinition(def)
                end
                defsToSave[k] = packedTransmog
            else
                 -- Save other definitions (e.g. server-only types) as normal
                 -- tables. They are not large enough to cause logout freezes.
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
    if type(self.NormalizeWishlistItems) == "function" then
        DCCollectionDB.wishlistCache = self:NormalizeWishlistItems(self.wishlist)
    else
        DCCollectionDB.wishlistCache = self.wishlist
    end
    DCCollectionDB.shopItemsCache = self.shopItems
    DCCollectionDB.shopCategoryCache = self.shopCategory

    DCCollectionDB.titleCollectionAuthoritative =
        self._titleCollectionAuthoritative == true
    DCCollectionDB.titleCollectionLastReceivedAt =
        tonumber(self._titleCollectionLastReceivedAt) or 0
    
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
    DCCollectionDB.shopItemsCache = nil
    DCCollectionDB.shopCategoryCache = nil
    DCCollectionDB.mountSpeedBonus = nil
    DCCollectionDB.titleCollectionAuthoritative = nil
    DCCollectionDB.titleCollectionLastReceivedAt = nil
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
    self.shopItems = nil
    self.shopCategory = nil
    self.mountSpeedBonus = 0
    self._titleCollectionAuthoritative = nil
    self._titleCollectionLastReceivedAt = nil

    if type(self.BootstrapLocalCollectionCDBC) == "function" then
        self:BootstrapLocalCollectionCDBC(true)
    end
    
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

local LOCAL_COLLECTION_TYPE_TO_NAME = {
    [1] = "mounts",
    [2] = "pets",
    [4] = "heirlooms",
    [5] = "titles",
    [6] = "transmog",
}

local SHOP_FILTER_DEFAULTS = {
    { key = "all", text = L["FILTER_ALL"] or "All" },
    { key = "bonus", text = L["SHOP_TYPE_BONUS"] or "Bonuses" },
    { key = "mount", text = L["SHOP_TYPE_MOUNT"] or "Mounts" },
    { key = "pet", text = L["SHOP_TYPE_PET"] or "Pets" },
}

local function MixLocalSignature(hash, value)
    hash = tonumber(hash) or 5381
    value = tonumber(value) or 0
    hash = ((hash * 131) + value + 17) % 2147483647
    if hash <= 0 then
        hash = hash + 2147483646
    end
    return hash
end

local function MixLocalSignatureString(hash, value)
    if type(value) ~= "string" then
        return MixLocalSignature(hash, 0)
    end

    for index = 1, string.len(value) do
        hash = MixLocalSignature(hash, string.byte(value, index))
    end

    return hash
end

local function ResolveLocalCategoryKey(row)
    local key = row and row.key
    if type(key) == "string" and key ~= "" then
        return string.lower(key)
    end

    local collectionType = tonumber(row and row.collectionType) or 0
    if collectionType == 1 then return "mount" end
    if collectionType == 2 then return "pet" end
    if collectionType == 4 then return "heirloom" end
    if collectionType == 5 then return "title" end
    if collectionType == 6 then return "transmog" end
    return nil
end

local function ResolveLocalSourceValue(row)
    if type(row) ~= "table" then
        return nil
    end

    local sourceType = row.sourceType
    if type(sourceType) == "string" and sourceType ~= "" then
        sourceType = string.lower(sourceType)
    else
        sourceType = nil
    end

    local sourceName = row.sourceName
    local sourceText = row.sourceText
    local sourceObjectId = tonumber(row.sourceObjectId) or 0
    local sourceValue = tonumber(row.sourceValue) or 0
    local itemId = tonumber(row.itemId) or 0

    if sourceText and sourceText ~= "" and (not sourceType or sourceType == "text") then
        return sourceText
    end

    if sourceType == "drop" then
        local source = { type = "drop" }
        if type(sourceName) == "string" and sourceName ~= "" then
            source.boss = sourceName
        end
        if sourceObjectId > 0 then
            source.creatureEntry = sourceObjectId
        end
        if sourceValue > 0 then
            source.dropRate = sourceValue
        end
        return source
    end

    if sourceType == "vendor" then
        local source = { type = "vendor" }
        if type(sourceName) == "string" and sourceName ~= "" then
            source.npc = sourceName
        end
        if sourceObjectId > 0 then
            source.npcEntry = sourceObjectId
        end
        return source
    end

    if sourceType == "quest" then
        local source = { type = "quest" }
        if sourceObjectId > 0 then
            source.questId = sourceObjectId
        end
        return source
    end

    if sourceType == "unknown" then
        local source = { type = "unknown" }
        if itemId > 0 then
            source.itemId = itemId
        end
        return source
    end

    if sourceType == "achievement" then
        return string.format(L["SOURCE_ACHIEVEMENT"] or "Achievement: %s",
            (type(sourceName) == "string" and sourceName ~= "") and
                sourceName or ("#" .. tostring(sourceObjectId)))
    end

    if sourceType == "profession" then
        return string.format(L["SOURCE_PROFESSION"] or "Profession: %s",
            (type(sourceName) == "string" and sourceName ~= "") and
                sourceName or ("#" .. tostring(sourceObjectId)))
    end

    if sourceType == "reputation" then
        return string.format(L["SOURCE_REPUTATION"] or "Reputation: %s",
            (type(sourceName) == "string" and sourceName ~= "") and
                sourceName or ("#" .. tostring(sourceObjectId)))
    end

    if sourceType == "pvp" then
        return L["SOURCE_PVP"] or "PvP Reward"
    end

    if sourceType == "promotion" then
        return L["SOURCE_PROMOTION"] or "Promotional"
    end

    if sourceType == "darkchaos" then
        return L["SOURCE_DARKCHAOS"] or "DarkChaos Exclusive"
    end

    if type(sourceText) == "string" and sourceText ~= "" then
        return sourceText
    end

    if type(sourceName) == "string" and sourceName ~= "" then
        return sourceName
    end

    if itemId > 0 then
        return { type = "unknown", itemId = itemId }
    end

    return nil
end

local function BuildLocalTransmogVariantKey(displayId, inventoryType, itemClass, itemSubClass)
    return table.concat({
        tostring(tonumber(displayId) or 0),
        tostring(tonumber(inventoryType) or 0),
        tostring(tonumber(itemClass) or 0),
        tostring(tonumber(itemSubClass) or 0),
    }, ":")
end

local function ParseLocalTransmogItemIds(rawValue)
    if type(rawValue) == "table" then
        return rawValue
    end

    if type(rawValue) ~= "string" or rawValue == "" then
        return nil
    end

    local itemIds = {}
    for token in string.gmatch(rawValue, "[^,]+") do
        local itemId = tonumber(token)
        if itemId and itemId > 0 then
            itemIds[#itemIds + 1] = itemId
        end
    end

    if #itemIds == 0 then
        return nil
    end

    return itemIds
end

function DC:GetShopFilterButtons()
    if type(self.ApplyCollectionDataFeaturePolicies) == "function" then
        self:ApplyCollectionDataFeaturePolicies()
    end

    local byKey = self.collectionCategoriesByKey or {}
    local filters = {}

    for _, info in ipairs(SHOP_FILTER_DEFAULTS) do
        local category = byKey[info.key] or byKey[info.key .. "s"]
        filters[#filters + 1] = {
            key = info.key,
            text = (category and category.name) or info.text,
            icon = category and category.icon or nil,
        }
    end

    return filters
end

local HANDSHAKE_COLLECTION_FEATURE_KEYS = {
    categories = "collectionCategories",
    mounts = "collectionSources",
    pets = "collectionSources",
    heirlooms = "collectionSources",
    titles = "collectionSources",
    shop = "collectionShop",
    itemsets = "collectionSets",
    sets = "collectionSets",
    transmog = "collectionTransmog",
}

local SOURCE_COLLECTION_TYPES = {
    mounts = true,
    pets = true,
    heirlooms = true,
    titles = true,
}

local function ReadBooleanish(value)
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

local function ClearLocalDefinitionType(self, state, typeName)
    if type(state) ~= "table" or
       type(state.definitionSources) ~= "table" or
       state.definitionSources[typeName] ~= "local-cdbc" then
        return false
    end

    self.definitions = self.definitions or {}
    self.definitions[typeName] = {}
    state.definitionTypes[typeName] = false
    state.definitionSources[typeName] = nil
    state.authoritativeDefinitionTypes[typeName] = false

    if typeName == "transmog" then
        self._transmogDefinitions = self.definitions[typeName]
        self._transmogDefinitionsSource = nil
        self._transmogDefTotal = 0
        if type(self._InvalidateTransmogDefinitionLookup) == "function" then
            self:_InvalidateTransmogDefinitionLookup()
        end
        self.definitionsLoaded = false
        if self.Wardrobe then
            self.Wardrobe.definitionsLoaded = false
        end
    end

    if type(self.SetSyncVersion) == "function" then
        self:SetSyncVersion(typeName, 0)
    end
    if type(self._BumpDefinitionsRevision) == "function" then
        self:_BumpDefinitionsRevision(typeName)
    end
    if self.stats and self.stats[typeName] then
        self.stats[typeName].total = 0
    end

    return true
end

local function ClearLocalItemSets(self, state)
    if type(state) ~= "table" or state.itemSetsSource ~= "local-cdbc" then
        return false
    end

    self.definitions = self.definitions or {}
    self.definitions.itemsets = {}
    self.definitions.itemSets = self.definitions.itemsets
    self.definitions.sets = self.definitions.itemsets
    self.itemSetsLoaded = false
    state.setsLoaded = false

    if type(self.SetSyncVersion) == "function" then
        self:SetSyncVersion("itemsets", 0)
    end
    if type(self._BumpDefinitionsRevision) == "function" then
        self:_BumpDefinitionsRevision("itemsets")
    end

    state.itemSetsSource = nil
    state.authoritativeItemSets = false
    return true
end

local function ClearLocalShopMetadata(self, state)
    if type(state) ~= "table" or not state.shopMetadataSource then
        return false
    end

    state.shopMetadataById = {}
    state.shopMetadataByTypeEntry = {}
    state.shopMetadataAuthoritative = false
    state.shopMetadataSource = nil
    self.localShopMetadataById = {}
    self.localShopMetadataByTypeEntry = {}
    return true
end

local function ClearLocalCategories(self, state)
    if type(state) ~= "table" or state.categoriesSource ~= "local-cdbc" then
        return false
    end

    self.collectionCategories = {}
    self.collectionCategoriesById = {}
    self.collectionCategoriesByKey = {}
    state.categoriesLoaded = false
    state.categoriesAuthoritative = false
    state.categoriesSource = nil
    return true
end

function DC:GetCollectionDataFeaturePolicy(collectionType)
    local featureKey = HANDSHAKE_COLLECTION_FEATURE_KEYS[
        NormalizeType(self, collectionType)]
    if not featureKey then
        return nil
    end

    local central = rawget(_G, "DCAddonProtocol")
    if type(central) ~= "table" or
       type(central.GetCapabilitySnapshot) ~= "function" then
        return nil
    end

    local ok, snapshot = pcall(function()
        return central:GetCapabilitySnapshot()
    end)
    if not ok or type(snapshot) ~= "table" or
       type(snapshot.serverDataFeatureStates) ~= "table" then
        return nil
    end

    local entry = snapshot.serverDataFeatureStates[featureKey]
    if type(entry) ~= "table" then
        return nil
    end

    local stateName = tostring(entry.state or entry.s or "")
    if stateName == "" then
        return nil
    end

    return {
        featureKey = featureKey,
        state = stateName,
        requiredRevision = tonumber(entry.requiredRevision or entry.rr) or 0,
        installedRevision = tonumber(entry.installedRevision or entry.ir) or 0,
        fallbackAllowed = ReadBooleanish(
            entry.fallbackAllowed or entry.fa),
        reason = tostring(entry.reason or entry.r or ""),
    }
end

function DC:ApplyCollectionDataFeaturePolicies()
    local state = self._localCollectionCDBC
    if type(state) ~= "table" then
        return nil
    end

    local appliedPolicies = {}

    local categoriesPolicy = self:GetCollectionDataFeaturePolicy("categories")
    if type(categoriesPolicy) == "table" then
        state.categoriesAuthoritative =
            categoriesPolicy.state == "OK_NATIVE_DBC" and
            state.categoriesLoaded == true

        if categoriesPolicy.state ~= "OK_NATIVE_DBC" then
            ClearLocalCategories(self, state)
        end

        appliedPolicies.categories = categoriesPolicy
    end

    local sourcesPolicy = self:GetCollectionDataFeaturePolicy("mounts")
    if type(sourcesPolicy) == "table" then
        for typeName in pairs(SOURCE_COLLECTION_TYPES) do
            local nativeEligible =
                type(state.nativeEligibleDefinitionTypes) == "table" and
                state.nativeEligibleDefinitionTypes[typeName] == true

            state.authoritativeDefinitionTypes[typeName] =
                sourcesPolicy.state == "OK_NATIVE_DBC" and
                state.definitionTypes[typeName] == true and
                nativeEligible

            if sourcesPolicy.state ~= "OK_NATIVE_DBC" then
                ClearLocalDefinitionType(self, state, typeName)
            end
        end

        appliedPolicies.sources = sourcesPolicy
    end

    local transmogPolicy = self:GetCollectionDataFeaturePolicy("transmog")
    if type(transmogPolicy) == "table" then
        local nativeEligible =
            type(state.nativeEligibleDefinitionTypes) == "table" and
            state.nativeEligibleDefinitionTypes.transmog == true

        state.authoritativeDefinitionTypes.transmog =
            transmogPolicy.state == "OK_NATIVE_DBC" and
            state.definitionTypes.transmog == true and
            nativeEligible

        if transmogPolicy.state ~= "OK_NATIVE_DBC" then
            ClearLocalDefinitionType(self, state, "transmog")
        end

        appliedPolicies.transmog = transmogPolicy
    end

    local setsPolicy = self:GetCollectionDataFeaturePolicy("itemsets")
    if type(setsPolicy) == "table" then
        state.authoritativeItemSets =
            setsPolicy.state == "OK_NATIVE_DBC" and
            state.setsLoaded == true and
            state.nativeEligibleItemSets == true

        if setsPolicy.state ~= "OK_NATIVE_DBC" then
            ClearLocalItemSets(self, state)
        end

        appliedPolicies.itemsets = setsPolicy
    end

    local shopPolicy = self:GetCollectionDataFeaturePolicy("shop")
    if type(shopPolicy) == "table" then
        state.shopMetadataAuthoritative =
            shopPolicy.state == "OK_NATIVE_DBC" and
            state.nativeEligibleShopMetadata == true

        if shopPolicy.state ~= "OK_NATIVE_DBC" then
            ClearLocalShopMetadata(self, state)
        end

        appliedPolicies.shop = shopPolicy
    end

    if next(appliedPolicies) == nil then
        return nil
    end

    return appliedPolicies
end

function DC:HasLocalCollectionDefinitions(collectionType)
    if type(self.ApplyCollectionDataFeaturePolicies) == "function" then
        self:ApplyCollectionDataFeaturePolicies()
    end

    local state = self._localCollectionCDBC
    if type(state) ~= "table" or
       type(state.definitionTypes) ~= "table" or
       type(state.authoritativeDefinitionTypes) ~= "table" then
        return false
    end

    local typeName = NormalizeType(self, collectionType)
    if typeName == "pets" and
       type(state.previewIncompleteDefinitionTypes) == "table" and
         state.previewIncompleteDefinitionTypes.pets == true and
         state.allowPreviewIncompletePets ~= true then
        return false
    end

    return state.definitionTypes[typeName] == true and
        state.authoritativeDefinitionTypes[typeName] == true
end

function DC:HasLocalCollectionItemSets()
    if type(self.ApplyCollectionDataFeaturePolicies) == "function" then
        self:ApplyCollectionDataFeaturePolicies()
    end

    local state = self._localCollectionCDBC
    return type(state) == "table" and state.authoritativeItemSets == true
end

function DC:ShouldUseLocalCollectionShopMetadata()
    if type(self.ApplyCollectionDataFeaturePolicies) == "function" then
        self:ApplyCollectionDataFeaturePolicies()
    end

    local state = self._localCollectionCDBC
    return type(state) == "table" and
        state.shopMetadataAuthoritative == true
end

function DC:GetLocalCollectionStaticManifest()
    local state = self._localCollectionCDBC
    if type(state) == "table" and type(state.manifest) == "table" then
        return state.manifest
    end

    if type(self.COLLECTION_STATIC_MANIFEST) == "table" then
        return self.COLLECTION_STATIC_MANIFEST
    end

    return nil
end

function DC:GetLocalCollectionCompleteness(collectionType)
    local manifest = self:GetLocalCollectionStaticManifest()
    if type(manifest) ~= "table" or type(manifest.types) ~= "table" then
        return nil
    end

    local typeName = NormalizeType(self, collectionType)
    if not typeName then
        return nil
    end

    return manifest.types[typeName]
end

function DC:GetLocalShopMetadata(shopId, collectionType, entryId)
    if type(self.ApplyCollectionDataFeaturePolicies) == "function" then
        self:ApplyCollectionDataFeaturePolicies()
    end

    local state = self._localCollectionCDBC
    if type(state) ~= "table" then
        return nil
    end

    local normalizedShopId = tonumber(shopId)
    if normalizedShopId and type(state.shopMetadataById) == "table" then
        local byShopId = state.shopMetadataById[normalizedShopId]
        if byShopId then
            return byShopId
        end
    end

    local typeName = NormalizeType(self, collectionType)
    local normalizedEntryId = tonumber(entryId)
    if typeName and normalizedEntryId and
       type(state.shopMetadataByTypeEntry) == "table" then
        local byType = state.shopMetadataByTypeEntry[typeName]
        if type(byType) == "table" then
            return byType[normalizedEntryId]
        end
    end

    return nil
end

function DC:BootstrapLocalCollectionCDBC(force)
    if self._localCollectionCDBCBootstrapped and not force then
        return self._localCollectionCDBC
    end

    local state = {
        available = false,
        categoriesLoaded = false,
        categoriesAuthoritative = false,
        categoriesSource = nil,
        sourcesLoaded = false,
        setsLoaded = false,
        authoritativeItemSets = false,
        nativeEligibleItemSets = false,
        itemSetsSource = nil,
        definitionTypes = {},
        definitionSources = {},
        authoritativeDefinitionTypes = {},
        nativeEligibleDefinitionTypes = {},
        previewIncompleteDefinitionTypes = {},
        previewIncompleteDefinitionCounts = {},
        signatures = {},
        manifest = nil,
        allowPreviewIncompletePets = false,
        shopMetadataById = {},
        shopMetadataByTypeEntry = {},
        shopMetadataAuthoritative = false,
        nativeEligibleShopMetadata = false,
        shopMetadataSource = nil,
    }

    if type(self.COLLECTION_STATIC_MANIFEST) == "table" then
        state.manifest = self.COLLECTION_STATIC_MANIFEST
    end

    if type(GetDCCollectionCategories) == "function" then
        local ok, rows = pcall(GetDCCollectionCategories)
        if ok and type(rows) == "table" and next(rows) ~= nil then
            local byId = {}
            local byKey = {}

            for _, row in ipairs(rows) do
                local id = tonumber(row.id)
                if id and id > 0 then
                    local category = {
                        id = id,
                        collectionType = tonumber(row.collectionType) or 0,
                        parentId = tonumber(row.parentId) or nil,
                        sortOrder = tonumber(row.sortOrder) or 0,
                        flags = tonumber(row.flags) or 0,
                        key = ResolveLocalCategoryKey(row),
                        name = row.name,
                        icon = row.icon,
                    }

                    byId[id] = category
                    if category.key then
                        byKey[category.key] = category
                    end
                end
            end

            self.collectionCategories = byId
            self.collectionCategoriesById = byId
            self.collectionCategoriesByKey = byKey
            state.categoriesLoaded = true
            state.categoriesAuthoritative = true
            state.categoriesSource = "local-cdbc"
            state.available = true
        end
    end

    if type(GetDCCollectionSources) == "function" then
        local ok, rows = pcall(GetDCCollectionSources)
        if ok and type(rows) == "table" and next(rows) ~= nil then
            local perType = {
                mounts = {},
                pets = {},
                heirlooms = {},
                titles = {},
            }
            local localDefinitionsChanged = false
            local signatures = {
                mounts = 5381,
                pets = 5381,
                heirlooms = 5381,
                titles = 5381,
            }

            for _, row in ipairs(rows) do
                local typeName =
                    LOCAL_COLLECTION_TYPE_TO_NAME[tonumber(
                        row.collectionType or row.CollectionType or row.collection_type)]
                local entryId = tonumber(row.entryId or row.EntryID or row.entry_id)

                if typeName and typeName ~= "transmog" and entryId and entryId > 0 then
                    local def = {}
                    if type(row.name) == "string" and row.name ~= "" then
                        def.name = row.name
                    end
                    if type(row.icon) == "string" and row.icon ~= "" then
                        def.icon = row.icon
                    end

                    local rarity = tonumber(row.rarity or row.Rarity)
                    if rarity and rarity > 0 then
                        def.rarity = rarity
                    end

                    local itemId = tonumber(
                        row.itemId or row.itemID or row.ItemID or row.item_id)
                    if itemId and itemId > 0 then
                        def.itemId = itemId
                    end

                    local spellId = tonumber(
                        row.spellId or row.spellID or row.SpellID or row.spell_id)
                    if spellId and spellId > 0 then
                        def.spellId = spellId
                    end

                    local displayId = tonumber(
                        row.previewDisplayId or row.previewDisplayID or
                        row.PreviewDisplayID or row.preview_display_id or
                        row.creatureDisplayId or row.creatureDisplayID or
                        row.CreatureDisplayID or row.creature_display_id or
                        row.displayId or row.displayID or row.DisplayID or
                        row.display_id)
                    if displayId and displayId > 0 then
                        def.displayId = displayId
                        def.previewDisplayId = displayId
                        def.creatureDisplayId = displayId
                    end

                    local creatureId = tonumber(
                        row.previewCreatureId or row.previewCreatureID or
                        row.PreviewCreatureID or row.preview_creature_id or
                        row.creatureId or row.creatureID or row.CreatureID or
                        row.creature_id or row.creatureEntry or row.creature_entry)
                    if creatureId and creatureId > 0 then
                        def.creatureId = creatureId
                        def.previewCreatureId = creatureId
                    end

                    local mountType = tonumber(
                        row.mountType or row.MountType or row.mount_type)
                    if typeName == "mounts" and mountType and mountType >= 0 then
                        def.mountType = mountType
                    end

                    if typeName == "mounts" then
                        local spd = tonumber(row.speed or row.Speed)
                        if spd and spd > 0 then def.speed = spd end
                        local gs = tonumber(row.groundSpeed or row.ground_speed)
                        if gs and gs > 0 then def.groundSpeed = gs end
                        local fs = tonumber(row.flySpeed or row.fly_speed)
                        if fs and fs > 0 then def.flySpeed = fs end
                    end

                    if typeName == "pets" and
                       not (displayId and displayId > 0) and
                       not (creatureId and creatureId > 0) then
                        state.previewIncompleteDefinitionTypes.pets = true
                        state.previewIncompleteDefinitionCounts.pets =
                            (tonumber(state.previewIncompleteDefinitionCounts.pets) or 0) + 1
                    end

                    local source = ResolveLocalSourceValue(row)
                    if source ~= nil then
                        def.source = source
                    end

                    perType[typeName][entryId] = def

                    signatures[typeName] =
                        MixLocalSignature(signatures[typeName], entryId)
                    signatures[typeName] =
                        MixLocalSignature(signatures[typeName], rarity or 0)
                    signatures[typeName] =
                        MixLocalSignature(signatures[typeName], itemId or 0)
                    signatures[typeName] =
                        MixLocalSignature(signatures[typeName], spellId or 0)
                    signatures[typeName] =
                        MixLocalSignature(signatures[typeName], displayId or 0)
                    signatures[typeName] =
                        MixLocalSignature(signatures[typeName], creatureId or 0)
                    signatures[typeName] =
                        MixLocalSignatureString(signatures[typeName], row.name)
                    signatures[typeName] =
                        MixLocalSignatureString(signatures[typeName], row.icon)
                    signatures[typeName] =
                        MixLocalSignatureString(signatures[typeName], row.sourceType)
                    signatures[typeName] =
                        MixLocalSignatureString(signatures[typeName], row.sourceName)
                    signatures[typeName] =
                        MixLocalSignatureString(signatures[typeName], row.sourceText)
                end
            end

            for typeName, defs in pairs(perType) do
                if next(defs) ~= nil then
                    local manifestEntry = nil
                    if type(state.manifest) == "table" and
                       type(state.manifest.types) == "table" then
                        manifestEntry = state.manifest.types[typeName]
                    end

                    self.definitions[typeName] = defs
                    localDefinitionsChanged = true
                    if type(self._BumpDefinitionsRevision) == "function" then
                        self:_BumpDefinitionsRevision(typeName)
                    end
                    if self.stats[typeName] then
                        self.stats[typeName].total = self:CountDefinitions(typeName)
                    end
                    self:SetSyncVersion(typeName, signatures[typeName])
                    state.definitionTypes[typeName] = true
                    if type(manifestEntry) == "table" and
                       manifestEntry.requestSkip == true then
                        state.authoritativeDefinitionTypes[typeName] = true
                    elseif typeName == "pets" and
                        ((type(manifestEntry) == "table" and
                            (tonumber(manifestEntry.missingCount) or 0) <= 1) or
                        (tonumber(state.previewIncompleteDefinitionCounts.pets) or 0) <= 1) then
                        -- Keep pets on local authoritative metadata when only the
                        -- known tiny unresolved tail remains (for example 39148).
                        state.authoritativeDefinitionTypes[typeName] = true
                        state.allowPreviewIncompletePets = true
                    elseif typeName == "titles" then
                        state.authoritativeDefinitionTypes[typeName] = true
                    end
                    state.nativeEligibleDefinitionTypes[typeName] =
                        state.authoritativeDefinitionTypes[typeName] == true
                    state.definitionSources[typeName] = "local-cdbc"
                    state.signatures[typeName] = signatures[typeName]
                end
            end

            state.sourcesLoaded = next(state.definitionTypes) ~= nil
            state.available = state.available or state.sourcesLoaded
        end
    end

    if type(QueryDCCollectionTransmog) == "function"
        and type(GetDCCollectionTransmogCount) == "function" then
        -- Native catalog: keep appearances in the DLL. Do NOT materialise
        -- self.definitions.transmog (the table + alias lookups are the main
        -- memory hog). The wardrobe grid queries the DLL per filter/page.
        local count = 0
        local okc, c = pcall(GetDCCollectionTransmogCount)
        if okc then count = tonumber(c) or 0 end

        if count > 0 then
            self._transmogNativeCatalog = true
            self.definitions.transmog = nil
            self._transmogDefinitions = nil
            self:_InvalidateTransmogDefinitionLookup()
            self._transmogDefinitionsSource = "native-dll"
            self._transmogDefTotal = count

            local signature = 1000000 + count
            self:SetSyncVersion("transmog", signature)

            state.definitionTypes.transmog = true
            state.definitionSources.transmog = "native-dll"
            state.nativeEligibleDefinitionTypes.transmog = true
            state.authoritativeDefinitionTypes.transmog = true
            state.signatures.transmog = signature
            state.available = true
            self.definitionsLoaded = true

            DCCollectionDB = DCCollectionDB or {}
            DCCollectionDB.transmogDefsIncomplete = nil
            DCCollectionDB.transmogDefsResumeOffset = nil
            DCCollectionDB.transmogDefsResumeLimit = nil
            DCCollectionDB.transmogDefsResumeTotal = nil
            DCCollectionDB.transmogDefsResumeUpdatedAt = nil

            if self.Wardrobe then
                self.Wardrobe.definitionsLoaded = true
            end
            if self.stats.transmog then
                self.stats.transmog.total = count
            end
            if type(self._BumpDefinitionsRevision) == "function" then
                self:_BumpDefinitionsRevision("transmog")
            end

            self:_SyncNativeTransmogCollected(true)
        end
    elseif type(GetDCCollectionTransmog) == "function" then
        self._transmogNativeCatalog = false
        local ok, rows = pcall(GetDCCollectionTransmog)
        if ok and type(rows) == "table" and next(rows) ~= nil then
            local defs = {}
            local signature = 5381
            local manifestEntry = nil

            if type(state.manifest) == "table" and
               type(state.manifest.types) == "table" then
                manifestEntry = state.manifest.types.transmog
            end

            for _, row in ipairs(rows) do
                local displayId = tonumber(row.displayId)
                local inventoryType = tonumber(row.inventoryType) or 0
                local itemClass = tonumber(row.class or row.itemClass) or 0
                local itemSubClass = tonumber(row.subclass or row.itemSubClass) or 0
                local itemId = tonumber(row.itemId or row.canonicalItemId) or 0

                if displayId and displayId > 0 and inventoryType > 0 and itemClass > 0 then
                    local key = BuildLocalTransmogVariantKey(
                        displayId,
                        inventoryType,
                        itemClass,
                        itemSubClass)
                    local itemIds = ParseLocalTransmogItemIds(
                        row.itemIds or row.itemIdsCsv)
                    local def = {
                        name = row.name,
                        icon = row.icon,
                        quality = tonumber(row.rarity) or 0,
                        rarity = tonumber(row.rarity) or 0,
                        displayId = displayId,
                        inventoryType = inventoryType,
                        class = itemClass,
                        subclass = itemSubClass,
                        visualSlot = tonumber(row.visualSlot) or nil,
                        itemId = itemId,
                        itemIdsTotal = tonumber(row.itemIdsTotal) or (itemIds and #itemIds) or nil,
                        itemIds = itemIds,
                    }

                    if itemClass == 2 then
                        def.weaponType = itemSubClass
                    elseif itemClass == 4 then
                        def.armorType = itemSubClass
                    end

                    defs[key] = PackTransmogDefinition(def)

                    signature = MixLocalSignature(signature, displayId)
                    signature = MixLocalSignature(signature, inventoryType)
                    signature = MixLocalSignature(signature, itemClass)
                    signature = MixLocalSignature(signature, itemSubClass)
                    signature = MixLocalSignature(signature, itemId)
                    signature = MixLocalSignature(signature, tonumber(row.rarity) or 0)
                    signature = MixLocalSignature(signature, tonumber(row.itemLevel) or 0)
                    signature = MixLocalSignature(signature, tonumber(row.itemIdsTotal) or 0)
                    signature = MixLocalSignatureString(signature, row.name)
                    signature = MixLocalSignatureString(signature, row.icon)
                    signature = MixLocalSignatureString(signature, row.itemIds or row.itemIdsCsv)
                end
            end

            if next(defs) ~= nil then
                self.definitions.transmog = defs
                self._transmogDefinitions = defs
                self._transmogDefinitionsSource = "local-cdbc"
                self._transmogDefTotal = self:CountDefinitions("transmog")
                self:SetSyncVersion("transmog", signature)
                state.definitionTypes.transmog = true
                state.definitionSources.transmog = "local-cdbc"
                state.nativeEligibleDefinitionTypes.transmog =
                    type(manifestEntry) == "table" and
                    manifestEntry.requestSkip == true
                if type(manifestEntry) == "table" and manifestEntry.requestSkip == true then
                    state.authoritativeDefinitionTypes.transmog = true
                end
                state.signatures.transmog = signature
                state.available = true
                self.definitionsLoaded = true

                if state.authoritativeDefinitionTypes.transmog == true then
                    DCCollectionDB = DCCollectionDB or {}
                    DCCollectionDB.transmogDefsIncomplete = nil
                    DCCollectionDB.transmogDefsResumeOffset = nil
                    DCCollectionDB.transmogDefsResumeLimit = nil
                    DCCollectionDB.transmogDefsResumeTotal = nil
                    DCCollectionDB.transmogDefsResumeUpdatedAt = nil
                end

                if self.Wardrobe then
                    self.Wardrobe.definitionsLoaded = true
                end

                if self.stats.transmog then
                    self.stats.transmog.total = self._transmogDefTotal
                end

                if type(self._InvalidateTransmogDefinitionLookup) == "function" then
                    self:_InvalidateTransmogDefinitionLookup()
                end
                if type(self._BumpDefinitionsRevision) == "function" then
                    self:_BumpDefinitionsRevision("transmog")
                end
            end
        end
    end

    if type(GetDCCollectionSets) == "function" then
        local ok, rows = pcall(GetDCCollectionSets)
        if ok and type(rows) == "table" and next(rows) ~= nil then
            local sets = {}
            local signature = 5381

            for _, row in ipairs(rows) do
                local setId = tonumber(row.id)
                if setId and setId > 0 then
                    local items = {}
                    if type(row.items) == "table" then
                        for _, itemId in ipairs(row.items) do
                            itemId = tonumber(itemId)
                            if itemId and itemId > 0 then
                                items[#items + 1] = itemId
                                signature = MixLocalSignature(signature, itemId)
                            end
                        end
                    end

                    sets[setId] = {
                        ID = setId,
                        name = row.name or ("Set " .. tostring(setId)),
                        icon = row.icon,
                        items = items,
                        categoryId = tonumber(row.categoryId) or nil,
                        sortOrder = tonumber(row.sortOrder) or 0,
                        flags = tonumber(row.flags) or 0,
                        pieceCount = tonumber(row.pieceCount) or #items,
                    }

                    signature = MixLocalSignature(signature, setId)
                    signature = MixLocalSignatureString(signature, row.name)
                    signature = MixLocalSignatureString(signature, row.icon)
                end
            end

            if next(sets) ~= nil then
                local existingItemSetSyncVersion =
                    type(self.GetSyncVersion) == "function" and
                    tonumber(self:GetSyncVersion("itemsets")) or 0

                self.definitions.itemsets = sets
                self.definitions.itemSets = sets
                self.definitions.sets = sets
                if existingItemSetSyncVersion == 0 then
                    self:SetSyncVersion("itemsets", signature)
                end
                state.setsLoaded = true
                state.nativeEligibleItemSets = true
                state.authoritativeItemSets = false
                state.itemSetsSource = "local-cdbc"
                state.signatures.itemsets = signature
                state.available = true

                if type(self._BumpDefinitionsRevision) == "function" then
                    self:_BumpDefinitionsRevision("itemsets")
                end
            end
        end
    end

    local shopRows = nil
    local shopMetadataSource = nil

    if type(GetDCCollectionShop) == "function" then
        local ok, rows = pcall(GetDCCollectionShop)
        if ok and type(rows) == "table" and next(rows) ~= nil then
            shopRows = rows
            shopMetadataSource = "native"
        end
    end

    if not shopRows and type(self.SHOP_STATIC_DATA) == "table" and
       next(self.SHOP_STATIC_DATA) ~= nil then
        shopRows = self.SHOP_STATIC_DATA
        shopMetadataSource = "lua"
    end

    if type(shopRows) == "table" and next(shopRows) ~= nil then
        local byShopId = {}
        local byTypeEntry = {}
        local signature = 5381
        local loaded = 0
        local manifestShop = nil

        if type(state.manifest) == "table" and type(state.manifest.shop) == "table" then
            manifestShop = state.manifest.shop
        end

        for _, row in ipairs(shopRows) do
            local shopId = tonumber(row.shopId)
            local collectionType = tonumber(row.collectionType)
            local entryId = tonumber(row.entryId)
            local typeName = NormalizeType(
                self,
                row.collectionTypeName or collectionType)

            if shopId and shopId > 0 and typeName and entryId and entryId > 0 then
                local metadata = {
                    shopId = shopId,
                    collectionType = collectionType or 0,
                    collectionTypeName = typeName,
                    entryId = entryId,
                    itemId = tonumber(row.itemId) or 0,
                    spellId = tonumber(row.spellId) or 0,
                    appearanceId = tonumber(row.appearanceId) or 0,
                    displayId = tonumber(row.displayId) or 0,
                    creatureId = tonumber(row.creatureId) or 0,
                    mountType = tonumber(row.mountType) or -1,
                    rarity = tonumber(row.rarity) or 0,
                    priceTokens = tonumber(row.priceTokens) or 0,
                    priceEmblems = tonumber(row.priceEmblems) or 0,
                    discount = tonumber(row.discount) or 0,
                    featured = tonumber(row.featured) == 1,
                    enabled = tonumber(row.enabled or 1) ~= 0,
                    stock = tonumber(row.stock) or -1,
                    availableFrom = row.availableFrom,
                    availableUntil = row.availableUntil,
                    name = row.name,
                    icon = row.icon,
                    sourceType = row.sourceType,
                    sourceName = row.sourceName,
                    sourceText = row.sourceText,
                }

                byShopId[shopId] = metadata
                byTypeEntry[typeName] = byTypeEntry[typeName] or {}
                if not byTypeEntry[typeName][entryId] then
                    byTypeEntry[typeName][entryId] = metadata
                end

                loaded = loaded + 1
                signature = MixLocalSignature(signature, shopId)
                signature = MixLocalSignature(signature, collectionType or 0)
                signature = MixLocalSignature(signature, entryId)
                signature = MixLocalSignature(signature, metadata.priceTokens)
                signature = MixLocalSignature(signature, metadata.priceEmblems)
                signature = MixLocalSignature(signature, metadata.discount)
                signature = MixLocalSignature(signature, metadata.featured and 1 or 0)
                signature = MixLocalSignatureString(signature, metadata.name)
                signature = MixLocalSignatureString(signature, metadata.icon)
            end
        end

        if loaded > 0 then
            state.shopMetadataById = byShopId
            state.shopMetadataByTypeEntry = byTypeEntry
            state.nativeEligibleShopMetadata =
                type(manifestShop) == "table" and
                manifestShop.authoritative == true
            state.shopMetadataAuthoritative =
                state.nativeEligibleShopMetadata == true
            state.shopMetadataSource = shopMetadataSource
            state.signatures.shop = signature
            state.available = true

            self.localShopMetadataById = byShopId
            self.localShopMetadataByTypeEntry = byTypeEntry
        end
    end

    self._localCollectionCDBC = state
    self._localCollectionCDBCBootstrapped = true

    if state.sourcesLoaded or state.setsLoaded or state.shopMetadataAuthoritative then
        self.isDataReady = true
        self.cacheNeedsSave = true
        self:Debug(string.format(
            "Bootstrapped local collection CDBC data (sources=%s, sets=%s, shop=%s, shopSource=%s, manifest=%s)",
            tostring(state.sourcesLoaded),
            tostring(state.setsLoaded),
            tostring(state.shopMetadataAuthoritative),
            tostring(state.shopMetadataSource),
            tostring(type(state.manifest) == "table")))
    end

    return state
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
        if type(self._InvalidateTransmogDefinitionLookup) == "function" then
            self:_InvalidateTransmogDefinitionLookup()
        end
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
        self._transmogDefinitionsSource = "runtime"
    end

    local state = self._localCollectionCDBC
    if type(state) == "table" and type(state.definitionSources) == "table" then
        state.definitionSources[typeName] = "runtime"
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

    if typeName == "transmog" and type(self._InvalidateTransmogDefinitionLookup) == "function" then
        self:_InvalidateTransmogDefinitionLookup()
    end

    if added > 0 then
        self:_BumpDefinitionsRevision(typeName)
    end
    
    if self.stats[typeName] then
        local currentTotal = tonumber(self.stats[typeName].total) or 0
        if currentTotal <= 0 then
            self.stats[typeName].total = self:CountDefinitions(typeName)
        end
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

        if typeName == "transmog" and self:HasNativeTransmogCatalog() then
            return tonumber(self._transmogDefTotal) or 0
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

    if typeName == "transmog" and self:HasNativeTransmogCatalog() then
        -- Resolve from the DLL by itemId first, then displayId.
        local row
        if type(GetDCCollectionTransmogByItemId) == "function" then
            local ok, r = pcall(GetDCCollectionTransmogByItemId, normalizedId)
            if ok and type(r) == "table" then row = r end
        end
        if not row and type(GetDCCollectionTransmogByDisplayId) == "function" then
            local ok, r = pcall(GetDCCollectionTransmogByDisplayId, normalizedId)
            if ok and type(r) == "table" then row = r end
        end
        return self:_NativeTransmogRowToDef(row)
    end

    if self.definitions[typeName] then
        local v = self.definitions[typeName][normalizedId]
        if not v and typeName == "transmog" and type(self._EnsureTransmogDefinitionAliasLookup) == "function" then
            local lookup = self:_EnsureTransmogDefinitionAliasLookup()
            if type(lookup) == "table" then
                local alias = lookup.byDisplayId and lookup.byDisplayId[normalizedId]
                if not alias and lookup.byItemId then
                    alias = lookup.byItemId[normalizedId]
                end
                if type(alias) == "table" then
                    v = alias.raw
                end
            end
        end
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
    ["mounts"] = 1,
    ["mount"] = 1,
    ["pets"] = 2,
    ["pet"] = 2,
    ["toys"] = 3,
    ["toy"] = 3,
    ["bonus"] = 3,
    ["heirlooms"] = 4,
    ["heirloom"] = 4,
    ["titles"] = 5,
    ["title"] = 5,
    ["transmog"] = 6,
    ["appearances"] = 6,
    ["item_sets"] = 7,
    ["item_set"] = 7,
}

-- Reverse lookup for ID to name
local TYPE_ID_TO_NAME = {
    [DC.CollectionType.MOUNT] = "mounts",
    [1] = "mounts",
    [DC.CollectionType.PET] = "pets",
    [2] = "pets",
    [3] = "bonus",
    [DC.CollectionType.HEIRLOOM] = "heirlooms",
    [4] = "heirlooms",
    [DC.CollectionType.TITLE] = "titles",
    [5] = "titles",
    [DC.CollectionType.TRANSMOG] = "transmog",
    [6] = "transmog",
    [7] = "item_sets",
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

function DC:NormalizeWishlistItems(items)
    local normalized = {}
    if type(items) ~= "table" then
        return normalized
    end

    for _, wish in ipairs(items) do
        if type(wish) == "table" then
            local normalizedWish = {}
            for key, value in pairs(wish) do
                normalizedWish[key] = value
            end

            local rawType = normalizedWish.typeId or normalizedWish.type_id or
                normalizedWish.type or normalizedWish.collection_type
            local typeId = tonumber(rawType)
            if not typeId and type(rawType) == "string" then
                typeId = self:GetTypeIdFromName(rawType)
            end

            local typeName = nil
            if typeId then
                typeName = self:GetTypeNameFromId(typeId)
            elseif type(rawType) == "string" then
                typeName = string.lower(rawType)
            end

            local entryId = tonumber(normalizedWish.entryId or normalizedWish.entry_id or
                normalizedWish.itemId or normalizedWish.item_id or normalizedWish.entry or
                normalizedWish.id)

            if typeName and entryId and entryId > 0 then
                normalizedWish.type = typeName
                normalizedWish.collection_type = typeName
                normalizedWish.typeId = typeId
                normalizedWish.type_id = typeId
                normalizedWish.entryId = entryId
                normalizedWish.entry_id = entryId
                normalizedWish.itemId = entryId
                normalizedWish.item_id = entryId
                normalized[#normalized + 1] = normalizedWish
            end
        end
    end

    return normalized
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
    if type(self.ScheduleCacheAutoSave) == "function" then
        self:ScheduleCacheAutoSave()
    end
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
        if type(self.ScheduleCacheAutoSave) == "function" then
            self:ScheduleCacheAutoSave()
        end
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
        if type(self.ScheduleCacheAutoSave) == "function" then
            self:ScheduleCacheAutoSave()
        end
        return true  -- Item was removed
    end
    
    return false  -- Item didn't exist
end

-- ============================================================================
-- HASH COMPUTATION
-- Matches server-side GenerateCollectionHash in dc_addon_collection.cpp
-- ============================================================================

local HANDSHAKE_HASHED_COLLECTION_TYPES = {
    mounts = true,
    pets = true,
    heirlooms = true,
}

local HANDSHAKE_HASH_ORDER = {
    "mounts",
    "pets",
    "heirlooms",
}

function DC:GetHandshakeCollectionSnapshot()
    local buckets = {}
    local counts = {}

    for _, typeName in ipairs(HANDSHAKE_HASH_ORDER) do
        buckets[typeName] = {}
        counts[typeName] = 0
    end

    for collectionType, items in pairs(self.collections) do
        local normalizedType = collectionType
        if type(self.NormalizeCollectionType) == "function" then
            normalizedType = self:NormalizeCollectionType(collectionType) or collectionType
        end

        if HANDSHAKE_HASHED_COLLECTION_TYPES[normalizedType] and
           type(items) == "table" then
            local bucket = buckets[normalizedType]
            for itemId in pairs(items) do
                itemId = tonumber(itemId)
                if itemId and itemId > 0 and not bucket[itemId] then
                    bucket[itemId] = true
                    counts[normalizedType] = counts[normalizedType] + 1
                end
            end
        end
    end

    local sortedIds = {}
    for _, typeName in ipairs(HANDSHAKE_HASH_ORDER) do
        local bucket = buckets[typeName]
        for itemId in pairs(bucket) do
            table.insert(sortedIds, itemId)
        end
    end

    table.sort(sortedIds)

    return {
        sortedIds = sortedIds,
        counts = counts,
    }
end

-- Compute hash of all collected item IDs for delta sync
function DC:ComputeCollectionHash()
    local snapshot = self:GetHandshakeCollectionSnapshot()
    local sortedIds = snapshot and snapshot.sortedIds or {}

    local hash = 0

    for _, itemId in ipairs(sortedIds) do
        hash = bit.bxor(hash, bit.band(itemId * 2654435761, 0xFFFFFFFF))
        hash = bit.bor(bit.lshift(hash, 13), bit.rshift(hash, 19))
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

function DC:ScheduleCacheAutoSave()
    ScheduleAutoSave()
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
    if type(self.RehydrateRecentAdditions) == "function" then
        self:RehydrateRecentAdditions()
    end
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
