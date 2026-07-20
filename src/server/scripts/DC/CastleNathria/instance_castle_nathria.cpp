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

// DarkChaos downport of the Shadowlands raid Castle Nathria (map 2296).
// Ported from the "shadowcore" (TrinityCore 9.x) implementation; adapted to
// AzerothCore 3.3.5a idioms per BlackwingDescent/PORT_NOTES.md. Notable AC deltas:
//   * TC RegisterInstanceScript(struct, mapId) -> AC InstanceMapScript wrapper class + inner struct
//   * TC Initialize() setup                    -> AC constructor (SetHeaders/SetBossNumber/Load*Data)
//   * TC array-extent LoadDoorData             -> AC null-terminated DoorData table ({ 0, 0, DOOR_TYPE_ROOM } END)
//   * TC Unit::UpdatePosition(..., true)       -> AC NearTeleportTo + SetHomePosition (evade-proof)
//   * TC spawned-AreaTrigger AI (at_nathria_nightcloak) has no 3.3.5 equivalent (see TODO at end of file)
// Boss DATA_* indices re-mapped from shadowcore's 1-indexed enum to DC's 0-indexed
// DungeonEncounter.dbc order (see castle_nathria.h).

#include "Creature.h"
#include "GameObject.h"
#include "InstanceScript.h"
#include "Map.h"
#include "ScriptMgr.h"
#include "castle_nathria.h"

// Single-entry boss creatures, auto-stashed by the ObjectData framework so
// GetCreature(DATA_*) works. The multi-creature encounters (Council of Blood,
// Stone Legion Generals) have no single kill-target entry and are managed by
// their own boss scripts.
ObjectData const creatureData[] =
{
    { NPC_SHRIEKWING,           DATA_SHRIEKWING             },
    { NPC_HUNTSMAN_ALTIMOR,     DATA_HUNTSMAN_ALTIMOR       },
    { NPC_HUNGERING_DESTROYER,  DATA_HUNGERING_DESTROYER    },
    { NPC_SUN_KING_SALVATION,   DATA_SUN_KINGS_SALVATION    },
    { NPC_ARTIFICER_XYMOX,      DATA_ARTIFICER_XYMOX        },
    { NPC_LADY_INERVA_DARKVEIN, DATA_LADY_INERVA_DARKVEIN   },
    { NPC_SLUDGEFIST,           DATA_SLUDGEFIST             },
    { NPC_SIRE_DENATHRIUS,      DATA_SIRE_DENATHRIUS        },
    { 0,                        0                           }  // END
};

DoorData const doorData[] =
{
    // Shriekwing (right-hand pair is opened manually in SetBossState, as in shadowcore)
    { GO_DOOR_SHRIEKWING_LEFT,        DATA_SHRIEKWING,            DOOR_TYPE_PASSAGE },
    { GO_DOOR_SHRIEKWING_LEFT2,       DATA_SHRIEKWING,            DOOR_TYPE_PASSAGE },
    // Altimor
    { GO_DOOR_ALTIMOR_EXIT_LEFT,      DATA_HUNTSMAN_ALTIMOR,      DOOR_TYPE_PASSAGE },
    { GO_DOOR_ALTIMOR_EXIT_RIGHT,     DATA_HUNTSMAN_ALTIMOR,      DOOR_TYPE_PASSAGE },
    // Hungering
    { GO_DOOR_HUNGERING_LEFT,         DATA_HUNGERING_DESTROYER,   DOOR_TYPE_PASSAGE },
    { GO_DOOR_HUNGERING_RIGHT,        DATA_HUNGERING_DESTROYER,   DOOR_TYPE_PASSAGE },
    // Lady Inerva Darkvein
    { GO_DOOR_LADY_ONE,               DATA_LADY_INERVA_DARKVEIN,  DOOR_TYPE_PASSAGE },
    { GO_DOOR_LADY_TWO,               DATA_LADY_INERVA_DARKVEIN,  DOOR_TYPE_PASSAGE },
    // Unlock Council of Blood after Inerva's defeat
    { GO_DOOR_COUNCIL_OF_BLOOD_LEFT,  DATA_LADY_INERVA_DARKVEIN,  DOOR_TYPE_PASSAGE },
    { GO_DOOR_COUNCIL_OF_BLOOD_RIGHT, DATA_LADY_INERVA_DARKVEIN,  DOOR_TYPE_PASSAGE },
    // Council of Blood, unlock door to Sludgefist
    { GO_DOOR_SLUDGEFIST_LEFT,        DATA_COUNCIL_OF_BLOOD,      DOOR_TYPE_PASSAGE },
    { GO_DOOR_SLUDGEFIST_RIGHT,       DATA_COUNCIL_OF_BLOOD,      DOOR_TYPE_PASSAGE },
    // Stone Legion Generals, unlock door to Sire Denathrius.
    // NOTE(port): shadowcore bound this row to DATA_COUNCIL_OF_BLOOD, contradicting both its own
    // comment and its SetBossState() (which opens this door on Stone Legion Generals DONE).
    // Fixed to DATA_STONE_LEGION_GENERALS so Denathrius stays gated behind the Generals.
    { GO_DOOR_SIRE_DENATHRIUS,        DATA_STONE_LEGION_GENERALS, DOOR_TYPE_PASSAGE },
    { 0,                              0,                          DOOR_TYPE_ROOM    }  // END
};

