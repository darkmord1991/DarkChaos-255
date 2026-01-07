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
inline uint32 GetGuildPhase(uint32 guildId)
{
    return guildId + 10;
}

inline uint32 GetGuildPhase(Guild* guild)
{
    return GetGuildPhase(guild->GetId());
}

inline uint32 GetGuildPhase(Player* player)
{
    return GetGuildPhase(player->GetGuildId());
}


struct GuildHouseData
{
    uint32 phase;
    uint32 map;
    float posX;
    float posY;
    float posZ;
    float ori;

    GuildHouseData() : phase(0), map(0), posX(0.0f), posY(0.0f), posZ(0.0f), ori(0.0f) {}
    GuildHouseData(uint32 _phase, uint32 _map, float _x, float _y, float _z, float _o)
        : phase(_phase), map(_map), posX(_x), posY(_y), posZ(_z), ori(_o) {}
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

    // Spawn Management
    static bool HasSpawn(uint32 mapId, uint32 phase, uint32 entry, bool isGameObject);
};
