/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Hyjal Frontier (map 1410) - zone-wide hooks.
 *
 * Responsibilities (stubbed):
 *   - OnMapChange: welcome broadcast + safe-respawn clamping for invalid
 *     coordinates (pre-Noggit finalization).
 *   - OnUpdateZone: per-tier weather (Scorched Groves = fire storm, Nordrassil
 *     Roots = calm, etc.).
 *   - OnPlayerEnterMap: grant the "Emberwood Pilgrim" aura (custom buff for
 *     XP curve bonus while inside map 1410).
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
    // Keep these in sync with AreaTable.dbc rows 6100-6106.
    static constexpr uint32 MAP_HYJAL_FRONTIER  = 1410;
    static constexpr uint32 ZONE_HYJAL_FRONTIER = 6100;
    static constexpr uint32 ZONE_FOOTHILLS      = 6101;
    static constexpr uint32 ZONE_SCORCHED       = 6102;
    static constexpr uint32 ZONE_SUMMIT         = 6103;
    static constexpr uint32 ZONE_NORDRASSIL     = 6104;
    static constexpr uint32 ZONE_JAINA_CAMP     = 6105;
    static constexpr uint32 ZONE_THRALL_CAMP    = 6106;
}

class hyjal_frontier_zone : public PlayerScript
{
public:
    hyjal_frontier_zone() : PlayerScript("hyjal_frontier_zone") { }

    void OnPlayerMapChanged(Player* player) override
    {
        if (!player || !player->GetMap())
            return;

        if (player->GetMapId() != Hyjal::MAP_HYJAL_FRONTIER)
            return;

        // TODO: welcome broadcast (DC broadcast system).
        // TODO: start the Emberwood Pilgrim aura.
        LOG_DEBUG("scripts.dc", "HyjalFrontier: player {} entered map {}",
            player->GetName(), player->GetMapId());
    }

    void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 /*newArea*/) override
    {
        if (!player || player->GetMapId() != Hyjal::MAP_HYJAL_FRONTIER)
            return;

        switch (newZone)
        {
            case Hyjal::ZONE_HYJAL_FRONTIER:
            case Hyjal::ZONE_FOOTHILLS:
            case Hyjal::ZONE_SCORCHED:
            case Hyjal::ZONE_SUMMIT:
            case Hyjal::ZONE_NORDRASSIL:
            case Hyjal::ZONE_JAINA_CAMP:
            case Hyjal::ZONE_THRALL_CAMP:
                // TODO: per-tier weather + tier entry announce.
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
