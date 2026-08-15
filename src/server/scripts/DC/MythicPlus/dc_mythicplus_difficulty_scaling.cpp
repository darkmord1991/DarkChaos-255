/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "dc_mythicplus_difficulty_scaling.h"
#include "dc_mythicplus_run_manager.h"
#include "dc_mythicplus_constants.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Group.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "DC/DungeonQuests/DungeonQuestConstants.h"
#include "DC/Seasons/SeasonalSystem.h"
#include "DC/CrossSystem/CrossSystemSeasonHelper.h"
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

    LoadScalingMultipliers();
    LoadDungeonSetup();

    // Use unified season helper for consistent season ID across all systems
    _activeSeasonId = DarkChaos::GetActiveSeasonId();
    LOG_INFO("server.loading", ">> Active Mythic+ season (ID {})", _activeSeasonId);
}

namespace
{
// Fallback curve used for any keystone level the database does not define.
// Kept out of CalculateMythicPlusMultipliers so that function can stay const:
// it used to lazily insert misses into _scalingMultipliers, which meant the
// damage path mutated a shared unordered_map from several map threads.
float GetFallbackMultiplier(uint32 keystoneLevel)
{
    static constexpr float TABLE[] = {
        1.00f, 1.14f, 1.23f, 1.31f, 1.40f, 1.50f, 1.61f, 1.72f, 1.84f,
        2.02f, 2.22f, 2.45f, 2.69f, 2.96f, 3.26f, 3.58f, 3.94f, 4.33f, 4.76f
    };

    constexpr uint32 FIRST_LEVEL = 2;
    constexpr uint32 LAST_LEVEL = 20;
    constexpr float M20_BASELINE = 4.76f;

    if (keystoneLevel < FIRST_LEVEL)
        return 1.0f;

    if (keystoneLevel <= LAST_LEVEL)
        return TABLE[keystoneLevel - FIRST_LEVEL];

    // Continue growth beyond +20 at ~10% per level.
    int32 levelDelta = static_cast<int32>(keystoneLevel) - static_cast<int32>(LAST_LEVEL);
    float fallback = M20_BASELINE * std::pow(1.10f, static_cast<float>(levelDelta));
    return fallback < 1.0f ? 1.0f : fallback;
}

// Precompute up to here so a forced GM key (capped at 30) never misses.
constexpr uint32 MAX_PRECOMPUTED_KEYSTONE_LEVEL = 40;
}

void MythicDifficultyScaling::LoadScalingMultipliers()
{
    _scalingMultipliers.clear();

    uint32 dbRows = 0;
    if (QueryResult result = WorldDatabase.Query(
            "SELECT keystoneLevel, hpMultiplier, damageMultiplier FROM dc_mplus_scale_multipliers"))
    {
        do
        {
            Field* fields = result->Fetch();
            uint32 level = fields[0].Get<uint32>();
            float hp = fields[1].Get<float>();
            float damage = fields[2].Get<float>();
            _scalingMultipliers[level] = { hp, damage };
            ++dbRows;
        }
        while (result->NextRow());
    }
    else
    {
        LOG_WARN("server.loading", ">> No rows found in dc_mplus_scale_multipliers; fallback math will be used");
    }

    // Fill every remaining level now, on the world thread, so the map threads
    // only ever read from this map.
    uint32 filled = 0;
    for (uint32 level = MythicPlusConstants::MIN_KEYSTONE_LEVEL; level <= MAX_PRECOMPUTED_KEYSTONE_LEVEL; ++level)
    {
        if (_scalingMultipliers.find(level) != _scalingMultipliers.end())
            continue;

        float fallback = GetFallbackMultiplier(level);
        _scalingMultipliers[level] = { fallback, fallback };
        ++filled;
    }

    LOG_INFO("server.loading", ">> Cached {} Mythic+ scaling entries ({} from DB, {} from fallback curve)",
             _scalingMultipliers.size(), dbRows, filled);
}

void MythicDifficultyScaling::LoadDungeonSetup()
{
    _dungeonSetup.clear();

    QueryResult result = WorldDatabase.Query(
        "SELECT map_id, is_unlocked, mythic_plus_enabled, IFNULL(season_lock, 0) FROM dc_dungeon_setup");

    if (!result)
    {
        LOG_WARN("server.loading", ">> No rows found in dc_dungeon_setup; no dungeon will be treated as featured");
        return;
    }

    do
    {
        Field* fields = result->Fetch();
        DungeonSetupEntry entry;
        uint32 mapId = fields[0].Get<uint32>();
        entry.unlocked = fields[1].Get<bool>();
        entry.mythicPlusEnabled = fields[2].Get<bool>();
        entry.seasonLock = fields[3].Get<uint32>();
        _dungeonSetup[mapId] = entry;
    }
    while (result->NextRow());

    LOG_INFO("server.loading", ">> Cached {} dc_dungeon_setup rows", _dungeonSetup.size());
}

