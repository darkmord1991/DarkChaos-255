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

namespace HLBGAddon
{
    static constexpr uint32 WARMUP_WINDOW_SECONDS = 120; // allow joins only during the first N seconds of a match

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

    static const char* WeatherName(uint32 w)
    {
        switch (w)
        {
            case 0: return "Fine";
            case 1: return "Rain";
            case 2: return "Snow";
            case 3: return "Storm";
            default: return "Unknown";
        }
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

    // Build TSV string for history rows (id\tseason\tseasonName\tts\twinner\taffix\treason) with lines joined by "||" for safe transport
    static std::string BuildHistoryTsv(QueryResult& rs)
    {
        std::ostringstream ss;
        bool first = true;
        while (rs && rs->NextRow())
        {
            Field* f = rs->Fetch();
            uint64 id = f[0].Get<uint64>();
            uint32 season = f[1].Get<uint32>();
            std::string sname = f[2].IsNull() ? std::string("") : f[2].Get<std::string>();
            std::string ts = f[3].Get<std::string>();
            uint32 winnerTid = f[4].Get<uint32>();
            std::string reason = f[5].Get<std::string>();
            uint32 affix = f[6].Get<uint32>();
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

class hlbg_addon_commandscript : public CommandScript
{
public:
    hlbg_addon_commandscript() : CommandScript("hlbg_addon_commandscript") {}

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable queueSub = {
            { "join",    HandleHLBGQueueJoin,    SEC_PLAYER, Console::No },
            { "leave",   HandleHLBGQueueLeave,   SEC_PLAYER, Console::No },
            { "status",  HandleHLBGQueueStatus,  SEC_PLAYER, Console::No },
            { "qstatus", HandleHLBGQueueStatus,  SEC_PLAYER, Console::No },
        };

        static ChatCommandTable uiSub = {
            { "live",    HandleHLBGLive,    SEC_PLAYER, Console::No },
            { "historyui", HandleHLBGHistoryUI, SEC_PLAYER, Console::No },
            { "statsui", HandleHLBGStatsUI, SEC_PLAYER, Console::No },
            { "warmup",  HandleHLBGWarmup,  SEC_GAMEMASTER, Console::No },
            { "results", HandleHLBGResults, SEC_GAMEMASTER, Console::No },
        };

        // Merge our UI and queue subcommands under a single 'hlbg' root to avoid duplicates
        static ChatCommandTable merged;
        if (merged.empty())
        {
            merged.reserve(uiSub.size() + queueSub.size());
            // Copy entries individually to avoid operations that require assignment
            for (auto const& c : uiSub) merged.push_back(c);
            for (auto const& c : queueSub) merged.push_back(c);
        }

        static ChatCommandTable root = {
            { "hlbg", merged },
        };
        return root;
    }

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
    static bool HandleHLBGLive(ChatHandler* handler, char const* args)
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
    static bool HandleHLBGWarmup(ChatHandler* handler, char const* args)
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
    static bool HandleHLBGResults(ChatHandler* handler, char const* /*args*/)
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
    static bool HandleHLBGHistoryUI(ChatHandler* handler, char const* args)
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
        // id, season, seasonName, occurred_at, winner_tid, win_reason, affix
        // Build SQL safely (whitelisted sort/dir), avoiding printf-style placeholders
        std::ostringstream qss;
        qss << "SELECT h.id, h.season, s.name AS seasonName, h.occurred_at, h.winner_tid, h.win_reason, h.affix FROM hlbg_winner_history h LEFT JOIN hlbg_seasons s ON h.season=s.season";
        if (season > 0)
            qss << " WHERE h.season=" << season;
        // Whitelist sort field mapping to avoid ambiguous column in join
        std::string sortCol = sort;
        if (sort == "id") sortCol = "h.id"; else if (sort == "occurred_at") sortCol = "h.occurred_at"; else if (sort == "season") sortCol = "h.season"; else sortCol = "h.id";
        qss << " ORDER BY " << sortCol << ' ' << odir;
        qss << " LIMIT " << per << " OFFSET " << offset;
        QueryResult rs = CharacterDatabase.Query(qss.str());
        if (!rs)
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_HISTORY_TSV] ");
            handler->PSendSysMessage("HLBG: no history rows found.");
            return true;
        }
        std::string tsv = HLBGAddon::BuildHistoryTsv(rs);
        std::string msg = std::string("[HLBG_HISTORY_TSV] ") + tsv;
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        return true;
    }

