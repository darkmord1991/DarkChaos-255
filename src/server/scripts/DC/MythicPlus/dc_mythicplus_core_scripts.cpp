/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "ScriptMgr.h"
#include "AllMapScript.h"
#include "AllSpellScript.h"
#include "Spell.h"
#include "dc_mythicplus_difficulty_scaling.h"
#include "dc_mythicplus_run_manager.h"
#include "dc_mythicplus_affixes.h"
#include "../DungeonQuests/DungeonQuestConstants.h"
#include "UnitScript.h"
#include "Unit.h"
#include "Creature.h"
#include "Map.h"
#include "DBCStores.h"
#include "ObjectMgr.h"
#include "Log.h"
#include "Player.h"
#include "Chat.h"
#include "StringFormat.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <mutex>
#include <sstream>
#include "dc_update_profiler.h"

namespace
{
// Creatures that have passed through our SelectLevel hook, so OnCreatureAddWorld
// knows which summons still need the fallback.
//
// This was thread_local. A map is not pinned to one MapUpdate worker across
// ticks, so a creature could be inserted on thread A and removed on thread B -
// leaving a permanent stale GUID in A's set and a missed cleanup in B's, which
// made the summon fallback intermittently skip creatures it should have
// rescaled. One shared set under a mutex instead; GUIDs are unique across maps.
std::mutex g_processedCreaturesMutex;
GuidUnorderedSet g_processedCreatures;

void MarkSelectLevelProcessed(ObjectGuid guid)
{
    std::lock_guard<std::mutex> guard(g_processedCreaturesMutex);
    g_processedCreatures.insert(guid);
}

bool WasSelectLevelProcessed(ObjectGuid guid)
{
    std::lock_guard<std::mutex> guard(g_processedCreaturesMutex);
    return g_processedCreatures.find(guid) != g_processedCreatures.end();
}

void ForgetSelectLevelProcessed(ObjectGuid guid)
{
    std::lock_guard<std::mutex> guard(g_processedCreaturesMutex);
    g_processedCreatures.erase(guid);
}

bool IsCountdownBlockedSpell(SpellInfo const* spellInfo)
{
    if (!spellInfo)
        return false;

    return spellInfo->HasEffect(SPELL_EFFECT_TELEPORT_UNITS) ||
        spellInfo->HasEffect(SPELL_EFFECT_TELEPORT_UNITS_FACE_CASTER) ||
        spellInfo->HasEffect(SPELL_EFFECT_CHARGE) ||
        spellInfo->HasEffect(SPELL_EFFECT_CHARGE_DEST) ||
        spellInfo->HasEffect(SPELL_EFFECT_JUMP) ||
        spellInfo->HasEffect(SPELL_EFFECT_JUMP_DEST) ||
        spellInfo->HasEffect(SPELL_EFFECT_LEAP_BACK) ||
        spellInfo->HasEffect(SPELL_EFFECT_KNOCK_BACK) ||
        spellInfo->HasEffect(SPELL_EFFECT_KNOCK_BACK_DEST) ||
        spellInfo->HasEffect(SPELL_EFFECT_PULL_TOWARDS_DEST);
}
}

// Forward declaration
void RegisterMythicPlusAffixHandlers();

// World script to load dungeon profiles on server startup
class MythicPlusWorldScript : public WorldScript
{
public:
    MythicPlusWorldScript() : WorldScript("MythicPlusWorldScript") { }

    void OnStartup() override
    {
        LOG_INFO("server.loading", ">> Loading Mythic+ system...");
        sMythicScaling->LoadDungeonProfiles();
        sMythicRuns->Reset();
        sMythicRuns->LoadLootTable();
        RegisterMythicPlusAffixHandlers();
        LOG_INFO("server.loading", ">> Mythic+ system loaded successfully");
    }

    void OnUpdate(uint32 diff) override
    {
        DarkChaos::ScopedUpdateProfiler _prof("MythicPlusCore");
        // Run-manager sweeps live here (world thread, once per second).
        // They used to run from OnPlayerUpdate, where (a) the accumulated
        // per-player diff hit the 1s gate N times faster with N dungeon
        // players, and (b) the shared run-manager state was touched from
        // multiple map-update threads.
        _sweepTimer += diff;
        if (_sweepTimer < 1000)
            return;
        _sweepTimer = 0;

        sMythicRuns->ProcessCancellationTimers();
        sMythicRuns->ProcessCancellationVotes();
        sMythicRuns->ProcessCountdowns();
        sMythicRuns->ProcessHudUpdates();
    }

private:
    uint32 _sweepTimer = 0;
};

