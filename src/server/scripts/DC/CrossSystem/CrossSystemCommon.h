/*
 * DarkChaos-255 Common Leaf Utilities
 * ===================================
 *
 * Dependency-free helpers shared across the whole DC tree: string/JSON escaping,
 * no-throw numeric parsing, quality naming, formatting and small math.
 *
 * LAYERING CONTRACT: this header must not include any DC subsystem header, and
 * must not depend on Player/Item/Map or any game entity. It is the bottom layer
 * every DC subsystem may include without creating a dependency cycle. Anything
 * that needs a game entity or another subsystem belongs one layer up, in
 * CrossSystemUtilities.h (currency) or the orchestration components
 * (RewardDistributor, WorldBossMgr, EventBus).
 *
 * Included by CrossSystemUtilities.h, so existing `DCUtils::` callers keep
 * working unchanged; include this header directly when you only need the leaf
 * helpers and want to avoid pulling in ItemUpgrades/Player.
 *
 * Copyright (C) 2025 DarkChaos Development Team
 */

#ifndef DC_CROSSSYSTEM_COMMON_H
#define DC_CROSSSYSTEM_COMMON_H

#include <algorithm>
#include <bit>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <string>
#include <string_view>
#include <sstream>
#include <ctime>
#include <vector>
#include "Define.h"
#include "Timer.h"

namespace DCUtils
{
    /**
     * Escape braces for fmt library compatibility
     * Replaces { with {{ and } with }}
     */
    inline std::string EscapeFmtBraces(std::string_view input)
    {
        std::string result;
        result.reserve(input.size());

        for (char c : input)
        {
            if (c == '{')
                result += "{{";
            else if (c == '}')
                result += "}}";
            else
                result += c;
        }

        return result;
    }

    /**
     * Escape JSON special characters
     * For building JSON strings safely.
     *
     * CANONICAL IMPLEMENTATION -- do not re-roll this per subsystem. Divergent
     * copies are how a framing bug ends up fixed in one addon module and live in
     * the other five.
     */
    inline std::string EscapeJson(std::string_view input)
    {
        std::string escaped;
        escaped.reserve(input.size());

        for (char c : input)
        {
            switch (c)
            {
                case '"':  escaped += "\\\""; break;
                case '\\': escaped += "\\\\"; break;
                case '\n': escaped += "\\n"; break;
                case '\r': escaped += "\\r"; break;
                case '\t': escaped += "\\t"; break;
                default:
                    if (static_cast<unsigned char>(c) < 0x20)
                    {
                        escaped += "\\u";
                        constexpr char hex[] = "0123456789ABCDEF";
                        uint8_t uc = static_cast<uint8_t>(c);
                        escaped.push_back(hex[(uc >> 4) & 0xF]);
                        escaped.push_back(hex[uc & 0xF]);
                    }
                    else
                    {
                        escaped.push_back(c);
                    }
                    break;
            }
        }

        return escaped;
    }

    // =========================================================================
    // No-throw numeric parsing
    //
    // std::stoul/std::stof throw on malformed OR out-of-range input. Thrown from
    // a command handler, a config loader or a DB-row loop, that exception has no
    // catch between it and WorldSession::Update / world startup, so it takes the
    // realm down. Use these instead: they report failure and leave `out` alone.
    // =========================================================================

    /// Parse an unsigned decimal integer. Rejects empty, non-digit and >64-bit values.
    inline bool TryParseUInt64(std::string_view input, uint64& out)
    {
        if (input.empty())
            return false;

        uint64 parsed = 0;
        for (unsigned char ch : input)
        {
            if (!std::isdigit(ch))
                return false;

            uint64 digit = uint64(ch - '0');
            if (parsed > (UINT64_MAX - digit) / 10)
                return false; // would overflow

            parsed = parsed * 10 + digit;
        }

        out = parsed;
        return true;
    }

    /// Parse an unsigned decimal integer that must fit in 32 bits.
    inline bool TryParseUInt32(std::string_view input, uint32& out)
    {
        uint64 parsed = 0;
        if (!TryParseUInt64(input, parsed) || parsed > 0xFFFFFFFFull)
            return false;

        out = static_cast<uint32>(parsed);
        return true;
    }

    /// Parse a floating point value. Rejects trailing garbage, NaN and infinities.
    inline bool TryParseFloat(std::string const& input, float& out)
    {
        if (input.empty())
            return false;

        try
        {
            size_t consumed = 0;
            float parsed = std::stof(input, &consumed);

            if (consumed != input.size())
                return false; // trailing garbage
            if (!std::isfinite(parsed))
                return false;

            out = parsed;
            return true;
        }
        catch (...)
        {
            return false;
        }
    }

    /// Parse with a fallback -- convenience for config loads that must not fail hard.
    inline uint32 ParseUInt32Or(std::string_view input, uint32 fallback)
    {
        uint32 parsed = 0;
        return TryParseUInt32(input, parsed) ? parsed : fallback;
    }

    inline float ParseFloatOr(std::string const& input, float fallback)
    {
        float parsed = 0.0f;
        return TryParseFloat(input, parsed) ? parsed : fallback;
    }

    /**
     * Get quality name string from item quality enum
     */
    inline char const* GetQualityName(uint32 quality)
    {
        switch (quality)
        {
            case 0: return "Poor";
            case 1: return "Common";
            case 2: return "Uncommon";
            case 3: return "Rare";
            case 4: return "Epic";
            case 5: return "Legendary";
            case 6: return "Artifact";
            case 7: return "Heirloom";
            default: return "Unknown";
        }
    }

