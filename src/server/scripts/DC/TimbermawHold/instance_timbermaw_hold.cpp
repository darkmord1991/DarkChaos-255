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

// Timbermaw Hold (map 819) -- 20-man raid, Turtle WoW's layout.
//
// Nine encounters. Four of the guardians -- Karrsh, Rotgrowl and Kodiak, Archdruid Kronn and
// Chieftain Partath -- each stand beside one of Turtle's braziers. A guardian's death puts its
// brazier out, and with all four dark the Barrier of Ursol opens and Ursol wakes in the room above.
// Loktanag, Ormanos, Selenaxx and Trioch are optional, exactly as Turtle placed them.
//
// The braziers are retired with SetPhaseMask(2) rather than despawned, the same way the stock
// Blackwing Lair script retires Razorgore's eggs: OnGameObjectCreate re-applies it from the saved
// boss states, so a reloaded instance comes back with the right braziers lit and the barrier in the
// right state without any respawn bookkeeping.

#include "Creature.h"
#include "CreatureAI.h"
#include "GameObject.h"
#include "InstanceMapScript.h"
#include "InstanceScript.h"
#include "Map.h"
#include "ScriptMgr.h"
#include "timbermaw_hold.h"

ObjectData const creatureData[] =
{
    { NPC_ROTGROWL,          DATA_ROTGROWL },
    { NPC_KODIAK,            DATA_KODIAK   },
    { NPC_SELENAXX,          DATA_SELENAXX },
    { NPC_DRAENETHYST_GEODE, DATA_GEODE    },
    { NPC_URSOL,             DATA_URSOL    },
    { 0,                     0             }
};

ObjectData const gameObjectData[] =
{
    { GO_BARRIER_OF_URSOL,         DATA_BARRIER_OF_URSOL         },
    { GO_BRAZIER_OF_CORRUPTION,    DATA_BRAZIER_OF_CORRUPTION    },
    { GO_BRAZIER_OF_DEFILEMENT,    DATA_BRAZIER_OF_DEFILEMENT    },
    { GO_BRAZIER_OF_DECAY,         DATA_BRAZIER_OF_DECAY         },
    { GO_BRAZIER_OF_PUTRIFICATION, DATA_BRAZIER_OF_PUTRIFICATION },
    { 0,                           0                             }
};

namespace
{
    // Which brazier a guardian encounter puts out; 0 for the encounters that have none.
    uint32 BrazierDataFor(uint32 bossId)
    {
        switch (bossId)
        {
            case DATA_KARRSH:   return DATA_BRAZIER_OF_CORRUPTION;
            case DATA_ROTGROWL: return DATA_BRAZIER_OF_DEFILEMENT;
            case DATA_KRONN:    return DATA_BRAZIER_OF_DECAY;
            case DATA_PARTATH:  return DATA_BRAZIER_OF_PUTRIFICATION;
            default:            return 0;
        }
    }

    uint32 GuardianFor(uint32 goEntry)
    {
        switch (goEntry)
        {
            case GO_BRAZIER_OF_CORRUPTION:    return DATA_KARRSH;
            case GO_BRAZIER_OF_DEFILEMENT:    return DATA_ROTGROWL;
            case GO_BRAZIER_OF_DECAY:         return DATA_KRONN;
            case GO_BRAZIER_OF_PUTRIFICATION: return DATA_PARTATH;
            default:                          return TimbermawEncounterCount;
        }
    }
}

class instance_timbermaw_hold : public InstanceMapScript
{
public:
    instance_timbermaw_hold() : InstanceMapScript(TimbermawHoldScriptName, MapTimbermawHold) { }

    struct instance_timbermaw_hold_InstanceMapScript : public InstanceScript
    {
        instance_timbermaw_hold_InstanceMapScript(Map* map) : InstanceScript(map)
        {
            SetHeaders(TMBHDataHeader);
            SetBossNumber(TimbermawEncounterCount);
            LoadObjectData(creatureData, gameObjectData);
        }

        bool BarrierOpen() const
        {
            for (uint32 guardian : TimbermawBrazierGuardians)
                if (GetBossState(guardian) != DONE)
                    return false;

            return true;
        }

        void OnCreatureCreate(Creature* creature) override
        {
            InstanceScript::OnCreatureCreate(creature);

            if (creature->GetEntry() == NPC_URSOL && !BarrierOpen())
                SealUrsol(creature, true);
        }

        void OnGameObjectCreate(GameObject* go) override
        {
            InstanceScript::OnGameObjectCreate(go);

            if (go->GetEntry() == GO_BARRIER_OF_URSOL)
            {
                HandleGameObject(ObjectGuid::Empty, BarrierOpen(), go);
                return;
            }

            uint32 const guardian = GuardianFor(go->GetEntry());
            if (guardian < TimbermawEncounterCount && GetBossState(guardian) == DONE)
                go->SetPhaseMask(2, true);
        }

        bool SetBossState(uint32 type, EncounterState state) override
        {
            if (!InstanceScript::SetBossState(type, state))
                return false;

            if (state != DONE)
                return true;

            if (uint32 const brazierData = BrazierDataFor(type))
            {
                if (GameObject* brazier = GetGameObject(brazierData))
                    brazier->SetPhaseMask(2, true);

                if (BarrierOpen())
                {
                    HandleGameObject(DATA_BARRIER_OF_URSOL, true);

                    if (Creature* ursol = GetCreature(DATA_URSOL))
                    {
                        SealUrsol(ursol, false);
                        ursol->AI()->Talk(4);
                    }
                }
            }

            return true;
        }

        // Ursol sits behind the barrier with no way to reach him, but a sealed room is not enough on
        // its own: a pet or a careless AoE could still pull him early, so he is untouchable until
        // the last brazier goes out.
        static void SealUrsol(Creature* ursol, bool seal)
        {
            if (seal)
            {
                ursol->SetUnitFlag(UNIT_FLAG_NOT_SELECTABLE);
                ursol->SetImmuneToPC(true);
                ursol->SetReactState(REACT_PASSIVE);
            }
            else
            {
                ursol->RemoveUnitFlag(UNIT_FLAG_NOT_SELECTABLE);
                ursol->SetImmuneToPC(false);
                ursol->SetReactState(REACT_AGGRESSIVE);
            }
        }
    };

    InstanceScript* GetInstanceScript(InstanceMap* map) const override
    {
        return new instance_timbermaw_hold_InstanceMapScript(map);
    }
};

void AddSC_instance_timbermaw_hold()
{
    new instance_timbermaw_hold();
}
