/*
 * This file is part of the DarkChaos-255 project, based on AzerothCore (GNU AGPL v3).
 *
 * Boss kit: extra boss abilities for Heroic, Mythic and Mythic+ that run next to a boss's own script, so the
 * stock instance scripts stay untouched. The kit is data: rows in the world table `dc_boss_kit` (timer, health
 * percent and pull events, target modes, difficulty and keystone gates), read once at startup and on
 * `.dca bosskit reload`. An entry without rows behaves exactly as before.
 *
 * The same file holds the Mythic+ trash spell-damage cap: in a running Mythic+ run, the part of a non-boss
 * creature's spell hit above DC.BossKit.TrashSpellCap.Threshold deals only 1/ExcessDivisor of itself.
 *
 * Threading: OnAllCreatureUpdate and the damage hook run on map threads. The kit store is written only on the
 * world thread while no map updates (OnBeforeWorldInitialized, and the reload command, which World::Update runs
 * after MapMgr::Update has joined its threads), so map threads read it without a lock. Per-creature state lives
 * in the creature's own CustomData, which only its map thread touches.
 */

#include "AllCreatureScript.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Config.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "DataMap.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "SpellMgr.h"
#include "TemporarySummon.h"
#include "ThreatManager.h"
#include "Timer.h"
#include "UnitScript.h"
#include "WorldScript.h"
#include "DC/MythicPlus/dc_mythicplus_run_manager.h"
#include <algorithm>
#include <atomic>
#include <limits>
#include <string>
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    enum class KitEvent : uint8
    {
        Timer  = 0,  // first cast after urand(param1, param2) ms of combat
        Health = 1,  // cast once health is at or below param1 percent
        Pull   = 2,  // cast when the boss engages
        Max
    };

    enum class KitTarget : uint8
    {
        Self          = 0,
        Victim        = 1,
        RandomPlayer  = 2,
        RandomNonTank = 3,
        Farthest      = 4,
        AllPlayers    = 5,  // every player on the threat list, always triggered
        Max
    };

    enum class CastOutcome : uint8
    {
        Done,   // cast went out (or failed for good): move on to the repeat timer
        Retry   // the boss could not cast right now: try again shortly
    };

    // Column count the SELECT below expects; checked against information_schema before the table is read,
    // because a query naming a missing table or column aborts the worldserver.
    constexpr uint64 KitColumnCount = 12;

    constexpr int32 TimerOff = -1;
    constexpr int32 RetryDelayMs = 250;
    constexpr uint32 MaxDelayMs = HOUR * IN_MILLISECONDS;
    constexpr uint32 HealthPctMax = 100;
    constexpr uint8 AllDifficultiesMask = (1 << MAX_DIFFICULTY) - 1;
    constexpr uint32 DefaultExcessDivisor = 20;
    constexpr uint32 Int32Max = uint32(std::numeric_limits<int32>::max());

    struct KitRow
    {
        uint32 spellId = 0;
        uint32 param1 = 0;
        uint32 param2 = 0;
        uint32 repeatMin = 0;
        uint32 repeatMax = 0;
        KitEvent event = KitEvent::Timer;
        KitTarget target = KitTarget::Victim;
        uint8 id = 0;
        uint8 minKeystone = 0;
        uint8 difficultyMask = 0;
        bool triggered = false;
    };

    struct BossKit
    {
        std::vector<KitRow> rows;
        bool needsKeystone = false;  // any row has minKeystone, so the pull asks the Mythic+ manager
    };

    struct KitStore
    {
        std::unordered_map<uint32, BossKit> kits;
        // Entry bounds let most creatures leave the update hook on two compares. Empty store: min > max.
        uint32 minEntry = std::numeric_limits<uint32>::max();
        uint32 maxEntry = 0;
        uint32 rowCount = 0;
        // Bumped on every load, so a boss mid-fight during a reload rebuilds its timers for the new rows.
        uint32 generation = 0;
    };

    KitStore sStore;

    std::atomic<bool> sKitEnabled{ true };
    std::atomic<int32> sTrashCapThreshold{ 0 };
    std::atomic<int32> sTrashCapDivisor{ int32(DefaultExcessDivisor) };

    std::string const KitStateKey = "dc_boss_kit";

    struct KitState : public DataMap::Base
    {
        std::vector<int32> timers;        // one per kit row, TimerOff = inactive this pull
        std::vector<ObjectGuid> targets;  // scratch list for KitTarget::AllPlayers, capacity kept between casts
        uint32 generation = 0;
        bool engaged = false;
    };

    uint32 Roll(uint32 low, uint32 high)
    {
        return high > low ? urand(low, high) : low;
    }

    bool LoadBossKits()
    {
        uint32 const oldMSTime = getMSTime();

        QueryResult probe = WorldDatabase.Query("SELECT COUNT(*) FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_boss_kit' AND COLUMN_NAME IN ('entry', 'id', "
            "'event', 'param1', 'param2', 'repeatMin', 'repeatMax', 'spellId', 'target', 'triggered', 'minKeystone', "
            "'difficultyMask')");
        if (!probe || probe->Fetch()[0].Get<uint64>() != KitColumnCount)
        {
            LOG_ERROR("scripts.dc", ">> Table `dc_boss_kit` is missing or out of date (apply the pending world SQL). "
                "Boss kits keep their previous state ({} rows).", sStore.rowCount);
            return false;
        }

        KitStore store;
        store.generation = sStore.generation + 1;

        if (QueryResult result = WorldDatabase.Query("SELECT `entry`, `id`, `event`, `param1`, `param2`, `repeatMin`, "
            "`repeatMax`, `spellId`, `target`, `triggered`, `minKeystone`, `difficultyMask` FROM `dc_boss_kit` "
            "ORDER BY `entry`, `id`"))
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 const entry = fields[0].Get<uint32>();
                uint8 const event = fields[2].Get<uint8>();
                uint8 const target = fields[8].Get<uint8>();

                KitRow row;
                row.id = fields[1].Get<uint8>();
                row.param1 = fields[3].Get<uint32>();
                row.param2 = fields[4].Get<uint32>();
                row.repeatMin = std::min(fields[5].Get<uint32>(), MaxDelayMs);
                row.repeatMax = std::min(fields[6].Get<uint32>(), MaxDelayMs);
                row.spellId = fields[7].Get<uint32>();
                row.triggered = fields[9].Get<uint8>() != 0;
                row.minKeystone = fields[10].Get<uint8>();
                row.difficultyMask = fields[11].Get<uint8>();

                if (!sObjectMgr->GetCreatureTemplate(entry))
                {
                    LOG_ERROR("scripts.dc", "Table `dc_boss_kit` ({}, {}): creature entry {} does not exist, skipped.",
                        entry, row.id, entry);
                    continue;
                }

                if (event >= uint8(KitEvent::Max))
                {
                    LOG_ERROR("scripts.dc", "Table `dc_boss_kit` ({}, {}): unknown event {}, skipped.", entry, row.id,
                        event);
                    continue;
                }
                row.event = KitEvent(event);

                if (target >= uint8(KitTarget::Max))
                {
                    LOG_ERROR("scripts.dc", "Table `dc_boss_kit` ({}, {}): unknown target {}, skipped.", entry, row.id,
                        target);
                    continue;
                }
                row.target = KitTarget(target);

                if (!sSpellMgr->GetSpellInfo(row.spellId))
                {
                    LOG_ERROR("scripts.dc", "Table `dc_boss_kit` ({}, {}): spell {} does not exist, skipped.", entry,
                        row.id, row.spellId);
                    continue;
                }

                if (row.event == KitEvent::Health && (!row.param1 || row.param1 > HealthPctMax))
                {
                    LOG_ERROR("scripts.dc", "Table `dc_boss_kit` ({}, {}): health row needs param1 in 1-{}, has {}, "
                        "skipped.", entry, row.id, HealthPctMax, row.param1);
                    continue;
                }

                if (row.difficultyMask & ~AllDifficultiesMask)
                {
                    LOG_ERROR("scripts.dc", "Table `dc_boss_kit` ({}, {}): difficultyMask {} has bits above {}, "
                        "skipped.", entry, row.id, row.difficultyMask, AllDifficultiesMask);
                    continue;
                }

                if (row.event == KitEvent::Timer)
                {
                    row.param1 = std::min(row.param1, MaxDelayMs);
                    row.param2 = std::max(row.param1, std::min(row.param2, MaxDelayMs));
                }
                row.repeatMax = std::max(row.repeatMin, row.repeatMax);

                BossKit& kit = store.kits[entry];
                kit.needsKeystone = kit.needsKeystone || row.minKeystone > 0;
                kit.rows.push_back(row);
                store.minEntry = std::min(store.minEntry, entry);
                store.maxEntry = std::max(store.maxEntry, entry);
                ++store.rowCount;
            } while (result->NextRow());
        }

        sStore = std::move(store);
        LOG_INFO("scripts.dc", ">> Loaded {} boss kit rows for {} creatures in {} ms", sStore.rowCount,
            sStore.kits.size(), GetMSTimeDiffToNow(oldMSTime));
        return true;
    }

    // Arms the timers for a new pull. freshPull is false when a reload replaced the rows mid-fight: the timers are
    // rebuilt but pull rows do not fire a second time.
    void BeginPull(Creature* me, BossKit const& kit, KitState& state, bool freshPull)
    {
        state.engaged = true;
        state.generation = sStore.generation;
        state.timers.assign(kit.rows.size(), TimerOff);

        Map* map = me->GetMap();
        uint8 const difficultyBit = uint8(1 << map->GetDifficulty());

        uint32 keystone = 0;
        if (kit.needsKeystone && sMythicRuns->IsMythicPlusActive(map))
            keystone = sMythicRuns->GetKeystoneLevel(map);

        for (std::size_t i = 0; i < kit.rows.size(); ++i)
        {
            KitRow const& row = kit.rows[i];
            if (row.difficultyMask && !(row.difficultyMask & difficultyBit))
                continue;

            if (row.minKeystone && keystone < row.minKeystone)
                continue;

            switch (row.event)
            {
                case KitEvent::Timer:
                    state.timers[i] = int32(Roll(row.param1, row.param2));
                    break;
                case KitEvent::Health:
                    state.timers[i] = 0;
                    break;
                case KitEvent::Pull:
                    state.timers[i] = freshPull ? 0 : TimerOff;
                    break;
                default:
                    break;
            }
        }
    }

    Unit* SelectKitTarget(Creature* me, KitTarget target)
    {
        Unit* selected = nullptr;
        switch (target)
        {
            case KitTarget::Self:
                return me;
            case KitTarget::RandomPlayer:
                selected = me->AI()->SelectTarget(SelectTargetMethod::Random, 0, 0.0f, true);
                break;
            case KitTarget::RandomNonTank:
                selected = me->AI()->SelectTarget(SelectTargetMethod::Random, 0, 0.0f, true, false);
                break;
            case KitTarget::Farthest:
                selected = me->AI()->SelectTarget(SelectTargetMethod::MaxDistance, 0, 0.0f, true);
                break;
            default:
                break;
        }

        return selected ? selected : me->GetVictim();
    }

    bool IsTransientCastFailure(SpellCastResult result)
    {
        switch (result)
        {
            case SPELL_FAILED_SPELL_IN_PROGRESS:
            case SPELL_FAILED_NOT_READY:
            case SPELL_FAILED_OUT_OF_RANGE:
            case SPELL_FAILED_LINE_OF_SIGHT:
                return true;
            default:
                return false;
        }
    }

    CastOutcome TryCast(Creature* me, KitRow const& row, KitState& state)
    {
        if (me->HasUnitState(UNIT_STATE_LOST_CONTROL))
            return CastOutcome::Retry;

        if (!row.triggered && me->HasUnitState(UNIT_STATE_CASTING))
            return CastOutcome::Retry;

        if (row.target == KitTarget::AllPlayers)
        {
            // Snapshot first: a cast can kill a target and change the threat list under the iterator.
            state.targets.clear();
            for (ThreatReference const* ref : me->GetThreatMgr().GetUnsortedThreatList())
                if (ref->IsAvailable() && ref->GetVictim()->IsPlayer())
                    state.targets.push_back(ref->GetVictim()->GetGUID());

            if (state.targets.empty())
                return CastOutcome::Retry;

            for (ObjectGuid const& guid : state.targets)
                if (Player* player = ObjectAccessor::GetPlayer(*me, guid))
                    me->CastSpell(player, row.spellId, TRIGGERED_FULL_MASK);

            return CastOutcome::Done;
        }

        Unit* target = SelectKitTarget(me, row.target);
        if (!target)
            return CastOutcome::Retry;

        SpellCastResult const result = me->CastSpell(target, row.spellId,
            row.triggered ? TRIGGERED_FULL_MASK : TRIGGERED_NONE);
        return IsTransientCastFailure(result) ? CastOutcome::Retry : CastOutcome::Done;
    }

    bool IsKitActive(Creature const* me)
    {
        return me->IsAlive() && me->IsInCombat() && !me->IsInEvadeMode() && !me->IsCharmedOwnedByPlayerOrPlayer()
            && me->AI();
    }

    void UpdateKit(Creature* me, BossKit const& kit, uint32 diff)
    {
        if (!IsKitActive(me))
        {
            // Evade, death, combat end or a player taking control: the next engage is a new pull.
            if (KitState* state = me->CustomData.Get<KitState>(KitStateKey))
                state->engaged = false;
            return;
        }

        // In combat without a victim is a phase (submerged, airborne, untargetable): hold the timers, keep the pull.
        if (!me->GetVictim())
            return;

        KitState* state = me->CustomData.GetDefault<KitState>(KitStateKey);
        if (!state->engaged)
            BeginPull(me, kit, *state, true);
        else if (state->generation != sStore.generation)
            BeginPull(me, kit, *state, false);

        int32 const elapsed = int32(std::min(diff, Int32Max));
        for (std::size_t i = 0; i < kit.rows.size(); ++i)
        {
            int32& timer = state->timers[i];
            if (timer == TimerOff)
                continue;

            KitRow const& row = kit.rows[i];
            if (row.event == KitEvent::Health && me->HealthAbovePct(int32(row.param1)))
                continue;

            timer = std::max(timer - elapsed, 0);
            if (timer > 0)
                continue;

            if (TryCast(me, row, *state) == CastOutcome::Retry)
                timer = RetryDelayMs;
            else if (row.repeatMin)
                timer = int32(Roll(row.repeatMin, row.repeatMax));
            else
                timer = TimerOff;

            // A cast can end the fight (the boss dies to a reflect, a spell resets it): stop here, and the next
            // update takes the reset path.
            if (!IsKitActive(me))
                break;
        }
    }

    // A creature with kit rows counts as a boss too, so its kit spells are never capped as trash.
    bool CountsAsBoss(Creature const* creature)
    {
        return creature->IsDungeonBoss() || creature->isWorldBoss() || sStore.kits.contains(creature->GetEntry())
            || sMythicRuns->IsBossCreature(creature);
    }

    // Bosses and whatever a boss summons keep their full damage: those hits are encounter mechanics.
    bool IsBossOrBossSummon(Creature const* creature)
    {
        if (CountsAsBoss(creature))
            return true;

        if (TempSummon const* summon = creature->ToTempSummon())
            if (Creature const* summoner = summon->GetSummonerCreatureBase())
                return CountsAsBoss(summoner);

        return false;
    }
}

