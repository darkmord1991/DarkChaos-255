/*
 * HLBG battlemaster bridge
 *
 * Redirects battlemaster join requests for the HLBG battlemaster-list ID
 * into the OutdoorPvPHL queue system.
 */

#include "hlbg.h"
#include "Chat.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"

namespace
{
    constexpr BattlegroundTypeId HLBG_BATTLEGROUND_TYPE_ID = BattlegroundTypeId(20);

    OutdoorPvPHL* GetHLController()
    {
        OutdoorPvP* opvp = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
        return opvp ? dynamic_cast<OutdoorPvPHL*>(opvp) : nullptr;
    }
}

class hlbg_battlemaster_join_hook : public PlayerScript
{
public:
    hlbg_battlemaster_join_hook() : PlayerScript("hlbg_battlemaster_join_hook") { }

    bool OnPlayerCanJoinInBattlegroundQueue(Player* player, ObjectGuid /*battlemasterGuid*/, BattlegroundTypeId bgTypeId, uint8 joinAsGroup, GroupJoinBattlegroundResult& err) override
    {
        if (bgTypeId != HLBG_BATTLEGROUND_TYPE_ID)
            return true;

        if (!player)
        {
            err = ERR_GROUP_JOIN_BATTLEGROUND_FAIL;
            return false;
        }

        OutdoorPvPHL* hl = GetHLController();
        if (!hl)
        {
            err = ERR_BATTLEGROUND_NONE;
            ChatHandler(player->GetSession()).SendNotification("HLBG is currently unavailable.");
            return false;
        }

        if (joinAsGroup)
            hl->HandleGroupQueueJoinCommand(player);
        else
            hl->HandleQueueJoinCommand(player);

        // Block default BattlegroundMgr queueing; HLBG uses OutdoorPvP queue logic.
        err = ERR_BATTLEGROUND_NONE;
        return false;
    }
};

void AddSC_hlbg_battlemaster_hook()
{
    new hlbg_battlemaster_join_hook();
}
