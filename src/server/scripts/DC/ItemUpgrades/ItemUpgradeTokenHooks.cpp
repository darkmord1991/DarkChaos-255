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
#include "ItemUpgradeManager.h"
#include "DC/CrossSystem/SeasonResolver.h"
#include "../CrossSystem/CrossSystemUtilities.h"
#include "Common.h"
#include <sstream>

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

            CreatureTemplate const* cTemplate = creature->GetCreatureTemplate();
            return cTemplate && cTemplate->type_flags & CREATURE_TYPE_FLAG_BOSS_MOB;
        }

        // Log token transaction to database
        static void LogTokenTransaction(uint32 player_guid, const char* transaction_type,
                                       const char* reason, int32 token_change, int32 essence_change)
        {
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

        LOG_INFO("scripts.dc", "ItemUpgrade: Player {} earned {} tokens from PvP kill of {}",
            killer->GetGUID().GetCounter(), reward, victim->GetGUID().GetCounter());
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

        LOG_INFO("scripts.dc", "ItemUpgrade: Player {} earned {} tokens from quest {} ({})",
            player->GetGUID().GetCounter(), reward, quest->GetQuestId(), quest->GetTitle());
            }

            void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement) override
            {
                if (!player || !achievement)
                    return;

                uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();

                // Award essence for achievement
                uint32 essence_reward = ACHIEVEMENT_ESSENCE_REWARD;

                try
                {
                    QueryResult result = CharacterDatabase.Query(
                        "SELECT COUNT(*) FROM dc_player_artifact_discoveries "
                        "WHERE player_guid = {} AND artifact_id = {}",
                        player->GetGUID().GetCounter(), achievement->ID);
                    if (result && result->Fetch()[0].Get<uint32>() > 0)
                    {
                        LOG_DEBUG("scripts.dc", "ItemUpgrade: Achievement {} already claimed by player {}",
                                 achievement->ID, player->GetGUID().GetCounter());
                        return;  // Already claimed
                    }
                }
                catch (std::exception const& e)
                {
                    LOG_DEBUG("scripts.dc", "ItemUpgrade: dc_player_artifact_discoveries query failed: {}", e.what());
                }
                catch (...)
                {
                    // Table may not exist yet - skip artifact discovery check
                    LOG_DEBUG("scripts.dc", "ItemUpgrade: dc_player_artifact_discoveries table not found, skipping duplicate check");
                }

                // Prepare a locale-aware achievement name (achievement->name is an array of locale strings)
                uint8 loc = player->GetSession() ? player->GetSession()->GetSessionDbcLocale() : 0;
                std::string achName = achievement->name[loc] ? achievement->name[loc] : "<unknown>";

                // Award essence using centralized utility
                uint32 playerGuid = player->GetGUID().GetCounter();
                DarkChaos::CrossSystem::CurrencyUtils::AddCurrencyAndSync(
                    playerGuid, CURRENCY_ARTIFACT_ESSENCE, essence_reward, season, player, true);

                // Mark as claimed (using 'event' as discovery_type for achievements)
                try
                {
                    CharacterDatabase.Execute(
                        "INSERT INTO dc_player_artifact_discoveries (player_guid, artifact_id, discovery_type, discovered_at) "
                        "VALUES ({}, {}, 'event', NOW())",
                        player->GetGUID().GetCounter(), achievement->ID);
                }
                catch (std::exception const& e)
                {
                    LOG_DEBUG("scripts.dc", "ItemUpgrade: Could not insert into dc_player_artifact_discoveries: {}", e.what());
                }
                catch (...)
                {
                    // Table may not exist - log but continue
                    LOG_DEBUG("scripts.dc", "ItemUpgrade: Could not insert into dc_player_artifact_discoveries, table may not exist");
                }

                // Log transaction
                std::ostringstream reason;
                reason << "Achievement: " << achName;
                LogTokenTransaction(player->GetGUID().GetCounter(), "reward", reason.str().c_str(), 0, essence_reward);

                // Send notification
                std::string achieveMsg = "|cffff9900+" + std::to_string(essence_reward) + " Artifact Essence|r (Achievement: " +
                                        achName + ")";
                ChatHandler(player->GetSession()).SendSysMessage(achieveMsg.c_str());

                LOG_INFO("scripts.dc", "ItemUpgrade: Player {} earned {} essence from achievement {} ({})",
                    player->GetGUID().GetCounter(), essence_reward, achievement->ID, achName);
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

                Player* player = killer->ToPlayer();
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

                if (is_raid)
                {
                    // Raid boss
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
                UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
                if (token_reward > 0)
                    mgr->AddCurrency(player->GetGUID().GetCounter(), CURRENCY_UPGRADE_TOKEN, token_reward, season);
                if (essence_reward > 0)
                    mgr->AddCurrency(player->GetGUID().GetCounter(), CURRENCY_ARTIFACT_ESSENCE, essence_reward, season);

                // Log transaction
                LogTokenTransaction(player->GetGUID().GetCounter(), "reward", reward_reason.str().c_str(),
                                   token_reward, essence_reward);

                // Send notification
                if (token_reward > 0 && essence_reward > 0)
                    ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cff00ff00+{} Tokens|r, |cffff9900+{} Essence|r", token_reward, essence_reward).c_str());
                else if (token_reward > 0)
                    ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cff00ff00+{} Upgrade Tokens|r", token_reward).c_str());
                else if (essence_reward > 0)
                    ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cffff9900+{} Artifact Essence|r", essence_reward).c_str());

        LOG_INFO("scripts.dc", "ItemUpgrade: Player {} earned {} tokens, {} essence from creature kill {}",
            player->GetGUID().GetCounter(), token_reward, essence_reward, creature->GetGUID().GetCounter());
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
