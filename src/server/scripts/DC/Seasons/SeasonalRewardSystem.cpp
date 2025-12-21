/*
 * Seasonal Reward System Implementation - DarkChaos
 *
 * Core C++ implementation for seasonal rewards, caps, and progression
 *
 * Author: DarkChaos Development Team
 * Date: November 22, 2025
 */

#include "SeasonalRewardSystem.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Item.h"
#include "Chat.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include <sstream>

namespace DarkChaos
{
    namespace SeasonalRewards
    {
        // =====================================================================
        // Singleton Implementation
        // =====================================================================

        SeasonalRewardManager* SeasonalRewardManager::instance()
        {
            static SeasonalRewardManager instance;
            return &instance;
        }

        // =====================================================================
        // Initialization
        // =====================================================================

        void SeasonalRewardManager::LoadConfiguration()
        {
            config_.enabled = sConfigMgr->GetOption<bool>("SeasonalRewards.Enable", true);

            // Try to get active season from generic seasonal system first
            if (Seasonal::GetSeasonalManager())
            {
                auto* activeSeason = Seasonal::GetSeasonalManager()->GetActiveSeason();
                if (activeSeason)
                {
                    config_.activeSeason = activeSeason->season_id;
                    LOG_INFO("module", ">> [SeasonalRewards] Using season {} from SeasonalManager", config_.activeSeason);
                }
                else
                {
                    config_.activeSeason = sConfigMgr->GetOption<uint32>("SeasonalRewards.ActiveSeasonID", 1);
                    LOG_WARN("module", ">> [SeasonalRewards] No active season in SeasonalManager, using config: {}", config_.activeSeason);
                }
            }
            else
            {
                // Fallback to canonical DarkChaos.ActiveSeasonID
                config_.activeSeason = sConfigMgr->GetOption<uint32>("DarkChaos.ActiveSeasonID", 1);
                LOG_INFO("module", ">> [SeasonalRewards] SeasonalManager not available, using config season: {}", config_.activeSeason);
            }

            // Load canonical seasonal currency from DarkChaos.Seasonal.* (Section 9 unified settings)
            config_.tokenItemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
            config_.essenceItemId = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();
            config_.weeklyTokenCap = sConfigMgr->GetOption<uint32>("SeasonalRewards.MaxTokensPerWeek", 0);
            config_.weeklyEssenceCap = sConfigMgr->GetOption<uint32>("SeasonalRewards.MaxEssencePerWeek", 0);
            config_.questMultiplier = sConfigMgr->GetOption<float>("SeasonalRewards.QuestMultiplier", 1.0f);
            config_.creatureMultiplier = sConfigMgr->GetOption<float>("SeasonalRewards.CreatureMultiplier", 1.0f);
            config_.worldBossMultiplier = sConfigMgr->GetOption<float>("SeasonalRewards.WorldBossBonus", 1.5f);
            config_.eventBossMultiplier = sConfigMgr->GetOption<float>("SeasonalRewards.EventBossBonus", 1.25f);
            config_.logTransactions = sConfigMgr->GetOption<bool>("SeasonalRewards.LogTransactions", true);
            config_.achievementTracking = sConfigMgr->GetOption<bool>("SeasonalRewards.AchievementTracking", true);
            config_.resetDay = sConfigMgr->GetOption<uint8>("SeasonalRewards.WeeklyResetDay", WEEKLY_RESET_DAY);
            config_.resetHour = sConfigMgr->GetOption<uint8>("SeasonalRewards.WeeklyResetHour", WEEKLY_RESET_HOUR);

            LOG_INFO("module", ">> [SeasonalRewards] Configuration loaded:");
            LOG_INFO("module", ">>   Active Season: {}", config_.activeSeason);
            LOG_INFO("module", ">>   Token Item: {}, Essence Item: {}", config_.tokenItemId, config_.essenceItemId);
            LOG_INFO("module", ">>   Weekly Caps: {} tokens, {} essence",
                config_.weeklyTokenCap == 0 ? "unlimited" : std::to_string(config_.weeklyTokenCap),
                config_.weeklyEssenceCap == 0 ? "unlimited" : std::to_string(config_.weeklyEssenceCap));
        }

