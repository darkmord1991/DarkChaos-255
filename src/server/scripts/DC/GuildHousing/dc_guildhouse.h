#pragma once

#include "Define.h"
#include "Guild.h"
#include "Player.h"

#include <string>
#include <vector>

class Map;

// Offsets from creatures_objects.sql
constexpr uint32 GetCreatureEntry(uint32 offset)
{
    return 500030 + offset;
}

constexpr uint32 GetGameObjectEntry(uint32 offset)
{
    return 500000 + offset;
}

// Instanced guild housing (Phase B migration)
//
// Each guild gets its own instance of the dedicated guild-house map, which
// replaces the legacy 27-phase shared-map isolation below. Separation is now
// provided by the instance id (effectively unlimited guilds), while the map's
// terrain (map/vmap/mmap for GUILD_HOUSE_MAP_ID) remains a single on-disk copy
// shared across all live instances. See GuildHouseManager::EnsureGuildInstanceId
// and the dc_guild_house_instance table.
constexpr uint32 GUILD_HOUSE_MAP_ID = 1409;
constexpr float  GUILD_HOUSE_ENTRANCE_X = 1102.5204f;
constexpr float  GUILD_HOUSE_ENTRANCE_Y = 1198.4127f;
constexpr float  GUILD_HOUSE_ENTRANCE_Z = 536.79785f;
constexpr float  GUILD_HOUSE_ENTRANCE_O = 1.6015308f;

// Multiple guild-house map skins. GUILD_HOUSE_MAP_ID (1409, "guildhousedala", WotLK Dalaran) is the
// original/default; 1413 ("guildhousedala2") is the same layout with the modern Legion Dalaran WMO.
// Each guild's chosen map + entrance comes from its dc_guild_house row (backfilled from
// dc_guild_house_locations); the instanced teleport/instance-script/decoration code keys off that map
// rather than a single hard-coded id. Adding another skin = add its id here AND a
// dc_guild_house_locations row + Map.dbc/MapDifficulty.dbc rows + cloned terrain/spawns.
// NOTE: 1409 keeps the exact GUILD_HOUSE_ENTRANCE_* above (no behaviour change for existing guilds);
// other maps use their stored per-location entrance coords.
constexpr uint32 GUILD_HOUSE_MAP_IDS[] = { GUILD_HOUSE_MAP_ID, 1413 };

inline bool IsGuildHouseMap(uint32 mapId)
{
    for (uint32 m : GUILD_HOUSE_MAP_IDS)
        if (m == mapId)
            return true;
    return false;
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

    GuildHouseData() : phase(0), map(0), posX(0.0f), posY(0.0f), posZ(0.0f), ori(0.0f), level(0) {}
    GuildHouseData(uint32 _phase, uint32 _map, float _x, float _y, float _z, float _o, uint8 _level)
        : phase(_phase), map(_map), posX(_x), posY(_y), posZ(_z), ori(_o), level(_level) {}
};

// A butler-purchased spawn the guild owns (one dc_guild_house_instance_spawns
// row, source=BUTLER), for the "Manage / Remove" gossip list.
struct ButlerContentItem
{
    uint32 id = 0;
    uint32 entry = 0;
    bool isGameObject = false;
    uint32 paidCopper = 0;
    std::string name;
};

class GuildHouseManager
{
public:
    static bool TeleportToGuildHouse(Player* player, uint32 guildId);
    // Returns the persistent instance id for this guild's private guild-house
    // map, minting (and persisting) a fresh one if none exists or the previous
    // InstanceSave has expired/reset. Returns 0 on failure.
    static uint32 EnsureGuildInstanceId(uint32 guildId);

    // --- Dynamic per-instance content (butler purchases + decorations) ---
    // Allocate a unique, monotonically-increasing id for a dc_guild_house_instance_spawns
    // row. World-thread only; the single id source for both butler and decoration
    // inserts (all rows use explicit ids, so the shared table never relies on AUTO_INCREMENT).
    static uint32 AllocateContentId();
    // Reverse lookup: which guild owns the given instance id (via dc_guild_house_instance).
    static uint32 GetGuildByInstanceId(uint32 instanceId);
    // Read-only: the guild's bound instance id (0 if none), without creating one.
    static uint32 GetGuildInstanceId(uint32 guildId);
    // True if the player stands in their own guild's house instance. Replaces the
    // legacy "same map + guild phasemask" check for "inside your guild house".
    static bool IsInOwnGuildHouse(Player* player);
    // Summon all of a guild's persisted content (dc_guild_house_instance_spawns)
    // non-persistently into the given (instance) map. Called once per instance load.
    static void LoadGuildContentIntoInstance(Map* map, uint32 guildId);
    // True if the guild already owns a spawn with this entry/type (table-based dedup).
    static bool GuildOwnsContent(uint32 guildId, uint32 entry, bool isGameObject);
    // Persist a piece of content for the guild AND summon it live into map.
    static bool PlaceGuildContent(Map* map, uint32 guildId, bool isGameObject, uint32 entry,
        float x, float y, float z, float o, float scale, uint32 paidCopper, uint64 placedBy);
    // Wipe a guild's dynamic content (butler + decorations) from the DB and the
    // decoration caches, used on house reset/removal. Live in-world objects clear
    // on the next instance reload.
    static void ClearGuildContent(uint32 guildId);
    // List a guild's butler-purchased spawns (for the remove gossip UI).
    static void ListButlerContent(uint32 guildId, std::vector<ButlerContentItem>& out);
    // Remove a butler spawn the player's guild owns: despawn the live object,
    // delete its row, and refund a configured share of the paid cost.
    static bool RemoveButlerContent(Player* player, uint32 rowId, uint32* outRefundCopper = nullptr);

    static bool RemoveGuildHouse(Guild* guild);
    static void CleanupGuildHouseSpawns(uint32 mapId, uint32 guildPhase);

    // Cache & Data Access
    static GuildHouseData* GetGuildHouseData(uint32 guildId);
    static void UpdateGuildHouseData(uint32 guildId, GuildHouseData const& data);
    static void RemoveGuildHouseData(uint32 guildId);
    static bool MoveGuildHouse(uint32 guildId, uint32 locationId, bool ignoreDisabled = false);
    static uint8 GetGuildHouseLevel(uint32 guildId);
    static bool SetGuildHouseLevel(uint32 guildId, uint8 level);
    static bool HasLocationEnabledColumn();

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
