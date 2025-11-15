/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "MythicDifficultyScaling.h"
#include "MythicPlusRunManager.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Group.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "DC/DungeonQuests/DungeonQuestConstants.h"
#include <string>
#include <cmath>
#include <unordered_set>

MythicDifficultyScaling* MythicDifficultyScaling::instance()
{
    static MythicDifficultyScaling instance;
    return &instance;
}

void MythicDifficultyScaling::LoadDungeonProfiles()
{
    LOG_INFO("server.loading", "Loading Mythic+ dungeon profiles...");
    
    _dungeonProfiles.clear();
    _activeKeystoneCache.clear();
    _activeSeasonId = 0;
    
    QueryResult result = WorldDatabase.Query("SELECT map_id, name, heroic_enabled, mythic_enabled, "
                                             "base_health_mult, base_damage_mult, "
                                             "heroic_level_normal, heroic_level_elite, heroic_level_boss, "
                                             "mythic_level_normal, mythic_level_elite, mythic_level_boss, "
                                             "death_budget, wipe_budget, loot_ilvl, token_reward "
                                             "FROM dc_dungeon_mythic_profile");
    
    if (!result)
    {
        LOG_WARN("server.loading", ">> No dungeon profiles found in dc_dungeon_mythic_profile");
        return;
    }
    
    uint32 count = 0;
    do
    {
        Field* fields = result->Fetch();
        DungeonProfile profile;
        
        profile.mapId = fields[0].Get<uint32>();
        profile.name = fields[1].Get<std::string>();
        profile.heroicEnabled = fields[2].Get<bool>();
        profile.mythicEnabled = fields[3].Get<bool>();
        profile.baseHealthMult = fields[4].Get<float>();
        profile.baseDamageMult = fields[5].Get<float>();
        profile.heroicLevelNormal = fields[6].Get<uint8>();
        profile.heroicLevelElite = fields[7].Get<uint8>();
        profile.heroicLevelBoss = fields[8].Get<uint8>();
        profile.mythicLevelNormal = fields[9].Get<uint8>();
        profile.mythicLevelElite = fields[10].Get<uint8>();
        profile.mythicLevelBoss = fields[11].Get<uint8>();
        profile.deathBudget = fields[12].Get<uint8>();
        profile.wipeBudget = fields[13].Get<uint8>();
        profile.lootItemLevel = fields[14].Get<uint32>();
        profile.tokenReward = fields[15].Get<uint32>();
        
        // Determine expansion from map ID
        profile.expansion = GetExpansionForMap(profile.mapId);
        
        // Set multipliers based on expansion and database values
        if (profile.expansion == EXPANSION_VANILLA)
        {
            // Vanilla: Heroic at 60-62, Mythic at 80-82
            profile.heroicHealthMult = 1.15f;
            profile.heroicDamageMult = 1.10f;
            // Use database multipliers for Mythic (base_health_mult/base_damage_mult)
            profile.mythicHealthMult = profile.baseHealthMult > 1.0f ? profile.baseHealthMult : 3.0f;
            profile.mythicDamageMult = profile.baseDamageMult > 1.0f ? profile.baseDamageMult : 2.0f;
        }
        else if (profile.expansion == EXPANSION_TBC)
        {
            // TBC: Heroic at 70, Mythic at 80-82
            profile.heroicHealthMult = 1.15f;
            profile.heroicDamageMult = 1.10f;
            // Use database multipliers for Mythic
            profile.mythicHealthMult = profile.baseHealthMult > 1.0f ? profile.baseHealthMult : 3.0f;
            profile.mythicDamageMult = profile.baseDamageMult > 1.0f ? profile.baseDamageMult : 2.0f;
        }
        else // EXPANSION_WOTLK
        {
            // WotLK: Keep existing scaling, modest Mythic boost
            profile.heroicHealthMult = 1.15f;
            profile.heroicDamageMult = 1.10f;
            // Use database multipliers for Mythic
            profile.mythicHealthMult = profile.baseHealthMult > 1.0f ? profile.baseHealthMult : 1.35f;
            profile.mythicDamageMult = profile.baseDamageMult > 1.0f ? profile.baseDamageMult : 1.20f;
        }
        
        _dungeonProfiles[profile.mapId] = profile;
        ++count;
        
    } while (result->NextRow());
    
    LOG_INFO("server.loading", ">> Loaded {} Mythic+ dungeon profiles", count);

    if (QueryResult season = WorldDatabase.Query("SELECT season_id FROM dc_mplus_seasons WHERE is_active = 1 ORDER BY start_ts DESC LIMIT 1"))
    {
        _activeSeasonId = (*season)[0].Get<uint32>();
        LOG_INFO("server.loading", ">> Active Mythic+ season detected (ID {})", _activeSeasonId);
    }
    else
    {
        LOG_WARN("server.loading", ">> No active Mythic+ season found in dc_mplus_seasons");
    }
}

