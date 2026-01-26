/*
 * Mythic+ Seasonal Integration - DarkChaos
 *
 * Integration of M+ system with generic seasonal framework
 *
 * Author: DarkChaos Development Team
 * Date: November 22, 2025
 */

#include "dc_mythicplus_difficulty_scaling.h"
#include "../Seasons/SeasonalSystem.h"
#include "../CrossSystem/CrossSystemSeasonHelper.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"

namespace DarkChaos
{
    namespace MythicPlus
    {
        // =====================================================================
        // Season Integration Helper
        // =====================================================================

        uint32 GetMythicPlusActiveSeason()
        {
            // Use unified season helper for consistent season ID across all systems
            uint32 seasonId = DarkChaos::GetActiveSeasonId();
            LOG_DEBUG("mythicplus", "Using unified season helper: Season {}", seasonId);
            return seasonId;
        }

    } // namespace MythicPlus
} // namespace DarkChaos
