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
#include "StringFormat.h"
#include "Timer.h"
#include <algorithm>
#include <cmath>
#include <string>
#include <unordered_map>
#include <vector>
#include "DC/CrossSystem/CrossSystemCommon.h"

// Expose constants at file scope to allow usage inside classes (avoid in-class using namespace)
using namespace HinterlandBGConstants;

namespace
{
    // Statistics are aggregated from the most recent rows only. An unbounded
    // scan grows with the history table and runs on the world thread.
    constexpr uint32 HLBG_STATS_SAMPLE_ROWS = 500;

    // Navigation footers reserved per page (see HLBGGossipPage).
    constexpr std::size_t HLBG_NAV_SLOTS_STATS = 4;   // History, Status, Close, (+truncation notice)
    constexpr std::size_t HLBG_NAV_SLOTS_HISTORY = 5; // Prev, Next, Status, Close, (+notice)
    constexpr std::size_t HLBG_NAV_SLOTS_STATUS = 5;  // Refresh, History, Statistics, Close, (+notice)

    // GossipMenu::AddMenuItem asserts once a menu exceeds GOSSIP_MAX_MENU_ITEMS,
    // and AzerothCore's ASSERT aborts the worldserver in release builds. Every
    // page built here therefore goes through a budget that reserves room for its
    // navigation footer and drops surplus content lines instead of overflowing.
    class HLBGGossipPage
    {
    public:
        HLBGGossipPage(Player* player, std::size_t navReserve)
            : _player(player), _budget(0)
        {
            constexpr std::size_t maxItems = static_cast<std::size_t>(GOSSIP_MAX_MENU_ITEMS);
            _budget = maxItems > navReserve ? maxItems - navReserve : 0u;
        }

        bool AddLine(std::string const& text, uint32 action)
        {
            if (_used >= _budget)
            {
                _truncated = true;
                return false;
            }

            AddGossipItemFor(_player, GOSSIP_ICON_CHAT, text, GOSSIP_SENDER_MAIN, action);
            ++_used;
            return true;
        }

        // Footer entries draw from the reserved slots and are never dropped.
        void AddNav(std::string const& text, uint32 action)
        {
            AddGossipItemFor(_player, GOSSIP_ICON_CHAT, text, GOSSIP_SENDER_MAIN, action);
        }

        [[nodiscard]] bool IsFull() const { return _used >= _budget; }
        [[nodiscard]] bool WasTruncated() const { return _truncated; }

    private:
        Player* _player;
        std::size_t _budget;
        std::size_t _used = 0;
        bool _truncated = false;
    };

    BattlegroundHLBG* GetHLBG(Player* preferredPlayer = nullptr)
    {
        return HLBGService::Instance().GetActiveBattleground(preferredPlayer);
    }

    char const* GetWeatherDisplayName(uint32 weatherType)
    {
        // Delegate to the canonical table in hlbg_constants.h; this call site's
        // out-of-range values default to "Fine" instead of "Unknown".
        return GetWeatherName(weatherType, "Fine");
    }

    bool TryConsumeGossipCooldown(Player* player, uint32 cooldownMs)
    {
        if (!player)
            return false;

        static std::unordered_map<uint32, uint32> s_lastUseMs;
        uint32 key = player->GetGUID().GetCounter();
        uint32 now = getMSTime();

        // The map is keyed by every player who ever used the NPC, so evict
        // stale entries rather than growing for the lifetime of the process.
        if (s_lastUseMs.size() > 512)
        {
            for (auto itr = s_lastUseMs.begin(); itr != s_lastUseMs.end(); )
            {
                if (getMSTimeDiff(itr->second, now) > 5 * MINUTE * IN_MILLISECONDS)
                    itr = s_lastUseMs.erase(itr);
                else
                    ++itr;
            }
        }

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
}

class npc_hl_scoreboard : public CreatureScript
{
public:
    npc_hl_scoreboard() : CreatureScript("npc_hl_scoreboard") {}

