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

class GuildHouseManager
{
public:
    static bool TeleportToGuildHouse(Player* player, uint32 guildId);
    static bool RemoveGuildHouse(Guild* guild);
};
