#include "Define.h"
#include "DC/CrossSystem/CrossSystemCache.h"
#include <cstdint>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // Use shared CrossSystem LRU cache implementation
        template<typename Key, typename Value>
        using LRUCache = DarkChaos::Cache::LRUCache<Key, Value>;

        /**
         * Performance Statistics for Item Upgrades
         */
        struct UpgradeStatistics
        {
            uint32_t upgrades_performed{0};
			uint32_t cache_hits{0};
			uint32_t cache_misses{0};
			uint32_t db_reads{0};
			uint32_t db_writes{0};
			uint64_t total_latency_us{0}; // Microseconds

            void Reset()
            {
                upgrades_performed = 0;
                cache_hits = 0;
                cache_misses = 0;
                db_reads = 0;
                db_writes = 0;
                total_latency_us = 0;
            }
        };

    } // namespace ItemUpgrade
} // namespace DarkChaos
