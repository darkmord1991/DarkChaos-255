/*
 * DarkChaos CrossSystem - Season Resolver
 *
 * THE single definition of "which season is active". Every DC system resolves
 * the season through this header, directly or through one of the forwarders
 * below.
 *
 * Precedence (highest first):
 *   1. worldserver.conf  DarkChaos.ActiveSeasonID   - admin override
 *   2. SeasonalManager / dc_seasons                 - content state
 *   3. Season 1                                     - last resort, logged
 *
 * History: this file and CrossSystemSeasonHelper.h each used to resolve the
 * season independently, in OPPOSITE order - this one consulted SeasonalManager
 * first, the helper consulted the config first. Whenever worldserver.conf and
 * dc_seasons disagreed the two returned different season IDs in the same tick,
 * so item upgrades could be written under one season while the leaderboard
 * reported another. Both now funnel through ResolveActiveSeasonId().
 *
 * Moved from ItemUpgrades to CrossSystem (Jan 2026); unified Aug 2026.
 */

#pragma once

#include "Config.h"
#include "Define.h"
#include "Log.h"
#include "DC/Seasons/SeasonalSystem.h"

#include <atomic>
#include <ctime>

namespace DarkChaos
{
    namespace CrossSystem
    {
        namespace detail
        {
            // Cached so the hot paths (handshakes, gossip, reward displays) do
            // not re-enter SeasonalManager on every call.
            inline std::atomic<uint32> g_cachedSeasonId{ 0 };
            inline std::atomic<time_t> g_cachedAt{ 0 };

            constexpr time_t SEASON_CACHE_TTL_SECONDS = 300;
        }

        /**
         * @brief Resolve the active season from source, ignoring the cache.
         *
         * Prefer GetActiveSeasonId(); this is exposed so the startup
         * consistency check can compare sources without disturbing the cache.
         *
         * @return uint32 Active season id. Never returns 0.
         */
        inline uint32 ResolveActiveSeasonId()
        {
            // Priority 1: admin-controlled config override.
            if (uint32 const configured =
                sConfigMgr->GetOption<uint32>("DarkChaos.ActiveSeasonID", 0))
                return configured;

            // Priority 2: content state (SeasonalManager reads dc_seasons).
            if (Seasonal::SeasonalManager* manager = Seasonal::GetSeasonalManager())
            {
                if (uint32 const active = manager->GetCurrentSeasonId())
                    return active;
            }

            LOG_WARN("dc.season",
                "No active season found. Set DarkChaos.ActiveSeasonID in worldserver.conf "
                "or activate a row in dc_seasons. Defaulting to season 1.");

            return 1;
        }

        /**
         * @brief Get the active season id. This is what every DC system calls.
         *
         * @param forceRefresh Bypass the cache and re-resolve from source.
         * @return uint32 Active season id. Never returns 0.
         */
        inline uint32 GetActiveSeasonId(bool forceRefresh = false)
        {
            time_t const now = time(nullptr);

            if (!forceRefresh)
            {
                uint32 const cached =
                    detail::g_cachedSeasonId.load(std::memory_order_acquire);

                if (cached > 0
                    && (now - detail::g_cachedAt.load(std::memory_order_acquire))
                        < detail::SEASON_CACHE_TTL_SECONDS)
                    return cached;
            }

            uint32 const resolved = ResolveActiveSeasonId();

            detail::g_cachedSeasonId.store(resolved, std::memory_order_release);
            detail::g_cachedAt.store(now, std::memory_order_release);

            return resolved;
        }

        /**
         * @brief Drop the cached season id. Call from any command that changes
         *        the active season so the change is visible immediately instead
         *        of up to SEASON_CACHE_TTL_SECONDS later.
         */
        inline void InvalidateSeasonCache()
        {
            detail::g_cachedAt.store(0, std::memory_order_release);
            GetActiveSeasonId(true);
        }

        // Legacy name, kept so existing call sites keep compiling.
        inline uint32 GetCurrentSeasonId()
        {
            return GetActiveSeasonId();
        }
    }

    // Legacy alias for backward compatibility. Resolves identically to
    // CrossSystem::GetActiveSeasonId() - before unification it did not.
    namespace ItemUpgrade
    {
        inline uint32 GetCurrentSeasonId()
        {
            return CrossSystem::GetActiveSeasonId();
        }
    }
}
