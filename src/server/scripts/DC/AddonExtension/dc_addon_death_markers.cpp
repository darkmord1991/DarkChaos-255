#include "Common.h"
#include "dc_addon_death_markers.h"

#include "dc_addon_namespace.h"

#include "DC/CrossSystem/CrossSystemMapCoords.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Unit.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"

#include <algorithm>
#include <string>
#include <vector>

namespace DCAddon
{
namespace DeathMarkers
{
    namespace
    {
        constexpr uint32 MARKER_TTL_SECONDS = 24 * 60 * 60;

        struct DeathMarker
        {
            uint32 markerId = 0;
            std::string modeId;
            std::string modeLabel;

            uint32 victimGuid = 0;
            std::string victimName;
            uint8 victimLevel = 0;
            uint8 victimClass = 0;

            std::string killerType; // "creature" | "player" | "environment" | "unknown"
            uint32 killerEntry = 0;
            std::string killerName;

            uint32 mapId = 0;
            float nx = 0.0f;
            float ny = 0.0f;

            uint32 diedAt = 0;
            uint32 expiresAt = 0;
        };

        std::vector<DeathMarker> g_markers;
        uint32 g_nextMarkerId = 1;

        void PruneExpired(uint32 now)
        {
            g_markers.erase(
                std::remove_if(g_markers.begin(), g_markers.end(), [now](DeathMarker const& m)
                {
                    return m.expiresAt <= now;
                }),
                g_markers.end());
        }

        Optional<std::pair<float, float>> TryGetNormalizedCoords(uint32 zoneId, float x, float y)
        {
            float nx = 0.0f;
            float ny = 0.0f;
            if (!DC::MapCoords::TryComputeNormalized(zoneId, x, y, nx, ny))
                return {};

            return std::make_pair(nx, ny);
        }

        JsonValue Serialize(DeathMarker const& m)
        {
            JsonValue obj; obj.SetObject();
            obj.Set("markerId", JsonValue(static_cast<int32>(m.markerId)));
            obj.Set("modeId", JsonValue(m.modeId));
            obj.Set("modeLabel", JsonValue(m.modeLabel));

            obj.Set("victimGuid", JsonValue(static_cast<int32>(m.victimGuid)));
            obj.Set("victimName", JsonValue(m.victimName));
            obj.Set("victimLevel", JsonValue(static_cast<int32>(m.victimLevel)));
            obj.Set("victimClass", JsonValue(static_cast<int32>(m.victimClass)));

            obj.Set("killerType", JsonValue(m.killerType));
            if (m.killerEntry)
                obj.Set("killerEntry", JsonValue(static_cast<int32>(m.killerEntry)));
            if (!m.killerName.empty())
                obj.Set("killerName", JsonValue(m.killerName));

            obj.Set("mapId", JsonValue(static_cast<int32>(m.mapId)));
            obj.Set("nx", JsonValue(m.nx));
            obj.Set("ny", JsonValue(m.ny));

            obj.Set("diedAt", JsonValue(static_cast<int32>(m.diedAt)));
            obj.Set("expiresAt", JsonValue(static_cast<int32>(m.expiresAt)));
            return obj;
        }

        void BroadcastNewMarker(DeathMarker const& marker)
        {
            JsonValue one; one.SetArray();
            one.Push(Serialize(marker));

            JsonMessage upd(Module::WORLD, Opcode::World::SMSG_UPDATE);
            upd.Set("deaths", one);

            auto const& sessions = sWorldSessionMgr->GetAllSessions();
            for (auto const& pair : sessions)
            {
                if (WorldSession* session = pair.second)
                {
                    if (Player* player = session->GetPlayer())
                    {
                        if (player->IsInWorld())
                            upd.Send(player);
                    }
                }
            }
        }

    } // namespace

    void RecordChallengeDeath(Player* victim, Unit* killer, char const* modeId, char const* modeLabel)
    {
        if (!victim)
            return;

        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());
        PruneExpired(now);

        DeathMarker marker;
        marker.markerId = g_nextMarkerId++;
        marker.modeId = modeId ? modeId : "challenge";
        marker.modeLabel = modeLabel ? modeLabel : "Challenge";

        marker.victimGuid = victim->GetGUID().GetCounter();
        marker.victimName = victim->GetName();
        marker.victimLevel = static_cast<uint8>(victim->GetLevel());
        marker.victimClass = static_cast<uint8>(victim->getClass());

        // Note: for client display, mapId is the server zone/area id.
        marker.mapId = victim->GetZoneId();
        marker.diedAt = now;
        marker.expiresAt = now + MARKER_TTL_SECONDS;

        // Killer info
        if (!killer)
        {
            marker.killerType = "unknown";
        }
        else if (killer->GetTypeId() == TYPEID_UNIT)
        {
            marker.killerType = "creature";
            marker.killerEntry = killer->GetEntry();
            marker.killerName = killer->GetName();
        }
        else if (killer->GetTypeId() == TYPEID_PLAYER)
        {
            marker.killerType = "player";
            marker.killerName = killer->GetName();
        }
        else
        {
            marker.killerType = "environment";
        }

        // Position -> nx/ny (0..1)
        float x = victim->GetPositionX();
        float y = victim->GetPositionY();
        if (auto norm = TryGetNormalizedCoords(marker.mapId, x, y))
        {
            marker.nx = norm->first;
            marker.ny = norm->second;
        }
        else
        {
            // If we can't normalize, we still record but it won't be placeable on the client map.
            marker.nx = 0.0f;
            marker.ny = 0.0f;
        }

        g_markers.push_back(marker);
        BroadcastNewMarker(marker);
    }

    JsonValue BuildDeathMarkersArray()
    {
        JsonValue arr; arr.SetArray();
        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());
        PruneExpired(now);

        for (DeathMarker const& m : g_markers)
            arr.Push(Serialize(m));

        return arr;
    }

} // namespace DeathMarkers
} // namespace DCAddon
