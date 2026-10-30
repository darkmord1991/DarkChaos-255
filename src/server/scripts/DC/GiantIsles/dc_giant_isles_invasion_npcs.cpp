/*
 * Giant Isles - Invasion: creature AIs
 * ==========================================================================
 * The combat/flavour units of the Zandalari incursion:
 *   - npc_invasion_mob      : every basic invader. Marches a route up the beach,
 *                             carries a per-entry ability kit and shares kill
 *                             credit with everyone who fought it.
 *   - npc_invasion_defender : the Beast Hunters and the mobilized guards.
 *   - npc_invasion_medic    : expedition healer behind the line.
 *   - npc_invasion_zuljin   : Elder Zul'jin taking the field for the warlord.
 *   - npc_invasion_objective: standards, effigies, engines and pylons.
 *   - npc_invasion_impact   : invisible marker that rains fire where it stands.
 *   - npc_invasion_leader   : General Rak'zor, narrator and final reckoning.
 *   - npc_invasion_commander: Warlord Zul'mar, the wave-4 boss.
 *   - npc_giant_isles_invasion_questgiver: blue daily/weekly "!" override.
 *
 * The orchestrator (dc_giant_isles_invasion.cpp) drives stages/spawning and
 * calls into these via the GI_* bridge declared in the internal header.
 * ==========================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "ScriptedCreature.h"
#include "EventMap.h"
#include "GameTime.h"
#include "Group.h"
#include "Map.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "QuestDef.h"
#include "SpellInfo.h"
#include "Timer.h"
#include "Random.h"

#include "dc_giant_isles_invasion_internal.h"
#include "DC/QOL/dc_questgiver_status_override.h"

#include <algorithm>
#include <cmath>
#include <map>
#include <vector>

using namespace std::chrono_literals;
using namespace DCGiantIsles;

namespace
{
    // Every id here was checked against Spell.dbc. The old kit carried labels
    // that did not match the spell (11971 "Sinister Strike" is Sunder Armor,
    // 16827 "Bite" is the rank 1 pet Claw, 32064 "Commanding Shout" is Battle
    // Shout) and classic-era damage values that a level 80 never noticed.
    enum InvasionSpells : uint32
    {
        SPELL_CHARGE            = 22120,
        SPELL_HEROIC_STRIKE     = 57846,
        SPELL_THROW             = 38904,
        SPELL_NET               = 6533,
        SPELL_SUNDER_ARMOR      = 50370,
        SPELL_SHIELD_BASH       = 11972,
        SPELL_CLEAVE            = 15496,
        SPELL_WHIRLWIND         = 38619,
        SPELL_ENRAGE            = 8599,
        SPELL_BLOOD_FURY        = 55285,    // +100% haste, +20% damage
        SPELL_HEX               = 66054,
        SPELL_CHAIN_LIGHTNING   = 61879,
        SPELL_LIGHTNING_BOLT    = 59006,
        SPELL_HEALING_WAVE      = 68318,
        SPELL_MORTAL_STRIKE     = 35054,
        SPELL_WAR_STOMP         = 11876,
        SPELL_SHADOW_BOLT       = 69387,
        SPELL_HEALING_WARD      = 5605,
        SPELL_MULTI_SHOT        = 34879,
        SPELL_PUNCTURE          = 55276,
        SPELL_SHIELD_WALL       = 871,
        SPELL_TAIL_SWEEP        = 15847,
        SPELL_TERRIFYING_ROAR   = 14100,
        SPELL_SWOOP             = 23919,
        SPELL_GROUND_TREMOR     = 55142,
        SPELL_GRIEVOUS_THROW    = 43093,
        SPELL_BATTLE_SHOUT      = 31403,
        SPELL_EVASION           = 5277,
        SPELL_RAIN_OF_FIRE      = 57757,
        SPELL_THUNDERCLAP       = 38537,
        SPELL_BLOODLUST         = 65980,
        SPELL_SHADOW_CHANNELING = 43897,    // self-only channel visual
    };

    enum WarlordEvents
    {
        EVENT_MORTAL_STRIKE     = 1,
        EVENT_WHIRLWIND         = 2,
        EVENT_WAR_SHOUT         = 3,
        EVENT_CHECK_GUARDS      = 4,
        EVENT_GRIEVOUS_THROW    = 5,
        EVENT_BLOOD_NOVA        = 6,
        EVENT_BLOOD_NOVA_BLAST  = 7,
        EVENT_RAIN_OF_FIRE      = 8,
        EVENT_THUNDERCLAP       = 9,
        EVENT_BLOODLUST         = 10,
    };

    enum WarlordTexts : uint8
    {
        SAY_WARLORD_AGGRO       = 0,
        SAY_WARLORD_ENRAGE      = 1,
        SAY_WARLORD_SLAY        = 2,
        SAY_WARLORD_DEATH       = 3,
        SAY_WARLORD_BEAST       = 4,
        SAY_WARLORD_POSSESSED   = 5,
        EMOTE_WARLORD_BLOOD_NOVA = 6,
    };

    enum ZuljinTexts : uint8
    {
        SAY_ZULJIN_ARRIVES      = 0,
        SAY_ZULJIN_FALLS_BACK   = 1,
        SAY_ZULJIN_VICTORY      = 2,
        SAY_ZULJIN_RECKONING    = 3,
    };

    enum InvaderTexts : uint8
    {
        SAY_INVADER_AGGRO       = 0,
        SAY_INVADER_DEATH       = 1,
    };

    constexpr uint8 EMOTE_ROGUE_ARRIVES = 0;

    // Base points for the warlord's telegraphed Blood Nova: a hit that hurts,
    // and stops hurting for anyone who walked out of the 25 yard radius.
    constexpr int32 BLOOD_NOVA_BASE_POINTS = 14000;

    constexpr uint32 MARCH_WATCHDOG_MS = 6000;
    constexpr uint32 MARCH_LANDING_DELAY_MS = 6000;
    constexpr float MARCH_SCATTER_YARDS = 4.0f;
    constexpr uint32 BATTLE_CRY_CHANCE = 12;
    constexpr size_t MAX_TRACKED_ATTACKERS = 25;

    // Kit ability event ids start here so they never collide with the boss
    // EventMap ids above.
    constexpr uint32 EVENT_KIT_ABILITY_BASE = 100;

    static uint64 GetNowMs()
    {
        return static_cast<uint64>(GameTime::GetGameTimeMS().count());
    }

    static void RememberAttacker(std::vector<ObjectGuid>& attackers, Unit* attacker)
    {
        if (!attacker || attackers.size() >= MAX_TRACKED_ATTACKERS)
            return;

        Player* player = attacker->GetCharmerOrOwnerPlayerOrPlayerItself();
        if (!player)
            return;

        ObjectGuid const guid = player->GetGUID();
        if (std::find(attackers.begin(), attackers.end(), guid) == attackers.end())
            attackers.push_back(guid);
    }

    // creature_text only carries battle cries for the troll invaders; a Talk()
    // on a missing group is a logged error, so the beasts must never ask.
    static bool HasBattleCries(uint32 entry)
    {
        return entry >= NPC_ZANDALARI_INVADER && entry <= NPC_ZANDALARI_HONOR_GUARD
            && entry != NPC_WARLORD_ZULMAR;
    }

    // =======================================================================
    // Combat ability kits, shared by both sides of the battle.
    // =======================================================================
    enum InvaderKitTarget : uint8
    {
        KIT_TARGET_VICTIM   = 0, // cast at the current melee/ranged victim
        KIT_TARGET_SELF     = 1, // self-buff / pbaoe centred on the caster
    };

    struct InvaderAbility
    {
        uint32 spellId;
        uint32 initialMin;
        uint32 initialMax;
        uint32 repeatMin;   // 0 -> reuse the initial window so it still recurs
        uint32 repeatMax;
        uint8  target;
    };

    struct InvaderKit
    {
        std::vector<InvaderAbility> abilities;
        uint32 lowHealthSpell;  // 0 -> no panic ability
        uint8  lowHealthPct;    // self-cast once below this health percent
    };

    InvaderKit const* GetInvaderKit(uint32 entry)
    {
        static std::map<uint32, InvaderKit> const kits =
        {
            { NPC_ZANDALARI_INVADER, {
                { { SPELL_CHARGE,         3000, 3000,  9000, 20000, KIT_TARGET_VICTIM },
                  { SPELL_HEROIC_STRIKE,  5000, 7000,  6000,  9000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_ZANDALARI_SCOUT, {
                { { SPELL_THROW,          2000, 4000,  6000,  9000, KIT_TARGET_VICTIM } },
                SPELL_EVASION, 30 } },

            { NPC_ZANDALARI_SPEARMAN, {
                { { SPELL_THROW,          3000, 5000,  8000, 14000, KIT_TARGET_VICTIM },
                  { SPELL_NET,           10000,15000, 18000, 26000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_ZANDALARI_WARRIOR, {
                { { SPELL_SUNDER_ARMOR,   5000, 8000,  7000, 11000, KIT_TARGET_VICTIM },
                  { SPELL_SHIELD_BASH,    9000,13000, 12000, 16000, KIT_TARGET_VICTIM },
                  { SPELL_CLEAVE,         6000, 9000,  8000, 12000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_ZANDALARI_BERSERKER, {
                { { SPELL_CLEAVE,         6000, 8000,  6000,  9000, KIT_TARGET_VICTIM },
                  { SPELL_WHIRLWIND,     12000,16000, 14000, 18000, KIT_TARGET_SELF } },
                SPELL_BLOOD_FURY, 25 } },

            { NPC_ZANDALARI_SHADOW_HUNTER, {
                { { SPELL_HEX,           12000,16000, 18000, 24000, KIT_TARGET_VICTIM },
                  { SPELL_CHAIN_LIGHTNING, 3000, 5000,  8000, 14000, KIT_TARGET_VICTIM },
                  { SPELL_HEALING_WAVE,  14000,18000, 16000, 22000, KIT_TARGET_SELF } },
                0, 0 } },

            { NPC_ZANDALARI_BLOOD_GUARD, {
                { { SPELL_MORTAL_STRIKE,  6000, 8000,  9000, 13000, KIT_TARGET_VICTIM },
                  { SPELL_WAR_STOMP,     12000,15000, 16000, 20000, KIT_TARGET_SELF } },
                0, 0 } },

            { NPC_ZANDALARI_WITCH_DOCTOR, {
                { { SPELL_SHADOW_BOLT,    2000, 3000,  3500,  5000, KIT_TARGET_VICTIM },
                  { SPELL_HEALING_WARD,  15000,20000, 22000, 30000, KIT_TARGET_SELF } },
                0, 0 } },

            { NPC_ZANDALARI_BEAST_TAMER, {
                { { SPELL_MULTI_SHOT,     8000,12000, 10000, 14000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_ZANDALARI_WAR_RAPTOR, {
                { { SPELL_PUNCTURE,       4000, 6000, 12000, 16000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_ZANDALARI_HONOR_GUARD, {
                { { SPELL_HEROIC_STRIKE,  4000, 6000,  6000,  9000, KIT_TARGET_VICTIM } },
                SPELL_SHIELD_WALL, 20 } },

            // ---- War-beasts ----
            { NPC_ZANDALARI_WAR_DIREHORN, {
                { { SPELL_CHARGE,         1000, 3000,  9000, 14000, KIT_TARGET_VICTIM },
                  { SPELL_PUNCTURE,       4000, 6000, 11000, 15000, KIT_TARGET_VICTIM },
                  { SPELL_WAR_STOMP,     10000,14000, 16000, 22000, KIT_TARGET_SELF } },
                0, 0 } },

            { NPC_ZANDALARI_PTERRORDAX_BOMBER, {
                { { SPELL_SWOOP,          5000, 9000,  9000, 14000, KIT_TARGET_SELF } },
                0, 0 } },

            { NPC_PRIMAL_DEVILSAUR, {
                { { SPELL_CLEAVE,         4000, 7000,  7000, 11000, KIT_TARGET_VICTIM },
                  { SPELL_TAIL_SWEEP,     9000,13000, 14000, 19000, KIT_TARGET_SELF },
                  { SPELL_PUNCTURE,       5000, 8000, 12000, 16000, KIT_TARGET_VICTIM } },
                SPELL_ENRAGE, 30 } },

            // ---- War plan units ----
            { NPC_ZANDALARI_DINOMANCER, {
                { { SPELL_CHAIN_LIGHTNING, 2000, 4000,  7000, 10000, KIT_TARGET_VICTIM },
                  { SPELL_HEX,           10000,14000, 18000, 24000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_ZANDALARI_ENGINE_CREW, {
                { { SPELL_THROW,          2000, 4000,  7000, 11000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_ZANDALARI_BEASTMASTER, {
                { { SPELL_MULTI_SHOT,     3000, 5000,  8000, 12000, KIT_TARGET_VICTIM },
                  { SPELL_NET,            8000,12000, 16000, 22000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_ZANDALARI_SKY_CALLER, {
                { { SPELL_LIGHTNING_BOLT, 1000, 2000,  3000,  4500, KIT_TARGET_VICTIM },
                  { SPELL_CHAIN_LIGHTNING, 5000, 8000,  9000, 13000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_STAMPEDING_DIREHORN, {
                { { SPELL_WAR_STOMP,      1000, 3000, 10000, 14000, KIT_TARGET_SELF } },
                0, 0 } },

            { NPC_BOUND_BEHEMOTH, {
                { { SPELL_GROUND_TREMOR,  6000, 9000, 14000, 18000, KIT_TARGET_SELF },
                  { SPELL_TAIL_SWEEP,     5000, 8000, 10000, 14000, KIT_TARGET_SELF },
                  { SPELL_PUNCTURE,       3000, 5000, 11000, 15000, KIT_TARGET_VICTIM },
                  { SPELL_TERRIFYING_ROAR, 15000,20000, 28000, 36000, KIT_TARGET_SELF } },
                SPELL_BLOOD_FURY, 25 } },

            { NPC_ROGUE_TYRANT, {
                { { SPELL_CLEAVE,         3000, 5000,  6000,  9000, KIT_TARGET_VICTIM },
                  { SPELL_TAIL_SWEEP,     7000, 9000, 11000, 15000, KIT_TARGET_SELF },
                  { SPELL_TERRIFYING_ROAR, 12000,16000, 24000, 30000, KIT_TARGET_SELF } },
                SPELL_ENRAGE, 35 } },

            // ---- Defenders ----
            { NPC_BEAST_HUNTER, {
                { { SPELL_THROW,          2000, 4000,  6000,  9000, KIT_TARGET_VICTIM },
                  { SPELL_HEROIC_STRIKE,  5000, 7000,  7000, 10000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_BEAST_HUNTER_VETERAN, {
                { { SPELL_CLEAVE,         4000, 6000,  7000, 10000, KIT_TARGET_VICTIM },
                  { SPELL_HEROIC_STRIKE,  3000, 5000,  6000,  9000, KIT_TARGET_VICTIM } },
                SPELL_SHIELD_WALL, 25 } },

            { NPC_BEAST_HUNTER_TRAPPER, {
                { { SPELL_NET,            2000, 4000, 12000, 16000, KIT_TARGET_VICTIM },
                  { SPELL_MULTI_SHOT,     5000, 8000,  9000, 13000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_BEAST_HUNTER_WARLORD, {
                { { SPELL_MORTAL_STRIKE,  4000, 6000,  8000, 11000, KIT_TARGET_VICTIM },
                  { SPELL_WHIRLWIND,      9000,12000, 14000, 18000, KIT_TARGET_SELF },
                  { SPELL_BATTLE_SHOUT,   1000, 2000, 45000, 60000, KIT_TARGET_SELF } },
                0, 0 } },

            { NPC_PRIMAL_GUARDIAN, {
                { { SPELL_HEROIC_STRIKE,  3000, 5000,  6000,  9000, KIT_TARGET_VICTIM } },
                0, 0 } },

            { NPC_ANCIENT_PRIMAL_GUARDIAN, {
                { { SPELL_CLEAVE,         3000, 5000,  7000, 10000, KIT_TARGET_VICTIM } },
                SPELL_SHIELD_WALL, 25 } },

            { NPC_ELDER_ZULJIN_BATTLE, {
                { { SPELL_GRIEVOUS_THROW, 2000, 4000,  9000, 13000, KIT_TARGET_VICTIM },
                  { SPELL_CHAIN_LIGHTNING, 4000, 6000,  8000, 11000, KIT_TARGET_VICTIM },
                  { SPELL_HEALING_WAVE,  10000,14000, 14000, 20000, KIT_TARGET_SELF } },
                0, 0 } },
        };

        auto const itr = kits.find(entry);
        return itr != kits.end() ? &itr->second : nullptr;
    }

    // Everything that fights on the beach: the kit scheduler, plus the march
    // that carries invaders up a route and resumes it after every skirmish.
    struct InvasionBattleAI : public ScriptedAI
    {
        explicit InvasionBattleAI(Creature* creature) : ScriptedAI(creature) { }

        void SetData(uint32 type, uint32 value) override
        {
            if (type == DATA_MARCH_ROUTE)
            {
                _route = static_cast<int32>(value);
                _waypoint = 0;
                _atLine = false;
                _scatterX = frand(-MARCH_SCATTER_YARDS, MARCH_SCATTER_YARDS);
                _scatterY = frand(-MARCH_SCATTER_YARDS, MARCH_SCATTER_YARDS);
                _lastPosition = me->GetPosition();
                _watchdogMs = MARCH_WATCHDOG_MS;
                SendMarchOrder();
            }
            else if (type == DATA_MARCH_RESUME)
            {
                _marchPending = true;
            }
            else if (type == DATA_MARCH_ROUTE_DELAYED)
            {
                _route = static_cast<int32>(value);
                _waypoint = 0;
                _atLine = false;
                _landingDelayMs = MARCH_LANDING_DELAY_MS;
            }
        }

        void MovementInform(uint32 type, uint32 id) override
        {
            if (type != POINT_MOTION_TYPE || id != POINT_MARCH)
                return;

            ++_waypoint;
            _marchPending = true;
        }

        void EnterEvadeMode(EvadeReason why = EVADE_REASON_OTHER) override
        {
            // Nothing marching on the line ever walks back to its landing: it
            // picks the route up again from wherever the skirmish left it.
            if (_route == ROUTE_NONE || !GI_IsBattleRunning())
            {
                ScriptedAI::EnterEvadeMode(why);
                return;
            }

            if (!_EnterEvadeMode(why))
                return;

            me->ClearUnitState(UNIT_STATE_EVADE);
            me->SetHomePosition(me->GetPosition());
            Reset();
            _marchPending = true;
        }

    protected:
        EventMap _kitEvents;
        InvaderKit const* _kit = nullptr;
        bool _lowHealthCast = false;

        void ClearKit()
        {
            _kitEvents.Reset();
            _kit = nullptr;
            _lowHealthCast = false;
        }

        void ScheduleKit()
        {
            ClearKit();
            _kit = GetInvaderKit(me->GetEntry());

            if (!_kit)
                return;

            for (uint32 i = 0; i < _kit->abilities.size(); ++i)
            {
                InvaderAbility const& ability = _kit->abilities[i];
                _kitEvents.ScheduleEvent(EVENT_KIT_ABILITY_BASE + i,
                    Milliseconds(ability.initialMin), Milliseconds(ability.initialMax));
            }
        }

        void CheckLowHealthAbility()
        {
            if (!_kit || _lowHealthCast || _kit->lowHealthSpell == 0)
                return;

            if (me->HealthBelowPct(_kit->lowHealthPct))
            {
                _lowHealthCast = true;
                DoCast(me, _kit->lowHealthSpell, true);
            }
        }

        void UpdateKit(uint32 diff)
        {
            _kitEvents.Update(diff);

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            while (uint32 eventId = _kitEvents.ExecuteEvent())
            {
                if (eventId < EVENT_KIT_ABILITY_BASE || !_kit)
                    continue;

                uint32 const index = eventId - EVENT_KIT_ABILITY_BASE;
                if (index >= _kit->abilities.size())
                    continue;

                InvaderAbility const& ability = _kit->abilities[index];
                if (ability.target == KIT_TARGET_SELF)
                    DoCast(me, ability.spellId, false);
                else
                    DoCastVictim(ability.spellId);

                uint32 const repeatMin = ability.repeatMin ? ability.repeatMin : ability.initialMin;
                uint32 const repeatMax = ability.repeatMax ? ability.repeatMax : ability.initialMax;
                _kitEvents.ScheduleEvent(eventId, Milliseconds(repeatMin), Milliseconds(repeatMax));
            }
        }

        // Out of combat: walk the next leg, and notice a march that has stalled
        // (knocked off the path, or a leg PathGenerator could not finish).
        void UpdateMarch(uint32 diff)
        {
            if (_route == ROUTE_NONE || !GI_IsBattleRunning())
                return;

            if (_landingDelayMs > 0)
            {
                if (_landingDelayMs > diff)
                {
                    _landingDelayMs -= diff;
                    return;
                }

                _landingDelayMs = 0;
                _lastPosition = me->GetPosition();
                _watchdogMs = MARCH_WATCHDOG_MS;
                SendMarchOrder();
                return;
            }

            if (_marchPending)
            {
                _marchPending = false;
                SendMarchOrder();
                return;
            }

            if (_watchdogMs > diff)
            {
                _watchdogMs -= diff;
                return;
            }

            _watchdogMs = MARCH_WATCHDOG_MS;

            if (_atLine)
            {
                GI_InvaderReachedLine(me);
                return;
            }

            if (me->GetExactDist2d(_lastPosition.GetPositionX(), _lastPosition.GetPositionY()) < 2.0f)
            {
                ++_waypoint;
                SendMarchOrder();
            }

            _lastPosition = me->GetPosition();
        }

    private:
        int32 _route = ROUTE_NONE;
        uint8 _waypoint = 0;
        bool _atLine = false;
        bool _marchPending = false;
        float _scatterX = 0.0f;
        float _scatterY = 0.0f;
        uint32 _watchdogMs = 0;
        uint32 _landingDelayMs = 0;
        Position _lastPosition;

        void SendMarchOrder()
        {
            if (!me->IsAlive() || me->IsInCombat())
                return;

            MarchRouteView const view = GetMarchRoute(_route);
            if (!view.points)
                return;

            if (_waypoint >= view.count)
            {
                _atLine = true;
                GI_InvaderReachedLine(me);
                return;
            }

            InvasionPoint const& point = view.points[_waypoint];
            float const x = point.x + _scatterX;
            float const y = point.y + _scatterY;
            float z = point.z;

            float const groundZ = me->GetMap()->GetHeight(x, y, z + 5.0f);
            if (groundZ > INVALID_HEIGHT)
                z = groundZ;

            me->SetWalk(false);
            me->GetMotionMaster()->Clear();
            me->GetMotionMaster()->MovePoint(POINT_MARCH, x, y, z);
        }
    };

    // =======================================================================
    // npc_invasion_mob - every basic invader.
    // =======================================================================
    class npc_invasion_mob : public CreatureScript
    {
    public:
        npc_invasion_mob() : CreatureScript("npc_invasion_mob") { }

        struct npc_invasion_mobAI : public InvasionBattleAI
        {
            npc_invasion_mobAI(Creature* creature) : InvasionBattleAI(creature) { }

            std::vector<ObjectGuid> _raptorGuids;
            std::vector<ObjectGuid> _attackers;

            void Reset() override
            {
                ClearKit();
                PruneRaptors();

                // Cleanup any stray summon instances if event is not active.
                if (!GI_IsInvasionActive() && me->IsSummon())
                    me->DespawnOrUnsummon(1s);
            }

            void JustEngagedWith(Unit* who) override
            {
                if (me->GetEntry() == NPC_ZANDALARI_BEAST_TAMER && GI_IsInvasionActive())
                    SummonWarRaptor(who);

                if (HasBattleCries(me->GetEntry()) && roll_chance_i(BATTLE_CRY_CHANCE))
                    Talk(SAY_INVADER_AGGRO);

                ScheduleKit();
            }

            void DamageTaken(Unit* attacker, uint32& /*damage*/, DamageEffectType /*damagetype*/,
                SpellSchoolMask /*schoolMask*/) override
            {
                RememberAttacker(_attackers, attacker);
                CheckLowHealthAbility();
            }

            void JustDied(Unit* /*killer*/) override
            {
                DespawnRaptors();

                if (HasBattleCries(me->GetEntry()) && roll_chance_i(BATTLE_CRY_CHANCE))
                    Talk(SAY_INVADER_DEATH);

                GI_CreditParticipants(me, _attackers);
            }

            void DoAction(int32 action) override
            {
                if (action == ACTION_ROGUE_ARRIVES)
                    Talk(EMOTE_ROGUE_ARRIVES);
            }

            void UpdateAI(uint32 diff) override
            {
                if (!UpdateVictim())
                {
                    UpdateMarch(diff);
                    return;
                }

                UpdateKit(diff);
                DoMeleeAttackIfReady();
            }

        private:
            void PruneRaptors()
            {
                if (_raptorGuids.empty())
                    return;

                Map* map = me->GetMap();
                if (!map)
                {
                    _raptorGuids.clear();
                    return;
                }

                _raptorGuids.erase(
                    std::remove_if(_raptorGuids.begin(), _raptorGuids.end(),
                        [map](ObjectGuid const& guid)
                        {
                            Creature* c = map->GetCreature(guid);
                            return !c || !c->IsAlive();
                        }),
                    _raptorGuids.end());
            }

            void DespawnRaptors()
            {
                if (_raptorGuids.empty())
                    return;

                Map* map = me->GetMap();
                if (!map)
                {
                    _raptorGuids.clear();
                    return;
                }

                for (ObjectGuid const& guid : _raptorGuids)
                {
                    if (Creature* c = map->GetCreature(guid))
                        c->DespawnOrUnsummon(1s);
                }

                _raptorGuids.clear();
            }

            void SummonWarRaptor(Unit* target)
            {
                PruneRaptors();

                if (!_raptorGuids.empty() || !GI_HasRoomForWarBeast(me->GetMap()))
                    return;

                Position pos = me->GetPosition();
                pos.m_positionX += frand(-1.5f, 1.5f);
                pos.m_positionY += frand(-1.5f, 1.5f);

                Creature* raptor = me->SummonCreature(
                    NPC_ZANDALARI_WAR_RAPTOR,
                    pos,
                    TEMPSUMMON_TIMED_OR_DEAD_DESPAWN,
                    2 * MINUTE * IN_MILLISECONDS);

                if (!raptor)
                    return;

                raptor->SetFaction(INVADER_FACTION);
                raptor->SetReactState(REACT_AGGRESSIVE);
                raptor->setActive(true);

                if (target)
                    raptor->AI()->AttackStart(target);

                GI_RegisterSummonedInvader(raptor);
                _raptorGuids.push_back(raptor->GetGUID());
            }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_mobAI(creature);
        }
    };

    // =======================================================================
    // npc_invasion_defender - Beast Hunters and the mobilized guards.
    // =======================================================================
    class npc_invasion_defender : public CreatureScript
    {
    public:
        npc_invasion_defender() : CreatureScript("npc_invasion_defender") { }

        struct npc_invasion_defenderAI : public InvasionBattleAI
        {
            npc_invasion_defenderAI(Creature* creature) : InvasionBattleAI(creature) { }

            void Reset() override
            {
                ClearKit();
            }

            void JustEngagedWith(Unit* /*who*/) override
            {
                ScheduleKit();
            }

            void DamageTaken(Unit* /*attacker*/, uint32& /*damage*/, DamageEffectType /*damagetype*/,
                SpellSchoolMask /*schoolMask*/) override
            {
                CheckLowHealthAbility();
            }

            void JustDied(Unit* /*killer*/) override
            {
                GI_DefenderDied(me);
            }

            void UpdateAI(uint32 diff) override
            {
                if (!UpdateVictim())
                    return;

                UpdateKit(diff);
                DoMeleeAttackIfReady();
            }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_defenderAI(creature);
        }
    };

    // =======================================================================
    // npc_invasion_medic - keeps the line standing from behind it.
    // =======================================================================
    class npc_invasion_medic : public CreatureScript
    {
    public:
        npc_invasion_medic() : CreatureScript("npc_invasion_medic") { }

        struct npc_invasion_medicAI : public ScriptedAI
        {
            npc_invasion_medicAI(Creature* creature) : ScriptedAI(creature) { }

            uint32 _healTimerMs = 2000;

            void Reset() override
            {
                _healTimerMs = 2000;
            }

            void JustDied(Unit* /*killer*/) override
            {
                GI_DefenderDied(me);
            }

            // The healing has to run out of combat too: a medic stands behind
            // the line and rarely has a victim of its own.
            void UpdateAI(uint32 diff) override
            {
                bool const engaged = UpdateVictim();

                if (_healTimerMs <= diff)
                {
                    _healTimerMs = urand(3500, 5500);

                    if (!me->HasUnitState(UNIT_STATE_CASTING))
                        if (Unit* wounded = DoSelectLowestHpFriendly(38.0f, 25000))
                            DoCast(wounded, SPELL_HEALING_WAVE);
                }
                else
                {
                    _healTimerMs -= diff;
                }

                if (engaged)
                    DoMeleeAttackIfReady();
            }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_medicAI(creature);
        }
    };

    // =======================================================================
    // npc_invasion_zuljin - Elder Zul'jin leads the counter-charge in person.
    // =======================================================================
    class npc_invasion_zuljin : public CreatureScript
    {
    public:
        npc_invasion_zuljin() : CreatureScript("npc_invasion_zuljin") { }

        struct npc_invasion_zuljinAI : public InvasionBattleAI
        {
            npc_invasion_zuljinAI(Creature* creature) : InvasionBattleAI(creature) { }

            bool _fallingBack = false;

            void Reset() override
            {
                ClearKit();
            }

            void JustEngagedWith(Unit* /*who*/) override
            {
                ScheduleKit();
            }

            void DoAction(int32 action) override
            {
                switch (action)
                {
                    case ACTION_ZULJIN_CHARGE:
                        Talk(SAY_ZULJIN_ARRIVES);
                        break;
                    case ACTION_ZULJIN_RECKONING:
                        Talk(SAY_ZULJIN_RECKONING);
                        break;
                    case ACTION_ZULJIN_VICTORY:
                        Talk(SAY_ZULJIN_VICTORY);
                        break;
                    default:
                        break;
                }
            }

            // The Elder is the player's quest hub in troll form: he never dies
            // on the sand, he is carried back to the Landing.
            void DamageTaken(Unit* /*attacker*/, uint32& damage, DamageEffectType /*damagetype*/,
                SpellSchoolMask /*schoolMask*/) override
            {
                if (_fallingBack)
                {
                    damage = 0;
                    return;
                }

                if (!me->HealthBelowPctDamaged(10, damage))
                    return;

                damage = 0;
                _fallingBack = true;
                Talk(SAY_ZULJIN_FALLS_BACK);
                me->SetReactState(REACT_PASSIVE);
                me->AttackStop();
                me->CombatStop(true);
                me->GetMotionMaster()->Clear();
                me->GetMotionMaster()->MovePoint(0, DefenderRallyPoint.x, DefenderRallyPoint.y, DefenderRallyPoint.z);
                me->DespawnOrUnsummon(8s);
            }

            void UpdateAI(uint32 diff) override
            {
                if (_fallingBack || !UpdateVictim())
                    return;

                UpdateKit(diff);
                DoMeleeAttackIfReady();
            }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_zuljinAI(creature);
        }
    };

    // =======================================================================
    // npc_invasion_objective - everything players are told to destroy. It
    // stands still, never answers back, and reports who brought it down.
    // =======================================================================
    class npc_invasion_objective : public CreatureScript
    {
    public:
        npc_invasion_objective() : CreatureScript("npc_invasion_objective") { }

        struct npc_invasion_objectiveAI : public ScriptedAI
        {
            npc_invasion_objectiveAI(Creature* creature) : ScriptedAI(creature) { }

            std::vector<ObjectGuid> _attackers;

            void Reset() override
            {
                me->SetReactState(REACT_PASSIVE);
            }

            void AttackStart(Unit* /*who*/) override { }
            void MoveInLineOfSight(Unit* /*who*/) override { }

            void DamageTaken(Unit* attacker, uint32& /*damage*/, DamageEffectType /*damagetype*/,
                SpellSchoolMask /*schoolMask*/) override
            {
                RememberAttacker(_attackers, attacker);
            }

            void JustDied(Unit* /*killer*/) override
            {
                GI_ObjectiveDestroyed(me, _attackers);
            }

            void UpdateAI(uint32 /*diff*/) override { }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_objectiveAI(creature);
        }
    };

    // =======================================================================
    // npc_invasion_impact - invisible marker under a falling war-engine shot or
    // one of Bozzle's bombs. Its faction decides who the fire hurts.
    // =======================================================================
    class npc_invasion_impact : public CreatureScript
    {
    public:
        npc_invasion_impact() : CreatureScript("npc_invasion_impact") { }

        struct npc_invasion_impactAI : public ScriptedAI
        {
            npc_invasion_impactAI(Creature* creature) : ScriptedAI(creature) { }

            void Reset() override
            {
                me->SetReactState(REACT_PASSIVE);
            }

            void AttackStart(Unit* /*who*/) override { }
            void MoveInLineOfSight(Unit* /*who*/) override { }

            void DoAction(int32 action) override
            {
                if (action == ACTION_DROP_FIRE)
                    me->CastSpell(me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), SPELL_RAIN_OF_FIRE, true);
            }

            void UpdateAI(uint32 /*diff*/) override { }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_impactAI(creature);
        }
    };

    // =======================================================================
    // npc_invasion_leader - General Rak'zor narrates from his ship until the
    // defenders earn a reckoning, then comes down the ramp to end it himself.
    // =======================================================================
    class npc_invasion_leader : public CreatureScript
    {
    public:
        npc_invasion_leader() : CreatureScript("npc_invasion_leader") { }

        struct npc_invasion_leaderAI : public ScriptedAI
        {
            npc_invasion_leaderAI(Creature* creature) : ScriptedAI(creature) { }

            EventMap _events;
            bool _ashore = false;
            bool _bloodlustUsed = false;

            void Reset() override
            {
                _events.Reset();
                _bloodlustUsed = false;

                if (_ashore)
                    return;

                me->SetReactState(REACT_PASSIVE);
                me->SetUnitFlag(UNIT_FLAG_NON_ATTACKABLE);
                me->SetImmuneToAll(true);
                me->GetMotionMaster()->MoveIdle();
            }

            void InitializeAI() override
            {
                Reset();
            }

            void DoAction(int32 action) override
            {
                if (action == ACTION_LEADER_COME_ASHORE)
                {
                    _ashore = true;
                    me->RemoveUnitFlag(UNIT_FLAG_NON_ATTACKABLE);
                    me->SetImmuneToAll(false);
                    me->SetReactState(REACT_AGGRESSIVE);
                    me->SetWalk(false);
                    me->GetMotionMaster()->Clear();
                    me->GetMotionMaster()->MovePoint(0, RakzorAshorePoint.x, RakzorAshorePoint.y, RakzorAshorePoint.z);
                }
                else if (action == ACTION_LEADER_STAND_DOWN && _ashore)
                {
                    _ashore = false;
                    me->CombatStop(true);
                    me->DespawnOrUnsummon(1s, 5s);
                }
            }

            void JustEngagedWith(Unit* /*who*/) override
            {
                _events.ScheduleEvent(EVENT_MORTAL_STRIKE, 6s);
                _events.ScheduleEvent(EVENT_THUNDERCLAP, 12s);
                _events.ScheduleEvent(EVENT_RAIN_OF_FIRE, 15s);
                _events.ScheduleEvent(EVENT_WHIRLWIND, 22s);
            }

            void DamageTaken(Unit* /*attacker*/, uint32& damage, DamageEffectType /*damagetype*/,
                SpellSchoolMask /*schoolMask*/) override
            {
                if (_bloodlustUsed || !me->HealthBelowPctDamaged(40, damage))
                    return;

                _bloodlustUsed = true;
                _events.ScheduleEvent(EVENT_BLOODLUST, 500ms);
            }

            void JustDied(Unit* /*killer*/) override
            {
                _ashore = false;
                GI_NotifyGeneralDeath();
            }

            void UpdateAI(uint32 diff) override
            {
                if (!_ashore || !UpdateVictim())
                    return;

                _events.Update(diff);

                if (me->HasUnitState(UNIT_STATE_CASTING))
                    return;

                while (uint32 eventId = _events.ExecuteEvent())
                {
                    switch (eventId)
                    {
                        case EVENT_MORTAL_STRIKE:
                            DoCastVictim(SPELL_MORTAL_STRIKE);
                            _events.ScheduleEvent(EVENT_MORTAL_STRIKE, 9s, 12s);
                            break;
                        case EVENT_THUNDERCLAP:
                            DoCastAOE(SPELL_THUNDERCLAP);
                            _events.ScheduleEvent(EVENT_THUNDERCLAP, 16s, 20s);
                            break;
                        case EVENT_RAIN_OF_FIRE:
                            if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                                me->CastSpell(target->GetPositionX(), target->GetPositionY(), target->GetPositionZ(),
                                    SPELL_RAIN_OF_FIRE, true);
                            _events.ScheduleEvent(EVENT_RAIN_OF_FIRE, 14s, 18s);
                            break;
                        case EVENT_WHIRLWIND:
                            DoCastAOE(SPELL_WHIRLWIND);
                            _events.ScheduleEvent(EVENT_WHIRLWIND, 24s, 30s);
                            break;
                        case EVENT_BLOODLUST:
                            DoCastSelf(SPELL_BLOODLUST, true);
                            break;
                        default:
                            break;
                    }
                }

                DoMeleeAttackIfReady();
            }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_leaderAI(creature);
        }
    };

    // =======================================================================
    // npc_invasion_commander - Warlord Zul'mar, the wave-4 boss.
    //   100-60%: duelist with an honor guard.
    //    60-30%: calls his war-devilsaur onto the beach.
    //    30-0%:  the Loa ride him. Blood Nova is telegraphed: he roots himself,
    //            the emote fires, and four seconds later everything inside 25
    //            yards takes the blast.
    // =======================================================================
    class npc_invasion_commander : public CreatureScript
    {
    public:
        npc_invasion_commander() : CreatureScript("npc_invasion_commander") { }

        struct npc_invasion_commanderAI : public InvasionBattleAI
        {
            npc_invasion_commanderAI(Creature* creature) : InvasionBattleAI(creature) { }

            EventMap _events;
            std::vector<ObjectGuid> _attackers;
            uint8 _stage = 1;
            bool _channeling = false;
            uint64 _lastSlayYellMs = 0;

            void Reset() override
            {
                _events.Reset();
                _lastSlayYellMs = 0;

                if (_channeling)
                    EndBloodNovaChannel();
            }

            void JustEngagedWith(Unit* /*who*/) override
            {
                Talk(SAY_WARLORD_AGGRO);

                _events.ScheduleEvent(EVENT_MORTAL_STRIKE, 8s);
                _events.ScheduleEvent(EVENT_WHIRLWIND, 16s);
                _events.ScheduleEvent(EVENT_WAR_SHOUT, 24s);
                _events.ScheduleEvent(EVENT_CHECK_GUARDS, 12s);
                _events.ScheduleEvent(EVENT_GRIEVOUS_THROW, 10s);

                if (_stage >= 3)
                    _events.ScheduleEvent(EVENT_BLOOD_NOVA, 10s);
            }

            void DamageTaken(Unit* attacker, uint32& damage, DamageEffectType /*damagetype*/,
                SpellSchoolMask /*schoolMask*/) override
            {
                RememberAttacker(_attackers, attacker);

                if (_stage == 1 && me->HealthBelowPctDamaged(60, damage))
                {
                    _stage = 2;
                    Talk(SAY_WARLORD_BEAST);
                    GI_CallWarlordBeast(me);
                }
                else if (_stage == 2 && me->HealthBelowPctDamaged(30, damage))
                {
                    _stage = 3;
                    Talk(SAY_WARLORD_POSSESSED);
                    Talk(SAY_WARLORD_ENRAGE);
                    DoCast(me, SPELL_BLOOD_FURY, true);
                    me->SetObjectScale(me->GetObjectScale() * 1.25f);
                    _events.ScheduleEvent(EVENT_BLOOD_NOVA, 6s);
                }
            }

            void KilledUnit(Unit* victim) override
            {
                if (!victim || !victim->IsPlayer())
                    return;

                uint64 now = GetNowMs();
                if (_lastSlayYellMs == 0 || (now - _lastSlayYellMs) > 8000)
                {
                    _lastSlayYellMs = now;
                    Talk(SAY_WARLORD_SLAY);
                }
            }

            void JustDied(Unit* /*killer*/) override
            {
                if (_channeling)
                    EndBloodNovaChannel();

                Talk(SAY_WARLORD_DEATH);
                GI_CreditParticipants(me, _attackers);
                GI_NotifyBossDeath();
            }

            void UpdateAI(uint32 diff) override
            {
                if (!UpdateVictim())
                {
                    UpdateMarch(diff);
                    return;
                }

                _events.Update(diff);

                if (me->HasUnitState(UNIT_STATE_CASTING))
                    return;

                while (uint32 eventId = _events.ExecuteEvent())
                {
                    switch (eventId)
                    {
                        case EVENT_MORTAL_STRIKE:
                            DoCastVictim(SPELL_MORTAL_STRIKE);
                            _events.ScheduleEvent(EVENT_MORTAL_STRIKE, 12s);
                            break;
                        case EVENT_WHIRLWIND:
                            DoCastAOE(SPELL_WHIRLWIND);
                            _events.ScheduleEvent(EVENT_WHIRLWIND, 20s);
                            break;
                        case EVENT_WAR_SHOUT:
                            DoCastAOE(SPELL_BATTLE_SHOUT);
                            _events.ScheduleEvent(EVENT_WAR_SHOUT, 30s);
                            break;
                        case EVENT_CHECK_GUARDS:
                            GI_MaintainBossGuards(me->GetMap());
                            _events.ScheduleEvent(EVENT_CHECK_GUARDS, 15s);
                            break;
                        case EVENT_GRIEVOUS_THROW:
                            if (Unit* target = SelectTarget(SelectTargetMethod::Random, 1, 30.0f, true))
                                DoCast(target, SPELL_GRIEVOUS_THROW);
                            else
                                DoCastVictim(SPELL_GRIEVOUS_THROW);
                            _events.ScheduleEvent(EVENT_GRIEVOUS_THROW, 14s, 18s);
                            break;
                        case EVENT_BLOOD_NOVA:
                            Talk(EMOTE_WARLORD_BLOOD_NOVA);
                            DoCastSelf(SPELL_SHADOW_CHANNELING, true);
                            me->SetControlled(true, UNIT_STATE_ROOT);
                            _channeling = true;
                            _events.ScheduleEvent(EVENT_BLOOD_NOVA_BLAST, 4s);
                            break;
                        case EVENT_BLOOD_NOVA_BLAST:
                            EndBloodNovaChannel();
                            me->CastCustomSpell(SPELL_THUNDERCLAP, SPELLVALUE_BASE_POINT0, BLOOD_NOVA_BASE_POINTS, me, true);
                            _events.ScheduleEvent(EVENT_BLOOD_NOVA, 22s);
                            break;
                        default:
                            break;
                    }
                }

                if (!_channeling)
                    DoMeleeAttackIfReady();
            }

        private:
            void EndBloodNovaChannel()
            {
                _channeling = false;
                me->RemoveAurasDueToSpell(SPELL_SHADOW_CHANNELING);
                me->SetControlled(false, UNIT_STATE_ROOT);
            }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_commanderAI(creature);
        }
    };

    // =======================================================================
    // npc_giant_isles_invasion_questgiver - blue daily/weekly "!" override.
    // Only the overhead dialog status is overridden; gossip and quest
    // accept/reward stay on the default DB-driven path. Promotion is data-driven
    // via the dc_questgiver_status_overrides row for entry 400200.
    //
    // Turning in a war-camp daily also banks war effort for the next assault.
    // =======================================================================
    class npc_giant_isles_invasion_questgiver : public CreatureScript
    {
    public:
        npc_giant_isles_invasion_questgiver() : CreatureScript("npc_giant_isles_invasion_questgiver") { }

        uint32 GetDialogStatus(Player* player, Creature* creature) override
        {
            return DCQuestgiverStatusOverride::GetDialogStatus(player, creature);
        }

        bool OnQuestReward(Player* /*player*/, Creature* /*creature*/, Quest const* quest, uint32 /*opt*/) override
        {
            if (!quest)
                return false;

            switch (quest->GetQuestId())
            {
                case QUEST_CUT_THEIR_CHAINS:
                case QUEST_SPIKE_THE_ENGINES:
                case QUEST_THIN_THE_BINDERS:
                    GI_AddWarEffort(1);
                    break;
                default:
                    break;
            }

            return false;
        }
    };
}

// Orchestrator -> NPC bridge: drive the ship leader's narration by text group.
void GI_LeaderSay(Creature* leader, uint8 textGroup)
{
    if (!leader || !leader->IsAlive())
        return;

    if (CreatureAI* ai = leader->AI())
        ai->Talk(textGroup);
}

// Registered through the orchestrator's single AddSC entry point.
void GI_RegisterInvasionNpcs()
{
    new npc_invasion_mob();
    new npc_invasion_defender();
    new npc_invasion_medic();
    new npc_invasion_zuljin();
    new npc_invasion_objective();
    new npc_invasion_impact();
    new npc_invasion_leader();
    new npc_invasion_commander();
    new npc_giant_isles_invasion_questgiver();
}
