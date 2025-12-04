/*
 * DarkChaos Cross-System Session Context Implementation
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#include "SessionContext.h"
#include "CrossSystemManager.h"
#include "Log.h"
#include "Player.h"
#include "Timer.h"

namespace DarkChaos
{
namespace CrossSystem
{
    // =========================================================================
    // SessionContext Implementation
    // =========================================================================
    
    SessionContext::SessionContext(ObjectGuid playerGuid)
        : playerGuid_(playerGuid)
        , sessionStartTime_(GameTime::GetGameTime())
    {
        // Initialize all systems as potentially active
        // Specific systems will enable/disable based on their state
    }
    
    SessionContext::~SessionContext() = default;
    
    uint64 SessionContext::GetSessionDuration() const
    {
        return GameTime::GetGameTime() - sessionStartTime_;
    }
    
    // =========================================================================
    // Active Content State
    // =========================================================================
    
    void SessionContext::SetActiveContent(ContentType type, ContentDifficulty difficulty,
                                          uint32 mapId, uint32 instanceId, uint8 keystoneLevel)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        activeContent_.type = type;
        activeContent_.difficulty = difficulty;
        activeContent_.mapId = mapId;
        activeContent_.instanceId = instanceId;
        activeContent_.keystoneLevel = keystoneLevel;
        activeContent_.enteredAt = GameTime::GetGameTime();
        
        isDirty_ = true;
        
        LOG_DEBUG("dc.crosssystem", "Session {} entered content: type={}, map={}, keystone={}",
                  playerGuid_.GetCounter(), static_cast<uint8>(type), mapId, keystoneLevel);
    }
    
    void SessionContext::ClearActiveContent()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        activeContent_.Reset();
        isDirty_ = true;
    }
    
    // =========================================================================
    // Run State
    // =========================================================================
    
    void SessionContext::StartRun(uint32 seasonId)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        activeContent_.isRunActive = true;
        activeContent_.runStartedAt = GameTime::GetGameTime();
        activeContent_.seasonId = seasonId;
        activeContent_.bossesKilled = 0;
        activeContent_.trashKilled = 0;
        activeContent_.deaths = 0;
        activeContent_.wipes = 0;
        
        isDirty_ = true;
    }
    
    void SessionContext::EndRun(bool success)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        activeContent_.isRunActive = false;
        
        if (success)
        {
            sessionStats_.dungeonsCompleted++;
            if (activeContent_.keystoneLevel > 0)
                sessionStats_.mplusCompleted++;
        }
        
        isDirty_ = true;
    }
    
    uint64 SessionContext::GetRunDuration() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        if (!activeContent_.isRunActive || activeContent_.runStartedAt == 0)
            return 0;
            
        return GameTime::GetGameTime() - activeContent_.runStartedAt;
    }
    
    void SessionContext::IncrementBossKills()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        activeContent_.bossesKilled++;
        sessionStats_.bossesKilled++;
        isDirty_ = true;
    }
    
    void SessionContext::IncrementTrashKills(uint32 count)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        activeContent_.trashKilled += count;
        sessionStats_.creaturesKilled += count;
        isDirty_ = true;
    }
    
    void SessionContext::IncrementDeaths()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        activeContent_.deaths++;
        sessionStats_.deaths++;
        isDirty_ = true;
    }
    
    void SessionContext::IncrementWipes()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        activeContent_.wipes++;
        isDirty_ = true;
    }
    
    // =========================================================================
    // Progression Snapshot
    // =========================================================================
    
    void SessionContext::RefreshProgression(Player* player)
    {
        if (!player)
            return;
            
        std::lock_guard<std::mutex> lock(mutex_);
        
        // Prestige data would come from PrestigeAPI
        // Seasonal data from SeasonalRewardManager
        // M+ data from MythicPlusRunManager
        // etc.
        
        // Calculate bonuses
        progression_.CalculateBonuses();
        
        isDirty_ = true;
    }
    
    void SessionContext::SetPrestigeLevel(uint8 level)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        progression_.prestigeLevel = level;
        progression_.CalculateBonuses();
        isDirty_ = true;
    }
    
    void SessionContext::SetSeasonalData(uint32 seasonId, uint32 tokens, uint32 essence, 
                                         uint32 weeklyTokens, uint32 weeklyEssence)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        progression_.currentSeasonId = seasonId;
        progression_.seasonalTokensEarned = tokens;
        progression_.seasonalEssenceEarned = essence;
        progression_.weeklyTokensEarned = weeklyTokens;
        progression_.weeklyEssenceEarned = weeklyEssence;
        
        isDirty_ = true;
    }
    
    void SessionContext::SetMythicPlusData(uint32 rating, uint8 highestKey, uint32 runsThisWeek)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        progression_.mythicPlusRating = rating;
        progression_.highestKeyCompleted = highestKey;
        progression_.mplusRunsThisWeek = runsThisWeek;
        
        isDirty_ = true;
    }
    
    // =========================================================================
    // Active Systems
    // =========================================================================
    
    void SessionContext::SetSystemActive(SystemId system, bool active)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        if (active)
            activeSystems_.insert(system);
        else
            activeSystems_.erase(system);
            
        isDirty_ = true;
    }
    
    bool SessionContext::IsSystemActive(SystemId system) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return activeSystems_.count(system) > 0;
    }
    
    std::vector<SystemId> SessionContext::GetActiveSystems() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return std::vector<SystemId>(activeSystems_.begin(), activeSystems_.end());
    }
    
    // =========================================================================
    // Pending Rewards
    // =========================================================================
    
    uint64 SessionContext::AddPendingReward(const PendingReward& reward)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        PendingReward r = reward;
        r.id = nextRewardId_++;
        r.createdAt = GameTime::GetGameTime();
        
        if (r.expiresAt == 0)
            r.expiresAt = r.createdAt + (7 * 24 * 60 * 60);  // Default 7 days
            
        pendingRewards_.push_back(r);
        isDirty_ = true;
        
        return r.id;
    }
    
    bool SessionContext::ClaimReward(uint64 rewardId)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        for (auto& reward : pendingRewards_)
        {
            if (reward.id == rewardId && !reward.claimed)
            {
                reward.claimed = true;
                isDirty_ = true;
                return true;
            }
        }
        
        return false;
    }
    
    void SessionContext::ExpireRewards()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        uint64 now = GameTime::GetGameTime();
        
        pendingRewards_.erase(
            std::remove_if(pendingRewards_.begin(), pendingRewards_.end(),
                [now](const PendingReward& r) {
                    return r.claimed || (r.expiresAt > 0 && now > r.expiresAt);
                }),
            pendingRewards_.end());
            
        isDirty_ = true;
    }
    
    std::vector<PendingReward> SessionContext::GetPendingRewards() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        std::vector<PendingReward> result;
        for (const auto& r : pendingRewards_)
        {
            if (!r.claimed)
                result.push_back(r);
        }
        return result;
    }
    
    std::vector<PendingReward> SessionContext::GetPendingRewardsForSystem(SystemId system) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        std::vector<PendingReward> result;
        for (const auto& r : pendingRewards_)
        {
            if (!r.claimed && r.sourceSystem == system)
                result.push_back(r);
        }
        return result;
    }
    
    // =========================================================================
    // Multiplier Calculations
    // =========================================================================
    
    float SessionContext::CalculateTokenMultiplier() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        float mult = 1.0f;
        
        // Prestige bonus
        mult *= progression_.prestigeBonus;
        
        // Content-specific bonuses would be applied elsewhere
        
        return mult;
    }
    
    float SessionContext::CalculateEssenceMultiplier() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        float mult = 1.0f;
        mult *= progression_.prestigeBonus;
        
        return mult;
    }
    
    float SessionContext::CalculateLootQualityBonus() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        float bonus = 0.0f;
        
        // M+ keystone level bonus
        if (activeContent_.keystoneLevel > 0)
            bonus += activeContent_.keystoneLevel * 0.02f;  // +2% per key level
            
        return bonus;
    }
    
    RewardContext SessionContext::BuildRewardContext(SystemId sourceSystem, EventType triggerEvent,
                                                     uint32 sourceId, const std::string& sourceName) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        RewardContext ctx;
        ctx.playerGuid = playerGuid_;
        ctx.sourceSystem = sourceSystem;
        ctx.triggerEvent = triggerEvent;
        ctx.contentType = activeContent_.type;
        ctx.difficulty = activeContent_.difficulty;
        ctx.mapId = activeContent_.mapId;
        ctx.instanceId = activeContent_.instanceId;
        ctx.sourceId = sourceId;
        ctx.sourceName = sourceName;
        ctx.keystoneLevel = activeContent_.keystoneLevel;
        ctx.prestigeLevel = progression_.prestigeLevel;
        ctx.seasonId = progression_.currentSeasonId;
        
        return ctx;
    }
    
    void SessionContext::IncrementSessionStat(const std::string& stat)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        if (stat == "quests")
            sessionStats_.questsCompleted++;
        else if (stat == "items_upgraded")
            sessionStats_.itemsUpgraded++;
            
        isDirty_ = true;
    }
    
    // =========================================================================
    // SessionManager Implementation
    // =========================================================================
    
    SessionManager* SessionManager::instance()
    {
        static SessionManager instance;
        return &instance;
    }
    
    SessionContext* SessionManager::GetSession(ObjectGuid guid)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        auto it = sessions_.find(guid.GetCounter());
        if (it != sessions_.end())
            return it->second.get();
            
        return nullptr;
    }
    
    SessionContext* SessionManager::GetSession(Player* player)
    {
        if (!player)
            return nullptr;
            
        return GetSession(player->GetGUID());
    }
    
    SessionContext* SessionManager::CreateSession(Player* player)
    {
        if (!player)
            return nullptr;
            
        std::lock_guard<std::mutex> lock(mutex_);
        
        ObjectGuid guid = player->GetGUID();
        auto& session = sessions_[guid.GetCounter()];
        
        if (!session)
        {
            session = std::make_unique<SessionContext>(guid);
            session->RefreshProgression(player);
            
            LOG_DEBUG("dc.crosssystem", "Created session for player {} ({})",
                      player->GetName(), guid.GetCounter());
        }
        
        return session.get();
    }
    
    void SessionManager::DestroySession(ObjectGuid guid)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        auto it = sessions_.find(guid.GetCounter());
        if (it != sessions_.end())
        {
            LOG_DEBUG("dc.crosssystem", "Destroyed session for player {}", guid.GetCounter());
            sessions_.erase(it);
        }
    }
    
    bool SessionManager::HasSession(ObjectGuid guid) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return sessions_.count(guid.GetCounter()) > 0;
    }
    
    void SessionManager::SaveDirtySessions()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        for (auto& [guid, session] : sessions_)
        {
            if (session && session->IsDirty())
            {
                // Persist session data if needed
                session->MarkClean();
            }
        }
    }
    
    void SessionManager::CleanupExpiredRewards()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        for (auto& [guid, session] : sessions_)
        {
            if (session)
                session->ExpireRewards();
        }
    }
    
    uint32 SessionManager::GetActiveSessionCount() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return static_cast<uint32>(sessions_.size());
    }

} // namespace CrossSystem
} // namespace DarkChaos
