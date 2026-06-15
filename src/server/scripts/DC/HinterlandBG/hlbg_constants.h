// -----------------------------------------------------------------------------
// hlbg_constants.h
// -----------------------------------------------------------------------------
// Centralized constants for Hinterland BG system
// Eliminates code duplication across multiple files
// -----------------------------------------------------------------------------

#ifndef HINTERLAND_BG_CONSTANTS_H
#define HINTERLAND_BG_CONSTANTS_H

#include "Player.h"
#include "DC/CrossSystem/CrossSystemAffixes.h"
#include <cstdint>

namespace HinterlandBGConstants
{
    // -------------------------------------------------------------------------
    // Spell IDs
    // -------------------------------------------------------------------------
    constexpr uint32 BG_DESERTER_SPELL = 26013;

    // HLBG Affix Spell IDs (custom placeholders)
    constexpr uint32 HLBG_AFFIX_SUNLIGHT_SPELL = 910010;      // Player haste buff
    constexpr uint32 HLBG_AFFIX_CLEAR_SKIES_SPELL = 910011;   // Player damage buff
    constexpr uint32 HLBG_AFFIX_GENTLE_BREEZE_SPELL = 910012; // Player healing received buff
    constexpr uint32 HLBG_AFFIX_STORM_NPC_SPELL = 910020;     // NPC damage buff
    constexpr uint32 HLBG_AFFIX_HEAVY_RAIN_NPC_SPELL = 910021; // NPC armor buff
    constexpr uint32 HLBG_AFFIX_FOG_NPC_SPELL = 910022;       // NPC evasion buff

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
    constexpr uint32 HLBG_ZONE_ID = 47;
    constexpr uint32 HLBG_MAP_ID = 1411;
    constexpr uint32 HLBG_AREA_ID = 6738;

    enum HLBGAffixCode : uint8
    {
        HLBG_AFFIX_NONE = 0,
        HLBG_AFFIX_SUNLIGHT = 1,
        HLBG_AFFIX_CLEAR_SKIES = 2,
        HLBG_AFFIX_GENTLE_BREEZE = 3,
        HLBG_AFFIX_STORM = 4,
        HLBG_AFFIX_HEAVY_RAIN = 5,
        HLBG_AFFIX_FOG = 6,
    };

    constexpr uint8 HLBG_AFFIX_STORAGE_SIZE = 7;

    enum AllianceNpcEntries : uint32
    {
        Alliance_Healer = 600005,
        Alliance_Boss = 810003,
        Alliance_Infantry = 810000,
        Alliance_Squadleader = 600011,
        Alliance_Battlewarden = 810009,
        Alliance_Sentry = 810010,
        Alliance_Scout = 810011,
        Alliance_GryphonHerald = 810013,
        Alliance_BannerBearer = 810015,
        Alliance_WatchCaptain = 810017,
        Alliance_Marksman = 810021,
        Alliance_Pathfinder = 810022,
        Alliance_RoostTender = 810023,
    };

    enum HordeNpcEntries : uint32
    {
        Horde_Heal = 600004,
        Horde_Squadleader = 600008,
        Horde_Infantry = 810001,
        Horde_Boss = 810002,
        Horde_Warcaller = 810006,
        Horde_Watchblade = 810007,
        Horde_Spiritmender = 810008,
        Horde_BannerSinger = 810012,
        Horde_Drumkeeper = 810014,
        Horde_FiresideShaman = 810016,
        Horde_Headhunter = 810018,
        Horde_Ritespeaker = 810019,
        Horde_BonfireTender = 810020,
    };

    inline bool IsPlayerInHLBGArea(Player const* player)
    {
        return player
            && player->GetMapId() == HLBG_MAP_ID
            && player->GetAreaId() == HLBG_AREA_ID;
    }

    inline uint32 GetDefaultAffixPlayerSpell(uint8 affixCode)
    {
        switch (affixCode)
        {
            case HLBG_AFFIX_SUNLIGHT:
                return HLBG_AFFIX_SUNLIGHT_SPELL;
            case HLBG_AFFIX_CLEAR_SKIES:
                return HLBG_AFFIX_CLEAR_SKIES_SPELL;
            case HLBG_AFFIX_GENTLE_BREEZE:
                return HLBG_AFFIX_GENTLE_BREEZE_SPELL;
            default:
                return 0u;
        }
    }

    inline uint32 GetDefaultAffixNpcSpell(uint8 affixCode)
    {
        switch (affixCode)
        {
            case HLBG_AFFIX_STORM:
                return HLBG_AFFIX_STORM_NPC_SPELL;
            case HLBG_AFFIX_HEAVY_RAIN:
                return HLBG_AFFIX_HEAVY_RAIN_NPC_SPELL;
            case HLBG_AFFIX_FOG:
                return HLBG_AFFIX_FOG_NPC_SPELL;
            default:
                return 0u;
        }
    }

    inline uint32 GetDefaultAffixWeatherType(uint8 affixCode)
    {
        switch (affixCode)
        {
            case HLBG_AFFIX_GENTLE_BREEZE:
            case HLBG_AFFIX_HEAVY_RAIN:
                return 1u;
            case HLBG_AFFIX_FOG:
                return 2u;
            case HLBG_AFFIX_STORM:
                return 3u;
            default:
                return 0u;
        }
    }

    inline float GetDefaultAffixWeatherIntensity(uint8 affixCode)
    {
        switch (affixCode)
        {
            case HLBG_AFFIX_SUNLIGHT:
                return 0.35f;
            case HLBG_AFFIX_CLEAR_SKIES:
                return 0.20f;
            case HLBG_AFFIX_GENTLE_BREEZE:
                return 0.30f;
            case HLBG_AFFIX_STORM:
                return 0.60f;
            case HLBG_AFFIX_HEAVY_RAIN:
                return 0.80f;
            case HLBG_AFFIX_FOG:
                return 0.40f;
            default:
                return 0.50f;
        }
    }

    // -------------------------------------------------------------------------
    // Affix Names
    // -------------------------------------------------------------------------
    inline const char* GetAffixName(uint8 affixCode)
    {
        char const* name = DarkChaos::CrossSystem::Affixes::GetName(
            DarkChaos::CrossSystem::SystemId::HLBG, affixCode);
        return (name && name[0]) ? name : "None";
    }

    // Legacy affix name mapping (for backward compatibility — same display name).
    inline const char* GetLegacyAffixName(uint8 affixCode)
    {
        return GetAffixName(affixCode);
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
