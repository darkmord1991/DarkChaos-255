/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// DarkChaos downport of the Cataclysm 4.3.4 Shadowfang Keep (heroic revamp).
// Ported from CataTC; adapted to AzerothCore 3.3.5a idioms.
// TC->AC API conversion conventions: see BlackwingDescent/PORT_NOTES.md.
//
// This runs on the CLONE map 825, NOT stock map 33. Classic Shadowfang Keep on
// 33 is untouched: it keeps its own `instance_shadowfang_keep` script, its own
// `shadowfang_keep.h`, and its own SmartAI on entries 3887 / 4278. Every name
// here is therefore suffixed so the two can coexist in one binary -- the guard,
// the header filename, the instance ScriptName and the AI factory macro.

#ifndef DEF_DC_SFK_CATA_H
#define DEF_DC_SFK_CATA_H

#include "CreatureAIImpl.h"
#include "Creature.h"

namespace ShadowfangKeepCata
{
constexpr char const* DataHeader = "SKC";
#define SKCataScriptName "instance_sfk_cata"

uint32 const EncounterCount = 7;

// DC clone map. Stock Shadowfang Keep stays on 33.
uint32 const MapShadowfangKeepCata = 825;

// ---------------------------------------------------------------------------------
// Portal constants -- shared by the clickable GO and the walk-through trigger NPC
// ---------------------------------------------------------------------------------
// NOTE: there is deliberately no min-level constant here. Entry to map 825 is gated by
// dungeon_access_template (rows 158/159/160) via MapMgr::PlayerCannotEnter, which
// Player::TeleportTo already calls -- one source of truth for the level, and it produces
// the correct client-side message.

// Arrival point inside: the spot stock Shadowfang Keep teleports to, which 825 shares
// because the two maps have the same coordinate space.
constexpr float SFK_INSIDE_X = -229.135f, SFK_INSIDE_Y = 2109.18f,
                SFK_INSIDE_Z = 76.8898f, SFK_INSIDE_O = 1.267f;

// And back out: just outside the door in Silverpine on map 751.
constexpr float SFK_OUTSIDE_X = -232.796f, SFK_OUTSIDE_Y = 1568.28f,
                SFK_OUTSIDE_Z = 76.8909f, SFK_OUTSIDE_O = 4.398f;

uint32 const MAP_SILVERPINE_751 = 751;

enum SKDataTypes
{
    // Bosses
    DATA_BARON_ASHBURY          = 0,
    DATA_BARON_SILVERLAINE      = 1,
    DATA_COMMANDER_SPRINGVALE   = 2,
    DATA_LORD_WALDEN            = 3,
    DATA_LORD_GODFREY           = 4,
    DATA_APOTHECARY_HUMMEL      = 5,

    // Additional data
    DATA_TEAM_IN_INSTANCE,
    DATA_OUTSIDE_TROUPS_SPAWN,
    DATA_GODFREY_INTRO_SPAWN,
    DATA_DEBUG_ANNOUNCER,
    DATA_ARUGAL_DOOR,
    DATA_SORCERER_GATE,
    DATA_COURTYARD_DOOR
};

// ---------------------------------------------------------------------------------
// ENTRY IDS ARE THE CLONE'S, NOT CATACLYSM'S
// ---------------------------------------------------------------------------------
// Everything in this dungeon was imported under a DC id band, because Cata SFK reuses two
// stock entries (3887 Silverlaine, 4278 Springvale) that classic Shadowfang Keep still
// spawns on map 33. The C++ compares `creature->GetEntry()` against these enums and passes
// them straight to SummonCreature, so they MUST be the clone ids -- with the source values
// the instance script matches nothing, no boss is ever tracked, no door is ever bound, and
// every summon asks for an entry that does not exist in this database at all.
//
// Creatures are a flat +5,000,000 (see 03_templates.sql).
// GameObjects are NOT: their 43 source entries span 18,895..208,524, which a flat offset
// scattered across three id bands and collided with live DC content, so they were remapped
// DENSELY from 5,400,000 via `dc_sfk825_gomap`. That mapping is deterministic (ROW_NUMBER
// over the sorted source ids) but not derivable by arithmetic, so the three the scripts
// care about are written out literally and cross-referenced to their source below.

uint32 const SFK_CATA_ENTRY_OFFSET = 5000000;

enum SKCreatures
{
    // Bosses
    BOSS_BARON_ASHBURY              = 46962 + SFK_CATA_ENTRY_OFFSET,
    BOSS_BARON_SILVERLAINE          = 3887 + SFK_CATA_ENTRY_OFFSET,
    BOSS_COMMANDER_SPRINGVALE       = 4278 + SFK_CATA_ENTRY_OFFSET,
    BOSS_LORD_WALDEN                = 46963 + SFK_CATA_ENTRY_OFFSET,
    BOSS_LORD_GODFREY               = 46964 + SFK_CATA_ENTRY_OFFSET,