// Position Sludgefist is moved to once Council of Blood is defeated (shadowcore data).
Position const SludgefistArenaPosition = { -1865.940f, 6721.381f, 4319.212f, 1.600f };

class instance_castle_nathria : public InstanceMapScript
{
public:
    instance_castle_nathria() : InstanceMapScript(CastleNathriaScriptName, MapCastleNathria) { }

    struct instance_castle_nathria_InstanceMapScript : public InstanceScript
    {
        instance_castle_nathria_InstanceMapScript(Map* map) : InstanceScript(map)
        {
            SetHeaders(DataHeader);
            SetBossNumber(EncounterCount);
            LoadObjectData(creatureData, nullptr);
            LoadDoorData(doorData);
        }

        void OnCreatureCreate(Creature* creature) override
        {
            InstanceScript::OnCreatureCreate(creature);

            // TODO(port): stage-manage story NPCs. The Accuser (172651), Prince Renathal (172652),
            // General Draven (172653) and RP-Sludgefist (174733) are statically spawned ONCE each at
            // their entrance-stage positions — the DB intentionally has no per-stage copies.
            // Shadowcore's instance script never relocated or summoned them (it relied on per-stage
            // static spawns), so there is no source logic to port. When the RP pass lands, summon the
            // stage copies from SetBossState() as encounters complete and despawn them on stage end.
            switch (creature->GetEntry())
            {
                case NPC_SLUDGEFIST:
                    // Boss-state persistence: on a fresh load of a saved lockout with Council of
                    // Blood already defeated, re-apply what SetBossState() did live — make
                    // Sludgefist attackable and stage him in his arena. Guarded so it degrades
                    // gracefully while bosses are unkilled (fresh instances are untouched).
                    if (GetBossState(DATA_COUNCIL_OF_BLOOD) == DONE && GetBossState(DATA_SLUDGEFIST) != DONE)
                    {
                        creature->RemoveUnitFlag(UNIT_FLAG_NON_ATTACKABLE);
                        creature->SetHomePosition(SludgefistArenaPosition);
                        creature->NearTeleportTo(SludgefistArenaPosition.GetPositionX(),
                            SludgefistArenaPosition.GetPositionY(), SludgefistArenaPosition.GetPositionZ(),
                            SludgefistArenaPosition.GetOrientation());
                    }
                    break;
                default:
                    break;
            }
        }

