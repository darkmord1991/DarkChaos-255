/*
 * Giant Isles - Boss: Nalak the Storm Lord
 * ============================================================================
 * Ancient Thunder Lizard - Master of Lightning
 * Based on MoP world boss mechanics adapted for WotLK 3.3.5a
 *
 * ABILITIES:
 *   - Static Shield: Absorbs damage and reflects lightning
 *   - Arc Nova: Large AoE lightning damage
 *   - Lightning Tether: Chains players together with lightning
 *   - Storm Cloud: Spawns damaging clouds that move around
 *   - Tempest Wing: Knockback all players in melee range
 *   - Stormstrike: Heavy tank-buster ability
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellScript.h"
#include "SpellAuraEffects.h"
#include "Player.h"
#include "World.h"
#include "Chat.h"
#include "GameTime.h"
#include <algorithm>
#include <random>
#include "DC/CrossSystem/WorldBossMgr.h"

#include <cmath>

enum NalakSpells
{
    // Main abilities
    SPELL_STATIC_SHIELD         = 39067,  // Lightning shield absorb
    SPELL_ARC_NOVA              = 56397,  // Large AoE nature damage (like spell from Malygos)
    SPELL_LIGHTNING_TETHER      = 53475,  // Chain lightning link between players
    SPELL_STORM_CLOUD           = 57986,  // Summon storm cloud (damaging void zone)
    SPELL_TEMPEST_WING          = 56867,  // Knockback
    SPELL_STORMSTRIKE           = 48617,  // Heavy nature damage to tank

    // Lightning effects
    SPELL_LIGHTNING_BOLT        = 59024,  // Ranged attack
    SPELL_CHAIN_LIGHTNING       = 64213,  // Chain lightning
    SPELL_LIGHTNING_NOVA        = 56326,  // Pulsing damage

    // Visual effects
    SPELL_BERSERK               = 26662,
    SPELL_CHAOS_AURA            = 28126,
    SPELL_LIGHTNING_VISUAL      = 45111,  // Storm visual on boss

    // Cloud spells
    SPELL_STORM_CLOUD_DAMAGE    = 58965,  // Damage from standing in cloud
};

enum NalakEvents
{
    EVENT_STATIC_SHIELD         = 1,
    EVENT_ARC_NOVA              = 2,
    EVENT_LIGHTNING_TETHER      = 3,
    EVENT_STORM_CLOUD           = 4,
    EVENT_TEMPEST_WING          = 5,
    EVENT_STORMSTRIKE           = 6,
    EVENT_LIGHTNING_BOLT        = 7,
    EVENT_CHAIN_LIGHTNING       = 8,
    EVENT_BERSERK               = 9,
    EVENT_HP_CHECK              = 10,
};

enum NalakTexts
{
    SAY_AGGRO                   = 0,
    SAY_ARC_NOVA                = 1,
    SAY_TETHER                  = 2,
    SAY_STORM                   = 3,
    SAY_BERSERK                 = 4,
    SAY_DEATH                   = 5,
    SAY_KILL                    = 6,
};

enum NalakData
{
    NPC_NALAK                   = 400102,
    NPC_STORM_SPARK             = 400402,
    NPC_STATIC_CLOUD            = 400403,

    // Timers
    TIMER_STATIC_SHIELD         = 60000,
    TIMER_ARC_NOVA              = 35000,
    TIMER_LIGHTNING_TETHER      = 25000,
    TIMER_STORM_CLOUD           = 20000,
    TIMER_TEMPEST_WING          = 18000,
    TIMER_STORMSTRIKE           = 10000,
    TIMER_LIGHTNING_BOLT        = 3000,
    TIMER_CHAIN_LIGHTNING       = 15000,
    TIMER_BERSERK               = 540000, // 9 minutes
};

// ============================================================================
// BOSS AI: NALAK THE STORM LORD
// ============================================================================

class boss_nalak : public CreatureScript
{
public:
    boss_nalak() : CreatureScript("boss_nalak") { }

    struct boss_nalakAI : public ScriptedAI
    {
        boss_nalakAI(Creature* creature) : ScriptedAI(creature), summons(me)
        {
            shieldActive = false;
            hpTriggered[0] = hpTriggered[1] = hpTriggered[2] = false;
        }

        EventMap events;
        SummonList summons;
        bool shieldActive;
        bool hpTriggered[3];

        void Reset() override
        {
            events.Reset();
            summons.DespawnAll();
            shieldActive = false;
            hpTriggered[0] = hpTriggered[1] = hpTriggered[2] = false;

            me->RemoveAllAuras();
            me->SetReactState(REACT_AGGRESSIVE);

            // Nalak uses nature/lightning school
            me->SetPower(POWER_MANA, me->GetMaxPower(POWER_MANA));
        }

        void JustAppeared()
        {
            // Notify addon clients via centralized WorldBossMgr
            sWorldBossMgr->OnBossSpawned(me);
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            Talk(SAY_AGGRO);

            // Apply storm visual
            DoCastSelf(SPELL_LIGHTNING_VISUAL);

            // Schedule abilities
            events.ScheduleEvent(EVENT_STATIC_SHIELD, 5s); // Early shield
            events.ScheduleEvent(EVENT_ARC_NOVA, 25s);
            events.ScheduleEvent(EVENT_LIGHTNING_TETHER, 15s);
            events.ScheduleEvent(EVENT_STORM_CLOUD, 30s);
            events.ScheduleEvent(EVENT_TEMPEST_WING, 18s);
            events.ScheduleEvent(EVENT_STORMSTRIKE, 10s);
            events.ScheduleEvent(EVENT_LIGHTNING_BOLT, 3s);
            events.ScheduleEvent(EVENT_CHAIN_LIGHTNING, 15s);
            events.ScheduleEvent(EVENT_BERSERK, 9min);
            events.ScheduleEvent(EVENT_HP_CHECK, 5s);

            // Notify addon clients via centralized WorldBossMgr
            sWorldBossMgr->OnBossEngaged(me);
        }

        void JustDied(Unit* /*killer*/) override
        {
            Talk(SAY_DEATH);
            summons.DespawnAll();
            hpTriggered[0] = hpTriggered[1] = hpTriggered[2] = false;
            // Notify addon clients via centralized WorldBossMgr
            sWorldBossMgr->OnBossDied(me);
        }

        void KilledUnit(Unit* victim) override
        {
            if (victim->IsPlayer())
            {
                if (urand(0, 100) < 30)
                    Talk(SAY_KILL);
            }
        }

        void JustSummoned(Creature* summon) override
        {
            summons.Summon(summon);

            if (summon->GetEntry() == NPC_STORM_SPARK)
            {
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                    summon->AI()->AttackStart(target);
            }
        }

        void SummonedCreatureDespawn(Creature* summon) override
        {
            summons.Despawn(summon);
        }

        void DoArcNova()
        {
            Talk(SAY_ARC_NOVA);

            // Warning emote
            me->Yell("Nalak channels a massive Arc Nova!", LANG_UNIVERSAL);

            // Cast AoE
            DoCastAOE(SPELL_ARC_NOVA);
        }

        void DoLightningTether()
        {
            Talk(SAY_TETHER);

            // Get 2-3 random players and chain them
            std::vector<Unit*> targets;
            ThreatContainer::StorageType const& threatList = me->GetThreatMgr().GetThreatList();

            for (auto itr = threatList.begin(); itr != threatList.end(); ++itr)
            {
                if (Unit* target = ObjectAccessor::GetUnit(*me, (*itr)->getUnitGuid()))
                {
                    if (target->IsPlayer())
                        targets.push_back(target);
                }
            }

            if (targets.size() >= 2)
            {
                // Shuffle and pick 2-3
                static std::random_device rd;
                static std::mt19937 rng(rd());
                std::shuffle(targets.begin(), targets.end(), rng);
                uint8 numTargets = std::min((size_t)3, targets.size());

                for (uint8 i = 0; i < numTargets; ++i)
                {
                    DoCast(targets[i], SPELL_LIGHTNING_TETHER);

                    if (Player* player = targets[i]->ToPlayer())
                    {
                        ChatHandler(player->GetSession()).PSendSysMessage(
                            "|cFF00FFFF[Nalak]|r You are tethered! Stay close to other tethered players!");
                    }
                }
            }
        }

        void DoStormCloud()
        {
            Talk(SAY_STORM);

            // Spawn storm clouds at random positions
            for (uint8 i = 0; i < urand(2, 4); ++i)
            {
                float angle = frand(0, 2 * M_PI);
                float dist = frand(15.0f, 35.0f);
                float x = me->GetPositionX() + dist * cos(angle);
                float y = me->GetPositionY() + dist * sin(angle);

                if (Creature* cloud = me->SummonCreature(NPC_STATIC_CLOUD, x, y, me->GetPositionZ(),
                    0, TEMPSUMMON_TIMED_DESPAWN, 20000))
                {
                    // Cloud moves slowly in random direction
                    cloud->SetSpeedRate(MOVE_WALK, 0.3f);
                    cloud->SetSpeedRate(MOVE_RUN, 0.3f);
                    cloud->SetReactState(REACT_PASSIVE);
                    cloud->SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NOT_SELECTABLE);

                    // Cloud pulses damage
                    cloud->CastSpell(cloud, SPELL_STORM_CLOUD_DAMAGE, true);
                }
            }
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
                    case EVENT_STATIC_SHIELD:
                        DoCastSelf(SPELL_STATIC_SHIELD);
                        shieldActive = true;

                        me->Yell("Nalak surrounds himself with a Static Shield!", LANG_UNIVERSAL);

                        // Spawn storm sparks while shield is active
                        for (uint8 i = 0; i < 2; ++i)
                        {
                            float angle = frand(0, 2 * M_PI);
                            float dist = frand(5.0f, 10.0f);
                            float x = me->GetPositionX() + dist * cos(angle);
                            float y = me->GetPositionY() + dist * sin(angle);

                            me->SummonCreature(NPC_STORM_SPARK, x, y, me->GetPositionZ(),
                                me->GetOrientation(), TEMPSUMMON_TIMED_OR_CORPSE_DESPAWN, 30000);
                        }

                        events.ScheduleEvent(EVENT_STATIC_SHIELD, 60s);
                        break;

                    case EVENT_ARC_NOVA:
                        DoArcNova();
                        events.ScheduleEvent(EVENT_ARC_NOVA, 35s);
                        break;

                    case EVENT_LIGHTNING_TETHER:
                        DoLightningTether();
                        events.ScheduleEvent(EVENT_LIGHTNING_TETHER, 25s);
                        break;

                    case EVENT_STORM_CLOUD:
                        DoStormCloud();
                        events.ScheduleEvent(EVENT_STORM_CLOUD, 20s);
                        break;

                    case EVENT_TEMPEST_WING:
                        DoCastAOE(SPELL_TEMPEST_WING);
                        events.ScheduleEvent(EVENT_TEMPEST_WING, 18s);
                        break;

                    case EVENT_STORMSTRIKE:
                        DoCastVictim(SPELL_STORMSTRIKE);
                        events.ScheduleEvent(EVENT_STORMSTRIKE, 10s);
                        break;

                    case EVENT_LIGHTNING_BOLT:
                        // Cast at random ranged player
                        if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                        {
                            DoCast(target, SPELL_LIGHTNING_BOLT);
                        }
                        events.ScheduleEvent(EVENT_LIGHTNING_BOLT, 3s);
                        break;

                    case EVENT_CHAIN_LIGHTNING:
                        if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                            DoCast(target, SPELL_CHAIN_LIGHTNING);
                        events.ScheduleEvent(EVENT_CHAIN_LIGHTNING, 15s);
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
                                sWorldBossMgr->OnBossHPUpdate(me, static_cast<uint8>(hpPct), static_cast<uint8>(thresholds[i]));
                            }
                        }
                        if (!me->isDead()) events.ScheduleEvent(EVENT_HP_CHECK, 5s);
                    }
                    break;

                    case EVENT_BERSERK:
                        Talk(SAY_BERSERK);
                        DoCastSelf(SPELL_BERSERK);
                        break;
                }
            }

            DoMeleeAttackIfReady();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new boss_nalakAI(creature);
    }
};

