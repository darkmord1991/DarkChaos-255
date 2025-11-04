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
        static const uint32 DAILY_QUEST_CAP = 100;
        
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
        static const uint32 WORLD_BOSS_REWARD = 100;
        static const uint32 WORLD_BOSS_ESSENCE = 20;
        
        // PvP rewards
        static const uint32 PVP_KILL_REWARD = 15;
        static const float PVP_LEVEL_SCALING = 1.0f;
        
        // Battleground rewards
        static const uint32 BATTLEGROUND_WIN_REWARD = 25;
        static const uint32 BATTLEGROUND_LOSS_REWARD = 5;
        
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
        static void LogTokenTransaction(uint32 player_guid, const char* event_type, 
                                       const char* reason, int32 token_change, int32 essence_change)
        {
            std::ostringstream oss;
            oss << "INSERT INTO dc_token_transaction_log (player_guid, event_type, token_change, essence_change, reason, timestamp) "
                << "VALUES (" << player_guid << ", '" << event_type << "', " << token_change << ", " << essence_change 
                << ", '" << reason << "', NOW())";
            
            CharacterDatabase.Execute(oss.str().c_str());
        }
        
        // Check if player is at weekly token cap
        static bool IsAtWeeklyTokenCap(uint32 player_guid, uint32 season = 1)
        {
            std::ostringstream oss;
                oss << "SELECT weekly_earned FROM dc_player_upgrade_tokens "
                    << "WHERE player_guid = " << player_guid 
                << " AND currency_type = 'upgrade_token' AND season = " << season;
            
            QueryResult result = CharacterDatabase.Query(oss.str().c_str());
            if (!result)
                return false;
            
            uint32 weekly_earned = result->Fetch()[0].Get<uint32>();
            return weekly_earned >= WEEKLY_TOKEN_CAP;
        }
        
        // Update weekly earned counter
        static void UpdateWeeklyEarned(uint32 player_guid, uint32 amount, uint32 season = 1)
        {
            std::ostringstream oss;
            oss << "UPDATE dc_player_upgrade_tokens SET weekly_earned = weekly_earned + " << amount 
                << " WHERE player_guid = " << player_guid 
                << " AND currency_type = 'upgrade_token' AND season = " << season;
            
            CharacterDatabase.Execute(oss.str().c_str());
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
                    killer->SendSysMessage("|cffff0000 Weekly token cap reached! No tokens awarded.|r");
                    return;
                }
                
                // Award tokens
                    DarkChaos::ItemUpgrade::GetUpgradeManager()->AddCurrency(killer->GetGUID().GetCounter(), CURRENCY_UPGRADE_TOKEN, reward);
                    UpdateWeeklyEarned(killer->GetGUID().GetCounter(), reward);
                
                // Log transaction
                std::ostringstream reason;
                reason << "PvP Kill: " << victim->GetName();
                LogTokenTransaction(killer->GetGUID().GetCounter(), "PvP", reason.str().c_str(), reward, 0);
                
                // Send notification
                killer->SendSysMessage("|cff00ff00+" << reward << " Upgrade Tokens|r (PvP Kill)");
                
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
                LogTokenTransaction(player->GetGUID().GetCounter(), "Quest", reason.str().c_str(), reward, 0);
                
                // Send notification
                player->SendSysMessage("|cff00ff00+" << reward << " Upgrade Tokens|r (Quest Complete: " << quest->GetTitle() << ")");
                
        LOG_INFO("scripts", "ItemUpgrade: Player {} earned {} tokens from quest {} ({})", 
            player->GetGUID().GetCounter(), reward, quest->GetQuestId(), quest->GetTitle());
            }
            
            void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement) override
            {
                if (!player || !achievement)
                    return;
                
                // Award essence for achievement
                uint32 essence_reward = ACHIEVEMENT_ESSENCE_REWARD;
                
                // Check if achievement was already claimed (one-time only)
                std::ostringstream oss;
                oss << "SELECT COUNT(*) FROM dc_player_artifact_discoveries "
                    << "WHERE player_guid = " << player->GetGUID().GetCounter() 
                    << " AND artifact_id = " << achievement->ID;
                
                QueryResult result = CharacterDatabase.Query(oss.str().c_str());
                if (result && result->Fetch()[0].Get<uint32>() > 0)
                {
                    LOG_DEBUG("scripts", "ItemUpgrade: Achievement {} already claimed by player {}", 
                             achievement->ID, player->GetGUID().GetCounter());
                    return;  // Already claimed
                }
                
                // Award essence
                    DarkChaos::ItemUpgrade::GetUpgradeManager()->AddCurrency(player->GetGUID().GetCounter(), CURRENCY_ARTIFACT_ESSENCE, essence_reward);
                
                // Mark as claimed
                std::ostringstream insert_oss;
                insert_oss << "INSERT INTO dc_player_artifact_discoveries (player_guid, artifact_id, discovered_at, season) "
                          << "VALUES (" << player->GetGUID().GetCounter() << ", " << achievement->ID << ", NOW(), 1)";
                CharacterDatabase.Execute(insert_oss.str().c_str());
                
                // Log transaction
                std::ostringstream reason;
                reason << "Achievement: " << achievement->name;
                LogTokenTransaction(player->GetGUID().GetCounter(), "Achievement", reason.str().c_str(), 0, essence_reward);
                
                // Send notification
                player->SendSysMessage("|cffff9900+" << essence_reward << " Artifact Essence|r (Achievement: " << achievement->name << ")");
                
        LOG_INFO("scripts", "ItemUpgrade: Player {} earned {} essence from achievement {} ({})", 
            player->GetGUID().GetCounter(), essence_reward, achievement->ID, achievement->name);
            }
        };
        
        // =====================================================================
        // Creature Script Hooks
        // =====================================================================
        
        class CreatureTokenHooks : public CreatureScript
        {
        public:
            CreatureTokenHooks() : CreatureScript("CreatureTokenHooks") {}
            
            void OnDeath(Creature* creature, Unit* killer) override
            {
                if (!creature || !killer)
                    return;
                
                Player* player = killer->ToPlayer();
                if (!player)
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
                LogTokenTransaction(player->GetGUID().GetCounter(), "Creature", reward_reason.str().c_str(), 
                                   token_reward, essence_reward);
                
                // Send notification
                if (token_reward > 0 && essence_reward > 0)
                    player->SendSysMessage("|cff00ff00+" << token_reward << " Tokens|r, |cffff9900+" << essence_reward << " Essence|r");
                else if (token_reward > 0)
                    player->SendSysMessage("|cff00ff00+" << token_reward << " Upgrade Tokens|r");
                else if (essence_reward > 0)
                    player->SendSysMessage("|cffff9900+" << essence_reward << " Artifact Essence|r");
                
        LOG_INFO("scripts", "ItemUpgrade: Player {} earned {} tokens, {} essence from creature kill {}", 
            player->GetGUID().GetCounter(), token_reward, essence_reward, creature->GetGUID().GetCounter());
            }
        };
        
        // =====================================================================
        // Registration Functions
        // =====================================================================
        
        void AddSC_ItemUpgradeTokenHooks()
        {
            new PlayerTokenHooks();
            new CreatureTokenHooks();
            LOG_INFO("scripts", "ItemUpgrade: Token system hooks registered successfully");
        }
    }
}
