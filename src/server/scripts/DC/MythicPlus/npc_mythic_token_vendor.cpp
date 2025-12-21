/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Mythic+ Token Vendor - Exchange tokens for class/spec appropriate gear
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Chat.h"
#include "ObjectMgr.h"
#include "DatabaseEnv.h"
#include "DC/AddonExtension/DCAddonNamespace.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "SharedDefines.h"
#include "StringFormat.h"
#include "ObjectAccessor.h"
#include <map>
#include <vector>
#include <sstream>
#include <unordered_map>

#include "Config.h"

// Token item ID (DC Item Upgrade Token)
// Default: 300311
// uint32 GetMythicTokenId() - Removed, using shared function

constexpr uint32 ESSENCE_PER_TOKEN = 500; // 1 Token = 500 Essence

// Gear slot categories
enum TokenGearSlot : uint8
{
    TOKEN_SLOT_HEAD = 1,
    TOKEN_SLOT_NECK = 2,
    TOKEN_SLOT_SHOULDERS = 3,
    TOKEN_SLOT_BACK = 4,
    TOKEN_SLOT_CHEST = 5,
    TOKEN_SLOT_WRIST = 6,
    TOKEN_SLOT_HANDS = 7,
    TOKEN_SLOT_WAIST = 8,
    TOKEN_SLOT_LEGS = 9,
    TOKEN_SLOT_FEET = 10,
    TOKEN_SLOT_FINGER = 11,
    TOKEN_SLOT_TRINKET = 12,
    TOKEN_SLOT_WEAPON = 13,
    TOKEN_SLOT_OFFHAND = 14
};

// Cost structure: item level determines token cost
struct TokenCost
{
    uint32 ilvl200 = 11;  // M+2-4
    uint32 ilvl213 = 12;  // M+5-7
    uint32 ilvl226 = 13;  // M+8-10
    uint32 ilvl239 = 14;  // M+11-13
    uint32 ilvl252 = 15;  // M+14-15
};

// Class-appropriate item pools (example structure - populate with actual item IDs)
struct ClassGearPool
{
    std::map<uint8, std::vector<uint32>> gearBySlot;  // slot -> list of item IDs
};

enum class VendorRoleHint : uint8
{
    Any = 0,
    Melee,
    Ranged,
    Tank,
    Caster,
    Healer
};

static uint32 GetClassMask(uint8 playerClass)
{
    if (playerClass == 0)
        return 0;
    return 1u << (playerClass - 1u);
}

static VendorRoleHint GetRoleHint(Player* player)
{
    if (!player)
        return VendorRoleHint::Any;

    // Use existing spec heuristics from core.
    if (player->HasHealSpec())
        return VendorRoleHint::Healer;
    if (player->HasTankSpec())
        return VendorRoleHint::Tank;
    if (player->HasCasterSpec())
        return VendorRoleHint::Caster;
    if (player->HasMeleeSpec())
        return VendorRoleHint::Melee;

    // Fallback: class-based defaults.
    switch (player->getClass())
    {
        case CLASS_HUNTER:
            return VendorRoleHint::Ranged;
        case CLASS_MAGE:
        case CLASS_WARLOCK:
            return VendorRoleHint::Caster;
        case CLASS_PRIEST:
            return VendorRoleHint::Healer;
        default:
            return VendorRoleHint::Melee;
    }
}

static bool HasItemStat(ItemTemplate const* proto, ItemModType mod)
{
    if (!proto)
        return false;
    uint32 count = std::min<uint32>(proto->StatsCount, MAX_ITEM_PROTO_STATS);
    for (uint32 i = 0; i < count; ++i)
        if (proto->ItemStat[i].ItemStatType == uint32(mod) && proto->ItemStat[i].ItemStatValue != 0)
            return true;
    return false;
}

static bool IsRoleFit(ItemTemplate const* proto, VendorRoleHint role)
{
    if (!proto || role == VendorRoleHint::Any)
        return true;

    bool hasInt = HasItemStat(proto, ITEM_MOD_INTELLECT);
    bool hasSpi = HasItemStat(proto, ITEM_MOD_SPIRIT);
    bool hasStr = HasItemStat(proto, ITEM_MOD_STRENGTH);
    bool hasAgi = HasItemStat(proto, ITEM_MOD_AGILITY);
    bool hasAP = HasItemStat(proto, ITEM_MOD_ATTACK_POWER) || HasItemStat(proto, ITEM_MOD_RANGED_ATTACK_POWER);
    bool hasSP = HasItemStat(proto, ITEM_MOD_SPELL_POWER);

    switch (role)
    {
        case VendorRoleHint::Melee:
        case VendorRoleHint::Ranged:
        {
            // Reject obvious caster/healer gear unless it also has a physical primary stat.
            bool looksCaster = hasInt || hasSpi || hasSP;
            bool looksPhysical = hasStr || hasAgi || hasAP;
            return !looksCaster || looksPhysical;
        }
        case VendorRoleHint::Caster:
        {
            bool looksPhysical = hasStr || hasAgi || hasAP;
            bool looksCaster = hasInt || hasSP;
            return looksCaster && !looksPhysical;
        }
        case VendorRoleHint::Healer:
        {
            bool looksPhysical = hasStr || hasAgi || hasAP;
            // Healers can have INT/SPI (and sometimes SP) but should not be STR/AGI/AP.
            return !looksPhysical && (hasInt || hasSpi || hasSP);
        }
        case VendorRoleHint::Tank:
        {
            // Tanks shouldn't get pure caster items.
            if (hasInt || hasSP)
                return false;
            // Defense is a strong hint but not required.
            return true;
        }
        default:
            break;
    }

    return true;
}

