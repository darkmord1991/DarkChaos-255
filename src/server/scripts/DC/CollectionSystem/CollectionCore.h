/*
 * CollectionCore.h - DarkChaos Collection System Header
 *
 * Shared declarations for the Collection system.
 * Part of DC-Collection addon server-side support.
 */

#ifndef DC_COLLECTION_CORE_H
#define DC_COLLECTION_CORE_H

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "SpellMgr.h"
#include "Spell.h"
#include "SpellInfo.h"
#include "DC/CrossSystem/CrossSystemDbSchema.h"

#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>

namespace DCCollection
{
    // Module identifier
    constexpr char const* MODULE = "COLL";

    // =======================================================================
    // Configuration Keys
    // =======================================================================
    namespace Config
    {
        constexpr char const* ENABLED = "DCCollection.Enable";
        constexpr char const* MOUNT_BONUSES_ENABLED = "DCCollection.MountBonuses.Enable";
        constexpr char const* SHOP_ENABLED = "DCCollection.Shop.Enable";
        constexpr char const* TRANSMOG_ENABLED = "DCCollection.Transmog.Enable";
        constexpr char const* TRANSMOG_APPEARANCES_ENABLED = "DCCollection.Transmog.Appearances.Enable";
        constexpr char const* ACCOUNTWIDE_ENABLED = "DCCollection.Accountwide.Enable";
        constexpr char const* PETS_REBUILD_ON_STARTUP = "DCCollection.Pets.RebuildDefinitionsOnStartup";
        constexpr char const* PETS_REBUILD_ON_STARTUP_TRUNCATE = "DCCollection.Pets.RebuildDefinitionsOnStartup.Truncate";
    }

    // =======================================================================
    // Collection Types
    // =======================================================================
    enum class CollectionType : uint8
    {
        MOUNT       = 1,
        PET         = 2,
        TOY         = 3,
        HEIRLOOM    = 4,
        TITLE       = 5,
        TRANSMOG    = 6,
    };

    // =======================================================================
    // Mount Speed Bonuses
    // =======================================================================
    constexpr uint32 SPELL_MOUNT_SPEED_TIER1 = 300510;  // +2% mount speed (25+ mounts)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER2 = 300511;  // +3% mount speed (50+ mounts)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER3 = 300512;  // +4% mount speed (100+ mounts)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER4 = 300513;  // +5% mount speed (200+ mounts)

    constexpr uint32 MOUNT_THRESHOLD_TIER1 = 25;
    constexpr uint32 MOUNT_THRESHOLD_TIER2 = 50;
    constexpr uint32 MOUNT_THRESHOLD_TIER3 = 100;
    constexpr uint32 MOUNT_THRESHOLD_TIER4 = 200;

    // =======================================================================
    // Transmog Appearance Structure
    // =======================================================================
    struct TransmogAppearanceVariant
    {
        uint32 displayId;
        uint32 itemEntry;
        uint32 invType;
        uint32 itemClass;
        uint32 itemSubClass;
        uint32 quality;
        uint32 itemLevel;
        bool isNonCustom;
    };

    using AppearanceIndex = std::unordered_map<uint32, std::vector<TransmogAppearanceVariant>>;

    // =======================================================================
    // Player Collection Cache - Avoids repeated DB queries per request
    // =======================================================================
    struct PlayerCollectionCache
    {
        std::unordered_set<uint32> mounts;
        std::unordered_set<uint32> pets;
        std::unordered_set<uint32> toys;
        std::unordered_set<uint32> heirlooms;
        std::unordered_set<uint32> titles;
        std::unordered_set<uint32> transmogDisplayIds;
        time_t lastUpdate = 0;
        bool valid = false;

        void Reset()
        {
            mounts.clear();
            pets.clear();
            toys.clear();
            heirlooms.clear();
            titles.clear();
            transmogDisplayIds.clear();
            lastUpdate = 0;
            valid = false;
        }
    };

    // Cache management functions
    PlayerCollectionCache& GetPlayerCache(uint32 accountId);
    void InvalidatePlayerCache(uint32 accountId);
    void LoadPlayerCollectionToCache(uint32 accountId);
    bool IsCollectionCacheValid(uint32 accountId, time_t maxAgeSeconds = 60);

    // =======================================================================
    // Utility Functions  (thin forwarders to DC::DbSchema canonical helpers)
    // =======================================================================
    bool WorldTableExists(std::string const& tableName);
    bool WorldColumnExists(std::string const& tableName, std::string const& columnName);
    bool CharacterTableExists(std::string const& tableName);
    bool CharacterColumnExists(std::string const& tableName, std::string const& columnName);

    // =======================================================================
    // Mount/Pet/Companion Functions
    // =======================================================================
    uint32 FindCompanionSpellIdForItem(uint32 itemId);
    uint32 FindCompanionItemIdForSpell(uint32 spellId);
    uint32 FindMountItemIdForSpell(uint32 spellId);
    bool IsCompanionSpell(SpellInfo const* spellInfo);
    uint32 ResolveCompanionSummonSpellFromSpell(uint32 spellId);
    void RebuildPetDefinitionsFromLocalData();

    // =======================================================================
    // Stats and bonuses
    // =======================================================================
    void UpdateMountSpeedBonuses(Player* player);

}  // namespace DCCollection

// Script registration
void AddSC_dc_addon_collection();

// Helper to get character GUID column name - consistent with legacy/modern schema
inline std::string GetCharEntryColumn(std::string const& /*tableName*/) { return "guid"; }

#endif // DC_COLLECTION_CORE_H
