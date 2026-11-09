/*
 * Giant Isles - Zone Scripts
 * ============================================================================
 * Custom zone ported from Pandaria's Isle of Giants
 * Features:
 *   - Zone announcements when players enter
 *   - Daily rotation system for world bosses
 *   - Special events and triggers
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "World.h"
#include "Chat.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "DC/CrossSystem/CrossSystemWorldBossMgr.h"
#include "DC/CrossSystem/CrossSystemDbSchema.h"
#include "MapMgr.h"
#include "ObjectMgr.h"

#include <algorithm>
#include <unordered_map>
#include <vector>
#include <optional>
#include "dc_update_profiler.h"

// ============================================================================
// ZONE CONSTANTS
// ============================================================================

enum GiantIslesData
{
    // Map and top-level zone (AreaTable). The world bosses are registered under
    // this zone in CrossSystemScripts.cpp.
    MAP_GIANT_ISLES             = 1405,
    ZONE_GIANT_ISLES            = 5006,

    // World Boss Entries
    NPC_OONDASTA                = 400100,
    NPC_THOK                    = 400101,
    NPC_NALAK                   = 400102,

    // Boss Add Entries
    NPC_YOUNG_OONDASTA          = 400400,
    NPC_PACK_RAPTOR             = 400401,
    NPC_STORM_SPARK             = 400402,
    NPC_STATIC_CLOUD            = 400403,

    // NPC Entries
    NPC_ELDER_ZULJIN            = 400200,
    NPC_WITCH_DOCTOR            = 400201,
    NPC_ROKHAN                  = 400202,

    // Rare Elite Entries (Static)
    NPC_PRIMAL_DIREHORN         = 400050,
    NPC_CHAOS_REX               = 400051,
    NPC_ANCIENT_PRIMORDIAL      = 400052,
    NPC_SAVAGE_MATRIARCH        = 400053,
    NPC_ALPHA_RAPTOR            = 400054,

    // Random Rare Spawns (Dynamic - spawned by zone script)
    NPC_BONECRUSHER             = 400055,
    NPC_GORESPINE               = 400056,
    NPC_VENOMFANG               = 400057,
    NPC_SKYSCREAMER             = 400058,
    NPC_GULROK                  = 400059,

    // Spawn timer constants
    RARE_SPAWN_TIMER_MIN        = 30 * 60 * 1000,    // 30 minutes minimum
    RARE_SPAWN_TIMER_MAX        = 90 * 60 * 1000,    // 90 minutes maximum
    RARE_DESPAWN_TIMER          = 30 * 60 * 1000,    // 30 minutes if not killed
    RARE_ALIVE_CHECK_MS         = 10 * 1000,
};

// The rotation's hold on a boss that is off today: longer than a boss ever stays
// off, and topped up before it could run out. No real respawn delay comes near the
// floor, which is how the hold is told apart from the timer of a boss killed today.
constexpr uint32 ROTATION_HOLD_SEC = 7 * DAY;
constexpr uint32 ROTATION_HOLD_FLOOR_SEC = ROTATION_HOLD_SEC / 2;
constexpr uint32 ROTATION_CHECK_SEC = 10;
constexpr uint32 SCHEDULE_REFRESH_SEC = 5 * MINUTE;

// ============================================================================
// ZONE ANNOUNCEMENT MESSAGES
// ============================================================================

constexpr char const* ZONE_ENTER_MESSAGE = "|cFFFF8000[Giant Isles]|r Welcome to the |cFF00FF00Giant Isles|r! "
    "Ancient dinosaurs roam these primordial lands. Beware of world bosses!";

// These messages are for future world boss spawn announcements
[[maybe_unused]] constexpr char const* BOSS_OONDASTA_SPAWN = "|cFFFF0000[World Boss]|r |cFFFFFF00Oondasta, King of Dinosaurs|r "
    "has awakened in |cFF00FF00Slippy Quagmire|r! Rally your forces!";

[[maybe_unused]] constexpr char const* BOSS_THOK_SPAWN = "|cFFFF0000[World Boss]|r |cFFFFFF00Thok the Bloodthirsty|r "
    "stalks the hunt in |cFF00FF00Oozing Overgrowth|r! Prepare for battle!";

[[maybe_unused]] constexpr char const* BOSS_NALAK_SPAWN = "|cFFFF0000[World Boss]|r |cFFFFFF00Nalak the Storm Lord|r "
    "descends upon |cFF00FF00Moist Ridge|r! The storm is coming!";

[[maybe_unused]] constexpr char const* BOSS_KILLED_MESSAGE = "|cFFFF8000[Giant Isles]|r |cFF00FF00%s|r has been defeated! "
    "A new world boss will appear tomorrow.";

constexpr char const* RARE_SPAWN_MESSAGE = "|cFFFF8000[Giant Isles]|r A rare creature |cFF00FF00{}|r "
    "has been spotted! Hunt it down for valuable rewards!";

// ============================================================================
// RANDOM RARE SPAWN DATA
// ============================================================================

struct RareSpawnLocation
{
    float x;
    float y;
    float z;
    float o;
};

// Potential spawn locations for random rares, on MoP's own dinosaur grounds and
// clear of the camps, the tar pits and the invasion's beach.
static const std::vector<RareSpawnLocation> RareSpawnPoints = {
    { 6147.5f, 1073.3f, 61.2f, 3.13f },  // Slippy Quagmire, east bank
    { 6155.8f, 1142.7f, 61.3f, 6.05f },  // Slippy Quagmire, north bank
    { 6102.3f, 1243.7f, 64.1f, 1.16f },  // Oozing Overgrowth, south slope
    { 5979.1f, 1397.9f, 86.3f, 4.65f },  // Oozing Overgrowth, plateau
    { 6118.2f, 1550.2f, 31.9f, 0.44f },  // Sticky Puddles, lower shelf
    { 5967.4f,  852.1f, 44.5f, 2.19f },  // Weeping Swallow
    { 6119.0f, 1517.4f, 43.7f, 0.40f },  // Sticky Puddles, upper shelf
    { 5924.0f,  709.9f, 24.4f, 1.60f },  // Slimer Bay heights
};

// Random rare NPC entries that can spawn dynamically
static const std::vector<uint32> RandomRareEntries = {
    400055,  // Bonecrusher - Primal Horror (massive devilsaur)
    400056,  // Gorespine the Impaler - Spiked Nightmare (armored stegodon)
    400057,  // Venomfang - Toxic Terror (poison raptor)
    400058,  // Skyscreamer - Chaos Windlord (storm pterrordax)
    400059,  // Gul'rok the Cursed - Primal Witch Doctor (troll caster)
};

// Get random rare entry
static uint32 GetRandomRareEntry()
{
    if (RandomRareEntries.empty())
        return 0;
    return RandomRareEntries[urand(0, RandomRareEntries.size() - 1)];
}

// Get random spawn location
static RareSpawnLocation GetRandomSpawnLocation()
{
    if (RareSpawnPoints.empty())
        return { 0.0f, 0.0f, 0.0f, 0.0f };
    return RareSpawnPoints[urand(0, RareSpawnPoints.size() - 1)];
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Per-player state lives on the player (CustomData), not in a global map. The zone
// hook runs inside Player::Update on the map-worker threads, and a shared
// unordered_map written from several workers at once corrupts its bucket chain
// (the FreezeDetector hangs). A player is only ever updated by one thread at a time,
// and the state goes away with the Player object at logout.
struct GiantIslesPlayerState : public DataMap::Base
{
    // Set on entry so the welcome is sent once per visit, not on every
    // UpdateZone call (teleport acks and resurrection repeat the same zone).
    bool inZone = false;

    // Last whisper time from the Spirit NPC, to avoid repeated whisper spam.
    uint32 lastSpiritWhisperSec = 0;
};

static constexpr char const* GIANT_ISLES_PLAYER_STATE_KEY = "dc_giant_isles_player_state";

// ============================================================================
// WORLD BOSS ROTATION HELPERS
// ============================================================================

// Today's bosses, refreshed by the rotation check on the world thread.
static std::vector<uint32> sTodaysBossEntries;

static Creature* FindSpawnedCreatureBySpawnId(Map* map, uint32 spawnId, uint32 entry)
{
    if (!map)
        return nullptr;

    // A dead copy can sit beside the live one for a tick while a spawn is replaced.
    Creature* found = nullptr;
    auto bounds = map->GetCreatureBySpawnIdStore().equal_range(spawnId);
    for (auto itr = bounds.first; itr != bounds.second; ++itr)
    {
        found = itr->second;
        if (found->IsAlive())
            return found;
    }

    if (found)
        return found;

    return map->GetCreature(ObjectGuid::Create<HighGuid::Unit>(entry, spawnId));
}

// Brings one boss in line with today's schedule and tells the manager where it
// stands. This runs on a timer, not once a day: a boss only exists while its grid
// is loaded, and that way a restart, a grid that loads late and a new day all take
// the same path. Bosses are dynamic spawns, so one that is down has no creature at
// all and its respawn timer on the map is what keeps it down.
static void ApplyRotationToBoss(uint32 bossEntry, bool scheduled)
{
    if (!sWorldBossMgr)
        return;

    DarkChaos::CrossSystem::WorldBossInfo const* info = sWorldBossMgr->GetBossInfo(bossEntry);
    if (!info || info->spawnId == 0)
        return;

    // No map means nobody has been on the island since the restart; timers load with it.
    Map* map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);
    Creature* boss = map ? FindSpawnedCreatureBySpawnId(map, info->spawnId, bossEntry) : nullptr;

    time_t const now = GameTime::GetGameTime().count();
    time_t const respawnAt = map ? map->GetCreatureRespawnTime(info->spawnId) : 0;
    uint32 timer = respawnAt > now ? static_cast<uint32>(respawnAt - now) : 0;
    bool const held = timer > ROTATION_HOLD_FLOOR_SEC;
    bool alive = boss && boss->IsAlive();

    if (scheduled)
    {
        // Its day has come. A boss killed today keeps its normal timer.
        if (held && boss && !alive)
        {
            // The creature that replaces this one reports in on the next check.
            boss->Respawn(true);
            return;
        }

        if (held && !boss)
        {
            map->ForceCreatureRespawn(info->spawnId);
            timer = 0;
        }
    }
    else if (alive)
    {
        // A fight that runs into the next day is finished first.
        if (!boss->IsInCombat())
        {
            sWorldBossMgr->OnBossDespawned(boss);
            boss->DespawnOrUnsummon(0ms, Seconds(ROTATION_HOLD_SEC));
            alive = false;
        }
    }
    else if (map && !held)
    {
        if (boss)
        {
            boss->SetRespawnTime(ROTATION_HOLD_SEC);
            boss->SaveRespawnTime();
        }
        else
        {
            time_t holdUntil = now + ROTATION_HOLD_SEC;
            map->SaveCreatureRespawnTime(info->spawnId, holdUntil);
        }
    }

    // A respawn the map has not run yet (it runs every 5 s, and waits for the grid to load)
    // counts as up. A dynamic respawn is a new creature that never runs JustRespawned, so
    // the manager announces the boss's return here: when the reported status turns active,
    // whether or not the creature exists yet, and never a second time when it shows up.
    bool const up = alive || (scheduled && timer == 0);
    sWorldBossMgr->SetBossState(bossEntry, up, scheduled && !up ? static_cast<int32>(timer) : -1,
        alive ? boss : nullptr);
}

static bool WorldBossScheduleTableExists()
{
    static std::optional<bool> cached;
    if (cached.has_value())
        return cached.value();

    cached = DC::DbSchema::WorldColumnExists("dc_world_boss_schedule", "boss_entry");
    return cached.value();
}

static std::vector<uint32> GetScheduledBossEntriesForDay(uint8 day)
{
    std::vector<uint32> entries;

    if (!WorldBossScheduleTableExists())
        return entries;

    QueryResult result = WorldDatabase.Query(
        "SELECT `boss_entry` FROM `dc_world_boss_schedule` WHERE `day_of_week` = {} AND `enabled` = 1",
        day);

    if (!result)
        return entries;

    do
    {
        Field* fields = result->Fetch();
        entries.push_back(fields[0].Get<uint32>());
    } while (result->NextRow());

    return entries;
}

static std::string FormatShortDuration(int32 totalSeconds)
{
    if (totalSeconds < 0)
        return "?";

    int32 seconds = totalSeconds;
    int32 hours = seconds / 3600;
    seconds %= 3600;
    int32 minutes = seconds / 60;
    seconds %= 60;

    if (hours > 0)
        return std::to_string(hours) + "h " + std::to_string(minutes) + "m";
    if (minutes > 0)
        return std::to_string(minutes) + "m " + std::to_string(seconds) + "s";
    return std::to_string(seconds) + "s";
}

static void SendBossStatusList(Player* player)
{
    if (!player || !player->GetSession())
        return;

    if (!sWorldBossMgr)
        return;

    std::vector<DarkChaos::CrossSystem::WorldBossInfo const*> bossesInZone;
    for (DarkChaos::CrossSystem::WorldBossInfo const* info : sWorldBossMgr->GetAllBosses())
    {
        if (info && info->zoneId == ZONE_GIANT_ISLES)
            bossesInZone.push_back(info);
    }

    ChatHandler handler(player->GetSession());
    handler.PSendSysMessage("|cFFFF8000[Giant Isles]|r World boss status:");

    auto sendOne = [&](char const* displayName, DarkChaos::CrossSystem::WorldBossInfo const* info)
    {
        if (!displayName || !displayName[0])
            displayName = "Unknown";

        if (!info)
        {
            handler.PSendSysMessage(" - |cFFFFFF00{}|r: |cFFAAAAAAUnregistered|r", displayName);
            return;
        }

        if (info->isActive)
        {
            handler.PSendSysMessage(" - |cFFFFFF00{}|r: |cFF00FF00Active|r", displayName);
            return;
        }

        if (info->respawnCountdown > 0)
        {
            std::string t = FormatShortDuration(info->respawnCountdown);
            handler.PSendSysMessage(" - |cFFFFFF00{}|r: |cFFFFFF00Respawn in {}|r", displayName, t.c_str());
            return;
        }

        handler.PSendSysMessage(" - |cFFFFFF00{}|r: |cFFAAAAAANot today|r", displayName);
    };

    // Preferred: use the WorldBossMgr zone registrations.
    if (!bossesInZone.empty())
    {
        for (DarkChaos::CrossSystem::WorldBossInfo const* info : bossesInZone)
            sendOne(info->displayName.c_str(), info);
        return;
    }

    // Fallback: show known Giant Isles bosses even if their registered zoneId isn't set to ZONE_GIANT_ISLES yet.
    sendOne("Oondasta", sWorldBossMgr->GetBossInfo(NPC_OONDASTA));
    sendOne("Thok", sWorldBossMgr->GetBossInfo(NPC_THOK));
    sendOne("Nalak", sWorldBossMgr->GetBossInfo(NPC_NALAK));
}

// Get current day of week (0 = Sunday, 6 = Saturday)
uint8 GetCurrentDayOfWeek()
{
    time_t rawtime = GameTime::GetGameTime().count();
    struct tm* timeinfo = localtime(&rawtime);
    return timeinfo->tm_wday;
}

// Get which boss should be active today based on rotation
uint32 GetActiveBossEntry()
{
    uint8 day = GetCurrentDayOfWeek();

    // Boss rotation: 3 bosses across 7 days
    // Mon, Thu = Oondasta
    // Tue, Fri = Thok
    // Wed, Sat, Sun = Nalak
    switch (day)
    {
        case 0: // Sunday
        case 3: // Wednesday
        case 6: // Saturday
            return NPC_NALAK;
        case 1: // Monday
        case 4: // Thursday
            return NPC_OONDASTA;
        case 2: // Tuesday
        case 5: // Friday
            return NPC_THOK;
        default:
            return NPC_OONDASTA;
    }
}

// ============================================================================
// ZONE SCRIPT - GIANT ISLES
// ============================================================================

class zone_giant_isles : public PlayerScript
{
public:
    zone_giant_isles() : PlayerScript("zone_giant_isles", { PLAYERHOOK_ON_UPDATE_ZONE }) { }

    void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 /*newArea*/) override
    {
        if (!player)
            return;

        // Runs on the map workers for every player: only touch state owned by this player.
        GiantIslesPlayerState* state = player->CustomData.Get<GiantIslesPlayerState>(GIANT_ISLES_PLAYER_STATE_KEY);
        if (newZone != ZONE_GIANT_ISLES)
        {
            // Left the zone (or never entered it): the next entry is announced again.
            if (state)
                state->inZone = false;
            return;
        }

        if (!state)
            state = player->CustomData.GetDefault<GiantIslesPlayerState>(GIANT_ISLES_PLAYER_STATE_KEY);

        // Only respond when transitioning into the zone.
        if (state->inZone)
            return;

        state->inZone = true;

        // Send welcome message
        ChatHandler(player->GetSession()).PSendSysMessage("{}", ZONE_ENTER_MESSAGE);

        // Tell the player which boss is up today, from the same schedule the rotation enforces
        std::vector<uint32> todaysBosses = sTodaysBossEntries;
        if (todaysBosses.empty())
            todaysBosses.push_back(GetActiveBossEntry());

        for (uint32 todaysBoss : todaysBosses)
        {
            std::string bossName;
            std::string location;

            switch (todaysBoss)
            {
                case NPC_OONDASTA:
                    bossName = "Oondasta, King of Dinosaurs";
                    location = "Slippy Quagmire";
                    break;
                case NPC_THOK:
                    bossName = "Thok the Bloodthirsty";
                    location = "Oozing Overgrowth";
                    break;
                case NPC_NALAK:
                    bossName = "Nalak the Storm Lord";
                    location = "Moist Ridge";
                    break;
                default:
                    continue;
            }

            bool bossActive = sWorldBossMgr && sWorldBossMgr->IsBossActive(todaysBoss);

            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF8000[Giant Isles]|r Today's world boss: |cFFFFFF00{}|r in |cFF00FF00{}|r{}",
                bossName.c_str(), location.c_str(), bossActive ? " |cFF00FF00(Active)|r" : "");
        }

        SendBossStatusList(player);
    }
};

