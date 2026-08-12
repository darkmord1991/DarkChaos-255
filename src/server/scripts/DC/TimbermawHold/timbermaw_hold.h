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

// Timbermaw Hold (map 819) -- shared definitions for the instance script and the seven
// encounter scripts.

#ifndef DEF_TIMBERMAW_HOLD_H
#define DEF_TIMBERMAW_HOLD_H

#include "CreatureAIImpl.h"

#define TimbermawHoldScriptName "instance_timbermaw_hold"
#define TMBHDataHeader "TMBH"

uint32 const TimbermawEncounterCount = 7;
uint32 const MapTimbermawHold = 819;

// 0-indexed and in DungeonEncounter.dbc order (rows 1100-1106). The M+ boss counter, the
// final-boss loot path and the HUD all read that ordering, so it must not drift.
enum TMBHDataTypes
{
    DATA_GATEWARDEN     = 0,
    DATA_CHIEFTAIN      = 1,
    DATA_DEN_MOTHER     = 2,
    DATA_XANTHIR        = 3,
    DATA_NIGHTMARE_ROOT = 4,
    DATA_URSOL          = 5,
    DATA_URSOC          = 6
};

enum TMBHCreatureIds
{
    NPC_GATEWARDEN     = 4010001,
    NPC_CHIEFTAIN      = 4010002,
    NPC_DEN_MOTHER     = 4010003,
    NPC_XANTHIR        = 4010004,
    NPC_NIGHTMARE_ROOT = 4010005,
    NPC_URSOL          = 4010006,
    NPC_URSOC          = 4010007
};

template <class AI, class T>
inline AI* GetTimbermawHoldAI(T* obj)
{
    return GetInstanceAI<AI>(obj, TimbermawHoldScriptName);
}

#define RegisterTimbermawHoldCreatureAI(ai_name) RegisterCreatureAIWithFactory(ai_name, GetTimbermawHoldAI)

#endif // DEF_TIMBERMAW_HOLD_H