bool MythicDifficultyScaling::IsDungeonFeatured(uint32 mapId, uint32 seasonId) const
{
    auto itr = _dungeonSetup.find(mapId);
    if (itr == _dungeonSetup.end())
        return false;

    DungeonSetupEntry const& entry = itr->second;
    bool seasonMatches = entry.seasonLock == 0 || entry.seasonLock == seasonId;
    return entry.unlocked && entry.mythicPlusEnabled && seasonMatches;
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
    // The previous version tested the Vanilla range (33-560) first, which
    // swallowed every TBC map and made the TBC branch below it unreachable;
    // anything outside both ranges (Black Temple 564, Gruul 565, Zul'Aman 568,
    // Sunwell 580) fell through to the WotLK default and received a fraction of
    // the intended Mythic scaling.
    //
    // Ranges cannot express this correctly: TBC and WotLK instance ids are
    // interleaved (580 and 585 are TBC, 574-578 are WotLK), so the TBC set is
    // enumerated explicitly.
    static const std::unordered_set<uint32> tbcMaps = {
        269, // The Black Morass
        540, // The Shattered Halls
        542, // The Blood Furnace
        543, // Hellfire Ramparts
        544, // Magtheridon's Lair
        545, // The Steamvault
        546, // The Underbog
        547, // The Slave Pens
        548, // Serpentshrine Cavern
        550, // Tempest Keep
        552, // The Arcatraz
        553, // The Botanica
        554, // The Mechanar
        555, // Shadow Labyrinth
        556, // Sethekk Halls
        557, // Mana-Tombs
        558, // Auchenai Crypts
        560, // Old Hillsbrad Foothills
        564, // Black Temple
        565, // Gruul's Lair
        568, // Zul'Aman
        580, // Sunwell Plateau
        585  // Magisters' Terrace
    };

    if (tbcMaps.find(mapId) != tbcMaps.end())
        return EXPANSION_TBC;

    // Vanilla: the classic instance block, which tops out at Dire Maul (429)
    // plus the level-60 raids that sit above it.
    if ((mapId >= 33 && mapId <= 429) || mapId == 469 || mapId == 509 || mapId == 531)
        return EXPANSION_VANILLA;

    return EXPANSION_WOTLK; // Northrend instances and anything unrecognised
}

// NOTE: ScaleCreature/CalculateCreatureLevel/ApplyMultipliers used to live here.
// They were an unreferenced second implementation of the scaling that
// MythicPlusCreatureScript already performs through the OnBeforeCreatureSelectLevel
// and OnCreatureSelectLevel hooks, and had drifted (they scaled UNIT_MOD_DAMAGE_*
// where the live path scales UNIT_FIELD_MINDAMAGE). Removed rather than kept as a
// trap for the next reader.

uint32 MythicDifficultyScaling::GetKeystoneLevel(Map* map)
{
    if (!map)
        return 0;

    return sMythicRuns->GetKeystoneLevel(map);
}

Difficulty MythicDifficultyScaling::ResolveDungeonDifficulty(Map* map) const
{
    if (!map)
        return DUNGEON_DIFFICULTY_NORMAL;

    Difficulty difficulty = map->GetDifficulty();
    if (difficulty <= DUNGEON_DIFFICULTY_EPIC)
        return difficulty;

    uint8 spawnMode = map->GetSpawnMode();
    if (spawnMode > DUNGEON_DIFFICULTY_EPIC)
        spawnMode = DUNGEON_DIFFICULTY_EPIC;

    return Difficulty(spawnMode);
}

void MythicDifficultyScaling::CalculateMythicPlusMultipliers(uint32 keystoneLevel, float& hpMult, float& damageMult) const
{
    if (keystoneLevel < MythicPlusConstants::MIN_KEYSTONE_LEVEL)
    {
        hpMult = 1.0f;
        damageMult = 1.0f;
        return;
    }

    if (auto itr = _scalingMultipliers.find(keystoneLevel); itr != _scalingMultipliers.end())
    {
        hpMult = itr->second.first;
        damageMult = itr->second.second;
        return;
    }

    // Beyond the precomputed range. Compute without touching the map: this runs
    // on the damage path across several map threads, so it must stay read-only.
    hpMult = damageMult = GetFallbackMultiplier(keystoneLevel);
}
