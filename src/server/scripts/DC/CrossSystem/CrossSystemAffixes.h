/*
 * DarkChaos Cross-System Affix Registry
 *
 * Shared metadata registry for affix-capable systems.
 * Keeps names, descriptions, and normalized lookup rules in one place while
 * leaving effect execution inside each owning system.
 */

#pragma once

#include "DC/CrossSystem/CrossSystemCore.h"
#include <string>
#include <string_view>

namespace DarkChaos
{
namespace CrossSystem
{
namespace Affixes
{
    struct AffixDefinition
    {
        SystemId systemId = SystemId::None;
        uint32 affixId = 0;
        char const* token = "";
        char const* name = "Unknown Affix";
        char const* legacyName = nullptr;
        char const* description = "";
    };

    std::string NormalizeToken(std::string_view value);
    AffixDefinition const* GetDefinition(SystemId systemId, uint32 affixId);
    AffixDefinition const* FindDefinitionByName(SystemId systemId, std::string_view name);
    char const* GetName(SystemId systemId, uint32 affixId);
    char const* GetLegacyName(SystemId systemId, uint32 affixId);
    char const* GetDescription(SystemId systemId, uint32 affixId);
}
}
}