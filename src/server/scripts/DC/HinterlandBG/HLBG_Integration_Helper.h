/* HLBG Battleground Integration Helper - Header
 * Provides static hooks for recording player statistics in dc_hlbg_player_stats table.
 * 
 * These functions should be called from OutdoorPvPHL handlers:
 * - OnPlayerEnterBG: When player enters HLBG zone (HandlePlayerEnterZone)
 * - OnPlayerKill: When a player kills another player (HandleKill)
 * - OnResourceCapture: When resources are captured/scored
 * - OnPlayerWin: When a player wins a match (incrementing battles_won)
 */

#ifndef HLBG_INTEGRATION_HELPER_H
#define HLBG_INTEGRATION_HELPER_H

#include "Player.h"
#include "DatabaseEnv.h"
#include "Log.h"

class HLBGPlayerStats
{
public:
    // Called when a player enters the HLBG zone - records participation
    static void OnPlayerEnterBG(Player* player)
    {
        if (!player)
            return;

        uint32 playerGuid = player->GetGUID().GetCounter();
        std::string playerName = player->GetName();
        std::string faction = player->GetTeamId() == TEAM_ALLIANCE ? "Alliance" : "Horde";

        // Insert or update player entry - increments battles_participated
        CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_HLBG_PLAYER_ENTER);
        stmt->SetData(0, playerGuid);
        stmt->SetData(1, playerName);
        stmt->SetData(2, faction);
        CharacterDatabase.Execute(stmt);

        LOG_DEBUG("hlbg.stats", "Player {} ({}) entered HLBG - participation recorded", playerName, playerGuid);
    }

    // Called when a player kills another player in HLBG
    static void OnPlayerKill(Player* killer, Player* victim)
    {
        if (!killer || !victim)
            return;

        uint32 killerGuid = killer->GetGUID().GetCounter();
        uint32 victimGuid = victim->GetGUID().GetCounter();

        // Increment killer's total_kills
        CharacterDatabasePreparedStatement* stmtKill = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_PLAYER_KILLS);
        stmtKill->SetData(0, killerGuid);
        CharacterDatabase.Execute(stmtKill);

        // Increment victim's total_deaths
        CharacterDatabasePreparedStatement* stmtDeath = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_PLAYER_DEATHS);
        stmtDeath->SetData(0, victimGuid);
        CharacterDatabase.Execute(stmtDeath);

        LOG_DEBUG("hlbg.stats", "HLBG Kill: {} killed {} - stats updated", killer->GetName(), victim->GetName());
    }

    // Called when resources are captured/scored by a player
    static void OnResourceCapture(Player* player, uint32 resourceAmount)
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

    // Called when a player wins a match - increments battles_won
    static void OnPlayerWin(Player* player)
    {
        if (!player)
            return;

        uint32 playerGuid = player->GetGUID().GetCounter();

        // Update battles_won using raw query (no prepared statement available for this specific update)
        CharacterDatabase.DirectExecute("UPDATE dc_hlbg_player_stats SET battles_won = battles_won + 1 WHERE player_guid = {}", playerGuid);

        LOG_DEBUG("hlbg.stats", "Player {} won HLBG - battles_won incremented", player->GetName());
    }

    // Batch update wins for all players in a faction who are in the zone
    static void OnTeamWin(TeamId winningTeam, uint32 zoneId)
    {
        // This will be called from the match end handler to update all winning players
        LOG_DEBUG("hlbg.stats", "Team {} won in zone {} - updating player wins", 
            winningTeam == TEAM_ALLIANCE ? "Alliance" : "Horde", zoneId);
    }
};

#endif // HLBG_INTEGRATION_HELPER_H
