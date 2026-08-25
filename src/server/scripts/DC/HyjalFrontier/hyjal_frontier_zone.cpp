/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Hyjal Frontier (map 750) - zone-wide hooks.
 *
 * STATUS: still a deliberate no-op. Audited 2026-07-20 -- the hooks themselves
 * are correct and harmless; what is missing is CONTENT, not code, and each item
 * is blocked on a specific asset that does not exist yet:
 *
 *   - "Emberwood Pilgrim" aura (XP-curve bonus while in the zone):
 *     BLOCKED. There is no Emberwood spell in `spell_dbc` at all (checked by
 *     name). Needs a custom spell authored + a client-side Spell.dbc row before
 *     anything can be cast here -- see the CSV-DBC pipeline.
 *   - Welcome broadcast / zone-entry announce + ambience:
 *     BLOCKED on the text itself; no strings written. Wire through the DC
 *     broadcast system once they exist.
 *   - Safe-respawn clamping for invalid coordinates:
 *     Not started. Only worth doing if bad spawn coords actually show up.
 *
 * Do NOT "implement" these by inventing a spell id or announce text -- the ids
 * have to exist in the DB/DBC first or the cast silently no-ops.
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
    hyjal_frontier_zone() : PlayerScript("hyjal_frontier_zone", { PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_UPDATE_ZONE }) { }

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
