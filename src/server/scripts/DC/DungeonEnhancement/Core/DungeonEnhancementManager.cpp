/*
 * ============================================================================
 * Dungeon Enhancement System - Manager Class (Implementation)
 * ============================================================================
 * Purpose: Singleton manager implementation for Mythic+/raid systems
 * Location: src/server/scripts/DC/DungeonEnhancement/Core/
 * ============================================================================
 */

#include "DungeonEnhancementManager.h"
#include "Player.h"
#include "Map.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Config.h"
#include "Item.h"
#include "Group.h"
#include <cstdarg>
#include <ctime>

namespace DungeonEnhancement
{
    // ========================================================================
    // STATIC MEMBER INITIALIZATION
    // ========================================================================
    DungeonEnhancementManager* DungeonEnhancementManager::instance = nullptr;
    std::mutex DungeonEnhancementManager::instanceMutex;

    // ========================================================================
    // CONSTRUCTOR / DESTRUCTOR
    // ========================================================================
    
    DungeonEnhancementManager::DungeonEnhancementManager()
        : _currentSeason(nullptr)
        , _currentRotation(nullptr)
        , _systemEnabled(false)
        , _lastCacheRefreshTime(0)
    {
        LogInfo(LogCategory::GENERAL, "DungeonEnhancementManager constructed");
    }

    DungeonEnhancementManager::~DungeonEnhancementManager()
    {
        LogInfo(LogCategory::GENERAL, "DungeonEnhancementManager destroyed");
    }

    // ========================================================================
    // SINGLETON ACCESS
    // ========================================================================
    
    DungeonEnhancementManager* DungeonEnhancementManager::Instance()
    {
        std::lock_guard<std::mutex> lock(instanceMutex);
        if (!instance)
        {
            instance = new DungeonEnhancementManager();
        }
        return instance;
    }

    void DungeonEnhancementManager::DestroyInstance()
    {
        std::lock_guard<std::mutex> lock(instanceMutex);
        if (instance)
        {
            delete instance;
            instance = nullptr;
        }
    }

    // ========================================================================
    // INITIALIZATION & LIFECYCLE
    // ========================================================================
    
    void DungeonEnhancementManager::Initialize()
    {
        LogInfo(LogCategory::GENERAL, "Initializing Dungeon Enhancement System v%s", SYSTEM_VERSION);
        
        // Load configuration
        _systemEnabled = sConfigMgr->GetOption<bool>(ConfigKeys::ENABLED, false);
        
        if (!_systemEnabled)
        {
            LogInfo(LogCategory::GENERAL, "Dungeon Enhancement System is DISABLED in config");
            return;
        }
        
        // Load all cached data
        LoadSeasonData();
        LoadDungeonConfigs();
        LoadAffixData();
        LoadAffixRotations();
        
        _lastCacheRefreshTime = static_cast<uint32>(std::time(nullptr));
        
        LogInfo(LogCategory::GENERAL, "Dungeon Enhancement System initialized successfully");
        LogInfo(LogCategory::GENERAL, "  - Seasons loaded: %u", static_cast<uint32>(_seasons.size()));
        LogInfo(LogCategory::GENERAL, "  - Dungeons configured: %u", static_cast<uint32>(_dungeonConfigs.size()));
        LogInfo(LogCategory::GENERAL, "  - Affixes available: %u", static_cast<uint32>(_affixes.size()));
        LogInfo(LogCategory::GENERAL, "  - Current season: %s", _currentSeason ? _currentSeason->seasonName.c_str() : "NONE");
    }

    void DungeonEnhancementManager::Shutdown()
    {
        LogInfo(LogCategory::GENERAL, "Shutting down Dungeon Enhancement System");
        
        _seasons.clear();
        _dungeonConfigs.clear();
        _affixes.clear();
        _affixRotations.clear();
        
        _currentSeason = nullptr;
        _currentRotation = nullptr;
        _systemEnabled = false;
    }

    // ========================================================================
    // CACHE MANAGEMENT
    // ========================================================================
    
