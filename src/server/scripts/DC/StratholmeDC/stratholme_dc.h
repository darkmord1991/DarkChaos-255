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

// Header for the DarkChaos Stratholme clone on map 821.
//
// Stock Stratholme (map 329) is left completely alone -- every one of its 469 creature and
// 188 gameobject spawns, its instance script, and its three entrance triggers keep working
// exactly as before. This is a private copy so the 130-160 re-level and a DC-owned
// entrance/exit can happen without changing the dungeon for everyone.
//
// ---------------------------------------------------------------------------------
// WHY THIS FILE IS A COPY OF stratholme.h RATHER THAN AN INCLUDE OF IT
// ---------------------------------------------------------------------------------
// Two things have to differ and neither can be overridden from outside:
//
//   1. The include guard and DataHeader. Upstream uses DEF_STRATHOLME_H / "STR". Including
//      both headers in one build with the same guard silently gives you whichever came
//      first -- the same class of collision that made the Shadowfang port need its own
//      header (AzerothCore's and CataTC's both used DEF_SHADOWFANG_H).
//
//   2. Every id. The clone's creatures and gameobjects live in remapped bands, so a
//      GetEntry() comparison against a stock id would simply never be true. On Shadowfang
//      this exact mistake shipped: the header kept the SOURCE ids, so the instance script
//      and every summon failed silently and completely, with nothing in any log.
//
// ---------------------------------------------------------------------------------
// WHERE THESE NUMBERS COME FROM -- DO NOT EDIT BY HAND
// ---------------------------------------------------------------------------------
// The remap is DENSE (ROW_NUMBER over the sorted source ids), not a fixed offset, so the
// clone id cannot be derived from the stock id with arithmetic. Every value below was read
// out of the mapping tables built by 02_id_maps.sql, and the stock id it came from is in
// the comment beside it. If those tables are ever rebuilt with a different source set, these
// constants must be re-read from them -- the authoritative query is:
//
//     SELECT src_entry, dst_entry FROM dc_strat821_cmap;   -- creatures
//     SELECT src_entry, dst_entry FROM dc_strat821_gmap;   -- gameobjects

#ifndef DEF_DC_STRATHOLME_DC_H
#define DEF_DC_STRATHOLME_DC_H

// Upstream's stratholme.h has no includes and relies on every consumer having pulled in
// Define.h first. This header uses uint32 at namespace scope, so it says so itself rather
// than depending on include order in whatever file picks it up next.
#include "Define.h"

#define DataHeader "STRDC"
#define StratholmeDCScriptName "instance_stratholme_dc"

// The clone's map id. Stock Stratholme is MAP_STRATHOLME (329) in AreaDefines.h and stays
// bound to the stock instance script; InstanceMapScript maps one script name to one map id,
// and ScriptMgr silently deletes the older registration if a name is reused.
uint32 const MAP_STRATHOLME_DC = 821;

enum DataTypes
{
    TYPE_BARON_RUN                      = 0,
    TYPE_ZIGGURAT1                      = 1,
    TYPE_ZIGGURAT2                      = 2,
    TYPE_ZIGGURAT3                      = 3,
    TYPE_BARON_FIGHT                    = 4,
    TYPE_MALLOW                         = 5,
    TYPE_BARTHILAS_RUN                  = 6,

    DATA_BARON_RUN_NONE                 = 0,
    DATA_BARON_RUN_GATE                 = 1,
    DATA_JARIEN                         = 2,
    DATA_SOTHOS                         = 3
};

// Clone entries from dc_strat821_cmap. Stock id in the comment.
enum CreatureIds
{
    NPC_BARTHILAS                       = 5500033,  // 10435
    NPC_BARON_RIVENDARE                 = 5500038,  // 10440
    NPC_BILE_SPEWER                     = 5500022,  // 10416
    NPC_VENOM_BELCHER                   = 5500023,  // 10417
    NPC_RAMSTEIN_THE_GORGER             = 5500037,  // 10439
    NPC_MINDLESS_UNDEAD                 = 5500052,  // 11030
    NPC_BLACK_GUARD                     = 5500008,  // 10394
    NPC_YSIDA                           = 5500059,  // 16031
    NPC_PLAGUED_RAT                     = 5500039,  // 10441
    NPC_PLAGUED_INSECT                  = 5500040,  // 10461
    NPC_PLAGUED_MAGGOT                  = 5500044,  // 10536
    NPC_JARIEN                          = 5500062,  // 16101
    NPC_SOTHOS                          = 5500063,  // 16102
    NPC_SPIRIT_OF_JARIEN                = 5500064,  // 16103
    NPC_SPIRIT_OF_SOTHOS                = 5500065   // 16104
};

