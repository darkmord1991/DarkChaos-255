// -----------------------------------------------------------------------------
// hlbg_constants.h
// -----------------------------------------------------------------------------
// Centralized constants for Hinterland BG system
// Eliminates code duplication across multiple files
// -----------------------------------------------------------------------------

#ifndef HINTERLAND_BG_CONSTANTS_H
#define HINTERLAND_BG_CONSTANTS_H

// Deliberately dependency-light: this header is pulled into BattlegroundHLBG.h,
// which compiles into the game library and cannot resolve the DC include chain.
#include "Define.h"

#include <cstdint>

namespace HinterlandBGConstants
{
    // -------------------------------------------------------------------------
    // Spell IDs
    // -------------------------------------------------------------------------
    constexpr uint32 BG_DESERTER_SPELL = 26013;

    // HLBG affix auras (authored in Custom/CSV DBC/Spell.csv).
    // All six are applied to PLAYERS: an affix nobody can feel is not an affix.
    // Both teams receive the identical aura, so no side gains an edge.
    constexpr uint32 HLBG_AFFIX_SUNLIGHT_SPELL = 910010;      // +15% healing done
    constexpr uint32 HLBG_AFFIX_CLEAR_SKIES_SPELL = 910011;   // +5% damage done
    constexpr uint32 HLBG_AFFIX_GENTLE_BREEZE_SPELL = 910012; // +12% movement speed
    constexpr uint32 HLBG_AFFIX_STORM_SPELL = 910020;         // +12% damage taken
    constexpr uint32 HLBG_AFFIX_HEAVY_RAIN_SPELL = 910021;    // -12% movement speed
    constexpr uint32 HLBG_AFFIX_FOG_SPELL = 910022;           // -8yd creature aggro range

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
    // How long the scoreboard NPC reuses a rendered statistics page.
    constexpr uint32 CACHE_DURATION_MS = 5000;

    // -------------------------------------------------------------------------
    // Map/Zone IDs
    // -------------------------------------------------------------------------
    // The map id is not listed here on purpose: the battleground runs in an
    // instance, so call sites must use Battleground::GetMapId().
    constexpr uint32 HLBG_ZONE_ID = 47;
    constexpr uint32 HLBG_AREA_ID = 6738;

    enum HLBGAffixCode : uint8
    {
        HLBG_AFFIX_NONE = 0,
        // Aura affixes - apply a spell to every player on both sides.
        HLBG_AFFIX_SUNLIGHT = 1,
        HLBG_AFFIX_CLEAR_SKIES = 2,
        HLBG_AFFIX_GENTLE_BREEZE = 3,
        HLBG_AFFIX_STORM = 4,
        HLBG_AFFIX_HEAVY_RAIN = 5,
        HLBG_AFFIX_FOG = 6,
        // Rule affixes - no spell, no weather. They retune the resource
        // economy, so they change how the match is won rather than how hard
        // players hit.
        HLBG_AFFIX_WARLORDS = 7,
        HLBG_AFFIX_SKIRMISH = 8,
        HLBG_AFFIX_BLOODLUST = 9,
        // Visual affix - overrides the zone light. Reuses the Fog aura.
        HLBG_AFFIX_NIGHTFALL = 10,

        HLBG_AFFIX_LAST = HLBG_AFFIX_NIGHTFALL
    };

    // Every per-affix array in BattlegroundHLBG (_affixPlayerSpell,
    // _affixNpcSpell, _affixWeatherState, _affixWeatherIntensity) is indexed
    // directly by affix code, so adding an affix without growing this would be
    // an out-of-bounds write rather than a compile error.
    constexpr uint8 HLBG_AFFIX_STORAGE_SIZE = HLBG_AFFIX_LAST + 1;
    static_assert(HLBG_AFFIX_STORAGE_SIZE > HLBG_AFFIX_LAST,
        "affix storage must have a slot for every affix code");

