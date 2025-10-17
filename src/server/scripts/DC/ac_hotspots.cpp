/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * 
 * DarkChaos Hotspots System
 * 
 * Randomly spawns XP bonus zones ("hotspots") across configured maps/zones.
 * Players entering a hotspot receive:
 *   - Visual entry aura (cloud effect)
 *   - Persistent buff icon (flag)
 *   - 100% (or configured) XP bonus from kills
 * 
 * Hotspots show on minimap/map as golden arrows or green crosses when nearby.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "World.h"
#include "Chat.h"
#include "MapMgr.h"
#include "ObjectMgr.h"
#include "GameTime.h"
#include "StringConvert.h"
#include "GameObject.h"
#include "ObjectAccessor.h"
#include <vector>
#include <random>

// Configuration cache
struct HotspotsConfig
{
    bool enabled = true;
    uint32 duration = 60;                    // minutes
    uint32 experienceBonus = 100;            // percentage
    float radius = 150.0f;                   // yards
    uint32 maxActive = 5;
    uint32 respawnDelay = 15;                // minutes
    uint32 auraSpell = 24171;                // Entry visual (cloud)
    uint32 buffSpell = 23768;                // Persistent buff (flag icon)
    uint32 minimapIcon = 1;                  // 1=arrow, 2=cross
    float announceRadius = 500.0f;           // yards
    std::vector<uint32> enabledMaps;
    std::vector<uint32> enabledZones;
    std::vector<uint32> excludedZones;
    bool announceSpawn = true;
    bool announceExpire = true;
    bool spawnVisualMarker = true;           // Spawn GameObject marker
    uint32 markerGameObjectEntry = 179976;   // Alliance Flag (shows on map)
};

static HotspotsConfig sHotspotsConfig;

// Hotspot data structure
struct Hotspot
{
    uint32 id;
    uint32 mapId;
    uint32 zoneId;
    float x;
    float y;
    float z;
    time_t spawnTime;
    time_t expireTime;
    ObjectGuid gameObjectGuid;  // Visual marker GameObject

    bool IsActive() const
    {
        return GameTime::GetGameTime() < expireTime;
    }

    bool IsPlayerInRange(Player* player) const
    {
        if (!player || player->GetMapId() != mapId)
            return false;

        float dist = std::sqrt(
            std::pow(player->GetPositionX() - x, 2) +
            std::pow(player->GetPositionY() - y, 2) +
            std::pow(player->GetPositionZ() - z, 2)
        );

        return dist <= sHotspotsConfig.radius;
    }

    bool IsPlayerNearby(Player* player) const
    {
        if (!player || player->GetMapId() != mapId)
            return false;

        float dist = std::sqrt(
            std::pow(player->GetPositionX() - x, 2) +
            std::pow(player->GetPositionY() - y, 2) +
            std::pow(player->GetPositionZ() - z, 2)
        );

        return dist <= sHotspotsConfig.announceRadius;
    }
};

// Global hotspots storage
static std::vector<Hotspot> sActiveHotspots;
static uint32 sNextHotspotId = 1;
static time_t sLastSpawnCheck = 0;

// Helper: parse comma-separated uint32 list
static std::vector<uint32> ParseUInt32List(std::string const& str)
{
    std::vector<uint32> result;
    if (str.empty())
        return result;

    std::istringstream ss(str);
    std::string token;
    while (std::getline(ss, token, ','))
    {
        token.erase(0, token.find_first_not_of(" \t\r\n"));
        token.erase(token.find_last_not_of(" \t\r\n") + 1);
        if (!token.empty())
        {
            if (Optional<uint32> val = Acore::StringTo<uint32>(token))
                result.push_back(*val);
        }
    }
    return result;
}