class MythicPlusCountdownSpellGate : public AllSpellScript
{
public:
    MythicPlusCountdownSpellGate()
        : AllSpellScript("MythicPlusCountdownSpellGate",
            { ALLSPELLHOOK_ON_SPELL_CHECK_CAST }) { }

    void OnSpellCheckCast(Spell* spell, bool /*strict*/,
        SpellCastResult& res) override
    {
        if (!spell || res != SPELL_CAST_OK)
            return;

        Player* player = spell->GetCaster() ?
            spell->GetCaster()->ToPlayer() : nullptr;
        if (!player)
            return;

        Map* map = player->GetMap();
        if (!map)
            return;

        MythicPlusRunManager::InstanceState const* state =
            sMythicRuns->GetRunState(map);
        if (!state || !state->countdownActive)
            return;

        if (state->participants.find(player->GetGUID().GetCounter()) ==
                state->participants.end())
            return;

        if (!IsCountdownBlockedSpell(spell->GetSpellInfo()))
            return;

        res = SPELL_FAILED_ROOTED;
    }
};

// Creature script to apply scaling DURING SelectLevel (proper way)
class MythicPlusCreatureScript : public AllCreatureScript
{
public:
    MythicPlusCreatureScript() : AllCreatureScript("MythicPlusCreatureScript") { }

    // Hook 1: Modify level BEFORE stats are calculated
    void OnBeforeCreatureSelectLevel(CreatureTemplate const* /*cinfo*/, Creature* creature, uint8& level) override
    {
        if (!creature)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Get dungeon profile
        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
        if (!profile)
            return;

        Difficulty difficulty = sMythicScaling->ResolveDungeonDifficulty(map);
        uint32 rank = creature->GetCreatureTemplate()->rank;

        // Determine creature type.
        //
        // instance_encounters is authoritative for "is this a boss";
        // rank is not, and used to be the only test here. Nearly every
        // Classic and TBC dungeon boss is rank 1 (elite) - Deadmines,
        // Shadowfang Keep and Blackfathom Deeps contain no rank 3
        // creature at all - so heroic_level_boss / mythic_level_boss
        // never fired on those maps and every boss silently took the
        // elite level instead. rank is kept as the fallback for the
        // handful of encounters with no instance_encounters row.
        bool isBoss = sMythicScaling->IsBossEntry(creature->GetEntry())
                      || rank == CREATURE_ELITE_WORLDBOSS
                      || rank == CREATURE_ELITE_RAREELITE;
        bool isElite = !isBoss && rank == CREATURE_ELITE_ELITE;

        uint8 newLevel = level; // Keep original by default

        switch (difficulty)
        {
            case DUNGEON_DIFFICULTY_HEROIC:
                // Use database configured levels (0 = keep original)
                if (isBoss && profile->heroicLevelBoss > 0)
                    newLevel = profile->heroicLevelBoss;
                else if (isElite && profile->heroicLevelElite > 0)
                    newLevel = profile->heroicLevelElite;
                else if (profile->heroicLevelNormal > 0)
                    newLevel = profile->heroicLevelNormal;
                break;

            case DUNGEON_DIFFICULTY_EPIC: // Mythic
                // Use database configured levels (0 = keep original)
                if (isBoss && profile->mythicLevelBoss > 0)
                    newLevel = profile->mythicLevelBoss;
                else if (isElite && profile->mythicLevelElite > 0)
                    newLevel = profile->mythicLevelElite;
                else if (profile->mythicLevelNormal > 0)
                    newLevel = profile->mythicLevelNormal;
                break;

            default:
                break;
        }

        // Modify the level reference - this will be used by SelectLevel()
        if (newLevel != level)
        {
            level = newLevel;
        }
    }