DungeonProfile* MythicDifficultyScaling::GetDungeonProfile(uint32 mapId)
{
    auto itr = _dungeonProfiles.find(mapId);
    if (itr != _dungeonProfiles.end())
        return &itr->second;
    return nullptr;
}

uint8 MythicDifficultyScaling::GetExpansionForMap(uint32 mapId)
{
    // Vanilla dungeons (Classic map IDs)
    if (mapId >= 33 && mapId <= 560)
        return EXPANSION_VANILLA;
    
    // TBC dungeons (Outland map IDs)
    if ((mapId >= 530 && mapId <= 580) || mapId == 269 || mapId == 540 || mapId == 542 || 
        mapId == 543 || mapId == 545 || mapId == 546 || mapId == 547 || mapId == 548 || 
        mapId == 550 || mapId == 552 || mapId == 553 || mapId == 554 || mapId == 555 || 
        mapId == 556 || mapId == 557 || mapId == 558 || mapId == 560)
        return EXPANSION_TBC;
    
    // WotLK dungeons (Northrend map IDs)
    if (mapId >= 574 && mapId <= 650)
        return EXPANSION_WOTLK;
    
    return EXPANSION_WOTLK; // Default to WotLK
}

void MythicDifficultyScaling::ScaleCreature(Creature* creature, Map* map)
{
    if (!creature || !map)
        return;
    
    // Only scale in dungeons
    if (!map->IsDungeon())
        return;
    
    // Get dungeon profile
    DungeonProfile* profile = GetDungeonProfile(map->GetId());
    if (!profile)
        return; // No profile = no scaling
    
    Difficulty difficulty = map->GetDifficulty();
    
    // Calculate appropriate level
    uint8 newLevel = CalculateCreatureLevel(creature, map, profile);
    if (newLevel > 0 && newLevel != creature->GetLevel())
    {
        creature->SetLevel(newLevel);
        // Recalculate stats for new level
        creature->UpdateAllStats();
    }
    
    // Determine multipliers based on difficulty
    float hpMult = 1.0f;
    float damageMult = 1.0f;
    
    uint32 keystoneLevel = 0;

    switch (difficulty)
    {
        case DUNGEON_DIFFICULTY_NORMAL:
            // No additional scaling for Normal
            break;
            
        case DUNGEON_DIFFICULTY_HEROIC:
            if (!profile->heroicEnabled)
                break;
            
            hpMult = profile->heroicHealthMult;
            damageMult = profile->heroicDamageMult;
            break;
            
        case DUNGEON_DIFFICULTY_EPIC:
            if (!profile->mythicEnabled)
                break;
            
            hpMult = profile->mythicHealthMult;
            damageMult = profile->mythicDamageMult;
            
            // Check for Mythic+ keystone
            keystoneLevel = GetKeystoneLevel(map);
            if (keystoneLevel > 0)
            {
                float mplusHpMult = 1.0f;
                float mplusDamageMult = 1.0f;
                CalculateMythicPlusMultipliers(keystoneLevel, mplusHpMult, mplusDamageMult);
                
                hpMult *= mplusHpMult;
                damageMult *= mplusDamageMult;
            }
            break;
            
        default:
            break;
    }
    
    // Apply multipliers
    if (hpMult > 1.0f || damageMult > 1.0f)
    {
        ApplyMultipliers(creature, hpMult, damageMult);
        // Force update to apply changes immediately
        creature->UpdateAllStats();
    }
    
    LOG_INFO("mythic.scaling", "Scaled creature {} (entry {}) on map {} (difficulty {}) to level {} with {:.2f}x HP ({} -> {}), {:.2f}x Damage",
              creature->GetName(), creature->GetEntry(), map->GetId(), uint32(difficulty), newLevel, 
              hpMult, creature->GetCreateHealth(), creature->GetMaxHealth(), damageMult);
}

