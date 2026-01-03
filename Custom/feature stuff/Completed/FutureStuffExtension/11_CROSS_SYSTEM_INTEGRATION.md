# Cross-System Integration Framework

**Priority:** A-Tier  
**Effort:** High (3 weeks)  
**Impact:** Very High  
**Target System:** New - `src/server/scripts/DC/Integration/`

---

## Overview

A unified integration framework that connects all DC systems together, enabling cross-system synergies, shared progression, and unified data management.

---

## Core Architecture

### Central Event Bus

```cpp
// DCEventBus.h
#pragma once

#include <functional>
#include <unordered_map>
#include <vector>
#include <any>

namespace DC
{

enum class EventType
{
    // Player Events
    PLAYER_LOGIN,
    PLAYER_LOGOUT,
    PLAYER_LEVEL_UP,
    PLAYER_DEATH,
    PLAYER_RESURRECTION,
    
    // Combat Events
    CREATURE_KILL,
    BOSS_KILL,
    PVP_KILL,
    DAMAGE_DEALT,
    HEALING_DONE,
    
    // Dungeon Events
    DUNGEON_ENTER,
    DUNGEON_COMPLETE,
    DUNGEON_WIPE,
    
    // Mythic+ Events
    MYTHIC_RUN_START,
    MYTHIC_RUN_COMPLETE,
    MYTHIC_RUN_FAIL,
    MYTHIC_AFFIX_TRIGGER,
    KEYSTONE_UPGRADE,
    
    // Season Events
    SEASON_START,
    SEASON_END,
    SEASON_RANK_CHANGE,
    
    // ItemUpgrade Events
    ITEM_UPGRADED,
    ITEM_UPGRADE_FAILED,
    
    // Prestige Events
    PRESTIGE_LEVEL_UP,
    PRESTIGE_TALENT_LEARNED,
    
    // Hotspot Events
    HOTSPOT_ENTER,
    HOTSPOT_EXIT,
    HOTSPOT_XP_GAINED,
    
    // Loot Events
    LOOT_COLLECTED,
    RARE_LOOT_DROPPED,
    
    // Quest Events
    QUEST_COMPLETE,
    QUEST_CHAIN_COMPLETE,
    DAILY_RESET,
    WEEKLY_RESET,
    
    // Economy Events
    CURRENCY_GAINED,
    CURRENCY_SPENT,
    
    // Custom Events
    CUSTOM_EVENT
};

struct Event
{
    EventType type;
    ObjectGuid player;
    std::unordered_map<std::string, std::any> data;
    time_t timestamp;
    
    template<typename T>
    T Get(const std::string& key, T defaultValue = T{}) const
    {
        auto it = data.find(key);
        if (it != data.end())
        {
            try { return std::any_cast<T>(it->second); }
            catch (...) { return defaultValue; }
        }
        return defaultValue;
    }
    
    template<typename T>
    void Set(const std::string& key, T value)
    {
        data[key] = std::make_any<T>(value);
    }
};

using EventHandler = std::function<void(const Event&)>;
using EventFilter = std::function<bool(const Event&)>;

class EventBus
{
public:
    static EventBus* instance();
    
    // Subscribe to events
    uint32 Subscribe(EventType type, EventHandler handler, int priority = 0);
    uint32 Subscribe(EventType type, EventHandler handler, EventFilter filter, int priority = 0);
    void Unsubscribe(uint32 subscriptionId);
    
    // Publish events
    void Publish(const Event& event);
    void PublishAsync(const Event& event);
    
    // Batch operations
    void PublishBatch(const std::vector<Event>& events);
    
    // Event history (for debugging/analytics)
    std::vector<Event> GetRecentEvents(EventType type, uint32 count = 10);
    void ClearHistory();

private:
    EventBus();
    
    struct Subscription
    {
        uint32 id;
        EventType type;
        EventHandler handler;
        EventFilter filter;
        int priority;
    };
    
    std::unordered_map<EventType, std::vector<Subscription>> _subscriptions;
    std::deque<Event> _eventHistory;
    uint32 _nextSubscriptionId = 1;
    std::mutex _mutex;
};

#define sEventBus DC::EventBus::instance()

} // namespace DC
```

