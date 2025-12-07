/*
 * Giant Isles - Zandalari Invasion Event
 * ============================================================================
 * Large-scale defense event where Zandalari trolls assault Seeping Shores
 * Players must defend against waves of invaders
 * 
 * Event Location: Seeping Shores (Area 5010)
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
#include "../Seasons/SeasonalRewardSystem.h"
#include <algorithm>

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

    // Defender NPCs (Friendly)
    NPC_PRIMAL_WARDEN           = 401000, // Basic guard
    NPC_PRIMAL_WARDEN_SERGEANT  = 401001, // Elite guard
    NPC_PRIMAL_WARDEN_MARKSMAN  = 401002, // Ranged guard
    NPC_PRIMAL_WARDEN_CAPTAIN   = 401003, // Commander

    // Timers
    INVASION_COOLDOWN           = 2 * HOUR,  // 2 hours between invasions
    INVASION_WARNING_TIME       = 30 * IN_MILLISECONDS,  // 30 sec warning before start
    WAVE_1_DURATION             = 2 * MINUTE,  // Scout wave (fast, weak)
    WAVE_2_DURATION             = 3 * MINUTE,  // Warrior wave
    WAVE_3_DURATION             = 4 * MINUTE,  // Elite wave
    WAVE_4_DURATION             = 6 * MINUTE,  // Boss wave
    INVASION_TOTAL_TIME         = 15 * MINUTE,  // Total event time

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

// Spawn coordinates for the three attack points
struct InvasionSpawnPoint
{
    float x, y, z, o;
    std::string name;
};

const InvasionSpawnPoint SPAWN_POINTS[3] = 
{
    { 5809.59f, 1200.97f, 7.04f, 1.94f, "Middle Beach" },
    { 5844.46f, 1215.58f, 10.58f, 2.29f, "Right Flank" },
    { 5785.77f, 1203.52f, 2.84f, 1.55f, "Left Flank" }
};

// Target waypoints - where invaders move to (defensive line)
const InvasionSpawnPoint TARGET_POINTS[3] =
{
    { 5753.34f, 1319.46f, 23.34f, 5.43f, "Left Defense Line" },   // Left target
    { 5769.76f, 1322.34f, 24.64f, 5.91f, "Center Defense Line" }, // Center target  
    { 5795.22f, 1318.57f, 27.29f, 4.13f, "Right Defense Line" }   // Right target
};

// Defender spawn points (around the beach, facing outward)
const InvasionSpawnPoint DEFENDER_POINTS[6] =
{
    { 5809.59f, 1190.97f, 7.04f, 1.94f, "Center Defense" },
    { 5820.0f, 1195.0f, 8.0f, 2.0f, "Right Center" },
    { 5799.0f, 1195.0f, 6.0f, 1.8f, "Left Center" },
    { 5844.46f, 1205.58f, 10.58f, 2.29f, "Right Defense" },
    { 5785.77f, 1193.52f, 2.84f, 1.55f, "Left Defense" },
    { 5809.59f, 1185.0f, 7.5f, 1.94f, "Rear Defense" }
};

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

// Helper to avoid circular-forward-declaration issues: call this from AIs
void GI_TrackPlayerKill(ObjectGuid playerGuid);

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

        void JustDied(Unit* killer) override
        {
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
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_invasion_mobAI(creature);
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
                ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "|cFF00FF00[VICTORY!]|r Warlord Zul'mar has fallen! The Zandalari invasion is repelled!");
                
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
                        // Check if any guards are still alive, summon more if needed
                        // TODO: Implement guard check logic
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
        _invasionPhase(INVASION_INACTIVE), _waveTimer(0), _spawnTimer(0), _killCount(0), _bossGUID()
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

    // State variables
    InvasionPhase _invasionPhase;
    uint32 _waveTimer;
    uint32 _spawnTimer;
    uint32 _killCount;
    ObjectGuid _bossGUID;
    std::vector<ObjectGuid> _defenderGuids;
    std::vector<ObjectGuid> _invaderGuids;
    std::map<ObjectGuid, uint32> _participantKills;

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
        _killCount = 0;

        // Dramatic warning announcement
        ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "|cFFFF0000[INVASION WARNING]|r War drums echo across Seeping Shores! The Zandalari fleet approaches!");
        
        // Play war horn sound to all players in zone
        map->DoForAllPlayers([](Player* player)
        {
            player->PlayDirectSound(6674);  // War horn sound
        });

        SpawnDefenders(map);
        LOG_INFO("scripts", "Giant Isles Invasion: Event starting with 30s warning. Triggered by {}", starter ? starter->GetName() : "System");
    }

    void StopInvasion(Map* map)
    {
        CleanupInvasion(map);
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
        _invasionPhase = INVASION_VICTORY;
        _waveTimer = 10 * IN_MILLISECONDS;
        ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "Victory! The Zandalari invasion has been repelled!");
        RewardParticipants();
        sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE + 10, static_cast<uint32>(GameTime::GetGameTime().count()));
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

    void OnUpdate(Map* map, uint32 diff) override
    {
        if (_invasionPhase == INVASION_INACTIVE || _invasionPhase == INVASION_VICTORY)
            return;

        // Wave timer - advance wave when time expires
        if (_waveTimer <= diff)
        {
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

        // Check if all defenders died - invasion fails
        if (CheckDefendersAlive(map) == 0 && _invasionPhase < INVASION_VICTORY)
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
                ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "|cFFFF8000[INVASION - WAVE 1]|r Zandalari scouts storm the beach! Kill them quickly!");
                map->DoForAllPlayers([](Player* player) { player->PlayDirectSound(8459); });  // Battle horn
                // Spawn the first wave batch immediately
                LOG_INFO("scripts", "Giant Isles Invasion: Starting Wave 1");
                SpawnWaveCreatures(map);
                break;
                
            case INVASION_WAVE_1:
                _invasionPhase = INVASION_WAVE_2;
                _waveTimer = WAVE_2_DURATION;
                _spawnTimer = SPAWN_DELAY_WAVE_2;
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 2);
                ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "|cFFFF8000[INVASION - WAVE 2]|r Zandalari warriors and berserkers charge! Hold the line!");
                map->DoForAllPlayers([](Player* player) { player->PlayDirectSound(8174); });  // Orc battle cry
                LOG_INFO("scripts", "Giant Isles Invasion: Starting Wave 2");
                SpawnWaveCreatures(map);
                break;
                
            case INVASION_WAVE_2:
                _invasionPhase = INVASION_WAVE_3;
                _waveTimer = WAVE_3_DURATION;
                _spawnTimer = SPAWN_DELAY_WAVE_3;
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 3);
                ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "|cFFFF4000[INVASION - WAVE 3]|r Elite Blood Guards and Witch Doctors arrive! Beware their dark magic!");
                map->DoForAllPlayers([](Player* player) { player->PlayDirectSound(8212); });  // Troll aggro
                LOG_INFO("scripts", "Giant Isles Invasion: Starting Wave 3");
                SpawnWaveCreatures(map);
                break;
                
            case INVASION_WAVE_3:
                _invasionPhase = INVASION_WAVE_4_BOSS;
                _waveTimer = WAVE_4_DURATION;
                _spawnTimer = 0;  // No more spawns, only boss
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 4);
                ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "|cFFFF0000[BOSS WAVE]|r Warlord Zul'mar arrives with his honor guard! Defeat him to repel the invasion!");
                map->DoForAllPlayers([](Player* player) { player->PlayDirectSound(8923); });  // Raid warning
                SpawnBoss(map);
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
        for (uint8 i = 0; i < 6; ++i)
        {
            const InvasionSpawnPoint& point = DEFENDER_POINTS[i];
            uint32 entry = NPC_PRIMAL_WARDEN;
            if (i == 0) entry = NPC_PRIMAL_WARDEN_CAPTAIN;
            else if (i == 3 || i == 4) entry = NPC_PRIMAL_WARDEN_SERGEANT;
            else if (i == 1 || i == 2) entry = NPC_PRIMAL_WARDEN_MARKSMAN;

            Position p(point.x, point.y, point.z, point.o);
            if (Creature* defender = map->SummonCreature(entry, p))
            {
                _defenderGuids.push_back(defender->GetGUID());
                defender->SetFaction(14);  // Monster faction (hostile to invaders who are faction 16)
                defender->SetReactState(REACT_AGGRESSIVE);
                LOG_INFO("scripts", "Giant Isles Invasion: Summoned defender entry {} at point {}", entry, i);
            }
        }
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

        // Spawn different NPCs at each spawn point
        for (uint8 i = 0; i < 3; ++i)
        {
            // Cycle through NPC types for each spawn point
            uint32 entry = waveEntries[i % waveEntries.size()];
            
            const InvasionSpawnPoint& spawnPoint = SPAWN_POINTS[i];
            Position p(spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.o);
            
            if (Creature* invader = map->SummonCreature(entry, p))
            {
                _invaderGuids.push_back(invader->GetGUID());
                invader->SetFaction(16);
                
                // Find nearest Primal Warden and attack them
                if (Creature* defender = GetNearestDefender(invader, map))
                {
                    invader->AI()->AttackStart(defender);
                }
                LOG_INFO("scripts", "Giant Isles Invasion: Spawned invader entry {} at {} ({})", 
                    entry, spawnPoint.name, invader->GetGUID().ToString());
            }
            else
            {
                LOG_INFO("scripts", "Giant Isles Invasion: Failed to summon invader entry {} at spawn {}", entry, i);
            }
        }
    }

    void SpawnBoss(Map* map)
    {
        const InvasionSpawnPoint& spawnPoint = SPAWN_POINTS[1];
        Position p(spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.o);
        if (Creature* boss = map->SummonCreature(NPC_WARLORD_ZULMAR, p))
        {
            _bossGUID = boss->GetGUID();
            boss->SetFaction(16);
            
            // Boss should attack nearest Primal Warden, not move to waypoint
            if (Creature* defender = GetNearestDefender(boss, map))
            {
                boss->AI()->AttackStart(defender);
            }

            const float guardDistance = 3.0f;
            Position guardPositions[4] =
            {
                { spawnPoint.x, spawnPoint.y - guardDistance, spawnPoint.z, spawnPoint.o },
                { spawnPoint.x, spawnPoint.y + guardDistance, spawnPoint.z, spawnPoint.o },
                { spawnPoint.x - guardDistance, spawnPoint.y, spawnPoint.z, spawnPoint.o },
                { spawnPoint.x + guardDistance, spawnPoint.y, spawnPoint.z, spawnPoint.o }
            };

            for (uint8 i = 0; i < 4; ++i)
            {
                Position gp(guardPositions[i].GetPositionX(), guardPositions[i].GetPositionY(), guardPositions[i].GetPositionZ(), guardPositions[i].GetOrientation());
                if (Creature* guard = map->SummonCreature(NPC_ZANDALARI_HONOR_GUARD, gp))
                {
                    _invaderGuids.push_back(guard->GetGUID());
                    guard->SetFaction(16);
                    float angle = i * M_PI / 2.0f;
                    guard->GetMotionMaster()->MoveFollow(boss, guardDistance, angle, MOTION_SLOT_ACTIVE);
                    if (guard->AI())
                        guard->AI()->SetGUID(boss->GetGUID(), 0);
                    
                    // Guards should also attack defenders
                    if (Creature* defender = GetNearestDefender(guard, map))
                    {
                        guard->AI()->AttackStart(defender);
                    }
                }
            }
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
        _invasionPhase = INVASION_FAILED;
        ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "Defeat! The Zandalari have overrun Seeping Shores!");
        sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 0);
        CleanupInvasion(map);
        LOG_INFO("scripts", "Giant Isles Invasion: Event failed");
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

        for (const auto& guid : _defenderGuids)
        {
            if (Creature* defender = map->GetCreature(guid))
                defender->DespawnOrUnsummon(30s);
        }
        _defenderGuids.clear();

        sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 0);
        _invasionPhase = INVASION_INACTIVE;
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

void AddSC_giant_isles_invasion()
{
    new npc_invasion_horn();
    new npc_invasion_mob();
    new npc_invasion_commander();
    new giant_isles_invasion();
    LOG_INFO("scripts", "Giant Isles Invasion: Scripts Registered");
}