    // Affix display names come from the shared registry in hlbg_constants.h.
    static std::string BuildAffixDisplay(uint8 affixPrimary,
        uint8 affixSecondary = 0, uint8 affixTertiary = 0)
    {
        std::string out;

        for (uint8 affixCode : { affixPrimary, affixSecondary, affixTertiary })
        {
            if (!affixCode)
                continue;

            if (!out.empty())
                out += ", ";

            out += GetAffixName(affixCode);
        }

        return out.empty() ? std::string("None") : out;
    }

    struct HistRow
    {
        TeamId tid = TEAM_NEUTRAL;
        uint32 a = 0;
        uint32 h = 0;
        std::string reason;
        std::string ts;
        uint8 affix = 0;
        uint8 affixSecondary = 0;
        uint8 affixTertiary = 0;
    };

    // Shared by the history page and the status page's "recent results" block.
    static std::vector<HistRow> FetchHistoryRows(uint32 limit, uint32 offset)
    {
        std::vector<HistRow> rows;

        CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_HLBG_HISTORY_PAGE);
        stmt->SetData(0, limit);
        stmt->SetData(1, offset);
        PreparedQueryResult res = CharacterDatabase.Query(stmt);
        if (!res)
            return rows;

        rows.reserve(limit);
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

        return rows;
    }

    // "Rain 60%" for the row's primary affix, empty when weather is off.
    static std::string FormatAffixWeather(BattlegroundHLBG const* hlbg, uint8 affixCode)
    {
        if (!hlbg || !affixCode || !hlbg->IsAffixWeatherEnabled())
            return {};

        float intensity = hlbg->GetAffixWeatherIntensity(affixCode);
        if (intensity <= 0.0f)
            intensity = 0.50f;

        return Acore::StringFormat("{} {}%",
            GetWeatherDisplayName(hlbg->GetAffixWeatherType(affixCode)),
            static_cast<uint32>(std::lround(intensity * 100.0f)));
    }

    // Renders "1) [ts] Alliance  A:x H:y  (reason, affixes: ..., weather: ...)".
    // Timestamp, reason, affixes and weather are all optional.
    static std::string FormatHistoryLine(uint32 index, HistRow const& row, std::string const& weather)
    {
        std::string detail;
        auto appendDetail = [&detail](std::string const& part)
        {
            if (part.empty())
                return;

            if (!detail.empty())
                detail += ", ";

            detail += part;
        };

        appendDetail(row.reason);
        if (row.affix || row.affixSecondary || row.affixTertiary)
            appendDetail("affixes: " + BuildAffixDisplay(row.affix, row.affixSecondary, row.affixTertiary));
        if (!weather.empty())
            appendDetail("weather: " + weather);

        return Acore::StringFormat("{}) {}{}  A:{} H:{}{}", index,
            row.ts.empty() ? std::string() : Acore::StringFormat("[{}] ", row.ts),
            GetTeamName(static_cast<uint8>(row.tid)), row.a, row.h,
            detail.empty() ? std::string() : "  (" + detail + ")");
    }

    void ShowHistoryPage(Player* player, Creature* creature, uint32 page)
    {
        ClearGossipMenuFor(player);

        HLBGGossipPage menu(player, HLBG_NAV_SLOTS_HISTORY);
        menu.AddLine("Recent results:", ACTION_HISTORY_PAGE_BASE + page);

        // One extra row detects whether a next page exists.
        std::vector<HistRow> rows = FetchHistoryRows(PAGE_SIZE + 1, page * PAGE_SIZE);

        bool hasNext = rows.size() > PAGE_SIZE;
        if (hasNext)
            rows.resize(PAGE_SIZE);

        if (rows.empty())
        {
            menu.AddLine("(no history)", ACTION_HISTORY_PAGE_BASE + page);
        }
        else
        {
            // Resolved once - the weather labels only read the affix tables,
            // which are identical for every row.
            BattlegroundHLBG const* hlbg = GetHLBG(player);

            uint32 idx = 1 + page * PAGE_SIZE;
            for (auto const& r : rows)
            {
                if (!menu.AddLine(FormatHistoryLine(idx++, r, FormatAffixWeather(hlbg, r.affix)),
                    ACTION_HISTORY_PAGE_BASE + page))
                {
                    break;
                }
            }
        }

        // Navigation
        if (page > 0)
            menu.AddNav("Prev", ACTION_HISTORY_PAGE_BASE + (page - 1));
        if (hasNext)
            menu.AddNav("Next", ACTION_HISTORY_PAGE_BASE + (page + 1));

        menu.AddNav("Show Hinterland BG status", ACTION_STATUS);
        menu.AddNav("Close", ACTION_CLOSE);
        SendGossipMenuFor(player, 1, creature->GetGUID());
    }

