/*
 * DarkChaos Leaderboard Utilities
 *
 * Shared leaderboard structures and helpers to reduce code duplication
 * across dc_addon_leaderboards.cpp, dc_addon_hlbg.cpp, etc.
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#ifndef DC_LEADERBOARD_UTILS_H
#define DC_LEADERBOARD_UTILS_H

#include "DC/CrossSystem/CrossSystemUtilities.h"
#include <string>
#include <vector>
#include <cstdint>

namespace DarkChaos
{
namespace Leaderboard
{

// =============================================================================
// Unified Leaderboard Entry Structure
// =============================================================================

struct Entry
{
    uint32_t rank = 0;
    std::string name;
    std::string className;
    uint32_t score = 0;
    std::string extra;               // Additional info (runs, time, etc.)
    std::string score_str;           // For uint64 values sent as string (gold)

    // Extended fields for specific leaderboard types
    uint32_t mapId = 0;              // M+ dungeon map ID

    // Wins/Losses (HLBG seasonal)
    bool hasWinsLosses = false;
    uint32_t wins = 0;
    uint32_t losses = 0;

    // Kill/Death stats (HLBG all-time)
    bool hasKD = false;
    uint32_t kills = 0;
    uint32_t deaths = 0;
    double kdRatio = 0.0;

    // Quality breakdown (AOE Loot)
    bool hasQuality = false;
    uint32_t qLeg = 0;
    uint32_t qEpic = 0;
    uint32_t qRare = 0;
    uint32_t qUncommon = 0;
};

// =============================================================================
// Class Name Helper
// =============================================================================

inline std::string GetClassNameFromId(uint8_t classId)
{
    switch (classId)
    {
        case 1:  return "WARRIOR";
        case 2:  return "PALADIN";
        case 3:  return "HUNTER";
        case 4:  return "ROGUE";
        case 5:  return "PRIEST";
        case 6:  return "DEATHKNIGHT";
        case 7:  return "SHAMAN";
        case 8:  return "MAGE";
        case 9:  return "WARLOCK";
        case 11: return "DRUID";
        default: return "UNKNOWN";
    }
}

// =============================================================================
// JSON Escaping Helper
// =============================================================================

inline std::string JsonEscape(const std::string& input)
{
    return DCUtils::EscapeJson(input);
}

// =============================================================================
// JSON Entry Builder
// =============================================================================

inline std::string BuildEntryJson(const Entry& e)
{
    std::string json = "{";
    json += "\"rank\":" + std::to_string(e.rank) + ",";
    json += "\"name\":\"" + JsonEscape(e.name) + "\",";
    json += "\"class\":\"" + e.className + "\",";
    json += "\"score\":" + std::to_string(e.score);

    if (!e.extra.empty())
        json += ",\"extra\":\"" + JsonEscape(e.extra) + "\"";

    if (!e.score_str.empty())
        json += ",\"score_str\":\"" + e.score_str + "\"";

    if (e.mapId > 0)
        json += ",\"mapId\":" + std::to_string(e.mapId);

    if (e.hasWinsLosses)
    {
        json += ",\"wins\":" + std::to_string(e.wins);
        json += ",\"losses\":" + std::to_string(e.losses);
    }

    if (e.hasKD)
    {
        json += ",\"kills\":" + std::to_string(e.kills);
        json += ",\"deaths\":" + std::to_string(e.deaths);
        char kdBuf[16];
        snprintf(kdBuf, sizeof(kdBuf), "%.2f", e.kdRatio);
        json += ",\"kd\":";
        json += kdBuf;
    }

    if (e.hasQuality)
    {
        json += ",\"qLeg\":" + std::to_string(e.qLeg);
        json += ",\"qEpic\":" + std::to_string(e.qEpic);
        json += ",\"qRare\":" + std::to_string(e.qRare);
        json += ",\"qUncommon\":" + std::to_string(e.qUncommon);
    }

    json += "}";
    return json;
}

inline std::string BuildEntriesJson(const std::vector<Entry>& entries)
{
    std::string json = "[";
    for (size_t i = 0; i < entries.size(); ++i)
    {
        if (i > 0) json += ",";
        json += BuildEntryJson(entries[i]);
    }
    json += "]";
    return json;
}

} // namespace Leaderboard
} // namespace DarkChaos

#endif // DC_LEADERBOARD_UTILS_H
