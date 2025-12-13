/*
 * DarkChaos Item Upgrade - Season Resolver
 *
 * Provides a single, shared way to resolve the active season for ItemUpgrades.
 * Preference order:
 *  1) Generic SeasonalSystem active season (if available)
 *  2) Config fallback: DarkChaos.ActiveSeasonID
 */

#pragma once

#include "Config.h"
#include "Define.h"
#include "../Seasons/SeasonalSystem.h"

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        inline uint32 GetCurrentSeasonId()
        {
            if (DarkChaos::Seasonal::SeasonalManager* mgr = DarkChaos::Seasonal::GetSeasonalManager())
            {
                if (auto* activeSeason = mgr->GetActiveSeason())
                    return activeSeason->season_id;
            }

            return sConfigMgr->GetOption<uint32>("DarkChaos.ActiveSeasonID", 1);
        }
    }
}