    enum AllianceNpcEntries : uint32
    {
        Alliance_Healer = 600005,   // NOTE: no creature_template row exists
        Alliance_Boss = 810003,
        Alliance_Infantry = 810001,  // Hinterland Alliance guard (faction 11)
        Alliance_Squadleader = 600011,  // NOTE: no creature_template row exists
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
        Horde_Heal = 600004,   // NOTE: no creature_template row exists
        Horde_Squadleader = 600008,  // NOTE: no creature_template row exists
        Horde_Infantry = 810000,  // Revantusk Watcher (faction 1495)
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
            case HLBG_AFFIX_STORM:
                return HLBG_AFFIX_STORM_SPELL;
            case HLBG_AFFIX_HEAVY_RAIN:
                return HLBG_AFFIX_HEAVY_RAIN_SPELL;
            case HLBG_AFFIX_FOG:
            case HLBG_AFFIX_NIGHTFALL:
                return HLBG_AFFIX_FOG_SPELL;
            default:
                return 0u;
        }
    }

    // No NPC-side affix auras by default. The hook stays so a future affix can
    // buff the guard camps, but a creature-only affix is invisible to players.
    inline uint32 GetDefaultAffixNpcSpell(uint8 /*affixCode*/)
    {
        return 0u;
    }

    // Values are WeatherState (Weather.h), NOT WeatherType. The battleground
    // drives weather through Map::SetZoneWeather, which takes a state directly -
    // that is the only way to reach WEATHER_STATE_FOG, since Weather::GetWeatherState
    // can never produce it from a WeatherType. Snow/sandstorm states are
    // deliberately unused: the Hinterlands is temperate forest.
    inline uint32 GetDefaultAffixWeatherState(uint8 affixCode)
    {
        switch (affixCode)
        {
            case HLBG_AFFIX_GENTLE_BREEZE:
                return 3u;   // WEATHER_STATE_LIGHT_RAIN
            case HLBG_AFFIX_HEAVY_RAIN:
                return 5u;   // WEATHER_STATE_HEAVY_RAIN
            case HLBG_AFFIX_FOG:
                return 1u;   // WEATHER_STATE_FOG
            case HLBG_AFFIX_STORM:
                return 86u;  // WEATHER_STATE_THUNDERS
            case HLBG_AFFIX_SUNLIGHT:
            case HLBG_AFFIX_CLEAR_SKIES:
            default:
                return 0u;   // WEATHER_STATE_FINE
        }
    }

    // Density passed alongside the state. FINE must be ~0 or the client still
    // renders precipitation particles over a "clear" sky.
    inline float GetDefaultAffixWeatherIntensity(uint8 affixCode)
    {
        switch (affixCode)
        {
            case HLBG_AFFIX_SUNLIGHT:
            case HLBG_AFFIX_CLEAR_SKIES:
                return 0.0f;
            case HLBG_AFFIX_GENTLE_BREEZE:
                return 0.35f;
            case HLBG_AFFIX_FOG:
                return 0.70f;
            case HLBG_AFFIX_HEAVY_RAIN:
                return 0.85f;
            case HLBG_AFFIX_STORM:
                return 0.90f;
            default:
                // Must match the default weather state, which is FINE. A 0.5
                // density on a clear sky still draws precipitation - the rule
                // affixes (Warlords/Skirmish/Bloodlust) and Nightfall all land
                // here, and all four rendered rain over clear weather.
                return 0.0f;
        }
    }

    // -------------------------------------------------------------------------
    // Affix Names
    // -------------------------------------------------------------------------
    // Display names mirror the canonical DC::CrossSystem::Affixes registry
    // (SystemId::HLBG). Kept local because this header is compiled into the
    // game library (BattlegroundHLBG.h), which cannot resolve the CrossSystem
    // include chain. Keep in sync with CrossSystemAffixes.cpp.
    inline char const* GetAffixName(uint8 affixCode)
    {
        switch (affixCode)
        {
            case HLBG_AFFIX_SUNLIGHT:      return "Sunlight";
            case HLBG_AFFIX_CLEAR_SKIES:   return "Clear Skies";
            case HLBG_AFFIX_GENTLE_BREEZE: return "Gentle Breeze";
            case HLBG_AFFIX_STORM:         return "Storm";
            case HLBG_AFFIX_HEAVY_RAIN:    return "Heavy Rain";
            case HLBG_AFFIX_FOG:           return "Fog";
            case HLBG_AFFIX_WARLORDS:      return "Warlords";
            case HLBG_AFFIX_SKIRMISH:      return "Skirmish";
            case HLBG_AFFIX_BLOODLUST:     return "Bloodlust";
            case HLBG_AFFIX_NIGHTFALL:     return "Nightfall";
            default:                       return "None";
        }
    }

    // One-line effect summary. Used by the in-game announce and mirrored in the
    // DC-HinterlandBG addon (HLBG_Stubs.lua) - keep both in step.
    inline char const* GetAffixDescription(uint8 affixCode)
    {
        switch (affixCode)
        {
            case HLBG_AFFIX_SUNLIGHT:      return "Healing done increased by 15%.";
            case HLBG_AFFIX_CLEAR_SKIES:   return "Damage done increased by 5%.";
            case HLBG_AFFIX_GENTLE_BREEZE: return "Movement speed increased by 12%.";
            case HLBG_AFFIX_STORM:         return "Damage taken increased by 12%.";
            case HLBG_AFFIX_HEAVY_RAIN:    return "Movement speed reduced by 12%.";
            case HLBG_AFFIX_FOG:           return "Creatures notice you from 8 yards closer.";
            case HLBG_AFFIX_WARLORDS:      return "Faction bosses are worth double resources.";
            case HLBG_AFFIX_SKIRMISH:      return "Killing NPCs drains no resources - players only.";
            case HLBG_AFFIX_BLOODLUST:     return "Player kills drain double resources.";
            case HLBG_AFFIX_NIGHTFALL:     return "Night falls. Creatures notice you from 8 yards closer.";
            default:                       return "";
        }
    }

    // Affixes that would cancel or duplicate each other must never roll
    // together when Affix.ConcurrentCount > 1.
    inline bool AreAffixesCompatible(uint8 left, uint8 right)
    {
        if (!left || !right || left == right)
            return left != right;

        auto pair = [left, right](uint8 a, uint8 b)
        {
            return (left == a && right == b) || (left == b && right == a);
        };

        // Opposite movement-speed modifiers cancel out.
        if (pair(HLBG_AFFIX_GENTLE_BREEZE, HLBG_AFFIX_HEAVY_RAIN))
            return false;
        // Both are clear-sky weather; the second would be invisible.
        if (pair(HLBG_AFFIX_SUNLIGHT, HLBG_AFFIX_CLEAR_SKIES))
            return false;
        // Both apply the same detection aura.
        if (pair(HLBG_AFFIX_FOG, HLBG_AFFIX_NIGHTFALL))
            return false;
        // Contradictory NPC economy rules.
        if (pair(HLBG_AFFIX_WARLORDS, HLBG_AFFIX_SKIRMISH))
            return false;

        return true;
    }

    // -------------------------------------------------------------------------
    // Weather Names
    // -------------------------------------------------------------------------
    // Canonical weather-name lookup (values match WeatherState in Weather.h).
    // outOfRangeDefault lets call sites override the fallback text without needing
    // their own copy of the table.
    inline char const* GetWeatherName(uint32 weatherState, char const* outOfRangeDefault = "Unknown")
    {
        switch (weatherState)
        {
            case 0:   return "Clear";
            case 1:   return "Fog";
            case 3:   return "Light Rain";
            case 4:   return "Rain";
            case 5:   return "Heavy Rain";
            case 6:   return "Light Snow";
            case 7:   return "Snow";
            case 8:   return "Heavy Snow";
            case 22:  return "Light Sandstorm";
            case 41:  return "Sandstorm";
            case 42:  return "Heavy Sandstorm";
            case 86:  return "Thunderstorm";
            case 90:  return "Black Rain";
            case 106: return "Black Snow";
            default:  return outOfRangeDefault;
        }
    }

    // -------------------------------------------------------------------------
    // Team Names
    // -------------------------------------------------------------------------
    inline char const* GetTeamName(uint8 teamId)
    {
        switch (teamId)
        {
            case 0: return "Alliance";
            case 1: return "Horde";
            case 2: return "Draw";
            default: return "Unknown";
        }
    }

} // namespace HinterlandBGConstants

#endif // HINTERLAND_BG_CONSTANTS_H
