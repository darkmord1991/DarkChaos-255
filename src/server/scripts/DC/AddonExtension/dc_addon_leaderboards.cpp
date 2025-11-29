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
        
        // Server -> Client
        constexpr uint8 SMSG_LEADERBOARD_DATA = 0x10;
        constexpr uint8 SMSG_CATEGORIES = 0x11;
        constexpr uint8 SMSG_MY_RANK = 0x12;
        constexpr uint8 SMSG_ERROR = 0x1F;
    }
    
    // Maximum entries per page
    constexpr uint32 MAX_ENTRIES_PER_PAGE = 50;
    constexpr uint32 DEFAULT_ENTRIES_PER_PAGE = 25;
    
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
    };
    
    // Get Mythic+ leaderboard
    std::vector<LeaderboardEntry> GetMythicPlusLeaderboard(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "s.best_level DESC, s.best_score DESC";
        std::string selectExtra = "s.total_runs";
        
        if (subcat == "mplus_time")
        {
            orderBy = "s.best_time ASC";
            selectExtra = "s.dungeon_name";
        }
        else if (subcat == "mplus_runs")
        {
            orderBy = "s.total_runs DESC";
            selectExtra = "s.best_level";
        }
        else if (subcat == "mplus_score")
        {
            orderBy = "s.best_score DESC";
            selectExtra = "s.total_runs";
        }
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, s.best_level, s.best_score, s.total_runs, s.best_time "
            "FROM dc_mplus_scores s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.season_id = {} "
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
            
            if (subcat == "mplus_time")
            {
                entry.score = fields[5].Get<uint32>();  // best_time in seconds
                entry.extra = "Fastest clear";
            }
            else if (subcat == "mplus_runs")
            {
                entry.score = fields[4].Get<uint32>();  // total_runs
                entry.extra = "M+" + std::to_string(fields[2].Get<uint32>()) + " best";
            }
            else if (subcat == "mplus_score")
            {
                entry.score = fields[3].Get<uint32>();  // best_score
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
    
    // Get Seasonal leaderboard
    std::vector<LeaderboardEntry> GetSeasonalLeaderboard(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "d.total_tokens DESC";
        std::string selectField = "d.total_tokens";
        
        if (subcat == "season_essence")
        {
            orderBy = "d.total_essence DESC";
            selectField = "d.total_essence";
        }
        else if (subcat == "season_points")
        {
            orderBy = "d.total_points DESC";
            selectField = "d.total_points";
        }
        else if (subcat == "season_level")
        {
            orderBy = "d.season_level DESC";
            selectField = "d.season_level";
        }
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, {}, d.total_tokens, d.total_essence, d.season_level "
            "FROM dc_player_season_data d "
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
            
            if (subcat == "season_level")
            {
                entry.extra = std::to_string(fields[3].Get<uint32>()) + " tokens";
            }
            else
            {
                entry.extra = "Level " + std::to_string(fields[5].Get<uint32>());
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get Hinterland BG leaderboard
    std::vector<LeaderboardEntry> GetHLBGLeaderboard(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
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
            orderBy = "(h.wins + h.losses) DESC";
        }
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, h.rating, h.wins, h.losses "
            "FROM dc_hlbg_player_stats h "
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
        
        return entries;
    }
    
    // Get Prestige leaderboard
    std::vector<LeaderboardEntry> GetPrestigeLeaderboard(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "p.prestige_rank DESC, p.total_prestige_points DESC";
        
        if (subcat == "prestige_points")
        {
            orderBy = "p.total_prestige_points DESC";
        }
        else if (subcat == "prestige_resets")
        {
            orderBy = "p.times_prestiged DESC";
        }
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, p.prestige_rank, p.total_prestige_points, p.times_prestiged "
            "FROM dc_player_artifact_mastery p "
            "JOIN characters c ON p.player_guid = c.guid "
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
            
            if (subcat == "prestige_points")
            {
                entry.score = fields[3].Get<uint32>();
                entry.extra = "Rank " + std::to_string(fields[2].Get<uint32>());
            }
            else if (subcat == "prestige_resets")
            {
                entry.score = fields[4].Get<uint32>();
                entry.extra = std::to_string(fields[3].Get<uint32>()) + " pts";
            }
            else  // prestige_level
            {
                entry.score = fields[2].Get<uint32>();
                entry.extra = std::to_string(fields[3].Get<uint32>()) + " pts";
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get Item Upgrade leaderboard
    std::vector<LeaderboardEntry> GetUpgradeLeaderboard(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "d.upgrades_applied DESC";
        
        if (subcat == "upgrade_items")
        {
            orderBy = "d.items_upgraded DESC";
        }
        else if (subcat == "upgrade_efficiency")
        {
            orderBy = "(CAST(d.upgrades_applied AS FLOAT) / GREATEST(d.essence_spent, 1)) DESC";
        }
        else if (subcat == "upgrade_tier")
        {
            orderBy = "d.highest_tier DESC";
        }
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, d.upgrades_applied, d.items_upgraded, d.essence_spent, d.highest_tier "
            "FROM dc_player_season_data d "
            "JOIN characters c ON d.player_guid = c.guid "
            "WHERE d.season_id = {} "
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
            
            if (subcat == "upgrade_items")
            {
                entry.score = fields[3].Get<uint32>();
                entry.extra = std::to_string(fields[2].Get<uint32>()) + " upgrades";
            }
            else if (subcat == "upgrade_efficiency")
            {
                uint32 upgrades = fields[2].Get<uint32>();
                uint32 spent = fields[4].Get<uint32>();
                float efficiency = spent > 0 ? (static_cast<float>(upgrades) / spent * 100.0f) : 0.0f;
                entry.score = static_cast<uint32>(efficiency * 10);
                entry.extra = std::to_string(upgrades) + " upgrades";
            }
            else if (subcat == "upgrade_tier")
            {
                entry.score = fields[5].Get<uint32>();
                entry.extra = std::to_string(fields[2].Get<uint32>()) + " upgrades";
            }
            else  // upgrade_total
            {
                entry.score = fields[2].Get<uint32>();
                entry.extra = std::to_string(fields[3].Get<uint32>()) + " items";
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get Duel leaderboard
    std::vector<LeaderboardEntry> GetDuelLeaderboard(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "d.wins DESC";
        
        if (subcat == "duel_winrate")
        {
            orderBy = "(CAST(d.wins AS FLOAT) / GREATEST(d.wins + d.losses, 1)) DESC";
        }
        else if (subcat == "duel_rating")
        {
            orderBy = "d.rating DESC";
        }
        else if (subcat == "duel_streak")
        {
            orderBy = "d.best_streak DESC";
        }
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, d.wins, d.losses, d.rating, d.best_streak "
            "FROM dc_duel_stats d "
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
            uint32 totalGames = wins + losses;
            float winRate = totalGames > 0 ? (static_cast<float>(wins) / totalGames * 100.0f) : 0.0f;
            
            if (subcat == "duel_winrate")
            {
                entry.score = static_cast<uint32>(winRate * 10);
                entry.extra = std::to_string(totalGames) + " duels";
            }
            else if (subcat == "duel_rating")
            {
                entry.score = fields[4].Get<uint32>();
                entry.extra = std::to_string(wins) + "W/" + std::to_string(losses) + "L";
            }
            else if (subcat == "duel_streak")
            {
                entry.score = fields[5].Get<uint32>();
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
    std::vector<LeaderboardEntry> GetAOELeaderboard(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "a.total_items_looted DESC";
        
        if (subcat == "aoe_gold")
        {
            orderBy = "a.total_gold DESC";
        }
        else if (subcat == "aoe_skinned")
        {
            orderBy = "a.creatures_skinned DESC";
        }
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, a.total_items_looted, a.total_gold, a.creatures_skinned "
            "FROM dc_aoe_loot_stats a "
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
            
            if (subcat == "aoe_gold")
            {
                entry.score = fields[3].Get<uint32>();
                entry.extra = std::to_string(fields[2].Get<uint32>()) + " items";
            }
            else if (subcat == "aoe_skinned")
            {
                entry.score = fields[4].Get<uint32>();
                entry.extra = std::to_string(fields[3].Get<uint32>()) + "g";
            }
            else  // aoe_items
            {
                entry.score = fields[2].Get<uint32>();
                entry.extra = std::to_string(fields[3].Get<uint32>()) + "g";
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
    // Get Achievement leaderboard
    std::vector<LeaderboardEntry> GetAchievementLeaderboard(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        
        std::string orderBy = "a.total_points DESC";
        
        if (subcat == "achieve_completed")
        {
            orderBy = "a.achievements_completed DESC";
        }
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, a.total_points, a.achievements_completed "
            "FROM dc_player_achievements a "
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
            
            if (subcat == "achieve_completed")
            {
                entry.score = fields[3].Get<uint32>();
                entry.extra = std::to_string(fields[2].Get<uint32>()) + " pts";
            }
            else  // achieve_points
            {
                entry.score = fields[2].Get<uint32>();
                entry.extra = std::to_string(fields[3].Get<uint32>()) + " achieved";
            }
            
            entries.push_back(entry);
        } while (result->NextRow());
        
        return entries;
    }
    
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
    
    // Get total entry count for pagination
    uint32 GetTotalEntryCount(const std::string& category, const std::string& subcat, uint32 seasonId)
    {
        QueryResult result = nullptr;
        
        if (category == "mplus")
        {
            result = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_mplus_scores WHERE season_id = {}", seasonId);
        }
        else if (category == "seasons")
        {
            result = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_player_season_data WHERE season_id = {}", seasonId);
        }
        else if (category == "hlbg")
        {
            result = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_hlbg_player_stats WHERE season_id = {}", seasonId);
        }
        else if (category == "prestige")
        {
            result = CharacterDatabase.Query("SELECT COUNT(*) FROM dc_player_artifact_mastery");
        }
        else if (category == "upgrade")
        {
            result = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_player_season_data WHERE season_id = {}", seasonId);
        }
        else if (category == "duel")
        {
            result = CharacterDatabase.Query("SELECT COUNT(*) FROM dc_duel_stats");
        }
        else if (category == "aoe")
        {
            result = CharacterDatabase.Query("SELECT COUNT(*) FROM dc_aoe_loot_stats");
        }
        else if (category == "achieve")
        {
            result = CharacterDatabase.Query("SELECT COUNT(*) FROM dc_player_achievements");
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
        uint32 seasonId = json["seasonId"].IsNumber() ? json["seasonId"].AsUInt32() : 1;  // TODO: Get current season
        
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
            entries = GetMythicPlusLeaderboard(subcategory, seasonId, limit, offset);
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
        uint32 seasonId = 1;  // TODO: Get current season
        
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
    
    void HandleError(Player* player, const std::string& message)
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
