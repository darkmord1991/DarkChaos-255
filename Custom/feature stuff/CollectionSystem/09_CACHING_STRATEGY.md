# Collection System Caching Strategy

**Purpose:** Define efficient caching patterns for collection data  
**Key Insight:** Collections are additive-only (items are never removed from a character)

---

## Why Caching Matters

Collection data has unique characteristics that make it ideal for aggressive caching:

| Characteristic | Implication |
|----------------|-------------|
| **Additive-only** | Items are learned, never unlearned |
| **Infrequent changes** | New items added rarely (days/weeks between) |
| **Large static data** | Definition tables change only on patches |
| **Frequent reads** | UI opens often, needs instant display |
| **Account-wide** | Same data across all characters |

---

## Cache Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLIENT-SIDE CACHES                            │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1: SavedVariables (Persistent)                           │
│  ├── Definition Cache (mounts, pets, toys, etc.)                │
│  ├── Collection Cache (owned items)                             │
│  ├── Statistics Cache                                           │
│  └── TTL: Until server sends invalidation                       │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: Session Memory (Volatile)                             │
│  ├── Search Results                                             │
│  ├── Filtered Views                                             │
│  ├── UI State                                                   │
│  └── TTL: Until logout                                          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    SERVER-SIDE CACHES                            │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1: Definition Cache (Global)                             │
│  ├── Loaded at server startup                                   │
│  ├── All mount/pet/toy definitions                              │
│  └── TTL: Until server restart                                  │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: Account Collection Cache (Per-Account)                │
│  ├── Loaded on first character login                            │
│  ├── Updated on item acquisition                                │
│  └── TTL: 5 minutes after last character logout                 │
├─────────────────────────────────────────────────────────────────┤
│  Layer 3: Leaderboard Cache (Global)                            │
│  ├── Recalculated every 10 minutes                              │
│  ├── Stored in dc_collection_leaderboard                        │
│  └── TTL: 10 minutes                                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Client-Side Caching (SavedVariables)

### Data Structure

```lua
-- DCCollectionsDB structure (saved to disk)
DCCollectionsDB = {
    -- Cache version for invalidation
    cacheVersion = 1,
    
    -- Definition cache (large, infrequent updates)
    definitions = {
        mounts = {
            version = 20251221,  -- Server definition version
            data = {
                [32458] = {
                    name = "Ashes of Al'ar",
                    type = 1,  -- flying
                    source = '{"type":"drop","location":"Tempest Keep"}',
                    rarity = 4,
                    icon = "Interface\\Icons\\INV_Misc_...",
                    -- ... more fields
                },
                -- ... all mounts
            }
        },
        pets = { version = 20251221, data = {} },
        toys = { version = 20251221, data = {} },
    },
    
    -- Collection cache (player's owned items)
    collections = {
        lastSync = 1703164800,  -- Unix timestamp
        mounts = {
            count = 127,
            items = {
                [32458] = { obtained = 1703000000, favorite = true, uses = 15 },
                [41252] = { obtained = 1702500000, favorite = false, uses = 3 },
                -- ... owned mounts
            }
        },
        pets = { count = 89, items = {} },
        toys = { count = 45, items = {} },
        transmog = { count = 312 },  -- Just count, actual data in transmog addon
        titles = { count = 23, items = {} },
    },
    
    -- Statistics cache
    statistics = {
        lastUpdate = 1703164800,
        totalCollected = 596,
        totalAvailable = 1500,
        percentComplete = 39.7,
        perType = {
            mount = { collected = 127, total = 175, percent = 72.6 },
            pet = { collected = 89, total = 156, percent = 57.1 },
            -- ...
        },
        rank = 42,  -- Server rank
    },
    
    -- Wishlist (always synced)
    wishlist = {
        items = {},
        lastSync = 1703164800,
    },
    
    -- UI preferences (not synced)
    settings = {
        defaultTab = "mount",
        gridColumns = 8,
        showUncollected = true,
        sortBy = "name",
        -- ...
    },
}
```

### Cache Invalidation

Since items are **never removed**, we use a simple additive sync:

```lua
-- On login, server sends only CHANGES since lastSync
function DCCollections:OnLoginSync(data)
    local lastSync = DCCollectionsDB.collections.lastSync or 0
    
    -- Server sends: { newItems = [...], updatedStats = {...}, timestamp = X }
    if data.newItems then
        for _, item in ipairs(data.newItems) do
            self:AddToLocalCache(item.type, item.id, item.data)
        end
    end
    
    if data.updatedStats then
        DCCollectionsDB.statistics = data.updatedStats
    end
    
    DCCollectionsDB.collections.lastSync = data.timestamp
end
```

### Version-Based Definition Sync

