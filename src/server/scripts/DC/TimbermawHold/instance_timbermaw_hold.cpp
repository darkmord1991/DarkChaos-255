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
#include "timbermaw_hold.h"

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
