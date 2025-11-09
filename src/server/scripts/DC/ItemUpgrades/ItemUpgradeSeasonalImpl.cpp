/*
 * DarkChaos Item Upgrade - Seasonal System Implementation (Phase 4C)
 * 
 * Implements:
 * - Season management and tracking
 * - Season transitions and resets
 * - Player season data
 * - Season leaderboards
 * - Upgrade history tracking
 * 
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "ItemUpgradeSeasonal.h"
#include "ItemUpgradeManager.h"
#include <sstream>
#include <iomanip>
#include <algorithm>

using namespace Acore::ChatCommands;
using namespace DarkChaos::ItemUpgrade;

// =====================================================================
// Season Reset Manager Implementation
// =====================================================================

class SeasonResetManagerImpl : public SeasonResetManager
{
private:
    SeasonResetConfig config;

public:
    SeasonResetManagerImpl() = default;

    void ResetPlayerForSeason(uint32 player_guid, uint32 new_season_id) override
    {
        // Archive current season data
        CharacterDatabase.Execute(
            "INSERT INTO dc_season_history "
            "SELECT {}, * FROM dc_player_season_data WHERE player_guid = {}",
            new_season_id, player_guid);
        
        if (config.reset_item_upgrades)
        {
            // Reset all item upgrades
            CharacterDatabase.Execute(
                "UPDATE {} SET upgrade_level = 0, "
                "stat_multiplier = 1.0 "
                "WHERE player_guid = {}",
                ITEM_UPGRADES_TABLE, player_guid);
        }
        
        // Calculate carryover currencies
        QueryResult result = CharacterDatabase.Query(
            "SELECT essence, tokens FROM dc_player_upgrade_tokens WHERE player_guid = {}",
            player_guid);
        
        if (result)
        {
            Field* fields = result->Fetch();
            uint32 essence = fields[0].Get<uint32>();
            uint32 tokens = fields[1].Get<uint32>();
            
            if (config.reset_currencies)
            {
                uint32 essence_carryover = (essence * config.essence_carryover_percent) / 100;
                uint32 tokens_carryover = (tokens * config.token_carryover_percent) / 100;
                
                CharacterDatabase.Execute(
                    "UPDATE dc_player_upgrade_tokens SET essence = {}, tokens = {} "
                    "WHERE player_guid = {}",
                    essence_carryover, tokens_carryover, player_guid);
            }
        }
        
        // Reset weekly spending counters
        CharacterDatabase.Execute(
            "DELETE FROM dc_weekly_spending WHERE player_guid = {}",
            player_guid);
        
        // Create new season data entry
        CharacterDatabase.Execute(
            "INSERT INTO dc_player_season_data "
            "(player_guid, season_id, essence_earned, tokens_earned, "
            "essence_spent, tokens_spent, first_upgrade_timestamp) "
            "VALUES ({}, {}, 0, 0, 0, 0, UNIX_TIMESTAMP())",
            player_guid, new_season_id);
    }

    void ExecuteGlobalSeasonReset(uint32 new_season_id) override
    {
        // Get all players with upgrade data
        QueryResult result = CharacterDatabase.Query(
            "SELECT DISTINCT player_guid FROM {}", ITEM_UPGRADES_TABLE);
        
        if (!result)
            return;
        
        do
        {
            uint32 player_guid = result->Fetch()[0].Get<uint32>();
            ResetPlayerForSeason(player_guid, new_season_id);
        } while (result->NextRow());
        
        // Update season status
        CharacterDatabase.Execute(
            "UPDATE dc_seasons SET is_active = 0 WHERE is_active = 1");
        
        CharacterDatabase.Execute(
            "INSERT INTO dc_seasons (season_id, season_name, start_timestamp, is_active) "
            "VALUES ({}, 'Season {}', UNIX_TIMESTAMP(), 1)",
            new_season_id, new_season_id);
    }
};

// =====================================================================
// History Manager Implementation
// =====================================================================

class HistoryManagerImpl : public HistoryManager
{
public:
    void RecordUpgrade(const UpgradeHistoryEntry& entry) override
    {
        CharacterDatabase.Execute(
            "INSERT INTO dc_upgrade_history "
            "(player_guid, item_guid, item_id, season_id, upgrade_from, upgrade_to, "
            "essence_cost, token_cost, timestamp, old_ilvl, new_ilvl) "
            "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {})",
            entry.player_guid, entry.item_guid, entry.item_id, entry.season_id,
            entry.upgrade_from, entry.upgrade_to, entry.essence_cost, entry.token_cost,
            entry.timestamp, entry.old_ilvl, entry.new_ilvl);
    }

    std::vector<UpgradeHistoryEntry> GetPlayerHistory(uint32 player_guid, uint32 limit = 100) override
    {
        std::vector<UpgradeHistoryEntry> history;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT player_guid, item_guid, item_id, season_id, upgrade_from, upgrade_to, "
            "essence_cost, token_cost, timestamp, old_ilvl, new_ilvl "
            "FROM dc_upgrade_history "
            "WHERE player_guid = {} "
            "ORDER BY timestamp DESC "
            "LIMIT {}",
            player_guid, limit);
        
        if (!result)
            return history;
        
        do
        {
            UpgradeHistoryEntry entry;
            Field* fields = result->Fetch();
            entry.player_guid = fields[0].Get<uint32>();
            entry.item_guid = fields[1].Get<uint32>();
            entry.item_id = fields[2].Get<uint32>();
            entry.season_id = fields[3].Get<uint8>();
            entry.upgrade_from = fields[4].Get<uint8>();
            entry.upgrade_to = fields[5].Get<uint8>();
            entry.essence_cost = fields[6].Get<uint32>();
            entry.token_cost = fields[7].Get<uint32>();
            entry.timestamp = fields[8].Get<uint64>();
            entry.old_ilvl = fields[9].Get<uint16>();
            entry.new_ilvl = fields[10].Get<uint16>();
            
            history.push_back(entry);
        } while (result->NextRow());
        
        return history;
    }

    std::vector<UpgradeHistoryEntry> GetSeasonHistory(uint32 player_guid, uint32 season_id) override
    {
        std::vector<UpgradeHistoryEntry> history;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT player_guid, item_guid, item_id, season_id, upgrade_from, upgrade_to, "
            "essence_cost, token_cost, timestamp, old_ilvl, new_ilvl "
            "FROM dc_upgrade_history "
            "WHERE player_guid = {} AND season_id = {} "
            "ORDER BY timestamp DESC",
            player_guid, season_id);
        
        if (!result)
            return history;
        
        do
        {
            UpgradeHistoryEntry entry;
            Field* fields = result->Fetch();
            entry.player_guid = fields[0].Get<uint32>();
            entry.item_guid = fields[1].Get<uint32>();
            entry.item_id = fields[2].Get<uint32>();
            entry.season_id = fields[3].Get<uint8>();
            entry.upgrade_from = fields[4].Get<uint8>();
            entry.upgrade_to = fields[5].Get<uint8>();
            entry.essence_cost = fields[6].Get<uint32>();
            entry.token_cost = fields[7].Get<uint32>();
            entry.timestamp = fields[8].Get<uint64>();
            entry.old_ilvl = fields[9].Get<uint16>();
            entry.new_ilvl = fields[10].Get<uint16>();
            
            history.push_back(entry);
        } while (result->NextRow());
        
        return history;
    }

    std::vector<UpgradeHistoryEntry> GetItemHistory(uint32 item_guid) override
    {
        std::vector<UpgradeHistoryEntry> history;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT player_guid, item_guid, item_id, season_id, upgrade_from, upgrade_to, "
            "essence_cost, token_cost, timestamp, old_ilvl, new_ilvl "
            "FROM dc_upgrade_history "
            "WHERE item_guid = {} "
            "ORDER BY timestamp ASC",
            item_guid);
        
        if (!result)
            return history;
        
        do
        {
            UpgradeHistoryEntry entry;
            Field* fields = result->Fetch();
            entry.player_guid = fields[0].Get<uint32>();
            entry.item_guid = fields[1].Get<uint32>();
            entry.item_id = fields[2].Get<uint32>();
            entry.season_id = fields[3].Get<uint8>();
            entry.upgrade_from = fields[4].Get<uint8>();
            entry.upgrade_to = fields[5].Get<uint8>();
            entry.essence_cost = fields[6].Get<uint32>();
            entry.token_cost = fields[7].Get<uint32>();
            entry.timestamp = fields[8].Get<uint64>();
            entry.old_ilvl = fields[9].Get<uint16>();
            entry.new_ilvl = fields[10].Get<uint16>();
            
            history.push_back(entry);
        } while (result->NextRow());
        
        return history;
    }

    std::vector<UpgradeHistoryEntry> GetRecentUpgrades(uint32 limit = 50) override
    {
        std::vector<UpgradeHistoryEntry> history;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT player_guid, item_guid, item_id, season_id, upgrade_from, upgrade_to, "
            "essence_cost, token_cost, timestamp, old_ilvl, new_ilvl "
            "FROM dc_upgrade_history "
            "ORDER BY timestamp DESC "
            "LIMIT {}",
            limit);
        
        if (!result)
            return history;
        
        do
        {
            UpgradeHistoryEntry entry;
            Field* fields = result->Fetch();
            entry.player_guid = fields[0].Get<uint32>();
            entry.item_guid = fields[1].Get<uint32>();
            entry.item_id = fields[2].Get<uint32>();
            entry.season_id = fields[3].Get<uint8>();
            entry.upgrade_from = fields[4].Get<uint8>();
            entry.upgrade_to = fields[5].Get<uint8>();
            entry.essence_cost = fields[6].Get<uint32>();
            entry.token_cost = fields[7].Get<uint32>();
            entry.timestamp = fields[8].Get<uint64>();
            entry.old_ilvl = fields[9].Get<uint16>();
            entry.new_ilvl = fields[10].Get<uint16>();
            
            history.push_back(entry);
        } while (result->NextRow());
        
        return history;
    }
};

// =====================================================================
// Leaderboard Manager Implementation
// =====================================================================

class LeaderboardManagerImpl : public LeaderboardManager
{
public:
    std::vector<LeaderboardEntry> GetUpgradeLeaderboard(uint32 season_id, uint32 limit = 25) override
    {
        std::vector<LeaderboardEntry> leaderboard;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT d.player_guid, c.name, d.upgrades_applied, d.items_upgraded, "
            "p.total_prestige_points, p.prestige_rank "
            "FROM dc_player_season_data d "
            "LEFT JOIN characters c ON c.guid = d.player_guid "
            "LEFT JOIN dc_player_artifact_mastery p ON p.player_guid = d.player_guid "
            "WHERE d.season_id = {} "
            "ORDER BY d.upgrades_applied DESC "
            "LIMIT {}",
            season_id, limit);
        
        if (!result)
            return leaderboard;
        
        uint32 rank = 1;
        do
        {
            LeaderboardEntry entry;
            Field* fields = result->Fetch();
            entry.rank = rank++;
            entry.player_guid = fields[0].Get<uint32>();
            entry.player_name = fields[1].Get<std::string>();
            entry.score = fields[2].Get<uint32>();  // upgrades_applied
            entry.items_upgraded = fields[3].Get<uint32>();
            entry.prestige_points = fields[4].Get<uint32>();
            entry.prestige_rank = fields[5].Get<uint8>();
            
            leaderboard.push_back(entry);
        } while (result->NextRow());
        
        return leaderboard;
    }

    std::vector<LeaderboardEntry> GetPrestigeLeaderboard(uint32 season_id, uint32 limit = 25) override
    {
        std::vector<LeaderboardEntry> leaderboard;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT p.player_guid, c.name, p.total_prestige_points, p.prestige_rank, "
            "d.items_upgraded, d.upgrades_applied "
            "FROM dc_player_artifact_mastery p "
            "LEFT JOIN characters c ON c.guid = p.player_guid "
            "LEFT JOIN dc_player_season_data d ON d.player_guid = p.player_guid AND d.season_id = {} "
            "ORDER BY p.total_prestige_points DESC "
            "LIMIT {}",
            season_id, limit);
        
        if (!result)
            return leaderboard;
        
        uint32 rank = 1;
        do
        {
            LeaderboardEntry entry;
            Field* fields = result->Fetch();
            entry.rank = rank++;
            entry.player_guid = fields[0].Get<uint32>();
            entry.player_name = fields[1].Get<std::string>();
            entry.prestige_points = fields[2].Get<uint32>();
            entry.prestige_rank = fields[3].Get<uint8>();
            entry.items_upgraded = fields[4].Get<uint32>();
            entry.score = fields[5].Get<uint32>();
            
            leaderboard.push_back(entry);
        } while (result->NextRow());
        
        return leaderboard;
    }

    std::vector<LeaderboardEntry> GetEfficiencyLeaderboard(uint32 season_id, uint32 limit = 25) override
    {
        std::vector<LeaderboardEntry> leaderboard;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT d.player_guid, c.name, "
            "(CAST(d.upgrades_applied AS FLOAT) / GREATEST(d.essence_spent, 1)) as efficiency, "
            "d.upgrades_applied, d.items_upgraded, "
            "p.total_prestige_points, p.prestige_rank "
            "FROM dc_player_season_data d "
            "LEFT JOIN characters c ON c.guid = d.player_guid "
            "LEFT JOIN dc_player_artifact_mastery p ON p.player_guid = d.player_guid "
            "WHERE d.season_id = {} AND d.upgrades_applied > 0 "
            "ORDER BY efficiency DESC "
            "LIMIT {}",
            season_id, limit);
        
        if (!result)
            return leaderboard;
        
        uint32 rank = 1;
        do
        {
            LeaderboardEntry entry;
            Field* fields = result->Fetch();
            entry.rank = rank++;
            entry.player_guid = fields[0].Get<uint32>();
            entry.player_name = fields[1].Get<std::string>();
            entry.score = static_cast<uint32>(fields[2].Get<float>() * 1000);  // Efficiency * 1000
            entry.items_upgraded = fields[4].Get<uint32>();
            entry.prestige_points = fields[5].Get<uint32>();
            entry.prestige_rank = fields[6].Get<uint8>();
            
            leaderboard.push_back(entry);
        } while (result->NextRow());
        
        return leaderboard;
    }

    uint32 GetPlayerRank(uint32 player_guid, uint32 season_id) override
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(*) + 1 FROM dc_player_season_data "
            "WHERE season_id = {} AND upgrades_applied > ("
            "  SELECT upgrades_applied FROM dc_player_season_data "
            "  WHERE player_guid = {} AND season_id = {}"
            ")",
            season_id, player_guid, season_id);
        
        return result ? result->Fetch()[0].Get<uint32>() : 0;
    }

    void UpdateLeaderboards(uint32 season_id) override
    {
        // Cache leaderboard rankings for quick access
        CharacterDatabase.Execute(
            "REPLACE INTO dc_leaderboard_cache "
            "(season_id, player_guid, upgrade_rank, prestige_rank, efficiency_rank, last_updated) "
            "SELECT {}, player_guid, "
            "  (SELECT COUNT(*) + 1 FROM dc_player_season_data d2 "
            "   WHERE d2.season_id = d1.season_id AND d2.upgrades_applied > d1.upgrades_applied), "
            "  (SELECT COUNT(*) + 1 FROM dc_player_artifact_mastery p2 "
            "   WHERE p2.total_prestige_points > p1.total_prestige_points), "
            "  0, UNIX_TIMESTAMP() "
            "FROM dc_player_season_data d1 "
            "LEFT JOIN dc_player_artifact_mastery p1 ON p1.player_guid = d1.player_guid "
            "WHERE d1.season_id = {}",
            season_id, season_id);
    }
};

// =====================================================================
// Seasonal Commands
// =====================================================================

class ItemUpgradeSeasonalCommands : public CommandScript
{
public:
    ItemUpgradeSeasonalCommands() : CommandScript("ItemUpgradeSeasonalCommands") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable upgradeSeasonalCommandTable =
        {
            { "info",       HandleSeasonInfoCommand,    SEC_PLAYER, Console::No },
            { "leaderboard", HandleLeaderboardCommand,   SEC_PLAYER, Console::No },
            { "history",    HandleHistoryCommand,       SEC_PLAYER, Console::No },
            { "reset",      HandleSeasonResetCommand,   SEC_ADMINISTRATOR, Console::No },
        };
        
        static ChatCommandTable commandTable =
        {
            { "season", upgradeSeasonalCommandTable },
        };
        
        return commandTable;
    }

    static bool HandleSeasonInfoCommand(ChatHandler* handler, const char* /*args*/)
    {
        // Get current season
        QueryResult result = CharacterDatabase.Query(
            "SELECT season_id, season_name, start_timestamp FROM dc_seasons WHERE is_active = 1");
        
        if (!result)
        {
            handler->PSendSysMessage("No active season found.");
            return false;
        }
        
        Field* fields = result->Fetch();
        uint32 season_id = fields[0].Get<uint32>();
        std::string season_name = fields[1].Get<std::string>();
        uint64 start_time = fields[2].Get<uint64>();
        
        time_t now = time(nullptr);
        uint64 season_duration = now - start_time;
        uint32 days = season_duration / 86400;
        
        handler->PSendSysMessage("|cffffd700===== Season Information =====|r");
        handler->PSendSysMessage("|cff00ff00Current Season:|r %s (ID: %u)", season_name.c_str(), season_id);
        handler->PSendSysMessage("|cff00ff00Season Duration:|r %u days", days);
        
        // Get player's season stats
        Player* player = handler->GetSession()->GetPlayer();
        if (player)
        {
            result = CharacterDatabase.Query(
                "SELECT essence_earned, tokens_earned, essence_spent, tokens_spent, "
                "items_upgraded, upgrades_applied FROM dc_player_season_data "
                "WHERE player_guid = {} AND season_id = {}",
                player->GetGUID().GetCounter(), season_id);
            
            if (result)
            {
                fields = result->Fetch();
                handler->PSendSysMessage("");
                handler->PSendSysMessage("|cffffd700=== Your Season Stats ===|r");
                handler->PSendSysMessage("|cff00ff00Essence Earned:|r %u (Spent: %u)",
                    fields[0].Get<uint32>(), fields[2].Get<uint32>());
                handler->PSendSysMessage("|cff00ff00Tokens Earned:|r %u (Spent: %u)",
                    fields[1].Get<uint32>(), fields[3].Get<uint32>());
                handler->PSendSysMessage("|cff00ff00Items Upgraded:|r %u", fields[4].Get<uint32>());
                handler->PSendSysMessage("|cff00ff00Total Upgrades:|r %u", fields[5].Get<uint32>());
            }
        }
        
        return true;
    }

    static bool HandleLeaderboardCommand(ChatHandler* handler, const char* args)
    {
        std::string type = "upgrades";
        if (*args)
            type = args;
        
        // Get current season
        QueryResult result = CharacterDatabase.Query(
            "SELECT season_id FROM dc_seasons WHERE is_active = 1");
        
        if (!result)
        {
            handler->PSendSysMessage("No active season found.");
            return false;
        }
        
        uint32 season_id = result->Fetch()[0].Get<uint32>();
        
        LeaderboardManagerImpl leaderboardMgr;
        std::vector<LeaderboardEntry> entries;
        
        if (type == "prestige")
            entries = leaderboardMgr.GetPrestigeLeaderboard(season_id, 10);
        else if (type == "efficiency")
            entries = leaderboardMgr.GetEfficiencyLeaderboard(season_id, 10);
        else
            entries = leaderboardMgr.GetUpgradeLeaderboard(season_id, 10);
        
        handler->PSendSysMessage("|cffffd700===== %s Leaderboard =====|r", type.c_str());
        handler->PSendSysMessage("");
        
        for (const auto& entry : entries)
        {
            handler->PSendSysMessage("#%u - %s (Score: %u, Items: %u, Prestige: %u)",
                entry.rank, entry.player_name.c_str(), entry.score,
                entry.items_upgraded, entry.prestige_points);
        }
        
        return true;
    }

    static bool HandleHistoryCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;
        
        uint32 limit = 10;
        if (*args)
            limit = atoi(args);
        
        HistoryManagerImpl historyMgr;
        auto history = historyMgr.GetPlayerHistory(player->GetGUID().GetCounter(), limit);
        
        handler->PSendSysMessage("|cffffd700===== Your Upgrade History =====|r");
        handler->PSendSysMessage("(Showing last %u upgrades)", limit);
        handler->PSendSysMessage("");
        
        for (const auto& entry : history)
        {
            time_t timestamp = entry.timestamp;
            char time_buf[64];
            strftime(time_buf, sizeof(time_buf), "%Y-%m-%d %H:%M", localtime(&timestamp));
            
            handler->PSendSysMessage("%s: Item %u (%u→%u) | Cost: %uE/%uT | iLvl: %u→%u",
                time_buf, entry.item_id, entry.upgrade_from, entry.upgrade_to,
                entry.essence_cost, entry.token_cost, entry.old_ilvl, entry.new_ilvl);
        }
        
        return true;
    }

    static bool HandleSeasonResetCommand(ChatHandler* handler, const char* args)
    {
        if (!*args)
        {
            handler->PSendSysMessage("Usage: .season reset <new_season_id>");
            handler->PSendSysMessage("WARNING: This will reset all player progress!");
            return false;
        }
        
        uint32 new_season_id = atoi(args);
        
        handler->PSendSysMessage("Starting global season reset to Season %u...", new_season_id);
        
        SeasonResetManagerImpl resetMgr;
        resetMgr.ExecuteGlobalSeasonReset(new_season_id);
        
        handler->PSendSysMessage("Season reset complete! Season %u is now active.", new_season_id);
        
        return true;
    }
};

// =====================================================================
// Script Registration
// =====================================================================

void AddSC_ItemUpgradeSeasonal()
{
    new ItemUpgradeSeasonalCommands();
}
