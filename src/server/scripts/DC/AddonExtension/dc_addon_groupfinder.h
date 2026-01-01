/*
 * Dark Chaos - Group Finder Addon Module Public Interface
 * ========================================================
 *
 * Public functions for the Group Finder Addon Module.
 */

#ifndef DC_ADDON_GROUPFINDER_H
#define DC_ADDON_GROUPFINDER_H

#include "Player.h"

namespace DCAddon
{
    namespace GroupFinder
    {
        // Sends a signal to open the Group Finder UI
        void SendOpenGroupFinder(Player* player);
    }
}

#endif
