// -----------------------------------------------------------------------------
// HinterlandBGConstants.h
// -----------------------------------------------------------------------------
// Centralized constants for Hinterland BG system
// Eliminates code duplication across multiple files
// -----------------------------------------------------------------------------

#ifndef HINTERLAND_BG_CONSTANTS_H
#define HINTERLAND_BG_CONSTANTS_H

#include <cstdint>

namespace HinterlandBGConstants
{
    // -------------------------------------------------------------------------
    // Spell IDs
    // -------------------------------------------------------------------------
    constexpr uint32 BG_DESERTER_SPELL = 26013;

    // -------------------------------------------------------------------------
    // Gossip Actions
    // -------------------------------------------------------------------------
    constexpr uint32 ACTION_STATUS = 1;
    constexpr uint32 ACTION_HISTORY = 2;
    constexpr uint32 ACTION_STATS = 3;
    constexpr uint32 ACTION_CLOSE = 100;
    constexpr uint32 ACTION_HISTORY_PAGE_BASE = 1000;

    // -------------------------------------------------------------------------
    // UI Pagination
    // -------------------------------------------------------------------------
    constexpr uint32 PAGE_SIZE = 5;
    constexpr uint32 TOP_N = 5;

    // -------------------------------------------------------------------------
    // Timing
    // -------------------------------------------------------------------------
    constexpr uint32 WARMUP_WINDOW_SECONDS = 120;
    constexpr uint32 CACHE_DURATION_MS = 5000;
    constexpr uint32 HL_OFFLINE_GRACE_SECONDS = 45;

    // -------------------------------------------------------------------------
    // Map/Zone IDs
    // -------------------------------------------------------------------------
    constexpr uint32 HLBG_MAP_ID = 47;

    // -------------------------------------------------------------------------
    // Affix Names
    // -------------------------------------------------------------------------
    inline const char* GetAffixName(uint8 affixCode)
    {
        switch (affixCode)
        {
            case 1: return "Sunlight";
            case 2: return "Clear Skies";
            case 3: return "Gentle Breeze";
            case 4: return "Storm";
            case 5: return "Heavy Rain";
            case 6: return "Fog";
            default: return "None";
        }
    }

    // Legacy affix name mapping (for backward compatibility)
    inline const char* GetLegacyAffixName(uint8 affixCode)
    {
        switch (affixCode)
        {
            case 1: return "Haste";
            case 2: return "Slow";
            case 3: return "Reduced Healing";
            case 4: return "Reduced Armor";
            case 5: return "Boss Enrage";
            default: return "None";
        }
    }

    // -------------------------------------------------------------------------
    // Weather Names
    // -------------------------------------------------------------------------
    inline const char* GetWeatherName(uint32 weatherType)
    {
        switch (weatherType)
        {
            case 0: return "Fine";
            case 1: return "Rain";
            case 2: return "Snow";
            case 3: return "Storm";
            default: return "Unknown";
        }
    }

    // Extended weather name mapping
    inline const char* GetExtendedWeatherName(uint32 weatherType)
    {
        static const char* names[] = {
            "Clear", "Rain", "Snow", "Sandstorm", "Storm", "Thunders", "BlackRain"
        };
        return (weatherType < (sizeof(names) / sizeof(names[0]))) ? names[weatherType] : "Weather";
    }

    // -------------------------------------------------------------------------
    // Team Names
    // -------------------------------------------------------------------------
    inline const char* GetTeamName(uint8 teamId)
    {
        switch (teamId)
        {
            case 0: return "Alliance";
            case 1: return "Horde";
            case 2: return "Draw";
            default: return "Unknown";
        }
    }

    inline const char* GetFactionName(bool isAlliance)
    {
        return isAlliance ? "Alliance" : "Horde";
    }

} // namespace HinterlandBGConstants

#endif // HINTERLAND_BG_CONSTANTS_H
