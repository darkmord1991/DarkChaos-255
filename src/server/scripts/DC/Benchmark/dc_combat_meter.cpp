/*
 * DarkChaos: server-side combat meter for balance benchmarks.
 *
 * Writes one row per finished fight of a player or playerbot into the
 * characters table `dc_bench_fight`: how long the fight took, what the
 * character, its pet and its other minions dealt, what it healed and what it
 * took. Comparing those rows between level bands, classes and balance
 * revisions is how scaling changes are checked (pet share of owner damage,
 * time to kill, health lost per kill).
 *
 * Why on the server: Mythic+ scales creature spell damage after the combat
 * log packet is sent, so a client meter never sees it, and playerbots have no
 * client at all.
 *
 * What is counted
 *  - Damage comes from the DealDamage hook, the first thing Unit::DealDamage
 *    runs. That is before a training dummy's AI zeroes the hit, so dummies
 *    can be measured. This script is registered last, so it sees the value
 *    the Mythic+ script (registered earlier) has already scaled.
 *  - Overkill is cut off at the victim's remaining health.
 *  - Healing is the effective amount (the OnHeal hook passes the health
 *    actually gained).
 *  - A pet is the owner's permanent pet; totems, guardians and charmed
 *    creatures count as minions.
 *  - The biggest single spell hit a creature landed on the character, and
 *    which spell it was. This is what shows a creature spell that scales
 *    out of proportion: compare it with max_health.
 *  - Who dealt the killing blow (creature with its entry, or a player with
 *    their pets and minions) and how much of the damage taken came from
 *    players. On maps both factions share, this separates world PvP from
 *    mob balance. Written only if the columns exist.
 *  - Per spell (table `dc_bench_spell`, written only if it exists): the
 *    damage of every spell the character, its pet and each minion dealt in
 *    the fight, with the minion's creature entry. Spell 0 is a melee swing.
 *    This is what tells which ability (or which totem) carries a spec.
 *
 * Threading: every hook here runs on the map thread of the player it reads
 * or writes, and the running totals live in that player's CustomData, so
 * there is no shared state between maps. Config values are atomics.
 *
 * Off by default (DC.Bench.Meter.Enable). The table comes from a pending
 * characters SQL file; apply it before switching the meter on.
 */

#include "Config.h"
#include "Creature.h"
#include "DataMap.h"
#include "DatabaseEnv.h"
#include "Group.h"
#include "Pet.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "Timer.h"
#include "WorldSession.h"
#include "StringFormat.h"
#include <algorithm>
#include <atomic>
#include <limits>
#include <string>
#include <vector>

namespace
{
    struct MeterConfig
    {
        std::atomic<bool> enabled{false};
        std::atomic<bool> bots{true};
        std::atomic<bool> players{true};
        std::atomic<uint32> runId{0};
        std::atomic<uint32> samplePct{100};
        std::atomic<uint32> minDurationMs{3000};
        std::atomic<uint32> minLevel{1};

        // Set at config load: whether dc_bench_fight already has the two
        // biggest_spell_* columns. They arrived in a later SQL file than the
        // table, and an INSERT naming a missing column would lose every row.
        std::atomic<bool> hasSpellHitColumns{false};

        // Set at config load: whether the per-spell table dc_bench_spell exists (a later SQL file).
        std::atomic<bool> hasSpellTable{false};

        // Set at config load: whether dc_bench_fight has damage_taken_players, killer_type and killer_entry.
        std::atomic<bool> hasKillerColumns{false};
    };

    MeterConfig s_config;

    char const* const FIGHT_KEY = "DCCombatMeterFight";

    // Events further apart than this belong to different fights. It keeps a
    // stray totem tick after combat from being glued onto the next pull.
    constexpr uint32 FIGHT_GAP_MS = 15000;

    enum DamageSource : uint8
    {
        SOURCE_PLAYER = 0,
        SOURCE_PET    = 1,
        SOURCE_MINION = 2,
    };

    // Values of dc_bench_fight.killer_type.
    enum KillerType : uint8
    {
        KILLER_NONE     = 0,    // no killing blow seen
        KILLER_CREATURE = 1,    // killer_entry holds the creature entry
        KILLER_PLAYER   = 2,    // a player, or a pet, totem or guardian a player controls
        KILLER_OTHER    = 3,    // no attacker (scripted kill)
    };