        void SeasonalRewardManager::LoadPlayerStats()
        {
            std::string sql = Acore::StringFormat("SELECT player_guid, season_id, total_tokens_earned, "
                "total_essence_earned, weekly_tokens_earned, weekly_essence_earned, quests_completed, "
                "bosses_killed, 0, 0, 0, weekly_reset_at, "
                "last_activity_at FROM dc_player_seasonal_stats WHERE season_id = {}", config_.activeSeason);

            QueryResult result = CharacterDatabase.Query(sql.c_str());

            if (!result)
            {
                LOG_INFO("module", ">> [SeasonalRewards] No player stats loaded (fresh season or no data)");
                return;
            }

            uint32 count = 0;
            do
            {
                Field* fields = result->Fetch();
                PlayerSeasonStats stats;
                stats.playerGuid = fields[0].Get<uint32>();
                stats.seasonId = fields[1].Get<uint32>();
                stats.seasonalTokensEarned = fields[2].Get<uint32>();
                stats.seasonalEssenceEarned = fields[3].Get<uint32>();
                stats.weeklyTokensEarned = fields[4].Get<uint32>();
                stats.weeklyEssenceEarned = fields[5].Get<uint32>();
                stats.questsCompleted = fields[6].Get<uint32>();
                stats.creaturesKilled = fields[7].Get<uint32>();
                stats.dungeonBossesKilled = fields[8].Get<uint32>();
                stats.worldBossesKilled = fields[9].Get<uint32>();
                stats.prestigeLevel = fields[10].Get<uint32>();
                stats.lastWeeklyReset = fields[11].Get<uint32>();
                stats.lastUpdated = fields[12].Get<uint32>();

                playerStats_[stats.playerGuid] = stats;
                count++;
            } while (result->NextRow());

            LOG_INFO("module", ">> [SeasonalRewards] Loaded {} player stats for season {}", count, config_.activeSeason);
        }

        void SeasonalRewardManager::Initialize()
        {
            if (!config_.enabled)
            {
                LOG_WARN("module", ">> [SeasonalRewards] System is DISABLED in config");
                return;
            }

            // Load quest rewards
            std::string questSql = Acore::StringFormat("SELECT quest_id, base_token_amount, base_essence_amount FROM dc_seasonal_quest_rewards WHERE season_id = {}", config_.activeSeason);
            QueryResult questResult = WorldDatabase.Query(questSql.c_str());
            if (questResult)
            {
                uint32 questCount = 0;
                do
                {
                    Field* fields = questResult->Fetch();
                    uint32 questId = fields[0].Get<uint32>();
                    uint32 tokens = fields[1].Get<uint32>();
                    uint32 essence = fields[2].Get<uint32>();
                    questRewards_[questId] = {tokens, essence};
                    questCount++;
                } while (questResult->NextRow());
                LOG_INFO("module", ">> [SeasonalRewards] Loaded {} quest rewards", questCount);
            }

            // Load creature rewards
            std::string creatureSql = Acore::StringFormat("SELECT creature_id, base_token_amount, base_essence_amount FROM dc_seasonal_creature_rewards WHERE season_id = {}", config_.activeSeason);
            QueryResult creatureResult = WorldDatabase.Query(creatureSql.c_str());
            if (creatureResult)
            {
                uint32 creatureCount = 0;
                do
                {
                    Field* fields = creatureResult->Fetch();
                    uint32 creatureEntry = fields[0].Get<uint32>();
                    uint32 tokens = fields[1].Get<uint32>();
                    uint32 essence = fields[2].Get<uint32>();
                    creatureRewards_[creatureEntry] = {tokens, essence};
                    creatureCount++;
                } while (creatureResult->NextRow());
                LOG_INFO("module", ">> [SeasonalRewards] Loaded {} creature rewards", creatureCount);
            }

            LOG_INFO("module", ">> [SeasonalRewards] System initialized successfully!");
        }

        void SeasonalRewardManager::ReloadConfiguration()
        {
            LoadConfiguration();
            questRewards_.clear();
            creatureRewards_.clear();
            Initialize();
            LOG_INFO("module", ">> [SeasonalRewards] Configuration reloaded!");
        }

        // =====================================================================
        // Reward Distribution
        // =====================================================================

        bool SeasonalRewardManager::AwardTokens(Player* player, uint32 amount, const std::string& source, uint32 sourceId)
        {
            return AwardCurrency(player, config_.tokenItemId, amount, source, sourceId);
        }

        bool SeasonalRewardManager::AwardEssence(Player* player, uint32 amount, const std::string& source, uint32 sourceId)
        {
            return AwardCurrency(player, config_.essenceItemId, amount, source, sourceId);
        }

        bool SeasonalRewardManager::AwardBoth(Player* player, uint32 tokens, uint32 essence, const std::string& source, uint32 sourceId)
        {
            bool success = true;
            if (tokens > 0)
                success &= AwardTokens(player, tokens, source, sourceId);
            if (essence > 0)
                success &= AwardEssence(player, essence, source, sourceId);
            return success;
        }

