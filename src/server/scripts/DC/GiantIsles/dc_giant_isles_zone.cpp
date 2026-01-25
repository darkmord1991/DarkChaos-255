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
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "World.h"
#include "Chat.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "DC/CrossSystem/CrossSystemWorldBossMgr.h"
#include "MapMgr.h"
#include "ObjectMgr.h"

#include <unordered_map>
#include <vector>
#include <optional>

// ============================================================================
// ZONE CONSTANTS
// ============================================================================

enum GiantIslesData
{
    // Zone/Area IDs (placeholder - needs actual custom zone ID)
    ZONE_GIANT_ISLES            = 5000,  // Custom zone ID

    // Subzone Area IDs
    AREA_DINOTAMER_CAMP         = 5001,
    AREA_PRIMAL_BASIN           = 5002,
    AREA_DEVILSAUR_GORGE        = 5003,
    AREA_RAPTOR_RIDGE           = 5004,
    AREA_THUNDERING_PEAKS       = 5005,
    AREA_BONE_WASTES            = 5006,
    AREA_ANCIENT_RUINS          = 5007,

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
};

// ============================================================================
// ZONE ANNOUNCEMENT MESSAGES
// ============================================================================

constexpr char const* ZONE_ENTER_MESSAGE = "|cFFFF8000[Giant Isles]|r Welcome to the |cFF00FF00Giant Isles|r! "
    "Ancient dinosaurs roam these primordial lands. Beware of world bosses!";

// These messages are for future world boss spawn announcements
[[maybe_unused]] constexpr char const* BOSS_OONDASTA_SPAWN = "|cFFFF0000[World Boss]|r |cFFFFFF00Oondasta, King of Dinosaurs|r "
    "has awakened in |cFF00FF00Devilsaur Gorge|r! Rally your forces!";

[[maybe_unused]] constexpr char const* BOSS_THOK_SPAWN = "|cFFFF0000[World Boss]|r |cFFFFFF00Thok the Bloodthirsty|r "
    "stalks the hunt in |cFF00FF00Raptor Ridge|r! Prepare for battle!";

[[maybe_unused]] constexpr char const* BOSS_NALAK_SPAWN = "|cFFFF0000[World Boss]|r |cFFFFFF00Nalak the Storm Lord|r "
    "descends upon |cFF00FF00Thundering Peaks|r! The storm is coming!";

[[maybe_unused]] constexpr char const* BOSS_KILLED_MESSAGE = "|cFFFF8000[Giant Isles]|r |cFF00FF00%s|r has been defeated! "
    "A new world boss will appear tomorrow.";

[[maybe_unused]] constexpr char const* RARE_SPAWN_MESSAGE = "|cFFFF8000[Giant Isles]|r A rare creature |cFF00FF00%s|r "
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

