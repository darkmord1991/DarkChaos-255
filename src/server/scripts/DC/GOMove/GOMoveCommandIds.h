#pragma once

#include "Define.h"

namespace DarkChaos::GOMove
{
    // Must stay in sync between:
    // - src/server/scripts/DC/GOMove/GOMoveScripts.cpp
    // - src/server/scripts/DC/AddonExtension/dc_addon_gomove.cpp
    enum CommandId : uint32
    {
        TEST,
        SELECTNEAR,
        DELET,
        X,
        Y,
        Z,
        O,
        GROUND,
        FLOOR,
        RESPAWN,
        GOTO,
        FACE,
        SPAWN,
        NORTH,
        EAST,
        SOUTH,
        WEST,
        NORTHEAST,
        NORTHWEST,
        SOUTHEAST,
        SOUTHWEST,
        UP,
        DOWN,
        LEFT,
        RIGHT,
        PHASE,
        SELECTALLNEAR,
        SPAWNSPELL,
    };
}
