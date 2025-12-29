/*
 * DarkChaos Item Upgrade - Progression System Implementation (Phase 4B)
 *
 * Implements:
 * - Tier progression management
 * - Level caps and tier unlocking
 * - Weekly spending caps
 * - Artifact Mastery system (renamed from "Prestige" to avoid conflict with DarkChaos Prestige System)
 * - Player progression tracking
 * - Test set command for class-specific gear
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "ItemUpgradeManager.h"
#include "ItemUpgradeProgression.h"
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <cstdlib>

using namespace Acore::ChatCommands;
using namespace DarkChaos::ItemUpgrade;

// =====================================================================
// Artifact Mastery Manager Implementation (renamed from Prestige)
// =====================================================================

class ArtifactMasteryManagerImpl : public ArtifactMasteryManager
{
private:
    std::map<uint32, PlayerArtifactMasteryInfo> mastery_cache;

public:
    PlayerArtifactMasteryInfo* GetMasteryInfo(uint32 player_guid) override
    {
        // Check cache
        auto it = mastery_cache.find(player_guid);
        if (it != mastery_cache.end())
            return &it->second;

        // Load from database
        QueryResult result = CharacterDatabase.Query(
            "SELECT total_mastery_points, mastery_rank, mastery_points_this_rank, "
            "items_fully_upgraded, total_upgrades_applied, last_upgrade_timestamp "
            "FROM dc_player_artifact_mastery WHERE player_guid = {}",
            player_guid);

        PlayerArtifactMasteryInfo info;
        info.player_guid = player_guid;

        if (result)
        {
            Field* fields = result->Fetch();
            info.total_mastery_points = fields[0].Get<uint32>();
            info.mastery_rank = fields[1].Get<uint8>();
            info.mastery_points_this_rank = fields[2].Get<uint32>();
            info.items_fully_upgraded = fields[3].Get<uint32>();
            info.total_upgrades_applied = fields[4].Get<uint32>();
            info.last_upgrade_timestamp = fields[5].Get<uint64>();
        }

        info.mastery_title = info.GetMasteryTitle();
        mastery_cache[player_guid] = info;

        return &mastery_cache[player_guid];
    }

    void AwardMasteryPoints(uint32 player_guid, uint32 points) override
    {
        PlayerArtifactMasteryInfo* info = GetMasteryInfo(player_guid);
        if (!info)
            return;

        info->total_mastery_points += points;
        info->mastery_points_this_rank += points;

        // Check for rank up (1000 points per rank)
        const uint32 POINTS_PER_RANK = 1000;
        while (info->mastery_points_this_rank >= POINTS_PER_RANK)
        {
            info->mastery_rank++;
            info->mastery_points_this_rank -= POINTS_PER_RANK;

            // Notify player of rank up
            NotifyMasteryRankUp(player_guid, info->mastery_rank);

            // Check for automatic tier unlocks
            CheckTierUnlocks(player_guid, info->mastery_rank);
        }

        info->mastery_title = info->GetMasteryTitle();
        SaveMasteryInfo(*info);

        // Update cache
        mastery_cache[player_guid] = *info;
    }

    void IncrementFullyUpgradedCount(uint32 player_guid) override
    {
        PlayerArtifactMasteryInfo* info = GetMasteryInfo(player_guid);
        if (!info)
            return;

        info->items_fully_upgraded++;
        info->total_upgrades_applied++;
        info->last_upgrade_timestamp = time(nullptr);

        SaveMasteryInfo(*info);
    }

    std::vector<PlayerArtifactMasteryInfo> GetMasteryLeaderboard(uint32 limit = 10) override
    {
        std::vector<PlayerArtifactMasteryInfo> leaderboard;

        QueryResult result = CharacterDatabase.Query(
            "SELECT player_guid, total_mastery_points, mastery_rank, mastery_points_this_rank, "
            "items_fully_upgraded, total_upgrades_applied, last_upgrade_timestamp "
            "FROM dc_player_artifact_mastery "
            "ORDER BY total_mastery_points DESC "
            "LIMIT {}",
            limit);

        if (!result)
            return leaderboard;

        do
        {
            Field* fields = result->Fetch();
            PlayerArtifactMasteryInfo info;
            info.player_guid = fields[0].Get<uint32>();
            info.total_mastery_points = fields[1].Get<uint32>();
            info.mastery_rank = fields[2].Get<uint8>();
            info.mastery_points_this_rank = fields[3].Get<uint32>();
            info.items_fully_upgraded = fields[4].Get<uint32>();
            info.total_upgrades_applied = fields[5].Get<uint32>();
            info.last_upgrade_timestamp = fields[6].Get<uint64>();
            info.mastery_title = info.GetMasteryTitle();

            leaderboard.push_back(info);
        } while (result->NextRow());

        return leaderboard;
    }

    uint32 GetPlayerMasteryRank(uint32 player_guid) override
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(*) + 1 FROM dc_player_artifact_mastery "
            "WHERE total_mastery_points > ("
            "  SELECT total_mastery_points FROM dc_player_artifact_mastery WHERE player_guid = {}"
            ")",
            player_guid);

        return result ? result->Fetch()[0].Get<uint32>() : 0;
    }

private:
    void SaveMasteryInfo(const PlayerArtifactMasteryInfo& info)
    {
        CharacterDatabase.Execute(
            "REPLACE INTO dc_player_artifact_mastery "
            "(player_guid, total_mastery_points, mastery_rank, mastery_points_this_rank, "
            "items_fully_upgraded, total_upgrades_applied, last_upgrade_timestamp) "
            "VALUES ({}, {}, {}, {}, {}, {}, {})",
            info.player_guid, info.total_mastery_points, info.mastery_rank,
            info.mastery_points_this_rank, info.items_fully_upgraded,
            info.total_upgrades_applied, info.last_upgrade_timestamp);
    }

    void NotifyMasteryRankUp(uint32 player_guid, uint8 new_rank)
    {
        // Send congratulation message to player
        QueryResult result = CharacterDatabase.Query(
            "SELECT mastery_rank FROM dc_player_artifact_mastery WHERE player_guid = {}",
            player_guid);

        // Would normally get player session and send message
        // For now, just log to database
        CharacterDatabase.Execute(
            "INSERT INTO dc_artifact_mastery_events (player_guid, event_type, new_rank, timestamp) "
            "VALUES ({}, 'RANK_UP', {}, UNIX_TIMESTAMP())",
            player_guid, new_rank);
    }

    void CheckTierUnlocks(uint32 player_guid, uint8 mastery_rank)
    {
        // Unlock Mythic tier at rank 5
        if (mastery_rank >= 5)
        {
            // Check if already unlocked
            QueryResult checkResult = CharacterDatabase.Query(
                "SELECT 1 FROM dc_player_tier_unlocks WHERE player_guid = {} AND tier_id = 4",
                player_guid);

            if (!checkResult)
            {
                // Unlock the tier
                CharacterDatabase.Execute(
                    "INSERT IGNORE INTO dc_player_tier_unlocks (player_guid, tier_id, unlocked_timestamp) "
                    "VALUES ({}, 4, UNIX_TIMESTAMP())",
                    player_guid);

                // Log the event
                CharacterDatabase.Execute(
                    "INSERT INTO dc_artifact_mastery_events (player_guid, event_type, tier_unlocked, timestamp) "
                    "VALUES ({}, 'TIER_UNLOCK', 4, UNIX_TIMESTAMP())",
                    player_guid);
            }
        }

        // Unlock Artifact tier at rank 10
        if (mastery_rank >= 10)
        {
            // Check if already unlocked
            QueryResult checkResult = CharacterDatabase.Query(
                "SELECT 1 FROM dc_player_tier_unlocks WHERE player_guid = {} AND tier_id = 5",
                player_guid);

            if (!checkResult)
            {
                // Unlock the tier
                CharacterDatabase.Execute(
                    "INSERT IGNORE INTO dc_player_tier_unlocks (player_guid, tier_id, unlocked_timestamp) "
                    "VALUES ({}, 5, UNIX_TIMESTAMP())",
                    player_guid);

                // Log the event
                CharacterDatabase.Execute(
                    "INSERT INTO dc_artifact_mastery_events (player_guid, event_type, tier_unlocked, timestamp) "
                    "VALUES ({}, 'TIER_UNLOCK', 5, UNIX_TIMESTAMP())",
                    player_guid);
            }
        }
    }
};

// =====================================================================
// Level Cap Manager Implementation
// =====================================================================

class LevelCapManagerImpl : public LevelCapManager
{
private:
    std::map<uint64, std::map<uint8, uint8>> player_tier_caps;  // player_guid -> tier_id -> max_level
    std::map<uint64, std::set<uint8>> unlocked_tiers;           // player_guid -> set of unlocked tiers

public:
    bool CanUpgradeToLevel(uint32 player_guid, uint8 target_level, uint8 tier_id) const override
    {
        uint8 max_level = GetPlayerMaxUpgradeLevel(player_guid, tier_id);
        return target_level <= max_level && IsTierUnlocked(player_guid, tier_id);
    }

    uint8 GetPlayerMaxUpgradeLevel(uint32 player_guid, uint8 tier_id) const override
    {
        // Check database first
        QueryResult result = CharacterDatabase.Query(
            "SELECT max_level FROM dc_player_tier_caps WHERE player_guid = {} AND tier_id = {}",
            player_guid, tier_id);

        if (result)
            return result->Fetch()[0].Get<uint8>();

        // Default caps based on tier
        TierProgressionManager tierMgr;
        return tierMgr.GetMaxUpgradeLevel(tier_id);
    }

    void SetPlayerTierCap(uint32 player_guid, uint8 tier_id, uint8 max_level) override
    {
        CharacterDatabase.Execute(
            "REPLACE INTO dc_player_tier_caps (player_guid, tier_id, max_level, last_updated) "
            "VALUES ({}, {}, {}, UNIX_TIMESTAMP())",
            player_guid, tier_id, max_level);
    }

    bool IsTierUnlocked(uint32 player_guid, uint8 tier_id) const override
    {
        // Tiers 1-3 are always unlocked
        if (tier_id <= 3)
            return true;

        // Check if manually unlocked by GM
        QueryResult result = CharacterDatabase.Query(
            "SELECT 1 FROM dc_player_tier_unlocks WHERE player_guid = {} AND tier_id = {}",
            player_guid, tier_id);

        if (result)
            return true;

        // Check mastery requirements for automatic unlocks
        ArtifactMasteryManagerImpl masteryMgr;
        PlayerArtifactMasteryInfo* info = masteryMgr.GetMasteryInfo(player_guid);
        if (!info)
            return false;

        // Tier unlock requirements based on mastery rank
        switch (tier_id)
        {
            case 4: // Mythic tier - requires rank 5
                return info->mastery_rank >= 5;
            case 5: // Artifact tier - requires rank 10
                return info->mastery_rank >= 10;
            default:
                return false;
        }
    }

    void UnlockTier(uint32 player_guid, uint8 tier_id) override
    {
        CharacterDatabase.Execute(
            "INSERT IGNORE INTO dc_player_tier_unlocks (player_guid, tier_id, unlocked_timestamp) "
            "VALUES ({}, {}, UNIX_TIMESTAMP())",
            player_guid, tier_id);
    }
};

// =====================================================================
// Cost Scaling Manager Implementation
// =====================================================================

class CostScalingManagerImpl : public CostScalingManager
{
private:
    CostScalingConfig config;

public:
    CostScalingManagerImpl()
    {
        // Default config already initialized in base class
    }

    bool HasHitWeeklyCap(uint32 player_guid, CurrencyType currency) const override
    {
        if (!config.enable_weekly_caps)
            return false;

        uint32 spent = GetWeeklySpending(player_guid, currency);
        uint32 hard_cap = (currency == CURRENCY_ARTIFACT_ESSENCE) ?
            config.hardcap_weekly_essence : config.hardcap_weekly_tokens;

        return spent >= hard_cap;
    }

    uint32 GetWeeklyRemainingBudget(uint32 player_guid, CurrencyType currency) const override
    {
        if (!config.enable_weekly_caps)
            return 999999;  // Effectively unlimited

        uint32 spent = GetWeeklySpending(player_guid, currency);
        uint32 hard_cap = (currency == CURRENCY_ARTIFACT_ESSENCE) ?
            config.hardcap_weekly_essence : config.hardcap_weekly_tokens;

        return (spent < hard_cap) ? (hard_cap - spent) : 0;
    }

    uint32 GetWeeklySpending(uint32 player_guid, CurrencyType currency) const override
    {
        // Get start of current week (Sunday 00:00)
        time_t now = time(nullptr);
        struct tm* timeinfo = localtime(&now);
        timeinfo->tm_hour = 0;
        timeinfo->tm_min = 0;
        timeinfo->tm_sec = 0;
        timeinfo->tm_mday -= timeinfo->tm_wday;  // Go back to Sunday
        time_t week_start = mktime(timeinfo);

        std::string column = (currency == CURRENCY_ARTIFACT_ESSENCE) ? "essence_spent" : "tokens_spent";

        QueryResult result = CharacterDatabase.Query(
            "SELECT {} FROM dc_weekly_spending WHERE player_guid = {} AND week_start = {}",
            column, player_guid, week_start);

        return result ? result->Fetch()[0].Get<uint32>() : 0;
    }
};

// =====================================================================
// Class-Specific Test Gear Configuration
// =====================================================================

struct ClassGearSet
{
    std::vector<uint32> item_ids;
    std::string description;
};

static const std::map<uint8, ClassGearSet> TEST_GEAR_SETS = {
    {CLASS_WARRIOR, {{48685, 48687, 48683, 48689, 48691, 50415, 50356}, "Warrior Tier 9.5 + Weapons"}},
    {CLASS_PALADIN, {{48627, 48625, 48623, 48621, 48629, 50415, 47661}, "Paladin Tier 9.5 + Weapons"}},
    {CLASS_HUNTER, {{48261, 48263, 48265, 48267, 48259, 50034, 47267}, "Hunter Tier 9.5 + Weapons"}},
    {CLASS_ROGUE, {{48221, 48223, 48225, 48227, 48229, 50276, 50415}, "Rogue Tier 9.5 + Weapons"}},
    {CLASS_PRIEST, {{48073, 48075, 48077, 48079, 48071, 50173, 50179}, "Priest Tier 9.5 + Weapons"}},
    {CLASS_DEATH_KNIGHT, {{48491, 48493, 48495, 48497, 48499, 50415}, "Death Knight Tier 9.5 + Weapon"}},
    {CLASS_SHAMAN, {{48313, 48315, 48317, 48319, 48321, 50428, 47666}, "Shaman Tier 9.5 + Weapons"}},
    {CLASS_MAGE, {{47751, 47753, 47755, 47757, 47749, 50173}, "Mage Tier 9.5 + Weapon"}},
    {CLASS_WARLOCK, {{47796, 47798, 47800, 47802, 47804, 50173}, "Warlock Tier 9.5 + Weapon"}},
    {CLASS_DRUID, {{48102, 48104, 48106, 48108, 48110, 50428, 47666}, "Druid Tier 9.5 + Weapons"}}
};

// =====================================================================
// Factory Function Implementations (Optimized for Singleton Access)
// =====================================================================

ArtifactMasteryManager* GetArtifactMasteryManager()
{
    static ArtifactMasteryManagerImpl instance;
    return &instance;
}

LevelCapManager* GetLevelCapManager()
{
    static LevelCapManagerImpl instance;
    return &instance;
}

CostScalingManager* GetCostScalingManager()
{
    static CostScalingManagerImpl instance;
    return &instance;
}

TierProgressionManager* GetTierProgressionManager()
{
    static TierProgressionManager instance;
    return &instance;
}

// =====================================================================
// Progression Commands
// =====================================================================

class ItemUpgradeProgressionCommands : public CommandScript
{
public:
    ItemUpgradeProgressionCommands() : CommandScript("ItemUpgradeProgressionCommands") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable upgradeProgressionCommandTable =
        {
            { "tiercap", HandleTierCapCommand, SEC_GAMEMASTER, Console::No },
            { "testset", HandleTestSetCommand, SEC_GAMEMASTER, Console::No }
        };

        static ChatCommandTable commandTable =
        {
            { "upgradeprog", upgradeProgressionCommandTable }
        };

        return commandTable;
    }

    static bool HandleTierCapCommand(ChatHandler* handler, const char* args)
    {
        if (!*args)
        {
            handler->PSendSysMessage("Usage: .upgradeprog tiercap <tier_id> <max_level>");
            return false;
        }

        char* tier_str = strtok((char*)args, " ");
        char* level_str = strtok(nullptr, " ");

        if (!tier_str || !level_str)
        {
            handler->PSendSysMessage("Usage: .upgradeprog tiercap <tier_id> <max_level>");
            return false;
        }

        uint8 tier_id = static_cast<uint8>(std::strtoul(tier_str, nullptr, 10));
        uint8 max_level = static_cast<uint8>(std::strtoul(level_str, nullptr, 10));

        Player* target = handler->getSelectedPlayer();
        if (!target)
        {
            handler->PSendSysMessage("No player selected.");
            return false;
        }

        LevelCapManagerImpl capMgr;
        capMgr.SetPlayerTierCap(target->GetGUID().GetCounter(), tier_id, max_level);

        handler->PSendSysMessage("Set tier %u max level to %u for %s.",
            tier_id, max_level, target->GetName().c_str());

        return true;
    }

    static bool HandleTestSetCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        uint8 playerClass = player->getClass();
        auto it = TEST_GEAR_SETS.find(playerClass);

        if (it == TEST_GEAR_SETS.end())
        {
            handler->PSendSysMessage("No test gear set configured for your class.");
            return false;
        }

        const ClassGearSet& gearSet = it->second;

        // Grant test items
        uint32 items_added = 0;
        for (uint32 itemId : gearSet.item_ids)
        {
            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1);
            if (msg == EQUIP_ERR_OK)
            {
                Item* item = player->StoreNewItem(dest, itemId, true);
                if (item)
                {
                    player->SendNewItem(item, 1, true, false);
                    items_added++;
                }
            }
        }

        // Grant currency (support for canonical seasonal currency)
        uint32 ESSENCE_ID = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();
        uint32 TOKEN_ID = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
        const uint32 TEST_ESSENCE_AMOUNT = 5000;  // From config: ItemUpgrade.Test.EssenceGrant
        const uint32 TEST_TOKEN_AMOUNT = 2500;    // From config: ItemUpgrade.Test.TokensGrant

        // Grant essence
        ItemPosCountVec essenceDest;
        InventoryResult essenceMsg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, essenceDest, ESSENCE_ID, TEST_ESSENCE_AMOUNT);
        if (essenceMsg == EQUIP_ERR_OK)
        {
            Item* essence = player->StoreNewItem(essenceDest, ESSENCE_ID, true);
            if (essence)
            {
                player->SendNewItem(essence, TEST_ESSENCE_AMOUNT, true, false);
            }
        }

        // Grant tokens
        ItemPosCountVec tokenDest;
        InventoryResult tokenMsg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, tokenDest, TOKEN_ID, TEST_TOKEN_AMOUNT);
        if (tokenMsg == EQUIP_ERR_OK)
        {
            Item* tokens = player->StoreNewItem(tokenDest, TOKEN_ID, true);
            if (tokens)
            {
                player->SendNewItem(tokens, TEST_TOKEN_AMOUNT, true, false);
            }
        }

        handler->PSendSysMessage("|cffffd700===== Test Set Granted =====|r");
        handler->PSendSysMessage("|cff00ff00Class:|r %s", player->GetName().c_str());
        handler->PSendSysMessage("|cff00ff00Gear Set:|r %s", gearSet.description.c_str());
        handler->PSendSysMessage("|cff00ff00Items Added:|r %u", items_added);
        handler->PSendSysMessage("|cff00ff00Upgrade Essence:|r %u", TEST_ESSENCE_AMOUNT);
        handler->PSendSysMessage("|cff00ff00Upgrade Tokens:|r %u", TEST_TOKEN_AMOUNT);
        handler->PSendSysMessage("|cff00ffffYou can now test the upgrade system!|r");

        return true;
    }
};

// =====================================================================
// Script Registration
// =====================================================================

void AddSC_ItemUpgradeProgression()
{
    new ItemUpgradeProgressionCommands();
}
