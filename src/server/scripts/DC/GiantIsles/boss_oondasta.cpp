/*
 * Giant Isles - Boss: Oondasta
 * ============================================================================
 * King of Dinosaurs - The apex predator of Giant Isles
 * Based on MoP world boss mechanics adapted for WotLK 3.3.5a
 *
 * ABILITIES:
 *   - Crushing Charge: Charges a random target, dealing massive damage
 *   - Frill Blast: Frontal cone attack dealing shadow damage
 *   - Growing Fury: Enrage stacking buff the longer the fight goes
 *   - Piercing Roar: Fear effect on all nearby players
 *   - Alpha Predator: Summons Young Oondasta adds periodically
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
#include "../AddonExtension/dc_addon_namespace.h"

enum OondastaSpells
{
    // Main abilities
    SPELL_CRUSHING_CHARGE       = 70988,  // Charge effect (from ICC bosses)
    SPELL_CRUSHING_CHARGE_DMG   = 70292,  // Damage on charge impact
    SPELL_FRILL_BLAST           = 69164,  // Shadow damage cone (like shadow breath)
    SPELL_PIERCING_ROAR         = 36629,  // AoE fear
    SPELL_GROWING_FURY          = 37540,  // Stacking damage buff (frenzy)
    SPELL_ALPHA_PREDATOR        = 42705,  // Visual for summoning

    // Visual effects
    SPELL_BERSERK               = 26662,  // Hard enrage
    SPELL_CHAOS_AURA            = 28126,  // Chaos visual effect

    // Add spells
    SPELL_YOUNG_BITE            = 49892,  // Young Oondasta basic attack
};

enum OondastaEvents
{
    EVENT_CRUSHING_CHARGE       = 1,
    EVENT_FRILL_BLAST           = 2,
    EVENT_PIERCING_ROAR         = 3,
    EVENT_GROWING_FURY          = 4,
    EVENT_SUMMON_ADDS           = 5,
    EVENT_BERSERK               = 6,
    EVENT_HP_CHECK              = 7,
};

enum OondastaTexts
{
    SAY_AGGRO                   = 0,
    SAY_CHARGE                  = 1,
    SAY_SUMMON                  = 2,
    SAY_FRILL_BLAST             = 3,
    SAY_BERSERK                 = 4,
    SAY_DEATH                   = 5,
    SAY_KILL                    = 6,
};

enum OondastaData
{
    NPC_OONDASTA                = 400100,
    NPC_YOUNG_OONDASTA          = 400400,

    // Timers (in milliseconds)
    TIMER_CRUSHING_CHARGE       = 25000,
    TIMER_FRILL_BLAST           = 15000,
    TIMER_PIERCING_ROAR         = 45000,
    TIMER_GROWING_FURY          = 20000,
    TIMER_SUMMON_ADDS           = 60000,
    TIMER_BERSERK               = 600000, // 10 minutes enrage
};

// ============================================================================
// BOSS AI: OONDASTA
// ============================================================================

class boss_oondasta : public CreatureScript
{
public:
    boss_oondasta() : CreatureScript("boss_oondasta") { }

    struct boss_oondastaAI : public ScriptedAI
    {
        boss_oondastaAI(Creature* creature) : ScriptedAI(creature), summons(me)
        {
            furyStacks = 0;
            isEnraged = false;
        }

        EventMap events;
        SummonList summons;
        uint8 furyStacks;
        bool isEnraged;
        bool hpTriggered[3];

        void Reset() override
        {

            events.Reset();
            summons.DespawnAll();
            furyStacks = 0;
            isEnraged = false;

            me->RemoveAllAuras();
            me->SetReactState(REACT_AGGRESSIVE);
            hpTriggered[0] = hpTriggered[1] = hpTriggered[2] = false;
        }

        void JustAppeared()
        {
            // Notify addon clients (WRLD) that a world boss has spawned
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
            if (Map* map = me->GetMap())
            {
                map->DoForAllPlayers([&](Player* player){ if (player && player->IsInWorld() && player->GetSession()) wmsg.Send(player); });
            }
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            Talk(SAY_AGGRO);

            // Schedule abilities
            events.ScheduleEvent(EVENT_CRUSHING_CHARGE, 10s);
            events.ScheduleEvent(EVENT_FRILL_BLAST, 8s);
            events.ScheduleEvent(EVENT_PIERCING_ROAR, 30s);
            events.ScheduleEvent(EVENT_GROWING_FURY, 20s);
            events.ScheduleEvent(EVENT_SUMMON_ADDS, 60s);
            events.ScheduleEvent(EVENT_BERSERK, 10min);
            events.ScheduleEvent(EVENT_HP_CHECK, 5s);

            // Notify addon clients (WRLD) that a world boss has started
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
            b.Set("action", DCAddon::JsonValue("engage"));
            bossesArr.Push(b);

            DCAddon::JsonMessage wmsg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
            wmsg.Set("bosses", bossesArr);
            if (Map* map = me->GetMap())
            {
                map->DoForAllPlayers([&](Player* player){ if (player && player->IsInWorld() && player->GetSession()) wmsg.Send(player); });
            }
        }

        void JustDied(Unit* /*killer*/) override
        {
            Talk(SAY_DEATH);
            summons.DespawnAll();

            // Server-wide announcement handled by zone script

            // Notify addon clients (WRLD) that world boss has died
            {
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
                b.Set("active", DCAddon::JsonValue(false));
                b.Set("hpPct", DCAddon::JsonValue(static_cast<int32>(me->GetHealthPct())));
                // Ensure respawn time is recorded before we compute it
                me->SetRespawnTime(me->GetRespawnDelay());
                me->SaveRespawnTime();
                {
                    time_t now = GameTime::GetGameTime().count();
                    int64 diff = 0;
                    if (Map* map = me->GetMap())
                    {
                        time_t rt = map->GetCreatureRespawnTime(static_cast<ObjectGuid::LowType>(me->GetSpawnId()));
                        diff = static_cast<int64>(rt) - static_cast<int64>(now);
                    }
                    if (diff <= 0)
                        diff = static_cast<int64>(me->GetRespawnTimeEx()) - static_cast<int64>(now);
                    uint32 spawnIn = diff > 0 ? static_cast<uint32>(diff) : me->GetRespawnDelay();
                    b.Set("spawnIn", DCAddon::JsonValue(static_cast<int32>(spawnIn)));
                    b.Set("status", DCAddon::JsonValue("spawning"));
                }
                b.Set("action", DCAddon::JsonValue("death"));
                bossesArr.Push(b);

                DCAddon::JsonMessage wmsg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
                wmsg.Set("bosses", bossesArr);
                if (Map* map = me->GetMap())
                {
                    map->DoForAllPlayers([&](Player* player){ if (player && player->IsInWorld() && player->GetSession()) wmsg.Send(player); });
                }
            }
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

            if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                summon->AI()->AttackStart(target);
        }

        void SummonedCreatureDespawn(Creature* summon) override
        {
            summons.Despawn(summon);
        }

        Unit* GetChargeTarget()
        {
            // Get a random ranged target for charge
            std::vector<Unit*> targets;
            ThreatContainer::StorageType const& threatList = me->GetThreatMgr().GetThreatList();

            for (auto itr = threatList.begin(); itr != threatList.end(); ++itr)
            {
                if (Unit* target = ObjectAccessor::GetUnit(*me, (*itr)->getUnitGuid()))
                {
                    if (target->IsPlayer() && me->GetDistance(target) > 15.0f)
                        targets.push_back(target);
                }
            }

            if (targets.empty())
                return SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true);

            return targets[urand(0, targets.size() - 1)];
        }

        void DoCrushingCharge()
        {
            if (Unit* target = GetChargeTarget())
            {
                Talk(SAY_CHARGE);

                // Face target and charge
                me->SetFacingToObject(target);
                DoCast(target, SPELL_CRUSHING_CHARGE);

                // Do AoE damage immediately after charge cast
                DoCastAOE(SPELL_CRUSHING_CHARGE_DMG);
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
                    case EVENT_CRUSHING_CHARGE:
                        DoCrushingCharge();
                        events.ScheduleEvent(EVENT_CRUSHING_CHARGE, 25s);
                        break;

                    case EVENT_FRILL_BLAST:
                        Talk(SAY_FRILL_BLAST);
                        DoCastVictim(SPELL_FRILL_BLAST);
                        events.ScheduleEvent(EVENT_FRILL_BLAST, 15s);
                        break;

                    case EVENT_PIERCING_ROAR:
                        DoCastAOE(SPELL_PIERCING_ROAR);
                        events.ScheduleEvent(EVENT_PIERCING_ROAR, 45s);
                        break;

                    case EVENT_GROWING_FURY:
                        DoCastSelf(SPELL_GROWING_FURY);
                        furyStacks++;

                        // Announce at dangerous stacks
                        if (furyStacks == 5)
                        {
                            me->Yell("Oondasta's fury grows!", LANG_UNIVERSAL);
                        }
                        else if (furyStacks == 10)
                        {
                            me->Yell("Oondasta enters a primal rage!", LANG_UNIVERSAL);
                        }

                        events.ScheduleEvent(EVENT_GROWING_FURY, 20s);
                        break;

                    case EVENT_SUMMON_ADDS:
                        Talk(SAY_SUMMON);

                        // Summon 2-3 Young Oondasta adds
                        for (uint8 i = 0; i < urand(2, 3); ++i)
                        {
                            float angle = frand(0, 2 * M_PI);
                            float dist = frand(10.0f, 20.0f);
                            float x = me->GetPositionX() + dist * cos(angle);
                            float y = me->GetPositionY() + dist * sin(angle);

                            me->SummonCreature(NPC_YOUNG_OONDASTA, x, y, me->GetPositionZ(),
                                me->GetOrientation(), TEMPSUMMON_TIMED_OR_CORPSE_DESPAWN, 120000);
                        }

                        events.ScheduleEvent(EVENT_SUMMON_ADDS, 60s);
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

                    case EVENT_BERSERK:
                        if (!isEnraged)
                        {
                            Talk(SAY_BERSERK);
                            DoCastSelf(SPELL_BERSERK);
                            isEnraged = true;
                        }
                        break;
                }
            }

            DoMeleeAttackIfReady();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new boss_oondastaAI(creature);
    }
};

// ============================================================================
// ADD AI: YOUNG OONDASTA
// ============================================================================

class npc_young_oondasta : public CreatureScript
{
public:
    npc_young_oondasta() : CreatureScript("npc_young_oondasta") { }

    struct npc_young_oondastaAI : public ScriptedAI
    {
        npc_young_oondastaAI(Creature* creature) : ScriptedAI(creature) { }

        uint32 biteTimer;

        void Reset() override
        {
            biteTimer = 3000;
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            if (biteTimer <= diff)
            {
                DoCastVictim(SPELL_YOUNG_BITE);
                biteTimer = 5000;
            }
            else
                biteTimer -= diff;

            DoMeleeAttackIfReady();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_young_oondastaAI(creature);
    }
};

// ============================================================================
// REGISTER SCRIPTS
// ============================================================================

void AddSC_boss_oondasta()
{
    new boss_oondasta();
    new npc_young_oondasta();
}
