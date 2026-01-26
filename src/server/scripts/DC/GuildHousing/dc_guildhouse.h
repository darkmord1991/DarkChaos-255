#pragma once

#include "Define.h"
#include "Guild.h"
#include "Player.h"

// Offsets from creatures_objects.sql
constexpr uint32 GetCreatureEntry(uint32 offset)
{
    return 500030 + offset;
}

constexpr uint32 GetGameObjectEntry(uint32 offset)
{
    return 500000 + offset;
}

// Guild Phase Helpers
//
// IMPORTANT: WoW phases are BITMASKS. Two phases with overlapping bits will see each other.
// To ensure isolation, each guild must use a UNIQUE POWER-OF-2 phase value.
// Formula: (1 << (4 + (guildId % 27))) gives bits 4-30, supporting up to 27 concurrent guild houses.
// Bits 0-3 are reserved for normal game phases (PHASEMASK_NORMAL = 1).
//
// If you need more than 27 guild houses, consider using separate map instances or
// multiple guildhouse maps with each handling 27 guilds.
//
inline uint32 GetGuildPhase(uint32 guildId)
{
    if (guildId == 0)
        return PHASEMASK_NORMAL; // No guild = normal phase

    // Use power-of-2 for true isolation. Bits 4-30 = 27 unique phases.
    // guildId % 27 maps guilds to bit positions 4-30.
    uint32 bitPosition = 4 + ((guildId - 1) % 27);
    return (1u << bitPosition);
}

inline uint32 GetGuildPhase(Guild* guild)
{
    return GetGuildPhase(guild ? guild->GetId() : 0);
}

inline uint32 GetGuildPhase(Player* player)
{
    return GetGuildPhase(player ? player->GetGuildId() : 0);
}

struct GuildHouseData
{
    uint32 phase;
    uint32 map;
    float posX;
    float posY;
    float posZ;
    float ori;
    uint8 level;

    GuildHouseData() : phase(0), map(0), posX(0.0f), posY(0.0f), posZ(0.0f), ori(0.0f), level(1) {}
    GuildHouseData(uint32 _phase, uint32 _map, float _x, float _y, float _z, float _o, uint8 _level)
        : phase(_phase), map(_map), posX(_x), posY(_y), posZ(_z), ori(_o), level(_level) {}
};

class GuildHouseManager
{
public:
    static bool TeleportToGuildHouse(Player* player, uint32 guildId);
    static bool RemoveGuildHouse(Guild* guild);
    static void CleanupGuildHouseSpawns(uint32 mapId, uint32 guildPhase);

    // Cache & Data Access
    static GuildHouseData* GetGuildHouseData(uint32 guildId);
    static void UpdateGuildHouseData(uint32 guildId, GuildHouseData const& data);
    static void RemoveGuildHouseData(uint32 guildId);
    static bool MoveGuildHouse(uint32 guildId, uint32 locationId);
    static uint8 GetGuildHouseLevel(uint32 guildId);
    static bool SetGuildHouseLevel(uint32 guildId, uint8 level);

    // Spawn Management
    static bool HasSpawn(uint32 mapId, uint32 phase, uint32 entry, bool isGameObject);
    static void SpawnTeleporterNPC(Player* player);
    static void SpawnButlerNPC(Player* player);
    static void SpawnTeleporterNPC(uint32 guildId, uint32 mapId, uint32 phase, float x, float y, float z, float o);
    static void SpawnButlerNPC(uint32 guildId, uint32 mapId, uint32 phase, float x, float y, float z, float o);

    // Permissions
    static bool HasPermission(Player* player, uint32 permission);
    static void SetPermission(uint32 guildId, uint8 rankId, uint32 permission);

    // Audit Log
    static void LogAction(Player* player, uint8 actionType, uint8 entityType, uint32 entry, uint32 guid, float x, float y, float z, float o);
    static bool UndoAction(Player* player, uint32 logId);
};

enum GuildHousePermissions
{
    GH_PERM_SPAWN   = 1,
    GH_PERM_DELETE  = 2,
    GH_PERM_MOVE    = 4,
    GH_PERM_ADMIN   = 8,
    GH_PERM_WORKSHOP = 16
};

enum GuildHouseActionType
{
    GH_ACTION_SPAWN  = 1,
    GH_ACTION_DELETE = 2,
    GH_ACTION_MOVE   = 3
};

enum GuildHouseEntityType
{
    GH_ENTITY_CREATURE   = 1,
    GH_ENTITY_GAMEOBJECT = 2
};