### Event Bus Implementation

```cpp
// DCEventBus.cpp
#include "DCEventBus.h"
#include <algorithm>

namespace DC
{

EventBus* EventBus::instance()
{
    static EventBus instance;
    return &instance;
}

uint32 EventBus::Subscribe(EventType type, EventHandler handler, int priority)
{
    return Subscribe(type, handler, nullptr, priority);
}

uint32 EventBus::Subscribe(EventType type, EventHandler handler, 
    EventFilter filter, int priority)
{
    std::lock_guard<std::mutex> lock(_mutex);
    
    uint32 id = _nextSubscriptionId++;
    
    _subscriptions[type].push_back({
        .id = id,
        .type = type,
        .handler = handler,
        .filter = filter,
        .priority = priority
    });
    
    // Sort by priority (higher first)
    std::sort(_subscriptions[type].begin(), _subscriptions[type].end(),
        [](const auto& a, const auto& b) { return a.priority > b.priority; });
    
    return id;
}

void EventBus::Publish(const Event& event)
{
    std::vector<Subscription> handlers;
    
    {
        std::lock_guard<std::mutex> lock(_mutex);
        
        // Store in history
        _eventHistory.push_back(event);
        if (_eventHistory.size() > 1000)
            _eventHistory.pop_front();
        
        // Get handlers
        auto it = _subscriptions.find(event.type);
        if (it != _subscriptions.end())
            handlers = it->second;
    }
    
    // Execute handlers outside lock
    for (const auto& sub : handlers)
    {
        if (!sub.filter || sub.filter(event))
        {
            try
            {
                sub.handler(event);
            }
            catch (const std::exception& e)
            {
                LOG_ERROR("dc.eventbus", "Handler error for event {}: {}", 
                    static_cast<int>(event.type), e.what());
            }
        }
    }
}

} // namespace DC
```

---

### System Registry

```cpp
// DCSystemRegistry.h
#pragma once

#include "DCEventBus.h"
#include <memory>

namespace DC
{

// Base interface for all DC systems
class ISystem
{
public:
    virtual ~ISystem() = default;
    
    virtual std::string GetName() const = 0;
    virtual void Initialize() = 0;
    virtual void Shutdown() = 0;
    virtual void OnPlayerLogin(Player* player) {}
    virtual void OnPlayerLogout(Player* player) {}
    virtual void OnDailyReset() {}
    virtual void OnWeeklyReset() {}
    virtual void OnSeasonEnd(uint32 seasonId) {}
};

class SystemRegistry
{
public:
    static SystemRegistry* instance();
    
    template<typename T>
    void Register(std::shared_ptr<T> system)
    {
        static_assert(std::is_base_of<ISystem, T>::value, 
            "T must derive from ISystem");
        
        _systems[system->GetName()] = system;
        system->Initialize();
    }
    
    template<typename T>
    std::shared_ptr<T> Get(const std::string& name)
    {
        auto it = _systems.find(name);
        if (it != _systems.end())
            return std::dynamic_pointer_cast<T>(it->second);
        return nullptr;
    }
    
    void InitializeAll();
    void ShutdownAll();
    void BroadcastPlayerLogin(Player* player);
    void BroadcastPlayerLogout(Player* player);
    void BroadcastDailyReset();
    void BroadcastWeeklyReset();

private:
    std::unordered_map<std::string, std::shared_ptr<ISystem>> _systems;
};

#define sSystemRegistry DC::SystemRegistry::instance()

} // namespace DC
```

---

### Cross-System Data Sharing

