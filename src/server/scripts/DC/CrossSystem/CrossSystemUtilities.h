/*
 * DarkChaos-255 Shared Utilities
 * ==============================
 *
 * Common utility functions shared across DC scripts.
 * Include this header where these utilities are needed.
 *
 * Copyright (C) 2025 DarkChaos Development Team
 */

#ifndef DC_UTILITIES_H
#define DC_UTILITIES_H

#include <string>
#include <string_view>
#include <sstream>

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
     * For building JSON strings safely
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

    /**
     * Get quality name string from item quality enum
     */
    inline const char* GetQualityName(uint32 quality)
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
    inline const char* GetQualityColor(uint32 quality)
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

} // namespace DCUtils

// Canonical namespace alias
namespace DarkChaos
{
namespace CrossSystem
{
    namespace Utils = ::DCUtils;
}
}

#endif // DC_UTILITIES_H