uint8 MythicDifficultyScaling::CalculateCreatureLevel(Creature* creature, Map* map, DungeonProfile* profile)
{
    if (!creature || !map || !profile)
        return 0;
    
    Difficulty difficulty = map->GetDifficulty();
    uint32 rank = creature->GetCreatureTemplate()->rank;
    uint8 originalLevel = creature->GetLevel();
    
    // Determine if creature is boss, elite, or normal
    bool isBoss = (rank == CREATURE_ELITE_WORLDBOSS || rank == CREATURE_ELITE_RAREELITE);
    bool isElite = (rank == CREATURE_ELITE_ELITE);
    
    uint8 newLevel = originalLevel; // Default: keep original level
    
    switch (difficulty)
    {
        case DUNGEON_DIFFICULTY_NORMAL:
            // Normal: Always keep original creature levels
            newLevel = originalLevel;
            break;
            
        case DUNGEON_DIFFICULTY_HEROIC:
            // Heroic: Use database configured levels (0 = keep original)
            if (isBoss && profile->heroicLevelBoss > 0)
                newLevel = profile->heroicLevelBoss;
            else if (isElite && profile->heroicLevelElite > 0)
                newLevel = profile->heroicLevelElite;
            else if (profile->heroicLevelNormal > 0)
                newLevel = profile->heroicLevelNormal;
            else
                newLevel = originalLevel; // Keep original if configured as 0
            break;
            
        case DUNGEON_DIFFICULTY_EPIC:
            // Mythic: Use database configured levels (0 = keep original)
            if (isBoss && profile->mythicLevelBoss > 0)
                newLevel = profile->mythicLevelBoss;
            else if (isElite && profile->mythicLevelElite > 0)
                newLevel = profile->mythicLevelElite;
            else if (profile->mythicLevelNormal > 0)
                newLevel = profile->mythicLevelNormal;
            else
                newLevel = originalLevel; // Keep original if configured as 0
            break;
            
        default:
            newLevel = originalLevel;
            break;
    }
    
    return newLevel;
}

void MythicDifficultyScaling::ApplyMultipliers(Creature* creature, float hpMult, float damageMult)
{
    if (!creature || hpMult <= 0.0f || damageMult <= 0.0f)
        return;
    
    // Apply HP multiplier
    uint32 baseHealth = creature->GetCreateHealth();
    uint32 newHealth = static_cast<uint32>(baseHealth * hpMult);
    creature->SetCreateHealth(newHealth);
    creature->SetMaxHealth(newHealth);
    creature->SetHealth(newHealth);
    
    // Apply damage multiplier
    float baseDamage = creature->GetModifierValue(UNIT_MOD_DAMAGE_MAINHAND, BASE_VALUE);
    float newDamage = baseDamage * damageMult;
    creature->SetModifierValue(UNIT_MOD_DAMAGE_MAINHAND, BASE_VALUE, newDamage);
    
    // Also scale off-hand if exists
    float baseOffhandDamage = creature->GetModifierValue(UNIT_MOD_DAMAGE_OFFHAND, BASE_VALUE);
    if (baseOffhandDamage > 0.0f)
    {
        float newOffhandDamage = baseOffhandDamage * damageMult;
        creature->SetModifierValue(UNIT_MOD_DAMAGE_OFFHAND, BASE_VALUE, newOffhandDamage);
    }
}

uint32 MythicDifficultyScaling::GetKeystoneLevel(Map* map)
{
    if (!map)
        return 0;

    return sMythicRuns->GetKeystoneLevel(map);
}

void MythicDifficultyScaling::CalculateMythicPlusMultipliers(uint32 keystoneLevel, float& hpMult, float& damageMult)
{
    if (keystoneLevel == 0 || keystoneLevel < 2)
    {
        hpMult = 1.0f;
        damageMult = 1.0f;
        return;
    }
    
    // Load scaling multipliers from database
    QueryResult result = WorldDatabase.Query(
        "SELECT hpMultiplier, damageMultiplier FROM dc_mythic_scaling_multipliers WHERE keystoneLevel = {}",
        keystoneLevel);
    
    if (result)
    {
        Field* fields = result->Fetch();
        hpMult = fields[0].Get<float>();
        damageMult = fields[1].Get<float>();
    }
    else
    {
        // Fallback: if not in database, calculate exponentially from M+15 baseline (2.96x)
        // Approximately +10% per level beyond defined values
        constexpr float M15_BASELINE = 2.96f;
        hpMult = damageMult = M15_BASELINE * std::pow(1.10f, static_cast<float>(keystoneLevel - 15));
        LOG_WARN("mythic.scaling", "Scaling multipliers not found for keystoneLevel {}, using exponential fallback: {}", 
                 keystoneLevel, hpMult);
    }
}

