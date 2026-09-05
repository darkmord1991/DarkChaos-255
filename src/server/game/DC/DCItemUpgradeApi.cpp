/*
 * DCItemUpgradeApi.cpp
 *
 * Holds the single provider pointer the scripts side registers and the modules
 * side consumes. See DCItemUpgradeApi.h for why the indirection exists.
 */

#include "DCItemUpgradeApi.h"

namespace DarkChaos
{
    namespace ItemUpgradeApi
    {
        namespace
        {
            // Set once during script loading, on the world thread, before any bot
            // is in world -- no synchronisation needed beyond that ordering.
            Provider* s_provider = nullptr;
        }

        void SetProvider(Provider* provider)
        {
            s_provider = provider;
        }

        Provider* GetProvider()
        {
            return s_provider;
        }
    }
}
