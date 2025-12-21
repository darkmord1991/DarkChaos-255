# Collection System - Protocol Integration

**Component:** DCAddonProtocol Extension  
**Purpose:** Unified messaging for collection system

---

## Overview

This document specifies the DCAddonProtocol extensions needed for the collection system. The design follows the existing DC addon patterns (AOE Loot, Item Upgrade, Mythic+, etc.) and uses JSON as the standard message format.

---

## Protocol Addition to DCAddonProtocol.lua

Add the following to the existing `DCAddonProtocol.lua` file:

```lua
-- ============================================================================
-- Collection System Module (Add to DCAddonProtocol.lua)
-- ============================================================================

-- Add to DC.ModuleNames table:
DC.ModuleNames.COLL = "Collections"

-- Add to DC.Module table:
DC.Module.COLLECTION = "COLL"

-- Collection Opcodes
DC.Opcode.Collection = {
    -- Client -> Server: Core Collection
    CMSG_GET_COLLECTION       = 0x01,  -- Get collection data for a type
    CMSG_GET_COUNT            = 0x02,  -- Get collection counts
    CMSG_SET_FAVORITE         = 0x03,  -- Toggle favorite status
    CMSG_USE_COLLECTABLE      = 0x04,  -- Use/summon a collectable
    CMSG_GET_STATISTICS       = 0x05,  -- Get detailed statistics
    CMSG_SEARCH               = 0x06,  -- Search/filter collection
    
    -- Client -> Server: Mount-specific (0x10-0x1F)
    CMSG_SUMMON_MOUNT         = 0x10,  -- Summon specific mount
    CMSG_SUMMON_RANDOM_MOUNT  = 0x11,  -- Summon random (favorite) mount
    CMSG_SET_MOUNT_FAVORITE   = 0x12,  -- Set mount as favorite
    
    -- Client -> Server: Pet-specific (0x20-0x2F)
    CMSG_SUMMON_PET           = 0x20,  -- Summon specific pet
    CMSG_SUMMON_RANDOM_PET    = 0x21,  -- Summon random (favorite) pet
    CMSG_RENAME_PET           = 0x22,  -- Rename a pet
    CMSG_SET_PET_FAVORITE     = 0x23,  -- Set pet as favorite
    
    -- Client -> Server: Transmog-specific (0x30-0x3F)
    CMSG_SYNC_TRANSMOG        = 0x30,  -- Request transmog sync
    CMSG_GET_TRANSMOG_SLOT    = 0x31,  -- Get appearances for slot
    
    -- Client -> Server: Toy-specific (0x40-0x4F)
    CMSG_USE_TOY              = 0x40,  -- Use a toy
    CMSG_SET_TOY_FAVORITE     = 0x41,  -- Set toy as favorite
    
    -- Server -> Client: Responses (0x50+)
    SMSG_COLLECTION_DATA      = 0x50,  -- Collection data response
    SMSG_COLLECTION_COUNT     = 0x51,  -- Count response
    SMSG_FAVORITE_UPDATED     = 0x52,  -- Favorite toggle confirmation
    SMSG_ITEM_USED            = 0x53,  -- Use confirmation
    SMSG_STATISTICS           = 0x54,  -- Statistics data
    SMSG_SEARCH_RESULTS       = 0x55,  -- Search results
    
    -- Server -> Client: Notifications
    SMSG_ITEM_LEARNED         = 0x60,  -- New item added to collection
    SMSG_ACHIEVEMENT_EARNED   = 0x61,  -- Collection achievement earned
    
    -- Server -> Client: Errors
    SMSG_ERROR                = 0x5F,  -- Error response
}

-- ============================================================================
-- Collection API Wrapper
-- ============================================================================

DC.Collection = {
    -- Core collection operations
    GetCollection = function(collectionType, page, limit)
        DC:Request("COLL", 0x01, {
            type = collectionType or "mount",
            page = page or 1,
            limit = limit or 50,
        })
    end,
    
    GetCount = function(collectionType)
        DC:Request("COLL", 0x02, { type = collectionType or "all" })
    end,
    
    SetFavorite = function(collectionType, entryId, favorite)
        DC:Request("COLL", 0x03, {
            type = collectionType,
            entryId = entryId,
            favorite = favorite,
        })
    end,
    
    Use = function(collectionType, entryId)
        DC:Request("COLL", 0x04, {
            type = collectionType,
            entryId = entryId,
        })
    end,
    
    GetStatistics = function()
        DC:Request("COLL", 0x05, {})
    end,
    
    Search = function(collectionType, query, filters)
        filters = filters or {}
        DC:Request("COLL", 0x06, {
            type = collectionType,
            query = query or "",
            rarity = filters.rarity,
            source = filters.source,
            collected = filters.collected,
            page = filters.page or 1,
            limit = filters.limit or 50,
        })
    end,
    
    -- Mount-specific
    Mount = {
        Summon = function(spellId)
            DC:Request("COLL", 0x10, { spellId = spellId })
        end,
        
        SummonRandom = function(favoritesOnly, preferFlying)
            DC:Request("COLL", 0x11, {
                favoritesOnly = favoritesOnly or false,
                preferFlying = preferFlying,
            })
        end,
        
        SetFavorite = function(spellId, favorite)
            DC:Request("COLL", 0x12, {
                spellId = spellId,
                favorite = favorite,
            })
        end,
    },
    
    -- Pet-specific
    Pet = {
        Summon = function(petEntry)
            DC:Request("COLL", 0x20, { petEntry = petEntry })
        end,
        
        SummonRandom = function(favoritesOnly)
            DC:Request("COLL", 0x21, { favoritesOnly = favoritesOnly or false })
        end,
        
        Rename = function(petEntry, newName)
            DC:Request("COLL", 0x22, {
                petEntry = petEntry,
                name = newName,
            })
        end,
        
        SetFavorite = function(petEntry, favorite)
            DC:Request("COLL", 0x23, {
                petEntry = petEntry,
                favorite = favorite,
            })
        end,
    },
    
    -- Transmog-specific
    Transmog = {
        Sync = function()
            DC:Request("COLL", 0x30, {})
        end,
        
        GetSlot = function(slot, page)
            DC:Request("COLL", 0x31, {
                slot = slot,
                page = page or 1,
            })
        end,
    },
    
    -- Toy-specific
    Toy = {
        Use = function(itemId)
            DC:Request("COLL", 0x40, { itemId = itemId })
        end,
        
        SetFavorite = function(itemId, favorite)
            DC:Request("COLL", 0x41, {
                itemId = itemId,
                favorite = favorite,
            })
        end,
    },
}
```

