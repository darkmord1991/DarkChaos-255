/*
 * DarkChaos Item Upgrade - Token System Hooks
 *
 * This file implements server event hooks to award upgrade tokens and artifact essence
 * to players through various gameplay activities:
 * - Quest completion
 * - Creature kills (dungeon/raid/world bosses)
 * - PvP kills
 * - Achievements
 * - Battleground wins
 *
 * Author: DarkChaos Development Team
 * Date: November 4, 2025
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "Quests/QuestDef.h"
#include "Log.h"
#include "Chat.h"
#include "Config.h"
#include "GameTime.h"
#include "Map.h"
#include "DC/CrossSystem/SeasonResolver.h"
#include "../CrossSystem/CrossSystemUtilities.h"
#include "Common.h"
#include <mutex>
#include <sstream>
#include <unordered_map>
#include <unordered_set>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Constants for Token Rewards
        // =====================================================================

    [[maybe_unused]] static const uint32 DAILY_QUEST_CAP = 100;

        // Quest reward tier: base tokens awarded for quest completion
        static const uint32 QUEST_REWARD_BASE = 10;
        static const float QUEST_SCALING_FACTOR = 0.5f;  // +50% per difficulty tier

        // Creature kill rewards: base tokens for creature kills
        static const uint32 DUNGEON_TRASH_REWARD = 5;
        static const uint32 DUNGEON_BOSS_REWARD = 25;
        static const uint32 DUNGEON_BOSS_ESSENCE = 5;
        static const uint32 RAID_TRASH_REWARD = 10;
        static const uint32 RAID_BOSS_REWARD = 50;
        static const uint32 RAID_BOSS_ESSENCE = 10;
    [[maybe_unused]] static const uint32 WORLD_BOSS_REWARD = 100;
    [[maybe_unused]] static const uint32 WORLD_BOSS_ESSENCE = 20;

        // PvP rewards
        static const uint32 PVP_KILL_REWARD = 15;
    [[maybe_unused]] static const float PVP_LEVEL_SCALING = 1.0f;

        // Battleground rewards
    [[maybe_unused]] static const uint32 BATTLEGROUND_WIN_REWARD = 25;
    [[maybe_unused]] static const uint32 BATTLEGROUND_LOSS_REWARD = 5;

        // Achievement essence rewards
        static const uint32 ACHIEVEMENT_ESSENCE_REWARD = 50;

        // =====================================================================
        // Helper Functions
        // =====================================================================

        static uint32 GetLogSamplePct(char const* option, uint32 defaultValue)
        {
            int32 value = sConfigMgr->GetOption<int32>(option, static_cast<int32>(defaultValue));
            if (value < 0)
                value = 0;
            if (value > 100)
                value = 100;
            return static_cast<uint32>(value);
        }

        static uint32 GetLogMinIntervalMs(char const* option, uint32 defaultValue)
        {
            int32 value = sConfigMgr->GetOption<int32>(option, static_cast<int32>(defaultValue));
            return value > 0 ? static_cast<uint32>(value) : 0u;
        }

        static bool ShouldEmitTokenLog(char const* samplePctOption, char const* minIntervalOption,
                                       uint32 defaultSamplePct, uint32 defaultMinIntervalMs)
        {
            uint32 samplePct = GetLogSamplePct(samplePctOption, defaultSamplePct);
            if (samplePct == 0)
                return false;

            uint32 minIntervalMs = GetLogMinIntervalMs(minIntervalOption, defaultMinIntervalMs);
            if (minIntervalMs > 0)
            {
                static std::mutex s_logThrottleMutex;
                static std::unordered_map<char const*, uint64> s_nextAllowedLogMs;

                uint64 nowMs = GameTime::GetGameTimeMS().count();

                std::lock_guard<std::mutex> guard(s_logThrottleMutex);
                uint64& nextAllowed = s_nextAllowedLogMs[minIntervalOption];
                if (nowMs < nextAllowed)
                    return false;

                nextAllowed = nowMs + minIntervalMs;
            }

            if (samplePct >= 100)
                return true;

            return urand(1, 100) <= samplePct;
        }

        static bool TryClaimArtifactAchievement(uint32 playerGuid, uint32 achievementId)
        {
            static std::mutex s_claimMutex;
            static std::unordered_map<uint64, uint64> s_claimedUntilMs;

            uint64 claimKey = (uint64(playerGuid) << 32) | uint64(achievementId);
            uint32 cacheTtlMs = GetLogMinIntervalMs("ItemUpgrade.Perf.AchievementClaimCacheMs", 5000);
            uint64 nowMs = GameTime::GetGameTimeMS().count();

            std::lock_guard<std::mutex> guard(s_claimMutex);

            if (cacheTtlMs > 0)
            {
                auto cached = s_claimedUntilMs.find(claimKey);
                if (cached != s_claimedUntilMs.end())
                {
                    if (nowMs < cached->second)
                        return false;

                    s_claimedUntilMs.erase(cached);
                }

                if (s_claimedUntilMs.size() > 4096)
                {
                    for (auto it = s_claimedUntilMs.begin(); it != s_claimedUntilMs.end();)
                    {
                        it = (nowMs >= it->second) ? s_claimedUntilMs.erase(it) : std::next(it);
                    }
                }
            }

            QueryResult existing = CharacterDatabase.Query(
                "SELECT 1 FROM dc_player_artifact_discoveries "
                "WHERE player_guid = {} AND artifact_id = {} LIMIT 1",
                playerGuid, achievementId);

            if (existing)
            {
                if (cacheTtlMs > 0)
                    s_claimedUntilMs[claimKey] = nowMs + cacheTtlMs;
                return false;
            }

            try
            {
                CharacterDatabase.Execute(
                    "INSERT IGNORE INTO dc_player_artifact_discoveries (player_guid, artifact_id, discovery_type, discovered_at) "
                    "VALUES ({}, {}, 'event', NOW())",
                    playerGuid, achievementId);
            }
            catch (...)
            {
                return false;
            }

            if (cacheTtlMs > 0)
                s_claimedUntilMs[claimKey] = nowMs + cacheTtlMs;
            return true;
        }

        // Get quest difficulty tier (0 = trivial, 1 = easy, 2 = normal, 3 = hard, 4 = legendary)
        static uint8 GetQuestDifficultyTier(uint32 quest_level, uint8 player_level)
        {
            if (player_level >= quest_level + 5)
                return 0;  // Trivial
            else if (player_level >= quest_level + 3)
                return 1;  // Easy
            else if (player_level >= quest_level)
                return 2;  // Normal
            else if (player_level >= quest_level - 5)
                return 3;  // Hard
            else
                return 4;  // Legendary
        }

        // Calculate quest token reward based on quest level and player level
        static uint32 CalculateQuestReward(uint32 quest_level, uint8 player_level)
        {
            uint8 difficulty = GetQuestDifficultyTier(quest_level, player_level);
            if (difficulty == 0)
                return 0;  // Trivial quests don't reward tokens

            return (uint32)(QUEST_REWARD_BASE * (1.0f + (difficulty - 1) * QUEST_SCALING_FACTOR));
        }

        // Determine if creature is a boss (based on rank)
        static bool IsCreatureBoss(Creature const* creature)
        {
            if (!creature)
                return false;

            CreatureTemplate const* cTemplate = creature->GetCreatureTemplate();
            if (!cTemplate)
                return false;

            // Rank 1 = Normal, 2 = Elite, 3 = Rare Elite, 4 = Boss/Raid Boss
            return cTemplate->rank >= CREATURE_ELITE_RARE;
        }

        // Determine dungeon/raid type from creature info
        static bool IsRaidCreature(Creature const* creature)
        {
            if (!creature)
                return false;

            Map const* map = creature->GetMap();
            return map && map->IsRaid();
        }

        // Log token transaction to database
        static void LogTokenTransaction(uint32 player_guid, const char* transaction_type,
                                       const char* reason, int32 token_change, int32 essence_change)
        {
            if (token_change == 0 && essence_change == 0)
                return;

            // Determine currency type based on what changed
            const char* currency_type = (essence_change != 0) ? "artifact_essence" : "upgrade_token";
            uint32 amount = (essence_change != 0) ? std::abs(essence_change) : std::abs(token_change);

            // Copy and sanitize free-form strings before embedding into SQL
            std::string safeTransaction = transaction_type ? transaction_type : "";
            std::string safeReason = reason ? reason : "";
            CleanStringForMysqlQuery(safeTransaction);
            CleanStringForMysqlQuery(safeReason);

            CharacterDatabase.Execute(
                "INSERT INTO dc_token_transaction_log (player_guid, currency_type, amount, transaction_type, reason) "
                "VALUES ({}, '{}', {}, '{}', '{}')",
                player_guid, currency_type, amount, safeTransaction, safeReason);
        }

        // NOTE: Weekly cap tracking removed - dc_player_upgrade_tokens table deprecated
        // Item-based currency (items 300311/300312) doesn't support weekly tracking
        // Weekly caps can be re-implemented via addon tracking if needed
        [[maybe_unused]] static bool IsAtWeeklyTokenCap([[maybe_unused]] uint32 player_guid, [[maybe_unused]] uint32 season = 1)
        {
            // Weekly cap disabled - return false to allow unlimited earning
            // TODO: Re-implement via separate tracking table if weekly caps needed
            return false;
        }

        // =====================================================================
        // Player Script Hooks
        // =====================================================================

        class PlayerTokenHooks : public PlayerScript
        {
        public:
            PlayerTokenHooks() : PlayerScript("PlayerTokenHooks") {}

            void OnPlayerPVPKill(Player* killer, Player* victim) override
            {
                if (!killer || !victim)
                    return;

                if (killer == victim || killer->GetGUID() == victim->GetGUID())
                    return;

                uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();

                // Calculate reward based on victim level (clamp to avoid unsigned underflow)
                int32 levelDelta = std::max<int32>(0, int32(victim->GetLevel()) - 60);
                uint32 reward = static_cast<uint32>(PVP_KILL_REWARD * (1.0f + levelDelta * 0.05f));

                if (reward == 0)
                    return;

                // Check weekly cap
                if (IsAtWeeklyTokenCap(killer->GetGUID().GetCounter(), season))
                {
                    ChatHandler(killer->GetSession()).PSendSysMessage("|cffff0000 Weekly token cap reached! No tokens awarded.|r");
                    return;
                }

                // Award tokens using centralized utility
                uint32 killerGuid = killer->GetGUID().GetCounter();
                DarkChaos::CrossSystem::CurrencyUtils::AddCurrencyAndSync(
                    killerGuid, CURRENCY_UPGRADE_TOKEN, reward, season, killer, true);

                // Log transaction
                std::ostringstream reason;
                reason << "PvP Kill: " << victim->GetName();
                LogTokenTransaction(killer->GetGUID().GetCounter(), "reward", reason.str().c_str(), reward, 0);

                // Send notification
                std::string pvpMsg = "|cff00ff00+" + std::to_string(reward) + " Upgrade Tokens|r (PvP Kill)";
                ChatHandler(killer->GetSession()).SendSysMessage(pvpMsg.c_str());

                if (ShouldEmitTokenLog("ItemUpgrade.Perf.PvpReward.SamplePct", "ItemUpgrade.Perf.PvpReward.MinIntervalMs",
                                       20, 1500))
                {
                    LOG_INFO("scripts.dc", "ItemUpgrade: Player {} earned {} tokens from PvP kill of {}",
                        killer->GetGUID().GetCounter(), reward, victim->GetGUID().GetCounter());
                }
            }

            void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
            {
                if (!player || !quest)
                    return;

                uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();

                // Calculate reward
                uint32 reward = CalculateQuestReward(quest->GetQuestLevel(), player->GetLevel());

                // If reward is 0, skip (trivial quest)
                if (reward == 0)
                    return;

                // Check weekly cap
                if (IsAtWeeklyTokenCap(player->GetGUID().GetCounter(), season))
                {
                    LOG_DEBUG("scripts.dc", "ItemUpgrade: Player {} at weekly token cap, no quest reward", player->GetGUID().GetCounter());
                    return;
                }

                // Award tokens using centralized utility
                uint32 playerGuid = player->GetGUID().GetCounter();
                DarkChaos::CrossSystem::CurrencyUtils::AddCurrencyAndSync(
                    playerGuid, CURRENCY_UPGRADE_TOKEN, reward, season, player, true);

                // Log transaction
                std::ostringstream reason;
                reason << "Quest: " << quest->GetTitle();
                LogTokenTransaction(player->GetGUID().GetCounter(), "reward", reason.str().c_str(), reward, 0);

                // Send notification
                std::string questMsg = "|cff00ff00+" + std::to_string(reward) + " Upgrade Tokens|r (Quest Complete: " +
                                      std::string(quest->GetTitle()) + ")";
                ChatHandler(player->GetSession()).SendSysMessage(questMsg.c_str());

                if (ShouldEmitTokenLog("ItemUpgrade.Perf.QuestReward.SamplePct",
                                       "ItemUpgrade.Perf.QuestReward.MinIntervalMs", 20, 1500))
                {
                    LOG_INFO("scripts.dc", "ItemUpgrade: Player {} earned {} tokens from quest {} ({})",
                        player->GetGUID().GetCounter(), reward, quest->GetQuestId(), quest->GetTitle());
                }
            }

            void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement) override
            {
                if (!player || !achievement)
                    return;

                uint32 playerGuid = player->GetGUID().GetCounter();
                if (!TryClaimArtifactAchievement(playerGuid, achievement->ID))
                    return;

                uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();

                // Award essence for achievement
                uint32 essence_reward = ACHIEVEMENT_ESSENCE_REWARD;

                // Prepare a locale-aware achievement name (achievement->name is an array of locale strings)
                uint8 loc = player->GetSession() ? player->GetSession()->GetSessionDbcLocale() : 0;
                std::string achName = achievement->name[loc] ? achievement->name[loc] : "<unknown>";

                // Award essence using centralized utility
                DarkChaos::CrossSystem::CurrencyUtils::AddCurrencyAndSync(
                    playerGuid, CURRENCY_ARTIFACT_ESSENCE, essence_reward, season, player, true);

                // Log transaction
                std::ostringstream reason;
                reason << "Achievement: " << achName;
                LogTokenTransaction(playerGuid, "reward", reason.str().c_str(), 0, essence_reward);

                // Send notification
                std::string achieveMsg = "|cffff9900+" + std::to_string(essence_reward) + " Artifact Essence|r (Achievement: " +
                                        achName + ")";
                ChatHandler(player->GetSession()).SendSysMessage(achieveMsg.c_str());

                if (ShouldEmitTokenLog("ItemUpgrade.Perf.AchievementReward.SamplePct",
                                       "ItemUpgrade.Perf.AchievementReward.MinIntervalMs", 30, 3000))
                {
                    LOG_INFO("scripts.dc", "ItemUpgrade: Player {} earned {} essence from achievement {} ({})",
                        playerGuid, essence_reward, achievement->ID, achName);
                }
            }
        };

        // =====================================================================
        // Creature Script Hooks
        // =====================================================================

        class CreatureTokenHooks : public UnitScript
        {
        public:
            CreatureTokenHooks() : UnitScript("CreatureTokenHooks") {}

            void OnUnitDeath(Unit* unit, Unit* killer) override
            {
                if (!unit || !killer)
                    return;

                Creature* creature = unit->ToCreature();
                if (!creature)
                    return;

                Player* player = killer->GetCharmerOrOwnerPlayerOrPlayerItself();
                if (!player)
                    return;

                uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();

                // Don't award tokens for trivial kills (very low level creatures)
                if (creature->GetLevel() < 50)
                    return;  // Skip low-level creatures

                // Determine reward based on creature type
                uint32 token_reward = 0;
                uint32 essence_reward = 0;
                std::ostringstream reward_reason;

                bool is_boss = IsCreatureBoss(creature);
                bool is_raid = IsRaidCreature(creature);
                bool is_world_boss = creature->isWorldBoss() && !is_raid;

                if (is_world_boss)
                {
                    token_reward = WORLD_BOSS_REWARD;
                    essence_reward = WORLD_BOSS_ESSENCE;
                    reward_reason << "World Boss: " << creature->GetName();
                }
                else if (is_raid)
                {
                    // Raid mob
                    if (is_boss)
                    {
                        token_reward = RAID_BOSS_REWARD;
                        essence_reward = RAID_BOSS_ESSENCE;
                        reward_reason << "Raid Boss: " << creature->GetName();
                    }
                    else
                    {
                        token_reward = RAID_TRASH_REWARD;
                        reward_reason << "Raid Trash: " << creature->GetName();
                    }
                }
                else
                {
                    // Dungeon or world creature
                    if (is_boss)
                    {
                        token_reward = DUNGEON_BOSS_REWARD;
                        essence_reward = DUNGEON_BOSS_ESSENCE;
                        reward_reason << "Dungeon Boss: " << creature->GetName();
                    }
                    else
                    {
                        token_reward = DUNGEON_TRASH_REWARD;
                        reward_reason << "Creature Kill: " << creature->GetName();
                    }
                }

                if (token_reward == 0)
                    return;

                // Check weekly cap (only for regular tokens, not essence)
                if (IsAtWeeklyTokenCap(player->GetGUID().GetCounter(), season))
                {
                    LOG_DEBUG("scripts.dc", "ItemUpgrade: Player {} at weekly token cap, creature kill reward only essence", player->GetGUID().GetCounter());
                    token_reward = 0;  // Zero out tokens, but still award essence
                }

                // Award tokens and essence
                uint32 playerGuid = player->GetGUID().GetCounter();
                if (token_reward > 0)
                {
                    DarkChaos::CrossSystem::CurrencyUtils::AddCurrencyAndSync(
                        playerGuid, CURRENCY_UPGRADE_TOKEN, token_reward, season, player, true);
                }
                if (essence_reward > 0)
                {
                    DarkChaos::CrossSystem::CurrencyUtils::AddCurrencyAndSync(
                        playerGuid, CURRENCY_ARTIFACT_ESSENCE, essence_reward, season, player, true);
                }

                // Log transaction
                LogTokenTransaction(player->GetGUID().GetCounter(), "reward", reward_reason.str().c_str(),
                                   token_reward, essence_reward);

                // Send notification
                if (ShouldEmitTokenLog("ItemUpgrade.Perf.CreatureRewardChat.SamplePct",
                                       "ItemUpgrade.Perf.CreatureRewardChat.MinIntervalMs", 100, 0))
                {
                    if (token_reward > 0 && essence_reward > 0)
                        ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cff00ff00+{} Tokens|r, |cffff9900+{} Essence|r", token_reward, essence_reward).c_str());
                    else if (token_reward > 0)
                        ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cff00ff00+{} Upgrade Tokens|r", token_reward).c_str());
                    else if (essence_reward > 0)
                        ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cffff9900+{} Artifact Essence|r", essence_reward).c_str());
                }

                if (ShouldEmitTokenLog("ItemUpgrade.Perf.CreatureReward.SamplePct",
                                       "ItemUpgrade.Perf.CreatureReward.MinIntervalMs", 10, 750))
                {
                    LOG_INFO("scripts.dc", "ItemUpgrade: Player {} earned {} tokens, {} essence from creature kill {}",
                        player->GetGUID().GetCounter(), token_reward, essence_reward, creature->GetGUID().GetCounter());
                }
            }
        };

        // =====================================================================
        // Registration Functions
        // =====================================================================

    } // namespace ItemUpgrade
} // namespace DarkChaos

// Registration function must be in global namespace for dc_script_loader.cpp
void AddSC_ItemUpgradeTokenHooks()
{
    try
    {
        new DarkChaos::ItemUpgrade::PlayerTokenHooks();
        new DarkChaos::ItemUpgrade::CreatureTokenHooks();
        LOG_INFO("scripts.dc", "ItemUpgrade: Token system hooks registered successfully");
    }
    catch (const std::exception& e)
    {
        LOG_ERROR("scripts.dc", "ItemUpgrade: Failed to register token hooks: {}", e.what());
    }
}
