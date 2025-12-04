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

#include "CrossSystemCore.h"
#include "CrossSystemManager.h"
#include "EventBus.h"
#include "Log.h"
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
        // MythicPlusRunManager is a singleton that's always available
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
        // No action needed here
    }
    
    void OnPlayerLogout(Player* /*player*/) override
    {
        // MythicPlusRunManager handles its own player data saving
        // No action needed here
    }
    
    void OnDungeonStart(Player* player, Map* map, uint8 difficulty) override
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
            // Publish event for other systems
            SystemEvent event(EventType::MYTHIC_PLUS_START);
            event.playerGuid = player->GetGUID().GetCounter();
            event.mapId = map->GetId();
            event.intParam1 = difficulty;
            event.intParam2 = state->keystoneLevel;
            
            GetEventBus()->Publish(event);
        }
    }
    
    void OnDungeonComplete(Player* player, Map* map, uint32 completionTimeMs) override
    {
        if (!_initialized || !player || !map)
            return;
            
        auto* manager = MythicPlusRunManager::instance();
        if (!manager)
            return;
            
        auto const* state = manager->GetRunState(map);
        if (state && state->keystoneLevel > 0 && state->completed)
        {
            // Publish completion event
            SystemEvent event(EventType::MYTHIC_PLUS_COMPLETE);
            event.playerGuid = player->GetGUID().GetCounter();
            event.mapId = map->GetId();
            event.intParam1 = state->keystoneLevel;
            event.intParam2 = !state->failed ? 1 : 0; // Success/fail
            event.floatParam1 = static_cast<float>(completionTimeMs) / 1000.0f;
            
            GetEventBus()->Publish(event);
        }
    }
    
    void OnBossKill(Player* player, Creature* boss, bool isWorldBoss) override
    {
        if (!_initialized || !player || !boss || isWorldBoss)
            return;
            
        // MythicPlusRunManager::HandleBossDeath is called directly by the script hooks
        // We just publish the cross-system event here
        auto* manager = MythicPlusRunManager::instance();
        if (!manager)
            return;
            
        Map* map = player->GetMap();
        if (!map)
            return;
            
        auto const* state = manager->GetRunState(map);
        if (state && state->keystoneLevel > 0)
        {
            SystemEvent event(EventType::BOSS_KILL);
            event.playerGuid = player->GetGUID().GetCounter();
            event.mapId = map->GetId();
            event.intParam1 = boss->GetEntry();
            event.intParam2 = state->keystoneLevel;
            event.stringParam = boss->GetName();
            
            GetEventBus()->Publish(event);
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
    
private:
    bool _initialized = false;
};

// =========================================================================
// Seasonal Reward System Adapter
// =========================================================================

/**
 * @brief Adapter wrapping SeasonalRewardSystem for cross-system integration
 *
 * SeasonalRewardManager handles:
 * - Token/Essence awarding via AwardTokens/AwardEssence
 * - Player stats via GetOrCreatePlayerStats
 * - Weekly caps and resets
 *
 * This adapter subscribes to cross-system events to grant seasonal rewards.
 */
class SeasonalRewardAdapter : public DCSystem
{
public:
    std::string GetSystemName() const override { return "SeasonalRewards"; }
    SystemPriority GetPriority() const override { return SystemPriority::ENHANCEMENT; }
    
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
        
        if (_initialized)
        {
            // Subscribe to relevant events to grant seasonal rewards
            GetEventBus()->Subscribe(EventType::DUNGEON_COMPLETE, this);
            GetEventBus()->Subscribe(EventType::MYTHIC_PLUS_COMPLETE, this);
            GetEventBus()->Subscribe(EventType::BOSS_KILL, this);
        }
        
        return _initialized;
    }
    
    void Shutdown() override
    {
        LOG_INFO("dc.crosssystem.adapter", "SeasonalRewardAdapter: Shutting down");
        GetEventBus()->Unsubscribe(EventType::DUNGEON_COMPLETE, this);
        GetEventBus()->Unsubscribe(EventType::MYTHIC_PLUS_COMPLETE, this);
        GetEventBus()->Unsubscribe(EventType::BOSS_KILL, this);
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
            // GetOrCreatePlayerStats handles loading
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
            // Stats are saved automatically on change
            auto* stats = manager->GetPlayerStats(player->GetGUID().GetCounter());
            if (stats)
            {
                manager->SavePlayerStats(*stats);
            }
        }
    }
    
    void HandleEvent(const SystemEvent& event) override
    {
        if (!_initialized)
            return;
            
        using namespace DarkChaos::SeasonalRewards;
        auto* manager = SeasonalRewardManager::instance();
        if (!manager)
            return;
            
        Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(event.playerGuid));
        if (!player)
            return;
            
        switch (event.type)
        {
            case EventType::MYTHIC_PLUS_COMPLETE:
            {
                // Grant tokens based on M+ level
                uint32 tokens = 5 + (event.intParam1 * 2); // Base 5 + 2 per level
                if (event.intParam2 > 0) // Timed success
                    tokens = static_cast<uint32>(tokens * 1.5f);
                    
                manager->AwardTokens(player, tokens, "mythic_plus", event.mapId);
                break;
            }
            
            case EventType::DUNGEON_COMPLETE:
            {
                // Grant base tokens for normal dungeon completion
                manager->AwardTokens(player, 5, "dungeon_complete", event.mapId);
                break;
            }
            
            case EventType::BOSS_KILL:
            {
                // Small token reward per boss
                uint32 tokens = 1;
                if (event.intParam2 > 0) // M+ level
                    tokens = 2;
                manager->AwardTokens(player, tokens, "boss_kill", event.intParam1);
                break;
            }
            
            default:
                break;
        }
    }
    
    // Read-only accessors using actual SeasonalRewardManager API
    uint32 GetCurrentSeasonId() const
    {
        using namespace DarkChaos::SeasonalRewards;
        auto* manager = SeasonalRewardManager::instance();
        return manager ? manager->GetConfig().activeSeason : 0;
    }
    
