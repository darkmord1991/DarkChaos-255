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

// Header for the DarkChaos Scholomance clone on map 822.
//
// Stock Scholomance (map 289) is left completely alone -- all 399 creature and 62
// gameobject spawns, its instance script and its entrance keep working exactly as before.
// This is a private copy so the 130-160 re-level and a DC-owned entrance/exit can happen
// without changing the dungeon for everyone. Same recipe as the Stratholme clone (821).
//
// ---------------------------------------------------------------------------------
// WHERE THESE NUMBERS COME FROM -- DO NOT EDIT BY HAND
// ---------------------------------------------------------------------------------
// The remap is DENSE (ROW_NUMBER over the sorted source ids), not a fixed offset, so a
// clone id cannot be derived from the stock id with arithmetic. Every value below was read
// out of the mapping tables built by 02_id_maps.sql; the stock id is in the comment. The
// authoritative query is:
//
//     SELECT src_entry, dst_entry FROM dc_scholo822_cmap;   -- creatures
//     SELECT src_entry, dst_entry FROM dc_scholo822_gmap;   -- gameobjects
//
// Keeping stock ids here is not a cosmetic mistake: on Shadowfang the header kept the
// SOURCE ids and every GetEntry() comparison and every summon failed silently, with nothing
// in any log.

#ifndef DEF_DC_SCHOLOMANCE_DC_H
#define DEF_DC_SCHOLOMANCE_DC_H

#include "CreatureAIImpl.h"

#define DataHeader "SCHOLODC"
#define ScholomanceDCScriptName "instance_scholomance_dc"

// The clone's map id. Stock Scholomance is MAP_SCHOLOMANCE (289) in AreaDefines.h and stays
// bound to the stock instance script; InstanceMapScript maps one script name to one map id,
// and ScriptMgr silently deletes the older registration if a name is reused.
uint32 const MAP_SCHOLOMANCE_DC = 822;

// Where the clone's exits put players. Stock's exit triggers all target map 0; the clone
// returns them to the DC Lordaeron extension instead, which is the whole reason this
// dungeon needed a private map id.
uint32 const MAP_LORDAERON_751 = 751;

enum DataTypes
{
    DATA_KIRTONOS_THE_HERALD            = 0,
    DATA_MINI_BOSSES                    = 1,
    DATA_RAS_HUMAN                      = 2,
    DATA_DARKMASTER_GANDLING            = 3
};

enum ModelIds
{
    MODEL_RAS_HUMAN = 3975
};

enum TalkGroupIds
{
    TALK_RAS_HUMAN = 0
};

// Clone entries from dc_scholo822_cmap. Stock id in the comment.
enum CreatureIds
{
    NPC_DARKMASTER_GANDLING     = 5700000,  // 1853
    NPC_SCHOLOMANCE_OCCULTIST   = 5700008,  // 10472  UpdateEntry target, see below
    NPC_KIRTONOS                = 5700029,  // 10506
    NPC_DARK_SHADE              = 5700036,  // 11284  UpdateEntry target, see below
    NPC_RISEN_GUARDIAN          = 5700039,  // 11598
    NPC_KORMOK                  = 5700044,  // 16118
    NPC_BONE_MINION             = 5700045,  // 16119
    NPC_BONE_MAGE               = 5700046   // 16120
};

// THE OCCULTIST MORPH PAIR -- a third kind of runtime-only entry.
// npc_scholomance_occultist_dc calls me->UpdateEntry() twice: once to normalise itself to
// the Occultist entry, and again at 30% health to become a Dark Shade. Neither is a spawn
// and neither is a summon, so a scan for spawned entries and a scan for SmartAI summon
// targets BOTH miss them -- an early draft of this port did exactly that and left Dark
// Shade (11284) out of the clone set entirely, which would have morphed the clone's
// occultists into the stock creature and dropped them out of this map's id band.
//
// Dark Shade is never spawned anywhere on map 289, so it only reaches the clone because
// 02_id_maps.sql seeds it explicitly. Adding it also SHIFTED four ids that sort above it
// (Risen Guardian, Kormok and both adds) -- which is why those differ from a first draft.

