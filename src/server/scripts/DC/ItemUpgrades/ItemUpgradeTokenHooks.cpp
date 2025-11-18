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
#include <sstream>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Constants for Token Rewards
        // =====================================================================

    static const uint32 WEEKLY_TOKEN_CAP = 500;
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
            
            CharacterDatabase.Execute(
                "INSERT INTO dc_token_transaction_log (player_guid, currency_type, amount, transaction_type, reason) "
                "VALUES ({}, '{}', {}, '{}', '{}')",
                player_guid, currency_type, amount, transaction_type, reason);
        }

        // Check if player is at weekly token cap
        static bool IsAtWeeklyTokenCap(uint32 player_guid, uint32 season = 1)
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT weekly_earned FROM dc_player_upgrade_tokens "
                "WHERE player_guid = {} AND currency_type = 'upgrade_token' AND season = {}",
                player_guid, season);
            if (!result)
                return false;

            uint32 weekly_earned = result->Fetch()[0].Get<uint32>();
            return weekly_earned >= WEEKLY_TOKEN_CAP;
        }

        // Update weekly earned counter
        static void UpdateWeeklyEarned(uint32 player_guid, uint32 amount, uint32 season = 1)
        {
            CharacterDatabase.Execute(
                "UPDATE dc_player_upgrade_tokens SET weekly_earned = weekly_earned + {} "
                "WHERE player_guid = {} AND currency_type = 'upgrade_token' AND season = {}",
                amount, player_guid, season);
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

                // Calculate reward based on victim level
                uint32 reward = (uint32)(PVP_KILL_REWARD * (1.0f + (victim->GetLevel() - 60) * 0.05f));

                // Check weekly cap
                    if (IsAtWeeklyTokenCap(killer->GetGUID().GetCounter()))
                {
                    ChatHandler(killer->GetSession()).PSendSysMessage("|cffff0000 Weekly token cap reached! No tokens awarded.|r");
                    return;
                }

                // Award tokens
                    DarkChaos::ItemUpgrade::GetUpgradeManager()->AddCurrency(killer->GetGUID().GetCounter(), CURRENCY_UPGRADE_TOKEN, reward);
                    UpdateWeeklyEarned(killer->GetGUID().GetCounter(), reward);

                // Log transaction
                std::ostringstream reason;
                reason << "PvP Kill: " << victim->GetName();
                LogTokenTransaction(killer->GetGUID().GetCounter(), "reward", reason.str().c_str(), reward, 0);

                // Send notification
                    ChatHandler(killer->GetSession()).PSendSysMessage("|cff00ff00+%u Upgrade Tokens|r (PvP Kill)", reward);

        LOG_INFO("scripts", "ItemUpgrade: Player {} earned {} tokens from PvP kill of {}",
            killer->GetGUID().GetCounter(), reward, victim->GetGUID().GetCounter());
            }

            void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
            {
                if (!player || !quest)
                    return;

                // Calculate reward
                uint32 reward = CalculateQuestReward(quest->GetQuestLevel(), player->GetLevel());

                // If reward is 0, skip (trivial quest)
                if (reward == 0)
                    return;

                // Check weekly cap
                if (IsAtWeeklyTokenCap(player->GetGUID().GetCounter()))
                {
                    LOG_DEBUG("scripts", "ItemUpgrade: Player {} at weekly token cap, no quest reward", player->GetGUID().GetCounter());
                    return;
                }

                // Cap reward if it would exceed weekly limit
                uint32 season = 1;  // TODO: Get current season from player
                UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();

                // Award tokens
                    mgr->AddCurrency(player->GetGUID().GetCounter(), CURRENCY_UPGRADE_TOKEN, reward, season);
                    UpdateWeeklyEarned(player->GetGUID().GetCounter(), reward, season);

                // Log transaction
                std::ostringstream reason;
                reason << "Quest: " << quest->GetTitle();
                LogTokenTransaction(player->GetGUID().GetCounter(), "reward", reason.str().c_str(), reward, 0);

                // Send notification
                ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00+%u Upgrade Tokens|r (Quest Complete: %s)", reward, quest->GetTitle().c_str());

        LOG_INFO("scripts", "ItemUpgrade: Player {} earned {} tokens from quest {} ({})",
            player->GetGUID().GetCounter(), reward, quest->GetQuestId(), quest->GetTitle());
            }

            void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement) override
            {
                if (!player || !achievement)
                    return;

                // Award essence for achievement
                uint32 essence_reward = ACHIEVEMENT_ESSENCE_REWARD;

                QueryResult result = CharacterDatabase.Query(
                    "SELECT COUNT(*) FROM dc_player_artifact_discoveries "
                    "WHERE player_guid = {} AND artifact_id = {}",
                    player->GetGUID().GetCounter(), achievement->ID);
                if (result && result->Fetch()[0].Get<uint32>() > 0)
                {
                    LOG_DEBUG("scripts", "ItemUpgrade: Achievement {} already claimed by player {}",
                             achievement->ID, player->GetGUID().GetCounter());
                    return;  // Already claimed
                }

                // Prepare a locale-aware achievement name (achievement->name is an array of locale strings)
                uint8 loc = player->GetSession() ? player->GetSession()->GetSessionDbcLocale() : 0;
                std::string achName = achievement->name[loc] ? achievement->name[loc] : "<unknown>";

                // Award essence
                DarkChaos::ItemUpgrade::GetUpgradeManager()->AddCurrency(player->GetGUID().GetCounter(), CURRENCY_ARTIFACT_ESSENCE, essence_reward);

                // Mark as claimed (using 'event' as discovery_type for achievements)
                CharacterDatabase.Execute(
                    "INSERT INTO dc_player_artifact_discoveries (player_guid, artifact_id, discovery_type, discovered_at) "
                    "VALUES ({}, {}, 'event', NOW())",
                    player->GetGUID().GetCounter(), achievement->ID);

                // Log transaction
                std::ostringstream reason;
                reason << "Achievement: " << achName;
                LogTokenTransaction(player->GetGUID().GetCounter(), "reward", reason.str().c_str(), 0, essence_reward);

                // Send notification
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff9900+%u Artifact Essence|r (Achievement: %s)", essence_reward, achName.c_str());

                LOG_INFO("scripts", "ItemUpgrade: Player {} earned {} essence from achievement {} ({})",
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

                // Don't award tokens in Mythic+ dungeons (they have their own token system)
                if (DarkChaos::MythicPlus::MythicPlusRunManager::Instance()->IsPlayerInActiveRun(player->GetGUID()))
                    return;

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
                if (IsAtWeeklyTokenCap(player->GetGUID().GetCounter()))
                {
                    LOG_DEBUG("scripts", "ItemUpgrade: Player {} at weekly token cap, creature kill reward only essence", player->GetGUID().GetCounter());
                    token_reward = 0;  // Zero out tokens, but still award essence
                }

                // Award tokens and essence
                UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
                if (token_reward > 0)
                {
                    mgr->AddCurrency(player->GetGUID().GetCounter(), CURRENCY_UPGRADE_TOKEN, token_reward);
                    UpdateWeeklyEarned(player->GetGUID().GetCounter(), token_reward);
                }
                if (essence_reward > 0)
                    mgr->AddCurrency(player->GetGUID().GetCounter(), CURRENCY_ARTIFACT_ESSENCE, essence_reward);

                // Log transaction
                LogTokenTransaction(player->GetGUID().GetCounter(), "reward", reward_reason.str().c_str(),
                                   token_reward, essence_reward);

                // Send notification
                if (token_reward > 0 && essence_reward > 0)
                    ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00+%u Tokens|r, |cffff9900+%u Essence|r", token_reward, essence_reward);
                else if (token_reward > 0)
                    ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00+%u Upgrade Tokens|r", token_reward);
                else if (essence_reward > 0)
                    ChatHandler(player->GetSession()).PSendSysMessage("|cffff9900+%u Artifact Essence|r", essence_reward);

        LOG_INFO("scripts", "ItemUpgrade: Player {} earned {} tokens, {} essence from creature kill {}",
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
        LOG_INFO("scripts", "ItemUpgrade: Token system hooks registered successfully");
    }
    catch (const std::exception& e)
    {
        LOG_ERROR("scripts", "ItemUpgrade: Failed to register token hooks: {}", e.what());
    }
}
