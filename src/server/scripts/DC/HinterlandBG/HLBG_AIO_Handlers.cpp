/*
 * HLBG Server AIO Integration
 * Location: src/server/scripts/DC/HinterlandBG/HLBG_AIO_Handlers.cpp
 * 
 * AIO handlers for Hinterland Battleground real-time communication
 */

#include "AIO.h"
#include "Player.h"
#include "World.h"
#include "WorldSession.h"
#include "DatabaseEnv.h"
#include "Log.h"

class HLBGAIOHandlers
{
public:
    // Initialize all HLBG AIO handlers
    static void Initialize()
    {
        // Client request handlers
        AIO().AddHandlers("HLBG", {
            { "RequestServerConfig", &HandleRequestServerConfig },
            { "RequestSeasonInfo", &HandleRequestSeasonInfo },
            { "RequestStats", &HandleRequestStats },
            { "RequestHistory", &HandleRequestHistory },
            { "RequestStatus", &HandleRequestStatus }
        });
        
        LOG_INFO("server.loading", "HLBG AIO Handlers initialized");
    }

private:
    // Handler: Client requests server configuration
    static void HandleRequestServerConfig(Player* player, Aio* /*aio*/, AioPacket packet)
    {
        if (!player)
            return;

        QueryResult result = WorldDatabase.Query("SELECT duration_minutes, max_players_per_side, min_level, max_level, affix_rotation_enabled, resource_cap, queue_type, respawn_time_seconds, is_active FROM hlbg_config ORDER BY id DESC LIMIT 1");
        
        AioPacket data;
        if (result)
        {
            Field* fields = result->Fetch();
            data.WriteU32(fields[0].Get<uint32>()); // duration_minutes
            data.WriteU32(fields[1].Get<uint32>()); // max_players_per_side
            data.WriteU32(fields[2].Get<uint32>()); // min_level
            data.WriteU32(fields[3].Get<uint32>()); // max_level
            data.WriteBool(fields[4].Get<bool>());  // affix_rotation_enabled
            data.WriteU32(fields[5].Get<uint32>()); // resource_cap
            data.WriteString(fields[6].Get<std::string>()); // queue_type
            data.WriteU32(fields[7].Get<uint32>()); // respawn_time_seconds
            data.WriteBool(fields[8].Get<bool>());  // is_active
        }
        else
        {
            // Default values if no config found
            data.WriteU32(30);     // 30 minutes
            data.WriteU32(40);     // 40 players per side
            data.WriteU32(255);    // min level 255
            data.WriteU32(255);    // max level 255
            data.WriteBool(true);  // affix enabled
            data.WriteU32(500);    // 500 resource cap
            data.WriteString("Level255Only"); // queue type
            data.WriteU32(30);     // 30 second respawn
            data.WriteBool(true);  // is active
        }
        
        AIO().Handle(player, "HLBG", "ServerConfig", data);
        
        LOG_DEBUG("hlbg", "Sent server config to player {}", player->GetName());
    }

    // Handler: Client requests current season information
    static void HandleRequestSeasonInfo(Player* player, Aio* /*aio*/, AioPacket packet)
    {
        if (!player)
            return;

        QueryResult result = WorldDatabase.Query("SELECT name, start_date, end_date, description, rewards_alliance, rewards_horde FROM hlbg_seasons WHERE is_active = 1 ORDER BY id DESC LIMIT 1");
        
        AioPacket data;
        if (result)
        {
            Field* fields = result->Fetch();
            data.WriteString(fields[0].Get<std::string>()); // name
            data.WriteString(fields[1].Get<std::string>()); // start_date
            data.WriteString(fields[2].Get<std::string>()); // end_date  
            data.WriteString(fields[3].Get<std::string>()); // description
            data.WriteString(fields[4].Get<std::string>()); // rewards_alliance
            data.WriteString(fields[5].Get<std::string>()); // rewards_horde
        }
        else
        {
            data.WriteString("No Active Season");
            data.WriteString("Unknown");
            data.WriteString("Unknown");
            data.WriteString("No season currently configured");
            data.WriteString("None");
            data.WriteString("None");
        }
        
        AIO().Handle(player, "HLBG", "UpdateSeasonInfo", data);
        
        LOG_DEBUG("hlbg", "Sent season info to player {}", player->GetName());
    }

