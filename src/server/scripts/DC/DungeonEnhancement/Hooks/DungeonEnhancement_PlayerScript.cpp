/*
 * ============================================================================
 * Dungeon Enhancement System - Player Hooks
 * ============================================================================
 * Purpose: Handle player death, login, weekly reset
 * Location: src/server/scripts/DC/DungeonEnhancement/Hooks/
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Map.h"
#include "Group.h"
#include "Chat.h"
#include "../Core/DungeonEnhancementManager.h"
#include "../Core/DungeonEnhancementConstants.h"
#include "../Core/MythicRunTracker.h"
#include "../Affixes/MythicAffixFactory.h"

using namespace DungeonEnhancement;

// Forward declare factory init/cleanup
namespace DungeonEnhancement
{
    extern void InitializeAffixFactory();
    extern void CleanupAffixFactory();
}

class DungeonEnhancement_PlayerScript : public PlayerScript
{
public:
    DungeonEnhancement_PlayerScript() : PlayerScript("DungeonEnhancement_PlayerScript") { }

    // ========================================================================
    // PLAYER DEATH HOOK
    // ========================================================================
    void OnPlayerDeath(Player* player, Unit* /*killer*/)
    {
        if (!player || !sDungeonEnhancementMgr->IsEnabled())
            return;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return;

        uint32 instanceId = map->GetInstanceId();

        // Check if a Mythic+ run is active
        if (!MythicRunTracker::IsRunActive(instanceId))
            return;

        // Record player death
        MythicRunTracker::OnPlayerDeath(player, map);

        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Player %s died in M+ instance %u",
                 player->GetName().c_str(), instanceId);
    }

    // ========================================================================
    // PLAYER LOGIN HOOK
    // ========================================================================
    void OnLogin(Player* player)
    {
        if (!player || !sDungeonEnhancementMgr->IsEnabled())
            return;

        // Check if player has an active keystone
        if (sDungeonEnhancementMgr->PlayerHasKeystone(player))
        {
            uint8 keystoneLevel = sDungeonEnhancementMgr->GetPlayerKeystoneLevel(player);
            
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFF00FF00You have an active Mythic+%u Keystone.|r", keystoneLevel
            );
        }

        // Check vault progress
        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        if (season && season->vaultEnabled)
        {
            uint8 vaultProgress = sDungeonEnhancementMgr->GetPlayerVaultProgress(player);
            
            if (vaultProgress > 0)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFAA00Great Vault Progress: %u/8 dungeons completed this week.|r",
                    vaultProgress
                );
            }
        }

        // Show current season info (once per login)
        if (season)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFF00FF00Mythic+ Season %u is active! Visit the Dungeon Teleporter to get started.|r",
                season->seasonId
            );
        }
    }

    // ========================================================================
    // DAMAGE TAKEN HOOK (for player-affecting affixes)
    // ========================================================================
    void OnTakeDamage(Player* player, Unit* attacker, uint32& damage)
    {
        if (!player || !attacker || !sDungeonEnhancementMgr->IsEnabled())
            return;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return;

        uint32 instanceId = map->GetInstanceId();

        // Check if a Mythic+ run is active
        if (!MythicRunTracker::IsRunActive(instanceId))
            return;

        MythicRunData* runData = MythicRunTracker::GetRunData(instanceId);
        if (!runData)
            return;

        // Apply affix effects that modify player damage taken via factory
        Creature* creatureAttacker = attacker->ToCreature();
        if (creatureAttacker)
            sAffixFactory->OnPlayerDamaged(instanceId, player, creatureAttacker, damage, runData->keystoneLevel);
    }

    // ========================================================================
    // GROUP LEAVE HOOK (abandon run if all players leave)
    // ========================================================================
    void OnGroupLeave(Player* player, Group* /*group*/)
    {
        if (!player || !sDungeonEnhancementMgr->IsEnabled())
            return;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return;

        uint32 instanceId = map->GetInstanceId();

        // Check if a Mythic+ run is active
        if (!MythicRunTracker::IsRunActive(instanceId))
            return;

        // Remove player from participants
        MythicRunTracker::RemoveParticipant(instanceId, player->GetGUID());

        // Check if all players have left
        std::unordered_set<ObjectGuid> participants = MythicRunTracker::GetParticipants(instanceId);
        
        uint32 remainingInInstance = 0;
        for (ObjectGuid guid : participants)
        {
            Player* participant = ObjectAccessor::FindPlayer(guid);
            if (participant && participant->GetMapId() == map->GetId() && 
                participant->GetInstanceId() == instanceId)
            {
                remainingInInstance++;
            }
        }

        // If no participants remain in instance, abandon the run
        if (remainingInInstance == 0)
        {
            LOG_INFO(LogCategory::MYTHIC_PLUS, 
                     "All players left instance %u - abandoning M+ run",
                     instanceId);
            
            MythicRunTracker::AbandonRun(map);
        }
    }

    // ========================================================================
    // MAP CHANGE HOOK (track teleports out of dungeon)
    // ========================================================================
    void OnMapChanged(Player* player)
    {
        if (!player || !sDungeonEnhancementMgr->IsEnabled())
            return;

        // Note: This fires AFTER player has changed maps
        // Use previous map ID to check if they left a Mythic+ instance
        // Implementation depends on core support for tracking previous map
    }
};

