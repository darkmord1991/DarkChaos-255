/*
 * Dark Chaos - Unified Leaderboard Addon Handler
 * ===============================================
 * 
 * Server-side handler for the DC-Leaderboards addon.
 * Provides leaderboard data for all DC systems via DCAddonProtocol.
 * 
 * Supports:
 * - Mythic+ leaderboards (best key, best time, runs, score)
 * - Seasonal leaderboards (tokens, essence, points, level)
 * - Hinterland BG leaderboards (rating, wins, winrate, games)
 * - Prestige leaderboards (level, points, resets)
 * - Item Upgrade leaderboards (total, items, efficiency, tier)
 * - Duel leaderboards (wins, winrate, rating, streak)
 * - AOE Loot leaderboards (items, gold, skinned)
 * - Achievement leaderboards (points, completed)
 * 
 * Uses JSON protocol for all responses.
 * 
 * Copyright (C) 2025 DarkChaos Development Team
 */

#include "DCAddonNamespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Config.h"
#include <cstdio>  // for snprintf
#include <unordered_set>
#include <utility>  // for std::pair

namespace
{
    // Module identifier for leaderboards
    constexpr const char* MODULE_LEADERBOARD = "LBRD";
    
    // Opcodes
    namespace Opcode
    {
        // Client -> Server
        constexpr uint8 CMSG_GET_LEADERBOARD = 0x01;
        constexpr uint8 CMSG_GET_CATEGORIES = 0x02;
        constexpr uint8 CMSG_GET_MY_RANK = 0x03;
        constexpr uint8 CMSG_REFRESH = 0x04;
        constexpr uint8 CMSG_TEST_TABLES = 0x05;
        constexpr uint8 CMSG_GET_SEASONS = 0x06;
        constexpr uint8 CMSG_GET_MPLUS_DUNGEONS = 0x07;  // v1.3.0: Get available M+ dungeons
        
        // Server -> Client
        constexpr uint8 SMSG_LEADERBOARD_DATA = 0x10;
        constexpr uint8 SMSG_CATEGORIES = 0x11;
        constexpr uint8 SMSG_MY_RANK = 0x12;
        constexpr uint8 SMSG_TEST_RESULTS = 0x15;
        constexpr uint8 SMSG_SEASONS_LIST = 0x16;
        constexpr uint8 SMSG_MPLUS_DUNGEONS = 0x17;      // v1.3.0: M+ dungeon list response
        constexpr uint8 SMSG_ERROR = 0x1F;
    }
    
    // Maximum entries per page
    constexpr uint32 MAX_ENTRIES_PER_PAGE = 50;
    constexpr uint32 DEFAULT_ENTRIES_PER_PAGE = 25;
    
    // Forward declarations
    uint32 GetCurrentSeasonId();
    
    // ========================================================================
    // LEADERBOARD DATA FETCHERS
    // ========================================================================
    
    struct LeaderboardEntry
    {
        uint32 rank;
        std::string name;
        std::string className;
        uint32 score;
        std::string extra;
        // Extended fields for v1.3.0
        std::string score_str;   // For gold (uint64) sent as string
        uint32 mapId = 0;        // For M+ per-dungeon display
    };
    
    // Helper to get class name from class ID
    std::string GetClassNameFromId(uint8 classId)
    {
        switch (classId)
        {
            case 1: return "WARRIOR";
            case 2: return "PALADIN";
            case 3: return "HUNTER";
            case 4: return "ROGUE";
            case 5: return "PRIEST";
            case 6: return "DEATHKNIGHT";
            case 7: return "SHAMAN";
            case 8: return "MAGE";
            case 9: return "WARLOCK";
            case 11: return "DRUID";
            default: return "UNKNOWN";
        }
    }
    
    // Get Mythic+ leaderboard
    // Note: dc_mplus_scores table has: character_guid, season_id, map_id, best_level, best_score, last_run_ts, total_runs
    std::vector<LeaderboardEntry> GetMythicPlusLeaderboard(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        // Use aggregate function aliases in ORDER BY for sql_mode=only_full_group_by compatibility
        std::string orderBy = "best_level DESC, total_score DESC";
        
        if (subcat == "mplus_runs")
        {
            orderBy = "total_runs DESC, best_level DESC";
        }
        else if (subcat == "mplus_score")
        {
            orderBy = "total_score DESC, best_level DESC";
        }
        
        // Aggregate per-player across all dungeons for the season
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, MAX(s.best_level) as best_level, SUM(s.best_score) as total_score, SUM(s.total_runs) as total_runs "
            "FROM dc_mplus_scores s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.season_id = {} "
            "GROUP BY s.character_guid, c.name, c.class "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            seasonId, orderBy, limit, offset);
        
