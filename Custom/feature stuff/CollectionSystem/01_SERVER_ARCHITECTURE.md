# Collection System - Server Architecture

**Component:** C++ Server (AzerothCore) + Eluna Scripts  
**Dependencies:** DCAddonProtocol handlers

---

## Overview

The server-side collection system consists of:
1. **CollectionManager** - Core C++ singleton for collection operations
2. **Database Layer** - Account-wide and character-specific tables
3. **Addon Handler** - DCAddonProtocol message processor
4. **Achievement Integration** - Collection-based achievements
5. **Eluna Bridge** - For rapid iteration during development

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CollectionManager                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │ MountModule │  │  PetModule  │  │TransmogMod  │  │  ToyModule  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │
│         │                │                │                │         │
│         └────────────────┴────────────────┴────────────────┘         │
│                                  │                                   │
│                     ┌────────────┴────────────┐                      │
│                     │  ICollectionModule      │                      │
│                     │  - LoadAccountData()    │                      │
│                     │  - HasCollectable()     │                      │
│                     │  - AddCollectable()     │                      │
│                     │  - GetCollectionData()  │                      │
│                     │  - UseCollectable()     │                      │
│                     └─────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │    AddonMessageHandler    │
                    │    (DCAddonProtocol)      │
                    └───────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │      Player Session       │
                    └───────────────────────────┘
```

---

## Core Classes

### ICollectionModule Interface

```cpp
// src/server/scripts/DC/Collections/ICollectionModule.h

#pragma once
#include <string>
#include <vector>
#include <unordered_set>

enum class CollectionType : uint8
{
    MOUNT       = 0,
    PET         = 1,
    TRANSMOG    = 2,
    TOY         = 3,
    HEIRLOOM    = 4,
    TITLE       = 5,
    MAX_TYPES
};

struct CollectionEntry
{
    uint32 entryId;
    uint32 spellId;           // For mounts/pets
    uint32 itemId;            // For toys/transmog
    std::string name;
    std::string icon;
    std::string source;       // JSON: {"type": "drop", "location": "Ulduar"}
    uint8 rarity;             // 0=common, 1=uncommon, 2=rare, 3=epic, 4=legendary
    bool isFavorite;
    bool isUsable;            // Class/faction restrictions met
    time_t obtainedDate;
    uint32 obtainedBy;        // Character GUID who obtained it
    std::string customName;   // For pets
};

struct CollectionStatistics
{
    uint32 totalCollected;
    uint32 totalAvailable;
    uint32 favoritesCount;
    std::map<uint8, uint32> byRarity;  // rarity -> count
    std::map<std::string, uint32> bySource;  // source_type -> count
};

class ICollectionModule
{
public:
    virtual ~ICollectionModule() = default;
    
    // Module identification
    virtual CollectionType GetType() const = 0;
    virtual std::string GetTypeName() const = 0;
    
    // Data loading
    virtual void LoadAccountData(uint32 accountId) = 0;
    virtual void UnloadAccountData(uint32 accountId) = 0;
    
    // Collection queries
    virtual bool HasCollectable(uint32 accountId, uint32 entryId) const = 0;
    virtual std::vector<CollectionEntry> GetCollection(uint32 accountId) const = 0;
    virtual CollectionStatistics GetStatistics(uint32 accountId) const = 0;
    virtual uint32 GetCollectedCount(uint32 accountId) const = 0;
    virtual uint32 GetTotalAvailable(uint32 accountId, Player* player = nullptr) const = 0;
    
    // Collection modifications
    virtual bool AddCollectable(Player* player, uint32 entryId) = 0;
    virtual bool RemoveCollectable(uint32 accountId, uint32 entryId) = 0;
    virtual bool SetFavorite(uint32 accountId, uint32 entryId, bool favorite) = 0;
    
    // Usage
    virtual bool UseCollectable(Player* player, uint32 entryId) = 0;
    virtual uint32 GetRandomCollectable(uint32 accountId, bool favoritesOnly = false) const = 0;
    