// ============================================================================
// ADD AI: STORM SPARK
// ============================================================================

class npc_storm_spark : public CreatureScript
{
public:
    npc_storm_spark() : CreatureScript("npc_storm_spark") { }

    struct npc_storm_sparkAI : public ScriptedAI
    {
        npc_storm_sparkAI(Creature* creature) : ScriptedAI(creature) { }

        uint32 boltTimer;
        uint32 novaTimer;

        void Reset() override
        {
            boltTimer = 2000;
            novaTimer = 8000;
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            if (boltTimer <= diff)
            {
                DoCastVictim(SPELL_LIGHTNING_BOLT);
                boltTimer = 3000;
            }
            else
                boltTimer -= diff;

            if (novaTimer <= diff)
            {
                DoCastAOE(SPELL_LIGHTNING_NOVA);
                novaTimer = 10000;
            }
            else
                novaTimer -= diff;

            DoMeleeAttackIfReady();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_storm_sparkAI(creature);
    }
};

// ============================================================================
// NPC AI: STATIC CLOUD (Void Zone)
// ============================================================================

class npc_static_cloud : public CreatureScript
{
public:
    npc_static_cloud() : CreatureScript("npc_static_cloud") { }

    struct npc_static_cloudAI : public NullCreatureAI
    {
        npc_static_cloudAI(Creature* creature) : NullCreatureAI(creature) { }

