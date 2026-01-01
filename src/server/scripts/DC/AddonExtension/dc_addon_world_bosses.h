#pragma once

#include <cstdint>
#include <cstddef>

namespace DCAddon
{
namespace WorldBosses
{
    struct BossDef
    {
        uint32_t entry;
        int32_t spawnId;
        char const* id;
        char const* name;
        char const* zone;
    };

    // Giant Isles DB spawn ids: Thok=9000189, Oondasta=9000190, Nalak=9000191.
    inline constexpr BossDef GIANT_ISLES_BOSSES[] =
    {
        { 400100, 9000190, "oondasta", "Oondasta, King of Dinosaurs", "Devilsaur Gorge" },
        { 400101, 9000189, "thok",     "Thok the Bloodthirsty",     "Raptor Ridge" },
        { 400102, 9000191, "nalak",    "Nalak the Storm Lord",      "Thundering Peaks" },
    };

    inline constexpr size_t GIANT_ISLES_BOSSES_COUNT = sizeof(GIANT_ISLES_BOSSES) / sizeof(GIANT_ISLES_BOSSES[0]);

} // namespace WorldBosses
} // namespace DCAddon