```lua
-- Only request definitions if server version is newer
function DCCollections:CheckDefinitionVersion()
    local localVersion = DCCollectionsDB.definitions.mounts.version or 0
    
    -- Request version check from server
    DC.Module.COLL:Request("VERSION_CHECK", { 
        mount = localVersion,
        pet = DCCollectionsDB.definitions.pets.version or 0,
        toy = DCCollectionsDB.definitions.toys.version or 0,
    })
end

-- Server responds with only types that need update
function DCCollections:OnVersionCheckResponse(data)
    for collType, serverVersion in pairs(data.versions) do
        local localVersion = DCCollectionsDB.definitions[collType].version or 0
        if serverVersion > localVersion then
            -- Request full definition update for this type
            DC.Module.COLL:Request("GET_DEFINITIONS", { type = collType })
        end
    end
end
```

---

## Server-Side Caching

### Definition Cache (Eluna)

```lua
-- Global definition cache (loaded once at startup)
local DefinitionCache = {
    mounts = {},
    pets = {},
    toys = {},
    version = {
        mount = 0,
        pet = 0,
        toy = 0,
    }
}

local function LoadDefinitionCache()
    -- Load mounts
    local query = CharDBQuery("SELECT spell_id, name, mount_type, source, faction, rarity, icon FROM dc_mount_definitions")
    if query then
        repeat
            local spellId = query:GetUInt32(0)
            DefinitionCache.mounts[spellId] = {
                name = query:GetString(1),
                type = query:GetUInt8(2),
                source = query:GetString(3),
                faction = query:GetUInt8(4),
                rarity = query:GetUInt8(5),
                icon = query:GetString(6),
            }
        until not query:NextRow()
    end
    
    -- Get version from metadata table
    local vQuery = CharDBQuery("SELECT collection_type, version FROM dc_definition_versions")
    if vQuery then
        repeat
            DefinitionCache.version[vQuery:GetString(0)] = vQuery:GetUInt32(1)
        until not vQuery:NextRow()
    end
    
    print("[Collections] Loaded " .. #DefinitionCache.mounts .. " mount definitions")
end

-- Call on server startup
LoadDefinitionCache()
```

### Account Collection Cache (Per-Player)

```lua
-- Per-account cache (loaded on login)
local AccountCollectionCache = {}

local function LoadAccountCollection(accountId)
    if AccountCollectionCache[accountId] then
        return AccountCollectionCache[accountId]  -- Already cached
    end
    
    local cache = {
        mounts = {},
        pets = {},
        toys = {},
        loadedAt = os.time(),
    }
    
    -- Load mounts
    local query = CharDBQuery(string.format(
        "SELECT spell_id, obtained_date, is_favorite, times_used FROM dc_mount_collection WHERE account_id = %d",
        accountId
    ))
    if query then
        repeat
            cache.mounts[query:GetUInt32(0)] = {
                obtained = query:GetUInt32(1),
                favorite = query:GetBool(2),
                uses = query:GetUInt32(3),
            }
        until not query:NextRow()
    end
    
    -- ... similar for pets, toys
    
    AccountCollectionCache[accountId] = cache
    return cache
end

-- Invalidate on logout (with delay)
local function OnPlayerLogout(event, player)
    local accountId = player:GetAccountId()
    
    -- Check if any other character from this account is online
    local anyOnline = false
    for _, p in ipairs(GetPlayersInWorld()) do
        if p:GetAccountId() == accountId and p:GetGUID() ~= player:GetGUID() then
            anyOnline = true
            break
        end
    end
    
    if not anyOnline then
        -- Schedule cache cleanup in 5 minutes
        CreateLuaEvent(function()
            AccountCollectionCache[accountId] = nil
        end, 300000, 1)  -- 5 minutes, once
    end
end
```

### Additive Cache Update

When a player learns a new mount:

```lua
local function OnLearnMount(event, player, spellId)
    local accountId = player:GetAccountId()
    local cache = AccountCollectionCache[accountId]
    
    if cache and not cache.mounts[spellId] then
        -- Add to cache (no DB query needed for read)
        cache.mounts[spellId] = {
            obtained = os.time(),
            favorite = false,
            uses = 0,
        }
        
        -- Insert to DB async
        CharDBExecute(string.format(
            "INSERT IGNORE INTO dc_mount_collection (account_id, spell_id, obtained_by) VALUES (%d, %d, %d)",
            accountId, spellId, player:GetGUID()
        ))
        
        -- Notify client to update local cache
        DC.Module.COLL:Send(player, "NEW_ITEM", {
            type = "mount",
            id = spellId,
            data = cache.mounts[spellId]
        })
    end
end
```

---

## Sync Protocol

### Initial Login Sync