// ============================================================================
// PLAYER SCRIPT - ZONE TRACKING (removed duplicate - merged into zone_giant_isles)
// ============================================================================

// ============================================================================
// WORLD SCRIPT - BOSS ROTATION & RANDOM RARE SPAWN MANAGEMENT
// ============================================================================

class world_giant_isles_manager : public WorldScript
{
public:
    world_giant_isles_manager() : WorldScript("world_giant_isles_manager")
    {
        _nextRareSpawnTime = Milliseconds(0);
        _nextRareCheckTime = Milliseconds(0);
        _currentRareGUID = ObjectGuid::Empty;
        _rareIsAlive = false;
        _lastRotationCheckSec = 0;
        _lastScheduleFetchSec = 0;
        _cachedScheduleDay = 255;
    }

    void OnStartup() override
    {
        LOG_INFO("scripts.dc", "Giant Isles zone manager loaded.");
        LOG_INFO("scripts.dc", "Today's active boss: Entry {}", GetActiveBossEntry());

        // Initialize first rare spawn timer (spawn first rare after 5-15 minutes)
        _nextRareSpawnTime = GameTime::GetGameTimeMS() + Milliseconds(urand(5 * 60 * 1000, 15 * 60 * 1000));
        // LOG_INFO("scripts.dc", "Giant Isles: First random rare spawn scheduled.");
    }

