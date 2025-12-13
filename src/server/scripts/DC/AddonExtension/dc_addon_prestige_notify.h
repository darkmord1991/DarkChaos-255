#pragma once

#include "Player.h"

namespace DCPrestigeAddon
{
    // Server-side prestige addon notification helper (implemented in dc_addon_prestige.cpp)
    void NotifyPrestigeLevelUp(Player* player, uint32 newLevel, uint32 totalBonus);
}