private:
    bool _initialized = false;
};

// =========================================================================
// Item Upgrade System Adapter
// =========================================================================

/**
 * @brief Adapter wrapping ItemUpgradeManager for cross-system integration
 *
 * The ItemUpgrade system uses:
 * - GetUpgradeManager() singleton accessor
 * - AddCurrency(guid, type, amount, season) for granting tokens
 * - GetCurrency(guid, type, season) for reading tokens
 *
 * Note: ItemUpgrade uses item-based upgrades, not direct player data loading.
 */
class ItemUpgradeAdapter : public DCSystem
{
public:
    std::string GetSystemName() const override { return "ItemUpgrades"; }
    SystemPriority GetPriority() const override { return SystemPriority::CORE; }
    
    uint32 GetCapabilities() const override
    {
        return static_cast<uint32>(SystemCapability::ITEM_MODIFICATION) |
               static_cast<uint32>(SystemCapability::PLAYER_PROGRESSION);
    }
    
    bool Initialize() override
    {
        LOG_INFO("dc.crosssystem.adapter", "ItemUpgradeAdapter: Initializing");
        
        using namespace DarkChaos::ItemUpgrade;
        _initialized = GetUpgradeManager() != nullptr;
        
        if (_initialized)
        {
            // Subscribe to events that should grant upgrade tokens
            GetEventBus()->Subscribe(EventType::BOSS_KILL, this);
            GetEventBus()->Subscribe(EventType::MYTHIC_PLUS_COMPLETE, this);
        }
        
        return _initialized;
    }
    
    void Shutdown() override
    {
        LOG_INFO("dc.crosssystem.adapter", "ItemUpgradeAdapter: Shutting down");
        GetEventBus()->Unsubscribe(EventType::BOSS_KILL, this);
        GetEventBus()->Unsubscribe(EventType::MYTHIC_PLUS_COMPLETE, this);
        _initialized = false;
    }
    
    void OnPlayerLogin(Player* /*player*/, bool /*firstLogin*/) override
    {
        // ItemUpgradeManager loads data per-item, not per-player
        // No action needed here
    }
    
    void OnPlayerLogout(Player* /*player*/) override
    {
        // ItemUpgradeManager saves per-item data automatically
        // No action needed here
    }
    
    void HandleEvent(const SystemEvent& event) override
    {
        if (!_initialized)
            return;
            
        using namespace DarkChaos::ItemUpgrade;
        auto* manager = GetUpgradeManager();
        if (!manager)
            return;
            
        switch (event.type)
        {
            case EventType::BOSS_KILL:
            {
                // Grant 1-2 upgrade tokens per boss kill
                uint32 tokens = (event.intParam2 > 0) ? 2 : 1; // More for M+
                manager->AddCurrency(event.playerGuid, CURRENCY_UPGRADE_TOKEN, tokens);
                break;
            }
            
            case EventType::MYTHIC_PLUS_COMPLETE:
            {
                // Grant tokens based on M+ level and success
                uint32 tokens = event.intParam1; // M+ level = base tokens
                if (event.intParam2 > 0) // Timed success
                    tokens += 5;
                    
                // Also grant some essence for higher keys
                if (event.intParam1 >= 10)
                {
                    uint32 essence = (event.intParam1 - 9);
                    manager->AddCurrency(event.playerGuid, CURRENCY_ARTIFACT_ESSENCE, essence);
                }
                    
                manager->AddCurrency(event.playerGuid, CURRENCY_UPGRADE_TOKEN, tokens);
                break;
            }
            
            default:
                break;
        }
    }
    