class dc_boss_kit_world : public WorldScript
{
public:
    dc_boss_kit_world() : WorldScript("dc_boss_kit_world",
        { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_BEFORE_WORLD_INITIALIZED }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        sKitEnabled.store(sConfigMgr->GetOption<bool>("DC.BossKit.Enable", true), std::memory_order_relaxed);

        uint32 const threshold = sConfigMgr->GetOption<uint32>("DC.BossKit.TrashSpellCap.Threshold", 0);
        sTrashCapThreshold.store(int32(std::min(threshold, Int32Max)), std::memory_order_relaxed);

        uint32 const divisor = sConfigMgr->GetOption<uint32>("DC.BossKit.TrashSpellCap.ExcessDivisor",
            DefaultExcessDivisor);
        sTrashCapDivisor.store(int32(std::clamp<uint32>(divisor, 1, Int32Max)), std::memory_order_relaxed);
    }

    // After spells and creature templates are loaded (rows are validated against both), before any map updates.
    void OnBeforeWorldInitialized() override
    {
        LoadBossKits();
    }
};

class dc_boss_kit_creature : public AllCreatureScript
{
public:
    dc_boss_kit_creature() : AllCreatureScript("dc_boss_kit_creature") { }

    // Runs for every creature on every update. A creature without kit rows leaves on the bounds compare or one
    // hash lookup; per-creature state is created only for kit entries, and only once they fight.
    void OnAllCreatureUpdate(Creature* creature, uint32 diff) override
    {
        if (!sKitEnabled.load(std::memory_order_relaxed))
            return;

        uint32 const entry = creature->GetEntry();
        if (entry < sStore.minEntry || entry > sStore.maxEntry)
            return;

        auto const itr = sStore.kits.find(entry);
        if (itr == sStore.kits.end())
            return;

        UpdateKit(creature, itr->second, diff);
    }
};

