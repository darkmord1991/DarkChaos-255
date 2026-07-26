/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Hyjal Frontier (map 750) - zone-wide hooks.
 *
 * Responsibilities (stubbed):
 *   - OnMapChange: welcome broadcast + safe-respawn clamping for invalid
 *     coordinates.
 *   - OnUpdateZone: zone entry announce / ambience.
 *   - OnPlayerEnterMap: grant the "Emberwood Pilgrim" aura (custom buff for
 *     XP curve bonus while inside the zone).
 *
 * All logic is intentionally TODO'd so this file compiles as a no-op until
 * the zone is actually balanced.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Map.h"
#include "Log.h"

namespace Hyjal
{
    // Retargeted from the superseded map 1410 `Hyjal130` clone to the Cata
    // downport that actually carries the content.
    //
    // There are no sub-zones to switch on: the DC terrain downport bakes ONE
    // uniform area id per map into every MCNK, so map 750 always reports 4923
    // and map 861 always reports 4925. The old 6101-6106 tier constants had no
    // in-world counterpart here and were removed rather than left dangling.
    // Same reasoning and the same ids as `DCHyjalAreas` in
    // src/server/scripts/DC/MountHyjal/zone_mount_hyjal.cpp.
    static constexpr uint32 MAP_HYJAL_FRONTIER  = 750;
    static constexpr uint32 MAP_MOLTEN_FRONT    = 861;
    static constexpr uint32 ZONE_HYJAL_FRONTIER = 4923;
    static constexpr uint32 ZONE_MOLTEN_FRONT   = 4925;

    inline bool IsHyjalMap(uint32 mapId)
    {
        return mapId == MAP_HYJAL_FRONTIER || mapId == MAP_MOLTEN_FRONT;
    }
}

class hyjal_frontier_zone : public PlayerScript
{
public:
    hyjal_frontier_zone() : PlayerScript("hyjal_frontier_zone") { }

    void OnPlayerMapChanged(Player* player) override
    {
        if (!player || !player->GetMap())
            return;

        if (!Hyjal::IsHyjalMap(player->GetMapId()))
            return;

        // TODO: welcome broadcast (DC broadcast system).
        // TODO: start the Emberwood Pilgrim aura.
        LOG_DEBUG("scripts.dc", "HyjalFrontier: player {} entered map {}",
            player->GetName(), player->GetMapId());
    }

    void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 /*newArea*/) override
    {
        if (!player || !Hyjal::IsHyjalMap(player->GetMapId()))
            return;

        switch (newZone)
        {
            case Hyjal::ZONE_HYJAL_FRONTIER:
            case Hyjal::ZONE_MOLTEN_FRONT:
                // TODO: zone entry announce + ambience.
                break;
            default:
                break;
        }
    }
};

void AddSC_hyjal_frontier_zone()
{
    new hyjal_frontier_zone();
}