    // Handler: Client requests comprehensive statistics
    static void HandleRequestStats(Player* player, Aio* /*aio*/, AioPacket packet)
    {
        if (!player)
            return;

        QueryResult result = WorldDatabase.Query("SELECT total_runs, alliance_wins, horde_wins, draws, manual_resets, current_streak_faction, current_streak_count, longest_streak_faction, longest_streak_count, avg_run_time_seconds, shortest_run_seconds, longest_run_seconds, most_popular_affix, total_players_participated, total_kills, total_deaths, last_reset_by_gm, server_start_time FROM hlbg_statistics ORDER BY id DESC LIMIT 1");
        
        AioPacket data;
        if (result)
        {
            Field* fields = result->Fetch();
            data.WriteU32(fields[0].Get<uint32>());  // total_runs
            data.WriteU32(fields[1].Get<uint32>());  // alliance_wins
            data.WriteU32(fields[2].Get<uint32>());  // horde_wins
            data.WriteU32(fields[3].Get<uint32>());  // draws
            data.WriteU32(fields[4].Get<uint32>());  // manual_resets
            data.WriteString(fields[5].Get<std::string>()); // current_streak_faction
            data.WriteU32(fields[6].Get<uint32>());  // current_streak_count
            data.WriteString(fields[7].Get<std::string>()); // longest_streak_faction
            data.WriteU32(fields[8].Get<uint32>());  // longest_streak_count
            data.WriteU32(fields[9].Get<uint32>());  // avg_run_time_seconds
            data.WriteU32(fields[10].Get<uint32>()); // shortest_run_seconds
            data.WriteU32(fields[11].Get<uint32>()); // longest_run_seconds
            data.WriteU32(fields[12].Get<uint32>()); // most_popular_affix
            data.WriteU32(fields[13].Get<uint32>()); // total_players_participated
            data.WriteU32(fields[14].Get<uint32>()); // total_kills
            data.WriteU32(fields[15].Get<uint32>()); // total_deaths
            
            // Last reset info
            std::string lastReset = fields[16].IsNull() ? "Never" : fields[16].Get<std::string>();
            data.WriteString(lastReset);
            
            // Calculate server uptime in days
            time_t now = time(nullptr);
            time_t serverStart = fields[17].Get<uint32>();
            uint32 uptimeDays = (now - serverStart) / 86400;
            data.WriteU32(uptimeDays);
        }
        else
        {
            // Default empty stats
            for (int i = 0; i < 16; ++i)
                data.WriteU32(0);
            data.WriteString("Never");
            data.WriteU32(0); // uptime
        }
        
        AIO().Handle(player, "HLBG", "UpdateScoreboardStats", data);
        
        LOG_DEBUG("hlbg", "Sent statistics to player {}", player->GetName());
    }

    // Handler: Client requests battle history
    static void HandleRequestHistory(Player* player, Aio* /*aio*/, AioPacket packet)
    {
        if (!player)
            return;

        QueryResult result = WorldDatabase.Query("SELECT battle_end, winner_faction, duration_seconds, affix_id, alliance_resources, horde_resources, alliance_players, horde_players FROM hlbg_battle_history WHERE battle_end IS NOT NULL ORDER BY id DESC LIMIT 24");
        
        AioPacket data;
        uint32 count = 0;
        
        if (result)
        {
            count = result->GetRowCount();
            data.WriteU32(count);
            
            do
            {
                Field* fields = result->Fetch();
                data.WriteString(fields[0].Get<std::string>()); // battle_end (date)
                data.WriteString(fields[1].Get<std::string>()); // winner_faction
                data.WriteU32(fields[2].Get<uint32>());    // duration_seconds
                data.WriteU32(fields[3].Get<uint32>());    // affix_id
                data.WriteU32(fields[4].Get<uint32>());    // alliance_resources
                data.WriteU32(fields[5].Get<uint32>());    // horde_resources
                data.WriteU32(fields[6].Get<uint32>());    // alliance_players
                data.WriteU32(fields[7].Get<uint32>());    // horde_players
            } while (result->NextRow());
        }
        else
        {
            data.WriteU32(0); // No history available
        }
        
        AIO().Handle(player, "HLBG", "History", data);
        
        LOG_DEBUG("hlbg", "Sent {} history entries to player {}", count, player->GetName());
    }