// Get class-appropriate armor subclass
uint8 GetArmorSubclassForClass(uint8 playerClass)
{
    switch (playerClass)
    {
        case CLASS_WARRIOR:
        case CLASS_PALADIN:
        case CLASS_DEATH_KNIGHT:
            return ITEM_SUBCLASS_ARMOR_PLATE;
        case CLASS_HUNTER:
        case CLASS_SHAMAN:
            return ITEM_SUBCLASS_ARMOR_MAIL;
        case CLASS_ROGUE:
        case CLASS_DRUID:
            return ITEM_SUBCLASS_ARMOR_LEATHER;
        case CLASS_PRIEST:
        case CLASS_MAGE:
        case CLASS_WARLOCK:
            return ITEM_SUBCLASS_ARMOR_CLOTH;
        default:
            return ITEM_SUBCLASS_ARMOR_MISC;
    }
}

// Get class-appropriate armor type name
std::string GetArmorTypeForClass(uint8 playerClass)
{
    switch (playerClass)
    {
        case CLASS_WARRIOR:
        case CLASS_PALADIN:
        case CLASS_DEATH_KNIGHT:
            return "Plate";
        case CLASS_HUNTER:
        case CLASS_SHAMAN:
            return "Mail";
        case CLASS_ROGUE:
        case CLASS_DRUID:
            return "Leather";
        case CLASS_PRIEST:
        case CLASS_MAGE:
        case CLASS_WARLOCK:
            return "Cloth";
        default:
            return "Unknown";
    }
}

// Convert token slot to InventoryType
uint8 TokenSlotToInventoryType(uint8 tokenSlot)
{
    switch (tokenSlot)
    {
        case TOKEN_SLOT_HEAD:      return INVTYPE_HEAD;
        case TOKEN_SLOT_NECK:      return INVTYPE_NECK;
        case TOKEN_SLOT_SHOULDERS: return INVTYPE_SHOULDERS;
        case TOKEN_SLOT_BACK:      return INVTYPE_CLOAK;
        case TOKEN_SLOT_CHEST:     return INVTYPE_CHEST;
        case TOKEN_SLOT_WRIST:     return INVTYPE_WRISTS;
        case TOKEN_SLOT_HANDS:     return INVTYPE_HANDS;
        case TOKEN_SLOT_WAIST:     return INVTYPE_WAIST;
        case TOKEN_SLOT_LEGS:      return INVTYPE_LEGS;
        case TOKEN_SLOT_FEET:      return INVTYPE_FEET;
        case TOKEN_SLOT_FINGER:    return INVTYPE_FINGER;
        case TOKEN_SLOT_TRINKET:   return INVTYPE_TRINKET;
        case TOKEN_SLOT_WEAPON:    return INVTYPE_WEAPON;
        case TOKEN_SLOT_OFFHAND:   return INVTYPE_SHIELD;
        default:                   return INVTYPE_NON_EQUIP;
    }
}

// Structure to hold item choices
struct ItemChoice
{
    uint32 itemId;
    std::string name;
    uint32 itemLevel;
    std::string stats;
};

// Get item link for gossip display
std::string GetItemLink(uint32 itemId, ItemTemplate const* proto)
{
    std::ostringstream ss;
    ss << "|c" << std::hex << ItemQualityColors[proto->Quality] << std::dec;
    ss << "|Hitem:" << itemId << ":0:0:0:0:0:0:0:0|h[" << proto->Name1 << "]|h|r";
    return ss.str();
}

// Get token cost based on item level
uint32 GetTokenCost(uint32 itemLevel)
{
    if (itemLevel >= 252)
        return 15;
    if (itemLevel >= 239)
        return 14;
    if (itemLevel >= 226)
        return 13;
    if (itemLevel >= 213)
        return 12;
    return 11;
}

namespace
{
    constexpr uint32 GOSSIP_ACTION_OPEN_VENDOR_UI = 9000;
    constexpr uint32 VENDOR_UI_DISTANCE = 12; // yards
    constexpr time_t VENDOR_UI_SESSION_SECONDS = 60;

    struct VendorUiSession
    {
        ObjectGuid creatureGuid;
        time_t expiresAt = 0;
    };

    static std::unordered_map<uint32, VendorUiSession> s_vendorUiSessions;

    static bool IsVendorSessionValid(Player* player, Creature** outCreature = nullptr)
    {
        if (!player)
            return false;

        uint32 key = player->GetGUID().GetCounter();
        auto it = s_vendorUiSessions.find(key);
        if (it == s_vendorUiSessions.end())
            return false;

        time_t now = time(nullptr);
        if (now > it->second.expiresAt)
        {
            s_vendorUiSessions.erase(it);
            return false;
        }

        Creature* creature = ObjectAccessor::GetCreature(*player, it->second.creatureGuid);
        if (!creature)
            return false;

        if (!player->IsWithinDistInMap(creature, float(VENDOR_UI_DISTANCE)))
            return false;

        if (outCreature)
            *outCreature = creature;

        return true;
    }

