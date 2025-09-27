#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include <string>
#include "Group.h"
#include "GroupMgr.h"
#include "Player.h"
#include <sstream>
#include <algorithm>

/*
 * hlbg_commandscript
 * ------------------
 * Provides GM/admin commands to inspect and manage the Hinterland (zone 47)
 * outdoor battleground state.
 *
 * Commands:
 *   .hlbg status            -- show battleground raid groups and sizes
 *   .hlbg get <alliance|horde> -- show resources for a team
 *   .hlbg set <team> <amt>  -- set resources for a team (GM-only); action is audited
 *   .hlbg reset             -- force-reset the Hinterland match state; action is audited
 *
 * Audit logging: administrative actions (.hlbg set/.hlbg reset) are logged to
 * the server log under the `admin.hlbg` category with the GM name and GUID.
 * Log format: "[ADMIN] <name> (GUID:<low>) <action>". This is intended for
 * lightweight operational audit trails; maintainers may redirect or persist
 * these messages to a centralized logging system if desired.
 *
 * Note: the Hinterland match code implements an explicit draw behavior when
 * match time expires with equal resources (no winner). See the comment in
 * `OutdoorPvPHL.cpp` for alternate tiebreak/reward approaches.
 */

using namespace Acore::ChatCommands;

class hlbg_commandscript : public CommandScript
{
public:
    hlbg_commandscript() : CommandScript("hlbg_commandscript") {}

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable hlbgCommandTable =
        {
            { "status", HandleHLBGStatusCommand, SEC_GAMEMASTER, Console::No },
            { "get",    HandleHLBGGetCommand,    SEC_GAMEMASTER, Console::No },
            { "set",    HandleHLBGSetCommand,    SEC_GAMEMASTER, Console::No },
            { "reset",  HandleHLBGResetCommand,  SEC_GAMEMASTER, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "hlbg", hlbgCommandTable }
        };

        return commandTable;
    }

    static bool HandleHLBGStatusCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        handler->PSendSysMessage("Hinterland BG raid groups:");

        for (uint8 team = TEAM_ALLIANCE; team <= TEAM_HORDE; ++team)
        {
            std::string teamName = (team == TEAM_ALLIANCE) ? "Alliance" : "Horde";
            handler->PSendSysMessage("Team: %s", teamName.c_str());

            std::vector<ObjectGuid> groups;
            if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(HL_ZONE_ID))
            {
                if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
                    groups = hl->GetBattlegroundGroupGUIDs((TeamId)team);
            }

            if (groups.empty())
            {
                handler->PSendSysMessage("  (no battleground raid groups)");
                continue;
            }

            for (auto gid : groups)
            {
                Group* g = sGroupMgr->GetGroupByGUID(gid.GetCounter());
                if (!g)
                {
                    handler->PSendSysMessage("  Group %u: (stale)", gid.GetCounter());
                    continue;
                }
                handler->PSendSysMessage("  Group %u: members=%u", g->GetGUID().GetCounter(), g->GetMembersCount());
            }
        }
        return true;
    }

    static bool HandleHLBGGetCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->PSendSysMessage("Usage: .hlbg get alliance|horde");
            return false;
        }
        std::string team(args);
        std::transform(team.begin(), team.end(), team.begin(), ::tolower);
        TeamId tid = (team == "alliance") ? TEAM_ALLIANCE : TEAM_HORDE;
        uint32 res = 0;
        if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(HL_ZONE_ID))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
                res = hl->GetResources(tid);
        }
        handler->PSendSysMessage("%s resources: %u", team.c_str(), res);
        return true;
    }

    static bool HandleHLBGSetCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->PSendSysMessage("Usage: .hlbg set alliance|horde <amount>");
            return false;
        }
        std::string in(args);
        std::istringstream iss(in);
        std::string teamStr;
        uint32 amount;
        iss >> teamStr >> amount;
        std::transform(teamStr.begin(), teamStr.end(), teamStr.begin(), ::tolower);
        TeamId tid = (teamStr == "alliance") ? TEAM_ALLIANCE : TEAM_HORDE;
        uint32 prev = 0;
        if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(HL_ZONE_ID))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
            {
                prev = hl->GetResources(tid);
                hl->SetResources(tid, amount);
            }
        }
        // Audit log with previous value
        if (Player* admin = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr)
            LOG_INFO("admin.hlbg", "[ADMIN] %s (GUID:%u) set %s resources from %u -> %u", admin->GetName().c_str(), admin->GetGUID().GetCounter(), teamStr.c_str(), prev, amount);
        handler->PSendSysMessage("Set %s resources to %u", teamStr.c_str(), amount);
        return true;
    }

    static bool HandleHLBGResetCommand(ChatHandler* handler, char const* /*args*/)
    {
        if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(HL_ZONE_ID))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
            {
                hl->ForceReset();
                // Audit log
                if (Player* admin = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr)
                    LOG_INFO("admin.hlbg", "[ADMIN] %s (GUID:%u) forced a Hinterland BG reset", admin->GetName().c_str(), admin->GetGUID().GetCounter());
                handler->PSendSysMessage("Hinterland BG forced reset executed.");
                return true;
            }
        }
        handler->PSendSysMessage("Hinterland BG instance not found.");
        return false;
    }
};

void AddSC_hlbg_commandscript()
{
    new hlbg_commandscript();
}
