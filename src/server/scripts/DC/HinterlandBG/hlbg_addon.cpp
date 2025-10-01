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

    static OutdoorPvPHL* GetHL()
    {
        OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
        if (!out) return nullptr;
        return dynamic_cast<OutdoorPvPHL*>(out);
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

    // Build TSV string for history rows (id\tseason\tts\twinner\taffix\treason) with lines joined by "||" for safe transport
    static std::string BuildHistoryTsv(QueryResult& rs)
    {
        std::ostringstream ss;
        bool first = true;
        while (rs && rs->NextRow())
        {
            Field* f = rs->Fetch();
            uint64 id = f[0].Get<uint64>();
            uint32 season = f[1].Get<uint32>();
            std::string ts = f[2].Get<std::string>();
            uint32 winnerTid = f[3].Get<uint32>();
            std::string reason = f[4].Get<std::string>();
            uint32 affix = f[5].Get<uint32>();
            const char* win = (winnerTid == 0 ? "Alliance" : (winnerTid == 1 ? "Horde" : "Draw"));
            if (!first) ss << "||"; first = false;
            ss << id << '\t' << season << '\t' << ts << '\t' << win << '\t' << affix << '\t' << reason;
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
            { "join", HandleHLBGQueueJoin,   SEC_PLAYER, Console::No },
            { "status", HandleHLBGQueueStatus, SEC_PLAYER, Console::No },
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
            // Push elements via move construction to avoid any assignment requirements
            for (auto& c : uiSub)
                merged.emplace_back(std::move(c));
            for (auto& c : queueSub)
                merged.emplace_back(std::move(c));
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

    // .hlbg historyui [page] [per] [sort=id] [dir=DESC]
    static bool HandleHLBGHistoryUI(ChatHandler* handler, char const* args)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;

        // Parse args
        uint32 page = 1, per = 5; std::string sort = "id", dir = "DESC";
        if (args && *args)
        {
            std::istringstream is(args);
            is >> page >> per >> sort >> dir;
            if (!is) { page = 1; per = 5; sort = "id"; dir = "DESC"; }
        }
        if (per == 0) per = 5;
        uint32 offset = (page > 0 ? (page - 1) * per : 0);
    // Whitelist sort/dir
    if (!(sort == "id" || sort == "occurred_at" || sort == "season")) sort = "id";
        std::string odir = (dir == "ASC" ? "ASC" : "DESC");

        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        uint32 season = hl ? hl->GetSeason() : 0u;
        // id, season, occurred_at, winner_tid, win_reason, affix
        QueryResult rs;
        if (season > 0)
        {
            rs = CharacterDatabase.Query(
                "SELECT id, season, occurred_at, winner_tid, win_reason, affix FROM hlbg_winner_history WHERE season=%u ORDER BY %s %s LIMIT %u OFFSET %u",
                season, sort.c_str(), odir.c_str(), per, offset);
        }
        else
        {
            rs = CharacterDatabase.Query(
                "SELECT id, season, occurred_at, winner_tid, win_reason, affix FROM hlbg_winner_history ORDER BY %s %s LIMIT %u OFFSET %u",
                sort.c_str(), odir.c_str(), per, offset);
        }
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

    // .hlbg statsui -> send compact stats JSON used by client Stats()
    static bool HandleHLBGStatsUI(ChatHandler* handler, char const* /*args*/)
    {
        if (!handler || !handler->GetSession()) return false;
        Player* player = handler->GetSession()->GetPlayer(); if (!player) return false;

        uint32 winA=0, winH=0, draws=0; uint32 avgDur=0;
        OutdoorPvPHL* hl = HLBGAddon::GetHL();
        uint32 season = hl ? hl->GetSeason() : 0u;
        if (season > 0)
        {
            if (QueryResult r = CharacterDatabase.Query("SELECT SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2) FROM hlbg_winner_history WHERE season=%u", season))
            {
                Field* f = r->Fetch();
                winA = f[0].Get<uint64>(); winH = f[1].Get<uint64>(); draws = f[2].Get<uint64>();
            }
            if (QueryResult r2 = CharacterDatabase.Query("SELECT AVG(duration_seconds) FROM hlbg_winner_history WHERE season=%u AND duration_seconds > 0", season))
            {
                Field* f = r2->Fetch(); avgDur = (uint32)f[0].Get<double>();
            }
        }
        else
        {
            if (QueryResult r = CharacterDatabase.Query("SELECT SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2) FROM hlbg_winner_history"))
            {
                Field* f = r->Fetch();
                winA = f[0].Get<uint64>(); winH = f[1].Get<uint64>(); draws = f[2].Get<uint64>();
            }
            if (QueryResult r2 = CharacterDatabase.Query("SELECT AVG(duration_seconds) FROM hlbg_winner_history WHERE duration_seconds > 0"))
            {
                Field* f = r2->Fetch(); avgDur = (uint32)f[0].Get<double>();
            }
        }
        std::ostringstream ss;
        ss << "{\"counts\":{\"Alliance\":" << winA << ",\"Horde\":" << winH << "},";
        ss << "\"draws\":" << draws << ",\"avgDuration\":" << avgDur << ",\"season\":" << season << '}';
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

        hl->TeleportToTeamBase(player);
        ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] teleporting");
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
        bool inZone = (player->GetZoneId() == OutdoorPvPHLBuffZones[0]);
        std::string s = std::string("[HLBG_QUEUE] ") + (inZone ? "in_zone" : "away");
        ChatHandler(player->GetSession()).SendSysMessage(s.c_str());
        return true;
    }
};

void AddSC_hlbg_addon()
{
    new hlbg_addon_commandscript();
}