    void DungeonEnhancementManager::LoadSeasonData()
    {
        LogInfo(LogCategory::GENERAL, "Loading season data from database...");
        
        _seasons.clear();
        _currentSeason = nullptr;
        
        try
        {
            QueryResult result = WorldDatabase.Query("SELECT season_id, season_name, season_short_name, "
                                                     "start_timestamp, end_timestamp, is_active, "
                                                     "max_keystone_level, vault_enabled, affix_rotation_weeks "
                                                     "FROM {} ORDER BY season_id", Tables::SEASONS);
            
            if (!result)
            {
                LogWarn(LogCategory::GENERAL, "No seasons found in database");
                return;
            }
            
            do
            {
                Field* fields = result->Fetch();
                SeasonData season;
                
                season.seasonId = fields[0].Get<uint32>();
                season.seasonName = fields[1].Get<std::string>();
                season.seasonShortName = fields[2].Get<std::string>();
                season.startTimestamp = fields[3].Get<uint32>();
                season.endTimestamp = fields[4].Get<uint32>();
                season.isActive = fields[5].Get<bool>();
                season.maxKeystoneLevel = fields[6].Get<uint8>();
                season.vaultEnabled = fields[7].Get<bool>();
                season.affixRotationWeeks = fields[8].Get<uint8>();
                
                _seasons[season.seasonId] = season;
                
                if (season.isActive)
                {
                    _currentSeason = &_seasons[season.seasonId];
                    LogInfo(LogCategory::GENERAL, "Active season found: %s (ID: %u)", 
                            season.seasonName.c_str(), season.seasonId);
                }
                
            } while (result->NextRow());
            
            LogInfo(LogCategory::GENERAL, "Loaded %u seasons from database", 
                    static_cast<uint32>(_seasons.size()));
        }
        catch (const std::exception& e)
        {
            LogError(LogCategory::GENERAL, "Failed to load season data: %s", e.what());
        }
    }

    void DungeonEnhancementManager::LoadDungeonConfigs()
    {
        LogInfo(LogCategory::GENERAL, "Loading dungeon configurations from database...");
        
        _dungeonConfigs.clear();
        
        if (!_currentSeason)
        {
            LogWarn(LogCategory::GENERAL, "No active season - skipping dungeon configs");
            return;
        }
        
        try
        {
            QueryResult result = WorldDatabase.Query(
                "SELECT config_id, season_id, map_id, dungeon_name, expansion, base_level, is_active, "
                "mythic0_hp_multiplier, mythic0_damage_multiplier, mythic_plus_hp_base, "
                "mythic_plus_damage_base, mythic_plus_scaling_per_level, boss_count, "
                "required_kills_for_completion, base_token_reward, token_scaling_per_level, "
                "max_deaths_before_fail, font_of_power_gameobject_id "
                "FROM {} WHERE season_id = {} AND is_active = 1",
                Tables::DUNGEONS_CONFIG, _currentSeason->seasonId
            );
            
            if (!result)
            {
                LogWarn(LogCategory::GENERAL, "No dungeon configs found for season %u", 
                        _currentSeason->seasonId);
                return;
            }
            
            do
            {
                Field* fields = result->Fetch();
                DungeonConfig config;
                
                config.configId = fields[0].Get<uint32>();
                config.seasonId = fields[1].Get<uint32>();
                config.mapId = fields[2].Get<uint16>();
                config.dungeonName = fields[3].Get<std::string>();
                config.expansion = fields[4].Get<std::string>();
                config.baseLevel = fields[5].Get<uint8>();
                config.isActive = fields[6].Get<bool>();
                config.mythic0HpMultiplier = fields[7].Get<float>();
                config.mythic0DamageMultiplier = fields[8].Get<float>();
                config.mythicPlusHpBase = fields[9].Get<float>();
                config.mythicPlusDamageBase = fields[10].Get<float>();
                config.mythicPlusScalingPerLevel = fields[11].Get<float>();
                config.bossCount = fields[12].Get<uint8>();
                config.requiredKillsForCompletion = fields[13].Get<uint8>();
                config.baseTokenReward = fields[14].Get<uint16>();
                config.tokenScalingPerLevel = fields[15].Get<uint16>();
                config.maxDeathsBeforeFail = fields[16].Get<uint8>();
                config.fontOfPowerGameObjectId = fields[17].Get<uint32>();
                
                _dungeonConfigs[config.mapId] = config;
                
                LogInfo(LogCategory::MYTHIC_PLUS, "Loaded dungeon: %s (Map %u)", 
                        config.dungeonName.c_str(), config.mapId);
                
            } while (result->NextRow());
            
            LogInfo(LogCategory::GENERAL, "Loaded %u dungeon configurations", 
                    static_cast<uint32>(_dungeonConfigs.size()));
        }
        catch (const std::exception& e)
        {
            LogError(LogCategory::GENERAL, "Failed to load dungeon configs: %s", e.what());
        }
    }