```sql
-- Unified player data
CREATE TABLE dc_player_profile (
    player_guid INT UNSIGNED PRIMARY KEY,
    account_id INT UNSIGNED NOT NULL,
    
    -- Prestige
    prestige_level TINYINT UNSIGNED DEFAULT 0,
    prestige_xp INT UNSIGNED DEFAULT 0,
    
    -- Season
    current_season_id INT UNSIGNED DEFAULT 0,
    season_pass_level TINYINT UNSIGNED DEFAULT 0,
    season_pass_premium BOOLEAN DEFAULT FALSE,
    
    -- Mythic+
    mythic_rating INT UNSIGNED DEFAULT 0,
    highest_key_completed TINYINT UNSIGNED DEFAULT 0,
    weekly_vault_slot_1 INT UNSIGNED DEFAULT 0,
    weekly_vault_slot_2 INT UNSIGNED DEFAULT 0,
    weekly_vault_slot_3 INT UNSIGNED DEFAULT 0,
    
    -- ItemUpgrades
    total_items_upgraded INT UNSIGNED DEFAULT 0,
    total_upgrade_tokens INT UNSIGNED DEFAULT 0,
    
    -- Engagement
    total_playtime_seconds BIGINT UNSIGNED DEFAULT 0,
    total_logins INT UNSIGNED DEFAULT 0,
    consecutive_daily_logins INT UNSIGNED DEFAULT 0,
    last_login TIMESTAMP NULL,
    last_daily_reset TIMESTAMP NULL,
    
    -- Performance
    total_boss_kills INT UNSIGNED DEFAULT 0,
    total_dungeon_completions INT UNSIGNED DEFAULT 0,
    total_pvp_kills INT UNSIGNED DEFAULT 0,
    
    KEY idx_account (account_id)
);

-- Cross-system achievements/unlocks
CREATE TABLE dc_player_unlocks (
    player_guid INT UNSIGNED NOT NULL,
    unlock_type ENUM('title', 'mount', 'pet', 'transmog', 'cosmetic', 'ability', 'perk') NOT NULL,
    unlock_id INT UNSIGNED NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (player_guid, unlock_type, unlock_id)
);

-- Cross-system currency wallet
CREATE TABLE dc_player_currencies (
    player_guid INT UNSIGNED NOT NULL,
    currency_id INT UNSIGNED NOT NULL,
    amount BIGINT UNSIGNED DEFAULT 0,
    total_earned BIGINT UNSIGNED DEFAULT 0,
    total_spent BIGINT UNSIGNED DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (player_guid, currency_id)
);
```

---

### Player Profile Manager

```cpp
// DCPlayerProfile.h
#pragma once

namespace DC
{

struct PlayerProfile
{
    ObjectGuid::LowType guid;
    uint32 accountId;
    
    // Prestige
    uint8 prestigeLevel;
    uint32 prestigeXP;
    
    // Season
    uint32 currentSeasonId;
    uint8 seasonPassLevel;
    bool seasonPassPremium;
    
    // Mythic+
    uint32 mythicRating;
    uint8 highestKeyCompleted;
    std::array<uint32, 3> weeklyVaultSlots;
    
    // ItemUpgrades
    uint32 totalItemsUpgraded;
    uint32 totalUpgradeTokens;
    
    // Engagement
    uint64 totalPlaytime;
    uint32 totalLogins;
    uint32 consecutiveDailyLogins;
    time_t lastLogin;
    
    // Performance
    uint32 totalBossKills;
    uint32 totalDungeonCompletions;
    uint32 totalPvPKills;
};

class PlayerProfileManager
{
public:
    static PlayerProfileManager* instance();
    
    PlayerProfile* GetProfile(ObjectGuid::LowType guid);
    PlayerProfile* GetOrCreateProfile(ObjectGuid::LowType guid, uint32 accountId);
    void SaveProfile(const PlayerProfile& profile);
    void DeleteProfile(ObjectGuid::LowType guid);
    
    // Convenience methods
    void IncrementStat(ObjectGuid::LowType guid, const std::string& stat, int64 amount = 1);
    void SetStat(ObjectGuid::LowType guid, const std::string& stat, int64 value);
    int64 GetStat(ObjectGuid::LowType guid, const std::string& stat);
    
    // Currency management
    bool AddCurrency(ObjectGuid::LowType guid, uint32 currencyId, uint32 amount, 
        const std::string& source);
    bool SpendCurrency(ObjectGuid::LowType guid, uint32 currencyId, uint32 amount,
        const std::string& reason);
    uint32 GetCurrency(ObjectGuid::LowType guid, uint32 currencyId);
    
    // Unlocks
    bool GrantUnlock(ObjectGuid::LowType guid, const std::string& type, 
        uint32 unlockId, const std::string& source);
    bool HasUnlock(ObjectGuid::LowType guid, const std::string& type, uint32 unlockId);
    std::vector<uint32> GetUnlocks(ObjectGuid::LowType guid, const std::string& type);

private:
    std::unordered_map<uint32, PlayerProfile> _profiles;
};

#define sPlayerProfile DC::PlayerProfileManager::instance()

} // namespace DC
```

