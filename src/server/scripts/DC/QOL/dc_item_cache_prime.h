/*
 * DarkChaos QoL - shared item cache priming
 *
 * Pushes SMSG_ITEM_QUERY_SINGLE_RESPONSE to a client before it asks, so its item
 * cache already holds the entry when a frame draws it. One per-session record of
 * what was sent is shared by every caller (the vendor prime and the QOS item
 * prefetch), so an entry goes out at most once per session whichever asked for
 * it. Implemented in dc_vendor_item_cache_prime.cpp; the record is bounded by
 * DC.Vendor.PrimeItemCache.MaxTrackedPerSession and cleared on logout.
 */

#ifndef DC_ITEM_CACHE_PRIME_H
#define DC_ITEM_CACHE_PRIME_H

#include "Define.h"

class Player;

namespace DarkChaos::ItemCachePrime
{
    enum class Result
    {
        Sent,           // the response was pushed
        AlreadySent,    // pushed earlier this session; the client still has it
        UnknownItem,    // no item_template row, so nothing the client could cache
        NoClient,       // a bot, or a player without a session
        SessionFull,    // the session hit the tracking cap; its record was reset
    };

    Result PrimeItem(Player* player, uint32 entry);
}

#endif
