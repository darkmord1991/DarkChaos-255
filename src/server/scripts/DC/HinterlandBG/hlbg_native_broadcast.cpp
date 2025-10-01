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
        static ChatCommandTable table =
        {
            { "hlbglive_native", HandleHLBGLiveNativeCommand, SEC_GAMEMASTER, Console::No },
        };
        static ChatCommandTable root = { { "hlbglive", table } };
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
            player->SendBroadcastMessage(msg);
            handler->PSendSysMessage("Sent HLBG live JSON payload to you.");
            return true;
        }

        // Fallback to TSV with '||' delimiter
        std::string tsv = BuildTsvRows(rows);
        std::string msg = std::string("[HLBG_LIVE] ") + tsv;
        player->SendBroadcastMessage(msg);
        handler->PSendSysMessage("Sent HLBG live TSV payload to you.");
        return true;
    }
};

void AddSC_hlbg_native_broadcast()
{
    new hlbg_native_commandscript();
}
