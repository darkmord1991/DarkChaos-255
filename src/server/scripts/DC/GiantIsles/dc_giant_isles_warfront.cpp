/*
 * Giant Isles - The war front
 * ==========================================================================
 * What the Blood Tide leaves behind between assaults:
 *   - Foothold camps: every level of the campaign foothold that the Zandalari
 *     hold is a set of spawns (game events 251-253), so a lost invasion is
 *     visible on the island, and a won one clears it again.
 *   - The captives in the cages around Slimer Bay and the bunkers.
 *   - The powder charges at the war engines.
 *   - The scouting markers for Elder Zul'jin's opening quest.
 *   - War-God Dokah on his flagship: killing him is the way to push the
 *     foothold back without waiting for the next assault.
 *
 * The orchestrator (dc_giant_isles_invasion.cpp) owns the campaign values and
 * the dailies here feed its war effort.
 * ==========================================================================
 */

#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "Chat.h"
#include "Player.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "GameObject.h"
#include "GameEventMgr.h"
#include "EventMap.h"
#include "Log.h"
#include "MotionMaster.h"
#include "WorldState.h"

#include "dc_giant_isles_invasion_internal.h"

#include <array>
#include <atomic>

using namespace std::chrono_literals;
using namespace DCGiantIsles;

namespace
{
    enum FootholdTier : uint16
    {
        // Spawn sets in game_event_creature / game_event_gameobject. Event ids stop
        // at 255: game_event.eventEntry is a tinyint and the core reads it as uint8.
        GAME_EVENT_FOOTHOLD_TERRACE = 251,      // foothold 1+: the terrace above the Landing
        GAME_EVENT_FOOTHOLD_BEACH   = 252,      // foothold 3+: the beach garrison
        GAME_EVENT_FOOTHOLD_WARPATH = 253,      // foothold 5:  the Warpath outposts
    };

    struct FootholdTierInfo
    {
        uint16 gameEvent;
        uint32 minFoothold;
    };

    std::array<FootholdTierInfo, 3> const FootholdTiers =
    {{
        { GAME_EVENT_FOOTHOLD_TERRACE, 1 },
        { GAME_EVENT_FOOTHOLD_BEACH,   3 },
        { GAME_EVENT_FOOTHOLD_WARPATH, 5 },
    }};

    constexpr uint32 FOOTHOLD_RESYNC_INTERVAL_MS = 30 * IN_MILLISECONDS;

    // Set from the map thread, consumed on the world thread.
    std::atomic<bool> sFootholdSyncRequested{ true };

    // Starting a game event spawns into the grid and edits global spawn data,
    // which is only safe outside the threaded map update. The world update runs
    // between map updates, so the camps are applied from here.
    class world_giant_isles_foothold : public WorldScript
    {
    public:
        world_giant_isles_foothold() : WorldScript("world_giant_isles_foothold", { WORLDHOOK_ON_UPDATE }) { }

        void OnUpdate(uint32 diff) override
        {
            if (_resyncTimerMs > diff)
                _resyncTimerMs -= diff;
            else
                _resyncTimerMs = 0;

            if (_resyncTimerMs > 0 && !sFootholdSyncRequested.exchange(false))
                return;

            _resyncTimerMs = FOOTHOLD_RESYNC_INTERVAL_MS;
            ApplyFoothold();
        }

    private:
        uint32 _resyncTimerMs = 0;

        void ApplyFoothold()
        {
            uint32 const foothold = sWorldState ? static_cast<uint32>(sWorldState->getWorldState(WS_INVASION_CAMPAIGN)) : 0;
            GameEventMgr::GameEventDataMap const& events = sGameEventMgr->GetEventMap();

            for (FootholdTierInfo const& tier : FootholdTiers)
            {
                // StartEvent indexes the event table unchecked; without the SQL
                // applied this id would be out of range.
                if (tier.gameEvent >= events.size() || !events[tier.gameEvent].isValid())
                    continue;

                bool const wanted = foothold >= tier.minFoothold;
                bool const running = sGameEventMgr->IsActiveEvent(tier.gameEvent);

                if (wanted && !running)
                {
                    LOG_INFO("scripts.dc", "Giant Isles war front: raising foothold camp {} (foothold {})", tier.gameEvent, foothold);
                    sGameEventMgr->StartEvent(tier.gameEvent, true);
                }
                else if (!wanted && running)
                {
                    LOG_INFO("scripts.dc", "Giant Isles war front: clearing foothold camp {} (foothold {})", tier.gameEvent, foothold);
                    sGameEventMgr->StopEvent(tier.gameEvent, true);
                }
            }
        }
    };

