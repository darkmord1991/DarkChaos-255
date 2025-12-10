/*
 * Giant Isles - Invasion: Zandalari Incursion
 * Spawn Points:
 *   Middle: X: 5809.59 Y: 1200.97 Z: 7.04 O: 1.94
 *   Right:  X: 5844.46 Y: 1215.58 Z: 10.58 O: 2.29
 *   Left:   X: 5785.77 Y: 1203.52 Z: 2.84 O: 1.55
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "ScriptedCreature.h"
#include "GameTime.h"
#include "World.h"
#include "WorldState.h"
#include "Map.h"
#include "MapMgr.h"
#include <map>
#include "InstanceScript.h"
#include "ObjectAccessor.h"
#include "Chat.h"
#include "Log.h"
#include "../AddonExtension/DCAddonNamespace.h"
#include "../Seasons/SeasonalRewardSystem.h"
#include <algorithm>
#include "Random.h"
#include <sstream>
#include <atomic>

// ============================================================================
// INVASION CONSTANTS
// ============================================================================

enum InvasionData
{
    // Map and Zone
    MAP_GIANT_ISLES             = 1405,
    AREA_SEEPING_SHORES         = 5010,

    // Invasion Trigger
    NPC_INVASION_HORN           = 400325,

    // Wave 1: Scout Party (6 spawns per point = 18 total)
    NPC_ZANDALARI_INVADER       = 400326,
    NPC_ZANDALARI_SCOUT         = 400327,
    NPC_ZANDALARI_SPEARMAN      = 400328,

    // Wave 2: Warriors (8 spawns per point = 24 total)
    NPC_ZANDALARI_WARRIOR       = 400329,
    NPC_ZANDALARI_BERSERKER     = 400330,
    NPC_ZANDALARI_SHADOW_HUNTER = 400331,

    // Wave 3: Elite Squad (10 spawns per point = 30 total)
    NPC_ZANDALARI_BLOOD_GUARD   = 400332,
    NPC_ZANDALARI_WITCH_DOCTOR  = 400333,
    NPC_ZANDALARI_BEAST_TAMER   = 400334,
    NPC_ZANDALARI_WAR_RAPTOR    = 400335, // Summoned by Beast Tamer

    // Wave 4: Boss Wave
    NPC_WARLORD_ZULMAR          = 400336, // Invasion Commander (boss)
    NPC_ZANDALARI_HONOR_GUARD   = 400337, // Boss guards (4 total)
    NPC_ZANDALARI_INVASION_LEADER = 400338, // Ship Commander (Announcer)

    // Defender NPCs (Friendly)
    NPC_PRIMAL_WARDEN           = 401000, // Basic guard
    NPC_PRIMAL_WARDEN_SERGEANT  = 401001, // Elite guard
    NPC_PRIMAL_WARDEN_MARKSMAN  = 401002, // Ranged guard
    NPC_PRIMAL_WARDEN_CAPTAIN   = 401003, // Commander

    // Timers
    INVASION_COOLDOWN           = 2 * HOUR,  // 2 hours between invasions (Seconds)
    INVASION_WARNING_TIME       = 30 * IN_MILLISECONDS,  // 30 sec warning before start
    WAVE_1_DURATION             = 2 * MINUTE * IN_MILLISECONDS,  // Scout wave (fast, weak)
    WAVE_2_DURATION             = 3 * MINUTE * IN_MILLISECONDS,  // Warrior wave
    WAVE_3_DURATION             = 4 * MINUTE * IN_MILLISECONDS,  // Elite wave
    WAVE_4_DURATION             = 6 * MINUTE * IN_MILLISECONDS,  // Boss wave
    INVASION_TOTAL_TIME         = 15 * MINUTE * IN_MILLISECONDS,  // Total event time

    // Spawn timers within waves (how often to spawn new enemies)
    SPAWN_DELAY_WAVE_1          = 3 * IN_MILLISECONDS,  // Every 3 seconds
    SPAWN_DELAY_WAVE_2          = 4 * IN_MILLISECONDS,  // Every 4 seconds
    SPAWN_DELAY_WAVE_3          = 5 * IN_MILLISECONDS,  // Every 5 seconds
    SPAWN_DELAY_BOSS            = 0,  // Boss spawns once

    // World states for tracking
    WORLD_STATE_INVASION_ACTIVE = 20000,
    WORLD_STATE_INVASION_WAVE   = 20001,
    WORLD_STATE_INVASION_KILLS  = 20002,

    // Quest/Rewards
    SPELL_INVASION_REWARD_BUFF  = 90010, // TODO: Create custom buff spell
    ITEM_INVASION_TOKEN         = 90001, // TODO: Create invasion token item
};


enum InvasionPhase
{
    INVASION_INACTIVE           = 0,
    INVASION_WAVE_1             = 1,
    INVASION_WAVE_2             = 2,
    INVASION_WAVE_3             = 3,
    INVASION_WAVE_4_BOSS        = 4,
    INVASION_VICTORY            = 5,
    INVASION_FAILED             = 6,
};

enum InvasionTexts
{
    // Zone-wide announcements
    SAY_INVASION_WARNING        = 0,  // 30 sec before start
    SAY_INVASION_START          = 1,  // Wave 1 begins
    SAY_WAVE_2_START            = 2,  // Warriors arrive
    SAY_WAVE_3_START            = 3,  // Elites arrive
    SAY_WAVE_4_BOSS             = 4,  // Boss arrives
    SAY_INVASION_VICTORY        = 5,  // Players win
    SAY_INVASION_FAILED         = 6,  // Defenders die
};

enum BossYells
{
    YELL_BOSS_AGGRO             = 0,  // Boss enters combat
    YELL_BOSS_ENRAGE            = 1,  // Boss at 25% HP
    YELL_BOSS_SLAY              = 2,  // Boss kills player
    YELL_BOSS_DEATH             = 3,  // Boss dies
};

enum InvaderYells
{
    YELL_INVADER_AGGRO          = 0,  // Random aggro yells
    YELL_INVADER_DEATH          = 1,  // Death cry
};

// Unique event identifier used by DC addon protocol (shared between spawns and status updates)
constexpr uint32 GIANT_ISLES_INVASION_EVENT_ID = 1405001;

// Spawn coordinates for the three attack points
struct InvasionSpawnPoint
{
    float x, y, z, o;
    std::string name;
};

constexpr uint32 MAX_ACTIVE_INVADERS = 20; // safety cap to avoid uncontrolled buildup

const InvasionSpawnPoint SPAWN_POINTS[5] =
{
    { 5838.9897f, 1180.7533f, 7.560014f, 2.3572648f, "Spawn 1" },
    { 5809.9420f, 1158.8385f, 6.1723530f, 1.4477761f, "Spawn 2" },
    { 5783.3540f, 1188.6102f, 2.4203668f, 1.1391146f, "Spawn 3" },
    { 5766.6455f, 1156.6140f, 1.4760970f, 1.6464609f, "Spawn 4" },
    { 5814.8574f, 1173.9581f, 7.8875175f, 1.9315608f, "Spawn 5" }
};

// Target waypoints - where invaders move to (defensive line)
const InvasionSpawnPoint TARGET_POINTS[3] =
{
    { 5753.34f, 1319.46f, 23.34f, 5.43f, "Left Defense Line" },   // Left target
    { 5769.76f, 1322.34f, 24.64f, 5.91f, "Center Defense Line" }, // Center target  
    { 5795.22f, 1318.57f, 27.29f, 4.13f, "Right Defense Line" }   // Right target
};

// Defender spawn points (around the beach, facing outward)
const InvasionSpawnPoint DEFENDER_POINTS[4] =
{
    { 5774.3030f, 1295.2063f, 13.849159f, 4.7393794f, "Defender 1" },
    { 5787.0960f, 1291.3738f, 14.315049f, 4.3427534f, "Defender 2" },
    { 5762.5030f, 1285.5364f, 11.072120f, 5.5499110f, "Defender 3" },
    { 5770.7040f, 1281.0323f, 9.5231530f, 5.6661500f, "Defender 4" }
};

// Cooldown in milliseconds between status broadcasts to prevent spam
constexpr uint32 EVENT_STATUS_BROADCAST_COOLDOWN_MS = 2000;
// Cooldown for ChatHandler world announcements (ms) to prevent duplicate world text spam
constexpr uint32 EVENT_ANNOUNCE_COOLDOWN_MS = 2000;

// ============================================================================
// INVASION COMMANDER BOSS - Warlord Zul'mar
// ============================================================================

enum WarlordSpells
{
    SPELL_MORTAL_STRIKE         = 16856,  // Reduces healing
    SPELL_WHIRLWIND             = 15589,  // AoE melee
    SPELL_COMMANDING_SHOUT      = 32064,  // Buff to allies
    SPELL_ENRAGE                = 8599,   // Enrage at low HP
};

enum WarlordEvents
{
    EVENT_MORTAL_STRIKE         = 1,
    EVENT_WHIRLWIND             = 2,
    EVENT_COMMANDING_SHOUT      = 3,
    EVENT_CHECK_GUARDS          = 4,
};

// ============================================================================
// FORWARD DECLARATIONS
// ============================================================================

// Global pointer to the active map script (Singleton-like for World Map)
class giant_isles_invasion;
static giant_isles_invasion* sGiantIslesInvasion = nullptr;

// Free helper wrapper that allows AIs to call this early. Forwards to the map script instance if loaded,
// or falls back to immediate ChatHandler call if not (should be rare during initialization).
static void SafeWorldAnnounce(Map* map, const char* text);

// Helper to avoid circular-forward-declaration issues: call this from AIs
void GI_TrackPlayerKill(ObjectGuid playerGuid);
void GI_RegisterSummonedInvader(Creature* creature);
void GI_MaintainBossGuards(Map* map);
void GI_BroadcastSpawn(Map* map, Creature* creature, uint8 waveId = 0, int8 laneIndex = -1);
InvasionPhase GI_GetCurrentPhase();

// ============================================================================
// INVASION MOB AI - Generic script for tracking player participation
// ============================================================================

class npc_invasion_mob : public CreatureScript
{
public:
    npc_invasion_mob() : CreatureScript("npc_invasion_mob") { }

    struct npc_invasion_mobAI : public ScriptedAI
    {
        npc_invasion_mobAI(Creature* creature) : ScriptedAI(creature) { }

        void Reset() override
        {
            CleanupSummons();
        }

        void JustEngagedWith(Unit* who) override
        {
            if (me->GetEntry() == NPC_ZANDALARI_BEAST_TAMER && who)
                SummonWarRaptors(who);
        }

        void JustDied(Unit* killer) override
        {
            DespawnSummons();

            // Regular invader killed - track single kill for the player
            if (killer)
            {
                Player* player = killer->ToPlayer();
                if (!player)
                    if (Unit* owner = killer->GetOwner())
                        player = owner->ToPlayer();

                if (player)
                    GI_TrackPlayerKill(player->GetGUID());
            }
        }

    private:
        std::vector<ObjectGuid> _raptorGuids;

        void CleanupSummons()
        {
            if (_raptorGuids.empty())
                return;

            Map* map = me->GetMap();
            _raptorGuids.erase(std::remove_if(_raptorGuids.begin(), _raptorGuids.end(), [map](const ObjectGuid& guid)
            {
                if (!map)
                    return true;
                Creature* summon = map->GetCreature(guid);
                return !summon || !summon->IsAlive();
            }), _raptorGuids.end());
        }

        void DespawnSummons()
        {
            if (_raptorGuids.empty())
                return;

            Map* map = me->GetMap();
            if (!map)
            {
                _raptorGuids.clear();
                return;
            }

            for (ObjectGuid guid : _raptorGuids)
                if (Creature* summon = map->GetCreature(guid))
                    summon->DespawnOrUnsummon(5s);

            _raptorGuids.clear();
        }

        void SummonWarRaptors(Unit* target)
        {
            CleanupSummons();

            Map* map = me->GetMap();
            if (!map)
                return;

            constexpr uint8 maxRaptors = 2;
            while (_raptorGuids.size() < maxRaptors)
            {
                Position spawn = me->GetPosition();
                spawn.m_positionX += frand(-2.0f, 2.0f);
                spawn.m_positionY += frand(-2.0f, 2.0f);

                Creature* raptor = nullptr;
                for (uint8 attempt = 1; attempt <= 3 && !raptor; ++attempt)
                {
                    Position attemptPos = spawn;
                    if (attempt > 1)
                    {
                        attemptPos.m_positionX += frand(-0.5f, 0.5f);
                        attemptPos.m_positionY += frand(-0.5f, 0.5f);
                    }
                    raptor = me->SummonCreature(NPC_ZANDALARI_WAR_RAPTOR, attemptPos, TEMPSUMMON_CORPSE_DESPAWN, 10 * IN_MILLISECONDS);
                    if (raptor)
                        LOG_WARN("scripts", "Giant Isles Invasion: Beast Tamer raptor spawn attempt {}/3 failed for parent {}", attempt, me->GetGUID().ToString());
                }
                        // Use helper to avoid requiring class definition in this AI file
                        GI_BroadcastSpawn(map, raptor, static_cast<uint8>(GI_GetCurrentPhase()), -1);
                if (raptor)
                {
                    LOG_INFO("scripts", "Giant Isles Invasion: Beast Tamer {} summoned raptor {} at {}", me->GetGUID().ToString(), raptor->GetGUID().ToString(), raptor->GetPosition().ToString());
                    _raptorGuids.push_back(raptor->GetGUID());
                    raptor->SetFaction(16);
                    raptor->SetReactState(REACT_AGGRESSIVE);
                    if (target)
                        raptor->AI()->AttackStart(target);
                    raptor->AI()->DoZoneInCombat();
                    GI_RegisterSummonedInvader(raptor);
                }
                else
                {
                    break;
                }
            }
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_invasion_mobAI(creature);
    }
};

// ============================================================================
// INVASION LEADER (Announcer) - General Rak'zor
// ============================================================================

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
            me->SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC);
        }

        void InitializeAI() override
        {
            Reset();
        }

        // Called by map script to make announcements
        void DoAnnouncement(uint8 waveId)
        {
            switch (waveId)
            {
                case 0: // Start / Warning
                    me->Yell("Warriors of Zandalar! The shores are ours! Leave none alive!", LANG_UNIVERSAL);
                    me->PlayDirectSound(8856); // Troll Aggro
                    break;
                case 1: // Wave 1
                    me->Yell("Scouts, forward! Mark their positions! Let the slaughter begin!", LANG_UNIVERSAL);
                    break;
                case 2: // Wave 2
                    me->Yell("Berserkers! Crush their defenses! Show them the fury of the Zandalari!", LANG_UNIVERSAL);
                    break;
                case 3: // Wave 3
                    me->Yell("Elites, advance! Bring down their walls with dark voodoo!", LANG_UNIVERSAL);
                    break;
                case 4: // Boss
                    me->Yell("Warlord Zul'mar, the honor is yours! Finish them!", LANG_UNIVERSAL);
                    break;
                case 5: // Victory (Players win)
                    me->Yell("Impossible! Retreat! We will return!", LANG_UNIVERSAL);
                    me->DespawnOrUnsummon(5s);
                    break;
                case 6: // Defeat (Players lose)
                    me->Yell("Victory for Zandalar! This island is ours!", LANG_UNIVERSAL);
                    me->DespawnOrUnsummon(10s);
                    break;
            }
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_invasion_leaderAI(creature);
    }
};

// ============================================================================
// INVASION COMMANDER (BOSS) - Warlord Zul'mar
// ============================================================================

class npc_invasion_commander : public CreatureScript
{
public:
    npc_invasion_commander() : CreatureScript("npc_invasion_commander") { }

    struct npc_invasion_commanderAI : public ScriptedAI
    {
        npc_invasion_commanderAI(Creature* creature) : ScriptedAI(creature) { }

        EventMap events;
        bool enraged;

        void Reset() override
        {
            events.Reset();
            enraged = false;
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            events.ScheduleEvent(EVENT_MORTAL_STRIKE, 8s);
            events.ScheduleEvent(EVENT_WHIRLWIND, 15s);
            events.ScheduleEvent(EVENT_COMMANDING_SHOUT, 5s);
            events.ScheduleEvent(EVENT_CHECK_GUARDS, 2s);

            // Dramatic boss yell
            me->Yell("You dare challenge Zul'mar?! Your bones will join the pile!", LANG_UNIVERSAL);
            me->PlayDirectSound(8856);  // Troll male aggro
        }

        void DamageTaken(Unit* /*attacker*/, uint32& /*damage*/, DamageEffectType /*damagetype*/, SpellSchoolMask /*damageSchoolMask*/) override
        {
            if (!enraged && me->HealthBelowPct(25))
            {
                enraged = true;
                DoCastSelf(SPELL_ENRAGE);
                me->Yell("You will ALL DIE! For Zandalar!", LANG_UNIVERSAL);
                me->PlayDirectSound(8863);  // Troll male roar
            }
        }

        void JustDied(Unit* killer) override
        {
            // Track player participation (Boss kill counts as 10 kills)
            if (killer)
            {
                Player* player = killer->ToPlayer();
                if (!player)
                    if (Unit* owner = killer->GetOwner())
                        player = owner->ToPlayer();
                if (player)
                {
                    // Give extra credit for boss kill - count as 10 kills
                    for (int i = 0; i < 10; ++i)
                        GI_TrackPlayerKill(player->GetGUID());
                }
            }

            // Dramatic death yell
            me->Yell("The Zandalari... will return... you have not won...", LANG_UNIVERSAL);
            
            // Notify: perform basic victory actions (inline fallback)
            if (Map* map = me->GetMap())
            {
                SafeWorldAnnounce(map, "|cFF00FF00[VICTORY!]|r Warlord Zul'mar has fallen! The Zandalari invasion is repelled!");
                
                // Victory sound
                map->DoForAllPlayers([](Player* player)
                {
                    player->PlayDirectSound(8455);  // Victory fanfare
                });

                // Set cooldown timestamp in world state
                sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE + 10, static_cast<uint32>(GameTime::GetGameTime().count()));

                // Placeholder for reward distribution
                LOG_INFO("scripts", "Giant Isles Invasion: Boss killed, victory triggered by boss {}", me->GetEntry());
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
                    case EVENT_MORTAL_STRIKE:
                        DoCastVictim(SPELL_MORTAL_STRIKE);
                        events.ScheduleEvent(EVENT_MORTAL_STRIKE, 12s);
                        break;
                    case EVENT_WHIRLWIND:
                        DoCastAOE(SPELL_WHIRLWIND);
                        events.ScheduleEvent(EVENT_WHIRLWIND, 20s);
                        break;
                    case EVENT_COMMANDING_SHOUT:
                        DoCastAOE(SPELL_COMMANDING_SHOUT);
                        events.ScheduleEvent(EVENT_COMMANDING_SHOUT, 30s);
                        break;
                    case EVENT_CHECK_GUARDS:
                        GI_MaintainBossGuards(me->GetMap());
                        events.ScheduleEvent(EVENT_CHECK_GUARDS, 15s);
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

// ============================================================================
// MAP SCRIPT - Invasion Event Manager
// ============================================================================

class giant_isles_invasion : public WorldMapScript
{
public:
    giant_isles_invasion() : WorldMapScript("giant_isles_invasion", MAP_GIANT_ISLES),
        _invasionPhase(INVASION_INACTIVE), _waveTimer(0), _spawnTimer(0), _killCount(0), _bossGUID(), _bossActivated(false),
        _broadcastedFailure(false), _broadcastedVictory(false), _spawnCounter(0), _failInvocationCount(0), _victoryInvocationCount(0), _spawnIndex(), _lastEventStatusBroadcastTime(0), _lastEventAnnouncementTime(0), _isFailing(false)
    {
        sGiantIslesInvasion = this;
    }

    ~giant_isles_invasion() override
    {
        if (sGiantIslesInvasion == this)
            sGiantIslesInvasion = nullptr;
    }

    void OnDestroy(Map* map) override
    {
        CleanupInvasion(map);
    }

    // Ensure any previous event state is cleaned up on map creation (server restart or map reload)
    void OnCreate(Map* map) override
    {
        // Reset world-state flags so the event doesn't auto-run or spam on restart.
        if (sWorldState)
        {
            sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 0);
            sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 0);
            sWorldState->setWorldState(WORLD_STATE_INVASION_KILLS, 0);
        }

        // Attempt to clean up any leftover creatures or state for this map instance
        CleanupInvasion(map);
        // Also clear internal tracking structures in case of hot reload
        _invasionPhase = INVASION_INACTIVE;
        _waveTimer = 0;
        _spawnTimer = 0;
        _invaderNudgeTimer = 0;
        _killCount = 0;
        _bossGUID.Clear();
        _leaderGUID.Clear();
        _bossGuardGuids.clear();
        _invaderGuids.clear();
        _participantKills.clear();
        _bossActivated = false;
        _spawnCounter = 0;
        _spawnIndex.clear();
        _lastEventAnnouncementTime = 0;
        _lastEventStatusBroadcastTime = 0;
        _failInvocationCount = 0;
        _isFailing.store(false);
        _victoryInvocationCount = 0;

        LOG_INFO("scripts", "Giant Isles Invasion: Map created - event state reset to inactive") ;
    }

    // State variables
    InvasionPhase _invasionPhase;
    uint32 _waveTimer;
    uint32 _spawnTimer;
    uint32 _invaderNudgeTimer;
    uint32 _killCount;
    ObjectGuid _bossGUID;
    ObjectGuid _leaderGUID; // GUID of the ship commander
    std::vector<ObjectGuid> _defenderGuids;
    std::vector<ObjectGuid> _invaderGuids;
    std::vector<ObjectGuid> _bossGuardGuids;
    std::map<ObjectGuid, uint32> _participantKills;
    bool _bossActivated;
    std::atomic<bool> _isFailing;
    bool _broadcastedFailure;
    bool _broadcastedVictory;
    uint32 _spawnCounter;
    uint32 _failInvocationCount;
    uint32 _victoryInvocationCount;
    std::map<ObjectGuid, uint32> _spawnIndex;
    uint64_t _lastEventStatusBroadcastTime;
    uint64_t _lastEventAnnouncementTime;

    // Maintain boss guards is defined inline below to manage guard AI and respawn
    // RegisterSummonedInvader is defined inline below as a convenience

    void StartInvasion(Player* starter, Map* map)
    {
        if (_invasionPhase != INVASION_INACTIVE)
            return;

        sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 1);
        sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 0);
        sWorldState->setWorldState(WORLD_STATE_INVASION_KILLS, 0);

        _invasionPhase = INVASION_INACTIVE;  // Will change to WAVE_1 after warning
        _waveTimer = INVASION_WARNING_TIME;
        _spawnTimer = 0;
        _invaderNudgeTimer = 2 * IN_MILLISECONDS;
        _killCount = 0;
        _bossGUID.Clear();
        _leaderGUID.Clear();
        _bossGuardGuids.clear();
        _bossActivated = false;
        _spawnCounter = 0; // reset spawn numbering for clean debugging output
        _broadcastedFailure = false;
        _broadcastedVictory = false;
        _lastEventAnnouncementTime = 0; // clear announcement cooldown for fresh event
        _failInvocationCount = 0;
        _victoryInvocationCount = 0;

        // Dramatic warning announcement (suppress rapid duplicates)
        {
            uint64_t now = GameTime::GetGameTime().count();
            if (_lastEventAnnouncementTime == 0 || (now - _lastEventAnnouncementTime) >= EVENT_ANNOUNCE_COOLDOWN_MS)
            {
                SafeWorldAnnounce("|cFFFF0000[INVASION WARNING]|r War drums echo across Seeping Shores! The Zandalari fleet approaches!");
                _lastEventAnnouncementTime = now;
            }
            else
            {
                LOG_DEBUG("scripts", "Giant Isles Invasion: Warning announcement suppressed due to cooldown ({}ms)", (now - _lastEventAnnouncementTime));
            }
        }
        
        // Play war horn sound to all players in zone
        map->DoForAllPlayers([](Player* player)
        {
            player->PlayDirectSound(6674);  // War horn sound
        });

        SpawnDefenders(map);
        SpawnBossSpectators(map);
        SpawnInvasionLeader(map); // Spawn the announcer
        
        // Initial announcement
        BossWaveComment(0);
        LeaderAnnounce(0);
        BroadcastEventStatus(map);

        LOG_INFO("scripts", "Giant Isles Invasion: Event starting with 30s warning. Triggered by {}", starter ? starter->GetName() : "System");
    }

    void StopInvasion(Map* map)
    {
        CleanupInvasion(map);
        BroadcastEventRemoval(map, "cancelled");
    }
    void OnCreatureKill(Creature* victim)
    {
        if (IsInvasionMob(victim->GetEntry()))
        {
            _killCount++;
            sWorldState->setWorldState(WORLD_STATE_INVASION_KILLS, _killCount);
        }
    }

    void TrackPlayerKill(ObjectGuid playerGuid)
    {
        _participantKills[playerGuid]++;
    }

    void OnBossKilled()
    {
        _victoryInvocationCount++;
        if (_victoryInvocationCount > 1)
        {
            LOG_WARN("scripts", "Giant Isles Invasion: OnBossKilled invoked multiple times (count={})", _victoryInvocationCount);
            // Prevent double victory processing
            if (_broadcastedVictory)
                return;
        }
        _broadcastedVictory = true;
        _invasionPhase = INVASION_VICTORY;
        _waveTimer = 10 * IN_MILLISECONDS;
        {
            uint64_t now = GameTime::GetGameTime().count();
            if (_lastEventAnnouncementTime == 0 || (now - _lastEventAnnouncementTime) >= EVENT_ANNOUNCE_COOLDOWN_MS)
            {
                SafeWorldAnnounce("Victory! The Zandalari invasion has been repelled!");
                _lastEventAnnouncementTime = now;
            }
            else
            {
                LOG_DEBUG("scripts", "Giant Isles Invasion: Victory announcement suppressed due to cooldown ({}ms)", (now - _lastEventAnnouncementTime));
            }
        }
        RewardParticipants();
        sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE + 10, static_cast<uint32>(GameTime::GetGameTime().count()));
        if (Map* map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0))
        {
            for (const ObjectGuid& guid : _bossGuardGuids)
                if (Creature* guard = map->GetCreature(guid))
                    guard->DespawnOrUnsummon(5s);
            
            // Leader retreat
            BossWaveComment(5);
            LeaderAnnounce(5);
                BroadcastEventStatus(map, "victory");
                BroadcastEventRemoval(map, "victory");
        }
        _bossGuardGuids.clear();
        _bossGUID.Clear();
        _leaderGUID.Clear();
        _bossActivated = false;
        LOG_INFO("scripts", "Giant Isles Invasion: Event completed successfully");
    }

    // Public method for GM commands to manually trigger waves
    void ForceSpawnWave(uint32 waveNum, Map* map)
    {
        if (waveNum < 1 || waveNum > 4)
            return;
            
        // Set phase to just before the requested wave, then advance
        _invasionPhase = static_cast<InvasionPhase>(waveNum - 1);
        AdvanceWave(map);
    }

    InvasionPhase GetCurrentPhase() const { return _invasionPhase; }

    uint32 GetActiveInvaderCount(Map* map) const
    {
        if (!map)
            return 0;
        uint32 count = 0;
        for (const ObjectGuid& guid : _invaderGuids)
        {
            if (Creature* inv = map->GetCreature(guid))
                if (inv->IsAlive())
                    ++count;
        }
        return count;
    }

    void OnUpdate(Map* map, uint32 diff) override
    {
        // Allow processing during the 30s warning (phase initially INACTIVE) so waves actually start
        if (_invasionPhase == INVASION_VICTORY)
            return;

        // Wave timer - advance wave when time expires
        if (_waveTimer <= diff)
        {
            LOG_INFO("scripts", "Giant Isles Invasion: Wave timer expired at phase {} (wave state={})", _invasionPhase, sWorldState->getWorldState(WORLD_STATE_INVASION_WAVE));
            AdvanceWave(map);
        }
        else
            _waveTimer -= diff;

        // Spawn timer - spawn new enemies during wave
        if (_invasionPhase >= INVASION_WAVE_1 && _invasionPhase <= INVASION_WAVE_3)
        {
            if (_spawnTimer <= diff)
            {
                SpawnWaveCreatures(map);
                _spawnTimer = GetSpawnDelay();
            }
            else
                _spawnTimer -= diff;
        }

        // Periodically re-issue movement/target commands to idle invaders
        if (_invaderNudgeTimer <= diff)
        {
            NudgeIdleInvaders(map);
            _invaderNudgeTimer = 2 * IN_MILLISECONDS;
        }
        else
            _invaderNudgeTimer -= diff;

        // Check if all defenders died - invasion fails
        // Only fail the invasion if we are actually in a wave or boss phase
        if (CheckDefendersAlive(map) == 0 && _invasionPhase >= INVASION_WAVE_1 && _invasionPhase < INVASION_VICTORY)
            FailInvasion(map);
            
        // Check boss death manually since we don't have InstanceScript hooks
        if (_invasionPhase == INVASION_WAVE_4_BOSS && !_bossGUID.IsEmpty())
        {
            if (Creature* boss = map->GetCreature(_bossGUID))
            {
                if (!boss->IsAlive())
                {
                    OnBossKilled();
                    _bossGUID.Clear(); // Prevent repeated calls
                }
            }
        }
    }

    void AdvanceWave(Map* map)
    {
        switch (_invasionPhase)
        {
            case INVASION_INACTIVE:  // Warning phase complete, start wave 1
                _invasionPhase = INVASION_WAVE_1;
                _waveTimer = WAVE_1_DURATION;
                _spawnTimer = SPAWN_DELAY_WAVE_1;
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 1);
                SafeWorldAnnounce("|cFFFF8000[INVASION - WAVE 1]|r Zandalari scouts storm the beach! Kill them quickly!");
                map->DoForAllPlayers([](Player* player) { player->PlayDirectSound(8459); });  // Battle horn
                // Spawn the first wave batch immediately
                LOG_INFO("scripts", "Giant Isles Invasion: Starting Wave 1");
                SpawnWaveCreatures(map);
                BossWaveComment(1);
                LeaderAnnounce(1);
                BroadcastEventStatus(map);
                break;
                
            case INVASION_WAVE_1:
                _invasionPhase = INVASION_WAVE_2;
                _waveTimer = WAVE_2_DURATION;
                _spawnTimer = SPAWN_DELAY_WAVE_2;
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 2);
                SafeWorldAnnounce("|cFFFF8000[INVASION - WAVE 2]|r Zandalari warriors and berserkers charge! Hold the line!");
                map->DoForAllPlayers([](Player* player) { player->PlayDirectSound(8174); });  // Orc battle cry
                LOG_INFO("scripts", "Giant Isles Invasion: Starting Wave 2");
                SpawnWaveCreatures(map);
                SpawnReinforcements(map);
                BossWaveComment(2);
                LeaderAnnounce(2);
                BroadcastEventStatus(map);
                break;
                
            case INVASION_WAVE_2:
                _invasionPhase = INVASION_WAVE_3;
                _waveTimer = WAVE_3_DURATION;
                _spawnTimer = SPAWN_DELAY_WAVE_3;
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 3);
                SafeWorldAnnounce("|cFFFF4000[INVASION - WAVE 3]|r Elite Blood Guards and Witch Doctors arrive! Beware their dark magic!");
                map->DoForAllPlayers([](Player* player) { player->PlayDirectSound(8212); });  // Troll aggro
                LOG_INFO("scripts", "Giant Isles Invasion: Starting Wave 3");
                SpawnWaveCreatures(map);
                SpawnReinforcements(map);
                BossWaveComment(3);
                LeaderAnnounce(3);
                BroadcastEventStatus(map);
                break;
                
            case INVASION_WAVE_3:
                _invasionPhase = INVASION_WAVE_4_BOSS;
                _waveTimer = WAVE_4_DURATION;
                _spawnTimer = 0;  // No more spawns, only boss
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 4);
                SafeWorldAnnounce("|cFFFF0000[BOSS WAVE]|r Warlord Zul'mar arrives with his honor guard! Defeat him to repel the invasion!");
                map->DoForAllPlayers([](Player* player) { player->PlayDirectSound(8923); });  // Raid warning
                ActivateBossWave(map);
                BossWaveComment(4);
                LeaderAnnounce(4);
                BroadcastEventStatus(map);
                break;
                
            case INVASION_WAVE_4_BOSS:
                // Victory handled in OnBossKilled
                break;
                
            default:
                break;
        }
    }

    void SpawnDefenders(Map* map)
    {
        constexpr uint8 DEFENDER_POINT_COUNT = static_cast<uint8>(std::size(DEFENDER_POINTS));
        for (uint8 i = 0; i < DEFENDER_POINT_COUNT; ++i)
        {
            const InvasionSpawnPoint& point = DEFENDER_POINTS[i];
            uint32 entry = NPC_PRIMAL_WARDEN;
            if (i == 0) entry = NPC_PRIMAL_WARDEN_CAPTAIN;
            else if (i == 1 || i == 3) entry = NPC_PRIMAL_WARDEN_MARKSMAN;
            else if (i == 2) entry = NPC_PRIMAL_WARDEN_SERGEANT;

            Position p(point.x, point.y, point.z, point.o);
            Creature* defender = TrySummonCreature(map, entry, p, 3, 1.5f);
            if (defender)
            {
                _defenderGuids.push_back(defender->GetGUID());
                defender->SetFaction(14);  // Monster faction (hostile to invaders who are faction 16)
                defender->SetReactState(REACT_AGGRESSIVE);
                
                // Move slightly forward to engage
                float x = p.GetPositionX() + 5.0f * cos(p.GetOrientation());
                float y = p.GetPositionY() + 5.0f * sin(p.GetOrientation());
                defender->GetMotionMaster()->MovePoint(0, x, y, p.GetPositionZ());

                LOG_INFO("scripts", "Giant Isles Invasion: Summoned defender entry {} at point {}", entry, i);
                BroadcastSpawn(map, defender, 0, i);
            }
            else
            {
                LOG_WARN("scripts", "Giant Isles Invasion: Failed to summon defender entry {} at point {} pos=({}, {}, {}, {})", entry, i, p.GetPositionX(), p.GetPositionY(), p.GetPositionZ(), p.GetOrientation());
            }
        }
    }

    void SpawnReinforcements(Map* map)
    {
        // Spawn 3 guards running from the village/rear
        Position spawnPos(5809.59f, 1150.0f, 7.5f, 1.94f); // Further back
        for (int i = 0; i < 3; ++i)
        {
            float x = spawnPos.GetPositionX() + (i * 5.0f) - 5.0f;
            Position guardPos(x, spawnPos.GetPositionY(), spawnPos.GetPositionZ(), spawnPos.GetOrientation());
            Creature* guard = TrySummonCreature(map, NPC_PRIMAL_WARDEN, guardPos, 3, 1.5f);
            if (guard)
            {
                _defenderGuids.push_back(guard->GetGUID());
                guard->SetFaction(14);
                guard->SetReactState(REACT_AGGRESSIVE);
                // Run to the front line
                guard->GetMotionMaster()->MovePoint(0, 5809.59f, 1200.0f, 7.0f);
                BroadcastSpawn(map, guard, 0, -1);
            }
        }
        SafeWorldAnnounce("Reinforcements have arrived!");
    }

    void SpawnWaveCreatures(Map* map)
    {
        LOG_INFO("scripts", "Giant Isles Invasion: SpawnWave for phase {}", _invasionPhase);

        // Get the NPC entries for current wave
        std::vector<uint32> waveEntries = GetWaveCreatureEntries();
        if (waveEntries.empty())
        {
            LOG_ERROR("scripts", "Giant Isles Invasion: No wave entries defined for phase {}", _invasionPhase);
            return;
        }

        // Soft cap: if too many invaders are already active, skip spawning this tick
        uint32 activeInvaders = GetActiveInvaderCount(map);
        if (activeInvaders >= MAX_ACTIVE_INVADERS)
        {
            LOG_WARN("scripts", "Giant Isles Invasion: Spawn skipped, active invaders {} >= cap {}", activeInvaders, MAX_ACTIVE_INVADERS);
            return;
        }

        uint8 laneMultiplier = GetLaneSpawnMultiplier();
        if (laneMultiplier == 0)
            laneMultiplier = 1;

        // Total mobs to spawn = 3 (original lanes) * multiplier, but respect cap
        uint32 totalMobs = std::min<uint32>(3 * laneMultiplier, MAX_ACTIVE_INVADERS - activeInvaders);

        LOG_INFO("scripts", "Giant Isles Invasion: Wave {} spawns={} lanesMultiplier={} entries={}", _invasionPhase, totalMobs, laneMultiplier, waveEntries.size());

        constexpr uint8 SPAWN_POINT_COUNT = static_cast<uint8>(std::size(SPAWN_POINTS));

        for (uint32 i = 0; i < totalMobs; ++i)
        {
            // Pick random spawn point
            uint8 spawnIdx = urand(0, SPAWN_POINT_COUNT - 1);
            const InvasionSpawnPoint& spawnPoint = SPAWN_POINTS[spawnIdx];
            
            // Pick random entry from wave entries
            uint32 entry = waveEntries[urand(0, waveEntries.size() - 1)];

            Position p(spawnPoint.x + frand(-1.5f, 1.5f), spawnPoint.y + frand(-1.5f, 1.5f), spawnPoint.z, spawnPoint.o);

            Creature* invader = TrySummonCreature(map, entry, p, 3, 1.5f);
                if (invader)
            {
                RegisterInvader(invader);
                // Pick random target lane (0-2)
                uint8 targetLane = urand(0, 2);

                // Half of the spawns attack immediately; half wait for the nudge cycle
                bool delayed = (i % 2) != 0;
                if (!delayed)
                    CommandInvader(invader, map, targetLane);

                LOG_INFO("scripts", "Giant Isles Invasion: Spawned invader entry {} at spawn {} target {} delayed={} ({})", entry, spawnIdx, targetLane, delayed, invader->GetGUID().ToString());
                BroadcastSpawn(map, invader, static_cast<uint8>(_invasionPhase), targetLane);
            }
            else
            {
                LOG_WARN("scripts", "Giant Isles Invasion: Spawn failed for entry {} at spawn {} pos=({}, {}, {}, {})", entry, spawnIdx, p.GetPositionX(), p.GetPositionY(), p.GetPositionZ(), p.GetOrientation());
            }
        }
    }

    void SpawnBossSpectators(Map* map)
    {
        if (!map)
            return;

        Creature* boss = EnsureBossPresence(map);
        if (!boss)
            return;

        _bossActivated = false;

        // Boss idle location (spectator spot)
        Position bossPos(5823.2993f, 1172.1396f, 8.596341f, 2.1467452f);

        if (!boss->IsWithinDist2d(bossPos.GetPositionX(), bossPos.GetPositionY(), 1.0f))
            boss->NearTeleportTo(bossPos.GetPositionX(), bossPos.GetPositionY(), bossPos.GetPositionZ(), bossPos.GetOrientation());
        boss->SetHomePosition(bossPos);

        ConfigureBossSpectatorState(boss, true);
        BroadcastSpawn(map, boss, static_cast<uint8>(_invasionPhase), 1);

        for (const ObjectGuid& guid : _bossGuardGuids)
            if (Creature* guard = map->GetCreature(guid))
                guard->DespawnOrUnsummon(1s);
        _bossGuardGuids.clear();

        const float guardDistance = 3.0f;
        Position guardPositions[4] =
        {
            { bossPos.GetPositionX(), bossPos.GetPositionY() - guardDistance, bossPos.GetPositionZ(), bossPos.GetOrientation() },
            { bossPos.GetPositionX(), bossPos.GetPositionY() + guardDistance, bossPos.GetPositionZ(), bossPos.GetOrientation() },
            { bossPos.GetPositionX() - guardDistance, bossPos.GetPositionY(), bossPos.GetPositionZ(), bossPos.GetOrientation() },
            { bossPos.GetPositionX() + guardDistance, bossPos.GetPositionY(), bossPos.GetPositionZ(), bossPos.GetOrientation() }
        };

        for (uint8 i = 0; i < 4; ++i)
        {
            Position gp(guardPositions[i].GetPositionX(), guardPositions[i].GetPositionY(), guardPositions[i].GetPositionZ(), guardPositions[i].GetOrientation());
            Creature* guard = TrySummonCreature(map, NPC_ZANDALARI_HONOR_GUARD, gp, 3, 1.0f);
            if (guard)
            {
                ConfigureBossSpectatorState(guard, true);
                guard->SetHomePosition(gp);
                _bossGuardGuids.push_back(guard->GetGUID());
                BroadcastSpawn(map, guard, static_cast<uint8>(_invasionPhase), 1);
            }
        }
    }

    void SpawnInvasionLeader(Map* map)
    {
        if (!map)
            return;

        // Leader is now spawned manually; find the nearest leader to a valid WorldObject source
        WorldObject* source = nullptr;
        Map::PlayerList const& players = map->GetPlayers();
        if (players.begin() != players.end())
            source = players.begin()->GetSource();
        else if (!_bossGUID.IsEmpty())
            source = map->GetCreature(_bossGUID);
        else if (!_defenderGuids.empty())
            source = map->GetCreature(_defenderGuids.front());

        if (!source)
        {
            LOG_WARN("scripts", "Giant Isles Invasion: No valid source to find invasion leader on map {}", map->GetId());
            return;
        }

        if (Creature* leader = GetClosestCreatureWithEntry(source, NPC_ZANDALARI_INVASION_LEADER, 500.0f))
        {
            _leaderGUID = leader->GetGUID();
            LOG_INFO("scripts", "Giant Isles Invasion: Found existing Invasion Leader at {}", leader->GetPosition().ToString());
        }
        else
        {
            LOG_WARN("scripts", "Giant Isles Invasion: Could not find Invasion Leader (Entry: {})", NPC_ZANDALARI_INVASION_LEADER);
        }
    }

    void LeaderAnnounce(uint8 waveId)
    {
        Map* map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);
        if (!map || _leaderGUID.IsEmpty())
            return;

        if (Creature* leader = map->GetCreature(_leaderGUID))
        {
            switch (waveId)
            {
                case 1: leader->Yell("We have sighted scouts! Wards man your posts!", LANG_UNIVERSAL); break;
                case 2: leader->Yell("Warriors! Push back the horde and take no prisoners!", LANG_UNIVERSAL); break;
                case 3: leader->Yell("Elite units incoming! Hold the line and stand firm!", LANG_UNIVERSAL); break;
                case 4: leader->Yell("The Warlord approaches! All hands to battle stations!", LANG_UNIVERSAL); break;
                case 5: leader->Yell("They are defeated! Well fought, defenders!", LANG_UNIVERSAL); break;
                default: leader->Yell("Hold steady! Keep watch for new threats.", LANG_UNIVERSAL); break;
            }
        }
    }

    void ActivateBossWave(Map* map)
    {
        if (!map)
            return;

        Creature* boss = EnsureBossPresence(map);
        if (!boss)
        {
            LOG_ERROR("scripts", "Giant Isles Invasion: Unable to activate boss wave - boss missing");
            return;
        }

        _bossActivated = true;
        ConfigureBossSpectatorState(boss, false);
        RegisterInvader(boss);
        CommandInvader(boss, map, 1);
        // Broadcast boss activation spawn
        BroadcastSpawn(map, boss, static_cast<uint8>(GetCurrentPhase()), 1);

        for (const ObjectGuid& guid : _bossGuardGuids)
        {
            if (Creature* guard = map->GetCreature(guid))
            {
                ConfigureBossSpectatorState(guard, false);
                RegisterInvader(guard);
                CommandInvader(guard, map, 1);
                BroadcastSpawn(map, guard, static_cast<uint8>(GetCurrentPhase()), 1);
            }
        }

        MaintainBossGuards(map);
    }

    Creature* EnsureBossPresence(Map* map)
    {
        if (!map)
            return nullptr;

        Creature* boss = !_bossGUID.IsEmpty() ? map->GetCreature(_bossGUID) : nullptr;
        if (!boss || !boss->IsAlive())
        {
            // Boss spawn location
            Position p(5823.2993f, 1172.1396f, 8.596341f, 2.1467452f);
            boss = TrySummonCreature(map, NPC_WARLORD_ZULMAR, p, 3, 1.0f);
            if (boss)
                _bossGUID = boss->GetGUID();
            else
                LOG_WARN("scripts", "Giant Isles Invasion: Boss spawn failed at {}, retries exhausted", p.ToString());
        }
        return boss;
    }

    void ConfigureBossSpectatorState(Creature* creature, bool spectator)
    {
        if (!creature)
            return;

        constexpr uint32 spectatorFlags = UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC;
        if (spectator)
        {
            // Keep the boss hostile (faction 16) but non-attackable while spectating
            creature->SetFaction(16);
            creature->SetReactState(REACT_PASSIVE);
            creature->AttackStop();
            // Clear the threat list via ThreatMgr; DeleteThreatList was removed/unused.
            creature->GetThreatMgr().ClearAllThreat();
            // Also stop combat to ensure spectator state
            creature->CombatStop();
            creature->SetFlag(UNIT_FIELD_FLAGS, spectatorFlags);
            creature->SetWalk(true);
            creature->GetMotionMaster()->MoveIdle();
            creature->SetHomePosition(creature->GetPosition());
        }
        else
        {
            creature->RemoveFlag(UNIT_FIELD_FLAGS, spectatorFlags);
            creature->SetFaction(16);
            creature->SetReactState(REACT_AGGRESSIVE);
        }
    }

    void BossWaveComment(uint8 waveId)
    {
        Map* map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);
        if (!map)
            return;

        // Try to use the Invasion Leader first
        if (!_leaderGUID.IsEmpty())
        {
            if (Creature* leader = map->GetCreature(_leaderGUID))
            {
                if (leader->IsAlive())
                {
                    if (npc_invasion_leader::npc_invasion_leaderAI* ai = CAST_AI(npc_invasion_leader::npc_invasion_leaderAI, leader->AI()))
                    {
                        ai->DoAnnouncement(waveId);
                        return; // Leader handled it
                    }
                }
            }
        }

        // Fallback to Boss if Leader is missing (e.g. for Boss Wave specific lines)
        if (_bossGUID.IsEmpty())
            return;

        Creature* boss = map->GetCreature(_bossGUID);
        if (!boss)
            return;

        switch (waveId)
        {
            case 1:
                boss->Yell("Scouts, measure their strength. I want every weakness exposed!", LANG_UNIVERSAL);
                break;
            case 2:
                boss->Yell("Hah! Warriors, shatter their shields and bring me their heads!", LANG_UNIVERSAL);
                break;
            case 3:
                boss->Yell("Blood Guard, prepare the ritual drums! Their doom draws near.", LANG_UNIVERSAL);
                break;
            case 4:
                boss->Yell("Enough watching. I will end this assault myself!", LANG_UNIVERSAL);
                break;
            default:
                break;
        }
    }

    std::vector<uint32> GetWaveCreatureEntries() const
    {
        // Return deterministic NPC composition for each wave
        // Each spawn point will get a different NPC type
        switch (_invasionPhase)
        {
            case INVASION_WAVE_1:
                // Scout wave - light forces
                return { NPC_ZANDALARI_INVADER, NPC_ZANDALARI_SCOUT, NPC_ZANDALARI_SPEARMAN };
            
            case INVASION_WAVE_2:
                // War party - heavier forces
                return { NPC_ZANDALARI_WARRIOR, NPC_ZANDALARI_BERSERKER, NPC_ZANDALARI_SHADOW_HUNTER };
            
            case INVASION_WAVE_3:
                // Elite assault - strongest forces
                return { NPC_ZANDALARI_BLOOD_GUARD, NPC_ZANDALARI_WITCH_DOCTOR, NPC_ZANDALARI_BEAST_TAMER };
            
            default:
                LOG_ERROR("scripts", "Giant Isles Invasion: GetWaveCreatureEntries called with invalid phase {}", _invasionPhase);
                return {};
        }
    }

    uint32 GetSpawnDelay() const
    {
        switch (_invasionPhase)
        {
            case INVASION_WAVE_1:
                return SPAWN_DELAY_WAVE_1;  // 3 seconds
            case INVASION_WAVE_2:
                return SPAWN_DELAY_WAVE_2;  // 4 seconds
            case INVASION_WAVE_3:
                return SPAWN_DELAY_WAVE_3;  // 5 seconds
            default:
                return 0;  // No spawning
        }
    }

    Creature* GetNearestDefender(Creature* invader, Map* map) const
    {
        Creature* nearest = nullptr;
        float minDist = 999.0f;
        for (const auto& guid : _defenderGuids)
        {
            if (Creature* defender = map->GetCreature(guid))
            {
                if (defender->IsAlive())
                {
                    float dist = invader->GetDistance2d(defender);
                    if (dist < minDist)
                    {
                        minDist = dist;
                        nearest = defender;
                    }
                }
            }
        }
        return nearest;
    }

    uint32 CheckDefendersAlive(Map* map) const
    {
        uint32 count = 0;
        for (const auto& guid : _defenderGuids)
        {
            if (Creature* defender = map->GetCreature(guid))
            {
                if (defender->IsAlive())
                    count++;
            }
        }
        return count;
    }

    bool IsInvasionMob(uint32 entry) const
    {
        return entry >= 400326 && entry <= 400337;
    }

    void FailInvasion(Map* map)
    {
        // Prevent re-entrancy from multiple triggers — atomic ensures a single thread proceeds.
        bool expected = false;
        if (!_isFailing.compare_exchange_strong(expected, true))
        {
            // Another thread is already handling the failure; ignore this invocation
            LOG_WARN("scripts", "Giant Isles Invasion: FailInvasion re-entry suppressed (already handling)");
            return;
        }
        _failInvocationCount++;
        if (_failInvocationCount > 1)
        {
            LOG_WARN("scripts", "Giant Isles Invasion: FailInvasion invoked multiple times (count={})", _failInvocationCount);
            if (_broadcastedFailure)
            {
                _isFailing.store(false);
                return;
            }
        }
        _broadcastedFailure = true;
        _invasionPhase = INVASION_FAILED;
        {
            uint64_t now = GameTime::GetGameTime().count();
            if (_lastEventAnnouncementTime == 0 || (now - _lastEventAnnouncementTime) >= EVENT_ANNOUNCE_COOLDOWN_MS)
            {
                SafeWorldAnnounce("Defeat! The Zandalari have overrun Seeping Shores!");
                _lastEventAnnouncementTime = now;
            }
            else
            {
                LOG_DEBUG("scripts", "Giant Isles Invasion: Failure announcement suppressed due to cooldown ({}ms)", (now - _lastEventAnnouncementTime));
            }
        }
        
            BroadcastEventStatus(map, "failed");
            BroadcastEventRemoval(map, "failed");
        BossWaveComment(6);

        // removed duplicate BroadcastEventStatus to avoid repeated outputs

        sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 0);
        CleanupInvasion(map);
        _bossGuardGuids.clear();
        _bossGUID.Clear();
        _bossActivated = false;
        LOG_INFO("scripts", "Giant Isles Invasion: Event failed");
        _isFailing.store(false);
    }

    void RewardParticipants()
    {
        Map* map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);
        if (!map)
            return;

        // Award tokens to all players who participated
        map->DoForAllPlayers([this](Player* player)
        {
            if (!player || !player->IsInWorld())
                return;

            // Check if player is in the invasion area (Seeping Shores)
            if (player->GetAreaId() != AREA_SEEPING_SHORES)
                return;

            // Base reward for participation
            const uint32 baseTokens = 50;
            uint32 bonusTokens = 0;

            // Check participation map for additional rewards
            auto itr = _participantKills.find(player->GetGUID());
            if (itr != _participantKills.end())
            {
                uint32 kills = itr->second;
                bonusTokens = std::min(kills, 50u);
            }

            uint32 totalTokens = baseTokens + bonusTokens;

            // Award seasonal tokens through the seasonal reward system
            if (sSeasonalRewards && sSeasonalRewards->GetConfig().enabled
                && sSeasonalRewards->AwardTokens(player, totalTokens, "Giant Isles Invasion", NPC_INVASION_HORN))
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Invasion Victory]|r You've been awarded |cffffd700{} Seasonal Tokens|r for defending the shores!",
                    totalTokens
                );

                if (bonusTokens > 0)
                {
                    ChatHandler(player->GetSession()).PSendSysMessage(
                        "|cff00ff00Bonus:|r +{} tokens for {} invader kills!",
                        bonusTokens, itr != _participantKills.end() ? itr->second : 0u
                    );
                }
            }
            else
            {
                // Temporary: fallback message if seasonal system isn't active
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Invasion Victory]|r You've defended the shores and earned {} tokens!",
                    totalTokens
                );
            }
        });
    }

    void CleanupInvasion(Map* map)
    {
        for (const auto& guid : _invaderGuids)
        {
            if (Creature* invader = map->GetCreature(guid))
                invader->DespawnOrUnsummon(5s);
        }
        _invaderGuids.clear();

        for (const auto& guid : _bossGuardGuids)
        {
            if (Creature* guard = map->GetCreature(guid))
                guard->DespawnOrUnsummon(5s);
        }
        _bossGuardGuids.clear();

        for (const auto& guid : _defenderGuids)
        {
            if (Creature* defender = map->GetCreature(guid))
                defender->DespawnOrUnsummon(30s);
        }
        _defenderGuids.clear();

        if (!_leaderGUID.IsEmpty())
        {
            if (Creature* leader = map->GetCreature(_leaderGUID))
                leader->DespawnOrUnsummon(5s);
            _leaderGUID.Clear();
        }

        if (!_leaderGUID.IsEmpty())
        {
            if (Creature* leader = map->GetCreature(_leaderGUID))
                leader->DespawnOrUnsummon(10s);
            _leaderGUID.Clear();
        }

        sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 0);
        _invasionPhase = INVASION_INACTIVE;
        _bossGUID.Clear();
        _bossActivated = false;
        _broadcastedFailure = false;
        _broadcastedVictory = false;
        _lastEventAnnouncementTime = 0;
        _isFailing.store(false);
    }

    // Helper to post event messages safely with per-map cooldown to avoid chat spam
    void SafeWorldAnnounce(const char* text)
    {
        uint64_t now = GameTime::GetGameTime().count();
        if (_lastEventAnnouncementTime == 0 || (now - _lastEventAnnouncementTime) >= EVENT_ANNOUNCE_COOLDOWN_MS)
        {
            ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, text);
            _lastEventAnnouncementTime = now;
        }
        else
        {
            LOG_DEBUG("scripts", "Giant Isles Invasion: Announce suppressed due to cooldown ({}ms)", (now - _lastEventAnnouncementTime));
        }
    }

    // Broadcast as CHAT_MSG_ADDON to players on the map (clients can pick this up in addons)
    void SendInvasionAddon(Player* player, std::string const& message)
    {
        if (!player || !player->GetSession())
            return;

        WorldPacket data;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_ADDON, LANG_ADDON, player, player, message);
        player->SendDirectMessage(&data);
    }

    void BroadcastInvasionAddon(Map* map, std::string const& message)
    {
        if (!map)
            return;

        // Option toggle from config
        if (!sConfigMgr->GetOption<bool>("Invasion.SendAddonPackets", false))
            return;

        map->DoForAllPlayers([&](Player* player)
        {
            if (player && player->IsInWorld() && player->GetSession())
                SendInvasionAddon(player, message);
        });
    }

    void BroadcastSpawn(Map* map, Creature* creature, uint8 waveId = 0, int8 laneIndex = -1)
    {
        if (!map || !creature)
            return;

        // Chat log toggle
        if (sConfigMgr->GetOption<bool>("Invasion.ChatSpawnMessages", true))
        {
            std::ostringstream ss;
            ss << "[INVASION SPAWN] Entry=" << creature->GetEntry()
               << " GUID=" << creature->GetGUID().ToString()
               << " Pos=" << creature->GetPosition().ToString()
               << " Wave=" << static_cast<int>(waveId)
               << " Lane=" << static_cast<int>(laneIndex);

            map->DoForAllPlayers([&](Player* player)
            {
                if (player && player->GetSession())
                    ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
            });
        }

        // Send addon packet to clients that accept it
        if (sConfigMgr->GetOption<bool>("Invasion.SendAddonPackets", false))
        {
            uint32 spawnNum = 0;
            auto itr = _spawnIndex.find(creature->GetGUID());
            if (itr != _spawnIndex.end())
                spawnNum = itr->second;
            uint32 activeCount = GetActiveInvaderCount(map);

            DCAddon::JsonMessage msg(DCAddon::Module::EVENTS, DCAddon::Opcode::Events::SMSG_EVENT_SPAWN);
            msg.Set("eventId", static_cast<int32>(GIANT_ISLES_INVASION_EVENT_ID));
            msg.Set("type", "invasion");
            msg.Set("name", "Zandalari Invasion");
            msg.Set("mapId", static_cast<int32>(map->GetId()));
            msg.Set("entry", static_cast<int32>(creature->GetEntry()));
            msg.Set("guid", creature->GetGUID().ToString());
            msg.Set("x", static_cast<double>(creature->GetPositionX()));
            msg.Set("y", static_cast<double>(creature->GetPositionY()));
            msg.Set("z", static_cast<double>(creature->GetPositionZ()));
            msg.Set("wave", static_cast<int32>(waveId));
            msg.Set("lane", static_cast<int32>(laneIndex));
            msg.Set("spawnNum", static_cast<int32>(spawnNum));
            msg.Set("enemiesRemaining", static_cast<int32>(activeCount));

            map->DoForAllPlayers([&](Player* player)
            {
                if (player && player->IsInWorld() && player->GetSession())
                    msg.Send(player);
            });
        }
    }

    // Broadcast event-level JSON status to players (startup / wave change / finish)
    void BroadcastEventStatus(Map* map, const char* stateOverride = nullptr)
    {
        if (!map)
            return;

        if (!sConfigMgr->GetOption<bool>("Invasion.SendAddonPackets", false))
            return;

        // Apply a short cooldown to prevent duplicate rapid broadcasts (e.g., due to restart hooks)
        uint64_t now = GameTime::GetGameTime().count();
        if (_lastEventStatusBroadcastTime != 0 && (now - _lastEventStatusBroadcastTime) < EVENT_STATUS_BROADCAST_COOLDOWN_MS)
        {
            LOG_DEBUG("scripts", "Giant Isles Invasion: BroadcastEventStatus suppressed due to cooldown ({}ms)", (now - _lastEventStatusBroadcastTime));
            return;
        }
        _lastEventStatusBroadcastTime = now;

        std::string state;
        if (stateOverride)
            state = stateOverride;
        else
        {
            switch (_invasionPhase)
            {
                case INVASION_INACTIVE:
                    state = "warning";
                    break;
                case INVASION_VICTORY:
                    state = "victory";
                    break;
                case INVASION_FAILED:
                    state = "failed";
                    break;
                default:
                    state = "active";
                    break;
            }
        }

        bool isActive = state == "active" || state == "warning";

        DCAddon::JsonMessage msg(DCAddon::Module::EVENTS, DCAddon::Opcode::Events::SMSG_EVENT_UPDATE);
        msg.Set("eventId", static_cast<int32>(GIANT_ISLES_INVASION_EVENT_ID));
        msg.Set("type", "invasion");
        msg.Set("name", "Zandalari Invasion");
        msg.Set("mapId", static_cast<int32>(map->GetId()));
        msg.Set("zoneId", static_cast<int32>(AREA_SEEPING_SHORES));
        msg.Set("wave", static_cast<int32>(_invasionPhase));
        msg.Set("maxWaves", static_cast<int32>(4));
        msg.Set("enemiesRemaining", static_cast<int32>(GetActiveInvaderCount(map)));
        msg.Set("timeRemaining", static_cast<int32>(_waveTimer / IN_MILLISECONDS));
        msg.Set("state", state);
        msg.Set("active", isActive);

        map->DoForAllPlayers([&](Player* player)
        {
            if (player && player->IsInWorld() && player->GetSession())
                msg.Send(player);
        });
    }

    void BroadcastEventRemoval(Map* map, const char* reason = "expired")
    {
        if (!sConfigMgr->GetOption<bool>("Invasion.SendAddonPackets", false))
            return;

        if (!map)
            map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);

        if (!map)
            return;

        DCAddon::JsonMessage msg(DCAddon::Module::EVENTS, DCAddon::Opcode::Events::SMSG_EVENT_REMOVE);
        msg.Set("eventId", static_cast<int32>(GIANT_ISLES_INVASION_EVENT_ID));
        msg.Set("type", "invasion");
        msg.Set("reason", reason ? reason : "expired");

        map->DoForAllPlayers([&](Player* player)
        {
            if (player && player->IsInWorld() && player->GetSession())
                msg.Send(player);
        });
    }

    // Try to summon a creature up to `attempts` times with small jitter around position
    Creature* TrySummonCreature(Map* map, uint32 entry, Position p, uint8 attempts = 3, float jitter = 1.5f, TempSummonType summonType = TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, uint32 despawnTime = 0)
    {
        if (!map)
            return nullptr;

        for (uint8 attempt = 1; attempt <= attempts; ++attempt)
        {
            Position attemptPos = p;
            if (attempt > 1 && jitter > 0.0f)
            {
                attemptPos.m_positionX += frand(-jitter, jitter);
                attemptPos.m_positionY += frand(-jitter, jitter);
                // Keep Z the same since vertical jitter can cause ground intersection
            }

            Creature* meSummon = nullptr;
            if (summonType == TEMPSUMMON_TIMED_OR_DEAD_DESPAWN || despawnTime == 0)
            {
                meSummon = map->SummonCreature(entry, attemptPos);
            }
            else
            {
                // Map::SummonCreature expects SummonPropertiesEntry const* rather than TempSummonType.
                // We don't currently support custom SummonProperties here, so call the Map overload with nullptr properties
                // and a duration in milliseconds.
                meSummon = map->SummonCreature(entry, attemptPos, nullptr, despawnTime);
            }

            if (meSummon)
            {
                if (attempt > 1)
                    LOG_INFO("scripts", "Giant Isles Invasion: Summon success after {} attempts for entry {} at {}", attempt, entry, attemptPos.ToString());
                return meSummon;
            }
            else
            {
                LOG_WARN("scripts", "Giant Isles Invasion: Failed to summon entry {} at {} (attempt {}/{})", entry, attemptPos.ToString(), attempt, attempts);
            }
        }

        LOG_ERROR("scripts", "Giant Isles Invasion: All summon attempts failed for entry {} at {}", entry, p.ToString());
        return nullptr;
    }

    void MaintainBossGuards(Map* map)
    {
        if (!map || _bossGUID.IsEmpty() || !_bossActivated)
            return;

        Creature* boss = map->GetCreature(_bossGUID);
        if (!boss || !boss->IsAlive())
            return;

        _bossGuardGuids.erase(std::remove_if(_bossGuardGuids.begin(), _bossGuardGuids.end(), [map](const ObjectGuid& guid)
        {
            Creature* guard = map->GetCreature(guid);
            return !guard || !guard->IsAlive();
        }), _bossGuardGuids.end());

        constexpr float guardDistance = 3.0f;
        while (_bossGuardGuids.size() < 4)
        {
            Position spawn = boss->GetPosition();
            spawn.m_positionX += frand(-guardDistance, guardDistance);
            spawn.m_positionY += frand(-guardDistance, guardDistance);
            Creature* guard = TrySummonCreature(map, NPC_ZANDALARI_HONOR_GUARD, spawn, 3, 1.0f);
            if (guard)
            {
            ConfigureBossSpectatorState(guard, false);
                RegisterInvader(guard);
                _bossGuardGuids.push_back(guard->GetGUID());
                float angle = frand(0.0f, 6.283185307f);
                guard->GetMotionMaster()->MoveFollow(boss, guardDistance, angle, MOTION_SLOT_ACTIVE);
                CommandInvader(guard, map, 1);
            }
            else
                break;
        }

        for (const ObjectGuid& guid : _bossGuardGuids)
        {
            if (Creature* guard = map->GetCreature(guid))
            {
                if (!guard->IsInCombat())
                {
                    if (Unit* target = SelectInvasionTarget(guard, map))
                        guard->AI()->AttackStart(target);
                }
            }
        }
    }

    void RegisterSummonedInvader(Creature* creature)
    {
        RegisterInvader(creature);
    }

    void RegisterInvader(Creature* creature)
    {
        if (!creature)
            return;

        _invaderGuids.push_back(creature->GetGUID());
        creature->SetFaction(16);
        creature->SetReactState(REACT_AGGRESSIVE);
        // Assign sequential spawn number for this invader
        _spawnCounter++;
        _spawnIndex[creature->GetGUID()] = _spawnCounter;
    }

    void NudgeIdleInvaders(Map* map)
    {
        if (!map)
            return;

        constexpr float reassignRange = 200.0f;
        for (const auto& guid : _invaderGuids)
        {
            Creature* inv = map->GetCreature(guid);
            if (!inv || !inv->IsAlive())
                continue;

            if (inv->IsInCombat())
                continue;

            // If not moving, reissue movement and target
            CommandInvader(inv, map, urand(0, 2));

            if (Unit* target = SelectInvasionTarget(inv, map))
            {
                if (inv->GetDistance(target) < reassignRange)
                    inv->AI()->AttackStart(target);
            }
        }
    }

    void CommandInvader(Creature* creature, Map* map, int8 laneIndex)
    {
        if (!creature || !map)
            return;

        creature->SetWalk(false);
        creature->SetHomePosition(creature->GetPosition());

        if (laneIndex >= 0 && laneIndex < 3)
        {
            const InvasionSpawnPoint& target = TARGET_POINTS[laneIndex];
            creature->GetMotionMaster()->MovePoint(laneIndex + 1, target.x, target.y, target.z);
        }

        if (Unit* targetUnit = SelectInvasionTarget(creature, map))
            creature->AI()->AttackStart(targetUnit);
    }

    Unit* SelectInvasionTarget(Creature* seeker, Map* map) const
    {
        if (!seeker || !map)
            return nullptr;

        if (Creature* defender = GetNearestDefender(seeker, map))
            return defender;

        Player* nearestPlayer = nullptr;
        float bestDistance = 150.0f;
        map->DoForAllPlayers([&](Player* player)
        {
            if (!player || !player->IsAlive())
                return;

            float dist = seeker->GetDistance(player);
            if (dist < bestDistance)
            {
                bestDistance = dist;
                nearestPlayer = player;
            }
        });

        return nearestPlayer;
    }

    uint8 GetLaneSpawnMultiplier() const
    {
        switch (_invasionPhase)
        {
            case INVASION_WAVE_1:
                return 1;
            case INVASION_WAVE_2:
                return 2;
            case INVASION_WAVE_3:
                return 3;
            default:
                return 1;
        }
    }
};

