/*
 * ============================================================================
 * Dungeon Enhancement System - Manager Class (Header)
 * ============================================================================
 * Purpose: Singleton manager for coordinating all Mythic+/raid systems
 * Location: src/server/scripts/DC/DungeonEnhancement/Core/
 * Pattern: Singleton (thread-safe)
 * ============================================================================
 */

#ifndef DUNGEON_ENHANCEMENT_MANAGER_H
#define DUNGEON_ENHANCEMENT_MANAGER_H

#include "Define.h"
#include "DungeonEnhancementConstants.h"
#include <map>
#include <vector>
#include <memory>
#include <mutex>

class Player;
class Map;
class Creature;

namespace DungeonEnhancement
{
    // ========================================================================
    // FORWARD DECLARATIONS
    // ========================================================================
    struct SeasonData;
    struct DungeonConfig;
    struct AffixData;
    struct AffixRotation;

    // ========================================================================
    // DATA STRUCTURES
    // ========================================================================
    
    struct SeasonData
    {
        uint32 seasonId;
        std::string seasonName;
        std::string seasonShortName;
        uint32 startTimestamp;
        uint32 endTimestamp;
        bool isActive;
        uint8 maxKeystoneLevel;
        bool vaultEnabled;
        uint8 affixRotationWeeks;
        
        SeasonData() : seasonId(0), startTimestamp(0), endTimestamp(0), 
                       isActive(false), maxKeystoneLevel(10), 
                       vaultEnabled(true), affixRotationWeeks(12) {}
    };
    
    struct DungeonConfig
    {
        uint32 configId;
        uint32 seasonId;
        uint16 mapId;
        std::string dungeonName;
        std::string expansion;
        uint8 baseLevel;
        bool isActive;
        
        // Scaling multipliers
        float mythic0HpMultiplier;
        float mythic0DamageMultiplier;
        float mythicPlusHpBase;
        float mythicPlusDamageBase;
        float mythicPlusScalingPerLevel;
        
        // Boss configuration
        uint8 bossCount;
        uint8 requiredKillsForCompletion;
        
        // Loot configuration
        uint16 baseTokenReward;
        uint16 tokenScalingPerLevel;
        
        // Death configuration (M+ only)
        uint8 maxDeathsBeforeFail;
        
        // GameObject ID
        uint32 fontOfPowerGameObjectId;
        
        DungeonConfig() : configId(0), seasonId(0), mapId(0), baseLevel(80), isActive(true),
                         mythic0HpMultiplier(1.8f), mythic0DamageMultiplier(1.8f),
                         mythicPlusHpBase(2.0f), mythicPlusDamageBase(2.0f),
                         mythicPlusScalingPerLevel(0.15f), bossCount(4),
                         requiredKillsForCompletion(4), baseTokenReward(50),
                         tokenScalingPerLevel(10), maxDeathsBeforeFail(15),
                         fontOfPowerGameObjectId(0) {}
    };
    
    struct AffixData
    {
        uint32 affixId;
        std::string affixName;
        std::string affixDescription;
        std::string affixType;
        uint8 minKeystoneLevel;
        bool isActive;
        
        // Effect configuration
        uint32 spellId;
        float hpModifierPercent;
        float damageModifierPercent;
        std::string specialMechanic;
        
        AffixData() : affixId(0), minKeystoneLevel(2), isActive(true),
                     spellId(0), hpModifierPercent(0.0f), damageModifierPercent(0.0f) {}
    };
    
    struct AffixRotation
    {
        uint32 rotationId;
        uint32 seasonId;
        uint8 weekNumber;
        uint32 tier1AffixId;
        uint32 tier2AffixId;
        uint32 tier3AffixId;
        uint32 startTimestamp;
        uint32 endTimestamp;
        
        AffixRotation() : rotationId(0), seasonId(0), weekNumber(0),
                         tier1AffixId(0), tier2AffixId(0), tier3AffixId(0),
                         startTimestamp(0), endTimestamp(0) {}
    };

    // ========================================================================
    // MANAGER CLASS (SINGLETON)
    // ========================================================================
    
    class DungeonEnhancementManager
    {
    private:
        // Singleton instance
        static DungeonEnhancementManager* instance;
        static std::mutex instanceMutex;
        
        // Cached data
        std::map<uint32, SeasonData> _seasons;
        std::map<uint16, DungeonConfig> _dungeonConfigs;  // Key: mapId
        std::map<uint32, AffixData> _affixes;
        std::vector<AffixRotation> _affixRotations;
        
        // Current active data
        SeasonData* _currentSeason;
        AffixRotation* _currentRotation;
        
        // System state
        bool _systemEnabled;
        uint32 _lastCacheRefreshTime;
        
        // Cache refresh intervals (seconds)
        static constexpr uint32 CACHE_REFRESH_INTERVAL_DUNGEONS = 300;  // 5 minutes
        static constexpr uint32 CACHE_REFRESH_INTERVAL_AFFIXES = 600;   // 10 minutes
        static constexpr uint32 CACHE_REFRESH_INTERVAL_SEASONS = 3600;  // 1 hour
        