        if (!result)
            return entries;
        
        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            
            if (subcat == "mplus_runs")
            {
                entry.score = fields[4].Get<uint32>();  // total_runs
                entry.extra = "M+" + std::to_string(fields[2].Get<uint32>()) + " best";
            }
            else if (subcat == "mplus_score")
            {
                entry.score = fields[3].Get<uint32>();  // total_score
                entry.extra = std::to_string(fields[4].Get<uint32>()) + " runs";
            }
            else  // mplus_key (default)
            {
                entry.score = fields[2].Get<uint32>();  // best_level
                entry.extra = std::to_string(fields[4].Get<uint32>()) + " runs";
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get dungeon name from dc_mplus_featured_dungeons or fallback to map_id
    std::string GetDungeonNameForMap(uint16 mapId, uint32 seasonId = 0)
    {
        // Try to get from dc_mplus_featured_dungeons (world database)
        // This table has: season_id, map_id, sort_order, dungeon_name, notes
        QueryResult result;
        if (seasonId > 0)
        {
            result = WorldDatabase.Query(
                "SELECT dungeon_name FROM dc_mplus_featured_dungeons WHERE map_id = {} AND season_id = {} LIMIT 1", 
                mapId, seasonId);
        }
        
        // If not found for specific season, try any season
        if (!result)
        {
            result = WorldDatabase.Query(
                "SELECT dungeon_name FROM dc_mplus_featured_dungeons WHERE map_id = {} ORDER BY season_id DESC LIMIT 1", 
                mapId);
        }
        
        if (result)
            return result->Fetch()[0].Get<std::string>();
        
        // Fallback to map ID
        return "Dungeon #" + std::to_string(mapId);
    }
    
    // Get available M+ dungeons for a season from dc_mplus_featured_dungeons
    std::vector<std::pair<uint16, std::string>> GetMythicPlusDungeons(uint32 seasonId)
    {
        std::vector<std::pair<uint16, std::string>> dungeons;
        
        // Get dungeons from dc_mplus_featured_dungeons for this season
        // Table structure: season_id, map_id, sort_order, dungeon_name, notes
        QueryResult result = WorldDatabase.Query(
            "SELECT map_id, dungeon_name FROM dc_mplus_featured_dungeons "
            "WHERE season_id = {} "
            "ORDER BY sort_order ASC", seasonId);
        
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint16 mapId = fields[0].Get<uint16>();
                std::string name = fields[1].Get<std::string>();
                dungeons.emplace_back(mapId, name);
            } while (result->NextRow());
        }
        