// ============================================================================
// INVASION HORN - Trigger NPC (gossip interaction)
// ============================================================================

class npc_invasion_horn : public CreatureScript
{
public:
    npc_invasion_horn() : CreatureScript("npc_invasion_horn") { }

    struct npc_invasion_hornAI : public ScriptedAI
    {
        npc_invasion_hornAI(Creature* creature) : ScriptedAI(creature) { }
        // AI-specific behaviour only (gossip handlers belong to CreatureScript)
    };

    // Gossip handlers must be declared on the CreatureScript-derived class (not the AI)
    bool OnGossipHello(Player* player, Creature* creature) override
    {
        bool isGM = player->IsGameMaster();
        bool isActive = sWorldState->getWorldState(WORLD_STATE_INVASION_ACTIVE) == 1;

        // GM Options
        if (isGM)
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "GM: Force Start Invasion", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 100);
            if (isActive)
            {
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "GM: Stop Invasion", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 101);
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "GM: Skip to Next Wave", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 102);
            }
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "GM: Spawn Wave...", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 200);
        }

        // Check if invasion is already active
        if (isActive)
        {
            if (!isGM)
            {
                ChatHandler(player->GetSession()).SendNotification("An invasion is already in progress!");
                return true;
            }
        }

        // Check cooldown (stored in world state with timestamp)
        uint32 lastInvasion = sWorldState->getWorldState(WORLD_STATE_INVASION_ACTIVE + 10);
        if (lastInvasion > 0)
        {
            uint32 nowSec = static_cast<uint32>(GameTime::GetGameTime().count());
            uint32 cooldownEnd = lastInvasion + INVASION_COOLDOWN;
            if (nowSec < cooldownEnd)
            {
                if (!isGM)
                {
                    uint32 remaining = cooldownEnd - nowSec;
                    ChatHandler(player->GetSession()).SendNotification("The invasion horn is on cooldown. Time remaining: {} minutes", remaining / 60);
                    return true;
                }
                else
                {
                    player->SendSystemMessage("Invasion is on cooldown, but you are a GM.");
                }
            }
        }

        // Add gossip option to start invasion
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Sound the horn! Rally the defenders!", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "What is this horn for?", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        SendGossipMenuFor(player, 400325, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        (void)sender; // unused parameter - silence warning
        ClearGossipMenuFor(player);

        // Get MapScript via Global Pointer
        giant_isles_invasion* mapScript = sGiantIslesInvasion;

        if (!mapScript)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Error: Invasion Map Script not found! Debug Info:");
            ChatHandler(player->GetSession()).PSendSysMessage("- Map ID: {}", creature->GetMapId());
            ChatHandler(player->GetSession()).PSendSysMessage("- Script Loaded: {}", sGiantIslesInvasion ? "Yes" : "No (Global Pointer Null)");
            return true;
        }

        // GM Wave Spawn Submenu
        if (action == GOSSIP_ACTION_INFO_DEF + 200)
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Spawn Wave 1 (Scouts)", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 201);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Spawn Wave 2 (Warriors)", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 202);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Spawn Wave 3 (Elites)", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 203);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Spawn Wave 4 (Boss)", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 204);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<- Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 0);
            SendGossipMenuFor(player, 400325, creature->GetGUID());
            return true;
        }

        // GM Wave Spawn Actions
        if (action >= GOSSIP_ACTION_INFO_DEF + 201 && action <= GOSSIP_ACTION_INFO_DEF + 204)
        {
            uint32 waveNum = action - (GOSSIP_ACTION_INFO_DEF + 200);
            mapScript->ForceSpawnWave(waveNum, creature->GetMap());
            ChatHandler(player->GetSession()).PSendSysMessage("GM: Spawned Wave {}", waveNum);
            CloseGossipMenuFor(player);
            return true;
        }

        if (action == GOSSIP_ACTION_INFO_DEF + 1)
        {
            // Start invasion event
            mapScript->StartInvasion(player, creature->GetMap());
        }
        else if (action == GOSSIP_ACTION_INFO_DEF + 2)
        {
            // Info text
            player->GetSession()->SendAreaTriggerMessage("The Invasion Horn summons defenders to fight off Zandalari attackers. Sound it to begin the defense event!");
        }
        else if (action == GOSSIP_ACTION_INFO_DEF + 100) // GM Force Start
        {
            mapScript->StopInvasion(creature->GetMap()); // Reset first
            mapScript->StartInvasion(player, creature->GetMap());
            player->SendSystemMessage("GM: Invasion Force Started.");
        }
        else if (action == GOSSIP_ACTION_INFO_DEF + 101) // GM Stop
        {
            mapScript->StopInvasion(creature->GetMap());
            player->SendSystemMessage("GM: Invasion Stopped.");
        }
        else if (action == GOSSIP_ACTION_INFO_DEF + 102) // GM Skip Wave
        {
            mapScript->AdvanceWave(creature->GetMap());
            player->SendSystemMessage("GM: Advanced to next wave.");
        }
        else if (action == GOSSIP_ACTION_INFO_DEF + 0) // Back to main menu
        {
            OnGossipHello(player, creature);
            return true;
        }

        return true;
    }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_invasion_hornAI(creature);
    }
};

// ============================================================================
// SCRIPT REGISTRATION
// ============================================================================

// Helper implementation: forward to the active invasion manager
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

void GI_BroadcastSpawn(Map* map, Creature* creature, uint8 waveId /*= 0*/, int8 laneIndex /*= -1*/)
{
    if (sGiantIslesInvasion)
        sGiantIslesInvasion->BroadcastSpawn(map, creature, waveId, laneIndex);
}

InvasionPhase GI_GetCurrentPhase()
{
    if (sGiantIslesInvasion)
        return sGiantIslesInvasion->GetCurrentPhase();
    return INVASION_INACTIVE;
}

void AddSC_giant_isles_invasion()
{
    new npc_invasion_horn();
    new npc_invasion_mob();
    new npc_invasion_leader();
    new npc_invasion_commander();
    new giant_isles_invasion();
    LOG_INFO("scripts", "Giant Isles Invasion: Scripts Registered");
}

// Free-level wrapper implemented after class definition to allow use in earlier AIs
static void SafeWorldAnnounce(Map* map, const char* text)
{
    if (sGiantIslesInvasion)
    {
        sGiantIslesInvasion->SafeWorldAnnounce(text);
    }
    else
    {
        ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, text);
    }
}