// ============================================================================
// WORLD SCRIPT (for weekly reset and periodic updates)
// ============================================================================

class DungeonEnhancement_WorldScript : public WorldScript
{
public:
    DungeonEnhancement_WorldScript() : WorldScript("DungeonEnhancement_WorldScript") { }

    void OnStartup() override
    {
        if (!sDungeonEnhancementMgr->IsEnabled())
            return;

        // Initialize manager on server startup
        sDungeonEnhancementMgr->Initialize();

        // Initialize affix factory
        DungeonEnhancement::InitializeAffixFactory();

        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Dungeon Enhancement System initialized successfully");
    }

    void OnShutdown() override
    {
        if (!sDungeonEnhancementMgr->IsEnabled())
            return;

        // Cleanup affix factory
        DungeonEnhancement::CleanupAffixFactory();

        // Shutdown manager
        sDungeonEnhancementMgr->Shutdown();

        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Dungeon Enhancement System shutdown complete");
    }

    void OnUpdate(uint32 diff) override
    {
        if (!sDungeonEnhancementMgr->IsEnabled())
            return;

        // Periodic affix tick for environmental effects (Volcanic, Grievous)
        // Call every 1 second
        static uint32 tickAccumulator = 0;
        tickAccumulator += diff;

        if (tickAccumulator >= 1000) // 1 second
        {
            tickAccumulator = 0;

            // Iterate all active M+ instances and call affix OnPeriodicTick
            // Note: This is a simplified approach - in production, you'd want
            // to track active instances more efficiently
            
            // For now, we'll just log periodic tick
            // The proper implementation would require instance iteration
        }

        // Periodic cache refresh (handled internally by manager)
        // TODO: Add periodic cleanup of old runs
        // MythicRunTracker::CleanupOldRuns(60);  // Clean runs older than 60 minutes
    }

    // ========================================================================
    // WEEKLY RESET (Tuesday reset)
    // ========================================================================
    void OnBeforeWorldInitialized() override
    {
        if (!sDungeonEnhancementMgr->IsEnabled())
            return;

        // Check if it's Tuesday (weekly reset day)
        time_t now = time(nullptr);
        tm timeInfo;
        localtime_r(&now, &timeInfo);
        
        // Tuesday = 2 (0=Sunday, 1=Monday, 2=Tuesday, etc.)
        if (timeInfo.tm_wday == 2)
        {
            // Check if reset has already happened today
            // TODO: Store last reset date in database and compare
            
            // Perform weekly reset
            PerformWeeklyReset();
        }
    }

private:
    void PerformWeeklyReset()
    {
        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Performing Mythic+ weekly reset (Great Vault, Keystones, Affixes)");

        // Reset all players' vault progress
        sDungeonEnhancementMgr->ResetWeeklyVaultProgress();
        LOG_INFO(LogCategory::MYTHIC_PLUS, "Vault progress reset completed");

        // Degrade all keystones by 1 level (minimum M+2)
        CharacterDatabase.Execute(
            "UPDATE dc_mythic_keystones SET keystoneLevel = GREATEST(keystoneLevel - 1, {}) WHERE keystoneLevel > {}",
            static_cast<uint8>(MYTHIC_PLUS_MIN_LEVEL), static_cast<uint8>(MYTHIC_PLUS_MIN_LEVEL)
        );
        LOG_INFO(LogCategory::MYTHIC_PLUS, "Keystone degradation completed");

        // Advance affix rotation by 1 week
        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        if (season && season->isActive)
        {
            // Rotate to next week's affixes (12-week cycle)
            CharacterDatabase.Execute(
                "UPDATE dc_mythic_affix_rotation SET weekNumber = ((weekNumber % 12) + 1) WHERE seasonId = {}",
                season->seasonId
            );
            LOG_INFO(LogCategory::MYTHIC_PLUS, "Affix rotation advanced for Season {}", season->seasonId);
        }

        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Weekly reset completed successfully");
    }
};

void AddSC_DungeonEnhancement_PlayerScript()
{
    new DungeonEnhancement_PlayerScript();
    new DungeonEnhancement_WorldScript();
}
