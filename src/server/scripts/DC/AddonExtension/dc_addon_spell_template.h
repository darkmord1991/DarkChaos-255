/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * dc_addon_spell_template.h - formatting primitives for the spell-description
 * template renderer.
 *
 * These nine helpers were `static` inside dc_addon_qos.cpp, which made them
 * unreachable from any other translation unit. The `.stresstest` GM command
 * needs exactly this logic to validate rendered tooltips, so it had grown a
 * near-identical private copy of each one, suffixed `ForStress`. The command
 * was therefore testing its own copies rather than the code that ships - a
 * divergence that could not be caught by either side failing, and the two
 * copies of HasUnresolvedTemplateTokens had already drifted in formatting.
 *
 * Hoisting them here lets both callers share one definition. dc_addon_qos.cpp
 * pulls them into DCQoS with using-declarations so its existing call sites are
 * untouched; the stress harness calls them qualified, so it is visible at the
 * call site that it is exercising production code.
 *
 * Header-only, following dc_addon_utils.h: no loader or CMake wiring needed.
 * Pure functions - no globals, no DB, no Player state - so they are safe to
 * call from any thread.
 */

#ifndef DC_ADDON_SPELL_TEMPLATE_H
#define DC_ADDON_SPELL_TEMPLATE_H

#include "Define.h"
#include "SharedDefines.h"

#include <cctype>
#include <cmath>
#include <cstddef>
#include <iomanip>
#include <sstream>
#include <string>

namespace DCAddon
{
namespace SpellTemplate
{
    // "1.5 sec" / "3 sec" - one decimal only when the value is not whole.
    inline std::string FormatSpellSeconds(uint32 milliseconds)
    {
        std::ostringstream out;
        out << std::fixed << std::setprecision((milliseconds % 1000) != 0 ? 1 : 0)
            << (static_cast<double>(milliseconds) / 1000.0)
            << " sec";
        return out.str();
    }

    inline std::string GetPowerTypeLabel(uint32 powerType)
    {
        switch (powerType)
        {
            case POWER_MANA: return "Mana";
            case POWER_RAGE: return "Rage";
            case POWER_FOCUS: return "Focus";
            case POWER_ENERGY: return "Energy";
            case POWER_HAPPINESS: return "Happiness";
            case POWER_RUNE: return "Rune";
            case POWER_RUNIC_POWER: return "Runic Power";
            case POWER_HEALTH: return "Health";
            default: return "Power";
        }
    }

    // Whole minutes and whole seconds render as such; anything else falls back
    // to the fractional-second form.
    inline std::string FormatDurationTemplate(uint32 milliseconds)
    {
        if (milliseconds == 0)
            return "0 sec";

        if (milliseconds % 60000 == 0)
        {
            uint32 minutes = milliseconds / 60000;
            return std::to_string(minutes) + " min";
        }

        if (milliseconds % 1000 == 0)
        {
            uint32 seconds = milliseconds / 1000;
            return std::to_string(seconds) + " sec";
        }

        return FormatSpellSeconds(milliseconds);
    }

    inline std::string TrimTemplateText(std::string value)
    {
        auto isSpace = [](unsigned char c) { return std::isspace(c) != 0; };

        while (!value.empty() && isSpace(static_cast<unsigned char>(value.front())))
            value.erase(value.begin());
        while (!value.empty() && isSpace(static_cast<unsigned char>(value.back())))
            value.pop_back();

        return value;
    }

    // Strict: the whole trimmed string must be consumed.
    inline bool TryParseStrictDouble(std::string const& text, double& out)
    {
        std::string trimmed = TrimTemplateText(text);
        if (trimmed.empty())
            return false;

        try
        {
            std::size_t index = 0;
            out = std::stod(trimmed, &index);
            return index == trimmed.size();
        }
        catch (...)
        {
            return false;
        }
    }

    // Lenient: a numeric prefix is enough ("50 yards" -> 50).
    inline bool TryParseLeadingDouble(std::string const& text, double& out)
    {
        std::string trimmed = TrimTemplateText(text);
        if (trimmed.empty())
            return false;

        try
        {
            std::size_t index = 0;
            out = std::stod(trimmed, &index);
            return index > 0;
        }
        catch (...)
        {
            return false;
        }
    }

    // Whole numbers lose the decimal point; fractions keep at most 2 places
    // with trailing zeroes stripped.
    inline std::string FormatTemplateNumericValue(double value)
    {
        double rounded = std::round(value);
        if (std::fabs(value - rounded) < 0.0001)
            return std::to_string(static_cast<int64>(rounded));

        std::ostringstream out;
        out << std::fixed << std::setprecision(2) << value;

        std::string text = out.str();
        while (!text.empty() && text.back() == '0')
            text.pop_back();
        if (!text.empty() && text.back() == '.')
            text.pop_back();

        return text.empty() ? "0" : text;
    }

    // True if a rendered tooltip still contains an unexpanded $-token, i.e. the
    // template referenced something the renderer could not resolve. Used by both
    // the live renderer and the .stresstest validator.
    inline bool HasUnresolvedTemplateTokens(std::string const& text)
    {
        for (std::size_t i = 0; i + 1 < text.size(); ++i)
        {
            if (text[i] != '$')
                continue;

            char token = text[i + 1];
            if (token == '$')
            {
                ++i;
                continue;
            }

            if (token == '{' || token == 'l'
                || std::isdigit(static_cast<unsigned char>(token)))
            {
                return true;
            }

            if (std::isalpha(static_cast<unsigned char>(token)))
            {
                if (i + 2 < text.size())
                {
                    char next = text[i + 2];
                    if (std::isalpha(static_cast<unsigned char>(next))
                        || std::isdigit(static_cast<unsigned char>(next)))
                    {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    // Scans backwards for the last parseable number in a rendered tooltip.
    // Returns 2.0 when there is none - the historical default, kept so callers
    // that treat the result as a multiplier still behave the same.
    inline double ExtractLastTemplateQuantity(std::string const& renderedText)
    {
        for (std::size_t pos = renderedText.size(); pos > 0; --pos)
        {
            if (!std::isdigit(static_cast<unsigned char>(renderedText[pos - 1])))
                continue;

            std::size_t end = pos;
            std::size_t start = pos - 1;
            while (start > 0)
            {
                char c = renderedText[start - 1];
                if (std::isdigit(static_cast<unsigned char>(c))
                    || c == '.' || c == '-' || c == '+')
                {
                    --start;
                }
                else
                {
                    break;
                }
            }

            double value = 0.0;
            if (TryParseStrictDouble(renderedText.substr(start, end - start),
                                     value))
            {
                return value;
            }
        }

        return 2.0;
    }
}
}

#endif // DC_ADDON_SPELL_TEMPLATE_H
