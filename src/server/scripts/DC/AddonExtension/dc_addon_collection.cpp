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

#include "../../ScriptPCH.h"
#include "dc_addon_namespace.h"
#include "dc_addon_collection.h"

void AddSC_dc_addon_wardrobe(); // Forward declaration
#include "Config.h"
#include "World.h"
#include "SpellMgr.h"
#include "SpellAuras.h"
#include "Pet.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Bag.h"
#include "ScriptMgr.h"
#include "DBCStores.h"
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
#include <chrono>

namespace DCCollection
{
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
        constexpr const char* TRANSMOG_UNLOCK_ON_LOOT = "DCCollection.Transmog.UnlockOnLoot";
        constexpr const char* TRANSMOG_UNLOCK_ON_QUEST_REWARD = "DCCollection.Transmog.UnlockOnQuestReward";

        // Login scanning (automatic unlock from inventory/bank on login)
        constexpr const char* TRANSMOG_LOGIN_SCAN_ENABLED = "DCCollection.Transmog.LoginScan.Enable";
        constexpr const char* TRANSMOG_LOGIN_SCAN_INCLUDE_BANK = "DCCollection.Transmog.LoginScan.IncludeBank";

        // Session notification deduplication (prevent spam from multiple events)
        [[maybe_unused]] constexpr const char* TRANSMOG_SESSION_NOTIFICATION_DEDUP = "DCCollection.Transmog.SessionNotificationDedup";

        // Quality filtering
        [[maybe_unused]] constexpr const char* TRANSMOG_MIN_QUALITY = "DCCollection.Transmog.MinQuality";

        // Paging: number of transmog items returned per slot page.
        // Higher values reduce message spam; keep reasonable to avoid overly large addon payloads.
        [[maybe_unused]] constexpr const char* TRANSMOG_SLOT_ITEMS_PAGE_SIZE = "DCCollection.Transmog.SlotItemsPageSize";

        // Legacy import (scan items owned by old characters)
        constexpr const char* TRANSMOG_LEGACY_IMPORT_ENABLED = "DCCollection.Transmog.LegacyImport.Enable";
        constexpr const char* TRANSMOG_LEGACY_IMPORT_INCLUDE_BANK = "DCCollection.Transmog.LegacyImport.IncludeBank";
        constexpr const char* TRANSMOG_LEGACY_IMPORT_REQUIRE_SOULBOUND = "DCCollection.Transmog.LegacyImport.RequireSoulbound";

        // When enabled, characters will be granted the account-wide collection entries
        // (so mounts/companions/titles are usable in the default Blizzard UI).
        constexpr const char* SYNC_TO_CHARACTER_ON_LOGIN = "DCCollection.Accountwide.SyncToCharacterOnLogin";

        // Performance: defer + batch the login sync to avoid long synchronous work during the login handshake.
        constexpr const char* SYNC_TO_CHARACTER_DELAY_MS = "DCCollection.Accountwide.SyncToCharacterOnLogin.DelayMs";
        constexpr const char* SYNC_TO_CHARACTER_BATCH_SIZE = "DCCollection.Accountwide.SyncToCharacterOnLogin.BatchSize";
        constexpr const char* SYNC_TO_CHARACTER_BATCH_DELAY_MS = "DCCollection.Accountwide.SyncToCharacterOnLogin.BatchDelayMs";

        // Performance: learning many mount/pet spells can update a large amount of achievement criteria.
        // By default these are saved on logout, which can cause a noticeable delay.
        // When enabled, we flush achievement progress once the accountwide sync completes.
        constexpr const char* SYNC_TO_CHARACTER_FLUSH_ACHIEVEMENTS_ON_COMPLETE = "DCCollection.Accountwide.SyncToCharacterOnLogin.FlushAchievementsOnComplete";

        // Optional maintenance: rebuild dc_pet_definitions from local data (item_template + Spell/SummonProperties DBC).
        // This avoids relying on external sources and fixes incorrect placeholder pet_spell_id values.
        constexpr const char* PET_DEFINITIONS_REBUILD_ON_STARTUP = "DCCollection.Pets.RebuildDefinitionsOnStartup";
        constexpr const char* PET_DEFINITIONS_REBUILD_TRUNCATE = "DCCollection.Pets.RebuildDefinitionsOnStartup.Truncate";

        // When rebuilding, prefer pulling the item list from the DB with a WHERE filter (fast) instead
        // of iterating the full in-memory item_template store (~270k rows).
        constexpr const char* PET_DEFINITIONS_REBUILD_USE_DB_ITEM_FILTER = "DCCollection.Pets.RebuildDefinitionsOnStartup.UseDbItemFilter";

