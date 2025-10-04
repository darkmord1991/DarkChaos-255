/*
 * HLBG Battleground Integration Helper
 * Location: Integrate with your existing Hinterland BG system
 * 
 * This file shows how to integrate the database and AIO system with your existing battleground code
 */

#include "HLBG_AIO_Handlers.cpp" // Include the AIO handlers
#include "WorldSessionMgr.h"

class HinterlandBattlegroundIntegration
{
public:
    // Call this when your battleground starts
    static void OnBattlegroundStart(uint32 instanceId, uint32 affixId)
    {
        // Record battle start in database
        WorldDatabase.PExecute("INSERT INTO hlbg_battle_history (battle_start, affix_id, instance_id, map_id) VALUES (NOW(), {}, {}, 47)", affixId, instanceId);
        
        // Broadcast to all players that battle has started
        BroadcastBattleStart(affixId);
        
        LOG_INFO("hlbg", "Hinterland BG started - Instance: {}, Affix: {}", instanceId, affixId);
    }
    
    // Call this when your battleground ends
    static void OnBattlegroundEnd(uint32 instanceId, const std::string& winner, uint32 allianceResources, uint32 hordeResources, uint32 duration, uint32 affixId)
    {
        // Update the battle history record
        WorldDatabase.PExecute("UPDATE hlbg_battle_history SET battle_end = NOW(), winner_faction = '{}', duration_seconds = {}, alliance_resources = {}, horde_resources = {} WHERE instance_id = {} AND battle_end IS NULL", 
            winner, duration, allianceResources, hordeResources, instanceId);
        
        // Count participants
        uint32 alliancePlayers = GetPlayerCountInBG(instanceId, ALLIANCE);
        uint32 hordePlayers = GetPlayerCountInBG(instanceId, HORDE);
        
        // Update player counts in history
        WorldDatabase.PExecute("UPDATE hlbg_battle_history SET alliance_players = {}, horde_players = {} WHERE instance_id = {} AND battle_end IS NOT NULL ORDER BY id DESC LIMIT 1", 
            alliancePlayers, hordePlayers, instanceId);
        
        // Update comprehensive statistics using our AIO handler class
        HLBGAIOHandlers::UpdateBattleResults(winner, duration, affixId, allianceResources, hordeResources, alliancePlayers, hordePlayers);
        
        // Update individual player statistics
        UpdatePlayerStatistics(instanceId, winner);
        
        LOG_INFO("hlbg", "Hinterland BG ended - Winner: {}, Duration: {}s, A:{}/H:{}", winner, duration, allianceResources, hordeResources);
    }
    
    // Call this when GM manually resets battle
    static void OnManualReset(uint32 instanceId, const std::string& gmName)
    {
        // Record manual reset
        HLBGAIOHandlers::RecordManualReset(gmName);
        
        // Update battle history
        WorldDatabase.PExecute("UPDATE hlbg_battle_history SET battle_end = NOW(), winner_faction = 'Draw', ended_by_gm = 1, gm_name = '{}', notes = 'Manually reset by GM' WHERE instance_id = {} AND battle_end IS NULL", 
            gmName, instanceId);
    }
    
