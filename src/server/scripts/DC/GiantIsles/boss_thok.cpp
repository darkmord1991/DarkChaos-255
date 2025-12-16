/*
 * Giant Isles - Boss: Thok the Bloodthirsty
 * ============================================================================
 * The Primal Hunter - A savage raptor pack leader
 * Based on SoO raid boss mechanics adapted for WotLK 3.3.5a world boss
 * 
 * ABILITIES:
 *   - Bloodthirsty: Gains attack speed as health decreases
 *   - Deafening Screech: Silences all players in range
 *   - Tail Lash: Cone damage behind the boss
 *   - Acceleration: Periodically increases move/attack speed
 *   - Blood Frenzy: At 30% health, summons pack raptors
 *   - Fixate: Targets a random player and chases them
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellScript.h"
#include "SpellAuraEffects.h"
#include "Player.h"
#include "World.h"
#include "Chat.h"
#include "../AddonExtension/DCAddonNamespace.h"

enum ThokSpells
{
    // Main abilities
    SPELL_DEAFENING_SCREECH     = 55942,  // Silence effect
    SPELL_TAIL_LASH             = 56910,  // Rear cone damage
    SPELL_ACCELERATION          = 61890,  // Haste buff
    SPELL_BLOOD_FRENZY          = 28131,  // Frenzy visual (soft enrage)
    SPELL_FIXATE                = 40415,  // Fixate on target
    SPELL_BLOODTHIRSTY          = 59867,  // Attack speed buff (stacks)
    
    // Damage spells
    SPELL_SAVAGE_BITE           = 52585,  // Heavy melee damage
    SPELL_CARNAGE               = 28414,  // Bleed DoT
    
    // Visual effects
    SPELL_BERSERK               = 26662,  // Hard enrage
    SPELL_CHAOS_AURA            = 28126,  // Chaos visual
};

enum ThokEvents
{
    EVENT_DEAFENING_SCREECH     = 1,
    EVENT_TAIL_LASH             = 2,
    EVENT_ACCELERATION          = 3,
    EVENT_SAVAGE_BITE           = 4,
    EVENT_FIXATE                = 5,
    EVENT_END_FIXATE            = 6,
    EVENT_SUMMON_PACK           = 7,
    EVENT_BERSERK               = 8,
    EVENT_HP_CHECK              = 9,
};

enum ThokTexts
{
    SAY_AGGRO                   = 0,
    SAY_SCREECH                 = 1,
    SAY_FIXATE                  = 2,
    SAY_FRENZY                  = 3,
    SAY_BERSERK                 = 4,
    SAY_DEATH                   = 5,
    SAY_KILL                    = 6,
};

enum ThokData
{
    NPC_THOK                    = 400101,
    NPC_PACK_RAPTOR             = 400401,
    
    // Timers
    TIMER_DEAFENING_SCREECH     = 30000,
    TIMER_TAIL_LASH             = 12000,
    TIMER_ACCELERATION          = 45000,
    TIMER_SAVAGE_BITE           = 8000,
    TIMER_FIXATE                = 40000,
    TIMER_FIXATE_DURATION       = 10000,
    TIMER_BERSERK               = 480000, // 8 minutes
};

enum ThokPhases
{
    PHASE_NORMAL                = 1,
    PHASE_FRENZY                = 2,
};

// ============================================================================
// BOSS AI: THOK THE BLOODTHIRSTY
// ============================================================================

class boss_thok : public CreatureScript
{
public:
    boss_thok() : CreatureScript("boss_thok") { }

    struct boss_thokAI : public ScriptedAI
    {
        boss_thokAI(Creature* creature) : ScriptedAI(creature), summons(me)
        {
            phase = PHASE_NORMAL;
            accelerationStacks = 0;
            inFrenzy = false;
            fixateTarget = ObjectGuid::Empty;
            hpTriggered[0] = hpTriggered[1] = hpTriggered[2] = false;
        }

        EventMap events;
        SummonList summons;
        uint8 phase;
        uint8 accelerationStacks;
        bool inFrenzy;
        ObjectGuid fixateTarget;
        bool hpTriggered[3];

        void Reset() override
        {
            events.Reset();
            summons.DespawnAll();
            
            phase = PHASE_NORMAL;
            accelerationStacks = 0;
            inFrenzy = false;
            fixateTarget = ObjectGuid::Empty;
            
            me->RemoveAllAuras();
            me->SetReactState(REACT_AGGRESSIVE);
            me->SetSpeedRate(MOVE_RUN, 1.0f);
            hpTriggered[0] = hpTriggered[1] = hpTriggered[2] = false;
        }

        void JustAppeared()
        {
            // WRLD: boss spawned
            DCAddon::JsonValue bossesArr; bossesArr.SetArray();
            DCAddon::JsonValue b; b.SetObject();
            b.Set("entry", DCAddon::JsonValue(static_cast<int32>(me->GetEntry())));
            b.Set("spawnId", DCAddon::JsonValue(static_cast<int32>(me->GetSpawnId())));
            b.Set("name", DCAddon::JsonValue(me->GetName()));
            b.Set("mapId", DCAddon::JsonValue(static_cast<int32>(me->GetMapId())));
            uint32 zoneId = me->GetZoneId();
            std::string zoneName = "Unknown";
            if (const AreaTableEntry* area = sAreaTableStore.LookupEntry(zoneId))
            {
                if (area->area_name[0] && area->area_name[0][0])
                    zoneName = area->area_name[0];
            }
            b.Set("zone", DCAddon::JsonValue(zoneName));
            b.Set("guid", DCAddon::JsonValue(me->GetGUID().ToString()));
            b.Set("active", DCAddon::JsonValue(true));
            b.Set("hpPct", DCAddon::JsonValue(static_cast<int32>(me->GetHealthPct())));
            b.Set("action", DCAddon::JsonValue("spawn"));
            bossesArr.Push(b);

            DCAddon::JsonMessage wmsg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
            wmsg.Set("bosses", bossesArr);
            if (Map* map = me->GetMap()) map->DoForAllPlayers([&](Player* player){ if (player && player->IsInWorld() && player->GetSession()) wmsg.Send(player); });
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            Talk(SAY_AGGRO);
            
            // Schedule abilities
            events.ScheduleEvent(EVENT_DEAFENING_SCREECH, 20s);
            events.ScheduleEvent(EVENT_TAIL_LASH, 8s);
            events.ScheduleEvent(EVENT_ACCELERATION, 45s);
            events.ScheduleEvent(EVENT_SAVAGE_BITE, 8s);
            events.ScheduleEvent(EVENT_FIXATE, 35s);
            events.ScheduleEvent(EVENT_BERSERK, 10min);

            // schedule HP check to send threshold updates
            events.ScheduleEvent(EVENT_HP_CHECK, 5s);

            // WRLD: boss engaged
            DCAddon::JsonValue bossesArr; bossesArr.SetArray();
            DCAddon::JsonValue b; b.SetObject();
            b.Set("entry", DCAddon::JsonValue(static_cast<int32>(me->GetEntry())));
            b.Set("spawnId", DCAddon::JsonValue(static_cast<int32>(me->GetSpawnId())));
            b.Set("name", DCAddon::JsonValue(me->GetName()));
            b.Set("mapId", DCAddon::JsonValue(static_cast<int32>(me->GetMapId())));
            // Zone name
            uint32 zoneId = me->GetZoneId();
            std::string zoneName = "Unknown";
            if (const AreaTableEntry* area = sAreaTableStore.LookupEntry(zoneId))
            {
                if (area->area_name[0] && area->area_name[0][0])
                    zoneName = area->area_name[0];
            }
            b.Set("zone", DCAddon::JsonValue(zoneName));
            b.Set("guid", DCAddon::JsonValue(me->GetGUID().ToString()));
            b.Set("active", DCAddon::JsonValue(true));
            b.Set("hpPct", DCAddon::JsonValue(static_cast<int32>(me->GetHealthPct())));
            b.Set("action", DCAddon::JsonValue("engage"));
            bossesArr.Push(b);
            DCAddon::JsonMessage wmsg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
            wmsg.Set("bosses", bossesArr);
            if (Map* map = me->GetMap()) map->DoForAllPlayers([&](Player* player){ if (player && player->IsInWorld() && player->GetSession()) wmsg.Send(player); });
        }

        void JustDied(Unit* /*killer*/) override
        {
            Talk(SAY_DEATH);
            // WRLD: boss died
            DCAddon::JsonValue bossesArr; bossesArr.SetArray();
            DCAddon::JsonValue b; b.SetObject();
            b.Set("entry", DCAddon::JsonValue(static_cast<int32>(me->GetEntry())));
            b.Set("spawnId", DCAddon::JsonValue(static_cast<int32>(me->GetSpawnId())));
            b.Set("name", DCAddon::JsonValue(me->GetName()));
            b.Set("mapId", DCAddon::JsonValue(static_cast<int32>(me->GetMapId())));
            uint32 zoneIdD = me->GetZoneId();
            std::string zoneNameD = "Unknown";
            if (const AreaTableEntry* areaD = sAreaTableStore.LookupEntry(zoneIdD))
            {
                if (areaD->area_name[0] && areaD->area_name[0][0])
                    zoneNameD = areaD->area_name[0];
            }
            b.Set("zone", DCAddon::JsonValue(zoneNameD));
            b.Set("guid", DCAddon::JsonValue(me->GetGUID().ToString()));
            b.Set("active", DCAddon::JsonValue(false));
            b.Set("hpPct", DCAddon::JsonValue(static_cast<int32>(me->GetHealthPct())));
            {
                time_t now = GameTime::GetGameTime().count();
                int64 diff = static_cast<int64>(me->GetRespawnTimeEx()) - static_cast<int64>(now);
                uint32 spawnIn = diff > 0 ? static_cast<uint32>(diff) : me->GetRespawnDelay();
                b.Set("spawnIn", DCAddon::JsonValue(static_cast<int32>(spawnIn)));
                b.Set("status", DCAddon::JsonValue("spawning"));
            }
            b.Set("action", DCAddon::JsonValue("death"));
            bossesArr.Push(b);
            DCAddon::JsonMessage wmsg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
            wmsg.Set("bosses", bossesArr);
            if (Map* map = me->GetMap()) map->DoForAllPlayers([&](Player* player){ if (player && player->IsInWorld() && player->GetSession()) wmsg.Send(player); });
            summons.DespawnAll();
            hpTriggered[0] = hpTriggered[1] = hpTriggered[2] = false;
        }

        void KilledUnit(Unit* victim) override
        {
            if (victim->IsPlayer())
            {
                // Killing makes Thok more bloodthirsty
                DoCastSelf(SPELL_BLOODTHIRSTY);
                
                if (urand(0, 100) < 30)
                    Talk(SAY_KILL);
            }
        }

        void JustSummoned(Creature* summon) override
        {
            summons.Summon(summon);
            
            if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                summon->AI()->AttackStart(target);
        }

        void DamageTaken(Unit* /*attacker*/, uint32& /*damage*/, DamageEffectType /*type*/, SpellSchoolMask /*school*/) override
        {
            // Enter frenzy at 30% health
            if (!inFrenzy && HealthBelowPct(30))
            {
                inFrenzy = true;
                phase = PHASE_FRENZY;
                
                Talk(SAY_FRENZY);
                DoCastSelf(SPELL_BLOOD_FRENZY);
                
                // Summon pack of raptors
                SummonPackRaptors();
                
                // Increase ability frequency in frenzy
                events.CancelEvent(EVENT_SUMMON_PACK);
                events.ScheduleEvent(EVENT_SUMMON_PACK, 30s);
            }
        }

        void SummonPackRaptors()
        {
            Talk(SAY_FRENZY);
            
            // Summon 4-6 pack raptors
            for (uint8 i = 0; i < urand(4, 6); ++i)
            {
                float angle = frand(0, 2 * M_PI);
                float dist = frand(8.0f, 15.0f);
                float x = me->GetPositionX() + dist * cos(angle);
                float y = me->GetPositionY() + dist * sin(angle);
                
                me->SummonCreature(NPC_PACK_RAPTOR, x, y, me->GetPositionZ(),
                    me->GetOrientation(), TEMPSUMMON_TIMED_OR_CORPSE_DESPAWN, 60000);
            }
        }

        void DoFixate()
        {
            Talk(SAY_FIXATE);
            
            // Target random player who isn't the tank
            if (Unit* target = SelectTarget(SelectTargetMethod::Random, 1, 100.0f, true))
            {
                fixateTarget = target->GetGUID();
                
                // Apply fixate visual
                DoCast(target, SPELL_FIXATE);
                
                // Warn the target
                if (Player* player = target->ToPlayer())
                {
                    ChatHandler(player->GetSession()).PSendSysMessage(
                        "|cFFFF0000Thok is FIXATING on you! RUN!|r");
                }
                
                // Clear threat and attack fixate target
                me->GetThreatMgr().ClearAllThreat();
                me->GetThreatMgr().AddThreat(target, 1000000.0f);
                
                // Increase speed during fixate
                me->SetSpeedRate(MOVE_RUN, 1.5f);
                
                // Schedule end of fixate
                events.ScheduleEvent(EVENT_END_FIXATE, 10s);
            }
        }

        void EndFixate()
        {
            fixateTarget = ObjectGuid::Empty;
            me->SetSpeedRate(MOVE_RUN, 1.0f + (accelerationStacks * 0.1f));
            
            // Return to normal threat
            me->GetThreatMgr().ClearAllThreat();
            DoZoneInCombat();
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            events.Update(diff);

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            while (uint32 eventId = events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_DEAFENING_SCREECH:
                        Talk(SAY_SCREECH);
                        DoCastAOE(SPELL_DEAFENING_SCREECH);
                        events.ScheduleEvent(EVENT_DEAFENING_SCREECH, 
                            inFrenzy ? 20s : 30s);
                        break;
                        
                    case EVENT_TAIL_LASH:
                        DoCastSelf(SPELL_TAIL_LASH);
                        events.ScheduleEvent(EVENT_TAIL_LASH, 12s);
                        break;
                        
                    case EVENT_ACCELERATION:
                        DoCastSelf(SPELL_ACCELERATION);
                        accelerationStacks++;
                        
                        // Increase base speed
                        me->SetSpeedRate(MOVE_RUN, 1.0f + (accelerationStacks * 0.1f));
                        
                        if (accelerationStacks == 3)
                        {
                            me->Yell("Thok accelerates dangerously!", LANG_UNIVERSAL);
                        }
                        else if (accelerationStacks >= 5)
                        {
                            me->Yell("Thok reaches maximum speed!", LANG_UNIVERSAL);
                        }
                        
                        events.ScheduleEvent(EVENT_ACCELERATION, 45s);
                        break;
                        
                    case EVENT_SAVAGE_BITE:
                        DoCastVictim(SPELL_SAVAGE_BITE);
                        
                        // Apply bleed
                        if (Unit* victim = me->GetVictim())
                            DoCast(victim, SPELL_CARNAGE);
                        
                        events.ScheduleEvent(EVENT_SAVAGE_BITE, 
                            inFrenzy ? 5s : 8s);
                        break;
                        
                    case EVENT_FIXATE:
                        DoFixate();
                        events.ScheduleEvent(EVENT_FIXATE, 40s);
                        break;
                        
                    case EVENT_END_FIXATE:
                        EndFixate();
                        break;
                        
                    case EVENT_SUMMON_PACK:
                        if (inFrenzy)
                        {
                            // Summon more raptors in frenzy phase
                            for (uint8 i = 0; i < urand(2, 3); ++i)
                            {
                                float angle = frand(0, 2 * M_PI);
                                float dist = frand(8.0f, 15.0f);
                                float x = me->GetPositionX() + dist * cos(angle);
                                float y = me->GetPositionY() + dist * sin(angle);
                                
                                me->SummonCreature(NPC_PACK_RAPTOR, x, y, me->GetPositionZ(),
                                    me->GetOrientation(), TEMPSUMMON_TIMED_OR_CORPSE_DESPAWN, 60000);
                            }
                            events.ScheduleEvent(EVENT_SUMMON_PACK, 30s);
                        }
                        break;
                        
                    case EVENT_BERSERK:
                        Talk(SAY_BERSERK);
                        DoCastSelf(SPELL_BERSERK);
                        break;
                    case EVENT_HP_CHECK:
                    {
                        int hpPct = me->GetHealthPct();
                        const int thresholds[3] = {75, 50, 25};
                        for (int i = 0; i < 3; ++i)
                        {
                            if (!hpTriggered[i] && hpPct <= thresholds[i])
                            {
                                hpTriggered[i] = true;
                                DCAddon::JsonValue bossesArr; bossesArr.SetArray();
                                DCAddon::JsonValue b; b.SetObject();
                                b.Set("entry", DCAddon::JsonValue(static_cast<int32>(me->GetEntry())));
                                b.Set("spawnId", DCAddon::JsonValue(static_cast<int32>(me->GetSpawnId())));
                                b.Set("name", DCAddon::JsonValue(me->GetName()));
                                b.Set("mapId", DCAddon::JsonValue(static_cast<int32>(me->GetMapId())));
                                b.Set("guid", DCAddon::JsonValue(me->GetGUID().ToString()));
                                b.Set("active", DCAddon::JsonValue(true));
                                b.Set("hpPct", DCAddon::JsonValue(static_cast<int32>(hpPct)));
                                b.Set("action", DCAddon::JsonValue("hp_update"));
                                b.Set("threshold", DCAddon::JsonValue(static_cast<int32>(thresholds[i])));
                                bossesArr.Push(b);
                                DCAddon::JsonMessage wmsg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
                                wmsg.Set("bosses", bossesArr);
                                if (Map* map = me->GetMap()) map->DoForAllPlayers([&](Player* player){ if (player && player->IsInWorld() && player->GetSession()) wmsg.Send(player); });
                            }
                        }
                        if (!me->isDead()) events.ScheduleEvent(EVENT_HP_CHECK, 5s);
                    }
                    break;
                }
            }

            DoMeleeAttackIfReady();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new boss_thokAI(creature);
    }
};

