#pragma once
#include "Position.h"
#include <string>

// Note: this header expects to be included after engine headers that define
// `Position`, `uint8`, etc. It's placed in the same namespace as the AI.
namespace DC_AC_Flight
{
// Scenic route data for Azshara Crater
// Definition moved to ac_flightmasters_data.cpp to keep header lightweight
extern Position const kPath[];
extern const uint8 kPathLength;
extern const uint8 kIndex_startcamp;
uint8 LastScenicIndex();
extern const uint8 kIndex_acfm15;
extern const uint8 kIndex_acfm19;
extern const uint8 kIndex_acfm35;
extern const uint8 kIndex_acfm40;
extern const uint8 kIndex_acfm57;

std::string NodeLabel(uint8 idx);

} // namespace DC_AC_Flight
