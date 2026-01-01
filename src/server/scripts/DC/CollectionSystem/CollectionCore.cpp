/*
 * CollectionCore.cpp - DarkChaos Collection System Core
 *
 * Contains shared configuration, database helpers, and utilities.
 * Part of the split collection system implementation.
 */

#include "CollectionCore.h"
#include "WorldSession.h"
#include "WorldPacket.h"
#include "World.h"
#include "SpellAuras.h"
#include "Pet.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Bag.h"
#include "DBCStores.h"
#include "../AddonExtension/DCAddonNamespace.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "DC/ItemUpgrades/ItemUpgradeSeasonResolver.h"

#include <sstream>
#include <ctime>
#include <functional>
#include <chrono>
#include <mutex>

namespace DCCollection
{
    // =======================================================================
    // Player Collection Cache Storage
    // =======================================================================
    static std::unordered_map<uint32, PlayerCollectionCache> sPlayerCacheMap;
    static std::mutex sPlayerCacheMutex;

    PlayerCollectionCache& GetPlayerCache(uint32 accountId)
    {
        std::lock_guard<std::mutex> lock(sPlayerCacheMutex);
        return sPlayerCacheMap[accountId];
    }

    void InvalidatePlayerCache(uint32 accountId)
    {
        std::lock_guard<std::mutex> lock(sPlayerCacheMutex);
        auto it = sPlayerCacheMap.find(accountId);
        if (it != sPlayerCacheMap.end())
        {
            it->second.Reset();
        }
    }

    bool IsCollectionCacheValid(uint32 accountId, time_t maxAgeSeconds)
    {
        std::lock_guard<std::mutex> lock(sPlayerCacheMutex);
        auto it = sPlayerCacheMap.find(accountId);
        if (it == sPlayerCacheMap.end() || !it->second.valid)
            return false;
        return (time(nullptr) - it->second.lastUpdate) < maxAgeSeconds;
    }