    // Search/filter
    virtual std::vector<CollectionEntry> Search(uint32 accountId, const std::string& query, 
        uint8 rarityFilter = 0xFF, const std::string& sourceFilter = "") const = 0;
    
    // Serialization for addon
    virtual std::string SerializeCollection(uint32 accountId) const = 0;
    virtual std::string SerializeEntry(const CollectionEntry& entry) const = 0;
};
```

### CollectionManager Singleton

```cpp
// src/server/scripts/DC/Collections/CollectionManager.h

#pragma once
#include "ICollectionModule.h"
#include <memory>
#include <unordered_map>

class CollectionManager
{
public:
    static CollectionManager* instance();
    
    // Module registration (called at server startup)
    void RegisterModule(std::unique_ptr<ICollectionModule> module);
    ICollectionModule* GetModule(CollectionType type) const;
    
    // Account lifecycle
    void OnAccountLogin(uint32 accountId);
    void OnAccountLogout(uint32 accountId);
    
    // Cross-module queries
    uint32 GetTotalCollectedCount(uint32 accountId) const;
    std::string GetAllStatisticsJSON(uint32 accountId) const;
    
    // Achievement integration
    void CheckCollectionAchievements(Player* player, CollectionType type);
    
    // Addon message handling
    void HandleAddonMessage(Player* player, const std::string& module, 
        uint8 opcode, const std::string& jsonData);
    
private:
    CollectionManager() = default;
    
    std::unordered_map<CollectionType, std::unique_ptr<ICollectionModule>> _modules;
    std::unordered_set<uint32> _loadedAccounts;
    
    // Rate limiting
    std::unordered_map<uint64, time_t> _lastRequest;  // playerGuid -> timestamp
    bool RateLimitCheck(Player* player);
};

#define sCollectionMgr CollectionManager::instance()
```

### Mount Module Implementation

```cpp
// src/server/scripts/DC/Collections/MountModule.h

#pragma once
#include "ICollectionModule.h"

struct MountDefinition
{
    uint32 spellId;
    std::string name;
    uint8 mountType;      // 0=ground, 1=flying, 2=aquatic, 3=all
    std::string source;
    uint8 faction;        // 0=both, 1=alliance, 2=horde
    uint8 classReq;       // 0=all, else class mask
    uint32 displayId;
    std::string icon;
    uint8 rarity;
};

class MountModule : public ICollectionModule
{
public:
    MountModule();
    
    // ICollectionModule implementation
    CollectionType GetType() const override { return CollectionType::MOUNT; }
    std::string GetTypeName() const override { return "mount"; }
    
    void LoadAccountData(uint32 accountId) override;
    void UnloadAccountData(uint32 accountId) override;
    
    bool HasCollectable(uint32 accountId, uint32 spellId) const override;
    std::vector<CollectionEntry> GetCollection(uint32 accountId) const override;
    CollectionStatistics GetStatistics(uint32 accountId) const override;
    uint32 GetCollectedCount(uint32 accountId) const override;
    uint32 GetTotalAvailable(uint32 accountId, Player* player = nullptr) const override;
    
    bool AddCollectable(Player* player, uint32 spellId) override;
    bool RemoveCollectable(uint32 accountId, uint32 spellId) override;
    bool SetFavorite(uint32 accountId, uint32 spellId, bool favorite) override;
    
    bool UseCollectable(Player* player, uint32 spellId) override;
    uint32 GetRandomCollectable(uint32 accountId, bool favoritesOnly = false) const override;
    
    std::vector<CollectionEntry> Search(uint32 accountId, const std::string& query,
        uint8 rarityFilter = 0xFF, const std::string& sourceFilter = "") const override;
    
    std::string SerializeCollection(uint32 accountId) const override;
    std::string SerializeEntry(const CollectionEntry& entry) const override;
    
    // Mount-specific
    uint32 GetSmartRandomMount(Player* player, bool favoritesOnly = false) const;
    bool CanUseMount(Player* player, uint32 spellId) const;
    
private:
    void LoadMountDefinitions();
    