class dc_boss_kit_trash_spell_cap : public UnitScript
{
public:
    dc_boss_kit_trash_spell_cap() : UnitScript("dc_boss_kit_trash_spell_cap", true,
        { UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN }) { }

    // Called from Unit::CalculateSpellDamageTaken for direct spell damage, before armor, resistances and absorbs,
    // and before the Mythic+ keystone multiplier (applied later in DealDamage), so the threshold is compared with
    // the creature's own spell amount.
    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* /*spellInfo*/) override
    {
        int32 const threshold = sTrashCapThreshold.load(std::memory_order_relaxed);
        if (threshold <= 0 || damage <= threshold || !attacker || !target)
            return;

        Creature* creature = attacker->ToCreature();
        if (!creature || creature->IsControlledByPlayer() || creature->IsCharmedOwnedByPlayerOrPlayer())
            return;

        // Only hits on the players' side: players, their pets and guardians.
        if (!target->GetCharmerOrOwnerPlayerOrPlayerItself())
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon() || IsBossOrBossSummon(creature))
            return;

        // Last, because it takes the Mythic+ manager's lock.
        if (!sMythicRuns->IsMythicPlusActive(map))
            return;

        int32 const divisor = sTrashCapDivisor.load(std::memory_order_relaxed);
        damage = threshold + (damage - threshold) / divisor;
    }
};