// Load configuration
static void LoadHotspotsConfig()
{
    sHotspotsConfig.enabled = sConfigMgr->GetOption<bool>("Hotspots.Enable", true);
    sHotspotsConfig.duration = sConfigMgr->GetOption<uint32>("Hotspots.Duration", 60);
    sHotspotsConfig.experienceBonus = sConfigMgr->GetOption<uint32>("Hotspots.ExperienceBonus", 100);
    sHotspotsConfig.radius = sConfigMgr->GetOption<float>("Hotspots.Radius", 150.0f);
    sHotspotsConfig.maxActive = sConfigMgr->GetOption<uint32>("Hotspots.MaxActive", 5);
    sHotspotsConfig.respawnDelay = sConfigMgr->GetOption<uint32>("Hotspots.RespawnDelay", 15);
    sHotspotsConfig.auraSpell = sConfigMgr->GetOption<uint32>("Hotspots.AuraSpell", 24171);
    sHotspotsConfig.buffSpell = sConfigMgr->GetOption<uint32>("Hotspots.BuffSpell", 23768);
    sHotspotsConfig.minimapIcon = sConfigMgr->GetOption<uint32>("Hotspots.MinimapIcon", 1);
    sHotspotsConfig.announceRadius = sConfigMgr->GetOption<float>("Hotspots.AnnounceRadius", 500.0f);
    sHotspotsConfig.announceSpawn = sConfigMgr->GetOption<bool>("Hotspots.AnnounceSpawn", true);
    sHotspotsConfig.announceExpire = sConfigMgr->GetOption<bool>("Hotspots.AnnounceExpire", true);
    sHotspotsConfig.spawnVisualMarker = sConfigMgr->GetOption<bool>("Hotspots.SpawnVisualMarker", true);
    sHotspotsConfig.markerGameObjectEntry = sConfigMgr->GetOption<uint32>("Hotspots.MarkerGameObjectEntry", 179976);

    std::string mapsStr = sConfigMgr->GetOption<std::string>("Hotspots.EnabledMaps", "0,1,530,571");
    sHotspotsConfig.enabledMaps = ParseUInt32List(mapsStr);

    std::string zonesStr = sConfigMgr->GetOption<std::string>("Hotspots.EnabledZones", "");
    sHotspotsConfig.enabledZones = ParseUInt32List(zonesStr);

    std::string excludedStr = sConfigMgr->GetOption<std::string>("Hotspots.ExcludedZones", "");
    sHotspotsConfig.excludedZones = ParseUInt32List(excludedStr);
}

// Helper: check if map is enabled
static bool IsMapEnabled(uint32 mapId)
{
    if (sHotspotsConfig.enabledMaps.empty())
        return true;

    return std::find(sHotspotsConfig.enabledMaps.begin(), sHotspotsConfig.enabledMaps.end(), mapId)
        != sHotspotsConfig.enabledMaps.end();
}

// Helper: check if zone is allowed
static bool IsZoneAllowed(uint32 zoneId)
{
    // Check excluded zones first
    if (std::find(sHotspotsConfig.excludedZones.begin(), sHotspotsConfig.excludedZones.end(), zoneId)
        != sHotspotsConfig.excludedZones.end())
        return false;

    // If enabled zones list is empty, allow all (that aren't excluded)
    if (sHotspotsConfig.enabledZones.empty())
        return true;

    // Otherwise check if zone is in enabled list
    return std::find(sHotspotsConfig.enabledZones.begin(), sHotspotsConfig.enabledZones.end(), zoneId)
        != sHotspotsConfig.enabledZones.end();
}

// Helper: get random position in enabled zone
static bool GetRandomHotspotPosition(uint32& outMapId, uint32& outZoneId, float& outX, float& outY, float& outZ)
{
    if (sHotspotsConfig.enabledMaps.empty())
        return false;

    std::random_device rd;
    std::mt19937 gen(rd());

    // Pick random enabled map
    std::uniform_int_distribution<size_t> mapDist(0, sHotspotsConfig.enabledMaps.size() - 1);
    outMapId = sHotspotsConfig.enabledMaps[mapDist(gen)];

    // TODO: In a production system, you'd query valid zones/coordinates from world data
    // For now, use hardcoded safe coordinates per map (placeholder)
    // Replace this with actual zone coordinate lookups from your DB or terrain data

    struct MapCoords
    {
        float minX, maxX, minY, maxY, z;
        uint32 zoneId;
    };

    std::vector<MapCoords> coords;

    switch (outMapId)
    {
        case 0: // Eastern Kingdoms - sample zones
            coords = {
                {-9000.0f, -8000.0f, -1000.0f, 0.0f, 50.0f, 1},      // Dun Morogh
                {-5000.0f, -4000.0f, -3000.0f, -2000.0f, 50.0f, 10}, // Duskwood
                {-11000.0f, -10000.0f, 1000.0f, 2000.0f, 50.0f, 85}, // Tirisfal Glades
            };
            break;
        case 1: // Kalimdor - sample zones
            coords = {
                {9000.0f, 10000.0f, 1000.0f, 2000.0f, 50.0f, 141},   // Teldrassil
                {-3000.0f, -2000.0f, -5000.0f, -4000.0f, 50.0f, 331}, // Ashenvale
                {-7000.0f, -6000.0f, -4000.0f, -3000.0f, 50.0f, 17},  // Barrens
            };
            break;
        case 530: // Outland - sample zones
            coords = {
                {-2000.0f, -1000.0f, 5000.0f, 6000.0f, 100.0f, 3524}, // Hellfire Peninsula
                {2000.0f, 3000.0f, 5000.0f, 6000.0f, 100.0f, 3520},   // Shadowmoon Valley
            };
            break;
        case 571: // Northrend - sample zones
            coords = {
                {2000.0f, 3000.0f, 5000.0f, 6000.0f, 100.0f, 3537},  // Borean Tundra
                {4000.0f, 5000.0f, 1000.0f, 2000.0f, 100.0f, 495},   // Howling Fjord
            };
            break;
        default:
            return false;
    }

    if (coords.empty())
        return false;

    // Filter by allowed zones
    std::vector<MapCoords> allowedCoords;
    for (auto const& coord : coords)
    {
        if (IsZoneAllowed(coord.zoneId))
            allowedCoords.push_back(coord);
    }

    if (allowedCoords.empty())
        return false;

    // Pick random allowed zone
    std::uniform_int_distribution<size_t> zoneDist(0, allowedCoords.size() - 1);
    MapCoords const& chosen = allowedCoords[zoneDist(gen)];

    // Generate random position within zone bounds
    std::uniform_real_distribution<float> xDist(chosen.minX, chosen.maxX);
    std::uniform_real_distribution<float> yDist(chosen.minY, chosen.maxY);

    outX = xDist(gen);
    outY = yDist(gen);
    outZ = chosen.z;
    outZoneId = chosen.zoneId;

    return true;
}