    // Hook 2: Modify HP/damage AFTER base stats are calculated
    void OnCreatureSelectLevel(CreatureTemplate const* /*cinfo*/, Creature* creature) override
    {
        if (!creature)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Get dungeon profile
        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
        if (!profile)
            return;

        Difficulty difficulty = sMythicScaling->ResolveDungeonDifficulty(map);

        // Track creatures that successfully pass through the SelectLevel path,
        // so OnCreatureAddWorld can avoid re-processing them.
        switch (difficulty)
        {
            case DUNGEON_DIFFICULTY_HEROIC:
                if (!profile->heroicEnabled)
                    return;
                break;
            case DUNGEON_DIFFICULTY_EPIC:
                if (!profile->mythicEnabled)
                    return;
                break;
            default:
                return;
        }

        MarkSelectLevelProcessed(creature->GetGUID());

        // Determine multipliers based on difficulty
        float hpMult = 1.0f;
        float damageMult = 1.0f;
        uint32 keystoneLevel = 0;

        switch (difficulty)
        {
            case DUNGEON_DIFFICULTY_HEROIC:
                hpMult = profile->heroicHealthMult;
                damageMult = profile->heroicDamageMult;
                break;

            case DUNGEON_DIFFICULTY_EPIC: // Mythic
                hpMult = profile->mythicHealthMult;
                damageMult = profile->mythicDamageMult;

                // Check for Mythic+ keystone
                keystoneLevel = sMythicScaling->GetKeystoneLevel(map);
                if (keystoneLevel > 0)
                {
                    float mplusHpMult = 1.0f;
                    float mplusDamageMult = 1.0f;
                    sMythicScaling->CalculateMythicPlusMultipliers(keystoneLevel, mplusHpMult, mplusDamageMult);

                    hpMult *= mplusHpMult;
                    damageMult *= mplusDamageMult;
                }
                break;

            default:
                break;
        }

        // Classic and TBC creatures are built from the wrong column of
        // creature_classlevelstats. AzerothCore picks the column by
        // creature_template.exp, and at level 81 the three read:
        //
        //     HP      5492 (exp0)  9474 (exp1)  13033 (exp2)
        //     damage  47.9 (exp0)  133.0 (exp1)  169.0 (exp2)
        //
        // so a Vanilla boss forced to level 81 still gets Vanilla-shaped
        // stats and lands at a fraction of a WotLK boss - most visibly on
        // damage, where the gap is 3.5x and the old 2.0x Mythic
        // multiplier could not close it.
        //
        // This cannot be fixed by setting exp = 2 on the templates:
        // basehp2 is unpopulated (= 1) below level 55 and again at levels
        // 60-63, so Normal-mode Deadmines mobs would drop to 1 HP. It is
        // corrected here instead, where the level has already been forced
        // to 80-82 and basehp2 is valid. Normal mode never reaches this
        // code.
        //
        // Expressed as a ratio rather than an absolute, so it composes
        // with whatever SelectLevel already produced and with the
        // difficulty and keystone multipliers below.
        if (sMythicScaling->UsesLegacyStatCurve(map->GetId()))
        {
            CreatureTemplate const* cinfo = creature->GetCreatureTemplate();

            // cinfo->expansion is uint32 and MAX_EXPANSIONS is a plain
            // enum constant, so the bound is widened explicitly - the
            // naive comparison is a -Wsign-compare, and CI builds -Werror.
            uint8 nativeExpansion =
                cinfo->expansion < static_cast<uint32>(MAX_EXPANSIONS)
                    ? static_cast<uint8>(cinfo->expansion)
                    : static_cast<uint8>(EXPANSION_WRATH_OF_THE_LICH_KING);

            if (nativeExpansion != EXPANSION_WRATH_OF_THE_LICH_KING)
            {
                if (CreatureBaseStats const* stats =
                        sObjectMgr->GetCreatureBaseStats(creature->GetLevel(), cinfo->unit_class))
                {
                    uint32 nativeHealth = stats->BaseHealth[nativeExpansion];
                    uint32 wotlkHealth  = stats->BaseHealth[EXPANSION_WRATH_OF_THE_LICH_KING];
                    float  nativeDamage = stats->BaseDamage[nativeExpansion];
                    float  wotlkDamage  = stats->BaseDamage[EXPANSION_WRATH_OF_THE_LICH_KING];

                    // Guard the unpopulated rows: creature_classlevelstats
                    // stores 1 rather than NULL where a column has no data.
                    if (nativeHealth > 1 && wotlkHealth > 1)
                        hpMult *= float(wotlkHealth) / float(nativeHealth);

                    if (nativeDamage > 1.0f && wotlkDamage > 1.0f)
                        damageMult *= wotlkDamage / nativeDamage;
                }

                // Stand in for the heroic template Blizzard never
                // authored - but ONLY when one is genuinely absent.
                //
                // Creature::UpdateEntry walks down from the map spawn
                // mode and swaps in DifficultyEntry[diff - 1] when set,
                // so on the TBC maps both Heroic and Mythic already spawn
                // a real heroic template with the boost baked in
                // (HealthModifier x1.35, DamageModifier x2.2-5.25).
                // Applying the stand-in on top of one of those doubles
                // it. Classic dungeons have no such template and fall
                // back to the normal one, so they still need it.
                float standInHealth = 1.0f;
                float standInDamage = 1.0f;

                if (!sMythicScaling->IsDifficultyVariantEntry(creature->GetEntry()))
                {
                    standInHealth = HEROIC_TEMPLATE_HEALTH_FACTOR;
                    standInDamage = HEROIC_TEMPLATE_DAMAGE_FACTOR;
                }

                hpMult *= standInHealth;

                // Hold the synthesised heroic DamageModifier inside a
                // sane band before applying it - and pick the band by
                // rank, because Blizzard's heroic templates differ by an
                // order of magnitude between elites (12.9 average) and
                // ordinary trash (1.0), while the Classic templates use
                // one undifferentiated value for both (Gnomeregan: 1.70
                // for rank 0 and rank 1 alike).
                //
                // Bosses take the elite band; WotLK heroic bosses are
                // uniformly 13.
                //
                // This is a stopgap that only stops the extremes being
                // trivial or lethal. Per-dungeon tuning still wants doing
                // properly against dc_dungeon_mythic_profile.
                uint32 rank = cinfo->rank;
                bool eliteOrBoss = sMythicScaling->IsBossEntry(creature->GetEntry())
                                   || rank == CREATURE_ELITE_ELITE
                                   || rank == CREATURE_ELITE_RAREELITE
                                   || rank == CREATURE_ELITE_WORLDBOSS;

                float floorMod = eliteOrBoss
                    ? sConfigMgr->GetOption<float>("MythicPlus.LegacyScaling.DamageModifierFloor",
                                                   LEGACY_DAMAGE_MOD_FLOOR_DEFAULT)
                    : sConfigMgr->GetOption<float>("MythicPlus.LegacyScaling.DamageModifierFloorTrash",
                                                   LEGACY_DAMAGE_MOD_TRASH_FLOOR_DEFAULT);
                float ceilingMod = eliteOrBoss
                    ? sConfigMgr->GetOption<float>("MythicPlus.LegacyScaling.DamageModifierCeiling",
                                                   LEGACY_DAMAGE_MOD_CEILING_DEFAULT)
                    : sConfigMgr->GetOption<float>("MythicPlus.LegacyScaling.DamageModifierCeilingTrash",
                                                   LEGACY_DAMAGE_MOD_TRASH_CEILING_DEFAULT);

                float synthesisedMod = cinfo->DamageModifier * standInDamage;

                if (floorMod > 0.0f && ceilingMod >= floorMod && synthesisedMod > 0.0f)
                {
                    float clampedMod = std::clamp(synthesisedMod, floorMod, ceilingMod);
                    damageMult *= clampedMod / cinfo->DamageModifier;
                }
                else
                {
                    damageMult *= standInDamage;
                }
            }
        }

        // Apply multipliers to already-set stats
        if (hpMult > 1.0f || damageMult > 1.0f)
        {
            // Multiply HP.
            //
            // UNIT_MOD_HEALTH has to be written as well, not just
            // MaxHealth. Creature::SelectLevel stores the UNSCALED health
            // in that modifier and only afterwards fires this hook, and
            // Creature::UpdateEntry then calls UpdateAllStats() a few
            // lines further on. Creature::UpdateMaxHealth recomputes
            // MaxHealth from GetTotalAuraModValue(UNIT_MOD_HEALTH), so a
            // bare SetMaxHealth is reverted before the creature is ever
            // seen. That is why a Gnomeregan boss sat at roughly
            // basehp0 x HealthModifier (~16k) with none of the heroic
            // scaling applied - and it silently defeated the Mythic+ HP
            // multipliers too, on every dungeon, since long before the
            // heroic tier existed.
            uint32 baseHealth = creature->GetMaxHealth();
            uint32 newHealth = uint32(baseHealth * hpMult);
            creature->SetCreateHealth(newHealth);
            creature->SetStatFlatModifier(UNIT_MOD_HEALTH, BASE_VALUE, float(newHealth));
            creature->SetMaxHealth(newHealth);
            creature->SetHealth(newHealth);

            // Multiply damage.
            //
            // Read the BASE WEAPON damage, not UNIT_FIELD_MINDAMAGE. The
            // UNIT_FIELD_* damage fields are outputs of
            // Unit::UpdateDamagePhysical, which has not run yet at this
            // point - UpdateAllStats calls it after this hook returns. On
            // a freshly created creature those fields are still 0, so the
            // old code was computing 0 * damageMult and storing that as
            // the creature's base weapon damage, leaving it with only its
            // attack-power contribution to hit with.
            float baseMinDamage = creature->GetWeaponDamageRange(BASE_ATTACK, MINDAMAGE);
            float baseMaxDamage = creature->GetWeaponDamageRange(BASE_ATTACK, MAXDAMAGE);
            creature->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, baseMinDamage * damageMult);
            creature->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, baseMaxDamage * damageMult);

