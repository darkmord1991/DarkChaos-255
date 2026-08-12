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

// Crescent Grove (map 823) -- levelling 5-man, and the only one of the three registered for
// Mythic+ keystones.
//
// Five encounters, taken verbatim from Turtle's own dungeon-finder data rather than from
// secondary sources: Keeper Ranathos, Grovetender Engryss, High Priestess A'lathea,
// Fenektis the Deceiver, Master Raxxieth. The route follows the map's own clean-to-corrupted
// gradient -- area 16104 "Crescent Grove" into 16105 "Vilethorn Scar".

#include "Creature.h"
#include "InstanceMapScript.h"
#include "InstanceScript.h"
#include "Map.h"
#include "ScriptMgr.h"
#include "crescent_grove.h"

class instance_crescent_grove : public InstanceMapScript
{
public:
    instance_crescent_grove() : InstanceMapScript(CrescentGroveScriptName, MapCrescentGrove) { }

    struct instance_crescent_grove_InstanceMapScript : public InstanceScript
    {
        instance_crescent_grove_InstanceMapScript(Map* map) : InstanceScript(map)
        {
            SetHeaders(CRGVDataHeader);
            SetBossNumber(CrescentGroveEncounterCount);
        }

        // THE COUNCIL IS THE ONE ENCOUNTER THE INSTANCE HAS TO ARBITRATE.
        // Engryss and his two elders share DungeonEncounter 1111, and the encounter is only
        // DONE once all three are down -- otherwise a group kills the Grovetender and takes
        // credit while both elders are still standing. BossAI::_JustDied() would mark it DONE
        // the moment Engryss falls, so boss_grovetender_engryss deliberately does NOT call it
        // and defers to this instead.
        void OnUnitDeath(Unit* unit) override
        {
            Creature* creature = unit ? unit->ToCreature() : nullptr;
            if (!creature)
                return;

            switch (creature->GetEntry())
            {
                case NPC_ENGRYSS:
                    _engryssDown = true;
                    break;
                case NPC_ONE_EYE:
                case NPC_BLACKMAW:
                    ++_eldersDown;
                    break;
                default:
                    return;
            }

            if (_engryssDown && _eldersDown >= 2)
                SetBossState(DATA_ENGRYSS, DONE);
        }

        void ReadSaveDataMore(std::istringstream& data) override
        {
            uint32 engryss = 0;
            data >> _eldersDown >> engryss;
            _engryssDown = engryss != 0;
        }

        void WriteSaveDataMore(std::ostringstream& data) override
        {
            data << _eldersDown << ' ' << (_engryssDown ? 1 : 0) << ' ';
        }

    private:
        uint32 _eldersDown = 0;
        bool _engryssDown = false;
    };

    InstanceScript* GetInstanceScript(InstanceMap* map) const override
    {
        return new instance_crescent_grove_InstanceMapScript(map);
    }
};

void AddSC_instance_crescent_grove()
{
    new instance_crescent_grove();
}
