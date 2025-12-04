/*
 * DarkChaos Cross-System Integration Core
 *
 * Central hub for coordinating between all DC custom systems:
 * - Mythic+ System
 * - Seasonal Rewards
 * - Item Upgrade System
 * - Prestige System
 * - AoE Loot System
 * - Dungeon Quest System
 * - HLBG System
 * - Heirloom System
 * - Challenge Modes
 *
 * Provides:
 * - Unified player session context
 * - Cross-system event bus
 * - Centralized reward distribution
 * - Cross-system multiplier calculations
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#pragma once

#include "Define.h"
#include "ObjectGuid.h"
#include "SharedDefines.h"
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

class Player;
class Creature;
class Map;

namespace DarkChaos
{
namespace CrossSystem
{
    // =========================================================================
    // Forward Declarations
    // =========================================================================
    
    class SessionContext;
    class EventBus;
    class RewardDistributor;
    class CrossSystemManager;
    
    // =========================================================================
    // System Identifiers
    // =========================================================================
    
    enum class SystemId : uint8
    {
        None            = 0,
        MythicPlus      = 1,
        SeasonalRewards = 2,
        ItemUpgrade     = 3,
        Prestige        = 4,
        AoeLoot         = 5,
        DungeonQuests   = 6,
        HLBG            = 7,
        Heirloom        = 8,
        ChallengeModes  = 9,
        Dueling         = 10,
        Welcome         = 11,
        Max
    };
    
    // Convert SystemId to string for logging/display
    inline const char* SystemIdToString(SystemId id)
    {
        switch (id)
        {
            case SystemId::None:            return "None";
            case SystemId::MythicPlus:      return "MythicPlus";
            case SystemId::SeasonalRewards: return "SeasonalRewards";
            case SystemId::ItemUpgrade:     return "ItemUpgrade";
            case SystemId::Prestige:        return "Prestige";
            case SystemId::AoeLoot:         return "AoeLoot";
            case SystemId::DungeonQuests:   return "DungeonQuests";
            case SystemId::HLBG:            return "HLBG";
            case SystemId::Heirloom:        return "Heirloom";
            case SystemId::ChallengeModes:  return "ChallengeModes";
            case SystemId::Dueling:         return "Dueling";
            case SystemId::Welcome:         return "Welcome";
            default:                        return "Unknown";
        }
    }
    
    // =========================================================================
    // Event Types
    // =========================================================================
    
    enum class EventType : uint16
    {
        None = 0,
        
        // Player Events
        PlayerLogin             = 100,
        PlayerLogout            = 101,
        PlayerLevelUp           = 102,
        PlayerDeath             = 103,
        PlayerPrestige          = 104,
        
        // Combat Events
        CreatureKill            = 200,
        BossKill                = 201,
        WorldBossKill           = 202,
        PlayerKill              = 203,
        
        // Dungeon Events
        DungeonEnter            = 300,
        DungeonLeave            = 301,
        DungeonComplete         = 302,
        DungeonFailed           = 303,
        DungeonReset            = 304,
        
        // Mythic+ Events
        MythicPlusStart         = 400,
        MythicPlusComplete      = 401,
        MythicPlusFail          = 402,
        MythicPlusAbandon       = 403,
        KeystoneUpgrade         = 404,
        
        // Quest Events
        QuestComplete           = 500,
        DailyQuestComplete      = 501,
        WeeklyQuestComplete     = 502,
        
        // Reward Events
        TokensAwarded           = 600,
        EssenceAwarded          = 601,
        ItemUpgraded            = 602,
        LootReceived            = 603,
        
        // Seasonal Events
        WeeklyResetOccurred     = 700,
        SeasonStart             = 701,
        SeasonEnd               = 702,
        VaultClaimed            = 703,
        
        // Achievement Events
        AchievementUnlocked     = 800,
        MilestoneReached        = 801,
        
        // PvP Events
        DuelComplete            = 900,
        HLBGMatchComplete       = 901,
        ArenaMatchComplete      = 902,
        
        Max
    };
    
    // =========================================================================
    // Content Type Classification
    // =========================================================================
    
    enum class ContentType : uint8
    {
        None        = 0,
        OpenWorld   = 1,
        Dungeon     = 2,
        Raid        = 3,
        Battleground= 4,
        Arena       = 5,
        Scenario    = 6,  // Custom scenarios
        HLBG        = 7,  // Hinterland BG
        Max
    };
    
    // =========================================================================
    // Difficulty Classification (unified across systems)
    // =========================================================================
    
    enum class ContentDifficulty : uint8
    {
        None        = 0,
        Normal      = 1,
        Heroic      = 2,
        Mythic      = 3,
        MythicPlus  = 4,  // Keystone dungeons
        Raid10N     = 5,
        Raid10H     = 6,
        Raid25N     = 7,
        Raid25H     = 8,
        Max
    };
    
    // =========================================================================
    // Event Data Structures
    // =========================================================================
    
    // Base event data
    struct EventData
    {
        EventType type = EventType::None;
        uint64 timestamp = 0;
        ObjectGuid playerGuid;
        uint32 mapId = 0;
        uint32 instanceId = 0;
        
        virtual ~EventData() = default;
    };
    
    // Creature kill event
    struct CreatureKillEvent : EventData
    {
        uint32 creatureEntry = 0;
        bool isBoss = false;
        bool isRare = false;
        bool isElite = false;
        uint8 keystoneLevel = 0;  // For M+ runs
        uint32 partySize = 1;
        uint32 tokensAwarded = 0;
        uint32 essenceAwarded = 0;
    };
    
    // Dungeon completion event
    struct DungeonCompleteEvent : EventData
    {
        ContentType contentType = ContentType::Dungeon;
        ContentDifficulty difficulty = ContentDifficulty::Normal;
        uint8 keystoneLevel = 0;
        uint32 completionTimeSeconds = 0;
        uint32 timerLimitSeconds = 0;
        uint8 deaths = 0;
        uint8 wipes = 0;
        bool timedSuccess = false;
        uint32 tokensAwarded = 0;
        uint32 essenceAwarded = 0;
        std::vector<ObjectGuid> participants;
    };
    
    // Quest complete event
    struct QuestCompleteEvent : EventData
    {
        uint32 questId = 0;
        bool isDaily = false;
        bool isWeekly = false;
        uint32 tokensAwarded = 0;
        uint32 essenceAwarded = 0;
    };
    
    // Item upgrade event
    struct ItemUpgradeEvent : EventData
    {
        uint32 itemGuid = 0;
        uint32 itemEntry = 0;
        uint8 fromLevel = 0;
        uint8 toLevel = 0;
        uint8 tierId = 0;
        uint32 tokensCost = 0;
        uint32 essenceCost = 0;
    };
    
    // Prestige event
    struct PrestigeEvent : EventData
    {
        uint8 fromPrestige = 0;
        uint8 toPrestige = 0;
        uint8 fromLevel = 0;
        bool keptGear = false;
    };
    
    // Vault claim event
    struct VaultClaimEvent : EventData
    {
        uint32 seasonId = 0;
        uint8 slotClaimed = 0;
        uint32 itemId = 0;
        uint32 tokensClaimed = 0;
        uint32 essenceClaimed = 0;
    };
    
    // =========================================================================
    // Multiplier Configuration
    // =========================================================================
    
    struct MultiplierConfig
    {
        float baseTokenMultiplier = 1.0f;
        float baseEssenceMultiplier = 1.0f;
        float prestigeBonusPerLevel = 0.02f;      // +2% per prestige level
        float mythicPlusLevelBonus = 0.05f;       // +5% per M+ level
        float groupSizeBonus = 0.0f;              // Optional group bonus
        float weekendBonus = 0.0f;                // Weekend event multiplier
        float eventBonus = 0.0f;                  // Special event multiplier
        
        // Per-content-type multipliers
        std::unordered_map<ContentType, float> contentTypeMultipliers;
        
        // Per-difficulty multipliers
        std::unordered_map<ContentDifficulty, float> difficultyMultipliers;
    };
    
    // =========================================================================
    // Event Handler Interface
    // =========================================================================
    
    // Base interface for systems that want to receive cross-system events
    class IEventHandler
    {
    public:
        virtual ~IEventHandler() = default;
        
        // Get system identifier
        virtual SystemId GetSystemId() const = 0;
        
        // Get system name for logging
        virtual const char* GetSystemName() const = 0;
        
        // Called when an event is broadcast
        virtual void OnEvent(const EventData& event) = 0;
        
        // Get which event types this handler wants to receive
        virtual std::vector<EventType> GetSubscribedEvents() const = 0;
        
        // Priority for event handling (lower = earlier)
        virtual uint8 GetPriority() const { return 100; }
    };
    
    // =========================================================================
    // Reward Context
    // =========================================================================
    
    // Context passed to reward calculations
    struct RewardContext
    {
        ObjectGuid playerGuid;
        SystemId sourceSystem = SystemId::None;
        EventType triggerEvent = EventType::None;
        ContentType contentType = ContentType::None;
        ContentDifficulty difficulty = ContentDifficulty::None;
        uint32 mapId = 0;
        uint32 instanceId = 0;
        uint32 sourceId = 0;        // Creature/quest/etc. ID
        std::string sourceName;     // Human-readable source
        uint8 keystoneLevel = 0;
        uint8 prestigeLevel = 0;
        uint32 seasonId = 0;
        bool isWeekly = false;
        bool isDaily = false;
        
        // Calculated multipliers (set by RewardDistributor)
        float finalTokenMultiplier = 1.0f;
        float finalEssenceMultiplier = 1.0f;
    };
    
    // =========================================================================
    // Global Access Functions
    // =========================================================================
    
    // Get the singleton CrossSystemManager instance
    CrossSystemManager* GetManager();
    
    // Convenience functions
    SessionContext* GetPlayerSession(Player* player);
    EventBus* GetEventBus();
    RewardDistributor* GetRewardDistributor();

} // namespace CrossSystem
} // namespace DarkChaos
