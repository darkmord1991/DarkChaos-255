/*
 * Giant Isles - Invasion: creature AIs
 * ==========================================================================
 * The combat/flavour units of the Zandalari incursion:
 *   - npc_invasion_mob      : every basic invader. Carries a per-entry ability
 *                             kit (folded in from the old, inert smart_scripts)
 *                             plus the beast tamer's war-raptor summon and the
 *                             event kill-credit hook.
 *   - npc_invasion_leader   : the ship commander who narrates the assault.
 *   - npc_invasion_commander: Warlord Zul'mar, the wave-4 boss.
 *   - npc_giant_isles_invasion_questgiver: blue daily/weekly "!" override.
 *
 * The orchestrator (dc_giant_isles_invasion.cpp) drives waves/spawning and
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
#include "Map.h"
#include "MotionMaster.h"
#include "Timer.h"
#include "Random.h"

#include "dc_giant_isles_invasion_internal.h"
#include "../QOL/dc_questgiver_status_override.h"

#include <algorithm>
#include <map>
#include <vector>

using namespace std::chrono_literals;
using namespace DCGiantIsles;

namespace
{
    enum WarlordSpells
    {
        SPELL_MORTAL_STRIKE             = 16856,
        SPELL_WHIRLWIND                 = 15589,
        SPELL_COMMANDING_SHOUT          = 32064,
        SPELL_ENRAGE                    = 8599,
    };

    enum WarlordEvents
    {
        EVENT_MORTAL_STRIKE             = 1,
        EVENT_WHIRLWIND                 = 2,
        EVENT_COMMANDING_SHOUT          = 3,
        EVENT_CHECK_GUARDS              = 4,
    };

    // Kit ability event ids start here so they never collide with the boss
    // EventMap ids above.
    constexpr uint32 EVENT_KIT_ABILITY_BASE = 100;

    static uint64 GetNowMs()
    {
        return static_cast<uint64>(GameTime::GetGameTimeMS().count());
    }

    static Player* ResolvePlayerKiller(Unit* killer)
    {
        if (!killer)
            return nullptr;

        if (Player* player = killer->ToPlayer())
            return player;

        if (Unit* owner = killer->GetOwner())
            return owner->ToPlayer();

        return nullptr;
    }

    static void ForceStartCombat(Creature* attacker, Unit* target)
    {
        if (!attacker || !target)
            return;

        if (!attacker->IsAlive() || !target->IsAlive())
            return;

        attacker->EngageWithTarget(target);
        attacker->AI()->AttackStart(target);

        if (Creature* targetCreature = target->ToCreature())
        {
            targetCreature->EngageWithTarget(attacker);

            if (!targetCreature->IsInCombat() || targetCreature->GetVictim() != attacker)
                targetCreature->AI()->AttackStart(attacker);
        }
    }

    // =======================================================================
    // Invader ability kits (folded in from the old smart_scripts so the basic
    // invaders actually use their kit through the C++ AI).
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
                { { 11578, 3000, 3000,  8000, 25000, KIT_TARGET_VICTIM },   // Charge
                  { 11976, 5000, 7000,  5000,  7000, KIT_TARGET_VICTIM } }, // Strike
                0, 0 } },

            { NPC_ZANDALARI_SCOUT, {
                { { 11971, 4000, 6000,  6000,  9000, KIT_TARGET_VICTIM } }, // Sinister Strike
                5277, 30 } },                                               // Evasion

            { NPC_ZANDALARI_SPEARMAN, {
                { { 10277, 3000, 5000, 10000, 30000, KIT_TARGET_VICTIM },   // Throw
                  {  6533,10000,15000, 18000, 26000, KIT_TARGET_VICTIM } }, // Net
                0, 0 } },

            { NPC_ZANDALARI_WARRIOR, {
                { { 11971, 5000, 8000,  7000, 11000, KIT_TARGET_VICTIM },   // Sunder Armor
                  { 11972, 9000,13000, 12000, 16000, KIT_TARGET_VICTIM } }, // Shield Bash
                0, 0 } },

            { NPC_ZANDALARI_BERSERKER, {
                { { 15284, 6000, 8000,  6000,  9000, KIT_TARGET_VICTIM } }, // Cleave
                8599, 25 } },                                               // Enrage

            { NPC_ZANDALARI_SHADOW_HUNTER, {
                { { 16097,12000,16000, 18000, 24000, KIT_TARGET_VICTIM },   // Hex
                  {  6660, 3000, 5000,  8000, 14000, KIT_TARGET_VICTIM },   // Shoot
                  { 11986,14000,18000, 16000, 22000, KIT_TARGET_SELF } },   // Healing Wave
                0, 0 } },

            { NPC_ZANDALARI_BLOOD_GUARD, {
                { { 16856, 6000, 8000,  9000, 13000, KIT_TARGET_VICTIM },   // Mortal Strike
                  { 11876,12000,15000, 16000, 20000, KIT_TARGET_SELF } },   // War Stomp
                0, 0 } },

            { NPC_ZANDALARI_WITCH_DOCTOR, {
                { {  9613, 2000, 3000,  3000,  4000, KIT_TARGET_VICTIM },   // Shadow Bolt
                  {  5605,15000,20000, 22000, 30000, KIT_TARGET_SELF } },   // Healing Ward
                0, 0 } },

            { NPC_ZANDALARI_BEAST_TAMER, {
                { { 14443, 8000,12000, 10000, 14000, KIT_TARGET_VICTIM } }, // Multi-Shot
                0, 0 } },

            { NPC_ZANDALARI_WAR_RAPTOR, {
                { { 16827, 4000, 6000,  5000,  8000, KIT_TARGET_VICTIM } }, // Bite
                0, 0 } },

            { NPC_ZANDALARI_HONOR_GUARD, {
                { { 29426, 4000, 6000,  6000,  9000, KIT_TARGET_VICTIM } }, // Heroic Strike
                871, 20 } },                                                // Shield Wall
        };

        auto const itr = kits.find(entry);
        return itr != kits.end() ? &itr->second : nullptr;
    }

    // =======================================================================
    // npc_invasion_mob - every basic invader.
    // =======================================================================
    class npc_invasion_mob : public CreatureScript
    {
    public:
        npc_invasion_mob() : CreatureScript("npc_invasion_mob") { }

        struct npc_invasion_mobAI : public ScriptedAI
        {
            npc_invasion_mobAI(Creature* creature) : ScriptedAI(creature) { }

            EventMap _events;
            std::vector<ObjectGuid> _raptorGuids;
            InvaderKit const* _kit = nullptr;
            bool _lowHealthCast = false;

            void Reset() override
            {
                _events.Reset();
                _kit = nullptr;
                _lowHealthCast = false;

                PruneRaptors();

                // Cleanup any stray summon instances if event is not active.
                if (!GI_IsInvasionActive() && me->IsSummon())
                    me->DespawnOrUnsummon(1s);
            }

            void JustEngagedWith(Unit* who) override
            {
                if (!GI_IsInvasionActive())
                    return;

                if (me->GetEntry() == NPC_ZANDALARI_BEAST_TAMER)
                    SummonWarRaptor(who);

                ScheduleKit();
            }

            void DamageTaken(Unit* /*attacker*/, uint32& /*damage*/, DamageEffectType /*damagetype*/,
                SpellSchoolMask /*schoolMask*/) override
            {
                if (!_kit || _lowHealthCast || _kit->lowHealthSpell == 0)
                    return;

                if (me->HealthBelowPct(_kit->lowHealthPct))
                {
                    _lowHealthCast = true;
                    DoCast(me, _kit->lowHealthSpell, true);
                }
            }

            void JustDied(Unit* killer) override
            {
                DespawnRaptors();

                if (Player* player = ResolvePlayerKiller(killer))
                    GI_TrackPlayerKill(player->GetGUID());
            }

            void UpdateAI(uint32 diff) override
            {
                if (!UpdateVictim())
                    return;

                _events.Update(diff);

                if (me->HasUnitState(UNIT_STATE_CASTING))
                    return;

                while (uint32 eventId = _events.ExecuteEvent())
                {
                    if (eventId < EVENT_KIT_ABILITY_BASE || !_kit)
                        continue;

                    uint32 const index = eventId - EVENT_KIT_ABILITY_BASE;
                    if (index >= _kit->abilities.size())
                        continue;

                    InvaderAbility const& ability = _kit->abilities[index];
                    CastKitAbility(ability);

                    uint32 const repeatMin = ability.repeatMin ? ability.repeatMin : ability.initialMin;
                    uint32 const repeatMax = ability.repeatMax ? ability.repeatMax : ability.initialMax;
                    _events.ScheduleEvent(eventId, Milliseconds(repeatMin), Milliseconds(repeatMax));
                }

                DoMeleeAttackIfReady();
            }

        private:
            void ScheduleKit()
            {
                _events.Reset();
                _lowHealthCast = false;
                _kit = GetInvaderKit(me->GetEntry());

                if (!_kit)
                    return;

                for (uint32 i = 0; i < _kit->abilities.size(); ++i)
                {
                    InvaderAbility const& ability = _kit->abilities[i];
                    _events.ScheduleEvent(EVENT_KIT_ABILITY_BASE + i,
                        Milliseconds(ability.initialMin), Milliseconds(ability.initialMax));
                }
            }

            void CastKitAbility(InvaderAbility const& ability)
            {
                if (ability.target == KIT_TARGET_SELF)
                    DoCast(me, ability.spellId, false);
                else
                    DoCastVictim(ability.spellId);
            }

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

                if (_raptorGuids.size() >= 1)
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

                if (target)
                    ForceStartCombat(raptor, target);

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
    // npc_invasion_leader - the ship commander who narrates the assault.
    // =======================================================================
    class npc_invasion_leader : public CreatureScript
    {
    public:
        npc_invasion_leader() : CreatureScript("npc_invasion_leader") { }

        struct npc_invasion_leaderAI : public ScriptedAI
        {
            npc_invasion_leaderAI(Creature* creature) : ScriptedAI(creature) { }

            void Reset() override
            {
                me->SetReactState(REACT_PASSIVE);
                me->SetFlag(UNIT_FIELD_FLAGS,
                    UNIT_FLAG_NON_ATTACKABLE |
                    UNIT_FLAG_IMMUNE_TO_PC |
                    UNIT_FLAG_IMMUNE_TO_NPC);
                me->GetMotionMaster()->MoveIdle();
            }

            void InitializeAI() override
            {
                Reset();
            }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_leaderAI(creature);
        }
    };

    // =======================================================================
    // npc_invasion_commander - Warlord Zul'mar, the wave-4 boss.
    // =======================================================================
    class npc_invasion_commander : public CreatureScript
    {
    public:
        npc_invasion_commander() : CreatureScript("npc_invasion_commander") { }

        struct npc_invasion_commanderAI : public ScriptedAI
        {
            npc_invasion_commanderAI(Creature* creature) : ScriptedAI(creature) { }

            EventMap _events;
            bool _enraged = false;
            uint64 _lastSlayYellMs = 0;

            void Reset() override
            {
                _events.Reset();
                _enraged = false;
                _lastSlayYellMs = 0;
            }

            void JustEngagedWith(Unit* /*who*/) override
            {
                me->Yell("You face Zul'mar, breaker of armies!", LANG_UNIVERSAL);

                _events.ScheduleEvent(EVENT_MORTAL_STRIKE, 8s);
                _events.ScheduleEvent(EVENT_WHIRLWIND, 16s);
                _events.ScheduleEvent(EVENT_COMMANDING_SHOUT, 24s);
                _events.ScheduleEvent(EVENT_CHECK_GUARDS, 12s);
            }

            void DamageTaken(Unit* /*attacker*/, uint32& /*damage*/, DamageEffectType /*damagetype*/,
                SpellSchoolMask /*schoolMask*/) override
            {
                if (_enraged)
                    return;

                if (me->HealthBelowPct(30))
                {
                    _enraged = true;
                    DoCast(me, SPELL_ENRAGE, true);
                    me->Yell("You only feed my fury!", LANG_UNIVERSAL);
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
                    me->Yell("Another defender falls!", LANG_UNIVERSAL);
                }
            }

            void JustDied(Unit* /*killer*/) override
            {
                me->Yell("This beach... is not yours...", LANG_UNIVERSAL);
                GI_NotifyBossDeath();
            }

            void UpdateAI(uint32 diff) override
            {
                if (!UpdateVictim())
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
                            _events.ScheduleEvent(EVENT_MORTAL_STRIKE, 12s);
                            break;
                        case EVENT_WHIRLWIND:
                            DoCastAOE(SPELL_WHIRLWIND);
                            _events.ScheduleEvent(EVENT_WHIRLWIND, 20s);
                            break;
                        case EVENT_COMMANDING_SHOUT:
                            DoCastAOE(SPELL_COMMANDING_SHOUT);
                            _events.ScheduleEvent(EVENT_COMMANDING_SHOUT, 30s);
                            break;
                        case EVENT_CHECK_GUARDS:
                            GI_MaintainBossGuards(me->GetMap());
                            _events.ScheduleEvent(EVENT_CHECK_GUARDS, 15s);
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
            return new npc_invasion_commanderAI(creature);
        }
    };

    // =======================================================================
    // npc_giant_isles_invasion_questgiver - blue daily/weekly "!" override.
    // Only the overhead dialog status is overridden; gossip and quest
    // accept/reward stay on the default DB-driven path. Promotion is data-driven
    // via the dc_questgiver_status_overrides row for entry 400200.
    // =======================================================================
    class npc_giant_isles_invasion_questgiver : public CreatureScript
    {
    public:
        npc_giant_isles_invasion_questgiver() : CreatureScript("npc_giant_isles_invasion_questgiver") { }

        uint32 GetDialogStatus(Player* player, Creature* creature) override
        {
            return DCQuestgiverStatusOverride::GetDialogStatus(player, creature);
        }
    };
}