    void DungeonEnhancementManager::LoadAffixData()
    {
        LogInfo(LogCategory::GENERAL, "Loading affix data from database...");
        
        _affixes.clear();
        
        try
        {
            QueryResult result = WorldDatabase.Query(
                "SELECT affix_id, affix_name, affix_description, affix_type, min_keystone_level, "
                "is_active, spell_id, hp_modifier_percent, damage_modifier_percent, special_mechanic "
                "FROM {} WHERE is_active = 1",
                Tables::AFFIXES
            );
            
            if (!result)
            {
                LogWarn(LogCategory::AFFIXES, "No affixes found in database");
                return;
            }
            
            do
            {
                Field* fields = result->Fetch();
                AffixData affix;
                
                affix.affixId = fields[0].Get<uint32>();
                affix.affixName = fields[1].Get<std::string>();
                affix.affixDescription = fields[2].Get<std::string>();
                affix.affixType = fields[3].Get<std::string>();
                affix.minKeystoneLevel = fields[4].Get<uint8>();
                affix.isActive = fields[5].Get<bool>();
                affix.spellId = fields[6].Get<uint32>();
                affix.hpModifierPercent = fields[7].Get<float>();
                affix.damageModifierPercent = fields[8].Get<float>();
                affix.specialMechanic = fields[9].Get<std::string>();
                
                _affixes[affix.affixId] = affix;
                
            } while (result->NextRow());
            
            LogInfo(LogCategory::AFFIXES, "Loaded %u affixes from database", 
                    static_cast<uint32>(_affixes.size()));
        }
        catch (const std::exception& e)
        {
            LogError(LogCategory::AFFIXES, "Failed to load affix data: %s", e.what());
        }
    }

    void DungeonEnhancementManager::LoadAffixRotations()
    {
        LogInfo(LogCategory::GENERAL, "Loading affix rotations from database...");
        
        _affixRotations.clear();
        _currentRotation = nullptr;
        
        if (!_currentSeason)
        {
            LogWarn(LogCategory::AFFIXES, "No active season - skipping affix rotations");
            return;
        }
        
        try
        {
            QueryResult result = WorldDatabase.Query(
                "SELECT rotation_id, season_id, week_number, tier1_affix_id, tier2_affix_id, "
                "tier3_affix_id, start_timestamp, end_timestamp "
                "FROM {} WHERE season_id = {} ORDER BY week_number",
                Tables::AFFIX_ROTATION, _currentSeason->seasonId
            );
            
            if (!result)
            {
                LogWarn(LogCategory::AFFIXES, "No affix rotations found for season %u", 
                        _currentSeason->seasonId);
                return;
            }
            
            uint32 currentTime = static_cast<uint32>(std::time(nullptr));
            
            do
            {
                Field* fields = result->Fetch();
                AffixRotation rotation;
                
                rotation.rotationId = fields[0].Get<uint32>();
                rotation.seasonId = fields[1].Get<uint32>();
                rotation.weekNumber = fields[2].Get<uint8>();
                rotation.tier1AffixId = fields[3].Get<uint32>();
                rotation.tier2AffixId = fields[4].Get<uint32>();
                rotation.tier3AffixId = fields[5].Get<uint32>();
                rotation.startTimestamp = fields[6].Get<uint32>();
                rotation.endTimestamp = fields[7].Get<uint32>();
                
                _affixRotations.push_back(rotation);
                
                // Check if this is the current active rotation
                if (currentTime >= rotation.startTimestamp && currentTime <= rotation.endTimestamp)
                {
                    _currentRotation = &_affixRotations.back();
                    LogInfo(LogCategory::AFFIXES, "Current rotation: Week %u (Tier1: %u, Tier2: %u, Tier3: %u)",
                            rotation.weekNumber, rotation.tier1AffixId, rotation.tier2AffixId, rotation.tier3AffixId);
                }
                
            } while (result->NextRow());
            
            LogInfo(LogCategory::AFFIXES, "Loaded %u affix rotations", 
                    static_cast<uint32>(_affixRotations.size()));
        }
        catch (const std::exception& e)
        {
            LogError(LogCategory::AFFIXES, "Failed to load affix rotations: %s", e.what());
        }
    }

    void DungeonEnhancementManager::RefreshAllCaches()
    {
        LogInfo(LogCategory::GENERAL, "Refreshing all caches...");
        LoadSeasonData();
        LoadDungeonConfigs();
        LoadAffixData();
        LoadAffixRotations();
        _lastCacheRefreshTime = static_cast<uint32>(std::time(nullptr));
    }

