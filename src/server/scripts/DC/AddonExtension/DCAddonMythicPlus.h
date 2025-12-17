/*
 * Dark Chaos - Mythic+ Addon Module Public Interface
 * ===================================================
 * 
 * Public functions for the Mythic+ Addon Module.
 */

#ifndef DC_ADDON_MYTHICPLUS_H
#define DC_ADDON_MYTHICPLUS_H

#include "Player.h"

namespace DCAddon
{
    namespace MythicPlus
    {
        // Sends the full Great Vault info packet to the player.
        // openWindow: If true, instructs the client to open the Vault UI.
        void SendVaultInfo(Player* player, bool openWindow = false);

        // Sends a specific signal to open the Vault UI
        void SendOpenVault(Player* player);
    }
}

#endif
