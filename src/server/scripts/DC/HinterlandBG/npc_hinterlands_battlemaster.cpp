/*
 * Hinterlands Battleground Battlemaster NPC
 * Allows players to join the custom Hinterlands BG queue
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "Battleground.h"
#include "BattlegroundMgr.h"

// Custom Battleground Type ID for Hinterlands
// TODO: Define this in BattlegroundMgr.h or use existing custom BG type
#define BATTLEGROUND_HINTERLANDS 32  // Adjust based on your server's custom BG ID

class npc_hinterlands_battlemaster : public CreatureScript
{
public:
    npc_hinterlands_battlemaster() : CreatureScript("npc_hinterlands_battlemaster") { }

    struct npc_hinterlands_battlemasterAI : public ScriptedAI
    {
        npc_hinterlands_battlemasterAI(Creature* creature) : ScriptedAI(creature) { }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_hinterlands_battlemasterAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        // Check if player meets requirements
        if (player->GetLevel() < 255)
        {
            ChatHandler(player->GetSession()).SendNotification("You must be level 255 to enter Hinterlands Battleground!");
            return true;
        }

        // Add gossip menu options
        ClearGossipMenuFor(player);
        
        // Check if player is already in queue
    BattlegroundQueueTypeId bgQueueTypeId = BattlegroundMgr::BGQueueTypeId(BattlegroundTypeId(BATTLEGROUND_HINTERLANDS), 0);
        if (player->InBattlegroundQueueForBattlegroundQueueType(bgQueueTypeId))
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Leave Hinterlands Battleground Queue", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        }
        else
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Join Hinterlands Battleground", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        }
        
        // Add info option
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Tell me about Hinterlands Battleground", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
        
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);

        switch (action)
        {
            case GOSSIP_ACTION_INFO_DEF + 1: // Join Queue
            {
                // Join battleground queue
                BattlegroundTypeId bgTypeId = BattlegroundTypeId(BATTLEGROUND_HINTERLANDS);
                BattlegroundQueueTypeId bgQueueTypeId = BattlegroundMgr::BGQueueTypeId(bgTypeId, 0);
                
                // Get bracket ID based on level (for level 255, use max bracket)
                PvPDifficultyEntry const* pvpDiff = GetBattlegroundBracketByLevel(571, player->GetLevel()); // Use Northrend map for 255 bracket
                if (!pvpDiff)
                {
                    ChatHandler(player->GetSession()).SendNotification("Could not find appropriate bracket!");
                    CloseGossipMenuFor(player);
                    return true;
                }

                uint8 arenaType = 0; // 0 for battleground
                bool isPremade = false;
                uint8 arenaRating = 0;
                uint8 matchmakerRating = 0;

                BattlegroundQueue& bgQueue = sBattlegroundMgr->GetBattlegroundQueue(bgQueueTypeId);

                GroupQueueInfo* ginfo = bgQueue.AddGroup(player, nullptr, bgTypeId, pvpDiff, arenaType,
                    false, isPremade, arenaRating, matchmakerRating, 0);

                if (ginfo)
                {
                    uint32 avgWaitTime = bgQueue.GetAverageQueueWaitTime(ginfo);
                    uint32 queueSlot = player->AddBattlegroundQueueId(bgQueueTypeId);

                    WorldPacket data;
                    sBattlegroundMgr->BuildBattlegroundStatusPacket(&data, nullptr, queueSlot, STATUS_WAIT_QUEUE,
                        avgWaitTime, 0, arenaType, TEAM_NEUTRAL);
                    player->SendDirectMessage(&data);

                    ChatHandler(player->GetSession()).SendNotification("You have joined the Hinterlands Battleground queue!");
                }
                else
                {
                    ChatHandler(player->GetSession()).SendNotification("Could not join queue. Please try again.");
                }
                
                CloseGossipMenuFor(player);
                break;
            }
            case GOSSIP_ACTION_INFO_DEF + 2: // Leave Queue
            {
                BattlegroundQueueTypeId bgQueueTypeId = BattlegroundMgr::BGQueueTypeId(BattlegroundTypeId(BATTLEGROUND_HINTERLANDS), 0);
                player->RemoveBattlegroundQueueId(bgQueueTypeId);
                
                WorldPacket data;
                sBattlegroundMgr->BuildBattlegroundStatusPacket(&data, nullptr, 0, STATUS_NONE, 0, 0, 0, TEAM_NEUTRAL);
                player->SendDirectMessage(&data);

                ChatHandler(player->GetSession()).SendNotification("You have left the Hinterlands Battleground queue.");
                CloseGossipMenuFor(player);
                break;
            }
            case GOSSIP_ACTION_INFO_DEF + 3: // Info
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
                SendGossipMenuFor(player, 50000, creature->GetGUID()); // Custom text ID - add to gossip_menu_option
                break;
            }
            default:
                OnGossipHello(player, creature);
                break;
        }

        return true;
    }
};

void AddSC_npc_hinterlands_battlemaster()
{
    new npc_hinterlands_battlemaster();
}
