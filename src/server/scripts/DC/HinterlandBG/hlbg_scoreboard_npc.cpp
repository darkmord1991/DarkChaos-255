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
#include "BattlegroundHLBG.h"
#include "HLBGService.h"
#include "hlbg.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "hlbg_constants.h"
#include "Timer.h"
#include <algorithm>
#include <cmath>
#include <sstream>
#include <unordered_map>

// Expose constants at file scope to allow usage inside classes (avoid in-class using namespace)
using namespace HinterlandBGConstants;

static BattlegroundHLBG* GetHLBG(Player* preferredPlayer = nullptr)
{
    return HLBGService::Instance().GetActiveBattleground(preferredPlayer);
}

static const char* GetWeatherDisplayName(uint32 weatherType)
{
    switch (weatherType)
    {
        case 1:
            return "Rain";
        case 2:
            return "Snow";
        case 3:
            return "Storm";
        default:
            return "Fine";
    }
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

    // Use the shared affix registry through the centralized HLBG helper.
    static const char* AffixName(uint8 a)
    {
        return GetAffixName(a);
    }

    static std::string BuildAffixDisplay(uint8 affixPrimary,
        uint8 affixSecondary = 0, uint8 affixTertiary = 0)
    {
        std::ostringstream out;
        bool first = true;

        for (uint8 affixCode : { affixPrimary, affixSecondary, affixTertiary })
        {
            if (!affixCode)
                continue;

            if (!first)
                out << ", ";

            first = false;
            out << AffixName(affixCode);
        }

        return first ? std::string("None") : out.str();
    }

    void ShowHistoryPage(Player* player, Creature* creature, uint32 page)
    {
        using namespace HinterlandBGConstants;
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Recent results:", GOSSIP_SENDER_MAIN, ACTION_HISTORY_PAGE_BASE + page);

        struct HistRow { TeamId tid; uint32 a; uint32 h; std::string reason; std::string ts; uint8 affix; uint8 affixSecondary; uint8 affixTertiary; };
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
                r.affixSecondary = f[6].Get<uint8>();
                r.affixTertiary = f[7].Get<uint8>();
                rows.push_back(std::move(r));
            } while (res->NextRow());
        }

        char line[256];
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
                bool hasAffix = r.affix || r.affixSecondary || r.affixTertiary;
                std::string affixDisplay = BuildAffixDisplay(r.affix, r.affixSecondary, r.affixTertiary);
                // Optional friendly weather label if affix weather is enabled
                char wbuf[48] = {0};
                if (r.affix > 0)
                {
                    if (BattlegroundHLBG* hlx = GetHLBG(player))
                    {
                        if (hlx->IsAffixWeatherEnabled())
                        {
                            uint32 wtype = hlx->GetAffixWeatherType(r.affix);
                            float wint = hlx->GetAffixWeatherIntensity(r.affix);
                            if (wint <= 0.0f) wint = 0.50f;
                            uint32 ipct = (uint32)std::lround(wint * 100.0f);
                            const char* wname = GetWeatherDisplayName(wtype);
                            snprintf(wbuf, sizeof(wbuf), ", weather: %s %u%%", wname, (unsigned)ipct);
                        }
                    }
                }
                if (!r.reason.empty())
                    snprintf(line, sizeof(line), "%u) [%s] %s  A:%u H:%u  (%s%s%s%s)", (unsigned)idx++, r.ts.c_str(), name, (unsigned)r.a, (unsigned)r.h,
                        r.reason.c_str(), hasAffix ? ", affixes: " : "", hasAffix ? affixDisplay.c_str() : "", wbuf);
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

        bool includeManual = HLBGService::Instance().GetStatsIncludeManualResets();
        // Build a generic condition that can be AND-ed with other filters
        // Important: older rows may have NULL win_reason; excluding manual must keep those (use IS NULL OR <> 'manual')
        std::string cond = includeManual ? std::string("1=1") : std::string("(win_reason IS NULL OR win_reason <> 'manual')");

        struct AffixAggregate
        {
            uint64 totalCount = 0;
            uint64 allianceWins = 0;
            uint64 hordeWins = 0;
            uint64 draws = 0;
            uint64 depletionCount = 0;
            uint64 tiebreakerCount = 0;
            double allianceScoreTotal = 0.0;
            double hordeScoreTotal = 0.0;
            double marginTotal = 0.0;
            double durationTotal = 0.0;
            uint64 durationCount = 0;
            std::vector<uint32> margins;
        };

        struct OutcomeEntry
        {
            uint8 affix = 0;
            TeamId outcome = TEAM_NEUTRAL;
            uint64 count = 0;
        };

        struct AffixCountEntry
        {
            uint8 affix = 0;
            uint64 count = 0;
        };

        struct AffixValueEntry
        {
            uint8 affix = 0;
            double value = 0.0;
            uint64 count = 0;
        };

        std::string affixStatsQuery =
            "SELECT winner_tid, win_reason, score_alliance, score_horde, duration_seconds, affix AS affix_code "
            "FROM dc_hlbg_winner_history WHERE " + cond + " AND affix > 0 "
            "UNION ALL "
            "SELECT winner_tid, win_reason, score_alliance, score_horde, duration_seconds, affix_secondary AS affix_code "
            "FROM dc_hlbg_winner_history WHERE " + cond + " AND affix_secondary > 0 "
            "UNION ALL "
            "SELECT winner_tid, win_reason, score_alliance, score_horde, duration_seconds, affix_tertiary AS affix_code "
            "FROM dc_hlbg_winner_history WHERE " + cond + " AND affix_tertiary > 0";
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

        char line[256];
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

        QueryResult rAffixStats = CharacterDatabase.Query(affixStatsQuery);
        if (rAffixStats)
        {
            std::unordered_map<uint8, AffixAggregate> affixStats;
            do
            {
                Field* f = rAffixStats->Fetch();
                TeamId outcome = static_cast<TeamId>(f[0].Get<uint8>());
                std::string reason = f[1].Get<std::string>();
                uint32 allianceScore = f[2].Get<uint32>();
                uint32 hordeScore = f[3].Get<uint32>();
                uint32 durationSeconds = f[4].Get<uint32>();
                uint8 affix = f[5].Get<uint8>();
                if (!affix)
                    continue;

                AffixAggregate& stats = affixStats[affix];
                ++stats.totalCount;
                stats.allianceScoreTotal += static_cast<double>(allianceScore);
                stats.hordeScoreTotal += static_cast<double>(hordeScore);

                uint32 margin = allianceScore > hordeScore ? (allianceScore - hordeScore) : (hordeScore - allianceScore);
                stats.marginTotal += static_cast<double>(margin);
                stats.margins.push_back(margin);

                if (durationSeconds > 0)
                {
                    stats.durationTotal += static_cast<double>(durationSeconds);
                    ++stats.durationCount;
                }

                if (outcome == TEAM_ALLIANCE)
                    ++stats.allianceWins;
                else if (outcome == TEAM_HORDE)
                    ++stats.hordeWins;
                else if (outcome == TEAM_NEUTRAL)
                    ++stats.draws;

                if (reason == "depletion")
                    ++stats.depletionCount;
                else if (reason == "tiebreaker")
                    ++stats.tiebreakerCount;
            } while (rAffixStats->NextRow());

            std::vector<uint8> orderedAffixes;
            orderedAffixes.reserve(affixStats.size());
            for (auto const& affixEntry : affixStats)
                orderedAffixes.push_back(affixEntry.first);

            std::sort(orderedAffixes.begin(), orderedAffixes.end());

            auto outcomeLabel = [](TeamId outcome) -> char const*
            {
                return outcome == TEAM_ALLIANCE ? "Alliance"
                    : (outcome == TEAM_HORDE ? "Horde" : "Draw");
            };

            std::vector<OutcomeEntry> topWinnerEntries;
            topWinnerEntries.reserve(orderedAffixes.size() * 2u);
            for (uint8 affix : orderedAffixes)
            {
                AffixAggregate const& stats = affixStats.at(affix);
                if (stats.allianceWins > 0)
                    topWinnerEntries.push_back({ affix, TEAM_ALLIANCE, stats.allianceWins });
                if (stats.hordeWins > 0)
                    topWinnerEntries.push_back({ affix, TEAM_HORDE, stats.hordeWins });
            }

            std::sort(topWinnerEntries.begin(), topWinnerEntries.end(), [](OutcomeEntry const& left, OutcomeEntry const& right)
            {
                if (left.count != right.count)
                    return left.count > right.count;
                if (left.affix != right.affix)
                    return left.affix < right.affix;
                return left.outcome < right.outcome;
            });

            if (!topWinnerEntries.empty())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Top winners by affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
                std::size_t limit = std::min<std::size_t>(static_cast<std::size_t>(TOP_N), topWinnerEntries.size());
                for (std::size_t index = 0; index < limit; ++index)
                {
                    OutcomeEntry const& entry = topWinnerEntries[index];
                    snprintf(line, sizeof(line), "- %s: %s wins x%llu", AffixName(entry.affix), outcomeLabel(entry.outcome), static_cast<unsigned long long>(entry.count));
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                }
            }

            std::vector<AffixCountEntry> drawEntries;
            drawEntries.reserve(orderedAffixes.size());
            for (uint8 affix : orderedAffixes)
            {
                AffixAggregate const& stats = affixStats.at(affix);
                if (stats.draws > 0)
                    drawEntries.push_back({ affix, stats.draws });
            }

            std::sort(drawEntries.begin(), drawEntries.end(), [](AffixCountEntry const& left, AffixCountEntry const& right)
            {
                if (left.count != right.count)
                    return left.count > right.count;
                return left.affix < right.affix;
            });

            if (!drawEntries.empty())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Draws by affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
                std::size_t limit = std::min<std::size_t>(static_cast<std::size_t>(TOP_N), drawEntries.size());
                for (std::size_t index = 0; index < limit; ++index)
                {
                    AffixCountEntry const& entry = drawEntries[index];
                    snprintf(line, sizeof(line), "- %s: draws x%llu", AffixName(entry.affix), static_cast<unsigned long long>(entry.count));
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                }
            }

            std::vector<OutcomeEntry> topOutcomeEntries;
            topOutcomeEntries.reserve(orderedAffixes.size() * 3u);
            for (uint8 affix : orderedAffixes)
            {
                AffixAggregate const& stats = affixStats.at(affix);
                if (stats.allianceWins > 0)
                    topOutcomeEntries.push_back({ affix, TEAM_ALLIANCE, stats.allianceWins });
                if (stats.hordeWins > 0)
                    topOutcomeEntries.push_back({ affix, TEAM_HORDE, stats.hordeWins });
                if (stats.draws > 0)
                    topOutcomeEntries.push_back({ affix, TEAM_NEUTRAL, stats.draws });
            }

            std::sort(topOutcomeEntries.begin(), topOutcomeEntries.end(), [](OutcomeEntry const& left, OutcomeEntry const& right)
            {
                if (left.count != right.count)
                    return left.count > right.count;
                if (left.affix != right.affix)
                    return left.affix < right.affix;
                return left.outcome < right.outcome;
            });

            if (!topOutcomeEntries.empty())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Top outcomes by affix (incl. draws):", GOSSIP_SENDER_MAIN, ACTION_STATS);
                std::size_t limit = std::min<std::size_t>(static_cast<std::size_t>(TOP_N), topOutcomeEntries.size());
                for (std::size_t index = 0; index < limit; ++index)
                {
                    OutcomeEntry const& entry = topOutcomeEntries[index];
                    snprintf(line, sizeof(line), "- %s: %s x%llu", AffixName(entry.affix), outcomeLabel(entry.outcome), static_cast<unsigned long long>(entry.count));
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                }
            }

            std::vector<AffixCountEntry> topAffixEntries;
            topAffixEntries.reserve(orderedAffixes.size());
            for (uint8 affix : orderedAffixes)
                topAffixEntries.push_back({ affix, affixStats.at(affix).totalCount });

            std::sort(topAffixEntries.begin(), topAffixEntries.end(), [](AffixCountEntry const& left, AffixCountEntry const& right)
            {
                if (left.count != right.count)
                    return left.count > right.count;
                return left.affix < right.affix;
            });

            if (!topAffixEntries.empty())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Top affixes by matches:", GOSSIP_SENDER_MAIN, ACTION_STATS);
                std::size_t limit = std::min<std::size_t>(static_cast<std::size_t>(TOP_N), topAffixEntries.size());
                for (std::size_t index = 0; index < limit; ++index)
                {
                    AffixCountEntry const& entry = topAffixEntries[index];
                    snprintf(line, sizeof(line), "- %s: matches x%llu", AffixName(entry.affix), static_cast<unsigned long long>(entry.count));
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                }
            }

            if (!orderedAffixes.empty())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Average score per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
                for (uint8 affix : orderedAffixes)
                {
                    AffixAggregate const& stats = affixStats.at(affix);
                    double averageAlliance = stats.allianceScoreTotal / static_cast<double>(stats.totalCount);
                    double averageHorde = stats.hordeScoreTotal / static_cast<double>(stats.totalCount);
                    snprintf(line, sizeof(line), "- %s: A:%.1f H:%.1f (n=%llu)", AffixName(affix), averageAlliance, averageHorde, static_cast<unsigned long long>(stats.totalCount));
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                }

                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Win rates per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
                for (uint8 affix : orderedAffixes)
                {
                    AffixAggregate const& stats = affixStats.at(affix);
                    double totalMatches = static_cast<double>(stats.totalCount);
                    double alliancePct = (static_cast<double>(stats.allianceWins) * 100.0) / totalMatches;
                    double hordePct = (static_cast<double>(stats.hordeWins) * 100.0) / totalMatches;
                    double drawPct = (static_cast<double>(stats.draws) * 100.0) / totalMatches;
                    snprintf(line, sizeof(line), "- %s: A:%.1f%% H:%.1f%% D:%.1f%% (n=%llu)", AffixName(affix), alliancePct, hordePct, drawPct, static_cast<unsigned long long>(stats.totalCount));
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                }
            }

            std::vector<AffixValueEntry> averageMarginEntries;
            averageMarginEntries.reserve(orderedAffixes.size());
            for (uint8 affix : orderedAffixes)
            {
                AffixAggregate const& stats = affixStats.at(affix);
                averageMarginEntries.push_back({ affix, stats.marginTotal / static_cast<double>(stats.totalCount), stats.totalCount });
            }

            std::sort(averageMarginEntries.begin(), averageMarginEntries.end(), [](AffixValueEntry const& left, AffixValueEntry const& right)
            {
                if (left.value != right.value)
                    return left.value > right.value;
                return left.affix < right.affix;
            });

            if (!averageMarginEntries.empty())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Average margin per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
                for (AffixValueEntry const& entry : averageMarginEntries)
                {
                    snprintf(line, sizeof(line), "- %s: %.1f (n=%llu)", AffixName(entry.affix), entry.value, static_cast<unsigned long long>(entry.count));
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                }
            }

            if (!orderedAffixes.empty())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Reason breakdown per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
                for (uint8 affix : orderedAffixes)
                {
                    AffixAggregate const& stats = affixStats.at(affix);
                    snprintf(line, sizeof(line), "- %s: depletion %llu, tiebreaker %llu (n=%llu)", AffixName(affix), static_cast<unsigned long long>(stats.depletionCount), static_cast<unsigned long long>(stats.tiebreakerCount), static_cast<unsigned long long>(stats.totalCount));
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                }
            }

            std::vector<AffixValueEntry> medianEntries;
            medianEntries.reserve(orderedAffixes.size());
            for (uint8 affix : orderedAffixes)
            {
                AffixAggregate const& stats = affixStats.at(affix);
                std::vector<uint32> sortedMargins = stats.margins;
                std::sort(sortedMargins.begin(), sortedMargins.end());

                std::size_t middle = sortedMargins.size() / 2u;
                double median = sortedMargins.size() % 2u == 0u
                    ? (static_cast<double>(sortedMargins[middle - 1u]) + static_cast<double>(sortedMargins[middle])) / 2.0
                    : static_cast<double>(sortedMargins[middle]);
                medianEntries.push_back({ affix, median, static_cast<uint64>(sortedMargins.size()) });
            }

            std::sort(medianEntries.begin(), medianEntries.end(), [](AffixValueEntry const& left, AffixValueEntry const& right)
            {
                if (left.value != right.value)
                    return left.value > right.value;
                return left.affix < right.affix;
            });

            if (!medianEntries.empty())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Median margin per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
                for (AffixValueEntry const& entry : medianEntries)
                {
                    snprintf(line, sizeof(line), "- %s: median %.1f", AffixName(entry.affix), entry.value);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                }
            }

            std::vector<AffixValueEntry> durationEntries;
            durationEntries.reserve(orderedAffixes.size());
            for (uint8 affix : orderedAffixes)
            {
                AffixAggregate const& stats = affixStats.at(affix);
                if (stats.durationCount == 0)
                    continue;

                durationEntries.push_back({ affix, stats.durationTotal / static_cast<double>(stats.durationCount), stats.durationCount });
            }

            if (!durationEntries.empty())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Average duration per affix:", GOSSIP_SENDER_MAIN, ACTION_STATS);
                for (AffixValueEntry const& entry : durationEntries)
                {
                    snprintf(line, sizeof(line), "- %s: %.1f s (n=%llu)", AffixName(entry.affix), entry.value, static_cast<unsigned long long>(entry.count));
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, ACTION_STATS);
                }
            }
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
            if (BattlegroundHLBG* hl = GetHLBG(player))
            {
                uint32 a = hl->GetResources(TEAM_ALLIANCE);
                uint32 h = hl->GetResources(TEAM_HORDE);
                uint32 sec = hl->GetTimeRemainingSeconds();
                uint32 mm = sec / 60u;
                uint32 ss = sec % 60u;
                uint8 aff = hl->GetActiveAffixCode();
                std::string affixDisplay = BuildAffixDisplay(
                    hl->GetActiveAffixCode(0u), hl->GetActiveAffixCode(1u), hl->GetActiveAffixCode(2u));
                uint32 aCount = 0, hCount = 0;
                for (auto const& playerEntry : hl->GetPlayers())
                {
                    Player* member = playerEntry.second;
                    if (!member || !member->IsInWorld())
                        continue;

                    if (member->GetBgTeamId() == TEAM_ALLIANCE)
                        ++aCount;
                    else if (member->GetBgTeamId() == TEAM_HORDE)
                        ++hCount;
                }

                ClearGossipMenuFor(player);
                // Header (non-interactive info lines)
                char line[256];
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
                    snprintf(line, sizeof(line), "Affixes: %s", affixDisplay.c_str());
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);
                    // Weather label for the current affix (friendly name + percent)
                    if (hl->IsAffixWeatherEnabled())
                    {
                        uint32 wtype = hl->GetAffixWeatherType(aff);
                        float wint = hl->GetAffixWeatherIntensity(aff);
                        if (wint <= 0.0f) wint = 0.50f;
                        uint32 ipct = (uint32)std::lround(wint * 100.0f);
                        snprintf(line, sizeof(line), "Weather: %s (%u%%)", GetWeatherDisplayName(wtype), (unsigned)ipct);
                        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);
                    }
                }

                // Recent history (last 5 winners): prefer DB history, fallback to in-memory
                struct HistRow { TeamId tid; uint32 a; uint32 h; std::string reason; std::string ts; uint8 affix; uint8 affixSecondary; uint8 affixTertiary; };
                std::vector<HistRow> rows;
                {
                    QueryResult res = CharacterDatabase.Query("SELECT occurred_at, winner_tid, score_alliance, score_horde, win_reason, affix, affix_secondary, affix_tertiary FROM dc_hlbg_winner_history ORDER BY id DESC LIMIT 5");
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
                            r.affixSecondary = f[6].Get<uint8>();
                            r.affixTertiary = f[7].Get<uint8>();
                            rows.push_back(std::move(r));
                        } while (res->NextRow());
                    }
                }
                if (rows.empty())
                {
                    auto recent = HLBGService::Instance().GetRecentWinners(5);
                    for (auto const& t : recent)
                        rows.push_back(HistRow{t, 0u, 0u, std::string(), std::string(), 0u, 0u, 0u});
                }
                if (!rows.empty())
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Recent results:", GOSSIP_SENDER_MAIN, 1);
                    uint32 idx = 1;
                    for (auto const& r : rows)
                    {
                        const char* name = (r.tid == TEAM_ALLIANCE ? "Alliance" : (r.tid == TEAM_HORDE ? "Horde" : "Draw"));
                        bool hasTs = !r.ts.empty();
                        bool hasAffix = r.affix || r.affixSecondary || r.affixTertiary;
                        std::string recentAffixDisplay = BuildAffixDisplay(r.affix, r.affixSecondary, r.affixTertiary);
                        if (!r.reason.empty())
                        {
                            if (hasTs)
                                snprintf(line, sizeof(line), "%u) [%s] %s  A:%u H:%u  (%s%s%s)", (unsigned)idx++, r.ts.c_str(), name, (unsigned)r.a, (unsigned)r.h, r.reason.c_str(), hasAffix ? ", affixes: " : "", hasAffix ? recentAffixDisplay.c_str() : "");
                            else
                                snprintf(line, sizeof(line), "%u) %s  A:%u H:%u  (%s%s%s)", (unsigned)idx++, name, (unsigned)r.a, (unsigned)r.h, r.reason.c_str(), hasAffix ? ", affixes: " : "", hasAffix ? recentAffixDisplay.c_str() : "");
                        }
                        else
                        {
                            if (hasTs)
                                snprintf(line, sizeof(line), "%u) [%s] %s%s%s%s", (unsigned)idx++, r.ts.c_str(), name, hasAffix ? "  (affixes: " : "", hasAffix ? recentAffixDisplay.c_str() : "", hasAffix ? ")" : "");
                            else
                                snprintf(line, sizeof(line), "%u) %s%s%s%s", (unsigned)idx++, name, hasAffix ? "  (affixes: " : "", hasAffix ? recentAffixDisplay.c_str() : "", hasAffix ? ")" : "");
                        }
                        AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 1);
                    }
                }
                else
                {
                    // Fallback to last persisted winner if any; helps after server restarts
                    TeamId last = HLBGService::Instance().GetLastWinnerTeamId();
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
