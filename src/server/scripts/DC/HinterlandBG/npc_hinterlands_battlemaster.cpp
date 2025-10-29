/*
 * Hinterlands Battleground Battlemaster NPC
 * Allows players to queue for Hinterlands BG via NPC interaction
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "OutdoorPvP/OutdoorPvPHL.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"

enum BattlemasterActions
{
    ACTION_JOIN_QUEUE   = GOSSIP_ACTION_INFO_DEF + 1,
    ACTION_LEAVE_QUEUE  = GOSSIP_ACTION_INFO_DEF + 2,
    ACTION_QUEUE_STATUS = GOSSIP_ACTION_INFO_DEF + 3
};

class npc_hinterlands_battlemaster : public CreatureScript
{
public:
    npc_hinterlands_battlemaster() : CreatureScript("npc_hinterlands_battlemaster") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Check if player can join
        if (player->GetLevel() < 255)
        {
            CloseGossipMenuFor(player);
            ChatHandler(player->GetSession()).PSendSysMessage("You must be level 255 to enter the Hinterlands Battleground.");
            return true;
        }

        // Get OutdoorPvP instance
        OutdoorPvP* outdoorPvP = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
        if (!outdoorPvP)
        {
            CloseGossipMenuFor(player);
            ChatHandler(player->GetSession()).PSendSysMessage("Hinterlands Battleground is currently unavailable.");
            return true;
        }

        OutdoorPvPHL* hlbg = dynamic_cast<OutdoorPvPHL*>(outdoorPvP);
        if (!hlbg)
        {
            CloseGossipMenuFor(player);
            ChatHandler(player->GetSession()).PSendSysMessage("Hinterlands Battleground is currently unavailable.");
            return true;
        }

        // Show menu options
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Join Hinterlands Battleground Queue", GOSSIP_SENDER_MAIN, ACTION_JOIN_QUEUE);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Leave Hinterlands Battleground Queue", GOSSIP_SENDER_MAIN, ACTION_LEAVE_QUEUE);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Queue Status", GOSSIP_SENDER_MAIN, ACTION_QUEUE_STATUS);

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* /*creature*/, uint32 /*sender*/, uint32 action) override
    {
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
            case ACTION_JOIN_QUEUE:
                hlbg->HandleQueueJoinCommand(player);
                break;
            case ACTION_LEAVE_QUEUE:
                hlbg->HandleQueueLeaveCommand(player);
                break;
            case ACTION_QUEUE_STATUS:
                hlbg->HandleQueueStatusCommand(player);
                break;
            default:
                break;
        }

        CloseGossipMenuFor(player);
        return true;
    }
};

void AddSC_npc_hinterlands_battlemaster()
{
    new npc_hinterlands_battlemaster();
}