---

## Message Format Examples

### Request: Get Mount Collection

```
Client -> Server:
Prefix: DC
Message: COLL|1|J|{"type":"mount","page":1,"limit":50}
```

### Response: Collection Data

```json
{
    "type": "mount",
    "items": [
        {
            "entryId": 458,
            "spellId": 458,
            "name": "Brown Horse",
            "icon": "Interface\\Icons\\Ability_Mount_RidingHorse",
            "rarity": 0,
            "mountType": 0,
            "source": {"type": "vendor", "npc": "Katie Hunter"},
            "collected": true,
            "isFavorite": false,
            "obtainedDate": 1703145600
        },
        {
            "entryId": 32458,
            "spellId": 32458,
            "name": "Ashes of Al'ar",
            "icon": "Interface\\Icons\\INV_Misc_Summoning_TotemFire",
            "rarity": 4,
            "mountType": 1,
            "source": {"type": "drop", "boss": "Kael'thas"},
            "collected": false,
            "isFavorite": false
        }
    ],
    "collected": 45,
    "total": 284,
    "page": 1,
    "pages": 6
}
```

### Request: Summon Random Mount

```
Client -> Server:
COLL|17|J|{"favoritesOnly":true,"preferFlying":true}
```

### Response: Mount Summoned

```json
{
    "success": true,
    "spellId": 32458,
    "name": "Ashes of Al'ar"
}
```