        // Optional: also include spell-only minipet summon spells (pet_entry = spellId) if no teaching item exists.
        // Disabled by default; iterates Spell.dbc which can add startup time.
        constexpr const char* PET_DEFINITIONS_REBUILD_INCLUDE_SPELL_ONLY = "DCCollection.Pets.RebuildDefinitionsOnStartup.IncludeSpellOnly";
    }


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
    // Mount count thresholds for speed bonuses
    constexpr uint32 MOUNT_THRESHOLD_TIER3 = 100;
    constexpr uint32 MOUNT_THRESHOLD_TIER4 = 200;

    // Forward declarations for helpers defined later in this file
    bool WorldTableExists(std::string const& tableName);
    bool WorldColumnExists(std::string const& tableName, std::string const& columnName);
    std::string const& GetWorldEntryColumn(std::string const& tableName);
    void HandleSummonMount(Player* player, uint32 entryId, bool random);
    void HandleSetTitle(Player* player, uint32 entryId);
    void HandleSummonHeirloom(Player* player, uint32 entryId);
    uint32 FindCompanionSpellIdForItem(uint32 itemId);
    
    uint32 FindCompanionItemIdForSpell(uint32 spellId)
    {
        // Static cache: spellId -> itemId mapping (0 means not found)
        static std::unordered_map<uint32, uint32> s_companionItemCache;
        [[maybe_unused]] static bool s_cacheInitialized = false;
        
        // Check cache first
        auto it = s_companionItemCache.find(spellId);
        if (it != s_companionItemCache.end())
            return it->second;
        
        // Companion pets in 3.3.5a are typically taught by item_template (class=15, subclass=2).
        QueryResult r = WorldDatabase.Query(
            "SELECT MIN(entry) FROM item_template "
            "WHERE class = 15 AND subclass = 2 AND ("
            "  spellid_1 = {} OR spellid_2 = {} OR spellid_3 = {} OR spellid_4 = {} OR spellid_5 = {}"
            ")",
            spellId, spellId, spellId, spellId, spellId);

        uint32 result = 0;
        if (r)
        {
            Field* f = r->Fetch();
            if (!f[0].IsNull())
                result = f[0].Get<uint32>();
        }
        
        // Cache the result (including 0 for "not found")
        s_companionItemCache[spellId] = result;
        return result;
    }

    uint32 FindMountItemIdForSpell(uint32 spellId)
    {
        // Static cache: spellId -> itemId mapping (0 means not found)
        static std::unordered_map<uint32, uint32> s_mountItemCache;
        
        // Check cache first
        auto it = s_mountItemCache.find(spellId);
        if (it != s_mountItemCache.end())
            return it->second;
        
        // Mounts are typically taught by item_template (class=15, subclass=5).
        QueryResult r = WorldDatabase.Query(
            "SELECT MIN(entry) FROM item_template "
            "WHERE class = 15 AND subclass = 5 AND ("
            "  spellid_1 = {} OR spellid_2 = {} OR spellid_3 = {} OR spellid_4 = {} OR spellid_5 = {}"
            ")",
            spellId, spellId, spellId, spellId, spellId);

        uint32 result = 0;
        if (r)
        {
            Field* f = r->Fetch();
            if (!f[0].IsNull())
                result = f[0].Get<uint32>();
        }
        
        // Cache the result (including 0 for "not found")
        s_mountItemCache[spellId] = result;
        return result;
    }

    bool IsCompanionSpell(SpellInfo const* spellInfo)
    {
        if (!spellInfo)
            return false;

        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
        {
            // WotLK non-combat pets can be summoned via SPELL_EFFECT_SUMMON or SPELL_EFFECT_SUMMON_PET
            // with SummonProperties Type = MINIPET.
            if (spellInfo->Effects[i].Effect != SPELL_EFFECT_SUMMON &&
                spellInfo->Effects[i].Effect != SPELL_EFFECT_SUMMON_PET)
                continue;

            SummonPropertiesEntry const* properties = sSummonPropertiesStore.LookupEntry(spellInfo->Effects[i].MiscValueB);
            if (properties && properties->Type == SUMMON_TYPE_MINIPET)
                return true;
        }
        return false;
    }

    uint32 ResolveCompanionSummonSpellFromSpell(uint32 spellId)
    {
        if (!spellId)
            return 0;

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
            return 0;

        if (IsCompanionSpell(spellInfo))
            return spellId;

        // Teaching spells: follow LEARN_* effects to the taught summon spell.
        for (uint8 eff = 0; eff < MAX_SPELL_EFFECTS; ++eff)
        {
            if (spellInfo->Effects[eff].Effect != SPELL_EFFECT_LEARN_SPELL &&
                spellInfo->Effects[eff].Effect != SPELL_EFFECT_LEARN_PET_SPELL)
                continue;

            uint32 taughtSpellId = spellInfo->Effects[eff].TriggerSpell;
            if (!taughtSpellId)
                continue;

            if (SpellInfo const* taughtInfo = sSpellMgr->GetSpellInfo(taughtSpellId))
            {
                if (IsCompanionSpell(taughtInfo))
                    return taughtSpellId;
            }
        }

        return 0;
    }

    void RebuildPetDefinitionsFromLocalData()
    {
        if (!WorldTableExists("dc_pet_definitions"))
        {
            LOG_WARN("module.dc", "DC-Collection: dc_pet_definitions missing; skipping pet definition rebuild.");
            return;
        }

        bool truncate = sConfigMgr->GetOption<bool>(Config::PET_DEFINITIONS_REBUILD_TRUNCATE, false);
        if (truncate)
        {
            WorldDatabase.Execute("TRUNCATE TABLE dc_pet_definitions");
        }

        uint32 insertedOrUpdated = 0;
        uint32 skippedNoSpell = 0;
        uint32 spellOnlyInsertedOrUpdated = 0;

        auto rebuildFromItemId = [&](uint32 itemId)
        {
            if (!itemId)
                return;

            ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
            if (!itemTemplate)
                return;

            if (itemTemplate->Class != 15 || itemTemplate->SubClass != 2)
                return;

            uint32 summonSpellId = FindCompanionSpellIdForItem(itemId);
            if (!summonSpellId)
            {
                ++skippedNoSpell;
                return;
            }

            uint32 creatureId = 0;
            uint32 displayId = 0;
            if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(summonSpellId))
            {
                for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                {
                    if (spellInfo->Effects[i].Effect != SPELL_EFFECT_SUMMON &&
                        spellInfo->Effects[i].Effect != SPELL_EFFECT_SUMMON_PET)
                        continue;

                    SummonPropertiesEntry const* properties = sSummonPropertiesStore.LookupEntry(spellInfo->Effects[i].MiscValueB);
                    if (!properties || properties->Type != SUMMON_TYPE_MINIPET)
                        continue;

                    creatureId = spellInfo->Effects[i].MiscValue;
                    break;
                }
            }

            if (creatureId)
            {
                if (CreatureTemplate const* cInfo = sObjectMgr->GetCreatureTemplate(creatureId))
                {
                    if (CreatureModel const* m = cInfo->GetFirstValidModel())
                        displayId = m->CreatureDisplayID;
                }
            }

            std::string name = itemTemplate->Name1;
            WorldDatabase.EscapeString(name);

            uint32 rarity = std::min<uint32>(itemTemplate->Quality, 4u);

            WorldDatabase.Execute(
                "INSERT INTO dc_pet_definitions (pet_entry, name, pet_type, pet_spell_id, rarity, display_id) "
                "VALUES ({}, '{}', 'companion', {}, {}, {}) "
                "ON DUPLICATE KEY UPDATE name = VALUES(name), pet_type = VALUES(pet_type), pet_spell_id = VALUES(pet_spell_id), rarity = VALUES(rarity), display_id = VALUES(display_id)",
                itemId,
                name,
                summonSpellId,
                rarity,
                displayId);

            ++insertedOrUpdated;
        };

        bool useDbFilter = sConfigMgr->GetOption<bool>(Config::PET_DEFINITIONS_REBUILD_USE_DB_ITEM_FILTER, true);
        if (useDbFilter)
        {
            QueryResult r = WorldDatabase.Query(
                "SELECT entry FROM item_template WHERE class = 15 AND subclass = 2");

            if (r)
            {
                do
                {
                    uint32 itemId = r->Fetch()[0].Get<uint32>();
                    rebuildFromItemId(itemId);
                } while (r->NextRow());
            }
        }
        else
        {
            // Slowest mode (still disabled unless rebuild is enabled): iterate full item_template store.
            ItemTemplateContainer const* items = sObjectMgr->GetItemTemplateStore();
            if (items)
            {
                for (auto const& [entry, itemTemplate] : *items)
                {
                    (void)entry;
                    if (itemTemplate.Class != 15 || itemTemplate.SubClass != 2)
                        continue;
                    rebuildFromItemId(itemTemplate.ItemId);
                }
            }
        }

        // Optional: include spell-only minipets (pet_entry = summon spellId) if no teaching item exists.
        if (sConfigMgr->GetOption<bool>(Config::PET_DEFINITIONS_REBUILD_INCLUDE_SPELL_ONLY, false))
        {
            for (SpellEntry const* spellEntry : sSpellStore)
            {
                if (!spellEntry)
                    continue;

                uint32 spellId = spellEntry->Id;
                if (!spellId)
                    continue;

                SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
                if (!IsCompanionSpell(spellInfo))
                    continue;

                // Skip spells that already have a teaching item.
                if (FindCompanionItemIdForSpell(spellId))
                    continue;

                uint32 creatureId = 0;
                uint32 displayId = 0;
                for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                {
                    if (spellInfo->Effects[i].Effect != SPELL_EFFECT_SUMMON &&
                        spellInfo->Effects[i].Effect != SPELL_EFFECT_SUMMON_PET)
                        continue;

                    SummonPropertiesEntry const* properties = sSummonPropertiesStore.LookupEntry(spellInfo->Effects[i].MiscValueB);
                    if (!properties || properties->Type != SUMMON_TYPE_MINIPET)
                        continue;

                    creatureId = spellInfo->Effects[i].MiscValue;
                    break;
                }

                if (creatureId)
                {
                    if (CreatureTemplate const* cInfo = sObjectMgr->GetCreatureTemplate(creatureId))
                    {
                        if (CreatureModel const* m = cInfo->GetFirstValidModel())
                            displayId = m->CreatureDisplayID;
                    }
                }

                std::string name;
                if (spellInfo && spellInfo->SpellName[0])
                    name = spellInfo->SpellName[0];
                WorldDatabase.EscapeString(name);

                WorldDatabase.Execute(
                    "INSERT INTO dc_pet_definitions (pet_entry, name, pet_type, pet_spell_id, rarity, display_id) "
                    "VALUES ({}, '{}', 'companion', {}, 0, {}) "
                    "ON DUPLICATE KEY UPDATE name = VALUES(name), pet_type = VALUES(pet_type), pet_spell_id = VALUES(pet_spell_id), display_id = VALUES(display_id)",
                    spellId,
                    name,
                    spellId,
                    displayId);

                ++spellOnlyInsertedOrUpdated;
            }
        }

        LOG_INFO(
            "module",
            "DC-Collection: Pet definition rebuild complete ({} item rows inserted/updated, {} companion items skipped: no summon spell, {} spell-only rows inserted/updated).",
            insertedOrUpdated,
            skippedNoSpell,
            spellOnlyInsertedOrUpdated);
    }

    uint32 FindCompanionSpellIdForItem(uint32 itemId)
    {
        if (!itemId)
            return 0;

        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
        if (!proto)
            return 0;

        // Prefer an item spell that is itself the summon spell.
        for (uint8 i = 0; i < MAX_ITEM_PROTO_SPELLS; ++i)
        {
            uint32 spellId = proto->Spells[i].SpellId;
            if (!spellId)
                continue;

            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (IsCompanionSpell(spellInfo))
                return spellId;

            // Many companion "teaching" items cast a spell that teaches the real summon spell.
            // In that case, look for LEARN_* effects and return the taught spell if it's a companion summon.
            if (spellInfo)
            {
                for (uint8 eff = 0; eff < MAX_SPELL_EFFECTS; ++eff)
                {
                    if (spellInfo->Effects[eff].Effect != SPELL_EFFECT_LEARN_SPELL &&
                        spellInfo->Effects[eff].Effect != SPELL_EFFECT_LEARN_PET_SPELL)
                        continue;

                    uint32 taughtSpellId = spellInfo->Effects[eff].TriggerSpell;
                    if (!taughtSpellId)
                        continue;

                    if (SpellInfo const* taughtInfo = sSpellMgr->GetSpellInfo(taughtSpellId))
                    {
                        if (IsCompanionSpell(taughtInfo))
                            return taughtSpellId;
                    }
                }
            }
        }

        // Fallback: If this is explicitly a companion item (Class 15, Subclass 2),
        // only return a spell that actually resolves to a companion summon.
        // Important: many DBs store a generic placeholder (e.g. 55884 "Learning") in spellid_1,
        // so returning the first non-zero spell here can produce bogus/"unknown" companions.
        if (proto->Class == 15 && proto->SubClass == 2)
        {
            for (uint8 i = 0; i < MAX_ITEM_PROTO_SPELLS; ++i)
            {
                uint32 spellId = proto->Spells[i].SpellId;
                if (!spellId)
                    continue;

                if (uint32 resolved = ResolveCompanionSummonSpellFromSpell(spellId))
                    return resolved;
            }
        }

        return 0;
    }


    // Forward declarations used by early migration helpers.
    uint32 GetItemDisplayId(ItemTemplate const* proto);
    bool IsItemEligibleForTransmogUnlock(ItemTemplate const* proto);
    bool CharacterTableExists(std::string const& tableName);
    // CharacterColumnExists is defined in CollectionCore.cpp and declared in dc_addon_collection.h

    bool CharacterColumnTypeContains(std::string const& tableName, std::string const& columnName, std::string_view needle)
    {
        if (!CharacterTableExists(tableName))
            return false;

        QueryResult result = CharacterDatabase.Query("SHOW COLUMNS FROM `{}` LIKE '{}'", tableName, columnName);
        if (!result)
            return false;

        Field* fields = result->Fetch();
        std::string type = fields[1].Get<std::string>();
        return type.find(needle) != std::string::npos;
    }

    bool WishlistCollectionTypeIsEnum()
    {
        static bool checked = false;
        static bool isEnum = false;
        if (!checked)
        {
            isEnum = CharacterColumnTypeContains("dc_collection_wishlist", "collection_type", "enum(");
            checked = true;
        }
        return isEnum;
    }

    std::string const& GetWishlistIdColumn()
    {
        static std::string cached;
        static bool checked = false;
        if (checked)
            return cached;

        checked = true;
        if (!CharacterTableExists("dc_collection_wishlist"))
            return cached;

        if (CharacterColumnExists("dc_collection_wishlist", "entry_id"))
            cached = "entry_id";
        else if (CharacterColumnExists("dc_collection_wishlist", "entry"))
            cached = "entry";
        else if (CharacterColumnExists("dc_collection_wishlist", "item_id"))
            cached = "item_id";

        if (cached.empty())
            LOG_ERROR("server.loading", "DC-Collection: Character DB table 'dc_collection_wishlist' missing 'entry_id'/'entry'/'item_id' column (schema mismatch).");

        return cached;
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

    // Forward declarations: ensure functions are visible at call sites
    inline uint32 GetAccountId(Player* player);
    bool WorldTableExists(std::string const& tableName);

    void ImportExistingCollections(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = GetAccountId(player);
        if (!accountId)
            return;

        std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
        if (itemsEntryCol.empty())
            return;

        auto trans = CharacterDatabase.BeginTransaction();

        // Migrate older PET collection rows that used learned spellIds instead of companion itemIds.
        // If entry_id is not a valid item_template entry, attempt to map it to the teaching item.
        {
            QueryResult pets = CharacterDatabase.Query(
                "SELECT {} FROM dc_collection_items "
                "WHERE account_id = {} AND collection_type = {} AND unlocked = 1",
                itemsEntryCol, accountId, static_cast<uint8>(CollectionType::PET));

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
                        "(account_id, collection_type, {}, source_type, unlocked, acquired_date) "
                        "VALUES ({}, {}, {}, 'IMPORT', 1, NOW())",
                        itemsEntryCol, accountId, static_cast<uint8>(CollectionType::PET), mappedItemId);

                    trans->Append(
                        "DELETE FROM dc_collection_items WHERE account_id = {} AND collection_type = {} AND {} = {}",
                        accountId, static_cast<uint8>(CollectionType::PET), itemsEntryCol, entryId);

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
            uint32 companionSummonSpellId = 0;

            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                if (spellInfo->Effects[i].Effect == SPELL_EFFECT_APPLY_AURA &&
                    (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED ||
                     spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOD_INCREASE_MOUNTED_FLIGHT_SPEED))
                {
                    isMount = true;
                    break;
                }
            }

            // Companion pets (non-combat minipets) are reliably detected via SummonProperties (MINIPET)
            // and/or via teaching spells that LEARN the summon spell.
            companionSummonSpellId = ResolveCompanionSummonSpellFromSpell(spellId);

            if (isMount)
            {
                trans->Append(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, {}, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'IMPORT', 1, NOW())",
                    itemsEntryCol, accountId, static_cast<uint8>(CollectionType::MOUNT), spellId);
            }
            else if (companionSummonSpellId)
            {
                uint32 itemId = FindCompanionItemIdForSpell(companionSummonSpellId);
                if (!itemId)
                    continue;

                trans->Append(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, {}, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'IMPORT', 1, NOW())",
                    itemsEntryCol, accountId, static_cast<uint8>(CollectionType::PET), itemId);
            }
        }

        // Import heirlooms already owned by the character into account-wide collections.
        // This relies on the custom world table dc_heirloom_definitions (item_id list).
        if (WorldTableExists("dc_heirloom_definitions"))
        {
            std::unordered_set<uint32> heirloomDefs;
            QueryResult defRes = WorldDatabase.Query("SELECT item_id FROM dc_heirloom_definitions");
            if (defRes)
            {
                do
                {
                    heirloomDefs.insert(defRes->Fetch()[0].Get<uint32>());
                } while (defRes->NextRow());
            }

            if (!heirloomDefs.empty())
            {
                std::unordered_set<uint32> foundHeirlooms;

                auto considerHeirloomItem = [&](Item* item)
                {
                    if (!item)
                        return;

                    uint32 itemId = item->GetEntry();
                    if (!itemId)
                        return;

                    if (heirloomDefs.find(itemId) == heirloomDefs.end())
                        return;

                    foundHeirlooms.insert(itemId);
                };

                // Equipped slots.
                for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
                    considerHeirloomItem(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

                // Backpack.
                for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
                    considerHeirloomItem(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

                // Bags.
                for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
                {
                    if (Bag* bag = player->GetBagByPos(bagSlot))
                        for (uint32 i = 0; i < bag->GetBagSize(); ++i)
                            considerHeirloomItem(bag->GetItemByPos(static_cast<uint8>(i)));
                }

                // Bank slots.
                for (uint8 slot = BANK_SLOT_ITEM_START; slot < BANK_SLOT_ITEM_END; ++slot)
                    considerHeirloomItem(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

                // Bank bags.
                for (uint8 bagSlot = BANK_SLOT_BAG_START; bagSlot < BANK_SLOT_BAG_END; ++bagSlot)
                {
                    if (Bag* bag = player->GetBagByPos(bagSlot))
                        for (uint32 i = 0; i < bag->GetBagSize(); ++i)
                            considerHeirloomItem(bag->GetItemByPos(static_cast<uint8>(i)));
                }

                for (uint32 itemId : foundHeirlooms)
                {
                    trans->Append(
                        "INSERT IGNORE INTO dc_collection_items "
                        "(account_id, collection_type, {}, source_type, unlocked, acquired_date) "
                        "VALUES ({}, {}, {}, 'IMPORT_ITEMSCAN', 1, NOW())",
                        itemsEntryCol, accountId, static_cast<uint8>(CollectionType::HEIRLOOM), itemId);
                }
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
                "(account_id, collection_type, {}, source_type, unlocked, acquired_date) "
                "VALUES ({}, {}, {}, 'IMPORT', 1, NOW())",
                itemsEntryCol, accountId, static_cast<uint8>(CollectionType::TITLE), titleEntry->ID);
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
                    "(account_id, collection_type, {}, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'IMPORT_ITEMSCAN', 1, NOW())",
                    itemsEntryCol, accountId, static_cast<uint8>(CollectionType::TRANSMOG), displayId);
            }

            // Mark migration as done even if nothing was found.
            MarkTransmogLegacyImportDone(accountId);
        }

        CharacterDatabase.CommitTransaction(trans);
    }

    void SyncAccountWideCollectionsToCharacter(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        if (!sConfigMgr->GetOption<bool>(Config::SYNC_TO_CHARACTER_ON_LOGIN, true))
            return;

        // NOTE: This sync can be large for accounts with many mounts/pets.
        // Doing it synchronously inside the login handler risks blocking the login handshake.
        // We therefore (1) defer the DB scan slightly, and (2) teach spells in batches.

        auto const delayMs = sConfigMgr->GetOption<uint32>(Config::SYNC_TO_CHARACTER_DELAY_MS, 1000);
        auto const batchSize = sConfigMgr->GetOption<uint32>(Config::SYNC_TO_CHARACTER_BATCH_SIZE, 200);
        auto const batchDelayMs = sConfigMgr->GetOption<uint32>(Config::SYNC_TO_CHARACTER_BATCH_DELAY_MS, 250);

        player->m_Events.AddEventAtOffset([player, batchSize, batchDelayMs]()
        {
            if (!player || !player->GetSession())
                return;

            uint32 accountId = GetAccountId(player);
            if (!accountId)
                return;

            std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
            if (itemsEntryCol.empty())
                return;

            std::vector<uint32> spellsToTeach;
            spellsToTeach.reserve(256);

            // Titles are cheap to apply and don't need batching.
            uint32 titlesApplied = 0;

            auto considerSpell = [&](uint32 spellId)
            {
                if (!spellId)
                    return;
                if (player->HasSpell(spellId))
                    return;
                if (!player->IsSpellFitByClassAndRace(spellId))
                    return;
                spellsToTeach.push_back(spellId);
            };

            // One DB pass for mounts/pets/titles.
            QueryResult result = CharacterDatabase.Query(
                "SELECT collection_type, {} FROM dc_collection_items "
                "WHERE account_id = {} AND collection_type IN ({}, {}, {}) AND unlocked = 1",
                itemsEntryCol,
                accountId,
                static_cast<uint8>(CollectionType::MOUNT),
                static_cast<uint8>(CollectionType::PET),
                static_cast<uint8>(CollectionType::TITLE));

            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint8 collectionType = fields[0].Get<uint8>();
                    uint32 entryId = fields[1].Get<uint32>();
                    if (!entryId)
                        continue;

                    switch (static_cast<CollectionType>(collectionType))
                    {
                        case CollectionType::MOUNT:
                        {
                            // Stored as mount spellIds
                            considerSpell(entryId);
                            break;
                        }
                        case CollectionType::PET:
                        {
                            // Stored as teaching itemId (preferred) or a spellId (legacy).
                            // Disambiguate by checking for an item template first.
                            uint32 spellId = 0;
                            if (sObjectMgr->GetItemTemplate(entryId))
                                spellId = FindCompanionSpellIdForItem(entryId);
                            else
                                spellId = ResolveCompanionSummonSpellFromSpell(entryId);

                            considerSpell(spellId);
                            break;
                        }
                        case CollectionType::TITLE:
                        {
                            CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(entryId);
                            if (!titleEntry)
                                break;

                            if (player->HasTitle(titleEntry))
                                break;

                            player->SetTitle(titleEntry, false);
                            ++titlesApplied;
                            break;
                        }
                        default:
                            break;
                    }

                } while (result->NextRow());
            }

            if (spellsToTeach.empty())
            {
                // No spells to teach; still report titles applied if any
                if (titlesApplied > 0)
                {
                    if (WorldSession* session = player->GetSession())
                    {
                        ChatHandler handler(session);
                        handler.PSendSysMessage(
                            "DC-Collection: Accountwide sync complete ({} titles applied). Please relog or /reload to see mounts/companions in the default UI.",
                            titlesApplied);
                    }
                }
                return;
            }

            // Dedupe (mount + pet spell collisions can happen in custom content)
            std::sort(spellsToTeach.begin(), spellsToTeach.end());
            spellsToTeach.erase(std::unique(spellsToTeach.begin(), spellsToTeach.end()), spellsToTeach.end());

            uint32 const effectiveBatchSize = std::max<uint32>(1u, batchSize);
            uint32 const effectiveBatchDelayMs = std::max<uint32>(1u, batchDelayMs);

            auto spellsPtr = std::make_shared<std::vector<uint32>>(std::move(spellsToTeach));
            auto indexPtr = std::make_shared<size_t>(0);
            auto tickPtr = std::make_shared<std::function<void()>>();
            auto taughtTotalPtr = std::make_shared<uint32>(0);

            *tickPtr = [player, spellsPtr, indexPtr, taughtTotalPtr, effectiveBatchSize, effectiveBatchDelayMs, tickPtr, titlesApplied]()
            {
                if (!player || !player->GetSession())
                    return;

                size_t idx = *indexPtr;
                size_t const total = spellsPtr->size();
                uint32 taughtThisTick = 0;
                std::vector<uint32> taughtSpellIds;
                taughtSpellIds.reserve(effectiveBatchSize);

                while (idx < total && taughtThisTick < effectiveBatchSize)
                {
                    uint32 spellId = (*spellsPtr)[idx++];
                    if (!spellId)
                        continue;

                    if (player->HasSpell(spellId))
                        continue;

                    if (!player->IsSpellFitByClassAndRace(spellId))
                        continue;

                    // Add silently (no "You have learned..." spam).
                    player->addSpell(spellId, SPEC_MASK_ALL, true, false, false);
                    ++taughtThisTick;
                    ++(*taughtTotalPtr);
                    taughtSpellIds.push_back(spellId);
                }

                // Persist taught spells now, so logout doesn't need to flush a huge spell delta.
                // Also mark them as UNCHANGED to avoid SaveToDB doing redundant INSERTs.
                if (!taughtSpellIds.empty())
                {
                    auto trans = CharacterDatabase.BeginTransaction();

                    std::ostringstream sql;
                    sql << "INSERT INTO character_spell (guid, spell, specMask) VALUES ";

                    ObjectGuid::LowType const guidLow = player->GetGUID().GetCounter();
                    bool first = true;
                    for (uint32 taughtSpellId : taughtSpellIds)
                    {
                        if (!taughtSpellId)
                            continue;

                        // Ensure it actually got added.
                        if (!player->HasSpell(taughtSpellId))
                            continue;

                        if (!first)
                            sql << ",";
                        first = false;
                        sql << "(" << guidLow << "," << taughtSpellId << "," << uint32(SPEC_MASK_ALL) << ")";

                        // Mark as unchanged to prevent redundant saving later.
                        PlayerSpellMap& spellMap = const_cast<PlayerSpellMap&>(player->GetSpellMap());
                        auto it = spellMap.find(taughtSpellId);
                        if (it != spellMap.end() && it->second && (it->second->State == PLAYERSPELL_NEW || it->second->State == PLAYERSPELL_CHANGED))
                            it->second->State = PLAYERSPELL_UNCHANGED;
                    }

                    // Ensure specMask is updated if the row already exists.
                    sql << " ON DUPLICATE KEY UPDATE specMask = VALUES(specMask)";

                    if (!first)
                        trans->Append(sql.str());

                    CharacterDatabase.CommitTransaction(trans);
                }

                *indexPtr = idx;

                if (idx < total)
                {
                    player->m_Events.AddEventAtOffset(*tickPtr, std::chrono::milliseconds(effectiveBatchDelayMs));
                }
                else
                {
                    // If we taught many spells at once, AchievementMgr may have accumulated a lot of changed criteria.
                    // Flushing those changes here can significantly reduce the time spent during logout SaveToDB.
                    if (*taughtTotalPtr > 0 && sConfigMgr->GetOption<bool>(Config::SYNC_TO_CHARACTER_FLUSH_ACHIEVEMENTS_ON_COMPLETE, true))
                    {
                        if (AchievementMgr* achievementMgr = player->GetAchievementMgr())
                        {
                            auto const t0 = std::chrono::steady_clock::now();

                            auto trans = CharacterDatabase.BeginTransaction();
                            achievementMgr->SaveToDB(trans);
                            CharacterDatabase.CommitTransaction(trans);

                            auto const dtMs = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - t0).count();
                            if (dtMs >= 250)
                                LOG_INFO("module.dc", "DC-Collection: Flushed achievement progress after accountwide sync in {} ms.", dtMs);
                        }
                    }

                    if (WorldSession* session = player->GetSession())
                    {
                        ChatHandler handler(session);
                        handler.PSendSysMessage(
                            "DC-Collection: Accountwide sync complete ({} spells taught, {} titles applied). Please relog or /reload to see mounts/companions in the default UI.",
                            *taughtTotalPtr,
                            titlesApplied);
                    }
                }
            };

            // Kick off immediately (still outside the login handler).
            (*tickPtr)();

        }, std::chrono::milliseconds(delayMs));
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


    // Load player's collection for a specific type
    std::vector<uint32> LoadPlayerCollection(uint32 accountId, CollectionType type)
    {
        std::vector<uint32> items;

        std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
        if (itemsEntryCol.empty())
            return items;

        QueryResult result = CharacterDatabase.Query(
            "SELECT {} FROM dc_collection_items "
            "WHERE account_id = {} AND collection_type = {} AND unlocked = 1",
            itemsEntryCol, accountId, static_cast<uint8>(type));

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
        std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
        if (itemsEntryCol.empty())
            return false;

        QueryResult result = CharacterDatabase.Query(
            "SELECT 1 FROM dc_collection_items WHERE account_id = {} AND collection_type = {} AND {} = {} AND unlocked = 1 LIMIT 1",
            accountId, static_cast<uint8>(type), itemsEntryCol, entryId);
        return result != nullptr;
    }

    // Forward declaration: ensure transmog keys available at call site
    std::vector<std::string> const& GetTransmogAppearanceVariantKeysCached();

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
        ensureTotal(CollectionType::TRANSMOG, static_cast<uint32>(GetTransmogAppearanceVariantKeysCached().size()));

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

    // TransmogAppearanceVariant struct moved to header

    // Transmog Cache Implementations moved to dc_addon_wardrobe.cpp

    // Transmog Helpers moved to dc_addon_wardrobe.cpp

    // Transmog Helpers Part 2 moved to dc_addon_wardrobe.cpp

    // Load wishlist
    std::vector<std::pair<uint8, uint32>> LoadWishlist(uint32 accountId)
    {
        std::vector<std::pair<uint8, uint32>> wishlist;

        std::string const& wishIdCol = GetWishlistIdColumn();
        if (wishIdCol.empty())
            return wishlist;

        QueryResult result = CharacterDatabase.Query(
            "SELECT collection_type, {} FROM dc_collection_wishlist "
            "WHERE account_id = {} ORDER BY added_date DESC",
            wishIdCol, accountId);

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();

                uint8 type = 0;
                if (WishlistCollectionTypeIsEnum())
                {
                    std::string t = fields[0].Get<std::string>();
                    type = WishlistTypeFromString(t);
                }
                else
                {
                    type = fields[0].Get<uint8>();
                }

                if (type)
                    wishlist.emplace_back(type, fields[1].Get<uint32>());
            } while (result->NextRow());
        }

        return wishlist;
    }

    struct RecentAddition
    {
        uint8 typeId = 0;
        uint32 entryId = 0;
        uint32 timestamp = 0;
    };

    std::vector<RecentAddition> LoadRecentAdditions(uint32 accountId, uint32 limit)
    {
        std::vector<RecentAddition> recent;

        if (!accountId || limit == 0)
            return recent;

        std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
        if (itemsEntryCol.empty())
            return recent;

        QueryResult result = CharacterDatabase.Query(
            "SELECT collection_type, {}, IFNULL(UNIX_TIMESTAMP(acquired_date), 0) "
            "FROM dc_collection_items "
            "WHERE account_id = {} AND unlocked = 1 "
            "ORDER BY acquired_date DESC LIMIT {}",
            itemsEntryCol, accountId, limit);

        if (result)
        {
            do
            {
                Field* f = result->Fetch();
                RecentAddition entry;
                entry.typeId = f[0].Get<uint8>();
                entry.entryId = f[1].Get<uint32>();
                entry.timestamp = f[2].Get<uint32>();
                recent.push_back(entry);
            } while (result->NextRow());
        }

        return recent;
    }

    // Check if item is on wishlist
    bool IsOnWishlist(uint32 accountId, CollectionType type, uint32 entryId)
    {
        std::string const& wishIdCol = GetWishlistIdColumn();
        if (wishIdCol.empty())
            return false;

        QueryResult result;
        if (WishlistCollectionTypeIsEnum())
        {
            std::string typeStr = WishlistTypeToString(static_cast<uint8>(type));
            if (typeStr.empty())
                return false;
            result = CharacterDatabase.Query(
                "SELECT 1 FROM dc_collection_wishlist "
                "WHERE account_id = {} AND collection_type = '{}' AND {} = {}",
                accountId, typeStr, wishIdCol, entryId);
        }
        else
        {
            result = CharacterDatabase.Query(
                "SELECT 1 FROM dc_collection_wishlist "
                "WHERE account_id = {} AND collection_type = {} AND {} = {}",
                accountId, static_cast<uint8>(type), wishIdCol, entryId);
        }

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

    void SendStats(Player* player, bool includeRecent = false)
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

        if (includeRecent)
        {
            constexpr uint32 RECENT_MAX_ITEMS = 12;
            auto recentRows = LoadRecentAdditions(accountId, RECENT_MAX_ITEMS);

            DCAddon::JsonValue recent;
            recent.SetArray();

            for (RecentAddition const& r : recentRows)
            {
                if (r.typeId == static_cast<uint8>(CollectionType::TOY))
                    continue; // Toys are disabled

                if (r.typeId > 6)
                    continue;

                std::string typeKey = typeNames[r.typeId];
                if (typeKey.empty())
                    continue;

                DCAddon::JsonValue entry;
                entry.SetObject();
                entry.Set("type", typeKey);
                entry.Set("id", r.entryId);
                entry.Set("timestamp", r.timestamp);

                // Help the client resolve icons/tooltips without requiring definitions.
                if (r.typeId == static_cast<uint8>(CollectionType::MOUNT))
                {
                    entry.Set("spellId", r.entryId);
                    if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(r.entryId))
                    {
                        if (spellInfo->SpellName[0])
                            entry.Set("name", std::string(spellInfo->SpellName[0]));
                    }

                    // Prefer rarity from the teaching item when available.
                    if (uint32 itemId = FindMountItemIdForSpell(r.entryId))
                    {
                        entry.Set("itemId", itemId);
                        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId))
                            entry.Set("rarity", static_cast<uint32>(proto->Quality));
                    }
                }
                else if (r.typeId == static_cast<uint8>(CollectionType::PET) || r.typeId == static_cast<uint8>(CollectionType::HEIRLOOM))
                {
                    entry.Set("itemId", r.entryId);
                    if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(r.entryId))
                    {
                        entry.Set("name", std::string(proto->Name1));
                        entry.Set("rarity", static_cast<uint32>(proto->Quality));
                    }
                }
                else if (r.typeId == static_cast<uint8>(CollectionType::TITLE))
                {
                    if (CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(r.entryId))
                    {
                        std::string name;
                        if (titleEntry->nameMale[0])
                            name = titleEntry->nameMale[0];
                        else if (titleEntry->nameFemale[0])
                            name = titleEntry->nameFemale[0];

                        if (!name.empty())
                            entry.Set("name", name);
                    }
                }
                else if (r.typeId == static_cast<uint8>(CollectionType::TRANSMOG))
                {
                    // Provide a representative item so the client can resolve name/icon via GetItemInfo.
                    auto const& idx = GetTransmogAppearanceIndexCached();
                    auto it = idx.find(r.entryId);
                    if (it != idx.end() && !it->second.empty())
                    {
                        TransmogAppearanceVariant const* best = &it->second[0];
                        for (TransmogAppearanceVariant const& v : it->second)
                        {
                            bool vNonCustom = v.canonicalItemId < TRANSMOG_CANONICAL_ITEMID_THRESHOLD;
                            bool bNonCustom = best->canonicalItemId < TRANSMOG_CANONICAL_ITEMID_THRESHOLD;
                            if (IsBetterTransmogRepresentative(v.canonicalItemId, vNonCustom, v.quality, v.itemLevel,
                                best->canonicalItemId, bNonCustom, best->quality, best->itemLevel))
                            {
                                best = &v;
                            }
                        }

                        if (best->canonicalItemId)
                            entry.Set("itemId", best->canonicalItemId);

                        if (!best->name.empty())
                            entry.Set("name", best->name);

                        entry.Set("rarity", best->quality);
                    }
                }

                recent.Push(entry);
            }

            msg.Set("recent", recent);
        }

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

        std::string const& shopEntryCol = GetWorldEntryColumn("dc_collection_shop");
        if (shopEntryCol.empty())
        {
            DCAddon::SendError(player, MODULE, "Shop table schema mismatch",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }

        // Query shop items based on category
        std::string query =
            "SELECT id, collection_type, " + shopEntryCol + ", price_tokens, price_emblems, "
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
                        if (TransmogAppearanceVariant const* v = FindAnyVariant(appearanceId))
                            itemId = v->canonicalItemId;
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
            std::string const& wishIdCol = GetWishlistIdColumn();
            if (wishIdCol.empty())
                return;

            if (WishlistCollectionTypeIsEnum())
            {
                std::string typeStr = WishlistTypeToString(static_cast<uint8>(type));
                if (typeStr.empty())
                    return;
                CharacterDatabase.Execute(
                    "DELETE FROM dc_collection_wishlist WHERE account_id = {} AND collection_type = '{}' AND {} = {}",
                    accountId, typeStr, wishIdCol, entryId);
            }
            else
            {
                CharacterDatabase.Execute(
                    "DELETE FROM dc_collection_wishlist WHERE account_id = {} AND collection_type = {} AND {} = {}",
                    accountId, static_cast<uint8>(type), wishIdCol, entryId);
            }
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

        std::string const& shopEntryCol = GetWorldEntryColumn("dc_collection_shop");
        if (shopEntryCol.empty())
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Shop table schema mismatch");
            msg.Send(player);
            return;
        }

        // Get shop item details
        QueryResult result = WorldDatabase.Query(
            "SELECT collection_type, {}, price_tokens, price_emblems, stock_remaining "
            "FROM dc_collection_shop WHERE id = {} AND enabled = 1",
            shopEntryCol, shopId);

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
                if (!FindAnyVariant(purchasedEntryId))
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

        std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
        if (itemsEntryCol.empty())
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Collection table schema mismatch");
            msg.Send(player);
            return;
        }

        // Add to collection
        trans->Append(
            "INSERT INTO dc_collection_items (account_id, collection_type, {}, source_type, source_id, unlocked, acquired_date) "
            "VALUES ({}, {}, {}, 'SHOP', {}, 1, NOW()) "
            "ON DUPLICATE KEY UPDATE unlocked = 1, acquired_date = NOW()",
            itemsEntryCol, accountId, collType, purchasedEntryId, shopId);

        // Record purchase
        trans->Append(
            "INSERT INTO dc_collection_shop_purchases (account_id, shop_id, character_id, character_name, purchase_date, cost_tokens, cost_emblems, cost_gold) "
            "VALUES ({}, {}, {}, '{}', NOW(), {}, {}, 0)",
            accountId, shopId, player->GetGUID().GetCounter(), std::string(player->GetName()), priceTokens, priceEmblems);

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

        std::string const& wishIdCol = GetWishlistIdColumn();
        if (wishIdCol.empty())
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
            msg.Set("success", false);
            msg.Set("error", "Wishlist table schema mismatch");
            msg.Send(player);
            return;
        }

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
        if (WishlistCollectionTypeIsEnum())
        {
            std::string typeStr = WishlistTypeToString(type);
            if (typeStr.empty())
            {
                DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
                msg.Set("success", false);
                msg.Set("error", "Unsupported wishlist type");
                msg.Send(player);
                return;
            }

            CharacterDatabase.Execute(
                "INSERT INTO dc_collection_wishlist (account_id, collection_type, {}, added_date) "
                "VALUES ({}, '{}', {}, NOW())",
                wishIdCol, accountId, typeStr, entryId);
        }
        else
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_collection_wishlist (account_id, collection_type, {}, added_date) "
                "VALUES ({}, {}, {}, NOW())",
                wishIdCol, accountId, type, entryId);
        }

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

        std::string const& wishIdCol = GetWishlistIdColumn();
        if (wishIdCol.empty())
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
            msg.Set("success", false);
            msg.Set("error", "Wishlist table schema mismatch");
            msg.Send(player);
            return;
        }

        if (WishlistCollectionTypeIsEnum())
        {
            std::string typeStr = WishlistTypeToString(type);
            if (typeStr.empty())
                return;

            CharacterDatabase.Execute(
                "DELETE FROM dc_collection_wishlist WHERE account_id = {} AND collection_type = '{}' AND {} = {}",
                accountId, typeStr, wishIdCol, entryId);
        }
        else
        {
            CharacterDatabase.Execute(
                "DELETE FROM dc_collection_wishlist WHERE account_id = {} AND collection_type = {} AND {} = {}",
                accountId, type, wishIdCol, entryId);
        }

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

        std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
        if (itemsEntryCol.empty())
            return;

        CharacterDatabase.Execute(
            "UPDATE dc_collection_items SET is_favorite = {} "
            "WHERE account_id = {} AND collection_type = {} AND {} = {}",
            favorite ? 1 : 0, accountId, type, itemsEntryCol, entryId);

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

                std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
                if (itemsEntryCol.empty())
                    return;

                QueryResult result = CharacterDatabase.Query(
                    "SELECT {} FROM dc_collection_items "
                    "WHERE account_id = {} AND collection_type = {} AND is_favorite = 1",
                    itemsEntryCol, accountId, static_cast<uint8>(CollectionType::MOUNT));
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
        std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
        if (itemsEntryCol.empty())
            return;

        CharacterDatabase.Execute(
            "UPDATE dc_collection_items SET times_used = times_used + 1 "
            "WHERE account_id = {} AND collection_type = {} AND {} = {}",
            accountId, static_cast<uint8>(CollectionType::MOUNT), itemsEntryCol, spellId);
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

    void HandleGetStats(Player* player, const DCAddon::ParsedMessage& msg)
    {
        // Include recent by default to keep the UI consistent across client versions
        // (older clients may send an empty/non-JSON stats request).
        bool includeRecent = true;
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
            if (json.HasKey("includeRecent"))
                includeRecent = json["includeRecent"].AsBool();
        }

        SendStats(player, includeRecent);
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


    // =======================================================================
    // Transmog Slot-Based UI Handlers (Transmogrification addon style)
    // =======================================================================

    // Map visual slot IDs (from Transmogrification addon) to equipment slot
    // Implementations for VisualSlotToEquipmentSlot and GetInvTypesForVisualSlot 
    // were moved to dc_addon_wardrobe.cpp. They are declared in dc_addon_collection.h.

    // Helper: Get collected appearances for a slot, optionally filtered by search







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
            auto const& appearanceIndex = GetTransmogAppearanceIndexCached();
            auto const& keys = GetTransmogAppearanceVariantKeysCached();

            // IMPORTANT: Keep these pages small. Transmog definitions can be extremely large,
            // and (depending on configuration) can trigger expensive metadata work.
            // Large pages are a common cause of world-thread hitching.
            if (limit == 0)
                limit = 250;

            // Hard clamp to keep worst-case per-request time bounded.
            if (limit > 500)
                limit = 500;

            // Optional: include per-item "source" info.
            // This can be expensive (World DB lookups) and is not required for core wardrobe UX.
            bool includeSources = sConfigMgr->GetOption<bool>("DCCollection.Transmog.Definitions.IncludeSources", false);

            uint32 total = static_cast<uint32>(keys.size());
            if (offset > total)
                offset = total;

            uint32 end = std::min<uint32>(total, offset + limit);
            for (uint32 i = offset; i < end; ++i)
            {
                std::string const& k = keys[i];

                // Parse: displayId:invType:class:subclass
                size_t p1 = k.find(':');
                size_t p2 = (p1 == std::string::npos) ? std::string::npos : k.find(':', p1 + 1);
                size_t p3 = (p2 == std::string::npos) ? std::string::npos : k.find(':', p2 + 1);
                if (p1 == std::string::npos || p2 == std::string::npos || p3 == std::string::npos)
                    continue;

                uint32 displayId = static_cast<uint32>(std::stoul(k.substr(0, p1)));
                uint32 invType = static_cast<uint32>(std::stoul(k.substr(p1 + 1, p2 - (p1 + 1))));
                uint32 itemClass = static_cast<uint32>(std::stoul(k.substr(p2 + 1, p3 - (p2 + 1))));
                uint32 itemSubClass = static_cast<uint32>(std::stoul(k.substr(p3 + 1)));

                auto it = appearanceIndex.find(displayId);
                if (it == appearanceIndex.end())
                    continue;

                TransmogAppearanceVariant const* def = nullptr;
                for (auto const& v : it->second)
                {
                    if (v.inventoryType == invType && v.itemClass == itemClass && v.itemSubClass == itemSubClass)
                    {
                        def = &v;
                        break;
                    }
                }
                if (!def)
                    continue;

                DCAddon::JsonValue d;
                d.SetObject();
                d.Set("itemId", def->canonicalItemId);
                d.Set("name", def->name);
                d.Set("rarity", def->quality);
                d.Set("inventoryType", def->inventoryType);
                d.Set("weaponType", def->itemClass == ITEM_CLASS_WEAPON ? def->itemSubClass : 0);
                d.Set("armorType", def->itemClass == ITEM_CLASS_ARMOR ? def->itemSubClass : 0);
                d.Set("displayId", def->displayId);
                d.Set("key", k);

                DCAddon::JsonValue itemsArr;
                itemsArr.SetArray();
                uint32 pushed = 0;
                for (uint32 itemId : def->itemIds)
                {
                    if (pushed >= 25)
                        break;
                    itemsArr.Push(DCAddon::JsonValue(itemId));
                    ++pushed;
                }
                d.Set("itemIds", itemsArr);
                d.Set("itemIdsTotal", static_cast<uint32>(def->itemIds.size()));

                if (includeSources)
                    d.Set("source", buildSourceForItemCached(def->canonicalItemId));
                defs.Set(k, d);
            }

            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_DEFINITIONS);
            msg.Set("type", typeName);
            msg.Set("definitions", defs);
            msg.Set("syncVersion", GetTransmogDefinitionsSyncVersionCached());
            msg.Set("offset", offset);
            msg.Set("limit", limit);
            msg.Set("total", total);
            msg.Set("more", end < total);
            msg.Send(player);
            return;
        }

        // Non-transmog: try curated per-type tables first; fall back to the generic index; fall back to owned-only.
        CollectionType ct = static_cast<CollectionType>(type);

        std::unordered_set<uint32> sentIds;

        auto addDef = [&](uint32 id, std::string const& name, std::string const& icon, uint32 rarity, std::string const& source, int32 extraType, uint32 itemIdForSource = 0, uint32 displayId = 0)
        {
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
            sentIds.insert(id);
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
                    sentIds.insert(spellId);
                    loadedAny = true;
                } while (r->NextRow());
            }
        }
        else if (ct == CollectionType::PET && WorldTableExists("dc_pet_definitions"))
        {
            // Pets are stored account-wide by the companion teaching itemId (class=15, subclass=2).
            // Send definitions keyed by that itemId, and include spellId/creatureId/displayId for the client.
            std::string entryCol = WorldColumnExists("dc_pet_definitions", "pet_entry") ? "pet_entry" : "";
            if (entryCol.empty() && WorldColumnExists("dc_pet_definitions", "item_id"))
                entryCol = "item_id";

            std::string spellCol;
            if (WorldColumnExists("dc_pet_definitions", "pet_spell_id"))
                spellCol = "pet_spell_id";
            else if (WorldColumnExists("dc_pet_definitions", "spell_id"))
                spellCol = "spell_id";
            else if (WorldColumnExists("dc_pet_definitions", "spellId"))
                spellCol = "spellId";

            std::string displayCol;
            if (WorldColumnExists("dc_pet_definitions", "display_id"))
                displayCol = "display_id";
            else if (WorldColumnExists("dc_pet_definitions", "displayId"))
                displayCol = "displayId";

            // Legacy schemas may not have pet_entry; fall back to selecting a spell id / pet_entry-like column.
            if (entryCol.empty())
            {
                if (!spellCol.empty())
                    entryCol = spellCol;
                else
                    entryCol = "pet_entry";
            }

            bool entryIsItemId = (entryCol == "pet_entry" || entryCol == "item_id");
            bool hasSpellCol = !spellCol.empty() && spellCol != entryCol;
            bool hasDisplayCol = !displayCol.empty();

            std::string query = "SELECT " + entryCol + ", name, icon, rarity, source";
            if (hasSpellCol)
                query += ", " + spellCol;
            if (hasDisplayCol)
                query += ", " + displayCol;
            query += " FROM dc_pet_definitions";

            QueryResult r = WorldDatabase.Query(query);
            if (r)
            {
                do
                {
                    Field* f = r->Fetch();
                    uint32 raw = f[0].Get<uint32>();
                    uint32 itemId = 0;
                    uint32 spellId = 0;
                    uint32 creatureId = 0;
                    uint32 displayId = 0;
                    uint32 displayIdFromTable = 0;

                    uint32 idx = 5;
                    if (hasSpellCol)
                        spellId = f[idx++].Get<uint32>();
                    if (hasDisplayCol)
                        displayIdFromTable = f[idx++].Get<uint32>();

                    if (entryIsItemId)
                        itemId = raw;
                    else
                        spellId = spellId ? spellId : raw;

                    // Validate Item ID: If it's not a companion item, check if it's actually a spell ID.
                    if (itemId)
                    {
                        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
                        if (!proto || (proto->Class != 15 || proto->SubClass != 2))
                        {
                            // Not a standard companion item.
                            // If we don't have a spellId yet, maybe this "itemId" is actually a spellId?
                            if (!spellId)
                            {
                                if (sSpellMgr->GetSpellInfo(itemId))
                                {
                                    spellId = itemId;
                                    itemId = 0; // Reset invalid item ID
                                }
                            }
                        }
                    }

                    if (spellId && !itemId)
                        itemId = FindCompanionItemIdForSpell(spellId);

                    // Always resolve the actual companion summon spell from the teaching itemId.
                    // This avoids relying on dc_pet_definitions.pet_spell_id, which can be placeholder/wrong (e.g. the same value for many rows).
                    if (itemId)
                    {
                        if (uint32 resolved = FindCompanionSpellIdForItem(itemId))
                            spellId = resolved;
                    }

                    if (SpellInfo const* spellInfo = spellId ? sSpellMgr->GetSpellInfo(spellId) : nullptr)
                    {
                        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                        {
                            if (spellInfo->Effects[i].Effect == SPELL_EFFECT_SUMMON ||
                                spellInfo->Effects[i].Effect == SPELL_EFFECT_SUMMON_PET)
                            {
                                creatureId = spellInfo->Effects[i].MiscValue;
                                // If we find a MINIPET type, prefer it and stop.
                                // Otherwise keep the first summon we found (or overwrite if we find a better one).
                                SummonPropertiesEntry const* properties = sSummonPropertiesStore.LookupEntry(spellInfo->Effects[i].MiscValueB);
                                if (properties && properties->Type == SUMMON_TYPE_MINIPET)
                                    break;
                            }
                        }
                    }

                    std::string name = f[1].Get<std::string>();
                    std::string icon = f[2].Get<std::string>();
                    uint32 rarity = f[3].Get<uint32>();

                    auto isUnknownName = [](std::string const& n) -> bool
                    {
                        if (n.empty())
                            return true;
                        std::string lower = n;
                        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
                        return lower == "unknown" || n == "???" || n == "?";
                    };

                    if (creatureId)
                    {
                        if (CreatureTemplate const* cInfo = sObjectMgr->GetCreatureTemplate(creatureId))
                        {
                            if (CreatureModel const* m = cInfo->GetFirstValidModel())
                                displayId = m->CreatureDisplayID;
                            
                            // Fallback name from creature if still missing
                            if (isUnknownName(name))
                                name = cInfo->Name;
                        }
                    }
                    if (!displayId && displayIdFromTable)
                        displayId = displayIdFromTable;

                    if (!itemId && !spellId)
                        continue;

                    if (itemId)
                    {
                        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId))
                        {
                            if (isUnknownName(name))
                                name = proto->Name1;
                            if (rarity == 0)
                                rarity = std::min<uint32>(proto->Quality, 4u);
                        }
                    }
                    else if (spellId)
                    {
                        // Fallback: If we still don't have a valid Item ID, but we have a Spell ID, use the spell name.
                        // This handles cases where the DB has spell IDs in the item column and we couldn't map them to items.
                        if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId))
                        {
                            if (isUnknownName(name))
                                name = spellInfo->SpellName[0];
                        }
                    }

                    DCAddon::JsonValue d;
                    d.SetObject();
                    d.Set("name", name);
                    d.Set("icon", icon);
                    d.Set("rarity", rarity);
                    if (itemId)
                        d.Set("itemId", itemId);
                    if (spellId)
                        d.Set("spellId", spellId);
                    if (creatureId)
                        d.Set("creatureId", creatureId);
                    if (displayId)
                        d.Set("displayId", displayId);

                    std::string source = f[4].Get<std::string>();
                    if (!source.empty())
                    {
                        DCAddon::JsonValue srcVal = parseSourceValue(source);
                        if (isUnknownSource(srcVal) && itemId)
                            srcVal = buildSourceForItemCached(itemId);
                        d.Set("source", srcVal);
                    }
                    else
                    {
                        d.Set("source", buildSourceForItemCached(itemId));
                    }

                    defs.Set(std::to_string(itemId ? itemId : spellId), d);
                    sentIds.insert(itemId ? itemId : spellId);
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
                    
                    uint32 displayId = 0;
                    if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId))
                        displayId = proto->DisplayInfoID;

                    addDef(
                        itemId,
                        f[1].Get<std::string>(),
                        f[2].Get<std::string>(),
                        f[3].Get<uint32>(),
                        f[4].Get<std::string>(),
                        -1,
                        itemId,
                        displayId);
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

                    uint32 displayId = 0;
                    if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId))
                        displayId = proto->DisplayInfoID;

                    addDef(
                        itemId,
                        f[1].Get<std::string>(),
                        f[2].Get<std::string>(),
                        0,
                        std::string(),
                        -1,
                        itemId,
                        displayId);
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
            std::string const& defEntryCol = GetWorldEntryColumn("dc_collection_definitions");
            if (defEntryCol.empty())
                return;

            QueryResult r = WorldDatabase.Query(
                "SELECT {} FROM dc_collection_definitions WHERE collection_type = {} AND enabled = 1",
                defEntryCol, static_cast<uint8>(ct));

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

        // Always ensure owned items have definitions, even if the DB table was incomplete.
        {
            uint32 accountId = GetAccountId(player);
            if (accountId)
            {
                auto owned = LoadPlayerCollection(accountId, ct);
                for (uint32 entryId : owned)
                {
                    if (sentIds.count(entryId))
                        continue;

                    std::string name;
                    std::string icon;
                    uint32 rarity = 1;
                    uint32 displayId = 0;
                    uint32 itemId = 0;

                    if (ct == CollectionType::MOUNT)
                    {
                        if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(entryId))
                        {
                            if (spellInfo->SpellName[0])
                                name = spellInfo->SpellName[0];
                            
                            // Try to find displayId
                            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                            {
                                if (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED)
                                {
                                    displayId = spellInfo->Effects[i].MiscValue;
                                    break;
                                }
                            }
                        }
                    }
                    else if (ct == CollectionType::PET)
                    {
                        // entryId is usually itemId
                        itemId = entryId;
                        uint32 spellId = 0;
                        uint32 creatureId = 0;
                        bool isValidCompanion = false;
                        
                        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entryId))
                        {
                            // Validate this is actually a companion item (Class 15, Subclass 2)
                            if (proto->Class == 15 && proto->SubClass == 2)
                            {
                                name = proto->Name1;
                                rarity = std::min<uint32>(proto->Quality, 4u);
                                
                                // Try to find spellId -> creatureId -> displayId
                                spellId = FindCompanionSpellIdForItem(entryId);
                                if (spellId)
                                {
                                    // Verify the spell is actually a companion summon
                                    if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId))
                                    {
                                        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                                        {
                                            if (spellInfo->Effects[i].Effect == SPELL_EFFECT_SUMMON ||
                                                spellInfo->Effects[i].Effect == SPELL_EFFECT_SUMMON_PET)
                                            {
                                                SummonPropertiesEntry const* properties = sSummonPropertiesStore.LookupEntry(spellInfo->Effects[i].MiscValueB);
                                                if (properties && properties->Type == SUMMON_TYPE_MINIPET)
                                                {
                                                    isValidCompanion = true;
                                                    creatureId = spellInfo->Effects[i].MiscValue;
                                                    if (creatureId)
                                                    {
                                                        if (CreatureTemplate const* cInfo = sObjectMgr->GetCreatureTemplate(creatureId))
                                                        {
                                                            if (CreatureModel const* m = cInfo->GetFirstValidModel())
                                                                displayId = m->CreatureDisplayID;
                                                            
                                                            // Fallback name from creature if item name is missing/unknown
                                                            if (name.empty() || name == "Unknown")
                                                                name = cInfo->Name;
                                                        }
                                                    }
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        else if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(entryId))
                        {
                            // Fallback if entryId is actually a spellId (legacy)
                            // But only if it's a valid companion summon spell
                            spellId = entryId;
                            
                            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                            {
                                if (spellInfo->Effects[i].Effect == SPELL_EFFECT_SUMMON ||
                                    spellInfo->Effects[i].Effect == SPELL_EFFECT_SUMMON_PET)
                                {
                                    SummonPropertiesEntry const* properties = sSummonPropertiesStore.LookupEntry(spellInfo->Effects[i].MiscValueB);
                                    if (properties && properties->Type == SUMMON_TYPE_MINIPET)
                                    {
                                        isValidCompanion = true;
                                        if (spellInfo->SpellName[0])
                                            name = spellInfo->SpellName[0];
                                        
                                        creatureId = spellInfo->Effects[i].MiscValue;
                                        if (creatureId)
                                        {
                                            if (CreatureTemplate const* cInfo = sObjectMgr->GetCreatureTemplate(creatureId))
                                            {
                                                if (CreatureModel const* m = cInfo->GetFirstValidModel())
                                                    displayId = m->CreatureDisplayID;
                                            }
                                        }
                                        break;
                                    }
                                }
                            }
                        }
                        
                        // Skip this entry if it's not actually a valid companion
                        if (!isValidCompanion)
                        {
                            LOG_WARN("module.dc", "DC-Collection: Skipping invalid companion entry {} for account {}", entryId, accountId);
                            continue;
                        }
                        
                        // Build the definition with all resolved IDs
                        DCAddon::JsonValue d;
                        d.SetObject();
                        if (!name.empty())
                            d.Set("name", name);
                        if (!icon.empty())
                            d.Set("icon", icon);
                        if (rarity > 0)
                            d.Set("rarity", rarity);
                        if (itemId > 0)
                            d.Set("itemId", itemId);
                        if (spellId > 0)
                            d.Set("spellId", spellId);
                        if (creatureId > 0)
                            d.Set("creatureId", creatureId);
                        if (displayId > 0)
                            d.Set("displayId", displayId);
                        
                        defs.Set(std::to_string(entryId), d);
                        sentIds.insert(entryId);
                        continue; // Skip the generic addDef call below
                    }
                    else if (ct == CollectionType::TOY || ct == CollectionType::HEIRLOOM)
                    {
                        itemId = entryId;
                        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entryId))
                        {
                            name = proto->Name1;
                            rarity = std::min<uint32>(proto->Quality, 4u);
                            displayId = proto->DisplayInfoID;
                        }
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

                    addDef(entryId, name, icon, rarity, std::string(), -1, itemId, displayId);
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
        uint32 clientSyncVersion = 0;

        if (json.HasKey("type"))
        {
            if (json["type"].IsString())
            {
                std::string t = json["type"].AsString();
                // Accept both singular and plural forms
                if (t == "mounts" || t == "mount") type = static_cast<uint8>(CollectionType::MOUNT);
                else if (t == "pets" || t == "pet" || t == "companions" || t == "companion") type = static_cast<uint8>(CollectionType::PET);
                else if (t == "heirlooms" || t == "heirloom") type = static_cast<uint8>(CollectionType::HEIRLOOM);
                else if (t == "titles" || t == "title") type = static_cast<uint8>(CollectionType::TITLE);
                else if (t == "transmog" || t == "appearances" || t == "appearance") type = static_cast<uint8>(CollectionType::TRANSMOG);
                else if (t == "itemSets" || t == "sets" || t == "itemset" || t == "set") type = static_cast<uint8>(CollectionType::ITEM_SET);
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

        // Optional: client can send a syncVersion/hash to skip re-downloading when unchanged.
        if (json.HasKey("syncVersion"))
            clientSyncVersion = json["syncVersion"].AsUInt32();
        else if (json.HasKey("version"))
            clientSyncVersion = json["version"].AsUInt32();

        // Handle itemSets separately (from DBC, not stored collection)
        if (type == static_cast<uint8>(CollectionType::ITEM_SET))
        {
            SendItemSetDefinitions(player);
            return;
        }

        // Transmog definitions are large: allow a client syncVersion short-circuit.
        if (type == static_cast<uint8>(CollectionType::TRANSMOG))
        {
            uint32 serverSyncVersion = GetTransmogDefinitionsSyncVersionCached();
            auto const& keys = GetTransmogAppearanceVariantKeysCached();

            // Only allow syncVersion short-circuit if server actually has definitions.
            // If the server index is empty (serverSyncVersion=0), force a full send.
            if (clientSyncVersion != 0 && clientSyncVersion == serverSyncVersion && offset == 0 && !keys.empty())
            {
                DCAddon::JsonValue empty;
                empty.SetObject();

                DCAddon::JsonMessage ack(MODULE, DCAddon::Opcode::Collection::SMSG_DEFINITIONS);
                ack.Set("type", "transmog");
                ack.Set("definitions", empty);
                ack.Set("syncVersion", serverSyncVersion);
                ack.Set("upToDate", true);
                ack.Set("offset", 0);
                ack.Set("limit", limit ? limit : 0);
                ack.Set("total", static_cast<uint32>(keys.size()));
                ack.Set("more", false);
                ack.Send(player);
                return;
            }

            // If server has no definitions, warn and continue (will send empty result).
            if (keys.empty())
            {
                LOG_WARN("module.dc", "[DCCollection] Transmog definitions requested but server index is empty. "
                    "Check if item_template query succeeded at startup.");
            }
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
                // Accept both singular and plural forms
                if (t == "mounts" || t == "mount") type = static_cast<uint8>(CollectionType::MOUNT);
                else if (t == "pets" || t == "pet" || t == "companions" || t == "companion") type = static_cast<uint8>(CollectionType::PET);
                else if (t == "heirlooms" || t == "heirloom") type = static_cast<uint8>(CollectionType::HEIRLOOM);
                else if (t == "titles" || t == "title") type = static_cast<uint8>(CollectionType::TITLE);
                else if (t == "transmog" || t == "appearances" || t == "appearance") type = static_cast<uint8>(CollectionType::TRANSMOG);
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

    // Community handlers moved to dc_addon_wardrobe.cpp

    // =======================================================================
    // Player Event Hooks
    // =======================================================================





    class CollectionPlayerScript : public PlayerScript
    {
    public:
        CollectionPlayerScript() : PlayerScript("dc_collection_player") {}

        static void ApplyStoredCharacterTransmog(Player* player)
        {
            if (!player || !player->GetSession())
                return;

            // Apply transmog appearance by overriding visible item entry fields.
            // This is intentionally run with a delay after login because the login pipeline
            // may overwrite PLAYER_VISIBLE_ITEM_* fields after early script hooks.
            QueryResult result = CharacterDatabase.Query(
                "SELECT slot, fake_entry, real_entry FROM dc_character_transmog WHERE guid = {}",
                player->GetGUID().GetCounter());

            if (!result)
                return;

            do
            {
                Field* fields = result->Fetch();
                uint8 slot = static_cast<uint8>(fields[0].Get<uint32>());
                uint32 fakeEntry = fields[1].Get<uint32>();
                uint32 realEntry = fields[2].Get<uint32>();

                if (slot >= EQUIPMENT_SLOT_END)
                    continue;

                Item* equippedItem = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (!equippedItem)
                    continue;

                uint32 currentEntry = equippedItem->GetEntry();
                if (currentEntry && currentEntry != realEntry)
                {
                    CharacterDatabase.Execute(
                        "UPDATE dc_character_transmog SET real_entry = {} WHERE guid = {} AND slot = {}",
                        currentEntry, player->GetGUID().GetCounter(), static_cast<uint32>(slot));
                }

                // fakeEntry == 0 means hide slot.
                if (fakeEntry)
                    player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (slot * 2), fakeEntry);
                else
                    player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (slot * 2), 0);
            } while (result->NextRow());
        }

        void OnPlayerLogin(Player* player) override
        {
            if (!sConfigMgr->GetOption<bool>(Config::ENABLED, true))
                return;

            // Seed account-wide collections from already-known mounts/pets/titles.
            ImportExistingCollections(player);

            // Make account-wide collections usable on this character in default UI.
            // (Mounts/Companions are spells; Titles are known-title flags.)
            SyncAccountWideCollectionsToCharacter(player);

            // Apply mount speed bonus on login
            UpdateMountSpeedBonus(player);

            // Push current transmog state so the UI can show applied slots
            SendTransmogState(player);

            // Re-apply stored transmogs after login initialization finishes.
            // Some login phases reset visible item fields to the real entries after early hooks run.
            // We schedule a couple of delayed passes to cover slower clients/servers.
            {
                ObjectGuid guid = player->GetGUID();
                player->m_Events.AddEventAtOffset([guid]()
                {
                    if (Player* p = ObjectAccessor::FindPlayer(guid))
                    {
                        ApplyStoredCharacterTransmog(p);
                        SendTransmogState(p);
                    }
                }, 1500ms);

                player->m_Events.AddEventAtOffset([guid]()
                {
                    if (Player* p = ObjectAccessor::FindPlayer(guid))
                    {
                        ApplyStoredCharacterTransmog(p);
                        SendTransmogState(p);
                    }
                }, 5s);
            }

            // Optional: scan player's equipment and bags to unlock transmogs at login
            if (!sConfigMgr->GetOption<bool>(Config::TRANSMOG_LOGIN_SCAN_ENABLED, false))
                return;

            bool includeBank = sConfigMgr->GetOption<bool>(Config::TRANSMOG_LOGIN_SCAN_INCLUDE_BANK, true);

            // Scan equipped items (slots EQUIPMENT_SLOT_START..EQUIPMENT_SLOT_END-1)
            for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            {
                Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (item)
                {
                    ItemTemplate const* proto = item->GetTemplate();
                    if (proto)
                        UnlockTransmogAppearance(player, proto, "LOGIN_SCAN", false); // Don't spam notifications
                }
            }

            // Scan normal bags
            for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
            {
                Bag* bag = player->GetBagByPos(bagSlot);
                if (!bag)
                    continue;
                for (uint32 i = 0; i < bag->GetBagSize(); ++i)
                {
                    Item* item = bag->GetItemByPos(static_cast<uint8>(i));
                    if (item)
                    {
                        ItemTemplate const* proto = item->GetTemplate();
                        if (proto)
                            UnlockTransmogAppearance(player, proto, "LOGIN_SCAN", false);
                    }
                }
            }

            // Optionally scan bank bags
            if (includeBank)
            {
                for (uint8 bankBag = BANK_SLOT_BAG_START; bankBag < BANK_SLOT_BAG_END; ++bankBag)
                {
                    Bag* bag = player->GetBagByPos(bankBag);
                    if (!bag)
                        continue;
                    for (uint32 i = 0; i < bag->GetBagSize(); ++i)
                    {
                        Item* item = bag->GetItemByPos(static_cast<uint8>(i));
                        if (item)
                        {
                            ItemTemplate const* proto = item->GetTemplate();
                            if (proto)
                                UnlockTransmogAppearance(player, proto, "LOGIN_SCAN", false);
                        }
                    }
                }
            }

            // Clear session notification cache on login
            uint32 guid = player->GetGUID().GetCounter();
            ClearSessionNotifiedAppearances(guid);
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

            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                if (spellInfo->Effects[i].Effect == SPELL_EFFECT_APPLY_AURA &&
                    (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED ||
                     spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOD_INCREASE_MOUNTED_FLIGHT_SPEED))
                {
                    isMount = true;
                    break;
                }
            }

            if (isMount)
            {
                std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
                if (itemsEntryCol.empty())
                    return;

                // Add mount to collection
                CharacterDatabase.Execute(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, {}, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'LEARNED', 1, NOW())",
                    itemsEntryCol, accountId, static_cast<uint8>(CollectionType::MOUNT), spellId);

                SendItemLearned(player, CollectionType::MOUNT, spellId);
                UpdateMountSpeedBonus(player);
            }
            else
            {
                uint32 companionSummonSpellId = ResolveCompanionSummonSpellFromSpell(spellId);
                if (!companionSummonSpellId)
                    return;

                uint32 itemId = FindCompanionItemIdForSpell(companionSummonSpellId);
                if (!itemId)
                    return;

                std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
                if (itemsEntryCol.empty())
                    return;

                CharacterDatabase.Execute(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, {}, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'LEARNED', 1, NOW())",
                    itemsEntryCol, accountId, static_cast<uint8>(CollectionType::PET), itemId);

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
                // Important: during LoginPlayer, visible item slots can be reset/initialized
                // before inventory items are fully loaded. In that phase, 'item' may be null
                // briefly even though an item is actually equipped.
                // If we delete here, transmogs get wiped on login.
                if (player->GetSession()->PlayerLoading())
                    return;

                // Slot is truly empty (not during load); clear transmog for that slot.
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
                TransmogAppearanceVariant appearance;
                appearance.canonicalItemId = fakeEntry;
                appearance.displayId = fakeProto->DisplayInfoID;
                appearance.inventoryType = fakeProto->InventoryType;
                appearance.itemClass = fakeProto->Class;
                appearance.itemSubClass = fakeProto->SubClass;
                appearance.quality = fakeProto->Quality;
                appearance.itemLevel = fakeProto->ItemLevel;
                appearance.itemIds.clear();
                appearance.itemIds.push_back(fakeEntry);

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

        void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootguid*/) override
        {
            if (!player || !item)
                return;

            if (!sConfigMgr->GetOption<bool>(Config::ENABLED, true))
                return;

            if (!sConfigMgr->GetOption<bool>(Config::TRANSMOG_UNLOCK_ON_LOOT, false))
                return;

            ItemTemplate const* proto = item->GetTemplate();
            if (proto)
                UnlockTransmogAppearance(player, proto, "LOOTED");
        }

        void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 /*count*/) override
        {
            if (!player || !item)
                return;

            if (!sConfigMgr->GetOption<bool>(Config::ENABLED, true))
                return;

            if (!sConfigMgr->GetOption<bool>(Config::TRANSMOG_UNLOCK_ON_QUEST_REWARD, false))
                return;

            ItemTemplate const* proto = item->GetTemplate();
            if (proto)
                UnlockTransmogAppearance(player, proto, "QUEST_REWARD");
        }


        void OnPlayerLogout(Player* player) override
        {
            if (!player)
                return;

            // Drop per-account transmog unlock cache (rebuilt on next request/login).
            uint32 accountId = GetAccountId(player);
            if (accountId)
                InvalidateAccountUnlockedTransmogAppearances(accountId);

            // Clear session notification cache on logout
            uint32 guid = player->GetGUID().GetCounter();
            EraseSessionNotifiedAppearances(guid);
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

        void OnAfterConfigLoad(bool reload) override
        {
            // Register module as enabled/disabled based on config
            bool enabled = sConfigMgr->GetOption<bool>(Config::ENABLED, true);
            DCAddon::MessageRouter::Instance().SetModuleEnabled(MODULE, enabled);

            if (enabled)
            {
                LOG_INFO("module.dc", "DC-Collection: Module enabled");
            }

            // Optional maintenance task. Run only at startup (not on config reload).
            if (!reload && enabled && sConfigMgr->GetOption<bool>(Config::PET_DEFINITIONS_REBUILD_ON_STARTUP, false))
            {
                RebuildPetDefinitionsFromLocalData();
            }
        }
    };

}  // namespace DCCollection

// =======================================================================
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



    // Register player and world scripts
    new CollectionPlayerScript();
    new CollectionMiscScript();
    new CollectionWorldScript();

    AddSC_dc_addon_wardrobe(); // Call Wardrobe registration

    LOG_INFO("server.loading", ">> Loaded DC-Collection addon handler");
}
