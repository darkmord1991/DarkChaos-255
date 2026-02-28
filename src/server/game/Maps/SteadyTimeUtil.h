/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef ACORE_STEADY_TIME_UTIL_H
#define ACORE_STEADY_TIME_UTIL_H

#include <chrono>
#include <cstdint>

/**
 * Returns the current steady clock time in milliseconds since epoch.
 * Used throughout the map/partition subsystem for latency tracking,
 * telemetry, and timeout calculations.
 */
inline uint64_t GetSteadyNowMs()
{
    return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count());
}

#endif // ACORE_STEADY_TIME_UTIL_H
