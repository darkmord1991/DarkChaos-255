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
#include "GameTime.h"
#include "World.h"
#include "Chat.h"
#include "Log.h"
#include "ObjectAccessor.h"

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

constexpr char const* BOSS_OONDASTA_SPAWN = "|cFFFF0000[World Boss]|r |cFFFFFF00Oondasta, King of Dinosaurs|r "
    "has awakened in |cFF00FF00Devilsaur Gorge|r! Rally your forces!";

constexpr char const* BOSS_THOK_SPAWN = "|cFFFF0000[World Boss]|r |cFFFFFF00Thok the Bloodthirsty|r "
    "stalks the hunt in |cFF00FF00Raptor Ridge|r! Prepare for battle!";

constexpr char const* BOSS_NALAK_SPAWN = "|cFFFF0000[World Boss]|r |cFFFFFF00Nalak the Storm Lord|r "
    "descends upon |cFF00FF00Thundering Peaks|r! The storm is coming!";

constexpr char const* BOSS_KILLED_MESSAGE = "|cFFFF8000[Giant Isles]|r |cFF00FF00%s|r has been defeated! "
    "A new world boss will appear tomorrow.";

constexpr char const* RARE_SPAWN_MESSAGE = "|cFFFF8000[Giant Isles]|r A rare creature |cFF00FF00%s|r "
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

// Get current day of week (0 = Sunday, 6 = Saturday)
uint8 GetCurrentDayOfWeek()
{
    time_t rawtime = GameTime::GetGameTime();
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

class zone_giant_isles : public ZoneScript
{
public:
    zone_giant_isles() : ZoneScript("zone_giant_isles") { }

    void OnPlayerEnterZone(Player* player, uint32 /*zone*/) override
    {
        if (!player)
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

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFF8000[Giant Isles]|r Today's world boss: |cFFFFFF00%s|r in |cFF00FF00%s|r",
            bossName.c_str(), location.c_str());
    }
};

// ============================================================================
// PLAYER SCRIPT - ZONE TRACKING
// ============================================================================

class player_giant_isles_tracker : public PlayerScript
{
public:
    player_giant_isles_tracker() : PlayerScript("player_giant_isles_tracker") { }

    void OnUpdateZone(Player* player, uint32 newZone, uint32 /*newArea*/) override
    {
        if (!player)
            return;

        // Track when player enters Giant Isles
        if (newZone == ZONE_GIANT_ISLES)
        {
            LOG_DEBUG("scripts.dc", "Player {} entered Giant Isles zone", player->GetName());
        }
    }
};

// ============================================================================
// WORLD SCRIPT - BOSS ROTATION & RANDOM RARE SPAWN MANAGEMENT
// ============================================================================

class world_giant_isles_manager : public WorldScript
{
public:
    world_giant_isles_manager() : WorldScript("world_giant_isles_manager") 
    {
        _nextRareSpawnTime = 0;
        _currentRareGUID = ObjectGuid::Empty;
        _rareIsAlive = false;
    }

    void OnStartup() override
    {
        LOG_INFO("scripts.dc", "Giant Isles zone manager loaded.");
        LOG_INFO("scripts.dc", "Today's active boss: Entry {}", GetActiveBossEntry());
        
        // Initialize first rare spawn timer (spawn first rare after 5-15 minutes)
        _nextRareSpawnTime = GameTime::GetGameTimeMS() + urand(5 * 60 * 1000, 15 * 60 * 1000);
        LOG_INFO("scripts.dc", "Giant Isles: First random rare spawn scheduled.");
    }

    // Called every server update - handles rare spawn timer
    void OnUpdate(uint32 diff) override
    {
        // Check if it's time to spawn a random rare
        uint32 currentTime = GameTime::GetGameTimeMS();
        
        if (!_rareIsAlive && currentTime >= _nextRareSpawnTime)
        {
            TrySpawnRandomRare();
        }
    }

private:
    uint32 _nextRareSpawnTime;
    ObjectGuid _currentRareGUID;
    bool _rareIsAlive;

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