    void DungeonEnhancementManager::RefreshCacheIfNeeded()
    {
        uint32 currentTime = static_cast<uint32>(std::time(nullptr));
        uint32 timeSinceRefresh = currentTime - _lastCacheRefreshTime;
        
        // Refresh every 5 minutes minimum
        if (timeSinceRefresh >= CACHE_REFRESH_INTERVAL_DUNGEONS)
        {
            RefreshAllCaches();
        }
    }

    // ========================================================================
    // SEASON MANAGEMENT
    // ========================================================================
    
    SeasonData* DungeonEnhancementManager::GetCurrentSeason()
    {
        return _currentSeason;
    }

    SeasonData* DungeonEnhancementManager::GetSeasonById(uint32 seasonId)
    {
        auto it = _seasons.find(seasonId);
        return (it != _seasons.end()) ? &it->second : nullptr;
    }

    bool DungeonEnhancementManager::IsSeasonActive(uint32 seasonId) const
    {
        auto it = _seasons.find(seasonId);
        return (it != _seasons.end()) && it->second.isActive;
    }

    void DungeonEnhancementManager::StartNewSeason(uint32 seasonId)
    {
        try
        {
            // End current season
            if (_currentSeason)
            {
                WorldDatabase.Execute("UPDATE {} SET is_active = 0, end_timestamp = {} WHERE season_id = {}",
                                    Tables::SEASONS, static_cast<uint32>(std::time(nullptr)), _currentSeason->seasonId);
            }
            
            // Start new season
            WorldDatabase.Execute("UPDATE {} SET is_active = 1 WHERE season_id = {}", 
                                Tables::SEASONS, seasonId);
            
            // Refresh caches
            RefreshAllCaches();
            
            LogInfo(LogCategory::GENERAL, "Started new season: %u", seasonId);
        }
        catch (const std::exception& e)
        {
            LogError(LogCategory::GENERAL, "Failed to start new season: %s", e.what());
        }
    }

    void DungeonEnhancementManager::EndCurrentSeason()
    {
        if (!_currentSeason)
        {
            LogWarn(LogCategory::GENERAL, "No active season to end");
            return;
        }
        
        try
        {
            WorldDatabase.Execute("UPDATE {} SET is_active = 0, end_timestamp = {} WHERE season_id = {}",
                                Tables::SEASONS, static_cast<uint32>(std::time(nullptr)), _currentSeason->seasonId);
            
            LogInfo(LogCategory::GENERAL, "Ended season: %u (%s)", 
                    _currentSeason->seasonId, _currentSeason->seasonName.c_str());
            
            _currentSeason = nullptr;
        }
        catch (const std::exception& e)
        {
            LogError(LogCategory::GENERAL, "Failed to end season: %s", e.what());
        }
    }

    // ========================================================================
    // DUNGEON CONFIGURATION
    // ========================================================================
    
    DungeonConfig* DungeonEnhancementManager::GetDungeonConfig(uint16 mapId)
    {
        auto it = _dungeonConfigs.find(mapId);
        return (it != _dungeonConfigs.end()) ? &it->second : nullptr;
    }

    bool DungeonEnhancementManager::IsDungeonMythicPlusEnabled(uint16 mapId)
    {
        DungeonConfig* config = GetDungeonConfig(mapId);
        return config && config->isActive;
    }

    std::vector<DungeonConfig*> DungeonEnhancementManager::GetSeasonalDungeons(uint32 seasonId)
    {
        std::vector<DungeonConfig*> dungeons;
        
        for (auto& pair : _dungeonConfigs)
        {
            if (pair.second.seasonId == seasonId && pair.second.isActive)
            {
                dungeons.push_back(&pair.second);
            }
        }
        
        return dungeons;
    }

    float DungeonEnhancementManager::GetDungeonScalingMultiplier(uint16 mapId, uint8 keystoneLevel, bool isHp)
    {
        DungeonConfig* config = GetDungeonConfig(mapId);
        if (!config)
            return 1.0f;  // No scaling
        
        // Mythic+0 (no keystone)
        if (keystoneLevel == 0)
        {
            return isHp ? config->mythic0HpMultiplier : config->mythic0DamageMultiplier;
        }
        
        // Mythic+ (M+2 to M+10)
        if (keystoneLevel >= MYTHIC_PLUS_MIN_LEVEL && keystoneLevel <= MYTHIC_PLUS_MAX_LEVEL)
        {
            float baseMultiplier = isHp ? config->mythicPlusHpBase : config->mythicPlusDamageBase;
            float scalingPerLevel = config->mythicPlusScalingPerLevel;
            
            // Formula: base * (1 + (level - 2) * scalingPerLevel)
            return baseMultiplier * (1.0f + (keystoneLevel - MYTHIC_PLUS_MIN_LEVEL) * scalingPerLevel);
        }
        
        return 1.0f;  // Default (no scaling)
    }