    static std::string GetWeaponFilterForClass(uint8 playerClass, uint8 slot)
    {
        std::ostringstream filter;

        if (slot == TOKEN_SLOT_OFFHAND)
        {
            // Shields for plate/mail tanks, off-hand for others
            if (playerClass == CLASS_WARRIOR || playerClass == CLASS_PALADIN || playerClass == CLASS_SHAMAN)
            {
                filter << "class = " << ITEM_CLASS_ARMOR << " AND subclass = " << ITEM_SUBCLASS_ARMOR_SHIELD;
            }
            else
            {
                filter << "(InventoryType = " << INVTYPE_WEAPONOFFHAND << " OR InventoryType = " << INVTYPE_HOLDABLE << ")";
            }
        }
        else
        {
            // Main hand weapons - allow various types based on class
            std::vector<uint8> allowedTypes;

            switch (playerClass)
            {
                case CLASS_WARRIOR:
                case CLASS_PALADIN:
                case CLASS_DEATH_KNIGHT:
                    allowedTypes = { ITEM_SUBCLASS_WEAPON_SWORD, ITEM_SUBCLASS_WEAPON_SWORD2,
                        ITEM_SUBCLASS_WEAPON_AXE, ITEM_SUBCLASS_WEAPON_AXE2,
                        ITEM_SUBCLASS_WEAPON_MACE, ITEM_SUBCLASS_WEAPON_MACE2,
                        ITEM_SUBCLASS_WEAPON_POLEARM };
                    break;
                case CLASS_HUNTER:
                    allowedTypes = { ITEM_SUBCLASS_WEAPON_AXE, ITEM_SUBCLASS_WEAPON_SWORD,
                        ITEM_SUBCLASS_WEAPON_POLEARM, ITEM_SUBCLASS_WEAPON_STAFF };
                    break;
                case CLASS_ROGUE:
                    allowedTypes = { ITEM_SUBCLASS_WEAPON_DAGGER, ITEM_SUBCLASS_WEAPON_SWORD,
                        ITEM_SUBCLASS_WEAPON_MACE, ITEM_SUBCLASS_WEAPON_FIST };
                    break;
                case CLASS_DRUID:
                    allowedTypes = { ITEM_SUBCLASS_WEAPON_MACE, ITEM_SUBCLASS_WEAPON_MACE2,
                        ITEM_SUBCLASS_WEAPON_DAGGER, ITEM_SUBCLASS_WEAPON_STAFF,
                        ITEM_SUBCLASS_WEAPON_POLEARM };
                    break;
                case CLASS_SHAMAN:
                    allowedTypes = { ITEM_SUBCLASS_WEAPON_AXE, ITEM_SUBCLASS_WEAPON_AXE2,
                        ITEM_SUBCLASS_WEAPON_MACE, ITEM_SUBCLASS_WEAPON_MACE2,
                        ITEM_SUBCLASS_WEAPON_STAFF, ITEM_SUBCLASS_WEAPON_FIST };
                    break;
                case CLASS_MAGE:
                case CLASS_PRIEST:
                case CLASS_WARLOCK:
                    allowedTypes = { ITEM_SUBCLASS_WEAPON_STAFF, ITEM_SUBCLASS_WEAPON_DAGGER,
                        ITEM_SUBCLASS_WEAPON_SWORD };
                    break;
                default:
                    break;
            }

            filter << "class = " << ITEM_CLASS_WEAPON << " AND (";
            for (size_t i = 0; i < allowedTypes.size(); ++i)
            {
                if (i > 0)
                    filter << " OR ";
                filter << "subclass = " << uint32(allowedTypes[i]);
            }
            filter << ")";
        }

        return filter.str();
    }

