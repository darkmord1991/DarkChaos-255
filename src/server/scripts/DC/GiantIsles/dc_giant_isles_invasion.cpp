/*
 * Giant Isles - Invasion: the Blood Tide
 * ==========================================================================
 * An island-wide assault staged on the real MoP layout:
 *   Omens      The storm rolls in, the sky turns, Warden's Landing musters.
 *   Landfall   Longboats beach on Seeping Shores and plant war standards.
 *   Onslaught  The first war plan, fought close to the line.
 *   Siege      The second war plan, on the Zandalari ground further out.
 *   Warlord    Zul'mar comes ashore. Elder Zul'jin leads the counter-charge.
 *   Reckoning  Earned by breaking every plan: Rak'zor takes the field himself.
 *
 * Every assault differs: two war plans are drawn from five, and a chaos
 * director keeps throwing flank landings, war-beasts, storm strikes, Bozzle's
 * bombs and the odd rogue devilsaur at both sides. The defense is measured by
 * line strength rather than a head count, so a bad moment hurts without ending
 * the event outright, and defeats feed a campaign foothold that outlives the
 * assault (dc_giant_isles_warfront.cpp).
 * ==========================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Group.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "GameTime.h"
#include "WorldState.h"
#include "Timer.h"
#include "Map.h"
#include "MapMgr.h"
#include "ObjectAccessor.h"
#include "Chat.h"
#include "Log.h"
#include "Random.h"
#include "Weather.h"
#include "World.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"

#include "dc_giant_isles_invasion_internal.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include "DC/CrossSystem/CrossSystemWorldBossMgr.h"
#include "DC/CrossSystem/RewardDistributor.h"

#include <array>
#include <map>
#include <vector>
#include <string>
#include <sstream>
#include <algorithm>
#include <cmath>
#include <limits>
#include "dc_update_profiler.h"

using namespace std::chrono_literals;

namespace
{
    // Shared NPC entry ids, factions and every position on the battlefield live
    // in the internal headers so the NPC AIs and this orchestrator agree.
    using namespace DCGiantIsles;

    enum InvasionData
    {
        MAP_GIANT_ISLES                 = 1405,

        // Rules
        INVASION_COOLDOWN               = 2 * HOUR,
        INVASION_MAX_GROUP_SIZE         = 10,
        INVASION_CAMPAIGN_MAX_FOOTHOLD  = 5,
        INVASION_WAR_EFFORT_MAX         = 30,
    };

    enum InvasionPhase
    {
        INVASION_INACTIVE               = 0,
        INVASION_WARNING                = 1,
        INVASION_WAVE_1                 = 2,
        INVASION_WAVE_2                 = 3,
        INVASION_WAVE_3                 = 4,
        INVASION_WAVE_4_BOSS            = 5,
        INVASION_RECKONING              = 6,
        INVASION_VICTORY                = 7,
        INVASION_FAILED                 = 8,
    };

    // A war plan is the Zandalari scheme for one stage. Each has an objective
    // the defenders can break and a consequence if the timer beats them.
    enum WarPlan : uint8
    {
        PLAN_NONE           = 0,
        PLAN_LOA_RITUAL     = 1,    // near: witch doctors raise an effigy mid-beach
        PLAN_STAMPEDE       = 2,    // near: beastmasters drive direhorns up the plain
        PLAN_SKY_RAID       = 3,    // near: a sky-caller directs pterrordax bombers
        PLAN_IRON_RAIN      = 4,    // far: war engines shell the line from their bunkers
        PLAN_KINGS_BINDING  = 5,    // far: dinomancers bind a behemoth at the tar pits
    };

    enum ChaosEvent : uint8
    {
        CHAOS_FLANK_LANDING = 0,
        CHAOS_WAR_DRUMS,
        CHAOS_BEAST_SURGE,
        CHAOS_RELIEF_COLUMN,
        CHAOS_STORM_STRIKES,
        CHAOS_TERRACE_AMBUSH,
        CHAOS_BOMB_RUN,
        CHAOS_ROGUE_TYRANT,
    };

    constexpr uint32 WARNING_DURATION_MS = 60 * IN_MILLISECONDS;
    constexpr uint32 WAVE_1_DURATION_MS = 3 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 WAVE_2_DURATION_MS = 4 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 WAVE_3_DURATION_MS = 4 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 WAVE_4_DURATION_MS = 7 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 RECKONING_DURATION_MS = 5 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 RESULT_DURATION_MS = 45 * IN_MILLISECONDS;

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
    constexpr uint32 RELIEF_INTERVAL_MS = 40000;
    constexpr uint32 WAVE_BREAK_GRACE_MS = 8000;
    // How often the live invasion state is pushed to the DC-InfoBar Events feed
    // while the event is running (also re-syncs anyone who just logged in).
    constexpr uint32 EVENT_BROADCAST_INTERVAL_MS = 10000;
    constexpr uint32 SUMMON_LIFETIME_MS = 45 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 IMPACT_LIFETIME_MS = 12 * IN_MILLISECONDS;

    constexpr float START_REQUIRED_RANGE_YARDS = 50.0f;
    constexpr float FRONTLINE_REWARD_RADIUS = 320.0f;
    constexpr float PRESENCE_CREDIT_RADIUS = 40.0f;
    constexpr uint32 OBJECTIVE_CONTRIBUTION = 5;

    // The line: 0 means Warden's Landing has fallen.
    constexpr int32 LINE_STRENGTH_MAX = 100;
    constexpr int32 LINE_FOOTHOLD_PENALTY = 5;      // per foothold level, at the start
    constexpr int32 LINE_DEFENDER_FALLEN = -3;
    constexpr int32 LINE_BREACH = -1;               // each unopposed invader at the line
    constexpr int32 LINE_BOMBARDMENT = -1;          // each war engine shell
    constexpr int32 LINE_OBJECTIVE_BROKEN = 4;
    constexpr int32 LINE_PLAN_BROKEN = 10;
    constexpr int32 LINE_PLAN_COMPLETED = -12;
    constexpr int32 LINE_WAVE_BROKEN = 6;
    constexpr int32 LINE_BEHEMOTH_FELLED = 10;

    // War plan pacing.
    constexpr uint32 PLAN_NEAR_DURATION_MS = 2 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 PLAN_FAR_DURATION_MS = 150 * IN_MILLISECONDS;
    constexpr uint32 PLAN_LOA_PULSE_MS = 8000;
    constexpr uint32 PLAN_STAMPEDE_PULSE_MS = 9000;
    constexpr uint32 PLAN_STAMPEDE_HERD = 6;            // direhorns one whole stampede drives up

    // This war is fought by trolls: beasts are set pieces. Never more of them at
    // once than this, and they do not take a soldier's place in the wave cap.
    constexpr uint32 MAX_WAR_BEASTS_ALIVE = 3;
    constexpr uint32 PLAN_SKY_PULSE_MS = 7000;
    constexpr uint32 PLAN_IRON_PULSE_MS = 11000;
    constexpr uint32 PLAN_BINDING_PULSE_MS = 30000;
    constexpr uint32 PLAN_CHECK_INTERVAL_MS = 1000;

    constexpr uint32 SPELL_LOA_FURY = 8599;             // Enrage: visible primal empowerment
    constexpr uint32 SPELL_SPIRIT_SHIELD = 40733;       // effigy cannot be hurt while channeled
    constexpr uint32 SPELL_RITUAL_BEAM = 45537;         // cosmetic channel from caster to objective
    constexpr uint32 SPELL_STORM_STRIKE = 23687;        // Lightning Strike
    constexpr int32 STORM_STRIKE_BASE_POINTS = 6000;
    constexpr uint32 SPELL_VICTORY_FIREWORK = 11542;    // Red Streaks Firework

    // The Blood Tide's atmosphere. Map 1405 has a single global Light row, so
    // the override recolours the whole island; heavy rain then drives the
    // client into the same row's storm palette. All of it is stock client data.
    constexpr uint32 LIGHT_BLOOD_TIDE = 453;            // black sky, crimson fog, warm key light
    constexpr Milliseconds LIGHT_FADE_IN = 20s;
    constexpr Milliseconds LIGHT_FADE_OUT = 15s;
    constexpr float WEATHER_STORM_GRADE = 0.85f;
    constexpr uint32 MUSIC_BLOOD_TIDE = 12133;          // ZA_zulaman_AMB10.mp3
    constexpr uint32 SOUND_WAR_DRUMS = 11773;           // Event_wardrum_ogre.wav
    constexpr uint32 SOUND_VOODOO_STINGER = 8452;       // ZulGurubVooDoo.mp3
    constexpr uint32 SOUND_WAR_HORN = 7234;             // DwarfHorn.wav

    // Warden's Landing's standing guards, mobilized for the assault.
    std::array<uint32, 5> const LandingGuardSpawnIds =
    {{
        9000178, 9000179, 9000180, 9000181, 9000182,
    }};

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

    static Position ToPosition(InvasionPoint const& point)
    {
        return Position(point.x, point.y, point.z, point.o);
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

    // Chat line plus the centre-screen text: for the moments that must not be
    // missed in the scroll of a fight.
    static void SendMapAnnouncement(Map* map, char const* text)
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
            player->GetSession()->SendAreaTriggerMessage(std::string_view(text));
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

        // A defender already fighting keeps its target: without this every new
        // arrival at the line would pull it off the invader it is killing.
        if (Creature* targetCreature = target->ToCreature())
        {
            targetCreature->EngageWithTarget(attacker);

            if (!targetCreature->GetVictim())
                targetCreature->AI()->AttackStart(attacker);
        }
    }

    static char const* GetWarPlanName(WarPlan plan)
    {
        switch (plan)
        {
            case PLAN_LOA_RITUAL:       return "Loa's Hunger";
            case PLAN_STAMPEDE:         return "The Stampede";
            case PLAN_SKY_RAID:         return "Sky Raid";
            case PLAN_IRON_RAIN:        return "Iron Rain";
            case PLAN_KINGS_BINDING:    return "The Binding";
            default:                    return "";
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
            GI_RequestFootholdSync(GetCampaignFoothold());
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

            DarkChaos::ScopedUpdateProfiler _prof("GiantIslesInvasion");

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

            // Keep the DC-InfoBar Events feed fresh (live wave / enemy counts)
            // and re-sync anyone who logged in mid-invasion.
            if (_eventBroadcastTimerMs <= diff)
                BroadcastInvasionEvent(map);
            else
                _eventBroadcastTimerMs -= diff;

            // Omens countdown.
            if (_phase == INVASION_WARNING)
            {
                UpdateOmens(map, diff);
                return;
            }

            UpdateBattle(map, diff);
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
                        "The horn is silent for now. Cooldown remaining: {} min.",
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
                    if (IsReckoningEarned())
                        StartReckoning(map);
                    else
                        EnterVictory(map);
                    break;
                case INVASION_RECKONING:
                    EnterVictory(map);
                    break;
                default:
                    break;
            }
        }

        // ----- Bridge from the creature AIs -----------------------------------

        void CreditParticipants(Creature* victim, std::vector<ObjectGuid> const& attackers)
        {
            if (_phase == INVASION_INACTIVE || !victim)
                return;

            Map* map = victim->GetMap();
            if (!map)
                return;

            ++_killCount;

            if (sWorldState)
                sWorldState->setWorldState(WS_INVASION_KILLS, _killCount);

            // Quest credit normally goes to the tapping group alone. On a public
            // battlefield everyone who bled the invader earned it, and a defender
            // NPC landing the last blow must not rob the players who fought it.
            CreatureTemplate const* cInfo = victim->GetCreatureTemplate();
            bool const sharesCredit = cInfo && cInfo->KillCredit[0] == NPC_INVADER_KILL_CREDIT;
            Player* tapper = victim->GetLootRecipient();
            Group* tapGroup = victim->GetLootRecipientGroup();

            for (ObjectGuid const& guid : attackers)
            {
                ++_contribution[guid];

                Player* player = ObjectAccessor::GetPlayer(map, guid);
                if (!player || !sharesCredit)
                    continue;

                bool const tapped = player == tapper || (tapGroup && player->GetGroup() == tapGroup);
                if (tapped)
                    continue;

                player->KilledMonsterCredit(NPC_INVADER_KILL_CREDIT);

                // "The Warlord's Head" asks for Zul'mar himself.
                if (victim->GetEntry() == NPC_WARLORD_ZULMAR)
                    player->KilledMonsterCredit(NPC_WARLORD_ZULMAR);
            }

            // Healers and supports rarely hit anything: being in the fight counts.
            map->DoForAllPlayers([&](Player* player)
            {
                if (!player || !player->IsAlive() || player->IsGameMaster())
                    return;

                if (!player->IsWithinDist(victim, PRESENCE_CREDIT_RADIUS))
                    return;

                if (std::find(attackers.begin(), attackers.end(), player->GetGUID()) == attackers.end())
                    ++_contribution[player->GetGUID()];
            });

            // Beastmasters and sky-callers are plan objectives that die as mobs.
            CreditPlanObjective(map, victim, attackers);
        }

        void RegisterSummonedInvader(Creature* creature)
        {
            if (!creature)
                return;

            RegisterInvader(creature);
        }

        void InvaderReachedLine(Creature* creature)
        {
            if (!creature || !creature->IsAlive() || creature->IsInCombat() || !IsBattleRunning())
                return;

            Map* map = creature->GetMap();

            if (Unit* target = SelectInvaderTarget(creature, map))
            {
                ForceStartCombat(creature, target);
                return;
            }

            // Nobody left to stop them: they tear into the Landing itself.
            AdjustLine(map, LINE_BREACH);
        }

        void DefenderDied(Creature* defender)
        {
            if (!defender || !IsBattleRunning())
                return;

            ObjectGuid const guid = defender->GetGUID();
            if (std::find(_defenderGuids.begin(), _defenderGuids.end(), guid) == _defenderGuids.end())
                return;

            AdjustLine(defender->GetMap(), LINE_DEFENDER_FALLEN);
        }

        void ObjectiveDestroyed(Creature* objective, std::vector<ObjectGuid> const& attackers)
        {
            if (!objective || !IsBattleRunning())
                return;

            Map* map = objective->GetMap();

            if (objective->GetEntry() == NPC_ZANDALARI_WAR_STANDARD)
            {
                for (ObjectGuid const& guid : attackers)
                {
                    _contribution[guid] += OBJECTIVE_CONTRIBUTION;

                    if (Player* player = ObjectAccessor::GetPlayer(map, guid))
                        player->KilledMonsterCredit(NPC_CREDIT_WAR_STANDARD);
                }

                for (uint8 lane = 0; lane < _standardGuids.size(); ++lane)
                {
                    if (_standardGuids[lane] == objective->GetGUID())
                    {
                        ScuttleLane(map, lane);
                        break;
                    }
                }

                return;
            }

            CreditPlanObjective(map, objective, attackers);
        }

        void CallWarlordBeast(Creature* warlord)
        {
            if (!warlord || !IsBattleRunning())
                return;

            Map* map = warlord->GetMap();
            Position pos = warlord->GetPosition();
            pos.m_positionX += frand(-6.0f, 6.0f);
            pos.m_positionY += frand(-6.0f, 6.0f);

            Creature* beast = map->SummonCreature(NPC_PRIMAL_DEVILSAUR, pos, nullptr, SUMMON_LIFETIME_MS);
            if (!beast)
                return;

            beast->setActive(true);
            RegisterInvader(beast);

            if (Unit* target = warlord->GetVictim())
                ForceStartCombat(beast, target);
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

            // One replacement per check: the honor guard thins as the fight goes
            // on instead of standing back up the moment it falls.
            if (aliveGuards >= 4)
                return;

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
                return;

            guard->setActive(true);
            RegisterInvader(guard);

            if (Unit* target = boss->GetVictim())
                ForceStartCombat(guard, target);
        }

        void NotifyBossKilled()
        {
            Map* map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);
            if (!map)
                return;

            if (_phase != INVASION_WAVE_4_BOSS)
                return;

            if (IsReckoningEarned())
                StartReckoning(map);
            else
                EnterVictory(map);
        }

        void NotifyGeneralKilled()
        {
            Map* map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);
            if (!map)
                return;

            if (_phase != INVASION_RECKONING)
                return;

            _generalSlain = true;
            EnterVictory(map);
        }

        // ----- Bridge from the war front ---------------------------------------

        void AddWarEffort(uint32 points)
        {
            if (!sWorldState)
                return;

            SetWarEffort(GetWarEffort() + points);
        }

        // Raiding the flagship is the other way to push the campaign back: it
        // costs the Zandalari their War-God, and them a level of foothold.
        void WarGodSlain(Map* map)
        {
            uint32 const foothold = GetCampaignFoothold();
            if (foothold == 0)
                return;

            SetCampaignFoothold(foothold - 1);
            GI_RequestFootholdSync(foothold - 1);

            std::string msg = "|cFF40FF40[CAMPAIGN]|r War-God Dokah has fallen on his own deck! "
                "Zandalari foothold reduced to level " + std::to_string(foothold - 1) + ".";
            SendMapSystemMessage(map, msg.c_str());

            LOG_INFO("scripts.dc", "Giant Isles Invasion: campaign foothold {} -> {} (war god slain)", foothold, foothold - 1);
        }

        std::string BuildWarStatus() const
        {
            std::ostringstream ss;
            ss << "|cFFFF8000[War Status]|r Zandalari foothold: level " << GetCampaignFoothold()
               << " of " << static_cast<uint32>(INVASION_CAMPAIGN_MAX_FOOTHOLD)
               << ". War effort banked: " << GetWarEffort() << ".";

            if (IsActive())
                ss << " Line strength: " << _line << "%.";

            return ss.str();
        }

        uint32 GetFoothold() const
        {
            return GetCampaignFoothold();
        }

        bool IsActive() const
        {
            return _phase != INVASION_INACTIVE;
        }

        bool IsBattleRunning() const
        {
            return _phase >= INVASION_WAVE_1 && _phase <= INVASION_RECKONING;
        }

        bool HasRoomForWarBeast(Map* map) const
        {
            return CountAliveWarBeasts(map) < MAX_WAR_BEASTS_ALIVE;
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
        struct PlanRuntime
        {
            WarPlan plan = PLAN_NONE;
            bool active = false;
            bool resolved = false;
            bool broken = false;
            uint32 timerMs = 0;
            uint32 pulseMs = 0;
            uint32 objectiveTotal = 0;
            uint32 herdLeft = 0;                    // direhorns the stampede can still send
            std::vector<ObjectGuid> objectives;     // must die to break the plan
            std::vector<ObjectGuid> support;        // crews, channelers, bombers
            std::vector<ObjectGuid> credited;       // players who brought objectives down
        };

        InvasionPhase _phase = INVASION_INACTIVE;
        uint32 _phaseTimerMs = 0;
        uint32 _spawnTimerMs = 0;
        uint32 _nudgeTimerMs = 0;
        uint32 _chaosTimerMs = 0;
        uint32 _reliefTimerMs = 0;
        uint32 _planCheckTimerMs = 0;
        uint32 _eventBroadcastTimerMs = 0;
        uint32 _waveBreakTimerMs = 0;
        uint32 _waveSpawnBudget = 0;
        uint32 _waveActiveCap = 0;
        uint32 _spawnedThisWave = 0;
        uint32 _killCount = 0;
        int32 _line = LINE_STRENGTH_MAX;
        bool _omenSpoken = false;
        bool _waveBroken = false;
        bool _generalSlain = false;
        bool _counterCharged = false;
        bool _rogueSpent = false;
        uint32 _bombRunsLeft = 0;
        uint32 _extraDefenders = 0;

        // War plans for this assault, one per stage.
        std::array<PlanRuntime, 2> _plans;
        bool _loaEmpowered = false;
        uint32 _loaBuffTimerMs = 0;
        ObjectGuid _behemothGuid;

        // Lane objective state: one war standard per landing lane.
        std::array<ObjectGuid, 4> _standardGuids;
        std::array<bool, 4> _laneScuttled = {{ false, false, false, false }};

        ObjectGuid _bossGuid;
        ObjectGuid _leaderGuid;
        ObjectGuid _zuljinGuid;

        std::vector<ObjectGuid> _invaderGuids;
        std::vector<ObjectGuid> _defenderGuids;
        std::vector<ObjectGuid> _guardGuids;
        std::vector<ObjectGuid> _chaosGuids;
        std::map<ObjectGuid, uint32> _contribution;
        std::array<uint8, 4> _lanePressure = {{ 1u, 1u, 1u, 1u }};
        uint32 _nextAutoTriggerAtSec = 0;

        bool IsAssaultWave() const
        {
            return _phase == INVASION_WAVE_1 || _phase == INVASION_WAVE_2 || _phase == INVASION_WAVE_3;
        }

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
                // A bot wandering the island is no audience for a 20 minute war.
                if (player->GetSession() && player->GetSession()->IsBot())
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
            _reliefTimerMs = RELIEF_INTERVAL_MS;
            _bombRunsLeft = 2;

            for (uint8& pressure : _lanePressure)
                pressure = urand(1u, 3u);

            if (sWorldState)
            {
                sWorldState->setWorldState(WS_INVASION_ACTIVE, 1);
                sWorldState->setWorldState(WS_INVASION_WAVE, 0);
                sWorldState->setWorldState(WS_INVASION_KILLS, 0);
            }

            uint32 const foothold = GetCampaignFoothold();
            uint32 const warEffort = GetWarEffort();

            _line = LINE_STRENGTH_MAX - static_cast<int32>(foothold) * LINE_FOOTHOLD_PENALTY
                + static_cast<int32>(std::min<uint32>(warEffort / 2, 15u));
            _line = std::clamp<int32>(_line, 1, LINE_STRENGTH_MAX);
            _extraDefenders = std::min<uint32>(warEffort / 6, 5u);
            SetWarEffort(0);

            PickWarPlans();
            StartBloodTideAtmosphere(map);
            SpawnDefenders(map);
            MobilizeGuards(map);
            BindShipCommander(map, horn);

            SendMapAnnouncement(
                map,
                "|cFFFF8000[THE BLOOD TIDE]|r The sky turns red over the Isles of Giants. "
                "Zandalari sails on the horizon - to Seeping Shores!");

            sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING,
                "|cFFFF8000[Giant Isles]|r The Blood Tide rises! Zandalari warships close on Seeping Shores. "
                "Defenders of Warden's Landing, to arms!");

            if (foothold > 0)
            {
                std::string fh = "|cFFFF6000[CAMPAIGN]|r The Zandalari already hold a foothold here "
                    "(level " + std::to_string(foothold) + "). Expect a fiercer assault!";
                SendMapSystemMessage(map, fh.c_str());
            }

            if (warEffort > 0)
            {
                std::string effort = "|cFF40FF40[WAR EFFORT]|r The raids on the war camps paid off: the line stands stronger";

                if (_extraDefenders > 0)
                    effort += " and " + std::to_string(_extraDefenders) + " freed hunters take up arms";

                effort += ".";
                SendMapSystemMessage(map, effort.c_str());
            }

            LeaderAnnounce(LEADER_SAY_OMENS, map);
            map->PlayDirectSoundToMap(SOUND_WAR_HORN, INVASION_ZONE_ID);

            BroadcastInvasionEvent(map);

            LOG_INFO("scripts.dc", "Giant Isles Invasion: omens started (trigger={}, starter={}, defenders={}, line={}, foothold={}, plans={}/{})",
                triggerSource,
                starterName,
                _defenderGuids.size(),
                _line,
                foothold,
                GetWarPlanName(_plans[0].plan),
                GetWarPlanName(_plans[1].plan));
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

        void UpdateOmens(Map* map, uint32 diff)
        {
            // Halfway through the omens the drums start: the fleet is visible.
            if (!_omenSpoken && _phaseTimerMs <= WARNING_DURATION_MS / 2)
            {
                _omenSpoken = true;
                map->PlayDirectSoundToMap(SOUND_WAR_DRUMS, INVASION_ZONE_ID);
                SendMapAnnouncement(
                    map,
                    "|cFFFF8000[INVASION WARNING]|r War drums thunder across the water. "
                    "Longboats will beach within the minute!");
            }

            if (_phaseTimerMs <= diff)
                BeginWave(map, INVASION_WAVE_1);
            else
                _phaseTimerMs -= diff;
        }

        void UpdateBattle(Map* map, uint32 diff)
        {
            if (IsAssaultWave())
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
            }

            if (_phase != INVASION_WAVE_1)
            {
                if (_chaosTimerMs <= diff)
                    RunChaosPulse(map);
                else
                    _chaosTimerMs -= diff;
            }

            if (_nudgeTimerMs <= diff)
            {
                PruneTrackedSummons(map);
                NudgeDefenders(map);
                _nudgeTimerMs = NUDGE_INTERVAL_MS;
            }
            else
            {
                _nudgeTimerMs -= diff;
            }

            if (_reliefTimerMs <= diff)
            {
                MaintainDefenderLine(map);
                _reliefTimerMs = RELIEF_INTERVAL_MS;
            }
            else
            {
                _reliefTimerMs -= diff;
            }

            UpdateWarPlans(map, diff);
            UpdateLoaFury(map, diff);

            if (_line <= 0)
            {
                FailInvasion(map, "|cFFFF3030[INVASION]|r Warden's Landing has been overrun!");
                return;
            }

            if (_phase == INVASION_WAVE_4_BOSS || _phase == INVASION_RECKONING)
            {
                if (_phaseTimerMs <= diff)
                {
                    if (_phase == INVASION_WAVE_4_BOSS)
                        FailInvasion(map, "|cFFFF3030[INVASION]|r The invaders secured Seeping Shores.");
                    else
                        EnterVictory(map);

                    return;
                }

                _phaseTimerMs -= diff;
                return;
            }

            // A wave that is out of bodies with no plan left running breaks early:
            // a strong defense earns its pace instead of waiting out an empty beach.
            if (!_waveBroken && IsWaveSpent(map))
            {
                _waveBroken = true;
                _waveBreakTimerMs = WAVE_BREAK_GRACE_MS;
                AdjustLine(map, LINE_WAVE_BROKEN);
                SendMapSystemMessage(map, "|cFF40FF40[DEFENDERS]|r The wave breaks on the line! Hold fast, the next is coming in.");
            }

            if (_waveBroken)
            {
                if (_waveBreakTimerMs > diff)
                {
                    _waveBreakTimerMs -= diff;
                    return;
                }

                AdvanceStage(map);
                return;
            }

            if (_phaseTimerMs <= diff)
                AdvanceStage(map);
            else
                _phaseTimerMs -= diff;
        }

        void AdvanceStage(Map* map)
        {
            if (_phase == INVASION_WAVE_1)
                BeginWave(map, INVASION_WAVE_2);
            else if (_phase == INVASION_WAVE_2)
                BeginWave(map, INVASION_WAVE_3);
            else
                StartBossWave(map);
        }

        bool IsWaveSpent(Map* map) const
        {
            if (!IsAssaultWave())
                return false;

            if (!AllLanesScuttled() && _spawnedThisWave < _waveSpawnBudget)
                return false;

            for (PlanRuntime const& plan : _plans)
            {
                if (plan.active)
                    return false;
            }

            return CountAliveInvaders(map) == 0;
        }

        void ResetRuntimeState()
        {
            _phase = INVASION_INACTIVE;
            _phaseTimerMs = 0;
            _spawnTimerMs = 0;
            _nudgeTimerMs = 0;
            _chaosTimerMs = 0;
            _reliefTimerMs = 0;
            _planCheckTimerMs = 0;
            _eventBroadcastTimerMs = 0;
            _waveBreakTimerMs = 0;
            _waveSpawnBudget = 0;
            _waveActiveCap = 0;
            _spawnedThisWave = 0;
            _killCount = 0;
            _line = LINE_STRENGTH_MAX;
            _omenSpoken = false;
            _waveBroken = false;
            _generalSlain = false;
            _counterCharged = false;
            _rogueSpent = false;
            _bombRunsLeft = 0;
            _extraDefenders = 0;
            for (PlanRuntime& plan : _plans)
                plan = PlanRuntime();
            _loaEmpowered = false;
            _loaBuffTimerMs = 0;
            _behemothGuid.Clear();
            for (ObjectGuid& g : _standardGuids)
                g.Clear();
            _laneScuttled = {{ false, false, false, false }};
            _bossGuid.Clear();
            _leaderGuid.Clear();
            _zuljinGuid.Clear();
            _invaderGuids.clear();
            _defenderGuids.clear();
            _guardGuids.clear();
            _chaosGuids.clear();
            _contribution.clear();
            _lanePressure = {{ 1u, 1u, 1u, 1u }};
            _nextAutoTriggerAtSec = 0;
        }

        void ResetWorldStates()
        {
            if (!sWorldState)
                return;

            sWorldState->setWorldState(WS_INVASION_ACTIVE, 0);
            sWorldState->setWorldState(WS_INVASION_WAVE, 0);
            sWorldState->setWorldState(WS_INVASION_KILLS, 0);
        }

        uint32 GetLastEndTimestamp() const
        {
            if (!sWorldState)
                return 0;

            return static_cast<uint32>(sWorldState->getWorldState(WS_INVASION_LAST_END));
        }

        void SetLastEndTimestamp()
        {
            if (!sWorldState)
                return;

            sWorldState->setWorldState(WS_INVASION_LAST_END, GetNowSeconds());
        }

        // ----- Persistent campaign (foothold + war effort) ---------------------

        uint32 GetCampaignFoothold() const
        {
            if (!sWorldState)
                return 0;

            return std::min<uint32>(
                static_cast<uint32>(sWorldState->getWorldState(WS_INVASION_CAMPAIGN)),
                static_cast<uint32>(INVASION_CAMPAIGN_MAX_FOOTHOLD));
        }

        void SetCampaignFoothold(uint32 value)
        {
            if (!sWorldState)
                return;

            sWorldState->setWorldState(WS_INVASION_CAMPAIGN,
                std::min<uint32>(value, static_cast<uint32>(INVASION_CAMPAIGN_MAX_FOOTHOLD)));
        }

        uint32 GetWarEffort() const
        {
            if (!sWorldState)
                return 0;

            return std::min<uint32>(
                static_cast<uint32>(sWorldState->getWorldState(WS_INVASION_WAR_EFFORT)),
                static_cast<uint32>(INVASION_WAR_EFFORT_MAX));
        }

        void SetWarEffort(uint32 value)
        {
            if (!sWorldState)
                return;

            sWorldState->setWorldState(WS_INVASION_WAR_EFFORT,
                std::min<uint32>(value, static_cast<uint32>(INVASION_WAR_EFFORT_MAX)));
        }

        void AdjustCampaign(Map* map, bool victory)
        {
            uint32 foothold = GetCampaignFoothold();
            uint32 next = foothold;

            if (victory)
            {
                // Bringing down the general himself breaks two levels at once.
                uint32 const pushBack = _generalSlain ? 2u : 1u;
                next = foothold > pushBack ? foothold - pushBack : 0;
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
                next = std::min<uint32>(foothold + 1, static_cast<uint32>(INVASION_CAMPAIGN_MAX_FOOTHOLD));
                SetCampaignFoothold(next);

                if (next > foothold)
                {
                    std::string msg = "|cFFFF3030[CAMPAIGN]|r The Zandalari dig in deeper. "
                        "Foothold strengthened to level " + std::to_string(next) +
                        " - new war camps rise on the island!";
                    SendMapSystemMessage(map, msg.c_str());
                }

                LOG_INFO("scripts.dc", "Giant Isles Invasion: campaign foothold {} -> {} (defeat)", foothold, next);
            }

            GI_RequestFootholdSync(next);
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

            // Re-apply the leader AI's passive/immune setup (defined in the NPC
            // unit). The concrete AI type lives in the other translation unit,
            // so go through the virtual CreatureAI interface.
            if (CreatureAI* ai = leader->AI())
                ai->Reset();
        }

        void LeaderAnnounce(uint8 textGroup, Map* map)
        {
            if (!map)
                return;

            if (_leaderGuid.IsEmpty())
                return;

            Creature* leader = map->GetCreature(_leaderGuid);
            if (!leader || !leader->IsAlive())
                return;

            GI_LeaderSay(leader, textGroup);
        }

        // ----- Atmosphere -------------------------------------------------------

        void StartBloodTideAtmosphere(Map* map)
        {
            map->SetZoneOverrideLight(INVASION_ZONE_ID, LIGHT_BLOOD_TIDE, LIGHT_FADE_IN);
            map->SetZoneWeather(INVASION_ZONE_ID, WEATHER_STATE_HEAVY_RAIN, WEATHER_STORM_GRADE);
            map->SetZoneMusic(INVASION_ZONE_ID, MUSIC_BLOOD_TIDE);
            map->PlayDirectSoundToMap(SOUND_VOODOO_STINGER, INVASION_ZONE_ID);
        }

        void ClearBloodTideAtmosphere(Map* map)
        {
            map->SetZoneOverrideLight(INVASION_ZONE_ID, 0, LIGHT_FADE_OUT);
            map->SetZoneWeather(INVASION_ZONE_ID, WEATHER_STATE_FINE, 0.0f);
            map->SetZoneMusic(INVASION_ZONE_ID, 0);
        }

        // ----- Event feed -------------------------------------------------------

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
                case INVASION_RECKONING:
                    return "active";
                case INVASION_VICTORY:
                    return "victory";
                case INVASION_FAILED:
                    return "failed";
                default:
                    return "inactive";
            }
        }

        char const* GetStageName() const
        {
            switch (_phase)
            {
                case INVASION_WARNING:      return "Omens";
                case INVASION_WAVE_1:       return "Landfall";
                case INVASION_WAVE_2:       return "Onslaught";
                case INVASION_WAVE_3:       return "Siege";
                case INVASION_WAVE_4_BOSS:  return "Warlord";
                case INVASION_RECKONING:    return "Reckoning";
                case INVASION_VICTORY:      return "Victory";
                case INVASION_FAILED:       return "Defeat";
                default:                    return "";
            }
        }

        // One line for the InfoBar: the thing the player should be doing now.
        std::string GetObjectiveText() const
        {
            if (_phase == INVASION_WAVE_4_BOSS)
                return "Slay Warlord Zul'mar";

            if (_phase == INVASION_RECKONING)
                return "Slay General Rak'zor";

            for (PlanRuntime const& plan : _plans)
            {
                if (!plan.active)
                    continue;

                std::string const progress = " (" + std::to_string(plan.objectiveTotal - plan.objectives.size())
                    + "/" + std::to_string(plan.objectiveTotal) + ")";

                switch (plan.plan)
                {
                    case PLAN_LOA_RITUAL:
                        return "Kill the channelers and shatter the Loa Effigy";
                    case PLAN_STAMPEDE:
                        return "Kill the Beastmasters on the plain" + progress;
                    case PLAN_SKY_RAID:
                        return "Slay the Sky-Caller on the terrace";
                    case PLAN_IRON_RAIN:
                        return "Destroy the War Engines at the bunkers" + progress;
                    case PLAN_KINGS_BINDING:
                        return "Shatter the Binding Pylons at the tar pits" + progress;
                    default:
                        break;
                }
            }

            if (_phase == INVASION_WARNING)
                return "Rally at Warden's Landing";

            if (!AllLanesScuttled())
                return "Cut down the War Standards at the landings";

            return "Hold the line";
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

            data.Set("stage", DCAddon::JsonValue(GetStageName()));
            data.Set("objective", DCAddon::JsonValue(GetObjectiveText()));
            data.Set("line", DCAddon::JsonValue(std::max<int32>(_line, 0)));
            data.Set("foothold", DCAddon::JsonValue(GetCampaignFoothold()));

            // War plan state for the DC-InfoBar HUD. Records are merged on the
            // client, so "no plan running" has to be sent, not just left out.
            char const* planName = "";
            uint32 planSeconds = 0;

            for (PlanRuntime const& plan : _plans)
            {
                if (!plan.active)
                    continue;

                planName = GetWarPlanName(plan.plan);
                planSeconds = plan.timerMs / IN_MILLISECONDS;
                break;
            }

            data.Set("plan", DCAddon::JsonValue(planName));
            data.Set("planTime", DCAddon::JsonValue(planSeconds));

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
                case INVASION_RECKONING:
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

        static bool IsWarBeast(uint32 entry)
        {
            switch (entry)
            {
                case NPC_ZANDALARI_WAR_RAPTOR:
                case NPC_ZANDALARI_WAR_DIREHORN:
                case NPC_STAMPEDING_DIREHORN:
                case NPC_PRIMAL_DEVILSAUR:
                case NPC_BOUND_BEHEMOTH:
                    return true;
                default:
                    return false;
            }
        }

        uint32 CountAliveWarBeasts(Map* map) const
        {
            if (!map)
                return 0;

            uint32 alive = 0;
            for (ObjectGuid const& guid : _invaderGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (c && c->IsAlive() && IsWarBeast(c->GetEntry()))
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

        // ----- Defenders ---------------------------------------------------------

        // Summon one defender and apply the shared combat/visual setup. Returns
        // the creature (already tracked in _defenderGuids) or nullptr on failure.
        Creature* SpawnDefender(Map* map, uint32 entry, Position const& pos)
        {
            Creature* defender = map->SummonCreature(entry, pos, nullptr, SUMMON_LIFETIME_MS);
            if (!defender)
            {
                LOG_WARN("scripts.dc", "Giant Isles Invasion: failed to spawn defender entry {}", entry);
                return nullptr;
            }

            defender->setActive(true);
            defender->SetReactState(REACT_AGGRESSIVE);
            defender->SetFaction(DEFENDER_FACTION);
            defender->RemoveUnitFlag(UNIT_FLAG_DISABLE_MOVE | UNIT_FLAG_PACIFIED);
            defender->ClearUnitState(UNIT_STATE_ROOT | UNIT_STATE_STUNNED);
            defender->LoadEquipment(1, true);
            defender->SetSheath(SHEATH_STATE_MELEE);
            _defenderGuids.push_back(defender->GetGUID());
            return defender;
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
                InvasionPoint const& sp = DefenderSpawnPoints[i];
                Position p(sp.x, sp.y, sp.z, sp.o);

                Creature* defender = SpawnDefender(map, entries[i], p);
                if (!defender)
                    continue;

                if (i < LaneObjectives.size())
                {
                    InvasionPoint const& obj = LaneObjectives[i];
                    defender->GetMotionMaster()->MovePoint(50 + i, obj.x, obj.y, obj.z);
                }
            }

            // The left flank (lane 0) is the most exposed landing approach, so
            // post two extra defenders to hold that side of the beach.
            std::array<uint32, 2> const leftFlank =
            {{
                NPC_BEAST_HUNTER_VETERAN,
                NPC_BEAST_HUNTER,
            }};

            InvasionPoint const& leftStage = DefenderSpawnPoints[1];
            InvasionPoint const& leftObjective = LaneObjectives[0];

            for (uint32 j = 0; j < leftFlank.size(); ++j)
            {
                Position p(leftStage.x + (j * 2.0f), leftStage.y - (j * 1.5f), leftStage.z, leftStage.o);

                Creature* defender = SpawnDefender(map, leftFlank[j], p);
                if (!defender)
                    continue;

                defender->GetMotionMaster()->MovePoint(70 + j, leftObjective.x, leftObjective.y, leftObjective.z);
            }

            // Two field medics hold behind the rear post.
            InvasionPoint const& rear = DefenderSpawnPoints[4];
            SpawnDefender(map, NPC_EXPEDITION_MEDIC, Position(rear.x - 4.0f, rear.y + 3.0f, rear.z, rear.o));
            SpawnDefender(map, NPC_EXPEDITION_MEDIC, Position(rear.x + 4.0f, rear.y + 3.0f, rear.z, rear.o));

            // Captives freed by the war effort join the line.
            for (uint32 i = 0; i < _extraDefenders; ++i)
            {
                float const offset = static_cast<float>(i) * 3.0f - 6.0f;
                SpawnDefender(map, NPC_BEAST_HUNTER, Position(rear.x + offset, rear.y - 6.0f, rear.z, rear.o));
            }
        }

        // Fresh hunters jog down from the camp while the Landing still stands.
        void MaintainDefenderLine(Map* map)
        {
            uint32 const wanted = 7u + _extraDefenders;
            if (CountAliveDefenders(map) >= wanted)
                return;

            SpawnDefenderReinforcement(map);
            SendMapSystemMessage(map, "|cFF40FF40[DEFENDERS]|r Expedition reinforcements rush down from the camp!");
        }

        void SpawnDefenderReinforcement(Map* map)
        {
            if (!map)
                return;

            InvasionPoint const& rally = DefenderRallyPoint;

            Position p1(rally.x - 2.0f, rally.y - 1.0f, rally.z, rally.o);
            Position p2(rally.x + 2.0f, rally.y + 1.0f, rally.z, rally.o);

            if (Creature* ranger = SpawnDefender(map, NPC_BEAST_HUNTER_TRAPPER, p1))
                CommandDefender(ranger, map);

            if (Creature* shaman = SpawnDefender(map, NPC_BEAST_HUNTER_VETERAN, p2))
                CommandDefender(shaman, map);
        }

        void MobilizeGuards(Map* map)
        {
            auto const& spawnStore = map->GetCreatureBySpawnIdStore();

            for (uint32 spawnId : LandingGuardSpawnIds)
            {
                auto bounds = spawnStore.equal_range(spawnId);
                for (auto itr = bounds.first; itr != bounds.second; ++itr)
                {
                    Creature* guard = itr->second;
                    if (!guard || !guard->IsAlive())
                        continue;

                    guard->SetFaction(DEFENDER_FACTION);
                    guard->SetReactState(REACT_AGGRESSIVE);
                    guard->setActive(true);
                    _guardGuids.push_back(guard->GetGUID());
                }
            }
        }

        void StandDownGuards(Map* map)
        {
            for (ObjectGuid const& guid : _guardGuids)
            {
                Creature* guard = map->GetCreature(guid);
                if (!guard)
                    continue;

                guard->SetFaction(guard->GetCreatureTemplate()->faction);
                guard->CombatStop(true);
                guard->setActive(false);
            }

            _guardGuids.clear();
        }

        // ----- War plans ---------------------------------------------------------

        void PickWarPlans()
        {
            // One fight beside the line, then one the defenders must go out for.
            std::array<WarPlan, 3> const nearPlans = {{ PLAN_LOA_RITUAL, PLAN_STAMPEDE, PLAN_SKY_RAID }};
            _plans[0].plan = nearPlans[urand(0u, static_cast<uint32>(nearPlans.size() - 1))];

            // The tar pits are Oondasta's arena: no binding while he is awake.
            bool const oondastaAwake = sWorldBossMgr && sWorldBossMgr->IsBossActive(400100);
            _plans[1].plan = (!oondastaAwake && urand(0u, 1u) == 1u) ? PLAN_KINGS_BINDING : PLAN_IRON_RAIN;
        }

        Creature* SpawnObjective(Map* map, uint32 entry, InvasionPoint const& point)
        {
            Position pos = ToPosition(point);

            // Snap to ground so the objective sits flush on the terrain.
            float groundZ = map->GetHeight(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ() + 6.0f);
            if (groundZ > INVALID_HEIGHT)
                pos.m_positionZ = groundZ;

            Creature* objective = map->SummonCreature(entry, pos, nullptr, SUMMON_LIFETIME_MS);
            if (!objective)
            {
                LOG_WARN("scripts.dc", "Giant Isles Invasion: failed to spawn objective {}", entry);
                return nullptr;
            }

            // A passive target: attackable by players, never moves, never retaliates.
            objective->setActive(true);
            objective->SetFaction(INVADER_FACTION);
            objective->SetReactState(REACT_PASSIVE);
            objective->SetUnitFlag(UNIT_FLAG_DISABLE_MOVE);
            objective->SetImmuneToAll(false);
            objective->GetMotionMaster()->MoveIdle();
            return objective;
        }

        // A plan's own troops: they hold their post rather than march.
        Creature* SpawnPlanGuard(Map* map, uint32 entry, InvasionPoint const& point, PlanRuntime& plan)
        {
            Creature* guard = map->SummonCreature(entry, ToPosition(point), nullptr, SUMMON_LIFETIME_MS);
            if (!guard)
                return nullptr;

            guard->setActive(true);
            guard->SetFaction(INVADER_FACTION);
            guard->SetReactState(REACT_AGGRESSIVE);
            guard->LoadEquipment(1, true);
            guard->SetSheath(SHEATH_STATE_MELEE);
            plan.support.push_back(guard->GetGUID());
            return guard;
        }

        // Remember who brought a plan's objective down: they share the daily's
        // credit once the plan breaks.
        void CreditPlanObjective(Map* map, Creature* objective, std::vector<ObjectGuid> const& attackers)
        {
            for (PlanRuntime& plan : _plans)
            {
                if (std::find(plan.objectives.begin(), plan.objectives.end(), objective->GetGUID()) == plan.objectives.end())
                    continue;

                for (ObjectGuid const& guid : attackers)
                    _contribution[guid] += OBJECTIVE_CONTRIBUTION;

                plan.credited.insert(plan.credited.end(), attackers.begin(), attackers.end());
                AdjustLine(map, LINE_OBJECTIVE_BROKEN);
                return;
            }
        }

        void StartWarPlan(Map* map, uint8 slot)
        {
            PlanRuntime& plan = _plans[slot];
            if (plan.plan == PLAN_NONE || plan.active || plan.resolved)
                return;

            switch (plan.plan)
            {
                case PLAN_LOA_RITUAL:
                    StartLoaRitual(map, plan);
                    break;
                case PLAN_STAMPEDE:
                    StartStampede(map, plan);
                    break;
                case PLAN_SKY_RAID:
                    StartSkyRaid(map, plan);
                    break;
                case PLAN_IRON_RAIN:
                    StartIronRain(map, plan);
                    break;
                case PLAN_KINGS_BINDING:
                    StartBinding(map, plan);
                    break;
                default:
                    return;
            }

            plan.objectiveTotal = static_cast<uint32>(plan.objectives.size());

            if (plan.objectives.empty())
            {
                LOG_WARN("scripts.dc", "Giant Isles Invasion: war plan {} spawned no objectives, skipping", GetWarPlanName(plan.plan));
                plan.resolved = true;
                return;
            }

            plan.active = true;
            _planCheckTimerMs = PLAN_CHECK_INTERVAL_MS;

            LOG_INFO("scripts.dc", "Giant Isles Invasion: war plan {} started ({} objectives)",
                GetWarPlanName(plan.plan), plan.objectiveTotal);

            BroadcastInvasionEvent(map);
        }

        // A ritualist holds its post and its beam until somebody kills it.
        void BindChanneler(Creature* channeler, Creature* focus)
        {
            channeler->SetUnitFlag(UNIT_FLAG_DISABLE_MOVE);
            channeler->CastSpell(focus, SPELL_RITUAL_BEAM, true);
        }

        void StartLoaRitual(Map* map, PlanRuntime& plan)
        {
            Creature* effigy = SpawnObjective(map, NPC_LOA_EFFIGY, LoaRitualPos);
            if (!effigy)
                return;

            plan.objectives.push_back(effigy->GetGUID());
            plan.timerMs = PLAN_NEAR_DURATION_MS;
            plan.pulseMs = PLAN_LOA_PULSE_MS;

            // The effigy cannot be hurt until its channelers fall.
            effigy->CastSpell(effigy, SPELL_SPIRIT_SHIELD, true);

            for (InvasionPoint const& point : LoaChannelerPoints)
            {
                if (Creature* doctor = SpawnPlanGuard(map, NPC_ZANDALARI_WITCH_DOCTOR, point, plan))
                {
                    RegisterInvader(doctor);
                    BindChanneler(doctor, effigy);
                }
            }

            LeaderAnnounce(LEADER_SAY_PLAN_LOA, map);
            SendMapAnnouncement(
                map,
                "|cFFFF0000[LOA'S HUNGER]|r Witch doctors raise a Loa effigy on the beach! "
                "Kill the channelers, then shatter it before the ritual completes!");
        }

        void StartStampede(Map* map, PlanRuntime& plan)
        {
            plan.timerMs = PLAN_NEAR_DURATION_MS;
            plan.pulseMs = PLAN_STAMPEDE_PULSE_MS;
            plan.herdLeft = PLAN_STAMPEDE_HERD;

            for (InvasionPoint const& point : BeastmasterPoints)
            {
                if (Creature* master = SpawnPlanGuard(map, NPC_ZANDALARI_BEASTMASTER, point, plan))
                {
                    plan.support.pop_back();
                    plan.objectives.push_back(master->GetGUID());
                }
            }

            LeaderAnnounce(LEADER_SAY_PLAN_STAMPEDE, map);
            SendMapAnnouncement(
                map,
                "|cFFFF0000[THE STAMPEDE]|r Beastmasters drive a herd of direhorns up the plain! "
                "Kill them to the east of the beach and the herd turns!");
        }

        void StartSkyRaid(Map* map, PlanRuntime& plan)
        {
            plan.timerMs = PLAN_NEAR_DURATION_MS;
            plan.pulseMs = PLAN_SKY_PULSE_MS;

            if (Creature* caller = SpawnPlanGuard(map, NPC_ZANDALARI_SKY_CALLER, SkyCallerPoint, plan))
            {
                plan.support.pop_back();
                plan.objectives.push_back(caller->GetGUID());
            }

            for (uint8 i = 0; i < 3; ++i)
            {
                float const angle = static_cast<float>(i) * 2.1f;
                Position pos(BomberOrbitCentre.x + std::cos(angle) * 30.0f, BomberOrbitCentre.y + std::sin(angle) * 30.0f,
                    BomberOrbitCentre.z, angle);

                Creature* bomber = map->SummonCreature(NPC_ZANDALARI_PTERRORDAX_BOMBER, pos, nullptr, SUMMON_LIFETIME_MS);
                if (!bomber)
                    continue;

                bomber->setActive(true);
                bomber->SetFaction(INVADER_FACTION);
                bomber->SetReactState(REACT_PASSIVE);
                bomber->SetCanFly(true);
                bomber->SetDisableGravity(true);
                bomber->GetMotionMaster()->MoveCirclePath(
                    BomberOrbitCentre.x, BomberOrbitCentre.y, BomberOrbitCentre.z, 30.0f, i % 2 == 0, 12);
                plan.support.push_back(bomber->GetGUID());
            }

            LeaderAnnounce(LEADER_SAY_PLAN_SKY_RAID, map);
            SendMapAnnouncement(
                map,
                "|cFFFF0000[SKY RAID]|r Pterrordax bombers circle the Landing! "
                "A sky-caller on the terrace directs them - bring the caller down!");
        }

        void StartIronRain(Map* map, PlanRuntime& plan)
        {
            plan.timerMs = PLAN_FAR_DURATION_MS;
            plan.pulseMs = PLAN_IRON_PULSE_MS;

            for (InvasionPoint const& point : WarEnginePoints)
            {
                if (Creature* engine = SpawnObjective(map, NPC_ZANDALARI_WAR_ENGINE, point))
                    plan.objectives.push_back(engine->GetGUID());
            }

            for (InvasionPoint const& point : EngineCrewPoints)
                SpawnPlanGuard(map, NPC_ZANDALARI_ENGINE_CREW, point, plan);

            LeaderAnnounce(LEADER_SAY_PLAN_IRON_RAIN, map);
            SendMapAnnouncement(
                map,
                "|cFFFF0000[IRON RAIN]|r War engines open fire from the Zandalari bunkers! "
                "Fly to Slimer Bay and the eastern heights and silence them!");
        }

        void StartBinding(Map* map, PlanRuntime& plan)
        {
            plan.timerMs = PLAN_FAR_DURATION_MS;
            plan.pulseMs = PLAN_BINDING_PULSE_MS;

            for (InvasionPoint const& point : BindingPylonPoints)
            {
                Creature* pylon = SpawnObjective(map, NPC_BINDING_PYLON, point);
                if (!pylon)
                    continue;

                plan.objectives.push_back(pylon->GetGUID());

                InvasionPoint binderPoint = point;
                binderPoint.x += 4.0f;
                binderPoint.y += 3.0f;

                if (Creature* binder = SpawnPlanGuard(map, NPC_ZANDALARI_DINOMANCER, binderPoint, plan))
                    BindChanneler(binder, pylon);
            }

            LeaderAnnounce(LEADER_SAY_PLAN_BINDING, map);
            SendMapAnnouncement(
                map,
                "|cFFFF0000[THE BINDING]|r Dinomancers bind a primal behemoth at the tar pits! "
                "Fly to the basin and shatter the Binding Pylons!");
        }

        void UpdateWarPlans(Map* map, uint32 diff)
        {
            bool checkObjectives = false;

            if (_planCheckTimerMs <= diff)
            {
                checkObjectives = true;
                _planCheckTimerMs = PLAN_CHECK_INTERVAL_MS;
            }
            else
            {
                _planCheckTimerMs -= diff;
            }

            for (PlanRuntime& plan : _plans)
            {
                if (!plan.active)
                    continue;

                if (checkObjectives)
                {
                    PruneGuids(map, plan.objectives);
                    PruneGuids(map, plan.support);

                    if (plan.plan == PLAN_LOA_RITUAL && plan.support.empty() && !plan.objectives.empty())
                        DropEffigyShield(map, plan);

                    if (plan.objectives.empty())
                    {
                        ResolveWarPlan(map, plan, true);
                        continue;
                    }
                }

                if (plan.pulseMs <= diff)
                {
                    PulseWarPlan(map, plan);
                }
                else
                {
                    plan.pulseMs -= diff;
                }

                if (plan.timerMs <= diff)
                    ResolveWarPlan(map, plan, false);
                else
                    plan.timerMs -= diff;
            }
        }

        void DropEffigyShield(Map* map, PlanRuntime const& plan)
        {
            Creature* effigy = map->GetCreature(plan.objectives.front());
            if (!effigy || !effigy->HasAura(SPELL_SPIRIT_SHIELD))
                return;

            effigy->RemoveAurasDueToSpell(SPELL_SPIRIT_SHIELD);
            SendMapAnnouncement(map, "|cFF40FF40[LOA'S HUNGER]|r The channelers are dead - the effigy's shield falls! Shatter it!");
        }

        void PulseWarPlan(Map* map, PlanRuntime& plan)
        {
            switch (plan.plan)
            {
                case PLAN_LOA_RITUAL:
                    plan.pulseMs = PLAN_LOA_PULSE_MS;
                    PulseLoaEmpowerment(map);
                    break;
                case PLAN_STAMPEDE:
                    plan.pulseMs = PLAN_STAMPEDE_PULSE_MS;
                    if (plan.herdLeft > 0)
                        plan.herdLeft -= SpawnStampede(map, 1);
                    break;
                case PLAN_SKY_RAID:
                    plan.pulseMs = PLAN_SKY_PULSE_MS;
                    for (ObjectGuid const& guid : plan.support)
                    {
                        Creature* bomber = map->GetCreature(guid);
                        if (bomber && bomber->IsAlive() && bomber->GetEntry() == NPC_ZANDALARI_PTERRORDAX_BOMBER)
                            DropFireNearLine(map, bomber->GetPositionX(), bomber->GetPositionY(), INVADER_FACTION);
                    }
                    break;
                case PLAN_IRON_RAIN:
                    plan.pulseMs = PLAN_IRON_PULSE_MS;
                    for (uint32 i = 0; i < plan.objectives.size(); ++i)
                    {
                        InvasionPoint const& post = LaneObjectives[urand(0u, static_cast<uint32>(LaneObjectives.size() - 1))];
                        DropFireNearLine(map, post.x + frand(-14.0f, 14.0f), post.y + frand(-14.0f, 14.0f), INVADER_FACTION);
                        AdjustLine(map, LINE_BOMBARDMENT);
                    }
                    break;
                case PLAN_KINGS_BINDING:
                {
                    plan.pulseMs = PLAN_BINDING_PULSE_MS;
                    std::string msg = "|cFFFF8000[THE BINDING]|r The binding tightens: "
                        + std::to_string(plan.timerMs / IN_MILLISECONDS) + " seconds until the behemoth breaks free!";
                    SendMapSystemMessage(map, msg.c_str());
                    break;
                }
                default:
                    break;
            }
        }

        void ResolveWarPlan(Map* map, PlanRuntime& plan, bool broken)
        {
            plan.active = false;
            plan.resolved = true;
            plan.broken = broken;

            for (ObjectGuid const& guid : plan.objectives)
                if (Creature* objective = map->GetCreature(guid))
                    objective->DespawnOrUnsummon(broken ? 1s : 4s);

            for (ObjectGuid const& guid : plan.support)
                if (Creature* unit = map->GetCreature(guid))
                    unit->DespawnOrUnsummon(2s);

            plan.objectives.clear();
            plan.support.clear();

            LOG_INFO("scripts.dc", "Giant Isles Invasion: war plan {} {}", GetWarPlanName(plan.plan), broken ? "broken" : "completed");

            if (broken)
            {
                AdjustLine(map, LINE_PLAN_BROKEN);

                // The fury was only ever borrowed from the ritual.
                if (plan.plan == PLAN_LOA_RITUAL)
                    StripLoaFury(map);

                // Every player who struck an objective shares the daily's credit.
                std::sort(plan.credited.begin(), plan.credited.end());
                plan.credited.erase(std::unique(plan.credited.begin(), plan.credited.end()), plan.credited.end());

                for (ObjectGuid const& guid : plan.credited)
                {
                    if (Player* player = ObjectAccessor::GetPlayer(map, guid))
                        player->KilledMonsterCredit(NPC_CREDIT_WAR_PLAN);
                }

                std::string msg = "|cFF40FF40[WAR PLAN BROKEN]|r ";
                msg += GetWarPlanName(plan.plan);
                msg += " is shattered! The defenders rally.";
                SendMapAnnouncement(map, msg.c_str());
            }
            else
            {
                AdjustLine(map, LINE_PLAN_COMPLETED);
                ApplyPlanConsequence(map, plan);
            }

            BroadcastInvasionEvent(map);
        }

        void ApplyPlanConsequence(Map* map, PlanRuntime const& plan)
        {
            switch (plan.plan)
            {
                case PLAN_LOA_RITUAL:
                    _loaEmpowered = true;
                    _loaBuffTimerMs = PLAN_LOA_PULSE_MS;
                    PulseLoaEmpowerment(map);
                    SendMapAnnouncement(
                        map,
                        "|cFFFF0000[LOA'S HUNGER]|r The Loa answers the Zandalari call! Every invader is "
                        "EMPOWERED with primal fury for the rest of the assault!");
                    break;
                case PLAN_STAMPEDE:
                    if (HasRoomForWarBeast(map))
                    {
                        SpawnMarcher(map, EastFlankLanding, NPC_PRIMAL_DEVILSAUR, ROUTE_EAST_FLANK);
                        SendMapAnnouncement(
                            map,
                            "|cFFFF0000[THE STAMPEDE]|r The herd is loose! A PRIMAL DEVILSAUR leads the last charge!");
                    }
                    else
                        SendMapAnnouncement(map, "|cFFFF0000[THE STAMPEDE]|r The herd is loose!");

                    SpawnStampede(map, 1);
                    break;
                case PLAN_SKY_RAID:
                    for (uint8 i = 0; i < 4; ++i)
                        DropFireNearLine(map, FrontlineAnchor.x + frand(-24.0f, 24.0f), FrontlineAnchor.y + frand(-24.0f, 24.0f), INVADER_FACTION);
                    SendMapAnnouncement(map, "|cFFFF0000[SKY RAID]|r The bombers empty their racks over the Landing!");
                    break;
                case PLAN_IRON_RAIN:
                    SendMapAnnouncement(map, "|cFFFF0000[IRON RAIN]|r The barrage walks through the Landing! The line reels!");
                    break;
                case PLAN_KINGS_BINDING:
                    ReleaseBehemoth(map);
                    break;
                default:
                    break;
            }
        }

        // ----- Stampede / behemoth --------------------------------------------

        // Up to `count` direhorns, never past the beast cap. Returns how many came.
        uint32 SpawnStampede(Map* map, uint32 count)
        {
            std::array<int32, 3> const routes = {{ ROUTE_STAMPEDE_A, ROUTE_STAMPEDE_B, ROUTE_STAMPEDE_C }};

            uint32 const alive = CountAliveWarBeasts(map);
            uint32 const room = alive < MAX_WAR_BEASTS_ALIVE ? MAX_WAR_BEASTS_ALIVE - alive : 0u;
            uint32 spawned = 0;

            for (uint32 i = 0; i < count && spawned < room; ++i)
            {
                int32 const route = routes[urand(0u, static_cast<uint32>(routes.size() - 1))];
                MarchRouteView const view = GetMarchRoute(route);
                if (SpawnMarcher(map, view.points[0], NPC_STAMPEDING_DIREHORN, route))
                    ++spawned;
            }

            return spawned;
        }

        void ReleaseBehemoth(Map* map)
        {
            Creature* behemoth = map->SummonCreature(NPC_BOUND_BEHEMOTH, ToPosition(BehemothCliffPoint), nullptr, SUMMON_LIFETIME_MS);
            if (!behemoth)
            {
                LOG_WARN("scripts.dc", "Giant Isles Invasion: failed to spawn the bound behemoth");
                return;
            }

            behemoth->setActive(true);
            RegisterInvader(behemoth);
            _behemothGuid = behemoth->GetGUID();

            behemoth->GetMotionMaster()->MoveJump(
                BehemothLandingPoint.x, BehemothLandingPoint.y, BehemothLandingPoint.z, 34.0f, 16.0f);

            if (CreatureAI* ai = behemoth->AI())
                ai->SetData(DATA_MARCH_ROUTE_DELAYED, static_cast<uint32>(ROUTE_LANE_3));

            map->PlayDirectSoundToMap(SOUND_WAR_DRUMS, INVASION_ZONE_ID);
            SendMapAnnouncement(
                map,
                "|cFFFF0000[THE BINDING]|r The binding holds! A PRIMAL BEHEMOTH hurls itself from the cliffs "
                "onto the beach - bring it down!");
        }

        // Fire falling near the line. The marker's faction picks who burns: an
        // invader's fire hurts defenders and players, Bozzle's hurts the invaders.
        void DropFireNearLine(Map* map, float x, float y, uint32 faction)
        {
            float z = map->GetHeight(x, y, MAX_HEIGHT);
            if (z <= INVALID_HEIGHT)
                return;

            Creature* marker = map->SummonCreature(NPC_IMPACT_MARKER, Position(x, y, z, 0.0f), nullptr, IMPACT_LIFETIME_MS);
            if (!marker)
                return;

            marker->setActive(true);
            marker->SetFaction(faction);

            if (CreatureAI* ai = marker->AI())
                ai->DoAction(ACTION_DROP_FIRE);
        }

        // ----- Loa fury ---------------------------------------------------------

        void UpdateLoaFury(Map* map, uint32 diff)
        {
            if (!_loaEmpowered)
                return;

            if (_loaBuffTimerMs <= diff)
            {
                PulseLoaEmpowerment(map);
                _loaBuffTimerMs = PLAN_LOA_PULSE_MS;
            }
            else
            {
                _loaBuffTimerMs -= diff;
            }
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

        void StripLoaFury(Map* map)
        {
            for (ObjectGuid const& guid : _invaderGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (c && c->HasAura(SPELL_LOA_FURY))
                    c->RemoveAurasDueToSpell(SPELL_LOA_FURY);
            }
        }

        bool IsLoaChanneling() const
        {
            for (PlanRuntime const& plan : _plans)
            {
                if (plan.active && plan.plan == PLAN_LOA_RITUAL)
                    return true;
            }

            return false;
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

                Creature* standard = SpawnObjective(map, NPC_ZANDALARI_WAR_STANDARD, InvaderSpawnPoints[lane]);
                if (!standard)
                    continue;

                _standardGuids[lane] = standard->GetGUID();
            }

            SendMapSystemMessage(
                map,
                "|cFFFFFF00[OBJECTIVE]|r The Zandalari plant war standards at each landing. "
                "Cut a standard down to scuttle that longboat and choke its reinforcements!");
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

            AdjustLine(map, LINE_OBJECTIVE_BROKEN);

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

        // ----- Invaders -----------------------------------------------------------

        // Anything that lands somewhere and walks a route to the line.
        Creature* SpawnMarcher(Map* map, InvasionPoint const& at, uint32 entry, int32 route)
        {
            if (!map)
                return nullptr;

            Creature* invader = map->SummonCreature(entry, ToPosition(at), nullptr, SUMMON_LIFETIME_MS);
            if (!invader)
            {
                LOG_WARN("scripts.dc", "Giant Isles Invasion: failed to spawn invader entry {} on route {}", entry, route);
                return nullptr;
            }

            invader->setActive(true);
            RegisterInvader(invader);

            if (CreatureAI* ai = invader->AI())
                ai->SetData(DATA_MARCH_ROUTE, static_cast<uint32>(route));

            return invader;
        }

        bool SpawnInvader(Map* map, uint8 lane, uint32 entry)
        {
            lane %= static_cast<uint8>(InvaderSpawnPoints.size());
            return SpawnMarcher(map, InvaderSpawnPoints[lane], entry, ROUTE_LANE_0 + lane) != nullptr;
        }

        void RegisterInvader(Creature* creature)
        {
            if (!creature)
                return;

            ObjectGuid guid = creature->GetGUID();
            if (std::find(_invaderGuids.begin(), _invaderGuids.end(), guid) == _invaderGuids.end())
                _invaderGuids.push_back(guid);

            // Keep invaders on explicit invasion faction (never Horde-side guards).
            creature->SetFaction(INVADER_FACTION);
            creature->SetReactState(REACT_AGGRESSIVE);

            // Force one of the template's weapon sets and draw it so the marching
            // invaders are visibly armed (summons can spawn with weapons sheathed).
            creature->LoadEquipment(-1, true);
            creature->SetSheath(SHEATH_STATE_MELEE);

            // Reinforcements that arrive while the Loa fury is up join empowered.
            if ((IsLoaChanneling() || _loaEmpowered) && !creature->HasAura(SPELL_LOA_FURY))
                creature->AddAura(SPELL_LOA_FURY, creature);
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
            float bestInvaderDist = _counterCharged ? 120.0f : 60.0f;

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

        void CommandDefender(Creature* creature, Map* map)
        {
            if (!creature || !map || !creature->IsAlive())
                return;

            // Medics hold behind the line and pick their own patients.
            if (creature->GetEntry() == NPC_EXPEDITION_MEDIC)
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

            // Keep defenders anchored near their posts when no invaders are in
            // range. After the counter-charge those posts are out on the beach.
            InvasionPoint const* posts = _counterCharged ? AdvancedLine.data() : LaneObjectives.data();
            size_t const postCount = _counterCharged ? AdvancedLine.size() : LaneObjectives.size();

            uint8 bestIndex = 0;
            float bestDist = std::numeric_limits<float>::max();

            for (uint8 i = 0; i < postCount; ++i)
            {
                float dist = creature->GetDistance(posts[i].x, posts[i].y, posts[i].z);

                if (dist < bestDist)
                {
                    bestDist = dist;
                    bestIndex = i;
                }
            }

            // Already at the post: leave it be rather than re-pathing every tick.
            if (bestDist < 6.0f)
                return;

            InvasionPoint const& objective = posts[bestIndex];
            creature->SetHomePosition(objective.x, objective.y, objective.z, objective.o);
            creature->GetMotionMaster()->Clear();
            creature->GetMotionMaster()->MovePoint(150 + bestIndex, objective.x, objective.y, objective.z);
        }

        void PruneGuids(Map* map, std::vector<ObjectGuid>& guids) const
        {
            guids.erase(
                std::remove_if(guids.begin(), guids.end(),
                    [&](ObjectGuid const& guid)
                    {
                        Creature* c = map->GetCreature(guid);
                        return !c || !c->IsAlive();
                    }),
                guids.end());
        }

        void PruneTrackedSummons(Map* map)
        {
            PruneGuids(map, _invaderGuids);
            PruneGuids(map, _defenderGuids);
            PruneGuids(map, _chaosGuids);

            if (!_behemothGuid.IsEmpty())
            {
                Creature* behemoth = map->GetCreature(_behemothGuid);
                if (!behemoth || !behemoth->IsAlive())
                {
                    _behemothGuid.Clear();
                    AdjustLine(map, LINE_BEHEMOTH_FELLED);
                    SendMapAnnouncement(map, "|cFF40FF40[THE BINDING]|r The behemoth falls! The ground stops shaking.");
                }
            }
        }

        void NudgeDefenders(Map* map)
        {
            if (!map)
                return;

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

            if (!IsAssaultWave())
                return;

            // Every longboat scuttled means there is no landing left to feed the
            // beach: reinforcements stop entirely.
            if (AllLanesScuttled())
                return;

            if (_spawnedThisWave >= _waveSpawnBudget)
                return;

            // War beasts run on their own cap: a herd must not keep the soldiers off the beach.
            uint32 alive = CountAliveInvaders(map) - CountAliveWarBeasts(map);
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
                uint32 entry = PickWaveEntry();

                // From the Onslaught on, part of every wave arrives overland: the
                // Warpath column from Slimer Bay, or the shorter east flank.
                if (_phase != INVASION_WAVE_1 && urand(0u, 99u) < 25)
                {
                    bool const warpath = _phase == INVASION_WAVE_3 && urand(0u, 1u) == 1u;
                    if (SpawnMarcher(map, warpath ? WarpathLanding : EastFlankLanding, entry, warpath ? ROUTE_WARPATH : ROUTE_EAST_FLANK))
                        ++_spawnedThisWave;
                    continue;
                }

                uint8 lane = ChooseLaneByPressure();

                if (SpawnInvader(map, lane, entry))
                {
                    ++_spawnedThisWave;
                    _lanePressure[lane] = std::min<uint8>(6u, static_cast<uint8>(_lanePressure[lane] + 1u));
                }
            }
        }

        // ----- Chaos director -----------------------------------------------------

        ChaosEvent PickChaosEvent() const
        {
            // The warlord fight keeps the storm and the relief going, not the waves.
            if (_phase == INVASION_WAVE_4_BOSS || _phase == INVASION_RECKONING)
            {
                std::array<ChaosEvent, 3> const bossPulses =
                {{
                    CHAOS_STORM_STRIKES, CHAOS_RELIEF_COLUMN, CHAOS_BOMB_RUN,
                }};
                return bossPulses[urand(0u, static_cast<uint32>(bossPulses.size() - 1))];
            }

            std::vector<ChaosEvent> pool =
            {
                CHAOS_FLANK_LANDING, CHAOS_WAR_DRUMS, CHAOS_BEAST_SURGE, CHAOS_RELIEF_COLUMN,
                CHAOS_STORM_STRIKES, CHAOS_TERRACE_AMBUSH,
            };

            if (_bombRunsLeft > 0)
                pool.push_back(CHAOS_BOMB_RUN);

            if (_phase == INVASION_WAVE_3 && !_rogueSpent)
                pool.push_back(CHAOS_ROGUE_TYRANT);

            return pool[urand(0u, static_cast<uint32>(pool.size() - 1))];
        }

        void RunChaosPulse(Map* map)
        {
            if (!map)
                return;

            RebalanceLanePressure();

            bool const landingsOpen = !AllLanesScuttled();

            switch (PickChaosEvent())
            {
                case CHAOS_FLANK_LANDING:
                    if (landingsOpen)
                    {
                        LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse flank (phase={})", static_cast<uint32>(_phase));
                        SendMapSystemMessage(map, "|cFFFF8000[INVASION]|r A flanking longboat lands at Bozzle's wreck and raiders surge in!");
                        SpawnMarcher(map, EastFlankLanding, PickWaveEntry(), ROUTE_EAST_FLANK);
                        SpawnMarcher(map, EastFlankLanding, PickWaveEntry(), ROUTE_EAST_FLANK);
                    }
                    break;
                case CHAOS_WAR_DRUMS:
                    if (landingsOpen)
                    {
                        uint8 lane = ChooseLaneByPressure();
                        LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse war-drum surge (phase={}, lane={})", static_cast<uint32>(_phase), lane);
                        map->PlayDirectSoundToMap(SOUND_WAR_DRUMS, INVASION_ZONE_ID);
                        SendMapSystemMessage(map, "|cFFFF8000[INVASION]|r War drums intensify. The assault grows more chaotic!");

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
                    break;
                case CHAOS_BEAST_SURGE:
                    if (landingsOpen && HasRoomForWarBeast(map))
                    {
                        // War-beast surge: the Zandalari loose one of their armoured beasts.
                        uint8 lane = ChooseLaneByPressure();
                        LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse war-beast surge (phase={}, lane={})", static_cast<uint32>(_phase), lane);
                        SendMapSystemMessage(map, "|cFFFF8000[INVASION]|r The Zandalari loose a war-direhorn on the shore!");

                        SpawnInvader(map, lane, NPC_ZANDALARI_WAR_DIREHORN);

                        // The wave-3 surge can unleash a devilsaur siege-beast to lead it.
                        if (_phase == INVASION_WAVE_3 && urand(0u, 99u) < 35 && HasRoomForWarBeast(map))
                        {
                            SendMapSystemMessage(map, "|cFFFF0000[INVASION]|r A PRIMAL DEVILSAUR crashes onto the beach! Bring it down!");
                            SpawnInvader(map, lane, NPC_PRIMAL_DEVILSAUR);
                        }
                    }
                    break;
                case CHAOS_RELIEF_COLUMN:
                    LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse defender reinforcements (phase={})", static_cast<uint32>(_phase));
                    SendMapSystemMessage(map, "|cFF40FF40[DEFENDERS]|r Expedition reinforcements rush down from the camp!");
                    SpawnDefenderReinforcement(map);
                    break;
                case CHAOS_STORM_STRIKES:
                    LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse storm strikes (phase={})", static_cast<uint32>(_phase));
                    SendMapSystemMessage(map, "|cFFFFA0FF[THE BLOOD TIDE]|r The storm turns on the Landing! Lightning walks the beach!");
                    CallStormStrikes(map);
                    break;
                case CHAOS_TERRACE_AMBUSH:
                    LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse terrace ambush (phase={})", static_cast<uint32>(_phase));
                    SendMapSystemMessage(map, "|cFFFF8000[INVASION]|r Raiders pour down from the terrace above the Landing!");
                    SpawnMarcher(map, TerraceAmbushPoint, NPC_ZANDALARI_SHADOW_HUNTER, ROUTE_TERRACE);
                    SpawnMarcher(map, TerraceAmbushPoint, NPC_ZANDALARI_SPEARMAN, ROUTE_TERRACE);
                    break;
                case CHAOS_BOMB_RUN:
                    LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse bomb run (phase={})", static_cast<uint32>(_phase));
                    SendMapAnnouncement(map, "|cFF40FF40[BOZZLE]|r \"Heads up down there! Compliments of the expedition!\" Goblin bombs rain on the invaders!");
                    CallBombRun(map);
                    if (_bombRunsLeft > 0)
                        --_bombRunsLeft;
                    break;
                case CHAOS_ROGUE_TYRANT:
                    LOG_INFO("scripts.dc", "Giant Isles Invasion: chaos pulse rogue tyrant (phase={})", static_cast<uint32>(_phase));
                    _rogueSpent = true;
                    ReleaseRogueTyrant(map);
                    break;
                default:
                    break;
            }

            _chaosTimerMs = urand(CHAOS_PULSE_MIN_MS, CHAOS_PULSE_MAX_MS);
        }

        void CallStormStrikes(Map* map)
        {
            std::vector<Unit*> victims;

            for (ObjectGuid const& guid : _defenderGuids)
            {
                Creature* defender = map->GetCreature(guid);
                if (defender && defender->IsAlive())
                    victims.push_back(defender);
            }

            map->DoForAllPlayers([&](Player* player)
            {
                if (!player || !player->IsAlive() || player->IsGameMaster())
                    return;

                if (player->GetDistance2d(FrontlineAnchor.x, FrontlineAnchor.y) <= 150.0f)
                    victims.push_back(player);
            });

            uint32 const strikes = std::min<uint32>(4u, static_cast<uint32>(victims.size()));
            for (uint32 i = 0; i < strikes; ++i)
            {
                Unit* victim = victims[urand(0u, static_cast<uint32>(victims.size() - 1))];

                Position pos = victim->GetPosition();
                Creature* marker = map->SummonCreature(NPC_IMPACT_MARKER, pos, nullptr, IMPACT_LIFETIME_MS);
                if (!marker)
                    continue;

                marker->setActive(true);
                marker->SetFaction(INVADER_FACTION);
                marker->CastCustomSpell(SPELL_STORM_STRIKE, SPELLVALUE_BASE_POINT0, STORM_STRIKE_BASE_POINTS, victim, true);
            }
        }

        void CallBombRun(Map* map)
        {
            std::vector<Creature*> targets;
            for (ObjectGuid const& guid : _invaderGuids)
            {
                Creature* invader = map->GetCreature(guid);
                if (invader && invader->IsAlive())
                    targets.push_back(invader);
            }

            uint32 const bombs = std::min<uint32>(4u, static_cast<uint32>(targets.size()));
            for (uint32 i = 0; i < bombs; ++i)
            {
                Creature* target = targets[urand(0u, static_cast<uint32>(targets.size() - 1))];
                DropFireNearLine(map, target->GetPositionX(), target->GetPositionY(), DEFENDER_FACTION);
            }
        }

        // A wild tyrant drawn by the blood. It owes nobody anything: its faction
        // is hostile to both armies, so the beach briefly fights a third side.
        void ReleaseRogueTyrant(Map* map)
        {
            InvasionPoint const& entry = RogueTyrantEntryPoints[urand(0u, static_cast<uint32>(RogueTyrantEntryPoints.size() - 1))];

            Creature* tyrant = map->SummonCreature(NPC_ROGUE_TYRANT, ToPosition(entry), nullptr, SUMMON_LIFETIME_MS);
            if (!tyrant)
                return;

            tyrant->setActive(true);
            tyrant->SetFaction(ROGUE_BEAST_FACTION);
            tyrant->SetReactState(REACT_AGGRESSIVE);
            _chaosGuids.push_back(tyrant->GetGUID());

            if (CreatureAI* ai = tyrant->AI())
            {
                ai->DoAction(ACTION_ROGUE_ARRIVES);
                ai->SetData(DATA_MARCH_ROUTE, static_cast<uint32>(ROUTE_LANE_2));
            }
        }

        // ----- The line -----------------------------------------------------------

        void AdjustLine(Map* map, int32 delta)
        {
            if (!IsBattleRunning())
                return;

            int32 const before = _line;
            _line = std::clamp<int32>(_line + delta, 0, LINE_STRENGTH_MAX);

            // Warn once per threshold on the way down.
            if (before > 50 && _line <= 50)
                SendMapAnnouncement(map, "|cFFFF8000[THE LINE]|r The line is buckling! Warden's Landing stands at half strength!");
            else if (before > 25 && _line <= 25)
                SendMapAnnouncement(map, "|cFFFF3030[THE LINE]|r The line is breaking! Hold or the Landing falls!");
        }

        // ----- Stages -------------------------------------------------------------

        void BeginWave(Map* map, InvasionPhase phase)
        {
            if (!map)
                return;

            _phase = phase;
            _spawnedThisWave = 0;
            _waveBroken = false;
            _waveBreakTimerMs = 0;

            switch (phase)
            {
                case INVASION_WAVE_1:
                    _phaseTimerMs = WAVE_1_DURATION_MS;
                    SendMapAnnouncement(map, "|cFFFF8000[LANDFALL]|r The longboats hit the sand! Zandalari scouts storm the beach!");
                    LeaderAnnounce(LEADER_SAY_LANDFALL, map);
                    break;
                case INVASION_WAVE_2:
                    _phaseTimerMs = WAVE_2_DURATION_MS;
                    SendMapAnnouncement(map, "|cFFFF6000[ONSLAUGHT]|r Warriors and berserkers crash into the defense line!");
                    LeaderAnnounce(LEADER_SAY_ONSLAUGHT, map);
                    break;
                case INVASION_WAVE_3:
                    _phaseTimerMs = WAVE_3_DURATION_MS;
                    SendMapAnnouncement(map, "|cFFFF4000[SIEGE]|r Elite blood guard and witch doctors unleash chaos!");
                    LeaderAnnounce(LEADER_SAY_SIEGE, map);
                    break;
                default:
                    return;
            }

            _waveActiveCap = ComputeWaveActiveCap(map, phase);
            _waveSpawnBudget = ComputeWaveSpawnBudget(map, phase);

            LOG_INFO("scripts.dc", "Giant Isles Invasion: entering wave {} (cap={}, budget={}, nearbyPlayers={}, line={})",
                static_cast<uint32>(GetPublicWave()),
                _waveActiveCap,
                _waveSpawnBudget,
                CountNearbyPlayers(map),
                _line);

            _spawnTimerMs = 1000;
            _nudgeTimerMs = NUDGE_INTERVAL_MS;
            _chaosTimerMs = urand(CHAOS_PULSE_MIN_MS, CHAOS_PULSE_MAX_MS);

            if (sWorldState)
                sWorldState->setWorldState(WS_INVASION_WAVE, GetPublicWave());

            // Wave 1 plants the lane standards as the landing force comes ashore.
            if (phase == INVASION_WAVE_1)
                SpawnLaneStandards(map);

            // Immediate opening pressure.
            SpawnWaveTick(map);
            SpawnWaveTick(map);

            // The later stages each open with this assault's war plan.
            if (phase == INVASION_WAVE_2)
                StartWarPlan(map, 0);
            else if (phase == INVASION_WAVE_3)
                StartWarPlan(map, 1);

            BroadcastInvasionEvent(map);
        }

        void ScaleBossHealth(Creature* boss, Map* map)
        {
            uint32 const players = CountNearbyPlayers(map);
            float const multiplier = 1.0f + 0.25f * static_cast<float>(players - 1);
            uint32 const health = static_cast<uint32>(static_cast<float>(boss->GetMaxHealth()) * multiplier);
            boss->SetMaxHealth(health);
            boss->SetHealth(health);
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
            _chaosTimerMs = urand(CHAOS_PULSE_MIN_MS, CHAOS_PULSE_MAX_MS);
            _waveActiveCap = 0;
            _waveSpawnBudget = 0;
            _spawnedThisWave = 0;
            _waveBroken = false;
            _bossGuid.Clear();

            if (sWorldState)
                sWorldState->setWorldState(WS_INVASION_WAVE, 4);

            SendMapAnnouncement(
                map,
                "|cFFFF0000[WARLORD]|r Warlord Zul'mar lands with an honor guard! Hold the beach!");
            LeaderAnnounce(LEADER_SAY_WARLORD, map);
            map->PlayDirectSoundToMap(SOUND_WAR_HORN, INVASION_ZONE_ID);

            // The landing is over once the warlord arrives - clear the longboats.
            DespawnLaneStandards(map);

            Creature* boss = SpawnMarcher(map, InvaderSpawnPoints[2], NPC_WARLORD_ZULMAR, ROUTE_LANE_2);

            if (!boss)
            {
                FailInvasion(map, "|cFFFF3030[INVASION]|r Zul'mar failed to deploy. Event aborted.");
                return;
            }

            _bossGuid = boss->GetGUID();
            ScaleBossHealth(boss, map);

            std::array<std::pair<float, float>, 4> const guardOffsets =
            {{
                { -2.5f, -2.0f },
                {  2.5f, -2.0f },
                { -2.5f,  2.0f },
                {  2.5f,  2.0f },
            }};

            for (auto const& offset : guardOffsets)
            {
                InvasionPoint gp = InvaderSpawnPoints[2];
                gp.x += offset.first;
                gp.y += offset.second;

                SpawnMarcher(map, gp, NPC_ZANDALARI_HONOR_GUARD, ROUTE_LANE_2);
            }

            // Elder Zul'jin answers in person and the whole line goes forward.
            SpawnElderZuljin(map);
            _counterCharged = true;

            BroadcastInvasionEvent(map);
        }

        void SpawnElderZuljin(Map* map)
        {
            Creature* elder = map->SummonCreature(NPC_ELDER_ZULJIN_BATTLE, ToPosition(FrontlineAnchor), nullptr, SUMMON_LIFETIME_MS);
            if (!elder)
                return;

            elder->setActive(true);
            elder->SetFaction(DEFENDER_FACTION);
            elder->SetReactState(REACT_AGGRESSIVE);
            _zuljinGuid = elder->GetGUID();
            _defenderGuids.push_back(elder->GetGUID());

            if (CreatureAI* ai = elder->AI())
                ai->DoAction(ACTION_ZULJIN_CHARGE);
        }

        // The defenders earned the general: both war plans broken, and at most
        // one longboat left afloat.
        bool IsReckoningEarned() const
        {
            return _plans[0].broken && _plans[1].broken && CountScuttledLanes() >= 3 && !_leaderGuid.IsEmpty();
        }

        void StartReckoning(Map* map)
        {
            Creature* leader = map->GetCreature(_leaderGuid);
            if (!leader || !leader->IsAlive())
            {
                EnterVictory(map);
                return;
            }

            LOG_INFO("scripts.dc", "Giant Isles Invasion: reckoning earned, the general comes ashore");

            _phase = INVASION_RECKONING;
            _phaseTimerMs = RECKONING_DURATION_MS;

            SendMapAnnouncement(
                map,
                "|cFFFF0000[RECKONING]|r Every war plan broken, the warlord dead - General Rak'zor comes ashore himself!");
            LeaderAnnounce(LEADER_SAY_RECKONING, map);
            map->PlayDirectSoundToMap(SOUND_VOODOO_STINGER, INVASION_ZONE_ID);

            if (CreatureAI* ai = leader->AI())
                ai->DoAction(ACTION_LEADER_COME_ASHORE);

            ScaleBossHealth(leader, map);

            if (Creature* elder = map->GetCreature(_zuljinGuid))
                if (CreatureAI* ai = elder->AI())
                    ai->DoAction(ACTION_ZULJIN_RECKONING);

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

            LOG_INFO("scripts.dc", "Giant Isles Invasion: victory state entered (kills={}, generalSlain={})", _killCount, _generalSlain);

            if (sWorldState)
            {
                sWorldState->setWorldState(WS_INVASION_ACTIVE, 0);
                sWorldState->setWorldState(WS_INVASION_WAVE, 0);
                sWorldState->setWorldState(WS_INVASION_KILLS, _killCount);
            }

            SendMapAnnouncement(
                map,
                _generalSlain
                    ? "|cFF40FF40[TOTAL VICTORY]|r General Rak'zor is dead! The Blood Tide breaks on Seeping Shores!"
                    : "|cFF40FF40[VICTORY]|r Warlord Zul'mar is defeated. Seeping Shores holds!");

            if (!_generalSlain)
                LeaderAnnounce(LEADER_SAY_RETREAT, map);

            // The general goes back to his ship whenever the battle ends with
            // him ashore and alive.
            if (Creature* leader = map->GetCreature(_leaderGuid))
                if (leader->IsAlive())
                    if (CreatureAI* ai = leader->AI())
                        ai->DoAction(ACTION_LEADER_STAND_DOWN);

            if (Creature* elder = map->GetCreature(_zuljinGuid))
                if (CreatureAI* ai = elder->AI())
                    ai->DoAction(ACTION_ZULJIN_VICTORY);

            RouteRemainingInvaders(map);
            CelebrateVictory(map);
            RewardParticipants(map, true);
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
                sWorldState->setWorldState(WS_INVASION_ACTIVE, 0);
                sWorldState->setWorldState(WS_INVASION_WAVE, 0);
            }

            SendMapAnnouncement(map, reasonText ? reasonText : "|cFFFF3030[INVASION]|r Defense failed.");
            LeaderAnnounce(LEADER_SAY_TRIUMPH, map);

            if (Creature* leader = map->GetCreature(_leaderGuid))
                if (leader->IsAlive())
                    if (CreatureAI* ai = leader->AI())
                        ai->DoAction(ACTION_LEADER_STAND_DOWN);

            RewardParticipants(map, false);
            AdjustCampaign(map, /*victory*/ false);
            BroadcastInvasionEvent(map);
        }

        // Whatever survives the warlord loses its nerve and breaks for the boats.
        void RouteRemainingInvaders(Map* map)
        {
            for (ObjectGuid const& guid : _invaderGuids)
            {
                Creature* invader = map->GetCreature(guid);
                if (!invader || !invader->IsAlive())
                    continue;

                invader->SetReactState(REACT_PASSIVE);
                invader->AttackStop();
                invader->CombatStop(true);
                invader->SetFaction(FACTION_FRIENDLY);
                invader->GetMotionMaster()->Clear();
                invader->GetMotionMaster()->MovePoint(0, InvaderSpawnPoints[0].x, InvaderSpawnPoints[0].y, InvaderSpawnPoints[0].z);
                invader->DespawnOrUnsummon(12s);
            }
        }

        void CelebrateVictory(Map* map)
        {
            for (ObjectGuid const& guid : _defenderGuids)
            {
                Creature* defender = map->GetCreature(guid);
                if (!defender || !defender->IsAlive())
                    continue;

                defender->HandleEmoteCommand(EMOTE_ONESHOT_CHEER);
                defender->CastSpell(defender, SPELL_VICTORY_FIREWORK, true);
            }
        }

        void RewardParticipants(Map* map, bool victory)
        {
            if (!map)
                return;

            uint32 const foothold = GetCampaignFoothold();
            uint32 plansBroken = 0;
            for (PlanRuntime const& plan : _plans)
            {
                if (plan.broken)
                    ++plansBroken;
            }

            map->DoForAllPlayers([&](Player* player)
            {
                if (!player || !player->IsInWorld() || !player->GetSession())
                    return;

                if (player->GetMapId() != MAP_GIANT_ISLES || player->GetSession()->IsBot())
                    return;

                uint32 personal = 0;
                auto itr = _contribution.find(player->GetGUID());
                if (itr != _contribution.end())
                    personal = itr->second;

                // Dying on the sand doesn't forfeit anything, and neither does
                // spending the battle at a far-off bunker; only spectators from a
                // safe distance go without.
                bool const atTheFront = player->GetDistance2d(FrontlineAnchor.x, FrontlineAnchor.y) <= FRONTLINE_REWARD_RADIUS;
                if (personal == 0 && (!victory || !atTheFront))
                    return;

                // War-Tokens: a flat showing-up reward plus contribution, scaled up
                // by how dug-in the enemy was and how much of its plan the team
                // tore apart. A defeat still pays a quarter: they bled here too.
                uint32 tokens = 5u + std::min<uint32>(personal, 40u) + (2u * foothold) + (5u * plansBroken);
                if (_generalSlain)
                    tokens += 25u;

                if (!victory)
                    tokens = std::max<uint32>(tokens / 4u, 1u);

                // DistributeItem mails the reward on full bags - no silent token loss.
                DarkChaos::CrossSystem::GetRewardDistributor()->DistributeItem(
                    player, WAR_TOKEN_ITEM, tokens, DarkChaos::CrossSystem::SystemId::None, "giant_isles_invasion");

                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Invasion]|r {}. Contribution: {}. Awarded {} War-Tokens.",
                    victory ? "Beach secured" : "The line fell, but you held your ground", personal, tokens);
            });
        }

        void CleanupTrackedSummons(Map* map)
        {
            if (!map)
            {
                _invaderGuids.clear();
                _defenderGuids.clear();
                _guardGuids.clear();
                _chaosGuids.clear();
                _bossGuid.Clear();
                _zuljinGuid.Clear();
                _behemothGuid.Clear();
                for (PlanRuntime& plan : _plans)
                    plan = PlanRuntime();
                for (ObjectGuid& g : _standardGuids)
                    g.Clear();
                return;
            }

            auto despawnAll = [map](std::vector<ObjectGuid> const& guids)
            {
                for (ObjectGuid const& guid : guids)
                {
                    if (Creature* c = map->GetCreature(guid))
                        c->DespawnOrUnsummon(1s);
                }
            };

            despawnAll(_invaderGuids);
            despawnAll(_defenderGuids);
            despawnAll(_chaosGuids);

            for (PlanRuntime& plan : _plans)
            {
                despawnAll(plan.objectives);
                despawnAll(plan.support);
                plan = PlanRuntime();
            }

            StandDownGuards(map);
            DespawnLaneStandards(map);

            _invaderGuids.clear();
            _defenderGuids.clear();
            _chaosGuids.clear();
            _bossGuid.Clear();
            _zuljinGuid.Clear();
            _behemothGuid.Clear();
        }

        void FinalizeEvent(Map* map)
        {
            ClearBloodTideAtmosphere(map);
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
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "How goes the war?", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);

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
                        "Break their war plans, cut down their standards and slay Warlord Zul'mar.");
                    break;

                case GOSSIP_ACTION_INFO_DEF + 4:
                    ChatHandler(player->GetSession()).SendSysMessage(sGiantIslesInvasion->BuildWarStatus().c_str());
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
// dc_giant_isles_invasion_npcs.cpp and the war front. (Anonymous-namespace
// names such as sGiantIslesInvasion remain visible at file scope for the rest
// of the TU.)
bool GI_IsInvasionActive()
{
    return sGiantIslesInvasion && sGiantIslesInvasion->IsActive();
}