    // =======================================================================
    // npc_giant_isles_captive - a Beast Hunter in a Zandalari cage.
    // =======================================================================
    constexpr uint32 CAPTIVE_GOSSIP_TEXT = 400366;
    constexpr uint8 SAY_CAPTIVE_FREED = 0;
    constexpr uint32 CAPTIVE_RESPAWN_SEC = 180;

    class npc_giant_isles_captive : public CreatureScript
    {
    public:
        npc_giant_isles_captive() : CreatureScript("npc_giant_isles_captive") { }

        bool OnGossipHello(Player* player, Creature* creature) override
        {
            if (!player || !creature)
                return false;

            if (player->GetQuestStatus(QUEST_CUT_THEIR_CHAINS) == QUEST_STATUS_INCOMPLETE)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Hold still. I'll break the lock.", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);

            SendGossipMenuFor(player, CAPTIVE_GOSSIP_TEXT, creature->GetGUID());
            return true;
        }

        bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
        {
            if (!player || !creature)
                return false;

            ClearGossipMenuFor(player);
            CloseGossipMenuFor(player);

            if (action != GOSSIP_ACTION_INFO_DEF + 1 || !creature->IsAlive())
                return true;

            if (player->GetQuestStatus(QUEST_CUT_THEIR_CHAINS) != QUEST_STATUS_INCOMPLETE)
                return true;

            player->KilledMonsterCredit(NPC_CAPTIVE_BEAST_HUNTER);

            if (CreatureAI* ai = creature->AI())
                ai->Talk(SAY_CAPTIVE_FREED, player);

            creature->ReplaceAllNpcFlags(UNIT_NPC_FLAG_NONE);
            creature->SetWalk(false);
            creature->GetMotionMaster()->MoveFleeing(player, 4000);
            creature->DespawnOrUnsummon(4s, Seconds(CAPTIVE_RESPAWN_SEC));
            return true;
        }
    };

    // =======================================================================
    // go_giant_isles_powder_charge - sabotage kit at a war engine.
    // =======================================================================
    constexpr uint32 POWDER_CHARGE_RESPAWN_SEC = 180;
    constexpr uint32 POWDER_CHARGE_BLAST_MS = 10 * IN_MILLISECONDS;

    class go_giant_isles_powder_charge : public GameObjectScript
    {
    public:
        go_giant_isles_powder_charge() : GameObjectScript("go_giant_isles_powder_charge") { }

        bool OnGossipHello(Player* player, GameObject* go) override
        {
            if (!player || !go)
                return true;

            if (player->GetQuestStatus(QUEST_SPIKE_THE_ENGINES) != QUEST_STATUS_INCOMPLETE)
            {
                ChatHandler(player->GetSession()).SendSysMessage("The charge is primed, but you have no orders to set it off.");
                return true;
            }

            player->KilledMonsterCredit(NPC_CREDIT_ENGINE_SABOTAGED);

            // The blast is friendly fire for the crew standing around it.
            if (Creature* blast = go->SummonCreature(NPC_IMPACT_MARKER, go->GetPosition(), TEMPSUMMON_TIMED_DESPAWN, POWDER_CHARGE_BLAST_MS))
            {
                blast->SetFaction(DEFENDER_FACTION);

                if (CreatureAI* ai = blast->AI())
                    ai->DoAction(ACTION_DROP_FIRE);
            }

            go->DespawnOrUnsummon(0ms, Seconds(POWDER_CHARGE_RESPAWN_SEC));
            return true;
        }
    };

    // =======================================================================
    // npc_giant_isles_scout_marker - invisible credit for getting eyes on a
    // Zandalari position. The creature's own entry is the quest objective.
    // =======================================================================
    constexpr float SCOUT_MARKER_RANGE = 45.0f;

    class npc_giant_isles_scout_marker : public CreatureScript
    {
    public:
        npc_giant_isles_scout_marker() : CreatureScript("npc_giant_isles_scout_marker") { }

        struct npc_giant_isles_scout_markerAI : public ScriptedAI
        {
            npc_giant_isles_scout_markerAI(Creature* creature) : ScriptedAI(creature) { }

            void Reset() override
            {
                me->SetReactState(REACT_PASSIVE);
            }

            void AttackStart(Unit* /*who*/) override { }