    // .hlbg statsui [season] -> send compact stats JSON used by client Stats()
    static bool HandleHLBGStatsUI(ChatHandler* handler, char const* args)
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
        // Common WHERE clause by season
        std::string where = (season > 0) ? (" WHERE season=" + std::to_string(season)) : std::string();
        auto whereAnd = [&](std::string const& cond) -> std::string {
            if (where.empty()) return std::string(" WHERE ") + cond;
            return where + " AND " + cond;
        };

        // Basic counts
        if (QueryResult r = CharacterDatabase.Query("SELECT SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2) FROM hlbg_winner_history" + where))
        {
            Field* f = r->Fetch();
            winA = f[0].Get<uint64>(); winH = f[1].Get<uint64>(); draws = f[2].Get<uint64>();
        }
        if (QueryResult r2 = CharacterDatabase.Query("SELECT AVG(duration_seconds) FROM hlbg_winner_history" + whereAnd("duration_seconds > 0")))
        {
            Field* f = r2->Fetch(); avgDur = (uint32)f[0].Get<double>();
        }
        if (QueryResult r3 = CharacterDatabase.Query("SELECT name FROM hlbg_seasons WHERE season=" + std::to_string(season)))
        {
            Field* f = r3->Fetch(); seasonName = f[0].Get<std::string>();
        }

        // Reasons breakdown
        uint32 rDepl=0, rTie=0, rDraw=0, rMan=0;
        if (QueryResult rr = CharacterDatabase.Query("SELECT win_reason, COUNT(*) FROM hlbg_winner_history" + where + " GROUP BY win_reason"))
        {
            do {
                Field* f = rr->Fetch();
                std::string reason = f[0].Get<std::string>();
                uint32 c = f[1].Get<uint32>();
                if (reason == "depletion") rDepl = c; else if (reason == "tiebreaker") rTie = c; else if (reason == "draw") rDraw = c; else if (reason == "manual") rMan = c;
            } while (rr->NextRow());
        }

        // Largest and average win margin (exclude draws)
        uint32 avgMargin = 0; uint32 largestMargin = 0; uint8 largestTeam = TEAM_NEUTRAL; uint32 lmA=0, lmH=0; std::string lmTs; uint64 lmId=0;
        if (QueryResult q = CharacterDatabase.Query(
            "SELECT id, occurred_at, winner_tid, score_alliance, score_horde, ABS(score_alliance - score_horde) AS margin FROM hlbg_winner_history" + whereAnd("winner_tid IN (0,1)") + " ORDER BY margin DESC, id DESC LIMIT 1"))
        {
            Field* f = q->Fetch();
            lmId = f[0].Get<uint64>(); lmTs = f[1].Get<std::string>(); largestTeam = f[2].Get<uint8>(); lmA = f[3].Get<uint32>(); lmH = f[4].Get<uint32>(); largestMargin = f[5].Get<uint32>();
        }
        if (QueryResult q2 = CharacterDatabase.Query("SELECT AVG(ABS(score_alliance - score_horde)) FROM hlbg_winner_history" + whereAnd("winner_tid IN (0,1)")))
        {
            Field* f = q2->Fetch(); avgMargin = (uint32)f[0].Get<double>();
        }

