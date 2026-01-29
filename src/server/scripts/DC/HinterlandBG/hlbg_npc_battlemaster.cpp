/*
 * Hinterlands BG Battlemaster NPC
 *
 * This NPC is a thin UI wrapper around the HLBG queue system implemented by
 * OutdoorPvPHL (not the core BattlegroundMgr queues).
 */

#include "hlbg.h"
#include "CreatureScript.h"
#include "Player.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"
#include "Chat.h"

namespace
{
    OutdoorPvPHL* GetHL()
    {
        OutdoorPvP* opvp = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
        return opvp ? dynamic_cast<OutdoorPvPHL*>(opvp) : nullptr;
    }
}

class npc_hinterlands_battlemaster : public CreatureScript
{
public:
    npc_hinterlands_battlemaster() : CreatureScript("npc_hinterlands_battlemaster") { }

    static std::string MakeLargeGossipText(std::string const& icon, std::string const& text)
    {
        return "|T" + icon + ":40:40:-18|t " + text;
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        OutdoorPvPHL* hl = GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendNotification("HLBG system is not available right now.");
            return true;
        }

        ClearGossipMenuFor(player);

        if (hl->IsPlayerQueued(player))
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                MakeLargeGossipText("Interface\\Icons\\Ability_Whirlwind", "Leave Hinterlands BG Queue"),
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        else
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                MakeLargeGossipText("Interface\\Icons\\Ability_Whirlwind", "Join Hinterlands BG Queue"),
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            MakeLargeGossipText("Interface\\Icons\\INV_Misc_QuestionMark", "What is Hinterlands BG?"),
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);

        OutdoorPvPHL* hl = GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendNotification("HLBG system is not available right now.");
            CloseGossipMenuFor(player);
            return true;
        }

        switch (action)
        {
            case GOSSIP_ACTION_INFO_DEF + 1: // Join
                hl->QueueCommandFromAddon(player, "queue", "join");
                CloseGossipMenuFor(player);
                return true;
            case GOSSIP_ACTION_INFO_DEF + 2: // Leave
                hl->QueueCommandFromAddon(player, "queue", "leave");
                CloseGossipMenuFor(player);
                return true;
            case GOSSIP_ACTION_INFO_DEF + 3: // Info
                ChatHandler(player->GetSession()).SendNotification("Hinterlands BG is a zone-wide PvP event in the Hinterlands. Use this NPC or .hlbg queue to join/leave.");
                return OnGossipHello(player, creature);
            default:
                return OnGossipHello(player, creature);
        }
    }
};

void AddSC_npc_hinterlands_battlemaster()
{
    new npc_hinterlands_battlemaster();
}
