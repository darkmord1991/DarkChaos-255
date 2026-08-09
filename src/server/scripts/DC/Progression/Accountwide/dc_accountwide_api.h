/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Cross-file surface of the account-wide progression pools.
 *
 * Each pool keeps its cache private inside its own translation unit; this
 * header is the only way the admin commands and the maintenance script reach
 * them, so the caches stay single-owner.
 */

#ifndef DC_ACCOUNTWIDE_API_H
#define DC_ACCOUNTWIDE_API_H

#include "Define.h"

#include <cstddef>

class Player;

#define DC_ACCOUNTWIDE_POOL_API(ns)                        \
    namespace ns                                           \
    {                                                      \
        void ClearCache(uint32 accountId);                 \
        std::size_t CachedAccounts();                      \
        bool IsAccountCached(uint32 accountId);            \
        std::size_t PoolSize(uint32 accountId);            \
        void ForceSync(Player* player);                    \
        char const* TableName();                           \
    }

DC_ACCOUNTWIDE_POOL_API(DCAccountWideAchievements)
DC_ACCOUNTWIDE_POOL_API(DCAccountWideReputation)
DC_ACCOUNTWIDE_POOL_API(DCAccountWideFriends)

#undef DC_ACCOUNTWIDE_POOL_API

namespace DCAccountWideMaintenance
{
    /// Which pools a purge/inspect targets.
    enum PoolMask : uint8
    {
        POOL_ACHIEVEMENTS = 0x1,
        POOL_REPUTATION   = 0x2,
        POOL_FRIENDS      = 0x4,
        POOL_ALL          = POOL_ACHIEVEMENTS | POOL_REPUTATION | POOL_FRIENDS
    };

    /// Deletes the account's pooled rows and drops its cached pools.
    void PurgeAccount(uint32 accountId, uint8 mask);

    /// Deletes rows belonging to accounts that no longer exist in acore_auth.
    /// Asynchronous; `mask` selects the tables.
    void PurgeOrphans(uint8 mask);
}

#endif // DC_ACCOUNTWIDE_API_H
