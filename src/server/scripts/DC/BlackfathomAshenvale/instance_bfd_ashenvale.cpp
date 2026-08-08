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

// Instance script for the Blackfathom Deeps clone on map 820 -- the Ashenvale-band
// (92-96 normal, 130 heroic/mythic) copy that the map-750 continent leads into.
//
// This is a straight port of Kalimdor/BlackfathomDeeps/instance_blackfathom_deeps.cpp.
// It has to be a separate registration because InstanceMapScript binds the map id in its
// constructor -- "instance_blackfathom_deeps" is nailed to map 48 and can never fire on 820.
// The creature and gameobject ids differ by the clone offsets used in the SQL:
//   creature   +3,900,000   (Custom/Custom feature SQLs/worlddb/BlackfathomAshenvale/01)
//   gameobject +4,400,000
//
// Behaviour is intentionally identical to the original: light all four Fire of Aku'mai
// braziers, kill every add they summon, and the Portal of Aku'Mai opens.

#include "InstanceMapScript.h"
#include "InstanceScript.h"

namespace
{
    constexpr uint32 MAP_BFD_ASHENVALE = 820;

    constexpr char const* DataHeader = "BFDA";

    enum Data
    {
        TYPE_GELIHAST      = 0,
        TYPE_FIRE1         = 1,
        TYPE_FIRE2         = 2,
        TYPE_FIRE3         = 3,
        TYPE_FIRE4         = 4,
        TYPE_AKU_MAI_EVENT = 5,
        TYPE_AKU_MAI       = 6,
        MAX_ENCOUNTERS     = 7
    };

    // originals 4825 / 4977 / 4978 / 4823 plus the +3,900,000 creature offset
    enum CreatureIds
    {
        NPC_AKU_MAI_SNAPJAW       = 3904825,
        NPC_MURKSHALLOW_SOFTSHELL = 3904977,
        NPC_AKU_MAI_SERVANT       = 3904978,
        NPC_BARBED_CRUSTACEAN     = 3904823
    };

    // originals 103015 / 21118-21121 / 21117 / 103016 plus the +4,400,000 gameobject offset
    enum GameObjectIds
    {
        GO_SHRINE_OF_GELIHAST = 4503015,
        GO_FIRE_OF_AKU_MAI_1  = 4421118,
        GO_FIRE_OF_AKU_MAI_2  = 4421119,
        GO_FIRE_OF_AKU_MAI_3  = 4421120,
        GO_FIRE_OF_AKU_MAI_4  = 4421121,
        GO_AKU_MAI_DOOR       = 4421117,
        GO_ALTAR_OF_THE_DEEPS = 4503016
    };
}

class instance_bfd_ashenvale : public InstanceMapScript
{
public:
    instance_bfd_ashenvale() : InstanceMapScript("instance_bfd_ashenvale", MAP_BFD_ASHENVALE) { }

    InstanceScript* GetInstanceScript(InstanceMap* map) const override
    {
        return new instance_bfd_ashenvale_InstanceMapScript(map);
    }

    struct instance_bfd_ashenvale_InstanceMapScript : public InstanceScript
    {
        instance_bfd_ashenvale_InstanceMapScript(Map* map) : InstanceScript(map) { }

        void Initialize() override
        {
            SetHeaders(DataHeader);
            memset(&_encounters, 0, sizeof(_encounters));
            _requiredDeaths = 0;
        }

        void OnCreatureCreate(Creature* creature) override
        {
            if (creature->IsSummon() && (creature->GetEntry() == NPC_BARBED_CRUSTACEAN || creature->GetEntry() == NPC_AKU_MAI_SERVANT ||
                                         creature->GetEntry() == NPC_MURKSHALLOW_SOFTSHELL || creature->GetEntry() == NPC_AKU_MAI_SNAPJAW))
                ++_requiredDeaths;
        }

        void OnUnitDeath(Unit* unit) override
        {
            if (unit->IsSummon() && (unit->GetEntry() == NPC_BARBED_CRUSTACEAN || unit->GetEntry() == NPC_AKU_MAI_SERVANT ||
                                     unit->GetEntry() == NPC_MURKSHALLOW_SOFTSHELL || unit->GetEntry() == NPC_AKU_MAI_SNAPJAW))
            {
                if (--_requiredDeaths == 0)
                {
                    if (IsFireEventDone())
                    {
                        HandleGameObject(_akumaiPortalGUID, true);
                        _encounters[TYPE_AKU_MAI_EVENT] = DONE;
                    }
                }
            }
        }

        void OnGameObjectCreate(GameObject* gameobject) override
        {
            switch (gameobject->GetEntry())
            {
                case GO_FIRE_OF_AKU_MAI_1:
                case GO_FIRE_OF_AKU_MAI_2:
                case GO_FIRE_OF_AKU_MAI_3:
                case GO_FIRE_OF_AKU_MAI_4:
                    if (_encounters[TYPE_AKU_MAI_EVENT] == DONE)
                    {
                        gameobject->SetGameObjectFlag(GO_FLAG_IN_USE);
                        gameobject->SetGoState(GO_STATE_ACTIVE);
                    }
                    break;
                case GO_SHRINE_OF_GELIHAST:
                    if (_encounters[TYPE_GELIHAST] == DONE)
                        gameobject->RemoveGameObjectFlag(GO_FLAG_NOT_SELECTABLE);
                    break;
                case GO_ALTAR_OF_THE_DEEPS:
                    if (_encounters[TYPE_AKU_MAI] == DONE)
                        gameobject->RemoveGameObjectFlag(GO_FLAG_NOT_SELECTABLE);
                    break;
                case GO_AKU_MAI_DOOR:
                    if (IsFireEventDone() && _encounters[TYPE_AKU_MAI_EVENT] == DONE)
                        HandleGameObject(ObjectGuid::Empty, true, gameobject);
                    _akumaiPortalGUID = gameobject->GetGUID();
                    break;
            }
        }

        void SetData(uint32 type, uint32 data) override
        {
            switch (type)
            {
                case TYPE_GELIHAST:
                case TYPE_FIRE1:
                case TYPE_FIRE2:
                case TYPE_FIRE3:
                case TYPE_FIRE4:
                case TYPE_AKU_MAI:
                case TYPE_AKU_MAI_EVENT:
                    _encounters[type] = data;
                    break;
            }

            if (data == DONE)
                SaveToDB();
        }

        void ReadSaveDataMore(std::istringstream& data) override
        {
            data >> _encounters[0];
            data >> _encounters[1];
            data >> _encounters[2];
            data >> _encounters[3];
            data >> _encounters[4];
            data >> _encounters[5];
        }

        void WriteSaveDataMore(std::ostringstream& data) override
        {
            data << _encounters[0] << ' '
                << _encounters[1] << ' '
                << _encounters[2] << ' '
                << _encounters[3] << ' '
                << _encounters[4] << ' '
                << _encounters[5];
        }

        bool IsFireEventDone()
        {
            return _encounters[TYPE_FIRE1] == DONE && _encounters[TYPE_FIRE2] == DONE && _encounters[TYPE_FIRE3] == DONE && _encounters[TYPE_FIRE4] == DONE;
        }

    private:
        uint32 _encounters[MAX_ENCOUNTERS];
        ObjectGuid _akumaiPortalGUID;
        uint8 _requiredDeaths;
    };
};

void AddSC_instance_bfd_ashenvale()
{
    new instance_bfd_ashenvale();
}