    // Static mount data (loaded once at startup)
    std::unordered_map<uint32, MountDefinition> _mountDefs;
    
    // Per-account collected mounts
    struct AccountMountData
    {
        std::unordered_set<uint32> collected;
        std::unordered_set<uint32> favorites;
        std::unordered_map<uint32, time_t> obtainedDates;
        std::unordered_map<uint32, uint32> obtainedBy;  // spellId -> charGuid
    };
    std::unordered_map<uint32, AccountMountData> _accountData;
};
```

---

## Addon Message Handler

```cpp
// src/server/scripts/DC/Collections/CollectionAddonHandler.cpp

#include "ScriptMgr.h"
#include "Player.h"
#include "CollectionManager.h"
#include "DCAddonProtocol.h"
#include "nlohmann/json.hpp"

using json = nlohmann::json;

class CollectionAddonHandler : public PlayerScript
{
public:
    CollectionAddonHandler() : PlayerScript("DC_CollectionAddonHandler") {}
    
    void OnLogin(Player* player) override
    {
        uint32 accountId = player->GetSession()->GetAccountId();
        sCollectionMgr->OnAccountLogin(accountId);
    }
    
    void OnLogout(Player* player) override
    {
        uint32 accountId = player->GetSession()->GetAccountId();
        sCollectionMgr->OnAccountLogout(accountId);
    }
};

class CollectionMessageHandler : public DCMessageHandler
{
public:
    CollectionMessageHandler() : DCMessageHandler("COLL") {}
    