### Server Push: New Item Learned

```json
{
    "type": "mount",
    "entryId": 63963,
    "spellId": 63963,
    "name": "Rusted Proto-Drake",
    "icon": "Interface\\Icons\\Ability_Mount_Drake_Proto",
    "rarity": 3,
    "source": {"type": "achievement"}
}
```

---

## Server-Side Handler Template

```cpp
// CollectionAddonHandler.cpp

void HandleCOLLMessage(Player* player, uint8 opcode, const nlohmann::json& data)
{
    switch (opcode)
    {
        case 0x01: // CMSG_GET_COLLECTION
        {
            std::string type = data.value("type", "mount");
            uint32 page = data.value("page", 1);
            uint32 limit = data.value("limit", 50);
            
            CollectionType colType = ParseType(type);
            auto module = sCollectionMgr->GetModule(colType);
            
            if (!module)
            {
                SendError(player, "Invalid collection type");
                return;
            }
            
            uint32 accountId = player->GetSession()->GetAccountId();
            auto items = module->GetCollection(accountId);
            
            // Paginate
            uint32 start = (page - 1) * limit;
            uint32 end = std::min(start + limit, (uint32)items.size());
            
            nlohmann::json response;
            response["type"] = type;
            response["items"] = nlohmann::json::array();
            
            for (uint32 i = start; i < end; ++i)
            {
                response["items"].push_back(SerializeItem(items[i]));
            }
            
            response["collected"] = module->GetCollectedCount(accountId);
            response["total"] = module->GetTotalAvailable(accountId, player);
            response["page"] = page;
            response["pages"] = (items.size() + limit - 1) / limit;
            
            SendMessage(player, "COLL", 0x50, response);
            break;
        }
        
        case 0x11: // CMSG_SUMMON_RANDOM_MOUNT
        {
            bool favoritesOnly = data.value("favoritesOnly", false);
            bool preferFlying = data.value("preferFlying", false);
            
            auto module = dynamic_cast<MountModule*>(
                sCollectionMgr->GetModule(CollectionType::MOUNT));
            
            if (!module)
                return;
            
            uint32 accountId = player->GetSession()->GetAccountId();
            uint32 spellId = module->GetSmartRandomMount(player, favoritesOnly, preferFlying);
            
            if (spellId == 0)
            {
                SendError(player, favoritesOnly ? 
                    "No favorite mounts found" : "No mounts available");
                return;
            }
            
            // Cast the mount spell
            player->CastSpell(player, spellId, true);
            
            // Update usage counter
            module->IncrementUsage(accountId, spellId);
            
            // Send confirmation
            nlohmann::json response;
            response["success"] = true;
            response["spellId"] = spellId;
            
            auto& def = module->GetDefinition(spellId);
            response["name"] = def.name;
            
            SendMessage(player, "COLL", 0x53, response);
            break;
        }
        
        // ... other opcodes
    }
}
```

---

## Client Handler Registration

