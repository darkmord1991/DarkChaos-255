/*
 * HotspotCore.h - DarkChaos Hotspots System Header
 *
 * Shared declarations for the Hotspot system split implementation.
 * Enables modular compilation while maintaining access to core types.
 */

#ifndef DC_HOTSPOT_CORE_H
#define DC_HOTSPOT_CORE_H

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "Config.h"
#include "GameTime.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "DatabaseEnv.h"
#include "MapMgr.h"
#include "DBCStores.h"
#include "Log.h"
#include "Spell.h"
#include "SpellMgr.h"
#include "GridNotifiers.h"
#include "CellImpl.h"

#include <vector>
#include <unordered_map>
#include <string>
#include <cmath>
#include <sstream>
#include <algorithm>
#include <random>

// =============================================================================
// Configuration
// =============================================================================

struct HotspotsConfig
{
    bool enabled = true;
    uint32 duration = 60;           // minutes
    uint32 experienceBonus = 100;   // percentage
    float radius = 150.0f;          // yards
    uint32 maxActive = 5;
    uint32 spawnInterval = 15;      // minutes between spawn attempts
    uint32 announceRadius = 500;    // yards for approach warning
    bool useSpecialTexture = false;
    std::string textureId = "";
    uint32 buffSpellId = 800001;
    uint32 auraSpell = 800002;

    // Map/zone configuration
    std::vector<uint32> enabledMaps = {0, 1, 530, 571};
    std::vector<uint32> excludedZones;
    uint32 maxPerZone = 2;

    void Load();
};

// Global config instance
extern HotspotsConfig sHotspotsConfig;

// =============================================================================
// Hotspot Data Structure
// =============================================================================

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
    ObjectGuid markerGuid; // Visual marker GO if spawned

    bool IsActive() const
    {
        return GameTime::GetGameTime().count() < expireTime;
    }

    bool IsPlayerInRange(Player* player) const;
    bool IsPlayerNearby(Player* player) const;
};

// Active hotspots
extern std::vector<Hotspot> sActiveHotspots;
extern uint32 sNextHotspotId;

// Player hotspot expiry tracking
extern std::unordered_map<ObjectGuid, time_t> sPlayerHotspotExpiry;

// =============================================================================
// Map Bounds
// =============================================================================

extern std::unordered_map<uint32, std::array<float,4>> sMapBounds;

// =============================================================================
// Public API Functions
// =============================================================================

// Configuration
void LoadHotspotsConfig();
bool IsMapEnabled(uint32 mapId);
bool IsZoneAllowed(uint32 mapId, uint32 zoneId);

// Core operations
bool SpawnHotspot();
void CleanupExpiredHotspots();
Hotspot* GetPlayerHotspot(Player* player);
bool IsPlayerInHotspot(Player* player);
void CheckPlayerHotspotStatusImmediate(Player* player);

// XP bonus
uint32 GetHotspotXPBonusPercentage();
uint32 GetHotspotBuffSpellId();

// Database operations
void EnsureHotspotTableExists();
void SaveHotspotToDB(Hotspot const& hotspot);
void LoadHotspotsFromDB();
void DeleteHotspotFromDB(uint32 hotspotId);
void ClearHotspotsDB();
void RecreateHotspotVisualMarkers();

// Map bounds
void BuildMapBoundsFromDBC();
void LoadMapBoundsFromCSV();
bool ComputeNormalizedCoords(uint32 mapId, uint32 zoneId, float x, float y, float& outNx, float& outNy);

// Utilities
std::string BuildHotspotAddonPayload(const Hotspot& hotspot, int32 durationSeconds);
std::string EscapeBraces(std::string const& s);
std::string GetSafeZoneName(uint32 zoneId);
std::string GetMapName(uint32 mapId);
Map* GetBaseMapSafe(uint32 mapId);

// Position generation
bool GetRandomHotspotPosition(uint32& outMapId, uint32& outZoneId, float& outX, float& outY, float& outZ);
uint32 GetHotspotCountInZone(uint32 zoneId);
bool CanSpawnInZone(uint32 zoneId);

// Script registration
void AddSC_ac_hotspots();

#endif // DC_HOTSPOT_CORE_H