        void OnGameObjectCreate(GameObject* go) override
        {
            // Registers the DoorData doors (AddDoor) — shadowcore skipped the base call, which is
            // why it also opened every door manually in SetBossState(); both paths are kept.
            InstanceScript::OnGameObjectCreate(go);

            switch (go->GetEntry())
            {
                case GO_BRICKDOOR_LEFT:
                    _brickDoorLeft = go->GetGUID();
                    // Not DoorData-managed: re-apply opened state on reload (BWD persistence pattern).
                    if (GetBossState(DATA_HUNGERING_DESTROYER) == DONE)
                        go->SetGoState(GO_STATE_ACTIVE);
                    break;
                case GO_DOOR_SHRIEKWING_LEFT:
                    _shriekwingDoorLeft = go->GetGUID();
                    break;
                case GO_DOOR_SHRIEKWING_LEFT2:
                    _shriekwingDoorLeftSecond = go->GetGUID();
                    break;
                case GO_DOOR_SHRIEKWING_RIGHT:
                    _shriekwingDoorRight = go->GetGUID();
                    // Not DoorData-managed: re-apply opened state on reload.
                    if (GetBossState(DATA_SHRIEKWING) == DONE)
                        go->SetGoState(GO_STATE_ACTIVE);
                    break;
                case GO_DOOR_SHRIEKWING_RIGHT2:
                    _shriekwingDoorRightSecond = go->GetGUID();
                    // Not DoorData-managed: re-apply opened state on reload.
                    if (GetBossState(DATA_SHRIEKWING) == DONE)
                        go->SetGoState(GO_STATE_ACTIVE);
                    break;
                case GO_DOOR_ALTIMOR_EXIT_LEFT:
                    _altimorDoorLeft = go->GetGUID();
                    break;
                case GO_DOOR_ALTIMOR_EXIT_RIGHT:
                    _altimorDoorRight = go->GetGUID();
                    break;
                case GO_DOOR_ALTIMOR_TUNNEL:
                    _altimorTunnel = go->GetGUID();
                    // Not DoorData-managed: re-apply opened state on reload.
                    if (GetBossState(DATA_HUNTSMAN_ALTIMOR) == DONE)
                        go->SetGoState(GO_STATE_ACTIVE);
                    break;
                case GO_DOOR_HUNGERING_LEFT:
                    _hungeringDoorLeft = go->GetGUID();
                    break;
                case GO_DOOR_HUNGERING_RIGHT:
                    _hungeringDoorRight = go->GetGUID();
                    break;
                case GO_DOOR_LADY_ONE:
                    _ladyInervaDarkveinDoor = go->GetGUID();
                    break;
                case GO_DOOR_LADY_TWO:
                    _ladyInervaDarkveinDoorTwo = go->GetGUID();
                    break;
                case GO_DOOR_COUNCIL_OF_BLOOD_LEFT:
                    _councilOfBloodTopDoorLeft = go->GetGUID();
                    break;
                case GO_DOOR_COUNCIL_OF_BLOOD_RIGHT:
                    _councilOfBloodTopDoorRight = go->GetGUID();
                    break;
                case GO_DOOR_SLUDGEFIST_LEFT:
                    _sludgefistDoorLeft = go->GetGUID();
                    break;
                case GO_DOOR_SLUDGEFIST_RIGHT:
                    _sludgefistDoorRight = go->GetGUID();
                    break;
                case GO_DOOR_SIRE_DENATHRIUS:
                    _sireDenathriusDoor = go->GetGUID();
                    break;
                default:
                    break;
            }
        }

