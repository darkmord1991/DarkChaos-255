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

        // Bridges addon keystone-activation requests to the Font of Power state machine.
        void HandleKeystoneActivationResponse(Player* player, bool accepted);
        void HandleKeystoneActivationCancel(Player* player);

        // True once this session has sent any DC|MPLUS| request, which only
        // DC-MythicPlus does. Used to decide whether end-of-run output belongs
        // in the addon's result frame or in the chat-window fallback - a client
        // that merely completed the CORE handshake (e.g. DC-Collection only)
        // must still get the chat transcript.
        bool PlayerHasMythicPlusAddon(Player* player);
        void ForgetMythicPlusAddonSession(ObjectGuid::LowType playerGuid);
    }
}

#endif
