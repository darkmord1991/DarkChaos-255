/*
 * hlbg_native_broadcast.cpp
 *
 * GM helper to broadcast an authoritative LIVE payload for Hinterland BG using
 * native runtime getters. Sends a compact chat JSON (or TSV if needed).
 * This avoids requiring mod-eluna linkage and is safe to compile into the
 * server as a small CommandScript.
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
#include <vector>
#include <tuple>

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

        rows.emplace_back("A", ts, "Alliance", "Alliance", static_cast<int>(a));
        rows.emplace_back("H", ts, "Horde", "Horde", static_cast<int>(h));

        // Always compact for two rows
        std::string json = BuildJsonRows(rows);
        std::string msg = std::string("[HLBG_LIVE_JSON] ") + json;
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        handler->PSendSysMessage("HLBG: native LIVE rows sent to you.");
        return true;
    }
};

void AddSC_hlbg_native_broadcast()
{
    new hlbg_native_commandscript();
}