    struct SpellTotal
    {
        uint8 source = SOURCE_PLAYER;
        uint32 casterEntry = 0;     // creature entry of the pet or minion, 0 for the character
        uint32 spellId = 0;         // 0: melee swing
        uint64 damage = 0;
        uint32 hits = 0;
    };

    // A fight rarely uses more; the rest is lumped into one "other" entry so a long multi-pull stays bounded.
    constexpr size_t MAX_SPELL_TOTALS = 40;
    constexpr uint32 OTHER_SPELLS_ID = std::numeric_limits<uint32>::max();

    struct Fight : public DataMap::Base
    {
        bool active = false;
        uint32 startMs = 0;
        uint32 lastEventMs = 0;
        uint64 damagePlayer = 0;
        uint64 damagePet = 0;
        uint64 damageMinion = 0;
        uint64 healingDone = 0;
        uint64 damageTaken = 0;
        uint64 damageTakenPlayers = 0;  // the part of damageTaken that players (or what they control) dealt

        uint8 killerType = KILLER_NONE;
        uint32 killerEntry = 0;

        // The creature with the most health among those hit: the boss in a
        // boss fight, the mob in a solo kill.
        uint32 targetEntry = 0;
        uint32 targetMaxHealth = 0;
        uint8 targetLevel = 0;
        uint8 targetRank = 0;

        uint32 biggestSpellHit = 0;
        uint32 biggestSpellId = 0;

        std::vector<SpellTotal> spells;
    };

    void AddSpellTotal(Fight* fight, uint8 source, uint32 casterEntry, uint32 spellId, uint32 damage)
    {
        for (SpellTotal& total : fight->spells)
            if (total.source == source && total.casterEntry == casterEntry && total.spellId == spellId)
            {
                total.damage += damage;
                ++total.hits;
                return;
            }

        if (fight->spells.size() >= MAX_SPELL_TOTALS)
        {
            source = SOURCE_PLAYER;
            casterEntry = 0;
            spellId = OTHER_SPELLS_ID;
            for (SpellTotal& total : fight->spells)
                if (total.spellId == OTHER_SPELLS_ID)
                {
                    total.damage += damage;
                    ++total.hits;
                    return;
                }
        }

        fight->spells.push_back({ source, casterEntry, spellId, damage, 1 });
    }

    bool IsMetered(Player const* player)
    {
        if (player->GetLevel() < s_config.minLevel)
            return false;

        WorldSession const* session = player->GetSession();
        bool isBot = session && session->IsBot();
        return isBot ? s_config.bots.load() : s_config.players.load();
    }

    // The player's running fight. Starts one when `start` is set and none is
    // running (or the running one has gone quiet); returns nullptr otherwise.
    Fight* TouchFight(Player* player, bool start)
    {
        Fight* fight = player->CustomData.GetDefault<Fight>(FIGHT_KEY);
        uint32 now = getMSTime();

        if (fight->active && getMSTimeDiff(fight->lastEventMs, now) > FIGHT_GAP_MS)
            *fight = Fight();

        if (!fight->active)
        {
            if (!start)
                return nullptr;

            fight->active = true;
            fight->startMs = now;
        }

        fight->lastEventMs = now;
        return fight;
    }

    void NoteTarget(Fight* fight, Unit const* victim)
    {
        Creature const* creature = victim->ToCreature();
        if (!creature || creature->GetMaxHealth() <= fight->targetMaxHealth)
            return;

        fight->targetEntry = creature->GetEntry();
        fight->targetMaxHealth = creature->GetMaxHealth();
        fight->targetLevel = creature->GetLevel();
        fight->targetRank = uint8(creature->GetCreatureTemplate()->rank);
    }

    uint32 ClampToUInt32(uint64 value)
    {
        return uint32(std::min<uint64>(value, std::numeric_limits<uint32>::max()));
    }
}

