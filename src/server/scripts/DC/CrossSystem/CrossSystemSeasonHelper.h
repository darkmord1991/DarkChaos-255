/*
 * DarkChaos Season Helper - Unified Season Access
 *
 * Convenience wrappers in namespace DarkChaos over the canonical resolver in
 * SeasonResolver.h, plus the season NAME lookup (which has no other home).
 *
 * There is exactly one season resolution path now:
 *
 *     DarkChaos::GetActiveSeasonId()
 *       -> DarkChaos::CrossSystem::GetActiveSeasonId()
 *          -> DarkChaos::CrossSystem::ResolveActiveSeasonId()
 *
 * Precedence and the reason it is what it is are documented in
 * SeasonResolver.h. Do not add a second resolver here; this header used to
 * contain one, and it disagreed with SeasonResolver.h whenever
 * worldserver.conf and dc_seasons diverged.
 *
 * Usage:
 *   #include "DC/CrossSystem/CrossSystemSeasonHelper.h"
 *   uint32 seasonId = DarkChaos::GetActiveSeasonId();
 *
 * Author: DarkChaos Development Team
 * Date: December 2025 (unified August 2026)
 */

#pragma once

#include "DC/CrossSystem/SeasonResolver.h"

#include "DatabaseEnv.h"
#include "Define.h"

#include <string>

namespace DarkChaos
{
    /**
     * @brief Get the currently active season ID for all DarkChaos systems.
     * @param forceRefresh If true, bypasses the cache and refreshes from source.
     * @return uint32 The active season ID (never returns 0, minimum is 1)
     */
    inline uint32 GetActiveSeasonId(bool forceRefresh = false)
    {
        return CrossSystem::GetActiveSeasonId(forceRefresh);
    }

    /**
     * @brief Force refresh of the cached season ID.
     * Call this when an admin changes the season via command.
     */
    inline void InvalidateSeasonCache()
    {
        CrossSystem::InvalidateSeasonCache();
    }

    /**
     * @brief Get the current season name (for display purposes).
     * Cached per season id: this used to issue a blocking WorldDatabase query
     * on EVERY call (handshakes, gossip, reward displays). The name only
     * changes with the season, so one lookup per season id per session
     * suffices. World-thread only.
     * @return std::string Season name or "Season X" if not found
     */
    inline std::string GetActiveSeasonName()
    {
        uint32 const seasonId = GetActiveSeasonId();

        static uint32 cachedSeasonId = 0;
        static std::string cachedSeasonName;

        if (seasonId == cachedSeasonId && !cachedSeasonName.empty())
            return cachedSeasonName;

        std::string name = "Season " + std::to_string(seasonId);
        if (QueryResult result = WorldDatabase.Query(
            "SELECT season_name FROM dc_seasons WHERE season_id = {} LIMIT 1", seasonId))
        {
            std::string dbName = (*result)[0].Get<std::string>();
            if (!dbName.empty())
                name = dbName;
        }

        cachedSeasonId = seasonId;
        cachedSeasonName = name;
        return name;
    }

} // namespace DarkChaos

/*
 * MIGRATION NOTES:
 *
 * The DarkChaos codebase previously had multiple season tables:
 *   - dc_seasons (WorldDatabase) - Used by SeasonalSystem, ItemUpgrades
 *   - dc_mplus_seasons (WorldDatabase) - Used by MythicPlus config data
 *   - dc_hlbg_seasons (WorldDatabase) - Used by HinterlandBG config data
 *
 * These are being consolidated:
 *   1. dc_seasons remains the PRIMARY source
 *   2. dc_mplus_seasons and dc_hlbg_seasons can remain for system-specific
 *      configuration (affix schedules, featured dungeons) but should NOT
 *      be the source of truth for "which season is active"
 *   3. The config value DarkChaos.ActiveSeasonID overrides the table, and is
 *      the easiest way to set the active season without database changes
 *
 * To migrate existing code:
 *   BEFORE:
 *     QueryResult result = WorldDatabase.Query("SELECT season FROM dc_mplus_seasons WHERE is_active = 1");
 *     uint32 seasonId = result ? (*result)[0].Get<uint32>() : 1;
 *
 *   AFTER:
 *     #include "DC/CrossSystem/CrossSystemSeasonHelper.h"
 *     uint32 seasonId = DarkChaos::GetActiveSeasonId();
 */
