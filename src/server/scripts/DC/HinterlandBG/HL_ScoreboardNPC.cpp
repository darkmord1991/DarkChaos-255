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
                uint32 mm = sec / 60u;
                uint32 ss = sec % 60u;
                // Compute current players per team using the raid group GUID sets
                auto const& aRaid = hl->GetBattlegroundGroupGUIDs(TEAM_ALLIANCE);
                auto const& hRaid = hl->GetBattlegroundGroupGUIDs(TEAM_HORDE);
                uint32 aCount = 0, hCount = 0;
                for (ObjectGuid const& g : aRaid) if (!g.IsEmpty()) ++aCount;
                for (ObjectGuid const& g : hRaid) if (!g.IsEmpty()) ++hCount;

                ClearGossipMenuFor(player);
                // Header (non-interactive info lines)
                char line[128];
                snprintf(line, sizeof(line), "Alliance: %u", (unsigned)a);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);
                snprintf(line, sizeof(line), "Horde: %u", (unsigned)h);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);
                snprintf(line, sizeof(line), "Time left: %02u:%02u", (unsigned)mm, (unsigned)ss);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);
                snprintf(line, sizeof(line), "Players — A:%u  H:%u", (unsigned)aCount, (unsigned)hCount);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);

                // Recent history (last 5 winners)
                auto recent = hl->GetRecentWinners(5);
                if (!recent.empty())
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Recent results:", GOSSIP_SENDER_MAIN, 1);
                    uint32 idx = 1;
                    for (auto const& w : recent)
                    {
                        const char* name = (w == TEAM_ALLIANCE ? "Alliance" : (w == TEAM_HORDE ? "Horde" : "Draw"));
                        snprintf(line, sizeof(line), "%u) %s", (unsigned)idx++, name);
                        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);
                    }
                }
                else
                {
                    // Fallback to last persisted winner if any; helps after server restarts
                    TeamId last = hl->GetLastWinnerTeamId();
                    if (last == TEAM_ALLIANCE || last == TEAM_HORDE)
                    {
                        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Last result:", GOSSIP_SENDER_MAIN, 1);
                        const char* name = (last == TEAM_ALLIANCE ? "Alliance" : "Horde");
                        snprintf(line, sizeof(line), "%s", name);
                        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);
                    }
                    else
                    {
                        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No results yet.", GOSSIP_SENDER_MAIN, 1);
                    }
                }

                // Controls
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Refresh", GOSSIP_SENDER_MAIN, 1);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, 100);
                SendGossipMenuFor(player, 1, creature->GetGUID());
                return true;
            }
            // Not active: show message inside gossip
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Hinterland BG is not active.", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, 100);
            SendGossipMenuFor(player, 1, creature->GetGUID());
            return true;
        }
        CloseGossipMenuFor(player);
        return true;
    }
};

void AddSC_hl_scoreboard()
{
    new npc_hl_scoreboard();
}