    // Called every server update - handles rare spawn timer
    void OnUpdate(uint32 /*diff*/) override
    {
        DarkChaos::ScopedUpdateProfiler _prof("GiantIslesZone");
        // Check if it's time to spawn a random rare
        Milliseconds currentTime = GameTime::GetGameTimeMS();

        if (!_rareIsAlive && currentTime >= _nextRareSpawnTime)
        {
            TrySpawnRandomRare();
        }
        else if (_rareIsAlive && currentTime >= _nextRareCheckTime)
        {
            CheckCurrentRare();
        }

        // Check and apply daily boss rotation.
        ApplyBossRotation();
    }

private:
    Milliseconds _nextRareSpawnTime;
    Milliseconds _nextRareCheckTime;
    ObjectGuid _currentRareGUID;
    bool _rareIsAlive;
    time_t _lastRotationCheckSec;
    time_t _lastScheduleFetchSec;
    uint8 _cachedScheduleDay;

    void ApplyBossRotation()
    {
        time_t nowSec = GameTime::GetGameTime().count();

        if (_lastRotationCheckSec != 0 && (nowSec - _lastRotationCheckSec) < ROTATION_CHECK_SEC)
            return;

        _lastRotationCheckSec = nowSec;

        // Throttled apart from the check to avoid excessive DB queries.
        uint8 day = GetCurrentDayOfWeek();
        if (day != _cachedScheduleDay || (nowSec - _lastScheduleFetchSec) >= SCHEDULE_REFRESH_SEC)
        {
            sTodaysBossEntries = GetScheduledBossEntriesForDay(day);
            if (sTodaysBossEntries.empty())
                sTodaysBossEntries.push_back(GetActiveBossEntry());

            _cachedScheduleDay = day;
            _lastScheduleFetchSec = nowSec;
        }

        // Enable scheduled bosses, disable the others.
        for (uint32 bossEntry : { uint32(NPC_OONDASTA), uint32(NPC_THOK), uint32(NPC_NALAK) })
        {
            auto const found = std::find(sTodaysBossEntries.begin(), sTodaysBossEntries.end(), bossEntry);
            ApplyRotationToBoss(bossEntry, found != sTodaysBossEntries.end());
        }
    }

