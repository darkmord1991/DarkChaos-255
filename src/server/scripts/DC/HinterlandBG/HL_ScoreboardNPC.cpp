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
#include "DatabaseEnv.h"

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

                // Recent history (last 5 winners): prefer DB history, fallback to in-memory
                struct HistRow { TeamId tid; uint32 a; uint32 h; std::string reason; std::string ts; };
                std::vector<HistRow> rows;
                {
                    QueryResult res = CharacterDatabase.Query("SELECT occurred_at, winner_tid, score_alliance, score_horde, win_reason FROM hlbg_winner_history ORDER BY id DESC LIMIT 5");
                    if (res)
                    {
                        do
                        {
                            Field* f = res->Fetch();
                            HistRow r;
                            r.ts = f[0].Get<std::string>();
                            r.tid = static_cast<TeamId>(f[1].Get<uint8>());
                            r.a = f[2].Get<uint32>();
                            r.h = f[3].Get<uint32>();
                            r.reason = f[4].Get<std::string>();
                            rows.push_back(std::move(r));
                        } while (res->NextRow());
                    }
                }
                if (rows.empty())
                {
                    auto recent = hl->GetRecentWinners(5);
                    for (auto const& t : recent)
                        rows.push_back(HistRow{t, 0u, 0u, std::string(), std::string()});
                }
                if (!rows.empty())
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Recent results:", GOSSIP_SENDER_MAIN, 1);
                    uint32 idx = 1;
                    for (auto const& r : rows)
                    {
                        const char* name = (r.tid == TEAM_ALLIANCE ? "Alliance" : (r.tid == TEAM_HORDE ? "Horde" : "Draw"));
                        bool hasTs = !r.ts.empty();
                        if (!r.reason.empty())
                        {
                            if (hasTs)
                                snprintf(line, sizeof(line), "%u) [%s] %s  A:%u H:%u  (%s)", (unsigned)idx++, r.ts.c_str(), name, (unsigned)r.a, (unsigned)r.h, r.reason.c_str());
                            else
                                snprintf(line, sizeof(line), "%u) %s  A:%u H:%u  (%s)", (unsigned)idx++, name, (unsigned)r.a, (unsigned)r.h, r.reason.c_str());
                        }
                        else
                        {
                            if (hasTs)
                                snprintf(line, sizeof(line), "%u) [%s] %s", (unsigned)idx++, r.ts.c_str(), name);
                            else
                                snprintf(line, sizeof(line), "%u) %s", (unsigned)idx++, name);
                        }
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
