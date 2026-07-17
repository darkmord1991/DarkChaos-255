#ifndef DC_HOTSPOT_DEFINES_H
#define DC_HOTSPOT_DEFINES_H

#include "Common.h"
#include "ObjectGuid.h"
#include "GameTime.h"
#include <vector>
#include <unordered_map>
#include <array>
#include <string>

class Player;

struct HotspotsConfig
{
    bool enabled = true;
    uint32 duration = 60;                    // minutes
    uint32 experienceBonus = 100;            // percentage
    float radius = 150.0f;                   // yards
    float minDistance = 300.0f;              // yards (minimum distance between hotspot centers; 0 = disabled)
    uint32 maxActive = 5;
    uint32 minActive = 1;                    // minimum hotspots to maintain (crash persistence)
    uint32 maxPerZone = 2;                   // max hotspots allowed in same zone (0 = unlimited)
    uint32 respawnDelay = 30;                // minutes
    uint32 auraSpell = 800001;               // Primary hotspot aura shown to players
    uint32 buffSpell = 800001;               // Legacy fallback spell if auraSpell is unset
    float announceRadius = 500.0f;           // yards
    std::vector<uint32> enabledMaps;
    std::vector<uint32> enabledZones;
    std::vector<uint32> excludedZones;
    // Per-map zone allow list: mapId -> list of allowed zone IDs (if present, this overrides global enabled/excluded lists)
    std::unordered_map<uint32, std::vector<uint32>> enabledZonesPerMap;
    bool announceSpawn = true;
    bool announceExpire = true;
    bool spawnVisualMarker = false;          // Spawn an in-world GameObject marker (off by default; addon pins are the primary cue)
    uint32 markerGameObjectEntry = 179976;   // Optional world marker GO entry (only used when spawnVisualMarker=1)
    bool sendAddonPackets = false;           // whether to send CHAT_MSG_ADDON packets (unsafe on some clients)

    // Hotspot Objectives system
    bool objectivesEnabled = true;           // Track and display objectives (kills, time survived)
    uint32 objectiveKillGoal = 50;           // Default kill target for "Kill X creatures" objective
    uint32 objectiveSurviveMinutes = 5;      // Default survive time for "Survive X minutes" objective
    bool showObjectivesProgress = true;      // Show progress messages to players
};

extern HotspotsConfig sHotspotsConfig;

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
    ObjectGuid gameObjectGuid;

    bool IsActive() const
    {
        return GameTime::GetGameTime().count() < expireTime;
    }

    // Implemented in .cpp to avoid including Player.h here
    bool IsPlayerInRange(Player* player) const;
};

struct HotspotObjectives
{
    uint32 hotspotId = 0;
    uint32 killCount = 0;
    time_t entryTime = 0;
    bool objectiveCompleted = false;

    // Survival time in whole seconds since the objective session started.
    uint32 GetSurvivalSeconds() const
    {
        if (entryTime == 0) return 0;
        return static_cast<uint32>(GameTime::GetGameTime().count() - entryTime);
    }
};

#endif