```
Client                          Server
   |                               |
   |--- LOGIN_SYNC --------------->|  lastSync=1703000000
   |                               |
   |                               |  Query: items WHERE obtained_date > lastSync
   |                               |
   |<-- SYNC_RESPONSE -------------|  newItems=[...], newTimestamp=1703164800
   |                               |
   |  Update local cache           |
   |  Update lastSync              |
   |                               |
```

### Delta Sync (Efficient)

Since items are never removed, we only sync additions:

```lua
-- Server-side: Get items added since timestamp
function GetCollectionDelta(accountId, lastSync)
    local delta = { mounts = {}, pets = {}, toys = {} }
    
    local query = CharDBQuery(string.format([[
        SELECT 'mount' as type, spell_id as id, obtained_date, is_favorite, times_used
        FROM dc_mount_collection 
        WHERE account_id = %d AND obtained_date > FROM_UNIXTIME(%d)
        UNION ALL
        SELECT 'pet', pet_entry, obtained_date, is_favorite, times_summoned
        FROM dc_pet_collection
        WHERE account_id = %d AND obtained_date > FROM_UNIXTIME(%d)
        UNION ALL
        SELECT 'toy', item_id, obtained_date, is_favorite, times_used
        FROM dc_toy_collection
        WHERE account_id = %d AND obtained_date > FROM_UNIXTIME(%d)
    ]], accountId, lastSync, accountId, lastSync, accountId, lastSync))
    
    if query then
        repeat
            local collType = query:GetString(0)
            delta[collType .. "s"][query:GetUInt32(1)] = {
                obtained = query:GetUInt32(2),
                favorite = query:GetBool(3),
                uses = query:GetUInt32(4),
            }
        until not query:NextRow()
    end
    
    return delta
end
```

---

## Cache Size Estimates

| Data Type | Items | Size per Item | Total Size |
|-----------|-------|---------------|------------|
| Mount Definitions | ~175 | ~200 bytes | ~35 KB |
| Pet Definitions | ~156 | ~200 bytes | ~31 KB |
| Toy Definitions | ~120 | ~150 bytes | ~18 KB |
| Player Mounts | ~100 avg | ~50 bytes | ~5 KB |
| Player Pets | ~80 avg | ~50 bytes | ~4 KB |
| Player Toys | ~50 avg | ~50 bytes | ~2.5 KB |
| Statistics | 1 | ~500 bytes | ~0.5 KB |
| Wishlist | ~20 avg | ~100 bytes | ~2 KB |
| **Total SavedVariables** | | | **~98 KB** |

This is well within acceptable limits for WoW SavedVariables (~1-2 MB is common).

---

## Benefits of Additive-Only Cache

1. **No Invalidation Complexity**
   - Never need to remove items from cache
   - No "stale cache" problems
   - No race conditions on removal

2. **Efficient Sync**
   - Only sync items newer than `lastSync`
   - Minimal bandwidth usage
   - Fast login experience

3. **Offline-Capable UI**
   - Collection UI works instantly from cache
   - No loading spinner on open
   - Server sync happens in background

4. **Resilient to Disconnects**
   - Cache survives disconnects
   - Next login just syncs delta
   - No data loss

---

## Cache Warming on Login

```lua
-- Sequence on player login
function DCCollections:OnPlayerLogin()
    -- 1. Load from SavedVariables (instant)
    self:LoadLocalCache()
    
    -- 2. Display UI immediately if opened
    -- (shows cached data)
    
    -- 3. Request delta sync in background
    C_Timer.After(1, function()
        DC.Module.COLL:Request("SYNC", {
            lastSync = DCCollectionsDB.collections.lastSync or 0,
            defVersions = {
                mount = DCCollectionsDB.definitions.mounts.version or 0,
                pet = DCCollectionsDB.definitions.pets.version or 0,
                toy = DCCollectionsDB.definitions.toys.version or 0,
            }
        })
    end)
    
    -- 4. On response, merge into cache
    -- 5. Refresh UI if open
end
```

---

## Summary

| Strategy | Why It Works |
|----------|--------------|
| **Additive-only** | Items never removed → no invalidation needed |
| **Delta sync** | Only sync new items since last timestamp |
| **Version-based definitions** | Skip full sync if definitions unchanged |
| **Persistent cache** | SavedVariables survive logout/login |
| **Background sync** | UI loads instantly from cache |
| **Per-account server cache** | Reduce DB queries across alt logins |

This caching strategy ensures:
- ⚡ **Instant UI response** - No loading delays
- 📉 **Minimal bandwidth** - Only sync changes
- 💾 **Low DB load** - Cache serves most reads
- 🔄 **Always consistent** - Additive-only = no stale data