    void TrySpawnRandomRare()
    {
        // Get a random rare entry and spawn location
        uint32 rareEntry = GetRandomRareEntry();
        RareSpawnLocation loc = GetRandomSpawnLocation();

        if (rareEntry == 0)
        {
            ScheduleNextRareSpawn();
            return;
        }

        // A rare nobody can hunt would only burn its despawn timer: an empty
        // island rolls again later.
        Map* map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);
        if (!map || !map->HavePlayers())
        {
            ScheduleNextRareSpawn();
            return;
        }

        Creature* rare = map->SummonCreature(rareEntry, Position(loc.x, loc.y, loc.z, loc.o), nullptr, RARE_DESPAWN_TIMER);
        if (!rare)
        {
            LOG_WARN("scripts.dc", "Giant Isles: failed to spawn random rare {}", rareEntry);
            ScheduleNextRareSpawn();
            return;
        }

        rare->setActive(true);
        _currentRareGUID = rare->GetGUID();
        _rareIsAlive = true;
        _nextRareCheckTime = GameTime::GetGameTimeMS() + Milliseconds(RARE_ALIVE_CHECK_MS);

        std::string const name = rare->GetName();
        map->DoForAllPlayers([&](Player* player)
        {
            if (player && player->GetSession())
                ChatHandler(player->GetSession()).PSendSysMessage(RARE_SPAWN_MESSAGE, name);
        });