    static std::vector<ItemChoice> GetItemsForSlotAndClass(Player* player, uint8 slot, uint32 itemLevel)
    {
        std::vector<ItemChoice> choices;

        if (!player)
            return choices;

        uint8 playerClass = player->getClass();
        uint32 classMask = GetClassMask(playerClass);
        VendorRoleHint roleHint = GetRoleHint(player);

        uint8 invType = TokenSlotToInventoryType(slot);
        if (invType == INVTYPE_NON_EQUIP)
            return choices;

        std::string query;

        // For armor slots, filter by armor subclass
        if (slot >= TOKEN_SLOT_HEAD && slot <= TOKEN_SLOT_FEET && slot != TOKEN_SLOT_NECK && slot != TOKEN_SLOT_BACK)
        {
            uint8 armorSubclass = GetArmorSubclassForClass(playerClass);
            query = "SELECT entry, name, ItemLevel FROM item_template "
                "WHERE class = " + std::to_string(ITEM_CLASS_ARMOR) + " "
                "AND subclass = " + std::to_string(armorSubclass) + " "
                "AND InventoryType = " + std::to_string(invType) + " "
                "AND ItemLevel BETWEEN " + std::to_string(itemLevel - 2) + " AND " + std::to_string(itemLevel + 2) + " "
                "AND (AllowableClass = 0 OR (AllowableClass & " + std::to_string(classMask) + ") != 0) "
                "AND Quality >= 3 "
                "ORDER BY ItemLevel DESC, name ASC "
                "LIMIT 60";
        }
        else if (slot == TOKEN_SLOT_NECK || slot == TOKEN_SLOT_BACK || slot == TOKEN_SLOT_FINGER || slot == TOKEN_SLOT_TRINKET)
        {
            query = "SELECT entry, name, ItemLevel FROM item_template "
                "WHERE InventoryType = " + std::to_string(invType) + " "
                "AND ItemLevel BETWEEN " + std::to_string(itemLevel - 2) + " AND " + std::to_string(itemLevel + 2) + " "
                "AND (AllowableClass = 0 OR (AllowableClass & " + std::to_string(classMask) + ") != 0) "
                "AND Quality >= 3 "
                "ORDER BY ItemLevel DESC, name ASC "
                "LIMIT 80";
        }
        else if (slot == TOKEN_SLOT_WEAPON || slot == TOKEN_SLOT_OFFHAND)
        {
            std::string weaponFilter = GetWeaponFilterForClass(playerClass, slot);
            if (!weaponFilter.empty())
            {
                query = "SELECT entry, name, ItemLevel FROM item_template "
                    "WHERE (" + weaponFilter + ") "
                    "AND ItemLevel BETWEEN " + std::to_string(itemLevel - 2) + " AND " + std::to_string(itemLevel + 2) + " "
                    "AND (AllowableClass = 0 OR (AllowableClass & " + std::to_string(classMask) + ") != 0) "
                    "AND Quality >= 3 "
                    "ORDER BY ItemLevel DESC, name ASC "
                    "LIMIT 80";
            }
        }

        if (query.empty())
            return choices;

        QueryResult result = WorldDatabase.Query(query.c_str());
        if (!result)
            return choices;

        do
        {
            Field* fields = result->Fetch();
            uint32 entry = fields[0].Get<uint32>();

            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entry);
            if (!proto)
                continue;

            // Hard class gating (set pieces etc).
            if (proto->AllowableClass != 0 && (proto->AllowableClass & classMask) == 0)
                continue;

            // Ensure the player can actually use the item.
            if (player->CanUseItem(proto) != EQUIP_ERR_OK)
                continue;

            // Spec/role fitment (avoid obvious mismatches).
            if (!IsRoleFit(proto, roleHint))
                continue;

            ItemChoice choice;
            choice.itemId = entry;
            choice.name = fields[1].Get<std::string>();
            choice.itemLevel = fields[2].Get<uint32>();
            choices.push_back(choice);

            if (choices.size() >= 3)
                break;
        } while (result->NextRow());