class dc_combat_meter_world : public WorldScript
{
public:
    dc_combat_meter_world() : WorldScript("dc_combat_meter_world",
        { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    // The first config load runs before the world is up; the column check waits for OnStartup then.
    void OnStartup() override
    {
        RefreshColumns();
    }

    void OnAfterConfigLoad(bool reload) override
    {
        if (reload)
            RefreshColumns();

        s_config.bots = sConfigMgr->GetOption<bool>("DC.Bench.Meter.Bots", true);
        s_config.players = sConfigMgr->GetOption<bool>("DC.Bench.Meter.Players", true);
        s_config.runId = sConfigMgr->GetOption<uint32>("DC.Bench.Meter.RunId", 0);
        s_config.samplePct = std::min<uint32>(sConfigMgr->GetOption<uint32>("DC.Bench.Meter.SamplePct", 100), 100);
        s_config.minDurationMs = sConfigMgr->GetOption<uint32>("DC.Bench.Meter.MinDurationMs", 3000);
        s_config.minLevel = sConfigMgr->GetOption<uint32>("DC.Bench.Meter.MinLevel", 1);
        s_config.enabled = sConfigMgr->GetOption<bool>("DC.Bench.Meter.Enable", false);
    }

private:
    static void RefreshColumns()
    {
        s_config.hasSpellHitColumns =
            CharacterDatabase.Query("SHOW COLUMNS FROM dc_bench_fight LIKE 'biggest_spell_hit'") != nullptr;
        s_config.hasSpellTable = CharacterDatabase.Query("SHOW TABLES LIKE 'dc_bench_spell'") != nullptr;
        s_config.hasKillerColumns =
            CharacterDatabase.Query("SHOW COLUMNS FROM dc_bench_fight LIKE 'killer_type'") != nullptr;
    }
};

class dc_combat_meter_unit : public UnitScript
{
public:
    dc_combat_meter_unit() : UnitScript("dc_combat_meter_unit", true,
        { UNITHOOK_ON_HEAL, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_ON_DEAL_DAMAGE_DETAIL }) { }

    // Right after the DealDamage hooks (so after the Mythic+ scaling) with the spell that dealt the damage.
    void OnDealDamageDetail(Unit* attacker, Unit* victim, uint32 damage, DamageEffectType /*damagetype*/,
        SpellInfo const* spellProto) override
    {
        if (!s_config.enabled || !damage || !victim || attacker == victim)
            return;

        uint32 effective = std::min(damage, victim->GetHealth());

        if (attacker)
            if (Player* owner = attacker->GetCharmerOrOwnerPlayerOrPlayerItself())
                if (IsMetered(owner))
                {
                    Fight* fight = TouchFight(owner, true);
                    uint8 source = SOURCE_PLAYER;
                    if (attacker == owner)
                        fight->damagePlayer += effective;
                    else if (attacker->IsPet())
                    {
                        fight->damagePet += effective;
                        source = SOURCE_PET;
                    }
                    else
                    {
                        fight->damageMinion += effective;
                        source = SOURCE_MINION;
                    }

                    if (s_config.hasSpellTable && effective)
                        AddSpellTotal(fight, source, attacker->IsCreature() ? attacker->GetEntry() : 0,
                            spellProto ? spellProto->Id : 0, effective);

                    NoteTarget(fight, victim);
                }

        if (Player* target = victim->ToPlayer())
            if (IsMetered(target))
            {
                Fight* fight = TouchFight(target, true);
                fight->damageTaken += effective;

                Player const* attackingPlayer = attacker ? attacker->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
                if (attackingPlayer)
                    fight->damageTakenPlayers += effective;

                // This hook runs before the health drops and after absorbs, so a hit this large is the killing blow.
                if (damage >= victim->GetHealth())
                {
                    if (attackingPlayer)
                    {
                        fight->killerType = KILLER_PLAYER;
                        fight->killerEntry = 0;
                    }
                    else if (attacker && attacker->IsCreature())
                    {
                        fight->killerType = KILLER_CREATURE;
                        fight->killerEntry = attacker->GetEntry();
                    }
                    else
                    {
                        fight->killerType = KILLER_OTHER;
                        fight->killerEntry = 0;
                    }
                }
            }
    }

    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo) override
    {
        if (!s_config.enabled || damage <= 0 || !target || !attacker || !spellInfo)
            return;

        Player* player = target->ToPlayer();
        if (!player || !attacker->IsCreature() || attacker->IsControlledByPlayer() || !IsMetered(player))
            return;

        Fight* fight = TouchFight(player, true);
        if (uint32(damage) > fight->biggestSpellHit)
        {
            fight->biggestSpellHit = uint32(damage);
            fight->biggestSpellId = spellInfo->Id;
        }
    }

    void OnHeal(Unit* healer, Unit* /*reciever*/, uint32& gain) override
    {
        if (!s_config.enabled || !gain || !healer)
            return;

        // Healing never starts a fight: topping up between pulls is not combat.
        if (Player* owner = healer->GetCharmerOrOwnerPlayerOrPlayerItself())
            if (IsMetered(owner))
                if (Fight* fight = TouchFight(owner, false))
                    fight->healingDone += gain;
    }
};

class dc_combat_meter_player : public PlayerScript
{
public:
    dc_combat_meter_player() : PlayerScript("dc_combat_meter_player", { PLAYERHOOK_ON_PLAYER_LEAVE_COMBAT }) { }