        bool SetBossState(uint32 type, EncounterState state) override
        {
            if (!InstanceScript::SetBossState(type, state))
                return false;

            switch (type)
            {
                case DATA_SHRIEKWING:
                    if (state == DONE)
                    {
                        HandleGameObject(_shriekwingDoorLeft, true);
                        HandleGameObject(_shriekwingDoorLeftSecond, true);
                        HandleGameObject(_shriekwingDoorRight, true);
                        HandleGameObject(_shriekwingDoorRightSecond, true);
                    }
                    break;
                case DATA_HUNTSMAN_ALTIMOR:
                    if (state == DONE)
                    {
                        HandleGameObject(_altimorDoorLeft, true);
                        HandleGameObject(_altimorDoorRight, true);
                        HandleGameObject(_altimorTunnel, true);
                    }
                    break;
                case DATA_HUNGERING_DESTROYER:
                    if (state == DONE)
                    {
                        HandleGameObject(_hungeringDoorLeft, true);
                        HandleGameObject(_hungeringDoorRight, true);
                        HandleGameObject(_brickDoorLeft, true);
                    }
                    break;
                case DATA_LADY_INERVA_DARKVEIN:
                    if (state == DONE)
                    {
                        HandleGameObject(_ladyInervaDarkveinDoor, true);
                        HandleGameObject(_ladyInervaDarkveinDoorTwo, true);
                        HandleGameObject(_councilOfBloodTopDoorLeft, true);
                        HandleGameObject(_councilOfBloodTopDoorRight, true);
                    }
                    break;
                case DATA_COUNCIL_OF_BLOOD:
                    if (state == DONE)
                    {
                        HandleGameObject(_sludgefistDoorLeft, true);
                        HandleGameObject(_sludgefistDoorRight, true);
                        // Stage Sludgefist: unchain him from his entrance-stage RP position and move
                        // him to his arena. No-op if the creature is not loaded (e.g. state applied
                        // while reading save data) — OnCreatureCreate() re-applies it on spawn.
                        if (Creature* sludgefist = GetCreature(DATA_SLUDGEFIST))
                        {
                            sludgefist->RemoveUnitFlag(UNIT_FLAG_NON_ATTACKABLE);
                            sludgefist->SetHomePosition(SludgefistArenaPosition);
                            sludgefist->NearTeleportTo(SludgefistArenaPosition.GetPositionX(),
                                SludgefistArenaPosition.GetPositionY(), SludgefistArenaPosition.GetPositionZ(),
                                SludgefistArenaPosition.GetOrientation());
                        }
                    }
                    break;
                case DATA_STONE_LEGION_GENERALS:
                    if (state == DONE)
                        HandleGameObject(_sireDenathriusDoor, true);
                    break;
                default:
                    break;
            }
            return true;
        }

    private:
        ObjectGuid _brickDoorLeft;
        ObjectGuid _shriekwingDoorLeft;
        ObjectGuid _shriekwingDoorLeftSecond;
        ObjectGuid _shriekwingDoorRight;
        ObjectGuid _shriekwingDoorRightSecond;
        ObjectGuid _altimorDoorLeft;
        ObjectGuid _altimorDoorRight;
        ObjectGuid _altimorTunnel;
        ObjectGuid _hungeringDoorLeft;
        ObjectGuid _hungeringDoorRight;
        ObjectGuid _ladyInervaDarkveinDoor;
        ObjectGuid _ladyInervaDarkveinDoorTwo;
        ObjectGuid _councilOfBloodTopDoorLeft;
        ObjectGuid _councilOfBloodTopDoorRight;
        ObjectGuid _sludgefistDoorLeft;
        ObjectGuid _sludgefistDoorRight;
        ObjectGuid _sireDenathriusDoor;
    };

    InstanceScript* GetInstanceScript(InstanceMap* map) const override
    {
        return new instance_castle_nathria_InstanceMapScript(map);
    }
};

// TODO(port): shadowcore also registered `at_nathria_nightcloak`, an AreaTriggerAI on SPAWNED
// AreaTrigger 100007: once DATA_SLUDGEFIST was DONE, players entering it were teleported to
// (-1840.733f, -9408.963f, 4644.256f, o 0.948f) — the shortcut toward the Stone Legion Generals.
// 3.3.5 has no spawned-AreaTrigger subsystem; re-author as an AreaTrigger.dbc row for map 2296
// plus an AreaTriggerScript (OnTrigger) once a trigger id is allocated.
void AddSC_instance_castle_nathria()
{
    new instance_castle_nathria();
}