        return choices;
    }

    static void SendVendorState(Player* player)
    {
        if (!player)
            return;
        auto* upgradeMgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!upgradeMgr)
            return;

        uint32 currentEssence = upgradeMgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE);
        uint32 tokenCount = player->GetItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), true);

        DCAddon::JsonMessage msg(DCAddon::Module::MYTHIC_PLUS, DCAddon::Opcode::MPlus::SMSG_TOKEN_VENDOR_STATE);
        msg.Set("essence", currentEssence);
        msg.Set("tokens", tokenCount);
        msg.Send(player);
    }

    static void SendVendorResult(Player* player, bool success, std::string const& message)
    {
        DCAddon::JsonMessage msg(DCAddon::Module::MYTHIC_PLUS, DCAddon::Opcode::MPlus::SMSG_TOKEN_VENDOR_RESULT);
        msg.Set("success", success);
        msg.Set("message", message);
        msg.Send(player);
        SendVendorState(player);
    }

    static void HandleTokenVendorChoices(Player* player, DCAddon::ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 itemLevel = 0;
        uint32 slot = 0;
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue req = DCAddon::GetJsonData(msg);
            if (req.IsObject())
            {
                if (req.HasKey("itemLevel") && req["itemLevel"].IsNumber())
                    itemLevel = req["itemLevel"].AsUInt32();
                if (req.HasKey("slot") && req["slot"].IsNumber())
                    slot = req["slot"].AsUInt32();
            }
        }

        if (itemLevel < 200 || itemLevel > 252 || slot == 0)
        {
            SendVendorResult(player, false, "Invalid selection.");
            return;
        }

        if (!IsVendorSessionValid(player))
        {
            SendVendorResult(player, false, "Please talk to the vendor again.");
            return;
        }

        uint32 tokenCount = player->GetItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), true);
        uint32 cost = GetTokenCost(itemLevel);

        std::vector<ItemChoice> choices = GetItemsForSlotAndClass(player, uint8(slot), itemLevel);

        DCAddon::JsonMessage resp(DCAddon::Module::MYTHIC_PLUS, DCAddon::Opcode::MPlus::SMSG_TOKEN_VENDOR_CHOICES);
        resp.Set("itemLevel", itemLevel);
        resp.Set("slot", slot);
        resp.Set("cost", cost);
        resp.Set("tokens", tokenCount);

        DCAddon::JsonValue arr;
        arr.SetArray();
        for (auto const& choice : choices)
        {
            if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(choice.itemId))
            {
                DCAddon::JsonValue obj;
                obj.SetObject();
                obj.Set("itemId", DCAddon::JsonValue(choice.itemId));
                obj.Set("name", DCAddon::JsonValue(std::string(proto->Name1)));
                obj.Set("itemLevel", DCAddon::JsonValue(choice.itemLevel));
                obj.Set("quality", DCAddon::JsonValue(uint32(proto->Quality)));
                arr.Push(obj);
            }
        }
        resp.Set("items", arr);
        resp.Send(player);
    }

    static void HandleTokenVendorBuy(Player* player, DCAddon::ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 itemId = 0;
        uint32 itemLevel = 0;
        uint32 slot = 0;
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue req = DCAddon::GetJsonData(msg);
            if (req.IsObject())
            {
                if (req.HasKey("itemId") && req["itemId"].IsNumber())
                    itemId = req["itemId"].AsUInt32();
                if (req.HasKey("itemLevel") && req["itemLevel"].IsNumber())
                    itemLevel = req["itemLevel"].AsUInt32();
                if (req.HasKey("slot") && req["slot"].IsNumber())
                    slot = req["slot"].AsUInt32();
            }
        }

        if (!itemId || !itemLevel || !slot)
        {
            SendVendorResult(player, false, "Invalid purchase request.");
            return;
        }

        if (!IsVendorSessionValid(player))
        {
            SendVendorResult(player, false, "Please talk to the vendor again.");
            return;
        }

        // Security: only allow purchases from the current top-3 choice list
        bool allowed = false;
        for (auto const& choice : GetItemsForSlotAndClass(player, uint8(slot), itemLevel))
        {
            if (choice.itemId == itemId)
            {
                allowed = true;
                break;
            }
        }
        if (!allowed)
        {
            SendVendorResult(player, false, "That item is not available for this selection.");
            return;
        }

        ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
        if (!itemTemplate)
        {
            SendVendorResult(player, false, "Item template not found.");
            return;
        }

        uint32 cost = GetTokenCost(itemTemplate->ItemLevel);
        uint32 tokenCount = player->GetItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), true);
        if (tokenCount < cost)
        {
            SendVendorResult(player, false, Acore::StringFormat("You need {} tokens but only have {}.", cost, tokenCount));
            return;
        }

        player->DestroyItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), cost, true);

        ItemPosCountVec dest;
        uint8 canStore = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1);
        if (canStore == EQUIP_ERR_OK)
        {
            if (Item* item = player->StoreNewItem(dest, itemId, true))
            {
                player->SendNewItem(item, 1, true, false);
                SendVendorResult(player, true, Acore::StringFormat("Purchased [{}] for {} tokens!", itemTemplate->Name1, cost));
                return;
            }
        }

        // Inventory full or failed to store: mail
        player->SendItemRetrievalMail(itemId, 1);
        SendVendorResult(player, true, Acore::StringFormat("Inventory full. [{}] mailed!", itemTemplate->Name1));
    }

    static void HandleTokenVendorExchange(Player* player, DCAddon::ParsedMessage const& msg)
    {
        if (!player)
            return;

        if (!IsVendorSessionValid(player))
        {
            SendVendorResult(player, false, "Please talk to the vendor again.");
            return;
        }

        std::string direction;
        uint32 amount = 0;
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue req = DCAddon::GetJsonData(msg);
            if (req.IsObject())
            {
                if (req.HasKey("direction") && req["direction"].IsString())
                    direction = req["direction"].AsString();
                if (req.HasKey("amount") && req["amount"].IsNumber())
                    amount = req["amount"].AsUInt32();
            }
        }

        if (!(amount == 1 || amount == 5))
        {
            SendVendorResult(player, false, "Invalid exchange amount.");
            return;
        }

        auto* upgradeMgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!upgradeMgr)
        {
            SendVendorResult(player, false, "Upgrade manager not available.");
            return;
        }

        uint32 essenceDelta = ESSENCE_PER_TOKEN * amount;

        if (direction == "token_to_essence")
        {
            if (!player->HasItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), amount))
            {
                SendVendorResult(player, false, "You don't have enough tokens.");
                return;
            }

            player->DestroyItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), amount, true);
            upgradeMgr->AddCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE, essenceDelta);
            SendVendorResult(player, true, Acore::StringFormat("Exchanged {} tokens for {} essence.", amount, essenceDelta));
            return;
        }

        if (direction == "essence_to_token")
        {
            uint32 currentEssence = upgradeMgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE);
            if (currentEssence < essenceDelta)
            {
                SendVendorResult(player, false, "You don't have enough essence.");
                return;
            }

            ItemPosCountVec dest;
            InventoryResult canStore = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), amount);
            if (canStore != EQUIP_ERR_OK)
            {
                player->SendEquipError(canStore, nullptr, nullptr, DarkChaos::ItemUpgrade::GetUpgradeTokenItemId());
                SendVendorResult(player, false, "Not enough bag space.");
                return;
            }

            if (!upgradeMgr->RemoveCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE, essenceDelta))
            {
                SendVendorResult(player, false, "Failed to remove essence.");
                return;
            }

            if (Item* item = player->StoreNewItem(dest, DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), true))
            {
                player->SendNewItem(item, amount, true, false);
                SendVendorResult(player, true, Acore::StringFormat("Exchanged {} essence for {} tokens.", essenceDelta, amount));
                return;
            }

            SendVendorResult(player, false, "Failed to create token item.");
            return;
        }

        SendVendorResult(player, false, "Invalid exchange direction.");
    }

    static void SendVendorOpen(Player* player)
    {
        auto* upgradeMgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!upgradeMgr)
            return;

        uint32 currentEssence = upgradeMgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE);
        uint32 tokenCount = player->GetItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), true);
        std::string armorType = GetArmorTypeForClass(player->getClass());

        DCAddon::JsonMessage open(DCAddon::Module::MYTHIC_PLUS, DCAddon::Opcode::MPlus::SMSG_TOKEN_VENDOR_OPEN);
        open.Set("tokens", tokenCount);
        open.Set("essence", currentEssence);
        open.Set("armorType", armorType);

        // Tier definitions (for UI rendering)
        DCAddon::JsonValue tiers;
        tiers.SetArray();
        auto addTier = [&](uint32 ilvl)
        {
            DCAddon::JsonValue t;
            t.SetObject();
            t.Set("itemLevel", DCAddon::JsonValue(ilvl));
            t.Set("cost", DCAddon::JsonValue(GetTokenCost(ilvl)));
            tiers.Push(t);
        };
        addTier(200);
        addTier(213);
        addTier(226);
        addTier(239);
        addTier(252);
        open.Set("tiers", tiers);

        open.Send(player);
    }
}

