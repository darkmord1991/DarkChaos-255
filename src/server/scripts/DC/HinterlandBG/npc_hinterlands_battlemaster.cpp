/*
 * Hinterlands Battleground Battlemaster NPC
 * Allows players to queue for Hinterlands BG via NPC interaction
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "OutdoorPvP/OutdoorPvPHL.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"

class npc_hinterlands_battlemaster : public CreatureScript
{
public:
    npc_hinterlands_battlemaster() : CreatureScript("npc_hinterlands_battlemaster") { }

    struct npc_hinterlands_battlemasterAI : public ScriptedAI
    {
        npc_hinterlands_battlemasterAI(Creature* creature) : ScriptedAI(creature) { }

        bool OnGossipHello(Player* player) override
        {
            // Check if player can join
            if (player->GetLevel() < 255)
            {
                player->PlayerTalkClass->SendCloseGossip();
                ChatHandler(player->GetSession()).PSendSysMessage("You must be level 255 to enter the Hinterlands Battleground.");
                return true;
            }

            // Get OutdoorPvP instance
            OutdoorPvP* outdoorPvP = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
            if (!outdoorPvP)
            {
                player->PlayerTalkClass->SendCloseGossip();
                ChatHandler(player->GetSession()).PSendSysMessage("Hinterlands Battleground is currently unavailable.");
                return true;
            }

            OutdoorPvPHL* hlbg = dynamic_cast<OutdoorPvPHL*>(outdoorPvP);
            if (!hlbg)
            {
                player->PlayerTalkClass->SendCloseGossip();
                ChatHandler(player->GetSession()).PSendSysMessage("Hinterlands Battleground is currently unavailable.");
                return true;
            }

            // Check if player is already in queue
            if (hlbg->IsPlayerInQueue(player->GetGUID()))
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Leave Hinterlands Battleground Queue", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Queue Status", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
            }
            else
            {
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Join Hinterlands Battleground", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Queue Status", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
            }

            SendGossipMenuFor(player, player->GetGossipTextId(me), me->GetGUID());
            return true;
        }

        bool OnGossipSelect(Player* player, uint32 /*menuId*/, uint32 gossipListId) override
        {
            uint32 action = player->PlayerTalkClass->GetGossipOptionAction(gossipListId);
            ClearGossipMenuFor(player);

            OutdoorPvP* outdoorPvP = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
            if (!outdoorPvP)
            {
                CloseGossipMenuFor(player);
                return true;
            }

            OutdoorPvPHL* hlbg = dynamic_cast<OutdoorPvPHL*>(outdoorPvP);
            if (!hlbg)
            {
                CloseGossipMenuFor(player);
                return true;
            }

            switch (action)
            {
                case GOSSIP_ACTION_INFO_DEF + 1: // Join queue
                {
                    if (!hlbg->IsPlayerInQueue(player->GetGUID()))
                    {
                        hlbg->AddPlayerToQueue(player->GetGUID());
                        ChatHandler(player->GetSession()).PSendSysMessage("You have joined the Hinterlands Battleground queue.");
                    }
                    else
                    {
                        ChatHandler(player->GetSession()).PSendSysMessage("You are already in the queue.");
                    }
                    CloseGossipMenuFor(player);
                    break;
                }
                case GOSSIP_ACTION_INFO_DEF + 2: // Leave queue
                {
                    if (hlbg->IsPlayerInQueue(player->GetGUID()))
                    {
                        hlbg->RemovePlayerFromQueue(player->GetGUID());
                        ChatHandler(player->GetSession()).PSendSysMessage("You have left the Hinterlands Battleground queue.");
                    }
                    else
                    {
                        ChatHandler(player->GetSession()).PSendSysMessage("You are not in the queue.");
                    }
                    CloseGossipMenuFor(player);
                    break;
                }
                case GOSSIP_ACTION_INFO_DEF + 3: // Queue status
                {
                    uint32 hordeCount = hlbg->GetQueueCountForTeam(HORDE);
                    uint32 allianceCount = hlbg->GetQueueCountForTeam(ALLIANCE);
                    
                    ChatHandler(player->GetSession()).PSendSysMessage("Hinterlands BG Queue Status:");
                    ChatHandler(player->GetSession()).PSendSysMessage("Alliance: %u | Horde: %u", allianceCount, hordeCount);
                    
                    if (hlbg->IsPlayerInQueue(player->GetGUID()))
                    {
                        ChatHandler(player->GetSession()).PSendSysMessage("You are currently in the queue.");
                    }
                    CloseGossipMenuFor(player);
                    break;
                }
                default:
                    CloseGossipMenuFor(player);
                    break;
            }

            return true;
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_hinterlands_battlemasterAI(creature);
    }
};

void AddSC_npc_hinterlands_battlemaster()
{
    new npc_hinterlands_battlemaster();
}