// Spawn a new hotspot
static void SpawnHotspot()
{
    if (!sHotspotsConfig.enabled)
        return;

    if (sActiveHotspots.size() >= sHotspotsConfig.maxActive)
        return;

    uint32 mapId, zoneId;
    float x, y, z;

    if (!GetRandomHotspotPosition(mapId, zoneId, x, y, z))
        return;

    Hotspot hotspot;
    hotspot.id = sNextHotspotId++;
    hotspot.mapId = mapId;
    hotspot.zoneId = zoneId;
    hotspot.x = x;
    hotspot.y = y;
    hotspot.z = z;
    hotspot.spawnTime = GameTime::GetGameTime();
    hotspot.expireTime = hotspot.spawnTime + (sHotspotsConfig.duration * MINUTE);

    // Spawn visual marker GameObject if enabled
    if (sHotspotsConfig.spawnVisualMarker)
    {
        if (Map* map = sMapMgr->FindMap(mapId, 0))
        {
            // Create GameObject from template
            if (GameObjectTemplate const* goInfo = sObjectMgr->GetGameObjectTemplate(sHotspotsConfig.markerGameObjectEntry))
            {
                GameObject* go = new GameObject();
                if (go->Create(map->GenerateLowGuid<HighGuid::GameObject>(), sHotspotsConfig.markerGameObjectEntry, 
                              map, 1, Position(x, y, z, 0.0f), QuaternionData(), 255, GO_STATE_READY))
                {
                    go->SetRespawnTime(sHotspotsConfig.duration * MINUTE);
                    map->AddToMap(go);
                    hotspot.gameObjectGuid = go->GetGUID();
                    
                    LOG_DEBUG("scripts", "Hotspot #{} spawned GameObject marker (GUID: {}) at ({}, {}, {}) on map {}",
                              hotspot.id, go->GetGUID().ToString(), x, y, z, mapId);
                }
                else
                {
                    delete go;
                    LOG_ERROR("scripts", "Failed to create hotspot marker GameObject");
                }
            }
        }
    }

    sActiveHotspots.push_back(hotspot);

    if (sHotspotsConfig.announceSpawn)
    {
        std::string mapName = "Unknown";
        switch (mapId)
        {
            case 0: mapName = "Eastern Kingdoms"; break;
            case 1: mapName = "Kalimdor"; break;
            case 530: mapName = "Outland"; break;
            case 571: mapName = "Northrend"; break;
        }

        std::ostringstream ss;
        ss << "|cFFFFD700[Hotspot]|r A new XP Hotspot has appeared in " << mapName
           << "! (+" << sHotspotsConfig.experienceBonus << "% XP)";

        sWorld->SendServerMessage(SERVER_MSG_STRING, ss.str());
    }
}

// Remove expired hotspots
static void CleanupExpiredHotspots()
{
    auto it = sActiveHotspots.begin();
    while (it != sActiveHotspots.end())
    {
        if (!it->IsActive())
        {
            // Remove visual marker GameObject if it exists
            if (!it->gameObjectGuid.IsEmpty())
            {
                if (GameObject* go = ObjectAccessor::GetGameObject(*go, it->gameObjectGuid))
                {
                    go->SetRespawnTime(0);
                    go->Delete();
                }
            }

            if (sHotspotsConfig.announceExpire)
            {
                std::ostringstream ss;
                ss << "|cFFFFD700[Hotspot]|r A Hotspot has expired.";
                sWorld->SendServerMessage(SERVER_MSG_STRING, ss.str());
            }

            it = sActiveHotspots.erase(it);
        }
        else
        {
            ++it;
        }
    }
}

