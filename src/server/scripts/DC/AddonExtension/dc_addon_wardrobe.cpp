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
#include "DatabaseEnv.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "World.h"
#include "Chat.h"
#include "WorldPacket.h"
#include "Config.h"
#include "SpellMgr.h"
#include "Bag.h"
#include <vector>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <map>
#include <algorithm>
#include <sstream>
#include <iomanip>

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

    static bool IsBetterTransmogRepresentative(uint32 newEntry, bool newIsNonCustom, uint32 newQuality, uint32 newItemLevel,
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

    // Unlocking Logic
    static std::unordered_map<uint32, std::unordered_set<uint32>> s_AccountUnlockedTransmogAppearances;
    constexpr size_t MAX_NOTIFIED_APPEARANCES_PER_PLAYER = 10000;
    static std::unordered_map<uint32, std::unordered_set<uint32>> sessionNotifiedAppearances;

    void InvalidateAccountUnlockedTransmogAppearances(uint32 accountId)
    {
        s_AccountUnlockedTransmogAppearances.erase(accountId);
    }

    static std::unordered_set<uint32> const& GetAccountUnlockedTransmogAppearances(uint32 accountId)
    {
        auto it = s_AccountUnlockedTransmogAppearances.find(accountId);
        if (it != s_AccountUnlockedTransmogAppearances.end()) return it->second;

        std::unordered_set<uint32> unlocked;
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

    void UnlockTransmogAppearance(Player* player, ItemTemplate const* proto, std::string const& source, bool notifyPlayer = true)
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

         if (!displayId || !HasTransmogAppearanceUnlocked(accountId, displayId)) return;

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

        // Used CharacterDatabase with transaction? For now individual executes.
        for (auto const& kv : preview.AsObject())
        {
             uint32 visualSlot = std::stoul(kv.first);
             uint8 equipmentSlot = VisualSlotToEquipmentSlot(visualSlot);
             if (equipmentSlot >= EQUIPMENT_SLOT_END) continue;

             Item* equippedItem = player->GetItemByPos(INVENTORY_SLOT_BAG_0, equipmentSlot);
             if (!equippedItem) continue;

             DCAddon::JsonValue const& slotValue = kv.second;
             if (slotValue.IsNull()) {
                 CharacterDatabase.Execute("DELETE FROM dc_character_transmog WHERE guid = {} AND slot = {}", guid, (uint32)equipmentSlot);
                 player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (equipmentSlot * 2), equippedItem->GetEntry());
             } else if (slotValue.AsUInt32() == 0) {
                 CharacterDatabase.Execute("REPLACE INTO dc_character_transmog (guid, slot, fake_entry, real_entry) VALUES ({}, {}, 0, {})", guid, (uint32)equipmentSlot, equippedItem->GetEntry());
                 player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (equipmentSlot * 2), 0);
             } else {
                 uint32 itemId = slotValue.AsUInt32();
                 ItemTemplate const* fakeProto = sObjectMgr->GetItemTemplate(itemId);
                 if (!fakeProto) continue;
                 uint32 displayId = fakeProto->DisplayInfoID;
                 if (!HasTransmogAppearanceUnlocked(accountId, displayId)) continue;
                 if (!FindBestVariantForSlot(displayId, equipmentSlot, equippedItem->GetTemplate())) continue;
                 
                 CharacterDatabase.Execute("REPLACE INTO dc_character_transmog (guid, slot, fake_entry, real_entry) VALUES ({}, {}, {}, {})", guid, (uint32)equipmentSlot, itemId, equippedItem->GetEntry());
                 player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (equipmentSlot * 2), itemId);
             }
        }
        SendTransmogState(player);
    }

    std::vector<uint32> GetCollectedAppearancesForSlot(Player* player, uint32 visualSlot, std::string const& searchFilter = "")
    {
        if (!player) return {};
        uint32 accountId = GetAccountId(player);
        std::vector<uint32> invTypes = GetInvTypesForVisualSlot(visualSlot);
        if (invTypes.empty()) return {};

        uint8 equipmentSlot = VisualSlotToEquipmentSlot(visualSlot);
        Item* equippedItem = (equipmentSlot < EQUIPMENT_SLOT_END) ? player->GetItemByPos(INVENTORY_SLOT_BAG_0, equipmentSlot) : nullptr;
        
        std::string searchLower = searchFilter;
        std::transform(searchLower.begin(), searchLower.end(), searchLower.begin(), ::tolower);
        bool hasSearch = !searchLower.empty();

        auto const& appearances = GetTransmogAppearanceIndexCached();
        std::vector<uint32> matchingItemIds;
        matchingItemIds.reserve(128);

        for (auto const& [displayId, variants] : appearances)
        {
            if (!HasTransmogAppearanceUnlocked(accountId, displayId)) continue;
            for (auto const& def : variants)
            {
                bool invTypeMatch = false;
                for (uint32 invType : invTypes) { if (def.inventoryType == invType) { invTypeMatch = true; break; } }
                if (!invTypeMatch) continue;

                if (equippedItem && !IsAppearanceCompatible(equipmentSlot, equippedItem->GetTemplate(), def)) continue;

                if (hasSearch)
                {
                    bool matchFound = false;
                    std::string nameLower = def.name;
                    std::transform(nameLower.begin(), nameLower.end(), nameLower.begin(), ::tolower);
                    if (nameLower.find(searchLower) != std::string::npos) matchFound = true;
                    if (!matchFound && std::to_string(displayId).find(searchFilter) != std::string::npos) matchFound = true;
                    // Simplify: skip itemId search for performance if needed, but keeping logic
                    if (!matchFound) {
                        for (uint32 itemId : def.itemIds) { if (std::to_string(itemId).find(searchFilter) != std::string::npos) { matchFound = true; break; } }
                    }
                    if (!matchFound) continue;
                }

                uint32 minQuality = sConfigMgr->GetOption<uint32>(TRANSMOG_MIN_QUALITY, 0);
                if (def.quality < minQuality) continue;

                matchingItemIds.push_back(def.canonicalItemId);
            }
        }
        return matchingItemIds;
    }

    void SendTransmogSlotItemsResponse(Player* player, uint32 visualSlot, uint32 page, std::vector<uint32> const& matchingItemIds, std::string const& searchFilter = "")
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

        DCAddon::JsonValue itemArr; itemArr.SetArray();
        auto const& idx = GetTransmogAppearanceIndexCached();
        for (uint32 d : unlocked) {
            auto it = idx.find(d);
            if (it != idx.end()) {
                 for (auto const& v : it->second) itemArr.Push(DCAddon::JsonValue(v.canonicalItemId));
            }
        }
        DCAddon::JsonMessage response(MODULE, DCAddon::Opcode::Collection::SMSG_COLLECTED_APPEARANCES);
        response.Set("count", static_cast<uint32>(unlocked.size()));
        response.Set("appearances", appArr);
        response.Set("items", itemArr);
        response.Send(player);
    }

    // =======================================================================
    // Community Outfits Platform Handlers
    // =======================================================================

    void HandleCommunityGetList(Player* player, const DCAddon::ParsedMessage& msg)
    {
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

        // Use new table prefix: dc_collection_community_outfits
        if (!WorldTableExists("dc_collection_community_outfits"))
        {
             DCAddon::JsonBuilder json;
             json.Add("outfits", DCAddon::JsonBuilder::Array());
             DCAddon::Message(MODULE, DCAddon::Opcode::Collection::SMSG_COMMUNITY_LIST).AddJson(json).Send(player);
             return;
        }

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

        QueryResult result;
        if (filter == "favorites")
        {
             // Join on favorites and filter
             result = CharacterDatabase.Query(
                "SELECT o.id, o.name, o.author_name, o.items_string, o.upvotes, o.downloads, 1 as is_favorite, o.views, o.tags "
                "FROM dc_collection_community_outfits o "
                "JOIN dc_collection_community_favorites f ON o.id = f.outfit_id "
                "WHERE f.account_id = {} {} "
                "ORDER BY {} LIMIT {}, {}",
                accountId, tagFilterCondition, orderBy, offset, limit);
        }
        else if (filter == "my_outfits")
        {
             // Filter by author GUID
             uint32 playerGuid = player->GetGUID().GetCounter();
             result = CharacterDatabase.Query(
                "SELECT o.id, o.name, o.author_name, o.items_string, o.upvotes, o.downloads, "
                "CAST((SELECT COUNT(*) FROM dc_collection_community_favorites f WHERE f.outfit_id = o.id AND f.account_id = {}) AS UNSIGNED) as is_favorite, "
                "o.views, o.tags "
                "FROM dc_collection_community_outfits o "
                "WHERE o.author_guid = {} {} "
                "ORDER BY o.created_at DESC LIMIT {}, {}",
                accountId, playerGuid, tagFilterCondition, offset, limit);
        }
        else // all or tag
        {
            // Join to get favorite status
            std::string whereClause = (filter == "tag" && !tagFilterCondition.empty()) ? "WHERE " + tagFilterCondition.substr(5) : ""; // Remove first AND

            result = CharacterDatabase.Query(
                "SELECT o.id, o.name, o.author_name, o.items_string, o.upvotes, o.downloads, "
                "CAST((SELECT COUNT(*) FROM dc_collection_community_favorites f WHERE f.outfit_id = o.id AND f.account_id = {}) AS UNSIGNED) as is_favorite, "
                "o.views, o.tags "
                "FROM dc_collection_community_outfits o "
                "{} "
                "ORDER BY {} LIMIT {}, {}",
                accountId, whereClause, orderBy, offset, limit);
        }

        DCAddon::JsonBuilder json;
        auto arr = json.AddArray("outfits");
        
        if (result)
        {
            do
            {
                Field* f = result->Fetch();
                auto obj = arr.AddObject();
                obj.Add("id", f[0].Get<uint32>());
                obj.Add("name", f[1].Get<std::string>());
                obj.Add("author", f[2].Get<std::string>());
                obj.Add("items", f[3].Get<std::string>());
                obj.Add("upvotes", f[4].Get<uint32>());
                obj.Add("downloads", f[5].Get<uint32>());
                obj.Add("is_favorite", f[6].Get<bool>());
                obj.Add("views", f[7].Get<uint32>());
                obj.Add("tags", f[8].Get<std::string>());
            } while (result->NextRow());
        }
        DCAddon::Message(MODULE, DCAddon::Opcode::Collection::SMSG_COMMUNITY_LIST).AddJson(json).Send(player);
    }

    void HandleCommunityPublish(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg)) return;
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        std::string name = json["name"].AsString();
        std::string items = json["items"].AsString();
        std::string tags = "";
        if (json.HasKey("tags")) tags = json["tags"].AsString();
        
        CharacterDatabase.EscapeString(name);
        CharacterDatabase.EscapeString(items);
        CharacterDatabase.EscapeString(tags);
        
        // Lazy create tables
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

        CharacterDatabase.Execute(
            "INSERT INTO dc_collection_community_outfits (name, author_name, author_guid, items_string, tags) "
            "VALUES ('{}', '{}', {}, '{}', '{}')",
            name, player->GetName(), player->GetGUID().GetCounter(), items, tags);

        DCAddon::JsonBuilder res;
        res.Add("success", true);
        DCAddon::Message(MODULE, DCAddon::Opcode::Collection::SMSG_COMMUNITY_PUBLISH_RESULT).AddJson(res).Send(player);
    }
    
    void HandleCommunityRate(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg)) return;
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 id = json["id"].AsUInt32();
        
        // Update both upvotes (lifetime) and weekly_votes (trending)
        CharacterDatabase.Execute("UPDATE dc_collection_community_outfits SET upvotes = upvotes + 1, weekly_votes = weekly_votes + 1 WHERE id = {}", id);
    }
    
    void HandleCommunityFavorite(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg)) return;
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 id = json["id"].AsUInt32();
        bool add = json["add"].AsBool();
        uint32 accountId = GetAccountId(player);
        
        if (add)
            CharacterDatabase.Execute("INSERT IGNORE INTO dc_collection_community_favorites (account_id, outfit_id) VALUES ({}, {})", accountId, id);
        else
            CharacterDatabase.Execute("DELETE FROM dc_collection_community_favorites WHERE account_id = {} AND outfit_id = {}", accountId, id);

        DCAddon::JsonBuilder res;
        res.Add("id", id);
        res.Add("is_favorite", add);
        DCAddon::Message(MODULE, DCAddon::Opcode::Collection::SMSG_COMMUNITY_FAVORITE_RESULT).AddJson(res).Send(player);
    }

    void HandleCommunityView(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg)) return;
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 id = json["id"].AsUInt32();

        // Increment views
        CharacterDatabase.Execute("UPDATE dc_collection_community_outfits SET views = views + 1 WHERE id = {}", id);
    }

    // Inspection Handler
    void HandleInspectTransmog(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !DCAddon::IsJsonMessage(msg)) return;
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        
        uint64 targetGuid = json["target"].AsUInt64();
        Player* target = ObjectAccessor::FindPlayer(ObjectGuid(targetGuid));
        
        // If target is offline or not found, we might still want to support it by querying DB if they exist?
        // For now, let's stick to online players or DB lookups.
        // DB lookup is safer as it works for offline too if we have GUID.
        // However, raw GUID from client might be low-guid or full guid.
        // JSON numbers are often doubles, careful with precision. Usually fine for low GUIDs.
        
        // Query DB for transmog entries
        QueryResult result = CharacterDatabase.Query("SELECT slot, fake_entry FROM dc_character_transmog WHERE guid = {}", (uint32)targetGuid);
        
        DCAddon::JsonBuilder res;
        auto obj = res.AddObject("slots"); // Map of slot -> entry
        
        if (result)
        {
            do
            {
                Field* f = result->Fetch();
                // Format: "slot": itemId
                obj.Add(std::to_string(f[0].Get<uint32>()), f[1].Get<uint32>());
            } while (result->NextRow());
        }
        res.EndObject();
        res.Add("target", targetGuid);
        
        DCAddon::Message(MODULE, DCAddon::Opcode::Collection::SMSG_INSPECT_TRANSMOG).AddJson(res).Send(player);
    }

    // =======================================================================
    // World/Player Scripts
    // =======================================================================

    class WardrobePlayerScript : public PlayerScript
    {
    public:
        WardrobePlayerScript() : PlayerScript("WardrobePlayerScript") {}

        void OnLogin(Player* player) override
        {
            if (!sConfigMgr->GetOption<bool>("DCCollection.Transmog.LoginScan.Enable", true)) return;
            // Scan inventory for NEW transmog unlocks
            // (Simplified logic here: actual comprehensive scan mimics item loot hooks)
        }
        
        void OnLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootguid*/) override
        {
            if (sConfigMgr->GetOption<bool>("DCCollection.Transmog.UnlockOnLoot", true))
                UnlockTransmogAppearance(player, item->GetTemplate(), "loot");
        }
        
        void OnCreateItem(Player* player, Item* item, uint32 /*count*/) override
        {
            if (sConfigMgr->GetOption<bool>("DCCollection.Transmog.UnlockOnCreate", true))
                UnlockTransmogAppearance(player, item->GetTemplate(), "create");
        }
        
        void OnQuestRewardItem(Player* player, Item* item, uint32 /*count*/) override
        {
            if (sConfigMgr->GetOption<bool>("DCCollection.Transmog.UnlockOnQuestReward", true))
                UnlockTransmogAppearance(player, item->GetTemplate(), "quest");
        }
    };

    class WardrobeMiscScript : public WorldScript 
    {
    public:
        WardrobeMiscScript() : WorldScript("WardrobeMiscScript") {}
        
        void OnAfterConfigLoad(bool /*reload*/) override
        {
            // Rebuild definitions if needed. 
            // NOTE: dc_addon_collection.cpp handles global definition loading. 
            // We just ensure our cache is ready on demand.
            // But we can pre-warm cache here if desired.
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
}
