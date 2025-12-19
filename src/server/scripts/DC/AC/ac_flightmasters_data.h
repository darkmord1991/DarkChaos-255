#pragma once
#include "Position.h"
#include <string>

// Note: this header expects to be included after engine headers that define
// `Position`, `uint8`, etc.
// Scenic route data for Azshara Crater
// Definition moved to ac_flightmasters_data.cpp to keep header lightweight
extern Position const kPath[];

// Path length and startcamp index are compile-time constants so they can be used
// in constant expressions (e.g., switch case labels).
inline constexpr uint8 kPathLength = 75; // keep in sync with `kPath` entries in the .cpp
inline constexpr uint8 kIndex_startcamp = static_cast<uint8>(kPathLength - 1);
inline constexpr uint8 LastScenicIndex() { return static_cast<uint8>(kPathLength - 2); }

// Semantic, compile-time anchor indices (keep in header for constant propagation)
inline constexpr uint8 kIndex_L25_End = 38;
inline constexpr uint8 kIndex_L25_Start = 39;
inline constexpr uint8 kIndex_L40_End = 55;
inline constexpr uint8 kIndex_L40_Start = 56;
inline constexpr uint8 kIndex_L60_End = 73;

std::string NodeLabel(uint8 idx);