        LOG_INFO("scripts.dc", "Giant Isles: random rare {} spawned at ({}, {}, {})", name, loc.x, loc.y, loc.z);
    }

    // The next rare is only rolled once the current one has died or despawned.
    void CheckCurrentRare()
    {
        _nextRareCheckTime = GameTime::GetGameTimeMS() + Milliseconds(RARE_ALIVE_CHECK_MS);

        Map* map = sMapMgr->FindMap(MAP_GIANT_ISLES, 0);
        Creature* rare = map ? map->GetCreature(_currentRareGUID) : nullptr;
        if (rare && rare->IsAlive())
            return;

        _currentRareGUID.Clear();
        ScheduleNextRareSpawn();
    }

    void ScheduleNextRareSpawn()
    {
        // Schedule next rare spawn between 30-90 minutes from now
        _nextRareSpawnTime = GameTime::GetGameTimeMS() +
            Milliseconds(urand(RARE_SPAWN_TIMER_MIN, RARE_SPAWN_TIMER_MAX));
        _rareIsAlive = false;

        // LOG_DEBUG("scripts.dc", "Giant Isles: Next random rare spawn scheduled.");
    }
};

// ============================================================================
// NPC SCRIPT - SPIRIT OF THE PRIMAL (Daily quest giver)
// ============================================================================

