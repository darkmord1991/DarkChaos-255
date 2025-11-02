#ifndef AZEROTHCORE_DC_PRESTIGE_API_H
#define AZEROTHCORE_DC_PRESTIGE_API_H

#include "Define.h"

class Player;

namespace PrestigeAPI
{
    bool IsEnabled();
    uint32 GetPrestigeLevel(Player* player);
    uint32 GetMaxPrestigeLevel();
    uint32 GetRequiredLevel();
    uint32 GetStatBonusPercent();
    bool CanPrestige(Player* player);
    void ApplyPrestigeBuffs(Player* player);
    void PerformPrestige(Player* player);
}

#endif // AZEROTHCORE_DC_PRESTIGE_API_H