// ============================================================================
// ADD AI: FRENZIED PACK RAPTOR
// ============================================================================

class npc_pack_raptor : public CreatureScript
{
public:
    npc_pack_raptor() : CreatureScript("npc_pack_raptor") { }

    struct npc_pack_raptorAI : public ScriptedAI
    {
        npc_pack_raptorAI(Creature* creature) : ScriptedAI(creature) { }

        uint32 leapTimer;
        uint32 rakeTimer;

        void Reset() override
        {
            leapTimer = 5000;
            rakeTimer = 3000;
            
            // Pack raptors are faster
            me->SetSpeedRate(MOVE_RUN, 1.3f);
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            if (leapTimer <= diff)
            {
                // Leap to a random target
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                {
                    me->GetMotionMaster()->MoveCharge(target->GetPositionX(), target->GetPositionY(),
                        target->GetPositionZ(), 42.0f);
                }
                leapTimer = 15000;
            }
            else
                leapTimer -= diff;

            if (rakeTimer <= diff)
            {
                DoCastVictim(SPELL_CARNAGE); // Bleed
                rakeTimer = 8000;
            }
            else
                rakeTimer -= diff;

            DoMeleeAttackIfReady();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_pack_raptorAI(creature);
    }
};

// ============================================================================
// REGISTER SCRIPTS
// ============================================================================

void AddSC_boss_thok()
{
    new boss_thok();
    new npc_pack_raptor();
}
