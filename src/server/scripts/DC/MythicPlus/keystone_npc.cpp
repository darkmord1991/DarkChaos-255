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

        // Get player's current keystone level from database
        // If they don't have a keystone, default to M+2
        uint8 keystoneLevel = MIN_KEYSTONE_LEVEL;
        
        // TODO: Query player's active keystone level from database
        // For now, default to M+2 for testing

        // Display all available keystones
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000=== Mythic+ Keystones ===|r", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);

        // Show keystone options for M+2 through M+20
        for (uint8 level = MIN_KEYSTONE_LEVEL; level <= MAX_KEYSTONE_LEVEL; ++level)
        {
            uint32 itemLevel = GetItemLevelForKeystoneLevel(level);
            std::string coloredName = GetKeystoneColoredName(level);
            std::string gossipText = coloredName + " |cffffffffItemLevel: " + std::to_string(itemLevel) + "|r";
            
            // Use level as action ID (2-20)
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, gossipText, 
                GOSSIP_SENDER_MAIN, level);
        }

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
        if (action == GOSSIP_ACTION_CLOSE)
        {
            CloseGossipMenuFor(player);
            return true;
        }

        // Validate keystone level (action is the keystone level 2-20)
        if (action >= MIN_KEYSTONE_LEVEL && action <= MAX_KEYSTONE_LEVEL)
        {
            uint8 keystoneLevel = static_cast<uint8>(action);
            uint32 keystoneItemId = GetItemIdFromKeystoneLevel(keystoneLevel);

            // Give player the keystone item
            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, keystoneItemId, 1);
            
            if (msg == EQUIP_ERR_OK)
            {
                Item* keystoneItem = player->StoreNewItem(dest, keystoneItemId, true);
                if (keystoneItem)
                {
                    ChatHandler(player->GetSession()).PSendSysMessage(
                        "|cff00ff00Mythic+:|r You received a %s |cffffffffKeystone|r!", 
                        GetKeystoneColoredName(keystoneLevel).c_str());
                }
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cffff0000Error:|r Not enough inventory space!");
            }
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
