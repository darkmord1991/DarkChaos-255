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

// Internal unconditional sender used by both the public helper and the force path
// context: small tag that classifies the payload sender/context (e.g. "XP").
// This is included in the dedupe key so different payload-types under the
// same addon prefix can be deduped independently.
static void SendXPAddonToPlayerInternal(Player* player, const char* context, uint32 xp, uint32 xpMax, uint32 level, bool bypassDedupe = false)
{
    if (!player)
        return;

    // Build payload: "XP|<xp>|<xpMax>|<level>"
    std::string payload = std::string("XP|") + std::to_string(xp) + "|" + std::to_string(xpMax) + "|" + std::to_string(level);

    // Compose as addon whisper "DCRXP\t<payload>" so client fires CHAT_MSG_ADDON with prefix="DCRXP"
    std::string message = std::string("DCRXP\t") + payload;

    // Build a dedupe key that includes sender context so different logical
    // messages (XP vs future payloads) are treated independently.
    std::string dedupeKey = std::string(context ? context : "") + "|" + payload;

    // Server-side quick dedupe: skip sending identical dedupeKey within a small window
    if (!bypassDedupe && player->IsDuplicateDCRXPPayload(dedupeKey))
    {
        LOG_DEBUG("addons.dcrxp", "SendXPAddonToPlayerInternal: duplicate payload (key={}) for {} (guid={}) -> skipping", dedupeKey, player->GetName(), player->GetGUID().ToString());
        return;
    }

    WorldSession* s = player->GetSession();
    if (s)
    {
        // Log a confirmation so GiveXP -> addon packet flows can be correlated in server logs
        LOG_INFO("addons.dcrxp", "SendXPAddonToPlayer: sending DCRXP to {} (guid={}, xp={}, xpMax={}, level={})", player->GetName(), player->GetGUID().ToString(), xp, xpMax, level);
        WorldPacket data;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, message);
        s->SendPacket(&data);
        // Record the dedupe key/timestamp so subsequent identical sends can be deduped
        player->UpdateLastDCRXPPayload(dedupeKey);
    }
}

// Public helper: only send addon snapshots for players at or above the configured threshold
// to avoid spamming low-level clients that don't need the fallback UI.
// Public helper: context defaults to "XP" for the current use-case.
void SendXPAddonToPlayer(Player* player, uint32 xp, uint32 xpMax, uint32 level, const char* context /*= "XP"*/)
{
    if (!player)
        return;

    // Server policy: only send DCRXP snapshots when the player's level is >= 80.
    // This prevents unnecessary addon traffic for low-level characters.
    const uint32 kDCRXPMinLevel = 80;
    if (player->GetLevel() < kDCRXPMinLevel)
    {
        LOG_DEBUG("addons.dcrxp", "SendXPAddonToPlayer: player {} (guid={}) level {} < {} -> skipping DCRXP send",
                  player->GetName(), player->GetGUID().ToString(), player->GetLevel(), kDCRXPMinLevel);
        return;
    }

    SendXPAddonToPlayerInternal(player, context ? context : "XP", xp, xpMax, level, false);
}

// Force-send variant: bypasses the level threshold and sends unconditionally.
// Intended for admin/GM commands that explicitly request a snapshot.
void SendXPAddonToPlayerForce(Player* player, uint32 xp, uint32 xpMax, uint32 level, const char* context /*= "XP"*/)
{
    // Force-send must bypass dedupe and any level checks; use bypass flag
    SendXPAddonToPlayerInternal(player, context ? context : "XP", xp, xpMax, level, true);
}
