#pragma once

#include "Define.h"

class Player;

namespace DC
{
namespace SpawnResolver
{
    enum class Type : uint8
    {
        Creature = 1,
        GameObject = 2,
        Player = 3,
    };

    enum class Source : uint8
    {
        Live = 1,
        SpawnCache = 2,
        WorldDB = 3,
    };

    struct ResolvedPosition
    {
        bool found = false;
        Source source = Source::SpawnCache;

        uint32 spawnId = 0;
        uint32 entry = 0;

        uint32 mapId = 0;
        uint32 zoneId = 0;
        uint32 areaId = 0;
        uint32 phaseMask = 1;

        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;

        bool hasNormalized = false;
        float nx = 0.0f;
        float ny = 0.0f;
    };

    // Tries to resolve a creature position.
    // - preferLive: if true, first tries to get the *current* position of the live creature (only works if it's loaded/near the player).
    // - Falls back to spawn cache (sObjectMgr) and then DB.
    ResolvedPosition ResolveCreature(Player* contextPlayer, uint32 spawnId, uint32 entry, bool preferLive);

    // Tries to resolve a gameobject position.
    // - preferLive: if true, first tries to get the live GO position (only works if it's loaded/near the player).
    // - Falls back to spawn cache (sObjectMgr) and then DB.
    ResolvedPosition ResolveGameObject(Player* contextPlayer, uint32 spawnId, uint32 entry, bool preferLive);

    // Resolves the player's current position (always live).
    ResolvedPosition ResolvePlayer(Player* player);

    // Convenience wrapper so callers (addon handlers/systems) don't need separate code paths.
    // - Type::Player ignores spawnId/entry.
    inline ResolvedPosition ResolveAny(Type type, Player* contextPlayer, uint32 spawnId, uint32 entry, bool preferLive)
    {
        switch (type)
        {
            case Type::Creature:
                return ResolveCreature(contextPlayer, spawnId, entry, preferLive);
            case Type::GameObject:
                return ResolveGameObject(contextPlayer, spawnId, entry, preferLive);
            case Type::Player:
                return ResolvePlayer(contextPlayer);
            default:
                return ResolvedPosition{};
        }
    }
}
}
