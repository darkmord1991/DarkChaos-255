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
#include "InstanceScript.h"
#include "ObjectAccessor.h"
#include "Chat.h"
#include "Log.h"

// Forward declaration of map script used by gossip handler
class giant_isles_invasion;

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
    WAVE_1_DURATION             = 3 * MINUTE,
    WAVE_2_DURATION             = 4 * MINUTE,
    WAVE_3_DURATION             = 5 * MINUTE,
    WAVE_4_DURATION             = 8 * MINUTE,
    INVASION_TOTAL_TIME         = 20 * MINUTE,

    // Spawn timers within waves
    SPAWN_DELAY_FAST            = 5 * IN_MILLISECONDS,
    SPAWN_DELAY_NORMAL          = 10 * IN_MILLISECONDS,
    SPAWN_DELAY_SLOW            = 15 * IN_MILLISECONDS,

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
    SAY_INVASION_START          = 0,
    SAY_WAVE_1_START            = 1,
    SAY_WAVE_2_START            = 2,
    SAY_WAVE_3_START            = 3,
    SAY_WAVE_4_BOSS             = 4,
    SAY_INVASION_VICTORY        = 5,
    SAY_INVASION_FAILED         = 6,
    SAY_INVASION_WARNING        = 7,
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
        // Check if invasion is already active
        if (sWorldState->getWorldState(WORLD_STATE_INVASION_ACTIVE) == 1)
        {
            ChatHandler(player->GetSession()).SendNotification("An invasion is already in progress!");
            return true;
        }

        // Check cooldown (stored in world state with timestamp)
            uint32 lastInvasion = sWorldState->getWorldState(WORLD_STATE_INVASION_ACTIVE + 10);
            if (lastInvasion > 0)
            {
                uint32 nowSec = static_cast<uint32>(GameTime::GetGameTime().count());
                uint32 cooldownEnd = lastInvasion + INVASION_COOLDOWN;
                if (nowSec < cooldownEnd)
                {
                    uint32 remaining = cooldownEnd - nowSec;
                    ChatHandler(player->GetSession()).SendNotification("The invasion horn is on cooldown. Time remaining: %u minutes", remaining / 60);
                    return true;
                }
            }

        // Add gossip option to start invasion
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Sound the horn! Rally the defenders!", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "What is this horn for?", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);

        if (action == GOSSIP_ACTION_INFO_DEF + 1)
        {
            // Start invasion event (inline fallback)
            if (Map* map = creature->GetMap())
            {
                // Mark world state as active and initialize counters
                sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 1);
                sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 1);
                sWorldState->setWorldState(WORLD_STATE_INVASION_KILLS, 0);

                // Announce and log
                    if (player)
                        ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "The Zandalari invasion of Seeping Shores has begun! Defend the beach!");

                LOG_INFO("scripts", "Giant Isles Invasion: Event started by player %s", player ? player->GetName() : "Unknown");

                // Spawn defenders at defender points
                for (uint8 i = 0; i < 6; ++i)
                {
                    const InvasionSpawnPoint& point = DEFENDER_POINTS[i];
                    uint32 entry = NPC_PRIMAL_WARDEN;
                    if (i == 0) entry = NPC_PRIMAL_WARDEN_CAPTAIN;
                    else if (i == 3 || i == 4) entry = NPC_PRIMAL_WARDEN_SERGEANT;
                    else if (i == 1 || i == 2) entry = NPC_PRIMAL_WARDEN_MARKSMAN;

                    {
                        Position p(point.x, point.y, point.z, point.o);
                        if (Creature* defender = map->SummonCreature(entry, p))
                        {
                            defender->SetFaction(35);
                        }
                    }
                }
            }
        }
        else if (action == GOSSIP_ACTION_INFO_DEF + 2)
        {
            // Info text
            player->GetSession()->SendAreaTriggerMessage("The Invasion Horn summons defenders to fight off Zandalari attackers. Sound it to begin the defense event!");
        }

        return true;
    }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_invasion_hornAI(creature);
    }
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

            Talk(SAY_INVASION_START); // Yell on engage
        }

        void DamageTaken(Unit* /*attacker*/, uint32& /*damage*/, DamageEffectType /*damagetype*/, SpellSchoolMask /*damageSchoolMask*/) override
        {
            if (!enraged && me->HealthBelowPct(25))
            {
                enraged = true;
                DoCastSelf(SPELL_ENRAGE);
                Talk(SAY_WAVE_4_BOSS); // Enrage yell
            }
        }

        void JustDied(Unit* /*killer*/) override
        {
            // Notify: perform basic victory actions (inline fallback)
            if (Map* map = me->GetMap())
            {
                ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "Victory! The Zandalari invasion has been repelled!");

                // Set cooldown timestamp in world state
                sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE + 10, static_cast<uint32>(GameTime::GetGameTime().count()));

                // Placeholder for reward distribution
                LOG_INFO("scripts", "Giant Isles Invasion: Boss killed, victory triggered by boss %u", me->GetEntry());
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
    giant_isles_invasion() : WorldMapScript("giant_isles_invasion", MAP_GIANT_ISLES) { }

    class giant_isles_invasionMapScript : public InstanceScript
    {
    public:
        explicit giant_isles_invasionMapScript(Map* map) : InstanceScript(map), _invasionPhase(INVASION_INACTIVE), _waveTimer(0), _spawnTimer(0), _killCount(0), _bossGUID() {}

        void StartInvasion(Player* starter)
        {
            if (_invasionPhase != INVASION_INACTIVE)
                return;

            sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 1);
            sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 1);
            sWorldState->setWorldState(WORLD_STATE_INVASION_KILLS, 0);

            _invasionPhase = INVASION_WAVE_1;
            _waveTimer = WAVE_1_DURATION;
            _spawnTimer = SPAWN_DELAY_FAST;
            _killCount = 0;

            if (starter)
                ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "The Zandalari invasion of Seeping Shores has begun! Defend the beach!");

            SpawnDefenders();
            LOG_INFO("scripts", "Giant Isles Invasion: Event started by player {}", starter ? starter->GetName() : "Unknown");
        }

        void OnCreatureKill(Creature* victim)
        {
            if (IsInvasionMob(victim->GetEntry()))
            {
                _killCount++;
                sWorldState->setWorldState(WORLD_STATE_INVASION_KILLS, _killCount);
            }
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

        void Update(uint32 diff) override
        {
            if (_invasionPhase == INVASION_INACTIVE || _invasionPhase == INVASION_VICTORY)
                return;

            if (_waveTimer <= diff)
                AdvanceWave();
            else
                _waveTimer -= diff;

            if (_spawnTimer <= diff)
            {
                SpawnWaveCreatures();
                _spawnTimer = GetSpawnDelay();
            }
            else
                _spawnTimer -= diff;

            if (CheckDefendersAlive() == 0 && _invasionPhase < INVASION_VICTORY)
                FailInvasion();
        }

    private:
        InvasionPhase _invasionPhase;
        uint32 _waveTimer;
        uint32 _spawnTimer;
        uint32 _killCount;
        ObjectGuid _bossGUID;
        std::vector<ObjectGuid> _defenderGuids;
        std::vector<ObjectGuid> _invaderGuids;

        void AdvanceWave()
        {
            switch (_invasionPhase)
            {
                case INVASION_WAVE_1:
                    _invasionPhase = INVASION_WAVE_2;
                    _waveTimer = WAVE_2_DURATION;
                    _spawnTimer = SPAWN_DELAY_NORMAL;
                    sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 2);
                    ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "Wave 2: Zandalari warriors assault the shores!");
                    break;
                case INVASION_WAVE_2:
                    _invasionPhase = INVASION_WAVE_3;
                    _waveTimer = WAVE_3_DURATION;
                    _spawnTimer = SPAWN_DELAY_NORMAL;
                    sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 3);
                    ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "Wave 3: Elite Zandalari forces arrive!");
                    break;
                case INVASION_WAVE_3:
                    _invasionPhase = INVASION_WAVE_4_BOSS;
                    _waveTimer = WAVE_4_DURATION;
                    sWorldState->setWorldState(WORLD_STATE_INVASION_WAVE, 4);
                    ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "BOSS WAVE: Warlord Zul'mar has arrived with his honor guard!");
                    SpawnBoss();
                    break;
                case INVASION_WAVE_4_BOSS:
                    if (Creature* boss = instance->GetCreature(_bossGUID))
                    {
                        if (!boss->IsAlive())
                            OnBossKilled();
                    }
                    break;
                default:
                    break;
            }
        }

        void SpawnDefenders()
        {
            for (uint8 i = 0; i < 6; ++i)
            {
                const InvasionSpawnPoint& point = DEFENDER_POINTS[i];
                uint32 entry = NPC_PRIMAL_WARDEN;
                if (i == 0) entry = NPC_PRIMAL_WARDEN_CAPTAIN;
                else if (i == 3 || i == 4) entry = NPC_PRIMAL_WARDEN_SERGEANT;
                else if (i == 1 || i == 2) entry = NPC_PRIMAL_WARDEN_MARKSMAN;

                Position p(point.x, point.y, point.z, point.o);
                if (Creature* defender = instance->SummonCreature(entry, p))
                {
                    _defenderGuids.push_back(defender->GetGUID());
                    defender->SetFaction(35);
                }
            }
        }

        void SpawnWaveCreatures()
        {
            uint32 entry = GetWaveCreatureEntry();
            if (entry == 0)
                return;

            for (uint8 i = 0; i < 3; ++i)
            {
                const InvasionSpawnPoint& spawnPoint = SPAWN_POINTS[i];
                const InvasionSpawnPoint& targetPoint = TARGET_POINTS[i];
                Position p(spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.o);
                if (Creature* invader = instance->SummonCreature(entry, p))
                {
                    _invaderGuids.push_back(invader->GetGUID());
                    invader->SetFaction(16);
                    invader->GetMotionMaster()->MovePoint(1, targetPoint.x, targetPoint.y, targetPoint.z);
                }
            }
        }

        void SpawnBoss()
        {
            const InvasionSpawnPoint& spawnPoint = SPAWN_POINTS[1];
            const InvasionSpawnPoint& targetPoint = TARGET_POINTS[1];
            Position p(spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.o);
            if (Creature* boss = instance->SummonCreature(NPC_WARLORD_ZULMAR, p))
            {
                _bossGUID = boss->GetGUID();
                boss->SetFaction(16);
                boss->GetMotionMaster()->MovePoint(1, targetPoint.x, targetPoint.y, targetPoint.z);

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
                    if (Creature* guard = instance->SummonCreature(NPC_ZANDALARI_HONOR_GUARD, gp))
                    {
                        _invaderGuids.push_back(guard->GetGUID());
                        guard->SetFaction(16);
                        float angle = i * M_PI / 2.0f;
                        guard->GetMotionMaster()->MoveFollow(boss, guardDistance, angle, MOTION_SLOT_ACTIVE);
                        if (guard->AI())
                            guard->AI()->SetGUID(boss->GetGUID(), 0);
                    }
                }
            }
        }

        uint32 GetWaveCreatureEntry() const
        {
            switch (_invasionPhase)
            {
                case INVASION_WAVE_1:
                    return RAND(NPC_ZANDALARI_INVADER, NPC_ZANDALARI_SCOUT, NPC_ZANDALARI_SPEARMAN);
                case INVASION_WAVE_2:
                    return RAND(NPC_ZANDALARI_WARRIOR, NPC_ZANDALARI_BERSERKER, NPC_ZANDALARI_SHADOW_HUNTER);
                case INVASION_WAVE_3:
                    return RAND(NPC_ZANDALARI_BLOOD_GUARD, NPC_ZANDALARI_WITCH_DOCTOR, NPC_ZANDALARI_BEAST_TAMER);
                default:
                    return 0;
            }
        }

        uint32 GetSpawnDelay() const
        {
            switch (_invasionPhase)
            {
                case INVASION_WAVE_1:
                    return SPAWN_DELAY_FAST;
                case INVASION_WAVE_2:
                case INVASION_WAVE_3:
                    return SPAWN_DELAY_NORMAL;
                default:
                    return SPAWN_DELAY_SLOW;
            }
        }

        Creature* GetNearestDefender(Creature* invader) const
        {
            Creature* nearest = nullptr;
            float minDist = 999.0f;
            for (const auto& guid : _defenderGuids)
            {
                if (Creature* defender = instance->GetCreature(guid))
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

        uint32 CheckDefendersAlive() const
        {
            uint32 count = 0;
            for (const auto& guid : _defenderGuids)
            {
                if (Creature* defender = instance->GetCreature(guid))
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

        void FailInvasion()
        {
            _invasionPhase = INVASION_FAILED;
            ChatHandler(nullptr).SendWorldText(LANG_EVENTMESSAGE, "Defeat! The Zandalari have overrun Seeping Shores!");
            sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 0);
            CleanupInvasion();
            LOG_INFO("scripts", "Giant Isles Invasion: Event failed");
        }

        void RewardParticipants()
        {
            // Placeholder for reward distribution
        }

        void CleanupInvasion()
        {
            for (const auto& guid : _invaderGuids)
            {
                if (Creature* invader = instance->GetCreature(guid))
                    invader->DespawnOrUnsummon(5s);
            }
            _invaderGuids.clear();

            for (const auto& guid : _defenderGuids)
            {
                if (Creature* defender = instance->GetCreature(guid))
                    defender->DespawnOrUnsummon(30s);
            }
            _defenderGuids.clear();

            sWorldState->setWorldState(WORLD_STATE_INVASION_ACTIVE, 0);
            _invasionPhase = INVASION_INACTIVE;
        }
    };

    InstanceScript* GetInstanceScript(Map* map) const
    {
        return new giant_isles_invasionMapScript(map);
    }
};

// ============================================================================
// SCRIPT REGISTRATION
// ============================================================================

void AddSC_giant_isles_invasion()
{
    new npc_invasion_horn();
    new npc_invasion_commander();
    new giant_isles_invasion();
}