// Check if player is in any hotspot
static Hotspot const* GetPlayerHotspot(Player* player)
{
    if (!player)
        return nullptr;

    for (auto const& hotspot : sActiveHotspots)
    {
        if (hotspot.IsPlayerInRange(player))
            return &hotspot;
    }

    return nullptr;
}

// World script for periodic updates
class HotspotsWorldScript : public WorldScript
{
public:
    HotspotsWorldScript() : WorldScript("HotspotsWorldScript") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        LoadHotspotsConfig();
    }

    void OnStartup() override
    {
        LoadHotspotsConfig();

        if (sHotspotsConfig.enabled)
        {
            LOG_INFO("server.loading", ">> DarkChaos Hotspots System loaded");
            LOG_INFO("server.loading", ">> - Duration: {} minutes", sHotspotsConfig.duration);
            LOG_INFO("server.loading", ">> - XP Bonus: +{}%", sHotspotsConfig.experienceBonus);
            LOG_INFO("server.loading", ">> - Max Active: {}", sHotspotsConfig.maxActive);
            LOG_INFO("server.loading", ">> - Enabled Maps: {}", sHotspotsConfig.enabledMaps.size());
        }
    }

    void OnUpdate(uint32 /*diff*/) override
    {
        if (!sHotspotsConfig.enabled)
            return;

        time_t now = GameTime::GetGameTime();

        // Check for expired hotspots every 10 seconds
        static time_t sLastCleanup = 0;
        if (now - sLastCleanup >= 10)
        {
            sLastCleanup = now;
            CleanupExpiredHotspots();
        }

        // Check for spawning new hotspots
        if (now - sLastSpawnCheck >= (sHotspotsConfig.respawnDelay * MINUTE))
        {
            sLastSpawnCheck = now;
            SpawnHotspot();
        }
    }
};

// Player script for hotspot detection and buff application
class HotspotsPlayerScript : public PlayerScript
{
public:
    HotspotsPlayerScript() : PlayerScript("HotspotsPlayerScript") { }

    void OnLogin(Player* player) override
    {
        if (!sHotspotsConfig.enabled || !player)
            return;

        // Check if player logged in inside a hotspot
        CheckPlayerHotspotStatus(player);
    }

    void OnUpdate(Player* player, uint32 /*diff*/) override
    {
        if (!sHotspotsConfig.enabled || !player)
            return;

        // Check hotspot status every few seconds (throttled by update frequency)
        static std::unordered_map<ObjectGuid, time_t> sLastCheck;
        time_t now = GameTime::GetGameTime();

        ObjectGuid guid = player->GetGUID();
        if (now - sLastCheck[guid] >= 2)
        {
            sLastCheck[guid] = now;
            CheckPlayerHotspotStatus(player);
        }
    }

private:
    void CheckPlayerHotspotStatus(Player* player)
    {
        if (!player)
            return;

        Hotspot const* hotspot = GetPlayerHotspot(player);
        bool hasBuffAura = player->HasAura(sHotspotsConfig.buffSpell);

        if (hotspot && !hasBuffAura)
        {
            // Player entered hotspot
            // Apply entry visual (temporary cloud aura)
            if (SpellInfo const* auraInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.auraSpell))
                player->CastSpell(player, sHotspotsConfig.auraSpell, true);

            // Apply persistent buff (flag icon)
            if (SpellInfo const* buffInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.buffSpell))
                player->CastSpell(player, sHotspotsConfig.buffSpell, true);

            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFFD700[Hotspot]|r You have entered an XP Hotspot! +{}%% experience from kills!",
                sHotspotsConfig.experienceBonus
            );
        }
        else if (!hotspot && hasBuffAura)
        {
            // Player left hotspot
            player->RemoveAura(sHotspotsConfig.buffSpell);

            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFFD700[Hotspot]|r You have left the XP Hotspot."
            );
        }
    }
};

// Modify XP gain when in hotspot
class HotspotsPlayerGainXP : public PlayerScript
{
public:
    HotspotsPlayerGainXP() : PlayerScript("HotspotsPlayerGainXP") { }