class npc_spirit_of_primal : public CreatureScript
{
public:
    npc_spirit_of_primal() : CreatureScript("npc_spirit_of_primal") { }

    struct npc_spirit_of_primalAI : public ScriptedAI
    {
        npc_spirit_of_primalAI(Creature* creature) : ScriptedAI(creature) { }

        void Reset() override
        {
            // Ethereal appearance
            me->SetDisplayId(me->GetNativeDisplayId());
        }

        void MoveInLineOfSight(Unit* who) override
        {
            if (!who || !who->IsPlayer())
                return;

            if (me->GetDistance(who) < 15.0f)
            {
                // Whisper to nearby players about the zone
                Player* player = who->ToPlayer();
                if (!player)
                    return;

                uint32 nowSec = static_cast<uint32>(GameTime::GetGameTime().count());
                // Per-player state: this AI runs on the map worker that also owns the player.
                uint32& lastSec = player->CustomData.GetDefault<GiantIslesPlayerState>(
                    GIANT_ISLES_PLAYER_STATE_KEY)->lastSpiritWhisperSec;

                // 60s cooldown per player to avoid spam.
                if (lastSec != 0 && (nowSec - lastSec) < 60)
                    return;

                lastSec = nowSec;
                me->Whisper("The ancient spirits stir... The dinosaurs grow restless.", LANG_UNIVERSAL, player);
            }
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_spirit_of_primalAI(creature);
    }
};

// ============================================================================
// CREATURE DEATH ANNOUNCEMENTS
// ============================================================================

class creature_giant_isles_death : public CreatureScript
{
public:
    creature_giant_isles_death() : CreatureScript("creature_giant_isles_death") { }