// STOCK ids, kept deliberately -- see boss_kormok_dc.cpp. Kormok's adds are summoned by
// Spell.dbc entries (SPELL_EFFECT_SUMMON with EffectMiscValue = the creature id), and
// Spell.dbc is SHARED with stock Scholomance. Those spells therefore always produce the
// stock adds even on the clone; the boss swaps them out by entry, and needs these to
// recognise them.
enum StockAddIds
{
    NPC_BONE_MINION_STOCK       = 16119,
    NPC_BONE_MAGE_STOCK         = 16120
};

// Clone entries from dc_scholo822_gmap. Stock id in the comment.
enum GameobjectIds
{
    GO_BRAZIER_KIRTONOS         = 5800001,  // 175564
    GO_GATE_KIRTONOS            = 5800002,  // 175570

    GO_DOOR_OPENED_WITH_KEY     = 5800000,  // 175167

    GO_GATE_GANDLING_ENTRANCE   = 5800044,  // 177374

    GO_GATE_GANDLING_DOWN_NORTH = 5800041,  // 177371
    GO_GATE_GANDLING_DOWN_EAST  = 5800043,  // 177373
    GO_GATE_GANDLING_DOWN_SOUTH = 5800042,  // 177372
    GO_GATE_GANDLING_UP_NORTH   = 5800046,  // 177376
    GO_GATE_GANDLING_UP_EAST    = 5800047,  // 177377
    GO_GATE_GANDLING_UP_SOUTH   = 5800045   // 177375
};

// ---------------------------------------------------------------------------------
// GANDLING'S ROOM DESTINATIONS -- the cross-instance leak this clone has to close
// ---------------------------------------------------------------------------------
// Darkmaster Gandling teleports a player into one of six side rooms. Upstream does that by
// casting one of six spells whose destination lives in `spell_target_position` -- and every
// one of those rows hardcodes MapID 289.
//
// Spell.cpp:1403-1409 applies that map id ABSOLUTELY for SPELL_EFFECT_TELEPORT_UNITS, and
// unlike the Stratholme case (where the equivalent spells were creature-targeted, so
// SpellEffects.cpp:1240 caught them and merely logged) these are cast on a PLAYER. On the
// clone that is a real teleport out of map 822 and into stock Scholomance.
//
// spell_target_position is keyed by spell id alone, so it cannot hold a different map per
// dungeon. Cloning the six spells would mean appending to the 234-field fork Spell.dbc and
// redeploying the client. Instead the cloned boss teleports directly, using the coordinates
// those spells would have used -- pure C++, no DBC work.
//
// The order MUST match GandlingPortalSpells[] in boss_darkmaster_gandling_dc.cpp:
//     0 down north, 1 down east, 2 down south, 3 up north, 4 up east, 5 up south
struct GandlingRoomDest
{
    float x, y, z, o;
};

GandlingRoomDest const GandlingRoomDestinations[6] =
{
    { 266.774f,   0.886003f, 75.2501f, 3.07178f  },  // 0 down north  (was spell 17944)
    { 179.141f, -91.118f,    71.5433f, 1.64061f  },  // 1 down east   (was spell 17946)
    { 103.305f,  -1.67752f,  75.2183f, 6.17846f  },  // 2 down south  (was spell 17948)
    { 274.877f,   1.33366f,  85.3117f, 3.22886f  },  // 3 up north    (was spell 17863)
    { 182.423f, -95.8264f,   85.2284f, 1.58984f  },  // 4 up east     (was spell 17939)
    {  83.2952f, -1.70237f,  85.2284f, 0.0174533f }  // 5 up south    (was spell 17943)
};

// Portal trigger entries, from 07_portals.sql. One way in, four ways out, matching stock.
uint32 const NPC_SCHOLO_DC_PORTAL_ENTRANCE  = 5720000;
uint32 const NPC_SCHOLO_DC_PORTAL_PORCH_A   = 5720001;
uint32 const NPC_SCHOLO_DC_PORTAL_PORCH_B   = 5720002;
uint32 const NPC_SCHOLO_DC_PORTAL_PORCH_C   = 5720003;
uint32 const NPC_SCHOLO_DC_PORTAL_MAIN_DOOR = 5720004;

template <class AI, class T>
inline AI* GetScholomanceDCAI(T* obj)
{
    return GetInstanceAI<AI>(obj, ScholomanceDCScriptName);
}

#define RegisterScholomanceDCCreatureAI(ai_name) RegisterCreatureAIWithFactory(ai_name, GetScholomanceDCAI)

#endif
