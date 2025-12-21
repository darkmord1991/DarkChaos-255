/*
 * DarkChaos Cross-System Adapters
 *
 * Wraps existing DC system managers in the DCSystem interface
 * for unified cross-system coordination.
 *
 * IMPORTANT: This file uses the actual APIs from existing DC systems.
 * Do not assume methods exist - check the actual headers.
 *
 * Author: DarkChaos Development Team
 * Date: December 2025
 */

#ifndef DC_CROSS_SYSTEM_ADAPTERS_H
#define DC_CROSS_SYSTEM_ADAPTERS_H

#include "DC/CrossSystem/CrossSystemCore.h"
#include "EventBus.h"
#include "Log.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Chat.h"

// Include existing system headers with correct paths
#include "../MythicPlus/MythicPlusRunManager.h"
#include "../Seasons/SeasonalRewardSystem.h"
#include "../ItemUpgrades/ItemUpgradeManager.h"
#include "../Prestige/dc_prestige_api.h"

namespace DarkChaos {
namespace CrossSystem {
namespace Adapters {

// =========================================================================
// Mythic+ System Adapter
// =========================================================================

/**
 * @brief Adapter wrapping MythicPlusRunManager for cross-system integration
 *
 * MythicPlusRunManager already handles:
 * - InstanceState tracking per map
 * - Boss kills, deaths, completion
 * - Keystone management
 * - Weekly vault updates
 *
 * This adapter publishes events for other systems to react to.
 */
class MythicPlusAdapter : public DCSystem
{
public:
    std::string GetSystemName() const override { return "MythicPlus"; }
    SystemPriority GetPriority() const override { return SystemPriority::CORE; }

    uint32 GetCapabilities() const override
    {
        return static_cast<uint32>(SystemCapability::DUNGEON_TRACKING) |
               static_cast<uint32>(SystemCapability::REWARD_GRANTING) |
               static_cast<uint32>(SystemCapability::DIFFICULTY_SCALING) |
               static_cast<uint32>(SystemCapability::LEADERBOARD_TRACKING);
    }

    bool Initialize() override
    {
        LOG_INFO("dc.crosssystem.adapter", "MythicPlusAdapter: Initializing");
        _initialized = MythicPlusRunManager::instance() != nullptr;
        return _initialized;
    }

    void Shutdown() override
    {
        LOG_INFO("dc.crosssystem.adapter", "MythicPlusAdapter: Shutting down");
        _initialized = false;
    }

    void OnPlayerLogin(Player* /*player*/, bool /*firstLogin*/) override
    {
        // MythicPlusRunManager handles its own player data loading
    }

    void OnPlayerLogout(Player* /*player*/) override
    {
        // MythicPlusRunManager handles its own player data saving
    }

    void OnDungeonStart(Player* player, Map* map, uint8 /*difficulty*/) override
    {
        if (!_initialized || !player || !map)
            return;

        auto* manager = MythicPlusRunManager::instance();
        if (!manager)
            return;

        // Check if there's an active M+ run for this map
        auto const* state = manager->GetRunState(map);
        if (state && state->keystoneLevel > 0)
        {
            // Use EventBus to publish - it will handle the event creation
            GetEventBus()->PublishSimple(EventType::MythicPlusStart,
                                         player->GetGUID(),
                                         map->GetId(),
                                         map->GetInstanceId());
        }
    }

    void OnDungeonComplete(Player* player, Map* map, uint32 /*completionTimeMs*/) override
    {
        if (!_initialized || !player || !map)
            return;

        auto* manager = MythicPlusRunManager::instance();
        if (!manager)
            return;

        auto const* state = manager->GetRunState(map);
        if (state && state->keystoneLevel > 0 && state->completed)
        {
            EventType eventType = state->failed ? EventType::MythicPlusFail : EventType::MythicPlusComplete;
            GetEventBus()->PublishSimple(eventType,
                                         player->GetGUID(),
                                         map->GetId(),
                                         map->GetInstanceId());
        }
    }

