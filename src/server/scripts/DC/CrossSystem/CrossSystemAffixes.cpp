/*
 * DarkChaos Cross-System Affix Registry Implementation
 */

#include "CrossSystemAffixes.h"

#include <array>
#include <cctype>

namespace DarkChaos
{
namespace CrossSystem
{
namespace Affixes
{
namespace
{
    using DefinitionArray = std::array<AffixDefinition, 14>;

    DefinitionArray const kDefinitions =
    {{
        { SystemId::MythicPlus, 1, "bolster", "Bolstering", nullptr,
            "When any non-boss enemy dies, its death cry empowers nearby allies, increasing their maximum health and damage by 20%." },
        { SystemId::MythicPlus, 2, "necrotic", "Necrotic", nullptr,
            "All enemies' melee attacks apply a stacking healing reduction effect." },
        { SystemId::MythicPlus, 3, "grievous", "Grievous", nullptr,
            "Players below 90% health take periodic damage until healed above the threshold." },
        { SystemId::MythicPlus, 4, "tyrannical", "Tyrannical", nullptr,
            "Boss enemies have 40% more health and inflict 15% more damage." },
        { SystemId::MythicPlus, 5, "fortified", "Fortified", nullptr,
            "Non-boss enemies have 20% more health and inflict 30% more damage." },
        { SystemId::MythicPlus, 6, "raging", "Raging", nullptr,
            "Enemies deal more damage at low health." },
        { SystemId::MythicPlus, 7, "sanguine", "Sanguine", nullptr,
            "Enemies leave behind a sanguine zone on death." },
        { SystemId::MythicPlus, 8, "volcanic", "Volcanic", nullptr,
            "Volcanic plumes erupt under players who stay at range." },
        { SystemId::HLBG, 1, "sunlight", "Sunlight", "Haste",
            "Clear weather empowers players with 10% haste." },
        { SystemId::HLBG, 2, "clearskies", "Clear Skies", "Slow",
            "Bright skies empower players with increased damage." },
        { SystemId::HLBG, 3, "gentlebreeze", "Gentle Breeze", "Reduced Healing",
            "A light rain increases healing received for players in the battleground." },
        { SystemId::HLBG, 4, "storm", "Storm", "Reduced Armor",
            "A violent storm empowers battleground NPCs with increased damage." },
        { SystemId::HLBG, 5, "heavyrain", "Heavy Rain", "Boss Enrage",
            "Heavy rain hardens battleground NPCs with increased armor." },
        { SystemId::HLBG, 6, "fog", "Fog", nullptr,
            "Dense fog empowers battleground NPCs with increased evasion." }
    }};

    bool MatchesNormalizedToken(std::string const& normalizedQuery, char const* candidate)
    {
        if (!candidate || !candidate[0])
            return false;

        std::string normalizedCandidate = NormalizeToken(candidate);
        return normalizedQuery == normalizedCandidate ||
            normalizedQuery.find(normalizedCandidate) != std::string::npos;
    }
}

std::string NormalizeToken(std::string_view value)
{
    std::string normalized;
    normalized.reserve(value.size());

    for (char c : value)
    {
        unsigned char current = static_cast<unsigned char>(c);
        if (std::isalnum(current))
            normalized.push_back(static_cast<char>(std::tolower(current)));
    }

    return normalized;
}

AffixDefinition const* GetDefinition(SystemId systemId, uint32 affixId)
{
    for (AffixDefinition const& definition : kDefinitions)
    {
        if (definition.systemId == systemId && definition.affixId == affixId)
            return &definition;
    }

    return nullptr;
}

AffixDefinition const* FindDefinitionByName(SystemId systemId, std::string_view name)
{
    std::string normalizedName = NormalizeToken(name);
    if (normalizedName.empty())
        return nullptr;

    for (AffixDefinition const& definition : kDefinitions)
    {
        if (definition.systemId != systemId)
            continue;

        if (MatchesNormalizedToken(normalizedName, definition.token) ||
            MatchesNormalizedToken(normalizedName, definition.name) ||
            MatchesNormalizedToken(normalizedName, definition.legacyName))
            return &definition;
    }

    return nullptr;
}

char const* GetName(SystemId systemId, uint32 affixId)
{
    if (affixId == 0)
        return "None";

    if (AffixDefinition const* definition = GetDefinition(systemId, affixId))
        return definition->name;

    return "Unknown Affix";
}

char const* GetLegacyName(SystemId systemId, uint32 affixId)
{
    if (affixId == 0)
        return "None";

    if (AffixDefinition const* definition = GetDefinition(systemId, affixId))
    {
        if (definition->legacyName && definition->legacyName[0])
            return definition->legacyName;

        return definition->name;
    }

    return "Unknown Affix";
}

char const* GetDescription(SystemId systemId, uint32 affixId)
{
    if (affixId == 0)
        return "No affix active.";

    if (AffixDefinition const* definition = GetDefinition(systemId, affixId))
        return definition->description;

    return "Unknown affix description.";
}
}
}
}