    void HandleMessage(Player* player, uint8 opcode, const json& data) override
    {
        uint32 accountId = player->GetSession()->GetAccountId();
        
        switch (opcode)
        {
            case 0x01: // CMSG_GET_COLLECTION
            {
                std::string type = data.value("type", "mount");
                CollectionType colType = ParseCollectionType(type);
                
                auto module = sCollectionMgr->GetModule(colType);
                if (!module)
                {
                    SendError(player, "Unknown collection type");
                    return;
                }
                
                json response;
                response["type"] = type;
                response["items"] = json::parse(module->SerializeCollection(accountId));
                response["total"] = module->GetTotalAvailable(accountId, player);
                response["collected"] = module->GetCollectedCount(accountId);
                
                SendResponse(player, 0x10, response);
                break;
            }
            
            case 0x02: // CMSG_GET_COUNT
            {
                std::string type = data.value("type", "all");
                
                json response;
                if (type == "all")
                {
                    response["total"] = sCollectionMgr->GetTotalCollectedCount(accountId);
                    // Include breakdown by type
                    for (uint8 t = 0; t < static_cast<uint8>(CollectionType::MAX_TYPES); ++t)
                    {
                        auto module = sCollectionMgr->GetModule(static_cast<CollectionType>(t));
                        if (module)
                        {
                            response[module->GetTypeName()] = module->GetCollectedCount(accountId);
                        }
                    }
                }
                else
                {
                    CollectionType colType = ParseCollectionType(type);
                    auto module = sCollectionMgr->GetModule(colType);
                    if (module)
                    {
                        response["type"] = type;
                        response["collected"] = module->GetCollectedCount(accountId);
                        response["total"] = module->GetTotalAvailable(accountId, player);
                    }
                }
                
                SendResponse(player, 0x11, response);
                break;
            }
            
            case 0x03: // CMSG_SET_FAVORITE
            {
                std::string type = data.value("type", "mount");
                uint32 entryId = data.value("entryId", 0);
                bool favorite = data.value("favorite", false);
                
                CollectionType colType = ParseCollectionType(type);
                auto module = sCollectionMgr->GetModule(colType);
                if (module && module->SetFavorite(accountId, entryId, favorite))
                {
                    json response;
                    response["success"] = true;
                    response["entryId"] = entryId;
                    response["favorite"] = favorite;
                    SendResponse(player, 0x12, response);
                }
                break;
            }
            
            case 0x04: // CMSG_USE_COLLECTABLE
            {
                std::string type = data.value("type", "mount");
                uint32 entryId = data.value("entryId", 0);
                
                CollectionType colType = ParseCollectionType(type);
                auto module = sCollectionMgr->GetModule(colType);
                if (module)
                {
                    if (module->UseCollectable(player, entryId))
                    {
                        json response;
                        response["success"] = true;
                        SendResponse(player, 0x13, response);
                    }
                    else
                    {
                        SendError(player, "Cannot use this collectable");
                    }
                }
                break;
            }
            
            case 0x05: // CMSG_GET_STATISTICS
            {
                json response = json::parse(sCollectionMgr->GetAllStatisticsJSON(accountId));
                SendResponse(player, 0x14, response);
                break;
            }
            
            case 0x06: // CMSG_SEARCH
            {
                std::string type = data.value("type", "mount");
                std::string query = data.value("query", "");
                uint8 rarity = data.value("rarity", 0xFF);
                std::string source = data.value("source", "");
                uint32 page = data.value("page", 1);
                uint32 limit = data.value("limit", 50);
                
                CollectionType colType = ParseCollectionType(type);
                auto module = sCollectionMgr->GetModule(colType);
                if (module)
                {
                    auto results = module->Search(accountId, query, rarity, source);
                    
                    // Paginate
                    uint32 start = (page - 1) * limit;
                    uint32 end = std::min(start + limit, static_cast<uint32>(results.size()));
                    
                    json items = json::array();
                    for (uint32 i = start; i < end; ++i)
                    {
                        items.push_back(json::parse(module->SerializeEntry(results[i])));
                    }
                    
                    json response;
                    response["type"] = type;
                    response["items"] = items;
                    response["total"] = results.size();
                    response["page"] = page;
                    response["pages"] = (results.size() + limit - 1) / limit;
                    
                    SendResponse(player, 0x15, response);
                }
                break;
            }
            
            // Mount-specific opcodes (0x10-0x1F)
            case 0x10: // CMSG_SUMMON_MOUNT
            {
                uint32 spellId = data.value("spellId", 0);
                auto module = sCollectionMgr->GetModule(CollectionType::MOUNT);
                if (module && module->UseCollectable(player, spellId))
                {
                    // Success handled by UseCollectable
                }
                break;
            }
            
            case 0x11: // CMSG_SUMMON_RANDOM_MOUNT
            {
                bool favoritesOnly = data.value("favoritesOnly", false);
                auto module = dynamic_cast<MountModule*>(
                    sCollectionMgr->GetModule(CollectionType::MOUNT));
                if (module)
                {
                    uint32 spellId = module->GetSmartRandomMount(player, favoritesOnly);
                    if (spellId && module->UseCollectable(player, spellId))
                    {
                        json response;
                        response["spellId"] = spellId;
                        SendResponse(player, 0x16, response);
                    }
                }
                break;
            }
            
            // Pet-specific opcodes (0x20-0x2F)
            case 0x22: // CMSG_RENAME_PET
            {
                uint32 petId = data.value("petId", 0);
                std::string name = data.value("name", "");
                // Implement pet rename...
                break;
            }
        }
    }
    
private:
    CollectionType ParseCollectionType(const std::string& type)
    {
        if (type == "mount") return CollectionType::MOUNT;
        if (type == "pet") return CollectionType::PET;
        if (type == "transmog") return CollectionType::TRANSMOG;
        if (type == "toy") return CollectionType::TOY;
        if (type == "heirloom") return CollectionType::HEIRLOOM;
        if (type == "title") return CollectionType::TITLE;
        return CollectionType::MOUNT;  // Default
    }
};

void AddSC_DC_Collections()
{
    new CollectionAddonHandler();
    new CollectionMessageHandler();
    
    // Register modules
    sCollectionMgr->RegisterModule(std::make_unique<MountModule>());
    sCollectionMgr->RegisterModule(std::make_unique<PetModule>());
    // Add more modules as implemented
}
```

---

## Eluna Bridge (Development/Rapid Iteration)

For features that need quick iteration, provide an Eluna bridge:

```lua
-- lua_scripts/DC_CollectionBridge.lua