    // ========================================================================
    // AFFIX SYSTEM
    // ========================================================================
    
    AffixData* DungeonEnhancementManager::GetAffixById(uint32 affixId)
    {
        auto it = _affixes.find(affixId);
        return (it != _affixes.end()) ? &it->second : nullptr;
    }

    AffixRotation* DungeonEnhancementManager::GetCurrentAffixRotation()
    {
        return _currentRotation;
    }

    std::vector<AffixData*> DungeonEnhancementManager::GetCurrentActiveAffixes(uint8 keystoneLevel)
    {
        std::vector<AffixData*> activeAffixes;
        
        if (!_currentRotation)
            return activeAffixes;
        
        // Tier 1: Always active (M+2+)
        if (keystoneLevel >= 2)
        {
            AffixData* tier1 = GetAffixById(_currentRotation->tier1AffixId);
            if (tier1)
                activeAffixes.push_back(tier1);
        }
        
        // Tier 2: M+4+
        if (keystoneLevel >= 4 && _currentRotation->tier2AffixId > 0)
        {
            AffixData* tier2 = GetAffixById(_currentRotation->tier2AffixId);
            if (tier2)
                activeAffixes.push_back(tier2);
        }
        
        // Tier 3: M+7+
        if (keystoneLevel >= 7 && _currentRotation->tier3AffixId > 0)
        {
            AffixData* tier3 = GetAffixById(_currentRotation->tier3AffixId);
            if (tier3)
                activeAffixes.push_back(tier3);
        }
        
        return activeAffixes;
    }

    bool DungeonEnhancementManager::IsAffixActiveThisWeek(uint32 affixId)
    {
        if (!_currentRotation)
            return false;
        
        return (_currentRotation->tier1AffixId == affixId ||
                _currentRotation->tier2AffixId == affixId ||
                _currentRotation->tier3AffixId == affixId);
    }

    void DungeonEnhancementManager::ApplyAffixToCreature(Creature* creature, uint8 keystoneLevel)
    {
        if (!creature || keystoneLevel < MYTHIC_PLUS_MIN_LEVEL)
            return;
        
        std::vector<AffixData*> affixes = GetCurrentActiveAffixes(keystoneLevel);
        
        for (AffixData* affix : affixes)
        {
            if (!affix)
                continue;
            
            // Apply HP modifier
            if (affix->hpModifierPercent > 0.0f)
            {
                float hpMultiplier = 1.0f + (affix->hpModifierPercent / 100.0f);
                creature->SetMaxHealth(static_cast<uint32>(creature->GetMaxHealth() * hpMultiplier));
                creature->SetHealth(creature->GetMaxHealth());
            }
            
            // Apply damage modifier
            if (affix->damageModifierPercent > 0.0f)
            {
                // Note: Damage modifier applied in combat hooks
                // Store in creature's data for later reference
            }
            
            // Apply spell/aura if defined
            if (affix->spellId > 0)
            {
                // creature->AddAura(affix->spellId, creature);
            }
            
            LogInfo(LogCategory::AFFIXES, "Applied affix '%s' to creature %u (Map %u)", 
                    affix->affixName.c_str(), creature->GetEntry(), creature->GetMapId());
        }
    }

    // ========================================================================
    // UTILITIES
    // ========================================================================
    
    std::string DungeonEnhancementManager::GetColoredMessage(const std::string& message, const char* colorCode)
    {
        return std::string(colorCode) + message + Colors::END;
    }

    void DungeonEnhancementManager::BroadcastToGroup(Player* player, const std::string& message)
    {
        if (!player)
            return;
        
        Group* group = player->GetGroup();
        if (!group)
        {
            SendSystemMessage(player, message);
            return;
        }
        
        for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
        {
            Player* member = itr->GetSource();
            if (member)
            {
                SendSystemMessage(member, message);
            }
        }
    }

    void DungeonEnhancementManager::SendSystemMessage(Player* player, const std::string& message)
    {
        if (player)
        {
            player->GetSession()->SendAreaTriggerMessage("%s", message.c_str());
        }
    }

    void DungeonEnhancementManager::LogInfo(const char* category, const char* format, ...)
    {
        va_list args;
        va_start(args, format);
        char buffer[1024];
        vsnprintf(buffer, sizeof(buffer), format, args);
        va_end(args);
        
        LOG_INFO(category, "%s", buffer);
    }

