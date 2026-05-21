// -----------------------------------------------------------------------------
// hlbg_announce.cpp
// -----------------------------------------------------------------------------
// Announcement helpers:
// - GetBgChatPrefix(): provides a battleground-style link prefix for messages.
// - HandleWinMessage(): zone broadcast for win shout with prefix.
// - BroadcastStatusToZone(): periodic status mirrors .hlbg output.
// -----------------------------------------------------------------------------
#include "hlbg.h"
#include "WorldSessionMgr.h"
#include "Chat.h"

// Chat cosmetics: clickable item link prefix for BG notifications
std::string OutdoorPvPHL::GetBgChatPrefix() const
{
    return "|cff0070dd[Hinterland Defence]|r ";
}

void OutdoorPvPHL::HandleWinMessage(const char* message)
{
    // Chat output disabled for HLBG.
    (void)message;
    return;
}

void OutdoorPvPHL::BroadcastStatusToZone()
{
    // Chat output disabled for HLBG.
    return;

    uint32 now = NowSec();
    // Throttle status broadcasts to once per second per map instance to avoid spam
    if (now - _lastZoneAnnounceEpoch < 1)
        return;
    _lastZoneAnnounceEpoch = now;
    // Build lines that mirror .hlbg status
    uint32 secs = GetTimeRemainingSeconds();
    uint32 min = secs / 60u;
    uint32 sec = secs % 60u;
    uint32 a = GetResources(TEAM_ALLIANCE);
    uint32 h = GetResources(TEAM_HORDE);

    // Compose strings
    BroadcastToZone("Hinterland BG status");
    BroadcastToZone("Time remaining: %02u:%02u", (unsigned)min, (unsigned)sec);
    BroadcastToZone("Resources: Alliance=%u, Horde=%u", (unsigned)a, (unsigned)h);
    if (_affixAnnounce && _affixEnabled)
    {
        const char* aff = GetAffixName(_activeAffix);
        BroadcastToZone("Affix: %s", aff);
    }
}
