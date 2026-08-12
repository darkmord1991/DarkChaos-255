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

// Emerald Sanctum (map 824) -- a compact 20-man raid whose replay value comes from a
// ROTATING final boss rather than from length.
//
// Two encounters only: Erennius, then "The Wakener" -- which is one of four corrupted green
// dragons, decided by the week. All four share a single DungeonEncounter (1121) so the M+ HUD
// and boss counters read 2 whichever one is present.
//
// WHY THE ROTATION IS DRIVEN FROM HERE AND NOT FROM A SPAWN TOGGLE
//
// The obvious approach -- copy SetWorldBossActive() from dc_giant_isles_zone.cpp -- cannot
// work. That resolves the spawn through sMapMgr->FindMap(mapId, 0), i.e. instance id 0, so it
// only ever finds the base map. It is correct for Giant Isles because that zone is open world.
// An instanced raid needs the decision made per instance, which is what this script does.
//
// It leans on upstream's pooling-in-instances support (df93fae2e1, PR #27001): Map's
// constructor calls PoolMgr::InitPoolsForMap, so every instance owns its own SpawnedPoolData
// and rolls its own pools. Child pools (those with a pool_pool row) never auto-spawn, so the
// four Wakener pools stay dormant until this script picks one.

#include "Creature.h"
#include "InstanceMapScript.h"
#include "InstanceScript.h"
#include "Log.h"
#include "Map.h"
#include "PoolMgr.h"
#include "ScriptMgr.h"
#include "DCWeeklyResetHub.h"

namespace
{
    constexpr uint32 MAP_EMERALD_SANCTUM = 824;

    constexpr char const* DataHeader = "EMSA";

    enum Data
    {
        DATA_ERENNIUS  = 0,
        DATA_WAKENER   = 1,
        MAX_ENCOUNTERS = 2
    };

    enum CreatureIds
    {
        NPC_ERENNIUS = 4030001,
        NPC_YSONDRE  = 4030002,
        NPC_LETHON   = 4030003,
        NPC_EMERISS  = 4030004,
        NPC_TAERAR   = 4030005
    };

    // Parent pool holds the four Wakener child pools with max_limit 1. The children are
    // pool_pool members, so PoolMgr skips them at auto-spawn time (PoolMgr.cpp: "Don't spawn
    // child pools, they are spawned recursively by their parent pools").
    constexpr uint32 POOL_WAKENER_PARENT = 300009;
    constexpr uint32 POOL_WAKENER_FIRST  = 300010;
    constexpr uint32 WAKENER_COUNT       = 4;

    constexpr uint32 SECONDS_PER_WEEK = 7 * 24 * 60 * 60;

    /// Index of the Wakener that owns the current week. Shares its boundary with the vault and
    /// the lockouts, so "this week's Wakener" flips at the same instant everything else resets.
    uint32 CurrentWakenerIndex()
    {
        uint32 const weekStart = DarkChaos::Seasons::GetVaultWeekStartTimestamp();
        return (weekStart / SECONDS_PER_WEEK) % WAKENER_COUNT;
    }

    class instance_emerald_sanctum : public InstanceMapScript
    {
    public:
        instance_emerald_sanctum() : InstanceMapScript("instance_emerald_sanctum", MAP_EMERALD_SANCTUM) { }

        struct instance_emerald_sanctum_InstanceMapScript : public InstanceScript
        {
            instance_emerald_sanctum_InstanceMapScript(Map* map) : InstanceScript(map)
            {
                SetHeaders(DataHeader);
                SetBossNumber(MAX_ENCOUNTERS);
                _wakenerIndex = CurrentWakenerIndex();
                _wakenerSpawned = false;
            }

            void OnPlayerEnter(Player* /*player*/) override
            {
                // Deferred to first entry rather than done in the constructor: the map's own
                // SpawnedPoolData is built by Map's constructor, and touching it from an
                // InstanceScript constructor would race that.
                EnsureWakenerSpawned();
            }

            void EnsureWakenerSpawned()
            {
                if (_wakenerSpawned)
                    return;

                Map* map = instance;
                if (!map)
                    return;

                // Clear whatever the parent pool may have rolled, then force this week's child.
                sPoolMgr->DespawnPool(map->GetPoolData(), POOL_WAKENER_PARENT);
                sPoolMgr->SpawnPool(map->GetPoolData(), POOL_WAKENER_FIRST + _wakenerIndex);
                _wakenerSpawned = true;

                LOG_DEBUG("scripts.dc", "Emerald Sanctum instance {}: week index {} -> pool {}",
                    map->GetInstanceId(), _wakenerIndex, POOL_WAKENER_FIRST + _wakenerIndex);
            }

            /// Any of the four credits the same encounter. instance_encounters keys on a single
            /// creditEntry, so the auto-credit path would only ever fire for one of them.
            void OnUnitDeath(Unit* unit) override
            {
                Creature* creature = unit ? unit->ToCreature() : nullptr;
                if (!creature)
                    return;

                switch (creature->GetEntry())
                {
                    case NPC_ERENNIUS:
                        SetBossState(DATA_ERENNIUS, DONE);
                        break;
                    case NPC_YSONDRE:
                    case NPC_LETHON:
                    case NPC_EMERISS:
                    case NPC_TAERAR:
                        SetBossState(DATA_WAKENER, DONE);
                        break;
                    default:
                        break;
                }
            }

            void ReadSaveDataMore(std::istringstream& data) override
            {
                data >> _wakenerIndex;
            }

            void WriteSaveDataMore(std::ostringstream& data) override
            {
                // Persisted so a saved instance keeps the Wakener it was created with, even if
                // the week rolls over while the raid is still saved to it.
                data << _wakenerIndex << ' ';
            }

        private:
            uint32 _wakenerIndex;
            bool _wakenerSpawned;
        };

        InstanceScript* GetInstanceScript(InstanceMap* map) const override
        {
            return new instance_emerald_sanctum_InstanceMapScript(map);
        }
    };
}

void AddSC_instance_emerald_sanctum()
{
    new instance_emerald_sanctum();
}