        bool SeasonalRewardManager::AwardCurrency(Player* player, uint32 itemId, uint32 amount, const std::string& source, uint32 sourceId)
        {
            if (!config_.enabled || !player || amount == 0)
                return false;

            // Determine if tokens or essence
            bool isToken = (itemId == config_.tokenItemId);
            bool isEssence = (itemId == config_.essenceItemId);

            if (!isToken && !isEssence)
                return false;

            // Check weekly cap
            uint32 tokens = isToken ? amount : 0;
            uint32 essence = isEssence ? amount : 0;

            if (!CheckWeeklyCap(player, tokens, essence))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000You've reached your weekly cap! No rewards awarded.|r");
                return false;
            }

            // Update amount if capped
            uint32 actualAmount = isToken ? tokens : essence;
            if (actualAmount < amount)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffffff00Weekly cap reached! Rewards reduced from {} to {}.|r", amount, actualAmount);
            }

            // Award item
            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, actualAmount);
            if (msg == EQUIP_ERR_OK)
            {
                Item* item = player->StoreNewItem(dest, itemId, true);
                player->SendNewItem(item, actualAmount, true, false);

                // Update stats
                PlayerSeasonStats* stats = GetOrCreatePlayerStats(player);
                if (isToken)
                {
                    stats->seasonalTokensEarned += actualAmount;
                    stats->weeklyTokensEarned += actualAmount;
                }
                else
                {
                    stats->seasonalEssenceEarned += actualAmount;
                    stats->weeklyEssenceEarned += actualAmount;
                }
                stats->lastUpdated = time(nullptr);
                SavePlayerStats(*stats);

                // Log transaction
                if (config_.logTransactions)
                {
                    RewardTransaction trans;
                    trans.playerGuid = player->GetGUID().GetCounter();
                    trans.seasonId = config_.activeSeason;
                    trans.source = source;
                    trans.sourceId = sourceId;
                    trans.tokensAwarded = isToken ? actualAmount : 0;
                    trans.essenceAwarded = isEssence ? actualAmount : 0;
                    trans.timestamp = time(nullptr);
                    LogTransaction(trans);
                }

                // Check achievements
                if (config_.achievementTracking)
                {
                    CheckAchievements(player);
                }

                // Notify player (via AIO if available)
                NotifyPlayer(player, isToken ? actualAmount : 0, isEssence ? actualAmount : 0, source);

                return true;
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Inventory full! Cannot award seasonal rewards.|r");
                return false;
            }
        }

        // =====================================================================
        // Quest Rewards
        // =====================================================================

        bool SeasonalRewardManager::ProcessQuestReward(Player* player, uint32 questId)
        {
            if (!config_.enabled || !player)
                return false;

            auto it = questRewards_.find(questId);
            if (it == questRewards_.end())
                return false;

            uint32 tokens = static_cast<uint32>(it->second.first * config_.questMultiplier);
            uint32 essence = static_cast<uint32>(it->second.second * config_.questMultiplier);

            if (tokens == 0 && essence == 0)
                return false;

            bool success = AwardBoth(player, tokens, essence, "Quest", questId);

            if (success)
            {
                PlayerSeasonStats* stats = GetPlayerStats(player->GetGUID().GetCounter());
                if (stats)
                {
                    stats->questsCompleted++;
                    SavePlayerStats(*stats);
                }
            }

            return success;
        }

        // =====================================================================
        // Creature Kill Rewards
        // =====================================================================

        bool SeasonalRewardManager::ProcessCreatureKill(Player* player, uint32 creatureEntry, bool isDungeonBoss, bool isWorldBoss)
        {
            if (!config_.enabled || !player)
                return false;

            auto it = creatureRewards_.find(creatureEntry);
            if (it == creatureRewards_.end())
                return false;

            float multiplier = config_.creatureMultiplier;
            if (isWorldBoss)
                multiplier *= config_.worldBossMultiplier;
            else if (isDungeonBoss)
                multiplier *= 1.0f; // Dungeon bosses use base multiplier

            uint32 tokens = static_cast<uint32>(it->second.first * multiplier);
            uint32 essence = static_cast<uint32>(it->second.second * multiplier);

            if (tokens == 0 && essence == 0)
                return false;

            bool success = AwardBoth(player, tokens, essence,
                isWorldBoss ? "WorldBoss" : (isDungeonBoss ? "DungeonBoss" : "Creature"),
                creatureEntry);

            if (success)
            {
                PlayerSeasonStats* stats = GetPlayerStats(player->GetGUID().GetCounter());
                if (stats)
                {
                    stats->creaturesKilled++;
                    if (isDungeonBoss)
                        stats->dungeonBossesKilled++;
                    if (isWorldBoss)
                        stats->worldBossesKilled++;
                    SavePlayerStats(*stats);
                }
            }

            return success;
        }

        // =====================================================================
        // Weekly Cap Management
        // =====================================================================

        bool SeasonalRewardManager::CheckWeeklyCap(Player* player, uint32& tokens, uint32& essence)
        {
            if (!player)
                return false;

            // Check if new week
            if (IsNewWeek(player))
            {
                ResetWeeklyStats(player);
            }

            PlayerSeasonStats* stats = GetPlayerStats(player->GetGUID().GetCounter());
            if (!stats)
                return true; // No stats yet, allow reward

            // Check token cap
            if (config_.weeklyTokenCap > 0 && stats->weeklyTokensEarned + tokens > config_.weeklyTokenCap)
            {
                uint32 remaining = config_.weeklyTokenCap > stats->weeklyTokensEarned ?
                    config_.weeklyTokenCap - stats->weeklyTokensEarned : 0;
                tokens = remaining;
            }

            // Check essence cap
            if (config_.weeklyEssenceCap > 0 && stats->weeklyEssenceEarned + essence > config_.weeklyEssenceCap)
            {
                uint32 remaining = config_.weeklyEssenceCap > stats->weeklyEssenceEarned ?
                    config_.weeklyEssenceCap - stats->weeklyEssenceEarned : 0;
                essence = remaining;
            }

            return (tokens > 0 || essence > 0);
        }

        time_t SeasonalRewardManager::GetCurrentWeekTimestamp() const
        {
            time_t now = time(nullptr);
            tm* timeInfo = localtime(&now);

            // Calculate days since last reset day
            int daysSinceReset = timeInfo->tm_wday - config_.resetDay;
            if (daysSinceReset < 0)
                daysSinceReset += 7;

            // Calculate seconds to subtract
            time_t secondsSinceReset = daysSinceReset * 86400 +
                timeInfo->tm_hour * 3600 +
                timeInfo->tm_min * 60 +
                timeInfo->tm_sec;

            time_t resetHourOffset = config_.resetHour * 3600;

            time_t weekTimestamp = now - secondsSinceReset + resetHourOffset;

            // If we haven't reached reset hour yet today and today is reset day, go back one week
            if (timeInfo->tm_wday == config_.resetDay && timeInfo->tm_hour < config_.resetHour)
                weekTimestamp -= 604800; // 7 days

            return weekTimestamp;
        }

        bool SeasonalRewardManager::IsNewWeek(Player* player)
        {
            if (!player)
                return false;

            PlayerSeasonStats* stats = GetPlayerStats(player->GetGUID().GetCounter());
            if (!stats)
                return true; // No stats = treat as new week

            time_t currentWeek = GetCurrentWeekTimestamp();
            return currentWeek > stats->lastWeeklyReset;
        }

        void SeasonalRewardManager::ResetWeeklyStats(Player* player)
        {
            if (!player)
                return;

            PlayerSeasonStats* stats = GetOrCreatePlayerStats(player);

            // Archive previous week
            std::string sql = Acore::StringFormat("INSERT INTO dc_player_weekly_cap_snapshot "
                "(player_guid, season_id, week_timestamp, tokens_earned, essence_earned, dungeons_completed) "
                "VALUES ({}, {}, {}, {}, {}, {})",
                stats->playerGuid, stats->seasonId, stats->lastWeeklyReset,
                stats->weeklyTokensEarned, stats->weeklyEssenceEarned, stats->dungeonBossesKilled);
            CharacterDatabase.Execute(sql.c_str());

            // Generate weekly chest before reset
            GenerateWeeklyChest(player);

            // Reset weekly counters
            stats->weeklyTokensEarned = 0;
            stats->weeklyEssenceEarned = 0;
            stats->lastWeeklyReset = GetCurrentWeekTimestamp();
            stats->lastUpdated = time(nullptr);

            SavePlayerStats(*stats);

            LOG_DEBUG("module", "[SeasonalRewards] Reset weekly stats for player {}", player->GetName());
        }

        // =====================================================================
        // Weekly Chest System
        // =====================================================================

        void SeasonalRewardManager::GenerateWeeklyChest(Player* player)
        {
            if (!player)
                return;

            PlayerSeasonStats* stats = GetPlayerStats(player->GetGUID().GetCounter());
            if (!stats)
                return;

            // Calculate chest rewards (10% of previous week earnings)
            uint32 bonusTokens = static_cast<uint32>(stats->weeklyTokensEarned * 0.1f);
            uint32 bonusEssence = static_cast<uint32>(stats->weeklyEssenceEarned * 0.1f);

            if (bonusTokens == 0 && bonusEssence == 0)
                return; // No activity last week

            // Determine slots unlocked based on dungeon completions
            uint8 slotsUnlocked = 0;
            if (stats->dungeonBossesKilled >= 1) slotsUnlocked = 1;
            if (stats->dungeonBossesKilled >= 4) slotsUnlocked = 2;
            if (stats->dungeonBossesKilled >= 10) slotsUnlocked = 3;

            WeeklyChest chest;
            chest.playerGuid = player->GetGUID().GetCounter();
            chest.seasonId = config_.activeSeason;
            chest.weekTimestamp = stats->lastWeeklyReset;
            chest.slotsUnlocked = slotsUnlocked;

            // Distribute rewards across slots
            if (slotsUnlocked >= 1)
            {
                chest.slot1Tokens = bonusTokens / 3;
                chest.slot1Essence = bonusEssence / 3;
            }
            if (slotsUnlocked >= 2)
            {
                chest.slot2Tokens = bonusTokens / 3;
                chest.slot2Essence = bonusEssence / 3;
            }
            if (slotsUnlocked >= 3)
            {
                chest.slot3Tokens = bonusTokens - (chest.slot1Tokens + chest.slot2Tokens);
                chest.slot3Essence = bonusEssence - (chest.slot1Essence + chest.slot2Essence);
            }

            // Save to database
            std::string sql = Acore::StringFormat("INSERT INTO dc_player_seasonal_chests "
                "(player_guid, season_id, week_timestamp, slot1_tokens, slot1_essence, slot2_tokens, slot2_essence, "
                "slot3_tokens, slot3_essence, slots_unlocked, collected) "
                "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, 0)",
                chest.playerGuid, chest.seasonId, chest.weekTimestamp,
                chest.slot1Tokens, chest.slot1Essence, chest.slot2Tokens, chest.slot2Essence,
                chest.slot3Tokens, chest.slot3Essence, chest.slotsUnlocked);
            CharacterDatabase.Execute(sql.c_str());

            weeklyChests_[chest.playerGuid] = chest;

            LOG_DEBUG("module", "[SeasonalRewards] Generated weekly chest for player {} with {} slots",
                player->GetName(), slotsUnlocked);
        }

        bool SeasonalRewardManager::CollectWeeklyChest(Player* player)
        {
            if (!player)
                return false;

            WeeklyChest* chest = GetWeeklyChest(player);
            if (!chest || chest->collected)
                return false;

            // Award chest contents
            uint32 totalTokens = chest->slot1Tokens + chest->slot2Tokens + chest->slot3Tokens;
            uint32 totalEssence = chest->slot1Essence + chest->slot2Essence + chest->slot3Essence;

            if (!AwardBoth(player, totalTokens, totalEssence, "WeeklyChest", 0))
                return false;

            // Mark as collected
            chest->collected = true;
            std::string sql = Acore::StringFormat("UPDATE dc_player_seasonal_chests SET collected = 1 "
                "WHERE player_guid = {} AND season_id = {} AND week_timestamp = {}",
                chest->playerGuid, chest->seasonId, chest->weekTimestamp);
            CharacterDatabase.Execute(sql.c_str());

            ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Weekly chest collected! Received {} tokens and {} essence.|r",
                totalTokens, totalEssence);

            return true;
        }

        WeeklyChest* SeasonalRewardManager::GetWeeklyChest(Player* player)
        {
            if (!player)
                return nullptr;

            uint32 playerGuid = player->GetGUID().GetCounter();
            auto it = weeklyChests_.find(playerGuid);
            if (it != weeklyChests_.end())
                return &it->second;

            // Load from database
            std::string sql = Acore::StringFormat("SELECT week_timestamp, slot1_tokens, slot1_essence, "
                "slot2_tokens, slot2_essence, slot3_tokens, slot3_essence, slots_unlocked, collected "
                "FROM dc_player_seasonal_chests WHERE player_guid = {} AND season_id = {} AND collected = 0 "
                "ORDER BY week_timestamp DESC LIMIT 1",
                playerGuid, config_.activeSeason);

            QueryResult result = CharacterDatabase.Query(sql.c_str());

            if (!result)
                return nullptr;

            Field* fields = result->Fetch();
            WeeklyChest chest;
            chest.playerGuid = playerGuid;
            chest.seasonId = config_.activeSeason;
            chest.weekTimestamp = fields[0].Get<uint32>();
            chest.slot1Tokens = fields[1].Get<uint32>();
            chest.slot1Essence = fields[2].Get<uint32>();
            chest.slot2Tokens = fields[3].Get<uint32>();
            chest.slot2Essence = fields[4].Get<uint32>();
            chest.slot3Tokens = fields[5].Get<uint32>();
            chest.slot3Essence = fields[6].Get<uint32>();
            chest.slotsUnlocked = fields[7].Get<uint8>();
            chest.collected = fields[8].Get<bool>();

            weeklyChests_[playerGuid] = chest;
            return &weeklyChests_[playerGuid];
        }

        // =====================================================================
        // Player Stats Management
        // =====================================================================

        PlayerSeasonStats* SeasonalRewardManager::GetPlayerStats(uint32 playerGuid)
        {
            auto it = playerStats_.find(playerGuid);
            return (it != playerStats_.end()) ? &it->second : nullptr;
        }

        PlayerSeasonStats* SeasonalRewardManager::GetOrCreatePlayerStats(Player* player)
        {
            if (!player)
                return nullptr;

            uint32 playerGuid = player->GetGUID().GetCounter();
            PlayerSeasonStats* stats = GetPlayerStats(playerGuid);

            if (!stats)
            {
                // Create new stats
                PlayerSeasonStats newStats;
                newStats.playerGuid = playerGuid;
                newStats.seasonId = config_.activeSeason;
                newStats.lastWeeklyReset = GetCurrentWeekTimestamp();
                newStats.lastUpdated = time(nullptr);

                playerStats_[playerGuid] = newStats;
                SavePlayerStats(newStats);

                return &playerStats_[playerGuid];
            }

            return stats;
        }

        void SeasonalRewardManager::UpdatePlayerStats(Player* player, const PlayerSeasonStats& stats)
        {
            if (!player)
                return;

            playerStats_[player->GetGUID().GetCounter()] = stats;
            SavePlayerStats(stats);
        }

        void SeasonalRewardManager::SavePlayerStats(const PlayerSeasonStats& stats)
        {
            std::string sql = Acore::StringFormat("REPLACE INTO dc_player_seasonal_stats "
                "(player_guid, season_id, total_tokens_earned, total_essence_earned, "
                "weekly_tokens_earned, weekly_essence_earned, quests_completed, creatures_killed, "
                "dungeon_bosses_killed, world_bosses_killed, prestige_level, last_weekly_reset, last_updated) "
                "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {})",
                stats.playerGuid, stats.seasonId, stats.seasonalTokensEarned, stats.seasonalEssenceEarned,
                stats.weeklyTokensEarned, stats.weeklyEssenceEarned, stats.questsCompleted, stats.creaturesKilled,
                stats.dungeonBossesKilled, stats.worldBossesKilled, stats.prestigeLevel,
                stats.lastWeeklyReset, stats.lastUpdated);
            CharacterDatabase.Execute(sql.c_str());
        }

        // =====================================================================
        // Achievement Tracking
        // =====================================================================

        void SeasonalRewardManager::CheckAchievements(Player* player)
        {
            if (!player || !config_.achievementTracking)
                return;

            PlayerSeasonStats* stats = GetPlayerStats(player->GetGUID().GetCounter());
            if (!stats)
                return;

            // Token milestones (Achievement IDs 11000-11009)
            const std::vector<std::pair<uint32, uint32>> tokenMilestones = {
                {11000, 1000}, {11001, 5000}, {11002, 10000}, {11003, 25000}, {11004, 50000},
                {11005, 100000}, {11006, 250000}, {11007, 500000}, {11008, 1000000}, {11009, 2500000}
            };

            for (auto const& [achievementId, threshold] : tokenMilestones)
            {
                if (stats->seasonalTokensEarned >= threshold && !player->HasAchieved(achievementId))
                    GrantAchievement(player, achievementId);
            }

            // Essence milestones (Achievement IDs 11010-11019)
            const std::vector<std::pair<uint32, uint32>> essenceMilestones = {
                {11010, 500}, {11011, 2500}, {11012, 5000}, {11013, 12500}, {11014, 25000},
                {11015, 50000}, {11016, 125000}, {11017, 250000}, {11018, 500000}, {11019, 1250000}
            };

            for (auto const& [achievementId, threshold] : essenceMilestones)
            {
                if (stats->seasonalEssenceEarned >= threshold && !player->HasAchieved(achievementId))
                    GrantAchievement(player, achievementId);
            }
        }

        void SeasonalRewardManager::GrantAchievement(Player* player, uint32 achievementId)
        {
            if (!player)
                return;

            player->CompletedAchievement(sAchievementMgr->GetAchievement(achievementId));
            LOG_DEBUG("module", "[SeasonalRewards] Granted achievement {} to player {}", achievementId, player->GetName());
        }

        // =====================================================================
        // Admin Commands
        // =====================================================================

        void SeasonalRewardManager::ResetPlayerSeason(Player* player)
        {
            if (!player)
                return;

            uint32 playerGuid = player->GetGUID().GetCounter();

            // Archive to history
            std::string archiveSql = Acore::StringFormat("INSERT INTO dc_player_seasonal_stats_history "
                "SELECT * FROM dc_player_seasonal_stats WHERE player_guid = {} AND season_id = {}",
                playerGuid, config_.activeSeason);
            CharacterDatabase.Execute(archiveSql.c_str());

            // Delete current stats
            std::string deleteSql = Acore::StringFormat("DELETE FROM dc_player_seasonal_stats WHERE player_guid = {} AND season_id = {}",
                playerGuid, config_.activeSeason);
            CharacterDatabase.Execute(deleteSql.c_str());

            // Remove from cache
            playerStats_.erase(playerGuid);
            weeklyChests_.erase(playerGuid);

            LOG_INFO("module", "[SeasonalRewards] Reset season data for player {}", player->GetName());
        }

        void SeasonalRewardManager::SetActiveSeason(uint32 seasonId)
        {
            config_.activeSeason = seasonId;
            playerStats_.clear();
            weeklyChests_.clear();
            LoadPlayerStats();
            Initialize();
            LOG_INFO("module", "[SeasonalRewards] Active season changed to {}", seasonId);
        }

        void SeasonalRewardManager::SetMultiplier(const std::string& type, float value)
        {
            if (type == "quest")
                config_.questMultiplier = value;
            else if (type == "creature")
                config_.creatureMultiplier = value;
            else if (type == "worldboss")
                config_.worldBossMultiplier = value;
            else if (type == "event")
                config_.eventBossMultiplier = value;

            LOG_INFO("module", "[SeasonalRewards] Set {} multiplier to {}", type, value);
        }

        // =====================================================================
        // Periodic Tasks
        // =====================================================================

        void SeasonalRewardManager::CheckWeeklyReset()
        {
            time_t now = time(nullptr);
            tm* timeInfo = localtime(&now);

            // Check if we're at reset time (Tuesday 3 PM by default)
            if (timeInfo->tm_wday == config_.resetDay &&
                timeInfo->tm_hour == config_.resetHour &&
                now - lastWeeklyCheck_ > 3600) // Don't check more than once per hour
            {
                LOG_INFO("module", "[SeasonalRewards] Weekly reset triggered!");

                // Process all loaded players
                // Note: This only affects online players. Offline players will be reset on login.
                lastWeeklyCheck_ = now;
            }
        }

        void SeasonalRewardManager::Update(uint32 diff)
        {
            if (!config_.enabled)
                return;

            updateTimer_ += diff;

            // Check weekly reset every minute
            if (updateTimer_ >= 60000)
            {
                CheckWeeklyReset();
                updateTimer_ = 0;
            }
        }

        // =====================================================================
        // Transaction Logging
        // =====================================================================

        void SeasonalRewardManager::LogTransaction(const RewardTransaction& transaction)
        {
            std::string sql = Acore::StringFormat("INSERT INTO dc_reward_transactions "
                "(player_guid, season_id, source, source_id, tokens_awarded, essence_awarded, timestamp) "
                "VALUES ({}, {}, '{}', {}, {}, {}, {})",
                transaction.playerGuid, transaction.seasonId, transaction.source,
                transaction.sourceId, transaction.tokensAwarded, transaction.essenceAwarded,
                transaction.timestamp);
            CharacterDatabase.Execute(sql.c_str());
        }

        std::vector<RewardTransaction> SeasonalRewardManager::GetPlayerTransactions(uint32 playerGuid, uint32 limit)
        {
            std::vector<RewardTransaction> transactions;

            std::string sql = Acore::StringFormat("SELECT season_id, source, source_id, tokens_awarded, "
                "essence_awarded, timestamp FROM dc_reward_transactions WHERE player_guid = {} "
                "ORDER BY timestamp DESC LIMIT {}",
                playerGuid, limit);

            QueryResult result = CharacterDatabase.Query(sql.c_str());

            if (!result)
                return transactions;

            do
            {
                Field* fields = result->Fetch();
                RewardTransaction trans;
                trans.playerGuid = playerGuid;
                trans.seasonId = fields[0].Get<uint32>();
                trans.source = fields[1].Get<std::string>();
                trans.sourceId = fields[2].Get<uint32>();
                trans.tokensAwarded = fields[3].Get<uint32>();
                trans.essenceAwarded = fields[4].Get<uint32>();
                trans.timestamp = fields[5].Get<uint32>();

                transactions.push_back(trans);
            } while (result->NextRow());

            return transactions;
        }

        // =====================================================================
        // SeasonalParticipant Interface Implementation
        // =====================================================================

        void SeasonalRewardManager::OnSeasonStart(uint32 season_id)
        {
            LOG_INFO("module", ">> [SeasonalRewards] Season {} started - initializing reward system", season_id);

            // Update active season
            config_.activeSeason = season_id;

            // Reload reward definitions for new season
            questRewards_.clear();
            creatureRewards_.clear();
            Initialize();

            LOG_INFO("module", ">> [SeasonalRewards] Season {} initialization complete", season_id);
        }

        void SeasonalRewardManager::OnSeasonEnd(uint32 season_id)
        {
            LOG_INFO("module", ">> [SeasonalRewards] Season {} ending - finalizing rewards", season_id);

            // Generate final weekly chests for all active players
            for (auto& [playerGuid, stats] : playerStats_)
            {
                if (stats.seasonId == season_id)
                {
                    // Final chest generation would happen here
                    LOG_DEBUG("module", ">> [SeasonalRewards] Finalizing season {} for player {}", season_id, playerGuid);
                }
            }

            LOG_INFO("module", ">> [SeasonalRewards] Season {} finalization complete", season_id);
        }

        void SeasonalRewardManager::OnPlayerSeasonChange(uint32 player_guid, uint32 old_season, uint32 new_season)
        {
            LOG_INFO("module", ">> [SeasonalRewards] Player {} transitioning from season {} to {}",
                player_guid, old_season, new_season);

            // Archive old season stats
            auto statsIt = playerStats_.find(player_guid);
            if (statsIt != playerStats_.end() && statsIt->second.seasonId == old_season)
            {
                // Stats are automatically saved to database with season_id
                SavePlayerStats(statsIt->second);
            }

            // Initialize new season stats
            PlayerSeasonStats newStats;
            newStats.playerGuid = player_guid;
            newStats.seasonId = new_season;
            newStats.lastWeeklyReset = time(nullptr);
            newStats.lastUpdated = time(nullptr);

            playerStats_[player_guid] = newStats;
            SavePlayerStats(newStats);

            LOG_INFO("module", ">> [SeasonalRewards] Player {} season transition complete", player_guid);
        }

        bool SeasonalRewardManager::ValidateSeasonTransition(uint32 /*player_guid*/, uint32 /*season_id*/)
        {
            // No special validation needed for reward system
            // Players can transition freely
            return true;
        }

        bool SeasonalRewardManager::InitializeForSeason(uint32 season_id)
        {
            LOG_INFO("module", ">> [SeasonalRewards] Initializing system for season {}", season_id);

            config_.activeSeason = season_id;

            // Load reward definitions for this season
            questRewards_.clear();
            creatureRewards_.clear();

            std::string questSql = Acore::StringFormat(
                "SELECT quest_id, token_reward, essence_reward FROM dc_seasonal_quest_rewards WHERE season_id = {}",
                season_id);
            QueryResult questResult = WorldDatabase.Query(questSql.c_str());
            if (questResult)
            {
                uint32 count = 0;
                do
                {
                    Field* fields = questResult->Fetch();
                    questRewards_[fields[0].Get<uint32>()] = {fields[1].Get<uint32>(), fields[2].Get<uint32>()};
                    count++;
                } while (questResult->NextRow());
                LOG_INFO("module", ">> [SeasonalRewards] Loaded {} quest rewards for season {}", count, season_id);
            }

            std::string creatureSql = Acore::StringFormat(
                "SELECT creature_entry, token_reward, essence_reward FROM dc_seasonal_creature_rewards WHERE season_id = {}",
                season_id);
            QueryResult creatureResult = WorldDatabase.Query(creatureSql.c_str());
            if (creatureResult)
            {
                uint32 count = 0;
                do
                {
                    Field* fields = creatureResult->Fetch();
                    creatureRewards_[fields[0].Get<uint32>()] = {fields[1].Get<uint32>(), fields[2].Get<uint32>()};
                    count++;
                } while (creatureResult->NextRow());
                LOG_INFO("module", ">> [SeasonalRewards] Loaded {} creature rewards for season {}", count, season_id);
            }

            return true;
        }

        bool SeasonalRewardManager::CleanupFromSeason(uint32 season_id)
        {
            LOG_INFO("module", ">> [SeasonalRewards] Cleaning up season {}", season_id);

            // Save all player stats for this season
            for (auto& [playerGuid, stats] : playerStats_)
            {
                if (stats.seasonId == season_id)
                {
                    SavePlayerStats(stats);
                }
            }

            // Clear cached reward definitions
            questRewards_.clear();
            creatureRewards_.clear();

            LOG_INFO("module", ">> [SeasonalRewards] Season {} cleanup complete", season_id);
            return true;
        }

        // =====================================================================
        // Internal Helpers
        // =====================================================================

        void SeasonalRewardManager::NotifyPlayer(Player* player, uint32 tokens, uint32 essence, const std::string& source)
        {
            // This will be handled by Eluna AIO bridge
            // For now, just send chat message
            if (tokens > 0 && essence > 0)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Seasonal Reward]|r Earned |cffffd700%u tokens|r and |cff00ffff%u essence|r from %s!",
                    tokens, essence, source.c_str());
            }
            else if (tokens > 0)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Seasonal Reward]|r Earned |cffffd700%u tokens|r from %s!",
                    tokens, source.c_str());
            }
            else if (essence > 0)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Seasonal Reward]|r Earned |cff00ffff%u essence|r from %s!",
                    essence, source.c_str());
            }
        }

    } // namespace SeasonalRewards
} // namespace DarkChaos