            void MoveInLineOfSight(Unit* who) override
            {
                if (!who)
                    return;

                Player* player = who->ToPlayer();
                if (!player || player->GetQuestStatus(QUEST_SMOKE_ON_THE_HORIZON) != QUEST_STATUS_INCOMPLETE)
                    return;

                if (me->IsWithinDist(player, SCOUT_MARKER_RANGE))
                    player->KilledMonsterCredit(me->GetEntry());
            }

            void UpdateAI(uint32 /*diff*/) override { }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_giant_isles_scout_markerAI(creature);
        }
    };

    // =======================================================================
    // npc_war_god_dokah - the master of the flagship.
    // =======================================================================
    enum DokahSpells : uint32
    {
        SPELL_DOKAH_MORTAL_STRIKE   = 35054,
        SPELL_DOKAH_WHIRLWIND       = 38619,
        SPELL_DOKAH_CHAIN_LIGHTNING = 61879,
        SPELL_DOKAH_THUNDERCLAP     = 38537,
        SPELL_DOKAH_BLOODLUST       = 65980,
    };

    enum DokahEvents
    {
        EVENT_DOKAH_MORTAL_STRIKE   = 1,
        EVENT_DOKAH_WHIRLWIND       = 2,
        EVENT_DOKAH_CHAIN_LIGHTNING = 3,
        EVENT_DOKAH_THUNDERCLAP     = 4,
    };

    enum DokahTexts : uint8
    {
        SAY_DOKAH_AGGRO = 0,
        SAY_DOKAH_FURY  = 1,
        SAY_DOKAH_DEATH = 2,
    };

    class npc_war_god_dokah : public CreatureScript
    {
    public:
        npc_war_god_dokah() : CreatureScript("npc_war_god_dokah") { }

        struct npc_war_god_dokahAI : public ScriptedAI
        {
            npc_war_god_dokahAI(Creature* creature) : ScriptedAI(creature) { }

            EventMap _events;
            bool _fury = false;

            void Reset() override
            {
                _events.Reset();
                _fury = false;
            }

            void JustEngagedWith(Unit* /*who*/) override
            {
                Talk(SAY_DOKAH_AGGRO);

                _events.ScheduleEvent(EVENT_DOKAH_MORTAL_STRIKE, 6s);
                _events.ScheduleEvent(EVENT_DOKAH_CHAIN_LIGHTNING, 9s);
                _events.ScheduleEvent(EVENT_DOKAH_THUNDERCLAP, 14s);
                _events.ScheduleEvent(EVENT_DOKAH_WHIRLWIND, 20s);
            }

            void DamageTaken(Unit* /*attacker*/, uint32& damage, DamageEffectType /*damagetype*/,
                SpellSchoolMask /*schoolMask*/) override
            {
                if (_fury || !me->HealthBelowPctDamaged(35, damage))
                    return;

                _fury = true;
                Talk(SAY_DOKAH_FURY);
                DoCastSelf(SPELL_DOKAH_BLOODLUST, true);
            }

            void JustDied(Unit* /*killer*/) override
            {
                Talk(SAY_DOKAH_DEATH);
                GI_NotifyWarGodSlain(me->GetMap());
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
                        case EVENT_DOKAH_MORTAL_STRIKE:
                            DoCastVictim(SPELL_DOKAH_MORTAL_STRIKE);
                            _events.ScheduleEvent(EVENT_DOKAH_MORTAL_STRIKE, 9s, 12s);
                            break;
                        case EVENT_DOKAH_CHAIN_LIGHTNING:
                            if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                                DoCast(target, SPELL_DOKAH_CHAIN_LIGHTNING);
                            _events.ScheduleEvent(EVENT_DOKAH_CHAIN_LIGHTNING, 11s, 15s);
                            break;
                        case EVENT_DOKAH_THUNDERCLAP:
                            DoCastAOE(SPELL_DOKAH_THUNDERCLAP);
                            _events.ScheduleEvent(EVENT_DOKAH_THUNDERCLAP, 16s, 20s);
                            break;
                        case EVENT_DOKAH_WHIRLWIND:
                            DoCastAOE(SPELL_DOKAH_WHIRLWIND);
                            _events.ScheduleEvent(EVENT_DOKAH_WHIRLWIND, 24s, 30s);
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
            return new npc_war_god_dokahAI(creature);
        }
    };
}

void GI_RequestFootholdSync(uint32 /*foothold*/)
{
    sFootholdSyncRequested = true;
}

void GI_RegisterWarFront()
{
    new world_giant_isles_foothold();
    new npc_giant_isles_captive();
    new go_giant_isles_powder_charge();
    new npc_giant_isles_scout_marker();
    new npc_war_god_dokah();
}