    /**
     * Get quality color code for chat messages
     */
    inline char const* GetQualityColor(uint32 quality)
    {
        switch (quality)
        {
            case 0: return "|cff9d9d9d"; // Poor (gray)
            case 1: return "|cffffffff"; // Common (white)
            case 2: return "|cff1eff00"; // Uncommon (green)
            case 3: return "|cff0070dd"; // Rare (blue)
            case 4: return "|cffa335ee"; // Epic (purple)
            case 5: return "|cffff8000"; // Legendary (orange)
            case 6: return "|cffe6cc80"; // Artifact (gold)
            case 7: return "|cffe6cc80"; // Heirloom (gold)
            default: return "|cffffffff";
        }
    }

    /**
     * Format copper amount as gold/silver/copper string
     */
    inline std::string FormatCoins(uint32 copper)
    {
        uint32 gold = copper / 10000;
        uint32 silver = (copper % 10000) / 100;
        uint32 cop = copper % 100;

        std::ostringstream ss;
        if (gold > 0)
            ss << gold << "g ";
        if (silver > 0 || gold > 0)
            ss << silver << "s ";
        ss << cop << "c";

        return ss.str();
    }

    /**
     * Format a timestamp as local time using a strftime pattern.
     * Thread-safe (wraps Acore::Time::TimeBreakdown). Pass when=0 for "now".
     */
    inline std::string FormatLocalTimestamp(time_t when = 0, char const* fmt = "%Y-%m-%d %H:%M:%S")
    {
        std::tm tmv = Acore::Time::TimeBreakdown(when);
        char buf[64];
        std::strftime(buf, sizeof(buf), fmt, &tmv);
        return std::string(buf);
    }

    /**
     * Format copper amount as a verbose gold/silver/copper string ("1 Gold 2 Silver 3 Copper").
     * Use FormatCoins (abbreviated "g/s/c") for compact display.
     */
    inline std::string FormatCoinsVerbose(uint64 copper)
    {
        uint64 gold   = copper / 10000;
        uint64 silver = (copper % 10000) / 100;
        uint64 cop    = copper % 100;
        std::ostringstream ss;
        if (gold > 0) ss << gold << " Gold ";
        if (silver > 0) ss << silver << " Silver ";
        ss << cop << " Copper";
        return ss.str();
    }

    /**
     * Build a gossip-menu line with a 40x40 inline icon (WoW 3.3.5 texture-escape).
     * Encodes the shared "|T<icon>:40:40:-18|t <text>" convention used by guard/flight
     * NPCs across the DC tree.
     */
    inline std::string MakeLargeGossipText(std::string const& icon, std::string const& text)
    {
        return "|T" + icon + ":40:40:-18|t " + text;
    }

    /**
     * Clamp a value between min and max
     */
    template<typename T>
    inline T Clamp(T value, T minVal, T maxVal)
    {
        return (value < minVal) ? minVal : ((value > maxVal) ? maxVal : value);
    }

    /**
     * Safe integer division (returns 0 if divisor is 0)
     */
    template<typename T>
    inline T SafeDiv(T dividend, T divisor)
    {
        return (divisor != 0) ? (dividend / divisor) : T(0);
    }

    /**
     * Calculate percentage (returns 0 if total is 0)
     */
    inline float SafePercent(uint32 part, uint32 total)
    {
        return (total > 0) ? (static_cast<float>(part) / static_cast<float>(total)) * 100.0f : 0.0f;
    }

    // Returns the number of set bits in a 32-bit value (C++20 std::popcount).
    inline uint32_t PopCount32(uint32_t value)
    {
        return std::popcount(value);
    }

    // Return a copy of s with all ASCII characters lowercased.
    inline std::string ToLower(std::string s)
    {
        std::transform(s.begin(), s.end(), s.begin(),
            [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        return s;
    }

    // Return a copy of s with all ASCII characters uppercased.
    inline std::string ToUpper(std::string s)
    {
        std::transform(s.begin(), s.end(), s.begin(),
            [](unsigned char c) { return static_cast<char>(std::toupper(c)); });
        return s;
    }

    // Join a list of strings with a separator.
    inline std::string JoinStringList(std::vector<std::string> const& values, char const* separator = ", ")
    {
        std::ostringstream ss;
        for (size_t i = 0; i < values.size(); ++i)
        {
            if (i > 0)
                ss << separator;
            ss << values[i];
        }
        return ss.str();
    }

    // Parse a comma-separated list of uint32 values from a string_view.
    // Keeps id 0 (general-purpose; callers that treat 0 as invalid must filter themselves).
    // Malformed and out-of-range entries are skipped.
    inline std::vector<uint32_t> ParseUInt32List(std::string_view input)
    {
        std::vector<uint32_t> result;
        std::string src{input};
        std::istringstream ss{src};
        std::string token;
        while (std::getline(ss, token, ','))
        {
            size_t start = token.find_first_not_of(" \t");
            if (start == std::string::npos) continue;
            size_t end = token.find_last_not_of(" \t");
            token = token.substr(start, end - start + 1);
            if (token.empty()) continue;

            uint32 parsed = 0;
            if (TryParseUInt32(token, parsed))
                result.push_back(parsed);
        }
        return result;
    }

} // namespace DCUtils

// Canonical namespace alias
namespace DarkChaos
{
namespace CrossSystem
{
    namespace Utils = ::DCUtils;
}
}

#endif // DC_CROSSSYSTEM_COMMON_H
