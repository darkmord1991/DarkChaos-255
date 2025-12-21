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
#include <unordered_map>
#include <unordered_set>
#include <utility>

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
    float mythicHealthMult;    // 3.0 for Vanilla/TBC, 1.35 for WotLK
    float mythicDamageMult;    // 2.0 for Vanilla/TBC, 1.20 for WotLK
    uint8 heroicLevelNormal;   // 0 = keep original level
    uint8 heroicLevelElite;    // 0 = keep original level
    uint8 heroicLevelBoss;     // 0 = keep original level
    uint8 mythicLevelNormal;   // 0 = keep original level
    uint8 mythicLevelElite;    // 0 = keep original level
    uint8 mythicLevelBoss;     // 0 = keep original level
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

    // Normalizes dungeon difficulty detection (accounts for spawn mode fallback)
    Difficulty ResolveDungeonDifficulty(Map* map) const;

    uint32 GetActiveSeasonId() const { return _activeSeasonId; }

private:
    MythicDifficultyScaling() = default;
    std::unordered_map<uint32, DungeonProfile> _dungeonProfiles;
    struct KeystoneCacheEntry
    {
        uint32 level = 0;
        uint64 lastUpdate = 0;
    };
    std::unordered_map<uint64, KeystoneCacheEntry> _activeKeystoneCache;
    uint32 _activeSeasonId = 0;
    uint32 _keystoneCacheTtlSeconds = 15;
    std::unordered_map<uint32, std::pair<float, float>> _scalingMultipliers;

    // Helper to determine expansion from map ID
    uint8 GetExpansionForMap(uint32 mapId);
    uint32 ResolveKeystoneLevel(Map* map);
    Player* GetPreferredKeystoneHolder(Map* map) const;
    uint32 QueryPlayerKeystone(uint32 playerGuidLow, uint32 mapId) const;
    uint64 MakeInstanceKey(Map* map) const;
    void LoadScalingMultipliers();
};

#define sMythicScaling MythicDifficultyScaling::instance()

#endif // MYTHIC_DIFFICULTY_SCALING_H