        // Private constructor (singleton pattern)
        DungeonEnhancementManager();
        ~DungeonEnhancementManager();
        
        // Prevent copying
        DungeonEnhancementManager(const DungeonEnhancementManager&) = delete;
        DungeonEnhancementManager& operator=(const DungeonEnhancementManager&) = delete;

    public:
        // ====================================================================
        // SINGLETON ACCESS
        // ====================================================================
        static DungeonEnhancementManager* Instance();
        static void DestroyInstance();
        
        // ====================================================================
        // INITIALIZATION & LIFECYCLE
        // ====================================================================
        void Initialize();
        void Shutdown();
        bool IsEnabled() const { return _systemEnabled; }
        void SetEnabled(bool enabled) { _systemEnabled = enabled; }
        
        // ====================================================================
        // CACHE MANAGEMENT
        // ====================================================================
        void LoadSeasonData();
        void LoadDungeonConfigs();
        void LoadAffixData();
        void LoadAffixRotations();
        void RefreshAllCaches();
        void RefreshCacheIfNeeded();
        
        // ====================================================================
        // SEASON MANAGEMENT
        // ====================================================================
        SeasonData* GetCurrentSeason();
        SeasonData* GetSeasonById(uint32 seasonId);
        bool IsSeasonActive(uint32 seasonId) const;
        void StartNewSeason(uint32 seasonId);
        void EndCurrentSeason();
        
        // ====================================================================
        // DUNGEON CONFIGURATION
        // ====================================================================
        DungeonConfig* GetDungeonConfig(uint16 mapId);
        bool IsDungeonMythicPlusEnabled(uint16 mapId);
        std::vector<DungeonConfig*> GetSeasonalDungeons(uint32 seasonId);
        float GetDungeonScalingMultiplier(uint16 mapId, uint8 keystoneLevel, bool isHp);
        
        // ====================================================================
        // AFFIX SYSTEM
        // ====================================================================
        AffixData* GetAffixById(uint32 affixId);
        AffixRotation* GetCurrentAffixRotation();
        std::vector<AffixData*> GetCurrentActiveAffixes(uint8 keystoneLevel);
        bool IsAffixActiveThisWeek(uint32 affixId);
        void ApplyAffixToCreature(Creature* creature, uint8 keystoneLevel);
        
        // ====================================================================
        // KEYSTONE MANAGEMENT
        // ====================================================================
        bool PlayerHasKeystone(Player* player);
        uint8 GetPlayerKeystoneLevel(Player* player);
        bool GivePlayerKeystone(Player* player, uint8 keystoneLevel);
        bool RemovePlayerKeystone(Player* player);
        bool UpgradePlayerKeystone(Player* player, uint8 newLevel);
        bool DowngradePlayerKeystone(Player* player);
        
    // ====================================================================
    // PLAYER PREFERENCES
    // ====================================================================
    uint8 GetPlayerPreferredMythicLevel(Player* player);
    void SetPlayerPreferredMythicLevel(Player* player, uint8 level);
        
        // ====================================================================
        // VAULT SYSTEM
        // ====================================================================
        uint8 GetPlayerVaultProgress(Player* player);
        bool IncrementPlayerVaultProgress(Player* player, uint8 keystoneLevel);
        bool CanClaimVaultSlot(Player* player, uint8 slotNumber);
        uint16 GetVaultTokenReward(uint8 slotNumber, uint8 highestKeystoneLevel);
        void ResetWeeklyVaultProgress();
        
        // ====================================================================
        // RATING & LEADERBOARD
        // ====================================================================
        uint32 GetPlayerRating(Player* player, uint32 seasonId);
        void UpdatePlayerRating(Player* player, uint32 seasonId, uint32 newRating);
        uint32 CalculateRatingGain(uint8 keystoneLevel, uint32 deathCount, uint32 timeTaken);
        
        // ====================================================================
        // TOKEN REWARDS
        // ====================================================================
        uint16 GetDungeonTokenReward(uint16 mapId, uint8 keystoneLevel, bool failedWith15Deaths);
        void AwardDungeonTokens(Player* player, uint16 amount);
        void AwardRaidTokens(Player* player, uint16 amount);
        
        // ====================================================================
        // UTILITIES
        // ====================================================================
        std::string GetColoredMessage(const std::string& message, const char* colorCode);
        void BroadcastToGroup(Player* player, const std::string& message);
        void SendSystemMessage(Player* player, const std::string& message);
        void LogInfo(const char* category, const char* format, ...);
        void LogWarn(const char* category, const char* format, ...);
        void LogError(const char* category, const char* format, ...);
    };
    
    // ========================================================================
    // CONVENIENCE MACRO
    // ========================================================================
    #define sDungeonEnhancementMgr DungeonEnhancement::DungeonEnhancementManager::Instance()

} // namespace DungeonEnhancement

#endif // DUNGEON_ENHANCEMENT_MANAGER_H
