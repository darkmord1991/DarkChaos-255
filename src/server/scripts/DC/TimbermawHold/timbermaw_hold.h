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

// Timbermaw Hold (map 819) -- shared definitions for the instance script and the encounters.
//
// The raid is Turtle WoW's own design, ported from tortoise-wow's world data
// (Custom/TimbermawHold/tortoise_port). Turtle shipped the creatures, spawns, patrols, loot and
// quests but no AI at all, so every encounter below is written here.

#ifndef DEF_TIMBERMAW_HOLD_H
#define DEF_TIMBERMAW_HOLD_H

#include "CreatureAIImpl.h"
#include "Unit.h"
#include <algorithm>

#define TimbermawHoldScriptName "instance_timbermaw_hold"
#define TMBHDataHeader "TMBH"

uint32 const TimbermawEncounterCount = 9;
uint32 const MapTimbermawHold = 819;

// 0-indexed, and the same order as the DungeonEncounter.dbc bits for map 819 (rows 1100-1108,
// 1218-1224 + 1115-1116, 1225-1231 + 1117-1118). The M+ boss counter, the boss tracker and the
// final-boss loot path all read that ordering, so it must not drift.
enum TMBHDataTypes
{
    DATA_KARRSH         = 0,
    DATA_ROTGROWL       = 1,    // Rotgrowl and Kodiak, one encounter
    DATA_LOKTANAG       = 2,
    DATA_ORMANOS        = 3,
    DATA_PARTATH        = 4,
    DATA_KRONN          = 5,
    DATA_SELENAXX       = 6,    // Selenaxx and the Corrupted Draenethyst Geode
    DATA_TRIOCH         = 7,
    DATA_URSOL          = 8,

    // ObjectData keys that are not encounters
    DATA_KODIAK         = 20,
    DATA_GEODE,
    DATA_BARRIER_OF_URSOL,
    DATA_BRAZIER_OF_CORRUPTION,
    DATA_BRAZIER_OF_DEFILEMENT,
    DATA_BRAZIER_OF_DECAY,
    DATA_BRAZIER_OF_PUTRIFICATION
};

enum TMBHCreatureIds
{
    NPC_KARRSH                  = 4010001,
    NPC_ROTGROWL                = 4010002,
    NPC_KODIAK                  = 4010003,
    NPC_ORMANOS                 = 4010004,
    NPC_LOKTANAG                = 4010005,
    NPC_SELENAXX                = 4010006,
    NPC_URSOL                   = 4010007,  // kept on 4010007: Achievement_Criteria 13511 points here
    NPC_DRAENETHYST_GEODE       = 4010008,
    NPC_KRONN                   = 4010009,
    NPC_TRIOCH                  = 4010010,
    NPC_PARTATH                 = 4010011,
    NPC_WITHERMAW_SHADOWKEEPER  = 4010013,
    NPC_FOULHEART_WARLOCK       = 4010014,
    NPC_CORRUPTION_OF_LOKTANAG  = 4010111,
    NPC_TWISTED_RUMBLER         = 4010112,
    NPC_SON_OF_URSOL            = 4010117,
    NPC_WITHERMAW_ILLUMINATOR   = 4010118
};

enum TMBHGameObjectIds
{
    GO_BRAZIER_OF_CORRUPTION        = 4010001,  // Karrsh
    GO_BRAZIER_OF_DEFILEMENT        = 4010002,  // Rotgrowl and Kodiak
    GO_BRAZIER_OF_DECAY             = 4010003,  // Kronn
    GO_BRAZIER_OF_PUTRIFICATION     = 4010004,  // Partath
    GO_BARRIER_OF_URSOL             = 4010005
};

// The four guardians whose braziers seal the Barrier of Ursol. All four down opens the way to Ursol;
// the other four encounters are optional, as in Turtle's layout.
uint32 const TimbermawBrazierGuardians[4] = { DATA_KARRSH, DATA_ROTGROWL, DATA_KRONN, DATA_PARTATH };

// Turtle authored every ability as a fixed level-60 number. Here every fixed-damage spell is cast
// with its base points set to a fraction of the caster's own melee swing, read from the final
// damage fields (DamageModifier, rank and auras all applied). Retuning a creature's DamageModifier
// therefore retunes its spells too, and an enrage or a Mythic damage aura lifts both together.
inline int32 TimbermawScaledDamage(Unit const* caster, float fractionOfMelee)
{
    float const average =
        (caster->GetFloatValue(UNIT_FIELD_MINDAMAGE) + caster->GetFloatValue(UNIT_FIELD_MAXDAMAGE)) * 0.5f;
    return std::max<int32>(1, int32(average * fractionOfMelee));
}

template <class AI, class T>
inline AI* GetTimbermawHoldAI(T* obj)
{
    return GetInstanceAI<AI>(obj, TimbermawHoldScriptName);
}

#define RegisterTimbermawHoldCreatureAI(ai_name) RegisterCreatureAIWithFactory(ai_name, GetTimbermawHoldAI)

#endif // DEF_TIMBERMAW_HOLD_H
