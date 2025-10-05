// -----------------------------------------------------------------------------
// OutdoorPvPHL_Performance.cpp
// -----------------------------------------------------------------------------
// Performance optimizations for HLBG system including session caching,
// batched operations, and efficient player iteration patterns.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "Player.h"
#include "WorldSessionMgr.h"
#include "ObjectAccessor.h"
#include <vector>
#include <unordered_set>

// Cached zone players to avoid expensive GetAllSessions() calls
struct ZonePlayerCache
{
    std::vector<ObjectGuid> playerGuids;
    uint32 lastUpdateTime;
    static constexpr uint32 CACHE_DURATION_MS = 5000; // 5 seconds
};

static ZonePlayerCache s_zonePlayerCache;

// Efficient zone player collection with caching
void OutdoorPvPHL::CollectZonePlayers(std::vector<Player*>& players) const
{
    uint32 currentTime = GameTime::GetGameTimeMS().count();
    
    // Check if cache needs refresh
    if (currentTime - s_zonePlayerCache.lastUpdateTime > ZonePlayerCache::CACHE_DURATION_MS)
    {
        s_zonePlayerCache.playerGuids.clear();
        
        // Use the OutdoorPvP's internal player tracking instead of GetAllSessions()
        for (uint8 team = 0; team < 2; ++team)
        {
            for (Player* player : _players[team])
            {
                if (player && player->IsInWorld() && player->GetZoneId() == OutdoorPvPHLBuffZones[0])
                {
                    s_zonePlayerCache.playerGuids.push_back(player->GetGUID());
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
    
    // Prepare all worldstate updates
    uint32 timeRemaining = GetTimeRemainingSeconds();
    updates.push_back({HL_WORLDSTATE_TIMER, timeRemaining});
    updates.push_back({HL_WORLDSTATE_ALLIANCE, GetResources(TEAM_ALLIANCE)});
    updates.push_back({HL_WORLDSTATE_HORDE, GetResources(TEAM_HORDE)});
    updates.push_back({HL_WORLDSTATE_MAX_ALLIANCE, _initialResourcesAlliance});
    updates.push_back({HL_WORLDSTATE_MAX_HORDE, _initialResourcesHorde});
    
    // Apply all updates to all players in batch
    for (Player* player : zonePlayers)
    {
        for (const WorldStateUpdate& update : updates)
        {
            player->SendUpdateWorldState(update.stateId, update.value);
        }
    }
}

// Efficient status broadcast without GetAllSessions()
void OutdoorPvPHL::_sendStatusBroadcast()
{
    if (!_statusBroadcastEnabled)
        return;
        
    std::vector<Player*> zonePlayers;
    CollectZonePlayers(zonePlayers);
    
    if (zonePlayers.empty())
        return;

    uint32 minutesLeft = GetTimeRemainingSeconds() / 60;
    uint32 allyResources = GetResources(TEAM_ALLIANCE);
    uint32 hordeResources = GetResources(TEAM_HORDE);

    char buffer[512];
    snprintf(buffer, sizeof(buffer), 
        "|cff1eff00[Hinterland BG]|r Time: %u min | Alliance: %u | Horde: %u", 
        minutesLeft, allyResources, hordeResources);

    // Single message to all zone players
    for (Player* player : zonePlayers)
    {
        ChatHandler(player->GetSession()).SendSysMessage(buffer);
    }
}

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
    
    uint32 playerSpell = GetAffixPlayerSpell(_currentAffix);
    uint32 npcSpell = GetAffixNpcSpell(_currentAffix);
    
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
    
    // Apply to NPCs using efficient map traversal
    if (npcSpell > 0 && _map)
    {
        auto applyToCreature = [npcSpell](Creature* creature)
        {
            if (creature && creature->IsAlive() && !creature->HasAura(npcSpell))
            {
                creature->CastSpell(creature, npcSpell, true);
            }
        };
        
        _map->DoForAllCreaturesInZone(applyToCreature, OutdoorPvPHLBuffZones[0]);
    }
}

// Performance monitoring for debugging
void OutdoorPvPHL::LogPerformanceStats() const
{
    uint32 cacheAge = GameTime::GetGameTimeMS().count() - s_zonePlayerCache.lastUpdateTime;
    uint32 cachedPlayers = s_zonePlayerCache.playerGuids.size();
    
    LOG_DEBUG("bg.battleground", "HLBG Performance: Cache age {}ms, {} cached players", cacheAge, cachedPlayers);
}