    void LoadPlayerCollectionToCache(uint32 accountId)
    {
        PlayerCollectionCache& cache = GetPlayerCache(accountId);
        cache.Reset();

        // Load mounts
        if (CharacterTableExists("dc_collection_mounts"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT mount_spell_id FROM dc_collection_mounts WHERE account_id = {}", accountId);
            if (result)
            {
                do
                {
                    cache.mounts.insert(result->Fetch()[0].Get<uint32>());
                } while (result->NextRow());
            }
        }

        // Load pets
        if (CharacterTableExists("dc_collection_pets"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT pet_spell_id FROM dc_collection_pets WHERE account_id = {}", accountId);
            if (result)
            {
                do
                {
                    cache.pets.insert(result->Fetch()[0].Get<uint32>());
                } while (result->NextRow());
            }
        }

        // Load toys
        if (CharacterTableExists("dc_collection_toys"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT toy_item_id FROM dc_collection_toys WHERE account_id = {}", accountId);
            if (result)
            {
                do
                {
                    cache.toys.insert(result->Fetch()[0].Get<uint32>());
                } while (result->NextRow());
            }
        }

        // Load transmog display IDs
        if (CharacterTableExists("dc_collection_transmog"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT display_id FROM dc_collection_transmog WHERE account_id = {}", accountId);
            if (result)
            {
                do
                {
                    cache.transmogDisplayIds.insert(result->Fetch()[0].Get<uint32>());
                } while (result->NextRow());
            }
        }

        cache.lastUpdate = time(nullptr);
        cache.valid = true;

        LOG_DEBUG("dc.collection", "Loaded collection cache for account {} ({} mounts, {} pets, {} toys, {} transmog)",
            accountId, cache.mounts.size(), cache.pets.size(), cache.toys.size(), cache.transmogDisplayIds.size());
    }

    // =======================================================================
    // Database Helpers
    // =======================================================================

    bool WorldTableExists(std::string const& tableName)
    {
        QueryResult result = WorldDatabase.Query("SHOW TABLES LIKE '{}'", tableName);
        return result != nullptr;
    }

    bool WorldColumnExists(std::string const& tableName, std::string const& columnName)
    {
        if (!WorldTableExists(tableName))
            return false;
        QueryResult result = WorldDatabase.Query("SHOW COLUMNS FROM `{}` LIKE '{}'", tableName, columnName);
        return result != nullptr;
    }

    bool CharacterTableExists(std::string const& tableName)
    {
        QueryResult result = CharacterDatabase.Query("SHOW TABLES LIKE '{}'", tableName);
        return result != nullptr;
    }

    bool CharacterColumnExists(std::string const& tableName, std::string const& columnName)
    {
        if (!CharacterTableExists(tableName))
            return false;
        QueryResult result = CharacterDatabase.Query("SHOW COLUMNS FROM `{}` LIKE '{}'", tableName, columnName);
        return result != nullptr;
    }

    std::string const& GetWorldEntryColumn(std::string const& tableName)
    {
        static std::unordered_map<std::string, std::string> cache;
        auto it = cache.find(tableName);
        if (it != cache.end())
            return it->second;

        std::string col;
        if (WorldColumnExists(tableName, "entry_id"))
            col = "entry_id";
        else if (WorldColumnExists(tableName, "entry"))
            col = "entry";

        if (col.empty())
            LOG_ERROR("server.loading", "DC-Collection: World DB table '{}' missing 'entry_id'/'entry' column.", tableName);

        auto res = cache.emplace(tableName, std::move(col));
        return res.first->second;
    }

    std::string const& GetCharEntryColumn(std::string const& tableName)
    {
        static std::unordered_map<std::string, std::string> cache;
        auto it = cache.find(tableName);
        if (it != cache.end())
            return it->second;

        std::string col;
        if (CharacterColumnExists(tableName, "entry_id"))
            col = "entry_id";
        else if (CharacterColumnExists(tableName, "entry"))
            col = "entry";

        if (col.empty())
            LOG_ERROR("server.loading", "DC-Collection: Character DB table '{}' missing 'entry_id'/'entry' column.", tableName);

        auto res = cache.emplace(tableName, std::move(col));
        return res.first->second;
    }

    // =======================================================================
    // Wishlist Type Helpers
    // =======================================================================

    std::string WishlistTypeToString(uint8 type)
    {
        switch (static_cast<CollectionType>(type))
        {
            case CollectionType::MOUNT: return "mount";
            case CollectionType::PET: return "pet";
            case CollectionType::TOY: return "toy";
            case CollectionType::HEIRLOOM: return "heirloom";
            case CollectionType::TITLE: return "title";
            case CollectionType::TRANSMOG: return "transmog";
            default: return std::string();
        }
    }

    uint8 WishlistTypeFromString(std::string const& type)
    {
        if (type == "mount") return static_cast<uint8>(CollectionType::MOUNT);
        if (type == "pet") return static_cast<uint8>(CollectionType::PET);
        if (type == "toy") return static_cast<uint8>(CollectionType::TOY);
        if (type == "heirloom") return static_cast<uint8>(CollectionType::HEIRLOOM);
        if (type == "title") return static_cast<uint8>(CollectionType::TITLE);
        if (type == "transmog") return static_cast<uint8>(CollectionType::TRANSMOG);
        return 0;
    }

    // =======================================================================
    // Account Helpers
    // =======================================================================

    uint32 GetAccountId(Player* player)
    {
        if (!player || !player->GetSession())
            return 0;
        return player->GetSession()->GetAccountId();
    }

    // =======================================================================
    // Forward References - Implemented in other split files
    // =======================================================================

    // These declarations allow CollectionCore to compile without circular deps.
    // Actual implementations are in CollectionMounts.cpp, CollectionPets.cpp, etc.

}  // namespace DCCollection