class npc_mythic_token_vendor : public CreatureScript
{
public:
    npc_mythic_token_vendor() : CreatureScript("npc_mythic_token_vendor") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        bool protocolEnabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.MythicPlus.Enable", true);
        static bool didLogMissingAutoOpenConfigOnce = false;
        bool autoOpenUi = sConfigMgr->GetOption<int32>(
            "DC.MythicPlus.AddonUI.AutoOpen",
            1,
            !didLogMissingAutoOpenConfigOnce) != 0;
        didLogMissingAutoOpenConfigOnce = true;
        if (protocolEnabled && autoOpenUi)
        {
            VendorUiSession session;
            session.creatureGuid = creature->GetGUID();
            session.expiresAt = time(nullptr) + VENDOR_UI_SESSION_SECONDS;
            s_vendorUiSessions[player->GetGUID().GetCounter()] = session;
            SendVendorOpen(player);
            CloseGossipMenuFor(player);
            return true;
        }

        ClearGossipMenuFor(player);

        // Count player's tokens
        uint32 tokenCount = player->GetItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId());
        std::string armorType = GetArmorTypeForClass(player->getClass());

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff8000=== Mythic+ Token Vendor ===|r", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffYour Tokens:|r " + std::to_string(tokenCount), GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffArmor Type:|r " + armorType, GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);

        // Addon UI entry (recommended)
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff32c4ff[UI]|r Open Token Vendor UI", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_OPEN_VENDOR_UI);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);

        // Item level tiers
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ff00Item Level 200 Gear|r (11 tokens)", GOSSIP_SENDER_MAIN, 200);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ff00Item Level 213 Gear|r (12 tokens)", GOSSIP_SENDER_MAIN, 213);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ff00Item Level 226 Gear|r (13 tokens)", GOSSIP_SENDER_MAIN, 226);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cffff8000Item Level 239 Gear|r (14 tokens)", GOSSIP_SENDER_MAIN, 239);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cffff8000Item Level 252 Gear|r (15 tokens)", GOSSIP_SENDER_MAIN, 252);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "|cffffd700Currency Exchange (Tokens <-> Essence)|r", GOSSIP_SENDER_MAIN, 2000);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "|cffaaaaaa[Info] How do tokens work?|r", GOSSIP_SENDER_MAIN, 1000);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, 0);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        (void)sender;  // Currently unused

        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);

        // Open Addon UI
        if (action == GOSSIP_ACTION_OPEN_VENDOR_UI)
        {
            VendorUiSession session;
            session.creatureGuid = creature->GetGUID();
            session.expiresAt = time(nullptr) + VENDOR_UI_SESSION_SECONDS;
            s_vendorUiSessions[player->GetGUID().GetCounter()] = session;
            SendVendorOpen(player);
            CloseGossipMenuFor(player);
            return true;
        }

        // Show info
        if (action == 1000)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff00=== Token System ===|r", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Tokens are earned from the Great Vault", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "for completing Mythic+ dungeons each week.", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Exchange tokens for gear appropriate to", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "your class, spec, and chosen item level.", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffToken Cost:|r", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "  ilvl 200: 11 tokens", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "  ilvl 213: 12 tokens", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "  ilvl 226: 13 tokens", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "  ilvl 239: 14 tokens", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "  ilvl 252: 15 tokens", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "<< Back", GOSSIP_SENDER_MAIN, 9999);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return true;
        }

        // Currency Exchange Menu
        if (action == 2000)
        {
            auto* upgradeMgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
            if (!upgradeMgr) return true;

            uint32 currentEssence = upgradeMgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE);
            uint32 tokenCount = player->GetItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), true);

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff8000=== Token Exchange ===|r", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG,
                "Current Essence: |cffffffff" + std::to_string(currentEssence) + "|r",
                GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG,
                "Current Tokens: |cffffffff" + std::to_string(tokenCount) + "|r",
                GOSSIP_SENDER_MAIN, 0);

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);

            // Token -> Essence
            if (tokenCount >= 1)
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Exchange 1 Token for " + std::to_string(ESSENCE_PER_TOKEN) + " Essence", GOSSIP_SENDER_MAIN, 2001);
            if (tokenCount >= 5)
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Exchange 5 Tokens for " + std::to_string(ESSENCE_PER_TOKEN * 5) + " Essence", GOSSIP_SENDER_MAIN, 2002);

            // Essence -> Token
            if (currentEssence >= ESSENCE_PER_TOKEN)
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Exchange " + std::to_string(ESSENCE_PER_TOKEN) + " Essence for 1 Token", GOSSIP_SENDER_MAIN, 2003);
            if (currentEssence >= ESSENCE_PER_TOKEN * 5)
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Exchange " + std::to_string(ESSENCE_PER_TOKEN * 5) + " Essence for 5 Tokens", GOSSIP_SENDER_MAIN, 2004);

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "<< Back", GOSSIP_SENDER_MAIN, 9999);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return true;
        }

        // Perform Exchange
        if (action >= 2001 && action <= 2004)
        {
            auto* upgradeMgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
            if (!upgradeMgr) return true;

            uint32 tokensToTake = 0;
            uint32 essenceToGive = 0;
            uint32 essenceToTake = 0;
            uint32 tokensToGive = 0;

            switch (action)
            {
                case 2001: tokensToTake = 1; essenceToGive = ESSENCE_PER_TOKEN; break;
                case 2002: tokensToTake = 5; essenceToGive = ESSENCE_PER_TOKEN * 5; break;
                case 2003: essenceToTake = ESSENCE_PER_TOKEN; tokensToGive = 1; break;
                case 2004: essenceToTake = ESSENCE_PER_TOKEN * 5; tokensToGive = 5; break;
            }

            if (tokensToTake > 0)
            {
                if (player->HasItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), tokensToTake))
                {
                    player->DestroyItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), tokensToTake, true);
                    upgradeMgr->AddCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE, essenceToGive);
                    ChatHandler(player->GetSession()).PSendSysMessage("Exchanged %u Tokens for %u Essence.", tokensToTake, essenceToGive);
                }
                else
                    ChatHandler(player->GetSession()).SendSysMessage("You don't have enough tokens.");
            }
            else if (essenceToTake > 0)
            {
                uint32 currentEssence = upgradeMgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE);
                if (currentEssence >= essenceToTake)
                {
                    ItemPosCountVec dest;
                    InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), tokensToGive);
                    if (msg == EQUIP_ERR_OK)
                    {
                        if (upgradeMgr->RemoveCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE, essenceToTake))
                        {
                            if (Item* item = player->StoreNewItem(dest, DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), true))
                            {
                                player->SendNewItem(item, tokensToGive, true, false);
                                ChatHandler(player->GetSession()).PSendSysMessage("Exchanged %u Essence for %u Tokens.", essenceToTake, tokensToGive);
                            }
                        }
                    }
                    else
                        player->SendEquipError(msg, nullptr, nullptr, DarkChaos::ItemUpgrade::GetUpgradeTokenItemId());
                }
                else
                    ChatHandler(player->GetSession()).SendSysMessage("You don't have enough Essence.");
            }

            // Return to exchange menu
            OnGossipSelect(player, creature, sender, 2000);
            return true;
        }

        // Back to main menu
        if (action == 9999)
        {
            return OnGossipHello(player, creature);
        }

        // Select item level tier
        if (action >= 200 && action <= 300)
        {
            uint32 selectedIlvl = action;
            ShowGearSlotMenu(player, creature, selectedIlvl);
            return true;
        }

        // Show item choices for slot (action format: ilvl * 1000 + slot)
        if (action >= 200000 && action < 300000)
        {
            uint32 itemLevel = action / 1000;
            uint8 slot = action % 1000;

            ShowItemChoices(player, creature, itemLevel, slot);
            return true;
        }

        // Purchase gear (action format: 5000000 + itemId)
        if (action >= 5000000)
        {
            uint32 itemId = action - 5000000;
            PurchaseGear(player, creature, itemId);
            return true;
        }

        CloseGossipMenuFor(player);
        return true;
    }