class dc_boss_kit_commandscript : public CommandScript
{
public:
    dc_boss_kit_commandscript() : CommandScript("dc_boss_kit_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        // Rebuilds the store that map threads read; the command runs on the world thread between map updates.
        static ChatCommandTable bossKitTable =
        {
            { "reload", HandleReload, SEC_ADMINISTRATOR, Console::Yes }
        };
        static ChatCommandTable dcaTable =
        {
            { "bosskit", bossKitTable }
        };
        static ChatCommandTable commandTable =
        {
            { "dca", dcaTable }
        };
        return commandTable;
    }

    static bool HandleReload(ChatHandler* handler)
    {
        if (!LoadBossKits())
        {
            // SendSysMessage, not the formatting SendErrorMessage overload: that one prints nothing on the console.
            handler->SendSysMessage("Table dc_boss_kit is missing or out of date, the boss kit was not changed.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        handler->SendSysMessage(Acore::StringFormat("Boss kit reloaded: {} rows for {} creatures.", sStore.rowCount,
            sStore.kits.size()));
        return true;
    }
};

void AddSC_dc_boss_kit()
{
    new dc_boss_kit_world();
    new dc_boss_kit_creature();
    new dc_boss_kit_trash_spell_cap();
    new dc_boss_kit_commandscript();
}