    void OnPlayerLeaveCombat(Player* player) override
    {
        Fight* running = player->CustomData.Get<Fight>(FIGHT_KEY);
        if (!running || !running->active)
            return;

        Fight fight = *running;
        *running = Fight();

        if (!s_config.enabled)
            return;

        uint32 durationMs = getMSTimeDiff(fight.startMs, fight.lastEventMs);
        uint64 dealt = fight.damagePlayer + fight.damagePet + fight.damageMinion;
        if (durationMs < s_config.minDurationMs || (!dealt && !fight.healingDone))
            return;

        uint32 samplePct = s_config.samplePct;
        if (samplePct < 100 && urand(1, 100) > samplePct)
            return;

        WorldSession const* session = player->GetSession();
        Group const* group = player->GetGroup();

        if (s_config.hasSpellTable && !fight.spells.empty())
            WriteSpellTotals(player, fight, session && session->IsBot());

        // Numbers only, so the statement can be built as text. Optional columns are named only when they exist:
        // an INSERT naming a missing column would lose every row.
        std::string columns = "run_id, guid, is_bot, class, spec, level, item_level, group_size, map, zone, "
            "target_entry, target_level, target_rank, target_max_health, duration_ms, damage_player, damage_pet, "
            "damage_minion, healing_done, damage_taken, max_health, died";
        std::string values = Acore::StringFormat(
            "{}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}",
            s_config.runId.load(), player->GetGUID().GetCounter(), (session && session->IsBot()) ? 1 : 0,
            uint32(player->getClass()), uint32(player->GetMostPointsTalentTree()), uint32(player->GetLevel()),
            uint32(player->GetAverageItemLevel()), group ? group->GetMembersCount() : uint32(1), player->GetMapId(),
            player->GetZoneId(), fight.targetEntry, uint32(fight.targetLevel), uint32(fight.targetRank),
            fight.targetMaxHealth, durationMs, ClampToUInt32(fight.damagePlayer), ClampToUInt32(fight.damagePet),
            ClampToUInt32(fight.damageMinion), ClampToUInt32(fight.healingDone), ClampToUInt32(fight.damageTaken),
            player->GetMaxHealth(), player->IsAlive() ? 0 : 1);

        if (s_config.hasSpellHitColumns)
        {
            columns += ", biggest_spell_hit, biggest_spell_id";
            values += Acore::StringFormat(", {}, {}", fight.biggestSpellHit, fight.biggestSpellId);
        }

        if (s_config.hasKillerColumns)
        {
            columns += ", damage_taken_players, killer_type, killer_entry";
            values += Acore::StringFormat(", {}, {}, {}", ClampToUInt32(fight.damageTakenPlayers),
                uint32(fight.killerType), fight.killerEntry);
        }

        CharacterDatabase.Execute("INSERT INTO dc_bench_fight (" + columns + ") VALUES (" + values + ")");
    }

private:
    // One row per spell, pet and minion of the fight. Numbers only, so the statement can be built as text.
    static void WriteSpellTotals(Player const* player, Fight const& fight, bool isBot)
    {
        std::string values;
        values.reserve(fight.spells.size() * 64);
        for (SpellTotal const& total : fight.spells)
        {
            if (!values.empty())
                values += ", ";
            values += Acore::StringFormat("({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {})", s_config.runId.load(),
                player->GetGUID().GetCounter(), isBot ? 1 : 0, uint32(player->getClass()),
                uint32(player->GetMostPointsTalentTree()), uint32(player->GetLevel()), player->GetMapId(),
                uint32(total.source), total.casterEntry, total.spellId, ClampToUInt32(total.damage), total.hits);
        }

        CharacterDatabase.Execute("INSERT INTO dc_bench_spell (run_id, guid, is_bot, class, spec, level, map, source, "
            "caster_entry, spell_id, damage, hits) VALUES " + values);
    }
};

void AddSC_dc_combat_meter()
{
    new dc_combat_meter_world();
    new dc_combat_meter_unit();
    new dc_combat_meter_player();
}
