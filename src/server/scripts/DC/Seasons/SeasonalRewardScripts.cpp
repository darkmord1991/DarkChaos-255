/*
 * Seasonal Reward System - Script Hooks
 * 
 * Player scripts and world update hooks for seasonal reward system
 * 
 * Author: DarkChaos Development Team
 * Date: November 22, 2025
 */

#include "SeasonalRewardSystem.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "QuestDef.h"
#include "Group.h"

using namespace DarkChaos::SeasonalRewards;

// =====================================================================
// Player Script Hooks
// =====================================================================

class SeasonalRewardPlayerScript : public PlayerScript
{
public:
    SeasonalRewardPlayerScript() : PlayerScript("SeasonalRewardPlayerScript") {}
    
    // Check weekly reset on login
    void OnLogin(Player* player)
    {
        if (!sSeasonalRewards->GetConfig().enabled)
            return;
        
        if (sSeasonalRewards->IsNewWeek(player))
        {
            sSeasonalRewards->ResetWeeklyStats(player);
            
            // Check if player has uncollected chest
            WeeklyChest* chest = sSeasonalRewards->GetWeeklyChest(player);
            if (chest && !chest->collected)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Seasonal Rewards]|r You have an uncollected weekly chest! Use |cffffcc00.season chest|r to claim it.");
            }
        }
    }
    
    // Process quest rewards
    void OnQuestComplete(Player* player, Quest const* quest)
    {
        if (!sSeasonalRewards->GetConfig().enabled)
            return;
        
        sSeasonalRewards->ProcessQuestReward(player, quest->GetQuestId());
    }
    
    // Process creature kills
    void OnCreatureKill(Player* player, Creature* creature)
    {
        if (!sSeasonalRewards->GetConfig().enabled)
            return;
        
        // Determine if dungeon or world boss
        bool isDungeonBoss = creature->IsDungeonBoss();
        bool isWorldBoss = creature->isWorldBoss();
        
        // Handle group loot distribution
        Group* group = player->GetGroup();
        if (group)
        {
            // Award to all group members in range
            for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
            {
                Player* member = itr->GetSource();
                if (member && member->IsInRange(creature, 100.0f, true)) // 100 yard range
                {
                    sSeasonalRewards->ProcessCreatureKill(member, creature->GetEntry(), isDungeonBoss, isWorldBoss);
                }
            }
        }
        else
        {
            // Solo kill
            sSeasonalRewards->ProcessCreatureKill(player, creature->GetEntry(), isDungeonBoss, isWorldBoss);
        }
    }
};

// =====================================================================
// World Script for periodic updates
// =====================================================================

class SeasonalRewardWorldScript : public WorldScript
{
public:
    SeasonalRewardWorldScript() : WorldScript("SeasonalRewardWorldScript") {}
    
    void OnAfterConfigLoad(bool /*reload*/) override
    {
        sSeasonalRewards->LoadConfiguration();
        sSeasonalRewards->LoadPlayerStats();
        sSeasonalRewards->Initialize();
        
        // Register with generic seasonal system if available
        if (DarkChaos::Seasonal::GetSeasonalManager())
        {
            DarkChaos::Seasonal::SystemRegistration registration;
            registration.system_name = sSeasonalRewards->GetSystemName();
            registration.system_version = std::to_string(sSeasonalRewards->GetSystemVersion());
            registration.priority = 100; // Standard priority
            
            // Bind callbacks to SeasonalRewardManager methods
            registration.on_season_event = [](uint32 season_id, DarkChaos::Seasonal::SeasonEventType event_type) {
                if (event_type == DarkChaos::Seasonal::SEASON_EVENT_START)
                    sSeasonalRewards->OnSeasonStart(season_id);
                else if (event_type == DarkChaos::Seasonal::SEASON_EVENT_END)
                    sSeasonalRewards->OnSeasonEnd(season_id);
            };
            
            registration.on_player_season_change = [](uint32 player_guid, uint32 old_season, uint32 new_season) {
                sSeasonalRewards->OnPlayerSeasonChange(player_guid, old_season, new_season);
            };
            
            registration.validate_season_transition = [](uint32 player_guid, uint32 season_id) {
                return sSeasonalRewards->ValidateSeasonTransition(player_guid, season_id);
            };
            
            registration.initialize_player_data = [](uint32 player_guid, uint32 season_id) {
                // Player stats are auto-initialized on first access
            };
            
            registration.cleanup_season_data = [](uint32 season_id) {
                sSeasonalRewards->CleanupFromSeason(season_id);
            };
            
            if (DarkChaos::Seasonal::GetSeasonalManager()->RegisterSystem(registration))
            {
                LOG_INFO("module", ">> [SeasonalRewards] Registered with SeasonalManager");
            }
            else
            {
                LOG_ERROR("module", ">> [SeasonalRewards] Failed to register with SeasonalManager!");
            }
        }
        else
        {
            LOG_WARN("module", ">> [SeasonalRewards] SeasonalManager not available - running in standalone mode");
        }
    }
    
    void OnUpdate(uint32 diff) override
    {
        sSeasonalRewards->Update(diff);
    }
};

// =====================================================================
// Registration
// =====================================================================

void AddSC_SeasonalRewardScripts()
{
    new SeasonalRewardPlayerScript();
    new SeasonalRewardWorldScript();
}