    void OnGiveXP(Player* player, uint32& amount, Unit* /*victim*/) override
    {
        if (!sHotspotsConfig.enabled || !player)
            return;

        // Check if player is in hotspot
        if (player->HasAura(sHotspotsConfig.buffSpell))
        {
            uint32 bonus = (amount * sHotspotsConfig.experienceBonus) / 100;
            amount += bonus;
        }
    }
};

// GM commands
class HotspotsCommandScript : public CommandScript
{
public:
    HotspotsCommandScript() : CommandScript("HotspotsCommandScript") { }

    std::vector<ChatCommand> GetCommands() const override
    {
        static std::vector<ChatCommand> hotspotsCommandTable =
        {
            { "list",   SEC_GAMEMASTER, false, &HandleHotspotsListCommand,   "" },
            { "spawn",  SEC_ADMINISTRATOR, false, &HandleHotspotsSpawnCommand,  "" },
            { "clear",  SEC_ADMINISTRATOR, false, &HandleHotspotsClearCommand,  "" },
            { "reload", SEC_ADMINISTRATOR, false, &HandleHotspotsReloadCommand, "" },
            { "tp",     SEC_GAMEMASTER, false, &HandleHotspotsTeleportCommand, "" },
        };

        static std::vector<ChatCommand> commandTable =
        {
            { "hotspots", SEC_GAMEMASTER, false, nullptr, "", hotspotsCommandTable },
        };

        return commandTable;
    }

    static bool HandleHotspotsListCommand(ChatHandler* handler, char const* /*args*/)
    {
        if (sActiveHotspots.empty())
        {
            handler->SendSysMessage("No active hotspots.");
            return true;
        }

        handler->PSendSysMessage("Active Hotspots: {}", sActiveHotspots.size());
        for (auto const& hotspot : sActiveHotspots)
        {
            time_t remaining = hotspot.expireTime - GameTime::GetGameTime();
            handler->PSendSysMessage(
                "  ID: {} | Map: {} | Zone: {} | Pos: ({:.1f}, {:.1f}, {:.1f}) | Time Left: {}m",
                hotspot.id, hotspot.mapId, hotspot.zoneId,
                hotspot.x, hotspot.y, hotspot.z,
                remaining / 60
            );
        }

        return true;
    }

    static bool HandleHotspotsSpawnCommand(ChatHandler* handler, char const* /*args*/)
    {
        SpawnHotspot();
        handler->SendSysMessage("Spawned a new hotspot.");
        return true;
    }

    static bool HandleHotspotsClearCommand(ChatHandler* handler, char const* /*args*/)
    {
        size_t count = sActiveHotspots.size();
        sActiveHotspots.clear();
        handler->PSendSysMessage("Cleared {} hotspot(s).", count);
        return true;
    }

    static bool HandleHotspotsReloadCommand(ChatHandler* handler, char const* /*args*/)
    {
        LoadHotspotsConfig();
        handler->SendSysMessage("Reloaded hotspots configuration.");
        return true;
    }

    static bool HandleHotspotsTeleportCommand(ChatHandler* handler, char const* args)
    {
        if (sActiveHotspots.empty())
        {
            handler->SendSysMessage("No active hotspots to teleport to.");
            return true;
        }

        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Parse hotspot ID from args, or default to first hotspot
        uint32 hotspotId = 0;
        if (args && *args)
        {
            if (Optional<uint32> val = Acore::StringTo<uint32>(args))
                hotspotId = *val;
        }

        // Find hotspot
        Hotspot const* targetHotspot = nullptr;
        
        if (hotspotId > 0)
        {
            // Find by specific ID
            for (auto const& hotspot : sActiveHotspots)
            {
                if (hotspot.id == hotspotId)
                {
                    targetHotspot = &hotspot;
                    break;
                }
            }

            if (!targetHotspot)
            {
                handler->PSendSysMessage("Hotspot ID {} not found.", hotspotId);
                return true;
            }
        }
        else
        {
            // Default to first hotspot
            targetHotspot = &sActiveHotspots[0];
        }

        // Teleport player
        if (player->TeleportTo(targetHotspot->mapId, targetHotspot->x, targetHotspot->y, 
                               targetHotspot->z, player->GetOrientation()))
        {
            handler->PSendSysMessage("Teleported to Hotspot ID {} on map {} at ({:.1f}, {:.1f}, {:.1f})",
                                    targetHotspot->id, targetHotspot->mapId,
                                    targetHotspot->x, targetHotspot->y, targetHotspot->z);
        }
        else
        {
            handler->SendSysMessage("Failed to teleport to hotspot.");
        }

        return true;
    }
};

void AddSC_ac_hotspots()
{
    new HotspotsWorldScript();
    new HotspotsPlayerScript();
    new HotspotsPlayerGainXP();
    new HotspotsCommandScript();
}
