/* HLBG Battleground Integration Helper
 * Integrates HLBG systems into AzerothCore sources.
 */

// #include "HLBG_AIO_Handlers.cpp"
#include "WorldSessionMgr.h"
#include "Chat/Chat.h"
#include "Log.h"

class HinterlandBattlegroundIntegration
{
public:
    static void OnBattlegroundStart(uint32 instanceId, uint32 affixId)
    {
        /* Legacy DB call - table removed
        CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_HLBG_BATTLE_START);
        stmt->SetData(0, affixId);
        stmt->SetData(1, instanceId);
        // Execute prepared statement (CharacterDatabase::Execute returns void)
        CharacterDatabase.Execute(stmt);
        */
        BroadcastBattleStart(affixId);
        LOG_INFO("hlbg", "Hinterland BG started - Instance: {}, Affix: {}", instanceId, affixId);
    }

    static void OnBattlegroundEnd(uint32 instanceId, const std::string& winner, uint32 allianceResources, uint32 hordeResources, uint32 duration, uint32 affixId)
    {
        /* Legacy DB calls - table removed
        CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_BATTLE_END);
        stmt->SetData(0, winner);
        stmt->SetData(1, duration);
        stmt->SetData(2, allianceResources);
        stmt->SetData(3, hordeResources);
        stmt->SetData(4, instanceId);
        // Execute prepared statement
        CharacterDatabase.Execute(stmt);

        uint32 alliancePlayers = GetPlayerCountInBG(instanceId, ALLIANCE);
        uint32 hordePlayers = GetPlayerCountInBG(instanceId, HORDE);

        CharacterDatabasePreparedStatement* stmt2 = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_BATTLE_PLAYERS);
        stmt2->SetData(0, alliancePlayers);
        stmt2->SetData(1, hordePlayers);
        stmt2->SetData(2, instanceId);
        CharacterDatabase.Execute(stmt2);
        */
        uint32 alliancePlayers = GetPlayerCountInBG(instanceId, ALLIANCE);
        uint32 hordePlayers = GetPlayerCountInBG(instanceId, HORDE);

        // HLBGAIOHandlers::UpdateBattleResults(winner, duration, affixId, allianceResources, hordeResources, alliancePlayers, hordePlayers);
        UpdatePlayerStatistics(instanceId, winner);
    }

    static void BroadcastLiveStatus(uint32 allianceResources, uint32 hordeResources, uint32 affixId, uint32 timeRemaining)
    {
        #ifdef HAS_AIO
        WorldSessionMgr::SessionMap const& sessions = sWorldSessionMgr->GetAllSessions();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
        {
            if (WorldSession* sess = itr->second)
            {
                Player* player = sess->GetPlayer();
                if (!player || !player->IsInWorld())
                    continue;

                AioPacket data;
                data.WriteU32(allianceResources);
                data.WriteU32(hordeResources);
                data.WriteU32(affixId);
                data.WriteU32(timeRemaining);

                AIO().Handle(player, "HLBG", "Status", data);
            }
        }
        #else
        // AIO not available: nothing to broadcast
        (void)allianceResources; (void)hordeResources; (void)affixId; (void)timeRemaining;
        #endif
    }

    static void OnPlayerEnterBG(Player* player, uint32 instanceId)
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

        SendBattleStatusToPlayer(player, instanceId);
    }

    static void OnPlayerKill(Player* killer, Player* victim, uint32 instanceId)
    {
        if (!killer || !victim)
            return;

        uint32 killerGuid = killer->GetGUID().GetCounter();
        uint32 victimGuid = victim->GetGUID().GetCounter();

        CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_PLAYER_KILLS);
        stmt->SetData(0, killerGuid);
        CharacterDatabase.Execute(stmt);

        CharacterDatabasePreparedStatement* stmt2 = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_PLAYER_DEATHS);
        stmt2->SetData(0, victimGuid);
        CharacterDatabase.Execute(stmt2);

        /* Legacy DB call
        CharacterDatabasePreparedStatement* stmt3 = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_STATISTICS_KILLS);
        CharacterDatabase.Execute(stmt3);
        */
        // instanceId not used in this integration shim; mark explicitly to avoid warnings
        (void)instanceId;
    }

    static void OnResourceCapture(Player* player, uint32 resourceAmount, uint32 instanceId)
    {
        if (!player)
            return;

        uint32 playerGuid = player->GetGUID().GetCounter();
        CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_PLAYER_RESOURCES);
        stmt->SetData(0, resourceAmount);
        stmt->SetData(1, playerGuid);
        CharacterDatabase.Execute(stmt);
        // instanceId not used here in this shim; avoid unused-parameter warning
        (void)instanceId;
    }

private:
    static void BroadcastBattleStart(uint32 affixId)
    {
        WorldSessionMgr::SessionMap const& sessions = sWorldSessionMgr->GetAllSessions();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
        {
            if (WorldSession* sess = itr->second)
            {
                Player* player = sess->GetPlayer();
                if (!player || !player->IsInWorld())
                    continue;

                ChatHandler(player->GetSession()).PSendSysMessage("Hinterland Battleground has started with affix {}!", affixId);
            }
        }
    }

    static void UpdatePlayerStatistics(uint32 /*instanceId*/, const std::string& /*winner*/)
    {
        /* Legacy DB calls - table removed
        if (winner == "Alliance")
        {
            CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_ALLIANCE_WINS);
            stmt->SetData(0, instanceId);
            CharacterDatabase.Execute(stmt);
        }
        else if (winner == "Horde")
        {
            CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_HORDE_WINS);
            stmt->SetData(0, instanceId);
            CharacterDatabase.Execute(stmt);
        }

        CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_HLBG_PARTICIPANT_COUNT);
        stmt->SetData(0, instanceId);
        PreparedQueryResult result = CharacterDatabase.Query(stmt);
        if (result)
        {
            uint32 participantCount = result->Fetch()[0].Get<uint32>();
            CharacterDatabasePreparedStatement* stmt2 = CharacterDatabase.GetPreparedStatement(CHAR_UPD_HLBG_TOTAL_PARTICIPANTS);
            stmt2->SetData(0, participantCount);
            CharacterDatabase.Execute(stmt2);
        }
        else
        {
            LOG_ERROR("hlbg", "Failed to query participant count for instance {}", instanceId);
        }
        */
    }

    static void SendBattleStatusToPlayer(Player* player, uint32 instanceId)
    {
        #ifdef HAS_AIO
        uint32 allianceResources = GetCurrentAllianceResources(instanceId);
        uint32 hordeResources = GetCurrentHordeResources(instanceId);
        uint32 affixId = GetCurrentAffix(instanceId);
        uint32 timeRemaining = GetBattleTimeRemaining(instanceId);

        AioPacket data;
        data.WriteU32(allianceResources);
        data.WriteU32(hordeResources);
        data.WriteU32(affixId);
        data.WriteU32(timeRemaining);

        AIO().Handle(player, "HLBG", "Status", data);
        #else
        // AIO not available: nothing to send
        (void)player; (void)instanceId;
        #endif
    }

    static uint32 GetPlayerCountInBG(uint32 instanceId, uint32 team) { (void)instanceId; (void)team; return 0; }
    static uint32 GetCurrentAllianceResources(uint32 instanceId) { (void)instanceId; return 0; }
    static uint32 GetCurrentHordeResources(uint32 instanceId) { (void)instanceId; return 0; }
    static uint32 GetCurrentAffix(uint32 instanceId) { (void)instanceId; return 0; }
    static uint32 GetBattleTimeRemaining(uint32 instanceId) { (void)instanceId; return 0; }
};
