/*
 * Mythic+ Keystone Vendor NPC Script
 * Single vendor NPC that distributes keystone items via gossip
 * Keystones are item objects (300313-300321) for M+2 through M+10
 * Players receive keystones and use them on the pedestal in dungeons
 * Entry: 100100
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "dc_mythicplus_run_manager.h"
#include "dc_mythicplus_constants.h"
#include "DC/dc_constants.h"
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
            // Reissue at the player's earned level, not a flat +2.
            //
            // dc_player_keystones is the record the run manager writes on every
            // upgrade and on depletion after a failed run - and the run manager
            // explicitly tells players "your +N keystone is held at the keystone
            // vendor" when their bags are full. This vendor previously ignored
            // that record entirely and handed everyone a +2, so a player at +15
            // was told to visit a vendor that would demote them to +2.
            uint8 storedLevel = sMythicRuns->GetPlayerKeystoneLevel(
                player->GetGUID().GetCounter());

            if (storedLevel < MIN_KEYSTONE_LEVEL)
                storedLevel = MIN_KEYSTONE_LEVEL;
            if (storedLevel > MAX_KEYSTONE_LEVEL)
                storedLevel = MAX_KEYSTONE_LEVEL;

            std::ostringstream ss;
            ss << "|cff00ff00Receive Mythic Keystone +" << static_cast<uint32>(storedLevel) << "|r";
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, ss.str(),
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_SELECT_BASE + storedLevel);
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

        LOG_DEBUG("mythic.keystone", "OnGossipSelect called for player {} with action {}", player->GetName(), action);

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

            // Non-GMs can only receive the level they have actually earned.
            if (player->GetSession()->GetSecurity() == SEC_PLAYER)
            {
                uint8 storedLevel = sMythicRuns->GetPlayerKeystoneLevel(
                    player->GetGUID().GetCounter());

                if (storedLevel < MIN_KEYSTONE_LEVEL)
                    storedLevel = MIN_KEYSTONE_LEVEL;
                if (storedLevel > MAX_KEYSTONE_LEVEL)
                    storedLevel = MAX_KEYSTONE_LEVEL;

                if (keystoneLevel != storedLevel)
                {
                    ChatHandler(player->GetSession()).PSendSysMessage(
                        "|cffff0000Error:|r You can only receive a Mythic Keystone +{}.",
                        static_cast<uint32>(storedLevel));
                    LOG_WARN("mythic.keystone", "Player {} (non-GM) attempted to get M+{} keystone but is entitled to M+{}",
                             player->GetName(), keystoneLevel, storedLevel);
                    CloseGossipMenuFor(player);
                    return true;
                }
            }

            LOG_DEBUG("mythic.keystone", "Player {} requesting M+{} keystone", player->GetName(), keystoneLevel);

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
                    player->SendNewItem(keystoneItem, 1, true, false);
                    LOG_INFO("mythic.keystone", "Player {} received M+{} keystone successfully", player->GetName(), keystoneLevel);

                    // Onboarding quest 820063 "A Key to the Deeps". Credited on the
                    // handover rather than through RequiredItemId, because a required
                    // item is destroyed at turn-in and the keystone is the whole point
                    // of the quest.
                    player->KilledMonsterCredit(DCConstants::NPC_CREDIT_KEYSTONE_ACQUIRED);
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
