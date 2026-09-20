#pragma once

#include "Player.h"

namespace DCPrestigeAddon
{
    // Server-side prestige addon notification helper (implemented in dc_addon_prestige.cpp)
    void NotifyPrestigeLevelUp(Player* player, uint32 newLevel, uint32 totalBonus);

    // Pushes the prestige talent panel state (SMSG_TALENTS) to the client
    void SendTalents(Player* player);

    // A mapped achievement ("challenge") added points to the account pool
    void NotifyChallengeEarned(Player* player, uint32 achievementId, uint32 points, uint32 accountPoints);
}