    // Handler: Client requests current battle status
    static void HandleRequestStatus(Player* player, Aio* /*aio*/, AioPacket packet)
    {
        if (!player)
            return;

        // Get current battle status (you'll need to implement this based on your BG system)
        uint32 allianceResources = GetCurrentAllianceResources(); // TODO: Implement
        uint32 hordeResources = GetCurrentHordeResources();       // TODO: Implement  
        uint32 currentAffix = GetCurrentAffix();                  // TODO: Implement
        uint32 timeRemaining = GetBattleTimeRemaining();          // TODO: Implement
        
        AioPacket data;
        data.WriteU32(allianceResources);
        data.WriteU32(hordeResources);
        data.WriteU32(currentAffix);
        data.WriteU32(timeRemaining);
        
        AIO().Handle(player, "HLBG", "Status", data);
        
        LOG_DEBUG("hlbg", "Sent battle status to player {} (A:{} H:{} Affix:{} Time:{})", 
            player->GetName(), allianceResources, hordeResources, currentAffix, timeRemaining);
    }

public:
    // Call this when a battle ends to update statistics
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
        
        // Insert battle history record
        WorldDatabase.Execute("INSERT INTO hlbg_battle_history (battle_end, winner_faction, duration_seconds, affix_id, alliance_resources, horde_resources, alliance_players, horde_players) VALUES (NOW(), '{}', {}, {}, {}, {}, {}, {})",
            winner, duration, affix, allianceRes, hordeRes, alliancePlayers, hordePlayers);
        
        // Update win streaks
        UpdateWinStreaks(winner);
        
        // Update affix usage
        WorldDatabase.Execute("UPDATE hlbg_affixes SET usage_count = usage_count + 1 WHERE id = {}", affix);
        
        // Broadcast updated stats to all online players
        BroadcastStatsUpdate();
        
        LOG_INFO("hlbg", "Battle ended: {} won in {}s with affix {} (A:{} H:{})", 
            winner, duration, affix, allianceRes, hordeRes);
    }
    
    // Call this when GM manually resets a battle
    static void RecordManualReset(const std::string& gmName)
    {
        WorldDatabase.Execute("UPDATE hlbg_statistics SET manual_resets = manual_resets + 1, last_reset_by_gm = NOW(), last_reset_gm_name = '{}'", gmName);
        
        LOG_INFO("hlbg", "Battle manually reset by GM: {}", gmName);
    }

private:
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
    
    static void BroadcastStatsUpdate()
    {
        // Send updated stats to all online players who have HLBG UI open
        SessionMap const& sessions = sWorld->GetAllSessions();
        for (SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
        {
            if (Player* player = itr->second->GetPlayer())
            {
                if (player->IsInWorld())
                {
                    // Send fresh stats
                    HandleRequestStats(player, nullptr, AioPacket());
                }
            }
        }
    }
    
    // These functions need to be implemented based on your BG system
    static uint32 GetCurrentAllianceResources() { return 0; } // TODO: Implement
    static uint32 GetCurrentHordeResources() { return 0; }    // TODO: Implement  
    static uint32 GetCurrentAffix() { return 0; }             // TODO: Implement
    static uint32 GetBattleTimeRemaining() { return 0; }      // TODO: Implement
};

// Add this to your server initialization (e.g., in World.cpp or similar)
void InitializeHLBGHandlers()
{
    HLBGAIOHandlers::Initialize();
}