            // Also scale off-hand if exists
            float baseOffhandMin = creature->GetWeaponDamageRange(OFF_ATTACK, MINDAMAGE);
            if (baseOffhandMin > 0.0f)
            {
                float baseOffhandMax = creature->GetWeaponDamageRange(OFF_ATTACK, MAXDAMAGE);
                creature->SetBaseWeaponDamage(OFF_ATTACK, MINDAMAGE, baseOffhandMin * damageMult);
                creature->SetBaseWeaponDamage(OFF_ATTACK, MAXDAMAGE, baseOffhandMax * damageMult);
            }

            LOG_DEBUG("mythic.scaling", "Scaled creature {} (entry {}) on map {} (difficulty {}) to level {} with {:.2f}x HP ({} -> {}), {:.2f}x Damage",
                      creature->GetName(), creature->GetEntry(), map->GetId(), uint32(difficulty), creature->GetLevel(),
                      hpMult, uint32(baseHealth), newHealth, damageMult);
        }

        // Apply affix-specific scaling (e.g., Tyrannical, Fortified)
        sAffixMgr->OnCreatureSelectLevel(creature);
    }

    void OnCreatureAddWorld(Creature* creature) override
    {
        if (!creature)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        Difficulty difficulty = sMythicScaling->ResolveDungeonDifficulty(map);

        // Keep the DC dungeon-quest follower out of Mythic runs.
        //
        // This used to be a blanket `creature->IsQuestGiver()` test, which despawned every
        // questgiver-flagged NPC on the map - including the stock NPCs the dungeons need to
        // progress at all. It made Mythic uncompletable in at least eight dungeons: Verdisa,
        // Belgaristrasz and Eternos hand out the Oculus drakes (npcflag 2), Chromie starts the
        // Culling of Stratholme, Brann Bronzebeard drives Halls of Stone, Sylvanas runs Forge
        // of Souls / Pit of Saron / Halls of Reflection, Thrall and Erozion are Old Hillsbrad,
        // Medivh and Sa'at are the Black Morass. Only the DC quest masters (700000-700052 and
        // the universal 700100) are ours to remove; DungeonQuest::IsQuestMasterBlockedDifficulty
        // already refuses to summon them on Mythic, so this is only a safety net for a follower
        // that survived a difficulty change.
        if (difficulty == DUNGEON_DIFFICULTY_EPIC &&
            (DungeonQuest::IsQuestMasterNPC(creature->GetEntry()) ||
             creature->GetEntry() == DungeonQuest::NPC_UNIVERSAL_QUEST_MASTER))
        {
            LOG_DEBUG("mythic.scaling", "Despawning dungeon quest master {} (entry {}) in Mythic mode",
                      creature->GetName(), creature->GetEntry());
            // DespawnOrUnsummon, not RemoveFromWorld: this hook fires from
            // inside Creature::AddToWorld(), so tearing the object out here
            // unwinds grid registration the caller is still establishing.
            // Deferring by a tick lets AddToWorld finish first.
            creature->DespawnOrUnsummon(1ms);
            return;
        }

        // Defensive fallback: some summon paths can alter creature state after
        // SelectLevel. Re-run SelectLevel once for summoned dungeon NPCs if
        // this creature did not pass through our SelectLevel hook.
        if (!creature->IsSummon() || creature->IsTrigger())
            return;

        if (TempSummon* summon = creature->ToTempSummon())
            if (Unit* summoner = summon->GetSummonerUnit())
                if (summoner->IsPlayer())
                    return;

        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
        if (!profile)
            return;

        if (difficulty == DUNGEON_DIFFICULTY_HEROIC && !profile->heroicEnabled)
            return;
        if (difficulty == DUNGEON_DIFFICULTY_EPIC && !profile->mythicEnabled)
            return;
        if (difficulty != DUNGEON_DIFFICULTY_HEROIC && difficulty != DUNGEON_DIFFICULTY_EPIC)
            return;

        if (WasSelectLevelProcessed(creature->GetGUID()))
            return;

        LOG_DEBUG("mythic.scaling", "Re-running SelectLevel fallback for summoned creature {} (entry {}) on map {} instance {}",
                  creature->GetName(), creature->GetEntry(), map->GetId(), map->GetInstanceId());

        creature->SelectLevel();
    }

    void OnCreatureRemoveWorld(Creature* creature) override
    {
        if (!creature)
            return;

        ForgetSelectLevelProcessed(creature->GetGUID());
    }
};