    // Call this periodically to send live battle status to players
    static void BroadcastLiveStatus(uint32 allianceResources, uint32 hordeResources, uint32 affixId, uint32 timeRemaining)
    {
            WorldSessionMgr::SessionMap const& sessions = sWorldSessionMgr->GetAllSessions();
        for (SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
        {
            if (Player* player = itr->second->GetPlayer())
            {
                if (player->IsInWorld())
                {
                    // Send live status via AIO
                    AioPacket data;
                    data.WriteU32(allianceResources);
                    data.WriteU32(hordeResources);
                    data.WriteU32(affixId);
                    data.WriteU32(timeRemaining);
                    
                    AIO().Handle(player, "HLBG", "Status", data);
                }
            }
        }
    }
    
    // Call this when a player joins the battleground
    static void OnPlayerEnterBG(Player* player, uint32 instanceId)
    {
        if (!player)
            return;
            
            uint32 playerGuid = player->GetGUID().GetCounter();
        std::string playerName = player->GetName();
        std::string faction = player->GetTeam() == ALLIANCE ? "Alliance" : "Horde";
        
        // Update or insert player statistics
        WorldDatabase.PExecute("INSERT INTO hlbg_player_stats (player_guid, player_name, faction, battles_participated, last_participation) VALUES ({}, '{}', '{}', 1, NOW()) ON DUPLICATE KEY UPDATE battles_participated = battles_participated + 1, last_participation = NOW()", 
            playerGuid, playerName, faction);
        
        // Send current battle status to the player
        SendBattleStatusToPlayer(player, instanceId);
        
        LOG_DEBUG("hlbg", "Player {} entered HLBG instance {}", playerName, instanceId);
    }
    
    // Call this when a player gets a kill in battleground
    static void OnPlayerKill(Player* killer, Player* victim, uint32 instanceId)
    {
        if (!killer || !victim)
            return;
            
            uint32 killerGuid = killer->GetGUID().GetCounter();
            uint32 victimGuid = victim->GetGUID().GetCounter();
        
        // Update killer statistics
        WorldDatabase.PExecute("UPDATE hlbg_player_stats SET total_kills = total_kills + 1 WHERE player_guid = {}", killerGuid);
        
        // Update victim statistics
        WorldDatabase.PExecute("UPDATE hlbg_player_stats SET total_deaths = total_deaths + 1 WHERE player_guid = {}", victimGuid);
        
        // Update global statistics
        WorldDatabase.Execute("UPDATE hlbg_statistics SET total_kills = total_kills + 1, total_deaths = total_deaths + 1");
    }
    
    // Call this when a player captures resources/objectives
    static void OnResourceCapture(Player* player, uint32 resourceAmount, uint32 instanceId)
    {
        if (!player)
            return;
            
            uint32 playerGuid = player->GetGUID().GetCounter();
        
        // Update player statistics
        WorldDatabase.PExecute("UPDATE hlbg_player_stats SET resources_captured = resources_captured + {} WHERE player_guid = {}", resourceAmount, playerGuid);
    }

private:
    static void BroadcastBattleStart(uint32 affixId)
    {
        // Notify all players that battle has started
        SessionMap const& sessions = sWorld->GetAllSessions();
        for (SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
        {
            if (Player* player = itr->second->GetPlayer())
            {
                if (player->IsInWorld())
                {
                    // You could send a chat message or AIO notification
                    ChatHandler(player->GetSession()).PSendSysMessage("Hinterland Battleground has started with affix {}!", affixId);
                }
            }
        }
    }
    
    static void UpdatePlayerStatistics(uint32 instanceId, const std::string& winner)
    {
        // Get all players who participated in this battle
        // This depends on how you track players in your BG system
        
        // Update win statistics for participants
        if (winner == "Alliance")
        {
            WorldDatabase.PExecute("UPDATE hlbg_player_stats SET battles_won = battles_won + 1 WHERE player_guid IN (SELECT player_guid FROM your_bg_participants_table WHERE instance_id = {} AND faction = 'Alliance')", instanceId);
        }
        else if (winner == "Horde")
        {
            WorldDatabase.PExecute("UPDATE hlbg_player_stats SET battles_won = battles_won + 1 WHERE player_guid IN (SELECT player_guid FROM your_bg_participants_table WHERE instance_id = {} AND faction = 'Horde')", instanceId);
        }
        
        // Update total participants count
        QueryResult result = WorldDatabase.PQuery("SELECT COUNT(DISTINCT player_guid) FROM your_bg_participants_table WHERE instance_id = {}", instanceId);
        if (result)
        {
            uint32 participantCount = result->Fetch()[0].GetUInt32();
            WorldDatabase.PExecute("UPDATE hlbg_statistics SET total_players_participated = total_players_participated + {}", participantCount);
        }
    }
    
    static void SendBattleStatusToPlayer(Player* player, uint32 instanceId)
    {
        // Get current battle status and send to player
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
    }
    
    // These functions need to be implemented based on your existing BG system
    static uint32 GetPlayerCountInBG(uint32 instanceId, uint32 team) { return 0; } // TODO: Implement
    static uint32 GetCurrentAllianceResources(uint32 instanceId) { return 0; }     // TODO: Implement
    static uint32 GetCurrentHordeResources(uint32 instanceId) { return 0; }        // TODO: Implement
    static uint32 GetCurrentAffix(uint32 instanceId) { return 0; }                 // TODO: Implement
    static uint32 GetBattleTimeRemaining(uint32 instanceId) { return 0; }          // TODO: Implement
};

/*
 * Example integration points in your existing battleground code:
 * 
 * In your battleground start function:
 * HinterlandBattlegroundIntegration::OnBattlegroundStart(GetInstanceId(), GetCurrentAffix());
 * 
 * In your battleground end function:
 * HinterlandBattlegroundIntegration::OnBattlegroundEnd(GetInstanceId(), winner, allianceRes, hordeRes, duration, affixId);
 * 
 * In your player join function:
 * HinterlandBattlegroundIntegration::OnPlayerEnterBG(player, GetInstanceId());
 * 
 * In your PvP kill handler:
 * HinterlandBattlegroundIntegration::OnPlayerKill(killer, victim, GetInstanceId());
 * 
 * In your resource capture handler:
 * HinterlandBattlegroundIntegration::OnResourceCapture(player, amount, GetInstanceId());
 * 
 * In your periodic update (every 5-10 seconds):
 * HinterlandBattlegroundIntegration::BroadcastLiveStatus(allianceRes, hordeRes, affixId, timeLeft);
 */
