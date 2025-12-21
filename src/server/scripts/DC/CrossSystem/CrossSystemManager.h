/*
 * DarkChaos Cross-System Manager
 *
 * Central coordinator for all DC custom systems. Provides:
 * - System registration and lifecycle management
 * - Cross-system integration hooks
 * - Unified API access to all DC subsystems
 * - World script hooks for player events
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#pragma once

#include "DC/CrossSystem/CrossSystemCore.h"
#include "EventBus.h"
#include "RewardDistributor.h"
#include "SessionContext.h"
#include <memory>
#include <unordered_map>

class Player;
class Creature;
class Map;
class WorldSession;

namespace DarkChaos
{
namespace CrossSystem
{
    // =========================================================================
    // System Registration Info
    // =========================================================================

    struct SystemInfo
    {
        SystemId id = SystemId::None;
        std::string name;
        std::string version;
        bool enabled = true;
        bool initialized = false;
        IEventHandler* handler = nullptr;

        // System capabilities
        bool providesRewards = false;
        bool tracksProgression = false;
        bool hasWeeklyContent = false;
        bool hasSeasonalContent = false;
    };

    // =========================================================================
    // Cross-System Manager
    // =========================================================================

    class CrossSystemManager
    {
    public:
        static CrossSystemManager* instance();

        // =====================================================================
        // Initialization
        // =====================================================================

        void Initialize();
        void Shutdown();
        bool IsInitialized() const { return initialized_; }

        // =====================================================================
        // System Registration
        // =====================================================================

        void RegisterSystem(const SystemInfo& info);
        void UnregisterSystem(SystemId id);

        bool IsSystemEnabled(SystemId id) const;
        void SetSystemEnabled(SystemId id, bool enabled);

        const SystemInfo* GetSystemInfo(SystemId id) const;
        std::vector<SystemInfo> GetAllSystems() const;
        std::vector<SystemId> GetEnabledSystems() const;

        // =====================================================================
        // Subsystem Access
        // =====================================================================

        SessionManager* GetSessionManager() { return sessionManager_; }
        EventBus* GetEventBus() { return eventBus_; }
        RewardDistributor* GetRewardDistributor() { return rewardDistributor_; }

        // =====================================================================
        // Player Session Hooks (called from WorldScript)
        // =====================================================================

        void OnPlayerLogin(Player* player, bool firstLogin);
        void OnPlayerLogout(Player* player);
        void OnPlayerLevelChanged(Player* player, uint8 oldLevel, uint8 newLevel);
        void OnPlayerDeath(Player* player, Player* killer);

        // =====================================================================
        // Content Hooks
        // =====================================================================

        void OnPlayerEnterMap(Player* player, Map* map);
        void OnPlayerLeaveMap(Player* player, Map* map);
        void OnPlayerEnterDungeon(Player* player, Map* map, Difficulty difficulty);
        void OnPlayerLeaveDungeon(Player* player, Map* map);

        // =====================================================================
        // Combat Hooks
        // =====================================================================

        void OnCreatureKilled(Player* player, Creature* creature);
        void OnBossKilled(Player* player, Creature* boss, bool isRaidBoss = false);

        // =====================================================================
        // Quest Hooks
        // =====================================================================

        void OnQuestComplete(Player* player, uint32 questId);
        void OnDailyQuestComplete(Player* player, uint32 questId);
        void OnWeeklyQuestComplete(Player* player, uint32 questId);

        // =====================================================================
        // Item Hooks
        // =====================================================================

        void OnItemUpgrade(Player* player, uint32 itemGuid, uint8 fromLevel, uint8 toLevel);

        // =====================================================================
        // Periodic Update
        // =====================================================================

        void Update(uint32 diff);
        void OnWorldUpdate(uint32 diff);

        // =====================================================================
        // Weekly/Seasonal
        // =====================================================================

        void OnWeeklyReset();
        void OnSeasonStart(uint32 seasonId);
        void OnSeasonEnd(uint32 seasonId);

        // =====================================================================
        // Configuration
        // =====================================================================

        void LoadConfiguration();
        void ReloadConfiguration();
        void SaveConfiguration();

        // =====================================================================
        // Debug/Admin
        // =====================================================================

        std::string GetStatusReport() const;
        std::string GetPlayerReport(Player* player) const;
        void DumpDebugInfo() const;

        // Global enable/disable
        void SetEnabled(bool enabled) { globalEnabled_ = enabled; }
        bool IsEnabled() const { return globalEnabled_; }

    private:
        CrossSystemManager() : eventBus_(nullptr), rewardDistributor_(nullptr), sessionManager_(nullptr) {}

        // Initialize subsystems
        void InitializeEventBus();
        void InitializeRewardDistributor();
        void RegisterDefaultHandlers();

        // Systems
        std::unordered_map<SystemId, SystemInfo> systems_;

        // Subsystems (use singletons via pointers)
        EventBus* eventBus_;
        RewardDistributor* rewardDistributor_;
        SessionManager* sessionManager_;

        // State
        bool initialized_ = false;
        bool globalEnabled_ = true;

        // Update tracking
        uint32 updateTimer_ = 0;
        uint32 saveTimer_ = 0;

        mutable std::mutex mutex_;
    };

    // =========================================================================
    // Global Access
    // =========================================================================

    inline CrossSystemManager* GetManager()
    {
        return CrossSystemManager::instance();
    }

} // namespace CrossSystem
} // namespace DarkChaos

// Convenience macros for common operations
#define DC_CROSS_SYSTEM DarkChaos::CrossSystem::GetManager()
#define DC_EVENT_BUS DarkChaos::CrossSystem::GetEventBus()
#define DC_REWARDS DarkChaos::CrossSystem::GetRewardDistributor()
#define DC_SESSION(player) DarkChaos::CrossSystem::GetPlayerSession(player)