// Player script to announce difficulty when entering dungeons
class MythicPlusPlayerScript : public PlayerScript
{
public:
    // Explicit hook list. An empty list means "register into all ~200 player
    // hooks", so this script was being walked by every unrelated player hook in
    // the server for the sake of the six it actually implements.
    MythicPlusPlayerScript() : PlayerScript("MythicPlusPlayerScript",
        {
            PLAYERHOOK_NOT_AVOID_SATISFY,
            PLAYERHOOK_ON_MAP_CHANGED,
            PLAYERHOOK_ON_LOGOUT,
            PLAYERHOOK_ON_GIVE_REPUTATION,
            PLAYERHOOK_CAN_REPOP_AT_GRAVEYARD,
            PLAYERHOOK_ON_UPDATE
        }) { }

    bool OnPlayerNotAvoidSatisfy(Player* player, DungeonProgressionRequirements const* ar, uint32 targetMap, bool /*report*/) override
    {
        if (!player || !ar)
            return true;

        if (!sMythicRuns->IsMythicPlusDungeon(targetMap))
            return true;

        MapEntry const* mapEntry = sMapStore.LookupEntry(targetMap);
        if (!mapEntry || mapEntry->IsRaid())
            return true;

        Difficulty intendedDifficulty = player->GetDifficulty(mapEntry->IsRaid());
        if (intendedDifficulty != DUNGEON_DIFFICULTY_EPIC)
            return true;

        LOG_DEBUG("mythic.run", "Bypassing dungeon_access_template for Mythic+ dungeon {} (player {})", targetMap, player->GetName());
        return false;
    }

