/*
 * Dark Chaos - Hinterland BG Unified Addon Handler
 *
 * Consolidated handler providing:
 * - Real-time BG status updates (queue, preparation, active, ended)
 * - Live resource tracking and objective updates
 * - Team scores, timers, and affix information
 * - Leaderboard data (seasonal player rankings - 7 types)
 * - Player personal stats (seasonal statistics)
 * - All-time career statistics
 * - Match end notifications with rewards
 *
 * Uses DCAddonProtocol for efficient binary + JSON communication.
 * Replaces old AIO-only handlers. Unified schema compatible.
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "Config.h"
#include "Log.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "StringFormat.h"
#include "DCAddonNamespace.h"

namespace DCAddon
{
namespace HLBG
{
    // =====================================================================
    // ENUMS & STRUCTURES
    // =====================================================================
    
    // BG Status values
    enum HLBGStatus : uint8
    {
        STATUS_NONE   = 0,
        STATUS_QUEUED = 1,
        STATUS_PREP   = 2, // Preparation countdown
        STATUS_ACTIVE = 3,
        STATUS_ENDED  = 4,
    };

    // Client message opcodes
    enum ClientOpcodes : uint8
    {
        CMSG_REQUEST_STATUS         = 0x00,
        CMSG_REQUEST_RESOURCES      = 0x01,
        CMSG_REQUEST_OBJECTIVE      = 0x02,
        CMSG_QUICK_QUEUE            = 0x03,
        CMSG_LEAVE_QUEUE            = 0x04,
        CMSG_REQUEST_STATS          = 0x05,
        CMSG_GET_LEADERBOARD        = 0x06,
        CMSG_GET_PLAYER_STATS       = 0x07,
        CMSG_GET_ALLTIME_STATS      = 0x08,
    };
    
    // Server message opcodes
    enum ServerOpcodes : uint8
    {
        SMSG_STATUS                 = 0x10,
        SMSG_RESOURCES              = 0x11,
        SMSG_QUEUE_UPDATE           = 0x12,
        SMSG_TIMER_SYNC             = 0x13,
        SMSG_TEAM_SCORE             = 0x14,
        SMSG_AFFIX_INFO             = 0x15,
        SMSG_MATCH_END              = 0x16,
        SMSG_OBJECTIVE              = 0x17,
        SMSG_LEADERBOARD_DATA       = 0x18,
        SMSG_PLAYER_STATS           = 0x19,
        SMSG_ALLTIME_STATS          = 0x1A,
        SMSG_ERROR                  = 0x1F,
    };

    // Leaderboard entry structure
    struct LeaderboardEntry
    {
        uint32 rank;
        std::string playerName;
        uint32 playerGuid;
        uint32 score;
        uint32 extra;  // Wins, games, K/D, etc depending on type
    };

    // Configuration
    static bool s_enabled = true;

    void LoadConfig()
    {
        s_enabled = sConfigMgr->GetOption<bool>("DC.Addon.HLBG.Enable", true);
    }

    // =====================================================================
    // BINARY MESSAGE HELPERS - Real-time BG updates
    // =====================================================================
    
    void SendStatus(Player* player, HLBGStatus status, uint32 mapId, uint32 timeRemaining)
    {
        Message msg(Module::HINTERLAND, SMSG_STATUS);
        msg.Add(static_cast<uint8>(status));
        msg.Add(mapId);
        msg.Add(timeRemaining);
        msg.Send(player);
    }

    void SendResources(Player* player, uint32 allianceRes, uint32 hordeRes,
                       uint32 allianceBases, uint32 hordeBases)
    {
        Message msg(Module::HINTERLAND, SMSG_RESOURCES);
        msg.Add(allianceRes);
        msg.Add(hordeRes);
        msg.Add(allianceBases);
        msg.Add(hordeBases);
        msg.Send(player);
    }

    void SendQueueUpdate(Player* player, uint8 queueStatus, uint32 position, uint32 estimatedTime)
    {
        Message msg(Module::HINTERLAND, SMSG_QUEUE_UPDATE);
        msg.Add(queueStatus);
        msg.Add(position);
        msg.Add(estimatedTime);
        msg.Send(player);
    }

    void SendTimerSync(Player* player, uint32 elapsedMs, uint32 maxMs)
    {
        Message msg(Module::HINTERLAND, SMSG_TIMER_SYNC);
        msg.Add(elapsedMs);
        msg.Add(maxMs);
        msg.Send(player);
    }

    void SendTeamScore(Player* player, uint32 allianceScore, uint32 hordeScore,
                       uint32 allianceKills, uint32 hordeKills)
    {
        Message msg(Module::HINTERLAND, SMSG_TEAM_SCORE);
        msg.Add(allianceScore);
        msg.Add(hordeScore);
        msg.Add(allianceKills);
        msg.Add(hordeKills);
        msg.Send(player);
    }

    void SendAffixInfo(Player* player, uint32 affixId1, uint32 affixId2, uint32 affixId3, uint32 seasonId)
    {
        Message msg(Module::HINTERLAND, SMSG_AFFIX_INFO);
        msg.Add(affixId1);
        msg.Add(affixId2);
        msg.Add(affixId3);
        msg.Add(seasonId);
        msg.Send(player);
    }

    void SendMatchEnd(Player* player, bool victory, uint32 personalScore, uint32 honorGained,
                      uint32 reputationGained, uint32 tokensGained)
    {
        Message msg(Module::HINTERLAND, SMSG_MATCH_END);
        msg.Add(victory);
        msg.Add(personalScore);
        msg.Add(honorGained);
        msg.Add(reputationGained);
        msg.Add(tokensGained);
        msg.Send(player);
    }

    // =====================================================================
    // UNIFIED SCHEMA LEADERBOARD QUERIES
    // =====================================================================
    
    /**
     * Query seasonal player leaderboard from materialized views
     * Uses v_hlbg_player_seasonal_stats for all 7 leaderboard types
     */
    static bool QuerySeasonalLeaderboard(
        uint32 leaderboardType,
        uint32 season,
        uint32 limit,
        std::vector<LeaderboardEntry>& outEntries,
        std::string& outError)
    {
        std::string query;
        
        // Map leaderboard type to SQL query
        switch (leaderboardType)
        {
            case 1:  // RATING
                query = Acore::StringFormat(
                    "SELECT guid, player_name, current_rating, wins "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u "
                    "ORDER BY current_rating DESC LIMIT %u",
                    season, limit);
                break;
                
            case 2:  // WINS
                query = Acore::StringFormat(
                    "SELECT guid, player_name, wins, games_played "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u "
                    "ORDER BY wins DESC LIMIT %u",
                    season, limit);
                break;
                
            case 3:  // WINRATE
                query = Acore::StringFormat(
                    "SELECT guid, player_name, CAST(win_rate * 100 AS UNSIGNED), games_played "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u AND games_played >= 5 "
                    "ORDER BY win_rate DESC LIMIT %u",
                    season, limit);
                break;
                
            case 4:  // GAMES PLAYED
                query = Acore::StringFormat(
                    "SELECT guid, player_name, games_played, wins "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u "
                    "ORDER BY games_played DESC LIMIT %u",
                    season, limit);
                break;
                
            case 5:  // KILLS
                query = Acore::StringFormat(
                    "SELECT guid, player_name, total_kills, avg_kills_per_game "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u "
                    "ORDER BY total_kills DESC LIMIT %u",
                    season, limit);
                break;
                
            case 6:  // RESOURCES CAPTURED
                query = Acore::StringFormat(
                    "SELECT guid, player_name, total_resources_captured, games_played "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u "
                    "ORDER BY total_resources_captured DESC LIMIT %u",
                    season, limit);
                break;
                
            case 7:  // K/D RATIO
                query = Acore::StringFormat(
                    "SELECT guid, player_name, CAST(kd_ratio * 100 AS UNSIGNED), games_played "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u AND total_deaths > 0 "
                    "ORDER BY kd_ratio DESC LIMIT %u",
                    season, limit);
                break;
                
            default:
                outError = "Invalid leaderboard type";
                return false;
        }
        
        // Execute query
        QueryResult result = CharacterDatabase.Query(query);
        if (!result)
        {
            outError = "No data available";
            return false;
        }
        
        uint32 rank = 1;
        do
        {
            Field* fields = result->Fetch();
            
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.playerGuid = fields[0].Get<uint32>();
            entry.playerName = fields[1].Get<std::string>();
            entry.score = fields[2].Get<uint32>();
            entry.extra = fields[3].Get<uint32>();
            
            outEntries.push_back(entry);
        } while (result->NextRow());
        
        return true;
    }
    
    /**
     * Query player's seasonal statistics from unified schema view
     */
    static bool QueryPlayerSeasonalStats(
        Player* player,
        uint32 season,
        std::string& outJson,
        std::string& outError)
    {
        if (!player)
        {
            outError = "Invalid player";
            return false;
        }
        
        uint32 playerGuid = player->GetGUID().GetCounter();
        
        std::string query = Acore::StringFormat(
            "SELECT "
            "IFNULL(current_rating, 0), "
            "IFNULL(wins, 0), "
            "IFNULL(losses, 0), "
            "IFNULL(games_played, 0), "
            "IFNULL(win_rate, 0), "
            "IFNULL(total_kills, 0), "
            "IFNULL(total_deaths, 0), "
            "IFNULL(kd_ratio, 0), "
            "IFNULL(avg_kills_per_game, 0), "
            "IFNULL(avg_damage_per_game, 0) "
            "FROM `v_hlbg_player_seasonal_stats` "
            "WHERE guid = %u AND season_id = %u",
            playerGuid, season);
        
        QueryResult result = CharacterDatabase.Query(query);
        if (!result)
        {
            // Return zero stats
            outJson = "{"
                "\"rating\":0,\"wins\":0,\"losses\":0,\"games\":0,"
                "\"winRate\":0,\"kills\":0,\"deaths\":0,\"kdRatio\":0,"
                "\"avgKills\":0,\"avgDamage\":0"
                "}";
            return true;
        }
        
        Field* fields = result->Fetch();
        
        outJson = Acore::StringFormat(
            "{"
            "\"rating\":%d,"
            "\"wins\":%u,"
            "\"losses\":%u,"
            "\"games\":%u,"
            "\"winRate\":%.2f,"
            "\"kills\":%u,"
            "\"deaths\":%u,"
            "\"kdRatio\":%.2f,"
            "\"avgKills\":%.2f,"
            "\"avgDamage\":%.0f"
            "}",
            fields[0].Get<int32>(),
            fields[1].Get<uint32>(),
            fields[2].Get<uint32>(),
            fields[3].Get<uint32>(),
            fields[4].Get<float>(),
            fields[5].Get<uint32>(),
            fields[6].Get<uint32>(),
            fields[7].Get<float>(),
            fields[8].Get<float>(),
            fields[9].Get<float>());
        
        return true;
    }
    
    /**
     * Query player's all-time statistics from unified schema view
     */
    static bool QueryPlayerAllTimeStats(
        Player* player,
        std::string& outJson,
        std::string& outError)
    {
        if (!player)
        {
            outError = "Invalid player";
            return false;
        }
        
        uint32 playerGuid = player->GetGUID().GetCounter();
        
        std::string query = Acore::StringFormat(
            "SELECT "
            "IFNULL(total_matches, 0), "
            "IFNULL(lifetime_wins, 0), "
            "IFNULL(lifetime_losses, 0), "
            "IFNULL(lifetime_kills, 0), "
            "IFNULL(lifetime_deaths, 0), "
            "IFNULL(lifetime_kd_ratio, 0), "
            "IFNULL(avg_kills_career, 0), "
            "IFNULL(avg_damage_career, 0) "
            "FROM `v_hlbg_player_alltime_stats` "
            "WHERE guid = %u",
            playerGuid);
        
        QueryResult result = CharacterDatabase.Query(query);
        if (!result)
        {
            // Return zero stats
            outJson = "{"
                "\"totalMatches\":0,\"lifetimeWins\":0,\"lifetimeLosses\":0,"
                "\"lifetimeKills\":0,\"lifetimeDeaths\":0,\"kdRatio\":0,"
                "\"avgKills\":0,\"avgDamage\":0"
                "}";
            return true;
        }
        
        Field* fields = result->Fetch();
        
        outJson = Acore::StringFormat(
            "{"
            "\"totalMatches\":%u,"
            "\"lifetimeWins\":%u,"
            "\"lifetimeLosses\":%u,"
            "\"lifetimeKills\":%u,"
            "\"lifetimeDeaths\":%u,"
            "\"kdRatio\":%.2f,"
            "\"avgKills\":%.2f,"
            "\"avgDamage\":%.0f"
            "}",
            fields[0].Get<uint32>(),
            fields[1].Get<uint32>(),
            fields[2].Get<uint32>(),
            fields[3].Get<uint32>(),
            fields[4].Get<uint32>(),
            fields[5].Get<float>(),
            fields[6].Get<float>(),
            fields[7].Get<float>());
        
        return true;
    }

    // =====================================================================
    // MESSAGE HANDLERS
    // =====================================================================
    
    // Real-time BG status handlers
    static void HandleRequestStatus(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        uint32 mapId = player->GetMapId();

        // Check if player is in HLBG instance
        if (mapId == 47) // Hinterlands zone
        {
            // TODO: Get actual BG instance data from your HLBG system
            SendStatus(player, STATUS_ACTIVE, mapId, 0);
        }
        else
        {
            SendStatus(player, STATUS_NONE, 0, 0);
        }
    }

    static void HandleRequestResources(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        // TODO: Get actual resource data from your HLBG system
        SendResources(player, 0, 0, 0, 0);
    }

    static void HandleRequestObjective(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        // TODO: Query objective status from HLBG system
    }

    static void HandleQuickQueue(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        ChatHandler handler(player->GetSession());
        handler.ParseCommands(".hlbg queue");
        SendQueueUpdate(player, 1, 0, 0);
    }

    static void HandleLeaveQueue(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        ChatHandler handler(player->GetSession());
        handler.ParseCommands(".hlbg leave");
        SendQueueUpdate(player, 0, 0, 0);
    }

    static void HandleRequestStats(Player* player, const ParsedMessage& msg)
    {
        if (!player) return;
        uint32 seasonId = msg.GetUInt32(0);
        
        // Query from unified schema
        std::string statsJson;
        std::string error;
        if (!QueryPlayerSeasonalStats(player, seasonId, statsJson, error))
        {
            Message response(Module::HINTERLAND, SMSG_ERROR);
            response.Add(error);
            response.Send(player);
            return;
        }
        
        Message response(Module::HINTERLAND, SMSG_PLAYER_STATS);
        response.Add(statsJson);
        response.Send(player);
    }

    // Leaderboard and stats handlers
    static void HandleGetLeaderboard(Player* player, const ParsedMessage& msg)
    {
        std::string data = msg.GetString(0);
        if (!player) return;
        
        uint32 leaderboardType = 1;
        uint32 season = 0;
        uint32 limit = 100;
        
        // Simple JSON parsing for request parameters
        if (data.find("\"leaderboardType\"") != std::string::npos)
        {
            int val = 0;
            if (sscanf(data.c_str(), "\"leaderboardType\":%d", &val) == 1)
                leaderboardType = val;
        }
        if (data.find("\"season\"") != std::string::npos)
        {
            int val = 0;
            if (sscanf(data.c_str(), "\"season\":%d", &val) == 1)
                season = val;
        }
        if (data.find("\"limit\"") != std::string::npos)
        {
            int val = 100;
            if (sscanf(data.c_str(), "\"limit\":%d", &val) == 1)
                limit = val;
        }
        
        // Query leaderboard
        std::vector<LeaderboardEntry> entries;
        std::string error;
        
        if (!QuerySeasonalLeaderboard(leaderboardType, season, limit, entries, error))
        {
            Message packet(Module::HINTERLAND, SMSG_ERROR);
            packet.Add(error);
            packet.Send(player);
            return;
        }
        
        // Build JSON response
        std::string jsonEntries = "[";
        for (size_t i = 0; i < entries.size(); ++i)
        {
            if (i > 0) jsonEntries += ",";
            
            jsonEntries += Acore::StringFormat(
                "{\"rank\":%u,\"guid\":%u,\"name\":\"%s\",\"score\":%u,\"extra\":%u}",
                entries[i].rank,
                entries[i].playerGuid,
                entries[i].playerName.c_str(),
                entries[i].score,
                entries[i].extra);
        }
        jsonEntries += "]";
        
        std::string response = Acore::StringFormat(
            "{\"leaderboardType\":%u,\"season\":%u,\"entries\":%s}",
            leaderboardType,
            season,
            jsonEntries.c_str());
        
        Message packet(Module::HINTERLAND, SMSG_LEADERBOARD_DATA);
        packet.Add(response);
        packet.Send(player);
    }

    static void HandleGetPlayerStats(Player* player, const ParsedMessage& msg)
    {
        std::string data = msg.GetString(0);
        if (!player) return;
        
        uint32 season = 0;
        if (data.find("\"season\"") != std::string::npos)
        {
            int val = 0;
            if (sscanf(data.c_str(), "\"season\":%d", &val) == 1)
                season = val;
        }
        
        std::string statsJson;
        std::string error;
        
        if (!QueryPlayerSeasonalStats(player, season, statsJson, error))
        {
            Message packet(Module::HINTERLAND, SMSG_ERROR);
            packet.Add(error);
            packet.Send(player);
            return;
        }
        
        Message packet(Module::HINTERLAND, SMSG_PLAYER_STATS);
        packet.Add(statsJson);
        packet.Send(player);
    }

    static void HandleGetAllTimeStats(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        
        std::string statsJson;
        std::string error;
        
        if (!QueryPlayerAllTimeStats(player, statsJson, error))
        {
            Message msg(Module::HINTERLAND, SMSG_ERROR);
            msg.Add(error);
            msg.Send(player);
            return;
        }
        
        Message msg(Module::HINTERLAND, SMSG_ALLTIME_STATS);
        msg.Add(statsJson);
        msg.Send(player);
    }

    // =====================================================================
    // HANDLER REGISTRATION
    // =====================================================================
    
    void RegisterHandlers()
    {
        // Real-time BG handlers
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_REQUEST_STATUS, HandleRequestStatus);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_REQUEST_RESOURCES, HandleRequestResources);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_REQUEST_OBJECTIVE, HandleRequestObjective);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_QUICK_QUEUE, HandleQuickQueue);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_LEAVE_QUEUE, HandleLeaveQueue);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_REQUEST_STATS, HandleRequestStats);
        
        // Leaderboard and stats handlers (JSON-based)
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_GET_LEADERBOARD, HandleGetLeaderboard);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_GET_PLAYER_STATS, HandleGetPlayerStats);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_GET_ALLTIME_STATS, HandleGetAllTimeStats);

        LOG_INFO("dc.addon", "HLBG unified handler registered with %s support", 
            "real-time + leaderboards + unified schema");
    }

}  // namespace HLBG
}  // namespace DCAddon

// Register the unified HLBG addon handler
void AddSC_dc_addon_hlbg()
{
    DCAddon::HLBG::RegisterHandlers();
}
