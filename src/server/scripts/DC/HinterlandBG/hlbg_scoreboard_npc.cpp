// -----------------------------------------------------------------------------
// hlbg_scoreboard_npc.cpp
// -----------------------------------------------------------------------------
// A simple gossip NPC that shows current/last results for Hinterland BG.
// Place an NPC with this scriptname near each faction base.
// -----------------------------------------------------------------------------
#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "GossipDef.h"
#include "Chat.h"
#include "hlbg.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "hlbg_constants.h"
#include "Timer.h"
#include <algorithm>
#include <cmath>
#include <unordered_map>

// Expose constants at file scope to allow usage inside classes (avoid in-class using namespace)
using namespace HinterlandBGConstants;

// Use centralized utility function
namespace HLBGUtils { OutdoorPvPHL* GetHinterlandBG(); }

static OutdoorPvPHL* GetHL()
{
    return HLBGUtils::GetHinterlandBG();
}

static bool TryConsumeGossipCooldown(Player* player, uint32 cooldownMs)
{
    if (!player)
        return false;

    static std::unordered_map<uint64, uint32> s_lastUseMs;
    uint64 key = player->GetGUID().GetCounter();

    uint32 now = getMSTime();
    auto it = s_lastUseMs.find(key);
    if (it != s_lastUseMs.end())
    {
        if (getMSTimeDiff(it->second, now) < cooldownMs)
            return false;
        it->second = now;
        return true;
    }

    s_lastUseMs.emplace(key, now);
    return true;
}

class npc_hl_scoreboard : public CreatureScript
{
public:
    npc_hl_scoreboard() : CreatureScript("npc_hl_scoreboard") {}

    static std::string MakeLargeGossipText(std::string const& icon, std::string const& text)
    {
        return "|T" + icon + ":40:40:-18|t " + text;
    }

    // Use centralized constants for backwards compatibility
    static const char* AffixName(uint8 a)
    {
        return GetLegacyAffixName(a);
    }

    void ShowHistoryPage(Player* player, Creature* creature, uint32 page)
    {
        using namespace HinterlandBGConstants;
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Recent results:", GOSSIP_SENDER_MAIN, ACTION_HISTORY_PAGE_BASE + page);

        struct HistRow { TeamId tid; uint32 a; uint32 h; std::string reason; std::string ts; uint8 affix; };
        std::vector<HistRow> rows;
        uint32 limit = PAGE_SIZE + 1; // fetch one extra to detect next page
        uint32 offset = page * PAGE_SIZE;

        CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_HLBG_HISTORY_PAGE);
        stmt->SetData(0, limit);
        stmt->SetData(1, offset);
        PreparedQueryResult res = CharacterDatabase.Query(stmt);
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
        using namespace HinterlandBGConstants;
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

    // Note: cond is either "1=1" or a safe constant string - no user input
    std::string query1 = "SELECT SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2), SUM(win_reason='depletion'), SUM(win_reason='tiebreaker'), SUM(win_reason='manual'), COUNT(*) FROM dc_hlbg_winner_history WHERE " + cond;
    QueryResult res = CharacterDatabase.Query(query1);
    if (res)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query winner statistics");
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

