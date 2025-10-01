/*
 * hlbg_native_broadcast.cpp
 *
 * GM helper to broadcast an authoritative LIVE payload for Hinterland BG using
 * native runtime getters. Sends a chat fallback JSON when compact, otherwise
 * TSV with '||' newline placeholder. This avoids requiring mod-eluna linkage
 * and is safe to compile into the server as a small CommandScript.
 */
#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "World.h"
#include "Map.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"
#include "OutdoorPvP/OutdoorPvPHL.h"
#include <string>
#include <sstream>
#include <ctime>

using namespace Acore::ChatCommands;

// Escape a string for inclusion in a JSON string value (minimal)
static std::string EscapeJson(const std::string& in)
{
    std::string out;
    out.reserve(in.size());
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

// Build a compact JSON array for rows
static std::string BuildJsonRows(const std::vector<std::tuple<std::string, std::string, std::string, std::string, int>>& rows)
{
    std::ostringstream ss;
    ss << '[';
    bool first = true;
    for (auto const& r : rows)
    {
        if (!first) ss << ',';
        first = false;
        std::string id, ts, name, team; int score;
        std::tie(id, ts, name, team, score) = r;
        ss << "{";
        ss << "\"id\":\"" << EscapeJson(id) << "\",";
        ss << "\"ts\":\"" << EscapeJson(ts) << "\",";
        ss << "\"name\":\"" << EscapeJson(name) << "\",";
        ss << "\"team\":\"" << EscapeJson(team) << "\",";
        ss << "\"score\":" << score;
        ss << "}";
    }
    ss << ']';
    return ss.str();
}

// Build a TSV payload where rows are joined by '||' (client will convert back to newlines)
static std::string BuildTsvRows(const std::vector<std::tuple<std::string, std::string, std::string, std::string, int>>& rows)
{
    std::ostringstream ss;
    bool first = true;
    for (auto const& r : rows)
    {
        if (!first) ss << "||";
        first = false;
        std::string id, ts, name, team; int score;
        std::tie(id, ts, name, team, score) = r;
        // fields separated by tab
        ss << id << '\t' << ts << '\t' << name << '\t' << team << '\t' << score;
    }
    return ss.str();
}

class hlbg_native_commandscript : public CommandScript
{
public:
    hlbg_native_commandscript() : CommandScript("hlbg_native_commandscript") {}

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable liveSub = {
            { "native", HandleHLBGLiveNativeCommand, SEC_GAMEMASTER, Console::No },
        };

        static ChatCommandTable queueSub = {
            { "join", HandleHLBGQueueJoin, SEC_PLAYER, Console::No },
            { "status", HandleHLBGQueueStatus, SEC_PLAYER, Console::No },
        };

        static ChatCommandTable hlbgSub = {
            { "live", liveSub },
            { "warmup", HandleHLBGWarmup, SEC_GAMEMASTER, Console::No },
            { "queue", queueSub },
            { "results", HandleHLBGResults, SEC_GAMEMASTER, Console::No },
        };

        static ChatCommandTable root = {
            { "hlbglive", liveSub },
            { "hlbg", hlbgSub },
        };
        return root;
    }

    static bool HandleHLBGLiveNativeCommand(ChatHandler* handler, char const* /*args*/)
    {
        if (!handler || !handler->GetSession())
            return false;
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
        if (!out)
        {
            handler->PSendSysMessage("Hinterland BG controller not active.");
            return true;
        }

        auto* hl = dynamic_cast<OutdoorPvPHL*>(out);
        if (!hl)
        {
            handler->PSendSysMessage("Hinterland BG controller not available.");
            return true;
        }

        // Build rows: two per-team summary rows (compact and small)
        std::vector<std::tuple<std::string, std::string, std::string, std::string, int>> rows;
        // timestamp
        std::time_t t = std::time(nullptr);
        char buf[64];
        std::tm tm;
#ifdef _WIN32
        localtime_s(&tm, &t);
#else
        localtime_r(&t, &tm);
#endif
        std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &tm);
        std::string ts(buf);

        uint32 a = hl->GetResources(TEAM_ALLIANCE);
        uint32 h = hl->GetResources(TEAM_HORDE);
        // Use match start epoch as part of id if available
        uint32 matchStart = hl->GetMatchStartEpoch();
        std::ostringstream ida; ida << matchStart << "-A";
        std::ostringstream idh; idh << matchStart << "-H";

        rows.emplace_back(ida.str(), ts, std::string("Alliance"), std::string("Alliance"), static_cast<int>(a));
        rows.emplace_back(idh.str(), ts, std::string("Horde"), std::string("Horde"), static_cast<int>(h));

        // Build JSON first and prefer it if under safe limit
        const size_t maxJsonLen = 1000; // keep in sync with HLBG_AIO.lua default
        std::string json = BuildJsonRows(rows);
        if (json.size() <= maxJsonLen)
        {
            std::string msg = std::string("[HLBG_LIVE_JSON] ") + json;
            ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
            handler->PSendSysMessage("Sent HLBG live JSON payload to you.");
            return true;
        }

        // Fallback to TSV with '||' delimiter
    std::string tsv = BuildTsvRows(rows);
    std::string msg = std::string("[HLBG_LIVE] ") + tsv;
    ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
    handler->PSendSysMessage("Sent HLBG live TSV payload to you.");
        return true;
    }

    static OutdoorPvPHL* GetHL()
    {
        OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
        if (!out)
            return nullptr;
        return dynamic_cast<OutdoorPvPHL*>(out);
    }

    // .hlbg warmup [text]
    static bool HandleHLBGWarmup(ChatHandler* handler, char const* args)
    {
        if (!handler || !handler->GetSession())
            return false;
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;
        std::string text = args ? std::string(args) : std::string();
        if (text.empty()) text = "Warmup has begun!";
        std::string msg = std::string("[HLBG_WARMUP] ") + text;
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        handler->PSendSysMessage("Sent HLBG warmup notice to you.");
        return true;
    }

    // .hlbg queue join
    static bool HandleHLBGQueueJoin(ChatHandler* handler, char const* /*args*/)
    {
        if (!handler || !handler->GetSession())
            return false;
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;
        OutdoorPvPHL* hl = GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] not_available");
            handler->PSendSysMessage("HLBG: Hinterland BG controller not available.");
            return true;
        }

        // Basic eligibility checks
        // 1) Level requirement: max level
        if (player->GetLevel() < sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL))
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] too_low_level");
            handler->PSendSysMessage("HLBG: You must be max level to join.");
            return true;
        }
        // 2) Deserter debuff denies entry
        static constexpr uint32 BG_DESERTER_SPELL = 26013; // Deserter
        if (player->HasAura(BG_DESERTER_SPELL))
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] deserter");
            handler->PSendSysMessage("HLBG: You have Deserter. Try again later.");
            return true;
        }
        // 3) No joining while dead or in combat
        if (!player->IsAlive())
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] dead");
            handler->PSendSysMessage("HLBG: You are dead. Release or resurrect first.");
            return true;
        }
        if (player->IsInCombat())
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] in_combat");
            handler->PSendSysMessage("HLBG: Cannot join while in combat.");
            return true;
        }
        // 4) Basic safe-area rule: do not allow from dungeons/raids/battlegrounds
        if (Map* m = player->GetMap())
        {
            if (m->IsDungeon() || m->IsRaid() || m->IsBattlegroundOrArena())
            {
                ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] not_in_safe_area");
                handler->PSendSysMessage("HLBG: Leave dungeon/raid/bg to join the Hinterland battle.");
                return true;
            }
        }

        // Treat no remaining time (0) as a locked/paused state (HL holds timer at 0 during lock)
        uint32 remaining = hl->GetTimeRemainingSeconds();
        if (remaining == 0)
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] locked");
            handler->PSendSysMessage("HLBG: Battleground is currently locked between matches. Please wait.");
            return true;
        }

        // If already in the Hinterlands, just ensure they are in the faction raid
        if (player->GetZoneId() == OutdoorPvPHLBuffZones[0])
        {
            // Auto-join faction raid group managed by HL
            (void)hl->AddOrSetPlayerToCorrectBfGroup(player);
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] joined");
            handler->PSendSysMessage("HLBG: You are in the Hinterlands — joined the faction raid (if available).");
            return true;
        }

        // Otherwise, teleport to team base in Hinterlands; On zone enter, HL will auto-invite to the raid
        hl->TeleportToTeamBase(player);
        ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] teleporting");
        handler->PSendSysMessage("HLBG: Teleporting you to your Hinterlands base…");
        return true;
    }

    // .hlbg queue status [text]
    static bool HandleHLBGQueueStatus(ChatHandler* handler, char const* args)
    {
        if (!handler || !handler->GetSession())
            return false;
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;
        // If an explicit text was provided, just echo it; otherwise compute a basic status
        if (args && *args)
        {
            std::string msg = std::string("[HLBG_QUEUE] ") + std::string(args);
            ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
            handler->PSendSysMessage("HLBG: queue status (echo) sent.");
            return true;
        }

        OutdoorPvPHL* hl = GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendSysMessage("[HLBG_QUEUE] not_available");
            handler->PSendSysMessage("HLBG: controller not available.");
            return true;
        }

        bool inZone = (player->GetZoneId() == OutdoorPvPHLBuffZones[0]);
        const char* s = inZone ? "in_zone" : "away";
        std::string msg = std::string("[HLBG_QUEUE] ") + s;
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        handler->PSendSysMessage("HLBG: queue status reported.");
        return true;
    }

    // .hlbg results -> build a compact JSON summary and send to client
    static bool HandleHLBGResults(ChatHandler* handler, char const* /*args*/)
    {
        if (!handler || !handler->GetSession())
            return false;
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        OutdoorPvPHL* hl = GetHL();
        std::string winner = "Draw";
        uint32 a = 0, h = 0;
        uint32 dur = 0;
        uint32 affix = 0;
        if (hl)
        {
            a = hl->GetResources(TEAM_ALLIANCE);
            h = hl->GetResources(TEAM_HORDE);
            if (a > h) winner = "Alliance"; else if (h > a) winner = "Horde"; else winner = "Draw";
            dur = hl->GetCurrentMatchDurationSeconds();
            affix = hl->GetActiveAffixCode();
        }

        std::ostringstream ss;
        ss << "{";
        ss << "\"winner\":\"" << winner << "\",";
        ss << "\"affix\":" << affix << ",";
        ss << "\"duration\":" << dur;
        ss << "}";
        std::string json = ss.str();
        std::string msg = std::string("[HLBG_RESULTS_JSON] ") + json;
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        handler->PSendSysMessage("Sent HLBG results JSON to you.");
        return true;
    }
};

void AddSC_hlbg_native_broadcast()
{
    new hlbg_native_commandscript();
}
