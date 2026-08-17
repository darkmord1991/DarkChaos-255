/*
 * DarkChaos Cross-System Manager
 *
 * Fan-out point between AzerothCore's gameplay hooks and the DC systems that
 * care about them. CrossSystemScripts.cpp feeds it engine events; it updates
 * the player's session context and republishes onto the EventBus, whose only
 * subscriber is the addon protocol bridge that forwards events to clients.
 *
 * NOT a plugin registry. It used to advertise one - RegisterSystem() and the
 * accessors built on it - but nothing ever registered, so systems_ was
 * permanently empty and every one of those accessors was inert. The registry,
 * the SystemInfo struct and the four never-instantiated adapters in
 * CrossSystemAdapters.h were removed (Aug 2026). If a real registry is needed
 * later, build it against actual subscribers rather than restoring this one.
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

class Player;
class Creature;
class Map;
class WorldSession;

namespace DarkChaos
{
namespace CrossSystem
{
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

        // Global enable/disable
        void SetEnabled(bool enabled) { globalEnabled_ = enabled; }
        bool IsEnabled() const { return globalEnabled_; }

    private:
        CrossSystemManager() : eventBus_(nullptr), rewardDistributor_(nullptr), sessionManager_(nullptr) {}

        // Subsystems (use singletons via pointers)
        EventBus* eventBus_;
        RewardDistributor* rewardDistributor_;
        SessionManager* sessionManager_;

        // State
        bool initialized_ = false;
        bool globalEnabled_ = true;

        // Update tracking
        uint32 saveTimer_ = 0;
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
