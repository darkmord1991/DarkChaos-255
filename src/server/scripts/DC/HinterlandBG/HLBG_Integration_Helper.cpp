/*
 * HLBG Battleground Integration Helper
 * Location: src/server/scripts/DC/HinterlandBG/HLBG_Integration_Helper.cpp
 * 
 * This file shows how to integrate the database and AIO system with your existing battleground code
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "World.h"
#include "WorldSessionMgr.h"
#include "Log.h"
#ifdef HAS_AIO
#include "AIO.h"
#endif

class HinterlandBattlegroundIntegration
{
public:
    // Call this when your battleground starts
    static void OnBattlegroundStart(uint32 instanceId, uint32 affixId)
    {
        // Record battle start in database
        WorldDatabase.Execute("INSERT INTO hlbg_battle_history (battle_start, affix_id, instance_id, map_id) VALUES (NOW(), {}, {}, 47)", affixId, instanceId);
        
        // Broadcast to all players that battle has started
        BroadcastBattleStart(affixId);
        
        LOG_INFO("hlbg", "Hinterland BG started - Instance: {}, Affix: {}", instanceId, affixId);
    }
    
    // Call this when your battleground ends
    static void OnBattlegroundEnd(uint32 instanceId, const std::string& winner, uint32 allianceResources, uint32 hordeResources, uint32 duration, uint32 affixId)
    {
        // Update the battle history record
        WorldDatabase.Execute("UPDATE hlbg_battle_history SET battle_end = NOW(), winner_faction = '{}', duration_seconds = {}, alliance_resources = {}, horde_resources = {} WHERE instance_id = {} AND battle_end IS NULL", 
            winner, duration, allianceResources, hordeResources, instanceId);
        
        // Count participants
        uint32 alliancePlayers = GetPlayerCountInBG(instanceId, ALLIANCE);
        uint32 hordePlayers = GetPlayerCountInBG(instanceId, HORDE);
        
        // Update player counts in history
        WorldDatabase.Execute("UPDATE hlbg_battle_history SET alliance_players = {}, horde_players = {} WHERE instance_id = {} AND battle_end IS NOT NULL ORDER BY id DESC LIMIT 1", 
            alliancePlayers, hordePlayers, instanceId);
        
        // Update comprehensive statistics using our AIO handler class
        UpdateBattleResults(winner, duration, affixId, allianceResources, hordeResources, alliancePlayers, hordePlayers);
        
        // Update individual player statistics
        UpdatePlayerStatistics(instanceId, winner);
        
        LOG_INFO("hlbg", "Hinterland BG ended - Winner: {}, Duration: {}s, A:{}/H:{}", winner, duration, allianceResources, hordeResources);
    }
    
    // Call this when GM manually resets battle
    static void OnManualReset(uint32 instanceId, const std::string& gmName)
    {
        // Record manual reset
        RecordManualReset(gmName);
        
        // Update battle history
        WorldDatabase.Execute("UPDATE hlbg_battle_history SET battle_end = NOW(), winner_faction = 'Draw', ended_by_gm = 1, gm_name = '{}', notes = 'Manually reset by GM' WHERE instance_id = {} AND battle_end IS NULL", 
            gmName, instanceId);
    }
    
    // Call this periodically to send live battle status to players
    static void BroadcastLiveStatus(uint32 allianceResources, uint32 hordeResources, uint32 affixId, uint32 timeRemaining)
    {
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
        {
            if (Player* player = itr->second->GetPlayer())
            {
                if (player->IsInWorld())
                {
                    // Send live status via AIO if available
#ifdef HAS_AIO
                    AioPacket data;
                    data.WriteU32(allianceResources);
                    data.WriteU32(hordeResources);
                    data.WriteU32(affixId);
                    data.WriteU32(timeRemaining);
                    
                    AIO().Handle(player, "HLBG", "Status", data);
#else
                    // AIO not available: optionally send a chat message as fallback
                    ChatHandler(player->GetSession()).PSendSysMessage("HLBG status: A:%u H:%u Affix:%u Time:%u", allianceResources, hordeResources, affixId, timeRemaining);
#endif
                }
            }
        }
    }
    
    // Call this when a player joins the battleground
    static void OnPlayerEnterBG(Player* player, uint32 instanceId)
    {
        if (!player)
            return;
            
        uint32 playerGuid = player->GetGUIDLow();
        std::string playerName = player->GetName();
        std::string faction = player->GetTeam() == ALLIANCE ? "Alliance" : "Horde";
        
        // Update or insert player statistics
        WorldDatabase.Execute("INSERT INTO hlbg_player_stats (player_guid, player_name, faction, battles_participated, last_participation) VALUES ({}, '{}', '{}', 1, NOW()) ON DUPLICATE KEY UPDATE battles_participated = battles_participated + 1, last_participation = NOW()", 
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
            
        uint32 killerGuid = killer->GetGUIDLow();
        uint32 victimGuid = victim->GetGUIDLow();
        
        // Update killer statistics
        WorldDatabase.Execute("UPDATE hlbg_player_stats SET total_kills = total_kills + 1 WHERE player_guid = {}", killerGuid);
        
        // Update victim statistics
        WorldDatabase.Execute("UPDATE hlbg_player_stats SET total_deaths = total_deaths + 1 WHERE player_guid = {}", victimGuid);
        
        // Update global statistics
        WorldDatabase.Execute("UPDATE hlbg_statistics SET total_kills = total_kills + 1, total_deaths = total_deaths + 1");
    }
    
    // Call this when a player captures resources/objectives
    static void OnResourceCapture(Player* player, uint32 resourceAmount, uint32 instanceId)
    {
        if (!player)
            return;
            
        uint32 playerGuid = player->GetGUIDLow();
        
        // Update player statistics
        WorldDatabase.Execute("UPDATE hlbg_player_stats SET resources_captured = resources_captured + {} WHERE player_guid = {}", resourceAmount, playerGuid);
    }

private:
    static void BroadcastBattleStart(uint32 affixId)
    {
        // Notify all players that battle has started
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
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
    
    static void UpdateBattleResults(const std::string& winner, uint32 duration, uint32 affix, uint32 allianceRes, uint32 hordeRes, uint32 alliancePlayers, uint32 hordePlayers)
    {
        // Update main statistics
        std::string updateQuery = "UPDATE hlbg_statistics SET total_runs = total_runs + 1";
        
        if (winner == "Alliance")
            updateQuery += ", alliance_wins = alliance_wins + 1";
        else if (winner == "Horde") 
            updateQuery += ", horde_wins = horde_wins + 1";
        else
            updateQuery += ", draws = draws + 1";
            
        // Update average run time
        updateQuery += ", avg_run_time_seconds = (avg_run_time_seconds + " + std::to_string(duration) + ") / 2";
        
        // Update shortest/longest runs
        updateQuery += ", shortest_run_seconds = CASE WHEN shortest_run_seconds = 0 OR " + std::to_string(duration) + " < shortest_run_seconds THEN " + std::to_string(duration) + " ELSE shortest_run_seconds END";
        updateQuery += ", longest_run_seconds = CASE WHEN " + std::to_string(duration) + " > longest_run_seconds THEN " + std::to_string(duration) + " ELSE longest_run_seconds END";
        
        WorldDatabase.Execute(updateQuery.c_str());
        
        // Update win streaks
        UpdateWinStreaks(winner);
        
        // Update affix usage
        WorldDatabase.Execute("UPDATE hlbg_affixes SET usage_count = usage_count + 1 WHERE id = {}", affix);
        
        LOG_INFO("hlbg", "Battle ended: {} won in {}s with affix {} (A:{} H:{})", 
            winner, duration, affix, allianceRes, hordeRes);
    }
    
    static void RecordManualReset(const std::string& gmName)
    {
        WorldDatabase.Execute("UPDATE hlbg_statistics SET manual_resets = manual_resets + 1, last_reset_by_gm = NOW(), last_reset_gm_name = '{}'", gmName);
        
        LOG_INFO("hlbg", "Battle manually reset by GM: {}", gmName);
    }
    
    static void UpdateWinStreaks(const std::string& winner)
    {
        QueryResult result = WorldDatabase.Query("SELECT current_streak_faction, current_streak_count, longest_streak_count FROM hlbg_statistics ORDER BY id DESC LIMIT 1");
        
        if (!result)
            return;
            
        Field* fields = result->Fetch();
        std::string currentFaction = fields[0].Get<std::string>();
        uint32 currentCount = fields[1].Get<uint32>();
        uint32 longestCount = fields[2].Get<uint32>();
        
        if (winner == "Draw")
        {
            // Reset current streak on draw
            WorldDatabase.Execute("UPDATE hlbg_statistics SET current_streak_faction = 'None', current_streak_count = 0");
        }
        else if (winner == currentFaction)
        {
            // Continue current streak
            uint32 newCount = currentCount + 1;
            std::string updateQuery = "UPDATE hlbg_statistics SET current_streak_count = " + std::to_string(newCount);
            
            if (newCount > longestCount)
            {
                updateQuery += ", longest_streak_faction = '" + winner + "', longest_streak_count = " + std::to_string(newCount);
            }
            
            WorldDatabase.Execute(updateQuery.c_str());
        }
        else
        {
            // Start new streak
            WorldDatabase.Execute("UPDATE hlbg_statistics SET current_streak_faction = '{}', current_streak_count = 1", winner);
        }
    }
    
    static void UpdatePlayerStatistics(uint32 instanceId, const std::string& winner)
    {
        // Get all players who participated in this battle
        // This depends on how you track players in your BG system
        
        // Update win statistics for participants
        if (winner == "Alliance")
        {
            // TODO: Update based on your participant tracking system
            // WorldDatabase.PExecute("UPDATE hlbg_player_stats SET battles_won = battles_won + 1 WHERE player_guid IN (SELECT player_guid FROM your_bg_participants_table WHERE instance_id = {} AND faction = 'Alliance')", instanceId);
        }
        else if (winner == "Horde")
        {
            // TODO: Update based on your participant tracking system
            // WorldDatabase.PExecute("UPDATE hlbg_player_stats SET battles_won = battles_won + 1 WHERE player_guid IN (SELECT player_guid FROM your_bg_participants_table WHERE instance_id = {} AND faction = 'Horde')", instanceId);
        }
    }
    
    static void SendBattleStatusToPlayer(Player* player, uint32 instanceId)
    {
        // Get current battle status and send to player
        uint32 allianceResources = GetCurrentAllianceResources(instanceId);
        uint32 hordeResources = GetCurrentHordeResources(instanceId);
        uint32 affixId = GetCurrentAffix(instanceId);
        uint32 timeRemaining = GetBattleTimeRemaining(instanceId);
        
    // Use AIO if available, otherwise send simple chat fallback
#ifdef HAS_AIO
    AioPacket data;
    data.WriteU32(allianceResources);
    data.WriteU32(hordeResources);
    data.WriteU32(affixId);
    data.WriteU32(timeRemaining);
        
    AIO().Handle(player, "HLBG", "Status", data);
#else
    ChatHandler(player->GetSession()).PSendSysMessage("HLBG status: A:%u H:%u Affix:%u Time:%u", allianceResources, hordeResources, affixId, timeRemaining);
#endif
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