private:
    void ShowGearSlotMenu(Player* player, Creature* creature, uint32 itemLevel)
    {
        ClearGossipMenuFor(player);

        uint32 tokenCount = player->GetItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId());
        uint32 cost = GetTokenCost(itemLevel);
        std::string armorType = GetArmorTypeForClass(player->getClass());

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff8000Item Level " + std::to_string(itemLevel) + " Gear|r", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffCost:|r " + std::to_string(cost) + " tokens | |cffffffffYou have:|r " + std::to_string(tokenCount), GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);

        // Gear slots
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Head (" + armorType + ")", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_HEAD);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Neck", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_NECK);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Shoulders (" + armorType + ")", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_SHOULDERS);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Back", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_BACK);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Chest (" + armorType + ")", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_CHEST);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Wrist (" + armorType + ")", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_WRIST);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Hands (" + armorType + ")", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_HANDS);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Waist (" + armorType + ")", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_WAIST);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Legs (" + armorType + ")", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_LEGS);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Feet (" + armorType + ")", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_FEET);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Finger (Ring)", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_FINGER);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Trinket", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_TRINKET);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Weapon", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_WEAPON);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Off-hand / Shield", GOSSIP_SENDER_MAIN, itemLevel * 1000 + TOKEN_SLOT_OFFHAND);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "<< Back", GOSSIP_SENDER_MAIN, 9999);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void ShowItemChoices(Player* player, Creature* creature, uint32 itemLevel, uint8 slot)
    {
        ClearGossipMenuFor(player);

        uint32 tokenCount = player->GetItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId());
        uint32 cost = GetTokenCost(itemLevel);

        // Query item_template for suitable items
        std::vector<ItemChoice> choices = ::GetItemsForSlotAndClass(player, slot, itemLevel);

        if (choices.empty())
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff0000No items found!|r", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No suitable items found for your class,", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "slot, and item level combination.", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "<< Back", GOSSIP_SENDER_MAIN, itemLevel);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return;
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff8000Choose Your Item|r", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffCost:|r " + std::to_string(cost) + " tokens | |cffffffffYou have:|r " + std::to_string(tokenCount), GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);

        // Show up to 3 item choices with preview
        for (size_t i = 0; i < choices.size() && i < 3; ++i)
        {
            ItemChoice const& choice = choices[i];
            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(choice.itemId);
            if (!proto)
                continue;

            std::string itemLink = GetItemLink(choice.itemId, proto);
            std::string displayText = itemLink + " (ilvl " + std::to_string(choice.itemLevel) + ")";

            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, displayText, GOSSIP_SENDER_MAIN, 5000000 + choice.itemId);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "<< Back", GOSSIP_SENDER_MAIN, itemLevel);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void PurchaseGear(Player* player, Creature* creature, uint32 itemId)
    {
        (void)creature;

        // Verify item template exists
        ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
        if (!itemTemplate)
        {
            ChatHandler(player->GetSession()).SendSysMessage("|cffff0000Error:|r Item template not found.");
            CloseGossipMenuFor(player);
            return;
        }

        uint32 cost = GetTokenCost(itemTemplate->ItemLevel);
        uint32 tokenCount = player->GetItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId());

        // Check if player has enough tokens
        if (tokenCount < cost)
        {
            ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cffff0000Error:|r You need {} tokens but only have {}.", cost, tokenCount));
            CloseGossipMenuFor(player);
            return;
        }

        // Remove tokens
        player->DestroyItemCount(DarkChaos::ItemUpgrade::GetUpgradeTokenItemId(), cost, true);

        // Give item
        ItemPosCountVec dest;
        uint8 msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1);

        if (msg == EQUIP_ERR_OK)
        {
            if (Item* item = player->StoreNewItem(dest, itemId, true))
            {
                player->SendNewItem(item, 1, true, false);
                std::string successMsg = "|cff00ff00Success:|r Purchased [" + std::string(itemTemplate->Name1) + "] for " + std::to_string(cost) + " tokens!";
                ChatHandler(player->GetSession()).SendSysMessage(successMsg.c_str());
            }
        }
        else
        {
            player->SendItemRetrievalMail(itemId, 1);
            std::string mailMsg = "|cff00ff00Success:|r Inventory full. [" + std::string(itemTemplate->Name1) + "] mailed!";
            ChatHandler(player->GetSession()).SendSysMessage(mailMsg.c_str());
        }

        CloseGossipMenuFor(player);
    }

    // Note: item selection queries are implemented in file-scope helpers for reuse
};

void AddSC_npc_mythic_token_vendor()
{
    new npc_mythic_token_vendor();

    // DCAddonProtocol handlers for UI
    bool enabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.MythicPlus.Enable", true);
    if (enabled)
    {
        DCAddon::MessageRouter::Instance().RegisterHandler(DCAddon::Module::MYTHIC_PLUS, DCAddon::Opcode::MPlus::CMSG_TOKEN_VENDOR_CHOICES, HandleTokenVendorChoices);
        DCAddon::MessageRouter::Instance().RegisterHandler(DCAddon::Module::MYTHIC_PLUS, DCAddon::Opcode::MPlus::CMSG_TOKEN_VENDOR_BUY, HandleTokenVendorBuy);
        DCAddon::MessageRouter::Instance().RegisterHandler(DCAddon::Module::MYTHIC_PLUS, DCAddon::Opcode::MPlus::CMSG_TOKEN_VENDOR_EXCHANGE, HandleTokenVendorExchange);
    }
}
