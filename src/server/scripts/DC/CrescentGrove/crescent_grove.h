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

// Crescent Grove (map 823) -- shared definitions for the instance and encounter scripts.

#ifndef DEF_CRESCENT_GROVE_H
#define DEF_CRESCENT_GROVE_H

#include "CreatureAIImpl.h"

#define CrescentGroveScriptName "instance_crescent_grove"
#define CRGVDataHeader "CRGV"

uint32 const CrescentGroveEncounterCount = 5;
uint32 const MapCrescentGrove = 823;

// 0-indexed, in DungeonEncounter.dbc order (rows 1110-1114).
enum CRGVDataTypes
{
    DATA_RANATHOS = 0,
    DATA_ENGRYSS  = 1,
    DATA_ALATHEA  = 2,
    DATA_FENEKTIS = 3,
    DATA_RAXXIETH = 4
};

enum CRGVCreatureIds
{
    NPC_RANATHOS = 4020001,
    NPC_ENGRYSS  = 4020002,
    NPC_ONE_EYE  = 4020003,
    NPC_BLACKMAW = 4020004,
    NPC_ALATHEA  = 4020005,
    NPC_FENEKTIS = 4020006,
    NPC_RAXXIETH = 4020007
};

template <class AI, class T>
inline AI* GetCrescentGroveAI(T* obj)
{
    return GetInstanceAI<AI>(obj, CrescentGroveScriptName);
}

#define RegisterCrescentGroveCreatureAI(ai_name) RegisterCreatureAIWithFactory(ai_name, GetCrescentGroveAI)

#endif // DEF_CRESCENT_GROVE_H
