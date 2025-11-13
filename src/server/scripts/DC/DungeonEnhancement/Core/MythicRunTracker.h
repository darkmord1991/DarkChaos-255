/*
 * ============================================================================
 * Dungeon Enhancement System - Run Tracker (Header)
 * ============================================================================
 * Purpose: Track active Mythic/M+ runs (deaths, timer, boss kills, state)
 * Location: src/server/scripts/DC/DungeonEnhancement/Core/
 * ============================================================================
 */

#ifndef MYTHIC_RUN_TRACKER_H
#define MYTHIC_RUN_TRACKER_H

#include "Common.h"
#include "DungeonEnhancementConstants.h"
#include <map>
#include <unordered_set>

class Player;
class Map;
class Group;

namespace DungeonEnhancement
{
    // ========================================================================
    // RUN STATE
    // ========================================================================
    
    enum RunState
    {
        RUN_STATE_NOT_STARTED   = 0,
        RUN_STATE_IN_PROGRESS   = 1,
        RUN_STATE_COMPLETED     = 2,
        RUN_STATE_FAILED        = 3,
        RUN_STATE_ABANDONED     = 4
    };
    
    // ========================================================================
    // RUN DATA STRUCTURE
    // ========================================================================
    
    struct MythicRunData
    {
        uint32 instanceId;
        uint16 mapId;
        uint8 keystoneLevel;
        RunState state;
        
        // Death tracking
        uint8 totalDeaths;
        std::map<ObjectGuid, uint8> playerDeaths;  // Player GUID -> death count
        
        // Boss tracking
        uint8 bossesKilled;
        uint8 requiredBosses;
        std::unordered_set<uint32> killedBossEntries;
        
        // Timer tracking
        uint32 startTime;
        uint32 endTime;
        uint32 timerLimitSeconds;
        
        // Group tracking
        ObjectGuid groupLeaderGUID;
        std::unordered_set<ObjectGuid> participantGUIDs;
        
        // Keystone tracking
        ObjectGuid keystoneOwnerGUID;
        uint32 keystoneItemEntry;
        
        // Constructor
        MythicRunData()
            : instanceId(0), mapId(0), keystoneLevel(0), state(RUN_STATE_NOT_STARTED),
              totalDeaths(0), bossesKilled(0), requiredBosses(0), 
              startTime(0), endTime(0), timerLimitSeconds(0),
              keystoneItemEntry(0)
        {}
    };
    
    // ========================================================================
    // RUN TRACKER CLASS
    // ========================================================================
    
    class MythicRunTracker
    {
    public:
        // ====================================================================
        // RUN MANAGEMENT
        // ====================================================================
        
        /**
         * Start a new Mythic+ run for the given instance
         * @param map The dungeon map
         * @param keystoneLevel The keystone level (2-10)
         * @param keystoneOwner The player who activated the keystone
         */
        static void StartRun(Map* map, uint8 keystoneLevel, Player* keystoneOwner);
        
        /**
         * End a run (completion or failure)
         * @param map The dungeon map
         * @param success True if completed successfully, false if failed
         */
        static void EndRun(Map* map, bool success);
        
        /**
         * Abandon a run (group disbanded or left dungeon)
         * @param map The dungeon map
         */
        static void AbandonRun(Map* map);
        
        /**
         * Get run data for an instance
         * @param instanceId The instance ID
         * @return Pointer to run data or nullptr if not found
         */
        static MythicRunData* GetRunData(uint32 instanceId);
        
        /**
         * Check if an instance has an active run
         * @param instanceId The instance ID
         * @return True if run exists and is in progress
         */
        static bool IsRunActive(uint32 instanceId);
        
        // ====================================================================
        // DEATH TRACKING
        // ====================================================================
        
        /**
         * Record a player death
         * @param player The player who died
         * @param map The dungeon map
         */
        static void OnPlayerDeath(Player* player, Map* map);
        
        /**
         * Get total deaths for a run
         * @param instanceId The instance ID
         * @return Total death count
         */
        static uint8 GetTotalDeaths(uint32 instanceId);
        
        /**
         * Get individual player death count
         * @param instanceId The instance ID
         * @param playerGUID The player's GUID
         * @return Player's death count
         */
        static uint8 GetPlayerDeaths(uint32 instanceId, ObjectGuid playerGUID);
        