// Clone entries from dc_strat821_gmap. Stock id in the comment.
enum GameobjectIds
{
    GO_CRUSADER_SQUARE_DOOR             = 5600076,  // 175967
    GO_HOARD_DOOR                       = 5600077,  // 175968
    GO_HALL_OF_HIGH_COMMAND             = 5600080,  // 176194
    GO_GAUNTLET_DOOR_1                  = 5600009,  // 175357
    GO_GAUNTLET_DOOR_2                  = 5600008,  // 175356
    GO_ZIGGURAT_DOORS1                  = 5600020,  // 175380  baroness
    GO_ZIGGURAT_DOORS2                  = 5600019,  // 175379  nerub'enkan
    GO_ZIGGURAT_DOORS3                  = 5600021,  // 175381  maleki
    GO_ZIGGURAT_DOORS4                  = 5600022,  // 175405  rammstein
    GO_ZIGGURAT_DOORS5                  = 5600070,  // 175796  baron
    GO_GAUNTLET_GATE                    = 5600015,  // 175374
    GO_SLAUGTHER_GATE                   = 5600014,  // 175373
    GO_SLAUGHTER_GATE_SIDE              = 5600010,  // 175358
    GO_EXIT_GATE                        = 5600100,  // 176424
    GO_PORT_TRAP_GATE_1                 = 5600003,  // 175351  rats trap
    GO_PORT_TRAP_GATE_2                 = 5600002,  // 175350  gate trap, scarlet side
    GO_PORT_TRAP_GATE_3                 = 5600007,  // 175355  gate trap, undead side
    GO_PORT_TRAP_GATE_4                 = 5600006,  // 175354
    // Summoned by boss_jarien_and_sothos_dc, never spawned. It is in dc_strat821_gmap only
    // because 02 deliberately seeds the gameobject set with runtime-summoned entries too --
    // without that this id would still point at the stock chest.
    GO_JARIEN_AND_SOTHOS_HEIRLOOMS      = 5600107   // 181083
};

enum MiscIds
{
    SAY_BLACK_GUARD_INIT                = 0,
    SAY_BARON_INIT_YELL                 = 0,
    SAY_BRAON_ZIGGURAT_FALL_YELL        = 1,
    SAY_BARON_10M                       = 2,
    SAY_BARON_5M                        = 3,
    SAY_BARON_0M                        = 4,
    SAY_BRAON_SUMMON_RAMSTEIN           = 5,
    SAY_BARON_GUARD_DEAD                = 6,

    EVENT_BARON_TIME                    = 1,
    EVENT_SPAWN_MINDLESS                = 2,
    EVENT_FORCE_SLAUGHTER_EVENT         = 3,
    EVENT_SPAWN_BLACK_GUARD             = 4,
    EVENT_EXECUTE_PRISONER              = 5,
    EVENT_GATE1_TRAP                    = 6,
    EVENT_GATE1_DELAY                   = 7,
    EVENT_GATE1_CRITTER_DELAY           = 8,
    EVENT_GATE2_TRAP                    = 9,
    EVENT_GATE2_DELAY                   = 10,
    EVENT_GATE2_CRITTER_DELAY           = 11,

    // Spell ids are NOT remapped. The clone reuses stock spells, which already exist both
    // server-side and in the client -- there is no Spell.dbc work anywhere in this port.
    SPELL_BARON_ULTIMATUM               = 27861
};

// Portal trigger entries, from 07_portals.sql. Three ways in, one way out, matching stock
// Stratholme's own three entrance triggers and single exit.
uint32 const NPC_STRAT_DC_PORTAL_FRONT_RIGHT = 5520000;
uint32 const NPC_STRAT_DC_PORTAL_FRONT_LEFT  = 5520001;
uint32 const NPC_STRAT_DC_PORTAL_BACK        = 5520002;
uint32 const NPC_STRAT_DC_PORTAL_EXIT        = 5520003;

// The map players arrive from and return to. Stock Stratholme's exit trigger (2221) sends
// players to map 0; the clone sends them to the DC Lordaeron extension instead, which is
// the entire reason this dungeon needed a private map id.
uint32 const MAP_LORDAERON_751 = 751;

template <class AI, class T>
inline AI* GetStratholmeDCAI(T* obj)
{
    return GetInstanceAI<AI>(obj, StratholmeDCScriptName);
}

#define RegisterStratholmeDCCreatureAI(ai_name) RegisterCreatureAIWithFactory(ai_name, GetStratholmeDCAI)

#endif