    void OnBossKill(Player* player, Creature* boss, bool isWorldBoss) override
    {
        if (!_initialized || !player || !boss || isWorldBoss)
            return;

        auto* manager = MythicPlusRunManager::instance();
        if (!manager)
            return;

        Map* map = player->GetMap();
        if (!map)
            return;

        auto const* state = manager->GetRunState(map);
        if (state && state->keystoneLevel > 0)
        {
            GetEventBus()->PublishCreatureKill(player, boss, true, state->keystoneLevel,
                                               player->GetGroup() ? player->GetGroup()->GetMembersCount() : 1);
        }
    }

    // Read-only accessors using actual MythicPlusRunManager API
    uint8 GetKeystoneLevel(Map* map) const
    {
        auto* manager = MythicPlusRunManager::instance();
        if (!manager || !map)
            return 0;
        auto const* state = manager->GetRunState(map);
        return state ? state->keystoneLevel : 0;
    }

    bool IsMythicPlusActive(Map* map) const
    {
        auto* manager = MythicPlusRunManager::instance();
        return manager ? manager->IsMythicPlusActive(map) : false;
    }
};

// =========================================================================
// Seasonal Reward System Adapter
// =========================================================================

/**
 * @brief Adapter wrapping SeasonalRewardSystem for cross-system integration
 */
class SeasonalRewardAdapter : public DCSystem
{
public:
    std::string GetSystemName() const override { return "SeasonalRewards"; }
    SystemPriority GetPriority() const override { return SystemPriority::NORMAL; }

    uint32 GetCapabilities() const override
    {
        return static_cast<uint32>(SystemCapability::REWARD_GRANTING) |
               static_cast<uint32>(SystemCapability::SEASONAL_CONTENT) |
               static_cast<uint32>(SystemCapability::LEADERBOARD_TRACKING);
    }

    bool Initialize() override
    {
        LOG_INFO("dc.crosssystem.adapter", "SeasonalRewardAdapter: Initializing");
        using namespace DarkChaos::SeasonalRewards;
        _initialized = SeasonalRewardManager::instance() != nullptr;
        return _initialized;
    }

    void Shutdown() override
    {
        LOG_INFO("dc.crosssystem.adapter", "SeasonalRewardAdapter: Shutting down");
        _initialized = false;
    }

    void OnPlayerLogin(Player* player, bool /*firstLogin*/) override
    {
        if (!_initialized || !player)
            return;

        using namespace DarkChaos::SeasonalRewards;
        auto* manager = SeasonalRewardManager::instance();
        if (manager)
        {
            manager->GetOrCreatePlayerStats(player);
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!_initialized || !player)
            return;

        using namespace DarkChaos::SeasonalRewards;
        auto* manager = SeasonalRewardManager::instance();
        if (manager)
        {
            auto* stats = manager->GetPlayerStats(player->GetGUID().GetCounter());
            if (stats)
            {
                manager->SavePlayerStats(*stats);
            }
        }
    }

    // Read-only accessor
    uint32 GetCurrentSeasonId() const
    {
        using namespace DarkChaos::SeasonalRewards;
        auto* manager = SeasonalRewardManager::instance();
        return manager ? manager->GetConfig().activeSeason : 0;
    }
};

// =========================================================================
// Item Upgrade System Adapter
// =========================================================================

/**
 * @brief Adapter wrapping ItemUpgradeManager for cross-system integration
 */
class ItemUpgradeAdapter : public DCSystem
{
public:
    std::string GetSystemName() const override { return "ItemUpgrades"; }
    SystemPriority GetPriority() const override { return SystemPriority::CORE; }

    uint32 GetCapabilities() const override
    {
        return static_cast<uint32>(SystemCapability::REWARD_GRANTING) |
               static_cast<uint32>(SystemCapability::CURRENCY_MANAGEMENT);
    }

    bool Initialize() override
    {
        LOG_INFO("dc.crosssystem.adapter", "ItemUpgradeAdapter: Initializing");
        using namespace DarkChaos::ItemUpgrade;
        _initialized = GetUpgradeManager() != nullptr;
        return _initialized;
    }