---

### Integration Handlers

```cpp
// DCIntegrationHandlers.cpp
#include "DCEventBus.h"
#include "DCPlayerProfile.h"

namespace DC
{

class MythicPlusIntegration
{
public:
    void Initialize()
    {
        // Subscribe to M+ events
        sEventBus->Subscribe(EventType::MYTHIC_RUN_COMPLETE, 
            [this](const Event& e) { OnMythicComplete(e); });
        
        sEventBus->Subscribe(EventType::KEYSTONE_UPGRADE,
            [this](const Event& e) { OnKeystoneUpgrade(e); });
    }
    
private:
    void OnMythicComplete(const Event& e)
    {
        auto guid = e.player.GetCounter();
        auto level = e.Get<uint8>("level");
        auto inTime = e.Get<bool>("in_time");
        auto rating = e.Get<uint32>("rating_gained");
        
        // Update profile
        auto profile = sPlayerProfile->GetProfile(guid);
        if (profile)
        {
            profile->mythicRating += rating;
            if (level > profile->highestKeyCompleted)
                profile->highestKeyCompleted = level;
            
            sPlayerProfile->SaveProfile(*profile);
        }
        
        // Award season pass XP
        uint32 xp = level * 1000 + (inTime ? 500 : 0);
        Event seasonEvent;
        seasonEvent.type = EventType::CURRENCY_GAINED;
        seasonEvent.player = e.player;
        seasonEvent.Set<uint32>("currency_type", CURRENCY_SEASON_XP);
        seasonEvent.Set<uint32>("amount", xp);
        seasonEvent.Set<std::string>("source", "mythic_plus");
        sEventBus->Publish(seasonEvent);
        
        // Award upgrade tokens
        uint32 tokens = level * 5;
        sPlayerProfile->AddCurrency(guid, CURRENCY_UPGRADE_TOKEN, tokens, "mythic_plus");
        
        // Hotspot bonus if applicable
        // (M+ dungeons can be designated as hotspots during events)
    }
    
    void OnKeystoneUpgrade(const Event& e)
    {
        auto guid = e.player.GetCounter();
        auto newLevel = e.Get<uint8>("new_level");
        
        // Prestige XP for key upgrades
        if (newLevel >= 15)
        {
            uint32 prestigeXP = (newLevel - 14) * 100;
            sPrestige->AddXP(guid, prestigeXP);
        }
    }
};

class SeasonPassIntegration
{
public:
    void Initialize()
    {
        // Listen to various events that grant season XP
        sEventBus->Subscribe(EventType::DUNGEON_COMPLETE,
            [this](const Event& e) { OnDungeonComplete(e); });
        
        sEventBus->Subscribe(EventType::BOSS_KILL,
            [this](const Event& e) { OnBossKill(e); });
        
        sEventBus->Subscribe(EventType::PVP_KILL,
            [this](const Event& e) { OnPvPKill(e); });
        
        sEventBus->Subscribe(EventType::QUEST_COMPLETE,
            [this](const Event& e) { OnQuestComplete(e); });
    }
    
private:
    void OnDungeonComplete(const Event& e)
    {
        auto guid = e.player.GetCounter();
        auto dungeonId = e.Get<uint32>("dungeon_id");
        
        // Base XP for dungeon
        uint32 xp = 2000;
        
        // Bonus for heroic
        if (e.Get<bool>("heroic"))
            xp += 500;
        
        sSeasonPass->AddXP(guid, xp, "dungeon_complete");
    }
    
    void OnBossKill(const Event& e)
    {
        auto guid = e.player.GetCounter();
        
        // Raid bosses give more XP
        uint32 xp = e.Get<bool>("raid_boss") ? 1000 : 500;
        sSeasonPass->AddXP(guid, xp, "boss_kill");
    }
    
    void OnPvPKill(const Event& e)
    {
        auto guid = e.player.GetCounter();
        sSeasonPass->AddXP(guid, 250, "pvp_kill");
    }
    
    void OnQuestComplete(const Event& e)
    {
        auto guid = e.player.GetCounter();
        
        // Quest type determines XP
        auto questType = e.Get<std::string>("quest_type");
        uint32 xp = 500;
        
        if (questType == "daily")
            xp = 1000;
        else if (questType == "weekly")
            xp = 5000;
        else if (questType == "chain")
            xp = 2500;
        
        sSeasonPass->AddXP(guid, xp, "quest_complete");
    }
};

class PrestigeIntegration
{
public:
    void Initialize()
    {
        sEventBus->Subscribe(EventType::PRESTIGE_LEVEL_UP,
            [this](const Event& e) { OnPrestigeUp(e); });
    }
    
private:
    void OnPrestigeUp(const Event& e)
    {
        auto guid = e.player.GetCounter();
        auto newPrestige = e.Get<uint8>("prestige_level");
        
        // Update profile
        auto profile = sPlayerProfile->GetProfile(guid);
        if (profile)
        {
            profile->prestigeLevel = newPrestige;
            sPlayerProfile->SaveProfile(*profile);
        }
        
        // Grant unlocks at milestones
        if (newPrestige == 5)
        {
            sPlayerProfile->GrantUnlock(guid, "title", TITLE_VETERAN, "prestige");
        }
        else if (newPrestige == 10)
        {
            sPlayerProfile->GrantUnlock(guid, "mount", MOUNT_PRESTIGE, "prestige");
        }
        else if (newPrestige == 20)
        {
            sPlayerProfile->GrantUnlock(guid, "cosmetic", COSMETIC_LEGENDARY_AURA, "prestige");
        }
        
        // Increase ItemUpgrade capacity
        sItemUpgrade->IncreaseCapacity(guid, 5);
    }
};

} // namespace DC
```

