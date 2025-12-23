/*
 * Dark Chaos - Collection System Addon Handler
 * ==============================================
 *
 * Server-side handler for the DC-Collection addon.
 * Provides retail-like collection management for WoW 3.3.5a.
 *
 * Features:
 * - Mount collection with speed bonuses
 * - Companion pet collection
 * - Toy box functionality
 * - Heirloom tracking
 * - Title collection
 * - Transmog appearance catalog
 * - Collection shop with currencies
 * - Wishlist system
 * - Delta sync for performance
 *
 * Message Format:
 * - JSON format: COLL|OPCODE|J|{json}
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "WorldSession.h"
#include "Chat.h"
#include "WorldPacket.h"
#include "DatabaseEnv.h"
#include "../AddonExtension/DCAddonNamespace.h"
#include "Config.h"
#include "World.h"
#include "SpellMgr.h"
#include "SpellAuras.h"
#include "Pet.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Bag.h"
#include "ScriptMgr.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "DC/ItemUpgrades/ItemUpgradeSeasonResolver.h"
#include <string>
#include <sstream>
#include <unordered_set>
#include <unordered_map>
#include <ctime>
#include <functional>
#include <algorithm>
#include <vector>

namespace DCCollection
{
    // Module identifier - must match client-side and DCAddonNamespace.h
    // Use literal constant to avoid depending on DCAddon::Module::COLLECTION being available in all build trees.
    constexpr const char* MODULE = "COLL";

    // =======================================================================
    // Configuration
    // =======================================================================
    namespace Config
    {
        constexpr const char* ENABLED = "DCCollection.Enable";
        constexpr const char* MOUNT_BONUSES_ENABLED = "DCCollection.MountBonuses.Enable";
        constexpr const char* SHOP_ENABLED = "DCCollection.Shop.Enable";
        constexpr const char* WISHLIST_ENABLED = "DCCollection.Wishlist.Enable";
        constexpr const char* WISHLIST_MAX_ITEMS = "DCCollection.Wishlist.MaxItems";
        [[maybe_unused]] constexpr const char* SYNC_INTERVAL = "DCCollection.SyncInterval";

        // Transmog unlock rules
        constexpr const char* TRANSMOG_UNLOCK_ON_CREATE = "DCCollection.Transmog.UnlockOnCreate";
        constexpr const char* TRANSMOG_UNLOCK_ON_EQUIP = "DCCollection.Transmog.UnlockOnEquip";
        constexpr const char* TRANSMOG_UNLOCK_ON_SOULBIND = "DCCollection.Transmog.UnlockOnSoulbind";

        // Legacy import (scan items owned by old characters)
        constexpr const char* TRANSMOG_LEGACY_IMPORT_ENABLED = "DCCollection.Transmog.LegacyImport.Enable";
        constexpr const char* TRANSMOG_LEGACY_IMPORT_INCLUDE_BANK = "DCCollection.Transmog.LegacyImport.IncludeBank";
        constexpr const char* TRANSMOG_LEGACY_IMPORT_REQUIRE_SOULBOUND = "DCCollection.Transmog.LegacyImport.RequireSoulbound";
    }

    // Collection types - matches client-side
    enum class CollectionType : uint8
    {
        MOUNT       = 1,
        PET         = 2,
        TOY         = 3,
        HEIRLOOM    = 4,
        TITLE       = 5,
        TRANSMOG    = 6,
        ITEM_SET    = 7  // Armor/weapon sets from ItemSet.dbc
    };

    // Currency IDs
    // Reuse the existing ItemUpgrade currency implementation (used by CrossSystem/Seasons).
    // These values intentionally match DarkChaos::ItemUpgrade::CurrencyType.
    constexpr uint32 CURRENCY_TOKEN = 1;     // Upgrade Token
    constexpr uint32 CURRENCY_EMBLEM = 2;    // Artifact Essence

    // Transmog behavior
    constexpr uint32 TRANSMOG_CANONICAL_ITEMID_THRESHOLD = 200000; // Prefer non-custom items for naming/appearance

    // Mount speed bonus spell IDs (custom spells in Spell.csv)
    // Range: 300510-300513 (verified free in Spell.csv)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER1 = 300510;  // +1% mount speed (25+ mounts)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER2 = 300511;  // +2% mount speed (50+ mounts)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER3 = 300512;  // +3% mount speed (100+ mounts)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER4 = 300513;  // +5% mount speed (200+ mounts)

    // Mount count thresholds for speed bonuses
    constexpr uint32 MOUNT_THRESHOLD_TIER1 = 25;
    constexpr uint32 MOUNT_THRESHOLD_TIER2 = 50;
    constexpr uint32 MOUNT_THRESHOLD_TIER3 = 100;
    constexpr uint32 MOUNT_THRESHOLD_TIER4 = 200;

    // =======================================================================
    // Utility Functions
    // =======================================================================

    uint32 FindCompanionItemIdForSpell(uint32 spellId)
    {
        // Companion pets in 3.3.5a are typically taught by item_template (class=15, subclass=2).
        QueryResult r = WorldDatabase.Query(
            "SELECT MIN(entry) FROM item_template "
            "WHERE class = 15 AND subclass = 2 AND ("
            "  spellid_1 = {} OR spellid_2 = {} OR spellid_3 = {} OR spellid_4 = {} OR spellid_5 = {}"
            ")",
            spellId, spellId, spellId, spellId, spellId);

        if (!r)
            return 0;

        Field* f = r->Fetch();
        if (f[0].IsNull())
            return 0;
        return f[0].Get<uint32>();
    }

    // Forward declarations used by early migration helpers.
    uint32 GetItemDisplayId(ItemTemplate const* proto);
    bool IsItemEligibleForTransmogUnlock(ItemTemplate const* proto);

    bool CharacterTableExists(std::string const& tableName)
    {
        QueryResult result = CharacterDatabase.Query("SHOW TABLES LIKE '{}'", tableName);
        return result != nullptr;
    }

    bool ShouldRunTransmogLegacyImport(uint32 accountId)
    {
        if (!sConfigMgr->GetOption<bool>(Config::TRANSMOG_LEGACY_IMPORT_ENABLED, true))
            return false;

        // Prefer a persistent migration flag when available.
        static bool checkedTable = false;
        static bool hasMigrationsTable = false;
        if (!checkedTable)
        {
            hasMigrationsTable = CharacterTableExists("dc_collection_migrations");
            checkedTable = true;
        }

        if (hasMigrationsTable)
        {
            QueryResult r = CharacterDatabase.Query(
                "SELECT 1 FROM dc_collection_migrations WHERE account_id = {} AND migration_key = 'legacy_transmog_import_v1' LIMIT 1",
                accountId);
            return r == nullptr;
        }

        // Fallback: run once per server session per account.
        static std::unordered_set<uint32> importedThisSession;
        if (importedThisSession.find(accountId) != importedThisSession.end())
            return false;

        importedThisSession.insert(accountId);
        return true;
    }

    void MarkTransmogLegacyImportDone(uint32 accountId)
    {
        if (!CharacterTableExists("dc_collection_migrations"))
            return;

        CharacterDatabase.Execute(
            "INSERT IGNORE INTO dc_collection_migrations (account_id, migration_key, done, done_at) "
            "VALUES ({}, 'legacy_transmog_import_v1', 1, NOW())",
            accountId);
    }

    // Forward declaration: ensure GetAccountId is visible at call sites
    inline uint32 GetAccountId(Player* player);

    void ImportExistingCollections(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);
        if (!accountId)
            return;

        auto trans = CharacterDatabase.BeginTransaction();

        // Migrate older PET collection rows that used learned spellIds instead of companion itemIds.
        // If entry_id is not a valid item_template entry, attempt to map it to the teaching item.
        {
            QueryResult pets = CharacterDatabase.Query(
                "SELECT entry_id FROM dc_collection_items "
                "WHERE account_id = {} AND collection_type = {} AND unlocked = 1",
                accountId, static_cast<uint8>(CollectionType::PET));

            if (pets)
            {
                do
                {
                    uint32 entryId = pets->Fetch()[0].Get<uint32>();
                    if (sObjectMgr->GetItemTemplate(entryId))
                        continue;

                    uint32 mappedItemId = FindCompanionItemIdForSpell(entryId);
                    if (!mappedItemId)
                        continue;

                    trans->Append(
                        "INSERT IGNORE INTO dc_collection_items "
                        "(account_id, collection_type, entry_id, source_type, unlocked, acquired_date) "
                        "VALUES ({}, {}, {}, 'IMPORT', 1, NOW())",
                        accountId, static_cast<uint8>(CollectionType::PET), mappedItemId);

                    trans->Append(
                        "DELETE FROM dc_collection_items WHERE account_id = {} AND collection_type = {} AND entry_id = {}",
                        accountId, static_cast<uint8>(CollectionType::PET), entryId);

                } while (pets->NextRow());
            }
        }

        // Import learned mount + companion pet spells into account-wide collections.
        PlayerSpellMap const& spells = player->GetSpellMap();
        for (auto const& spell : spells)
        {
            if (!spell.second || spell.second->State == PLAYERSPELL_REMOVED)
                continue;

            uint32 spellId = spell.first;
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (!spellInfo)
                continue;

            bool isMount = false;
            bool isPetSpell = false;

            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                if (spellInfo->Effects[i].Effect == SPELL_EFFECT_APPLY_AURA &&
                    (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED ||
                     spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOD_INCREASE_MOUNTED_FLIGHT_SPEED))
                {
                    isMount = true;
                    break;
                }

                if (spellInfo->Effects[i].Effect == SPELL_EFFECT_SUMMON &&
                    spellInfo->Effects[i].MiscValueB == 0)
                {
                    isPetSpell = true;
                }
            }

            if (isMount)
            {
                trans->Append(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, entry_id, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'IMPORT', 1, NOW())",
                    accountId, static_cast<uint8>(CollectionType::MOUNT), spellId);
            }
            else if (isPetSpell)
            {
                uint32 itemId = FindCompanionItemIdForSpell(spellId);
                if (!itemId)
                    continue;

                trans->Append(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, entry_id, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'IMPORT', 1, NOW())",
                    accountId, static_cast<uint8>(CollectionType::PET), itemId);
            }
        }

        // Import earned titles into account-wide collections.
        for (uint32 i = 1; i < sCharTitlesStore.GetNumRows(); ++i)
        {
            CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(i);
            if (!titleEntry)
                continue;

            if (!player->HasTitle(titleEntry))
                continue;

            trans->Append(
                "INSERT IGNORE INTO dc_collection_items "
                "(account_id, collection_type, entry_id, source_type, unlocked, acquired_date) "
                "VALUES ({}, {}, {}, 'IMPORT', 1, NOW())",
                accountId, static_cast<uint8>(CollectionType::TITLE), titleEntry->ID);
        }

        // Import legacy transmog appearances for old characters by scanning owned items.
        // This is intentionally a one-time import per account.
        if (ShouldRunTransmogLegacyImport(accountId))
        {
            bool includeBank = sConfigMgr->GetOption<bool>(Config::TRANSMOG_LEGACY_IMPORT_INCLUDE_BANK, true);
            bool requireSoulbound = sConfigMgr->GetOption<bool>(Config::TRANSMOG_LEGACY_IMPORT_REQUIRE_SOULBOUND, false);

            std::unordered_set<uint32> displayIds;

            auto considerItem = [&](Item* item)
            {
                if (!item)
                    return;

                if (requireSoulbound && !item->IsSoulBound())
                    return;

                ItemTemplate const* proto = item->GetTemplate();
                if (!IsItemEligibleForTransmogUnlock(proto))
                    return;

                uint32 displayId = GetItemDisplayId(proto);
                if (!displayId)
                    return;

                displayIds.insert(displayId);
            };

            // Equipped slots.
            for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
                considerItem(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

            // Backpack.
            for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
                considerItem(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

            // Bags.
            for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
            {
                if (Bag* bag = player->GetBagByPos(bagSlot))
                    for (uint32 i = 0; i < bag->GetBagSize(); ++i)
                        considerItem(bag->GetItemByPos(static_cast<uint8>(i)));
            }

            if (includeBank)
            {
                // Bank slots.
                for (uint8 slot = BANK_SLOT_ITEM_START; slot < BANK_SLOT_ITEM_END; ++slot)
                    considerItem(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

                // Bank bags.
                for (uint8 bagSlot = BANK_SLOT_BAG_START; bagSlot < BANK_SLOT_BAG_END; ++bagSlot)
                {
                    if (Bag* bag = player->GetBagByPos(bagSlot))
                        for (uint32 i = 0; i < bag->GetBagSize(); ++i)
                            considerItem(bag->GetItemByPos(static_cast<uint8>(i)));
                }
            }

            for (uint32 displayId : displayIds)
            {
                trans->Append(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, entry_id, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'IMPORT_ITEMSCAN', 1, NOW())",
                    accountId, static_cast<uint8>(CollectionType::TRANSMOG), displayId);
            }

            // Mark migration as done even if nothing was found.
            MarkTransmogLegacyImportDone(accountId);
        }

        CharacterDatabase.CommitTransaction(trans);
    }

    // Generate simple hash for delta sync comparison
    inline uint32 GenerateCollectionHash(const std::vector<uint32>& items)
    {
        uint32 hash = 0;
        for (uint32 item : items)
        {
            hash ^= (item * 2654435761u);  // Knuth's multiplicative hash
            hash = (hash << 13) | (hash >> 19);  // Rotate
        }
        return hash;
    }

    // Get player's account ID for account-wide collections
    inline uint32 GetAccountId(Player* player)
    {
        if (!player || !player->GetSession())
            return 0;
        return player->GetSession()->GetAccountId();
    }

    // =======================================================================
    // Database Queries
    // =======================================================================

    bool WorldTableExists(std::string const& tableName)
    {
        QueryResult result = WorldDatabase.Query("SHOW TABLES LIKE '{}'", tableName);
        return result != nullptr;
    }

    // Load player's collection for a specific type
    std::vector<uint32> LoadPlayerCollection(uint32 accountId, CollectionType type)
    {
        std::vector<uint32> items;

        QueryResult result = CharacterDatabase.Query(
            "SELECT entry_id FROM dc_collection_items "
            "WHERE account_id = {} AND collection_type = {} AND unlocked = 1",
            accountId, static_cast<uint8>(type));

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                items.push_back(fields[0].Get<uint32>());
            } while (result->NextRow());
        }

        return items;
    }

    // Load collection counts for all types
    std::map<CollectionType, uint32> LoadCollectionCounts(uint32 accountId)
    {
        std::map<CollectionType, uint32> counts;

        QueryResult result = CharacterDatabase.Query(
            "SELECT collection_type, COUNT(*) FROM dc_collection_items "
            "WHERE account_id = {} AND unlocked = 1 "
            "GROUP BY collection_type",
            accountId);

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                CollectionType type = static_cast<CollectionType>(fields[0].Get<uint8>());
                counts[type] = fields[1].Get<uint32>();
            } while (result->NextRow());
        }

        return counts;
    }

    // Check whether an account owns a given collection item (unlocked)
    bool HasCollectionItem(uint32 accountId, CollectionType type, uint32 entryId)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT 1 FROM dc_collection_items WHERE account_id = {} AND collection_type = {} AND entry_id = {} AND unlocked = 1 LIMIT 1",
            accountId, static_cast<uint8>(type), entryId);
        return result != nullptr;
    }

    // Forward declaration: ensure transmog keys available at call site
    std::vector<uint32> const& GetTransmogAppearanceKeysCached();

    // Get total counts for definitions (for % calculations)
    std::map<CollectionType, uint32> LoadTotalDefinitions()
    {
        std::map<CollectionType, uint32> totals;

        if (WorldTableExists("dc_collection_definitions"))
        {
            QueryResult result = WorldDatabase.Query(
                "SELECT collection_type, COUNT(*) FROM dc_collection_definitions "
                "WHERE enabled = 1 "
                "GROUP BY collection_type");

            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    CollectionType type = static_cast<CollectionType>(fields[0].Get<uint8>());
                    totals[type] = fields[1].Get<uint32>();
                } while (result->NextRow());
            }
        }

        // Fallbacks when the generic definitions table is missing or unpopulated.
        auto ensureTotal = [&](CollectionType type, uint32 value)
        {
            if (totals.find(type) == totals.end())
                totals[type] = value;
        };

        // Titles can always be enumerated from DBC.
        ensureTotal(CollectionType::TITLE, static_cast<uint32>(sCharTitlesStore.GetNumRows() > 0 ? (sCharTitlesStore.GetNumRows() - 1) : 0));

        // Transmog definitions are built in-memory from item_template.
        ensureTotal(CollectionType::TRANSMOG, static_cast<uint32>(GetTransmogAppearanceKeysCached().size()));

        // Prefer curated per-type tables if they exist.
        if (WorldTableExists("dc_mount_definitions"))
        {
            QueryResult r = WorldDatabase.Query("SELECT COUNT(*) FROM dc_mount_definitions");
            if (r)
                ensureTotal(CollectionType::MOUNT, r->Fetch()[0].Get<uint32>());
        }
        if (WorldTableExists("dc_pet_definitions"))
        {
            QueryResult r = WorldDatabase.Query("SELECT COUNT(*) FROM dc_pet_definitions");
            if (r)
                ensureTotal(CollectionType::PET, r->Fetch()[0].Get<uint32>());
        }
        if (WorldTableExists("dc_toy_definitions"))
        {
            QueryResult r = WorldDatabase.Query("SELECT COUNT(*) FROM dc_toy_definitions");
            if (r)
                ensureTotal(CollectionType::TOY, r->Fetch()[0].Get<uint32>());
        }
        if (WorldTableExists("dc_heirloom_definitions"))
        {
            QueryResult r = WorldDatabase.Query("SELECT COUNT(*) FROM dc_heirloom_definitions");
            if (r)
                ensureTotal(CollectionType::HEIRLOOM, r->Fetch()[0].Get<uint32>());
        }

        return totals;
    }

    // Load player currencies (shared currency backing from the ItemUpgrade system)
    std::map<uint32, uint32> LoadCurrencies(Player* player)
    {
        std::map<uint32, uint32> currencies;

        if (!player)
            return currencies;

        DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!mgr)
            return currencies;

        uint32 playerGuid = player->GetGUID().GetCounter();
        uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();

        currencies[CURRENCY_TOKEN] = mgr->GetCurrency(playerGuid, DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN, season);
        currencies[CURRENCY_EMBLEM] = mgr->GetCurrency(playerGuid, DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE, season);

        return currencies;
    }

    // =======================================================================
    // Transmog Helpers
    // =======================================================================

    struct TransmogAppearanceDef
    {
        uint32 canonicalItemId = 0;
        uint32 displayId = 0;
        uint32 inventoryType = 0;
        uint32 itemClass = 0;
        uint32 itemSubClass = 0;
        uint32 quality = 0;
        std::string name;
    };

    using AppearanceMap = std::unordered_map<uint32, TransmogAppearanceDef>; // displayId -> def

    // Forward declaration
    AppearanceMap BuildTransmogAppearanceMap();

    // Forward declaration: A list of appearance display IDs cached for quick lookup
    std::vector<uint32> const& GetTransmogAppearanceKeysCached();

    // Forward declarations for user actions
    void HandleSummonMount(Player* player, uint32 spellId, bool random);
    void HandleSetTitle(Player* player, uint32 titleId);
    void HandleSummonHeirloom(Player* player, uint32 itemId);

    AppearanceMap const& GetTransmogAppearanceMapCached()
    {
        static AppearanceMap cached;
        static bool initialized = false;
        if (!initialized)
        {
            cached = BuildTransmogAppearanceMap();
            initialized = true;
        }
        return cached;
    }

    std::vector<uint32> const& GetTransmogAppearanceKeysCached()
    {
        static std::vector<uint32> keys;
        static bool initialized = false;
        if (!initialized)
        {
            auto const& appearances = GetTransmogAppearanceMapCached();
            keys.reserve(appearances.size());
            for (auto const& [displayId, _] : appearances)
                keys.push_back(displayId);

            std::sort(keys.begin(), keys.end());
            initialized = true;
        }
        return keys;
    }

    bool IsInvTypeCompatibleForSlot(uint8 slot, uint32 invType)
    {
        switch (slot)
        {
            case EQUIPMENT_SLOT_HEAD: return invType == INVTYPE_HEAD;
            case EQUIPMENT_SLOT_SHOULDERS: return invType == INVTYPE_SHOULDERS;
            case EQUIPMENT_SLOT_CHEST: return invType == INVTYPE_CHEST || invType == INVTYPE_ROBE;
            case EQUIPMENT_SLOT_WAIST: return invType == INVTYPE_WAIST;
            case EQUIPMENT_SLOT_LEGS: return invType == INVTYPE_LEGS;
            case EQUIPMENT_SLOT_FEET: return invType == INVTYPE_FEET;
            case EQUIPMENT_SLOT_WRISTS: return invType == INVTYPE_WRISTS;
            case EQUIPMENT_SLOT_HANDS: return invType == INVTYPE_HANDS;
            case EQUIPMENT_SLOT_BACK: return invType == INVTYPE_CLOAK;
            case EQUIPMENT_SLOT_MAINHAND:
                return invType == INVTYPE_WEAPON || invType == INVTYPE_WEAPONMAINHAND || invType == INVTYPE_2HWEAPON;
            case EQUIPMENT_SLOT_OFFHAND:
                return invType == INVTYPE_WEAPON || invType == INVTYPE_WEAPONOFFHAND || invType == INVTYPE_SHIELD || invType == INVTYPE_HOLDABLE;
            case EQUIPMENT_SLOT_RANGED:
                return invType == INVTYPE_RANGED || invType == INVTYPE_RANGEDRIGHT || invType == INVTYPE_THROWN || invType == INVTYPE_RELIC;
            default:
                return false;
        }
    }

    bool IsAppearanceCompatible(uint8 slot, ItemTemplate const* equipped, TransmogAppearanceDef const& appearance)
    {
        if (!equipped)
            return false;

        // Only armor/weapons.
        if (equipped->Class != ITEM_CLASS_ARMOR && equipped->Class != ITEM_CLASS_WEAPON)
            return false;

        if (appearance.itemClass != equipped->Class)
            return false;

        // Armor type / weapon subtype should match (retail-like restriction).
        if (appearance.itemSubClass != equipped->SubClass)
            return false;

        if (!IsInvTypeCompatibleForSlot(slot, appearance.inventoryType))
            return false;

        // Also ensure the equipped item itself is valid for the slot group.
        if (!IsInvTypeCompatibleForSlot(slot, equipped->InventoryType))
            return false;

        // Chest vs robe treated as compatible in the same slot group.
        if (slot == EQUIPMENT_SLOT_CHEST)
        {
            auto isChestLike = [](uint32 inv) { return inv == INVTYPE_CHEST || inv == INVTYPE_ROBE; };
            return isChestLike(equipped->InventoryType) && isChestLike(appearance.inventoryType);
        }

        // Otherwise require exact inventoryType (within slot group already checked).
        if (equipped->InventoryType != appearance.inventoryType)
        {
            // Allow general weapon invtypes within a slot.
            if (slot == EQUIPMENT_SLOT_MAINHAND || slot == EQUIPMENT_SLOT_OFFHAND)
                return true;
            return false;
        }

        return true;
    }

    bool HasTransmogAppearanceUnlocked(uint32 accountId, uint32 displayId)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT 1 FROM dc_collection_items WHERE account_id = {} AND collection_type = {} AND entry_id = {} AND unlocked = 1 LIMIT 1",
            accountId, static_cast<uint8>(CollectionType::TRANSMOG), displayId);

        return result != nullptr;
    }

    void SendTransmogState(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonValue state;
        state.SetObject();

        QueryResult result = CharacterDatabase.Query(
            "SELECT slot, fake_entry FROM dc_character_transmog WHERE guid = {}",
            player->GetGUID().GetCounter());

        if (result)
        {
            auto const& appearances = GetTransmogAppearanceMapCached();
            do
            {
                Field* fields = result->Fetch();
                uint32 slot = fields[0].Get<uint32>();
                uint32 fakeEntry = fields[1].Get<uint32>();

                uint32 displayId = 0;
                ItemTemplate const* fakeProto = sObjectMgr->GetItemTemplate(fakeEntry);
                if (fakeProto)
                    displayId = fakeProto->DisplayInfoID;

                // Prefer mapping back to known appearance IDs when possible.
                if (displayId && appearances.find(displayId) != appearances.end())
                    state.Set(std::to_string(slot), displayId);
                else
                    state.Set(std::to_string(slot), 0);

            } while (result->NextRow());
        }

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_TRANSMOG_STATE);
        msg.Set("state", state);
        msg.Send(player);
    }

    // Build a minimal in-memory appearance map from item_template.
    // Dedup by displayId, prefer canonical item IDs < 200000.
    AppearanceMap BuildTransmogAppearanceMap()
    {
        AppearanceMap defs;

        QueryResult result = WorldDatabase.Query(
            "SELECT entry, displayid, name, class, subclass, InventoryType, Quality "
            "FROM item_template "
            "WHERE displayid <> 0 "
            "  AND class IN (2, 4) " // weapon, armor
            "  AND InventoryType <> 0");

        if (!result)
            return defs;

        do
        {
            Field* fields = result->Fetch();
            uint32 entry = fields[0].Get<uint32>();
            uint32 displayId = fields[1].Get<uint32>();
            std::string name = fields[2].Get<std::string>();
            uint32 itemClass = fields[3].Get<uint32>();
            uint32 itemSubClass = fields[4].Get<uint32>();
            uint32 inventoryType = fields[5].Get<uint32>();
            uint32 quality = fields[6].Get<uint32>();

            if (!displayId)
                continue;

            auto it = defs.find(displayId);
            bool prefer = false;

            if (it == defs.end())
            {
                prefer = true;
            }
            else
            {
                uint32 existing = it->second.canonicalItemId;
                bool entryIsNonCustom = entry < TRANSMOG_CANONICAL_ITEMID_THRESHOLD;
                bool existingIsNonCustom = existing < TRANSMOG_CANONICAL_ITEMID_THRESHOLD;

                if (entryIsNonCustom && !existingIsNonCustom)
                    prefer = true;
                else if (entryIsNonCustom == existingIsNonCustom && entry < existing)
                    prefer = true;
            }

            if (prefer)
            {
                TransmogAppearanceDef def;
                def.canonicalItemId = entry;
                def.displayId = displayId;
                def.inventoryType = inventoryType;
                def.itemClass = itemClass;
                def.itemSubClass = itemSubClass;
                def.quality = quality;
                def.name = name;
                defs[displayId] = std::move(def);
            }
        } while (result->NextRow());

        return defs;
    }

    uint32 GetItemDisplayId(ItemTemplate const* proto)
    {
        if (!proto)
            return 0;
        return proto->DisplayInfoID;
    }

    bool IsItemEligibleForTransmogUnlock(ItemTemplate const* proto)
    {
        if (!proto)
            return false;

        if (proto->DisplayInfoID == 0)
            return false;

        // Only armor/weapons for now
        if (proto->Class != ITEM_CLASS_WEAPON && proto->Class != ITEM_CLASS_ARMOR)
            return false;

        if (proto->InventoryType == INVTYPE_NON_EQUIP)
            return false;

        return true;
    }

    void UnlockTransmogAppearance(Player* player, ItemTemplate const* proto, std::string_view sourceType)
    {
        if (!player || !player->GetSession() || !proto)
            return;

        if (!IsItemEligibleForTransmogUnlock(proto))
            return;

        uint32 accountId = GetAccountId(player);
        if (!accountId)
            return;

        uint32 displayId = GetItemDisplayId(proto);
        if (!displayId)
            return;

        // Store as a generic collection item: type=TRANSMOG, entry_id=displayId
        CharacterDatabase.Execute(
            "INSERT IGNORE INTO dc_collection_items "
            "(account_id, collection_type, entry_id, source_type, unlocked, acquired_date) "
            "VALUES ({}, {}, {}, '{}', 1, NOW())",
            accountId, static_cast<uint8>(CollectionType::TRANSMOG), displayId, std::string(sourceType));
    }

    // Load wishlist
    std::vector<std::pair<uint8, uint32>> LoadWishlist(uint32 accountId)
    {
        std::vector<std::pair<uint8, uint32>> wishlist;

        QueryResult result = CharacterDatabase.Query(
            "SELECT collection_type, entry_id FROM dc_collection_wishlist "
            "WHERE account_id = {} ORDER BY added_date DESC",
            accountId);

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                wishlist.emplace_back(fields[0].Get<uint8>(), fields[1].Get<uint32>());
            } while (result->NextRow());
        }

        return wishlist;
    }

    // Check if item is on wishlist
    bool IsOnWishlist(uint32 accountId, CollectionType type, uint32 entryId)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT 1 FROM dc_collection_wishlist "
            "WHERE account_id = {} AND collection_type = {} AND entry_id = {}",
            accountId, static_cast<uint8>(type), entryId);

        return result != nullptr;
    }

    // =======================================================================
    // Mount Speed Bonus Management
    // =======================================================================

    void UpdateMountSpeedBonus(Player* player)
    {
        if (!player)
            return;

        if (!sConfigMgr->GetOption<bool>(Config::MOUNT_BONUSES_ENABLED, true))
            return;

        uint32 accountId = GetAccountId(player);
        if (!accountId)
            return;

        // Get mount count
        auto counts = LoadCollectionCounts(accountId);
        uint32 mountCount = counts[CollectionType::MOUNT];

        // Remove all existing speed bonuses first
        player->RemoveAurasDueToSpell(SPELL_MOUNT_SPEED_TIER1);
        player->RemoveAurasDueToSpell(SPELL_MOUNT_SPEED_TIER2);
        player->RemoveAurasDueToSpell(SPELL_MOUNT_SPEED_TIER3);
        player->RemoveAurasDueToSpell(SPELL_MOUNT_SPEED_TIER4);

        // Apply appropriate tier (only highest)
        if (mountCount >= MOUNT_THRESHOLD_TIER4)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER4, true);
        else if (mountCount >= MOUNT_THRESHOLD_TIER3)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER3, true);
        else if (mountCount >= MOUNT_THRESHOLD_TIER2)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER2, true);
        else if (mountCount >= MOUNT_THRESHOLD_TIER1)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER1, true);
    }

    // Get current mount speed bonus percentage
    uint8 GetMountSpeedBonusPercent(uint32 mountCount)
    {
        if (mountCount >= MOUNT_THRESHOLD_TIER4)
            return 5;
        else if (mountCount >= MOUNT_THRESHOLD_TIER3)
            return 3;
        else if (mountCount >= MOUNT_THRESHOLD_TIER2)
            return 2;
        else if (mountCount >= MOUNT_THRESHOLD_TIER1)
            return 1;
        return 0;
    }

    // Get next mount speed tier threshold
    uint32 GetNextMountThreshold(uint32 mountCount)
    {
        if (mountCount < MOUNT_THRESHOLD_TIER1)
            return MOUNT_THRESHOLD_TIER1;
        else if (mountCount < MOUNT_THRESHOLD_TIER2)
            return MOUNT_THRESHOLD_TIER2;
        else if (mountCount < MOUNT_THRESHOLD_TIER3)
            return MOUNT_THRESHOLD_TIER3;
        else if (mountCount < MOUNT_THRESHOLD_TIER4)
            return MOUNT_THRESHOLD_TIER4;
        return 0;  // Max reached
    }

    // =======================================================================
    // Handler Functions - Send Data
    // =======================================================================

    void SendHandshakeAck(Player* player, uint32 clientHash)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);

        // Load all collections and compute server hash
        std::vector<uint32> allItems;
        for (int t = 1; t <= 6; ++t)
        {
            if (t == static_cast<int>(CollectionType::TOY))
                continue; // Toys are disabled
            auto items = LoadPlayerCollection(accountId, static_cast<CollectionType>(t));
            allItems.insert(allItems.end(), items.begin(), items.end());
        }

        uint32 serverHash = GenerateCollectionHash(allItems);
        bool needsSync = (serverHash != clientHash);

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_HANDSHAKE_ACK);
        msg.Set("serverHash", serverHash);
        msg.Set("needsSync", needsSync);
        msg.Set("totalItems", static_cast<uint32>(allItems.size()));

        msg.Send(player);
    }

    void SendFullCollection(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);

        // Build JSON object with all collection types
        DCAddon::JsonValue collections;
        collections.SetObject();

        // Load each collection type
        const char* typeNames[] = { "", "mounts", "pets", "toys", "heirlooms", "titles", "transmog" };

        for (int t = 1; t <= 6; ++t)
        {
            if (t == static_cast<int>(CollectionType::TOY))
                continue; // Toys are disabled
            auto items = LoadPlayerCollection(accountId, static_cast<CollectionType>(t));

            DCAddon::JsonValue arr;
            arr.SetArray();
            for (uint32 id : items)
            {
                arr.Push(DCAddon::JsonValue(id));
            }
            collections.Set(typeNames[t], arr);
        }

        // Load counts and totals for percentages
        auto counts = LoadCollectionCounts(accountId);
        auto totals = LoadTotalDefinitions();

        DCAddon::JsonValue stats;
        stats.SetObject();
        for (int t = 1; t <= 6; ++t)
        {
            if (t == static_cast<int>(CollectionType::TOY))
                continue; // Toys are disabled
            CollectionType type = static_cast<CollectionType>(t);
            uint32 owned = counts[type];
            uint32 total = totals[type];

            DCAddon::JsonValue typeStat;
            typeStat.SetObject();
            typeStat.Set("owned", owned);
            typeStat.Set("total", total);
            typeStat.Set("percent", total > 0 ? static_cast<double>(owned * 100) / total : 0.0);
            stats.Set(typeNames[t], typeStat);
        }

        // Mount speed bonus
        uint32 mountCount = counts[CollectionType::MOUNT];
        DCAddon::JsonValue bonuses;
        bonuses.SetObject();
        bonuses.Set("mountSpeedBonus", GetMountSpeedBonusPercent(mountCount));
        bonuses.Set("nextThreshold", GetNextMountThreshold(mountCount));
        bonuses.Set("mountsToNext", GetNextMountThreshold(mountCount) > 0 ?
            static_cast<int32>(GetNextMountThreshold(mountCount) - mountCount) : 0);

        // Compute hash
        std::vector<uint32> allItems;
        for (int t = 1; t <= 6; ++t)
        {
            if (t == static_cast<int>(CollectionType::TOY))
                continue; // Toys are disabled
            auto items = LoadPlayerCollection(accountId, static_cast<CollectionType>(t));
            allItems.insert(allItems.end(), items.begin(), items.end());
        }
        uint32 serverHash = GenerateCollectionHash(allItems);

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_FULL_COLLECTION);
        msg.Set("collections", collections);
        msg.Set("stats", stats);
        msg.Set("bonuses", bonuses);
        msg.Set("hash", serverHash);
        msg.Set("timestamp", static_cast<uint32>(std::time(nullptr)));

        msg.Send(player);
    }

    void SendStats(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);
        auto counts = LoadCollectionCounts(accountId);
        auto totals = LoadTotalDefinitions();

        const char* typeNames[] = { "", "mounts", "pets", "toys", "heirlooms", "titles", "transmog" };

        DCAddon::JsonValue stats;
        stats.SetObject();

        uint32 totalOwned = 0;
        uint32 totalAvailable = 0;

        for (int t = 1; t <= 6; ++t)
        {
            if (t == static_cast<int>(CollectionType::TOY))
                continue; // Toys are disabled
            CollectionType type = static_cast<CollectionType>(t);
            uint32 owned = counts[type];
            uint32 total = totals[type];
            totalOwned += owned;
            totalAvailable += total;

            DCAddon::JsonValue typeStat;
            typeStat.SetObject();
            typeStat.Set("owned", owned);
            typeStat.Set("total", total);
            typeStat.Set("percent", total > 0 ? static_cast<double>(owned * 100) / total : 0.0);
            stats.Set(typeNames[t], typeStat);
        }

        stats.Set("totalOwned", totalOwned);
        stats.Set("totalAvailable", totalAvailable);
        stats.Set("totalPercent", totalAvailable > 0 ?
            static_cast<double>(totalOwned * 100) / totalAvailable : 0.0);

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_STATS);
        msg.Set("stats", stats);

        msg.Send(player);
    }

    void SendBonuses(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);
        auto counts = LoadCollectionCounts(accountId);
        uint32 mountCount = counts[CollectionType::MOUNT];

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_BONUSES);
        msg.Set("mountSpeedBonus", GetMountSpeedBonusPercent(mountCount));
        msg.Set("mountCount", mountCount);
        msg.Set("nextThreshold", GetNextMountThreshold(mountCount));
        msg.Set("mountsToNext", GetNextMountThreshold(mountCount) > 0 ?
            static_cast<int32>(GetNextMountThreshold(mountCount) - mountCount) : 0);

        // Future bonuses can be added here
        msg.Set("petBonusActive", false);  // Placeholder for pet battle bonus
        msg.Set("toyBonusActive", false);  // Placeholder for toy cooldown reduction

        msg.Send(player);
    }

    void SendCurrencies(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        auto currencies = LoadCurrencies(player);

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_CURRENCIES);
        msg.Set("tokens", currencies[CURRENCY_TOKEN]);
        msg.Set("emblems", currencies[CURRENCY_EMBLEM]);

        msg.Send(player);
    }

    void SendShopData(Player* player, const std::string& category)
    {
        if (!player || !player->GetSession())
            return;

        if (!sConfigMgr->GetOption<bool>(Config::SHOP_ENABLED, true))
        {
            DCAddon::SendError(player, MODULE, "Shop is currently disabled",
                DCAddon::ErrorCode::MODULE_DISABLED, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        uint32 accountId = GetAccountId(player);

        // Query shop items based on category
        std::string query =
            "SELECT id, collection_type, entry_id, price_tokens, price_emblems, "
            "       discount_percent, available_until, stock_remaining, featured "
            "FROM dc_collection_shop "
            "WHERE enabled = 1 AND (available_from IS NULL OR available_from <= NOW()) "
            "  AND (available_until IS NULL OR available_until >= NOW()) "
            "  AND collection_type != 3";

        if (!category.empty() && category != "all")
        {
            uint8 typeId = 0;
            if (category == "mounts") typeId = 1;
            else if (category == "pets") typeId = 2;
            else if (category == "heirlooms") typeId = 4;
            else if (category == "titles") typeId = 5;
            else if (category == "transmog") typeId = 6;

            if (typeId > 0)
                query += " AND collection_type = " + std::to_string(typeId);
        }

        query += " ORDER BY featured DESC, id ASC LIMIT 100";

        QueryResult result = WorldDatabase.Query(query);

        DCAddon::JsonValue items;
        items.SetArray();

        if (result)
        {
            // Get player's owned items to mark as owned
            std::unordered_set<std::string> ownedItems;
            for (int t = 1; t <= 6; ++t)
            {
                if (t == static_cast<int>(CollectionType::TOY))
                    continue; // Toys are disabled
                auto owned = LoadPlayerCollection(accountId, static_cast<CollectionType>(t));
                for (uint32 id : owned)
                {
                    ownedItems.insert(std::to_string(t) + "_" + std::to_string(id));
                }
            }

            do
            {
                Field* fields = result->Fetch();

                uint32 shopId = fields[0].Get<uint32>();
                uint8 collType = fields[1].Get<uint8>();
                uint32 entryId = fields[2].Get<uint32>();
                uint32 priceTokens = fields[3].Get<uint32>();
                uint32 priceEmblems = fields[4].Get<uint32>();
                uint8 discount = fields[5].Get<uint8>();
                // fields[6] = available_until (can be null)
                int32 stock = fields[7].IsNull() ? -1 : fields[7].Get<int32>();
                bool featured = fields[8].Get<bool>();

                uint32 ownedEntryId = entryId;
                uint32 appearanceId = 0;
                uint32 itemId = 0;
                if (collType == static_cast<uint8>(CollectionType::TRANSMOG))
                {
                    // Try entryId as itemId
                    QueryResult itemRes = WorldDatabase.Query(
                        "SELECT displayid FROM item_template WHERE entry = {}",
                        entryId);

                    if (itemRes)
                    {
                        Field* itemFields = itemRes->Fetch();
                        appearanceId = itemFields[0].Get<uint32>();
                        itemId = entryId;
                    }
                    else
                    {
                        // Treat entryId as displayId
                        appearanceId = entryId;
                        auto const& appearances = GetTransmogAppearanceMapCached();
                        auto it = appearances.find(appearanceId);
                        if (it != appearances.end())
                            itemId = it->second.canonicalItemId;
                    }

                    ownedEntryId = appearanceId;
                }

                std::string key = std::to_string(collType) + "_" + std::to_string(ownedEntryId);
                bool owned = ownedItems.count(key) > 0;

                // Resolve name and icon for the shop item
                std::string itemName;
                std::string itemIcon;
                uint32 itemRarity = 2; // Default to uncommon

                switch (static_cast<CollectionType>(collType))
                {
                    case CollectionType::MOUNT:
                    {
                        // Mounts use spell data
                        if (SpellInfo const* spell = sSpellMgr->GetSpellInfo(entryId))
                        {
                            itemName = spell->SpellName[0]; // English locale
                            // Spell icons are stored as client texture IDs; client can use GetSpellTexture
                            itemIcon = std::to_string(spell->SpellIconID);
                        }
                        break;
                    }
                    case CollectionType::PET:
                    {
                        // Pets are usually items that teach a pet spell
                        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entryId))
                        {
                            itemName = proto->Name1;
                            itemIcon = std::to_string(proto->DisplayInfoID);
                            itemRarity = proto->Quality;
                        }
                        break;
                    }
                    case CollectionType::HEIRLOOM:
                    {
                        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entryId))
                        {
                            itemName = proto->Name1;
                            itemIcon = std::to_string(proto->DisplayInfoID);
                            itemRarity = proto->Quality;
                        }
                        break;
                    }
                    case CollectionType::TITLE:
                    {
                        if (CharTitlesEntry const* title = sCharTitlesStore.LookupEntry(entryId))
                        {
                            itemName = title->nameMale[0]; // English locale
                        }
                        itemIcon = ""; // Titles don't have icons; client uses static icon
                        break;
                    }
                    case CollectionType::TRANSMOG:
                    {
                        uint32 lookupItemId = itemId ? itemId : entryId;
                        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(lookupItemId))
                        {
                            itemName = proto->Name1;
                            itemIcon = std::to_string(proto->DisplayInfoID);
                            itemRarity = proto->Quality;
                        }
                        break;
                    }
                    default:
                        break;
                }

                DCAddon::JsonValue item;
                item.SetObject();
                item.Set("shopId", shopId);
                item.Set("type", collType);
                item.Set("entryId", entryId);
                item.Set("name", itemName);
                item.Set("icon", itemIcon);
                item.Set("rarity", itemRarity);
                if (collType == static_cast<uint8>(CollectionType::TRANSMOG))
                {
                    item.Set("appearanceId", appearanceId);
                    item.Set("itemId", itemId);
                }
                item.Set("priceTokens", priceTokens);
                item.Set("priceEmblems", priceEmblems);
                item.Set("discount", discount);
                item.Set("stock", stock);
                item.Set("featured", featured);
                item.Set("owned", owned);

                items.Push(item);
            } while (result->NextRow());
        }

        // Get player currencies for display
        auto currencies = LoadCurrencies(player);

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_SHOP_DATA);
        msg.Set("items", items);
        msg.Set("category", category);
        msg.Set("tokens", currencies[CURRENCY_TOKEN]);
        msg.Set("emblems", currencies[CURRENCY_EMBLEM]);

        msg.Send(player);
    }

    void SendWishlistData(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        if (!sConfigMgr->GetOption<bool>(Config::WISHLIST_ENABLED, true))
        {
            DCAddon::SendError(player, MODULE, "Wishlist is currently disabled",
                DCAddon::ErrorCode::MODULE_DISABLED, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        uint32 accountId = GetAccountId(player);
        auto wishlist = LoadWishlist(accountId);

        DCAddon::JsonValue items;
        items.SetArray();

        for (auto const& [type, entryId] : wishlist)
        {
            DCAddon::JsonValue item;
            item.SetObject();
            item.Set("type", type);
            item.Set("entryId", entryId);
            items.Push(item);
        }

        uint32 maxItems = sConfigMgr->GetOption<uint32>(Config::WISHLIST_MAX_ITEMS, 25);

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_DATA);
        msg.Set("items", items);
        msg.Set("count", static_cast<uint32>(wishlist.size()));
        msg.Set("maxItems", maxItems);

        msg.Send(player);
    }

    void SendItemLearned(Player* player, CollectionType type, uint32 entryId)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_ITEM_LEARNED);
        msg.Set("type", static_cast<uint8>(type));
        msg.Set("entryId", entryId);

        msg.Send(player);

        // Check wishlist notification
        uint32 accountId = GetAccountId(player);
        if (IsOnWishlist(accountId, type, entryId))
        {
            DCAddon::JsonMessage wishMsg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_AVAILABLE);
            wishMsg.Set("type", static_cast<uint8>(type));
            wishMsg.Set("entryId", entryId);
            wishMsg.Set("message", "A wishlist item is now in your collection!");
            wishMsg.Send(player);

            // Remove from wishlist
            CharacterDatabase.Execute(
                "DELETE FROM dc_collection_wishlist WHERE account_id = {} AND collection_type = {} AND entry_id = {}",
                accountId, static_cast<uint8>(type), entryId);
        }
    }

    // =======================================================================
    // Handler Functions - Process Requests
    // =======================================================================

    void HandleBuyItem(Player* player, uint32 shopId)
    {
        if (!player || !player->GetSession())
            return;

        if (!sConfigMgr->GetOption<bool>(Config::SHOP_ENABLED, true))
        {
            DCAddon::SendError(player, MODULE, "Shop is currently disabled",
                DCAddon::ErrorCode::MODULE_DISABLED, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        uint32 accountId = GetAccountId(player);

        // Get shop item details
        QueryResult result = WorldDatabase.Query(
            "SELECT collection_type, entry_id, price_tokens, price_emblems, stock_remaining "
            "FROM dc_collection_shop WHERE id = {} AND enabled = 1",
            shopId);

        if (!result)
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Item not found or unavailable");
            msg.Send(player);
            return;
        }

        Field* fields = result->Fetch();
        uint8 collType = fields[0].Get<uint8>();
        uint32 entryId = fields[1].Get<uint32>();
        uint32 priceTokens = fields[2].Get<uint32>();
        uint32 priceEmblems = fields[3].Get<uint32>();
        int32 stock = fields[4].IsNull() ? -1 : fields[4].Get<int32>();

        uint32 purchasedEntryId = entryId;
        if (collType == static_cast<uint8>(CollectionType::TRANSMOG))
        {
            // Shop can be configured with itemId or appearanceId; always unlock by appearanceId
            QueryResult itemRes = WorldDatabase.Query(
                "SELECT displayid FROM item_template WHERE entry = {}",
                entryId);

            if (itemRes)
            {
                Field* itemFields = itemRes->Fetch();
                purchasedEntryId = itemFields[0].Get<uint32>();
            }
            else
            {
                purchasedEntryId = entryId;
                auto const& appearances = GetTransmogAppearanceMapCached();
                if (appearances.find(purchasedEntryId) == appearances.end())
                {
                    DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
                    msg.Set("success", false);
                    msg.Set("error", "Invalid transmog appearance");
                    msg.Send(player);
                    return;
                }
            }
        }

        // Check stock
        if (stock == 0)
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Item is out of stock");
            msg.Send(player);
            return;
        }

        // Check if already owned
        auto owned = LoadPlayerCollection(accountId, static_cast<CollectionType>(collType));
        if (std::find(owned.begin(), owned.end(), purchasedEntryId) != owned.end())
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "You already own this item");
            msg.Send(player);
            return;
        }

        // Check currencies
        auto currencies = LoadCurrencies(player);
        if (currencies[CURRENCY_TOKEN] < priceTokens || currencies[CURRENCY_EMBLEM] < priceEmblems)
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Insufficient currency");
            msg.Send(player);
            return;
        }

        // Deduct currencies using the shared ItemUpgrade currency implementation.
        DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!mgr)
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Currency system unavailable");
            msg.Send(player);
            return;
        }

        uint32 playerGuid = player->GetGUID().GetCounter();
        uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();

        if (priceTokens > 0 && !mgr->RemoveCurrency(playerGuid, DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN, priceTokens, season))
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Insufficient currency");
            msg.Send(player);
            return;
        }

        if (priceEmblems > 0 && !mgr->RemoveCurrency(playerGuid, DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE, priceEmblems, season))
        {
            if (priceTokens > 0)
            mgr->AddCurrency(playerGuid, DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN, priceTokens, season);

            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Insufficient currency");
            msg.Send(player);
            return;
        }

        // Process purchase - use transaction for granting/recording
        auto trans = CharacterDatabase.BeginTransaction();

        // Add to collection
        trans->Append(
            "INSERT INTO dc_collection_items (account_id, collection_type, entry_id, source_type, source_id, unlocked, acquired_date) "
            "VALUES ({}, {}, {}, 'SHOP', {}, 1, NOW()) "
            "ON DUPLICATE KEY UPDATE unlocked = 1, acquired_date = NOW()",
            accountId, collType, purchasedEntryId, shopId);

        // Record purchase
        trans->Append(
            "INSERT INTO dc_collection_shop_purchases (account_id, shop_item_id, character_guid, price_tokens, price_emblems, purchase_date) "
            "VALUES ({}, {}, {}, {}, {}, NOW())",
            accountId, shopId, player->GetGUID().GetCounter(), priceTokens, priceEmblems);

        // Update stock if limited
        if (stock > 0)
        {
            WorldDatabase.Execute(
                "UPDATE dc_collection_shop SET stock_remaining = stock_remaining - 1 WHERE id = {}",
                shopId);
        }

        CharacterDatabase.CommitTransaction(trans);

        // Update mount speed bonus if mount was purchased
        if (collType == static_cast<uint8>(CollectionType::MOUNT))
        {
            UpdateMountSpeedBonus(player);
        }

        // Send success response
        auto newCurrencies = LoadCurrencies(player);

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
        msg.Set("success", true);
        msg.Set("type", collType);
        msg.Set("entryId", purchasedEntryId);
        msg.Set("tokens", newCurrencies[CURRENCY_TOKEN]);
        msg.Set("emblems", newCurrencies[CURRENCY_EMBLEM]);
        msg.Send(player);

        // Send item learned notification
        SendItemLearned(player, static_cast<CollectionType>(collType), purchasedEntryId);
    }

    void HandleAddWishlist(Player* player, uint8 type, uint32 entryId)
    {
        if (!player || !player->GetSession())
            return;

        if (!sConfigMgr->GetOption<bool>(Config::WISHLIST_ENABLED, true))
        {
            DCAddon::SendError(player, MODULE, "Wishlist is currently disabled",
                DCAddon::ErrorCode::MODULE_DISABLED, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        uint32 accountId = GetAccountId(player);
        uint32 maxItems = sConfigMgr->GetOption<uint32>(Config::WISHLIST_MAX_ITEMS, 25);

        // Check current count
        auto wishlist = LoadWishlist(accountId);
        if (wishlist.size() >= maxItems)
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
            msg.Set("success", false);
            msg.Set("error", "Wishlist is full (max " + std::to_string(maxItems) + " items)");
            msg.Send(player);
            return;
        }

        // Check if already on wishlist
        if (IsOnWishlist(accountId, static_cast<CollectionType>(type), entryId))
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
            msg.Set("success", false);
            msg.Set("error", "Item is already on your wishlist");
            msg.Send(player);
            return;
        }

        // Add to wishlist
        CharacterDatabase.Execute(
            "INSERT INTO dc_collection_wishlist (account_id, collection_type, entry_id, added_date) "
            "VALUES ({}, {}, {}, NOW())",
            accountId, type, entryId);

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
        msg.Set("success", true);
        msg.Set("action", "added");
        msg.Set("type", type);
        msg.Set("entryId", entryId);
        msg.Send(player);
    }

    void HandleRemoveWishlist(Player* player, uint8 type, uint32 entryId)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);

        CharacterDatabase.Execute(
            "DELETE FROM dc_collection_wishlist WHERE account_id = {} AND collection_type = {} AND entry_id = {}",
            accountId, type, entryId);

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
        msg.Set("success", true);
        msg.Set("action", "removed");
        msg.Set("type", type);
        msg.Set("entryId", entryId);
        msg.Send(player);
    }

    void HandleSetFavorite(Player* player, uint8 type, uint32 entryId, bool favorite)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);

        CharacterDatabase.Execute(
            "UPDATE dc_collection_items SET is_favorite = {} "
            "WHERE account_id = {} AND collection_type = {} AND entry_id = {}",
            favorite ? 1 : 0, accountId, type, entryId);

        // No response needed, client handles optimistically
    }

    // =======================================================================
    // Use Item Handlers (Summon Mount, Set Title, Summon Heirloom)
    // =======================================================================

    void HandleUseItemMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession())
            return;

        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        
        std::string typeStr = json.HasKey("type") ? json["type"].AsString() : "";
        uint32 entryId = json.HasKey("entryId") ? json["entryId"].AsUInt32() : 0;
        bool random = json.HasKey("random") && json["random"].AsBool();

        uint8 typeId = 0;
        if (typeStr == "mount" || typeStr == "mounts") typeId = static_cast<uint8>(CollectionType::MOUNT);
        else if (typeStr == "title" || typeStr == "titles") typeId = static_cast<uint8>(CollectionType::TITLE);
        else if (typeStr == "heirloom" || typeStr == "heirlooms") typeId = static_cast<uint8>(CollectionType::HEIRLOOM);
        else if (json.HasKey("type") && json["type"].IsNumber())
            typeId = static_cast<uint8>(json["type"].AsUInt32());

        switch (static_cast<CollectionType>(typeId))
        {
            case CollectionType::MOUNT:
                HandleSummonMount(player, entryId, random);
                break;
            case CollectionType::TITLE:
                HandleSetTitle(player, entryId);
                break;
            case CollectionType::HEIRLOOM:
                HandleSummonHeirloom(player, entryId);
                break;
            default:
                DCAddon::SendError(player, MODULE, "Unsupported collection type for use",
                    DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
                break;
        }
    }

    void HandleSummonMount(Player* player, uint32 spellId, bool random)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);

        if (random)
        {
            // Get all collected mounts for this account
            std::vector<uint32> mounts = LoadPlayerCollection(accountId, CollectionType::MOUNT);
            
            if (mounts.empty())
            {
                DCAddon::SendError(player, MODULE, "No mounts in collection",
                    DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
                return;
            }

            // Check config for favorites-only random
            bool favoritesOnly = sConfigMgr->GetOption<bool>("DCCollection.Mounts.RandomFavoritesOnly", false);
            if (favoritesOnly)
            {
                std::vector<uint32> favorites;
                QueryResult result = CharacterDatabase.Query(
                    "SELECT entry_id FROM dc_collection_items "
                    "WHERE account_id = {} AND collection_type = {} AND is_favorite = 1",
                    accountId, static_cast<uint8>(CollectionType::MOUNT));
                if (result)
                {
                    do
                    {
                        favorites.push_back(result->Fetch()[0].Get<uint32>());
                    } while (result->NextRow());
                }

                if (!favorites.empty())
                    mounts = favorites;
            }

            // Smart mount: prefer ground/flying mounts based on zone flyability
            bool smartMount = sConfigMgr->GetOption<bool>("DCCollection.Mounts.SmartMount", true);
            if (smartMount)
            {
                // Check if player can fly in current zone
                // Determine whether the player is allowed to fly in their current location
                bool canFly = player->canFlyInZone(player->GetMapId(), player->GetZoneId(), nullptr);

                // Mount types: 0=ground, 1=flying, 2=aquatic, 3=all
                // Filter mounts by type based on whether player can fly
                std::vector<uint32> filteredMounts;

                // Query mount types from definitions table
                std::string mountListStr;
                for (size_t i = 0; i < mounts.size(); ++i)
                {
                    if (i > 0)
                        mountListStr += ",";
                    mountListStr += std::to_string(mounts[i]);
                }

                if (!mountListStr.empty())
                {
                    QueryResult defResult = WorldDatabase.Query(
                        "SELECT spell_id, mount_type FROM dc_mount_definitions WHERE spell_id IN ({})",
                        mountListStr);
                    
                    std::unordered_map<uint32, uint8> mountTypes;
                    if (defResult)
                    {
                        do
                        {
                            Field* fields = defResult->Fetch();
                            uint32 mountSpellId = fields[0].Get<uint32>();
                            uint8 mountType = fields[1].Get<uint8>();
                            mountTypes[mountSpellId] = mountType;
                        } while (defResult->NextRow());
                    }

                    for (uint32 mountId : mounts)
                    {
                        auto it = mountTypes.find(mountId);
                        uint8 type = (it != mountTypes.end()) ? it->second : 3; // Default to "all" if not found

                        if (canFly)
                        {
                            // Prefer flying mounts (1) or all-terrain (3)
                            if (type == 1 || type == 3)
                                filteredMounts.push_back(mountId);
                        }
                        else
                        {
                            // Prefer ground mounts (0) or all-terrain (3)
                            if (type == 0 || type == 3)
                                filteredMounts.push_back(mountId);
                        }
                    }

                    // Fallback to all mounts if filtering resulted in empty list
                    if (!filteredMounts.empty())
                        mounts = filteredMounts;
                }
            }

            // Pick random mount
            spellId = mounts[urand(0, mounts.size() - 1)];
        }

        // Verify player owns this mount
        if (!HasCollectionItem(accountId, CollectionType::MOUNT, spellId))
        {
            DCAddon::SendError(player, MODULE, "Mount not in collection",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        // Check if player can cast (combat, moving, casting, arena, battleground start, etc.)
        if (player->IsInCombat())
        {
            DCAddon::SendError(player, MODULE, "Cannot summon mount in combat",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        if (player->HasUnitState(UNIT_STATE_CASTING))
        {
            DCAddon::SendError(player, MODULE, "Cannot summon mount while casting",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        if (player->IsMounted())
        {
            // Dismount first
            player->RemoveAurasByType(SPELL_AURA_MOUNTED);
        }

        // Prevent mounting while inside arena matches
        if (player->InArena())
        {
            DCAddon::SendError(player, MODULE, "Cannot summon mount in arena",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        // Check if player is in a battleground that hasn't started
        if (Battleground* bg = player->GetBattleground())
        {
            if (bg->GetStatus() != STATUS_IN_PROGRESS)
            {
                DCAddon::SendError(player, MODULE, "Cannot summon mount yet",
                    DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
                return;
            }
        }

        // Check if indoors (non-flyable)
        if (!player->IsOutdoors())
        {
            // Check if mount is ground-capable
            QueryResult typeRes = WorldDatabase.Query(
                "SELECT mount_type FROM dc_mount_definitions WHERE spell_id = {}",
                spellId);
            if (typeRes)
            {
                uint8 mountType = typeRes->Fetch()[0].Get<uint8>();
                // type 1 = flying only
                if (mountType == 1)
                {
                    DCAddon::SendError(player, MODULE, "Cannot use flying mount indoors",
                        DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
                    return;
                }
            }
        }

        // Cast the mount spell with triggered=false for normal cast time and interrupt checks
        player->CastSpell(player, spellId, false);

        // Update usage counter
        CharacterDatabase.Execute(
            "UPDATE dc_collection_items SET times_used = times_used + 1 "
            "WHERE account_id = {} AND collection_type = {} AND entry_id = {}",
            accountId, static_cast<uint8>(CollectionType::MOUNT), spellId);
    }

    void HandleSetTitle(Player* player, uint32 titleId)
    {
        if (!player || !player->GetSession())
            return;

        // titleId = 0 means clear title
        if (titleId == 0)
        {
            player->SetTitle(nullptr);
            return;
        }

        uint32 accountId = GetAccountId(player);

        // Verify player owns this title
        if (!HasCollectionItem(accountId, CollectionType::TITLE, titleId))
        {
            DCAddon::SendError(player, MODULE, "Title not in collection",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        // Get title from DBC
        CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(titleId);
        if (!titleEntry)
        {
            DCAddon::SendError(player, MODULE, "Invalid title ID",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        // Make sure player has the title bit set
        if (!player->HasTitle(titleEntry))
        {
            player->SetTitle(titleEntry, false);  // Grant the title
        }

        // Set as active title (chosenTitle is the bit index)
        player->SetUInt32Value(PLAYER_CHOSEN_TITLE, titleEntry->bit_index);
    }

    void HandleSummonHeirloom(Player* player, uint32 itemId)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);

        // Verify player owns this heirloom
        if (!HasCollectionItem(accountId, CollectionType::HEIRLOOM, itemId))
        {
            DCAddon::SendError(player, MODULE, "Heirloom not in collection",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        // Check if player has bag space
        ItemPosCountVec dest;
        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1);
        if (msg != EQUIP_ERR_OK)
        {
            DCAddon::SendError(player, MODULE, "No bag space available",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        // Create and add the item
        if (Item* item = player->StoreNewItem(dest, itemId, true))
        {
            player->SendNewItem(item, 1, true, false);
        }
    }

    // =======================================================================
    // Message Handlers
    // =======================================================================

    void HandleHandshake(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
        {
            SendHandshakeAck(player, 0);
            return;
        }

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 clientHash = json["hash"].AsUInt32();

        SendHandshakeAck(player, clientHash);
    }

    void HandleGetFullCollection(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendFullCollection(player);
    }

    void HandleSyncCollection(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        // For delta sync, we just send the full collection for now
        // Future: Implement proper delta sync based on client's last known state
        SendFullCollection(player);
    }

    void HandleGetStats(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendStats(player);
    }

    void HandleGetBonuses(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendBonuses(player);
    }

    void HandleGetShop(Player* player, const DCAddon::ParsedMessage& msg)
    {
        std::string category = "all";

        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
            if (json.HasKey("category"))
                category = json["category"].AsString();
        }

        SendShopData(player, category);
    }

    void HandleBuyItemMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 shopId = json["shopId"].AsUInt32();

        HandleBuyItem(player, shopId);
    }

    void HandleGetCurrencies(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendCurrencies(player);
    }

    void HandleGetWishlist(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendWishlistData(player);
    }

    void HandleSetTransmogMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession())
            return;

        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint8 slot = static_cast<uint8>(json["slot"].AsUInt32());
        bool clear = json.HasKey("clear") ? json["clear"].AsBool() : false;
        uint32 displayId = json.HasKey("appearanceId") ? json["appearanceId"].AsUInt32() : 0;

        if (slot >= EQUIPMENT_SLOT_END)
        {
            DCAddon::SendError(player, MODULE, "Invalid slot",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        Item* equippedItem = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
        if (!equippedItem)
        {
            DCAddon::SendError(player, MODULE, "No item equipped in that slot",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        uint32 guid = player->GetGUID().GetCounter();
        uint32 accountId = GetAccountId(player);

        if (clear)
        {
            CharacterDatabase.Execute(
                "DELETE FROM dc_character_transmog WHERE guid = {} AND slot = {}",
                guid, static_cast<uint32>(slot));

            // Restore real appearance
            player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (slot * 2), equippedItem->GetEntry());
            SendTransmogState(player);
            return;
        }

        if (!displayId)
        {
            DCAddon::SendError(player, MODULE, "Missing appearanceId",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        if (!HasTransmogAppearanceUnlocked(accountId, displayId))
        {
            DCAddon::SendError(player, MODULE, "Appearance not collected",
                DCAddon::ErrorCode::PERMISSION_DENIED, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        auto const& appearances = GetTransmogAppearanceMapCached();
        auto it = appearances.find(displayId);
        if (it == appearances.end())
        {
            DCAddon::SendError(player, MODULE, "Unknown appearance",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        TransmogAppearanceDef const& appearance = it->second;

        ItemTemplate const* equippedProto = equippedItem->GetTemplate();
        if (!IsAppearanceCompatible(slot, equippedProto, appearance))
        {
            DCAddon::SendError(player, MODULE, "Appearance not compatible with equipped item",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        uint32 fakeEntry = appearance.canonicalItemId;
        CharacterDatabase.Execute(
            "REPLACE INTO dc_character_transmog (guid, slot, fake_entry, real_entry) VALUES ({}, {}, {}, {})",
            guid, static_cast<uint32>(slot), fakeEntry, equippedItem->GetEntry());

        // Apply immediately
        player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (slot * 2), fakeEntry);
        SendTransmogState(player);
    }

    // =======================================================================
    // Transmog Slot-Based UI Handlers (Transmogrification addon style)
    // =======================================================================

    // Map visual slot IDs (from Transmogrification addon) to equipment slot
    uint8 VisualSlotToEquipmentSlot(uint32 visualSlot)
    {
        switch (visualSlot)
        {
            case 283: return EQUIPMENT_SLOT_HEAD;       // PLAYER_VISIBLE_ITEM_1_ENTRYID
            case 287: return EQUIPMENT_SLOT_SHOULDERS;  // PLAYER_VISIBLE_ITEM_3_ENTRYID
            case 289: return EQUIPMENT_SLOT_BODY;      // PLAYER_VISIBLE_ITEM_4_ENTRYID (Shirt)
            case 291: return EQUIPMENT_SLOT_CHEST;      // PLAYER_VISIBLE_ITEM_5_ENTRYID
            case 293: return EQUIPMENT_SLOT_WAIST;      // PLAYER_VISIBLE_ITEM_6_ENTRYID
            case 295: return EQUIPMENT_SLOT_LEGS;       // PLAYER_VISIBLE_ITEM_7_ENTRYID
            case 297: return EQUIPMENT_SLOT_FEET;       // PLAYER_VISIBLE_ITEM_8_ENTRYID
            case 299: return EQUIPMENT_SLOT_WRISTS;     // PLAYER_VISIBLE_ITEM_9_ENTRYID
            case 301: return EQUIPMENT_SLOT_HANDS;      // PLAYER_VISIBLE_ITEM_10_ENTRYID
            case 311: return EQUIPMENT_SLOT_BACK;       // PLAYER_VISIBLE_ITEM_15_ENTRYID
            case 313: return EQUIPMENT_SLOT_MAINHAND;   // PLAYER_VISIBLE_ITEM_16_ENTRYID
            case 315: return EQUIPMENT_SLOT_OFFHAND;    // PLAYER_VISIBLE_ITEM_17_ENTRYID
            case 317: return EQUIPMENT_SLOT_RANGED;     // PLAYER_VISIBLE_ITEM_18_ENTRYID
            case 319: return EQUIPMENT_SLOT_TABARD;     // PLAYER_VISIBLE_ITEM_19_ENTRYID
            default:  return 255;  // Invalid
        }
    }

    // Get inventory types for a visual slot
    std::vector<uint32> GetInvTypesForVisualSlot(uint32 visualSlot)
    {
        switch (visualSlot)
        {
            case 283: return { INVTYPE_HEAD };                                    // Head
            case 287: return { INVTYPE_SHOULDERS };                               // Shoulder
            case 289: return { INVTYPE_BODY };                                    // Shirt
            case 291: return { INVTYPE_CHEST, INVTYPE_ROBE };                     // Chest
            case 293: return { INVTYPE_WAIST };                                   // Waist
            case 295: return { INVTYPE_LEGS };                                    // Legs
            case 297: return { INVTYPE_FEET };                                    // Feet
            case 299: return { INVTYPE_WRISTS };                                  // Wrist
            case 301: return { INVTYPE_HANDS };                                   // Hands
            case 311: return { INVTYPE_CLOAK };                                   // Back
            case 313: return { INVTYPE_WEAPON, INVTYPE_2HWEAPON, INVTYPE_WEAPONMAINHAND }; // Main Hand
            case 315: return { INVTYPE_WEAPON, INVTYPE_WEAPONOFFHAND, INVTYPE_SHIELD, INVTYPE_HOLDABLE, INVTYPE_2HWEAPON }; // Off Hand
            case 317: return { INVTYPE_RANGED, INVTYPE_RANGEDRIGHT, INVTYPE_THROWN, INVTYPE_RELIC }; // Ranged
            case 319: return { INVTYPE_TABARD };                                  // Tabard
            default:  return {};
        }
    }

    // Helper: Get collected appearances for a slot, optionally filtered by search
    std::vector<uint32> GetCollectedAppearancesForSlot(Player* player, uint32 visualSlot, std::string const& searchFilter = "")
    {
        if (!player)
            return {};

        uint32 accountId = GetAccountId(player);
        std::vector<uint32> invTypes = GetInvTypesForVisualSlot(visualSlot);
        if (invTypes.empty())
            return {};

        uint8 equipmentSlot = VisualSlotToEquipmentSlot(visualSlot);
        Item* equippedItem = (equipmentSlot < EQUIPMENT_SLOT_END) ?
            player->GetItemByPos(INVENTORY_SLOT_BAG_0, equipmentSlot) : nullptr;

        uint32 equippedClass = 0;
        uint32 equippedSubClass = 0;
        if (equippedItem)
        {
            ItemTemplate const* proto = equippedItem->GetTemplate();
            equippedClass = proto->Class;
            equippedSubClass = proto->SubClass;
        }

        // Lowercase search filter for case-insensitive matching
        std::string searchLower = searchFilter;
        std::transform(searchLower.begin(), searchLower.end(), searchLower.begin(), ::tolower);
        bool hasSearch = !searchLower.empty();

        auto const& appearances = GetTransmogAppearanceMapCached();
        std::vector<uint32> matchingItemIds;
        matchingItemIds.reserve(128);  // Pre-allocate for performance

        for (auto const& [displayId, def] : appearances)
        {
            // Check inventory type match
            bool invTypeMatch = false;
            for (uint32 invType : invTypes)
            {
                if (def.inventoryType == invType)
                {
                    invTypeMatch = true;
                    break;
                }
            }
            if (!invTypeMatch)
                continue;

            // If equipped item exists, check armor/weapon subclass match
            if (equippedItem && equippedClass == def.itemClass && equippedSubClass != def.itemSubClass)
                continue;

            // Apply search filter if provided
            if (hasSearch)
            {
                std::string nameLower = def.name;
                std::transform(nameLower.begin(), nameLower.end(), nameLower.begin(), ::tolower);
                if (nameLower.find(searchLower) == std::string::npos &&
                    std::to_string(displayId).find(searchFilter) == std::string::npos)
                    continue;
            }

            // Check if player owns this appearance
            if (HasTransmogAppearanceUnlocked(accountId, displayId))
            {
                matchingItemIds.push_back(def.canonicalItemId);
            }
        }

        return matchingItemIds;
    }

    // Helper: Build and send paginated transmog slot items response
    void SendTransmogSlotItemsResponse(Player* player, uint32 visualSlot, uint32 page,
                                        std::vector<uint32> const& matchingItemIds,
                                        std::string const& searchFilter = "")
    {
        uint32 pageSize = 6;  // Match Eluna's SLOTS = 6
        uint32 totalCount = static_cast<uint32>(matchingItemIds.size());
        uint32 startIdx = (page > 0) ? (page - 1) * pageSize : 0;
        bool hasMore = (startIdx + pageSize) < totalCount;

        DCAddon::JsonValue items;
        items.SetArray();
        for (uint32 i = startIdx; i < totalCount && i < startIdx + pageSize; ++i)
        {
            items.Push(DCAddon::JsonValue(matchingItemIds[i]));
        }

        DCAddon::JsonMessage response(MODULE, DCAddon::Opcode::Collection::SMSG_TRANSMOG_SLOT_ITEMS);
        response.Set("slot", visualSlot);
        response.Set("page", page);
        response.Set("hasMore", hasMore);
        response.Set("items", items);
        response.Set("total", totalCount);
        if (!searchFilter.empty())
            response.Set("search", searchFilter);
        response.Send(player);
    }

    void HandleGetTransmogSlotItems(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession())
            return;

        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 visualSlot = json["slot"].AsUInt32();
        uint32 page = json.HasKey("page") ? json["page"].AsUInt32() : 1;

        uint8 equipmentSlot = VisualSlotToEquipmentSlot(visualSlot);
        if (equipmentSlot >= EQUIPMENT_SLOT_END && equipmentSlot != EQUIPMENT_SLOT_TABARD)
        {
            DCAddon::SendError(player, MODULE, "Invalid slot",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        // Use common helpers to get and send collected appearances
        std::vector<uint32> matchingItemIds = GetCollectedAppearancesForSlot(player, visualSlot, "");
        SendTransmogSlotItemsResponse(player, visualSlot, page, matchingItemIds);
    }

    void HandleSearchTransmogItems(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession())
            return;

        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 visualSlot = json["slot"].AsUInt32();
        std::string search = json.HasKey("search") ? json["search"].AsString() : "";
        uint32 page = json.HasKey("page") ? json["page"].AsUInt32() : 1;

        // Use common helpers - empty search is treated as no filter
        std::vector<uint32> matchingItemIds = GetCollectedAppearancesForSlot(player, visualSlot, search);
        SendTransmogSlotItemsResponse(player, visualSlot, page, matchingItemIds, search);
    }

    void HandleGetCollectedAppearances(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);

        // Get all collected transmog displayIds
        std::vector<uint32> collectedDisplayIds = LoadPlayerCollection(accountId, CollectionType::TRANSMOG);

        // Also get all items that share these displayIds for tooltip support
        DCAddon::JsonValue items;
        items.SetArray();

        auto const& appearances = GetTransmogAppearanceMapCached();
        for (uint32 displayId : collectedDisplayIds)
        {
            auto it = appearances.find(displayId);
            if (it != appearances.end())
            {
                items.Push(DCAddon::JsonValue(it->second.canonicalItemId));
            }
        }

        DCAddon::JsonMessage response(MODULE, DCAddon::Opcode::Collection::SMSG_COLLECTED_APPEARANCES);
        response.Set("count", static_cast<uint32>(collectedDisplayIds.size()));
        response.Set("items", items);
        response.Send(player);
    }

    void HandleGetTransmogState(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendTransmogState(player);
    }

    void HandleApplyTransmogPreview(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession())
            return;

        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.HasKey("preview") || !json["preview"].IsObject())
        {
            DCAddon::SendError(player, MODULE, "Missing preview data",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        DCAddon::JsonValue preview = json["preview"];
        uint32 accountId = GetAccountId(player);
        uint32 guid = player->GetGUID().GetCounter();
        auto const& appearances = GetTransmogAppearanceMapCached();

        // Process each slot in the preview
        for (auto const& kv : preview.AsObject())
        {
            auto const& key = kv.first;
            uint32 visualSlot = std::stoul(key);
            uint8 equipmentSlot = VisualSlotToEquipmentSlot(visualSlot);

            if (equipmentSlot >= EQUIPMENT_SLOT_END)
                continue;

            Item* equippedItem = player->GetItemByPos(INVENTORY_SLOT_BAG_0, equipmentSlot);
            if (!equippedItem)
                continue;

            DCAddon::JsonValue const& slotValue = kv.second;
            
            if (slotValue.IsNull())
            {
                // Clear/restore transmog
                CharacterDatabase.Execute(
                    "DELETE FROM dc_character_transmog WHERE guid = {} AND slot = {}",
                    guid, static_cast<uint32>(equipmentSlot));
                player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (equipmentSlot * 2), equippedItem->GetEntry());
            }
            else if (slotValue.AsUInt32() == 0)
            {
                // Hide item (set to 0)
                CharacterDatabase.Execute(
                    "REPLACE INTO dc_character_transmog (guid, slot, fake_entry, real_entry) VALUES ({}, {}, 0, {})",
                    guid, static_cast<uint32>(equipmentSlot), equippedItem->GetEntry());
                player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (equipmentSlot * 2), 0);
            }
            else
            {
                uint32 itemId = slotValue.AsUInt32();
                ItemTemplate const* fakeProto = sObjectMgr->GetItemTemplate(itemId);
                if (!fakeProto)
                    continue;

                uint32 displayId = fakeProto->DisplayInfoID;
                if (!HasTransmogAppearanceUnlocked(accountId, displayId))
                    continue;

                auto it = appearances.find(displayId);
                if (it == appearances.end())
                    continue;

                ItemTemplate const* equippedProto = equippedItem->GetTemplate();
                if (!IsAppearanceCompatible(equipmentSlot, equippedProto, it->second))
                    continue;

                CharacterDatabase.Execute(
                    "REPLACE INTO dc_character_transmog (guid, slot, fake_entry, real_entry) VALUES ({}, {}, {}, {})",
                    guid, static_cast<uint32>(equipmentSlot), itemId, equippedItem->GetEntry());
                player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (equipmentSlot * 2), itemId);
            }
        }

        SendTransmogState(player);
    }

    // =======================================================================
    // Definitions / Per-Type Sync
    // =======================================================================

    void SendDefinitions(Player* player, uint8 type, uint32 offset = 0, uint32 limit = 0)
    {
        if (!player || !player->GetSession())
            return;

        auto const looksLikeJson = [](std::string const& s) -> bool
        {
            size_t i = s.find_first_not_of(" \t\r\n");
            if (i == std::string::npos)
                return false;
            return s[i] == '{' || s[i] == '[';
        };

        auto const parseSourceValue = [&](std::string const& sourceStr) -> DCAddon::JsonValue
        {
            if (!looksLikeJson(sourceStr))
                return DCAddon::JsonValue(sourceStr);

            DCAddon::JsonValue parsed = DCAddon::JsonParser::Parse(sourceStr);
            if (parsed.IsObject() || parsed.IsArray())
                return parsed;

            return DCAddon::JsonValue(sourceStr);
        };

        auto const isUnknownSource = [](DCAddon::JsonValue const& v) -> bool
        {
            if (!v.IsObject())
                return false;
            if (!v.HasKey("type"))
                return false;

            DCAddon::JsonValue const& t = v["type"];
            return t.IsString() && (t.AsString() == "unknown" || t.AsString() == "");
        };

        auto const buildSourceForItem = [&](uint32 itemId) -> DCAddon::JsonValue
        {
            DCAddon::JsonValue src;
            src.SetObject();
            src.Set("type", DCAddon::JsonValue("unknown"));
            if (itemId)
                src.Set("itemId", DCAddon::JsonValue(itemId));

            if (!itemId)
                return src;

            // Prefer boss drops.
            if (QueryResult r = WorldDatabase.Query(
                "SELECT ct.name, ct.entry, clt.Chance "
                "FROM creature_loot_template clt "
                "JOIN creature_template ct ON ct.lootid = clt.Entry "
                "WHERE clt.Item = {} AND (ct.rank >= 3 OR (ct.unit_flags & 32768) > 0) "
                "ORDER BY clt.Chance DESC LIMIT 1",
                itemId))
            {
                Field* f = r->Fetch();
                src.Set("type", DCAddon::JsonValue("drop"));
                src.Set("boss", DCAddon::JsonValue(f[0].Get<std::string>()));
                src.Set("creatureEntry", DCAddon::JsonValue(f[1].Get<uint32>()));
                src.Set("dropRate", DCAddon::JsonValue(f[2].Get<float>()));
                return src;
            }

            // Vendors.
            if (QueryResult r = WorldDatabase.Query(
                "SELECT ct.name, ct.entry "
                "FROM npc_vendor nv "
                "JOIN creature_template ct ON ct.entry = nv.entry "
                "WHERE nv.item = {} LIMIT 1",
                itemId))
            {
                Field* f = r->Fetch();
                src.Set("type", DCAddon::JsonValue("vendor"));
                src.Set("npc", DCAddon::JsonValue(f[0].Get<std::string>()));
                src.Set("npcEntry", DCAddon::JsonValue(f[1].Get<uint32>()));
                return src;
            }

            // Quest rewards.
            if (QueryResult r = WorldDatabase.Query(
                "SELECT ID FROM quest_template WHERE "
                "RewardItem1 = {} OR RewardItem2 = {} OR RewardItem3 = {} OR RewardItem4 = {} OR "
                "RewardChoiceItemID1 = {} OR RewardChoiceItemID2 = {} OR RewardChoiceItemID3 = {} OR "
                "RewardChoiceItemID4 = {} OR RewardChoiceItemID5 = {} OR RewardChoiceItemID6 = {} "
                "LIMIT 1",
                itemId, itemId, itemId, itemId,
                itemId, itemId, itemId, itemId, itemId, itemId))
            {
                Field* f = r->Fetch();
                src.Set("type", DCAddon::JsonValue("quest"));
                src.Set("questId", DCAddon::JsonValue(f[0].Get<uint32>()));
                return src;
            }

            // Any creature drop.
            if (QueryResult r = WorldDatabase.Query(
                "SELECT ct.name, ct.entry, clt.Chance "
                "FROM creature_loot_template clt "
                "JOIN creature_template ct ON ct.lootid = clt.Entry "
                "WHERE clt.Item = {} "
                "ORDER BY clt.Chance DESC LIMIT 1",
                itemId))
            {
                Field* f = r->Fetch();
                src.Set("type", DCAddon::JsonValue("drop"));
                src.Set("boss", DCAddon::JsonValue(f[0].Get<std::string>()));
                src.Set("creatureEntry", DCAddon::JsonValue(f[1].Get<uint32>()));
                src.Set("dropRate", DCAddon::JsonValue(f[2].Get<float>()));
                return src;
            }

            return src;
        };

        // Cache expensive worlddb lookups by itemId across requests.
        auto const buildSourceForItemCached = [&](uint32 itemId) -> DCAddon::JsonValue
        {
            if (!itemId)
                return buildSourceForItem(itemId);

            static std::unordered_map<uint32, DCAddon::JsonValue> cache;
            auto it = cache.find(itemId);
            if (it != cache.end())
                return it->second;

            DCAddon::JsonValue v = buildSourceForItem(itemId);
            cache.emplace(itemId, v);
            return v;
        };

        std::string typeName;
        switch (static_cast<CollectionType>(type))
        {
            case CollectionType::MOUNT: typeName = "mounts"; break;
            case CollectionType::PET: typeName = "pets"; break;
            case CollectionType::TOY: typeName = "toys"; break;
            case CollectionType::HEIRLOOM: typeName = "heirlooms"; break;
            case CollectionType::TITLE: typeName = "titles"; break;
            case CollectionType::TRANSMOG: typeName = "transmog"; break;
            default: typeName = "unknown"; break;
        }

        DCAddon::JsonValue defs;
        defs.SetObject();

        if (static_cast<CollectionType>(type) == CollectionType::TRANSMOG)
        {
            auto const& appearanceMap = GetTransmogAppearanceMapCached();
            auto const& keys = GetTransmogAppearanceKeysCached();

            if (limit == 0)
                limit = 200;

            uint32 total = static_cast<uint32>(keys.size());
            if (offset > total)
                offset = total;

            uint32 end = std::min<uint32>(total, offset + limit);
            for (uint32 i = offset; i < end; ++i)
            {
                uint32 displayId = keys[i];
                auto it = appearanceMap.find(displayId);
                if (it == appearanceMap.end())
                    continue;

                auto const& def = it->second;
                DCAddon::JsonValue d;
                d.SetObject();
                d.Set("itemId", def.canonicalItemId);
                d.Set("name", def.name);
                d.Set("rarity", def.quality);
                d.Set("inventoryType", def.inventoryType);
                d.Set("weaponType", def.itemClass == ITEM_CLASS_WEAPON ? def.itemSubClass : 0);
                d.Set("armorType", def.itemClass == ITEM_CLASS_ARMOR ? def.itemSubClass : 0);
                d.Set("displayId", def.displayId);
                d.Set("source", buildSourceForItemCached(def.canonicalItemId));
                defs.Set(std::to_string(displayId), d);
            }

            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_DEFINITIONS);
            msg.Set("type", typeName);
            msg.Set("definitions", defs);
            msg.Set("syncVersion", 1);
            msg.Set("offset", offset);
            msg.Set("limit", limit);
            msg.Set("total", total);
            msg.Set("more", end < total);
            msg.Send(player);
            return;
        }

        // Non-transmog: try curated per-type tables first; fall back to the generic index; fall back to owned-only.
        CollectionType ct = static_cast<CollectionType>(type);

        auto addDef = [&](uint32 id, std::string const& name, std::string const& icon, uint32 rarity, std::string const& source, int32 extraType, uint32 itemIdForSource = 0)
        {
            DCAddon::JsonValue d;
            d.SetObject();
            if (!name.empty())
                d.Set("name", name);
            if (!icon.empty())
                d.Set("icon", icon);
            if (rarity)
                d.Set("rarity", rarity);

            if (!source.empty())
            {
                DCAddon::JsonValue srcVal = parseSourceValue(source);
                if (isUnknownSource(srcVal) && itemIdForSource)
                    srcVal = buildSourceForItemCached(itemIdForSource);
                d.Set("source", srcVal);
            }
            else if (itemIdForSource)
            {
                d.Set("source", buildSourceForItemCached(itemIdForSource));
            }

            // Some client modules sort on mountType.
            if (ct == CollectionType::MOUNT && extraType >= 0)
                d.Set("mountType", static_cast<uint32>(extraType));

            defs.Set(std::to_string(id), d);
        };

        bool loadedAny = false;

        if (ct == CollectionType::MOUNT && WorldTableExists("dc_mount_definitions"))
        {
            QueryResult r = WorldDatabase.Query(
                "SELECT md.spell_id, md.name, md.icon, md.rarity, md.mount_type, md.source, "
                "(SELECT MIN(i.entry) FROM item_template i "
                " WHERE i.class = 15 AND i.subclass = 5 AND (" 
                "   i.spellid_1 = md.spell_id OR i.spellid_2 = md.spell_id OR i.spellid_3 = md.spell_id OR "
                "   i.spellid_4 = md.spell_id OR i.spellid_5 = md.spell_id" 
                ")) AS item_id "
                "FROM dc_mount_definitions md");
            if (r)
            {
                do
                {
                    Field* f = r->Fetch();

                    uint32 spellId = f[0].Get<uint32>();
                    std::string name = f[1].Get<std::string>();
                    std::string icon = f[2].Get<std::string>();
                    uint32 rarity = f[3].Get<uint32>();
                    int32 mountType = f[4].Get<int32>();
                    std::string source = f[5].Get<std::string>();
                    uint32 itemId = f[6].Get<uint32>();

                    // Get mount displayId from spell data
                    uint32 displayId = 0;
                    if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId))
                    {
                        // Mount spells typically use effect SPELL_EFFECT_APPLY_AURA with SPELL_AURA_MOUNTED
                        // The mount displayId is stored in MiscValue or EffectMiscValue
                        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                        {
                            if (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED)
                            {
                                displayId = spellInfo->Effects[i].MiscValue;
                                break;
                            }
                        }
                    }

                    DCAddon::JsonValue d;
                    d.SetObject();
                    if (!name.empty())
                        d.Set("name", name);
                    if (!icon.empty())
                        d.Set("icon", icon);
                    if (rarity)
                        d.Set("rarity", rarity);
                    if (displayId > 0)
                        d.Set("displayId", displayId);
                    {
                        if (!source.empty())
                        {
                            DCAddon::JsonValue srcVal = parseSourceValue(source);
                            if (isUnknownSource(srcVal) && itemId)
                                srcVal = buildSourceForItem(itemId);
                            d.Set("source", srcVal);
                        }
                        else if (itemId)
                        {
                            d.Set("source", buildSourceForItem(itemId));
                        }
                    }
                    if (mountType >= 0)
                        d.Set("mountType", static_cast<uint32>(mountType));
                    if (itemId)
                        d.Set("itemId", itemId);

                    defs.Set(std::to_string(spellId), d);
                    loadedAny = true;
                } while (r->NextRow());
            }
        }
        else if (ct == CollectionType::PET && WorldTableExists("dc_pet_definitions"))
        {
            QueryResult r = WorldDatabase.Query(
                "SELECT pet_entry, name, icon, rarity, source FROM dc_pet_definitions");
            if (r)
            {
                do
                {
                    Field* f = r->Fetch();

                    uint32 itemId = f[0].Get<uint32>();
                    addDef(
                        itemId,
                        f[1].Get<std::string>(),
                        f[2].Get<std::string>(),
                        f[3].Get<uint32>(),
                        f[4].Get<std::string>(),
                        -1,
                        itemId);
                    loadedAny = true;
                } while (r->NextRow());
            }
        }
        else if (ct == CollectionType::TOY && WorldTableExists("dc_toy_definitions"))
        {
            QueryResult r = WorldDatabase.Query(
                "SELECT item_id, name, icon, rarity, source FROM dc_toy_definitions");
            if (r)
            {
                do
                {
                    Field* f = r->Fetch();
                    uint32 itemId = f[0].Get<uint32>();
                    addDef(
                        itemId,
                        f[1].Get<std::string>(),
                        f[2].Get<std::string>(),
                        f[3].Get<uint32>(),
                        f[4].Get<std::string>(),
                        -1,
                        itemId);
                    loadedAny = true;
                } while (r->NextRow());
            }
        }
        else if (ct == CollectionType::HEIRLOOM && WorldTableExists("dc_heirloom_definitions"))
        {
            QueryResult r = WorldDatabase.Query(
                "SELECT item_id, name, icon FROM dc_heirloom_definitions");
            if (r)
            {
                do
                {
                    Field* f = r->Fetch();
                    uint32 itemId = f[0].Get<uint32>();
                    addDef(
                        itemId,
                        f[1].Get<std::string>(),
                        f[2].Get<std::string>(),
                        0,
                        std::string(),
                        -1,
                        itemId);
                    loadedAny = true;
                } while (r->NextRow());
            }
        }
        else if (ct == CollectionType::TITLE)
        {
            // Titles are available from DBC; send them all (lightweight).
            for (uint32 i = 1; i < sCharTitlesStore.GetNumRows(); ++i)
            {
                CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(i);
                if (!titleEntry)
                    continue;

                std::string name;
                if (titleEntry->nameMale[0])
                    name = titleEntry->nameMale[0];
                else if (titleEntry->nameFemale[0])
                    name = titleEntry->nameFemale[0];

                addDef(titleEntry->ID, name, std::string(), 0, std::string(), -1, 0);
                loadedAny = true;
            }
        }

        if (!loadedAny && WorldTableExists("dc_collection_definitions"))
        {
            QueryResult r = WorldDatabase.Query(
                "SELECT entry_id FROM dc_collection_definitions WHERE collection_type = {} AND enabled = 1",
                static_cast<uint8>(ct));

            if (r)
            {
                do
                {
                    uint32 entryId = r->Fetch()[0].Get<uint32>();
                    std::string name;

                    if (ct == CollectionType::MOUNT || ct == CollectionType::PET)
                    {
                        if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(entryId))
                        {
                            if (spellInfo->SpellName[0])
                                name = spellInfo->SpellName[0];
                        }
                    }
                    else if (ct == CollectionType::TOY || ct == CollectionType::HEIRLOOM)
                    {
                        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entryId))
                            name = proto->Name1;
                    }
                    else if (ct == CollectionType::TITLE)
                    {
                        if (CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(entryId))
                        {
                            if (titleEntry->nameMale[0])
                                name = titleEntry->nameMale[0];
                            else if (titleEntry->nameFemale[0])
                                name = titleEntry->nameFemale[0];
                        }
                    }

                    addDef(entryId, name, std::string(), 0, std::string(), -1);
                    loadedAny = true;
                } while (r->NextRow());
            }
        }

        if (!loadedAny)
        {
            // Last-resort: send definitions only for owned items so the UI isn't empty.
            uint32 accountId = GetAccountId(player);
            if (accountId)
            {
                auto owned = LoadPlayerCollection(accountId, ct);
                for (uint32 entryId : owned)
                {
                    std::string name;

                    if (ct == CollectionType::MOUNT || ct == CollectionType::PET)
                    {
                        if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(entryId))
                        {
                            if (spellInfo->SpellName[0])
                                name = spellInfo->SpellName[0];
                        }
                    }
                    else if (ct == CollectionType::TOY || ct == CollectionType::HEIRLOOM)
                    {
                        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entryId))
                            name = proto->Name1;
                    }
                    else if (ct == CollectionType::TITLE)
                    {
                        if (CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(entryId))
                        {
                            if (titleEntry->nameMale[0])
                                name = titleEntry->nameMale[0];
                            else if (titleEntry->nameFemale[0])
                                name = titleEntry->nameFemale[0];
                        }
                    }

                    addDef(entryId, name, std::string(), 0, std::string(), -1);
                }
            }
        }

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_DEFINITIONS);
        msg.Set("type", typeName);
        msg.Set("definitions", defs);
        msg.Set("syncVersion", 1);
        msg.Send(player);
    }

    // Send ItemSet definitions from ItemSet.dbc
    void SendItemSetDefinitions(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonValue defs;
        defs.SetObject();

        for (uint32 entryId = 0; entryId < sItemSetStore.GetNumRows(); ++entryId)
        {
            ItemSetEntry const* setEntry = sItemSetStore.LookupEntry(entryId);
            if (!setEntry)
                continue;

            // Get set name
            std::string name;
            if (setEntry->name[0])
                name = setEntry->name[0];

            if (name.empty())
                continue;

            // Build items array
            DCAddon::JsonValue itemsArr;
            itemsArr.SetArray();
            uint32 itemCount = 0;

            for (uint32 i = 0; i < MAX_ITEM_SET_ITEMS; ++i)
            {
                uint32 itemId = setEntry->itemId[i];
                if (itemId)
                {
                    itemsArr.Push(DCAddon::JsonValue(itemId));
                    ++itemCount;
                }
            }

            if (itemCount == 0)
                continue;

            // Get first item for icon
            uint32 firstItemId = setEntry->itemId[0];
            std::string icon;
            if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(firstItemId))
            {
                if (proto->DisplayInfoID)
                {
                    // We don't have easy icon access, client will use GetItemInfo
                }
            }

            DCAddon::JsonValue setDef;
            setDef.SetObject();
            setDef.Set("name", DCAddon::JsonValue(name));
            setDef.Set("items", itemsArr);
            if (setEntry->required_skill_id)
                setDef.Set("requiredSkill", DCAddon::JsonValue(setEntry->required_skill_id));
            if (setEntry->required_skill_value)
                setDef.Set("requiredSkillValue", DCAddon::JsonValue(setEntry->required_skill_value));

            defs.Set(std::to_string(entryId), setDef);
        }

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_DEFINITIONS);
        msg.Set("type", "itemSets");
        msg.Set("definitions", defs);
        msg.Set("syncVersion", 1);
        msg.Send(player);
    }

    void SendCollection(Player* player, uint8 type)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);
        if (!accountId)
            return;

        CollectionType ct = static_cast<CollectionType>(type);

        std::string typeName;
        switch (ct)
        {
            case CollectionType::MOUNT: typeName = "mounts"; break;
            case CollectionType::PET: typeName = "pets"; break;
            case CollectionType::TOY: typeName = "toys"; break;
            case CollectionType::HEIRLOOM: typeName = "heirlooms"; break;
            case CollectionType::TITLE: typeName = "titles"; break;
            case CollectionType::TRANSMOG: typeName = "transmog"; break;
            default: typeName = "unknown"; break;
        }

        // For client-side CacheMergeCollection we want an object map { id: { owned=true } }
        DCAddon::JsonValue items;
        items.SetObject();

        auto owned = LoadPlayerCollection(accountId, ct);
        for (uint32 id : owned)
        {
            DCAddon::JsonValue entry;
            entry.SetObject();
            entry.Set("owned", true);
            items.Set(std::to_string(id), entry);
        }

        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_COLLECTION);
        msg.Set("type", typeName);
        msg.Set("items", items);
        msg.Send(player);
    }

    void HandleGetDefinitionsMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        // Client sends collType string, but we accept either string or numeric.
        uint8 type = 0;
        uint32 offset = 0;
        uint32 limit = 0;

        if (json.HasKey("type"))
        {
            if (json["type"].IsString())
            {
                std::string t = json["type"].AsString();
                if (t == "mounts") type = static_cast<uint8>(CollectionType::MOUNT);
                else if (t == "pets") type = static_cast<uint8>(CollectionType::PET);
                else if (t == "heirlooms") type = static_cast<uint8>(CollectionType::HEIRLOOM);
                else if (t == "titles") type = static_cast<uint8>(CollectionType::TITLE);
                else if (t == "transmog") type = static_cast<uint8>(CollectionType::TRANSMOG);
                else if (t == "itemSets" || t == "sets") type = static_cast<uint8>(CollectionType::ITEM_SET);
            }
            else
            {
                type = static_cast<uint8>(json["type"].AsUInt32());
            }
        }

        if (json.HasKey("offset"))
            offset = json["offset"].AsUInt32();
        if (json.HasKey("limit"))
            limit = json["limit"].AsUInt32();

        // Handle itemSets separately (from DBC, not stored collection)
        if (type == static_cast<uint8>(CollectionType::ITEM_SET))
        {
            SendItemSetDefinitions(player);
            return;
        }

        if (type >= 1 && type <= 6 && type != static_cast<uint8>(CollectionType::TOY))
            SendDefinitions(player, type, offset, limit);
    }

    void HandleGetCollectionMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint8 type = 0;

        if (json.HasKey("type"))
        {
            if (json["type"].IsString())
            {
                std::string t = json["type"].AsString();
                if (t == "mounts") type = static_cast<uint8>(CollectionType::MOUNT);
                else if (t == "pets") type = static_cast<uint8>(CollectionType::PET);
                else if (t == "heirlooms") type = static_cast<uint8>(CollectionType::HEIRLOOM);
                else if (t == "titles") type = static_cast<uint8>(CollectionType::TITLE);
                else if (t == "transmog") type = static_cast<uint8>(CollectionType::TRANSMOG);
            }
            else
            {
                type = static_cast<uint8>(json["type"].AsUInt32());
            }
        }

        if (type >= 1 && type <= 6 && type != static_cast<uint8>(CollectionType::TOY))
            SendCollection(player, type);
    }

    void HandleAddWishlistMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint8 type = static_cast<uint8>(json["type"].AsUInt32());
        uint32 entryId = json["entryId"].AsUInt32();

        HandleAddWishlist(player, type, entryId);
    }

    void HandleRemoveWishlistMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint8 type = static_cast<uint8>(json["type"].AsUInt32());
        uint32 entryId = json["entryId"].AsUInt32();

        HandleRemoveWishlist(player, type, entryId);
    }

    void HandleSetFavoriteMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint8 type = static_cast<uint8>(json["type"].AsUInt32());
        uint32 entryId = json["entryId"].AsUInt32();
        bool favorite = json["favorite"].AsBool();

        HandleSetFavorite(player, type, entryId, favorite);
    }

    // =======================================================================
    // Player Event Hooks
    // =======================================================================

    class CollectionPlayerScript : public PlayerScript
    {
    public:
        CollectionPlayerScript() : PlayerScript("dc_collection_player") {}

        void OnPlayerLogin(Player* player) override
        {
            if (!sConfigMgr->GetOption<bool>(Config::ENABLED, true))
                return;

            // Seed account-wide collections from already-known mounts/pets/titles.
            ImportExistingCollections(player);

            // Apply mount speed bonus on login
            UpdateMountSpeedBonus(player);

            // Push current transmog state so the UI can show applied slots
            SendTransmogState(player);
        }

        void OnPlayerLearnSpell(Player* player, uint32 spellId) override
        {
            if (!sConfigMgr->GetOption<bool>(Config::ENABLED, true))
                return;

            // Check if this is a mount or pet spell
            // Auto-add to collection if it's a mount/pet
            const SpellInfo* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (!spellInfo)
                return;

            uint32 accountId = GetAccountId(player);
            if (!accountId)
                return;

            // Check for mount effect
            bool isMount = false;
            bool isPet = false;

            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                if (spellInfo->Effects[i].Effect == SPELL_EFFECT_APPLY_AURA &&
                    (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED ||
                     spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOD_INCREASE_MOUNTED_FLIGHT_SPEED))
                {
                    isMount = true;
                    break;
                }
                // Check for companion pet summon
                if (spellInfo->Effects[i].Effect == SPELL_EFFECT_SUMMON &&
                    spellInfo->Effects[i].MiscValueB == 0)  // Non-combat pet
                {
                    // Additional checks could be added here
                    isPet = true;
                }
            }

            if (isMount)
            {
                // Add mount to collection
                CharacterDatabase.Execute(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, entry_id, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'LEARNED', 1, NOW())",
                    accountId, static_cast<uint8>(CollectionType::MOUNT), spellId);

                SendItemLearned(player, CollectionType::MOUNT, spellId);
                UpdateMountSpeedBonus(player);
            }
            else if (isPet)
            {
                uint32 itemId = FindCompanionItemIdForSpell(spellId);
                if (!itemId)
                    return;

                CharacterDatabase.Execute(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, entry_id, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'LEARNED', 1, NOW())",
                    accountId, static_cast<uint8>(CollectionType::PET), itemId);

                SendItemLearned(player, CollectionType::PET, itemId);
            }
        }

        void OnPlayerAfterSetVisibleItemSlot(Player* player, uint8 slot, Item* item) override
        {
            // Apply transmog appearance by overriding the visible item entry.
            if (!player || !player->GetSession())
                return;

            // Only for equipment slots that use visible item fields.
            if (slot >= EQUIPMENT_SLOT_END)
                return;

            QueryResult result = CharacterDatabase.Query(
                "SELECT fake_entry, real_entry FROM dc_character_transmog WHERE guid = {} AND slot = {}",
                player->GetGUID().GetCounter(), static_cast<uint32>(slot));

            if (!result)
                return;

            Field* fields = result->Fetch();
            uint32 fakeEntry = fields[0].Get<uint32>();
            uint32 realEntry = fields[1].Get<uint32>();

            // If the currently equipped item changed, update real_entry and/or clear.
            uint32 currentEntry = item ? item->GetEntry() : 0;

            if (!currentEntry)
            {
                // Slot is empty; clear transmog for that slot.
                CharacterDatabase.Execute(
                    "DELETE FROM dc_character_transmog WHERE guid = {} AND slot = {}",
                    player->GetGUID().GetCounter(), static_cast<uint32>(slot));
                return;
            }

            // If equipped item changed, validate compatibility; clear if invalid.
            ItemTemplate const* equippedProto = item ? item->GetTemplate() : nullptr;
            ItemTemplate const* fakeProto = sObjectMgr->GetItemTemplate(fakeEntry);
            if (fakeEntry && fakeProto)
            {
                TransmogAppearanceDef appearance;
                appearance.canonicalItemId = fakeEntry;
                appearance.displayId = fakeProto->DisplayInfoID;
                appearance.inventoryType = fakeProto->InventoryType;
                appearance.itemClass = fakeProto->Class;
                appearance.itemSubClass = fakeProto->SubClass;
                appearance.quality = fakeProto->Quality;

                if (!IsAppearanceCompatible(slot, equippedProto, appearance))
                {
                    CharacterDatabase.Execute(
                        "DELETE FROM dc_character_transmog WHERE guid = {} AND slot = {}",
                        player->GetGUID().GetCounter(), static_cast<uint32>(slot));
                    return;
                }
            }

            if (currentEntry != realEntry)
            {
                // Equipped a different item than the one this transmog was applied to.
                // Keep the appearance but update the tracked real item.
                CharacterDatabase.Execute(
                    "UPDATE dc_character_transmog SET real_entry = {} WHERE guid = {} AND slot = {}",
                    currentEntry, player->GetGUID().GetCounter(), static_cast<uint32>(slot));
            }

            if (fakeEntry)
            {
                // Override visible entry ID field (slot uses PLAYER_VISIBLE_ITEM_1_ENTRYID + slot*2)
                player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (slot * 2), fakeEntry);
            }
        }

        void OnPlayerEquip(Player* player, Item* it, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
        {
            if (!player || !it)
                return;

            if (!sConfigMgr->GetOption<bool>(Config::ENABLED, true))
                return;

            ItemTemplate const* proto = it->GetTemplate();
            if (!proto)
                return;

            bool unlockOnEquip = sConfigMgr->GetOption<bool>(Config::TRANSMOG_UNLOCK_ON_EQUIP, false);
            bool unlockOnSoulbind = sConfigMgr->GetOption<bool>(Config::TRANSMOG_UNLOCK_ON_SOULBIND, false);

            if (unlockOnEquip)
                UnlockTransmogAppearance(player, proto, "EQUIPPED");

            if (unlockOnSoulbind && it->IsSoulBound())
                UnlockTransmogAppearance(player, proto, "SOULBOUND");
        }
    };

    class CollectionMiscScript : public MiscScript
    {
    public:
        CollectionMiscScript() : MiscScript("dc_collection_misc", { MISCHOOK_ON_ITEM_CREATE }) {}

        void OnItemCreate(Item* /*item*/, ItemTemplate const* itemProto, Player const* owner) override
        {
            if (!owner)
                return;

            Player* player = const_cast<Player*>(owner);

            if (!sConfigMgr->GetOption<bool>(Config::ENABLED, true))
                return;

            if (sConfigMgr->GetOption<bool>(Config::TRANSMOG_UNLOCK_ON_CREATE, true))
            {
                // Unlock transmog appearances for any created item (loot, craft, vendor, mail, etc.)
                UnlockTransmogAppearance(player, itemProto, "CREATED");
            }
        }
    };

    // =======================================================================
    // World Script for Configuration
    // =======================================================================

    class CollectionWorldScript : public WorldScript
    {
    public:
        CollectionWorldScript() : WorldScript("dc_collection_world") {}

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            // Register module as enabled/disabled based on config
            bool enabled = sConfigMgr->GetOption<bool>(Config::ENABLED, true);
            DCAddon::MessageRouter::Instance().SetModuleEnabled(MODULE, enabled);

            if (enabled)
            {
                LOG_INFO("module", "DC-Collection: Module enabled");
            }
        }
    };

}  // namespace DCCollection

