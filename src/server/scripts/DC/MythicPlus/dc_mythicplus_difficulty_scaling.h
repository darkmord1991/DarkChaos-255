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

// Blizzard's own normal -> heroic conversion for WotLK 5-player bosses,
// read straight out of the paired creature templates, where it is
// strikingly consistent:
//
//   Ingvar     HealthModifier 12.5 -> 19   DamageModifier 7.5 -> 13
//   Trollgore                 20   -> 32                  7.5 -> 13
//   Tharon'ja                 25   -> 38                  7.5 -> 13
//   King Ymiron               30   -> 42                  7.5 -> 13
//   Slad'ran                  15   -> 24                  7.5 -> 13
//
// Classic and TBC dungeons have no heroic template to read these from -
// 0 of ~700 Vanilla creature templates carry difficulty_entry_1 - so the
// factor is applied to the normal template instead, reproducing what the
// heroic template would have been.
constexpr float HEROIC_TEMPLATE_HEALTH_FACTOR = 1.55f;
constexpr float HEROIC_TEMPLATE_DAMAGE_FACTOR = 1.733f;

// Band the synthesised heroic DamageModifier is held inside on the
// Classic/TBC maps.
//
// The band has to be split by rank, because Blizzard's own heroic
// templates differ by an order of magnitude between elites and everything
// else, while the Classic templates do not differentiate at all. Averaged
// over the WotLK heroic dungeons:
//
//                    WotLK heroic    Gnomeregan (Classic)
//   rank 0 trash        1.0                1.70
//   rank 1 elite       12.9                1.70
//
// A single flat band is wrong in both directions - the first version of
// this used one floor of 8.0, which left non-elite Classic trash hitting
// eight times as hard as its WotLK counterpart while elites still landed
// at 62% of theirs.
//
// Bosses share the elite band: WotLK heroic bosses are uniformly 13.
//
// These are stopgap defaults, overridable in config. They only stop the
// extremes being trivial or lethal; they are NOT a substitute for
// per-dungeon tuning.
constexpr float LEGACY_DAMAGE_MOD_FLOOR_DEFAULT = 11.0f;
constexpr float LEGACY_DAMAGE_MOD_CEILING_DEFAULT = 16.0f;
constexpr float LEGACY_DAMAGE_MOD_TRASH_FLOOR_DEFAULT = 1.0f;
constexpr float LEGACY_DAMAGE_MOD_TRASH_CEILING_DEFAULT = 3.0f;

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

    // Is this creature entry a real dungeon encounter?
    //
    // creature_template.rank cannot answer this. Nearly every Classic and
    // TBC dungeon boss is rank 1 (elite), and Deadmines, Shadowfang Keep
    // and Blackfathom Deeps contain no rank 3 creature at all - so a
    // rank-based test never fired heroic_level_boss / mythic_level_boss
    // and quietly handed every boss the elite level instead.
    // instance_encounters is the authoritative list: 174 of the 175
    // Classic/TBC boss encounters resolve through it.
    bool IsBossEntry(uint32 creatureEntry) const;

    // True when this map's creatures sit on the Classic (exp 0) or TBC
    // (exp 1) columns of creature_classlevelstats and must be normalised
    // onto the WotLK curve before any difficulty multiplier applies.
    // See NormaliseToWotlkCurve in dc_mythicplus_core_scripts.cpp.
    bool UsesLegacyStatCurve(uint32 mapId) const;

    // Is this entry a creature_template.difficulty_entry_N variant of some
    // other template - i.e. a real heroic template authored by Blizzard?
    //
    // Creature::UpdateEntry walks down from the map's spawn mode and swaps
    // in DifficultyEntry[diff - 1] when it is set, so on the TBC maps both
    // Heroic and Mythic spawn the heroic template, which already carries
    // the normal -> heroic boost (HealthModifier x1.35, DamageModifier
    // x2.2-5.25). Applying HEROIC_TEMPLATE_* on top of one of those would
    // double it. Classic dungeons have no such templates and fall back to
    // the normal one, so they still need the stand-in.
    //
    // The split is per creature, not per map: on TBC maps the coverage is
    // partial (Slave Pens 20 of 44 templates, Old Hillsbrad 17 of 87), so
    // a map-level rule would be wrong in both directions.
    bool IsDifficultyVariantEntry(uint32 creatureEntry) const;

private:
    MythicDifficultyScaling() = default;
    std::unordered_map<uint32, DungeonProfile> _dungeonProfiles;
    std::unordered_map<uint32, DungeonSetupEntry> _dungeonSetup;
    uint32 _activeSeasonId = 0;
    std::unordered_map<uint32, std::pair<float, float>> _scalingMultipliers;

    // Read once at load from instance_encounters. Read-only afterwards,
    // which matters because IsBossEntry is called from the creature spawn
    // path on several map threads at once.
    std::unordered_set<uint32> _bossEntries;

    // Every entry referenced as a difficulty_entry_1/2/3 by some other
    // template. Same threading contract as _bossEntries: written once at
    // load, read-only from the spawn path afterwards.
    std::unordered_set<uint32> _difficultyVariantEntries;

    // Helper to determine expansion from map ID
    static uint8 GetExpansionForMap(uint32 mapId);
    void LoadScalingMultipliers();
    void LoadDungeonSetup();
    void LoadBossEntries();
    void LoadDifficultyVariantEntries();
};

#define sMythicScaling MythicDifficultyScaling::instance()

#endif // DC_MYTHICPLUS_DIFFICULTY_SCALING_H