    void OnPlayerMapChanged(Player* player) override
    {
        if (!player)
            return;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return;

        sMythicRuns->RegisterPlayerEnter(player);

        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());

        // Define helper lambda first so it's available for both branches
        auto FormatScalingText = [](float hpMult, float damageMult) -> std::string
        {
            auto percentString = [](float mult) -> std::string
            {
                int32 pct = int32(std::round((mult - 1.0f) * 100.0f));
                std::ostringstream stream;
                if (pct >= 0)
                    stream << "+";
                stream << pct << "%";
                return stream.str();
            };

            std::ostringstream result;
            result << percentString(hpMult) << " HP, " << percentString(damageMult) << " Damage";
            return result.str();
        };

        // Determine dungeon name
        std::string dungeonName;
        if (profile)
            dungeonName = profile->name;
        else
        {
            // Fallback to DBC map name for non-Mythic+ instances (e.g. Raids)
            MapEntry const* mapEntry = sMapStore.LookupEntry(map->GetId());
            if (mapEntry)
                dungeonName = mapEntry->name[0]; // 0 is usually localized name
            else
                dungeonName = "Unknown Instance";
        }

        // Announce difficulty on dungeon entry
        Difficulty diff = sMythicScaling->ResolveDungeonDifficulty(map);
        std::string instanceTypeLabel;
        std::string scaling;

        if (map->IsRaid())
        {
            switch (map->GetDifficulty())
            {
                case RAID_DIFFICULTY_10MAN_NORMAL:
                    instanceTypeLabel = "10 Player";
                    break;
                case RAID_DIFFICULTY_25MAN_NORMAL:
                    instanceTypeLabel = "25 Player";
                    break;
                case RAID_DIFFICULTY_10MAN_HEROIC:
                    instanceTypeLabel = "10 Player (Heroic)";
                    break;
                case RAID_DIFFICULTY_25MAN_HEROIC:
                    instanceTypeLabel = "25 Player (Heroic)";
                    break;
                default:
                    instanceTypeLabel = "Raid";
                    break;
            }
        }
        else
        {
            switch (diff)
            {
                case DUNGEON_DIFFICULTY_NORMAL:
                    instanceTypeLabel = "5 Player";
                    scaling = "Base creature stats";
                    break;
                case DUNGEON_DIFFICULTY_HEROIC:
                    instanceTypeLabel = "5 Player (Heroic)";
                    scaling = profile ? FormatScalingText(profile->heroicHealthMult, profile->heroicDamageMult)
                                    : "+15% HP, +10% Damage";
                    break;
                case DUNGEON_DIFFICULTY_EPIC:
                    instanceTypeLabel = "5 Player (Mythic)";
                    scaling = profile ? FormatScalingText(profile->mythicHealthMult, profile->mythicDamageMult)
                                    : "+35% HP, +20% Damage";
                    break;
                default:
                    instanceTypeLabel = "Unknown Difficulty";
                    break;
            }
        }

        std::string welcomeLine = Acore::StringFormat("Welcome to {} ({}).", dungeonName, instanceTypeLabel);
        ChatHandler(player->GetSession()).SendSysMessage(welcomeLine.c_str());