    // -------------------------------------------------------------------------
    // Status page
    // -------------------------------------------------------------------------
    void ShowStatus(Player* player, Creature* creature)
    {
        BattlegroundHLBG const* hlbg = GetHLBG(player);

        ClearGossipMenuFor(player);

        if (!hlbg)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Hinterland BG is not active.", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            SendGossipMenuFor(player, 1, creature->GetGUID());
            return;
        }

        HLBGGossipPage menu(player, HLBG_NAV_SLOTS_STATUS);

        uint32 allianceCount = 0;
        uint32 hordeCount = 0;
        for (auto const& playerEntry : hlbg->GetPlayers())
        {
            Player* member = playerEntry.second;
            if (!member || !member->IsInWorld())
                continue;

            if (member->GetBgTeamId() == TEAM_ALLIANCE)
                ++allianceCount;
            else if (member->GetBgTeamId() == TEAM_HORDE)
                ++hordeCount;
        }

        uint32 remaining = hlbg->GetTimeRemainingSeconds();

        // Info lines are non-interactive: they all re-open this page.
        menu.AddLine(Acore::StringFormat("Alliance: {}", hlbg->GetResources(TEAM_ALLIANCE)), ACTION_STATUS);
        menu.AddLine(Acore::StringFormat("Horde: {}", hlbg->GetResources(TEAM_HORDE)), ACTION_STATUS);
        menu.AddLine(Acore::StringFormat("Time left: {:02}:{:02}", remaining / 60u, remaining % 60u), ACTION_STATUS);
        menu.AddLine(Acore::StringFormat("Players - A:{}  H:{}", allianceCount, hordeCount), ACTION_STATUS);

        uint8 primaryAffix = hlbg->GetActiveAffixCode();
        if (primaryAffix)
        {
            menu.AddLine("Affixes: " + BuildAffixDisplay(hlbg->GetActiveAffixCode(0u),
                hlbg->GetActiveAffixCode(1u), hlbg->GetActiveAffixCode(2u)), ACTION_STATUS);

            std::string weather = FormatAffixWeather(hlbg, primaryAffix);
            if (!weather.empty())
                menu.AddLine("Weather: " + weather, ACTION_STATUS);
        }

        // Recent history: prefer the persisted rows, fall back to the in-memory
        // ring so the page stays useful before the first flush after a restart.
        std::vector<HistRow> rows = FetchHistoryRows(TOP_N, 0);
        if (rows.empty())
        {
            for (TeamId winner : HLBGService::Instance().GetRecentWinners(TOP_N))
            {
                HistRow row;
                row.tid = winner;
                rows.push_back(std::move(row));
            }
        }

        if (rows.empty())
        {
            menu.AddLine("No results yet.", ACTION_STATUS);
        }
        else
        {
            menu.AddLine("Recent results:", ACTION_STATUS);

            uint32 idx = 1;
            for (auto const& row : rows)
            {
                if (!menu.AddLine(FormatHistoryLine(idx++, row, FormatAffixWeather(hlbg, row.affix)), ACTION_STATUS))
                    break;
            }
        }

