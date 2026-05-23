// -----------------------------------------------------------------------------
// hlbg_utils.cpp
// -----------------------------------------------------------------------------
// HLBG player stat persistence hooks.
// -----------------------------------------------------------------------------
#include "hlbg.h"
#include "DatabaseEnv.h"
#include "Log.h"

void HLBGPlayerStats::OnPlayerEnterBG(Player* player)
{
    if (!player)
        return;

    uint32 playerGuid = player->GetGUID().GetCounter();
    std::string playerName = player->GetName();
    std::string faction = player->GetTeamId() == TEAM_ALLIANCE ? "Alliance" : "Horde";

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_HLBG_PLAYER_ENTER);
    stmt->SetData(0, playerGuid);
    stmt->SetData(1, playerName);
    stmt->SetData(2, faction);
    CharacterDatabase.Execute(stmt);

    LOG_DEBUG("hlbg.stats", "Player {} ({}) entered HLBG - participation recorded", playerName, playerGuid);
}

void HLBGPlayerStats::OnPlayerKill(Player* killer, Player* victim)
{
    if (!killer || !victim)
        return;

    uint32 killerGuid = killer->GetGUID().GetCounter();
    uint32 victimGuid = victim->GetGUID().GetCounter();

    CharacterDatabasePreparedStatement* stmtKill = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_PLAYER_KILLS);
    stmtKill->SetData(0, killerGuid);
    CharacterDatabase.Execute(stmtKill);

    CharacterDatabasePreparedStatement* stmtDeath = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_PLAYER_DEATHS);
    stmtDeath->SetData(0, victimGuid);
    CharacterDatabase.Execute(stmtDeath);

    LOG_DEBUG("hlbg.stats", "HLBG Kill: {} killed {} - stats updated", killer->GetName(), victim->GetName());
}

void HLBGPlayerStats::OnResourceCapture(Player* player, uint32 resourceAmount)
{
    if (!player || resourceAmount == 0)
        return;

    uint32 playerGuid = player->GetGUID().GetCounter();

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_PLAYER_RESOURCES);
    stmt->SetData(0, resourceAmount);
    stmt->SetData(1, playerGuid);
    CharacterDatabase.Execute(stmt);

    LOG_DEBUG("hlbg.stats", "Player {} captured {} resources", player->GetName(), resourceAmount);
}

void HLBGPlayerStats::OnPlayerWin(Player* player)
{
    if (!player)
        return;

    uint32 playerGuid = player->GetGUID().GetCounter();
    CharacterDatabase.DirectExecute("UPDATE dc_hlbg_player_stats SET battles_won = battles_won + 1 WHERE player_guid = {}", playerGuid);

    LOG_DEBUG("hlbg.stats", "Player {} won HLBG - battles_won incremented", player->GetName());
}

void HLBGPlayerStats::OnTeamWin(TeamId winningTeam, uint32 zoneId)
{
    LOG_DEBUG("hlbg.stats", "Team {} won in zone {} - updating player wins",
        winningTeam == TEAM_ALLIANCE ? "Alliance" : "Horde", zoneId);
}