// =======================================================================
// Script Registration
// =======================================================================

void AddSC_dc_addon_collection()
{
    using namespace DCCollection;
    using namespace DCAddon;

    // Register message handlers
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_HANDSHAKE, HandleHandshake);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_FULL_COLLECTION, HandleGetFullCollection);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_SYNC_COLLECTION, HandleSyncCollection);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_STATS, HandleGetStats);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_BONUSES, HandleGetBonuses);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_DEFINITIONS, HandleGetDefinitionsMessage);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_COLLECTION, HandleGetCollectionMessage);

    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_SHOP, HandleGetShop);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_BUY_ITEM, HandleBuyItemMessage);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_CURRENCIES, HandleGetCurrencies);

    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_WISHLIST, HandleGetWishlist);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_ADD_WISHLIST, HandleAddWishlistMessage);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_REMOVE_WISHLIST, HandleRemoveWishlistMessage);

    // Actions: Use item (summon mount, set title, summon heirloom)
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_USE_ITEM, HandleUseItemMessage);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_SET_FAVORITE, HandleSetFavoriteMessage);

    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_SET_TRANSMOG, HandleSetTransmogMessage);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_TRANSMOG_SLOT_ITEMS, HandleGetTransmogSlotItems);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_SEARCH_TRANSMOG_ITEMS, HandleSearchTransmogItems);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_COLLECTED_APPEARANCES, HandleGetCollectedAppearances);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_TRANSMOG_STATE, HandleGetTransmogState);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_APPLY_TRANSMOG_PREVIEW, HandleApplyTransmogPreview);

    // Register player and world scripts
    new CollectionPlayerScript();
    new CollectionMiscScript();
    new CollectionWorldScript();

    LOG_INFO("server.loading", ">> Loaded DC-Collection addon handler");
}
