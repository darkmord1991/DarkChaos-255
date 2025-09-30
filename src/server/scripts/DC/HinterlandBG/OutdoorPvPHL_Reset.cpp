// -----------------------------------------------------------------------------
// OutdoorPvPHL_Reset.cpp
// -----------------------------------------------------------------------------
// Zone reset and teleport helpers:
// - HandleReset(): resets resources, clears AFK states, respawns NPCs/GOs, and
//   seeds a new match window + HUD updates.
// - TeleportPlayersToStart(): sends all players in the zone to their faction
//   base coordinates, then posts a zone text summary.
// - TeleportToTeamBase(): helper used by resets and AFK handling.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "MapMgr.h"
#include "WorldSessionMgr.h"
#include "DC/HinterlandBG/OutdoorPvPHLResetWorker.h"

// Reset match state and respawn zone actors (creatures/GOs) within the zone.
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
    // If configured, pick a random affix for the new battle immediately
    // (weather will be synced if enabled)
    if (_affixEnabled && _affixRandomOnStart)
    {
        // clear any previous effects and choose a new one
        _clearAffixEffects();
        uint32 roll = urand(1, 5);
        _activeAffix = static_cast<AffixType>(roll);
        _applyAffixEffects();
        if (_affixWeatherEnabled)
            _setAffixWeather();
        _affixTimerMs = std::max<uint32>(10, _affixPeriodSec) * IN_MILLISECONDS;
        _affixNextChangeEpoch = NowSec() + std::max<uint32>(10, _affixPeriodSec);
    }
    UpdateWorldStatesAllPlayers();
    _statusBroadcastTimerMs = 1;
}

// Teleport all players currently inside the Hinterlands to their faction bases.
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
    if (Map* m = GetMap())
        m->SendZoneText(zoneId, msg);
}

// Teleport a single player to his/her faction base location.
void OutdoorPvPHL::TeleportToTeamBase(Player* player) const
{
    if (!player) return;
    HLBase const& b = (player->GetTeamId() == TEAM_HORDE) ? _baseHorde : _baseAlliance;
    player->TeleportTo(b.map, b.x, b.y, b.z, b.o);
}
