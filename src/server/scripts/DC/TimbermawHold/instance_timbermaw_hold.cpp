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

// Timbermaw Hold (map 819) -- 20-man raid, "Nightmares of Ursol".
//
// Seven encounters laid out along the WMO's own three-wing shape: the village wing falls
// first, then the corruption wing, then the twin bear gods. The room names in the WMO
// (Village01, SatyrRoom, Corruption01_Upper, UrsocRoom) are what the encounter order follows,
// and the client's own music cues confirm it -- Zone-TimbermawHold -> ...Evil -> ...Ursol.
//
// InstanceMapScript nails the map id in its constructor, so this cannot be shared with any
// other map even though the structure is unremarkable.

#include "Creature.h"
#include "InstanceMapScript.h"
#include "InstanceScript.h"
#include "Map.h"
#include "ScriptMgr.h"

namespace
{
    constexpr uint32 MAP_TIMBERMAW_HOLD = 819;

    constexpr char const* DataHeader = "TMBH";

    // 0-indexed and in DungeonEncounter.dbc order (1100-1106). The M+ boss counter, the
    // final-boss loot path and the HUD all read that ordering, so it must not drift.
    enum Data
    {
        DATA_GATEWARDEN     = 0,
        DATA_CHIEFTAIN      = 1,
        DATA_DEN_MOTHER     = 2,
        DATA_XANTHIR        = 3,
        DATA_NIGHTMARE_ROOT = 4,
        DATA_URSOL          = 5,
        DATA_URSOC          = 6,
        MAX_ENCOUNTERS      = 7
    };

    enum CreatureIds
    {
        NPC_GATEWARDEN     = 4010001,
        NPC_CHIEFTAIN      = 4010002,
        NPC_DEN_MOTHER     = 4010003,
        NPC_XANTHIR        = 4010004,
        NPC_NIGHTMARE_ROOT = 4010005,
        NPC_URSOL          = 4010006,
        NPC_URSOC          = 4010007
    };

    class instance_timbermaw_hold : public InstanceMapScript
    {
    public:
        instance_timbermaw_hold() : InstanceMapScript("instance_timbermaw_hold", MAP_TIMBERMAW_HOLD) { }

        struct instance_timbermaw_hold_InstanceMapScript : public InstanceScript
        {
            instance_timbermaw_hold_InstanceMapScript(Map* map) : InstanceScript(map)
            {
                SetHeaders(DataHeader);
                SetBossNumber(MAX_ENCOUNTERS);
            }

            void OnUnitDeath(Unit* unit) override
            {
                Creature* creature = unit ? unit->ToCreature() : nullptr;
                if (!creature)
                    return;

                switch (creature->GetEntry())
                {
                    case NPC_GATEWARDEN:     SetBossState(DATA_GATEWARDEN, DONE);     break;
                    case NPC_CHIEFTAIN:      SetBossState(DATA_CHIEFTAIN, DONE);      break;
                    case NPC_DEN_MOTHER:     SetBossState(DATA_DEN_MOTHER, DONE);     break;
                    case NPC_XANTHIR:        SetBossState(DATA_XANTHIR, DONE);        break;
                    case NPC_NIGHTMARE_ROOT: SetBossState(DATA_NIGHTMARE_ROOT, DONE); break;
                    case NPC_URSOL:          SetBossState(DATA_URSOL, DONE);          break;
                    case NPC_URSOC:          SetBossState(DATA_URSOC, DONE);          break;
                    default: break;
                }
            }
        };

        InstanceScript* GetInstanceScript(InstanceMap* map) const override
        {
            return new instance_timbermaw_hold_InstanceMapScript(map);
        }
    };
}

void AddSC_instance_timbermaw_hold()
{
    new instance_timbermaw_hold();
}