        // Check if this is a Mythic+ run
        uint8 keystoneLevel = sMythicScaling->GetKeystoneLevel(map);
        if (keystoneLevel > 0)
        {
            // Mythic+ run - show simplified message
            ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cffff8000Keystone Level: |r|cffff8000+{}|r", keystoneLevel));

            // Show M+ specific scaling (multiplicative on top of Mythic base)
            float mplusHpMult = 1.0f;
            float mplusDamageMult = 1.0f;
            sMythicScaling->CalculateMythicPlusMultipliers(keystoneLevel, mplusHpMult, mplusDamageMult);
            std::string mplusScaling = FormatScalingText(mplusHpMult, mplusDamageMult);
            ChatHandler(player->GetSession()).SendSysMessage(("M+ Multiplier (×Mythic base): |cffaaaaaa" + mplusScaling + "|r").c_str());

            // Show active affixes
            auto activeAffixes = sAffixMgr->GetActiveAffixes(map);
            if (!activeAffixes.empty())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff8000Active Affixes:|r");
                std::ostringstream affixLine;
                affixLine << "|cffff8000Active Affixes|r: ";
                bool firstAffix = true;
                for (auto affix : activeAffixes)
                {
                    std::string affixName = sAffixMgr->GetAffixName(affix);

                    if (!firstAffix)
                        affixLine << ", ";
                    firstAffix = false;
                    affixLine << affixName;
                }

                ChatHandler(player->GetSession()).SendSysMessage(affixLine.str().c_str());
            }
        }
        else
        {
            // Only show Scaling info if a profile exists and thus scaling is actually active
            if (profile)
            {
                ChatHandler(player->GetSession()).SendSysMessage(("Scaling: |cffaaaaaa" + scaling + "|r").c_str());
            }
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Player leaving during an active Mythic+ run. InitiateCancellation is
        // a no-op unless this was the last participant, so do not log at INFO
        // for every dungeon logout on the realm.
        sMythicRuns->InitiateCancellation(map);

        LOG_DEBUG("mythic.run", "Player {} logged out on map {} instance {}",
                  player->GetName(), map->GetId(), map->GetInstanceId());
    }

    void OnPlayerGiveReputation(Player* player, int32 /*factionID*/, float& amount, ReputationSource repSource) override
    {
        if (!player || amount <= 0.0f)
            return;

        if (repSource != REPUTATION_SOURCE_KILL)
            return;

        if (sMythicRuns->ShouldSuppressReputation(player))
        {
            amount = 0.0f;
            LOG_DEBUG("mythic.run", "Suppressed reputation gain for {} during active Mythic+ run", player->GetName());
        }
    }

    // Mythic+ death handling: resurrect at dungeon entrance instead of graveyard (retail-like behavior)
    // Return false to prevent normal graveyard repop, and handle entrance teleport + resurrection ourselves
    bool OnPlayerCanRepopAtGraveyard(Player* player) override
    {
        if (!player)
            return true;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return true;

        if (!sMythicRuns->RespawnPlayerAtEntrance(player))
            return true;

        ChatHandler(player->GetSession()).PSendSysMessage("|cffff8000[Mythic+]|r You have been resurrected at the dungeon entrance.");
        return false;
    }

    // Folded in from the former MythicPlusUpdateScript, which was a second
    // PlayerScript registration that existed only to carry this one hook (and
    // was missing its override keyword).
    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (!player || !player->IsInWorld())
            return;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Run-manager sweeps live in MythicPlusWorldScript::OnUpdate (world
        // thread, real 1s cadence); only the per-player affix dispatch stays
        // on the player-update path.
        sAffixMgr->OnPlayerUpdate(player, diff);
    }
};

class MythicPlusAllMapScript : public AllMapScript
{
public:
    MythicPlusAllMapScript() : AllMapScript("MythicPlusAllMapScript",
        { ALLMAPHOOK_ON_DESTROY_MAP, ALLMAPHOOK_ON_PLAYER_LEAVE_ALL }) { }

    void OnDestroyMap(Map* map) override
    {
        if (!map || !map->IsDungeon())
            return;

        sMythicRuns->HandleInstanceReset(map);
        sAffixMgr->DeactivateAffixes(map);
    }

    void OnPlayerLeaveAll(Map* map, Player* player) override
    {
        if (!player || !map || !map->IsDungeon())
            return;

        sMythicRuns->InitiateCancellation(map);
    }
};

class MythicPlusUnitScript : public UnitScript
{
public:
    // NOTE: DealDamage is dispatched over every UnitScript unconditionally
    // rather than through the hook registry, so it stays active regardless of
    // this list; the list still narrows the three hooks that are gated.
    MythicPlusUnitScript() : UnitScript("MythicPlusUnitScript", true,
        {
            UNITHOOK_ON_UNIT_DEATH,
            UNITHOOK_ON_UNIT_ENTER_EVADE_MODE,
            UNITHOOK_ON_DAMAGE
        }) { }

