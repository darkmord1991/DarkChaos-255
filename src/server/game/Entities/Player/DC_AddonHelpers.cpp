/*
 * Small helper functions to send addon-style messages from server to client.
 * Used by DC-RestoreXP: send XP/xpMax/level payloads so legacy clients can show an XP bar.
 */
#include "Player.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "Chat.h"
#include "Log.h"
#include <string>

// Compose and send a CHAT_MSG_ADDON style packet that addons can consume via CHAT_MSG_ADDON
// Prefix kept short for 3.3.5a limits; addon listens for prefix containing "DCRXP"
void SendXPAddonToPlayer(Player* player, uint32 xp, uint32 xpMax, uint32 level)
{
    if (!player)
        return;

    // Build payload: "XP|<xp>|<xpMax>|<level>"
    std::string payload = std::string("XP|") + std::to_string(xp) + "|" + std::to_string(xpMax) + "|" + std::to_string(level);

    // Compose as addon whisper "DCRXP\t<payload>" so client fires CHAT_MSG_ADDON with prefix="DCRXP"
    std::string message = std::string("DCRXP\t") + payload;

    if (WorldSession* s = player->GetSession())
    {
        // Log a confirmation so GiveXP -> addon packet flows can be correlated in server logs
        LOG_INFO("addons.dcrxp", "SendXPAddonToPlayer: sending DCRXP to {} (guid={}, xp={}, xpMax={}, level={})", player->GetName(), player->GetGUID().ToString(), xp, xpMax, level);
        WorldPacket data;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, message);
        s->SendPacket(&data);
    }
}