        /**
         * Check if death limit has been reached
         * @param instanceId The instance ID
         * @return True if at or above MAX_DEATHS_BEFORE_FAILURE
         */
        static bool IsDeathLimitReached(uint32 instanceId);
        
        // ====================================================================
        // BOSS TRACKING
        // ====================================================================
        
        /**
         * Record a boss kill
         * @param map The dungeon map
         * @param bossEntry The boss creature entry
         */
        static void OnBossKilled(Map* map, uint32 bossEntry);
        
        /**
         * Check if all required bosses are killed
         * @param instanceId The instance ID
         * @return True if all bosses killed
         */
        static bool AreAllBossesKilled(uint32 instanceId);
        
        /**
         * Get boss kill count
         * @param instanceId The instance ID
         * @return Number of bosses killed
         */
        static uint8 GetBossesKilled(uint32 instanceId);
        
        // ====================================================================
        // TIMER TRACKING
        // ====================================================================
        
        /**
         * Get elapsed time for a run (in seconds)
         * @param instanceId The instance ID
         * @return Elapsed time in seconds
         */
        static uint32 GetElapsedTime(uint32 instanceId);
        
        /**
         * Get remaining time for a run (in seconds)
         * @param instanceId The instance ID
         * @return Remaining time in seconds (0 if expired)
         */
        static uint32 GetRemainingTime(uint32 instanceId);
        
        /**
         * Check if timer has expired
         * @param instanceId The instance ID
         * @return True if timer expired
         */
        static bool IsTimerExpired(uint32 instanceId);
        
        /**
         * Get timer limit for a dungeon
         * @param mapId The dungeon map ID
         * @return Timer limit in seconds
         */
        static uint32 GetTimerLimit(uint16 mapId);
        
        // ====================================================================
        // COMPLETION HANDLING
        // ====================================================================
        
        /**
         * Calculate keystone upgrade level based on deaths and timer
         * @param instanceId The instance ID
         * @return Upgrade amount (-1 = destroy, 0 = no change, +1, +2, +3)
         */
        static int8 CalculateKeystoneUpgrade(uint32 instanceId);
        
        /**
         * Award completion rewards to group
         * @param map The dungeon map
         * @param upgradeLevel The keystone upgrade level
         */
        static void AwardCompletionRewards(Map* map, int8 upgradeLevel);
        
        /**
         * Handle run failure (15 deaths)
         * @param map The dungeon map
         */
        static void HandleRunFailure(Map* map);
        
        /**
         * Check and award achievements based on run completion
         * @param runData The run data
         */
        static void CheckAndAwardAchievements(MythicRunData* runData);
        
        // ====================================================================
        // GROUP UTILITIES
        // ====================================================================
        
        /**
         * Add participant to run
         * @param instanceId The instance ID
         * @param playerGUID The player's GUID
         */
        static void AddParticipant(uint32 instanceId, ObjectGuid playerGUID);
        
        /**
         * Remove participant from run
         * @param instanceId The instance ID
         * @param playerGUID The player's GUID
         */
        static void RemoveParticipant(uint32 instanceId, ObjectGuid playerGUID);
        
        /**
         * Get all participants in a run
         * @param instanceId The instance ID
         * @return Set of participant GUIDs
         */
        static std::unordered_set<ObjectGuid> GetParticipants(uint32 instanceId);
        
        // ====================================================================
        // CLEANUP
        // ====================================================================
        
        /**
         * Clean up completed/abandoned runs older than X minutes
         * @param maxAgeMinutes Maximum age before cleanup (default: 60)
         */
        static void CleanupOldRuns(uint32 maxAgeMinutes = 60);
        
        /**
         * Remove run data for an instance
         * @param instanceId The instance ID
         */
        static void RemoveRunData(uint32 instanceId);
        
    private:
        // ====================================================================
        // INTERNAL DATA
        // ====================================================================
        
        // Active runs: Instance ID -> Run Data
        static std::map<uint32, MythicRunData> _activeRuns;
        
        // Helper: Broadcast message to all participants
        static void BroadcastToParticipants(uint32 instanceId, const std::string& message, uint32 color);
        
        // Helper: Get player object from GUID
        static Player* GetPlayerByGUID(ObjectGuid guid);
    };

} // namespace DungeonEnhancement

#endif // MYTHIC_RUN_TRACKER_H
