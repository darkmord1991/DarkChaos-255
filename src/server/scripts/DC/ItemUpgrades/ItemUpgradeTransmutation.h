/*
 * Deprecated: Transmutation renamed to Exchange (Jan 2026).
 * This header now forwards to ItemUpgradeExchange.h for compatibility.
 */

#ifndef ITEM_UPGRADE_TRANSMUTATION_H
#define ITEM_UPGRADE_TRANSMUTATION_H

#include "ItemUpgradeExchange.h"
        struct TransmutationInput
        {
            uint32 item_id;
            uint32 quantity;
            uint8 required_tier;
            uint8 required_upgrade_level;

            TransmutationInput() :
                item_id(0), quantity(0), required_tier(1), required_upgrade_level(0) {}
        };

        /**
         * Transmutation recipe configuration
        #include "ItemUpgradeExchange.h"

        #endif // ITEM_UPGRADE_TRANSMUTATION_H
}

#endif // ITEM_UPGRADE_TRANSMUTATION_H
