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
//
// Engryss is flanked by two elders. They are NOT separate encounters: they share his
// DungeonEncounter, so the boss count stays 5 and the M+ HUD does not report seven.

#include "Creature.h"
#include "InstanceMapScript.h"
#include "InstanceScript.h"
#include "Map.h"
#include "ScriptMgr.h"

namespace
{
    constexpr uint32 MAP_CRESCENT_GROVE = 823;

    constexpr char const* DataHeader = "CRGV";

    // 0-indexed, in DungeonEncounter.dbc order (1110-1114).
    enum Data
    {
        DATA_RANATHOS  = 0,
        DATA_ENGRYSS   = 1,
        DATA_ALATHEA   = 2,
        DATA_FENEKTIS  = 3,
        DATA_RAXXIETH  = 4,
        MAX_ENCOUNTERS = 5
    };

    enum CreatureIds
    {
        NPC_RANATHOS = 4020001,
        NPC_ENGRYSS  = 4020002,
        NPC_ONE_EYE  = 4020003,
        NPC_BLACKMAW = 4020004,
        NPC_ALATHEA  = 4020005,
        NPC_FENEKTIS = 4020006,
        NPC_RAXXIETH = 4020007
    };

    class instance_crescent_grove : public InstanceMapScript
    {
    public:
        instance_crescent_grove() : InstanceMapScript("instance_crescent_grove", MAP_CRESCENT_GROVE) { }

        struct instance_crescent_grove_InstanceMapScript : public InstanceScript
        {
            instance_crescent_grove_InstanceMapScript(Map* map) : InstanceScript(map)
            {
                SetHeaders(DataHeader);
                SetBossNumber(MAX_ENCOUNTERS);
                _eldersDown = 0;
            }

            void OnUnitDeath(Unit* unit) override
            {
                Creature* creature = unit ? unit->ToCreature() : nullptr;
                if (!creature)
                    return;

                switch (creature->GetEntry())
                {
                    case NPC_RANATHOS: SetBossState(DATA_RANATHOS, DONE); break;
                    case NPC_ALATHEA:  SetBossState(DATA_ALATHEA, DONE);  break;
                    case NPC_FENEKTIS: SetBossState(DATA_FENEKTIS, DONE); break;
                    case NPC_RAXXIETH: SetBossState(DATA_RAXXIETH, DONE); break;
                    case NPC_ONE_EYE:
                    case NPC_BLACKMAW:
                        ++_eldersDown;
                        TryCompleteEngryss();
                        break;
                    case NPC_ENGRYSS:
                        _engryssDown = true;
                        TryCompleteEngryss();
                        break;
                    default:
                        break;
                }
            }

            /// The council only counts as cleared once the Grovetender AND both elders are
            /// down, so a group cannot skip the adds and still take credit.
            void TryCompleteEngryss()
            {
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
}

void AddSC_instance_crescent_grove()
{
    new instance_crescent_grove();
}
