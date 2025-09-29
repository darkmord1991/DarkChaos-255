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
    for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
        sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[i], full.c_str());
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
    sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + "|cffffd700Hinterland BG status:|r").c_str());
    char line1[64];
    snprintf(line1, sizeof(line1), "  Time remaining: %02u:%02u", (unsigned)min, (unsigned)sec);
    sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + std::string(line1)).c_str());
    char line2[96];
    snprintf(line2, sizeof(line2), "  Resources: |cff1e90ffAlliance|r=%u, |cffff0000Horde|r=%u", (unsigned)a, (unsigned)h);
    sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + std::string(line2)).c_str());
}