    // Read-only accessors using actual ItemUpgrade API
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
    
private:
    bool _initialized = false;
};

// =========================================================================
// Prestige System Adapter
// =========================================================================

/**
 * @brief Adapter wrapping PrestigeAPI for cross-system integration
 *
 * PrestigeAPI provides static functions:
 * - IsEnabled()
 * - GetPrestigeLevel(player)
 * - GetMaxPrestigeLevel()
 * - CanPrestige(player)
 * - ApplyPrestigeBuffs(player)
 * - PerformPrestige(player)
 *
 * Note: Prestige data is loaded/saved by dc_prestige_system.cpp PlayerScript hooks.
 */
class PrestigeAdapter : public DCSystem
{
public:
    std::string GetSystemName() const override { return "Prestige"; }
    SystemPriority GetPriority() const override { return SystemPriority::CORE; }
    
    uint32 GetCapabilities() const override
    {
        return static_cast<uint32>(SystemCapability::PLAYER_PROGRESSION) |
               static_cast<uint32>(SystemCapability::REWARD_GRANTING);
    }
    
    bool Initialize() override
    {
        LOG_INFO("dc.crosssystem.adapter", "PrestigeAdapter: Initializing");
        _initialized = PrestigeAPI::IsEnabled();
        
        if (_initialized)
        {
            // Subscribe to level up events to check for prestige eligibility
            GetEventBus()->Subscribe(EventType::PLAYER_LEVEL_UP, this);
        }
        
        return _initialized;
    }
    
    void Shutdown() override
    {
        LOG_INFO("dc.crosssystem.adapter", "PrestigeAdapter: Shutting down");
        GetEventBus()->Unsubscribe(EventType::PLAYER_LEVEL_UP, this);
        _initialized = false;
    }
    
    void OnPlayerLogin(Player* player, bool /*firstLogin*/) override
    {
        if (!_initialized || !player)
            return;
            
        // Apply prestige buffs on login (loaded by dc_prestige_system.cpp)
        PrestigeAPI::ApplyPrestigeBuffs(player);
    }
    
    void OnPlayerLogout(Player* /*player*/) override
    {
        // Prestige data is saved by dc_prestige_system.cpp
        // No action needed here
    }
    
    void HandleEvent(const SystemEvent& event) override
    {
        if (!_initialized)
            return;
            
        if (event.type == EventType::PLAYER_LEVEL_UP)
        {
            Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(event.playerGuid));
            if (!player)
                return;
                
            // Check if player reached max level and can prestige
            uint32 requiredLevel = PrestigeAPI::GetRequiredLevel();
            if (player->GetLevel() >= requiredLevel && PrestigeAPI::CanPrestige(player))
            {
                // Notify player they can prestige
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Prestige]|r You have reached the maximum level! "
                    "Visit the Prestige NPC to prestige and start your next journey!"
                );
            }
        }
    }
    
    // Read-only accessors using actual PrestigeAPI
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
    
private:
    bool _initialized = false;
};

// =========================================================================
// Adapter Registration Helper
// =========================================================================

/**
 * @brief Registers all system adapters with the CrossSystemManager
 *
 * Each adapter wraps an existing DC system and provides:
 * - Event publishing for cross-system coordination
 * - Event subscription for reacting to other systems
 * - Read-only accessors for querying system state
 *
 * Adapters do NOT duplicate existing functionality - they bridge systems.
 */
inline void RegisterAllAdapters()
{
    auto* manager = GetManager();
    if (!manager)
    {
        LOG_ERROR("dc.crosssystem.adapter", "Cannot register adapters - manager not available");
        return;
    }
    
    LOG_INFO("dc.crosssystem.adapter", "Registering cross-system adapters...");
    
    // Register adapters in priority order
    // Each adapter is optional - if the underlying system isn't available,
    // the adapter's Initialize() will return false and it won't be active
    
    manager->RegisterSystem(std::make_unique<MythicPlusAdapter>());
    manager->RegisterSystem(std::make_unique<PrestigeAdapter>());
    manager->RegisterSystem(std::make_unique<ItemUpgradeAdapter>());
    manager->RegisterSystem(std::make_unique<SeasonalRewardAdapter>());
    
    LOG_INFO("dc.crosssystem.adapter", "All adapters registered successfully");
}

} // namespace Adapters
} // namespace CrossSystem
} // namespace DarkChaos

#endif // DC_CROSS_SYSTEM_ADAPTERS_H
