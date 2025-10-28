// -----------------------------------------------------------------------------
// OutdoorPvPHL_Announce.cpp
// -----------------------------------------------------------------------------
// Announcement helpers:
// - GetBgChatPrefix(): provides a battleground-style link prefix for messages.
// - HandleWinMessage(): zone broadcast for win shout with prefix.
// - BroadcastStatusToZone(): periodic status mirrors .hlbg output.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
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
    std::string full = GetBgChatPrefix() + std::string(message);
    if (Map* m = GetMap())
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            m->SendZoneText(OutdoorPvPHLBuffZones[i], full.c_str());
}

void OutdoorPvPHL::BroadcastStatusToZone()
{
    // Build lines that mirror .hlbg status
    uint32 secs = GetTimeRemainingSeconds();
    uint32 min = secs / 60u;
    uint32 sec = secs % 60u;
    uint32 a = GetResources(TEAM_ALLIANCE);
    uint32 h = GetResources(TEAM_HORDE);

    // Compose strings
    if (Map* m = GetMap())
        m->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + "|cffffd700Hinterland BG status:|r").c_str());
    char line1[64];
    snprintf(line1, sizeof(line1), "  Time remaining: %02u:%02u", (unsigned)min, (unsigned)sec);
    if (Map* m = GetMap())
        m->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + std::string(line1)).c_str());
    char line2[96];
    snprintf(line2, sizeof(line2), "  Resources: |cff1e90ffAlliance|r=%u, |cffff0000Horde|r=%u", (unsigned)a, (unsigned)h);
    if (Map* m = GetMap())
        m->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + std::string(line2)).c_str());
    if (_affixAnnounce && _affixEnabled)
    {
        const char* aff = "None";
        switch (_activeAffix) { case AFFIX_SUNLIGHT: aff = "Sunlight"; break; case AFFIX_CLEAR_SKIES: aff = "Clear Skies"; break; case AFFIX_GENTLE_BREEZE: aff = "Gentle Breeze"; break; case AFFIX_STORM: aff = "Storm"; break; case AFFIX_HEAVY_RAIN: aff = "Heavy Rain"; break; case AFFIX_FOG: aff = "Fog"; break; default: break; }
        char line3[96];
        snprintf(line3, sizeof(line3), "  Affix: %s", aff);
        if (Map* m = GetMap())
            m->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + std::string(line3)).c_str());
    }
}