        menu.AddNav("Refresh", ACTION_STATUS);
        menu.AddNav("History", ACTION_HISTORY);
        menu.AddNav("Statistics", ACTION_STATS);
        menu.AddNav("Close", ACTION_CLOSE);
        SendGossipMenuFor(player, 1, creature->GetGUID());
    }

    // -------------------------------------------------------------------------
    // Statistics page
    // -------------------------------------------------------------------------
    // The rendered lines are cached process-wide for CACHE_DURATION_MS: the page
    // is identical for every viewer, and rebuilding it costs two synchronous
    // queries on the world thread.
    struct StatsCacheEntry
    {
        std::vector<std::string> lines;
        uint32 builtAtMs = 0;
        bool valid = false;
    };

    static std::vector<std::string> const& GetCachedStatsLines(bool includeManual)
    {
        // Separate slots so toggling HinterlandBG.Stats.IncludeManual does not
        // serve the other variant's cached text.
        static StatsCacheEntry s_cache[2];
        StatsCacheEntry& cache = s_cache[includeManual ? 1 : 0];

        uint32 now = getMSTime();
        if (cache.valid && getMSTimeDiff(cache.builtAtMs, now) < CACHE_DURATION_MS)
            return cache.lines;

        cache.lines = BuildStatsLines(includeManual);
        cache.builtAtMs = now;
        cache.valid = true;
        return cache.lines;
    }

    static std::string FormatDuration(double seconds)
    {
        uint32 total = seconds > 0.0 ? static_cast<uint32>(std::lround(seconds)) : 0u;
        return Acore::StringFormat("{:02}:{:02}", total / 60u, total % 60u);
    }

    static std::vector<std::string> BuildStatsLines(bool includeManual)
    {
        std::vector<std::string> lines;

        // Both filters are compile-time constants - no user input reaches SQL.
        // Older rows may carry a NULL win_reason; excluding manual resets must
        // keep those, hence the explicit IS NULL branch.
        std::string const cond = includeManual
            ? std::string("1=1")
            : std::string("(win_reason IS NULL OR win_reason <> 'manual')");

        // ---- Lifetime totals -------------------------------------------------
        uint64 allianceWins = 0, hordeWins = 0, draws = 0;
        uint64 depletionWins = 0, tiebreakerWins = 0, manualResets = 0, total = 0;

        QueryResult totals = CharacterDatabase.Query(
            "SELECT SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2), "
            "SUM(win_reason='depletion'), SUM(win_reason='tiebreaker'), SUM(win_reason='manual'), "
            "COUNT(*) FROM dc_hlbg_winner_history WHERE " + cond);
        if (totals)
        {
            Field* f = totals->Fetch();
            allianceWins = f[0].Get<uint64>();
            hordeWins = f[1].Get<uint64>();
            draws = f[2].Get<uint64>();
            depletionWins = f[3].Get<uint64>();
            tiebreakerWins = f[4].Get<uint64>();
            manualResets = f[5].Get<uint64>();
            total = f[6].Get<uint64>();
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query HLBG winner statistics");
        }

        lines.push_back(Acore::StringFormat("Total records: {}", total));
        lines.push_back(Acore::StringFormat("Alliance wins: {}  (losses: {})", allianceWins, hordeWins));
        lines.push_back(Acore::StringFormat("Horde wins: {}  (losses: {})", hordeWins, allianceWins));
        lines.push_back(Acore::StringFormat("Draws: {}  Manual resets: {}", draws, manualResets));
        lines.push_back(Acore::StringFormat("Win reasons: depletion {}, tiebreaker {}", depletionWins, tiebreakerWins));

        // ---- Bounded recent sample ------------------------------------------
        // Streaks, the largest margin and every per-affix aggregate come from
        // this single pass. The previous implementation ran one query per block,
        // including a three-way UNION ALL that scanned the whole table thrice.
        struct AffixAggregate
        {
            uint64 matches = 0;
            uint64 allianceWins = 0;
            uint64 hordeWins = 0;
            uint64 draws = 0;
            uint64 depletion = 0;
            uint64 tiebreaker = 0;
            double marginTotal = 0.0;
            double durationTotal = 0.0;
            uint64 durationCount = 0;
            std::vector<uint32> margins;
        };

        std::unordered_map<uint8, AffixAggregate> affixStats;

        uint32 currentStreak = 0;
        TeamId currentTeam = TEAM_NEUTRAL;
        uint32 bestStreak = 0;
        TeamId bestTeam = TEAM_NEUTRAL;

        uint32 largestMargin = 0;
        bool hasLargestMargin = false;
        TeamId largestMarginTeam = TEAM_NEUTRAL;
        uint32 largestMarginAlliance = 0;
        uint32 largestMarginHorde = 0;
        std::string largestMarginTs;

        uint32 sampleRows = 0;

        QueryResult sample = CharacterDatabase.Query(
            "SELECT occurred_at, winner_tid, win_reason, score_alliance, score_horde, duration_seconds, "
            "affix, affix_secondary, affix_tertiary FROM dc_hlbg_winner_history WHERE " + cond +
            " ORDER BY id DESC LIMIT " + std::to_string(HLBG_STATS_SAMPLE_ROWS));

        if (sample)
        {
            bool currentActive = true;
            bool currentSeeded = false;
            TeamId runTeam = TEAM_NEUTRAL;
            uint32 runLength = 0;

            do
            {
                Field* f = sample->Fetch();
                std::string occurredAt = f[0].Get<std::string>();
                TeamId winner = static_cast<TeamId>(f[1].Get<uint8>());
                std::string reason = f[2].Get<std::string>();
                uint32 allianceScore = f[3].Get<uint32>();
                uint32 hordeScore = f[4].Get<uint32>();
                uint32 durationSeconds = f[5].Get<uint32>();

                ++sampleRows;

                uint32 margin = allianceScore > hordeScore
                    ? (allianceScore - hordeScore)
                    : (hordeScore - allianceScore);

                // --- streaks (rows arrive newest first) ---
                bool isWin = winner == TEAM_ALLIANCE || winner == TEAM_HORDE;
                if (!isWin)
                {
                    if (runLength > bestStreak)
                    {
                        bestStreak = runLength;
                        bestTeam = runTeam;
                    }

                    runTeam = TEAM_NEUTRAL;
                    runLength = 0;

                    if (!currentSeeded)
                    {
                        currentStreak = 0;
                        currentTeam = TEAM_NEUTRAL;
                    }

                    currentActive = false;
                }
                else
                {
                    if (!currentSeeded)
                    {
                        currentTeam = winner;
                        currentStreak = 1;
                        currentSeeded = true;
                    }
                    else if (currentActive)
                    {
                        if (winner == currentTeam)
                            ++currentStreak;
                        else
                            currentActive = false;
                    }

                    if (runLength == 0)
                    {
                        runTeam = winner;
                        runLength = 1;
                    }
                    else if (winner == runTeam)
                    {
                        ++runLength;
                    }
                    else
                    {
                        if (runLength > bestStreak)
                        {
                            bestStreak = runLength;
                            bestTeam = runTeam;
                        }

                        runTeam = winner;
                        runLength = 1;
                    }

                    // --- largest decided margin ---
                    if (!hasLargestMargin || margin > largestMargin)
                    {
                        hasLargestMargin = true;
                        largestMargin = margin;
                        largestMarginTeam = winner;
                        largestMarginAlliance = allianceScore;
                        largestMarginHorde = hordeScore;
                        largestMarginTs = occurredAt;
                    }
                }

                // --- per-affix aggregates (primary + secondary + tertiary) ---
                for (uint8 column = 6; column <= 8; ++column)
                {
                    uint8 affixCode = f[column].Get<uint8>();
                    if (!affixCode)
                        continue;

                    AffixAggregate& stats = affixStats[affixCode];
                    ++stats.matches;
                    stats.marginTotal += static_cast<double>(margin);
                    stats.margins.push_back(margin);

                    if (durationSeconds > 0)
                    {
                        stats.durationTotal += static_cast<double>(durationSeconds);
                        ++stats.durationCount;
                    }

                    if (winner == TEAM_ALLIANCE)
                        ++stats.allianceWins;
                    else if (winner == TEAM_HORDE)
                        ++stats.hordeWins;
                    else
                        ++stats.draws;

                    if (reason == "depletion")
                        ++stats.depletion;
                    else if (reason == "tiebreaker")
                        ++stats.tiebreaker;
                }
            } while (sample->NextRow());

            if (runLength > bestStreak)
            {
                bestStreak = runLength;
                bestTeam = runTeam;
            }
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query HLBG statistics sample");
        }

        // GetTeamName maps TEAM_NEUTRAL to "Draw", which reads wrong for a
        // streak that simply has no holder.
        auto streakHolder = [](TeamId team) -> char const*
        {
            return team == TEAM_ALLIANCE ? "Alliance" : (team == TEAM_HORDE ? "Horde" : "None");
        };

        lines.push_back(Acore::StringFormat("Current streak: {} x{}",
            streakHolder(currentTeam), currentStreak));
        lines.push_back(Acore::StringFormat("Longest streak: {} x{} (last {} matches)",
            streakHolder(bestTeam), bestStreak, sampleRows));

        if (hasLargestMargin)
        {
            lines.push_back(Acore::StringFormat("Largest margin: [{}] {} by {} (A:{} H:{})",
                largestMarginTs, GetTeamName(static_cast<uint8>(largestMarginTeam)),
                largestMargin, largestMarginAlliance, largestMarginHorde));
        }

        if (affixStats.empty())
            return lines;

        std::vector<uint8> orderedAffixes;
        orderedAffixes.reserve(affixStats.size());
        for (auto const& affixEntry : affixStats)
            orderedAffixes.push_back(affixEntry.first);

        std::sort(orderedAffixes.begin(), orderedAffixes.end());

        lines.push_back("Affix outcomes (win rate):");
        for (uint8 affixCode : orderedAffixes)
        {
            AffixAggregate const& stats = affixStats.at(affixCode);
            double matches = static_cast<double>(stats.matches);
            lines.push_back(Acore::StringFormat("- {}: A {:.1f}% / H {:.1f}% / D {:.1f}%  (n={})",
                GetAffixName(affixCode),
                (static_cast<double>(stats.allianceWins) * 100.0) / matches,
                (static_cast<double>(stats.hordeWins) * 100.0) / matches,
                (static_cast<double>(stats.draws) * 100.0) / matches,
                stats.matches));
        }

        lines.push_back("Affix margin / duration:");
        for (uint8 affixCode : orderedAffixes)
        {
            AffixAggregate& stats = affixStats.at(affixCode);
            std::sort(stats.margins.begin(), stats.margins.end());

            std::size_t middle = stats.margins.size() / 2u;
            double median = stats.margins.size() % 2u == 0u
                ? (static_cast<double>(stats.margins[middle - 1u]) + static_cast<double>(stats.margins[middle])) / 2.0
                : static_cast<double>(stats.margins[middle]);

            std::string duration = stats.durationCount > 0
                ? FormatDuration(stats.durationTotal / static_cast<double>(stats.durationCount))
                : std::string("--:--");

            lines.push_back(Acore::StringFormat("- {}: avg {:.1f}, med {:.1f}, dur {}  (dep {} / tie {})",
                GetAffixName(affixCode),
                stats.marginTotal / static_cast<double>(stats.matches),
                median, duration, stats.depletion, stats.tiebreaker));
        }

        return lines;
    }

    void ShowStats(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);

        HLBGGossipPage page(player, HLBG_NAV_SLOTS_STATS);
        page.AddLine("Hinterland BG statistics:", ACTION_STATS);

        for (std::string const& line : GetCachedStatsLines(HLBGService::Instance().GetStatsIncludeManualResets()))
        {
            if (!page.AddLine(line, ACTION_STATS))
                break;
        }

        if (page.WasTruncated())
            page.AddNav("(list truncated)", ACTION_STATS);

        page.AddNav("History", ACTION_HISTORY);
        page.AddNav("Status", ACTION_STATUS);
        page.AddNav("Close", ACTION_CLOSE);
        SendGossipMenuFor(player, 1, creature->GetGUID());
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            DCUtils::MakeLargeGossipText("Interface\\Icons\\INV_Misc_Map_01", "Show Hinterland BG status"),
            GOSSIP_SENDER_MAIN, ACTION_STATUS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            DCUtils::MakeLargeGossipText("Interface\\Icons\\INV_Misc_Book_09", "Show Hinterland BG history"),
            GOSSIP_SENDER_MAIN, ACTION_HISTORY);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            DCUtils::MakeLargeGossipText("Interface\\Icons\\INV_Misc_Book_11", "Show Hinterland BG statistics"),
            GOSSIP_SENDER_MAIN, ACTION_STATS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            DCUtils::MakeLargeGossipText("Interface\\Icons\\INV_Misc_QuestionMark", "Close"),
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
            ShowStatus(player, creature);
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
