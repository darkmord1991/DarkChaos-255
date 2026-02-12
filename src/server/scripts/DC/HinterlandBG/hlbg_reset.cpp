// -----------------------------------------------------------------------------
// hlbg_reset.cpp
// -----------------------------------------------------------------------------
// Zone reset and teleport helpers:
// - HandleReset(): resets resources, clears AFK states, respawns NPCs/GOs, and
//   seeds a new match window + HUD updates.
// - TeleportPlayersToStart(): sends all players in the zone to their faction
//   base coordinates, then posts a zone text summary.
// - TeleportToTeamBase(): helper used by resets and AFK handling.
// -----------------------------------------------------------------------------
#include "hlbg.h"
#include "Chat.h"
#include "MapMgr.h"
#include "WorldSessionMgr.h"
#include "DC/HinterlandBG/hlbg_reset_worker.h"

namespace
{
    struct HLZoneResetCollectWorker
    {
        uint32 areaId;
        std::vector<ObjectGuid> creatureGuids;
        std::vector<ObjectGuid> gameObjectGuids;

        void Visit(std::unordered_map<ObjectGuid, Creature*>& creatureMap)
        {
            for (auto const& p : creatureMap)
            {
                Creature* c = p.second;
                if (!c || !c->IsInWorld())
                    continue;
                if (c->GetAreaId() != areaId)
                    continue;
                if (c->IsPlayer() || c->IsPet() || c->IsTotem() || c->IsGuardian() || c->IsSummon())
                    continue;

                creatureGuids.push_back(c->GetGUID());
            }
        }

        void Visit(std::unordered_map<ObjectGuid, GameObject*>& goMap)
        {
            for (auto const& p : goMap)
            {
                GameObject* go = p.second;
                if (!go || !go->IsInWorld())
                    continue;
                if (go->GetAreaId() != areaId)
                    continue;

                gameObjectGuids.push_back(go->GetGUID());
            }
        }

