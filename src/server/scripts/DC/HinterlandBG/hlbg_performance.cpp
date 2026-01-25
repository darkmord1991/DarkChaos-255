// -----------------------------------------------------------------------------
// hlbg_performance.cpp
// -----------------------------------------------------------------------------
// Performance optimizations for HLBG system including session caching,
// batched operations, and efficient player iteration patterns.
// -----------------------------------------------------------------------------
#include "hlbg.h"
#include "Player.h"
#include "WorldSessionMgr.h"
#include "ObjectAccessor.h"
#include "WorldStateDefines.h"
#include "Creature.h"
#include "Map.h"
#include "Chat.h"
#include "Log.h"
#include "hlbg_constants.h"
#include <vector>
#include <unordered_set>

// Cached zone players to avoid expensive GetAllSessions() calls
struct ZonePlayerCache
{
    std::vector<ObjectGuid> playerGuids;
    uint32 lastUpdateTime;
};

static ZonePlayerCache s_zonePlayerCache;

// Efficient zone player collection with caching
void OutdoorPvPHL::CollectZonePlayers(std::vector<Player*>& players) const
{
    uint32 currentTime = GameTime::GetGameTimeMS().count();

    // Check if cache needs refresh
    if (currentTime - s_zonePlayerCache.lastUpdateTime > HinterlandBGConstants::CACHE_DURATION_MS)
    {
        s_zonePlayerCache.playerGuids.clear();

        // Use the OutdoorPvP's internal player tracking instead of GetAllSessions()
        for (uint8 team = 0; team < 2; ++team)
        {
            for (const ObjectGuid& playerGuid : _players[team])
            {
                if (Player* player = ObjectAccessor::FindConnectedPlayer(playerGuid))
                {
                    if (player->IsInWorld() && player->GetZoneId() == OutdoorPvPHLBuffZones[0])
                    {
                        s_zonePlayerCache.playerGuids.push_back(playerGuid);
                    }
                }
            }
        }

        s_zonePlayerCache.lastUpdateTime = currentTime;
    }

    // Convert cached GUIDs to Player pointers
    players.clear();
    players.reserve(s_zonePlayerCache.playerGuids.size());

    for (const ObjectGuid& guid : s_zonePlayerCache.playerGuids)
    {
        if (Player* player = ObjectAccessor::FindConnectedPlayer(guid))
        {
            if (player->IsInWorld() && player->GetZoneId() == OutdoorPvPHLBuffZones[0])
            {
                players.push_back(player);
            }
        }
    }
}

// Optimized version of PlaySounds that uses cached players
void OutdoorPvPHL::PlaySoundsOptimized(bool side)
{
    std::vector<Player*> zonePlayers;
    CollectZonePlayers(zonePlayers);

    for (Player* player : zonePlayers)
    {
        if (player->GetTeamId() == TEAM_ALLIANCE && side == true)
        {
            player->PlayDirectSound(8212, player);
        }
        else if (player->GetTeamId() == TEAM_HORDE && side == false)
        {
            player->PlayDirectSound(8174, player);
        }
    }
}

// Efficient worldstate broadcast using batching
void OutdoorPvPHL::UpdateWorldStatesAllPlayersOptimized()
{
    std::vector<Player*> zonePlayers;
    CollectZonePlayers(zonePlayers);

    // Batch worldstate updates to reduce per-player overhead
    struct WorldStateUpdate
    {
        uint32 stateId;
        uint32 value;
    };

    std::vector<WorldStateUpdate> updates;
    updates.reserve(10); // Typical number of worldstates

    // Use Wintergrasp worldstates (WG-like HUD for HLBG).
    // Keep this consistent with FillInitialWorldStates()/UpdateWorldStatesForPlayer:
    // - CLOCK/CLOCK_TEXTS use an absolute end-epoch (not seconds remaining)
    // - VEHICLE_* carry resources
    // - ACTIVE=0 indicates wartime (per WG implementation)
    uint32 endEpoch = GetHudEndEpoch();
    uint32 hordeRes = GetResources(TEAM_HORDE);
    uint32 allianceRes = GetResources(TEAM_ALLIANCE);
    uint32 maxVal = std::max(hordeRes, allianceRes);

    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_SHOW, 1});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_CLOCK, endEpoch});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS, endEpoch});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H, hordeRes});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A, allianceRes});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_H, maxVal});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_A, maxVal});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_ACTIVE, 0});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_ATTACKER, TEAM_HORDE});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_DEFENDER, TEAM_ALLIANCE});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_CONTROL, 0});
    updates.push_back({WORLD_STATE_BATTLEFIELD_WG_ICON_ACTIVE, 0});
    if (_affixWorldstateEnabled)
        updates.push_back({WORLD_STATE_HL_AFFIX_TEXT, static_cast<uint32>(_activeAffix)});

    // Apply all updates to all players in batch
    for (Player* player : zonePlayers)
    {
        for (const WorldStateUpdate& update : updates)
        {
            player->SendUpdateWorldState(update.stateId, update.value);
        }
    }
}

// Method removed - functionality exists in BroadcastStatusToZone() method

// Cache invalidation when players enter/leave zone
void OutdoorPvPHL::InvalidatePlayerCache()
{
    s_zonePlayerCache.lastUpdateTime = 0; // Force refresh on next access
}

// Efficient affix application without expensive session iteration
void OutdoorPvPHL::_applyAffixEffectsOptimized()
{
    if (!_affixEnabled)
        return;

    std::vector<Player*> zonePlayers;
    CollectZonePlayers(zonePlayers);

    uint32 playerSpell = GetAffixPlayerSpell(static_cast<uint8>(_activeAffix));
    uint32 npcSpell = GetAffixNpcSpell(static_cast<uint8>(_activeAffix));

    // Apply to players in batch
    if (playerSpell > 0)
    {
        for (Player* player : zonePlayers)
        {
            if (_isPlayerInBGRaid(player))
            {
                player->CastSpell(player, playerSpell, true);
            }
        }
    }

    // Apply to NPCs using zone player iteration (more compatible approach)
    if (npcSpell > 0)
    {
        // Apply affix to nearby NPCs for each player in the zone
        for (Player* player : zonePlayers)
        {
            std::list<Creature*> nearbyCreatures;
            player->GetCreatureListWithEntryInGrid(nearbyCreatures, 0, 200.0f); // Get all creatures within 200 yards

            for (Creature* creature : nearbyCreatures)
            {
                if (creature && creature->IsAlive() && !creature->HasAura(npcSpell) &&
                    creature->GetZoneId() == OutdoorPvPHLBuffZones[0])
                {
                    creature->CastSpell(creature, npcSpell, true);
                }
            }
            break; // Only need to do this once, not for every player
        }
    }
}

// Performance monitoring for debugging
void OutdoorPvPHL::LogPerformanceStats() const
{
    uint32 cacheAge = GameTime::GetGameTimeMS().count() - s_zonePlayerCache.lastUpdateTime;
    uint32 cachedPlayers = s_zonePlayerCache.playerGuids.size();

    LOG_DEBUG("bg.battleground", "HLBG Performance: Cache age {}ms, {} cached players", cacheAge, cachedPlayers);
}