---

### Unified Addon Data

```lua
-- DCIntegration.lua - Unified data handler
local Integration = AIO.AddAddon()

function Integration:Init()
    -- Central data cache
    self.playerData = {}
    
    -- Register for all DC data packets
    AIO.RegisterEvent("DC_PROFILE_UPDATE", function(data)
        self:UpdateProfile(data)
    end)
    
    AIO.RegisterEvent("DC_CURRENCY_UPDATE", function(data)
        self:UpdateCurrencies(data)
    end)
    
    AIO.RegisterEvent("DC_UNLOCK_GAINED", function(data)
        self:OnUnlockGained(data)
    end)
end

function Integration:UpdateProfile(data)
    self.playerData.prestige = data.prestige
    self.playerData.mythicRating = data.mythic_rating
    self.playerData.seasonLevel = data.season_level
    self.playerData.highestKey = data.highest_key
    
    -- Notify all DC addons
    self:BroadcastUpdate("profile")
end

function Integration:UpdateCurrencies(data)
    self.playerData.currencies = self.playerData.currencies or {}
    
    for currencyId, amount in pairs(data) do
        self.playerData.currencies[currencyId] = amount
    end
    
    self:BroadcastUpdate("currencies")
end

function Integration:OnUnlockGained(data)
    -- Show unlock notification
    local notif = DCNotification:Create()
    notif:SetTitle("New Unlock!")
    notif:SetIcon(data.icon)
    notif:SetText(data.name)
    notif:SetSubtext("From: " .. data.source)
    notif:Show()
    
    -- Play unlock sound
    PlaySound("QUESTCOMPLETED")
end

function Integration:BroadcastUpdate(dataType)
    -- All DC addons can listen for this
    DCEventBus:Fire("DC_DATA_UPDATE", dataType, self.playerData)
end

-- Expose API for other addons
function Integration:GetPlayerData()
    return self.playerData
end

function Integration:GetCurrency(currencyId)
    return (self.playerData.currencies or {})[currencyId] or 0
end

function Integration:GetPrestige()
    return self.playerData.prestige or 0
end

function Integration:GetMythicRating()
    return self.playerData.mythicRating or 0
end

-- Global access
DCIntegration = Integration
```

