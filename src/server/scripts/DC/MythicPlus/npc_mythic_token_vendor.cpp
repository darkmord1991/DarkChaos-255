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
#include <map>
#include <vector>

// Token item ID (same as vault rewards)
constexpr uint32 MYTHIC_TOKEN_ITEM = 101000;

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

// Get class-appropriate armor type
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

class npc_mythic_token_vendor : public CreatureScript
{
public:
    npc_mythic_token_vendor() : CreatureScript("npc_mythic_token_vendor") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);
        
        // Count player's tokens
        uint32 tokenCount = player->GetItemCount(MYTHIC_TOKEN_ITEM);
        std::string armorType = GetArmorTypeForClass(player->getClass());
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff8000=== Mythic+ Token Vendor ===|r", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffYour Tokens:|r " + std::to_string(tokenCount), GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffArmor Type:|r " + armorType, GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
        
        // Item level tiers
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ff00Item Level 200 Gear|r (11 tokens)", GOSSIP_SENDER_MAIN, 200);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ff00Item Level 213 Gear|r (12 tokens)", GOSSIP_SENDER_MAIN, 213);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ff00Item Level 226 Gear|r (13 tokens)", GOSSIP_SENDER_MAIN, 226);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cffff8000Item Level 239 Gear|r (14 tokens)", GOSSIP_SENDER_MAIN, 239);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cffff8000Item Level 252 Gear|r (15 tokens)", GOSSIP_SENDER_MAIN, 252);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "|cffaaaaaa[Info] How do tokens work?|r", GOSSIP_SENDER_MAIN, 1000);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, 0);
        
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);

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

        // Purchase gear (action format: ilvl * 1000 + slot)
        if (action >= 200000)
        {
            uint32 itemLevel = action / 1000;
            uint8 slot = action % 1000;
            
            PurchaseGear(player, creature, itemLevel, slot);
            return true;
        }

        CloseGossipMenuFor(player);
        return true;
    }

private:
    void ShowGearSlotMenu(Player* player, Creature* creature, uint32 itemLevel)
    {
        ClearGossipMenuFor(player);
        
        uint32 tokenCount = player->GetItemCount(MYTHIC_TOKEN_ITEM);
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

    void PurchaseGear(Player* player, Creature* creature, uint32 itemLevel, uint8 slot)
    {
        uint32 cost = GetTokenCost(itemLevel);
        uint32 tokenCount = player->GetItemCount(MYTHIC_TOKEN_ITEM);
        
        // Check if player has enough tokens
        if (tokenCount < cost)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Error:|r You need %u tokens but only have %u.", cost, tokenCount);
            CloseGossipMenuFor(player);
            return;
        }

        // TODO: Get class/spec appropriate item for this slot and ilvl
        // For now, create a generic item or token
        // You would query a database table or use predefined item pools here
        
        uint32 itemId = GetItemForSlotAndClass(player->getClass(), slot, itemLevel);
        
        if (itemId == 0)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Error:|r No suitable item found for your class and slot.");
            CloseGossipMenuFor(player);
            return;
        }

        // Verify item template exists
        ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
        if (!itemTemplate)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Error:|r Item template not found.");
            CloseGossipMenuFor(player);
            return;
        }

        // Remove tokens
        player->DestroyItemCount(MYTHIC_TOKEN_ITEM, cost, true);

        // Give item
        ItemPosCountVec dest;
        uint8 msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1);
        
        if (msg == EQUIP_ERR_OK)
        {
            if (Item* item = player->StoreNewItem(dest, itemId, true))
            {
                player->SendNewItem(item, 1, true, false);
                ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Success:|r Purchased [%s] for %u tokens!", 
                                                                  itemTemplate->Name1.c_str(), cost);
            }
        }
        else
        {
            player->SendItemRetrievalMail(itemId, 1);
            ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Success:|r Inventory full. [%s] mailed!", 
                                                              itemTemplate->Name1.c_str());
        }

        CloseGossipMenuFor(player);
    }

    // Query database for class/spec appropriate item
    uint32 GetItemForSlotAndClass(uint8 playerClass, uint8 slot, uint32 itemLevel)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT item_id FROM dc_token_vendor_items "
            "WHERE class = {} AND slot = {} AND item_level = {} "
            "ORDER BY priority DESC, spec ASC LIMIT 1",
            playerClass, slot, itemLevel
        );

        if (!result)
        {
            // No item found in database - could fallback to generic items or return 0
            return 0;
        }

        Field* fields = result->Fetch();
        return fields[0].Get<uint32>();
    }
};

void AddSC_npc_mythic_token_vendor()
{
    new npc_mythic_token_vendor();
}
