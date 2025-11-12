/*
 * ============================================================================
 * Dungeon Enhancement System - Run Tracker (Implementation)
 * ============================================================================
 * Purpose: Track active Mythic/M+ runs (deaths, timer, boss kills, state)
 * Location: src/server/scripts/DC/DungeonEnhancement/Core/
 * ============================================================================
 */

#include "MythicRunTracker.h"
#include "DungeonEnhancementManager.h"
#include "Player.h"
#include "Group.h"
#include "Map.h"
#include "InstanceScript.h"
#include "WorldSession.h"
#include "../Affixes/MythicAffixFactory.h"
#include "Chat.h"
#include "Log.h"

namespace DungeonEnhancement
{
    // Initialize static member
    std::map<uint32, MythicRunData> MythicRunTracker::_activeRuns;
    
    // ========================================================================
    // RUN MANAGEMENT
    // ========================================================================
    
    void MythicRunTracker::StartRun(Map* map, uint8 keystoneLevel, Player* keystoneOwner)
    {
        if (!map || !keystoneOwner)
            return;
        
        uint32 instanceId = map->GetInstanceId();
        uint16 mapId = map->GetId();
        
        // Check if run already exists
        if (IsRunActive(instanceId))
        {
            LOG_WARN(LogCategory::MYTHIC_PLUS, 
                     "Attempted to start run for instance %u but run already active", instanceId);
            return;
        }
        
        // Get dungeon configuration
        DungeonConfig* config = sDungeonEnhancementMgr->GetDungeonConfig(mapId);
        if (!config)
        {
            LOG_ERROR(LogCategory::MYTHIC_PLUS, 
                      "Failed to start run: No dungeon config for map %u", mapId);
            return;
        }
        
        // Create new run data
        MythicRunData runData;
        runData.instanceId = instanceId;
        runData.mapId = mapId;
        runData.keystoneLevel = keystoneLevel;
        runData.state = RUN_STATE_IN_PROGRESS;
        runData.startTime = time(nullptr);
        runData.timerLimitSeconds = GetTimerLimit(mapId);
        runData.requiredBosses = config->bossCount;
        runData.keystoneOwnerGUID = keystoneOwner->GetGUID();
        runData.keystoneItemEntry = ITEM_KEYSTONE_BASE + keystoneLevel;
        
        // Add group members as participants
        Group* group = keystoneOwner->GetGroup();
        if (group)
        {
            runData.groupLeaderGUID = group->GetLeaderGUID();
            
            for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
            {
                Player* member = itr->GetSource();
                if (member && member->GetMapId() == mapId)
                {
                    runData.participantGUIDs.insert(member->GetGUID());
                    runData.playerDeaths[member->GetGUID()] = 0;
                }
            }
        }
        else
        {
            // Solo player
            runData.participantGUIDs.insert(keystoneOwner->GetGUID());
            runData.playerDeaths[keystoneOwner->GetGUID()] = 0;
        }
        
        // Store run data
        _activeRuns[instanceId] = runData;
        
        // Broadcast start message
        std::string startMsg = sDungeonEnhancementMgr->GetColoredMessage(
            Colors::MYTHIC_PLUS, 
            "Mythic+ Run Started! M+%u - %s. Timer: %u minutes. Death Limit: %u",
            keystoneLevel,
            config->dungeonName.c_str(),
            runData.timerLimitSeconds / 60,
            MAX_DEATHS_BEFORE_PENALTY
        );
        BroadcastToParticipants(instanceId, startMsg, Colors::MYTHIC_PLUS);
        
        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Started M+%u run for map %u (Instance %u). Participants: %zu",
                 keystoneLevel, mapId, instanceId, runData.participantGUIDs.size());
    }
    
    void MythicRunTracker::EndRun(Map* map, bool success)
    {
        if (!map)
            return;
        
        uint32 instanceId = map->GetInstanceId();
        MythicRunData* runData = GetRunData(instanceId);
        
        if (!runData || runData->state != RUN_STATE_IN_PROGRESS)
            return;
        
        runData->endTime = time(nullptr);
        runData->state = success ? RUN_STATE_COMPLETED : RUN_STATE_FAILED;
        
        if (success)
        {
            // Calculate keystone upgrade
            int8 upgradeLevel = CalculateKeystoneUpgrade(instanceId);
            
            // Award rewards
            AwardCompletionRewards(map, upgradeLevel);
            
            // Broadcast completion message
            uint32 elapsedTime = GetElapsedTime(instanceId);
            uint32 minutes = elapsedTime / 60;
            uint32 seconds = elapsedTime % 60;
            
            std::string completeMsg = sDungeonEnhancementMgr->GetColoredMessage(
                Colors::SUCCESS,
                "Run Completed! Time: %um %us | Deaths: %u/%u | Keystone: %s%d",
                minutes, seconds,
                runData->totalDeaths, MAX_DEATHS_BEFORE_PENALTY,
                (upgradeLevel > 0 ? "+" : (upgradeLevel < 0 ? "" : "")),
                upgradeLevel
            );
            BroadcastToParticipants(instanceId, completeMsg, Colors::SUCCESS);
            
            LOG_INFO(LogCategory::MYTHIC_PLUS, 
                     "Run completed for instance %u. Time: %um %us, Deaths: %u, Upgrade: %d",
                     instanceId, minutes, seconds, runData->totalDeaths, upgradeLevel);
        }
        else
        {
            HandleRunFailure(map);
        }
        
        // Cleanup affix handlers when run ends
        sAffixFactory->CleanupInstanceHandlers(instanceId);
        
        // Clean up after 5 minutes
        // Note: In production, schedule this cleanup instead of immediate removal
        // RemoveRunData(instanceId);
    }
    
    void MythicRunTracker::AbandonRun(Map* map)
    {
        if (!map)
            return;
        
        uint32 instanceId = map->GetInstanceId();
        MythicRunData* runData = GetRunData(instanceId);
        
        if (!runData || runData->state != RUN_STATE_IN_PROGRESS)
            return;
        
        runData->state = RUN_STATE_ABANDONED;
        
        // Broadcast abandonment message
        std::string abandonMsg = sDungeonEnhancementMgr->GetColoredMessage(
            Colors::ERROR,
            "Run Abandoned. Keystone destroyed."
        );
        BroadcastToParticipants(instanceId, abandonMsg, Colors::ERROR);
        
        // Destroy keystone
        Player* keystoneOwner = GetPlayerByGUID(runData->keystoneOwnerGUID);
        if (keystoneOwner)
        {
            sDungeonEnhancementMgr->RemovePlayerKeystone(keystoneOwner);
        }
        
        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Run abandoned for instance %u", instanceId);
        
        // Cleanup affix handlers
        sAffixFactory->CleanupInstanceHandlers(instanceId);
        
        RemoveRunData(instanceId);
    }
    
    MythicRunData* MythicRunTracker::GetRunData(uint32 instanceId)
    {
        auto itr = _activeRuns.find(instanceId);
        return (itr != _activeRuns.end()) ? &itr->second : nullptr;
    }
    
    bool MythicRunTracker::IsRunActive(uint32 instanceId)
    {
        MythicRunData* runData = GetRunData(instanceId);
        return runData && runData->state == RUN_STATE_IN_PROGRESS;
    }
    
    // ========================================================================
    // DEATH TRACKING
    // ========================================================================
    
    void MythicRunTracker::OnPlayerDeath(Player* player, Map* map)
    {
        if (!player || !map)
            return;
        
        uint32 instanceId = map->GetInstanceId();
        MythicRunData* runData = GetRunData(instanceId);
        
        if (!runData || runData->state != RUN_STATE_IN_PROGRESS)
            return;
        
        ObjectGuid playerGUID = player->GetGUID();
        
        // Increment death counters
        runData->totalDeaths++;
        runData->playerDeaths[playerGUID]++;
        
        // Broadcast death notification
        uint8 remaining = (runData->totalDeaths < MAX_DEATHS_BEFORE_PENALTY) 
                          ? (MAX_DEATHS_BEFORE_PENALTY - runData->totalDeaths) 
                          : 0;
        
        std::string deathMsg = sDungeonEnhancementMgr->GetColoredMessage(
            Colors::WARNING,
            "%s died. Deaths: %u/%u (Remaining: %u)",
            player->GetName().c_str(),
            runData->totalDeaths,
            MAX_DEATHS_BEFORE_PENALTY,
            remaining
        );
        BroadcastToParticipants(instanceId, deathMsg, Colors::WARNING);
        
        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Player %s died in instance %u. Total deaths: %u (penalty at %u)",
                 player->GetName().c_str(), instanceId, runData->totalDeaths, MAX_DEATHS_BEFORE_PENALTY);
        
        // Note: Deaths DO NOT auto-fail the run
        // Group can continue with 50% reward penalty at 15+ deaths
    }
    
    uint8 MythicRunTracker::GetTotalDeaths(uint32 instanceId)
    {
        MythicRunData* runData = GetRunData(instanceId);
        return runData ? runData->totalDeaths : 0;
    }
    
    uint8 MythicRunTracker::GetPlayerDeaths(uint32 instanceId, ObjectGuid playerGUID)
    {
        MythicRunData* runData = GetRunData(instanceId);
        if (!runData)
            return 0;
        
        auto itr = runData->playerDeaths.find(playerGUID);
        return (itr != runData->playerDeaths.end()) ? itr->second : 0;
    }
    
    bool MythicRunTracker::IsDeathLimitReached(uint32 instanceId)
    {
        return GetTotalDeaths(instanceId) >= MAX_DEATHS_BEFORE_PENALTY;
    }
    
    // ========================================================================
    // BOSS TRACKING
    // ========================================================================
    
    void MythicRunTracker::OnBossKilled(Map* map, uint32 bossEntry)
    {
        if (!map)
            return;
        
        uint32 instanceId = map->GetInstanceId();
        MythicRunData* runData = GetRunData(instanceId);
        
        if (!runData || runData->state != RUN_STATE_IN_PROGRESS)
            return;
        
        // Check if boss already killed
        if (runData->killedBossEntries.find(bossEntry) != runData->killedBossEntries.end())
            return;
        
        // Record boss kill
        runData->killedBossEntries.insert(bossEntry);
        runData->bossesKilled++;
        
        // Broadcast boss kill notification
        std::string bossMsg = sDungeonEnhancementMgr->GetColoredMessage(
            Colors::SUCCESS,
            "Boss Defeated! Progress: %u/%u",
            runData->bossesKilled,
            runData->requiredBosses
        );
        BroadcastToParticipants(instanceId, bossMsg, Colors::SUCCESS);
        
        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Boss %u killed in instance %u. Progress: %u/%u",
                 bossEntry, instanceId, runData->bossesKilled, runData->requiredBosses);
        
        // Check if all bosses killed
        if (AreAllBossesKilled(instanceId))
        {
            EndRun(map, true);
        }
    }
    
    bool MythicRunTracker::AreAllBossesKilled(uint32 instanceId)
    {
        MythicRunData* runData = GetRunData(instanceId);
        return runData && (runData->bossesKilled >= runData->requiredBosses);
    }
    
    uint8 MythicRunTracker::GetBossesKilled(uint32 instanceId)
    {
        MythicRunData* runData = GetRunData(instanceId);
        return runData ? runData->bossesKilled : 0;
    }
    
    // ========================================================================
    // TIMER TRACKING
    // ========================================================================
    
    uint32 MythicRunTracker::GetElapsedTime(uint32 instanceId)
    {
        MythicRunData* runData = GetRunData(instanceId);
        if (!runData || runData->startTime == 0)
            return 0;
        
        uint32 currentTime = (runData->endTime > 0) ? runData->endTime : time(nullptr);
        return currentTime - runData->startTime;
    }
    
    uint32 MythicRunTracker::GetRemainingTime(uint32 instanceId)
    {
        MythicRunData* runData = GetRunData(instanceId);
        if (!runData)
            return 0;
        
        uint32 elapsed = GetElapsedTime(instanceId);
        return (elapsed < runData->timerLimitSeconds) 
               ? (runData->timerLimitSeconds - elapsed) 
               : 0;
    }
    
    bool MythicRunTracker::IsTimerExpired(uint32 instanceId)
    {
        return GetRemainingTime(instanceId) == 0;
    }
    
    uint32 MythicRunTracker::GetTimerLimit(uint16 mapId)
    {
        // Default timer: 30 minutes
        uint32 defaultTimer = 30 * 60;
        
        // Get dungeon-specific timer from config (if available)
        DungeonConfig* config = sDungeonEnhancementMgr->GetDungeonConfig(mapId);
        if (config)
        {
            // TODO: Add timerLimitSeconds field to DungeonConfig
            // For now, use default
        }
        
        return defaultTimer;
    }
    
    // ========================================================================
    // COMPLETION HANDLING
    // ========================================================================
    
    int8 MythicRunTracker::CalculateKeystoneUpgrade(uint32 instanceId)
    {
        MythicRunData* runData = GetRunData(instanceId);
        if (!runData)
            return -1;
        
        uint8 deaths = runData->totalDeaths;
        
        // Keystone upgrade tiers based on deaths
        if (deaths <= DEATH_TIER_1_MAX)
            return DEATH_TIER_1_UPGRADE;  // 0-5 deaths: +2 levels
        else if (deaths <= DEATH_TIER_2_MAX)
            return DEATH_TIER_2_UPGRADE;  // 6-10 deaths: +1 level
        else if (deaths < MAX_DEATHS_BEFORE_PENALTY)
            return DEATH_TIER_3_UPGRADE;  // 11-14 deaths: same level (0)
        else
            return -1;  // 15+ deaths: destroy keystone
    }
    
    void MythicRunTracker::AwardCompletionRewards(Map* map, int8 upgradeLevel)
    {
        if (!map)
            return;
        
        uint32 instanceId = map->GetInstanceId();
        MythicRunData* runData = GetRunData(instanceId);
        
        if (!runData)
            return;
        
        // Award tokens to all participants
        bool deathPenalty = (runData->totalDeaths >= MAX_DEATHS_BEFORE_PENALTY);
        
        for (ObjectGuid participantGUID : runData->participantGUIDs)
        {
            Player* player = GetPlayerByGUID(participantGUID);
            if (!player)
                continue;
            
            // Award dungeon tokens
            sDungeonEnhancementMgr->AwardDungeonTokens(player, runData->mapId, runData->keystoneLevel, deathPenalty);
            
            // Update vault progress
            sDungeonEnhancementMgr->IncrementPlayerVaultProgress(player, runData->keystoneLevel);
            
            // Update rating
            uint32 completionTime = static_cast<uint32>(runData->endTime - runData->startTime);
            uint32 ratingGain = sDungeonEnhancementMgr->CalculateRatingGain(runData->keystoneLevel, runData->totalDeaths, completionTime);
            uint32 currentRating = sDungeonEnhancementMgr->GetPlayerRating(player);
            sDungeonEnhancementMgr->UpdatePlayerRating(player, 0, currentRating + ratingGain);
            
            // Save run to history
            SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
            if (season)
            {
                uint16 tokensAwarded = sDungeonEnhancementMgr->GetDungeonTokenReward(runData->mapId, runData->keystoneLevel, deathPenalty);
                
                CharacterDatabase.Execute(
                    "INSERT INTO dc_mythic_run_history (seasonId, playerGUID, mapId, keystoneLevel, completionTime, deaths, success, tokensAwarded) "
                    "VALUES ({}, {}, {}, {}, {}, {}, 1, {})",
                    season->seasonId,
                    participantGUID.GetCounter(),
                    runData->mapId,
                    runData->keystoneLevel,
                    completionTime,
                    runData->totalDeaths,
                    tokensAwarded
                );
            }
        }
        
        // Upgrade keystone for owner
        Player* keystoneOwner = GetPlayerByGUID(runData->keystoneOwnerGUID);
        if (keystoneOwner)
        {
            if (upgradeLevel > 0)
            {
                for (int8 i = 0; i < upgradeLevel; i++)
                {
                    sDungeonEnhancementMgr->UpgradePlayerKeystone(keystoneOwner);
                }
            }
            else if (upgradeLevel < 0)
            {
                sDungeonEnhancementMgr->RemovePlayerKeystone(keystoneOwner);
            }
            // upgradeLevel == 0: no change to keystone
        }
        
        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Awarded completion rewards for instance %u. Upgrade: %d, Participants: %zu",
                 instanceId, upgradeLevel, runData->participantGUIDs.size());
    }
    
    void MythicRunTracker::HandleRunFailure(Map* map)
    {
        if (!map)
            return;
        
        uint32 instanceId = map->GetInstanceId();
        MythicRunData* runData = GetRunData(instanceId);
        
        if (!runData)
            return;
        
        // Broadcast failure message
        std::string failMsg = sDungeonEnhancementMgr->GetColoredMessage(
            Colors::ERROR,
            "Run Failed! Death limit reached (%u/%u). Keystone destroyed.",
            runData->totalDeaths,
            MAX_DEATHS_BEFORE_PENALTY
        );
        BroadcastToParticipants(instanceId, failMsg, Colors::ERROR);
        
        // Award tokens with 50% penalty
        AwardCompletionRewards(map, -1);
        
        // Destroy keystone
        Player* keystoneOwner = GetPlayerByGUID(runData->keystoneOwnerGUID);
        if (keystoneOwner)
        {
            sDungeonEnhancementMgr->RemovePlayerKeystone(keystoneOwner);
        }
        
        // Update run state
        runData->state = RUN_STATE_FAILED;
        runData->endTime = time(nullptr);
        
        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Run failed for instance %u. Deaths: %u/%u",
                 instanceId, runData->totalDeaths, MAX_DEATHS_BEFORE_PENALTY);
    }
    
    // ========================================================================
    // GROUP UTILITIES
    // ========================================================================
    
    void MythicRunTracker::AddParticipant(uint32 instanceId, ObjectGuid playerGUID)
    {
        MythicRunData* runData = GetRunData(instanceId);
        if (!runData)
            return;
        
        runData->participantGUIDs.insert(playerGUID);
        runData->playerDeaths[playerGUID] = 0;
    }
    
    void MythicRunTracker::RemoveParticipant(uint32 instanceId, ObjectGuid playerGUID)
    {
        MythicRunData* runData = GetRunData(instanceId);
        if (!runData)
            return;
        
        runData->participantGUIDs.erase(playerGUID);
        // Note: Keep death count for historical data
    }
    
    std::unordered_set<ObjectGuid> MythicRunTracker::GetParticipants(uint32 instanceId)
    {
        MythicRunData* runData = GetRunData(instanceId);
        return runData ? runData->participantGUIDs : std::unordered_set<ObjectGuid>();
    }
    
    // ========================================================================
    // CLEANUP
    // ========================================================================
    
    void MythicRunTracker::CleanupOldRuns(uint32 maxAgeMinutes)
    {
        uint32 currentTime = time(nullptr);
        uint32 maxAgeSeconds = maxAgeMinutes * 60;
        
        std::vector<uint32> toRemove;
        
        for (auto& [instanceId, runData] : _activeRuns)
        {
            // Skip active runs
            if (runData.state == RUN_STATE_IN_PROGRESS)
                continue;
            
            // Check if old enough to remove
            uint32 endTime = (runData.endTime > 0) ? runData.endTime : runData.startTime;
            if (currentTime - endTime >= maxAgeSeconds)
            {
                toRemove.push_back(instanceId);
            }
        }
        
        // Remove old runs
        for (uint32 instanceId : toRemove)
        {
            RemoveRunData(instanceId);
        }
        
        if (!toRemove.empty())
        {
            LOG_INFO(LogCategory::MYTHIC_PLUS, 
                     "Cleaned up %zu old run(s)", toRemove.size());
        }
    }
    
    void MythicRunTracker::RemoveRunData(uint32 instanceId)
    {
        _activeRuns.erase(instanceId);
    }
    
    // ========================================================================
    // HELPER FUNCTIONS
    // ========================================================================
    
    void MythicRunTracker::BroadcastToParticipants(uint32 instanceId, const std::string& message, uint32 color)
    {
        MythicRunData* runData = GetRunData(instanceId);
        if (!runData)
            return;
        
        for (ObjectGuid participantGUID : runData->participantGUIDs)
        {
            Player* player = GetPlayerByGUID(participantGUID);
            if (player)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("%s", message.c_str());
            }
        }
    }
    
    Player* MythicRunTracker::GetPlayerByGUID(ObjectGuid guid)
    {
        return ObjectAccessor::FindPlayer(guid);
    }

} // namespace DungeonEnhancement
