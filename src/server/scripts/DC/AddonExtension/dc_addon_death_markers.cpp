#include "Common.h"
#include "dc_addon_death_markers.h"

#include "dc_addon_namespace.h"

#include "DC/CrossSystem/CrossSystemMapCoords.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Unit.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"

#include <algorithm>
#include <mutex>
#include <string>
#include <unordered_map>
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
            std::string environmentType; // e.g. "Falling", "Lava" (only set when killerType == "environment")
            uint32 killingBlowDamage = 0;
            std::string failureReason;

            uint32 mapId = 0;
            float nx = 0.0f;
            float ny = 0.0f;

            uint32 diedAt = 0;
            uint32 expiresAt = 0;
        };

        // Written from player-kill hooks (map-update worker threads) and read
        // from the world thread; every access must hold g_markersMutex.
        std::mutex g_markersMutex;
        std::vector<DeathMarker> g_markers;
        uint32 g_nextMarkerId = 1;

        // Caller must hold g_markersMutex.
        void PruneExpired(uint32 now)
        {
            g_markers.erase(
                std::remove_if(g_markers.begin(), g_markers.end(), [now](DeathMarker const& m)
                {
                    return m.expiresAt <= now;
                }),
                g_markers.end());
        }

        // Transient "what is about to kill this player" info, captured at the moment lethal
        // damage/cause is determined (Player::EnvironmentalDamage / Unit::DealDamage) and
        // consumed moments later by ResolveDeathContext(). Keyed by victim GUID counter.
        // Written from combat code (map-update worker threads); every access must hold g_pendingMutex.
        struct PendingDeathInfo
        {
            uint32 killingBlowDamage = 0;
            int16 environmentalType = -1; // -1 = none captured; else an EnviromentalDamage enum value
            uint32 notedAt = 0;
        };

        constexpr uint32 PENDING_TTL_SECONDS = 30;

        std::mutex g_pendingMutex;
        std::unordered_map<uint32, PendingDeathInfo> g_pending;

        // Caller must hold g_pendingMutex.
        void PrunePending(uint32 now)
        {
            for (auto it = g_pending.begin(); it != g_pending.end(); )
            {
                if (now - it->second.notedAt > PENDING_TTL_SECONDS)
                    it = g_pending.erase(it);
                else
                    ++it;
            }
        }

        void ClearPendingDeathInfo(uint32 guidCounter)
        {
            std::lock_guard<std::mutex> lock(g_pendingMutex);
            g_pending.erase(guidCounter);
        }

        char const* EnvironmentalTypeToString(uint8 type)
        {
            switch (type)
            {
                case DAMAGE_EXHAUSTED:    return "Fatigue";
                case DAMAGE_DROWNING:     return "Drowning";
                case DAMAGE_FALL:         return "Falling";
                case DAMAGE_LAVA:         return "Lava";
                case DAMAGE_SLIME:        return "Slime";
                case DAMAGE_FIRE:         return "Fire";
                case DAMAGE_FALL_TO_VOID: return "Falling";
                default:                  return "";
            }
        }

        Optional<std::pair<float, float>> TryGetNormalizedCoords(uint32 zoneId, float x, float y)
        {
            float nx = 0.0f;
            float ny = 0.0f;
            if (!DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(zoneId, x, y, nx, ny))
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
            if (!m.environmentType.empty())
                obj.Set("environmentType", JsonValue(m.environmentType));
            if (m.killingBlowDamage)
                obj.Set("killingBlowDamage", JsonValue(static_cast<int32>(m.killingBlowDamage)));
            if (!m.failureReason.empty())
                obj.Set("failureReason", JsonValue(m.failureReason));

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

        // Fire-and-forget persistence so markers survive a worldserver restart. Matches the
        // established local convention (raw escaped SQL, not PreparedStatement) used by the
        // sibling dc_character_challenge_mode_log / dc_prestige_challenges tables.
        void PersistMarker(DeathMarker const& m)
        {
            std::string modeIdEsc = m.modeId;
            CharacterDatabase.EscapeString(modeIdEsc);
            std::string modeLabelEsc = m.modeLabel;
            CharacterDatabase.EscapeString(modeLabelEsc);
            std::string victimNameEsc = m.victimName;
            CharacterDatabase.EscapeString(victimNameEsc);
            std::string killerTypeEsc = m.killerType;
            CharacterDatabase.EscapeString(killerTypeEsc);
            std::string killerNameEsc = m.killerName;
            CharacterDatabase.EscapeString(killerNameEsc);
            std::string environmentTypeEsc = m.environmentType;
            CharacterDatabase.EscapeString(environmentTypeEsc);
            std::string failureReasonEsc = m.failureReason;
            CharacterDatabase.EscapeString(failureReasonEsc);

            CharacterDatabase.Execute(
                "INSERT INTO dc_death_markers "
                "(mode_id, mode_label, victim_guid, victim_name, victim_level, victim_class, "
                "killer_type, killer_entry, killer_name, environment_type, killing_blow_damage, "
                "failure_reason, map_id, pos_x, pos_y, died_at, expires_at) "
                "VALUES ('{}', '{}', {}, '{}', {}, {}, '{}', {}, '{}', '{}', {}, '{}', {}, {}, {}, {}, {})",
                modeIdEsc, modeLabelEsc, m.victimGuid, victimNameEsc, m.victimLevel, m.victimClass,
                killerTypeEsc, m.killerEntry, killerNameEsc, environmentTypeEsc, m.killingBlowDamage,
                failureReasonEsc, m.mapId, m.nx, m.ny, m.diedAt, m.expiresAt);

            // Opportunistic cleanup, piggybacked on the same cadence as new deaths rather than a
            // separate scheduled task.
            CharacterDatabase.Execute("DELETE FROM dc_death_markers WHERE expires_at <= UNIX_TIMESTAMP()");
        }

        // Loads persisted, not-yet-expired markers into g_markers. Only meant to run once, from
        // WorldScript::OnStartup() before the world accepts any connections/updates, but still
        // takes g_markersMutex to keep every g_markers access uniformly guarded.
        void LoadPersistedMarkers()
        {
            uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

            QueryResult result = CharacterDatabase.Query(
                "SELECT id, mode_id, mode_label, victim_guid, victim_name, victim_level, victim_class, "
                "killer_type, killer_entry, killer_name, environment_type, killing_blow_damage, "
                "failure_reason, map_id, pos_x, pos_y, died_at, expires_at "
                "FROM dc_death_markers WHERE expires_at > {} ORDER BY id",
                now);

            if (!result)
                return;

            std::vector<DeathMarker> loaded;
            uint32 maxId = 0;
            do
            {
                Field* fields = result->Fetch();

                DeathMarker marker;
                marker.markerId = fields[0].Get<uint32>();
                marker.modeId = fields[1].Get<std::string>();
                marker.modeLabel = fields[2].Get<std::string>();
                marker.victimGuid = fields[3].Get<uint32>();
                marker.victimName = fields[4].Get<std::string>();
                marker.victimLevel = fields[5].Get<uint8>();
                marker.victimClass = fields[6].Get<uint8>();
                marker.killerType = fields[7].Get<std::string>();
                marker.killerEntry = fields[8].Get<uint32>();
                marker.killerName = fields[9].Get<std::string>();
                marker.environmentType = fields[10].Get<std::string>();
                marker.killingBlowDamage = fields[11].Get<uint32>();
                marker.failureReason = fields[12].Get<std::string>();
                marker.mapId = fields[13].Get<uint32>();
                marker.nx = fields[14].Get<float>();
                marker.ny = fields[15].Get<float>();
                marker.diedAt = fields[16].Get<uint32>();
                marker.expiresAt = fields[17].Get<uint32>();

                maxId = std::max(maxId, marker.markerId);
                loaded.push_back(std::move(marker));
            } while (result->NextRow());

            std::lock_guard<std::mutex> lock(g_markersMutex);
            for (DeathMarker& marker : loaded)
                g_markers.push_back(std::move(marker));
            g_nextMarkerId = std::max(g_nextMarkerId, maxId + 1);

            LOG_INFO("dc.addon", "DeathMarkers: loaded {} persisted marker(s) from dc_death_markers", loaded.size());
        }

    } // namespace

    void NotePendingEnvironmentalCause(Player* victim, uint8_t environmentalType)
    {
        if (!victim)
            return;

        uint32 guid = victim->GetGUID().GetCounter();
        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

        std::lock_guard<std::mutex> lock(g_pendingMutex);
        PrunePending(now);
        PendingDeathInfo& info = g_pending[guid];
        info.environmentalType = static_cast<int16>(environmentalType);
        info.notedAt = now;
    }

    void NotePendingKillingBlow(Player* victim, uint32_t damage)
    {
        if (!victim)
            return;

        uint32 guid = victim->GetGUID().GetCounter();
        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

        std::lock_guard<std::mutex> lock(g_pendingMutex);
        PrunePending(now);
        PendingDeathInfo& info = g_pending[guid];
        info.killingBlowDamage = damage;
        info.notedAt = now;
    }

    DeathContext ResolveDeathContext(Player* victim, Unit* killer)
    {
        DeathContext ctx;
        if (!victim)
            return ctx;

        uint32 guid = victim->GetGUID().GetCounter();
        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

        PendingDeathInfo pending;
        bool hasPending = false;
        {
            std::lock_guard<std::mutex> lock(g_pendingMutex);
            auto it = g_pending.find(guid);
            if (it != g_pending.end() && (now - it->second.notedAt) <= PENDING_TTL_SECONDS)
            {
                pending = it->second;
                hasPending = true;
            }
        }

        if (hasPending)
            ctx.killingBlowDamage = pending.killingBlowDamage;

        // Environmental self-damage routes through Unit::DealDamage(this, this, ...), so `killer`
        // is the victim itself (not nullptr) by the time Unit::Kill() fires PlayerScript hooks.
        bool selfInflicted = !killer || killer->GetGUID() == victim->GetGUID();

        if (!selfInflicted && killer->IsCreature())
        {
            ctx.killerType = "creature";
            ctx.killerEntry = killer->GetEntry();
            ctx.killerName = killer->GetName();
        }
        else if (!selfInflicted && killer->IsPlayer())
        {
            ctx.killerType = "player";
            ctx.killerName = killer->GetName();
        }
        else if (hasPending && pending.environmentalType >= 0)
        {
            ctx.killerType = "environment";
            ctx.environmentType = EnvironmentalTypeToString(static_cast<uint8>(pending.environmentalType));
        }
        else
        {
            ctx.killerType = "unknown";
        }

        return ctx;
    }

    void RecordChallengeDeath(Player* victim, Unit* killer, char const* modeId, char const* modeLabel, char const* failureReason)
    {
        if (!victim)
            return;

        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

        DeathMarker marker;
        marker.modeId = modeId ? modeId : "challenge";
        marker.modeLabel = modeLabel ? modeLabel : "Challenge";
        marker.failureReason = failureReason ? failureReason : "Died.";

        marker.victimGuid = victim->GetGUID().GetCounter();
        marker.victimName = victim->GetName();
        marker.victimLevel = static_cast<uint8>(victim->GetLevel());
        marker.victimClass = static_cast<uint8>(victim->getClass());

        // Note: for client display, mapId is the server zone/area id.
        marker.mapId = victim->GetZoneId();
        marker.diedAt = now;
        marker.expiresAt = now + MARKER_TTL_SECONDS;

        DeathContext ctx = ResolveDeathContext(victim, killer);
        marker.killerType = ctx.killerType;
        marker.killerEntry = ctx.killerEntry;
        marker.killerName = ctx.killerName;
        marker.environmentType = ctx.environmentType;
        marker.killingBlowDamage = ctx.killingBlowDamage;

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

        {
            std::lock_guard<std::mutex> lock(g_markersMutex);
            PruneExpired(now);
            marker.markerId = g_nextMarkerId++;
            g_markers.push_back(marker);
        }

        PersistMarker(marker);
        BroadcastNewMarker(marker);
        ClearPendingDeathInfo(marker.victimGuid);
    }

    JsonValue BuildDeathMarkersArray()
    {
        JsonValue arr; arr.SetArray();
        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

        std::lock_guard<std::mutex> lock(g_markersMutex);
        PruneExpired(now);

        for (DeathMarker const& m : g_markers)
            arr.Push(Serialize(m));

        return arr;
    }

} // namespace DeathMarkers
} // namespace DCAddon

class DeathMarkersWorldScript : public WorldScript
{
public:
    DeathMarkersWorldScript() : WorldScript("DeathMarkersWorldScript") { }

    void OnStartup() override
    {
        DCAddon::DeathMarkers::LoadPersistedMarkers();
    }
};

void AddSC_dc_addon_death_markers()
{
    new DeathMarkersWorldScript();
}