        std::string query2 = "SELECT winner_tid FROM dc_hlbg_winner_history WHERE " + cond + " ORDER BY id DESC LIMIT 200";
        QueryResult rs = CharacterDatabase.Query(query2);
        if (rs)
        {
            bool currentActive = true;
            bool currentSeeded = false;

            TeamId runTeam = TEAM_NEUTRAL;
            uint32 runLen = 0;

            do
            {
                Field* f = rs->Fetch();
                TeamId t = static_cast<TeamId>(f[0].Get<uint8>());

                bool isWin = (t == TEAM_ALLIANCE || t == TEAM_HORDE);
                if (!isWin)
                {
                    if (runLen > bestCount)
                    {
                        bestCount = runLen;
                        bestTeam = runTeam;
                    }
                    runTeam = TEAM_NEUTRAL;
                    runLen = 0;

                    if (!currentSeeded)
                    {
                        currCount = 0;
                        currTeam = TEAM_NEUTRAL;
                    }
                    currentActive = false;
                    continue;
                }

                // Current streak (from the newest row)
                if (!currentSeeded)
                {
                    currTeam = t;
                    currCount = 1;
                    currentSeeded = true;
                }
                else if (currentActive)
                {
                    if (t == currTeam)
                        ++currCount;
                    else
                        currentActive = false;
                }

                // Longest streak within the sample
                if (runLen == 0)
                {
                    runTeam = t;
                    runLen = 1;
                }
                else if (t == runTeam)
                {
                    ++runLen;
                }
                else
                {
                    if (runLen > bestCount)
                    {
                        bestCount = runLen;
                        bestTeam = runTeam;
                    }
                    runTeam = t;
                    runLen = 1;
                }
            } while (rs->NextRow());

            if (runLen > bestCount)
            {
                bestCount = runLen;
                bestTeam = runTeam;
            }
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query winning streaks");
        }
        const char* currName = (currTeam == TEAM_ALLIANCE ? "Alliance" : (currTeam == TEAM_HORDE ? "Horde" : "None"));
        const char* bestName = (bestTeam == TEAM_ALLIANCE ? "Alliance" : (bestTeam == TEAM_HORDE ? "Horde" : "None"));
        snprintf(line, sizeof(line), "Current streak: %s x%u", currName, (unsigned)currCount);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
        snprintf(line, sizeof(line), "Longest streak: %s x%u", bestName, (unsigned)bestCount);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);

        // Largest margin win
        std::string query3 = "SELECT occurred_at, winner_tid, score_alliance, score_horde FROM dc_hlbg_winner_history WHERE " + cond + " AND winner_tid IN (0,1) ORDER BY ABS(score_alliance - score_horde) DESC, id DESC LIMIT 1";
        QueryResult rm = CharacterDatabase.Query(query3);
        if (rm)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query largest margin win");
        }

        // Top N most frequent winners by affix (Alliance/Horde only)
        std::string query4 = "SELECT winner_tid, affix, COUNT(*) AS c FROM dc_hlbg_winner_history WHERE " + cond + " AND winner_tid IN (0,1) GROUP BY winner_tid, affix ORDER BY c DESC LIMIT " + std::to_string(TOP_N);
        QueryResult rt = CharacterDatabase.Query(query4);
        if (rt)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query top winners by affix");
        }

        // Draws by affix (separate list for clarity)
        std::string query5 = "SELECT affix, COUNT(*) AS c FROM dc_hlbg_winner_history WHERE " + cond + " AND winner_tid=2 GROUP BY affix ORDER BY c DESC LIMIT " + std::to_string(TOP_N);
        QueryResult rdraw = CharacterDatabase.Query(query5);
        if (rdraw)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query draws by affix");
        }

        // Top N outcomes by affix (includes draws); excludes manual resets
        std::string query6 = "SELECT winner_tid, affix, COUNT(*) AS c FROM dc_hlbg_winner_history WHERE " + cond + " GROUP BY winner_tid, affix ORDER BY c DESC LIMIT " + std::to_string(TOP_N);
        QueryResult rtd = CharacterDatabase.Query(query6);
        if (rtd)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query top outcomes by affix");
        }

        // Top N affixes by overall frequency (any outcome); excludes manual resets
        std::string query7 = "SELECT affix, COUNT(*) AS c FROM dc_hlbg_winner_history WHERE " + cond + " GROUP BY affix ORDER BY c DESC, affix ASC LIMIT " + std::to_string(TOP_N);
        QueryResult raf = CharacterDatabase.Query(query7);
        if (raf)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query top affixes by matches");
        }

        // Average scores per affix (exclude manual resets)
        std::string query8 = "SELECT affix, AVG(score_alliance), AVG(score_horde), COUNT(*) FROM dc_hlbg_winner_history WHERE " + cond + " GROUP BY affix ORDER BY affix";
        QueryResult ra = CharacterDatabase.Query(query8);
        if (ra)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query average scores per affix");
        }

        // Per-affix win rates (Alliance/Horde/Draw percentage); excludes manual resets
        std::string query9 = "SELECT affix, SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2), COUNT(*) FROM dc_hlbg_winner_history WHERE " + cond + " GROUP BY affix ORDER BY affix";
        QueryResult rr = CharacterDatabase.Query(query9);
        if (rr)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query win rates per affix");
        }

        // Per-affix average margin (exclude manual resets)
        std::string query10 = "SELECT affix, AVG(ABS(score_alliance - score_horde)) AS am, COUNT(*) FROM dc_hlbg_winner_history WHERE " + cond + " GROUP BY affix ORDER BY am DESC";
        QueryResult ram = CharacterDatabase.Query(query10);
        if (ram)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query average margin per affix");
        }

        // Per-affix reason breakdown (exclude manual resets)
        std::string query11 = "SELECT affix, SUM(win_reason='depletion'), SUM(win_reason='tiebreaker'), COUNT(*) FROM dc_hlbg_winner_history WHERE " + cond + " GROUP BY affix ORDER BY affix";
        QueryResult rrb = CharacterDatabase.Query(query11);
        if (rrb)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query reason breakdown per affix");
        }

        // Median margin per affix using window functions (guarded by DB capability)
        if (sWindowFns)
        {
            std::string query12 =
                "WITH ranked AS (\n"
                "  SELECT affix, ABS(score_alliance - score_horde) AS m,\n"
                "         ROW_NUMBER() OVER (PARTITION BY affix ORDER BY ABS(score_alliance - score_horde)) AS rn,\n"
                "         COUNT(*)     OVER (PARTITION BY affix) AS cnt\n"
                "  FROM dc_hlbg_winner_history WHERE " + cond + "\n"
                ")\n"
                "SELECT affix, AVG(m) AS med FROM ranked\n"
                "WHERE rn IN (FLOOR((cnt+1)/2), FLOOR((cnt+2)/2))\n"
                "GROUP BY affix ORDER BY med DESC";
            QueryResult rmed = CharacterDatabase.Query(query12);
            if (rmed)
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
            else
            {
                LOG_ERROR("hlbg", "Failed to query median margin per affix");
            }
        }

        // Average duration per affix (if populated)
        std::string query13 = "SELECT affix, AVG(duration_seconds), COUNT(*) FROM dc_hlbg_winner_history WHERE " + cond + " AND duration_seconds > 0 GROUP BY affix ORDER BY affix";
        QueryResult rdur = CharacterDatabase.Query(query13);
        if (rdur)
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
        else
        {
            LOG_ERROR("hlbg", "Failed to query average duration per affix");
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
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            MakeLargeGossipText("Interface\\Icons\\INV_Misc_Map_01", "Show Hinterland BG status"),
            GOSSIP_SENDER_MAIN, ACTION_STATUS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            MakeLargeGossipText("Interface\\Icons\\INV_Misc_Book_09", "Show Hinterland BG history"),
            GOSSIP_SENDER_MAIN, ACTION_HISTORY);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            MakeLargeGossipText("Interface\\Icons\\INV_Misc_Book_11", "Show Hinterland BG statistics"),
            GOSSIP_SENDER_MAIN, ACTION_STATS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            MakeLargeGossipText("Interface\\Icons\\INV_Misc_QuestionMark", "Close"),
            GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        SendGossipMenuFor(player, 1, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        // Throttle DB-heavy gossip actions to avoid spam/DoS.
        // Stats is significantly heavier than history/status.
        if (action != ACTION_CLOSE)
        {
            uint32 cd = (action == ACTION_STATS) ? 5000u : 1500u;
            if (!TryConsumeGossipCooldown(player, cd))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Please wait a moment before using this again.");
                return true;
            }
        }

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
                    QueryResult res = CharacterDatabase.Query("SELECT occurred_at, winner_tid, score_alliance, score_horde, win_reason FROM dc_hlbg_winner_history ORDER BY id DESC LIMIT 5");
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
