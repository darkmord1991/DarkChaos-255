#include "ScriptMgr.h"
#include "Chat.h"
#include "Group.h"
#include "GroupMgr.h"
#include "Player.h"
#include <sstream>
#include <algorithm>

class hlbg_commandscript : public CommandScript
{
public:
    hlbg_commandscript() : CommandScript("hlbg_commandscript") {}

    std::vector<ChatCommand> GetCommands() const override
    {
        static std::vector<ChatCommand> hlbgCommandTable =
        {
            { "status",   SEC_GAMEMASTER,  false, &HandleHLBGStatusCommand, "Show Hinterland BG raid groups and sizes" },
            { "get",       SEC_GAMEMASTER,  false, &HandleHLBGGetCommand, "Get resource amount for a team: hlbg get alliance|horde" },
            { "set",       SEC_GAMEMASTER,  false, &HandleHLBGSetCommand, "Set resource amount for a team: hlbg set alliance|horde <amount>" },
            { "reset",     SEC_GAMEMASTER,  false, &HandleHLBGResetCommand, "Force reset the Hinterland BG match state" },
        };

        static std::vector<ChatCommand> commandTable =
        {
            { "hlbg",      SEC_GAMEMASTER,  false, nullptr, "Commands for Hinterland BG" , hlbgCommandTable },
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
        if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(HL_ZONE_ID))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
                hl->SetResources(tid, amount);
        }
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
