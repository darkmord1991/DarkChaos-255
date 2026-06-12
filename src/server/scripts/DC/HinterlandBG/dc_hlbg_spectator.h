/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Hinterland BG spectating - join the running match GM-invisible and
 * receive live HUD snapshots through the unified spectator core.
 */

#ifndef DC_HLBG_SPECTATOR_H
#define DC_HLBG_SPECTATOR_H

#include "ObjectGuid.h"

#include <string>

class Player;

namespace DCHLBGSpectator
{
    bool StartSpectating(Player* player, std::string& error);
    bool StopSpectating(Player* player);
    bool IsSpectating(ObjectGuid guid);
}

#endif // DC_HLBG_SPECTATOR_H
