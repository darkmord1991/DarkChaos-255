/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * 
 * DarkChaos Hotspots System - Constants
 * 
 * Centralized constants for the hotspot system to eliminate magic numbers
 * and improve maintainability.
 */

#ifndef HOTSPOT_CONSTANTS_H
#define HOTSPOT_CONSTANTS_H

#include <cstdint>
#include <string>

namespace HotspotConstants
{
    // Spell IDs
    constexpr uint32 HOTSPOT_AURA_SPELL_ID = 800001;
    constexpr uint32 HOTSPOT_BUFF_SPELL_ID = 800001;

    // GameObject entries
    constexpr uint32 HOTSPOT_MARKER_GO_ENTRY = 179976; // Alliance Flag

    // Timing constants (in seconds)
    constexpr uint32 DEFAULT_DURATION_MINUTES = 60;
    constexpr uint32 DEFAULT_RESPAWN_DELAY_MINUTES = 30;
    constexpr uint32 CLEANUP_INTERVAL_SECONDS = 10;
    constexpr uint32 PLAYER_UPDATE_INTERVAL_SECONDS = 2;

    // Distance constants (in yards)
    constexpr float DEFAULT_RADIUS = 150.0f;
    constexpr float DEFAULT_ANNOUNCE_RADIUS = 500.0f;

    // Limits and thresholds
    constexpr uint32 DEFAULT_MAX_ACTIVE_HOTSPOTS = 5;
    constexpr uint32 DEFAULT_EXPERIENCE_BONUS_PERCENT = 100;
    constexpr size_t MAX_ADDON_PAYLOAD_BYTES = 512;
    constexpr int BUFF_APPLY_MAX_RETRIES = 3;
    constexpr int ATTEMPTS_PER_RECT = 48;
    constexpr int FALLBACK_SAMPLING_ATTEMPTS = 2048;

    // Minimap icon types
    constexpr uint32 MINIMAP_ICON_ARROW = 1;
    constexpr uint32 MINIMAP_ICON_CROSS = 2;

    // Fallback texture path for addons when spell icon cannot be resolved
    const std::string FALLBACK_TEXTURE_PATH = "Interface\\Icons\\INV_Misc_Map_01";

    // Helper: Get safe zone name from zone ID
    inline std::string GetSafeZoneName(uint32 zoneId)
    {
        extern DBCStorage<AreaTableEntry> sAreaTableStore;
        if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(zoneId))
        {
            if (area->area_name[0])
                return area->area_name[0];
        }
        return "Unknown Zone";
    }

    // Helper: Get safe map name from map ID
    inline std::string GetSafeMapName(uint32 mapId)
    {
        switch (mapId)
        {
            case 0: return "Eastern Kingdoms";
            case 1: return "Kalimdor";
            case 530: return "Outland";
            case 571: return "Northrend";
            case 37: return "Azshara Crater";
            default: return "Unknown Map";
        }
    }
}

#endif // HOTSPOT_CONSTANTS_H