        return dungeons;
    }
    
    // Get Mythic+ leaderboard for a specific dungeon
    // v1.3.0: New function for per-dungeon leaderboards with dungeon name display
    std::vector<LeaderboardEntry> GetMythicPlusDungeonLeaderboard(uint16 mapId, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string dungeonName = GetDungeonNameForMap(mapId, seasonId);
        
        // Query best runs for this specific dungeon
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, s.best_level, s.best_score, s.total_runs, s.map_id "
            "FROM dc_mplus_scores s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.season_id = {} AND s.map_id = {} "
            "ORDER BY s.best_level DESC, s.best_score DESC "
            "LIMIT {} OFFSET {}",
            seasonId, mapId, limit, offset);
        
        if (!result)
            return entries;
        
        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            entry.score = fields[2].Get<uint32>();  // best_level
            entry.mapId = fields[5].Get<uint16>();
            
            // Extra shows dungeon name and total runs
            entry.extra = dungeonName + " (" + std::to_string(fields[4].Get<uint32>()) + " runs)";
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get Mythic+ best dungeon runs per player (shows their best dungeon)
    // v1.3.0: Shows which dungeon each player performed best in
    std::vector<LeaderboardEntry> GetMythicPlusBestRunsLeaderboard(uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        // Get each player's best single dungeon run (highest level)
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, s.best_level, s.best_score, s.total_runs, s.map_id "
            "FROM dc_mplus_scores s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.season_id = {} AND s.best_level = ("
            "    SELECT MAX(s2.best_level) FROM dc_mplus_scores s2 "
            "    WHERE s2.character_guid = s.character_guid AND s2.season_id = s.season_id"
            ") "
            "ORDER BY s.best_level DESC, s.best_score DESC "
            "LIMIT {} OFFSET {}",
            seasonId, limit, offset);
        
        if (!result)
            return entries;
        
        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            entry.score = fields[2].Get<uint32>();  // best_level
            entry.mapId = fields[5].Get<uint16>();
            
            // Get dungeon name from dc_mplus_featured_dungeons
            std::string dungeonName = GetDungeonNameForMap(entry.mapId, seasonId);
            entry.extra = dungeonName;
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get Seasonal leaderboard
    // Table: dc_player_seasonal_stats with fields: total_tokens_earned, total_essence_earned, quests_completed, bosses_killed
    std::vector<LeaderboardEntry> GetSeasonalLeaderboard(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "d.total_tokens_earned DESC";
        std::string selectField = "d.total_tokens_earned";
        
        if (subcat == "season_essence")
        {
            orderBy = "d.total_essence_earned DESC";
            selectField = "d.total_essence_earned";
        }
        else if (subcat == "season_quests")
        {
            orderBy = "d.quests_completed DESC";
            selectField = "d.quests_completed";
        }
        else if (subcat == "season_bosses")
        {
            orderBy = "d.bosses_killed DESC";
            selectField = "d.bosses_killed";
        }
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, {}, d.total_tokens_earned, d.total_essence_earned, d.quests_completed "
            "FROM dc_player_seasonal_stats d "
            "JOIN characters c ON d.player_guid = c.guid "
            "WHERE d.season_id = {} "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            selectField, seasonId, orderBy, limit, offset);
        
        if (!result)
            return entries;
        
        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            entry.score = fields[2].Get<uint32>();
            
            if (subcat == "season_quests" || subcat == "season_bosses")
            {
                entry.extra = std::to_string(fields[3].Get<uint32>()) + " tokens";
            }
            else
            {
                entry.extra = std::to_string(fields[5].Get<uint32>()) + " quests";
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get Hinterland BG leaderboard
    // Tables:
    //   - dc_hlbg_player_season_data: player_guid, season_id, rating, wins, losses, completed_games (seasonal)
    //   - dc_hlbg_player_stats: player_guid, player_name, battles_won, total_kills, total_deaths, resources_captured (overall)
    std::vector<LeaderboardEntry> GetHLBGLeaderboard(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        // Check if we need overall stats (dc_hlbg_player_stats) or seasonal (dc_hlbg_player_season_data)
        bool useOverallStats = (subcat == "hlbg_kills" || subcat == "hlbg_alltime_wins" || subcat == "hlbg_resources");
        
        if (useOverallStats)
        {
            // Use dc_hlbg_player_stats for all-time stats
            std::string orderBy = "h.total_kills DESC";
            
            if (subcat == "hlbg_alltime_wins")
            {
                orderBy = "h.battles_won DESC";
            }
            else if (subcat == "hlbg_resources")
            {
                orderBy = "h.resources_captured DESC";
            }
            
            QueryResult result = CharacterDatabase.Query(
                "SELECT c.name, c.class, h.battles_won, h.total_kills, h.total_deaths, h.resources_captured, h.battles_participated "
                "FROM dc_hlbg_player_stats h "
                "JOIN characters c ON h.player_guid = c.guid "
                "ORDER BY {} "
                "LIMIT {} OFFSET {}",
                orderBy, limit, offset);
            
            if (!result)
                return entries;
            
            uint32 rank = offset + 1;
            do
            {
                Field* fields = result->Fetch();
                LeaderboardEntry entry;
                entry.rank = rank++;
                entry.name = fields[0].Get<std::string>();
                entry.className = GetClassNameFromId(fields[1].Get<uint8>());
                
                uint32 wins = fields[2].Get<uint32>();
                uint32 kills = fields[3].Get<uint32>();
                uint32 deaths = fields[4].Get<uint32>();
                uint32 resources = fields[5].Get<uint32>();
                uint32 battles = fields[6].Get<uint32>();
                
                if (subcat == "hlbg_alltime_wins")
                {
                    entry.score = wins;
                    entry.extra = std::to_string(battles) + " battles";
                }
                else if (subcat == "hlbg_resources")
                {
                    entry.score = resources;
                    entry.extra = std::to_string(kills) + " kills";
                }
                else  // hlbg_kills
                {
                    entry.score = kills;
                    float kd = deaths > 0 ? (static_cast<float>(kills) / deaths) : static_cast<float>(kills);
                    char kdBuf[16];
                    snprintf(kdBuf, sizeof(kdBuf), "%.2f K/D", kd);
                    entry.extra = kdBuf;
                }
                
                entries.push_back(entry);
            } while (result->NextRow());
        }
        else
        {
            // Use dc_hlbg_player_season_data for seasonal stats
            std::string orderBy = "h.rating DESC";
            
            if (subcat == "hlbg_wins")
            {
                orderBy = "h.wins DESC";
            }
            else if (subcat == "hlbg_winrate")
            {
                orderBy = "(CAST(h.wins AS FLOAT) / GREATEST(h.wins + h.losses, 1)) DESC";
            }
            else if (subcat == "hlbg_games")
            {
                orderBy = "h.completed_games DESC";
            }
            
            QueryResult result = CharacterDatabase.Query(
                "SELECT c.name, c.class, h.rating, h.wins, h.losses "
                "FROM dc_hlbg_player_season_data h "
                "JOIN characters c ON h.player_guid = c.guid "
                "WHERE h.season_id = {} "
                "ORDER BY {} "
                "LIMIT {} OFFSET {}",
                seasonId, orderBy, limit, offset);
            
            if (!result)
                return entries;
            
            uint32 rank = offset + 1;
            do
            {
                Field* fields = result->Fetch();
                LeaderboardEntry entry;
                entry.rank = rank++;
                entry.name = fields[0].Get<std::string>();
                entry.className = GetClassNameFromId(fields[1].Get<uint8>());
                
                uint32 wins = fields[3].Get<uint32>();
                uint32 losses = fields[4].Get<uint32>();
                uint32 totalGames = wins + losses;
                float winRate = totalGames > 0 ? (static_cast<float>(wins) / totalGames * 100.0f) : 0.0f;
                
                if (subcat == "hlbg_wins")
                {
                    entry.score = wins;
                    entry.extra = std::to_string(losses) + " losses";
                }
                else if (subcat == "hlbg_winrate")
                {
                    entry.score = static_cast<uint32>(winRate * 10);  // Store as x10 for precision
                    entry.extra = std::to_string(totalGames) + " games";
                }
                else if (subcat == "hlbg_games")
                {
                    entry.score = totalGames;
                    entry.extra = std::to_string(wins) + "W/" + std::to_string(losses) + "L";
                }
                else  // hlbg_rating
                {
                    entry.score = fields[2].Get<uint32>();
                    entry.extra = std::to_string(wins) + "W/" + std::to_string(losses) + "L";
                }
                
                entries.push_back(entry);
            } while (result->NextRow());
        }
        
        return entries;
    }
    
    // Get Prestige leaderboard
    // Table: dc_character_prestige with fields: guid, prestige_level, total_prestiges, last_prestige_time
    std::vector<LeaderboardEntry> GetPrestigeLeaderboard(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "p.prestige_level DESC, p.total_prestiges DESC";
        
        if (subcat == "prestige_resets")
        {
            orderBy = "p.total_prestiges DESC, p.prestige_level DESC";
        }
        
        // Get prestige data per player
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, p.prestige_level, p.total_prestiges, p.last_prestige_time "
            "FROM dc_character_prestige p "
            "JOIN characters c ON p.guid = c.guid "
            "WHERE p.prestige_level > 0 OR p.total_prestiges > 0 "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            orderBy, limit, offset);
        
        if (!result)
            return entries;
        
        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            
            uint32 prestigeLevel = fields[2].Get<uint32>();
            uint32 totalPrestiges = fields[3].Get<uint32>();
            
            if (subcat == "prestige_resets")
            {
                entry.score = totalPrestiges;
                entry.extra = "P" + std::to_string(prestigeLevel);
            }
            else  // prestige_level (default)
            {
                entry.score = prestigeLevel;
                entry.extra = std::to_string(totalPrestiges) + " resets";
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get Item Upgrade leaderboard
    // Uses dc_item_upgrades table: player_guid, tier_id, upgrade_level, tokens_invested, essence_invested
    std::vector<LeaderboardEntry> GetUpgradeLeaderboard(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "total_tokens DESC";
        
        if (subcat == "upgrade_items")
        {
            orderBy = "item_count DESC";
        }
        else if (subcat == "upgrade_essence")
        {
            orderBy = "total_essence DESC";
        }
        else if (subcat == "upgrade_tier")
        {
            orderBy = "highest_tier DESC, total_tokens DESC";
        }
        
        // Aggregate upgrades per player from dc_item_upgrades
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, "
            "SUM(u.tokens_invested) as total_tokens, "
            "SUM(u.essence_invested) as total_essence, "
            "COUNT(DISTINCT u.item_guid) as item_count, "
            "MAX(u.tier_id) as highest_tier "
            "FROM dc_item_upgrades u "
            "JOIN characters c ON u.player_guid = c.guid "
            "WHERE u.season = {} OR u.season = 0 "
            "GROUP BY u.player_guid, c.name, c.class "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            seasonId, orderBy, limit, offset);
        
        if (!result)
            return entries;
        
        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            
            uint32 tokens = fields[2].Get<uint32>();
            uint32 essence = fields[3].Get<uint32>();
            uint32 itemCount = fields[4].Get<uint32>();
            uint32 tier = fields[5].Get<uint32>();
            
            if (subcat == "upgrade_items")
            {
                entry.score = itemCount;
                entry.extra = std::to_string(tokens) + " tokens spent";
            }
            else if (subcat == "upgrade_essence")
            {
                entry.score = essence;
                entry.extra = std::to_string(itemCount) + " items";
            }
            else if (subcat == "upgrade_tier")
            {
                entry.score = tier;
                entry.extra = std::to_string(itemCount) + " items upgraded";
            }
            else  // upgrade_tokens (default)
            {
                entry.score = tokens;
                entry.extra = std::to_string(itemCount) + " items";
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get Duel leaderboard
    // Table: dc_duel_statistics with fields: player_guid, wins, losses, draws, total_damage_dealt
    std::vector<LeaderboardEntry> GetDuelLeaderboard(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "d.wins DESC";
        
        if (subcat == "duel_winrate")
        {
            orderBy = "(CAST(d.wins AS FLOAT) / GREATEST(d.wins + d.losses, 1)) DESC";
        }
        else if (subcat == "duel_total")
        {
            orderBy = "(d.wins + d.losses + d.draws) DESC";
        }
        else if (subcat == "duel_damage")
        {
            orderBy = "d.total_damage_dealt DESC";
        }
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, d.wins, d.losses, d.draws, d.total_damage_dealt "
            "FROM dc_duel_statistics d "
            "JOIN characters c ON d.player_guid = c.guid "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            orderBy, limit, offset);
        
        if (!result)
            return entries;
        
        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            
            uint32 wins = fields[2].Get<uint32>();
            uint32 losses = fields[3].Get<uint32>();
            uint32 draws = fields[4].Get<uint32>();
            uint64 damage = fields[5].Get<uint64>();
            uint32 totalGames = wins + losses + draws;
            float winRate = totalGames > 0 ? (static_cast<float>(wins) / totalGames * 100.0f) : 0.0f;
            
            if (subcat == "duel_winrate")
            {
                entry.score = static_cast<uint32>(winRate * 10);
                entry.extra = std::to_string(totalGames) + " duels";
            }
            else if (subcat == "duel_total")
            {
                entry.score = totalGames;
                entry.extra = std::to_string(wins) + "W/" + std::to_string(losses) + "L/" + std::to_string(draws) + "D";
            }
            else if (subcat == "duel_damage")
            {
                entry.score = static_cast<uint32>(damage / 1000);  // Display as thousands
                entry.extra = std::to_string(wins) + " wins";
            }
            else  // duel_wins
            {
                entry.score = wins;
                entry.extra = std::to_string(losses) + " losses";
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get AOE Loot leaderboard
    // Table: dc_aoeloot_detailed_stats with quality breakdown columns
    // Simplified to 3 views: aoe_items (looted + quality), aoe_filtered (filtered + quality), aoe_gold
    std::vector<LeaderboardEntry> GetAOELeaderboard(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "a.total_items DESC";
        
        if (subcat == "aoe_gold")
        {
            orderBy = "a.total_gold DESC";
        }
        else if (subcat == "aoe_filtered")
        {
            // Order by total filtered items
            orderBy = "(COALESCE(a.filtered_poor, 0) + COALESCE(a.filtered_common, 0) + COALESCE(a.filtered_uncommon, 0) + "
                      "COALESCE(a.filtered_rare, 0) + COALESCE(a.filtered_epic, 0) + COALESCE(a.filtered_legendary, 0)) DESC";
        }
        // aoe_items uses default order by total_items
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, a.total_items, a.total_gold, a.upgrades, a.skinned, a.vendor_gold, "
            "COALESCE(a.quality_poor, 0), COALESCE(a.quality_common, 0), COALESCE(a.quality_uncommon, 0), "
            "COALESCE(a.quality_rare, 0), COALESCE(a.quality_epic, 0), COALESCE(a.quality_legendary, 0), "
            "COALESCE(a.filtered_poor, 0), COALESCE(a.filtered_common, 0), COALESCE(a.filtered_uncommon, 0), "
            "COALESCE(a.filtered_rare, 0), COALESCE(a.filtered_epic, 0), COALESCE(a.filtered_legendary, 0) "
            "FROM dc_aoeloot_detailed_stats a "
            "JOIN characters c ON a.player_guid = c.guid "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            orderBy, limit, offset);
        
        if (!result)
            return entries;
        
        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            
            uint32 items = fields[2].Get<uint32>();
            uint64 totalGold = fields[3].Get<uint64>();  // In copper
            // Future: These fields are queried but not yet exposed in the UI
            // uint32 upgrades = fields[4].Get<uint32>();
            // uint32 skinned = fields[5].Get<uint32>();
            // uint64 vendorGold = fields[6].Get<uint64>();
            (void)fields[4];  // upgrades - reserved for future use
            (void)fields[5];  // skinned - reserved for future use
            (void)fields[6];  // vendorGold - reserved for future use
            
            // Quality breakdown for looted items
            uint32 qPoor = fields[7].Get<uint32>();
            uint32 qCommon = fields[8].Get<uint32>();
            uint32 qUncommon = fields[9].Get<uint32>();
            uint32 qRare = fields[10].Get<uint32>();
            uint32 qEpic = fields[11].Get<uint32>();
            uint32 qLegendary = fields[12].Get<uint32>();
            
            // Quality breakdown for filtered/skipped items
            uint32 fPoor = fields[13].Get<uint32>();
            uint32 fCommon = fields[14].Get<uint32>();
            uint32 fUncommon = fields[15].Get<uint32>();
            uint32 fRare = fields[16].Get<uint32>();
            uint32 fEpic = fields[17].Get<uint32>();
            uint32 fLegendary = fields[18].Get<uint32>();
            
            if (subcat == "aoe_gold")
            {
                // Gold view: send as string to avoid uint32 truncation (max 4.2B copper = 429k gold)
                // Client will parse and format with FormatMoney()
                entry.score = 0;  // Set to 0, use score_str instead
                entry.score_str = std::to_string(totalGold);  // Full uint64 as string
                entry.extra = std::to_string(items) + " items";
            }
            else if (subcat == "aoe_filtered")
            {
                // Filtered items view with quality breakdown
                uint32 totalFiltered = fPoor + fCommon + fUncommon + fRare + fEpic + fLegendary;
                entry.score = totalFiltered;
                
                // Format: "P:X C:X U:X R:X" with colors
                std::ostringstream oss;
                if (fPoor > 0) oss << "|cff9d9d9dP:" << fPoor << "|r ";
                if (fCommon > 0) oss << "C:" << fCommon << " ";
                if (fUncommon > 0) oss << "|cff1eff00U:" << fUncommon << "|r ";
                if (fRare > 0) oss << "|cff0070ddR:" << fRare << "|r ";
                if (fEpic > 0) oss << "|cffa335eeE:" << fEpic << "|r ";
                if (fLegendary > 0) oss << "|cffff8000L:" << fLegendary << "|r";
                entry.extra = oss.str();
                if (entry.extra.empty())
                    entry.extra = "None filtered";
            }
            else  // aoe_items (default)
            {
                // Items view with quality breakdown
                entry.score = items;
                
                // Format: "L:X E:X R:X U:X" with colors (from best to worst)
                std::ostringstream oss;
                if (qLegendary > 0) oss << "|cffff8000L:" << qLegendary << "|r ";
                if (qEpic > 0) oss << "|cffa335eeE:" << qEpic << "|r ";
                if (qRare > 0) oss << "|cff0070ddR:" << qRare << "|r ";
                if (qUncommon > 0) oss << "|cff1eff00U:" << qUncommon << "|r";
                entry.extra = oss.str();
                if (entry.extra.empty())
                {
                    // Fallback: show common + poor count
                    entry.extra = std::to_string(qCommon + qPoor) + " common/poor";
                }
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get Achievement leaderboard
    // Table: dc_player_achievements with fields: player_guid, achievement_id, progress, completed
    std::vector<LeaderboardEntry> GetAchievementLeaderboard(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "total_completed DESC";
        
        if (subcat == "achieve_progress")
        {
            orderBy = "total_progress DESC";
        }
        
        // Aggregate achievements per player
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, SUM(a.completed) as total_completed, SUM(a.progress) as total_progress "
            "FROM dc_player_achievements a "
            "JOIN characters c ON a.player_guid = c.guid "
            "GROUP BY a.player_guid, c.name, c.class "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            orderBy, limit, offset);
        
        if (!result)
            return entries;
        
        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            
            uint32 completed = fields[2].Get<uint32>();
            uint32 progress = fields[3].Get<uint32>();
            
            if (subcat == "achieve_progress")
            {
                entry.score = progress;
                entry.extra = std::to_string(completed) + " completed";
            }
            else  // achieve_completed (default)
            {
                entry.score = completed;
                entry.extra = std::to_string(progress) + " progress";
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get total entry count for pagination
    uint32 GetTotalEntryCount(const std::string& category, const std::string& subcat, uint32 seasonId)
    {
        QueryResult result = nullptr;
        
        // Handle seasonId = 0 as current season
        if (seasonId == 0)
            seasonId = GetCurrentSeasonId();
        
        if (category == "mplus")
        {
            result = CharacterDatabase.Query(
                "SELECT COUNT(DISTINCT character_guid) FROM dc_mplus_scores WHERE season_id = {}", seasonId);
        }
        else if (category == "seasons")
        {
            result = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_player_seasonal_stats WHERE season_id = {}", seasonId);
        }
        else if (category == "hlbg")
        {
            // Check if using overall stats or seasonal
            bool useOverallStats = (subcat == "hlbg_kills" || subcat == "hlbg_alltime_wins" || subcat == "hlbg_resources");
            if (useOverallStats)
            {
                result = CharacterDatabase.Query("SELECT COUNT(*) FROM dc_hlbg_player_stats");
            }
            else
            {
                result = CharacterDatabase.Query(
                    "SELECT COUNT(*) FROM dc_hlbg_player_season_data WHERE season_id = {}", seasonId);
            }
        }
        else if (category == "prestige")
        {
            result = CharacterDatabase.Query("SELECT COUNT(DISTINCT player_guid) FROM dc_player_artifact_mastery");
        }
        else if (category == "upgrade")
        {
            result = CharacterDatabase.Query(
                "SELECT COUNT(DISTINCT player_guid) FROM dc_item_upgrades WHERE season = {} OR season = 0", seasonId);
        }
        else if (category == "duel")
        {
            result = CharacterDatabase.Query("SELECT COUNT(*) FROM dc_duel_statistics");
        }
        else if (category == "aoe")
        {
            // Use dc_aoeloot_detailed_stats which is populated by dc_aoeloot_extensions.cpp
            result = CharacterDatabase.Query("SELECT COUNT(*) FROM dc_aoeloot_detailed_stats");
        }
        else if (category == "achieve")
        {
            result = CharacterDatabase.Query("SELECT COUNT(DISTINCT player_guid) FROM dc_player_achievements");
        }
        
        if (result)
            return result->Fetch()[0].Get<uint32>();
        
        return 0;
    }
    
    // Get player's rank in a leaderboard
    uint32 GetPlayerRank(Player* player, const std::string& category, const std::string& subcat, uint32 seasonId)
    {
        uint32 guid = player->GetGUID().GetCounter();
        QueryResult result = nullptr;
        
        // This is a simplified version - a full implementation would use window functions
        // or subqueries to get the exact rank
        if (category == "mplus" && subcat == "mplus_key")
        {
            result = CharacterDatabase.Query(
                "SELECT COUNT(*) + 1 FROM dc_mplus_scores s1 "
                "WHERE s1.season_id = {} AND s1.best_level > "
                "(SELECT best_level FROM dc_mplus_scores WHERE character_guid = {} AND season_id = {} LIMIT 1)",
                seasonId, guid, seasonId);
        }
        // Add more cases as needed...
        
        if (result)
            return result->Fetch()[0].Get<uint32>();
        
        return 0;
    }
    
    // ========================================================================
    // MESSAGE HANDLERS
    // ========================================================================
    
    // Helper to get the current active season ID
    uint32 GetCurrentSeasonId()
    {
        // Try to get from HLBG seasons first (most commonly used)
        // Note: Season config tables are in WorldDatabase, not CharacterDatabase
        QueryResult result = WorldDatabase.Query(
            "SELECT season FROM dc_hlbg_seasons WHERE is_active = 1 ORDER BY season DESC LIMIT 1");
        
        if (result)
            return result->Fetch()[0].Get<uint32>();
        
        // Fallback: try dc_mplus_seasons
        result = WorldDatabase.Query(
            "SELECT season_id FROM dc_mplus_seasons WHERE is_active = 1 ORDER BY season_id DESC LIMIT 1");
        
        if (result)
            return result->Fetch()[0].Get<uint32>();
        
        // Ultimate fallback
        return 1;
    }
    
    void HandleGetLeaderboard(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession())
            return;
        
        // Parse JSON data
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        
        std::string category = json["category"].IsString() ? json["category"].AsString() : "mplus";
        std::string subcategory = json["subcategory"].IsString() ? json["subcategory"].AsString() : "mplus_key";
        uint32 page = json["page"].IsNumber() ? json["page"].AsUInt32() : 1;
        uint32 limit = json["limit"].IsNumber() ? json["limit"].AsUInt32() : DEFAULT_ENTRIES_PER_PAGE;
        uint32 seasonId = json["seasonId"].IsNumber() ? json["seasonId"].AsUInt32() : 0;
        
        // If seasonId is 0, get the current active season
        if (seasonId == 0)
            seasonId = GetCurrentSeasonId();
        
        LOG_DEBUG("server.scripts", "DC-Leaderboards: Request for {}/{} page {} limit {} season {}", 
            category, subcategory, page, limit, seasonId);
        
        // Clamp limit
        if (limit > MAX_ENTRIES_PER_PAGE)
            limit = MAX_ENTRIES_PER_PAGE;
        if (limit < 1)
            limit = DEFAULT_ENTRIES_PER_PAGE;
        
        // Calculate offset
        uint32 offset = (page - 1) * limit;
        
        // Get entries based on category
        std::vector<LeaderboardEntry> entries;
        
        if (category == "mplus")
        {
            // v1.3.0: Check for per-dungeon subcategory (format: mplus_dungeon_<mapId>)
            if (subcategory.rfind("mplus_dungeon_", 0) == 0)
            {
                // Extract map ID from subcategory
                std::string mapIdStr = subcategory.substr(14);  // After "mplus_dungeon_"
                uint16 mapId = static_cast<uint16>(std::stoul(mapIdStr));
                entries = GetMythicPlusDungeonLeaderboard(mapId, seasonId, limit, offset);
            }
            else if (subcategory == "mplus_bestruns")
            {
                // Best runs view - shows each player's best dungeon run with name
                entries = GetMythicPlusBestRunsLeaderboard(seasonId, limit, offset);
            }
            else
            {
                entries = GetMythicPlusLeaderboard(subcategory, seasonId, limit, offset);
            }
        }
        else if (category == "seasons")
            entries = GetSeasonalLeaderboard(subcategory, seasonId, limit, offset);
        else if (category == "hlbg")
            entries = GetHLBGLeaderboard(subcategory, seasonId, limit, offset);
        else if (category == "prestige")
            entries = GetPrestigeLeaderboard(subcategory, limit, offset);
        else if (category == "upgrade")
            entries = GetUpgradeLeaderboard(subcategory, seasonId, limit, offset);
        else if (category == "duel")
            entries = GetDuelLeaderboard(subcategory, limit, offset);
        else if (category == "aoe")
            entries = GetAOELeaderboard(subcategory, limit, offset);
        else if (category == "achieve")
            entries = GetAchievementLeaderboard(subcategory, limit, offset);
        
        // Get total count for pagination
        uint32 totalEntries = GetTotalEntryCount(category, subcategory, seasonId);
        uint32 totalPages = (totalEntries + limit - 1) / limit;
        if (totalPages < 1) totalPages = 1;
        
        // Build JSON response
        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_LEADERBOARD_DATA);
        response.Set("category", category);
        response.Set("subcategory", subcategory);
        response.Set("page", static_cast<int32>(page));
        response.Set("totalPages", static_cast<int32>(totalPages));
        response.Set("totalEntries", static_cast<int32>(totalEntries));
        
        // Build entries array as JSON string
        std::string entriesJson = "[";
        for (size_t i = 0; i < entries.size(); ++i)
        {
            if (i > 0) entriesJson += ",";
            entriesJson += "{";
            entriesJson += "\"rank\":" + std::to_string(entries[i].rank) + ",";
            entriesJson += "\"name\":\"" + entries[i].name + "\",";
            entriesJson += "\"class\":\"" + entries[i].className + "\",";
            entriesJson += "\"score\":" + std::to_string(entries[i].score) + ",";
            // v1.3.0: Add score_str for large values (gold as uint64)
            if (!entries[i].score_str.empty())
                entriesJson += "\"score_str\":\"" + entries[i].score_str + "\",";
            // v1.3.0: Add mapId for per-dungeon display
            if (entries[i].mapId > 0)
                entriesJson += "\"mapId\":" + std::to_string(entries[i].mapId) + ",";
            entriesJson += "\"extra\":\"" + entries[i].extra + "\"";
            entriesJson += "}";
        }
        entriesJson += "]";
        
        // Unfortunately we need to build this manually since JsonValue doesn't support nested arrays easily
        // Send as a complete JSON string
        std::string fullJson = "{";
        fullJson += "\"category\":\"" + category + "\",";
        fullJson += "\"subcategory\":\"" + subcategory + "\",";
        fullJson += "\"page\":" + std::to_string(page) + ",";
        fullJson += "\"totalPages\":" + std::to_string(totalPages) + ",";
        fullJson += "\"totalEntries\":" + std::to_string(totalEntries) + ",";
        fullJson += "\"entries\":" + entriesJson;
        fullJson += "}";
        
        // Send raw JSON message
        std::string msg_str = std::string(MODULE_LEADERBOARD) + "|" + std::to_string(Opcode::SMSG_LEADERBOARD_DATA) + "|J|" + fullJson;
        
        WorldPacket data;
        std::string fullMsg = std::string(DCAddon::DC_PREFIX) + "\t" + msg_str;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, fullMsg);
        player->SendDirectMessage(&data);
    }
    
    void HandleGetCategories(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;
        
        // Send available categories (client already has these hardcoded, but we can confirm)
        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_CATEGORIES);
        response.Set("success", true);
        response.Set("count", 8);
        response.Send(player);
    }
    
    void HandleGetMyRank(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;
        
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        
        std::string category = json["category"].IsString() ? json["category"].AsString() : "mplus";
        std::string subcategory = json["subcategory"].IsString() ? json["subcategory"].AsString() : "mplus_key";
        uint32 seasonId = json["seasonId"].IsNumber() ? json["seasonId"].AsUInt32() : 0;
        
        // If seasonId is 0, get the current active season
        if (seasonId == 0)
            seasonId = GetCurrentSeasonId();
        
        uint32 rank = GetPlayerRank(player, category, subcategory, seasonId);
        uint32 total = GetTotalEntryCount(category, subcategory, seasonId);
        float percentile = total > 0 ? (static_cast<float>(rank) / total * 100.0f) : 0.0f;
        
        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_MY_RANK);
        response.Set("category", category);
        response.Set("subcategory", subcategory);
        response.Set("rank", static_cast<int32>(rank));
        response.Set("percentile", static_cast<double>(percentile));
        response.Send(player);
    }
    
    void HandleRefresh(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;
        
        // Nothing to do server-side for refresh, client will re-request data
        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_LEADERBOARD_DATA);
        response.Set("refreshed", true);
        response.Send(player);
    }
    
    // Helper struct for table test results
    struct TableTestResult
    {
        std::string name;
        bool exists;
        uint32 count;
    };
    
    // Tables that are in WorldDatabase instead of CharacterDatabase
    static const std::unordered_set<std::string> WorldDatabaseTables = {
        "dc_mplus_seasons",
        "dc_hlbg_seasons"
    };
    
    // Test if a table exists and get row count
    TableTestResult TestTable(const std::string& tableName)
    {
        TableTestResult result;
        result.name = tableName;
        result.exists = false;
        result.count = 0;
        
        // Use correct database based on table name
        bool useWorld = WorldDatabaseTables.count(tableName) > 0;
        
        // Try to count rows - if table doesn't exist, this will fail
        try
        {
            QueryResult countResult;
            if (useWorld)
            {
                countResult = WorldDatabase.Query(
                    "SELECT COUNT(*) FROM {}", tableName);
            }
            else
            {
                countResult = CharacterDatabase.Query(
                    "SELECT COUNT(*) FROM {}", tableName);
            }
            
            if (countResult)
            {
                result.exists = true;
                result.count = countResult->Fetch()[0].Get<uint32>();
            }
        }
        catch (...)
        {
            result.exists = false;
        }
        
        return result;
    }
    
    void HandleTestTables(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;
        
        LOG_INFO("server.scripts", "DC-Leaderboards: Testing database tables for player {}", player->GetName());
        
        // Test all leaderboard-related tables
        std::vector<std::string> tables = {
            "dc_mplus_scores",
            "dc_player_seasonal_stats",
            "dc_hlbg_player_season_data",
            "dc_hlbg_player_stats",
            "dc_character_prestige",
            "dc_item_upgrades",
            "dc_duel_statistics",
            "dc_aoeloot_detailed_stats",
            "dc_player_achievements",
            "dc_hlbg_seasons",
            "dc_mplus_seasons"
        };
        
        // Build JSON response manually for array support
        std::string tablesJson = "[";
        bool first = true;
        
        for (const auto& tableName : tables)
        {
            TableTestResult result = TestTable(tableName);
            
            if (!first) tablesJson += ",";
            first = false;
            
            tablesJson += "{";
            tablesJson += "\"name\":\"" + result.name + "\",";
            tablesJson += "\"exists\":" + std::string(result.exists ? "true" : "false") + ",";
            tablesJson += "\"count\":" + std::to_string(result.count);
            tablesJson += "}";
            
            LOG_DEBUG("server.scripts", "  Table {}: exists={}, count={}", 
                result.name, result.exists, result.count);
        }
        tablesJson += "]";
        
        // Get current season
        uint32 currentSeason = GetCurrentSeasonId();
        
        // Build full JSON response
        std::string fullJson = "{";
        fullJson += "\"tables\":" + tablesJson + ",";
        fullJson += "\"currentSeason\":" + std::to_string(currentSeason);
        fullJson += "}";
        
        // Send raw JSON message
        std::string msg_str = std::string(MODULE_LEADERBOARD) + "|" + std::to_string(Opcode::SMSG_TEST_RESULTS) + "|J|" + fullJson;
        
        WorldPacket data;
        std::string fullMsg = std::string(DCAddon::DC_PREFIX) + "\t" + msg_str;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, fullMsg);
        player->SendDirectMessage(&data);
    }
    
    void HandleGetSeasons(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;
        
        LOG_DEBUG("server.scripts", "DC-Leaderboards: Getting seasons list for player {}", player->GetName());
        
        // Build seasons array
        std::string seasonsJson = "[";
        bool first = true;
        
        // Try HLBG seasons first (season config is in WorldDatabase)
        QueryResult result = WorldDatabase.Query(
            "SELECT season, is_active FROM dc_hlbg_seasons ORDER BY season DESC LIMIT 10");
        
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 seasonId = fields[0].Get<uint32>();
                bool isActive = fields[1].Get<uint8>() != 0;
                
                if (!first) seasonsJson += ",";
                first = false;
                
                seasonsJson += "{";
                seasonsJson += "\"id\":" + std::to_string(seasonId) + ",";
                seasonsJson += "\"active\":" + std::string(isActive ? "true" : "false");
                seasonsJson += "}";
            } while (result->NextRow());
        }
        
        // Also try M+ seasons if we got nothing (dc_mplus_seasons is in WorldDatabase)
        if (first)
        {
            result = WorldDatabase.Query(
                "SELECT season_id, is_active FROM dc_mplus_seasons ORDER BY season_id DESC LIMIT 10");
            
            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint32 seasonId = fields[0].Get<uint32>();
                    bool isActive = fields[1].Get<uint8>() != 0;
                    
                    if (!first) seasonsJson += ",";
                    first = false;
                    
                    seasonsJson += "{";
                    seasonsJson += "\"id\":" + std::to_string(seasonId) + ",";
                    seasonsJson += "\"active\":" + std::string(isActive ? "true" : "false");
                    seasonsJson += "}";
                } while (result->NextRow());
            }
        }
        
        seasonsJson += "]";
        
        // Build full JSON response
        std::string fullJson = "{\"seasons\":" + seasonsJson + "}";
        
        // Send raw JSON message
        std::string msg_str = std::string(MODULE_LEADERBOARD) + "|" + std::to_string(Opcode::SMSG_SEASONS_LIST) + "|J|" + fullJson;
        
        WorldPacket data;
        std::string fullMsg = std::string(DCAddon::DC_PREFIX) + "\t" + msg_str;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, fullMsg);
        player->SendDirectMessage(&data);
    }
    
    // v1.3.0: Handle request for available M+ dungeons
    void HandleGetMythicPlusDungeons(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;
        
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 seasonId = json["seasonId"].IsNumber() ? json["seasonId"].AsUInt32() : 0;
        
        if (seasonId == 0)
            seasonId = GetCurrentSeasonId();
        
        LOG_DEBUG("server.scripts", "DC-Leaderboards: Getting M+ dungeons for season {}", seasonId);
        
        auto dungeons = GetMythicPlusDungeons(seasonId);
        
        // Build dungeons array
        std::string dungeonsJson = "[";
        bool first = true;
        
        for (const auto& [mapId, dungeonName] : dungeons)
        {
            if (!first) dungeonsJson += ",";
            first = false;
            
            dungeonsJson += "{";
            dungeonsJson += "\"mapId\":" + std::to_string(mapId) + ",";
            dungeonsJson += "\"name\":\"" + dungeonName + "\"";
            dungeonsJson += "}";
        }
        
        dungeonsJson += "]";
        
        // Build full JSON response
        std::string fullJson = "{\"seasonId\":" + std::to_string(seasonId) + ",\"dungeons\":" + dungeonsJson + "}";
        
        // Send raw JSON message
        std::string msg_str = std::string(MODULE_LEADERBOARD) + "|" + std::to_string(Opcode::SMSG_MPLUS_DUNGEONS) + "|J|" + fullJson;
        
        WorldPacket data;
        std::string fullMsg = std::string(DCAddon::DC_PREFIX) + "\t" + msg_str;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, fullMsg);
        player->SendDirectMessage(&data);
    }
    
    // Error handler for future use
    [[maybe_unused]] void HandleError(Player* player, const std::string& message)
    {
        if (!player)
            return;
        
        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_ERROR);
        response.Set("message", message);
        response.Send(player);
    }
    
    // ========================================================================
    // REGISTRATION
    // ========================================================================
    
    void RegisterLeaderboardHandlers()
    {
        auto& router = DCAddon::MessageRouter::Instance();
        
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_LEADERBOARD, HandleGetLeaderboard);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_CATEGORIES, HandleGetCategories);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_MY_RANK, HandleGetMyRank);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_REFRESH, HandleRefresh);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_TEST_TABLES, HandleTestTables);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_SEASONS, HandleGetSeasons);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_MPLUS_DUNGEONS, HandleGetMythicPlusDungeons);
        
        LOG_INFO("server.scripts", "DC-Leaderboards: Addon protocol handlers registered");
    }

}  // anonymous namespace

// ============================================================================
// SCRIPT REGISTRATION
// ============================================================================

class dc_addon_leaderboards_world : public WorldScript
{
public:
    dc_addon_leaderboards_world() : WorldScript("dc_addon_leaderboards_world") { }
    
    void OnStartup() override
    {
        RegisterLeaderboardHandlers();
    }
};

void AddSC_dc_addon_leaderboards()
{
    new dc_addon_leaderboards_world();
}
