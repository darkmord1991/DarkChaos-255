/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#ifndef DC_MYTHICPLUS_DIFFICULTY_SCALING_H
#define DC_MYTHICPLUS_DIFFICULTY_SCALING_H

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

// Cached row of world.dc_dungeon_setup. Held in memory because the featured
// check sits on player-entry and gossip paths that used to issue a synchronous
// query per call, from two separate copies of the same SQL.
struct DungeonSetupEntry
{
    bool unlocked = false;
    bool mythicPlusEnabled = false;
    uint32 seasonLock = 0;
};

class MythicDifficultyScaling
{
public:
    static MythicDifficultyScaling* instance();

    // Initialize and load dungeon profiles from database
    void LoadDungeonProfiles();

    // Get dungeon profile for a given map
    DungeonProfile* GetDungeonProfile(uint32 mapId);

    // Check if keystone is active for Mythic+ scaling
    uint32 GetKeystoneLevel(Map* map);

    // Look up Mythic+ multipliers for a keystone level. Const and allocation
    // free: the whole curve is precomputed at load so this can be called from
    // the damage path on several map threads at once.
    void CalculateMythicPlusMultipliers(uint32 keystoneLevel, float& hpMult, float& damageMult) const;

    // Normalizes dungeon difficulty detection (accounts for spawn mode fallback)
    Difficulty ResolveDungeonDifficulty(Map* map) const;

    // Cached dc_dungeon_setup lookup: is this dungeon unlocked, M+ enabled and
    // either unrestricted or locked to the given season?
    bool IsDungeonFeatured(uint32 mapId, uint32 seasonId) const;

    uint32 GetActiveSeasonId() const { return _activeSeasonId; }

private:
    MythicDifficultyScaling() = default;
    std::unordered_map<uint32, DungeonProfile> _dungeonProfiles;
    std::unordered_map<uint32, DungeonSetupEntry> _dungeonSetup;
    uint32 _activeSeasonId = 0;
    std::unordered_map<uint32, std::pair<float, float>> _scalingMultipliers;

    // Helper to determine expansion from map ID
    static uint8 GetExpansionForMap(uint32 mapId);
    void LoadScalingMultipliers();
    void LoadDungeonSetup();
};

#define sMythicScaling MythicDifficultyScaling::instance()

#endif // DC_MYTHICPLUS_DIFFICULTY_SCALING_H
