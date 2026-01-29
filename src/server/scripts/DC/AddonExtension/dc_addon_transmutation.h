/*
 * Dark Chaos - Transmutation Addon Interface
 */

#ifndef DC_ADDON_TRANSMUTATION_H
#define DC_ADDON_TRANSMUTATION_H

#include "Player.h"

namespace DCAddon
{
    namespace Upgrade
    {
        void SendOpenTransmutationUI(Player* player);
        void SendCurrencyUpdate(Player* player);  // Shared with dc_addon_upgrade.cpp
    }
}

#endif
