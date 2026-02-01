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

#ifndef AC_PARTITION_RELOCATION_TXN_H
#define AC_PARTITION_RELOCATION_TXN_H

#include "Define.h"
#include "ObjectGuid.h"

enum class RelocationState : uint8
{
    PENDING = 0,     // Relocation started but not yet validated
    LOCKED = 1,      // Object locked in source partition
    VALIDATED = 2,   // Position validated in target partition
    COMMITTED = 3,   // Relocation complete
    ROLLED_BACK = 4  // Relocation failed and rolled back
};

struct PartitionRelocationTxn
{
    ObjectGuid::LowType guidLow = 0;
    uint32 mapId = 0;
    uint32 fromPartition = 0;
    uint32 toPartition = 0;
    RelocationState state = RelocationState::PENDING;
    uint64 startTimeMs = 0;      // When relocation began
    uint64 lockTimeMs = 0;       // When object was locked
    uint64 timeoutMs = 500;      // Max duration before auto-rollback
    float startX = 0.0f;         // Position when relocation started
    float startY = 0.0f;
    float startZ = 0.0f;
};

#endif // AC_PARTITION_RELOCATION_TXN_H