    uint32 DealDamage(Unit* attacker, Unit* victim, uint32 damage, DamageEffectType damagetype) override
    {
        if (!attacker || !victim || !damage)
            return damage;

        // Base creature melee is already scaled via stat multipliers in
        // OnCreatureSelectLevel. Apply dynamic multiplier only to spell hit types.
        if (damagetype != SPELL_DIRECT_DAMAGE && damagetype != DOT)
            return damage;

        Creature* attackerCreature = attacker->ToCreature();
        if (!attackerCreature)
            return damage;

        // Do not scale player-controlled pets/guardians here.
        if (attackerCreature->IsControlledByPlayer())
            return damage;

        Map* map = attackerCreature->GetMap();
        if (!map || !map->IsDungeon())
            return damage;

        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
        if (!profile)
            return damage;

        Difficulty difficulty = sMythicScaling->ResolveDungeonDifficulty(map);
        float spellDamageMult = 1.0f;

        switch (difficulty)
        {
            case DUNGEON_DIFFICULTY_HEROIC:
                if (!profile->heroicEnabled)
                    return damage;

                spellDamageMult = profile->heroicDamageMult;
                break;

            case DUNGEON_DIFFICULTY_EPIC:
                if (!profile->mythicEnabled)
                    return damage;

                spellDamageMult = profile->mythicDamageMult;

                if (uint32 keystoneLevel = sMythicScaling->GetKeystoneLevel(map); keystoneLevel > 0)
                {
                    float mplusHpMult = 1.0f;
                    float mplusDamageMult = 1.0f;
                    sMythicScaling->CalculateMythicPlusMultipliers(keystoneLevel, mplusHpMult, mplusDamageMult);
                    spellDamageMult *= mplusDamageMult;
                }
                break;

            default:
                return damage;
        }

        if (spellDamageMult == 1.0f)
            return damage;

        float scaledFloat = static_cast<float>(damage) * spellDamageMult;
        if (scaledFloat <= 0.0f)
            return 1;

        uint64 scaledRounded = static_cast<uint64>(std::round(scaledFloat));
        if (scaledRounded == 0)
            return 1;

        if (scaledRounded >= std::numeric_limits<uint32>::max())
            return std::numeric_limits<uint32>::max();

        return static_cast<uint32>(scaledRounded);
    }

    void OnUnitDeath(Unit* unit, Unit* killer) override
    {
        if (!unit)
            return;

        Map* map = unit->GetMap();
        if (!map || !map->IsDungeon())
            return;

        if (Player* player = unit->ToPlayer())
        {
            Creature* creatureKiller = killer ? killer->ToCreature() : nullptr;
            sMythicRuns->HandlePlayerDeath(player, creatureKiller);
            return;
        }

        Creature* creature = unit->ToCreature();
        if (!creature)
            return;

        if (sMythicRuns->ShouldSuppressLoot(creature))
        {
            creature->SetLootRecipient(nullptr);
            creature->loot.clear();
            creature->loot.gold = 0;
            creature->ResetLootMode();
            creature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
        }

        // Track all creature kills for statistics
        sMythicRuns->HandleCreatureKill(creature, killer);

        // Dispatch affix death handlers for all creatures
        sAffixMgr->OnCreatureDeath(creature, killer);

        // Handle boss-specific logic
        if (sMythicRuns->IsBossCreature(creature))
        {
            sMythicRuns->HandleBossDeath(creature, killer);
        }
    }

    void OnUnitEnterEvadeMode(Unit* unit, uint8 /*evadeReason*/) override
    {
        if (!unit)
            return;

        Creature* creature = unit->ToCreature();
        if (!creature)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        if (!sMythicRuns->IsBossCreature(creature))
            return;

        sMythicRuns->HandleBossEvade(creature);
    }

    void OnDamage(Unit* attacker, Unit* victim, uint32& damage) override
    {
        if (!attacker || !victim || damage == 0)
            return;

        Map* map = attacker->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Dispatch to affix handlers
        if (Creature* attackerCreature = attacker->ToCreature())
        {
            if (Player* victimPlayer = victim->ToPlayer())
                sAffixMgr->OnPlayerDamageTaken(victimPlayer, attackerCreature, damage);
            else if (Creature* victimCreature = victim->ToCreature())
                sAffixMgr->OnCreatureDamageTaken(victimCreature, attacker, damage);

            sAffixMgr->OnCreatureDamageDone(attackerCreature, victim, damage);
        }
    }
};

void AddSC_mythic_plus_core_scripts()
{
    new MythicPlusWorldScript();
    new MythicPlusCountdownSpellGate();
    new MythicPlusCreatureScript();
    new MythicPlusPlayerScript();
    new MythicPlusAllMapScript();
    new MythicPlusUnitScript();
}
