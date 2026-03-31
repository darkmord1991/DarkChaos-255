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
    // Blue-quality color for visibility; item ID 47241 (Emblem of Triumph) used as a neutral link host
    return "|cff0070dd|Hitem:47241:0:0:0:0:0:0:0:0|h[Hinterland Defence]|h|r ";
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
    if (Map* m = GetMap())
        m->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + "|TInterface\\Icons\\INV_Misc_PocketWatch_01:16|t |cffffd700Hinterland BG status|r").c_str());
    char line1[128];
    snprintf(line1, sizeof(line1), "|TInterface\\Icons\\INV_Misc_PocketWatch_01:14|t |cffffff00Time remaining:|r |cffffffff%02u:%02u|r", (unsigned)min, (unsigned)sec);
    if (Map* m = GetMap())
        m->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + std::string(line1)).c_str());
    char line2[160];
    snprintf(line2, sizeof(line2), "|TInterface\\Icons\\INV_Misc_Coin_01:14|t |cffffff00Resources:|r |cff1e90ffAlliance|r=%u, |cffff2020Horde|r=%u", (unsigned)a, (unsigned)h);
    if (Map* m = GetMap())
        m->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + std::string(line2)).c_str());
    if (_affixAnnounce && _affixEnabled)
    {
        const char* aff = GetAffixName(_activeAffix);
        char line3[160];
        snprintf(line3, sizeof(line3), "|TInterface\\Icons\\Spell_Nature_Cyclone:14|t |cffffff00Affix:|r |cff98fb98%s|r", aff);
        if (Map* m = GetMap())
            m->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + std::string(line3)).c_str());
    }
}