        uint32 moveTimer;
        uint32 damageTimer;

        void Reset() override
        {
            moveTimer = 3000;
            damageTimer = 1000;

            // Apply storm cloud visual
            DoCastSelf(SPELL_STORM_CLOUD_DAMAGE);
        }

        void UpdateAI(uint32 diff) override
        {
            // Move in random direction periodically
            if (moveTimer <= diff)
            {
                float angle = frand(0, 2 * M_PI);
                float dist = 5.0f;
                float x = me->GetPositionX() + dist * cos(angle);
                float y = me->GetPositionY() + dist * sin(angle);

                me->GetMotionMaster()->MovePoint(0, x, y, me->GetPositionZ());
                moveTimer = 5000;
            }
            else
                moveTimer -= diff;

            // Damage nearby players
            if (damageTimer <= diff)
            {
                Map::PlayerList const& players = me->GetMap()->GetPlayers();
                for (auto itr = players.begin(); itr != players.end(); ++itr)
                {
                    if (Player* player = itr->GetSource())
                    {
                        if (player->IsAlive() && me->GetDistance(player) < 6.0f)
                        {
                            me->CastSpell(player, SPELL_STORM_CLOUD_DAMAGE, true);
                        }
                    }
                }
                damageTimer = 2000;
            }
            else
                damageTimer -= diff;
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_static_cloudAI(creature);
    }
};

// ============================================================================
// REGISTER SCRIPTS
// ============================================================================

void AddSC_boss_nalak()
{
    new boss_nalak();
    new npc_storm_spark();
    new npc_static_cloud();
}