```lua
-- In DC-Collections addon initialization

local function RegisterProtocolHandlers()
    local DC = DCAddonProtocol
    
    -- Collection data response
    DC:RegisterJSONHandler("COLL", 0x50, function(data)
        local moduleType = data.type
        DCCollectionManager:OnCollectionDataReceived(moduleType, data)
    end)
    
    -- Count response
    DC:RegisterJSONHandler("COLL", 0x51, function(data)
        DCCollectionManager:OnCountReceived(data)
    end)
    
    -- Favorite update confirmation
    DC:RegisterJSONHandler("COLL", 0x52, function(data)
        DCCollectionManager:OnFavoriteUpdated(data.type, data.entryId, data.favorite)
    end)
    
    -- Use confirmation
    DC:RegisterJSONHandler("COLL", 0x53, function(data)
        -- Could show feedback, play sound, etc.
        if data.success then
            PlaySound("igMainMenuOptionCheckBoxOn", "sfx")
        end
    end)
    
    -- Statistics
    DC:RegisterJSONHandler("COLL", 0x54, function(data)
        DCCollectionManager:OnStatisticsReceived(data)
    end)
    
    -- Search results
    DC:RegisterJSONHandler("COLL", 0x55, function(data)
        DCCollectionManager:OnSearchResults(data)
    end)
    
    -- New item learned (server push)
    DC:RegisterJSONHandler("COLL", 0x60, function(data)
        DCCollectionManager:OnItemLearned(data)
        
        -- Show toast notification
        if DCCollectionFrame and DCCollectionFrame.ShowToast then
            DCCollectionFrame:ShowToast(data.name, data.icon, data.type)
        end
        
        -- Chat message
        local rarityColor = GetRarityColor(data.rarity)
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff00ff00New %s:|r %s%s|r",
            data.type,
            rarityColor,
            data.name
        ))
    end)
    
    -- Achievement earned
    DC:RegisterJSONHandler("COLL", 0x61, function(data)
        -- Could integrate with achievement system
        print(string.format("|cffff8000Achievement:|r %s", data.name))
    end)
    
    -- Error handler
    DC:RegisterJSONHandler("COLL", 0x5F, function(data)
        print(string.format("|cffff0000Collection Error:|r %s", data.message or "Unknown error"))
    end)
end
```

---

## Comparison with Existing Modules

| Feature | AOE Loot | Item Upgrade | Mythic+ | Collection (New) |
|---------|----------|--------------|---------|------------------|
| Protocol | JSON | JSON | JSON | JSON |
| Module ID | AOE | UPG | MPLUS | COLL |
| Request Tracking | ✓ | ✓ | ✓ | ✓ |
| Error Handling | ✓ | ✓ | ✓ | ✓ |
| Pagination | ✗ | ✓ | ✓ | ✓ |
| Caching | ✗ | ✗ | ✓ | ✓ |
| Debug Support | ✓ | ✓ | ✓ | ✓ |

---

## Backward Compatibility

The collection system is entirely new, so no backward compatibility concerns exist. However, for the **Transmog Bridge**:

1. **Existing Transmogrification addon continues to work**
2. Collection UI reads from existing `CollectedAppearances` table
3. No changes to existing AIO-based transmog communication
4. Collection system is additive, not replacement

---

## Performance Considerations

### Client-Side Caching

```lua
-- Cache configuration
DCCollectionManager.config = {
    cacheTimeout = 300,  -- 5 minutes
    maxCacheSize = 10,   -- Max cached collection types
    prefetchEnabled = true,
}

-- Cache structure
DCCollectionManager.cache = {
    mount = {
        data = {},
        timestamp = 0,
        page = 1,
    },
    -- ...
}

-- Check cache before request
function DCCollectionManager:GetCollectionCached(type, page)
    local cache = self.cache[type]
    if cache and cache.page == page then
        local age = time() - cache.timestamp
        if age < self.config.cacheTimeout then
            return cache.data
        end
    end
    return nil
end
```

### Server-Side Rate Limiting

```cpp
bool CollectionAddonHandler::RateLimitCheck(Player* player, uint8 opcode)
{
    // Allow most read operations freely
    if (opcode < 0x10)
    {
        // Core reads - 2 second cooldown
        return CheckCooldown(player, 2);
    }
    
    // Action operations - 1 second cooldown
    return CheckCooldown(player, 1);
}
```

---

## Summary

The DCAddonProtocol integration for the collection system follows established patterns:

1. **Module ID:** `COLL`
2. **Format:** JSON (via `DC:Request()`)
3. **Opcode Ranges:**
   - `0x01-0x0F`: Core collection operations
   - `0x10-0x1F`: Mount-specific
   - `0x20-0x2F`: Pet-specific
   - `0x30-0x3F`: Transmog-specific
   - `0x40-0x4F`: Toy-specific
   - `0x50-0x5F`: Server responses
   - `0x60-0x6F`: Server notifications
4. **API Wrapper:** `DC.Collection.*`
5. **Fully compatible with existing DC infrastructure**
