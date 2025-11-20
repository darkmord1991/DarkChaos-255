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
#include "StringFormat.h"

using namespace MythicPlusConstants;

// Gossip action IDs
enum KeystoneGossipActions : uint32
{
    GOSSIP_ACTION_KEYSTONE_INFO       = 1,
    GOSSIP_ACTION_CLOSE               = 2,
    GOSSIP_ACTION_KEYSTONE_SELECT_BASE = 100
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

        // Header
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000=== Mythic+ Keystone Vendor ===|r", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);

        // GMs get access to all keystone levels
        if (player->GetSession()->GetSecurity() > SEC_PLAYER)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "|cffff00ff[GM] Select Keystone Level:|r", 
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);
            
            for (uint8 level = MIN_KEYSTONE_LEVEL; level <= MAX_KEYSTONE_LEVEL; ++level)
            {
                std::ostringstream ss;
                ss << "|cff00ff00Receive Mythic Keystone +" << static_cast<uint32>(level) << "|r";
                AddGossipItemFor(player, GOSSIP_ICON_VENDOR, ss.str(), 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_SELECT_BASE + level);
            }
        }
        else
        {
            // Regular players get starter keystone (M+2)
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, 
                "|cff00ff00Receive Mythic Keystone +2|r", 
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_SELECT_BASE + MIN_KEYSTONE_LEVEL);
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

        LOG_INFO("mythic.keystone", "OnGossipSelect called for player {} with action {}", player->GetName(), action);

        if (action == GOSSIP_ACTION_CLOSE || action == GOSSIP_ACTION_KEYSTONE_INFO)
        {
            CloseGossipMenuFor(player);
            return true;
        }

        if (action >= GOSSIP_ACTION_KEYSTONE_SELECT_BASE)
        {
            uint32 requestedLevel = action - GOSSIP_ACTION_KEYSTONE_SELECT_BASE;
            uint8 keystoneLevel = static_cast<uint8>(requestedLevel);
            
            // Validate level range
            if (keystoneLevel < MIN_KEYSTONE_LEVEL || keystoneLevel > MAX_KEYSTONE_LEVEL)
            {
                LOG_ERROR("mythic.keystone", "Invalid keystone level {} requested by player {}", keystoneLevel, player->GetName());
                CloseGossipMenuFor(player);
                return true;
            }
            
            // Non-GMs can only get M+2
            if (player->GetSession()->GetSecurity() == SEC_PLAYER && keystoneLevel != MIN_KEYSTONE_LEVEL)
            {
                ChatHandler(player->GetSession()).SendSysMessage(
                    "|cffff0000Error:|r You can only receive a Mythic Keystone +2!");
                LOG_WARN("mythic.keystone", "Player {} (non-GM) attempted to get M+{} keystone", player->GetName(), keystoneLevel);
                CloseGossipMenuFor(player);
                return true;
            }
            
            LOG_INFO("mythic.keystone", "Player {} requesting M+{} keystone", player->GetName(), keystoneLevel);
            
            // Get the item ID for this keystone level
            uint32 keystoneItemId = GetItemIdFromKeystoneLevel(keystoneLevel);

            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, keystoneItemId, 1);
            
            if (msg == EQUIP_ERR_OK)
            {
                Item* keystoneItem = player->StoreNewItem(dest, keystoneItemId, true);
                if (keystoneItem)
                {
                    std::ostringstream ss;
                    ss << "|cff00ff00Mythic+:|r You received a |cff1eff00Mythic Keystone +" 
                       << static_cast<uint32>(keystoneLevel) << "|r! Use it in any dungeon to begin your journey.";
                    ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
                    LOG_INFO("mythic.keystone", "Player {} received M+{} keystone successfully", player->GetName(), keystoneLevel);
                }
                else
                {
                    ChatHandler(player->GetSession()).SendSysMessage(
                        "|cffff0000Error:|r Failed to store keystone item!");
                    LOG_ERROR("mythic.keystone", "Failed to store keystone for player {} - StoreNewItem returned null", player->GetName());
                }
            }
            else
            {
                ChatHandler(player->GetSession()).SendSysMessage(
                    "|cffff0000Error:|r Not enough inventory space!");
                LOG_WARN("mythic.keystone", "No inventory space for player {} - error code {}", player->GetName(), msg);
            }

            CloseGossipMenuFor(player);
            return true;
        }

            LOG_WARN("mythic.keystone", "Unknown action {} for player {}", action, player->GetName());
        CloseGossipMenuFor(player);
        return true;
    }
};

// Script registration
void AddSC_npc_keystone_vendor()
{
    new npc_keystone_vendor();
}