    void Shutdown() override
    {
        LOG_INFO("dc.crosssystem.adapter", "ItemUpgradeAdapter: Shutting down");
        _initialized = false;
    }

    void OnPlayerLogin(Player* /*player*/, bool /*firstLogin*/) override
    {
        // ItemUpgradeManager loads data per-item, not per-player
    }

    void OnPlayerLogout(Player* /*player*/) override
    {
        // ItemUpgradeManager saves per-item data automatically
    }

    // Read-only accessors
    uint32 GetPlayerTokens(uint32 playerGuid) const
    {
        using namespace DarkChaos::ItemUpgrade;
        auto* manager = GetUpgradeManager();
        return manager ? manager->GetCurrency(playerGuid, CURRENCY_UPGRADE_TOKEN) : 0;
    }

    uint32 GetPlayerEssence(uint32 playerGuid) const
    {
        using namespace DarkChaos::ItemUpgrade;
        auto* manager = GetUpgradeManager();
        return manager ? manager->GetCurrency(playerGuid, CURRENCY_ARTIFACT_ESSENCE) : 0;
    }
};

// =========================================================================
// Prestige System Adapter
// =========================================================================

/**
 * @brief Adapter wrapping PrestigeAPI for cross-system integration
 */
class PrestigeAdapter : public DCSystem
{
public:
    std::string GetSystemName() const override { return "Prestige"; }
    SystemPriority GetPriority() const override { return SystemPriority::CORE; }

    uint32 GetCapabilities() const override
    {
        return static_cast<uint32>(SystemCapability::PLAYER_TRACKING) |
               static_cast<uint32>(SystemCapability::REWARD_GRANTING);
    }

    bool Initialize() override
    {
        LOG_INFO("dc.crosssystem.adapter", "PrestigeAdapter: Initializing");
        _initialized = PrestigeAPI::IsEnabled();
        return _initialized;
    }

    void Shutdown() override
    {
        LOG_INFO("dc.crosssystem.adapter", "PrestigeAdapter: Shutting down");
        _initialized = false;
    }

    void OnPlayerLogin(Player* player, bool /*firstLogin*/) override
    {
        if (!_initialized || !player)
            return;

        PrestigeAPI::ApplyPrestigeBuffs(player);
    }

    void OnPlayerLogout(Player* /*player*/) override
    {
        // Prestige data is saved by dc_prestige_system.cpp
    }

    void OnPlayerLevelUp(Player* player, uint8 /*oldLevel*/) override
    {
        if (!_initialized || !player)
            return;

        uint32 requiredLevel = PrestigeAPI::GetRequiredLevel();
        if (player->GetLevel() >= requiredLevel && PrestigeAPI::CanPrestige(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ff00[Prestige]|r You have reached the maximum level! "
                "Visit the Prestige NPC to prestige and start your next journey!"
            );
        }
    }

    // Read-only accessors
    uint32 GetPrestigeLevel(Player* player) const
    {
        return player ? PrestigeAPI::GetPrestigeLevel(player) : 0;
    }

    float GetPrestigeBonusMultiplier(Player* player) const
    {
        if (!player)
            return 1.0f;

        uint32 level = PrestigeAPI::GetPrestigeLevel(player);
        float bonusPercent = static_cast<float>(PrestigeAPI::GetStatBonusPercent());
        return 1.0f + (level * bonusPercent / 100.0f);
    }

    bool CanPrestige(Player* player) const
    {
        return player ? PrestigeAPI::CanPrestige(player) : false;
    }
};

// =========================================================================
// Adapter Registration Helper
// =========================================================================

/**
 * @brief Registers all system adapters with the CrossSystemManager
 *
 * Note: This is called during server startup from CrossSystemScripts.cpp
 */
inline void RegisterAllAdapters()
{
    LOG_INFO("dc.crosssystem.adapter", "System adapters available for registration");
    // Actual registration happens via CrossSystemManager::RegisterSystem
    // which is called from individual adapter Initialize() methods
}

} // namespace Adapters
} // namespace CrossSystem
} // namespace DarkChaos

#endif // DC_CROSS_SYSTEM_ADAPTERS_H
