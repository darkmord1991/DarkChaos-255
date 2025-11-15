/*
 * Mythic+ Keystone Vendor NPC Script
 * Single vendor NPC that distributes keystone items via gossip
 * Keystones are item objects (190001-190009) for M+2 through M+10
 * Players receive keystones and use them on the pedestal in dungeons
 * Entry: 100100
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "MythicPlusRunManager.h"
#include "MythicPlusConstants.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "ObjectGuid.h"

using namespace MythicPlusConstants;

// Gossip action IDs
enum KeystoneGossipActions
{
    GOSSIP_ACTION_KEYSTONE_START = 1,
    GOSSIP_ACTION_KEYSTONE_INFO = 2,
    GOSSIP_ACTION_CLOSE = 3
};

class npc_keystone_vendor : public CreatureScript
{
public:
    npc_keystone_vendor() : CreatureScript("npc_keystone_vendor") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);

        // Check if player is level 80
        if (player->GetLevel() < 80)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "|cffff0000You must be level 80 to receive a keystone.|r", 
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLOSE);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return true;
        }

        // Check if player already has a keystone in inventory
        bool hasKeystone = false;
        for (uint8 level = MIN_KEYSTONE_LEVEL; level <= MAX_KEYSTONE_LEVEL; ++level)
        {
            uint32 itemId = GetItemIdFromKeystoneLevel(level);
            if (player->HasItemCount(itemId, 1, false))
            {
                hasKeystone = true;
                break;
            }
        }

        if (hasKeystone)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "|cffffff00You already have a keystone in your inventory.|r", 
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLOSE);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "|cffaaaaaa[Close]|r", 
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLOSE);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return true;
        }

        // Offer starter keystone (M+2)
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000=== Mythic+ Keystone Vendor ===|r", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);

        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, 
            "|cff00ff00Receive Mythic Keystone +2|r", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_START);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "|cffaaaaaa[Close]|r", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLOSE);
        
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!player || !creature)
            return false;

        // Close on close action
        if (action == GOSSIP_ACTION_CLOSE || action == GOSSIP_ACTION_KEYSTONE_INFO)
        {
            CloseGossipMenuFor(player);
            return true;
        }

        // Handle starter keystone request
        if (action == GOSSIP_ACTION_KEYSTONE_START)
        {
            // Give M+2 keystone (item 190001)
            uint32 keystoneItemId = 190001; // M+2 keystone

            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, keystoneItemId, 1);
            
            if (msg == EQUIP_ERR_OK)
            {
                Item* keystoneItem = player->StoreNewItem(dest, keystoneItemId, true);
                if (keystoneItem)
                {
                    ChatHandler(player->GetSession()).PSendSysMessage(
                        "|cff00ff00Mythic+:|r You received a |cff1eff00Mythic Keystone +2|r! Use it in any dungeon to begin your journey.");
                    LOG_INFO("mythic.keystone", "Player {} received M+2 keystone", player->GetName());
                }
                else
                {
                    ChatHandler(player->GetSession()).PSendSysMessage(
                        "|cffff0000Error:|r Failed to store keystone item!");
                    LOG_ERROR("mythic.keystone", "Failed to store keystone for player {}", player->GetName());
                }
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cffff0000Error:|r Not enough inventory space!");
                LOG_WARN("mythic.keystone", "No inventory space for player {}", player->GetName());
            }

            CloseGossipMenuFor(player);
            return true;
        }

        CloseGossipMenuFor(player);
        return true;
    }
};

// Script registration
void AddSC_npc_keystone_vendor()
{
    new npc_keystone_vendor();
}
