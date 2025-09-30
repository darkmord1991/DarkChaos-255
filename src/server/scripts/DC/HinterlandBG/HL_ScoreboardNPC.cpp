// -----------------------------------------------------------------------------
// HL_ScoreboardNPC.cpp
// -----------------------------------------------------------------------------
// A simple gossip NPC that shows current/last results for Hinterland BG.
// Place an NPC with this scriptname near each faction base.
// -----------------------------------------------------------------------------
#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "GossipDef.h"
#include "Chat.h"
#include "HinterlandBG.h"

static OutdoorPvPHL* GetHL()
{
    if (OutdoorPvP* pvp = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
        return dynamic_cast<OutdoorPvPHL*>(pvp);
    return nullptr;
}

class npc_hl_scoreboard : public CreatureScript
{
public:
    npc_hl_scoreboard() : CreatureScript("npc_hl_scoreboard") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Hinterland BG status", GOSSIP_SENDER_MAIN, 1);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, 100);
        SendGossipMenuFor(player, 1, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        if (action == 100)
        {
            CloseGossipMenuFor(player);
            return true;
        }
        if (action == 1)
        {
            if (OutdoorPvPHL* hl = GetHL())
            {
                uint32 a = hl->GetResources(TEAM_ALLIANCE);
                uint32 h = hl->GetResources(TEAM_HORDE);
                uint32 sec = hl->GetTimeRemainingSeconds();
                bool locked = false;
                // crude access: using status broadcast as a text
                char msg[256];
                snprintf(msg, sizeof(msg), "Alliance: %u, Horde: %u, Time left: %us", (unsigned)a, (unsigned)h, (unsigned)sec);
                SendGossipMenuFor(player, 1, creature->GetGUID());
                ChatHandler(player->GetSession()).SendNotification("{}", msg);
                return true;
            }
            ChatHandler(player->GetSession()).SendNotification("Hinterland BG is not active.");
        }
        CloseGossipMenuFor(player);
        return true;
    }
};

void AddSC_hl_scoreboard()
{
    new npc_hl_scoreboard();
}
