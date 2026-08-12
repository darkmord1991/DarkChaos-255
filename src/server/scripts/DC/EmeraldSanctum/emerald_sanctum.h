/*
 * This file is part of the AzerothCore Project. See AUTHORS file for
 * Copyright information.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Emerald Sanctum (map 824) -- shared definitions for the instance and encounter scripts.

#ifndef DEF_EMERALD_SANCTUM_H
#define DEF_EMERALD_SANCTUM_H

#include "CreatureAIImpl.h"

#define EmeraldSanctumScriptName "instance_emerald_sanctum"
#define EMSADataHeader "EMSA"

uint32 const EmeraldSanctumEncounterCount = 2;
uint32 const MapEmeraldSanctum = 824;

// Only two encounters: the four Wakeners SHARE DungeonEncounter 1121, so the boss count reads
// 2 whichever one the week rolled.
enum EMSADataTypes
{
    DATA_ERENNIUS = 0,
    DATA_WAKENER  = 1
};

enum EMSACreatureIds
{
    NPC_ERENNIUS = 4030001,
    NPC_YSONDRE  = 4030002,
    NPC_LETHON   = 4030003,
    NPC_EMERISS  = 4030004,
    NPC_TAERAR   = 4030005
};

// Parent pool holds the four Wakener child pools at max_limit 1. Children carry a pool_pool
// row, so PoolMgr skips them at auto-spawn time and the instance script chooses.
uint32 const POOL_WAKENER_PARENT = 300009;
uint32 const POOL_WAKENER_FIRST  = 300010;
uint32 const WAKENER_COUNT       = 4;

template <class AI, class T>
inline AI* GetEmeraldSanctumAI(T* obj)
{
    return GetInstanceAI<AI>(obj, EmeraldSanctumScriptName);
}

#define RegisterEmeraldSanctumCreatureAI(ai_name) RegisterCreatureAIWithFactory(ai_name, GetEmeraldSanctumAI)

#endif // DEF_EMERALD_SANCTUM_H
