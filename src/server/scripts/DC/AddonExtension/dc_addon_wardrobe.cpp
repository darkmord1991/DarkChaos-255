/*
 * Dark Chaos - Collection System Addon (Wardrobe Extension)
 * =========================================================
 *
 * This file handles the Transmogrification system and Community Outfits platform.
 * Split from dc_addon_collection.cpp.
 */

#include "../../ScriptPCH.h"
#include "dc_addon_collection.h"
#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "ObjectAccessor.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "World.h"
#include "Chat.h"
#include "WorldPacket.h"
#include "Config.h"
#include "SpellMgr.h"
#include "Bag.h"
#include "CryptoHash.h"
#include <vector>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <map>
#include <algorithm>
#include <sstream>
#include <iomanip>
#include <mutex>

namespace DCCollection
{
    // =======================================================================
    // Configuration
    // =======================================================================
    
    // Transmog constants
    constexpr uint32 TRANSMOG_CANONICAL_ITEMID_THRESHOLD_VAL = 200000;
    constexpr const char* TRANSMOG_MIN_QUALITY = "DCCollection.Transmog.MinQuality";
    constexpr const char* TRANSMOG_SLOT_ITEMS_PAGE_SIZE = "DCCollection.Transmog.SlotItemsPageSize";
    constexpr const char* TRANSMOG_SESSION_NOTIFICATION_DEDUP = "DCCollection.Transmog.SessionNotificationDedup";

    // =======================================================================
    // Transmog Helper Implementations
    // =======================================================================

    bool IsBetterTransmogRepresentative(uint32 newEntry, bool newIsNonCustom, uint32 newQuality, uint32 newItemLevel,
        uint32 oldEntry, bool oldIsNonCustom, uint32 oldQuality, uint32 oldItemLevel)
    {
        if (newIsNonCustom != oldIsNonCustom)
            return newIsNonCustom;

        if (newQuality != oldQuality)
            return newQuality > oldQuality;

        if (newItemLevel != oldItemLevel)
            return newItemLevel > oldItemLevel;

        return newEntry < oldEntry;
    }

    static std::string BuildTransmogVariantKey(uint32 displayId, uint32 inventoryType, uint32 itemClass, uint32 itemSubClass)
    {
        return std::to_string(displayId) + ":" + std::to_string(inventoryType) + ":" + std::to_string(itemClass) + ":" + std::to_string(itemSubClass);
    }

    using AppearanceIndex = std::unordered_map<uint32, std::vector<TransmogAppearanceVariant>>;

    AppearanceIndex BuildTransmogAppearanceIndex()
    {
        AppearanceIndex defs;

        QueryResult result = WorldDatabase.Query(
            "SELECT entry, displayid, name, class, subclass, InventoryType, Quality, ItemLevel "
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
            uint32 itemLevel = fields[7].Get<uint32>();

            if (!displayId)
                continue;

            auto& variants = defs[displayId];

            TransmogAppearanceVariant* bucket = nullptr;
            for (auto& v : variants)
            {
                if (v.inventoryType == inventoryType && v.itemClass == itemClass && v.itemSubClass == itemSubClass)
                {
                    bucket = &v;
                    break;
                }
            }

            if (!bucket)
            {
                TransmogAppearanceVariant v;
                v.canonicalItemId = entry;
                v.displayId = displayId;
                v.inventoryType = inventoryType;
                v.itemClass = itemClass;
                v.itemSubClass = itemSubClass;
                v.quality = quality;
                v.itemLevel = itemLevel;
                v.name = name;
                v.itemIds.push_back(entry);
                variants.push_back(std::move(v));
                continue;
            }

            bucket->itemIds.push_back(entry);

            bool entryIsNonCustom = entry < TRANSMOG_CANONICAL_ITEMID_THRESHOLD_VAL;
            bool existingIsNonCustom = bucket->canonicalItemId < TRANSMOG_CANONICAL_ITEMID_THRESHOLD_VAL;
            if (IsBetterTransmogRepresentative(entry, entryIsNonCustom, quality, itemLevel,
                bucket->canonicalItemId, existingIsNonCustom, bucket->quality, bucket->itemLevel))
            {
                bucket->canonicalItemId = entry;
                bucket->quality = quality;
                bucket->itemLevel = itemLevel;
                bucket->name = name;
            }
        } while (result->NextRow());

        for (auto& [_, variants] : defs)
        {
            for (auto& v : variants)
            {
                std::sort(v.itemIds.begin(), v.itemIds.end());
                v.itemIds.erase(std::unique(v.itemIds.begin(), v.itemIds.end()), v.itemIds.end());
            }
        }

        return defs;
    }

    // Explicitly convert unordered_map to map for the header interface if needed,
    // OR change the header to use unordered_map.
    // The header declared `std::map<uint32, std::vector<TransmogAppearanceVariant>>`.
    // My local `AppearanceIndex` is unordered_map.
    // I will change the internal one to `std::map` to match header, or change header.
    // Using `std::map` is safer for header inclusion, though unordered_map is faster.
    // Given the size, map is acceptable for lookup. 
    // Wait, the header declared `std::map`. I should respect that or update header.
    // I'll update the implementation here to use std::map to match header for now.
    // Actually, I can use an internal cache and return a reference to it.
    
    // Re-declaring AppearanceIndex to match header:
    using PublicAppearanceIndex = std::map<uint32, std::vector<TransmogAppearanceVariant>>;

    PublicAppearanceIndex BuildTransmogAppearanceIndexMap()
    {
        // Copy-paste logic but use map
        PublicAppearanceIndex defs;
        // ... build logic ... 
        // It's the same logic.
        QueryResult result = WorldDatabase.Query(
            "SELECT entry, displayid, name, class, subclass, InventoryType, Quality, ItemLevel "
            "FROM item_template "
            "WHERE displayid <> 0 "
            "  AND class IN (2, 4) " // weapon, armor
            "  AND InventoryType <> 0");

        if (!result) return defs;

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
            uint32 itemLevel = fields[7].Get<uint32>();

            if (!displayId) continue;

            auto& variants = defs[displayId];
            TransmogAppearanceVariant* bucket = nullptr;
            for (auto& v : variants)
            {
                if (v.inventoryType == inventoryType && v.itemClass == itemClass && v.itemSubClass == itemSubClass)
                {
                    bucket = &v;
                    break;
                }
            }

            if (!bucket)
            {
                TransmogAppearanceVariant v;
                v.canonicalItemId = entry;
                v.displayId = displayId;
                v.inventoryType = inventoryType;
                v.itemClass = itemClass;
                v.itemSubClass = itemSubClass;
                v.quality = quality;
                v.itemLevel = itemLevel;
                v.name = name;
                v.itemIds.push_back(entry);
                variants.push_back(std::move(v));
                continue;
            }
            bucket->itemIds.push_back(entry);

            bool entryIsNonCustom = entry < TRANSMOG_CANONICAL_ITEMID_THRESHOLD_VAL;
            bool existingIsNonCustom = bucket->canonicalItemId < TRANSMOG_CANONICAL_ITEMID_THRESHOLD_VAL;
            if (IsBetterTransmogRepresentative(entry, entryIsNonCustom, quality, itemLevel,
                bucket->canonicalItemId, existingIsNonCustom, bucket->quality, bucket->itemLevel))
            {
                bucket->canonicalItemId = entry;
                bucket->quality = quality;
                bucket->itemLevel = itemLevel;
                bucket->name = name;
            }
        } while (result->NextRow());

