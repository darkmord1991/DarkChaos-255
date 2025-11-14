/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#ifndef MYTHIC_DIFFICULTY_SCALING_H
#define MYTHIC_DIFFICULTY_SCALING_H

#include "ScriptMgr.h"
#include "Creature.h"
#include "Map.h"
#include "InstanceScript.h"
#include "Player.h"

enum Expansion : uint8
{
    EXPANSION_VANILLA = 0,
    EXPANSION_TBC     = 1,
    EXPANSION_WOTLK   = 2
};

struct DungeonProfile
{
    uint32 mapId;
    std::string name;
    uint8 expansion;
    bool heroicEnabled;
    bool mythicEnabled;
    float baseHealthMult;
    float baseDamageMult;
    float heroicHealthMult;    // 1.15 for Option A
    float heroicDamageMult;    // 1.10 for Option A
    float mythicHealthMult;    // 3.0 for Vanilla/TBC, 1.8 for WotLK
    float mythicDamageMult;    // 2.0 for Vanilla/TBC, 1.8 for WotLK
    uint8 deathBudget;
    uint8 wipeBudget;
    uint32 lootItemLevel;
    uint32 tokenReward;
};

class MythicDifficultyScaling
{
public:
    static MythicDifficultyScaling* instance();
    
    // Initialize and load dungeon profiles from database
    void LoadDungeonProfiles();
    
    // Get dungeon profile for a given map
    DungeonProfile* GetDungeonProfile(uint32 mapId);
    
    // Main scaling function called on creature spawn
    void ScaleCreature(Creature* creature, Map* map);
    
    // Calculate appropriate level based on difficulty and creature rank
    uint8 CalculateCreatureLevel(Creature* creature, Map* map, DungeonProfile* profile);
    
    // Apply HP and damage multipliers
    void ApplyMultipliers(Creature* creature, float hpMult, float damageMult);
    
    // Check if keystone is active for Mythic+ scaling
    uint32 GetKeystoneLevel(Map* map);
    
    // Calculate Mythic+ multipliers based on keystone level
    void CalculateMythicPlusMultipliers(uint32 keystoneLevel, float& hpMult, float& damageMult);
    
private:
    MythicDifficultyScaling() = default;
    std::unordered_map<uint32, DungeonProfile> _dungeonProfiles;
    
    // Helper to determine expansion from map ID
    uint8 GetExpansionForMap(uint32 mapId);
};

#define sMythicScaling MythicDifficultyScaling::instance()

#endif // MYTHIC_DIFFICULTY_SCALING_H