---

## Bonus System Synergies

### Synergy Definitions
```sql
CREATE TABLE dc_system_synergies (
    synergy_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    synergy_name VARCHAR(100) NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    source_condition TEXT NOT NULL,  -- JSON conditions
    target_system VARCHAR(50) NOT NULL,
    target_effect TEXT NOT NULL,     -- JSON effect definition
    enabled BOOLEAN DEFAULT TRUE
);

-- Example synergies
INSERT INTO dc_system_synergies (synergy_name, source_system, source_condition, target_system, target_effect) VALUES
('Prestige Upgrade Discount', 'prestige', '{"prestige_level": {"gte": 10}}', 'itemupgrade', '{"cost_reduction_percent": 10}'),
('M+ Hotspot XP', 'mythicplus', '{"key_level": {"gte": 15}}', 'hotspots', '{"xp_bonus_percent": 25}'),
('Season Loot Boost', 'seasons', '{"pass_level": {"gte": 50}}', 'aoeloot', '{"drop_rate_bonus_percent": 15}'),
('Prestige Mythic Bonus', 'prestige', '{"prestige_level": {"gte": 5}}', 'mythicplus', '{"rating_bonus_percent": 5}'),
('High Key Prestige XP', 'mythicplus', '{"key_level": {"gte": 20}}', 'prestige', '{"xp_multiplier": 1.5}');
```

### Synergy Manager
```cpp
class SynergyManager
{
public:
    static SynergyManager* instance();
    
    float GetBonusMultiplier(ObjectGuid::LowType guid, 
        const std::string& targetSystem, const std::string& effectType)
    {
        float multiplier = 1.0f;
        
        for (const auto& synergy : _synergies)
        {
            if (synergy.targetSystem != targetSystem)
                continue;
            
            if (!CheckCondition(guid, synergy))
                continue;
            
            auto effect = nlohmann::json::parse(synergy.targetEffect);
            
            if (effect.contains(effectType))
            {
                float value = effect[effectType].get<float>();
                
                // Determine if additive or multiplicative
                if (effectType.find("percent") != std::string::npos)
                    multiplier += value / 100.0f;
                else if (effectType.find("multiplier") != std::string::npos)
                    multiplier *= value;
            }
        }
        
        return multiplier;
    }
    
private:
    bool CheckCondition(ObjectGuid::LowType guid, const Synergy& synergy)
    {
        auto conditions = nlohmann::json::parse(synergy.sourceCondition);
        auto profile = sPlayerProfile->GetProfile(guid);
        
        if (!profile)
            return false;
        
        for (auto& [key, value] : conditions.items())
        {
            int64 playerValue = GetPlayerValue(profile, synergy.sourceSystem, key);
            
            if (value.is_object())
            {
                if (value.contains("gte") && playerValue < value["gte"].get<int64>())
                    return false;
                if (value.contains("lte") && playerValue > value["lte"].get<int64>())
                    return false;
                if (value.contains("eq") && playerValue != value["eq"].get<int64>())
                    return false;
            }
            else if (playerValue != value.get<int64>())
            {
                return false;
            }
        }
        
        return true;
    }
};
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Event Bus | 3 days | Core event system |
| System Registry | 2 days | Registration, lifecycle |
| Profile Manager | 3 days | Unified player data |
| Integration Handlers | 5 days | Per-system integrations |
| Synergy System | 3 days | Cross-system bonuses |
| Addon Integration | 3 days | Client-side unification |
| Testing | 3 days | Full integration tests |
| **Total** | **~3 weeks** | |

---

## Benefits

1. **Reduced Code Duplication** - Shared event handling
2. **Unified Player Data** - Single source of truth
3. **Dynamic Synergies** - Database-configurable bonuses
4. **Easier Debugging** - Centralized event logging
5. **Better Performance** - Optimized data access patterns
6. **Extensibility** - Easy to add new systems
