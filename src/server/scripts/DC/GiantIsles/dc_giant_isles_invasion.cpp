/*
 * Giant Isles - Invasion: Zandalari Incursion
 * ==========================================================================
 * Deterministic rewrite focused on reliability:
 * - Fixed spawn coordinates only (no random XY jitter)
 * - Strict event-state gating (no out-of-event spawning)
 * - Simpler, conflict-free movement commands
 * - Replayability through lane-pressure and chaos pulses
 * ==========================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Group.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "ScriptedCreature.h"
#include "GameTime.h"
#include "WorldState.h"
#include "Map.h"
#include "MapMgr.h"
#include "ObjectAccessor.h"
#include "Chat.h"
#include "Log.h"
#include "Random.h"

#include <array>
#include <map>
#include <vector>
#include <string>
#include <sstream>
#include <algorithm>
#include <cmath>
#include <limits>

using namespace std::chrono_literals;

namespace
{
    enum InvasionData
    {
        MAP_GIANT_ISLES                 = 1405,
        AREA_SEEPING_SHORES             = 5010,

        NPC_INVASION_HORN               = 400325,

        // Invaders
        NPC_ZANDALARI_INVADER           = 400326,
        NPC_ZANDALARI_SCOUT             = 400327,
        NPC_ZANDALARI_SPEARMAN          = 400328,
        NPC_ZANDALARI_WARRIOR           = 400329,
        NPC_ZANDALARI_BERSERKER         = 400330,
        NPC_ZANDALARI_SHADOW_HUNTER     = 400331,
        NPC_ZANDALARI_BLOOD_GUARD       = 400332,
        NPC_ZANDALARI_WITCH_DOCTOR      = 400333,
        NPC_ZANDALARI_BEAST_TAMER       = 400334,
        NPC_ZANDALARI_WAR_RAPTOR        = 400335,
        NPC_WARLORD_ZULMAR              = 400336,
        NPC_ZANDALARI_HONOR_GUARD       = 400337,
        NPC_ZANDALARI_INVASION_LEADER   = 400338,

        // Defenders (Horde camp units)
        NPC_BEAST_HUNTER                = 401004,
        NPC_BEAST_HUNTER_VETERAN        = 401005,
        NPC_BEAST_HUNTER_TRAPPER        = 401006,
        NPC_BEAST_HUNTER_WARLORD        = 401007,

        INVADER_FACTION                 = 16,
        DEFENDER_FACTION_HORDE          = 29,

        // World states
        WORLD_STATE_INVASION_ACTIVE     = 20000,
        WORLD_STATE_INVASION_WAVE       = 20001,
        WORLD_STATE_INVASION_KILLS      = 20002,
        WORLD_STATE_INVASION_LAST_END   = 20010,

        // Rules
        INVASION_COOLDOWN               = 2 * HOUR,
        INVASION_MAX_GROUP_SIZE         = 10,
    };

    enum InvasionPhase
    {
        INVASION_INACTIVE               = 0,
        INVASION_WARNING                = 1,
        INVASION_WAVE_1                 = 2,
        INVASION_WAVE_2                 = 3,
        INVASION_WAVE_3                 = 4,
        INVASION_WAVE_4_BOSS            = 5,
        INVASION_VICTORY                = 6,
        INVASION_FAILED                 = 7,
    };

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

    constexpr uint32 WARNING_DURATION_MS = 30 * IN_MILLISECONDS;
    constexpr uint32 WAVE_1_DURATION_MS = 2 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 WAVE_2_DURATION_MS = 3 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 WAVE_3_DURATION_MS = 4 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 WAVE_4_DURATION_MS = 6 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 RESULT_DURATION_MS = 20 * IN_MILLISECONDS;

    constexpr uint32 WAVE_1_SPAWN_INTERVAL_MS = 5000;
    constexpr uint32 WAVE_2_SPAWN_INTERVAL_MS = 4200;
    constexpr uint32 WAVE_3_SPAWN_INTERVAL_MS = 3200;

    constexpr uint32 AUTO_TRIGGER_MIN_DELAY_SEC = 2 * HOUR;
    constexpr uint32 AUTO_TRIGGER_MAX_DELAY_SEC = 4 * HOUR;
    constexpr uint32 AUTO_TRIGGER_RETRY_NO_PLAYERS_SEC = 5 * MINUTE;
    constexpr uint32 AUTO_TRIGGER_RETRY_NO_HORN_SEC = 2 * MINUTE;

    constexpr uint32 NUDGE_INTERVAL_MS = 2000;
    constexpr uint32 CHAOS_PULSE_MIN_MS = 18000;
    constexpr uint32 CHAOS_PULSE_MAX_MS = 28000;
    constexpr uint32 SUMMON_LIFETIME_MS = 45 * MINUTE * IN_MILLISECONDS;

    constexpr float START_REQUIRED_RANGE_YARDS = 50.0f;
    constexpr float FRONTLINE_REWARD_RADIUS = 320.0f;

    struct InvasionSpawnPoint
    {
        float x;
        float y;
        float z;
        float o;
    };

    // User-provided invader landing positions.
    std::array<InvasionSpawnPoint, 4> const InvaderSpawnPoints =
    {{
        { 5764.2870f, 1156.7125f, 1.5225310f, 1.0770167f },
        { 5785.9243f, 1195.3062f, 2.9915880f, 1.2560875f },
        { 5811.5054f, 1164.1709f, 6.3400393f, 1.3785971f },
        { 5835.3057f, 1185.9261f, 7.4619540f, 2.1522145f },
    }};

    // User-provided defender setup points.
    std::array<InvasionSpawnPoint, 5> const DefenderSpawnPoints =
    {{
        { 5773.8545f, 1279.0825f, 9.0212740f, 4.8602786f },
        { 5767.0710f, 1267.4742f, 4.4330260f, 5.5907025f },
        { 5783.7056f, 1274.3718f, 8.9616880f, 4.9522200f },
        { 5795.2460f, 1275.0509f, 8.3642630f, 4.2979894f },
        { 5772.1035f, 1290.6915f, 12.275494f, 4.8210610f },
    }};

    std::array<InvasionSpawnPoint, 4> const LaneObjectives =
    {{
        { 5767.0710f, 1267.4742f, 4.4330260f, 5.5907025f },
        { 5773.8545f, 1279.0825f, 9.0212740f, 4.8602786f },
        { 5783.7056f, 1274.3718f, 8.9616880f, 4.9522200f },
        { 5795.2460f, 1275.0509f, 8.3642630f, 4.2979894f },
    }};

    InvasionSpawnPoint const FrontlineAnchor =
        { 5772.1035f, 1290.6915f, 12.275494f, 4.8210610f };

    class giant_isles_invasion;
    static giant_isles_invasion* sGiantIslesInvasion = nullptr;

    static uint32 GetNowSeconds()
    {
        return static_cast<uint32>(GameTime::GetGameTime().count());
    }

    static uint64 GetNowMs()
    {
        return static_cast<uint64>(GameTime::GetGameTimeMS().count());
    }

    static void SendMapSystemMessage(Map* map, char const* text)
    {
        if (!map || !text || !*text)
            return;

        map->DoForAllPlayers([&](Player* player)
        {
            if (!player || !player->IsInWorld() || !player->GetSession())
                return;
            if (player->GetMapId() != MAP_GIANT_ISLES)
                return;

            ChatHandler(player->GetSession()).SendSysMessage(text);
        });
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

    static void GI_TrackPlayerKill(ObjectGuid playerGuid);
    static void GI_RegisterSummonedInvader(Creature* creature);
    static void GI_MaintainBossGuards(Map* map);
    static void GI_NotifyBossDeath();
    static bool GI_IsInvasionActive();

    class npc_invasion_mob : public CreatureScript
    {
    public:
        npc_invasion_mob() : CreatureScript("npc_invasion_mob") { }

        struct npc_invasion_mobAI : public ScriptedAI
        {
            npc_invasion_mobAI(Creature* creature) : ScriptedAI(creature) { }

            std::vector<ObjectGuid> _raptorGuids;

            void Reset() override
            {
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
            }

            void JustDied(Unit* killer) override
            {
                DespawnRaptors();

                if (Player* player = ResolvePlayerKiller(killer))
                    GI_TrackPlayerKill(player->GetGUID());
            }

            void UpdateAI(uint32 diff) override
            {
                (void)diff;

                if (!UpdateVictim())
                    return;

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

            void DoAnnouncement(uint8 stage)
            {
                switch (stage)
                {
                    case 0:
                        me->Yell("Unload everything! The beach will burn!", LANG_UNIVERSAL);
                        break;
                    case 1:
                        me->Yell("Scouts first! Probe their line!", LANG_UNIVERSAL);
                        break;
                    case 2:
                        me->Yell("Warriors to the front! Break their shields!", LANG_UNIVERSAL);
                        break;
                    case 3:
                        me->Yell("Elites, crush them! No survivors!", LANG_UNIVERSAL);
                        break;
                    case 4:
                        me->Yell("Warlord Zul'mar, finish this!", LANG_UNIVERSAL);
                        break;
                    case 5:
                        me->Yell("Retreat to the ship!", LANG_UNIVERSAL);
                        break;
                    case 6:
                        me->Yell("The beach is ours. Hold this ground!", LANG_UNIVERSAL);
                        break;
                    default:
                        break;
                }
            }
        };

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_leaderAI(creature);
        }
    };

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

    class giant_isles_invasion : public WorldMapScript
    {
    public:
        giant_isles_invasion() : WorldMapScript("giant_isles_invasion", MAP_GIANT_ISLES)
        {
            sGiantIslesInvasion = this;
        }

        ~giant_isles_invasion() override
        {
            if (sGiantIslesInvasion == this)
                sGiantIslesInvasion = nullptr;
        }

        void OnCreate(Map* map) override
        {
            ResetWorldStates();
            CleanupTrackedSummons(map);
            ResetRuntimeState();
            ScheduleNextAutoTrigger("map-create");
            LOG_INFO("scripts.dc", "Giant Isles Invasion: map created and invasion state reset");
        }

        void OnDestroy(Map* map) override
        {
            CleanupTrackedSummons(map);
            ResetRuntimeState();
            ResetWorldStates();
        }

        void OnUpdate(Map* map, uint32 diff) override
        {
            if (!map || map->GetId() != MAP_GIANT_ISLES)
                return;

            if (_phase == INVASION_INACTIVE)
            {
                HandleAutoTrigger(map);
                return;
            }

            // Result states keep event visible briefly, then fully cleanup.
            if (_phase == INVASION_VICTORY || _phase == INVASION_FAILED)
            {
                if (_phaseTimerMs <= diff)
                    FinalizeEvent(map);
                else
                    _phaseTimerMs -= diff;

                return;
            }

            // Warning countdown.
            if (_phase == INVASION_WARNING)
            {
                if (_phaseTimerMs <= diff)
                    BeginWave(map, INVASION_WAVE_1);
                else
                    _phaseTimerMs -= diff;

                return;
            }

            if (_phase == INVASION_WAVE_1 || _phase == INVASION_WAVE_2 || _phase == INVASION_WAVE_3)
            {
                if (_spawnTimerMs <= diff)
                {
                    SpawnWaveTick(map);
                    _spawnTimerMs = GetWaveSpawnIntervalMs();
                }
                else
                {
                    _spawnTimerMs -= diff;
                }

                if (_phase == INVASION_WAVE_2 || _phase == INVASION_WAVE_3)
                {
                    if (_chaosTimerMs <= diff)
                        RunChaosPulse(map);
                    else
                        _chaosTimerMs -= diff;
                }

                if (_nudgeTimerMs <= diff)
                {
                    NudgeInvaders(map);
                    NudgeDefenders(map);
                    _nudgeTimerMs = NUDGE_INTERVAL_MS;
                }
                else
                {
                    _nudgeTimerMs -= diff;
                }

                if (CountAliveDefenders(map) == 0)
                {
                    FailInvasion(map, "|cFFFF3030[INVASION]|r The defenders were wiped out!");
                    return;
                }

                if (_phaseTimerMs <= diff)
                {
                    if (_phase == INVASION_WAVE_1)
                        BeginWave(map, INVASION_WAVE_2);
                    else if (_phase == INVASION_WAVE_2)
                        BeginWave(map, INVASION_WAVE_3);
                    else
                        StartBossWave(map);
                }
                else
                {
                    _phaseTimerMs -= diff;
                }

                return;
            }

            if (_phase == INVASION_WAVE_4_BOSS)
            {
                if (_nudgeTimerMs <= diff)
                {
                    NudgeInvaders(map);
                    NudgeDefenders(map);
                    _nudgeTimerMs = NUDGE_INTERVAL_MS;
                }
                else
                {
                    _nudgeTimerMs -= diff;
                }

                MaintainBossGuards(map);

                if (CountAliveDefenders(map) == 0)
                {
                    FailInvasion(map, "|cFFFF3030[INVASION]|r Zul'mar crushed the beach defense!");
                    return;
                }

                if (!_bossGuid.IsEmpty())
                {
                    Creature* boss = map->GetCreature(_bossGuid);
                    if (!boss || !boss->IsAlive())
                    {
                        EnterVictory(map);
                        return;
                    }
                }

                if (_phaseTimerMs <= diff)
                {
                    FailInvasion(map, "|cFFFF3030[INVASION]|r The invaders secured Seeping Shores.");
                    return;
                }

                _phaseTimerMs -= diff;
            }
        }

        void StartInvasion(Player* starter, Creature* horn, bool ignoreStartRange = false)
        {
            if (!starter || !horn)
                return;

            Map* map = horn->GetMap();
            if (!map || map->GetId() != MAP_GIANT_ISLES)
                return;

            if (_phase != INVASION_INACTIVE)
            {
                LOG_INFO("scripts.dc", "Giant Isles Invasion: manual trigger denied for {} (event already active, phase={})", starter->GetName(), static_cast<uint32>(_phase));
                ChatHandler(starter->GetSession()).SendNotification("An invasion is already in progress.");
                return;
            }

            LOG_INFO("scripts.dc", "Giant Isles Invasion: manual trigger request by {} (gm={}, ignoreRange={})", starter->GetName(), starter->IsGameMaster(), ignoreStartRange);

            std::string error;
            if (!ValidateStarter(starter, horn, ignoreStartRange, error))
            {
                LOG_INFO("scripts.dc", "Giant Isles Invasion: manual trigger validation failed for {}: {}", starter->GetName(), error);
                ChatHandler(starter->GetSession()).SendNotification(error.c_str());
                return;
            }

            if (!starter->IsGameMaster())
            {
                uint32 lastEnd = GetLastEndTimestamp();
                uint32 now = GetNowSeconds();
                if (lastEnd > 0 && now < (lastEnd + INVASION_COOLDOWN))
                {
                    uint32 remainSec = (lastEnd + INVASION_COOLDOWN) - now;
                    LOG_INFO("scripts.dc", "Giant Isles Invasion: manual trigger denied for {} due cooldown (remaining={} sec)", starter->GetName(), remainSec);
                    ChatHandler(starter->GetSession()).PSendSysMessage(
                        "The horn is silent for now. Cooldown remaining: %u min.",
                        remainSec / 60);
                    return;
                }
            }

            StartWarningPhase(map, horn, "manual-horn", starter->GetName());
        }

        void StopInvasion(Map* map, char const* reason = "cancelled")
        {
            if (!map)
                map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);

            if (_phase == INVASION_INACTIVE)
                return;

            LOG_INFO("scripts.dc", "Giant Isles Invasion: stop requested (reason={}, phase={})",
                reason ? reason : "none",
                static_cast<uint32>(_phase));

            std::string msg = "|cFFFF8000[INVASION]|r Event stopped";
            if (reason && *reason)
            {
                msg += ": ";
                msg += reason;
            }

            if (map)
                SendMapSystemMessage(map, msg.c_str());

            SetLastEndTimestamp();
            _phase = INVASION_FAILED;
            _phaseTimerMs = 1 * IN_MILLISECONDS;
        }

        void ForceAdvanceWave(Map* map)
        {
            if (!map)
                map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);

            if (!map)
                return;

            switch (_phase)
            {
                case INVASION_WARNING:
                    BeginWave(map, INVASION_WAVE_1);
                    break;
                case INVASION_WAVE_1:
                    BeginWave(map, INVASION_WAVE_2);
                    break;
                case INVASION_WAVE_2:
                    BeginWave(map, INVASION_WAVE_3);
                    break;
                case INVASION_WAVE_3:
                    StartBossWave(map);
                    break;
                case INVASION_WAVE_4_BOSS:
                    EnterVictory(map);
                    break;
                default:
                    break;
            }
        }

        void TrackPlayerKill(ObjectGuid playerGuid)
        {
            if (_phase == INVASION_INACTIVE)
                return;

            ++_killCount;
            _participantKills[playerGuid]++;

            if (sWorldState)
                sWorldState->setWorldState(WORLD_STATE_INVASION_KILLS, _killCount);
        }

        void RegisterSummonedInvader(Creature* creature)
        {
            if (!creature)
                return;

            uint8 lane = 0;
            float bestDistance = std::numeric_limits<float>::max();

            for (uint8 i = 0; i < InvaderSpawnPoints.size(); ++i)
            {
                float dist = creature->GetDistance(
                    InvaderSpawnPoints[i].x,
                    InvaderSpawnPoints[i].y,
                    InvaderSpawnPoints[i].z);

                if (dist < bestDistance)
                {
                    bestDistance = dist;
                    lane = i;
                }
            }

            RegisterInvader(creature, lane);
        }

        void MaintainBossGuards(Map* map)
        {
            if (!map)
                return;

            if (_phase != INVASION_WAVE_4_BOSS)
                return;

            if (_bossGuid.IsEmpty())
                return;

            Creature* boss = map->GetCreature(_bossGuid);
            if (!boss || !boss->IsAlive())
                return;

            uint32 aliveGuards = 0;
            for (ObjectGuid const& guid : _invaderGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (!c || !c->IsAlive())
                    continue;
                if (c->GetEntry() == NPC_ZANDALARI_HONOR_GUARD)
                    ++aliveGuards;
            }

            while (aliveGuards < 4)
            {
                constexpr float pi = 3.1415926535f;
                float angle = static_cast<float>(aliveGuards) * pi / 2.0f;
                Position p = boss->GetPosition();
                p.m_positionX += std::cos(angle) * 3.0f;
                p.m_positionY += std::sin(angle) * 3.0f;

                Creature* guard = map->SummonCreature(
                    NPC_ZANDALARI_HONOR_GUARD,
                    p,
                    nullptr,
                    SUMMON_LIFETIME_MS);

                if (!guard)
                    break;

                RegisterInvader(guard, 2);
                CommandInvader(guard, map, 2);
                ++aliveGuards;
            }
        }

        void NotifyBossKilled()
        {
            Map* map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);
            if (!map)
                return;

            if (_phase != INVASION_WAVE_4_BOSS)
                return;

            EnterVictory(map);
        }

        bool IsActive() const
        {
            return _phase != INVASION_INACTIVE;
        }

        uint32 GetNextAutoTriggerAtSec() const
        {
            return _nextAutoTriggerAtSec;
        }

        InvasionPhase GetCurrentPhase() const
        {
            return _phase;
        }

    private:
        InvasionPhase _phase = INVASION_INACTIVE;
        uint32 _phaseTimerMs = 0;
        uint32 _spawnTimerMs = 0;
        uint32 _nudgeTimerMs = 0;
        uint32 _chaosTimerMs = 0;
        uint32 _waveSpawnBudget = 0;
        uint32 _waveActiveCap = 0;
        uint32 _spawnedThisWave = 0;
        uint32 _killCount = 0;

        ObjectGuid _bossGuid;
        ObjectGuid _leaderGuid;

        std::vector<ObjectGuid> _invaderGuids;
        std::vector<ObjectGuid> _defenderGuids;
        std::map<ObjectGuid, uint8> _laneByInvader;
        std::map<ObjectGuid, uint32> _participantKills;
        std::array<uint8, 4> _lanePressure = {{ 1u, 1u, 1u, 1u }};
        uint32 _nextAutoTriggerAtSec = 0;

        void ScheduleNextAutoTrigger(char const* reason)
        {
            uint32 now = GetNowSeconds();
            uint32 delay = urand(AUTO_TRIGGER_MIN_DELAY_SEC, AUTO_TRIGGER_MAX_DELAY_SEC);
            _nextAutoTriggerAtSec = now + delay;

            LOG_INFO("scripts.dc", "Giant Isles Invasion [AUTO]: next trigger in {} min (reason={}, targetEpoch={})",
                delay / 60,
                reason ? reason : "n/a",
                _nextAutoTriggerAtSec);
        }

        Player* FindAutoStarter(Map* map) const
        {
            if (!map)
                return nullptr;

            Player* selected = nullptr;
            map->DoForAllPlayers([&](Player* player)
            {
                if (selected)
                    return;
                if (!player || !player->IsInWorld() || !player->IsAlive())
                    return;
                if (player->IsGameMaster())
                    return;
                if (player->GetMapId() != MAP_GIANT_ISLES)
                    return;

                selected = player;
            });

            return selected;
        }

        Creature* FindInvasionHorn(Map* map, Player* preferredSource) const
        {
            if (!map)
                return nullptr;

            if (preferredSource)
                if (Creature* horn = GetClosestCreatureWithEntry(preferredSource, NPC_INVASION_HORN, 1000.0f))
                    return horn;

            Creature* foundHorn = nullptr;
            map->DoForAllPlayers([&](Player* player)
            {
                if (foundHorn)
                    return;
                if (!player || !player->IsInWorld() || player->GetMapId() != MAP_GIANT_ISLES)
                    return;

                foundHorn = GetClosestCreatureWithEntry(player, NPC_INVASION_HORN, 1000.0f);
            });

            return foundHorn;
        }

        void StartWarningPhase(Map* map, Creature* horn, std::string const& triggerSource, std::string const& starterName)
        {
            if (!map || !horn)
                return;

            CleanupTrackedSummons(map);
            ResetRuntimeState();

            _phase = INVASION_WARNING;
            _phaseTimerMs = WARNING_DURATION_MS;
            _spawnTimerMs = 0;
            _nudgeTimerMs = NUDGE_INTERVAL_MS;
            _chaosTimerMs = urand(CHAOS_PULSE_MIN_MS, CHAOS_PULSE_MAX_MS);

            for (uint8& pressure : _lanePressure)
                pressure = urand(1u, 3u);

            if (sWorldState)
            {
                sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 1);
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 0);
                sWorldState->setWorldState(WORLD_STATE_INVASION_KILLS, 0);
            }

            SpawnDefenders(map);
            BindShipCommander(map, horn);

            SendMapSystemMessage(
                map,
                "|cFFFF8000[INVASION WARNING]|r Zandalari longboats hit the shore. "
                "War drums thunder across Seeping Shores!");

            LeaderAnnounce(0, map);

            map->DoForAllPlayers([](Player* player)
            {
                if (player && player->IsInWorld() && player->GetMapId() == MAP_GIANT_ISLES)
                    player->PlayDirectSound(6674);
            });

            LOG_INFO("scripts.dc", "Giant Isles Invasion: warning phase started (trigger={}, starter={}, defenders={}, nextAutoWas={})",
                triggerSource,
                starterName,
                _defenderGuids.size(),
                _nextAutoTriggerAtSec);
        }

        void HandleAutoTrigger(Map* map)
        {
            if (!map)
                return;

            if (_nextAutoTriggerAtSec == 0)
            {
                ScheduleNextAutoTrigger("auto-init");
                return;
            }

            uint32 now = GetNowSeconds();
            if (now < _nextAutoTriggerAtSec)
                return;

            Player* starter = FindAutoStarter(map);
            if (!starter)
            {
                _nextAutoTriggerAtSec = now + AUTO_TRIGGER_RETRY_NO_PLAYERS_SEC;
                LOG_DEBUG("scripts.dc", "Giant Isles Invasion [AUTO]: due but no eligible players online on map, retry in {} sec",
                    AUTO_TRIGGER_RETRY_NO_PLAYERS_SEC);
                return;
            }

            Creature* horn = FindInvasionHorn(map, starter);
            if (!horn)
            {
                _nextAutoTriggerAtSec = now + AUTO_TRIGGER_RETRY_NO_HORN_SEC;
                LOG_WARN("scripts.dc", "Giant Isles Invasion [AUTO]: due but no invasion horn {} found, retry in {} sec",
                    static_cast<uint32>(NPC_INVASION_HORN),
                    AUTO_TRIGGER_RETRY_NO_HORN_SEC);
                return;
            }

            LOG_INFO("scripts.dc", "Giant Isles Invasion [AUTO]: trigger fired for {} (guid={})",
                starter->GetName(),
                starter->GetGUID().ToString());

            StartWarningPhase(map, horn, "auto-timer", starter->GetName());
        }

        void ResetRuntimeState()
        {
            _phase = INVASION_INACTIVE;
            _phaseTimerMs = 0;
            _spawnTimerMs = 0;
            _nudgeTimerMs = 0;
            _chaosTimerMs = 0;
            _waveSpawnBudget = 0;
            _waveActiveCap = 0;
            _spawnedThisWave = 0;
            _killCount = 0;
            _bossGuid.Clear();
            _leaderGuid.Clear();
            _invaderGuids.clear();
            _defenderGuids.clear();
            _laneByInvader.clear();
            _participantKills.clear();
            _lanePressure = {{ 1u, 1u, 1u, 1u }};
            _nextAutoTriggerAtSec = 0;
        }

        void ResetWorldStates()
        {
            if (!sWorldState)
                return;

            sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 0);
            sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 0);
            sWorldState->setWorldState(WORLD_STATE_INVASION_KILLS, 0);
        }

        uint32 GetLastEndTimestamp() const
        {
            if (!sWorldState)
                return 0;

            return sWorldState->getWorldState(WORLD_STATE_INVASION_LAST_END);
        }

        void SetLastEndTimestamp()
        {
            if (!sWorldState)
                return;

            sWorldState->setWorldState(WORLD_STATE_INVASION_LAST_END, GetNowSeconds());
        }

        bool ValidateStarter(Player* starter, Creature* horn, bool ignoreRange, std::string& outError) const
        {
            outError.clear();

            if (!starter || !horn)
            {
                outError = "Internal error: missing starter or horn.";
                return false;
            }

            if (starter->GetMapId() != MAP_GIANT_ISLES)
            {
                outError = "You must be on Giant Isles to start the invasion.";
                return false;
            }

            if (!ignoreRange && !starter->IsWithinDist2d(horn, START_REQUIRED_RANGE_YARDS))
            {
                outError = "You must stand near the invasion horn.";
                return false;
            }

            Group* group = starter->GetGroup();
            if (!group)
                return true;

            if (group->GetMembersCount() > INVASION_MAX_GROUP_SIZE)
            {
                outError = "Group too large (maximum is 10).";
                return false;
            }

            for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
            {
                Player* member = itr->GetSource();
                if (!member || !member->IsInWorld() || member->GetMapId() != MAP_GIANT_ISLES)
                {
                    outError = "All group members must be present on Giant Isles.";
                    return false;
                }

                if (!ignoreRange && !member->IsWithinDist2d(horn, START_REQUIRED_RANGE_YARDS))
                {
                    std::ostringstream ss;
                    ss << member->GetName() << " is too far from the invasion horn.";
                    outError = ss.str();
                    return false;
                }
            }

            return true;
        }

        void BindShipCommander(Map* map, Creature* horn)
        {
            _leaderGuid.Clear();

            if (!map || !horn)
                return;

            Creature* leader = GetClosestCreatureWithEntry(
                horn,
                NPC_ZANDALARI_INVASION_LEADER,
                600.0f);

            if (!leader)
            {
                LOG_WARN("scripts.dc", "Giant Isles Invasion: leader {} not found on ship", static_cast<uint32>(NPC_ZANDALARI_INVASION_LEADER));
                return;
            }

            _leaderGuid = leader->GetGUID();
            leader->SetReactState(REACT_PASSIVE);
            leader->SetFlag(UNIT_FIELD_FLAGS,
                UNIT_FLAG_NON_ATTACKABLE |
                UNIT_FLAG_IMMUNE_TO_PC |
                UNIT_FLAG_IMMUNE_TO_NPC);
            leader->GetMotionMaster()->MoveIdle();

            if (npc_invasion_leader::npc_invasion_leaderAI* ai =
                CAST_AI(npc_invasion_leader::npc_invasion_leaderAI, leader->AI()))
            {
                ai->Reset();
            }
        }

        void LeaderAnnounce(uint8 stage, Map* map)
        {
            if (!map)
                return;

            if (_leaderGuid.IsEmpty())
                return;

            Creature* leader = map->GetCreature(_leaderGuid);
            if (!leader || !leader->IsAlive())
                return;

            if (npc_invasion_leader::npc_invasion_leaderAI* ai =
                CAST_AI(npc_invasion_leader::npc_invasion_leaderAI, leader->AI()))
            {
                ai->DoAnnouncement(stage);
            }
        }

        uint8 GetPublicWave() const
        {
            switch (_phase)
            {
                case INVASION_WAVE_1:
                    return 1;
                case INVASION_WAVE_2:
                    return 2;
                case INVASION_WAVE_3:
                    return 3;
                case INVASION_WAVE_4_BOSS:
                    return 4;
                default:
                    return 0;
            }
        }

        uint32 CountAliveDefenders(Map* map) const
        {
            if (!map)
                return 0;

            uint32 alive = 0;
            for (ObjectGuid const& guid : _defenderGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (c && c->IsAlive())
                    ++alive;
            }

            return alive;
        }

        uint32 CountAliveInvaders(Map* map) const
        {
            if (!map)
                return 0;

            uint32 alive = 0;
            for (ObjectGuid const& guid : _invaderGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (c && c->IsAlive())
                    ++alive;
            }

            return alive;
        }

        uint32 CountNearbyPlayers(Map* map) const
        {
            if (!map)
                return 1;

            uint32 nearby = 0;
            uint32 fallbackAlive = 0;

            map->DoForAllPlayers([&](Player* player)
            {
                if (!player || !player->IsInWorld() || !player->IsAlive() || player->IsGameMaster())
                    return;

                ++fallbackAlive;

                float dist = player->GetDistance2d(FrontlineAnchor.x, FrontlineAnchor.y);
                if (dist <= 260.0f)
                    ++nearby;
            });

            uint32 effective = nearby > 0 ? nearby : fallbackAlive;
            effective = std::clamp<uint32>(effective, 1u, INVASION_MAX_GROUP_SIZE);
            return effective;
        }

        uint32 ComputeWaveActiveCap(Map* map, InvasionPhase phase) const
        {
            uint32 n = CountNearbyPlayers(map);

            switch (phase)
            {
                case INVASION_WAVE_1:
                    return std::clamp<uint32>(6u + n, 8u, 16u);
                case INVASION_WAVE_2:
                    return std::clamp<uint32>(8u + n, 10u, 20u);
                case INVASION_WAVE_3:
                    return std::clamp<uint32>(10u + n, 12u, 24u);
                default:
                    return 0u;
            }
        }

        uint32 ComputeWaveSpawnBudget(Map* map, InvasionPhase phase) const
        {
            uint32 n = CountNearbyPlayers(map);

            switch (phase)
            {
                case INVASION_WAVE_1:
                    return std::clamp<uint32>(16u + (2u * n), 18u, 40u);
                case INVASION_WAVE_2:
                    return std::clamp<uint32>(22u + (2u * n), 24u, 52u);
                case INVASION_WAVE_3:
                    return std::clamp<uint32>(28u + (2u * n), 32u, 64u);
                default:
                    return 0u;
            }
        }

        uint32 GetWaveSpawnIntervalMs() const
        {
            switch (_phase)
            {
                case INVASION_WAVE_1:
                    return WAVE_1_SPAWN_INTERVAL_MS;
                case INVASION_WAVE_2:
                    return WAVE_2_SPAWN_INTERVAL_MS;
                case INVASION_WAVE_3:
                    return WAVE_3_SPAWN_INTERVAL_MS;
                default:
                    return 0;
            }
        }

        uint32 PickWaveEntry() const
        {
            switch (_phase)
            {
                case INVASION_WAVE_1:
                {
                    static std::array<uint32, 3> const wave1 =
                    {{
                        NPC_ZANDALARI_INVADER,
                        NPC_ZANDALARI_SCOUT,
                        NPC_ZANDALARI_SPEARMAN,
                    }};
                    return wave1[urand(0u, static_cast<uint32>(wave1.size() - 1))];
                }

                case INVASION_WAVE_2:
                {
                    static std::array<uint32, 3> const wave2 =
                    {{
                        NPC_ZANDALARI_WARRIOR,
                        NPC_ZANDALARI_BERSERKER,
                        NPC_ZANDALARI_SHADOW_HUNTER,
                    }};
                    return wave2[urand(0u, static_cast<uint32>(wave2.size() - 1))];
                }

                case INVASION_WAVE_3:
                {
                    uint32 roll = urand(0u, 99u);
                    if (roll < 35)
                        return NPC_ZANDALARI_BLOOD_GUARD;
                    if (roll < 70)
                        return NPC_ZANDALARI_WITCH_DOCTOR;
                    return NPC_ZANDALARI_BEAST_TAMER;
                }

                default:
                    return NPC_ZANDALARI_INVADER;
            }
        }

        uint8 ChooseLaneByPressure() const
        {
            uint32 total = 0;
            for (uint8 p : _lanePressure)
                total += p;

            if (total == 0)
                return static_cast<uint8>(urand(0u, 3u));

            uint32 pick = urand(1u, total);
            uint32 running = 0;

            for (uint8 i = 0; i < _lanePressure.size(); ++i)
            {
                running += _lanePressure[i];
                if (pick <= running)
                    return i;
            }

            return 0;
        }

        void RebalanceLanePressure()
        {
            for (uint8& p : _lanePressure)
            {
                if (p > 1)
                    --p;
            }

            uint8 pushLane = static_cast<uint8>(urand(0u, 3u));
            _lanePressure[pushLane] = std::min<uint8>(6u, static_cast<uint8>(_lanePressure[pushLane] + 2u));

            if (urand(0u, 1u) == 1u)
            {
                uint8 secondLane = static_cast<uint8>(urand(0u, 3u));
                _lanePressure[secondLane] = std::min<uint8>(6u, static_cast<uint8>(_lanePressure[secondLane] + 1u));
            }
        }

        void SpawnDefenders(Map* map)
        {
            if (!map)
                return;

            std::array<uint32, 5> const entries =
            {{
                NPC_BEAST_HUNTER_WARLORD,
                NPC_BEAST_HUNTER_TRAPPER,
                NPC_BEAST_HUNTER,
                NPC_BEAST_HUNTER_VETERAN,
                NPC_BEAST_HUNTER,
            }};

            for (uint8 i = 0; i < DefenderSpawnPoints.size(); ++i)
            {
                InvasionSpawnPoint const& sp = DefenderSpawnPoints[i];
                Position p(sp.x, sp.y, sp.z, sp.o);

                Creature* defender = map->SummonCreature(entries[i], p, nullptr, SUMMON_LIFETIME_MS);
                if (!defender)
                {
                    LOG_WARN("scripts.dc", "Giant Isles Invasion: failed to spawn defender entry {}", entries[i]);
                    continue;
                }

                defender->SetReactState(REACT_AGGRESSIVE);
                defender->SetFaction(DEFENDER_FACTION_HORDE);
                defender->RemoveUnitFlag(UNIT_FLAG_DISABLE_MOVE | UNIT_FLAG_PACIFIED);
                defender->ClearUnitState(UNIT_STATE_ROOT | UNIT_STATE_STUNNED);
                _defenderGuids.push_back(defender->GetGUID());

                if (i < LaneObjectives.size())
                {
                    InvasionSpawnPoint const& obj = LaneObjectives[i];
                    defender->GetMotionMaster()->MovePoint(50 + i, obj.x, obj.y, obj.z);
                }

                CommandDefender(defender, map);
            }
        }

        void SpawnDefenderReinforcement(Map* map)
        {
            if (!map)
                return;

            InvasionSpawnPoint const& rear = DefenderSpawnPoints[4];

            Position p1(rear.x - 2.0f, rear.y - 1.0f, rear.z, rear.o);
            Position p2(rear.x + 2.0f, rear.y + 1.0f, rear.z, rear.o);

            Creature* ranger = map->SummonCreature(
                NPC_BEAST_HUNTER_TRAPPER,
                p1,
                nullptr,
                SUMMON_LIFETIME_MS);

            Creature* shaman = map->SummonCreature(
                NPC_BEAST_HUNTER_VETERAN,
                p2,
                nullptr,
                SUMMON_LIFETIME_MS);

            if (ranger)
            {
                ranger->SetReactState(REACT_AGGRESSIVE);
                ranger->SetFaction(DEFENDER_FACTION_HORDE);
                ranger->RemoveUnitFlag(UNIT_FLAG_DISABLE_MOVE | UNIT_FLAG_PACIFIED);
                ranger->ClearUnitState(UNIT_STATE_ROOT | UNIT_STATE_STUNNED);
                _defenderGuids.push_back(ranger->GetGUID());
                CommandDefender(ranger, map);
            }

            if (shaman)
            {
                shaman->SetReactState(REACT_AGGRESSIVE);
                shaman->SetFaction(DEFENDER_FACTION_HORDE);
                shaman->RemoveUnitFlag(UNIT_FLAG_DISABLE_MOVE | UNIT_FLAG_PACIFIED);
                shaman->ClearUnitState(UNIT_STATE_ROOT | UNIT_STATE_STUNNED);
                _defenderGuids.push_back(shaman->GetGUID());
                CommandDefender(shaman, map);
            }
        }

        bool SpawnInvader(Map* map, uint8 lane, uint32 entry)
        {
            if (!map)
                return false;

            lane %= static_cast<uint8>(InvaderSpawnPoints.size());
            InvasionSpawnPoint const& sp = InvaderSpawnPoints[lane];
            Position p(sp.x, sp.y, sp.z, sp.o);

            Creature* invader = map->SummonCreature(entry, p, nullptr, SUMMON_LIFETIME_MS);
            if (!invader)
            {
                LOG_WARN("scripts.dc", "Giant Isles Invasion: failed to spawn invader entry {} on lane {}", entry, lane);
                return false;
            }

            RegisterInvader(invader, lane);
            CommandInvader(invader, map, lane);
            return true;
        }

        void RegisterInvader(Creature* creature, uint8 lane)
        {
            if (!creature)
                return;

            ObjectGuid guid = creature->GetGUID();
            if (std::find(_invaderGuids.begin(), _invaderGuids.end(), guid) == _invaderGuids.end())
                _invaderGuids.push_back(guid);

            _laneByInvader[guid] = lane;

            // Keep invaders on explicit invasion faction (never Horde-side guards).
            creature->SetFaction(INVADER_FACTION);
            creature->SetReactState(REACT_AGGRESSIVE);
        }

        uint8 GetLaneForInvader(ObjectGuid guid) const
        {
            auto itr = _laneByInvader.find(guid);
            if (itr == _laneByInvader.end())
                return 0;
            return itr->second;
        }

        Unit* SelectInvaderTarget(Creature* invader, Map* map) const
        {
            if (!invader || !map)
                return nullptr;

            Creature* bestDefender = nullptr;
            float bestDefenderDist = 180.0f;

            for (ObjectGuid const& guid : _defenderGuids)
            {
                Creature* defender = map->GetCreature(guid);
                if (!defender || !defender->IsAlive())
                    continue;

                float dist = invader->GetDistance(defender);
                if (dist < bestDefenderDist)
                {
                    bestDefenderDist = dist;
                    bestDefender = defender;
                }
            }

            if (bestDefender)
                return bestDefender;

            Player* bestPlayer = nullptr;
            float bestPlayerDist = 90.0f;

            map->DoForAllPlayers([&](Player* player)
            {
                if (!player || !player->IsInWorld() || !player->IsAlive() || player->IsGameMaster())
                    return;

                if (player->GetDistance2d(FrontlineAnchor.x, FrontlineAnchor.y) > 280.0f)
                    return;

                float dist = invader->GetDistance(player);
                if (dist < bestPlayerDist)
                {
                    bestPlayerDist = dist;
                    bestPlayer = player;
                }
            });

            return bestPlayer;
        }

        Unit* SelectDefenderTarget(Creature* defender, Map* map) const
        {
            if (!defender || !map)
                return nullptr;

            Creature* bestInvader = nullptr;
            float bestInvaderDist = 180.0f;

            for (ObjectGuid const& guid : _invaderGuids)
            {
                Creature* invader = map->GetCreature(guid);
                if (!invader || !invader->IsAlive())
                    continue;

                float dist = defender->GetDistance(invader);
                if (dist < bestInvaderDist)
                {
                    bestInvaderDist = dist;
                    bestInvader = invader;
                }
            }

            return bestInvader;
        }

        void CommandInvader(Creature* creature, Map* map, uint8 lane)
        {
            if (!creature || !map || !creature->IsAlive())
                return;

            creature->RemoveUnitFlag(UNIT_FLAG_DISABLE_MOVE | UNIT_FLAG_PACIFIED);
            creature->ClearUnitState(UNIT_STATE_ROOT | UNIT_STATE_STUNNED);
            creature->SetWalk(false);
            creature->SetFaction(DEFENDER_FACTION_HORDE);
            creature->SetReactState(REACT_AGGRESSIVE);

            if (Unit* target = SelectInvaderTarget(creature, map))
            {
                ForceStartCombat(creature, target);
                return;
            }

            InvasionSpawnPoint const& objective = LaneObjectives[lane % LaneObjectives.size()];
            creature->GetMotionMaster()->Clear();
            creature->GetMotionMaster()->MovePoint(100 + lane, objective.x, objective.y, objective.z);
        }

        void CommandDefender(Creature* creature, Map* map)
        {
            if (!creature || !map || !creature->IsAlive())
                return;

            creature->RemoveUnitFlag(UNIT_FLAG_DISABLE_MOVE | UNIT_FLAG_PACIFIED);
            creature->ClearUnitState(UNIT_STATE_ROOT | UNIT_STATE_STUNNED);
            creature->SetWalk(false);
            creature->SetReactState(REACT_AGGRESSIVE);

            if (Unit* target = SelectDefenderTarget(creature, map))
            {
                ForceStartCombat(creature, target);
                return;
            }

            // Keep defenders anchored near objectives when no invaders are in range.
            uint8 bestIndex = 0;
            float bestDist = std::numeric_limits<float>::max();

            for (uint8 i = 0; i < LaneObjectives.size(); ++i)
            {
                InvasionSpawnPoint const& obj = LaneObjectives[i];
                float dist = creature->GetDistance(obj.x, obj.y, obj.z);

                if (dist < bestDist)
                {
                    bestDist = dist;
                    bestIndex = i;
                }
            }

            InvasionSpawnPoint const& objective = LaneObjectives[bestIndex];
            creature->GetMotionMaster()->Clear();
            creature->GetMotionMaster()->MovePoint(150 + bestIndex, objective.x, objective.y, objective.z);
        }

        void NudgeInvaders(Map* map)
        {
            if (!map)
                return;

            _invaderGuids.erase(
                std::remove_if(_invaderGuids.begin(), _invaderGuids.end(),
                    [&](ObjectGuid const& guid)
                    {
                        Creature* c = map->GetCreature(guid);
                        if (!c)
                            return true;
                        return !c->IsAlive();
                    }),
                _invaderGuids.end());

            for (ObjectGuid const& guid : _invaderGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (!c || !c->IsAlive())
                    continue;

                if (c->IsInCombat())
                    continue;

                CommandInvader(c, map, GetLaneForInvader(guid));
            }
        }

        void NudgeDefenders(Map* map)
        {
            if (!map)
                return;

            _defenderGuids.erase(
                std::remove_if(_defenderGuids.begin(), _defenderGuids.end(),
                    [&](ObjectGuid const& guid)
                    {
                        Creature* c = map->GetCreature(guid);
                        if (!c)
                            return true;
                        return !c->IsAlive();
                    }),
                _defenderGuids.end());

            for (ObjectGuid const& guid : _defenderGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (!c || !c->IsAlive())
                    continue;

                if (c->IsInCombat())
                    continue;

                CommandDefender(c, map);
            }
        }

        void SpawnWaveTick(Map* map)
        {
            if (!map)
                return;

            if (!(_phase == INVASION_WAVE_1 || _phase == INVASION_WAVE_2 || _phase == INVASION_WAVE_3))
                return;

            if (_spawnedThisWave >= _waveSpawnBudget)
                return;

            uint32 alive = CountAliveInvaders(map);
            if (alive >= _waveActiveCap)
                return;

            uint32 remainingBudget = _waveSpawnBudget - _spawnedThisWave;
            uint32 availableSlots = _waveActiveCap - alive;
            uint32 maxPerTick = (_phase == INVASION_WAVE_3) ? 3u : 2u;

            uint32 toSpawn = std::min<uint32>(remainingBudget, availableSlots);
            toSpawn = std::min<uint32>(toSpawn, maxPerTick);

            if (toSpawn > 0)
            {
                LOG_DEBUG("scripts.dc", "Giant Isles Invasion: wave tick phase={} alive={} spawnNow={} spawnedThisWave={}/{} cap={}",
                    static_cast<uint32>(_phase),
                    alive,
                    toSpawn,
                    _spawnedThisWave,
                    _waveSpawnBudget,
                    _waveActiveCap);
            }

            for (uint32 i = 0; i < toSpawn; ++i)
            {
                uint8 lane = ChooseLaneByPressure();
                uint32 entry = PickWaveEntry();

                if (SpawnInvader(map, lane, entry))
                {
                    ++_spawnedThisWave;
                    _lanePressure[lane] = std::min<uint8>(6u, static_cast<uint8>(_lanePressure[lane] + 1u));
                }
            }
        }

        void RunChaosPulse(Map* map)
        {
            if (!map)
                return;

            if (!(_phase == INVASION_WAVE_2 || _phase == INVASION_WAVE_3))
                return;

            RebalanceLanePressure();

            uint32 roll = urand(0u, 2u);
            if (roll == 0)
            {
                uint8 lane = ChooseLaneByPressure();
                LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse flank (phase={}, lane={})", static_cast<uint32>(_phase), lane);
                SendMapSystemMessage(
                    map,
                    "|cFFFF8000[INVASION]|r A flanking longboat lands and new raiders surge in!");

                SpawnInvader(map, lane, PickWaveEntry());
                SpawnInvader(map, lane, PickWaveEntry());
            }
            else if (roll == 1)
            {
                LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse defender reinforcements (phase={})", static_cast<uint32>(_phase));
                SendMapSystemMessage(
                    map,
                    "|cFF40FF40[DEFENDERS]|r Expedition reinforcements rush down from the camp!");
                SpawnDefenderReinforcement(map);
            }
            else
            {
                uint8 lane = ChooseLaneByPressure();
                LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse war-drum surge (phase={}, lane={})", static_cast<uint32>(_phase), lane);
                SendMapSystemMessage(
                    map,
                    "|cFFFF8000[INVASION]|r War drums intensify. The assault grows more chaotic!");

                if (_phase == INVASION_WAVE_2)
                {
                    SpawnInvader(map, lane, NPC_ZANDALARI_BERSERKER);
                    SpawnInvader(map, lane, NPC_ZANDALARI_SHADOW_HUNTER);
                }
                else
                {
                    SpawnInvader(map, lane, NPC_ZANDALARI_BLOOD_GUARD);
                    SpawnInvader(map, lane, NPC_ZANDALARI_WITCH_DOCTOR);
                }
            }

            _chaosTimerMs = urand(CHAOS_PULSE_MIN_MS, CHAOS_PULSE_MAX_MS);
        }

        void BeginWave(Map* map, InvasionPhase phase)
        {
            if (!map)
                return;

            _phase = phase;
            _spawnedThisWave = 0;

            switch (phase)
            {
                case INVASION_WAVE_1:
                    _phaseTimerMs = WAVE_1_DURATION_MS;
                    SendMapSystemMessage(map, "|cFFFF8000[WAVE 1]|r Zandalari scouts storm the beach!");
                    LeaderAnnounce(1, map);
                    break;
                case INVASION_WAVE_2:
                    _phaseTimerMs = WAVE_2_DURATION_MS;
                    SendMapSystemMessage(map, "|cFFFF6000[WAVE 2]|r Warriors and berserkers crash into the defense line!");
                    LeaderAnnounce(2, map);
                    break;
                case INVASION_WAVE_3:
                    _phaseTimerMs = WAVE_3_DURATION_MS;
                    SendMapSystemMessage(map, "|cFFFF4000[WAVE 3]|r Elite blood guard and witch doctors unleash chaos!");
                    LeaderAnnounce(3, map);
                    break;
                default:
                    return;
            }

            _waveActiveCap = ComputeWaveActiveCap(map, phase);
            _waveSpawnBudget = ComputeWaveSpawnBudget(map, phase);

            LOG_INFO("scripts.dc", "Giant Isles Invasion: entering wave {} (cap={}, budget={}, nearbyPlayers={})",
                static_cast<uint32>(GetPublicWave()),
                _waveActiveCap,
                _waveSpawnBudget,
                CountNearbyPlayers(map));

            _spawnTimerMs = 1000;
            _nudgeTimerMs = NUDGE_INTERVAL_MS;
            _chaosTimerMs = urand(CHAOS_PULSE_MIN_MS, CHAOS_PULSE_MAX_MS);

            if (sWorldState)
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, GetPublicWave());

            // Immediate opening pressure.
            SpawnWaveTick(map);
            SpawnWaveTick(map);
        }

        void StartBossWave(Map* map)
        {
            if (!map)
                return;

            LOG_INFO("scripts.dc", "Giant Isles Invasion: transitioning to boss wave");

            _phase = INVASION_WAVE_4_BOSS;
            _phaseTimerMs = WAVE_4_DURATION_MS;
            _spawnTimerMs = 0;
            _nudgeTimerMs = NUDGE_INTERVAL_MS;
            _chaosTimerMs = 0;
            _waveActiveCap = 0;
            _waveSpawnBudget = 0;
            _spawnedThisWave = 0;

            if (sWorldState)
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 4);

            SendMapSystemMessage(
                map,
                "|cFFFF0000[BOSS WAVE]|r Warlord Zul'mar lands with an honor guard! Hold the beach!");
            LeaderAnnounce(4, map);

            for (ObjectGuid const& guid : _invaderGuids)
            {
                if (Creature* c = map->GetCreature(guid))
                    c->DespawnOrUnsummon(1s);
            }
            _invaderGuids.clear();
            _laneByInvader.clear();
            _bossGuid.Clear();

            Position bossPos(
                InvaderSpawnPoints[2].x,
                InvaderSpawnPoints[2].y,
                InvaderSpawnPoints[2].z,
                InvaderSpawnPoints[2].o);

            Creature* boss = map->SummonCreature(
                NPC_WARLORD_ZULMAR,
                bossPos,
                nullptr,
                SUMMON_LIFETIME_MS);

            if (!boss)
            {
                FailInvasion(map, "|cFFFF3030[INVASION]|r Zul'mar failed to deploy. Event aborted.");
                return;
            }

            RegisterInvader(boss, 2);
            _bossGuid = boss->GetGUID();
            CommandInvader(boss, map, 2);

            std::array<std::pair<float, float>, 4> const guardOffsets =
            {{
                { -2.5f, -2.0f },
                {  2.5f, -2.0f },
                { -2.5f,  2.0f },
                {  2.5f,  2.0f },
            }};

            for (auto const& offset : guardOffsets)
            {
                Position gp = bossPos;
                gp.m_positionX += offset.first;
                gp.m_positionY += offset.second;

                Creature* guard = map->SummonCreature(
                    NPC_ZANDALARI_HONOR_GUARD,
                    gp,
                    nullptr,
                    SUMMON_LIFETIME_MS);

                if (!guard)
                    continue;

                RegisterInvader(guard, 2);
                CommandInvader(guard, map, 2);
            }
        }

        void EnterVictory(Map* map)
        {
            if (!map)
                return;

            if (_phase == INVASION_VICTORY || _phase == INVASION_FAILED)
                return;

            _phase = INVASION_VICTORY;
            _phaseTimerMs = RESULT_DURATION_MS;
            SetLastEndTimestamp();

            LOG_INFO("scripts.dc", "Giant Isles Invasion: victory state entered (kills={})", _killCount);

            if (sWorldState)
            {
                sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 0);
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 0);
                sWorldState->setWorldState(WORLD_STATE_INVASION_KILLS, _killCount + 10);
            }

            SendMapSystemMessage(
                map,
                "|cFF40FF40[VICTORY]|r Warlord Zul'mar is defeated. Seeping Shores holds!"
            );
            LeaderAnnounce(5, map);
            RewardParticipants(map);
        }

        void FailInvasion(Map* map, char const* reasonText)
        {
            if (!map)
                return;

            if (_phase == INVASION_VICTORY || _phase == INVASION_FAILED)
                return;

            _phase = INVASION_FAILED;
            _phaseTimerMs = RESULT_DURATION_MS;
            SetLastEndTimestamp();

            LOG_INFO("scripts.dc", "Giant Isles Invasion: failure state entered (reason={})", reasonText ? reasonText : "unknown");

            if (sWorldState)
            {
                sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 0);
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 0);
            }

            SendMapSystemMessage(map, reasonText ? reasonText : "|cFFFF3030[INVASION]|r Defense failed.");
            LeaderAnnounce(6, map);
        }

        void RewardParticipants(Map* map)
        {
            if (!map)
                return;

            map->DoForAllPlayers([&](Player* player)
            {
                if (!player || !player->IsInWorld() || !player->GetSession() || !player->IsAlive())
                    return;

                if (player->GetMapId() != MAP_GIANT_ISLES)
                    return;

                if (player->GetDistance2d(FrontlineAnchor.x, FrontlineAnchor.y) > FRONTLINE_REWARD_RADIUS)
                    return;

                uint32 personalKills = 0;
                auto itr = _participantKills.find(player->GetGUID());
                if (itr != _participantKills.end())
                    personalKills = itr->second;

                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Invasion]|r Beach secured. Personal contribution: %u kills.",
                    personalKills);
            });
        }

        void CleanupTrackedSummons(Map* map)
        {
            if (!map)
            {
                _invaderGuids.clear();
                _defenderGuids.clear();
                _laneByInvader.clear();
                _bossGuid.Clear();
                return;
            }

            for (ObjectGuid const& guid : _invaderGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (c)
                    c->DespawnOrUnsummon(1s);
            }

            for (ObjectGuid const& guid : _defenderGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (c)
                    c->DespawnOrUnsummon(1s);
            }

            _invaderGuids.clear();
            _defenderGuids.clear();
            _laneByInvader.clear();
            _bossGuid.Clear();
        }

        void FinalizeEvent(Map* map)
        {
            CleanupTrackedSummons(map);
            ResetRuntimeState();
            ResetWorldStates();
            ScheduleNextAutoTrigger("event-finalized");
            LOG_INFO("scripts.dc", "Giant Isles Invasion: event finalized and auto-trigger rescheduled");
        }
    };

    class npc_invasion_horn : public CreatureScript
    {
    public:
        npc_invasion_horn() : CreatureScript("npc_invasion_horn") { }

        struct npc_invasion_hornAI : public ScriptedAI
        {
            npc_invasion_hornAI(Creature* creature) : ScriptedAI(creature) { }
        };

        bool OnGossipHello(Player* player, Creature* creature) override
        {
            if (!player || !creature)
                return false;

            bool active = sGiantIslesInvasion && sGiantIslesInvasion->IsActive();
            bool gm = player->IsGameMaster();

            if (!active)
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Sound the invasion horn", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
            else if (!gm)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "The invasion is already underway.", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "What is happening on this beach?", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);

            if (gm)
            {
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "[GM] Force start invasion", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 100);
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "[GM] Advance to next wave", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 101);
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "[GM] Stop invasion", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 102);
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "[GM] Show next auto-trigger time", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 103);
            }

            SendGossipMenuFor(player, 400325, creature->GetGUID());
            return true;
        }

        bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
        {
            (void)sender;

            if (!player || !creature)
                return false;

            ClearGossipMenuFor(player);
            CloseGossipMenuFor(player);

            if (!sGiantIslesInvasion)
            {
                ChatHandler(player->GetSession()).SendNotification("Invasion script is not loaded.");
                return true;
            }

            switch (action)
            {
                case GOSSIP_ACTION_INFO_DEF + 1:
                    sGiantIslesInvasion->StartInvasion(player, creature, false);
                    break;

                case GOSSIP_ACTION_INFO_DEF + 2:
                    ChatHandler(player->GetSession()).SendNotification("The invasion is already active.");
                    break;

                case GOSSIP_ACTION_INFO_DEF + 3:
                    player->GetSession()->SendAreaTriggerMessage(
                        "Zandalari raiders are unloading weapons and beasts at Seeping Shores. "
                        "Defend the beach and slay Warlord Zul'mar.");
                    break;

                case GOSSIP_ACTION_INFO_DEF + 100:
                    if (player->IsGameMaster())
                        sGiantIslesInvasion->StartInvasion(player, creature, true);
                    break;

                case GOSSIP_ACTION_INFO_DEF + 101:
                    if (player->IsGameMaster())
                        sGiantIslesInvasion->ForceAdvanceWave(creature->GetMap());
                    break;

                case GOSSIP_ACTION_INFO_DEF + 102:
                    if (player->IsGameMaster())
                        sGiantIslesInvasion->StopInvasion(creature->GetMap(), "stopped by GM");
                    break;

                case GOSSIP_ACTION_INFO_DEF + 103:
                    if (player->IsGameMaster())
                    {
                        uint32 now = GetNowSeconds();
                        uint32 next = sGiantIslesInvasion->GetNextAutoTriggerAtSec();

                        std::ostringstream ss;
                        ss << "[GM][Invasion Auto] nowEpoch=" << now
                           << " active=" << (sGiantIslesInvasion->IsActive() ? "true" : "false");

                        if (next == 0)
                        {
                            ss << " next=unscheduled";
                        }
                        else if (next <= now)
                        {
                            ss << " nextEpoch=" << next << " (due now)";
                        }
                        else
                        {
                            uint32 remainSec = next - now;
                            ss << " nextEpoch=" << next
                               << " (in " << (remainSec / 60) << "m " << (remainSec % 60) << "s)";
                        }

                        ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
                        LOG_INFO("scripts.dc", "Giant Isles Invasion [AUTO]: GM {} queried timer (now={}, next={}, active={})",
                            player->GetName(),
                            now,
                            next,
                            sGiantIslesInvasion->IsActive());
                    }
                    break;

                default:
                    break;
            }

            return true;
        }

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new npc_invasion_hornAI(creature);
        }
    };

    static void GI_TrackPlayerKill(ObjectGuid playerGuid)
    {
        if (sGiantIslesInvasion)
            sGiantIslesInvasion->TrackPlayerKill(playerGuid);
    }

    static void GI_RegisterSummonedInvader(Creature* creature)
    {
        if (sGiantIslesInvasion)
            sGiantIslesInvasion->RegisterSummonedInvader(creature);
    }

    static void GI_MaintainBossGuards(Map* map)
    {
        if (sGiantIslesInvasion)
            sGiantIslesInvasion->MaintainBossGuards(map);
    }

    static void GI_NotifyBossDeath()
    {
        if (sGiantIslesInvasion)
            sGiantIslesInvasion->NotifyBossKilled();
    }

    static bool GI_IsInvasionActive()
    {
        return sGiantIslesInvasion && sGiantIslesInvasion->IsActive();
    }

}

void AddSC_giant_isles_invasion()
{
    new npc_invasion_horn();
    new npc_invasion_mob();
    new npc_invasion_leader();
    new npc_invasion_commander();
    new giant_isles_invasion();

    LOG_INFO("scripts.dc", "Giant Isles Invasion: deterministic rewrite loaded");
}