        template<class T>
        void Visit(std::unordered_map<ObjectGuid, T*>&) { }
    };
}

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
        uint32 const areaId = OutdoorPvPHLBattleAreaId;
        uint32 mapId = 0;
        if (Map* m = GetMap())
            mapId = m->GetId();
        uint32 totalCreatureCount = 0;
        uint32 totalGoCount = 0;

        sMapMgr->DoForAllMapsWithMapId(mapId, [&totalCreatureCount, &totalGoCount](Map* map)
        {
            HLZoneResetCollectWorker collector{};
            collector.areaId = OutdoorPvPHLBattleAreaId;
            map->VisitAllObjectStores([&](MapStoredObjectTypesContainer& objects)
            {
                TypeContainerVisitor<HLZoneResetCollectWorker, MapStoredObjectTypesContainer> visitor(collector);
                visitor.Visit(objects);
            });

            for (ObjectGuid const& guid : collector.creatureGuids)
            {
                Creature* c = map->GetCreature(guid);
                if (!c || !c->IsInWorld() || c->GetAreaId() != collector.areaId)
                    continue;

                c->CombatStop(true);
                c->GetThreatMgr().ClearAllThreat();
                c->RemoveAllAuras();
                float x, y, z, o;
                c->GetRespawnPosition(x, y, z, &o);
                c->NearTeleportTo(x, y, z, o, false);
                if (!c->IsAlive())
                    c->Respawn(true);
                c->SetFullHealth();
                ++totalCreatureCount;
            }

            for (ObjectGuid const& guid : collector.gameObjectGuids)
            {
                GameObject* go = map->GetGameObject(guid);
                if (!go || !go->IsInWorld() || go->GetAreaId() != collector.areaId)
                    continue;

                go->Respawn();
                ++totalGoCount;
            }
        });

    LOG_INFO("outdoorpvp.hl", "[HL] Reset: respawned {} creatures and {} gameobjects in area {}", totalCreatureCount, totalGoCount, areaId);
    }

    IS_ABLE_TO_SHOW_MESSAGE = false;
    IS_RESOURCE_MESSAGE_A = false;
    IS_RESOURCE_MESSAGE_H = false;
    _FirstLoad = false;
    limit_A = 0;
    limit_H = 0;
    limit_resources_message_A = 0;
    limit_resources_message_H = 0;

    _matchStartTime = NowSec();
    _matchEndTime = _matchStartTime + _matchDurationSeconds;
    // Clear per-player scoreboard for new match
    _playerScores.clear();
    _playerHKBaseline.clear();
    LOG_INFO("misc", "[OutdoorPvPHL]: Reset Hinterland BG");
    _winnerRecorded = false; // allow new winner recording for next match
    // If configured, pick a random affix for the new battle immediately
    // (weather will be synced if enabled)
    if (_affixEnabled && _affixRandomOnStart)
    {
        // clear any previous effects and choose a new one
        _clearAffixEffects();
        uint32 roll = urand(1, 6);
        _activeAffix = static_cast<AffixType>(roll);
        _applyAffixEffects();
        if (_affixWeatherEnabled)
            ApplyAffixWeather();
        if (_affixPeriodSec > 0)
        {
            _affixTimerMs = _affixPeriodSec * IN_MILLISECONDS;
            _affixNextChangeEpoch = NowSec() + _affixPeriodSec;
        }
        else
        {
            _affixTimerMs = 0;
            _affixNextChangeEpoch = 0;
        }
        // Start announcement with affix name
        if (_affixAnnounce)
        {
            const char* aff = "None";
            switch (_activeAffix) { case AFFIX_SUNLIGHT: aff = "Sunlight"; break; case AFFIX_CLEAR_SKIES: aff = "Clear Skies"; break; case AFFIX_GENTLE_BREEZE: aff = "Gentle Breeze"; break; case AFFIX_STORM: aff = "Storm"; break; case AFFIX_HEAVY_RAIN: aff = "Heavy Rain"; break; case AFFIX_FOG: aff = "Fog"; break; default: break; }
            if (Map* m = GetMap())
            {
                char line[160];
                snprintf(line, sizeof(line), "%sBattle restarted — current affix: %s", GetBgChatPrefix().c_str(), aff);
                m->SendZoneText(OutdoorPvPHLBuffZones[0], line);
            }
            // Global start-of-run announcement with affix
            {
                char gmsg[180];
                snprintf(gmsg, sizeof(gmsg), "[Hinterland BG] Battle restarted — current affix: %s", aff);
                uint32 now = NowSec();
                if (now - _lastGlobalAnnounceEpoch >= 3)
                {
                    ChatHandler(nullptr).SendGlobalSysMessage(gmsg);
                    _lastGlobalAnnounceEpoch = now;
                }
            }
        }
    }
    // HUD worldstates removed - now handled by addon\n    // UpdateWorldStatesAllPlayers();
    UpdateAffixWorldstateAll();
    // Deterministic client HUD update via addon whisper
    SendAffixAddonToZone();
    SendStatusAddonToZone();
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
    uint32 now = NowSec();
    if (Map* m = GetMap())
    {
        // Throttle zone-level reset text to once per second to avoid spam from concurrent resets
        if (now - _lastZoneAnnounceEpoch >= 1)
        {
            m->SendZoneText(zoneId, msg);
            _lastZoneAnnounceEpoch = now;
        }
    }
    // Optional global heads-up for the reset start (affix is chosen during HandleReset)
    // Throttle global messages to once every few seconds to avoid duplicate broadcasts
    if (now - _lastGlobalAnnounceEpoch >= 3)
    {
        ChatHandler(nullptr).SendGlobalSysMessage("[Hinterland BG] Resetting — teleporting players to their bases...");
        _lastGlobalAnnounceEpoch = now;
    }
}

// Teleport a single player to his/her faction base location.
void OutdoorPvPHL::TeleportToTeamBase(Player* player) const
{
    if (!player) return;
    HLBase const& b = (player->GetTeamId() == TEAM_HORDE) ? _baseHorde : _baseAlliance;
    player->TeleportTo(b.map, b.x, b.y, b.z, b.o);
}
