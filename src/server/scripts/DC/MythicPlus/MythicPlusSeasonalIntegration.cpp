/*
 * Mythic+ Seasonal Integration - DarkChaos
 *
 * Integration of M+ system with generic seasonal framework
 *
 * Author: DarkChaos Development Team
 * Date: November 22, 2025
 */

#include "MythicDifficultyScaling.h"
#include "../Seasons/SeasonalSystem.h"
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
            // Try generic seasonal system first
            if (Seasonal::GetSeasonalManager())
            {
                auto* activeSeason = Seasonal::GetSeasonalManager()->GetActiveSeason();
                if (activeSeason)
                {
                    LOG_DEBUG("mythicplus", "Using generic seasonal system: Season {}", activeSeason->season_id);
                    return activeSeason->season_id;
                }
            }
            
            // Fallback to M+ specific season table (backward compatibility)
            QueryResult result = WorldDatabase.Query("SELECT season_id FROM dc_mplus_seasons WHERE is_active = 1 ORDER BY start_ts DESC LIMIT 1");
            if (result)
            {
                uint32 seasonId = (*result)[0].Get<uint32>();
                LOG_DEBUG("mythicplus", "Using M+ specific season table: Season {}", seasonId);
                return seasonId;
            }
            
            // Last resort: config or default
            uint32 configSeason = sConfigMgr->GetOption<uint32>("DarkChaos.ActiveSeasonID", 1);
            LOG_DEBUG("mythicplus", "Using config/default season: Season {}", configSeason);
            return configSeason;
        }
        
    } // namespace MythicPlus
} // namespace DarkChaos