    void DungeonEnhancementManager::LogWarn(const char* category, const char* format, ...)
    {
        va_list args;
        va_start(args, format);
        char buffer[1024];
        vsnprintf(buffer, sizeof(buffer), format, args);
        va_end(args);
        
        LOG_WARN(category, "%s", buffer);
    }

    void DungeonEnhancementManager::LogError(const char* category, const char* format, ...)
    {
        va_list args;
        va_start(args, format);
        char buffer[1024];
        vsnprintf(buffer, sizeof(buffer), format, args);
        va_end(args);
        
        LOG_ERROR(category, "%s", buffer);
    }

    // ========================================================================
    // KEYSTONE MANAGEMENT (Stubs - to be implemented)
    // ========================================================================
    
    bool DungeonEnhancementManager::PlayerHasKeystone(Player* player)
    {
        if (!player)
            return false;
        
        // Check if player has any keystone item (100000-100008)
        for (uint32 itemId = ITEM_KEYSTONE_BASE; itemId <= ITEM_KEYSTONE_M10; ++itemId)
        {
            if (player->HasItemCount(itemId, 1))
                return true;
        }
        
        return false;
    }

    uint8 DungeonEnhancementManager::GetPlayerKeystoneLevel(Player* player)
    {
        if (!player)
            return 0;
        
        // Check each keystone level
        for (uint8 level = MYTHIC_PLUS_MIN_LEVEL; level <= MYTHIC_PLUS_MAX_LEVEL; ++level)
        {
            uint32 itemId = ITEM_KEYSTONE_BASE + (level - MYTHIC_PLUS_MIN_LEVEL);
            if (player->HasItemCount(itemId, 1))
                return level;
        }
        
        return 0;  // No keystone
    }

    bool DungeonEnhancementManager::GivePlayerKeystone(Player* player, uint8 keystoneLevel)
    {
        if (!player || keystoneLevel < MYTHIC_PLUS_MIN_LEVEL || keystoneLevel > MYTHIC_PLUS_MAX_LEVEL)
            return false;
        
        // Remove any existing keystone first
        RemovePlayerKeystone(player);
        
        uint32 itemId = ITEM_KEYSTONE_BASE + (keystoneLevel - MYTHIC_PLUS_MIN_LEVEL);
        ItemPosCountVec dest;
        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1);
        
        if (msg == EQUIP_ERR_OK)
        {
            Item* item = player->StoreNewItem(dest, itemId, true);
            if (item)
            {
                player->SendNewItem(item, 1, true, false);
                LogInfo(LogCategory::MYTHIC_PLUS, "Player %s received M+%u keystone", 
                        player->GetName().c_str(), keystoneLevel);
                return true;
            }
        }
        