local CollectionBridge = {}

-- Forward calls to C++ when ready, use Lua implementation during development
CollectionBridge.GetMountCount = function(player)
    local accountId = player:GetAccountId()
    local query = CharDBQuery(string.format(
        "SELECT COUNT(*) FROM dc_mount_collection WHERE account_id = %d", 
        accountId))
    if query then
        return query:GetUInt32(0)
    end
    return 0
end

CollectionBridge.HasMount = function(player, spellId)
    local accountId = player:GetAccountId()
    local query = CharDBQuery(string.format(
        "SELECT 1 FROM dc_mount_collection WHERE account_id = %d AND mount_spell_id = %d",
        accountId, spellId))
    return query ~= nil
end

CollectionBridge.AddMount = function(player, spellId)
    local accountId = player:GetAccountId()
    local charGuid = player:GetGUIDLow()
    
    if CollectionBridge.HasMount(player, spellId) then
        return false
    end
    
    CharDBExecute(string.format(
        "INSERT INTO dc_mount_collection (account_id, mount_spell_id, obtained_by) VALUES (%d, %d, %d)",
        accountId, spellId, charGuid))
    
    -- Check achievements
    CollectionBridge.CheckMountAchievements(player)
    
    return true
end

-- Register with Eluna events
RegisterPlayerEvent(PLAYER_EVENT_ON_LEARN_SPELL, function(event, player, spellId)
    -- Check if spell is a mount spell
    local mountDef = MountDefinitions[spellId]
    if mountDef then
        CollectionBridge.AddMount(player, spellId)
    end
end)

return CollectionBridge
```

---

## Integration Points

### With Existing Transmog
```cpp
// Bridge to existing transmog system
class TransmogCollectionModule : public ICollectionModule
{
    // Wraps existing transmog tables
    // Provides unified interface for collection UI
    // Does NOT replace transmog addon functionality
};
```

### With Achievement System
```cpp
void CollectionManager::CheckCollectionAchievements(Player* player, CollectionType type)
{
    uint32 accountId = player->GetSession()->GetAccountId();
    auto module = GetModule(type);
    if (!module) return;
    
    uint32 count = module->GetCollectedCount(accountId);
    
    // Check type-specific achievements
    switch (type)
    {
        case CollectionType::MOUNT:
            if (count >= 10)  player->CompletedAchievement(ACHI_STABLE_KEEPER);
            if (count >= 25)  player->CompletedAchievement(ACHI_LEADING_CAVALRY);
            if (count >= 50)  player->CompletedAchievement(ACHI_MOUNTAIN_MOUNTS);
            if (count >= 100) player->CompletedAchievement(ACHI_MORE_SADDLES);
            if (count >= 200) player->CompletedAchievement(ACHI_MOUNT_PARADE);
            break;
        case CollectionType::PET:
            // Pet achievements...
            break;
        // etc.
    }
    
    // Check cross-collection achievements
    uint32 totalCollected = GetTotalCollectedCount(accountId);
    if (totalCollected >= 100)  player->CompletedAchievement(ACHI_COLLECTOR_100);
    if (totalCollected >= 500)  player->CompletedAchievement(ACHI_COLLECTOR_500);
    if (totalCollected >= 1000) player->CompletedAchievement(ACHI_COLLECTOR_1000);
}
```

---

## Summary

| Component | Technology | Status |
|-----------|------------|--------|
| ICollectionModule | C++ Interface | To Implement |
| CollectionManager | C++ Singleton | To Implement |
| MountModule | C++ + DB | To Implement |
| PetModule | C++ + DB | To Implement |
| TransmogBridge | C++ Wrapper | Uses Existing |
| AddonHandler | C++ + DCProtocol | To Implement |
| Eluna Bridge | Lua | For Development |
