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
#include <algorithm>
#include <cmath>

// Use centralized utility function
namespace HLBGUtils { OutdoorPvPHL* GetHinterlandBG(); }

static OutdoorPvPHL* GetHL()
{
    return HLBGUtils::GetHinterlandBG();
}

class npc_hl_scoreboard : public CreatureScript
{
public:
    npc_hl_scoreboard() : CreatureScript("npc_hl_scoreboard") {}

    static constexpr uint32 ACTION_STATUS = 1;
    static constexpr uint32 ACTION_HISTORY = 2; // routes to page 0
    static constexpr uint32 ACTION_STATS = 3;
    static constexpr uint32 ACTION_CLOSE = 100;
    static constexpr uint32 ACTION_HISTORY_PAGE_BASE = 1000; // + page index
    static constexpr uint32 PAGE_SIZE = 5;
    static constexpr uint32 TOP_N = 5; // change this to show more/less entries in top lists

    static const char* AffixName(uint8 a)
    {
        switch (a)
        {
            case 1: return "Haste";
            case 2: return "Slow";
            case 3: return "Reduced Healing";
            case 4: return "Reduced Armor";
            case 5: return "Boss Enrage";
            default: return "None";
        }
    }

    void ShowHistoryPage(Player* player, Creature* creature, uint32 page)
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Recent results:", GOSSIP_SENDER_MAIN, ACTION_HISTORY_PAGE_BASE + page);