        for (auto& [_, variants] : defs)
        {
            for (auto& v : variants)
            {
                std::sort(v.itemIds.begin(), v.itemIds.end());
                v.itemIds.erase(std::unique(v.itemIds.begin(), v.itemIds.end()), v.itemIds.end());
            }
        }
        return defs;
    }

    std::map<uint32, std::vector<TransmogAppearanceVariant>> const& GetTransmogAppearanceIndexCached()
    {
        static PublicAppearanceIndex cached;
        static bool initialized = false;
        if (!initialized)
        {
            cached = BuildTransmogAppearanceIndexMap();
            initialized = true;
        }
        return cached;
    }

    std::vector<std::string> const& GetTransmogAppearanceVariantKeysCached()
    {
        static std::vector<std::string> keys;
        static bool initialized = false;
        if (!initialized)
        {
            auto const& appearances = GetTransmogAppearanceIndexCached();
            std::vector<std::tuple<uint32, uint32, uint32, uint32, std::string>> tmp;
            tmp.reserve(appearances.size());

            for (auto const& [displayId, variants] : appearances)
            {
                for (auto const& v : variants)
                {
                    tmp.emplace_back(displayId, v.inventoryType, v.itemClass, v.itemSubClass,
                        BuildTransmogVariantKey(displayId, v.inventoryType, v.itemClass, v.itemSubClass));
                }
            }

            std::sort(tmp.begin(), tmp.end(), [](auto const& a, auto const& b)
            {
                return std::tie(std::get<0>(a), std::get<1>(a), std::get<2>(a), std::get<3>(a))
                    < std::tie(std::get<0>(b), std::get<1>(b), std::get<2>(b), std::get<3>(b));
            });

            keys.reserve(tmp.size());
            for (auto const& t : tmp)
                keys.push_back(std::get<4>(t));

            initialized = true;
        }
        return keys;
    }

    uint32 GetTransmogDefinitionsSyncVersionCached()
    {
        static uint32 version = 0;
        static bool initialized = false;
        if (initialized) return version;

        uint32 h = 2166136261u;
        auto fnvMixU32 = [&](uint32 v)
        {
            for (int i = 0; i < 4; ++i)
            {
                h ^= (v & 0xFFu);
                h *= 16777619u;
                v >>= 8;
            }
        };

        auto const& appearances = GetTransmogAppearanceIndexCached();
        for (auto const& [displayId, variants] : appearances)
        {
            for (auto const& v : variants)
            {
                fnvMixU32(displayId);
                fnvMixU32(v.inventoryType);
                fnvMixU32(v.canonicalItemId);
            }
        }

        version = h;
        initialized = true;
        return version;
    }
    
    // =======================================================================
    // Helpers
    // =======================================================================

    static inline bool IsDigitsOnly(std::string const& s)
    {
        if (s.empty())
            return false;
        for (unsigned char c : s)
            if (c < '0' || c > '9')
                return false;
        return true;
    }

    static inline bool ContainsCaseInsensitive(std::string const& haystack, std::string const& needleLower)
    {
        if (needleLower.empty())
            return true;

        // Simple ASCII case-insensitive substring search without allocations.
        size_t const n = needleLower.size();
        size_t const h = haystack.size();
        if (n > h)
            return false;

        for (size_t i = 0; i + n <= h; ++i)
        {
            bool match = true;
            for (size_t j = 0; j < n; ++j)
            {
                unsigned char c = static_cast<unsigned char>(haystack[i + j]);
                c = static_cast<unsigned char>(std::tolower(c));
                if (c != static_cast<unsigned char>(needleLower[j]))
                {
                    match = false;
                    break;
                }
            }
            if (match)
                return true;
        }
        return false;
    }

    static void EnsureCommunityTables()
    {
        static std::once_flag once;
        std::call_once(once, []()
        {
            CharacterDatabase.Execute(
                "CREATE TABLE IF NOT EXISTS dc_collection_community_outfits ("
                "id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,"
                "name VARCHAR(100),"
                "author_name VARCHAR(50),"
                "author_guid INT UNSIGNED,"
                "items_string TEXT,"
                "upvotes INT UNSIGNED DEFAULT 0,"
                "downloads INT UNSIGNED DEFAULT 0,"
                "views INT UNSIGNED DEFAULT 0,"
                "weekly_votes INT UNSIGNED DEFAULT 0,"
                "tags VARCHAR(255) DEFAULT '',"
                "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
                ")");

            CharacterDatabase.Execute(
                "CREATE TABLE IF NOT EXISTS dc_collection_community_favorites ("
                "account_id INT UNSIGNED,"
                "outfit_id INT UNSIGNED,"
                "PRIMARY KEY(account_id, outfit_id)"
                ")");
        });
    }

    uint8 VisualSlotToEquipmentSlot(uint32 visualSlot)
    {
        switch (visualSlot)
        {
            case 283: return EQUIPMENT_SLOT_HEAD;
            case 287: return EQUIPMENT_SLOT_SHOULDERS;
            case 289: return EQUIPMENT_SLOT_BODY;
            case 291: return EQUIPMENT_SLOT_CHEST;
            case 293: return EQUIPMENT_SLOT_WAIST;
            case 295: return EQUIPMENT_SLOT_LEGS;
            case 297: return EQUIPMENT_SLOT_FEET;
            case 299: return EQUIPMENT_SLOT_WRISTS;
            case 301: return EQUIPMENT_SLOT_HANDS;
            case 311: return EQUIPMENT_SLOT_BACK;
            case 313: return EQUIPMENT_SLOT_MAINHAND;
            case 315: return EQUIPMENT_SLOT_OFFHAND;
            case 317: return EQUIPMENT_SLOT_RANGED;
            case 319: return EQUIPMENT_SLOT_TABARD;
            default:  return 255;
        }
    }

    std::vector<uint32> GetInvTypesForVisualSlot(uint32 visualSlot)
    {
        switch (visualSlot)
        {
            case 283: return { INVTYPE_HEAD };
            case 287: return { INVTYPE_SHOULDERS };
            case 289: return { INVTYPE_BODY };
            case 291: return { INVTYPE_CHEST, INVTYPE_ROBE };
            case 293: return { INVTYPE_WAIST };
            case 295: return { INVTYPE_LEGS };
            case 297: return { INVTYPE_FEET };
            case 299: return { INVTYPE_WRISTS };
            case 301: return { INVTYPE_HANDS };
            case 311: return { INVTYPE_CLOAK };
            case 313: return { INVTYPE_WEAPON, INVTYPE_2HWEAPON, INVTYPE_WEAPONMAINHAND };
            case 315: return { INVTYPE_WEAPON, INVTYPE_WEAPONOFFHAND, INVTYPE_SHIELD, INVTYPE_HOLDABLE, INVTYPE_2HWEAPON };
            case 317: return { INVTYPE_RANGED, INVTYPE_RANGEDRIGHT, INVTYPE_THROWN, INVTYPE_RELIC };
            case 319: return { INVTYPE_TABARD };
            default:  return {};
        }
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

    bool IsWeaponCompatible(uint32 subClass1, uint32 subClass2)
    {
        if (subClass1 == subClass2) return true;
        auto is1H = [](uint32 s) { return s == ITEM_SUBCLASS_WEAPON_AXE || s == ITEM_SUBCLASS_WEAPON_MACE || s == ITEM_SUBCLASS_WEAPON_SWORD; };
        auto is2H = [](uint32 s) { return s == ITEM_SUBCLASS_WEAPON_AXE2 || s == ITEM_SUBCLASS_WEAPON_MACE2 || s == ITEM_SUBCLASS_WEAPON_SWORD2; };
        auto isRanged = [](uint32 s) { return s == ITEM_SUBCLASS_WEAPON_BOW || s == ITEM_SUBCLASS_WEAPON_GUN || s == ITEM_SUBCLASS_WEAPON_CROSSBOW; };
        if (is1H(subClass1) && is1H(subClass2)) return true;
        if (is2H(subClass1) && is2H(subClass2)) return true;
        if (isRanged(subClass1) && isRanged(subClass2)) return true;
        if ((subClass1 == ITEM_SUBCLASS_WEAPON_POLEARM || subClass1 == ITEM_SUBCLASS_WEAPON_STAFF) &&
            (subClass2 == ITEM_SUBCLASS_WEAPON_POLEARM || subClass2 == ITEM_SUBCLASS_WEAPON_STAFF))
            return true;
        return false;
    }

    bool IsAppearanceCompatible(uint8 slot, ItemTemplate const* equipped, TransmogAppearanceVariant const& appearance)
    {
        if (!equipped) return false;
        if (equipped->Class != ITEM_CLASS_ARMOR && equipped->Class != ITEM_CLASS_WEAPON) return false;
        if (appearance.itemClass != equipped->Class) return false;
        
        if (appearance.itemSubClass != equipped->SubClass)
        {
            if (equipped->Class == ITEM_CLASS_WEAPON)
            {
                if (!IsWeaponCompatible(equipped->SubClass, appearance.itemSubClass)) return false;
            }
            else return false;
        }

        if (!IsInvTypeCompatibleForSlot(slot, appearance.inventoryType)) return false;
        if (!IsInvTypeCompatibleForSlot(slot, equipped->InventoryType)) return false;

        if (slot == EQUIPMENT_SLOT_CHEST)
        {
            auto isChestLike = [](uint32 inv) { return inv == INVTYPE_CHEST || inv == INVTYPE_ROBE; };
            return isChestLike(equipped->InventoryType) && isChestLike(appearance.inventoryType);
        }

        if (equipped->InventoryType != appearance.inventoryType)
        {
            if (slot == EQUIPMENT_SLOT_MAINHAND || slot == EQUIPMENT_SLOT_OFFHAND) return true;
            return false;
        }

        return true;
    }

    TransmogAppearanceVariant const* FindBestVariantForSlot(uint32 displayId, uint8 slot, ItemTemplate const* equippedProto)
    {
        auto const& idx = GetTransmogAppearanceIndexCached();
        auto it = idx.find(displayId);
        if (it == idx.end()) return nullptr;

        TransmogAppearanceVariant const* best = nullptr;
        for (auto const& v : it->second)
        {
            if (!IsAppearanceCompatible(slot, equippedProto, v)) continue;
            if (!best) { best = &v; continue; }

            bool newIsNonCustom = v.canonicalItemId < TRANSMOG_CANONICAL_ITEMID_THRESHOLD_VAL;
            bool oldIsNonCustom = best->canonicalItemId < TRANSMOG_CANONICAL_ITEMID_THRESHOLD_VAL;
            if (IsBetterTransmogRepresentative(v.canonicalItemId, newIsNonCustom, v.quality, v.itemLevel,
                best->canonicalItemId, oldIsNonCustom, best->quality, best->itemLevel))
            {
                best = &v;
            }
        }
        return best;
    }
    
    TransmogAppearanceVariant const* FindAnyVariant(uint32 displayId)
    {
        auto const& idx = GetTransmogAppearanceIndexCached();
        auto it = idx.find(displayId);
        if (it != idx.end() && !it->second.empty())
            return &it->second[0];
        return nullptr;
    }

    // Unlocking Logic
    static std::unordered_map<uint32, std::unordered_set<uint32>> s_AccountUnlockedTransmogAppearances;
    constexpr size_t MAX_NOTIFIED_APPEARANCES_PER_PLAYER = 10000;
    static std::unordered_map<uint32, std::unordered_set<uint32>> sessionNotifiedAppearances;

    void InvalidateAccountUnlockedTransmogAppearances(uint32 accountId)
    {
        s_AccountUnlockedTransmogAppearances.erase(accountId);
    }

    // Session notification helpers: keep the actual storage private to this translation unit.
    void ClearSessionNotifiedAppearances(uint32 guid)
    {
        sessionNotifiedAppearances[guid].clear();
    }

    void EraseSessionNotifiedAppearances(uint32 guid)
    {
        sessionNotifiedAppearances.erase(guid);
    }

    static std::unordered_set<uint32> const& GetAccountUnlockedTransmogAppearances(uint32 accountId)
    {
        auto it = s_AccountUnlockedTransmogAppearances.find(accountId);
        if (it != s_AccountUnlockedTransmogAppearances.end()) return it->second;

        std::unordered_set<uint32> unlocked;
        
        // Try new cache table first (90%+ faster)
        if (CharacterTableExists("dc_account_transmog_cache"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT displayid FROM dc_account_transmog_cache WHERE account_id = {}",
                accountId);
            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint32 dId = fields[0].Get<uint32>();
                    if (dId) unlocked.insert(dId);
                } while (result->NextRow());
            }
        }
        else
        {
            // Fallback to old table for backward compatibility
            std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
            if (!itemsEntryCol.empty())
            {
                 QueryResult result = CharacterDatabase.Query(
                    "SELECT {} FROM dc_collection_items WHERE account_id = {} AND collection_type = {} AND unlocked = 1",
                    itemsEntryCol, accountId, static_cast<uint8>(CollectionType::TRANSMOG));
                if (result)
                {
                    do
                    {
                        Field* fields = result->Fetch();
                        uint32 dId = fields[0].Get<uint32>();
                        if (dId) unlocked.insert(dId);
                    } while (result->NextRow());
                }
            }
        }
        auto [insertedIt, _] = s_AccountUnlockedTransmogAppearances.emplace(accountId, std::move(unlocked));
        return insertedIt->second;
    }

    bool HasTransmogAppearanceUnlocked(uint32 accountId, uint32 displayId)
    {
        if (!accountId || !displayId) return false;
        auto const& unlocked = GetAccountUnlockedTransmogAppearances(accountId);
        return unlocked.find(displayId) != unlocked.end();
    }

    bool IsItemEligibleForTransmogUnlock(ItemTemplate const* proto)
    {
        if (!proto || !proto->DisplayInfoID) return false;
        if (proto->Class != ITEM_CLASS_WEAPON && proto->Class != ITEM_CLASS_ARMOR) return false;
        if (proto->InventoryType == INVTYPE_NON_EQUIP) return false;
        return true;
    }

    uint32 GetItemDisplayId(ItemTemplate const* proto)
    {
        return proto ? proto->DisplayInfoID : 0;
    }

    void UnlockTransmogAppearance(Player* player, ItemTemplate const* proto, std::string const& source, bool notifyPlayer)
    {
        if (!player || !player->GetSession() || !proto) return;
        if (!IsItemEligibleForTransmogUnlock(proto)) return;
        
        uint32 minQuality = sConfigMgr->GetOption<uint32>(TRANSMOG_MIN_QUALITY, 0);
        if (proto->Quality < minQuality) return;

        uint32 accountId = GetAccountId(player);
        if (!accountId) return;

        uint32 displayId = GetItemDisplayId(proto);
        if (!displayId) return;

        if (HasTransmogAppearanceUnlocked(accountId, displayId)) return;

        bool shouldNotify = notifyPlayer;
        if (sConfigMgr->GetOption<bool>(TRANSMOG_SESSION_NOTIFICATION_DEDUP, true))
        {
             uint32 guid = player->GetGUID().GetCounter();
             auto& playerNotifications = sessionNotifiedAppearances[guid];
             if (playerNotifications.count(displayId)) shouldNotify = false;
             else if (playerNotifications.size() < MAX_NOTIFIED_APPEARANCES_PER_PLAYER)
                 playerNotifications.insert(displayId);
        }

        std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
        if (itemsEntryCol.empty()) return;

        CharacterDatabase.Execute(
            "INSERT IGNORE INTO dc_collection_items "
            "(account_id, collection_type, {}, source_type, unlocked, acquired_date) "
            "VALUES ({}, {}, {}, '{}', 1, NOW())",
            itemsEntryCol, accountId, static_cast<uint8>(CollectionType::TRANSMOG), displayId, source);

        // Also populate new cache table if it exists (90%+ faster lookups)
        if (CharacterTableExists("dc_account_transmog_cache"))
        {
            CharacterDatabase.Execute(
                "INSERT IGNORE INTO dc_account_transmog_cache "
                "(account_id, displayid, source, unlocked_at) "
                "VALUES ({}, {}, '{}', NOW())",
                accountId, displayId, source);
        }

        auto cacheIt = s_AccountUnlockedTransmogAppearances.find(accountId);
        if (cacheIt != s_AccountUnlockedTransmogAppearances.end())
            cacheIt->second.insert(displayId);

        if (shouldNotify)
        {
            if (WorldSession* session = player->GetSession())
            {
                 ChatHandler handler(session);
                 handler.PSendSysMessage("DC-Collection: Appearance collected: {} (appearance {}).", proto->Name1, displayId);
            }
        }
    }

    // =======================================================================
    // Handlers
    // =======================================================================

    void SendTransmogState(Player* player)
    {
        if (!player || !player->GetSession()) return;

        DCAddon::JsonValue state;
        state.SetObject();

        QueryResult result = CharacterDatabase.Query(
            "SELECT slot, fake_entry FROM dc_character_transmog WHERE guid = {}",
            player->GetGUID().GetCounter());

        if (result)
        {
            auto const& appearances = GetTransmogAppearanceIndexCached();
            do
            {
                Field* fields = result->Fetch();
                uint32 slot = fields[0].Get<uint32>();
                uint32 fakeEntry = fields[1].Get<uint32>();
                uint32 displayId = 0;
                ItemTemplate const* fakeProto = sObjectMgr->GetItemTemplate(fakeEntry);
                if (fakeProto) displayId = fakeProto->DisplayInfoID;
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

    void HandleSetTransmogMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
         if (!player || !player->GetSession()) return;
         if (!DCAddon::IsJsonMessage(msg)) return;

         DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
         uint8 slot = static_cast<uint8>(json["slot"].AsUInt32());
         bool clear = json.HasKey("clear") ? json["clear"].AsBool() : false;
         // Client may send either a transmog appearance displayId OR an item entry ID.
         // Prefer displayId when it is already unlocked; otherwise try to interpret
         // it as an item entry and derive the displayId from the item template.
         uint32 displayId = json.HasKey("appearanceId") ? json["appearanceId"].AsUInt32() : 0;

         if (slot >= EQUIPMENT_SLOT_END) return;
         
         Item* equippedItem = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
         if (!equippedItem) return;

         uint32 guid = player->GetGUID().GetCounter();
         uint32 accountId = GetAccountId(player);

         if (clear)
         {
             CharacterDatabase.Execute("DELETE FROM dc_character_transmog WHERE guid = {} AND slot = {}", guid, static_cast<uint32>(slot));
             player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (slot * 2), equippedItem->GetEntry());
             SendTransmogState(player);
             return;
         }

         if (!displayId)
             return;

         if (!HasTransmogAppearanceUnlocked(accountId, displayId))
         {
             // Fallback: if the value is actually an item entry, derive its displayId.
             if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(displayId))
             {
                 uint32 derived = proto->DisplayInfoID;
                 if (derived && HasTransmogAppearanceUnlocked(accountId, derived))
                     displayId = derived;
             }
         }

         if (!HasTransmogAppearanceUnlocked(accountId, displayId))
             return;

         ItemTemplate const* equippedProto = equippedItem->GetTemplate();
         TransmogAppearanceVariant const* appearance = FindBestVariantForSlot(displayId, slot, equippedProto);
         if (!appearance) return;

         uint32 fakeEntry = appearance->canonicalItemId;
         CharacterDatabase.Execute(
             "REPLACE INTO dc_character_transmog (guid, slot, fake_entry, real_entry) VALUES ({}, {}, {}, {})",
             guid, static_cast<uint32>(slot), fakeEntry, equippedItem->GetEntry());

         player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (slot * 2), fakeEntry);
         SendTransmogState(player);
    }

    void HandleGetTransmogState(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendTransmogState(player);
    }

    void HandleApplyTransmogPreview(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession()) return;
        if (!DCAddon::IsJsonMessage(msg)) return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.HasKey("preview")) return;
        DCAddon::JsonValue preview = json["preview"];

        uint32 accountId = GetAccountId(player);
        uint32 guid = player->GetGUID().GetCounter();

        auto trans = CharacterDatabase.BeginTransaction();
        for (auto const& kv : preview.AsObject())
        {
             uint32 visualSlot = std::stoul(kv.first);
             uint8 equipmentSlot = VisualSlotToEquipmentSlot(visualSlot);
             if (equipmentSlot >= EQUIPMENT_SLOT_END) continue;

             Item* equippedItem = player->GetItemByPos(INVENTORY_SLOT_BAG_0, equipmentSlot);
             if (!equippedItem) continue;

             DCAddon::JsonValue const& slotValue = kv.second;
             if (slotValue.IsNull()) {
                 trans->Append("DELETE FROM dc_character_transmog WHERE guid = {} AND slot = {}", guid, (uint32)equipmentSlot);
                 player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (equipmentSlot * 2), equippedItem->GetEntry());
             } else if (slotValue.AsUInt32() == 0) {
                 trans->Append("REPLACE INTO dc_character_transmog (guid, slot, fake_entry, real_entry) VALUES ({}, {}, 0, {})", guid, (uint32)equipmentSlot, equippedItem->GetEntry());
                 player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (equipmentSlot * 2), 0);
             } else {
                 uint32 itemId = slotValue.AsUInt32();
                 ItemTemplate const* fakeProto = sObjectMgr->GetItemTemplate(itemId);
                 if (!fakeProto) continue;
                 uint32 displayId = fakeProto->DisplayInfoID;
                 if (!HasTransmogAppearanceUnlocked(accountId, displayId)) continue;
                 if (!FindBestVariantForSlot(displayId, equipmentSlot, equippedItem->GetTemplate())) continue;

                 trans->Append("REPLACE INTO dc_character_transmog (guid, slot, fake_entry, real_entry) VALUES ({}, {}, {}, {})", guid, (uint32)equipmentSlot, itemId, equippedItem->GetEntry());
                 player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (equipmentSlot * 2), itemId);
             }
        }

        CharacterDatabase.CommitTransaction(trans);
        SendTransmogState(player);
    }

    std::vector<uint32> GetCollectedAppearancesForSlot(Player* player, uint32 visualSlot, std::string const& searchFilter = "")
    {
        if (!player) return {};
        uint32 accountId = GetAccountId(player);
        std::vector<uint32> invTypes = GetInvTypesForVisualSlot(visualSlot);
        if (invTypes.empty()) return {};

        uint32 minQuality = sConfigMgr->GetOption<uint32>(TRANSMOG_MIN_QUALITY, 0);

        uint8 equipmentSlot = VisualSlotToEquipmentSlot(visualSlot);
        Item* equippedItem = (equipmentSlot < EQUIPMENT_SLOT_END) ? player->GetItemByPos(INVENTORY_SLOT_BAG_0, equipmentSlot) : nullptr;
        
        bool hasSearch = !searchFilter.empty();
        bool searchIsDigitsOnly = hasSearch && IsDigitsOnly(searchFilter);
        uint32 searchNumeric = 0;
        if (searchIsDigitsOnly)
            searchNumeric = static_cast<uint32>(std::strtoul(searchFilter.c_str(), nullptr, 10));

        std::string searchLower;
        if (hasSearch && !searchIsDigitsOnly)
        {
            searchLower = searchFilter;
            std::transform(searchLower.begin(), searchLower.end(), searchLower.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        }

        auto const& appearances = GetTransmogAppearanceIndexCached();
        std::vector<uint32> matchingItemIds;
        matchingItemIds.reserve(128);

        // Critical optimization: iterate the player's unlocked displayIds instead of scanning the entire item_template-derived index.
        // Scanning the full index on each slot/search request can hitch the world thread even with few players.
        auto const& unlocked = GetAccountUnlockedTransmogAppearances(accountId);
        for (uint32 displayId : unlocked)
        {
            auto it = appearances.find(displayId);
            if (it == appearances.end())
                continue;

            for (auto const& def : it->second)
            {
                if (def.quality < minQuality)
                    continue;

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

                if (equippedItem && !IsAppearanceCompatible(equipmentSlot, equippedItem->GetTemplate(), def))
                    continue;

                if (hasSearch)
                {
                    bool matchFound = false;

                    if (searchIsDigitsOnly)
                    {
                        // Numeric searches are common; avoid string allocations.
                        if (searchNumeric == displayId)
                            matchFound = true;
                        if (!matchFound)
                        {
                            for (uint32 itemId : def.itemIds)
                            {
                                if (itemId == searchNumeric)
                                {
                                    matchFound = true;
                                    break;
                                }
                            }
                        }
                    }
                    else
                    {
                        if (ContainsCaseInsensitive(def.name, searchLower))
                            matchFound = true;
                    }

                    if (!matchFound)
                        continue;
                }

                matchingItemIds.push_back(def.canonicalItemId);
            }
        }
        return matchingItemIds;
    }

    void SendTransmogSlotItemsResponse(Player* player, uint32 visualSlot, uint32 page, std::vector<uint32> const& matchingItemIds, std::string const& searchFilter)
    {
        uint32 pageSize = sConfigMgr->GetOption<uint32>(TRANSMOG_SLOT_ITEMS_PAGE_SIZE, 24);
        if (pageSize < 6) pageSize = 6;
        uint32 totalCount = static_cast<uint32>(matchingItemIds.size());
        uint32 startIdx = (page > 0) ? (page - 1) * pageSize : 0;
        bool hasMore = (startIdx + pageSize) < totalCount;

        DCAddon::JsonValue items;
        items.SetArray();
        for (uint32 i = startIdx; i < totalCount && i < startIdx + pageSize; ++i)
            items.Push(DCAddon::JsonValue(matchingItemIds[i]));

        DCAddon::JsonMessage response(MODULE, DCAddon::Opcode::Collection::SMSG_TRANSMOG_SLOT_ITEMS);
        response.Set("slot", visualSlot);
        response.Set("page", page);
        response.Set("hasMore", hasMore);
        
        response.Set("items", items);
        response.Set("total", totalCount);
        if (!searchFilter.empty()) response.Set("search", searchFilter);
        response.Send(player);
    }

    void HandleGetTransmogSlotItems(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession() || !DCAddon::IsJsonMessage(msg)) return;
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 visualSlot = json["slot"].AsUInt32();
        uint32 page = json.HasKey("page") ? json["page"].AsUInt32() : 1;
        std::vector<uint32> matching = GetCollectedAppearancesForSlot(player, visualSlot, "");
        SendTransmogSlotItemsResponse(player, visualSlot, page, matching, "");
    }

    void HandleSearchTransmogItems(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession() || !DCAddon::IsJsonMessage(msg)) return;
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 visualSlot = json["slot"].AsUInt32();
        std::string search = json.HasKey("search") ? json["search"].AsString() : "";
        uint32 page = json.HasKey("page") ? json["page"].AsUInt32() : 1;
        std::vector<uint32> matching = GetCollectedAppearancesForSlot(player, visualSlot, search);
        SendTransmogSlotItemsResponse(player, visualSlot, page, matching, search);
    }

    void HandleGetCollectedAppearances(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player) return;
        uint32 accountId = GetAccountId(player);
        auto const& unlocked = GetAccountUnlockedTransmogAppearances(accountId);
        
        DCAddon::JsonValue appArr; appArr.SetArray();
        for (uint32 d : unlocked) appArr.Push(DCAddon::JsonValue(d));

        // NOTE: We intentionally do NOT include a secondary "items" array here.
        // Building canonical itemId lists forces loading the full transmog appearance index
        // (item_template scan), which can cause noticeable server hitching when the addon opens.
        DCAddon::JsonMessage response(MODULE, DCAddon::Opcode::Collection::SMSG_COLLECTED_APPEARANCES);
        response.Set("count", static_cast<uint32>(unlocked.size()));
        response.Set("appearances", appArr);
        response.Send(player);
    }

    // =======================================================================
    // Community Outfits Platform Handlers
    // =======================================================================

    void HandleCommunityGetList(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        EnsureCommunityTables();

        uint32 offset = 0;
        uint32 limit = 50;
        std::string filter = "all";
        std::string sort = "popular";
        
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
            if (json.HasKey("offset")) offset = json["offset"].AsUInt32();
            if (json.HasKey("limit")) limit = json["limit"].AsUInt32();
            if (json.HasKey("filter")) filter = json["filter"].AsString();
            if (json.HasKey("sort")) sort = json["sort"].AsString();
        }
        if (limit > 50) limit = 50;

        if (limit > 50) limit = 50;
        
        // Table existence check removed (WorldTableExists checks World DB, but table is in Character DB)


        uint32 accountId = GetAccountId(player);
        
        std::string orderBy = "o.upvotes DESC";
        if (sort == "trending") orderBy = "o.weekly_votes DESC";
        else if (sort == "most_viewed") orderBy = "o.views DESC";
        else if (sort == "newest") orderBy = "o.created_at DESC";
        else if (sort == "downloads") orderBy = "o.downloads DESC";
        
        // Tag filtering
        std::string tagFilterWrapper = "";
        std::string tagFilterCondition = "";
        
        // Basic tag filter: if filter starts with "tag:", extract tag.
        if (filter.find("tag:") == 0)
        {
            std::string tag = filter.substr(4);
            CharacterDatabase.EscapeString(tag);
            tagFilterCondition = " AND o.tags LIKE '%" + tag + "%' ";
            filter = "tag"; // Override filter mode to just use WHERE clause
        }

        std::string sql;
        if (filter == "favorites")
        {
            sql = Acore::StringFormat(
                "SELECT o.id, o.name, o.author_name, o.items_string, o.upvotes, o.downloads, 1 as is_favorite, o.views, o.tags "
                "FROM dc_collection_community_outfits o "
                "JOIN dc_collection_community_favorites f ON o.id = f.outfit_id "
                "WHERE f.account_id = {} {} "
                "ORDER BY {} LIMIT {}, {}",
                accountId, tagFilterCondition, orderBy, offset, limit);
        }
        else if (filter == "my_outfits")
        {
            uint32 playerGuid = player->GetGUID().GetCounter();
            sql = Acore::StringFormat(
                "SELECT o.id, o.name, o.author_name, o.items_string, o.upvotes, o.downloads, "
                "CASE WHEN f.account_id IS NOT NULL THEN 1 ELSE 0 END as is_favorite, "
                "o.views, o.tags "
                "FROM dc_collection_community_outfits o "
                "LEFT JOIN dc_collection_community_favorites f ON f.outfit_id = o.id AND f.account_id = {} "
                "WHERE o.author_guid = {} {} "
                "ORDER BY o.created_at DESC LIMIT {}, {}",
                accountId, playerGuid, tagFilterCondition, offset, limit);
        }
        else
        {
            std::string whereClause = (filter == "tag" && !tagFilterCondition.empty()) ? "WHERE " + tagFilterCondition.substr(5) : "";
            sql = Acore::StringFormat(
                "SELECT o.id, o.name, o.author_name, o.items_string, o.upvotes, o.downloads, "
                "CASE WHEN f.account_id IS NOT NULL THEN 1 ELSE 0 END as is_favorite, "
                "o.views, o.tags "
                "FROM dc_collection_community_outfits o "
                "LEFT JOIN dc_collection_community_favorites f ON f.outfit_id = o.id AND f.account_id = {} "
                "{} "
                "ORDER BY {} LIMIT {}, {}",
                accountId, whereClause, orderBy, offset, limit);
        }

        ObjectGuid playerGuid = player->GetGUID();
        CharacterDatabase.AsyncQuery(sql).WithCallback([playerGuid](QueryResult result)
        {
            Player* player = ObjectAccessor::FindPlayer(playerGuid);
            if (!player)
                return;

            DCAddon::JsonValue outfits;
            outfits.SetArray();
            if (result)
            {
                do
                {
                    Field* f = result->Fetch();
                    DCAddon::JsonValue obj;
                    obj.SetObject();
                    obj.Set("id", f[0].Get<uint32>());
                    obj.Set("name", f[1].Get<std::string>());
                    obj.Set("author", f[2].Get<std::string>());
                    obj.Set("items", f[3].Get<std::string>());
                    obj.Set("upvotes", f[4].Get<uint32>());
                    obj.Set("downloads", f[5].Get<uint32>());
                    obj.Set("is_favorite", f[6].Get<bool>());
                    obj.Set("views", f[7].Get<uint32>());
                    obj.Set("tags", f[8].Get<std::string>());
                    outfits.Push(obj);
                } while (result->NextRow());
            }

            DCAddon::JsonMessage response(MODULE, DCAddon::Opcode::Collection::SMSG_COMMUNITY_LIST);
            response.Set("outfits", outfits);
            response.Send(player);
        });
    }

    void HandleCommunityPublish(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg)) return;

        EnsureCommunityTables();

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        std::string name = json["name"].AsString();
        std::string items = json["items"].AsString();
        std::string tags = "";
        if (json.HasKey("tags")) tags = json["tags"].AsString();
        
        CharacterDatabase.EscapeString(name);
        CharacterDatabase.EscapeString(items);
        CharacterDatabase.EscapeString(tags);
        
        std::string insertSql = Acore::StringFormat(
            "INSERT INTO dc_collection_community_outfits (name, author_name, author_guid, items_string, tags) "
            "VALUES ('{}', '{}', {}, '{}', '{}')",
            name, player->GetName(), player->GetGUID().GetCounter(), items, tags);

        CharacterDatabase.AsyncQuery(insertSql).WithCallback([playerGuid = player->GetGUID()](QueryResult)
        {
            if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
            {
                DCAddon::JsonMessage res(MODULE, DCAddon::Opcode::Collection::SMSG_COMMUNITY_PUBLISH_RESULT);
                res.Set("success", true);
                res.Send(player);
            }
        });
    }
    
    void HandleCommunityRate(Player* /*player*/, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg)) return;
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 id = json["id"].AsUInt32();
        
        // Update both upvotes (lifetime) and weekly_votes (trending)
        EnsureCommunityTables();
        CharacterDatabase.AsyncQuery(Acore::StringFormat(
            "UPDATE dc_collection_community_outfits SET upvotes = upvotes + 1, weekly_votes = weekly_votes + 1 WHERE id = {}",
            id));
    }
    
    void HandleCommunityFavorite(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg)) return;
        EnsureCommunityTables();
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 id = json["id"].AsUInt32();
        bool add = json["add"].AsBool();
        uint32 accountId = GetAccountId(player);

        std::string sql;
        if (add)
            sql = Acore::StringFormat("INSERT IGNORE INTO dc_collection_community_favorites (account_id, outfit_id) VALUES ({}, {})", accountId, id);
        else
            sql = Acore::StringFormat("DELETE FROM dc_collection_community_favorites WHERE account_id = {} AND outfit_id = {}", accountId, id);

        ObjectGuid playerGuid = player->GetGUID();
        CharacterDatabase.AsyncQuery(sql).WithCallback([playerGuid, id, add](QueryResult)
        {
            if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
            {
                DCAddon::JsonMessage res(MODULE, DCAddon::Opcode::Collection::SMSG_COMMUNITY_FAVORITE_RESULT);
                res.Set("id", id);
                res.Set("is_favorite", add);
                res.Send(player);
            }
        });
    }

    void HandleCommunityView(Player* /*player*/, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg)) return;
        EnsureCommunityTables();
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 id = json["id"].AsUInt32();

        CharacterDatabase.AsyncQuery(Acore::StringFormat(
            "UPDATE dc_collection_community_outfits SET views = views + 1 WHERE id = {}",
            id));
    }

    // Inspection Handler
    void HandleInspectTransmog(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !DCAddon::IsJsonMessage(msg)) return;
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        
        std::string targetStr = json["target"].IsString() ? json["target"].AsString() : std::to_string(static_cast<uint64>(json["target"].AsNumber()));
        uint64 targetGuid = std::stoull(targetStr);
        
        // Query DB for transmog entries
        QueryResult result = CharacterDatabase.Query("SELECT slot, fake_entry FROM dc_character_transmog WHERE guid = {}", (uint32)targetGuid);
        
        DCAddon::JsonValue slots;
        slots.SetObject();
        
        if (result)
        {
            do
            {
                Field* f = result->Fetch();
                // Format: "slot": itemId
                slots.Set(std::to_string(f[0].Get<uint32>()), f[1].Get<uint32>());
            } while (result->NextRow());
        }
        
        DCAddon::JsonMessage res(MODULE, DCAddon::Opcode::Collection::SMSG_INSPECT_TRANSMOG);
        res.Set("slots", slots);
        res.Set("target", std::to_string(targetGuid)); // Use string to preserve large GUID precision
        res.Send(player);
    }

     // Get correct Item IDs for Item Sets
    // This assumes ItemSet.dbc is loaded on server
    void HandleGetItemSets(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession())
            return;

        uint32 offset = 0;
        uint32 limit = 50;
        uint32 clientSyncVersion = 0;
        bool wantPacked = false;
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue json = DCAddon::GetJsonData(msg);

            if (json.HasKey("offset") && json["offset"].IsNumber())
                offset = json["offset"].AsUInt32();
            if (json.HasKey("limit") && json["limit"].IsNumber())
                limit = json["limit"].AsUInt32();

            if (json.HasKey("syncVersion") && json["syncVersion"].IsNumber())
                clientSyncVersion = json["syncVersion"].AsUInt32();
            else if (json.HasKey("version") && json["version"].IsNumber())
                clientSyncVersion = json["version"].AsUInt32();

            // Optional: request packed payload to reduce JSON overhead.
            // Accept 1/true.
            if (json.HasKey("packed"))
            {
                if (json["packed"].IsBool())
                    wantPacked = json["packed"].AsBool();
                else if (json["packed"].IsNumber())
                    wantPacked = (json["packed"].AsUInt32() != 0);
                else if (json["packed"].IsString())
                    wantPacked = (json["packed"].AsString() == "1" || json["packed"].AsString() == "true");
            }
        }

        // Clamp paging parameters.
        if (limit < 10)
            limit = 10;
        if (limit > 200)
            limit = 200;

        struct ItemSetPayload
        {
            std::vector<std::string> setJson;    // individual {"id":..,"name":..,"items":[..]} entries
            std::vector<std::string> setPacked;  // individual id;urlenc(name);csv(items)
            uint32 syncVersion = 0;
        };

        // Cache the set fragments by locale (names are locale-dependent).
        static std::map<uint8, ItemSetPayload> s_itemSetsByLocale;

        uint8 locale = static_cast<uint8>(player->GetSession()->GetSessionDbcLocale());
        auto it = s_itemSetsByLocale.find(locale);
        if (it == s_itemSetsByLocale.end())
        {
            ItemSetPayload payload;
            payload.setJson.reserve(600);
            payload.setPacked.reserve(600);

            Acore::Crypto::MD5 md5;

            uint32 const rows = sItemSetStore.GetNumRows();
            for (uint32 i = 0; i < rows; ++i)
            {
                ItemSetEntry const* set = sItemSetStore.LookupEntry(i);
                if (!set)
                    continue;

                std::string name = set->name[locale];
                if (name.empty())
                    name = set->name[0];

                // Minimal JSON escaping.
                std::string escaped;
                escaped.reserve(name.size());
                for (char c : name)
                {
                    if (c == '\\') escaped += "\\\\";
                    else if (c == '"') escaped += "\\\"";
                    else escaped += c;
                }

                // Packed-name escaping (percent-encoding for a few separators/controls).
                auto packEscape = [](std::string const& s)
                {
                    std::string out;
                    out.reserve(s.size());
                    auto hex = [](uint8 v) -> char { return v < 10 ? char('0' + v) : char('A' + (v - 10)); };
                    for (unsigned char uc : s)
                    {
                        char c = static_cast<char>(uc);
                        bool need = (c == '%' || c == '\n' || c == '\r' || c == ';' || c == ',' || c == '|' || c == '"' || c == '\\');
                        if (!need)
                        {
                            out += c;
                            continue;
                        }
                        out += '%';
                        out += hex((uc >> 4) & 0xF);
                        out += hex(uc & 0xF);
                    }
                    return out;
                };

                std::ostringstream entry;
                entry << "{\"id\":" << i << ",\"name\":\"" << escaped << "\",\"items\":[";

                bool firstItem = true;
                std::ostringstream itemsCsv;
                for (uint8 j = 0; j < 10; ++j)
                {
                    if (set->itemId[j] > 0)
                    {
                        if (!firstItem)
                        {
                            entry << ',';
                            itemsCsv << ',';
                        }
                        entry << set->itemId[j];
                        itemsCsv << set->itemId[j];
                        firstItem = false;
                    }
                }
                entry << "]}";

                std::string s = entry.str();
                md5.UpdateData(s);
                md5.UpdateData("\n");
                payload.setJson.emplace_back(std::move(s));

                // Packed line: id;urlenc(name);csv(items)
                std::ostringstream packed;
                packed << i << ';' << packEscape(name) << ';' << itemsCsv.str();
                payload.setPacked.emplace_back(packed.str());
            }

            md5.Finalize();
            auto const& d = md5.GetDigest();
            payload.syncVersion = uint32(d[0]) | (uint32(d[1]) << 8) | (uint32(d[2]) << 16) | (uint32(d[3]) << 24);

            it = s_itemSetsByLocale.emplace(locale, std::move(payload)).first;
        }

        ItemSetPayload const& payload = it->second;
        uint32 total = static_cast<uint32>(payload.setJson.size());
        if (offset >= total)
            offset = total;

        // If the client already has this exact locale's item set payload, avoid re-sending.
        if (offset == 0 && clientSyncVersion != 0 && clientSyncVersion == payload.syncVersion)
        {
            std::ostringstream ss;
            if (wantPacked)
            {
                ss << "{\"packed\":1,\"data\":\"\",\"offset\":0,\"limit\":" << limit << ",\"total\":" << total
                   << ",\"hasMore\":0,\"upToDate\":1,\"syncVersion\":" << payload.syncVersion << "}";
            }
            else
            {
                ss << "{\"sets\":[],\"offset\":0,\"limit\":" << limit << ",\"total\":" << total
                   << ",\"hasMore\":0,\"upToDate\":1,\"syncVersion\":" << payload.syncVersion << "}";
            }

            DCAddon::Message res(DCAddon::Module::COLLECTION, DCAddon::Opcode::Collection::SMSG_ITEM_SETS);
            res.Add("J");
            res.Add(ss.str());
            res.Send(player);
            return;
        }

        uint32 end = std::min<uint32>(offset + limit, total);
        bool hasMore = end < total;

        std::ostringstream ss;
        if (wantPacked)
        {
            ss << "{\"packed\":1,\"data\":\"";
            // Join packed lines with '\n' (note: we never embed raw newlines; names are percent-encoded).
            for (uint32 i = offset; i < end; ++i)
            {
                if (i != offset)
                    ss << "\\n";
                ss << payload.setPacked[i];
            }
            ss << "\",\"offset\":" << offset << ",\"limit\":" << limit << ",\"total\":" << total
               << ",\"hasMore\":" << (hasMore ? 1 : 0) << ",\"syncVersion\":" << payload.syncVersion << "}";
        }
        else
        {
            ss << "{\"sets\":[";
            bool first = true;
            for (uint32 i = offset; i < end; ++i)
            {
                if (!first)
                    ss << ',';
                first = false;
                ss << payload.setJson[i];
            }
            ss << "],\"offset\":" << offset << ",\"limit\":" << limit << ",\"total\":" << total
               << ",\"hasMore\":" << (hasMore ? 1 : 0) << ",\"syncVersion\":" << payload.syncVersion << "}";
        }

        DCAddon::Message res(DCAddon::Module::COLLECTION, DCAddon::Opcode::Collection::SMSG_ITEM_SETS);
        res.Add("J");
        res.Add(ss.str());
        res.Send(player);
    }

    // =======================================================================
    // Outfit Saving Handlers
    // =======================================================================

    void HandleGetSavedOutfits(Player* player, const DCAddon::ParsedMessage& msg); // Forward declaration

    void HandleSaveOutfit(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !DCAddon::IsJsonMessage(msg)) return;
        
        // Check if outfits enabled
        if (!sConfigMgr->GetOption<bool>("DCCollection.Outfits.Enable", true))
            return;
        
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);

        uint32 clientId = json["id"].AsUInt32();
        std::string name = json["name"].AsString();
        std::string icon = json["icon"].AsString();
        std::string items = json["items"].IsString() ? json["items"].AsString() : json["items"].Encode();
        uint32 accountId = player->GetSession()->GetAccountId();

        // Sanitize Icon Path
        std::replace(icon.begin(), icon.end(), '\\', '/');

        // Escape strings for SQL
        CharacterDatabase.EscapeString(name);
        CharacterDatabase.EscapeString(icon);
        CharacterDatabase.EscapeString(items);
        
        // Needed for lambda
        ObjectGuid playerGuid = player->GetGUID();

        // If clientId is 0, generate new ID. Otherwise update existing.
        if (clientId == 0) {
            // Check outfit limit
            uint32 maxOutfits = sConfigMgr->GetOption<uint32>("DCCollection.Outfits.MaxPerAccount", 50);
            
            std::string countQuery = "SELECT COUNT(*) FROM dc_account_outfits WHERE account_id = " + std::to_string(accountId);
            CharacterDatabase.AsyncQuery(countQuery)
                .WithCallback([playerGuid, accountId, name, icon, items, maxOutfits, msg](QueryResult countResult) {
                    Player* player = ObjectAccessor::FindPlayer(playerGuid);
                    if (!player) return;

                    if (countResult && countResult->Fetch()[0].Get<uint32>() >= maxOutfits) {
                        // Limit reached
                        DCAddon::JsonMessage res(DCAddon::Module::COLLECTION, DCAddon::Opcode::Collection::SMSG_ERROR);
                        res.Set("error", "Outfit limit reached (" + std::to_string(maxOutfits) + ")");
                        res.Send(player);
                        return;
                    }
                    
                    // Get next available ID
                    std::string maxQuery = "SELECT COALESCE(MAX(outfit_id), 0) + 1 FROM dc_account_outfits WHERE account_id = " + std::to_string(accountId);
                    CharacterDatabase.AsyncQuery(maxQuery)
                        .WithCallback([playerGuid, accountId, name, icon, items, msg](QueryResult maxResult) {
                            Player* player = ObjectAccessor::FindPlayer(playerGuid);
                            if (!player) return;
                            
                            uint32 newId = maxResult ? maxResult->Fetch()[0].Get<uint32>() : 1;
                            
                            std::string insertSql = "INSERT INTO dc_account_outfits (account_id, outfit_id, name, icon, items) VALUES (" + 
                                std::to_string(accountId) + ", " + std::to_string(newId) + ", '" + name + "', '" + icon + "', '" + items + "')";
                                
                            // Use AsyncQuery for INSERT to ensure serialization
                            CharacterDatabase.AsyncQuery(insertSql).WithCallback([playerGuid, msg](QueryResult) {
                                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                                if (!player) return;
                                HandleGetSavedOutfits(player, msg);
                            });
                        });
                });
        } else {
            // Update existing outfit
            std::string updateSql = "UPDATE dc_account_outfits SET name='" + name + "', icon='" + icon + "', items='" + items + 
                "' WHERE account_id=" + std::to_string(accountId) + " AND outfit_id=" + std::to_string(clientId);

            CharacterDatabase.AsyncQuery(updateSql).WithCallback([playerGuid, msg](QueryResult) {
                 Player* player = ObjectAccessor::FindPlayer(playerGuid);
                 if (!player) return;
                 HandleGetSavedOutfits(player, msg);
            });
        }
    }

    void HandleDeleteOutfit(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !DCAddon::IsJsonMessage(msg)) return;
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 outfitId = json["id"].AsUInt32();
        uint32 accountId = player->GetSession()->GetAccountId();

        std::string sql = "DELETE FROM dc_account_outfits WHERE account_id = " + std::to_string(accountId) + " AND outfit_id = " + std::to_string(outfitId);
        CharacterDatabase.AsyncQuery(sql).WithCallback([playerGuid = player->GetGUID(), msg](QueryResult) {
            Player* p = ObjectAccessor::FindPlayer(playerGuid);
            if (p) HandleGetSavedOutfits(p, msg);
        });
    }

    void HandleGetSavedOutfits(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player) return;

        uint32 accountId = player->GetSession()->GetAccountId();

        uint32 offset = 0;
        uint32 limit = 6;
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
            if (json.HasKey("offset") && json["offset"].IsNumber())
                offset = json["offset"].AsUInt32();
            if (json.HasKey("limit") && json["limit"].IsNumber())
                limit = json["limit"].AsUInt32();
        }

        if (limit < 1)
            limit = 1;
        if (limit > 50)
            limit = 50;

        // Fetch total + page.
        std::string countSql = "SELECT COUNT(*) FROM dc_account_outfits WHERE account_id = " + std::to_string(accountId);
        CharacterDatabase.AsyncQuery(countSql)
            .WithCallback([playerGuid = player->GetGUID(), accountId, offset, limit](QueryResult countResult)
            {
                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                if (!player)
                    return;

                uint32 total = 0;
                if (countResult)
                    total = countResult->Fetch()[0].Get<uint32>();

                uint32 pageOffset = offset;
                if (pageOffset > total)
                    pageOffset = total;

                std::string pageSql =
                    "SELECT outfit_id, name, icon, items, source_author FROM dc_account_outfits "
                    "WHERE account_id = " + std::to_string(accountId) +
                    " ORDER BY outfit_id LIMIT " + std::to_string(pageOffset) + ", " + std::to_string(limit);

                CharacterDatabase.AsyncQuery(pageSql)
                    .WithCallback([playerGuid, pageOffset, limit, total](QueryResult result)
                    {
                        Player* player = ObjectAccessor::FindPlayer(playerGuid);
                        if (!player)
                            return;

                        std::stringstream ss;
                        ss << "{\"outfits\":[";

                        uint32 outfitCount = 0;
                        if (result)
                        {
                            bool first = true;
                            do
                            {
                                Field* f = result->Fetch();
                                uint32 id = f[0].Get<uint32>();
                                std::string name = f[1].Get<std::string>();
                                std::string icon = f[2].Get<std::string>();
                                std::string items = f[3].Get<std::string>();
                                std::string sourceAuthor = f[4].IsNull() ? "" : f[4].Get<std::string>();

                                // Simple JSON escape
                                auto escape = [](std::string s)
                                {
                                    std::string res;
                                    for (char c : s)
                                    {
                                        if (c == '"') res += "\\\"";
                                        else if (c == '\\') res += "\\\\";
                                        else res += c;
                                    }
                                    return res;
                                };

                                if (items.empty())
                                    items = "{}";

                                if (!first)
                                    ss << ",";
                                first = false;

                                ss << "{\"id\":" << id
                                   << ",\"name\":\"" << escape(name) << "\""
                                   << ",\"icon\":\"" << escape(icon) << "\""
                                   << ",\"items\":" << items;

                                if (!sourceAuthor.empty())
                                    ss << ",\"author\":\"" << escape(sourceAuthor) << "\"";

                                ss << "}";
                                outfitCount++;

                            } while (result->NextRow());
                        }

                        bool hasMore = (pageOffset + outfitCount) < total;

                        ss << "],\"offset\":" << pageOffset
                           << ",\"limit\":" << limit
                           << ",\"total\":" << total
                           << ",\"hasMore\":" << (hasMore ? 1 : 0)
                           << "}";

                        LOG_INFO("module.dc", "[DCWardrobe] Loaded {} saved outfits for account (Async) offset={} limit={} total={}", outfitCount, pageOffset, limit, total);

                        DCAddon::Message res(DCAddon::Module::COLLECTION, DCAddon::Opcode::Collection::SMSG_SAVED_OUTFITS);
                        res.Add("J");
                        res.Add(ss.str());
                        res.Send(player);
                    });
            });
    }
    void HandleCopyCommunityOutfit(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !DCAddon::IsJsonMessage(msg)) return;
        
        if (!sConfigMgr->GetOption<bool>("DCCollection.Outfits.AllowCommunityImport", true))
            return;
        
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 communityId = json["id"].AsUInt32();
        uint32 accountId = player->GetSession()->GetAccountId();
        ObjectGuid playerGuid = player->GetGUID();
        
        // 1. Check Count
        std::string countQuery = "SELECT COUNT(*) FROM dc_account_outfits WHERE account_id = " + std::to_string(accountId);
        
        CharacterDatabase.AsyncQuery(countQuery)
            .WithCallback([playerGuid, accountId, communityId, msg](QueryResult countResult) {
                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                if (!player) return;
                
                uint32 maxOutfits = sConfigMgr->GetOption<uint32>("DCCollection.Outfits.MaxPerAccount", 50);
                
                if (countResult && countResult->Fetch()[0].Get<uint32>() >= maxOutfits) {
                    DCAddon::JsonMessage res(DCAddon::Module::COLLECTION, DCAddon::Opcode::Collection::SMSG_ERROR);
                    res.Set("error", "Outfit limit reached (" + std::to_string(maxOutfits) + ")");
                    res.Send(player);
                    return;
                }
                
                // 2. Fetch community outfit
                std::string commQuery = "SELECT name, author_name, items_string FROM dc_collection_community_outfits WHERE id = " + std::to_string(communityId);
                
                CharacterDatabase.AsyncQuery(commQuery)
                    .WithCallback([playerGuid, accountId, communityId, msg](QueryResult commResult) {
                        Player* player = ObjectAccessor::FindPlayer(playerGuid);
                        if (!player) return;
                        
                        if (!commResult) {
                            DCAddon::JsonMessage res(DCAddon::Module::COLLECTION, DCAddon::Opcode::Collection::SMSG_ERROR);
                            res.Set("error", "Community outfit not found");
                            res.Send(player);
                            return;
                        }
                        
                        Field* f = commResult->Fetch();
                        std::string name = f[0].Get<std::string>();
                        std::string author = f[1].Get<std::string>();
                        std::string items = f[2].Get<std::string>();
                        
                        CharacterDatabase.EscapeString(name);
                        CharacterDatabase.EscapeString(author);
                        CharacterDatabase.EscapeString(items);
                        
                        // 3. Get ID
                        std::string maxQuery = "SELECT COALESCE(MAX(outfit_id), 0) + 1 FROM dc_account_outfits WHERE account_id = " + std::to_string(accountId);
                        
                         CharacterDatabase.AsyncQuery(maxQuery)
                            .WithCallback([playerGuid, accountId, communityId, name, author, items, msg](QueryResult maxResult) {
                                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                                if (!player) return;
                                
                                uint32 newId = maxResult ? maxResult->Fetch()[0].Get<uint32>() : 1;
                                
                                // 4. Insert
                                std::string insertSql = "INSERT INTO dc_account_outfits (account_id, outfit_id, name, icon, items, source_community_id, source_author) VALUES (" +
                                    std::to_string(accountId) + ", " + std::to_string(newId) + ", '" + name + "', 'Interface/Icons/INV_Chest_Cloth_17', '" + items + "', " + std::to_string(communityId) + ", '" + author + "')";
                                    
                                CharacterDatabase.AsyncQuery(insertSql)
                                    .WithCallback([playerGuid, communityId, msg](QueryResult) {
                                        Player* player = ObjectAccessor::FindPlayer(playerGuid);
                                        if (!player) return;
                                        
                                        // 5. Update Downloads
                                        std::string updateDownSql = "UPDATE dc_collection_community_outfits SET downloads = downloads + 1 WHERE id = " + std::to_string(communityId);
                                        CharacterDatabase.Execute(updateDownSql.c_str());
                                        
                                        HandleGetSavedOutfits(player, msg);
                                    });
                            });
                    });
            });
    }

    // =======================================================================
    // World/Player Scripts
    // =======================================================================

    class WardrobePlayerScript : public PlayerScript
    {
    public:
        WardrobePlayerScript() : PlayerScript("WardrobePlayerScript") {}

        void OnPlayerLogin(Player* /*player*/) override
        {
            if (!sConfigMgr->GetOption<bool>("DCCollection.Transmog.LoginScan.Enable", true)) return;
            // Scan inventory for NEW transmog unlocks
            // (Simplified logic here: actual comprehensive scan mimics item loot hooks)
        }
        
        void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootguid*/) override
        {
            if (sConfigMgr->GetOption<bool>("DCCollection.Transmog.UnlockOnLoot", true))
                UnlockTransmogAppearance(player, item->GetTemplate(), "loot");
        }
        
        void OnPlayerCreateItem(Player* player, Item* item, uint32 /*count*/) override
        {
            if (sConfigMgr->GetOption<bool>("DCCollection.Transmog.UnlockOnCreate", true))
                UnlockTransmogAppearance(player, item->GetTemplate(), "create");
        }
        
        void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 /*count*/) override
        {
            if (sConfigMgr->GetOption<bool>("DCCollection.Transmog.UnlockOnQuestReward", true))
                UnlockTransmogAppearance(player, item->GetTemplate(), "quest");
        }
    };

    class WardrobeMiscScript : public WorldScript 
    {
    public:
        WardrobeMiscScript() : WorldScript("WardrobeMiscScript") {}
        
        void OnAfterConfigLoad(bool reload) override
        {
            if (reload)
                return;

            // Ensure Community tables exist once at startup (avoid runtime DDL stalls).
            EnsureCommunityTables();

            // Pre-warm heavy transmog caches at startup to avoid the first-player hitch.
            // (Doing the item_template scan lazily can freeze the world thread and make gossips/menus feel laggy.)
            (void)GetTransmogAppearanceIndexCached();
            (void)GetTransmogAppearanceVariantKeysCached();
            (void)GetTransmogDefinitionsSyncVersionCached();
        }
    };

} // namespace DCCollection