        // Find a map to spawn on (Giant Isles map - placeholder mapId)
        // In production, you'd need the actual map ID for Giant Isles
        // For now, we'll just log the spawn attempt
        LOG_INFO("scripts.dc", "Giant Isles: Attempting to spawn random rare {} at ({}, {}, {})", 
            rareEntry, loc.x, loc.y, loc.z);
        
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
        
        // Announce the spawn server-wide
        std::string message = "|cFFFF8000[Giant Isles]|r A rare creature |cFFFFFF00" + 
            rareName + "|r has been spotted in the wilds! Hunt it down for valuable rewards!";
        sWorld->SendServerMessage(SERVER_MSG_STRING, message.c_str());
        
        _rareIsAlive = true;
        
        // Schedule despawn check and next spawn
        ScheduleNextRareSpawn();
    }

    void ScheduleNextRareSpawn()
    {
        // Schedule next rare spawn between 30-90 minutes from now
        _nextRareSpawnTime = GameTime::GetGameTimeMS() + 
            urand(RARE_SPAWN_TIMER_MIN, RARE_SPAWN_TIMER_MAX);
        _rareIsAlive = false;
        
        LOG_DEBUG("scripts.dc", "Giant Isles: Next random rare spawn scheduled.");
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
                if (player && !player->HasAura(28126)) // Check if not recently whispered
                {
                    me->Whisper("The ancient spirits stir... The dinosaurs grow restless.", 
                        LANG_UNIVERSAL, player);
                }
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
            // Announce world boss deaths server-wide
            switch (me->GetEntry())
            {
                case NPC_OONDASTA:
                    sWorld->SendServerMessage(SERVER_MSG_STRING, 
                        "|cFFFF8000[Giant Isles]|r Oondasta, King of Dinosaurs has been defeated! "
                        "A new world boss will appear tomorrow.");
                    break;
                case NPC_THOK:
                    sWorld->SendServerMessage(SERVER_MSG_STRING,
                        "|cFFFF8000[Giant Isles]|r Thok the Bloodthirsty has been slain! "
                        "A new world boss will appear tomorrow.");
                    break;
                case NPC_NALAK:
                    sWorld->SendServerMessage(SERVER_MSG_STRING,
                        "|cFFFF8000[Giant Isles]|r Nalak the Storm Lord has fallen! "
                        "A new world boss will appear tomorrow.");
                    break;
                // Static rare elite announcements
                case NPC_PRIMAL_DIREHORN:
                case NPC_CHAOS_REX:
                case NPC_ANCIENT_PRIMORDIAL:
                case NPC_SAVAGE_MATRIARCH:
                case NPC_ALPHA_RAPTOR:
                    sWorld->SendServerMessage(SERVER_MSG_STRING,
                        (std::string("|cFFFF8000[Giant Isles]|r Rare creature |cFF00FF00") + 
                         me->GetName() + "|r has been slain!").c_str());
                    break;
                // Random rare spawn announcements (special loot message)
                case NPC_BONECRUSHER:
                case NPC_GORESPINE:
                case NPC_VENOMFANG:
                case NPC_SKYSCREAMER:
                case NPC_GULROK:
                    sWorld->SendServerMessage(SERVER_MSG_STRING,
                        (std::string("|cFFFF8000[Giant Isles]|r |cFFFFFF00") + 
                         me->GetName() + "|r has been vanquished! Another rare will spawn soon...").c_str());
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

        void JustAppeared() override
        {
            // Announce rare spawn to zone
            std::string message = "|cFFFF8000[Giant Isles]|r A rare creature |cFF00FF00" + 
                std::string(me->GetName()) + "|r has been spotted!";
            
            sWorld->SendServerMessage(SERVER_MSG_STRING, message.c_str());
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

        // Check if world boss is already active
        uint32 activeBoss = GetActiveBossEntry();
        
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
    new player_giant_isles_tracker();
    new world_giant_isles_manager();
    new npc_spirit_of_primal();
    new creature_giant_isles_death();
    new creature_giant_isles_rare_spawn();
    new go_ancient_primal_altar();
}