    // Encounter related creatures
    /*Baron Silverlaine*/
    NPC_WORGEN_SPIRIT_NANDOS        = 51047 + SFK_CATA_ENTRY_OFFSET,
    NPC_WOLF_MASTER_NANDOS          = 50851 + SFK_CATA_ENTRY_OFFSET,
    NPC_WORGEN_SPIRIT_ODO           = 50934 + SFK_CATA_ENTRY_OFFSET,
    NPC_ODO_THE_BLINDWATCHER        = 50857 + SFK_CATA_ENTRY_OFFSET,
    NPC_WORGEN_SPIRIT_RAZORCLAW     = 51080 + SFK_CATA_ENTRY_OFFSET,
    NPC_RAZORCLAW_THE_BUTCHER       = 50869 + SFK_CATA_ENTRY_OFFSET,
    NPC_WORGEN_SPIRIT_RETHILGORE    = 51085 + SFK_CATA_ENTRY_OFFSET,
    NPC_RETHILGORE                  = 50834 + SFK_CATA_ENTRY_OFFSET,
    // Summoned three at a time by Wolf Master Nandos (SPELL_SUMMON_LUPINE_SPECTRE).
    // Nothing in C++ names it -- it is listed because 03_templates.sql derives its
    // import set for SUMMONED adds from this enum, and being absent from here is why
    // the creature was never imported and the spell summoned nothing. Keep it.
    NPC_LUPINE_SPECTRE              = 50923 + SFK_CATA_ENTRY_OFFSET,

    /*Commander Springvale*/
    NPC_TORMENTED_OFFICER           = 50615 + SFK_CATA_ENTRY_OFFSET,
    NPC_WAILING_GUARDSMAN           = 50613 + SFK_CATA_ENTRY_OFFSET,
    NPC_SHIELD_FOCUS                = 50547 + SFK_CATA_ENTRY_OFFSET,
    NPC_DESECRATION_STALKER         = 50503 + SFK_CATA_ENTRY_OFFSET,

    /*Lord Walden*/
    NPC_MYSTERY_TOXIN               = 50522 + SFK_CATA_ENTRY_OFFSET,

    /*Lord Godfrey*/
    NPC_BLOODTHIRSTY_GHOUL          = 50561 + SFK_CATA_ENTRY_OFFSET,
    NPC_PISTOL_BARRAGE_DUMMY        = 52065 + SFK_CATA_ENTRY_OFFSET,

    // Generic NPCs
    NPC_HIGH_WARLORD_CROMUSH        = 47294 + SFK_CATA_ENTRY_OFFSET,
    NPC_PACKLEADER_IVAR_BLOODFANG   = 47006 + SFK_CATA_ENTRY_OFFSET,
    NPC_DEBUG_ANNOUNCER             = 43679 + SFK_CATA_ENTRY_OFFSET,
    NPC_BLOODFANG_BERSERKER         = 47027 + SFK_CATA_ENTRY_OFFSET,
    NPC_FORSAKEN_BLIGHTSPREADER     = 47031 + SFK_CATA_ENTRY_OFFSET
};

enum SKGameObjectIds
{
    // dense remap from dc_sfk825_gomap; source id in the comment
    GO_COURTYARD_DOOR   = 5400000,      // 18895
    GO_ARUGALS_LAIR     = 5400007,      // 18971
    GO_SORCERERS_DOOR   = 5400008       // 18972
};

enum SKWorldStates
{
    // Baron Ashbury
    WORLD_STATE_ID_PARDON_DENIED = 5670,

    // Commander Springvale
    WORLD_STATE_ID_TO_THE_GROUND = 5672
};

template<class AI, class T>
inline AI* GetShadowfangKeepCataAI(T* obj)
{
    return GetInstanceAI<AI>(obj, SKCataScriptName);
}

#define RegisterShadowfangKeepCataCreatureAI(ai_name) RegisterCreatureAIWithFactory(ai_name, GetShadowfangKeepCataAI)
}

#endif // DEF_DC_SFK_CATA_H