// Orchestrator -> NPC bridge: drive the ship leader's narration by stage.
void GI_LeaderYell(Creature* leader, uint8 stage)
{
    if (!leader || !leader->IsAlive())
        return;

    switch (stage)
    {
        case 0:
            leader->Yell("Unload everything! The beach will burn!", LANG_UNIVERSAL);
            break;
        case 1:
            leader->Yell("Scouts first! Probe their line!", LANG_UNIVERSAL);
            break;
        case 2:
            leader->Yell("Warriors to the front! Break their shields!", LANG_UNIVERSAL);
            break;
        case 3:
            leader->Yell("Elites, crush them! No survivors!", LANG_UNIVERSAL);
            break;
        case 4:
            leader->Yell("Warlord Zul'mar, finish this!", LANG_UNIVERSAL);
            break;
        case 5:
            leader->Yell("Retreat to the ship!", LANG_UNIVERSAL);
            break;
        case 6:
            leader->Yell("The beach is ours. Hold this ground!", LANG_UNIVERSAL);
            break;
        default:
            break;
    }
}

// Registered through the orchestrator's single AddSC entry point.
void GI_RegisterInvasionNpcs()
{
    new npc_invasion_mob();
    new npc_invasion_leader();
    new npc_invasion_commander();
    new npc_giant_isles_invasion_questgiver();
}