// Registration
void AddSC_dc_addon_wardrobe()
{
    new DCCollection::WardrobePlayerScript();
    new DCCollection::WardrobeMiscScript();

    using namespace DCAddon;
    using namespace DCCollection;

    LOG_INFO("module.dc", "[DCWardrobe] AddSC_dc_addon_wardrobe() - Registering wardrobe handlers...");

    // Register Transmog & Community Handlers
    // NOTE: Module 'COLL' is shared. We register specific opcodes here.
    
    // Transmog
    // CMSG_SET_TRANSMOG = 0x33
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_SET_TRANSMOG, &HandleSetTransmogMessage);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_GET_TRANSMOG_SLOT_ITEMS, &HandleGetTransmogSlotItems);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_SEARCH_TRANSMOG_ITEMS, &HandleSearchTransmogItems);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_GET_COLLECTED_APPEARANCES, &HandleGetCollectedAppearances);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_GET_TRANSMOG_STATE, &HandleGetTransmogState);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_APPLY_TRANSMOG_PREVIEW, &HandleApplyTransmogPreview);

    // Community
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_COMMUNITY_GET_LIST, &HandleCommunityGetList);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_COMMUNITY_PUBLISH, &HandleCommunityPublish);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_COMMUNITY_RATE, &HandleCommunityRate);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_COMMUNITY_FAVORITE, &HandleCommunityFavorite);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_COMMUNITY_VIEW, &HandleCommunityView);

    // Inspection
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_INSPECT_TRANSMOG, &HandleInspectTransmog);

    // Item Sets
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_GET_ITEM_SETS, &HandleGetItemSets);

    // Outfits
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_SAVE_OUTFIT, &HandleSaveOutfit);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_DELETE_OUTFIT, &HandleDeleteOutfit);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_GET_SAVED_OUTFITS, &HandleGetSavedOutfits);
    MessageRouter::Instance().RegisterHandler(Module::COLLECTION, Opcode::Collection::CMSG_COPY_COMMUNITY_OUTFIT, &HandleCopyCommunityOutfit);
}
