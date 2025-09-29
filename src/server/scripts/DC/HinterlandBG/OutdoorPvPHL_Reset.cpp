#include "HinterlandBG.h"
#include "MapMgr.h"
#include "WorldSessionMgr.h"
#include "DC/HinterlandBG/OutdoorPvPHLResetWorker.h"

void OutdoorPvPHL::HandleReset()
{
    // Reset match state to defaults and respawn NPCs and GOs in the Hinterlands zone.
    _ally_gathered = _initialResourcesAlliance;
    _horde_gathered = _initialResourcesHorde;
    _LastWin = 0;
    // Clear AFK flags and local trackers
    _afkInfractions.clear();
    _afkFlagged.clear();
    _memberOfflineSince.clear();

    {
        uint32 const zoneId = OutdoorPvPHLBuffZones[0];
        uint32 mapId = 0;
        if (Map* m = GetMap())
            mapId = m->GetId();
        uint32 totalCreatureCount = 0;
        uint32 totalGoCount = 0;

        sMapMgr->DoForAllMapsWithMapId(mapId, [zoneId, &totalCreatureCount, &totalGoCount](Map* map)
        {
            HLZoneResetWorker worker{ zoneId };
            TypeContainerVisitor<HLZoneResetWorker, MapStoredObjectTypesContainer> visitor(worker);
            visitor.Visit(map->GetObjectsStore());
            totalCreatureCount += worker.creatureCount;
            totalGoCount += worker.goCount;
        });

        LOG_INFO("outdoorpvp.hl", "[HL] Reset: respawned %u creatures and %u gameobjects in zone %u", totalCreatureCount, totalGoCount, zoneId);
    }

    IS_ABLE_TO_SHOW_MESSAGE = false;
    IS_RESOURCE_MESSAGE_A = false;
    IS_RESOURCE_MESSAGE_H = false;
    _FirstLoad = false;
    limit_A = 0;
    limit_H = 0;
    limit_resources_message_A = 0;
    limit_resources_message_H = 0;

    _matchEndTime = NowSec() + _matchDurationSeconds;
    LOG_INFO("misc", "[OutdoorPvPHL]: Reset Hinterland BG");
    UpdateWorldStatesAllPlayers();
    _statusBroadcastTimerMs = 1;
}

void OutdoorPvPHL::TeleportPlayersToStart()
{
    uint32 const zoneId = OutdoorPvPHLBuffZones[0];
    uint32 countA = 0, countH = 0;
    ForEachPlayerInZone([&](Player* p){
        TeamId team = p->GetTeamId();
        TeleportToTeamBase(p);
        if (team == TEAM_ALLIANCE) ++countA; else ++countH;
    });
    char msg[128];
    snprintf(msg, sizeof(msg), "Hinterland BG: Resetting — sent %u Alliance and %u Horde to their bases.", (unsigned)countA, (unsigned)countH);
    sWorldSessionMgr->SendZoneText(zoneId, msg);
}

void OutdoorPvPHL::TeleportToTeamBase(Player* player) const
{
    if (!player) return;
    HLBase const& b = (player->GetTeamId() == TEAM_HORDE) ? _baseHorde : _baseAlliance;
    player->TeleportTo(b.map, b.x, b.y, b.z, b.o);
}