bool GI_IsBattleRunning()
{
    return sGiantIslesInvasion && sGiantIslesInvasion->IsBattleRunning();
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

void GI_NotifyGeneralDeath()
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->NotifyGeneralKilled();
}

void GI_InvaderReachedLine(Creature* invader)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->InvaderReachedLine(invader);
}

void GI_DefenderDied(Creature* defender)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->DefenderDied(defender);
}

void GI_ObjectiveDestroyed(Creature* objective, std::vector<ObjectGuid> const& attackers)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->ObjectiveDestroyed(objective, attackers);
}

void GI_CreditParticipants(Creature* victim, std::vector<ObjectGuid> const& attackers)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->CreditParticipants(victim, attackers);
}

void GI_CallWarlordBeast(Creature* warlord)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->CallWarlordBeast(warlord);
}

bool GI_HasRoomForWarBeast(Map* map)
{
    return sGiantIslesInvasion && sGiantIslesInvasion->HasRoomForWarBeast(map);
}

uint32 GI_GetCampaignFoothold()
{
    return sGiantIslesInvasion ? sGiantIslesInvasion->GetFoothold() : 0;
}

void GI_AddWarEffort(uint32 points)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->AddWarEffort(points);
}

void GI_NotifyWarGodSlain(Map* map)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->WarGodSlain(map);
}

std::string GI_BuildWarStatus()
{
    return sGiantIslesInvasion ? sGiantIslesInvasion->BuildWarStatus() : std::string();
}

void AddSC_giant_isles_invasion()
{
    new npc_invasion_horn();
    new giant_isles_invasion();
    GI_RegisterInvasionNpcs();
    GI_RegisterWarFront();

    LOG_INFO("scripts.dc", "Giant Isles Invasion: the Blood Tide loaded");
}