        // Per-affix splits (top 8 by total rows)
        struct AffixRow { uint32 affix; uint32 a; uint32 h; uint32 d; uint32 avgd; };
        std::vector<AffixRow> affixRows;
        if (QueryResult qa = CharacterDatabase.Query(
            "SELECT affix, SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2), AVG(duration_seconds) FROM hlbg_winner_history" + where + " GROUP BY affix ORDER BY COUNT(*) DESC LIMIT 8"))
        {
            do {
                Field* f = qa->Fetch(); AffixRow ar; ar.affix = f[0].Get<uint32>(); ar.a = f[1].Get<uint64>(); ar.h = f[2].Get<uint64>(); ar.d = f[3].Get<uint64>(); ar.avgd = (uint32)f[4].Get<double>(); affixRows.push_back(ar);
            } while (qa->NextRow());
        }

        // Exact per-weather splits from DB (season-filtered)
        struct WeatherRow { uint32 weather; uint32 a; uint32 h; uint32 d; uint32 avgd; };
        std::vector<WeatherRow> weatherRows;
        if (QueryResult qw = CharacterDatabase.Query(
            "SELECT weather, SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2), AVG(duration_seconds) FROM hlbg_winner_history" + where + " GROUP BY weather ORDER BY COUNT(*) DESC"))
        {
            do {
                Field* f = qw->Fetch(); WeatherRow wr; wr.weather = f[0].Get<uint32>(); wr.a = f[1].Get<uint64>(); wr.h = f[2].Get<uint64>(); wr.d = f[3].Get<uint64>(); wr.avgd = (uint32)f[4].Get<double>(); weatherRows.push_back(wr);
            } while (qw->NextRow());
        }

        // Streaks (compute in code from chronological winners)
        uint32 longestLen = 0; uint8 longestTeam = TEAM_NEUTRAL; uint32 currentLen = 0; uint8 currentTeam = TEAM_NEUTRAL;
        if (QueryResult qs = CharacterDatabase.Query("SELECT winner_tid FROM hlbg_winner_history" + where + " ORDER BY occurred_at ASC, id ASC"))
        {
            do {
                Field* f = qs->Fetch(); uint8 tid = f[0].Get<uint8>();
                if (tid > 1) { // draw or neutral breaks streak
                    currentLen = 0; currentTeam = TEAM_NEUTRAL;
                } else {
                    if (currentLen == 0 || currentTeam != tid) { currentTeam = tid; currentLen = 1; } else { ++currentLen; }
                    if (currentLen > longestLen) { longestLen = currentLen; longestTeam = currentTeam; }
                }
            } while (qs->NextRow());
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
            ss << "{\"weather\":\"" << HLBGAddon::WeatherName(weatherRows[i].weather) << "\",\"Alliance\":" << weatherRows[i].a
               << ",\"Horde\":" << weatherRows[i].h << ",\"DRAW\":" << weatherRows[i].d << ",\"avg\":" << weatherRows[i].avgd << "}";
        }
        ss << "]}";
        std::string msg = std::string("[HLBG_STATS_JSON] ") + ss.str();
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        return true;
    }

    // .hlbg queue join -> warmup-only join and safe eligibility checks
    static bool HandleHLBGQueueJoin(ChatHandler* handler, char const* /*args*/)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;
        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] not_available");
            return true;
        }

        // Max level requirement
        if (player->GetLevel() < sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL))
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] too_low_level");
            return true;
        }
        // Deserter
        static constexpr uint32 BG_DESERTER_SPELL = 26013;
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

        // Use the new queue system
        hl->HandleQueueJoinCommand(player);
        return true;
    }

    // .hlbg queue leave -> leave the queue
    static bool HandleHLBGQueueLeave(ChatHandler* handler, char const* /*args*/)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;
        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] not_available");
            return true;
        }

        // Use the new queue system
        hl->HandleQueueLeaveCommand(player);
        return true;
    }

    // .hlbg queue status [text]
    static bool HandleHLBGQueueStatus(ChatHandler* handler, char const* args)
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
        // Use the new queue system to show status
        hl->HandleQueueStatusCommand(player);
        return true;
    }
};

void AddSC_hlbg_addon()
{
    new hlbg_addon_commandscript();
}
