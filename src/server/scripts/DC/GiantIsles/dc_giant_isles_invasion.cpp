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
#include "Timer.h"
#include "Map.h"
#include "MapMgr.h"
#include "ObjectAccessor.h"
#include "Chat.h"
#include "Log.h"
#include "Random.h"
#include "World.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"

#include "dc_giant_isles_invasion_internal.h"
#include "../AddonExtension/dc_addon_namespace.h"

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
    // Shared NPC entry ids and factions live in the internal header so the NPC
    // AIs (dc_giant_isles_invasion_npcs.cpp) and this orchestrator agree.
    using namespace DCGiantIsles;

    enum InvasionData
    {
        MAP_GIANT_ISLES                 = 1405,
        AREA_SEEPING_SHORES             = 5010,

        // World states
        WORLD_STATE_INVASION_ACTIVE     = 20000,
        WORLD_STATE_INVASION_WAVE       = 20001,
        WORLD_STATE_INVASION_KILLS      = 20002,
        WORLD_STATE_INVASION_LAST_END   = 20010,
        // Persistent campaign progress: how deep a foothold the Zandalari hold.
        // Losses push it up (fiercer next assault); victories push it back down.
        WORLD_STATE_INVASION_CAMPAIGN   = 20011,

        // Rules
        INVASION_COOLDOWN               = 2 * HOUR,
        INVASION_MAX_GROUP_SIZE         = 10,
        INVASION_CAMPAIGN_MAX_FOOTHOLD  = 5,
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
    // How often the live invasion state is pushed to the DC-InfoBar Events feed
    // while the event is running (also re-syncs anyone who just logged in).
    constexpr uint32 EVENT_BROADCAST_INTERVAL_MS = 10000;
    constexpr uint32 SUMMON_LIFETIME_MS = 45 * MINUTE * IN_MILLISECONDS;

    constexpr float START_REQUIRED_RANGE_YARDS = 50.0f;
    constexpr float FRONTLINE_REWARD_RADIUS = 320.0f;

    // Loa ritual objective (wave 3): the witch doctors raise an effigy of the
    // Loa and channel it. The defenders must destroy the effigy before the
    // timer runs out; otherwise the Loa answers and every invader is empowered
    // with primal fury for the rest of the assault.
    constexpr uint32 LOA_RITUAL_DURATION_MS = 75 * IN_MILLISECONDS;
    constexpr uint32 LOA_BUFF_PULSE_MS = 8000;
    constexpr uint32 SPELL_LOA_FURY = 8599; // Enrage: visible primal empowerment

    // Lane objective: each landing plants a war standard. Destroy it to scuttle
    // that longboat and cut off the lane's reinforcements for the rest of the
    // assault. Polled on this cadence so a kill is noticed promptly.
    constexpr uint32 STANDARD_CHECK_INTERVAL_MS = 2000;

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

    // Mid-beach contested ground (between the invader landing and the defender
    // line), so reaching the Loa effigy means pushing into the fight.
    InvasionSpawnPoint const LoaRitualPos =
        { 5794.8f, 1230.3f, 7.9f, 4.95f };

    class giant_isles_invasion;
    static giant_isles_invasion* sGiantIslesInvasion = nullptr;

    static uint32 GetNowSeconds()
    {
        return static_cast<uint32>(GameTime::GetGameTime().count());
    }

    static std::string FormatEpochTimestamp(uint32 epoch)
    {
        if (epoch == 0)
            return "unscheduled";

        return Acore::Time::TimeToTimestampStr(Seconds(epoch));
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

    // The invader / leader / boss / questgiver creature AIs live in
    // dc_giant_isles_invasion_npcs.cpp. They reach back into this orchestrator
    // through the GI_* bridge declared in dc_giant_isles_invasion_internal.h.

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

            // Keep the DC-InfoBar Events feed fresh (live wave / enemy counts)
            // and re-sync anyone who logged in mid-invasion. Result states are
            // skipped: their transition already pushed the final record.
            if (_phase != INVASION_VICTORY && _phase != INVASION_FAILED)
            {
                if (_eventBroadcastTimerMs <= diff)
                    BroadcastInvasionEvent(map);
                else
                    _eventBroadcastTimerMs -= diff;
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

                UpdateLoaRitual(map, diff);
                UpdateLaneStandards(map, diff);

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

                // An unbroken Loa empowerment carries into the boss fight.
                UpdateLoaRitual(map, diff);

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
            BroadcastInvasionEvent(map);
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
        uint32 _eventBroadcastTimerMs = 0;
        uint32 _waveSpawnBudget = 0;
        uint32 _waveActiveCap = 0;
        uint32 _spawnedThisWave = 0;
        uint32 _killCount = 0;

        // Loa ritual objective state.
        bool _ritualActive = false;     // effigy is up and counting down
        bool _ritualResolved = false;   // ritual already happened this invasion
        bool _loaEmpowered = false;     // ritual completed; invaders stay buffed
        uint32 _ritualTimerMs = 0;
        uint32 _loaBuffTimerMs = 0;
        ObjectGuid _loaTotemGuid;

        // Lane objective state: one war standard per landing lane.
        std::array<ObjectGuid, 4> _standardGuids;
        std::array<bool, 4> _laneScuttled = {{ false, false, false, false }};
        uint32 _standardCheckTimerMs = 0;

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

            LOG_INFO("scripts.dc", "Giant Isles Invasion [AUTO]: next trigger in {} min (reason={}, targetEpoch={}, targetTime={})",
                delay / 60,
                reason ? reason : "n/a",
                _nextAutoTriggerAtSec,
                FormatEpochTimestamp(_nextAutoTriggerAtSec));
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

            if (uint32 foothold = GetCampaignFoothold())
            {
                std::string fh = "|cFFFF6000[CAMPAIGN]|r The Zandalari already hold a foothold here "
                    "(level " + std::to_string(foothold) + "). Expect a fiercer assault!";
                SendMapSystemMessage(map, fh.c_str());
            }

            LeaderAnnounce(0, map);

            map->DoForAllPlayers([](Player* player)
            {
                if (player && player->IsInWorld() && player->GetMapId() == MAP_GIANT_ISLES)
                    player->PlayDirectSound(6674);
            });

            BroadcastInvasionEvent(map);

            LOG_INFO("scripts.dc", "Giant Isles Invasion: warning phase started (trigger={}, starter={}, defenders={}, nextAutoWas={}, nextAutoWasTime={})",
                triggerSource,
                starterName,
                _defenderGuids.size(),
                _nextAutoTriggerAtSec,
                FormatEpochTimestamp(_nextAutoTriggerAtSec));
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
            _eventBroadcastTimerMs = 0;
            _waveSpawnBudget = 0;
            _waveActiveCap = 0;
            _spawnedThisWave = 0;
            _killCount = 0;
            _ritualActive = false;
            _ritualResolved = false;
            _loaEmpowered = false;
            _ritualTimerMs = 0;
            _loaBuffTimerMs = 0;
            _loaTotemGuid.Clear();
            for (ObjectGuid& g : _standardGuids)
                g.Clear();
            _laneScuttled = {{ false, false, false, false }};
            _standardCheckTimerMs = 0;
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

        // ----- Persistent campaign (foothold) ---------------------------------

        uint32 GetCampaignFoothold() const
        {
            if (!sWorldState)
                return 0;

            return std::min<uint32>(
                sWorldState->getWorldState(WORLD_STATE_INVASION_CAMPAIGN),
                static_cast<uint32>(INVASION_CAMPAIGN_MAX_FOOTHOLD));
        }

        void SetCampaignFoothold(uint32 value)
        {
            if (!sWorldState)
                return;

            sWorldState->setWorldState(WORLD_STATE_INVASION_CAMPAIGN,
                std::min<uint32>(value, static_cast<uint32>(INVASION_CAMPAIGN_MAX_FOOTHOLD)));
        }

        void AdjustCampaign(Map* map, bool victory)
        {
            uint32 foothold = GetCampaignFoothold();

            if (victory)
            {
                uint32 next = foothold > 0 ? foothold - 1 : 0;
                SetCampaignFoothold(next);

                if (foothold > 0 && next == 0)
                    SendMapSystemMessage(map,
                        "|cFF40FF40[CAMPAIGN]|r The Zandalari are driven back into the sea. "
                        "Their foothold on Giant Isles is broken!");
                else if (foothold > 0)
                {
                    std::string msg = "|cFF40FF40[CAMPAIGN]|r The invaders are pushed back. "
                        "Zandalari foothold weakened to level " + std::to_string(next) + ".";
                    SendMapSystemMessage(map, msg.c_str());
                }

                LOG_INFO("scripts.dc", "Giant Isles Invasion: campaign foothold {} -> {} (victory)", foothold, next);
            }
            else
            {
                uint32 next = std::min<uint32>(foothold + 1, static_cast<uint32>(INVASION_CAMPAIGN_MAX_FOOTHOLD));
                SetCampaignFoothold(next);

                if (next > foothold)
                {
                    std::string msg = "|cFFFF3030[CAMPAIGN]|r The Zandalari dig in deeper. "
                        "Foothold strengthened to level " + std::to_string(next) +
                        " - the next assault will be fiercer!";
                    SendMapSystemMessage(map, msg.c_str());
                }

                LOG_INFO("scripts.dc", "Giant Isles Invasion: campaign foothold {} -> {} (defeat)", foothold, next);
            }
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

            // Re-apply the leader AI's passive/immune setup (defined in the NPC
            // unit). The concrete AI type lives in the other translation unit,
            // so go through the virtual CreatureAI interface.
            if (CreatureAI* ai = leader->AI())
                ai->Reset();
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

            GI_LeaderYell(leader, stage);
        }

        char const* GetEventStateString() const
        {
            switch (_phase)
            {
                case INVASION_WARNING:
                    return "warning";
                case INVASION_WAVE_1:
                case INVASION_WAVE_2:
                case INVASION_WAVE_3:
                case INVASION_WAVE_4_BOSS:
                    return "active";
                case INVASION_VICTORY:
                    return "victory";
                case INVASION_FAILED:
                    return "failed";
                default:
                    return "inactive";
            }
        }

        // Push the current invasion state to every online player's DC-InfoBar
        // Events feed. Uses the shared EVNT module/opcode and the stable event
        // id so the bar upserts a single record. The WRLD content snapshot
        // (BuildEventsArray in dc_addon_world.cpp) carries the same record for
        // the login/handshake sync path.
        void BroadcastInvasionEvent(Map* map)
        {
            bool const active = (_phase != INVASION_INACTIVE &&
                _phase != INVASION_VICTORY && _phase != INVASION_FAILED);

            DCAddon::JsonValue data;
            data.SetObject();
            data.Set("id", DCAddon::JsonValue(static_cast<int32>(DCGiantIsles::INVASION_EVENT_ID)));
            data.Set("name", DCAddon::JsonValue("Zandalari Invasion"));
            data.Set("zone", DCAddon::JsonValue("Giant Isles"));
            data.Set("type", DCAddon::JsonValue("invasion"));
            data.Set("state", DCAddon::JsonValue(GetEventStateString()));
            data.Set("active", DCAddon::JsonValue(active));
            data.Set("wave", DCAddon::JsonValue(static_cast<uint32>(GetPublicWave())));
            data.Set("maxWaves", DCAddon::JsonValue(static_cast<uint32>(DCGiantIsles::INVASION_MAX_WAVES)));
            data.Set("timeRemaining", DCAddon::JsonValue(static_cast<uint32>(_phaseTimerMs / IN_MILLISECONDS)));

            if (map)
                data.Set("enemiesRemaining", DCAddon::JsonValue(CountAliveInvaders(map)));

            // Loa ritual objective state for the DC-InfoBar HUD.
            char const* ritualState = _ritualActive ? "channeling"
                : (_loaEmpowered ? "empowered" : "none");
            data.Set("ritual", DCAddon::JsonValue(ritualState));
            if (_ritualActive)
                data.Set("ritualTime", DCAddon::JsonValue(static_cast<uint32>(_ritualTimerMs / IN_MILLISECONDS)));

            // Lane objective progress (how many longboats the defenders have sunk).
            data.Set("boatsScuttled", DCAddon::JsonValue(CountScuttledLanes()));
            data.Set("boatsTotal", DCAddon::JsonValue(static_cast<uint32>(_standardGuids.size())));

            DCAddon::JsonMessage msg(DCAddon::Module::EVENTS,
                DCAddon::Opcode::Events::SMSG_EVENT_UPDATE, data);

            WorldSessionMgr::SessionMap const& sessions = sWorldSessionMgr->GetAllSessions();
            for (WorldSessionMgr::SessionMap::const_iterator itr = sessions.begin();
                itr != sessions.end(); ++itr)
            {
                if (!itr->second)
                    continue;

                if (Player* player = itr->second->GetPlayer())
                {
                    if (player->IsInWorld() && player->GetSession())
                        msg.Send(player);
                }
            }

            _eventBroadcastTimerMs = EVENT_BROADCAST_INTERVAL_MS;
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
            uint32 base = 0;

            switch (phase)
            {
                case INVASION_WAVE_1:
                    base = std::clamp<uint32>(6u + n, 8u, 16u);
                    break;
                case INVASION_WAVE_2:
                    base = std::clamp<uint32>(8u + n, 10u, 20u);
                    break;
                case INVASION_WAVE_3:
                    base = std::clamp<uint32>(10u + n, 12u, 24u);
                    break;
                default:
                    return 0u;
            }

            // Each foothold level keeps one more invader on the field at once.
            return base + GetCampaignFoothold();
        }

        uint32 ComputeWaveSpawnBudget(Map* map, InvasionPhase phase) const
        {
            uint32 n = CountNearbyPlayers(map);
            uint32 base = 0;

            switch (phase)
            {
                case INVASION_WAVE_1:
                    base = std::clamp<uint32>(16u + (2u * n), 18u, 40u);
                    break;
                case INVASION_WAVE_2:
                    base = std::clamp<uint32>(22u + (2u * n), 24u, 52u);
                    break;
                case INVASION_WAVE_3:
                    base = std::clamp<uint32>(28u + (2u * n), 32u, 64u);
                    break;
                default:
                    return 0u;
            }

            // A deeper foothold throws more total bodies at the beach.
            return base + (3u * GetCampaignFoothold());
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
            // Scuttled lanes contribute no pressure and are never chosen.
            uint32 total = 0;
            for (uint8 i = 0; i < _lanePressure.size(); ++i)
            {
                if (!_laneScuttled[i])
                    total += _lanePressure[i];
            }

            if (total == 0)
            {
                // No weighted choice available: pick any open lane, else lane 0.
                for (uint8 i = 0; i < _laneScuttled.size(); ++i)
                {
                    if (!_laneScuttled[i])
                        return i;
                }
                return 0;
            }

            uint32 pick = urand(1u, total);
            uint32 running = 0;

            for (uint8 i = 0; i < _lanePressure.size(); ++i)
            {
                if (_laneScuttled[i])
                    continue;

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
                defender->SetFaction(DEFENDER_FACTION);
                defender->RemoveUnitFlag(UNIT_FLAG_DISABLE_MOVE | UNIT_FLAG_PACIFIED);
                defender->ClearUnitState(UNIT_STATE_ROOT | UNIT_STATE_STUNNED);
                defender->LoadEquipment(1, true);
                defender->SetSheath(SHEATH_STATE_MELEE);
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
                ranger->SetFaction(DEFENDER_FACTION);
                ranger->RemoveUnitFlag(UNIT_FLAG_DISABLE_MOVE | UNIT_FLAG_PACIFIED);
                ranger->ClearUnitState(UNIT_STATE_ROOT | UNIT_STATE_STUNNED);
                ranger->LoadEquipment(1, true);
                ranger->SetSheath(SHEATH_STATE_MELEE);
                _defenderGuids.push_back(ranger->GetGUID());
                CommandDefender(ranger, map);
            }

            if (shaman)
            {
                shaman->SetReactState(REACT_AGGRESSIVE);
                shaman->SetFaction(DEFENDER_FACTION);
                shaman->RemoveUnitFlag(UNIT_FLAG_DISABLE_MOVE | UNIT_FLAG_PACIFIED);
                shaman->ClearUnitState(UNIT_STATE_ROOT | UNIT_STATE_STUNNED);
                shaman->LoadEquipment(1, true);
                shaman->SetSheath(SHEATH_STATE_MELEE);
                _defenderGuids.push_back(shaman->GetGUID());
                CommandDefender(shaman, map);
            }
        }

        // ----- Loa ritual objective -------------------------------------------

        void StartLoaRitual(Map* map)
        {
            if (!map || _ritualActive || _ritualResolved)
                return;

            Position pos(LoaRitualPos.x, LoaRitualPos.y, LoaRitualPos.z, LoaRitualPos.o);

            // Snap to ground so the carved effigy sits flush on the beach.
            float groundZ = map->GetHeight(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ() + 6.0f);
            if (groundZ > INVALID_HEIGHT)
                pos.m_positionZ = groundZ;

            Creature* effigy = map->SummonCreature(NPC_LOA_EFFIGY, pos, nullptr, SUMMON_LIFETIME_MS);
            if (!effigy)
            {
                LOG_WARN("scripts.dc", "Giant Isles Invasion: failed to spawn Loa effigy {}", static_cast<uint32>(NPC_LOA_EFFIGY));
                return;
            }

            // A passive idol: attackable by players, never moves, never retaliates.
            effigy->SetFaction(INVADER_FACTION);
            effigy->SetReactState(REACT_PASSIVE);
            effigy->SetUnitFlag(UNIT_FLAG_DISABLE_MOVE);
            effigy->SetImmuneToAll(false);
            effigy->GetMotionMaster()->MoveIdle();

            _loaTotemGuid = effigy->GetGUID();
            _ritualActive = true;
            _ritualTimerMs = LOA_RITUAL_DURATION_MS;
            _loaBuffTimerMs = LOA_BUFF_PULSE_MS;

            LOG_INFO("scripts.dc", "Giant Isles Invasion: Loa ritual started (effigy guid={})", effigy->GetGUID().ToString());

            SendMapSystemMessage(
                map,
                "|cFFFF0000[RITUAL]|r The witch doctors raise a Loa effigy and begin a dark chant! "
                "Destroy the effigy before the ritual completes!");

            BroadcastInvasionEvent(map);
        }

        void UpdateLoaRitual(Map* map, uint32 diff)
        {
            if (!map)
                return;

            // Keep the empowerment buff refreshed on living invaders while the
            // ritual channels OR after the Loa has answered.
            if (_ritualActive || _loaEmpowered)
            {
                if (_loaBuffTimerMs <= diff)
                {
                    PulseLoaEmpowerment(map);
                    _loaBuffTimerMs = LOA_BUFF_PULSE_MS;
                }
                else
                {
                    _loaBuffTimerMs -= diff;
                }
            }

            if (!_ritualActive)
                return;

            // Players win the objective by destroying the effigy in time.
            Creature* effigy = map->GetCreature(_loaTotemGuid);
            if (!effigy || !effigy->IsAlive())
            {
                EndLoaRitual(map, /*disrupted*/ true);
                return;
            }

            if (_ritualTimerMs <= diff)
                EndLoaRitual(map, /*disrupted*/ false);
            else
                _ritualTimerMs -= diff;
        }

        void EndLoaRitual(Map* map, bool disrupted)
        {
            _ritualActive = false;
            _ritualResolved = true;

            if (Creature* effigy = map->GetCreature(_loaTotemGuid))
                effigy->DespawnOrUnsummon(disrupted ? 1s : 4s);
            _loaTotemGuid.Clear();

            if (disrupted)
            {
                _loaEmpowered = false;
                LOG_INFO("scripts.dc", "Giant Isles Invasion: Loa ritual disrupted by defenders");

                // Strip the fury from any invader that was already empowered.
                for (ObjectGuid const& guid : _invaderGuids)
                {
                    Creature* c = map->GetCreature(guid);
                    if (c && c->HasAura(SPELL_LOA_FURY))
                        c->RemoveAurasDueToSpell(SPELL_LOA_FURY);
                }

                SendMapSystemMessage(
                    map,
                    "|cFF40FF40[DEFENDERS]|r The Loa effigy is shattered! The dark ritual collapses "
                    "and the Loa's fury is denied!");
            }
            else
            {
                _loaEmpowered = true;
                LOG_INFO("scripts.dc", "Giant Isles Invasion: Loa ritual completed - invaders empowered");

                PulseLoaEmpowerment(map);

                SendMapSystemMessage(
                    map,
                    "|cFFFF0000[RITUAL]|r The Loa answers the Zandalari call! Every invader is "
                    "EMPOWERED with primal fury for the rest of the assault!");
            }

            BroadcastInvasionEvent(map);
        }

        void PulseLoaEmpowerment(Map* map)
        {
            if (!map)
                return;

            for (ObjectGuid const& guid : _invaderGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (!c || !c->IsAlive())
                    continue;

                if (!c->HasAura(SPELL_LOA_FURY))
                    c->AddAura(SPELL_LOA_FURY, c);
            }
        }

        // ----- Lane objective: destructible longboat standards ----------------

        void SpawnLaneStandards(Map* map)
        {
            if (!map)
                return;

            for (uint8 lane = 0; lane < InvaderSpawnPoints.size(); ++lane)
            {
                if (!_standardGuids[lane].IsEmpty())
                    continue;

                InvasionSpawnPoint const& sp = InvaderSpawnPoints[lane];
                Position pos(sp.x, sp.y, sp.z, sp.o);

                float groundZ = map->GetHeight(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ() + 6.0f);
                if (groundZ > INVALID_HEIGHT)
                    pos.m_positionZ = groundZ;

                Creature* standard = map->SummonCreature(NPC_ZANDALARI_WAR_STANDARD, pos, nullptr, SUMMON_LIFETIME_MS);
                if (!standard)
                {
                    LOG_WARN("scripts.dc", "Giant Isles Invasion: failed to spawn lane standard on lane {}", lane);
                    continue;
                }

                // A planted banner: attackable, immovable, never retaliates.
                standard->SetFaction(INVADER_FACTION);
                standard->SetReactState(REACT_PASSIVE);
                standard->SetUnitFlag(UNIT_FLAG_DISABLE_MOVE);
                standard->SetImmuneToAll(false);
                standard->GetMotionMaster()->MoveIdle();

                _standardGuids[lane] = standard->GetGUID();
            }

            SendMapSystemMessage(
                map,
                "|cFFFFFF00[OBJECTIVE]|r The Zandalari plant war standards at each landing. "
                "Cut a standard down to scuttle that longboat and choke its reinforcements!");
        }

        void UpdateLaneStandards(Map* map, uint32 diff)
        {
            if (!map)
                return;

            if (_standardCheckTimerMs > diff)
            {
                _standardCheckTimerMs -= diff;
                return;
            }
            _standardCheckTimerMs = STANDARD_CHECK_INTERVAL_MS;

            for (uint8 lane = 0; lane < _standardGuids.size(); ++lane)
            {
                if (_laneScuttled[lane] || _standardGuids[lane].IsEmpty())
                    continue;

                Creature* standard = map->GetCreature(_standardGuids[lane]);
                if (!standard || !standard->IsAlive())
                    ScuttleLane(map, lane);
            }
        }

        void ScuttleLane(Map* map, uint8 lane)
        {
            if (lane >= _laneScuttled.size() || _laneScuttled[lane])
                return;

            _laneScuttled[lane] = true;
            _lanePressure[lane] = 0;

            if (Creature* standard = map->GetCreature(_standardGuids[lane]))
                standard->DespawnOrUnsummon(2s);
            _standardGuids[lane].Clear();

            LOG_INFO("scripts.dc", "Giant Isles Invasion: lane {} scuttled by defenders", lane);

            std::string msg = "|cFF40FF40[OBJECTIVE]|r A Zandalari longboat is scuttled! "
                "Lane " + std::to_string(static_cast<uint32>(lane + 1)) +
                " reinforcements are cut off.";
            SendMapSystemMessage(map, msg.c_str());

            if (AllLanesScuttled())
                SendMapSystemMessage(
                    map,
                    "|cFF40FF40[OBJECTIVE]|r Every longboat is scuttled! The Zandalari "
                    "landing force is broken - no fresh raiders can reach the beach!");
        }

        bool AllLanesScuttled() const
        {
            for (bool scuttled : _laneScuttled)
            {
                if (!scuttled)
                    return false;
            }
            return true;
        }

        uint32 CountScuttledLanes() const
        {
            uint32 n = 0;
            for (bool scuttled : _laneScuttled)
            {
                if (scuttled)
                    ++n;
            }
            return n;
        }

        void DespawnLaneStandards(Map* map)
        {
            for (ObjectGuid& guid : _standardGuids)
            {
                if (map)
                    if (Creature* standard = map->GetCreature(guid))
                        standard->DespawnOrUnsummon(1s);
                guid.Clear();
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

            // Force the template's weapon/shield set and draw it so the marching
            // invaders are visibly armed (summons can spawn with weapons sheathed).
            creature->LoadEquipment(1, true);
            creature->SetSheath(SHEATH_STATE_MELEE);

            // Reinforcements that arrive while the Loa fury is up join empowered.
            if ((_ritualActive || _loaEmpowered) && !creature->HasAura(SPELL_LOA_FURY))
                creature->AddAura(SPELL_LOA_FURY, creature);
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
            // Invaders must stay on the hostile invader faction. Previously this
            // wrote the defender faction here, which made every invader friendly
            // to the defenders (and to Horde players) and silently broke combat.
            creature->SetFaction(INVADER_FACTION);
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

            // Every longboat scuttled means there is no landing left to feed the
            // beach: reinforcements stop entirely.
            if (AllLanesScuttled())
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

            uint32 roll = urand(0u, 3u);
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
            else if (roll == 2)
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
            else
            {
                // War-beast surge: the Zandalari loose the isle's primal dinosaurs.
                uint8 lane = ChooseLaneByPressure();
                LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse war-beast surge (phase={}, lane={})", static_cast<uint32>(_phase), lane);
                SendMapSystemMessage(
                    map,
                    "|cFFFF8000[INVASION]|r The Zandalari loose their war-beasts! Primal dinosaurs stampede the shore!");

                SpawnInvader(map, lane, NPC_ZANDALARI_WAR_DIREHORN);
                SpawnInvader(map, ChooseLaneByPressure(), NPC_ZANDALARI_PTERRORDAX_BOMBER);

                // The wave-3 surge can unleash a devilsaur siege-beast to lead it.
                if (_phase == INVASION_WAVE_3 && urand(0u, 99u) < 35)
                {
                    SendMapSystemMessage(
                        map,
                        "|cFFFF0000[INVASION]|r A PRIMAL DEVILSAUR crashes onto the beach! Bring it down!");
                    SpawnInvader(map, lane, NPC_PRIMAL_DEVILSAUR);
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

            // Wave 1 plants the lane standards as the landing force comes ashore.
            if (phase == INVASION_WAVE_1)
                SpawnLaneStandards(map);

            // Immediate opening pressure.
            SpawnWaveTick(map);
            SpawnWaveTick(map);

            // Wave 3 raises the Loa ritual objective on the contested beach.
            if (phase == INVASION_WAVE_3)
                StartLoaRitual(map);

            BroadcastInvasionEvent(map);
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

            // The landing is over once the warlord arrives - clear the longboats.
            DespawnLaneStandards(map);

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

            BroadcastInvasionEvent(map);
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
            AdjustCampaign(map, /*victory*/ true);
            BroadcastInvasionEvent(map);
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
            AdjustCampaign(map, /*victory*/ false);
            BroadcastInvasionEvent(map);
        }

        void RewardParticipants(Map* map)
        {
            if (!map)
                return;

            uint32 const foothold = GetCampaignFoothold();
            bool const ritualDisrupted = (_ritualResolved && !_loaEmpowered);

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

                // War-Tokens: a flat showing-up reward plus one per personal kill,
                // scaled up by how dug-in the enemy was, with a bonus for the team
                // having denied the Loa ritual.
                uint32 tokens = 5u + personalKills + (2u * foothold);
                if (ritualDisrupted)
                    tokens += 5u;

                player->AddItem(WAR_TOKEN_ITEM, tokens);

                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Invasion]|r Beach secured. Personal contribution: %u kills. "
                    "Awarded %u War-Tokens.",
                    personalKills, tokens);
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
                _loaTotemGuid.Clear();
                for (ObjectGuid& g : _standardGuids)
                    g.Clear();
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

            if (Creature* effigy = map->GetCreature(_loaTotemGuid))
                effigy->DespawnOrUnsummon(1s);

            DespawnLaneStandards(map);

            _invaderGuids.clear();
            _defenderGuids.clear();
            _laneByInvader.clear();
            _bossGuid.Clear();
            _loaTotemGuid.Clear();
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
                                    << " nowTime=" << FormatEpochTimestamp(now)
                           << " active=" << (sGiantIslesInvasion->IsActive() ? "true" : "false");

                        if (next == 0)
                        {
                            ss << " next=unscheduled";
                        }
                        else if (next <= now)
                        {
                            ss << " nextEpoch=" << next
                               << " nextTime=" << FormatEpochTimestamp(next)
                               << " (due now)";
                        }
                        else
                        {
                            uint32 remainSec = next - now;
                            ss << " nextEpoch=" << next
                               << " nextTime=" << FormatEpochTimestamp(next)
                               << " (in " << (remainSec / 60) << "m " << (remainSec % 60) << "s)";
                        }

                        ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
                        LOG_INFO("scripts.dc", "Giant Isles Invasion [AUTO]: GM {} queried timer (now={}, nowTime={}, next={}, nextTime={}, active={})",
                            player->GetName(),
                            now,
                            FormatEpochTimestamp(now),
                            next,
                            FormatEpochTimestamp(next),
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

}

// GI_* bridge: implemented here on the orchestrator side, declared in
// dc_giant_isles_invasion_internal.h, and called by the creature AIs in
// dc_giant_isles_invasion_npcs.cpp. (Anonymous-namespace names such as
// sGiantIslesInvasion remain visible at file scope for the rest of the TU.)
bool GI_IsInvasionActive()
{
    return sGiantIslesInvasion && sGiantIslesInvasion->IsActive();
}

void GI_TrackPlayerKill(ObjectGuid playerGuid)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->TrackPlayerKill(playerGuid);
}

void GI_RegisterSummonedInvader(Creature* creature)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->RegisterSummonedInvader(creature);
}

void GI_MaintainBossGuards(Map* map)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->MaintainBossGuards(map);
}

void GI_NotifyBossDeath()
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->NotifyBossKilled();
}

void AddSC_giant_isles_invasion()
{
    new npc_invasion_horn();
    new giant_isles_invasion();
    GI_RegisterInvasionNpcs();

    LOG_INFO("scripts.dc", "Giant Isles Invasion: deterministic rewrite loaded");
}
