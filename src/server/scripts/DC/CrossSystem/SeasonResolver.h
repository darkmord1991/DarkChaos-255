/*
 * DarkChaos CrossSystem - Season Resolver
 *
 * Provides a single, shared way to resolve the active season across all DC systems.
 * Preference order:
 *  1) Generic SeasonalSystem active season (if available)
 *  2) Config fallback: DarkChaos.ActiveSeasonID
 *
 * Moved from ItemUpgrades to CrossSystem (Jan 2026)
 */

#pragma once

#include "Config.h"
#include "Define.h"
#include "DC/Seasons/SeasonalSystem.h"

namespace DarkChaos
{
    // Primary namespace - CrossSystem utilities
    namespace CrossSystem
    {
        inline uint32 GetCurrentSeasonId()
        {
            if (DarkChaos::Seasonal::SeasonalManager* mgr = DarkChaos::Seasonal::GetSeasonalManager())
            {
                uint32 seasonId = mgr->GetCurrentSeasonId();
                if (seasonId > 0)
                    return seasonId;
            }

            return sConfigMgr->GetOption<uint32>("DarkChaos.ActiveSeasonID", 1);
        }
    }

    // Legacy alias for backward compatibility
    namespace ItemUpgrade
    {
        inline uint32 GetCurrentSeasonId()
        {
            return DarkChaos::CrossSystem::GetCurrentSeasonId();
        }
    }
}
