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

        // Only expose a separate root to avoid conflicts with other HLBG command trees
        static ChatCommandTable root = {
            { "hlbglive", liveSub },
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
        static bool HandleHLBGResults(ChatHandler* handler, char const* /*args*/)
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