    struct creature_giant_isles_deathAI : public ScriptedAI
    {
        creature_giant_isles_deathAI(Creature* creature) : ScriptedAI(creature) { }

        void JustDied(Unit* /*killer*/) override
        {
            // Log world boss deaths (zone-wide announcements handled by broadcast to zone players)
            switch (me->GetEntry())
            {
                case NPC_OONDASTA:
                    LOG_INFO("scripts.dc", "Giant Isles: Oondasta defeated");
                    break;
                case NPC_THOK:
                    LOG_INFO("scripts.dc", "Giant Isles: Thok defeated");
                    break;
                case NPC_NALAK:
                    LOG_INFO("scripts.dc", "Giant Isles: Nalak defeated");
                    break;
                // Static rare elite deaths
                case NPC_PRIMAL_DIREHORN:
                case NPC_CHAOS_REX:
                case NPC_ANCIENT_PRIMORDIAL:
                case NPC_SAVAGE_MATRIARCH:
                case NPC_ALPHA_RAPTOR:
                    LOG_INFO("scripts.dc", "Giant Isles: Rare {} defeated", me->GetName());
                    break;
                // Random rare spawn deaths
                case NPC_BONECRUSHER:
                case NPC_GORESPINE:
                case NPC_VENOMFANG:
                case NPC_SKYSCREAMER:
                case NPC_GULROK:
                    LOG_INFO("scripts.dc", "Giant Isles: Random rare {} defeated", me->GetName());
                    break;
            }
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new creature_giant_isles_deathAI(creature);
    }
};

// ============================================================================
// RARE SPAWN ANNOUNCEMENTS
// ============================================================================

class creature_giant_isles_rare_spawn : public CreatureScript
{
public:
    creature_giant_isles_rare_spawn() : CreatureScript("creature_giant_isles_rare_spawn") { }

    struct creature_rare_spawnAI : public ScriptedAI
    {
        creature_rare_spawnAI(Creature* creature) : ScriptedAI(creature) { }

        void InitializeAI() override
        {
            // Log rare spawn
            LOG_INFO("scripts.dc", "Giant Isles: Rare creature {} spawned", me->GetName());
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new creature_rare_spawnAI(creature);
    }
};

// ============================================================================
// GAMEOBJECT SCRIPT - ANCIENT ALTAR (for world boss summoning)
// ============================================================================

class go_ancient_primal_altar : public GameObjectScript
{
public:
    go_ancient_primal_altar() : GameObjectScript("go_ancient_primal_altar") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player || !go)
            return false;

        // Add gossip options
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Commune with the ancient spirits",
            GOSSIP_SENDER_MAIN, 1);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Inquire about today's world boss",
            GOSSIP_SENDER_MAIN, 2);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* /*go*/, uint32 /*sender*/, uint32 action) override
    {
        if (!player)
            return false;

        CloseGossipMenuFor(player);

        switch (action)
        {
            case 1: // Commune
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFF00FF00Ancient Voice:|r The dinosaurs remember a time before mortals. "
                    "Prove yourself worthy by defeating our champions.");
                break;
            case 2: // Boss info
            {
                uint32 activeBoss = GetActiveBossEntry();
                std::string bossName;
                switch (activeBoss)
                {
                    case NPC_OONDASTA: bossName = "Oondasta, King of Dinosaurs"; break;
                    case NPC_THOK: bossName = "Thok the Bloodthirsty"; break;
                    case NPC_NALAK: bossName = "Nalak the Storm Lord"; break;
                }
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFF00FF00Ancient Voice:|r Today, |cFFFFFF00{}|r roams the isles. "
                    "Gather your allies and face the challenge!", bossName.c_str());
                break;
            }
        }
        return true;
    }
};

// ============================================================================
// REGISTER SCRIPTS
// ============================================================================

void AddSC_giant_isles_zone()
{
    new zone_giant_isles();
    new world_giant_isles_manager();
    new npc_spirit_of_primal();
    new creature_giant_isles_death();
    new creature_giant_isles_rare_spawn();
    new go_ancient_primal_altar();
}
