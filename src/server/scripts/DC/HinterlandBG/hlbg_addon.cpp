/*
 * hlbg_addon.cpp
 *
 * Unified addon interface support for Hinterland BG (HLBG).
 * - Provides chat-based fallbacks for clients to fetch Live/History/Stats and Queue actions.
 * - Enforces warmup-only join window for ".hlbg queue join".
 * - Emits compact JSON/TSV messages prefixed with [HLBG_*] that the client addon parses.
 *
 * Notes:
 * - We intentionally use chat-prefixed messages instead of Rochet/AIO so this compiles without extra deps.
 * - If AIO is later integrated, keep these as fallbacks for players without AIO.
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "World.h"
#include "Map.h"
#include "DatabaseEnv.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"
#include "Log.h"
#include "HinterlandBGConstants.h"

// Forward declaration for utility functions
// OutdoorPvPHL is declared in OutdoorPvP/OutdoorPvPHL.h which we include below,
// but declare a lightweight forward declaration so prototypes using the pointer
// type can appear before the full include.
class OutdoorPvPHL;
namespace HLBGUtils { OutdoorPvPHL* GetHinterlandBG(); }
#include "OutdoorPvP/OutdoorPvPHL.h"
#include "Util.h"
#include <string>
#include <sstream>
#include <tuple>
#include <vector>
#include <ctime>
#include <algorithm>
#include <iterator>
#include <cctype>
#include <map>

using namespace Acore::ChatCommands;
using namespace HinterlandBGConstants;

// Forward declarations for handler functions referenced by the command tables
bool HandleHLBGLive(ChatHandler* handler, char const* args);
bool HandleHLBGWarmup(ChatHandler* handler, char const* args);
bool HandleHLBGResults(ChatHandler* handler, char const* args);
bool HandleHLBGHistoryUI(ChatHandler* handler, char const* args);
bool HandleHLBGStatsUI(ChatHandler* handler, char const* args);
bool HandleHLBGQueueJoin(ChatHandler* handler, char const* args);
bool HandleHLBGQueueLeave(ChatHandler* handler, char const* args);
bool HandleHLBGQueueStatus(ChatHandler* handler, char const* args);

namespace HLBGAddon
{
    // Minimal JSON escaper
    static std::string EscapeJson(const std::string& in)
    {
        std::string out; out.reserve(in.size());
        for (char c : in)
        {
            switch (c)
            {
                case '\\': out += "\\\\"; break;
                case '"':  out += "\\\""; break;
                case '\n': out += "\\n"; break;
                case '\r': out += "\\r"; break;
                case '\t': out += "\\t"; break;
                default: out.push_back(c); break;
            }
        }
        return out;
    }

    // Use centralized utility function
    static OutdoorPvPHL* GetHL()
    {
        return HLBGUtils::GetHinterlandBG();
    }

    static std::string NowTimestamp()
    {
        std::time_t t = std::time(nullptr);
        char buf[64];
#ifdef _WIN32
        std::tm tm; localtime_s(&tm, &t);
        std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &tm);
#else
        std::tm tm; localtime_r(&t, &tm);
        std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &tm);
#endif
        return std::string(buf);
    }

    // Build a compact JSON array for scoreboard rows (used by live)
    static std::string BuildLiveJson(uint32 matchStart, uint32 a, uint32 h)
    {
        std::ostringstream ss;
        std::string ts = NowTimestamp();
        ss << '[';
        ss << "{\"id\":\"" << matchStart << "-A\",\"ts\":\"" << EscapeJson(ts) << "\",\"name\":\"Alliance\",\"team\":\"Alliance\",\"score\":" << a << '}';
        ss << ',';
        ss << "{\"id\":\"" << matchStart << "-H\",\"ts\":\"" << EscapeJson(ts) << "\",\"name\":\"Horde\",\"team\":\"Horde\",\"score\":" << h << '}';
        ss << ']';
        return ss.str();
    }

    // Cache for season names (loaded from WorldDatabase.dc_hlbg_seasons)
    static std::unordered_map<uint32, std::string> s_SeasonNameCache;

    static std::string GetSeasonName(uint32 season)
    {
        auto it = s_SeasonNameCache.find(season);
        if (it != s_SeasonNameCache.end())
            return it->second;

        // Query from WorldDatabase
        QueryResult rs = WorldDatabase.Query("SELECT name FROM dc_hlbg_seasons WHERE season={}", season);
        std::string name = rs ? rs->Fetch()[0].Get<std::string>() : ("Season " + std::to_string(season));
        s_SeasonNameCache[season] = name;
        return name;
    }

    // Build TSV string for history rows (id\tseason\tseasonName\tts\twinner\taffix\treason) with lines joined by "||" for safe transport
    // Query format: SELECT id, season, occurred_at, winner_tid, win_reason, affix FROM dc_hlbg_winner_history
    static std::string BuildHistoryTsv(QueryResult& rs)
    {
        std::ostringstream ss;
        bool first = true;
        while (rs && rs->NextRow())
        {
            Field* f = rs->Fetch();
            uint64 id = f[0].Get<uint64>();
            uint32 season = f[1].Get<uint32>();
            std::string sname = GetSeasonName(season);
            std::string ts = f[2].Get<std::string>();
            uint32 winnerTid = f[3].Get<uint32>();
            std::string reason = f[4].Get<std::string>();
            uint32 affix = f[5].Get<uint32>();
            const char* win = (winnerTid == 0 ? "Alliance" : (winnerTid == 1 ? "Horde" : "Draw"));
            if (!first) ss << "||"; first = false;
            ss << id << '\t' << season << '\t' << HLBGAddon::EscapeJson(sname) << '\t' << ts << '\t' << win << '\t' << affix << '\t' << reason;
        }
        return ss.str();
    }

    static bool IsInWarmup(OutdoorPvPHL* hl)
    {
        if (!hl) return false;
        uint32 elapsed = hl->GetCurrentMatchDurationSeconds();
        // If duration is unknown (0) but timer is running, treat as not warmup. If it's a fresh start it should be small.
        return elapsed > 0 && elapsed <= WARMUP_WINDOW_SECONDS;
    }
}

// Note: command registration for '.hlbg' is centralized in
// src/server/scripts/Commands/cs_hl_bg.cpp. This file only provides the
// handler implementations (e.g. HandleHLBGLive, HandleHLBGQueueJoin, ...)
// as free functions so they can be referenced by the centralized command
// table. The previous addon-level CommandScript that registered a top-level
// 'hlbg' node has been removed to avoid duplicate registrations at startup.

// Helper: build per-player JSON rows (sorted by score desc, limited)
    static std::string BuildLivePlayersJson(OutdoorPvPHL* hl, uint32 limit = 40)
    {
        if (!hl) return std::string("[]");
        // Collect players currently in zone with their scores
        struct Row { std::string name; std::string team; uint32 score; uint32 hk; uint8 cls; int8 subgroup; };
        std::vector<Row> rows;
        hl->ForEachPlayerInZone([&](Player* p){
            if (!p) return;
            Row r; r.name = p->GetName(); r.team = (p->GetTeamId()==TEAM_ALLIANCE?"Alliance":"Horde"); r.score = hl->GetPlayerScore(p->GetGUID());
            r.hk = hl->GetPlayerHKDelta(p);
            r.cls = p->getClass();
            r.subgroup = (p->GetGroup() ? (int8)p->GetGroup()->GetMemberGroup(p->GetGUID()) : -1);
            rows.push_back(std::move(r));
        });
        std::sort(rows.begin(), rows.end(), [](Row const& a, Row const& b){ return a.score > b.score; });
        if (rows.size() > limit) rows.resize(limit);
        std::ostringstream ss; ss << '['; bool first = true; std::string ts = HLBGAddon::NowTimestamp(); uint32 mid = hl->GetMatchStartEpoch();
        for (size_t i=0;i<rows.size();++i)
        {
            if (!first) ss << ','; first = false;
            ss << '{'
               << "\"id\":\"" << mid << "-P" << i+1 << "\","
               << "\"ts\":\"" << HLBGAddon::EscapeJson(ts) << "\","
               << "\"name\":\"" << HLBGAddon::EscapeJson(rows[i].name) << "\","
               << "\"team\":\"" << rows[i].team << "\","
               << "\"score\":" << rows[i].score << ','
               << "\"hk\":" << rows[i].hk << ','
               << "\"class\":" << static_cast<uint32>(rows[i].cls) << ','
               << "\"subgroup\":" << static_cast<int32>(rows[i].subgroup)
               << '}';
        }
        ss << ']';
        return ss.str();
    }

    // .hlbg live [players] => send compact live JSON
    bool HandleHLBGLive(ChatHandler* handler, char const* args)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;
        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        if (!hl)
        {
            handler->PSendSysMessage("HLBG: controller not available.");
            return true;
        }
        uint32 a = hl->GetResources(TEAM_ALLIANCE);
        uint32 h = hl->GetResources(TEAM_HORDE);
        uint32 ms = hl->GetMatchStartEpoch();
        std::string jsonAH = HLBGAddon::BuildLiveJson(ms, a, h);
    // Always send A/H totals payload first so header updates before list
    ChatHandler(player->GetSession()).SendSysMessage((std::string("[HLBG_LIVE_JSON] ") + jsonAH).c_str());
        // If caller requested players or client is in Live tab, also send per-player rows
        bool wantPlayers = false;
        if (args && *args)
        {
            std::string s(args);
            std::transform(s.begin(), s.end(), s.begin(), ::tolower);
            wantPlayers = (s.find("players") != std::string::npos);
        }
        if (wantPlayers)
        {
            std::string jsonPlayers = BuildLivePlayersJson(hl);
            ChatHandler(player->GetSession()).SendSysMessage((std::string("[HLBG_LIVE_JSON] ") + jsonPlayers).c_str());
        }
        return true;
    }

    // .hlbg warmup [text]
    bool HandleHLBGWarmup(ChatHandler* handler, char const* args)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;
        std::string text = args ? std::string(args) : std::string();
        if (text.empty()) text = "Warmup has begun!";
        std::string msg = std::string("[HLBG_WARMUP] ") + text;
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        return true;
    }

    // .hlbg results (GM) -> send compact results JSON
    bool HandleHLBGResults(ChatHandler* handler, char const* /*args*/)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;
        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        std::string winner = "Draw"; uint32 a=0, h=0, dur=0, affix=0;
        if (hl)
        {
            a = hl->GetResources(TEAM_ALLIANCE);
            h = hl->GetResources(TEAM_HORDE);
            winner = (a>h) ? "Alliance" : (h>a) ? "Horde" : "Draw";
            dur = hl->GetCurrentMatchDurationSeconds();
            affix = hl->GetActiveAffixCode();
        }
        std::ostringstream ss; ss << '{' << "\"winner\":\"" << winner << "\",";
        ss << "\"affix\":" << affix << ',';
        ss << "\"duration\":" << dur << '}';
        std::string msg = std::string("[HLBG_RESULTS_JSON] ") + ss.str();
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        return true;
    }

    // .hlbg historyui [page] [per] [season?] [sort=id] [dir=DESC]
    // Notes:
    //  - season is optional; if omitted, server's current HL season is used.
    //  - to preserve backward compatibility, if the 3rd token is a number it is treated as season.
    bool HandleHLBGHistoryUI(ChatHandler* handler, char const* args)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;

        // Parse args (supports explicit season as the 3rd token)
        uint32 page = 1, per = 5; uint32 seasonOverride = 0; std::string sort = "id", dir = "DESC";
        if (args && *args)
        {
            std::vector<std::string> tokens; tokens.reserve(6);
            {
                std::istringstream is(args);
                std::string t; while (is >> t) tokens.push_back(t);
            }
            // page
            if (tokens.size() >= 1) { try { page = std::max<uint32>(1, std::stoul(tokens[0])); } catch (...) {} }
            // per
            if (tokens.size() >= 2) { try { per = std::max<uint32>(1, std::stoul(tokens[1])); } catch (...) {} }
            // season (optional if 3rd token is numeric)
            size_t idx = 2;
            if (tokens.size() >= 3)
            {
                bool numeric = !tokens[2].empty() && std::all_of(tokens[2].begin(), tokens[2].end(), ::isdigit);
                if (numeric)
                {
                    try { seasonOverride = std::stoul(tokens[2]); } catch (...) { seasonOverride = 0; }
                    idx = 3;
                }
            }
            // sort
            if (tokens.size() > idx) sort = tokens[idx++];
            // dir
            if (tokens.size() > idx) dir = tokens[idx++];
        }
        if (per == 0) per = 5;
        uint32 offset = (page > 0 ? (page - 1) * per : 0);
        // Whitelist sort/dir
        if (!(sort == "id" || sort == "occurred_at" || sort == "season")) sort = "id";
        std::string odir = (dir == "ASC" ? "ASC" : "DESC");

        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        uint32 season = seasonOverride > 0 ? seasonOverride : (hl ? hl->GetSeason() : 0u);

        // Build parameterized query with whitelisted sort/dir
        std::string sortCol = "h.id";
        if (sort == "id") sortCol = "h.id";
        else if (sort == "occurred_at") sortCol = "h.occurred_at";
        else if (sort == "season") sortCol = "h.season";

        // Note: dc_hlbg_seasons is in WorldDatabase, dc_hlbg_winner_history is in CharacterDatabase
        // Cannot JOIN across databases, so we fetch history without season names and look them up separately
        std::string query = "SELECT id, season, occurred_at, winner_tid, win_reason, affix FROM dc_hlbg_winner_history";
        if (season > 0)
            query += " WHERE season=" + std::to_string(season);
        query += " ORDER BY " + sortCol + " " + odir;
        query += " LIMIT " + std::to_string(per) + " OFFSET " + std::to_string(offset);

        // Get total count for pagination
        std::string countQuery = "SELECT COUNT(*) FROM dc_hlbg_winner_history";
        if (season > 0) countQuery += " WHERE season=" + std::to_string(season);

        uint32 totalRows = 0;
        QueryResult countRes = CharacterDatabase.Query(countQuery);
        if (countRes) totalRows = countRes->Fetch()[0].Get<uint32>();

        QueryResult rs = CharacterDatabase.Query(query);
        if (!rs)
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_HISTORY_TSV] ");
            handler->PSendSysMessage("HLBG: no history rows found.");
            return true;
        }
        std::string tsv = HLBGAddon::BuildHistoryTsv(rs);
        std::string msg = std::string("[HLBG_HISTORY_TSV] TOTAL=") + std::to_string(totalRows) + "||" + tsv;
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        return true;
    }

    // .hlbg statsui [season] -> send compact stats JSON used by client Stats()
    bool HandleHLBGStatsUI(ChatHandler* handler, char const* args)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;

        uint32 winA=0, winH=0, draws=0; uint32 avgDur=0; std::string seasonName;
        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        uint32 season = hl ? hl->GetSeason() : 0u;
        if (args && *args)
        {
            // Accept a single numeric season override
            std::string s(args);
            // Trim
            s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](unsigned char ch){ return !std::isspace(ch); }));
            s.erase(std::find_if(s.rbegin(), s.rend(), [](unsigned char ch){ return !std::isspace(ch); }).base(), s.end());
            if (!s.empty() && std::all_of(s.begin(), s.end(), ::isdigit))
            {
                try { uint32 so = std::stoul(s); if (so > 0) season = so; } catch (...) {}
            }
        }
        // Common WHERE clause by season (season is validated as uint32, safe to use)
        std::string where = (season > 0) ? (" WHERE season=" + std::to_string(season)) : std::string();
        auto whereAnd = [&](std::string const& cond) -> std::string {
            if (where.empty()) return std::string(" WHERE ") + cond;
            return where + " AND " + cond;
        };

        // Basic counts
        QueryResult r = CharacterDatabase.Query("SELECT SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2) FROM dc_hlbg_winner_history" + where);
        if (r)
        {
            Field* f = r->Fetch();
            winA = f[0].Get<uint64>(); winH = f[1].Get<uint64>(); draws = f[2].Get<uint64>();
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query basic winner counts for season {}", season);
    }
        QueryResult r2 = CharacterDatabase.Query("SELECT AVG(duration_seconds) FROM dc_hlbg_winner_history" + whereAnd("duration_seconds > 0"));
        if (r2)
        {
            Field* f = r2->Fetch(); avgDur = (uint32)f[0].Get<double>();
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query average duration for season {}", season);
        }

        if (season > 0)
        {
            QueryResult r3 = WorldDatabase.Query("SELECT name FROM dc_hlbg_seasons WHERE season={}", season);
            if (r3)
            {
                Field* f = r3->Fetch(); seasonName = f[0].Get<std::string>();
            }
            else
            {
                LOG_ERROR("hlbg", "Failed to query season name for season {}", season);
            }
        }

        // Reasons breakdown
        uint32 rDepl=0, rTie=0, rDraw=0, rMan=0;
        QueryResult rr = CharacterDatabase.Query("SELECT win_reason, COUNT(*) FROM dc_hlbg_winner_history" + where + " GROUP BY win_reason");
        if (rr)
        {
            do {
                Field* f = rr->Fetch();
                std::string reason = f[0].Get<std::string>();
                uint32 c = f[1].Get<uint32>();
                if (reason == "depletion") rDepl = c; else if (reason == "tiebreaker") rTie = c; else if (reason == "draw") rDraw = c; else if (reason == "manual") rMan = c;
            } while (rr->NextRow());
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query win reasons for season {}", season);
        }

        // Largest and average win margin (exclude draws)
        uint32 avgMargin = 0; uint32 largestMargin = 0; uint8 largestTeam = TEAM_NEUTRAL; uint32 lmA=0, lmH=0; std::string lmTs; uint64 lmId=0;
        QueryResult q = CharacterDatabase.Query(
            "SELECT id, occurred_at, winner_tid, score_alliance, score_horde, ABS(score_alliance - score_horde) AS margin FROM dc_hlbg_winner_history" + whereAnd("winner_tid IN (0,1)") + " ORDER BY margin DESC, id DESC LIMIT 1");
        if (q)
        {
            Field* f = q->Fetch();
            lmId = f[0].Get<uint64>(); lmTs = f[1].Get<std::string>(); largestTeam = f[2].Get<uint8>(); lmA = f[3].Get<uint32>(); lmH = f[4].Get<uint32>(); largestMargin = f[5].Get<uint32>();
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query largest margin for season {}", season);
        }

        QueryResult q2 = CharacterDatabase.Query("SELECT AVG(ABS(score_alliance - score_horde)) FROM dc_hlbg_winner_history" + whereAnd("winner_tid IN (0,1)"));
        if (q2)
        {
            Field* f = q2->Fetch(); avgMargin = (uint32)f[0].Get<double>();
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query average margin for season {}", season);
        }

        // Per-affix splits (top 8 by total rows)
        struct AffixRow { uint32 affix; uint32 a; uint32 h; uint32 d; uint32 avgd; };
        std::vector<AffixRow> affixRows;
        QueryResult qa = CharacterDatabase.Query(
            "SELECT affix, SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2), AVG(duration_seconds) FROM dc_hlbg_winner_history" + where + " GROUP BY affix ORDER BY COUNT(*) DESC LIMIT 8");
        if (qa)
        {
            do {
                Field* f = qa->Fetch(); AffixRow ar; ar.affix = f[0].Get<uint32>(); ar.a = f[1].Get<uint64>(); ar.h = f[2].Get<uint64>(); ar.d = f[3].Get<uint64>(); ar.avgd = (uint32)f[4].Get<double>(); affixRows.push_back(ar);
            } while (qa->NextRow());
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query affix splits for season {}", season);
        }

        // Exact per-weather splits from DB (season-filtered)
        struct WeatherRow { uint32 weather; uint32 a; uint32 h; uint32 d; uint32 avgd; };
        std::vector<WeatherRow> weatherRows;
        QueryResult qw = CharacterDatabase.Query(
            "SELECT weather, SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2), AVG(duration_seconds) FROM dc_hlbg_winner_history" + where + " GROUP BY weather ORDER BY COUNT(*) DESC");
        if (qw)
        {
            do {
                Field* f = qw->Fetch(); WeatherRow wr; wr.weather = f[0].Get<uint32>(); wr.a = f[1].Get<uint64>(); wr.h = f[2].Get<uint64>(); wr.d = f[3].Get<uint64>(); wr.avgd = (uint32)f[4].Get<double>(); weatherRows.push_back(wr);
            } while (qw->NextRow());
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query weather splits for season {}", season);
        }

        // Streaks (compute in code from chronological winners)
        uint32 longestLen = 0; uint8 longestTeam = TEAM_NEUTRAL; uint32 currentLen = 0; uint8 currentTeam = TEAM_NEUTRAL;
        QueryResult qs = CharacterDatabase.Query("SELECT winner_tid FROM dc_hlbg_winner_history" + where + " ORDER BY occurred_at ASC, id ASC");
        if (qs)
        {
            do {
                Field* f = qs->Fetch(); uint8 tid = f[0].Get<uint8>();
                if (tid > 1) // draw or neutral breaks streak
                {
                    currentLen = 0;
                    currentTeam = TEAM_NEUTRAL;
                }
                else
                {
                    if (currentLen == 0 || currentTeam != tid) { currentTeam = tid; currentLen = 1; } else { ++currentLen; }
                    if (currentLen > longestLen) { longestLen = currentLen; longestTeam = currentTeam; }
                }
            } while (qs->NextRow());
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query win streaks for season {}", season);
        }

        // Build JSON
        std::ostringstream ss;
        ss << "{\"counts\":{\"Alliance\":" << winA << ",\"Horde\":" << winH << "},";
        ss << "\"draws\":" << draws << ",\"avgDuration\":" << avgDur << ",\"season\":" << season << ",";
        ss << "\"seasonName\":\"" << HLBGAddon::EscapeJson(seasonName) << "\",";
        ss << "\"reasons\":{\"depletion\":" << rDepl << ",\"tiebreaker\":" << rTie << ",\"draw\":" << rDraw << ",\"manual\":" << rMan << "},";
        ss << "\"margins\":{\"avg\":" << avgMargin << ",\"largest\":{\"team\":\"" << (largestTeam==0?"Alliance":(largestTeam==1?"Horde":"")) << "\",\"margin\":" << largestMargin << ",\"a\":" << lmA << ",\"h\":" << lmH << ",\"ts\":\"" << HLBGAddon::EscapeJson(lmTs) << "\",\"id\":" << lmId << "}},";
        ss << "\"streaks\":{\"longest\":{\"team\":\"" << (longestTeam==0?"Alliance":(longestTeam==1?"Horde":"")) << "\",\"len\":" << longestLen << "},\"current\":{\"team\":\"" << (currentTeam==0?"Alliance":(currentTeam==1?"Horde":"")) << "\",\"len\":" << currentLen << "}},";
        ss << "\"byAffix\":[";
        for (size_t i=0;i<affixRows.size();++i) {
            if (i) ss << ',';
            ss << "{\"affix\":" << affixRows[i].affix << ",\"Alliance\":" << affixRows[i].a << ",\"Horde\":" << affixRows[i].h << ",\"DRAW\":" << affixRows[i].d << ",\"avg\":" << affixRows[i].avgd << "}";
        }
        ss << "],";
        // byWeather as array
        ss << "\"byWeather\":[";
        for (size_t i=0;i<weatherRows.size();++i) {
            if (i) ss << ',';
            ss << "{\"weather\":\"" << GetWeatherName(weatherRows[i].weather) << "\",\"Alliance\":" << weatherRows[i].a
               << ",\"Horde\":" << weatherRows[i].h << ",\"DRAW\":" << weatherRows[i].d << ",\"avg\":" << weatherRows[i].avgd << "}";
        }
        ss << "]}";
        std::string msg = std::string("[HLBG_STATS_JSON] ") + ss.str();
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        return true;
    }

    // .hlbg queue join -> warmup-only join and safe eligibility checks
    bool HandleHLBGQueueJoin(ChatHandler* handler, char const* /*args*/)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;
        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] not_available");
            return true;
        }

        // Level requirement (configured on the HLBG controller)
        if (!hl->IsPlayerMaxLevel(player))
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] too_low_level");
            return true;
        }
        // Deserter check
        if (player->HasAura(BG_DESERTER_SPELL))
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] deserter");
            return true;
        }
        if (!player->IsAlive())
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] dead");
            return true;
        }
        if (player->IsInCombat())
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] in_combat");
            return true;
        }
        if (Map* m = player->GetMap())
        {
            if (m->IsDungeon() || m->IsRaid() || m->IsBattlegroundOrArena())
            {
                ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] not_in_safe_area");
                return true;
            }
        }

        // Enforce warmup-only joining
        if (!HLBGAddon::IsInWarmup(hl))
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] closed");
            handler->PSendSysMessage("HLBG: Joining is allowed during warmup only.");
            return true;
        }

        // If already in Hinterlands, ensure raid membership; else teleport to base
        if (player->GetZoneId() == OutdoorPvPHLBuffZones[0])
        {
            (void)hl->AddOrSetPlayerToCorrectBfGroup(player);
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] joined");
            return true;
        }

    // Use the addon-friendly wrapper that safely forwards to the internal command handler
    hl->QueueCommandFromAddon(player, "queue", "join");
        return true;
    }

    // .hlbg queue leave -> leave the queue
    bool HandleHLBGQueueLeave(ChatHandler* handler, char const* /*args*/)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;
        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] not_available");
            return true;
        }

    hl->QueueCommandFromAddon(player, "queue", "leave");
        return true;
    }

    // .hlbg queue status [text]
    bool HandleHLBGQueueStatus(ChatHandler* handler, char const* args)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;
        if (args && *args)
        {
            std::string msg = std::string("[HLBG_QUEUE] ") + std::string(args);
            ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
            return true;
        }
        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] not_available");
            return true;
        }
    hl->QueueCommandFromAddon(player, "queue", "status");
        return true;
    }
// Note: Command registration for '.hlbg' is centralized in
// src/server/scripts/Commands/cs_hl_bg.cpp. This file contains the
// handler implementations (e.g. HandleHLBGLive, HandleHLBGQueueJoin, ...)
// as free functions so they can be referenced by the centralized command
// table. The previous addon-level CommandScript registration has been
// removed to avoid duplicate top-level 'hlbg' registration at startup.

// Provide a no-op AddSC symbol so legacy callers (dc_script_loader.cpp)
// that expect this registration function still link successfully.
// The actual command registration lives in `cs_hl_bg.cpp` now.
void AddSC_hlbg_addon()
{
    // intentionally empty; registration moved to cs_hl_bg.cpp
}