        return false;
    }

    bool DungeonEnhancementManager::RemovePlayerKeystone(Player* player)
    {
        if (!player)
            return false;
        
        bool removed = false;
        
        // Remove all keystone items
        for (uint32 itemId = ITEM_KEYSTONE_BASE; itemId <= ITEM_KEYSTONE_M10; ++itemId)
        {
            if (player->HasItemCount(itemId, 1))
            {
                player->DestroyItemCount(itemId, 1, true);
                removed = true;
            }
        }
        
        return removed;
    }

    bool DungeonEnhancementManager::UpgradePlayerKeystone(Player* player, uint8 newLevel)
    {
        if (!player || newLevel > MYTHIC_PLUS_MAX_LEVEL)
            return false;
        
        return GivePlayerKeystone(player, newLevel);
    }

    bool DungeonEnhancementManager::DowngradePlayerKeystone(Player* player)
    {
        uint8 currentLevel = GetPlayerKeystoneLevel(player);
        if (currentLevel <= MYTHIC_PLUS_MIN_LEVEL)
            return false;  // Can't downgrade below M+2
        
        return GivePlayerKeystone(player, currentLevel - 1);
    }

    // ========================================================================
    // VAULT SYSTEM
    // ========================================================================
    
    uint8 DungeonEnhancementManager::GetPlayerVaultProgress(Player* player)
    {
        if (!player)
            return 0;

        SeasonData* season = GetCurrentSeason();
        if (!season)
            return 0;

        QueryResult result = CharacterDatabase.Query(
            "SELECT completedDungeons FROM dc_mythic_vault_progress "
            "WHERE playerGUID = {} AND seasonId = {}",
            player->GetGUID().GetCounter(), season->seasonId
        );

        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint8>();
        }

        return 0;
    }

    bool DungeonEnhancementManager::IncrementPlayerVaultProgress(Player* player, uint8 keystoneLevel)
    {
        if (!player || keystoneLevel < MYTHIC_PLUS_MIN_LEVEL)
            return false;

        SeasonData* season = GetCurrentSeason();
        if (!season)
            return false;

        // Insert or update vault progress
        CharacterDatabase.Execute(
            "INSERT INTO dc_mythic_vault_progress (playerGUID, seasonId, completedDungeons, lastResetDate) "
            "VALUES ({}, {}, 1, NOW()) "
            "ON DUPLICATE KEY UPDATE "
            "completedDungeons = LEAST(completedDungeons + 1, 8), "
            "lastResetDate = NOW()",
            player->GetGUID().GetCounter(), season->seasonId
        );

        LOG_DEBUG("dungeon.enhancement.vault",
                  "Incremented vault progress for player {} (GUID {})",
                  player->GetName(), player->GetGUID().GetCounter());

        return true;
    }

    bool DungeonEnhancementManager::CanClaimVaultSlot(Player* player, uint8 slotNumber)
    {
        if (!player || slotNumber < 1 || slotNumber > 3)
            return false;

        uint8 vaultProgress = GetPlayerVaultProgress(player);

        // Slot 1 = 1 dungeon, Slot 2 = 4 dungeons, Slot 3 = 8 dungeons
        uint8 requiredDungeons = (slotNumber == 1) ? 1 : (slotNumber == 2) ? 4 : 8;

        if (vaultProgress < requiredDungeons)
            return false;

        // Check if slot already claimed
        SeasonData* season = GetCurrentSeason();
        if (!season)
            return false;

        std::string slotColumn = "slot" + std::to_string(slotNumber) + "Claimed";

        QueryResult result = CharacterDatabase.Query(
            "SELECT {} FROM dc_mythic_vault_progress "
            "WHERE playerGUID = {} AND seasonId = {}",
            slotColumn, player->GetGUID().GetCounter(), season->seasonId
        );

        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint8>() == 0; // Not yet claimed
        }

        return true; // No record means not claimed
    }

    uint16 DungeonEnhancementManager::GetVaultTokenReward(uint8 slotNumber, uint8 highestKeystoneLevel)
    {
        // Determine tier based on highest keystone level completed
        uint8 tier = 1; // Low tier
        if (highestKeystoneLevel >= 7)
            tier = 3; // High tier
        else if (highestKeystoneLevel >= 4)
            tier = 2; // Medium tier

        QueryResult result = WorldDatabase.Query(
            "SELECT tokenAmount FROM dc_mythic_vault_rewards "
            "WHERE slotId = {} AND tier = {}",
            slotNumber, tier
        );

        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint16>();
        }

        // Fallback default values
        return 50 * slotNumber * tier;
    }

    void DungeonEnhancementManager::ResetWeeklyVaultProgress()
    {
        SeasonData* season = GetCurrentSeason();
        if (!season)
            return;

        // Reset all vault progress for current season
        CharacterDatabase.Execute(
            "UPDATE dc_mythic_vault_progress "
            "SET completedDungeons = 0, slot1Claimed = 0, slot2Claimed = 0, slot3Claimed = 0, lastResetDate = NOW() "
            "WHERE seasonId = {}",
            season->seasonId
        );

        LOG_INFO("dungeon.enhancement.vault", 
                 "Weekly vault progress reset for season {}", season->seasonId);
    }

    void DungeonEnhancementManager::ResetWeeklyVaultProgress(Player* player)
    {
        if (!player)
            return;

        SeasonData* season = GetCurrentSeason();
        if (!season)
            return;

        // Reset specific player's vault progress
        CharacterDatabase.Execute(
            "UPDATE dc_mythic_vault_progress "
            "SET completedDungeons = 0, slot1Claimed = 0, slot2Claimed = 0, slot3Claimed = 0, lastResetDate = NOW() "
            "WHERE playerGUID = {} AND seasonId = {}",
            player->GetGUID().GetCounter(), season->seasonId
        );

        LOG_DEBUG("dungeon.enhancement.vault",
                  "Reset vault progress for player {} (GUID {})",
                  player->GetName(), player->GetGUID().GetCounter());
    }

    // ========================================================================
    // RATING & TOKEN REWARDS
    // ========================================================================
    
    uint32 DungeonEnhancementManager::GetPlayerRating(Player* player, uint32 seasonId)
    {
        if (!player)
            return 0;

        // If no seasonId specified, use current season
        if (seasonId == 0)
        {
            SeasonData* season = GetCurrentSeason();
            if (!season)
                return 0;
            seasonId = season->seasonId;
        }

        QueryResult result = CharacterDatabase.Query(
            "SELECT rating FROM dc_mythic_player_rating "
            "WHERE playerGUID = {} AND seasonId = {}",
            player->GetGUID().GetCounter(), seasonId
        );

        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }

        return 0;
    }

    void DungeonEnhancementManager::UpdatePlayerRating(Player* player, uint32 seasonId, uint32 newRating)
    {
        if (!player || seasonId == 0)
            return;

        // Determine rank based on rating
        std::string rank = "Unranked";
        if (newRating >= 2000)
            rank = "Mythic";
        else if (newRating >= 1500)
            rank = "Heroic";
        else if (newRating >= 1000)
            rank = "Advanced";
        else if (newRating >= 500)
            rank = "Novice";

        // Insert or update rating
        CharacterDatabase.Execute(
            "INSERT INTO dc_mythic_player_rating (playerGUID, seasonId, rating, rank, lastUpdated) "
            "VALUES ({}, {}, {}, '{}', NOW()) "
            "ON DUPLICATE KEY UPDATE "
            "rating = {}, rank = '{}', lastUpdated = NOW()",
            player->GetGUID().GetCounter(), seasonId, newRating, rank,
            newRating, rank
        );

        LOG_DEBUG("dungeon.enhancement.rating",
                  "Updated rating for player {} (GUID {}): {} ({})",
                  player->GetName(), player->GetGUID().GetCounter(), newRating, rank);
    }

    uint32 DungeonEnhancementManager::CalculateRatingGain(uint8 keystoneLevel, uint32 deathCount, uint32 timeTaken)
    {
        // Base rating formula: keystoneLevel * 10
        uint32 baseRating = keystoneLevel * 10;

        // Bonus for low deaths (0-2 deaths = +50%, 3-5 deaths = +25%)
        float deathMultiplier = 1.0f;
        if (deathCount <= 2)
            deathMultiplier = 1.5f;
        else if (deathCount <= 5)
            deathMultiplier = 1.25f;
        else if (deathCount >= 10)
            deathMultiplier = 0.75f; // Penalty for high deaths

        // Time bonus (placeholder - would need timer thresholds per dungeon)
        // For now, just use death multiplier
        
        uint32 finalRating = static_cast<uint32>(baseRating * deathMultiplier);

        return finalRating;
    }

    uint16 DungeonEnhancementManager::GetDungeonTokenReward(uint16 mapId, uint8 keystoneLevel, bool failedWith15Deaths)
    {
        DungeonConfig* config = GetDungeonConfig(mapId);
        if (!config)
            return 0;
        
        uint16 baseReward = config->baseTokenReward;
        uint16 scalingPerLevel = config->tokenScalingPerLevel;
        
        // Calculate tokens: base + (level - 2) * scaling
        uint16 totalTokens = baseReward + ((keystoneLevel - MYTHIC_PLUS_MIN_LEVEL) * scalingPerLevel);
        
        // Apply penalty if failed with 15 deaths
        if (failedWith15Deaths)
        {
            totalTokens = static_cast<uint16>(totalTokens * DEATH_PENALTY_TOKEN_MULTIPLIER);
        }
        
        return totalTokens;
    }

    void DungeonEnhancementManager::AwardDungeonTokens(Player* player, uint16 amount)
    {
        if (!player || amount == 0)
            return;
        
        ItemPosCountVec dest;
        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, ITEM_MYTHIC_DUNGEON_TOKEN, amount);
        
        if (msg == EQUIP_ERR_OK)
        {
            Item* item = player->StoreNewItem(dest, ITEM_MYTHIC_DUNGEON_TOKEN, true);
            if (item)
            {
                player->SendNewItem(item, amount, true, false);
                std::string message = GetColoredMessage(
                    "You received " + std::to_string(amount) + " Mythic Dungeon Tokens!",
                    Colors::GREEN
                );
                SendSystemMessage(player, message);
            }
        }
    }

    void DungeonEnhancementManager::AwardRaidTokens(Player* player, uint16 amount)
    {
        if (!player || amount == 0)
            return;
        
        ItemPosCountVec dest;
        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, ITEM_MYTHIC_RAID_TOKEN, amount);
        
        if (msg == EQUIP_ERR_OK)
        {
            Item* item = player->StoreNewItem(dest, ITEM_MYTHIC_RAID_TOKEN, true);
            if (item)
            {
                player->SendNewItem(item, amount, true, false);
                std::string message = GetColoredMessage(
                    "You received " + std::to_string(amount) + " Mythic Raid Tokens!",
                    Colors::GREEN
                );
                SendSystemMessage(player, message);
            }
        }
    }

} // namespace DungeonEnhancement
