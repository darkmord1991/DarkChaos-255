/*
 * DarkChaos Season Helper - Unified Season Access
 *
 * This header provides a simple, unified way to access the current active season
 * across ALL DarkChaos systems. Use this instead of querying individual season
 * tables (dc_mplus_seasons, dc_hlbg_seasons, dc_seasons, etc.)
 *
 * IMPORTANT: This is the SINGLE SOURCE OF TRUTH for season ID access.
 *
 * Usage:
 *   #include "CrossSystem/DCSeasonHelper.h"
 *   uint32 seasonId = DarkChaos::GetActiveSeasonId();
 *
 * The function uses the following priority:
 *   1. Config value: DarkChaos.ActiveSeasonID (from worldserver.conf)
 *   2. Database fallback: dc_seasons table
 *   3. Legacy fallback: dc_mplus_seasons table
 *   4. Default: 1
 *
 * Author: DarkChaos Development Team
 * Date: December 2025
 */

#pragma once

#include "Define.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include <atomic>
#include <string>

namespace DarkChaos
{
    // =========================================================================
    // Cached Season ID - Thread-safe singleton
    // =========================================================================
    
    namespace Internal
    {
        // Thread-safe cached season ID (refreshed periodically or on demand)
        inline std::atomic<uint32> g_cachedSeasonId{ 0 };
        inline std::atomic<time_t> g_lastSeasonRefresh{ 0 };
        
        // Refresh interval (5 minutes)
        constexpr time_t SEASON_CACHE_REFRESH_SECONDS = 300;
    }

    // =========================================================================
    // Primary API - Use this everywhere!
    // =========================================================================

    /**
     * @brief Get the currently active season ID for all DarkChaos systems.
     * 
     * This is the SINGLE SOURCE OF TRUTH for season access. All systems
     * (Mythic+, HLBG, ItemUpgrades, SeasonalRewards) should use this.
     * 
     * The function returns a cached value for performance, refreshing
     * from the config/database every 5 minutes.
     * 
     * @param forceRefresh If true, bypasses cache and refreshes from source
     * @return uint32 The active season ID (never returns 0, minimum is 1)
     */
    inline uint32 GetActiveSeasonId(bool forceRefresh = false)
    {
        time_t now = time(nullptr);
        
        // Check if cache is valid
        if (!forceRefresh && Internal::g_cachedSeasonId.load() > 0)
        {
            if ((now - Internal::g_lastSeasonRefresh.load()) < Internal::SEASON_CACHE_REFRESH_SECONDS)
            {
                return Internal::g_cachedSeasonId.load();
            }
        }
        
        uint32 seasonId = 0;
        
        // Priority 1: Config value (most reliable - admin controlled)
        seasonId = sConfigMgr->GetOption<uint32>("DarkChaos.ActiveSeasonID", 0);
        if (seasonId > 0)
        {
            Internal::g_cachedSeasonId.store(seasonId);
            Internal::g_lastSeasonRefresh.store(now);
            return seasonId;
        }
        
        // Priority 2: Database fallback (dc_seasons in CharacterDatabase)
        if (QueryResult result = CharacterDatabase.Query(
            "SELECT season_id FROM dc_seasons WHERE season_state = 1 ORDER BY season_id DESC LIMIT 1"))
        {
            seasonId = (*result)[0].Get<uint32>();
            if (seasonId > 0)
            {
                Internal::g_cachedSeasonId.store(seasonId);
                Internal::g_lastSeasonRefresh.store(now);
                return seasonId;
            }
        }
        
        // Priority 3: Secondary database fallback (dc_mplus_seasons in WorldDatabase)
        // This is for backward compatibility during migration
        if (QueryResult result = WorldDatabase.Query(
            "SELECT season FROM dc_mplus_seasons WHERE is_active = 1 LIMIT 1"))
        {
            seasonId = (*result)[0].Get<uint32>();
            if (seasonId > 0)
            {
                Internal::g_cachedSeasonId.store(seasonId);
                Internal::g_lastSeasonRefresh.store(now);
                LOG_WARN("dc.season", "Using legacy dc_mplus_seasons table for season ID. "
                         "Consider migrating to unified dc_seasons table.");
                return seasonId;
            }
        }
        
        // Final fallback: Default to season 1
        LOG_WARN("dc.season", "No active season found! Defaulting to season 1. "
                 "Set DarkChaos.ActiveSeasonID in worldserver.conf or configure dc_seasons table.");
        Internal::g_cachedSeasonId.store(1);
        Internal::g_lastSeasonRefresh.store(now);
        return 1;
    }

    /**
     * @brief Force refresh of the cached season ID.
     * Call this when an admin changes the season via command.
     */
    inline void InvalidateSeasonCache()
    {
        Internal::g_lastSeasonRefresh.store(0);
        GetActiveSeasonId(true); // Force immediate refresh
    }

    /**
     * @brief Get the current season name (for display purposes).
     * @return std::string Season name or "Season X" if not found
     */
    inline std::string GetActiveSeasonName()
    {
        uint32 seasonId = GetActiveSeasonId();
        
        // Try CharacterDatabase first (primary)
        if (QueryResult result = CharacterDatabase.Query(
            "SELECT season_name FROM dc_seasons WHERE season_id = {} LIMIT 1", seasonId))
        {
            std::string name = (*result)[0].Get<std::string>();
            if (!name.empty())
                return name;
        }
        
        // Fallback to WorldDatabase (legacy)
        if (QueryResult result = WorldDatabase.Query(
            "SELECT name FROM dc_mplus_seasons WHERE season = {} LIMIT 1", seasonId))
        {
            std::string name = (*result)[0].Get<std::string>();
            if (!name.empty())
                return name;
        }
        
        // Default format
        return "Season " + std::to_string(seasonId);
    }

} // namespace DarkChaos

/*
 * MIGRATION NOTES:
 *
 * The DarkChaos codebase previously had multiple season tables:
 *   - dc_seasons (CharacterDatabase) - Used by SeasonalSystem, ItemUpgrades
 *   - dc_mplus_seasons (WorldDatabase) - Used by MythicPlus, addon handlers
 *   - dc_hlbg_seasons (WorldDatabase) - Used by HinterlandBG
 *
 * These are being consolidated:
 *   1. dc_seasons remains the PRIMARY source (CharacterDatabase)
 *   2. dc_mplus_seasons and dc_hlbg_seasons can remain for system-specific
 *      configuration (affix schedules, featured dungeons) but should NOT
 *      be the source of truth for "which season is active"
 *   3. The config value DarkChaos.ActiveSeasonID is the easiest way to
 *      set the active season without database changes
 *
 * To migrate existing code:
 *   BEFORE:
 *     QueryResult result = WorldDatabase.Query("SELECT season FROM dc_mplus_seasons WHERE is_active = 1");
 *     uint32 seasonId = result ? (*result)[0].Get<uint32>() : 1;
 *
 *   AFTER:
 *     #include "CrossSystem/DCSeasonHelper.h"
 *     uint32 seasonId = DarkChaos::GetActiveSeasonId();
 */
