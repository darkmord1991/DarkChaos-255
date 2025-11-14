/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "MythicDifficultyScaling.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectMgr.h"
#include <cmath>

MythicDifficultyScaling* MythicDifficultyScaling::instance()
{
    static MythicDifficultyScaling instance;
    return &instance;
}

void MythicDifficultyScaling::LoadDungeonProfiles()
{
    LOG_INFO("server.loading", "Loading Mythic+ dungeon profiles...");
    
    _dungeonProfiles.clear();
    
    QueryResult result = WorldDatabase.Query("SELECT map_id, name, heroic_enabled, mythic_enabled, "
                                             "base_health_mult, base_damage_mult, death_budget, wipe_budget, "
                                             "loot_ilvl, token_reward FROM dc_dungeon_mythic_profile");
    
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
        profile.deathBudget = fields[6].Get<uint8>();
        profile.wipeBudget = fields[7].Get<uint8>();
        profile.lootItemLevel = fields[8].Get<uint32>();
        profile.tokenReward = fields[9].Get<uint32>();
        
        // Determine expansion from map ID
        profile.expansion = GetExpansionForMap(profile.mapId);
        
        // Set multipliers based on expansion (Option A with differentiated levels)
        if (profile.expansion == EXPANSION_VANILLA)
        {
            // Vanilla: Heroic at 60-62, Mythic at 80-82
            profile.heroicHealthMult = 1.15f;
            profile.heroicDamageMult = 1.10f;
            profile.mythicHealthMult = 3.0f;
            profile.mythicDamageMult = 2.0f;
        }
        else if (profile.expansion == EXPANSION_TBC)
        {
            // TBC: Heroic at 70, Mythic at 80-82
            profile.heroicHealthMult = 1.15f;
            profile.heroicDamageMult = 1.10f;
            profile.mythicHealthMult = 3.0f;
            profile.mythicDamageMult = 2.0f;
        }
        else // EXPANSION_WOTLK
        {
            // WotLK: Keep existing scaling, modest Mythic boost
            profile.heroicHealthMult = 1.15f;
            profile.heroicDamageMult = 1.10f;
            profile.mythicHealthMult = 1.8f;
            profile.mythicDamageMult = 1.8f;
        }
        
        _dungeonProfiles[profile.mapId] = profile;
        ++count;
        
    } while (result->NextRow());
    
    LOG_INFO("server.loading", ">> Loaded {} Mythic+ dungeon profiles", count);
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
    if (newLevel > 0)
        creature->SetLevel(newLevel);
    
    // Determine multipliers based on difficulty
    float hpMult = 1.0f;
    float damageMult = 1.0f;
    
    switch (difficulty)
    {
        case DIFFICULTY_NORMAL:
            // No additional scaling for Normal
            break;
            
        case DIFFICULTY_HEROIC:
            if (!profile->heroicEnabled)
                break;
            
            hpMult = profile->heroicHealthMult;
            damageMult = profile->heroicDamageMult;
            break;
            
        case DIFFICULTY_10_N: // Using this as Mythic (difficulty 3/Epic in some cores)
        case DIFFICULTY_25_N:
            if (!profile->mythicEnabled)
                break;
            
            hpMult = profile->mythicHealthMult;
            damageMult = profile->mythicDamageMult;
            
            // Check for Mythic+ keystone
            uint32 keystoneLevel = GetKeystoneLevel(map);
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
    ApplyMultipliers(creature, hpMult, damageMult);
    
    LOG_DEBUG("mythic.scaling", "Scaled creature {} (entry {}) on map {} to level {} with {}x HP, {}x Damage",
              creature->GetName(), creature->GetEntry(), map->GetId(), newLevel, hpMult, damageMult);
}

uint8 MythicDifficultyScaling::CalculateCreatureLevel(Creature* creature, Map* map, DungeonProfile* profile)
{
    if (!creature || !map || !profile)
        return 0;
    
    Difficulty difficulty = map->GetDifficulty();
    uint32 rank = creature->GetCreatureTemplate()->rank;
    
    // Determine if creature is boss, elite, or normal
    bool isBoss = (rank == CREATURE_ELITE_WORLDBOSS || rank == CREATURE_ELITE_RAREELITE);
    bool isElite = (rank == CREATURE_ELITE_ELITE);
    
    uint8 newLevel = 0;
    
    switch (difficulty)
    {
        case DIFFICULTY_NORMAL:
            // Normal: Keep original levels
            if (profile->expansion == EXPANSION_VANILLA)
                newLevel = isBoss ? 62 : (isElite ? 61 : 60);
            else if (profile->expansion == EXPANSION_TBC)
                newLevel = 70;
            else // WotLK
                newLevel = 80;
            break;
            
        case DIFFICULTY_HEROIC:
            // Heroic: Differentiated levels for Vanilla, same level for TBC/WotLK
            if (profile->expansion == EXPANSION_VANILLA)
            {
                // Vanilla Heroic: 60/61/62 (Option A with differentiated levels)
                newLevel = isBoss ? 62 : (isElite ? 61 : 60);
            }
            else if (profile->expansion == EXPANSION_TBC)
            {
                // TBC Heroic: Stay at 70
                newLevel = 70;
            }
            else // WotLK
            {
                // WotLK Heroic: Stay at 80
                newLevel = 80;
            }
            break;
            
        case DIFFICULTY_10_N: // Mythic
        case DIFFICULTY_25_N:
            // Mythic: All content scales to 80-82
            newLevel = isBoss ? 82 : (isElite ? 81 : 80);
            break;
            
        default:
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
    
    // TODO: Implement keystone tracking in InstanceScript
    // For now, check instance data for stored keystone level
    
    InstanceScript* instance = map->GetInstanceScript();
    if (!instance)
        return 0;
    
    // Placeholder: Retrieve keystone level from instance data
    // This will be set when keystone is activated via Font of Power
    return instance->GetData(DATA_KEYSTONE_LEVEL); // Need to define DATA_KEYSTONE_LEVEL
}

void MythicDifficultyScaling::CalculateMythicPlusMultipliers(uint32 keystoneLevel, float& hpMult, float& damageMult)
{
    if (keystoneLevel == 0)
    {
        hpMult = 1.0f;
        damageMult = 1.0f;
        return;
    }
    
    // Mythic+ scaling: +15% HP, +12% Damage per level (multiplicative)
    // Formula: Multiplier = 1.15^level for HP, 1.12^level for Damage
    hpMult = std::pow(1.15f, static_cast<float>(keystoneLevel));
    damageMult = std::pow(1.12f, static_cast<float>(keystoneLevel));
}
