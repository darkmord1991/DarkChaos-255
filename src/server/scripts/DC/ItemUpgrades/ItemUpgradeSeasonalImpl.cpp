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
#include "ItemUpgradeSeasonResolver.h"
#include "../Seasons/SeasonalSystem.h" // Include Seasonal System
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <cstdlib>

namespace DarkChaos { namespace ItemUpgrade {

using namespace Acore::ChatCommands;

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

        // Calculate carryover currencies (migrate old season balances into the new season)
        uint32 old_season_id = GetCurrentSeasonId();
        if (old_season_id == 0)
            old_season_id = 1;

        uint32 essence = 0;
        uint32 tokens = 0;

        QueryResult result = CharacterDatabase.Query(
            "SELECT currency_type, amount FROM dc_player_upgrade_tokens "
            "WHERE player_guid = {} AND season = {} AND currency_type IN ('artifact_essence', 'upgrade_token')",
            player_guid, old_season_id);

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                std::string currency = fields[0].Get<std::string>();
                uint32 amount = fields[1].Get<uint32>();

                if (currency == "artifact_essence")
                    essence = amount;
                else if (currency == "upgrade_token")
                    tokens = amount;
            } while (result->NextRow());
        }

        uint32 essence_percent = config.reset_currencies ? config.essence_carryover_percent : 100;
        uint32 token_percent = config.reset_currencies ? config.token_carryover_percent : 100;
        uint32 essence_carryover = (essence * essence_percent) / 100;
        uint32 tokens_carryover = (tokens * token_percent) / 100;

        // Move balances into the new season (and clear old season balances so they can't leak)
        if (old_season_id != new_season_id)
        {
            CharacterDatabase.Execute(
                "UPDATE dc_player_upgrade_tokens SET amount = 0 "
                "WHERE player_guid = {} AND season = {} AND currency_type IN ('artifact_essence', 'upgrade_token')",
                player_guid, old_season_id);
        }

        CharacterDatabase.Execute(
            "INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season) "
            "VALUES ({}, 'artifact_essence', {}, {}) "
            "ON DUPLICATE KEY UPDATE amount = {}",
            player_guid, essence_carryover, new_season_id, essence_carryover);

        CharacterDatabase.Execute(
            "INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season) "
            "VALUES ({}, 'upgrade_token', {}, {}) "
            "ON DUPLICATE KEY UPDATE amount = {}",
            player_guid, tokens_carryover, new_season_id, tokens_carryover);

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

        // =====================================================================
        // Factory Function Implementations (Optimized for Singleton Access)
        // =====================================================================

        SeasonResetManager* GetSeasonResetManager()
        {
            static SeasonResetManagerImpl instance;
            return &instance;
        }

        HistoryManager* GetHistoryManager()
        {
            static HistoryManagerImpl instance;
            return &instance;
        }

        LeaderboardManager* GetLeaderboardManager()
        {
            static LeaderboardManagerImpl instance;
            return &instance;
        }

        BalanceManager* GetBalanceManager()
        {
             static BalanceManager instance;
             return &instance;
        }

        SeasonManager* GetSeasonManager()
        {
            static SeasonManager instance;
            return &instance;
        }

} } // namespace DarkChaos::ItemUpgrade

void AddSC_ItemUpgradeSeasonal()
{
    // Register Item Upgrade System with Seasonal Manager
    using namespace DarkChaos::Seasonal;

    SystemRegistration reg;
    reg.system_name = "item_upgrades";
    reg.system_version = "4.0";
    reg.priority = 100;

    // Map Seasonal System events to Item Upgrade Manager logic
    
    // On Player Season Change
    reg.on_player_season_change = [](uint32 player_guid, uint32 old_season, uint32 new_season) {
        (void)old_season;
        // We use the reset manager to handle the complex logic of resetting/archiving/carrying over
        DarkChaos::ItemUpgrade::GetSeasonResetManager()->ResetPlayerForSeason(player_guid, new_season);
    };

    // On Season Event (Start/End)
    reg.on_season_event = [](uint32 season_id, SeasonEventType event_type) {
        if (event_type == SEASON_EVENT_START) {
            // Trigger global reset logic if needed, simplify leaderboards
             DarkChaos::ItemUpgrade::GetLeaderboardManager()->UpdateLeaderboards(season_id);
        }
    };

    // Initialize - Ensure data exists if needed
    reg.initialize_player_data = [](uint32 player_guid, uint32 season_id) {
         // Create initial structure if missing
         CharacterDatabase.Execute(
            "INSERT IGNORE INTO dc_player_season_data "
            "(player_guid, season_id, essence_earned, tokens_earned, "
            "essence_spent, tokens_spent, first_upgrade_timestamp) "
            "VALUES ({}, {}, 0, 0, 0, 0, UNIX_TIMESTAMP())",
            player_guid, season_id);
    };

    if (GetSeasonalManager()) {
        GetSeasonalManager()->RegisterSystem(reg);
    }
}
