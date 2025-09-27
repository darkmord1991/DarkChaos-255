#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include <string>
#include "Group.h"
#include "GroupMgr.h"
#include "Player.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"
#include "OutdoorPvP/OutdoorPvPHL.h"
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
        // ChatCommandTable usage
        // ----------------------
        // A ChatCommandTable is a simple vector-of-entries that the command
        // dispatch system converts into a tree. Each entry below registers
        // a subcommand name, a handler function, the required security level
        // and whether the console may execute it. Help text may be provided
        // via other overloads; for these simple admin commands we rely on the
        // top-level help and the explicit usage strings in the handlers.

        // Notes for maintainers:
        // - The handler signatures in this file use the legacy
        //   `bool(ChatHandler*, char const*)` form which is compatible with
        //   the CommandInvoker wrapper. Newer commands may use typed
        //   argument parsing and different handler signatures.

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
        // Purpose: show all battleground-style raid groups tracked for the
        // Hinterland (zone defined by `OutdoorPvPHLBuffZones[0]`) and their
        // member counts. This helps GMs inspect which auto-created raid
        // groups are currently active for each faction.
        //
        // Inputs: Chat handler for the GM invoking the command. No arguments
        // are expected.
        // Outputs: multiple `PSendSysMessage` calls to the GM with group info.
        // Error modes: returns false if no player is associated with the handler.

        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        // Print high-level status: active, time, resources
        if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
            {
                const bool active = hl->BattleActive();
                const uint32 tRemain = hl->GetMatchTimeRemainingSeconds();
                const uint32 tElapsed = hl->GetMatchTimeElapsedSeconds();
                const char* last = hl->GetLastWinner() == ALLIANCE ? "Alliance" : (hl->GetLastWinner() == HORDE ? "Horde" : "None");
                handler->PSendSysMessage("Hinterland BG status: active={} | lastWinner={} | time elapsed={}s | time remaining={}s", active ? "yes" : "no", last, tElapsed, tRemain);
                uint32 aCur = hl->GetResources(TEAM_ALLIANCE);
                uint32 hCur = hl->GetResources(TEAM_HORDE);
                uint32 aMax = hl->GetPermanentResources(TEAM_ALLIANCE);
                uint32 hMax = hl->GetPermanentResources(TEAM_HORDE);
                handler->PSendSysMessage("Resources: Alliance {}/{} | Horde {}/{}", aCur, aMax, hCur, hMax);
            }
        }

        handler->PSendSysMessage("Hinterland BG raid groups:");

        for (uint8 team = TEAM_ALLIANCE; team <= TEAM_HORDE; ++team)
        {
            std::string teamName = (team == TEAM_ALLIANCE) ? "Alliance" : "Horde";
            handler->PSendSysMessage("Team: {}", teamName);

            // Query the OutdoorPvP manager for the Hinterland instance.
            // We look it up by the buff-zone constant exported from
            // `OutdoorPvPHL.h` (the script that implements Hinterland's logic).
            // The dynamic_cast ensures we only call HL-specific helpers when
            // the zone script is present and matches the expected type.
            std::vector<ObjectGuid> groups;
            if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
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
                    handler->PSendSysMessage("  Group {}: (stale)", gid.GetCounter());
                    continue;
                }
                handler->PSendSysMessage("  Group {}: members={}", g->GetGUID().GetCounter(), g->GetMembersCount());
            }
        }
        return true;
    }

    static bool HandleHLBGGetCommand(ChatHandler* handler, char const* args)
    {
        // Purpose: show the current resource counter for the requested team.
        //
        // Usage: .hlbg get alliance|horde
        // Inputs: `args` should contain the team name. Handler will respond
        // with a usage message if args are missing or malformed.
        // Outputs: PSysMessage showing the requested team's resources.

        if (!args || !*args)
        {
        handler->PSendSysMessage("Usage: .hlbg get alliance|horde");
            return false;
        }
        std::string team(args);
        std::transform(team.begin(), team.end(), team.begin(), ::tolower);
        TeamId tid = (team == "alliance") ? TEAM_ALLIANCE : TEAM_HORDE;
        uint32 res = 0;
            if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
                res = hl->GetResources(tid);
        }
    handler->PSendSysMessage("{} resources: {}", team, res);
        return true;
    }

    static bool HandleHLBGSetCommand(ChatHandler* handler, char const* args)
    {
        // Purpose: allow a GM to set a team's resource counter (audit-logged).
        //
        // Usage: .hlbg set alliance|horde <amount>
        // Inputs: `args` parsed into team and numeric amount. No further
        // validation is performed here (amount is taken as an unsigned 32-bit
        // value). Consider clamping or validating ranges if needed.
        // Outputs: sets the resource counter via the `OutdoorPvPHL` API and
        // emits an audit log line under the `admin.hlbg` category.
        // Error modes: returns false / prints usage when args are missing.

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
    if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
            {
                // Capture previous value for audit trail, then set new amount.
                prev = hl->GetResources(tid);
                hl->SetResources(tid, amount);
            }
        }
        // Audit log with previous value
        // Record the administrative action to the server log. The category
        // `admin.hlbg` is used to make it easy to filter these entries for
        // operational auditing. The message includes the GM name and low GUID
        // as a compact identity marker.
        if (Player* admin = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr)
            LOG_INFO("admin.hlbg", "[ADMIN] %s (GUID:%u) set %s resources from %u -> %u", admin->GetName().c_str(), admin->GetGUID().GetCounter(), teamStr.c_str(), prev, amount);
    handler->PSendSysMessage("Set {} resources to {}", teamStr, amount);
        return true;
    }

    static bool HandleHLBGResetCommand(ChatHandler* handler, char const* /*args*/)
    {
        // Purpose: force the Hinterland match into its reset state. This is a
        // powerful operation and is therefore logged to `admin.hlbg`.
        //
        // Usage: .hlbg reset
        // Inputs: no args; acts on the Hinterland OutdoorPvP instance if present.
        // Outputs: calls `ForceReset()` on the HL instance and logs the action.

    if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
            {
                hl->ForceReset();
                // Teleport players back to start positions configured in the OutdoorPvP script
                hl->TeleportPlayersToStart();
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