        struct HistRow { TeamId tid; uint32 a; uint32 h; std::string reason; std::string ts; uint8 affix; };
        std::vector<HistRow> rows;
        uint32 limit = PAGE_SIZE + 1; // fetch one extra to detect next page
        uint32 offset = page * PAGE_SIZE;
        QueryResult res = CharacterDatabase.Query(
            "SELECT occurred_at, winner_tid, score_alliance, score_horde, win_reason, affix FROM hlbg_winner_history ORDER BY id DESC LIMIT {} OFFSET {}",
            limit, offset);
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
                r.affix = f[5].Get<uint8>();
                rows.push_back(std::move(r));
            } while (res->NextRow());
        }

        char line[200];
        bool hasNext = rows.size() > PAGE_SIZE;
        if (hasNext)
            rows.resize(PAGE_SIZE);

        if (rows.empty())
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "(no history)", GOSSIP_SENDER_MAIN, ACTION_HISTORY_PAGE_BASE + page);
        }
        else
        {
            uint32 idx = 1 + page * PAGE_SIZE;
            for (auto const& r : rows)
            {
                const char* name = (r.tid == TEAM_ALLIANCE ? "Alliance" : (r.tid == TEAM_HORDE ? "Horde" : "Draw"));
                // Optional friendly weather label if affix weather is enabled
                char wbuf[48] = {0};
                if (r.affix > 0)
                {
                    if (OutdoorPvPHL* hlx = GetHL())
                    {
                        if (hlx->IsAffixWeatherEnabled())
                        {
                            uint32 wtype = hlx->GetAffixWeatherType(r.affix);
                            float wint = hlx->GetAffixWeatherIntensity(r.affix);
                            if (wint <= 0.0f) wint = 0.50f;
                            uint32 ipct = (uint32)std::lround(wint * 100.0f);
                            const char* wname = "Fine";
                            switch (wtype) {
                                case 1: wname = "Rain"; break;
                                case 2: wname = "Snow"; break;
                                case 3: wname = "Storm"; break;
                                default: wname = "Fine"; break;
                            }
                            snprintf(wbuf, sizeof(wbuf), ", weather: %s %u%%", wname, (unsigned)ipct);
                        }
                    }
                }
                if (!r.reason.empty())
                    snprintf(line, sizeof(line), "%u) [%s] %s  A:%u H:%u  (%s%s%s%s)", (unsigned)idx++, r.ts.c_str(), name, (unsigned)r.a, (unsigned)r.h,
                        r.reason.c_str(), r.affix ? ", affix: " : "", r.affix ? AffixName(r.affix) : "", wbuf);
                else
                    snprintf(line, sizeof(line), "%u) [%s] %s  A:%u H:%u%s", (unsigned)idx++, r.ts.c_str(), name, (unsigned)r.a, (unsigned)r.h, wbuf);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_HISTORY_PAGE_BASE + page);
            }
        }
        // Navigation
        if (page > 0)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Prev", GOSSIP_SENDER_MAIN, ACTION_HISTORY_PAGE_BASE + (page - 1));
        if (hasNext)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Next", GOSSIP_SENDER_MAIN, ACTION_HISTORY_PAGE_BASE + (page + 1));

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Hinterland BG status", GOSSIP_SENDER_MAIN, ACTION_STATUS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        SendGossipMenuFor(player, 1, creature->GetGUID());
    }

    void ShowStats(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Hinterland BG statistics:", GOSSIP_SENDER_MAIN, ACTION_STATS);

        // Detect (once per call) whether DB supports window functions for median
        static bool sWindowFns = [](){
            bool supported = false;
            if (QueryResult v = CharacterDatabase.Query("SELECT VERSION()"))
            {
                std::string ver = v->Fetch()[0].Get<std::string>();
                // crude check: MySQL 8.x or MariaDB 10.2+
                if (ver.find("MariaDB") != std::string::npos)
                {
                    // find 10.x
                    size_t p = ver.find("10.");
                    if (p != std::string::npos)
                        supported = true; // window functions since 10.2
                }
                else if (!ver.empty() && ver[0] >= '8')
                {
                    supported = true;
                }
            }
            return supported;
        }();

    bool includeManual = true;
    if (OutdoorPvPHL* hl = GetHL()) includeManual = hl->GetStatsIncludeManualResets();
    // Build a generic condition that can be AND-ed with other filters
    // Important: older rows may have NULL win_reason; excluding manual must keep those (use IS NULL OR <> 'manual')
    std::string cond = includeManual ? std::string("1=1") : std::string("(win_reason IS NULL OR win_reason <> 'manual')");
    uint64 aWins = 0, hWins = 0, draws = 0, depWins = 0, tieWins = 0, manual = 0, total = 0;
    if (QueryResult res = CharacterDatabase.Query(
        "SELECT SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2), SUM(win_reason='depletion'), SUM(win_reason='tiebreaker'), SUM(win_reason='manual'), COUNT(*) FROM hlbg_winner_history WHERE {}",
        cond))
        {
            Field* f = res->Fetch();
            aWins = f[0].Get<uint64>();
            hWins = f[1].Get<uint64>();
            draws = f[2].Get<uint64>();
            depWins = f[3].Get<uint64>();
            tieWins = f[4].Get<uint64>();
            manual = f[5].Get<uint64>();
            total = f[6].Get<uint64>();
        }

        uint64 aLoss = hWins; // alliance losses = horde wins
        uint64 hLoss = aWins;

        char line[200];
        snprintf(line, sizeof(line), "Total records: %llu", static_cast<unsigned long long>(total));
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
        snprintf(line, sizeof(line), "Alliance wins: %llu  (losses: %llu)", static_cast<unsigned long long>(aWins), static_cast<unsigned long long>(aLoss));
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
        snprintf(line, sizeof(line), "Horde wins: %llu  (losses: %llu)", static_cast<unsigned long long>(hWins), static_cast<unsigned long long>(hLoss));
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
        snprintf(line, sizeof(line), "Draws: %llu  Manual resets: %llu", static_cast<unsigned long long>(draws), static_cast<unsigned long long>(manual));
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
        snprintf(line, sizeof(line), "Win reasons: depletion %llu, tiebreaker %llu", static_cast<unsigned long long>(depWins), static_cast<unsigned long long>(tieWins));
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);

        // Current and longest winning streaks (based on last 200 rows)
        uint32 currCount = 0; TeamId currTeam = TEAM_NEUTRAL;
        uint32 bestCount = 0; TeamId bestTeam = TEAM_NEUTRAL;
    if (QueryResult rs = CharacterDatabase.Query("SELECT winner_tid FROM hlbg_winner_history WHERE {} ORDER BY id DESC LIMIT 200", cond))
        {
            bool first = true;
            TeamId prev = TEAM_NEUTRAL;
            do {
                Field* f = rs->Fetch();
                TeamId t = static_cast<TeamId>(f[0].Get<uint8>());
                if (t != TEAM_ALLIANCE && t != TEAM_HORDE)
                {
                    // draw/manual: break streak
                    if (first) { currCount = 0; currTeam = TEAM_NEUTRAL; first = false; }
                    prev = TEAM_NEUTRAL; // reset chain for longest
                    continue;
                }
                if (first)
                {
                    currTeam = t; currCount = 1; first = false;
                }
                if (prev == t)
                {
                    // continue longest chain
                    ++currCount;
                }
                else if (prev == TEAM_NEUTRAL)
                {
                    currCount = 1; currTeam = t;
                }
                else
                {
                    // reset streak length for longest tracking
                    if (currCount > bestCount)
                    {
                        bestCount = currCount; bestTeam = prev;
                    }
                    currCount = 1; currTeam = t;
                }
                prev = t;
            } while (rs->NextRow());
            if (currCount > bestCount)
            {
                bestCount = currCount; bestTeam = currTeam;
            }
        }
        const char* currName = (currTeam == TEAM_ALLIANCE ? "Alliance" : (currTeam == TEAM_HORDE ? "Horde" : "None"));
        const char* bestName = (bestTeam == TEAM_ALLIANCE ? "Alliance" : (bestTeam == TEAM_HORDE ? "Horde" : "None"));
        snprintf(line, sizeof(line), "Current streak: %s x%u", currName, (unsigned)currCount);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
        snprintf(line, sizeof(line), "Longest streak: %s x%u", bestName, (unsigned)bestCount);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);

        // Largest margin win
    if (QueryResult rm = CharacterDatabase.Query("SELECT occurred_at, winner_tid, score_alliance, score_horde FROM hlbg_winner_history WHERE {} AND winner_tid IN (0,1) ORDER BY ABS(score_alliance - score_horde) DESC, id DESC LIMIT 1", cond))
        {
            Field* f = rm->Fetch();
            std::string ts = f[0].Get<std::string>();
            TeamId t = static_cast<TeamId>(f[1].Get<uint8>());
            uint32 a = f[2].Get<uint32>();
            uint32 h = f[3].Get<uint32>();
            const char* name = (t == TEAM_ALLIANCE ? "Alliance" : "Horde");
            uint32 margin = (a > h) ? (a - h) : (h - a);
            snprintf(line, sizeof(line), "Largest margin: [%s] %s by %u (A:%u H:%u)", ts.c_str(), name, (unsigned)margin, (unsigned)a, (unsigned)h);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
        }

        // Top N most frequent winners by affix (Alliance/Horde only)
    if (QueryResult rt = CharacterDatabase.Query(
        "SELECT winner_tid, affix, COUNT(*) AS c FROM hlbg_winner_history WHERE {} AND winner_tid IN (0,1) GROUP BY winner_tid, affix ORDER BY c DESC LIMIT {}",
        cond, TOP_N))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Top winners by affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
            do
            {
                Field* f = rt->Fetch();
                uint8 tid = f[0].Get<uint8>();
                uint8 aff = f[1].Get<uint8>();
                uint64 c  = f[2].Get<uint64>();
                const char* wname = (tid == TEAM_ALLIANCE ? "Alliance" : "Horde");
                snprintf(line, sizeof(line), "- %s: %s wins x%llu", AffixName(aff), wname, (unsigned long long)c);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
            } while (rt->NextRow());
        }

        // Draws by affix (separate list for clarity)
    if (QueryResult rdraw = CharacterDatabase.Query(
        "SELECT affix, COUNT(*) AS c FROM hlbg_winner_history WHERE {} AND winner_tid=2 GROUP BY affix ORDER BY c DESC LIMIT {}",
        cond, TOP_N))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Draws by affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
            do
            {
                Field* f = rdraw->Fetch();
                uint8 aff = f[0].Get<uint8>();
                uint64 c  = f[1].Get<uint64>();
                snprintf(line, sizeof(line), "- %s: draws x%llu", AffixName(aff), (unsigned long long)c);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
            } while (rdraw->NextRow());
        }

        // Top N outcomes by affix (includes draws); excludes manual resets
    if (QueryResult rtd = CharacterDatabase.Query(
        "SELECT winner_tid, affix, COUNT(*) AS c FROM hlbg_winner_history WHERE {} GROUP BY winner_tid, affix ORDER BY c DESC LIMIT {}",
        cond, TOP_N))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Top outcomes by affix (incl. draws):", GOSSIP_SENDER_MAIN, ACTION_STATS);
            do
            {
                Field* f = rtd->Fetch();
                uint8 tid = f[0].Get<uint8>();
                uint8 aff = f[1].Get<uint8>();
                uint64 c  = f[2].Get<uint64>();
                const char* oname = (tid == TEAM_ALLIANCE ? "Alliance" : (tid == TEAM_HORDE ? "Horde" : "Draw"));
                snprintf(line, sizeof(line), "- %s: %s x%llu", AffixName(aff), oname, (unsigned long long)c);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
            } while (rtd->NextRow());
        }

        // Top N affixes by overall frequency (any outcome); excludes manual resets
    if (QueryResult raf = CharacterDatabase.Query(
        "SELECT affix, COUNT(*) AS c FROM hlbg_winner_history WHERE {} GROUP BY affix ORDER BY c DESC, affix ASC LIMIT {}",
        cond, TOP_N))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Top affixes by matches:", GOSSIP_SENDER_MAIN, ACTION_STATS);
            do
            {
                Field* f = raf->Fetch();
                uint8 aff = f[0].Get<uint8>();
                uint64 c  = f[1].Get<uint64>();
                snprintf(line, sizeof(line), "- %s: matches x%llu", AffixName(aff), (unsigned long long)c);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
            } while (raf->NextRow());
        }

        // Average scores per affix (exclude manual resets)
    if (QueryResult ra = CharacterDatabase.Query(
        "SELECT affix, AVG(score_alliance), AVG(score_horde), COUNT(*) FROM hlbg_winner_history WHERE {} GROUP BY affix ORDER BY affix",
        cond))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Average score per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
            do
            {
                Field* f = ra->Fetch();
                uint8 aff = f[0].Get<uint8>();
                double avga = f[1].Get<double>();
                double avgh = f[2].Get<double>();
                uint64 n     = f[3].Get<uint64>();
                snprintf(line, sizeof(line), "- %s: A:%.1f H:%.1f (n=%llu)", AffixName(aff), avga, avgh, (unsigned long long)n);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
            } while (ra->NextRow());
        }

        // Per-affix win rates (Alliance/Horde/Draw percentage); excludes manual resets
    if (QueryResult rr = CharacterDatabase.Query(
        "SELECT affix, SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2), COUNT(*) FROM hlbg_winner_history WHERE {} GROUP BY affix ORDER BY affix",
        cond))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Win rates per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
            do
            {
                Field* f = rr->Fetch();
                uint8 aff = f[0].Get<uint8>();
                double a = static_cast<double>(f[1].Get<uint64>());
                double h = static_cast<double>(f[2].Get<uint64>());
                double d = static_cast<double>(f[3].Get<uint64>());
                double n = static_cast<double>(f[4].Get<uint64>());
                if (n < 1.0) continue;
                double ap = (a * 100.0) / n;
                double hp = (h * 100.0) / n;
                double dp = (d * 100.0) / n;
                snprintf(line, sizeof(line), "- %s: A:%.1f%% H:%.1f%% D:%.1f%% (n=%u)", AffixName(aff), ap, hp, dp, (unsigned)n);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
            } while (rr->NextRow());
        }

        // Per-affix average margin (exclude manual resets)
    if (QueryResult ram = CharacterDatabase.Query(
        "SELECT affix, AVG(ABS(score_alliance - score_horde)) AS am, COUNT(*) FROM hlbg_winner_history WHERE {} GROUP BY affix ORDER BY am DESC",
        cond))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Average margin per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
            do
            {
                Field* f = ram->Fetch();
                uint8 aff = f[0].Get<uint8>();
                double avgm = f[1].Get<double>();
                uint64 n    = f[2].Get<uint64>();
                snprintf(line, sizeof(line), "- %s: %.1f (n=%llu)", AffixName(aff), avgm, (unsigned long long)n);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
            } while (ram->NextRow());
        }

        // Per-affix reason breakdown (exclude manual resets)
    if (QueryResult rrb = CharacterDatabase.Query(
        "SELECT affix, SUM(win_reason='depletion'), SUM(win_reason='tiebreaker'), COUNT(*) FROM hlbg_winner_history WHERE {} GROUP BY affix ORDER BY affix",
        cond))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Reason breakdown per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
            do
            {
                Field* f = rrb->Fetch();
                uint8 aff = f[0].Get<uint8>();
                uint64 dep = f[1].Get<uint64>();
                uint64 tie = f[2].Get<uint64>();
                uint64 n   = f[3].Get<uint64>();
                snprintf(line, sizeof(line), "- %s: depletion %llu, tiebreaker %llu (n=%llu)", AffixName(aff), (unsigned long long)dep, (unsigned long long)tie, (unsigned long long)n);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
            } while (rrb->NextRow());
        }

        // Median margin per affix using window functions (guarded by DB capability)
        if (sWindowFns)
        {
            if (QueryResult rmed = CharacterDatabase.Query(
                "WITH ranked AS (\n"
                "  SELECT affix, ABS(score_alliance - score_horde) AS m,\n"
                "         ROW_NUMBER() OVER (PARTITION BY affix ORDER BY ABS(score_alliance - score_horde)) AS rn,\n"
                "         COUNT(*)     OVER (PARTITION BY affix) AS cnt\n"
                "  FROM hlbg_winner_history WHERE {}\n"
                ")\n"
                "SELECT affix, AVG(m) AS med FROM ranked\n"
                "WHERE rn IN (FLOOR((cnt+1)/2), FLOOR((cnt+2)/2))\n"
                "GROUP BY affix ORDER BY med DESC",
                cond))
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Median margin per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
                do
                {
                    Field* f = rmed->Fetch();
                    uint8 aff = f[0].Get<uint8>();
                    double med = f[1].Get<double>();
                    snprintf(line, sizeof(line), "- %s: median %.1f", AffixName(aff), med);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                } while (rmed->NextRow());
            }
        }

        // Average duration per affix (if populated)
    if (QueryResult rdur = CharacterDatabase.Query(
        "SELECT affix, AVG(duration_seconds), COUNT(*) FROM hlbg_winner_history WHERE {} AND duration_seconds > 0 GROUP BY affix ORDER BY affix",
        cond))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Average duration per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
            do
            {
                Field* f = rdur->Fetch();
                uint8 aff = f[0].Get<uint8>();
                double avgd = f[1].Get<double>();
                uint64 n    = f[2].Get<uint64>();
                snprintf(line, sizeof(line), "- %s: %.1f s (n=%llu)", AffixName(aff), avgd, (unsigned long long)n);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
            } while (rdur->NextRow());
        }

        // Navigation
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "History", GOSSIP_SENDER_MAIN, ACTION_HISTORY);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Status", GOSSIP_SENDER_MAIN, ACTION_STATUS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        SendGossipMenuFor(player, 1, creature->GetGUID());
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Hinterland BG status", GOSSIP_SENDER_MAIN, ACTION_STATUS);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Hinterland BG history", GOSSIP_SENDER_MAIN, ACTION_HISTORY);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Hinterland BG statistics", GOSSIP_SENDER_MAIN, ACTION_STATS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        SendGossipMenuFor(player, 1, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (action == ACTION_CLOSE)
        {
            CloseGossipMenuFor(player);
            return true;
        }
        if (action == ACTION_STATUS)
        {
            if (OutdoorPvPHL* hl = GetHL())
            {
                uint32 a = hl->GetResources(TEAM_ALLIANCE);
                uint32 h = hl->GetResources(TEAM_HORDE);
                uint32 sec = hl->GetTimeRemainingSeconds();
                uint32 mm = sec / 60u;
                uint32 ss = sec % 60u;
                uint8 aff = hl->GetActiveAffixCode();
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
                if (aff)
                {
                    snprintf(line, sizeof(line), "Affix: %s", AffixName(aff));
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);
                    // Weather label for the current affix (friendly name + percent)
                    if (OutdoorPvPHL* hlx = GetHL())
                    {
                        if (hlx->IsAffixWeatherEnabled())
                        {
                            uint32 wtype = hlx->GetAffixWeatherType(aff);
                            float wint = hlx->GetAffixWeatherIntensity(aff);
                            if (wint <= 0.0f) wint = 0.50f;
                            const char* wname = "Fine";
                            switch (wtype)
                            {
                                case 1: wname = "Rain"; break;
                                case 2: wname = "Snow"; break;
                                case 3: wname = "Storm"; break;
                                default: wname = "Fine"; break;
                            }
                            uint32 ipct = (uint32)std::lround(wint * 100.0f);
                            snprintf(line, sizeof(line), "Weather: %s (%u%%)", wname, (unsigned)ipct);
                            AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);
                        }
                    }
                }

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
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Refresh", GOSSIP_SENDER_MAIN, ACTION_STATUS);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "History", GOSSIP_SENDER_MAIN, ACTION_HISTORY);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Statistics", GOSSIP_SENDER_MAIN, ACTION_STATS);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
                SendGossipMenuFor(player, 1, creature->GetGUID());
                return true;
            }
            // Not active: show message inside gossip
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Hinterland BG is not active.", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            SendGossipMenuFor(player, 1, creature->GetGUID());
            return true;
        }
        else if (action == ACTION_HISTORY)
        {
            ShowHistoryPage(player, creature, 0);
            return true;
        }
        else if (action == ACTION_STATS)
        {
            ShowStats(player, creature);
            return true;
        }
        else if (action >= ACTION_HISTORY_PAGE_BASE && action < ACTION_HISTORY_PAGE_BASE + 100000)
        {
            uint32 page = action - ACTION_HISTORY_PAGE_BASE;
            ShowHistoryPage(player, creature, page);
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