// Potential spawn locations for random rares (placeholder coords - update with actual zone coords)
static const std::vector<RareSpawnLocation> RareSpawnPoints = {
    { 0.0f, 0.0f, 0.0f, 0.0f },  // Devilsaur Gorge spawn point 1
    { 50.0f, 50.0f, 0.0f, 0.0f },  // Devilsaur Gorge spawn point 2
    { 100.0f, -50.0f, 0.0f, 0.0f },  // Raptor Ridge spawn point 1
    { -100.0f, 100.0f, 0.0f, 0.0f },  // Primal Basin spawn point 1
    { 200.0f, 200.0f, 0.0f, 0.0f },  // Bone Wastes spawn point 1
    { -150.0f, -150.0f, 0.0f, 0.0f },  // Ancient Ruins spawn point 1
    { 75.0f, -100.0f, 0.0f, 0.0f },  // Thundering Peaks spawn point 1
    { -200.0f, 50.0f, 0.0f, 0.0f },  // Beach area spawn point 1
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

// Track last known zone per player so we only announce on zone entry,
// not on every area update inside the same zone.
static std::unordered_map<ObjectGuid, uint32> sGiantIslesLastZoneByPlayer;

// Track last whisper time for the Spirit NPC to avoid repeated whisper spam.
static std::unordered_map<ObjectGuid, uint32> sSpiritLastWhisperSecByPlayer;

// ============================================================================
// WORLD BOSS ROTATION HELPERS
// ============================================================================

static Creature* FindSpawnedCreatureBySpawnId(Map* map, uint32 spawnId, uint32 entry)
{
    if (!map)
        return nullptr;

    auto bounds = map->GetCreatureBySpawnIdStore().equal_range(spawnId);
    if (bounds.first != bounds.second)
        return bounds.first->second;

    return map->GetCreature(ObjectGuid::Create<HighGuid::Unit>(entry, spawnId));
}

static bool LoadCreatureFromSpawnId(Map* map, uint32 spawnId)
{
    if (!map)
        return false;

    Creature* creature = new Creature();
    if (!creature->LoadCreatureFromDB(spawnId, map))
    {
        delete creature;
        return false;
    }

    sObjectMgr->AddCreatureToGrid(spawnId, sObjectMgr->GetCreatureData(spawnId));
    return true;
}

static bool SetWorldBossActive(uint32 bossEntry, bool active)
{
    if (!sWorldBossMgr)
        return false;

    DC::WorldBossInfo* info = sWorldBossMgr->GetBossInfo(bossEntry);
    if (!info || info->spawnId == 0)
        return false;

    CreatureData const* data = sObjectMgr->GetCreatureData(info->spawnId);
    if (!data)
        return false;

    Map* map = sMapMgr->FindMap(data->mapid, 0);
    if (!map)
        return false;

    Creature* creature = FindSpawnedCreatureBySpawnId(map, info->spawnId, bossEntry);
    if (!creature)
    {
        if (!LoadCreatureFromSpawnId(map, info->spawnId))
            return false;
        creature = FindSpawnedCreatureBySpawnId(map, info->spawnId, bossEntry);
    }

    if (!creature)
        return false;

    if (active)
    {
        creature->SetRespawnTime(0);
        creature->SaveRespawnTime();

        if (!creature->IsAlive())
            creature->Respawn();
    }
    else
    {
        creature->SetRespawnTime(7 * DAY);
        creature->SaveRespawnTime();
        creature->DespawnOrUnsummon(0ms);
    }

    return true;
}

static bool WorldBossScheduleTableExists()
{
    static std::optional<bool> cached;
    if (cached.has_value())
        return cached.value();

    QueryResult result = WorldDatabase.Query(
        "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_world_boss_schedule' AND COLUMN_NAME = 'boss_entry'");

    if (!result)
    {
        cached = false;
        return false;
    }

    Field* fields = result->Fetch();
    cached = (fields[0].Get<uint64>() > 0);
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

    std::vector<DC::WorldBossInfo const*> bossesInZone;
    for (DC::WorldBossInfo const* info : sWorldBossMgr->GetAllBosses())
    {
        if (info && info->zoneId == ZONE_GIANT_ISLES)
            bossesInZone.push_back(info);
    }

    ChatHandler handler(player->GetSession());
    handler.PSendSysMessage("|cFFFF8000[Giant Isles]|r World boss status:");

    auto sendOne = [&](char const* displayName, DC::WorldBossInfo const* info)
    {
        if (!displayName || !displayName[0])
            displayName = "Unknown";

        if (!info)
        {
            handler.PSendSysMessage(" - |cFFFFFF00%s|r: |cFFAAAAAAUnregistered|r", displayName);
            return;
        }

        if (info->isActive)
        {
            handler.PSendSysMessage(" - |cFFFFFF00%s|r: |cFF00FF00Active|r", displayName);
            return;
        }

        if (info->respawnCountdown > 0)
        {
            std::string t = FormatShortDuration(info->respawnCountdown);
            handler.PSendSysMessage(" - |cFFFFFF00%s|r: |cFFFFFF00Respawn in %s|r", displayName, t.c_str());
            return;
        }

        handler.PSendSysMessage(" - |cFFFFFF00%s|r: |cFFAAAAAAUnknown|r", displayName);
    };

    // Preferred: use the WorldBossMgr zone registrations.
    if (!bossesInZone.empty())
    {
        for (DC::WorldBossInfo const* info : bossesInZone)
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
    zone_giant_isles() : PlayerScript("zone_giant_isles") { }

    void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 /*newArea*/) override
    {
        if (!player)
            return;

        ObjectGuid playerGuid = player->GetGUID();
        uint32& lastZone = sGiantIslesLastZoneByPlayer[playerGuid];
        uint32 previousZone = lastZone;
        lastZone = newZone;

        // Only respond when transitioning into the zone.
        if (previousZone == newZone)
            return;

        // Only respond when entering Giant Isles
        if (newZone != ZONE_GIANT_ISLES)
            return;

        // Send welcome message
        ChatHandler(player->GetSession()).PSendSysMessage("%s", ZONE_ENTER_MESSAGE);

        // Check which boss is active and inform player
        uint32 activeBoss = GetActiveBossEntry();
        std::string bossName;
        std::string location;

        switch (activeBoss)
        {
            case NPC_OONDASTA:
                bossName = "Oondasta, King of Dinosaurs";
                location = "Devilsaur Gorge";
                break;
            case NPC_THOK:
                bossName = "Thok the Bloodthirsty";
                location = "Raptor Ridge";
                break;
            case NPC_NALAK:
                bossName = "Nalak the Storm Lord";
                location = "Thundering Peaks";
                break;
        }

        bool bossActive = sWorldBossMgr && sWorldBossMgr->IsBossActive(activeBoss);

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFF8000[Giant Isles]|r Today's world boss: |cFFFFFF00%s|r in |cFF00FF00%s|r%s",
            bossName.c_str(), location.c_str(), bossActive ? " |cFF00FF00(Active)|r" : "");

        SendBossStatusList(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;

        ObjectGuid guid = player->GetGUID();
        sGiantIslesLastZoneByPlayer.erase(guid);
        sSpiritLastWhisperSecByPlayer.erase(guid);
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
        _currentRareGUID = ObjectGuid::Empty;
        _rareIsAlive = false;
        _lastRotationDay = 255;
        _lastRotationKey = 0;
        _lastRotationCheckSec = 0;
        _lastScheduleFetchSec = 0;
        _cachedScheduleDay = 255;
    }

    void OnStartup() override
    {
        LOG_INFO("scripts.dc", "Giant Isles zone manager loaded.");
        LOG_INFO("scripts.dc", "Today's active boss: Entry {}", GetActiveBossEntry());

        // Apply daily boss rotation immediately on startup when map is available.
        ApplyBossRotation(true);

        // Initialize first rare spawn timer (spawn first rare after 5-15 minutes)
        _nextRareSpawnTime = GameTime::GetGameTimeMS() + Milliseconds(urand(5 * 60 * 1000, 15 * 60 * 1000));
        // LOG_INFO("scripts.dc", "Giant Isles: First random rare spawn scheduled.");
    }

    // Called every server update - handles rare spawn timer
    void OnUpdate(uint32 /*diff*/) override
    {
        // Check if it's time to spawn a random rare
        Milliseconds currentTime = GameTime::GetGameTimeMS();

        if (!_rareIsAlive && currentTime >= _nextRareSpawnTime)
        {
            TrySpawnRandomRare();
        }

        // Check and apply daily boss rotation.
        ApplyBossRotation(false);
    }

private:
    Milliseconds _nextRareSpawnTime;
    ObjectGuid _currentRareGUID;
    bool _rareIsAlive;
    uint8 _lastRotationDay;
    uint32 _lastRotationKey;
    time_t _lastRotationCheckSec;
    time_t _lastScheduleFetchSec;
    uint8 _cachedScheduleDay;
    std::vector<uint32> _cachedScheduledEntries;

    void ApplyBossRotation(bool force)
    {
        time_t nowSec = GameTime::GetGameTime().count();

        if (!force)
        {
            // Throttle rotation checks to avoid excessive DB queries.
            if (_lastRotationCheckSec != 0 && (nowSec - _lastRotationCheckSec) < 10)
                return;
            _lastRotationCheckSec = nowSec;
        }

        uint8 day = GetCurrentDayOfWeek();
        std::vector<uint32> scheduledEntries;

        bool needRefresh = force || day != _cachedScheduleDay;
        if (!needRefresh && _lastScheduleFetchSec != 0 && (nowSec - _lastScheduleFetchSec) >= 300)
            needRefresh = true;

        if (needRefresh)
        {
            _cachedScheduledEntries = GetScheduledBossEntriesForDay(day);
            _cachedScheduleDay = day;
            _lastScheduleFetchSec = nowSec;
        }

        scheduledEntries = _cachedScheduledEntries;

        if (scheduledEntries.empty())
            scheduledEntries.push_back(GetActiveBossEntry());

        uint32 rotationKey = 17;
        for (uint32 entry : scheduledEntries)
            rotationKey = rotationKey * 131 + entry;

        if (!force && day == _lastRotationDay && rotationKey == _lastRotationKey)
            return;

        _lastRotationDay = day;
        _lastRotationKey = rotationKey;

        auto isScheduled = [&](uint32 entry)
        {
            for (uint32 e : scheduledEntries)
            {
                if (e == entry)
                    return true;
            }
            return false;
        };

        // Enable scheduled bosses, disable the others.
        SetWorldBossActive(NPC_OONDASTA, isScheduled(NPC_OONDASTA));
        SetWorldBossActive(NPC_THOK, isScheduled(NPC_THOK));
        SetWorldBossActive(NPC_NALAK, isScheduled(NPC_NALAK));
    }

    void TrySpawnRandomRare()
    {
        // Get a random rare entry and spawn location
        uint32 rareEntry = GetRandomRareEntry();
        [[maybe_unused]] RareSpawnLocation loc = GetRandomSpawnLocation();

        if (rareEntry == 0)
        {
            ScheduleNextRareSpawn();
            return;
        }

        // NOTE: This is currently a placeholder manager. It logs spawn attempts,
        // but does not actually spawn anything until mapId/coords are finalized.
        // LOG_INFO("scripts.dc", "Giant Isles: Attempting to spawn random rare {} at ({}, {}, {})",
        //     rareEntry, loc.x, loc.y, loc.z);

        // Get the creature name for announcement
        std::string rareName;
        switch (rareEntry)
        {
            case 400055: rareName = "Bonecrusher"; break;
            case 400056: rareName = "Gorespine the Impaler"; break;
            case 400057: rareName = "Venomfang"; break;
            case 400058: rareName = "Skyscreamer"; break;
            case 400059: rareName = "Gul'rok the Cursed"; break;
            default: rareName = "Unknown Rare"; break;
        }

        // Placeholder manager: do not announce "spawned" since no creature is actually spawned yet.
        // LOG_INFO("scripts.dc", "Giant Isles: Rare {} spawned", rareName);

        // Schedule next attempt
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
                uint32& lastSec = sSpiritLastWhisperSecByPlayer[player->GetGUID()];

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
                    "|cFF00FF00Ancient Voice:|r Today, |cFFFFFF00%s|r roams the isles. "
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
