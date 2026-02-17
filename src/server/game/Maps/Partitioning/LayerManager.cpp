/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "LayerManager.h"
#include "World.h"
#include "WorldConfig.h"
#include "Log.h"
#include "Grids/GridDefines.h"
#include "GameTime.h"
#include "DatabaseEnv.h"
#include "QueryResult.h"
#include "Group.h"
#include "GroupMgr.h"
#include "Creature.h"
#include "GameObject.h"
#include "Pet.h"
#include "Player.h"
#include "Chat.h"
#include "Map.h"
#include "MapMgr.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Position.h"
#include <algorithm>
#include <cmath>
#include <functional>
#include <limits>
#include <sstream>
#include <string_view>

namespace
{
    constexpr uint32 kHinterlandBattleAreaId = 6738;

    bool IsNoLayerBattleAreaPlayer(uint32 mapId, ObjectGuid const& playerGuid)
    {
        if (mapId != 0 || !playerGuid || !playerGuid.IsPlayer())
            return false;

        if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
            return player->GetAreaId() == kHinterlandBattleAreaId;

        return false;
    }

    void NotifyLayerChange(Player* player, uint32 fromLayer, uint32 toLayer, std::string_view reason)
    {
        if (!player || fromLayer == toLayer)
            return;

        if (WorldSession* session = player->GetSession())
        {
            ChatHandler handler(session);
            handler.PSendSysMessage("Layer change: {} -> {} ({})", fromLayer, toLayer, reason);
        }
    }
}

LayerManager* LayerManager::instance()
{
    static LayerManager instance;
    static std::once_flag initFlag;
    std::call_once(initFlag, [&] { instance.LoadConfig(); });
    return &instance;
}

void LayerManager::LoadConfig()
{
    _config.enabled = sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_LAYERS_ENABLED);
    _config.capacity = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_CAPACITY);
    _config.maxLayers = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_MAX);
    _config.npcLayering = sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_NPC_LAYERS);
    _config.goLayering = sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_GO_LAYERS);
    _config.skipCloneSpawnsIfNoPlayers = sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_SKIP_CLONES_NO_PLAYERS);
    _config.emitPerLayerCloneMetrics = sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_LAYER_CLONE_METRICS);
    _config.lazyCloneLoading = sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_LAYER_LAZY_CLONE_LOADING);
    _config.softTransfersEnabled = sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_LAYER_SOFT_TRANSFERS);
    _config.softTransferTimeoutMs = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_SOFT_TRANSFER_TIMEOUT_MS);
    _config.hysteresisCreationWarmupMs = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_HYSTERESIS_CREATION_MS);
    _config.hysteresisDestructionCooldownMs = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_HYSTERESIS_DESTRUCTION_MS);

    ParsePerMapCapacityOverrides();
    LoadRebalancingConfig();

    // Pre-reserve hash maps to minimize costly rehashing during bulk grid loads.
    // Rehashing traverses ALL existing nodes; if any node was corrupted by
    // external heap corruption (e.g. transaction use-after-free) the traversal
    // segfaults.  Large initial bucket counts keep rehashing rare.
    if (_config.goLayering)
    {
        _goLayers.reserve(100000);
        _goLayerIndex.reserve(2048);
    }
    if (_config.npcLayering)
    {
        _npcLayers.reserve(100000);
        _npcLayerIndex.reserve(2048);
    }
    _playerLayers.reserve(5000);

    LOG_INFO("map.partition", "LayerManager config loaded: enabled={} capacity={} max={} npc={} go={}",
        _config.enabled, _config.capacity, _config.maxLayers, _config.npcLayering, _config.goLayering);
}

bool LayerManager::IsLayeringEnabled() const
{
    return _config.enabled;
}

uint32_t LayerManager::GetLayerCapacity() const
{
    return _config.capacity;
}

uint32_t LayerManager::GetLayerCapacity(uint32 mapId) const
{
    // Per-map override takes priority over global default
    auto it = _perMapCapacity.find(mapId);
    if (it != _perMapCapacity.end())
        return it->second;
    return _config.capacity;
}

uint32_t LayerManager::GetLayerMax() const
{
    return _config.maxLayers;
}

bool LayerManager::IsRuntimeDiagnosticsEnabled() const
{
    return _runtimeDiagnostics.load(std::memory_order_relaxed);
}

void LayerManager::SetRuntimeDiagnosticsEnabled(bool enabled)
{
    _runtimeDiagnostics.store(enabled, std::memory_order_relaxed);
    if (enabled)
        _runtimeDiagnosticsUntilMs.store(GameTime::GetGameTimeMS().count() + 60000, std::memory_order_relaxed);
    else
        _runtimeDiagnosticsUntilMs.store(0, std::memory_order_relaxed);
    LOG_INFO("map.partition", "Layer diagnostics {}", enabled ? "enabled" : "disabled");
}

bool LayerManager::IsSoftTransfersEnabled() const
{
    return _config.softTransfersEnabled;
}

uint32 LayerManager::GetSoftTransferTimeoutMs() const
{
    return _config.softTransferTimeoutMs;
}

uint32 LayerManager::GetHysteresisCreationWarmupMs() const
{
    return _config.hysteresisCreationWarmupMs;
}

uint32 LayerManager::GetHysteresisDestructionCooldownMs() const
{
    return _config.hysteresisDestructionCooldownMs;
}

void LayerManager::ParsePerMapCapacityOverrides()
{
    _perMapCapacity.clear();
    std::string_view overrides = sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_LAYER_CAPACITY_OVERRIDES);
    if (overrides.empty())
        return;

    // Format: "mapId:capacity,mapId:capacity,..."
    // Example: "0:150,1:200,530:100,571:250"
    std::istringstream ss{std::string(overrides)};
    std::string token;
    while (std::getline(ss, token, ','))
    {
        // Trim whitespace
        auto start = token.find_first_not_of(" \t");
        auto end = token.find_last_not_of(" \t");
        if (start == std::string::npos) continue;
        token = token.substr(start, end - start + 1);

        auto colonPos = token.find(':');
        if (colonPos == std::string::npos || colonPos == 0 || colonPos == token.size() - 1)
        {
            LOG_ERROR("map.partition", "Invalid CapacityOverrides entry: '{}' (expected mapId:capacity)", token);
            continue;
        }

        try
        {
            uint32 mapId = static_cast<uint32>(std::stoul(token.substr(0, colonPos)));
            uint32 capacity = static_cast<uint32>(std::stoul(token.substr(colonPos + 1)));
            if (capacity == 0)
            {
                LOG_WARN("map.partition", "CapacityOverrides: mapId {} has capacity 0, skipping", mapId);
                continue;
            }
            _perMapCapacity[mapId] = capacity;
            LOG_INFO("map.partition", "Per-map capacity override: Map {} = {} players/layer", mapId, capacity);
        }
        catch (std::exception const& e)
        {
            LOG_ERROR("map.partition", "Invalid CapacityOverrides entry '{}': {}", token, e.what());
        }
    }

    if (!_perMapCapacity.empty())
        LOG_INFO("map.partition", "Loaded {} per-map capacity override(s)", _perMapCapacity.size());
}

void LayerManager::LoadRebalancingConfig()
{
    _rebalancingConfig.enabled = sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_LAYER_REBALANCING_ENABLED);
    _rebalancingConfig.checkIntervalMs = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_REBALANCING_INTERVAL_MS);
    _rebalancingConfig.minPlayersPerLayer = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_REBALANCING_MIN_PLAYERS);
    _rebalancingConfig.imbalanceThreshold = sWorld->getFloatConfig(CONFIG_MAP_PARTITIONS_LAYER_REBALANCING_IMBALANCE_THRESHOLD);
    _rebalancingConfig.migrationBatchSize = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_REBALANCING_MIGRATION_BATCH);

    LOG_INFO("map.partition", "Rebalancing config: enabled={} interval={}ms minPlayers={} threshold={:.2f} batchSize={}",
        _rebalancingConfig.enabled ? "true" : "false",
        _rebalancingConfig.checkIntervalMs,
        _rebalancingConfig.minPlayersPerLayer,
        _rebalancingConfig.imbalanceThreshold,
        _rebalancingConfig.migrationBatchSize);
}

void LayerManager::SyncControlledToLayer(uint32 mapId, ObjectGuid const& playerGuid, uint32 layerId)
{
    if (!IsNPCLayeringEnabled())
        return;

    Player* player = ObjectAccessor::FindPlayer(playerGuid);
    if (!player || !player->IsInWorld())
        return;

    // Get zone from the pet/guardian position for NPC assignment tracking
    if (Pet* pet = player->GetPet())
        if (pet->IsInWorld())
            AssignNPCToLayer(mapId, pet->GetZoneId(), pet->GetGUID(), layerId);

    if (Guardian* guardian = player->GetGuardianPet())
        if (guardian->IsInWorld())
            AssignNPCToLayer(mapId, guardian->GetZoneId(), guardian->GetGUID(), layerId);

    if (Unit* charmed = player->GetCharm())
        if (Creature* charmedCreature = charmed->ToCreature())
            if (charmedCreature->IsInWorld())
                AssignNPCToLayer(mapId, charmedCreature->GetZoneId(), charmedCreature->GetGUID(), layerId);
}

bool LayerManager::ShouldEmitRegenMetrics() const
{
    if (!IsRuntimeDiagnosticsEnabled())
        return false;

    uint64 until = _runtimeDiagnosticsUntilMs.load(std::memory_order_relaxed);
    if (!until)
        return false;

    return static_cast<uint64>(GameTime::GetGameTimeMS().count()) <= until;
}

uint64 LayerManager::GetRuntimeDiagnosticsRemainingMs() const
{
    if (!IsRuntimeDiagnosticsEnabled())
        return 0;

    uint64 until = _runtimeDiagnosticsUntilMs.load(std::memory_order_relaxed);
    if (!until)
        return 0;

    uint64 now = static_cast<uint64>(GameTime::GetGameTimeMS().count());
    return now >= until ? 0 : (until - now);
}

uint32_t LayerManager::GetLayerForPlayer(uint32_t mapId, ObjectGuid const& playerGuid) const
{
    if (IsNoLayerBattleAreaPlayer(mapId, playerGuid))
        return 0;

    struct PlayerLayerCache
    {
        ObjectGuid::LowType guid = 0;
        uint32 mapId = 0;
        uint32 layerId = 0;
        uint64 expiresMs = 0;
    };

    thread_local PlayerLayerCache cache;
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    if (cache.guid == playerGuid.GetCounter() && cache.mapId == mapId && nowMs <= cache.expiresMs)
        return cache.layerId;

    // Fast path: try lock-free atomic read under shared_lock
    {
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto atomicIt = _atomicPlayerLayers.find(playerGuid.GetCounter());
        if (atomicIt != _atomicPlayerLayers.end())
        {
            uint32 storedMapId, storedLayerId;
            atomicIt->second.Load(storedMapId, storedLayerId);
            if (storedMapId == mapId)
            {
                cache = { playerGuid.GetCounter(), mapId, storedLayerId, nowMs + 250 };
                return storedLayerId;
            }
        }

        // Fallback to regular lookup
        auto it = _playerLayers.find(playerGuid.GetCounter());
        if (it != _playerLayers.end())
        {
            if (it->second.mapId == mapId)
            {
                cache = { playerGuid.GetCounter(), mapId, it->second.layerId, nowMs + 250 };
                return it->second.layerId;
            }
        }
    }
    cache = { playerGuid.GetCounter(), mapId, 0, nowMs + 250 };
    return 0; // Default layer
}

uint32 LayerManager::GetPlayerLayer(uint32 mapId, ObjectGuid const& playerGuid) const
{
    return GetLayerForPlayer(mapId, playerGuid);
}

uint32_t LayerManager::GetLayerCount(uint32_t mapId) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto mapIt = _layers.find(mapId);
    if (mapIt != _layers.end())
        return static_cast<uint32>(mapIt->second.size());
    return 1; // Always at least default layer
}

std::vector<uint32> LayerManager::GetLayerIds(uint32 mapId) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);

    // _layers[mapId] is the canonical source of all active layers.
    // Layers are created via CreateLayer() which always registers them in _layers,
    // so NPC/GO-only layers without player entries are not a real case.
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end())
        return { 0 }; // Always include default layer

    std::vector<uint32> layerIds;
    layerIds.reserve(mapIt->second.size() + 1);
    bool hasZero = false;
    for (auto const& [layerId, _] : mapIt->second)
    {
        layerIds.push_back(layerId);
        if (layerId == 0)
            hasZero = true;
    }

    // Always include layer 0
    if (!hasZero)
        layerIds.push_back(0);

    std::sort(layerIds.begin(), layerIds.end());
    return layerIds;
}

void LayerManager::GetActiveLayerIds(uint32 mapId, std::vector<uint32>& out) const
{
    out.clear();

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end())
        return;

    out.reserve(mapIt->second.size());
    for (auto const& [layerId, players] : mapIt->second)
    {
        if (!players.empty())
            out.push_back(layerId);
    }

    std::sort(out.begin(), out.end());
}

void LayerManager::GetNPCLayerCountsByZone(uint32 mapId, LayerCountByZone& out) const
{
    out.clear();

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    for (auto const& [_, assignment] : _npcLayers)
    {
        if (assignment.mapId != mapId)
            continue;

        ++out[assignment.zoneId][assignment.layerId];
    }
}

void LayerManager::GetGOLayerCountsByZone(uint32 mapId, LayerCountByZone& out) const
{
    out.clear();

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    for (auto const& [_, assignment] : _goLayers)
    {
        if (assignment.mapId != mapId)
            continue;

        ++out[assignment.zoneId][assignment.layerId];
    }
}

void LayerManager::GetLayerPlayerCountsByLayer(uint32 mapId, std::map<uint32, uint32>& out) const
{
    out.clear();

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end())
        return;

    for (auto const& [layerId, players] : mapIt->second)
        out[layerId] = static_cast<uint32>(players.size());
}

bool LayerManager::HasPlayersOnMap(uint32 mapId) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end())
        return false;

    for (auto const& [_, players] : mapIt->second)
    {
        if (!players.empty())
            return true;
    }

    return false;
}

bool LayerManager::SkipCloneSpawnsIfNoPlayers() const
{
    return _config.skipCloneSpawnsIfNoPlayers;
}

bool LayerManager::EmitPerLayerCloneMetrics() const
{
    return _config.emitPerLayerCloneMetrics;
}

bool LayerManager::LazyCloneLoadingEnabled() const
{
    return _config.lazyCloneLoading;
}

void LayerManager::AssignPlayerToLayer(uint32_t mapId, ObjectGuid const& playerGuid, uint32_t layerId)
{
    if (IsNoLayerBattleAreaPlayer(mapId, playerGuid))
        layerId = 0;

    bool layerWasEmpty = false;
    bool needsDespawn = false;
    uint32 despawnMapId = 0, despawnLayerId = 0;
    {
        std::unique_lock<std::shared_mutex> guard(_layerLock);

        // Remove from old layer if exists
        auto it = _playerLayers.find(playerGuid.GetCounter());
        if (it != _playerLayers.end())
        {
            auto& oldLayer = _layers[it->second.mapId][it->second.layerId];
            oldLayer.erase(playerGuid.GetCounter());
            if (CleanupEmptyLayers(it->second.mapId, it->second.layerId))
            {
                needsDespawn = true;
                despawnMapId = it->second.mapId;
                despawnLayerId = it->second.layerId;
            }
        }

        // Assign to new
        auto& targetLayer = _layers[mapId][layerId];
        layerWasEmpty = targetLayer.empty();
        targetLayer.insert(playerGuid.GetCounter());
        _playerLayers[playerGuid.GetCounter()] = { mapId, 0, layerId };
        
        // Sync atomic for lock-free reads
        _atomicPlayerLayers[playerGuid.GetCounter()].Store(mapId, layerId);

        if (IsRuntimeDiagnosticsEnabled())
        {
            LOG_INFO("map.partition", "Diag: AssignPlayerToLayer player={} map={} layer={}",
                playerGuid.ToString(), mapId, layerId);
        }
    }

    // Phase 2: expensive despawn outside lock
    if (needsDespawn)
        DespawnLayerClones(despawnMapId, despawnLayerId);

    SyncControlledToLayer(mapId, playerGuid, layerId);

    if (layerWasEmpty && layerId != 0)
    {
        ReassignNPCsForNewLayer(mapId, layerId);
        ReassignGOsForNewLayer(mapId, layerId);
    }
}

void LayerManager::RemovePlayerFromLayer(uint32_t mapId, ObjectGuid const& playerGuid)
{
    bool needsDespawn = false;
    uint32 despawnLayerId = 0;
    {
        std::unique_lock<std::shared_mutex> guard(_layerLock);
        
        auto it = _playerLayers.find(playerGuid.GetCounter());
        if (it == _playerLayers.end())
            return;

        // Verify map match
        if (it->second.mapId != mapId)
            return;

        auto& layer = _layers[mapId][it->second.layerId];
        layer.erase(playerGuid.GetCounter());
        if (CleanupEmptyLayers(mapId, it->second.layerId))
        {
            needsDespawn = true;
            despawnLayerId = it->second.layerId;
        }

        _playerLayers.erase(it);
        
        // Erase atomic entry entirely to prevent unbounded map growth
        _atomicPlayerLayers.erase(playerGuid.GetCounter());

        if (IsRuntimeDiagnosticsEnabled())
        {
            LOG_INFO("map.partition", "Diag: RemovePlayerFromLayer player={} map={}",
                playerGuid.ToString(), mapId);
        }
    }

    // Phase 2: expensive despawn outside lock
    if (needsDespawn)
        DespawnLayerClones(mapId, despawnLayerId);
}

bool LayerManager::CleanupEmptyLayers(uint32 mapId, uint32 layerId)
{
    // Phase 1: In-memory bookkeeping only (called while _layerLock is held by caller).
    // Returns true if the layer was removed and DespawnLayerClones should be called
    // AFTER releasing _layerLock.
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end())
        return false;
    auto& mapLayers = mapIt->second;
    // Never destroy the base layer (layer 0) — it holds original spawns.
    if (layerId == 0)
        return false;

    auto layerIt = mapLayers.find(layerId);
    if (layerIt == mapLayers.end())
        return false;
    if (!layerIt->second.empty())
        return false;

    // Layer is empty — remove from tracking
    mapLayers.erase(layerId);

    // Use reverse index for O(1) NPC/GO cleanup instead of full table scan
    uint64 indexKey = (static_cast<uint64>(mapId) << 32) | layerId;

    auto npcIndexIt = _npcLayerIndex.find(indexKey);
    if (npcIndexIt != _npcLayerIndex.end())
    {
        for (LayerKey key : npcIndexIt->second)
            _npcLayers.erase(key);
        _npcLayerIndex.erase(npcIndexIt);
    }

    auto goIndexIt = _goLayerIndex.find(indexKey);
    if (goIndexIt != _goLayerIndex.end())
    {
        for (LayerKey key : goIndexIt->second)
            _goLayers.erase(key);
        _goLayerIndex.erase(goIndexIt);
    }

    if (mapLayers.empty())
        _layers.erase(mapId);

    return true; // Caller must call DespawnLayerClones(mapId, layerId) outside the lock
}

void LayerManager::DespawnLayerClones(uint32 mapId, uint32 layerId)
{
    // Phase 2: Expensive map iteration — must be called OUTSIDE _layerLock.
    sMapMgr->DoForAllMapsWithMapId(mapId, [&](Map* map)
    {
        if (!map)
            return;

        map->ClearLoadedLayer(layerId);

        std::vector<Creature*> creaturesToRemove;
        for (auto const& entry : map->GetCreatureBySpawnIdStoreSnapshot())
        {
            Creature* creature = entry.second;
            if (creature && creature->IsLayerClone() && creature->GetLayerCloneId() == layerId && creature->IsInWorld())
                creaturesToRemove.push_back(creature);
        }

        std::vector<GameObject*> gosToRemove;
        for (auto const& entry : map->GetGameObjectBySpawnIdStoreSnapshot())
        {
            GameObject* go = entry.second;
            if (go && go->IsLayerClone() && go->GetLayerCloneId() == layerId && go->IsInWorld())
                gosToRemove.push_back(go);
        }

        for (Creature* creature : creaturesToRemove)
            creature->AddObjectToRemoveList();
        for (GameObject* go : gosToRemove)
            go->AddObjectToRemoveList();
    });
}

void LayerManager::AutoAssignPlayerToLayer(uint32_t mapId, ObjectGuid const& playerGuid)
{
    if (!IsLayeringEnabled())
        return;

    if (IsNoLayerBattleAreaPlayer(mapId, playerGuid))
    {
        AssignPlayerToLayer(mapId, playerGuid, 0);
        return;
    }

    // First check if party member should sync to leader's layer (outside of lock to avoid deadlock)
    uint32 partyTargetLayer = GetPartyTargetLayer(mapId, playerGuid);

    uint32 assignedLayerId = 0;
    uint32 previousLayerId = 0;
    std::string_view reason = "auto";
    bool shouldSync = false;
    bool createdNewLayer = false;
    bool needsDespawn = false;
    uint32 despawnMapId = 0, despawnLayerId = 0;

    {
        std::unique_lock<std::shared_mutex> guard(_layerLock);

        // If player is already assigned to a layer on this map, keep them there (stickiness)
        // Blizzard-style: layer is map-wide, so no re-assignment on zone change
        auto it = _playerLayers.find(playerGuid.GetCounter());
        if (it != _playerLayers.end() && it->second.mapId == mapId)
        {
            // If party leader is on a different layer, move to match them
            if (partyTargetLayer > 0 && it->second.layerId != partyTargetLayer)
            {
                previousLayerId = it->second.layerId;

                // Remove from old layer
                auto& oldLayerPlayers = _layers[mapId][it->second.layerId];
                oldLayerPlayers.erase(playerGuid.GetCounter());

                if (oldLayerPlayers.empty() && CleanupEmptyLayers(mapId, it->second.layerId))
                {
                    needsDespawn = true;
                    despawnMapId = mapId;
                    despawnLayerId = it->second.layerId;
                }

                // Assign to party leader's layer
                _layers[mapId][partyTargetLayer].insert(playerGuid.GetCounter());
                _playerLayers[playerGuid.GetCounter()] = { mapId, 0, partyTargetLayer };
                _atomicPlayerLayers[playerGuid.GetCounter()].Store(mapId, partyTargetLayer);

                LOG_DEBUG("map.partition", "Player {} moved to party leader's Layer {} on Map {}",
                    playerGuid.ToString(), partyTargetLayer, mapId);

                if (IsRuntimeDiagnosticsEnabled())
                {
                    LOG_INFO("map.partition", "Diag: AutoAssignPlayerToLayer player={} map={} layer={} reason=party",
                        playerGuid.ToString(), mapId, partyTargetLayer);
                }

                assignedLayerId = partyTargetLayer;
                shouldSync = true;
                reason = "party";
            }
            else
            {
                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                bool isBot = player && player->GetSession() && player->GetSession()->IsBot();

                if (!isBot)
                    return;  // Already on correct layer for this map

                auto& mapLayers = _layers[mapId];
                uint32 mapCapacity = GetLayerCapacity(mapId);

                uint32 currentLayer = it->second.layerId;
                uint32 currentCount = static_cast<uint32>(mapLayers[currentLayer].size());

                uint32 bestLayerId = currentLayer;
                bool foundLayer = false;
                for (auto const& [layerId, players] : mapLayers)
                {
                    if (layerId == currentLayer)
                        continue;

                    if (players.size() < mapCapacity)
                    {
                        bestLayerId = layerId;
                        foundLayer = true;
                        break;
                    }
                }

                if (!foundLayer || currentCount <= mapCapacity)
                    return;

                previousLayerId = currentLayer;
                auto& oldLayerPlayers = mapLayers[currentLayer];
                oldLayerPlayers.erase(playerGuid.GetCounter());

                if (oldLayerPlayers.empty() && CleanupEmptyLayers(mapId, currentLayer))
                {
                    needsDespawn = true;
                    despawnMapId = mapId;
                    despawnLayerId = currentLayer;
                }

                mapLayers[bestLayerId].insert(playerGuid.GetCounter());
                _playerLayers[playerGuid.GetCounter()] = { mapId, 0, bestLayerId };
                _atomicPlayerLayers[playerGuid.GetCounter()].Store(mapId, bestLayerId);

                assignedLayerId = bestLayerId;
                shouldSync = true;
                reason = "bot rebalance";
            }
        }
        else
        {
            // Player is on a different map, or not yet assigned.
            // Remove old assignment first if it exists.
            if (it != _playerLayers.end())
            {
                uint32 oldMapId = it->second.mapId;
                uint32 oldLayerId = it->second.layerId;
                previousLayerId = oldLayerId;

                auto& oldLayer = _layers[oldMapId][oldLayerId];
                oldLayer.erase(playerGuid.GetCounter());

                if (oldLayer.empty() && CleanupEmptyLayers(oldMapId, oldLayerId))
                {
                    needsDespawn = true;
                    despawnMapId = oldMapId;
                    despawnLayerId = oldLayerId;
                }

                _playerLayers.erase(it);
            }

            uint32_t bestLayerId = 0;
            bool foundLayer = false;

            // Priority 1: Party leader's layer (if available)
            if (partyTargetLayer > 0)
            {
                bestLayerId = partyTargetLayer;
                foundLayer = true;
                LOG_DEBUG("map.partition", "Player {} joining party leader's Layer {} on Map {}",
                    playerGuid.ToString(), bestLayerId, mapId);
                reason = "party";
            }
            else
            {
                // Priority 2: Find first layer with capacity
                auto& mapLayers = _layers[mapId];
                uint32 mapCapacity = GetLayerCapacity(mapId);

                // Check existing layers first (prioritize filling gaps)
                for (auto const& [layerId, players] : mapLayers)
                {
                    if (players.size() < mapCapacity)
                    {
                        if (!foundLayer || layerId < bestLayerId)
                        {
                            bestLayerId = layerId;
                            foundLayer = true;
                        }
                    }
                }

                // If we found capacity, reset the hysteresis creation timer (pressure relieved)
                if (foundLayer)
                {
                    std::lock_guard<std::mutex> hg(_hysteresisLock);
                    auto hit = _hysteresisState.find(mapId);
                    if (hit != _hysteresisState.end() && hit->second.creationRequestMs != 0)
                    {
                        hit->second.creationRequestMs = 0;
                        LOG_DEBUG("map.partition", "Hysteresis: creation warmup reset for Map {} (capacity available)", mapId);
                    }
                }

                if (!foundLayer)
                {
                    // No existing layer has space. Create new one.
                    if (mapLayers.empty())
                    {
                        bestLayerId = 0;
                    }
                    else
                    {
                        uint32_t maxId = 0;
                        for (auto const& [layerId, _] : mapLayers)
                        {
                            if (layerId > maxId) maxId = layerId;
                        }

                        uint32_t layerMax = GetLayerMax();
                        if (layerMax == 0)
                            layerMax = 1;

                        if (mapLayers.size() >= layerMax)
                        {
                            // All layers full; stick to the least populated existing layer.
                            uint32_t bestCount = std::numeric_limits<uint32_t>::max();
                            for (auto const& [layerId, players] : mapLayers)
                            {
                                if (players.size() < bestCount)
                                {
                                    bestCount = static_cast<uint32_t>(players.size());
                                    bestLayerId = layerId;
                                }
                            }
                            reason = "capacity";
                        }
                        else
                        {
                            // Hysteresis: delay layer creation to prevent oscillation
                            uint32 warmupMs = GetHysteresisCreationWarmupMs();
                            uint64 nowMs = GameTime::GetGameTimeMS().count();
                            bool hysteresisReady = true;

                            if (warmupMs > 0)
                            {
                                std::lock_guard<std::mutex> hg(_hysteresisLock);
                                auto& hs = _hysteresisState[mapId];
                                if (hs.creationRequestMs == 0)
                                {
                                    // First time we want to create — start the warmup timer
                                    hs.creationRequestMs = nowMs;
                                    hysteresisReady = false;
                                    LOG_DEBUG("map.partition", "Hysteresis: creation warmup started for Map {} ({}ms)", mapId, warmupMs);
                                }
                                else if (nowMs < hs.creationRequestMs + warmupMs)
                                {
                                    // Still warming up
                                    hysteresisReady = false;
                                }
                                else
                                {
                                    // Warmup elapsed — allow creation and reset timer
                                    hs.creationRequestMs = 0;
                                }
                            }

                            if (hysteresisReady)
                            {
                                bestLayerId = maxId + 1;
                                createdNewLayer = true;
                                reason = "new layer";
                            }
                            else
                            {
                                // Hysteresis not yet elapsed — overflow into least populated layer
                                uint32_t bestCount = std::numeric_limits<uint32_t>::max();
                                for (auto const& [layerId2, players2] : mapLayers)
                                {
                                    if (players2.size() < bestCount)
                                    {
                                        bestCount = static_cast<uint32_t>(players2.size());
                                        bestLayerId = layerId2;
                                    }
                                }
                                foundLayer = true;
                                reason = "hysteresis overflow";
                            }
                        }
                    }
                }
            }

            // Assign directly to the chosen layer.
            _layers[mapId][bestLayerId].insert(playerGuid.GetCounter());
            _playerLayers[playerGuid.GetCounter()] = { mapId, 0, bestLayerId };
            _atomicPlayerLayers[playerGuid.GetCounter()].Store(mapId, bestLayerId);

            if (bestLayerId > 0)
            {
                LOG_DEBUG("map.partition", "Player {} assigned to Layer {} on Map {}",
                    playerGuid.ToString(), bestLayerId, mapId);
            }

            if (IsRuntimeDiagnosticsEnabled())
            {
                LOG_INFO("map.partition", "Diag: AutoAssignPlayerToLayer player={} map={} layer={} reason={}",
                    playerGuid.ToString(), mapId, bestLayerId, reason);
            }

            assignedLayerId = bestLayerId;
            if (!previousLayerId)
                previousLayerId = bestLayerId;
            shouldSync = true;
        }
    }  // Release lock here

    // Phase 2: expensive despawn outside lock
    if (needsDespawn)
        DespawnLayerClones(despawnMapId, despawnLayerId);

    // Perform DB I/O outside the lock to prevent deadlocks
    if (shouldSync)
    {
        SavePersistentLayerAssignment(playerGuid, mapId, assignedLayerId);
        SyncControlledToLayer(mapId, playerGuid, assignedLayerId);
    }

    // Spawn NPC/GO clones for brand-new layers BEFORE visibility rebuild so the
    // player can see them immediately (ordering matters).
    if (createdNewLayer)
    {
        ReassignNPCsForNewLayer(mapId, assignedLayerId);
        ReassignGOsForNewLayer(mapId, assignedLayerId);
    }

    if (shouldSync)
    {
        if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
        {
            NotifyLayerChange(player, previousLayerId, assignedLayerId, reason);

            if (assignedLayerId != previousLayerId && player->IsInWorld())
            {
                if (Map* map = player->GetMap())
                    map->LoadLayerClonesInRange(player, MAX_VISIBILITY_DISTANCE);
                player->InvalidateLayerCache();
                player->UpdateObjectVisibility(true, true);
            }
        }
    }
}

void LayerManager::ReassignNPCsForNewLayer(uint32 mapId, uint32 layerId)
{
    if (!IsNPCLayeringEnabled() || layerId == 0)
        return;

    uint32 spawned = 0;
    sMapMgr->DoForAllMapsWithMapId(mapId, [&](Map* map)
    {
        if (!map)
            return;

        uint8 spawnMode = map->GetSpawnMode();
        for (uint16 gridX = 0; gridX < MAX_NUMBER_OF_GRIDS; ++gridX)
        {
            for (uint16 gridY = 0; gridY < MAX_NUMBER_OF_GRIDS; ++gridY)
            {
                if (!map->IsGridLoaded(GridCoord(gridX, gridY)))
                    continue;

                // Mark this grid+layer as loaded so EnsureGridLayerLoaded won't
                // double-spawn clones later.
                map->MarkGridLayerLoaded(gridX, gridY, layerId);

                uint32 gridId = gridY * MAX_NUMBER_OF_GRIDS + gridX;
                CellObjectGuids const& cellGuids = sObjectMgr->GetGridObjectGuids(mapId, spawnMode, gridId);
                for (ObjectGuid::LowType const& spawnId : cellGuids.creatures)
                {
                    CreatureData const* data = sObjectMgr->GetCreatureData(spawnId);
                    if (!data)
                        continue;

                    bool existsInLayer = false;
                    auto creatures = map->GetCreaturesBySpawnId(spawnId);
                    for (Creature* existing : creatures)
                    {
                        if (existing && existing->IsLayerClone() && existing->GetLayerCloneId() == layerId)
                        {
                            existsInLayer = true;
                            break;
                        }
                    }

                    if (existsInLayer)
                        continue;

                    Creature* obj = new Creature();
                    if (!obj->LoadCreatureFromDB(spawnId, map, false, true, true, layerId))
                    {
                        delete obj;
                        continue;
                    }

                    if (!map->AddToMap(obj))
                    {
                        delete obj;
                        continue;
                    }

                    ++spawned;
                }
            }
        }
    });

    if (IsRuntimeDiagnosticsEnabled() && spawned > 0)
    {
        LOG_INFO("map.partition", "Diag: ReassignNPCsForNewLayer map={} layer={} spawned={}",
            mapId, layerId, spawned);
    }
}

uint32 LayerManager::GetPartyTargetLayer(uint32 mapId, ObjectGuid const& playerGuid)
{
    if (!IsLayeringEnabled())
        return 0;

    if (!playerGuid)
        return 0;

    // Fast path: thread-local cache avoids any lock on the hot path
    struct PartyLayerTLCache
    {
        ObjectGuid::LowType guid = 0;
        uint32 mapId = 0;
        uint32 layerId = 0;
        uint64 expiresMs = 0;
    };
    thread_local PartyLayerTLCache tlCache;

    uint64 nowMs = GameTime::GetGameTimeMS().count();
    if (tlCache.guid == playerGuid.GetCounter() && tlCache.mapId == mapId && nowMs <= tlCache.expiresMs)
        return tlCache.layerId;

    {
        std::lock_guard<std::mutex> cacheGuard(_partyLayerCacheLock);
        auto cacheIt = _partyTargetLayerCache.find(playerGuid.GetCounter());
        if (cacheIt != _partyTargetLayerCache.end())
        {
            if (cacheIt->second.mapId == mapId && nowMs <= cacheIt->second.expiresMs)
            {
                tlCache = { playerGuid.GetCounter(), mapId, cacheIt->second.layerId, cacheIt->second.expiresMs };
                return cacheIt->second.layerId;
            }

            if (nowMs > cacheIt->second.expiresMs)
                _partyTargetLayerCache.erase(cacheIt);
        }
    }

    Player* player = ObjectAccessor::FindPlayer(playerGuid);
    if (!player)
        return 0;

    Group* group = player->GetGroup();
    if (!group)
        return 0;

    ObjectGuid leaderGuid = group->GetLeaderGUID();
    if (leaderGuid == playerGuid)
        return 0; // Player is leader, no target layer

    uint32 layerId = GetLayerForPlayer(mapId, leaderGuid);

    LOG_DEBUG("map.partition", "Party sync: Player {} targeting leader {} layer {} on map {}",
        playerGuid.ToString(), leaderGuid.ToString(), layerId, mapId);

    // Update shared cache (lock order safe: _layerLock already released)
    {
        std::lock_guard<std::mutex> cacheGuard(_partyLayerCacheLock);
        _partyTargetLayerCache[playerGuid.GetCounter()] = { mapId, layerId, nowMs + 1000 };
    }

    // Update thread-local cache
    tlCache = { playerGuid.GetCounter(), mapId, layerId, nowMs + 1000 };

    return layerId;
}

bool LayerManager::IsNPCLayeringEnabled() const
{
    return _config.npcLayering;
}

void LayerManager::AssignNPCToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& npcGuid, uint32 layerId)
{
    if (!IsNPCLayeringEnabled())
        return;

    if (!npcGuid || npcGuid.GetCounter() == 0)
    {
        LOG_ERROR("map.partition", "AssignNPCToLayer: invalid NPC guid (mapId={} zoneId={} layerId={})",
            mapId, zoneId, layerId);
        return;
    }

    std::unique_lock<std::shared_mutex> guard(_layerLock);
    LayerKey layerKey = MakeLayerKey(mapId, npcGuid);

    try
    {
        auto [it, inserted] = _npcLayers.try_emplace(layerKey, LayerAssignment{ mapId, zoneId, layerId, npcGuid.GetEntry() });
        if (!inserted)
            it->second = { mapId, zoneId, layerId, npcGuid.GetEntry() };

        uint64 indexKey = (static_cast<uint64>(mapId) << 32) | layerId;
        _npcLayerIndex[indexKey].insert(layerKey);
    }
    catch (std::exception const& e)
    {
        LOG_ERROR("map.partition", "AssignNPCToLayer: exception inserting NPC {} map {} zone {} layer {}: {}",
            npcGuid.ToString(), mapId, zoneId, layerId, e.what());
        return;
    }

    LOG_DEBUG("map.partition", "Assigned NPC {} to layer {} in map {} zone {}",
        npcGuid.ToString(), layerId, mapId, zoneId);
}

void LayerManager::RemoveNPCFromLayer(uint32 mapId, ObjectGuid const& npcGuid)
{
    if (!npcGuid || npcGuid.GetCounter() == 0)
        return;

    std::unique_lock<std::shared_mutex> guard(_layerLock);
    LayerKey layerKey = MakeLayerKey(mapId, npcGuid);

    try
    {
        auto it = _npcLayers.find(layerKey);
        if (it != _npcLayers.end())
        {
            uint64 indexKey = (static_cast<uint64>(it->second.mapId) << 32) | it->second.layerId;
            auto indexIt = _npcLayerIndex.find(indexKey);
            if (indexIt != _npcLayerIndex.end())
            {
                indexIt->second.erase(layerKey);
                if (indexIt->second.empty())
                    _npcLayerIndex.erase(indexIt);
            }
            _npcLayers.erase(it);
        }
    }
    catch (std::exception const& e)
    {
        LOG_ERROR("map.partition", "RemoveNPCFromLayer: exception for NPC {} map {}: {}",
            npcGuid.ToString(), mapId, e.what());
    }
}

uint32 LayerManager::GetLayerForNPC(uint32 mapId, ObjectGuid const& npcGuid) const
{
    struct LayerCache
    {
        ObjectGuid::LowType guid = 0;
        uint32 mapId = 0;
        uint32 layerId = 0;
        uint64 expiresMs = 0;
    };

    thread_local LayerCache cache;
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    if (cache.guid == npcGuid.GetCounter() && cache.mapId == mapId && nowMs <= cache.expiresMs)
        return cache.layerId;

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto it = _npcLayers.find(MakeLayerKey(mapId, npcGuid));
    if (it == _npcLayers.end())
    {
        cache = { npcGuid.GetCounter(), mapId, 0, nowMs + 250 };
        return 0;
    }
    
    if (it->second.mapId != mapId)
    {
        cache = { npcGuid.GetCounter(), mapId, 0, nowMs + 250 };
        return 0;
    }
    
    cache = { npcGuid.GetCounter(), mapId, it->second.layerId, nowMs + 250 };
    return it->second.layerId;
}

uint32 LayerManager::GetLayerForNPC(ObjectGuid const& npcGuid) const
{
    struct LayerCache
    {
        ObjectGuid::LowType guid = 0;
        uint32 layerId = 0;
        uint64 expiresMs = 0;
    };

    thread_local LayerCache cache;
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    if (cache.guid == npcGuid.GetCounter() && nowMs <= cache.expiresMs)
        return cache.layerId;

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    ObjectGuid::LowType guidLow = npcGuid.GetCounter();
    for (auto const& [key, assignment] : _npcLayers)
    {
        if (static_cast<ObjectGuid::LowType>(key) == guidLow)
        {
            cache = { guidLow, assignment.layerId, nowMs + 250 };
            return assignment.layerId;
        }
    }

    cache = { guidLow, 0, nowMs + 250 };
    return 0;
}

uint32 LayerManager::GetDefaultLayerForMap(uint32 mapId, uint64 seed) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end() || mapIt->second.empty())
        return 0;

    std::vector<uint32> layerIds;
    layerIds.reserve(mapIt->second.size());
    for (auto const& [layerId, _] : mapIt->second)
        layerIds.push_back(layerId);

    std::sort(layerIds.begin(), layerIds.end());
    uint32 index = static_cast<uint32>(seed % layerIds.size());
    return layerIds[index];
}

bool LayerManager::IsGOLayeringEnabled() const
{
    return _config.goLayering;
}

void LayerManager::AssignGOToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& goGuid, uint32 layerId)
{
    if (!IsGOLayeringEnabled())
        return;

    // Validate the GO GUID before modifying the hash table.  Garbage inputs
    // could produce sentinel LayerKeys that collide with bookkeeping entries.
    if (!goGuid || goGuid.GetCounter() == 0)
    {
        LOG_ERROR("map.partition", "AssignGOToLayer: invalid GO guid (mapId={} zoneId={} layerId={})",
            mapId, zoneId, layerId);
        return;
    }

    std::unique_lock<std::shared_mutex> guard(_layerLock);
    LayerKey layerKey = MakeLayerKey(mapId, goGuid);

    // Use try_emplace + assign to avoid double-lookup on new insertions,
    // and protect against exceptions from the allocator / hash function.
    try
    {
        auto [it, inserted] = _goLayers.try_emplace(layerKey, LayerAssignment{ mapId, zoneId, layerId, goGuid.GetEntry() });
        if (!inserted)
            it->second = { mapId, zoneId, layerId, goGuid.GetEntry() };

        uint64 indexKey = (static_cast<uint64>(mapId) << 32) | layerId;
        _goLayerIndex[indexKey].insert(layerKey);
    }
    catch (std::exception const& e)
    {
        LOG_ERROR("map.partition", "AssignGOToLayer: exception inserting GO {} map {} zone {} layer {}: {}",
            goGuid.ToString(), mapId, zoneId, layerId, e.what());
        return;
    }

    LOG_DEBUG("map.partition", "Assigned GO {} to layer {} in map {} zone {}",
        goGuid.ToString(), layerId, mapId, zoneId);
}

void LayerManager::RemoveGOFromLayer(uint32 mapId, ObjectGuid const& goGuid)
{
    if (!goGuid || goGuid.GetCounter() == 0)
        return;

    std::unique_lock<std::shared_mutex> guard(_layerLock);
    LayerKey layerKey = MakeLayerKey(mapId, goGuid);

    try
    {
        auto it = _goLayers.find(layerKey);
        if (it != _goLayers.end())
        {
            uint64 indexKey = (static_cast<uint64>(it->second.mapId) << 32) | it->second.layerId;
            auto indexIt = _goLayerIndex.find(indexKey);
            if (indexIt != _goLayerIndex.end())
            {
                indexIt->second.erase(layerKey);
                if (indexIt->second.empty())
                    _goLayerIndex.erase(indexIt);
            }
            _goLayers.erase(it);
        }
    }
    catch (std::exception const& e)
    {
        LOG_ERROR("map.partition", "RemoveGOFromLayer: exception for GO {} map {}: {}",
            goGuid.ToString(), mapId, e.what());
    }
}

uint32 LayerManager::GetLayerForGO(uint32 mapId, ObjectGuid const& goGuid) const
{
    struct LayerCache
    {
        ObjectGuid::LowType guid = 0;
        uint32 mapId = 0;
        uint32 layerId = 0;
        uint64 expiresMs = 0;
    };

    thread_local LayerCache cache;
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    if (cache.guid == goGuid.GetCounter() && cache.mapId == mapId && nowMs <= cache.expiresMs)
        return cache.layerId;

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto it = _goLayers.find(MakeLayerKey(mapId, goGuid));
    if (it == _goLayers.end())
    {
        cache = { goGuid.GetCounter(), mapId, 0, nowMs + 250 };
        return 0;
    }

    if (it->second.mapId != mapId)
    {
        cache = { goGuid.GetCounter(), mapId, 0, nowMs + 250 };
        return 0;
    }

    cache = { goGuid.GetCounter(), mapId, it->second.layerId, nowMs + 250 };
    return it->second.layerId;
}

uint32 LayerManager::GetLayerForGO(ObjectGuid const& goGuid) const
{
    struct LayerCache
    {
        ObjectGuid::LowType guid = 0;
        uint32 layerId = 0;
        uint64 expiresMs = 0;
    };

    thread_local LayerCache cache;
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    if (cache.guid == goGuid.GetCounter() && nowMs <= cache.expiresMs)
        return cache.layerId;

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    ObjectGuid::LowType guidLow = goGuid.GetCounter();
    for (auto const& [key, assignment] : _goLayers)
    {
        if (static_cast<ObjectGuid::LowType>(key) == guidLow)
        {
            cache = { guidLow, assignment.layerId, nowMs + 250 };
            return assignment.layerId;
        }
    }

    cache = { guidLow, 0, nowMs + 250 };
    return 0;
}

void LayerManager::ReassignGOsForNewLayer(uint32 mapId, uint32 layerId)
{
    if (!IsGOLayeringEnabled() || layerId == 0)
        return;

    uint32 spawned = 0;
    sMapMgr->DoForAllMapsWithMapId(mapId, [&](Map* map)
    {
        if (!map)
            return;

        uint8 spawnMode = map->GetSpawnMode();
        for (uint16 gridX = 0; gridX < MAX_NUMBER_OF_GRIDS; ++gridX)
        {
            for (uint16 gridY = 0; gridY < MAX_NUMBER_OF_GRIDS; ++gridY)
            {
                if (!map->IsGridLoaded(GridCoord(gridX, gridY)))
                    continue;

                // Mark this grid+layer as loaded so EnsureGridLayerLoaded won't
                // double-spawn clones later.  (NPC pass already marks it, but GO-only
                // layers need the mark too.)
                map->MarkGridLayerLoaded(gridX, gridY, layerId);

                uint32 gridId = gridY * MAX_NUMBER_OF_GRIDS + gridX;
                CellObjectGuids const& cellGuids = sObjectMgr->GetGridObjectGuids(mapId, spawnMode, gridId);
                for (ObjectGuid::LowType const& spawnId : cellGuids.gameobjects)
                {
                    GameObjectData const* data = sObjectMgr->GetGameObjectData(spawnId);
                    if (!data)
                        continue;

                    if (sObjectMgr->IsGameObjectStaticTransport(data->id))
                        continue;

                    bool existsInLayer = false;
                    auto gameObjects = map->GetGameObjectsBySpawnId(spawnId);
                    for (GameObject* existing : gameObjects)
                    {
                        if (existing && existing->IsLayerClone() && existing->GetLayerCloneId() == layerId)
                        {
                            existsInLayer = true;
                            break;
                        }
                    }

                    if (existsInLayer)
                        continue;

                    GameObject* obj = new GameObject();
                    if (!obj->LoadGameObjectFromDB(spawnId, map, false, true, true, layerId))
                    {
                        delete obj;
                        continue;
                    }

                    if (!map->AddToMap(obj))
                    {
                        delete obj;
                        continue;
                    }

                    ++spawned;
                }
            }
        }
    });

    if (IsRuntimeDiagnosticsEnabled() && spawned > 0)
    {
        LOG_INFO("map.partition", "Diag: ReassignGOsForNewLayer map={} layer={} spawned={}",
            mapId, layerId, spawned);
    }
}

bool LayerManager::CanSwitchLayer(ObjectGuid const& playerGuid) const
{
    if (!IsLayeringEnabled())
        return false;

    // Get player object to check combat and death status
    Player* player = ObjectAccessor::FindPlayer(playerGuid);
    if (!player)
        return false;
    
    // Combat check
    if (player->IsInCombat())
        return false;
    
    // Death check
    if (player->isDead())
        return false;
    
    // Cooldown check
    std::lock_guard<std::mutex> guard(_cooldownLock);
    auto it = _layerSwitchCooldowns.find(playerGuid.GetCounter());
    if (it != _layerSwitchCooldowns.end())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        if (!it->second.CanSwitch(nowMs))
            return false;
    }
    
    return true;
}

uint32 LayerManager::GetLayerSwitchCooldownMs(ObjectGuid const& playerGuid) const
{
    std::lock_guard<std::mutex> guard(_cooldownLock);
    auto it = _layerSwitchCooldowns.find(playerGuid.GetCounter());
    if (it == _layerSwitchCooldowns.end())
        return 0;
    
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    return it->second.GetRemainingCooldownMs(nowMs);
}

bool LayerManager::SwitchPlayerToLayer(ObjectGuid const& playerGuid, uint32 targetLayer, std::string const& reason)
{
    if (!IsLayeringEnabled())
        return false;

    Player* player = ObjectAccessor::FindPlayer(playerGuid);
    if (!player)
        return false;

    if (player->GetMapId() == 0 && player->GetAreaId() == kHinterlandBattleAreaId)
        targetLayer = 0;
    
    // Enforce restrictions
    if (!CanSwitchLayer(playerGuid))
        return false;
    
    uint32 mapId = player->GetMapId();
    
    // Check if target layer actually exists
    {
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto mapIt = _layers.find(mapId);
        if (mapIt == _layers.end())
            return false;
        if (mapIt->second.find(targetLayer) == mapIt->second.end())
            return false;
    }
    
    // Get current layer
    uint32 currentLayer = GetLayerForPlayer(mapId, playerGuid);
    if (currentLayer == targetLayer)
        return false; // Already on target layer
    
    // Perform the switch
    AssignPlayerToLayer(mapId, playerGuid, targetLayer);

    NotifyLayerChange(player, currentLayer, targetLayer, reason);

    // Ensure clone NPCs/GOs for the new layer are loaded on nearby grids
    if (Map* map = player->GetMap())
        map->LoadLayerClonesInRange(player, MAX_VISIBILITY_DISTANCE);

    // Invalidate the per-player layer cache
    player->InvalidateLayerCache();

    // Force visibility rebuild
    player->UpdateObjectVisibility(true, true);
    
    // Record the switch for cooldown tracking
    {
        std::lock_guard<std::mutex> guard(_cooldownLock);
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        _layerSwitchCooldowns[playerGuid.GetCounter()].RecordSwitch(nowMs);
    }
    
    LOG_DEBUG("map.partition", "Player {} switched from layer {} to layer {} (reason: {})",
        playerGuid.ToString(), currentLayer, targetLayer, reason);
    
    if (IsRuntimeDiagnosticsEnabled())
    {
        LOG_INFO("map.partition", "Diag: SwitchPlayerToLayer player={} from={} to={} reason={}",
            playerGuid.ToString(), currentLayer, targetLayer, reason);
    }
    
    return true;
}

bool LayerManager::CreateLayer(uint32 mapId, uint32 layerId, std::string const& reason)
{
    if (!IsLayeringEnabled())
        return false;

    bool created = false;
    {
        std::unique_lock<std::shared_mutex> guard(_layerLock);
        auto& mapLayers = _layers[mapId];

        if (mapLayers.find(layerId) != mapLayers.end())
            return false;

        uint32 layerMax = GetLayerMax();
        if (layerMax == 0)
            layerMax = 1;

        if (mapLayers.size() >= layerMax)
            return false;

        mapLayers[layerId] = {};
        created = true;
    }

    if (created)
    {
        ReassignNPCsForNewLayer(mapId, layerId);
        ReassignGOsForNewLayer(mapId, layerId);

        LOG_INFO("map.partition", "Layer {} created for map {} (reason: {})",
            layerId, mapId, reason);
    }

    return created;
}

void LayerManager::LoadPersistentLayerAssignment(ObjectGuid const& playerGuid)
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_DC_LAYER_ASSIGNMENT);
    stmt->SetData(0, playerGuid.GetCounter());
    
    sWorld->GetQueryProcessor().AddCallback(CharacterDatabase.AsyncQuery(stmt).WithPreparedCallback(
        [this, playerGuid](PreparedQueryResult result)
        {
            if (result)
                HandlePersistentLayerAssignmentLoad(playerGuid, result);
        }));
}

void LayerManager::HandlePersistentLayerAssignmentLoad(ObjectGuid const& playerGuid, PreparedQueryResult result)
{
    if (!_layerPersistenceEnabled)
        return;

    Field* fields = result->Fetch();
    uint32 mapId = fields[0].Get<uint32>();
    // fields[1] is zone_id — ignored in map-wide layering
    uint32 layerId = fields[2].Get<uint32>();

    // Basic sanity check
    if (!MapMgr::IsValidMAP(mapId, false))
        return;

    bool needsReassign = false;
    bool needsDespawn = false;
    uint32 despawnMapId = 0, despawnLayerId = 0;
    {
        std::unique_lock<std::shared_mutex> guard(_layerLock);

        // Check if persisted layer still exists (use find() to avoid auto-creating empty entries)
        auto mapIt = _layers.find(mapId);
        if (mapIt == _layers.end())
            return;
        bool layerExists = mapIt->second.count(layerId) > 0;
        if (!layerExists)
            return; // Persisted layer no longer exists; keep current assignment

        auto it = _playerLayers.find(playerGuid.GetCounter());
        if (it == _playerLayers.end())
        {
            // Player has no current assignment — apply persisted layer directly
            _layers[mapId][layerId].insert(playerGuid.GetCounter());
            _playerLayers[playerGuid.GetCounter()] = { mapId, 0, layerId };
            _atomicPlayerLayers[playerGuid.GetCounter()].Store(mapId, layerId);

            LOG_DEBUG("map.partition", "Restored persistent layer assignment: Player {} -> Map {} Layer {}",
                playerGuid.ToString(), mapId, layerId);
        }
        else if (it->second.mapId == mapId && it->second.layerId != layerId)
        {
            // Player was auto-assigned to a different layer — move to persisted layer.
            // Remove from current layer.
            auto& oldLayer = _layers[it->second.mapId][it->second.layerId];
            oldLayer.erase(playerGuid.GetCounter());
            if (CleanupEmptyLayers(it->second.mapId, it->second.layerId))
            {
                needsDespawn = true;
                despawnMapId = it->second.mapId;
                despawnLayerId = it->second.layerId;
            }

            // Assign to persisted layer
            _layers[mapId][layerId].insert(playerGuid.GetCounter());
            _playerLayers[playerGuid.GetCounter()] = { mapId, 0, layerId };
            _atomicPlayerLayers[playerGuid.GetCounter()].Store(mapId, layerId);

            LOG_DEBUG("map.partition", "Reassigned player to persisted layer: Player {} -> Map {} Layer {}",
                playerGuid.ToString(), mapId, layerId);

            needsReassign = true;
        }
        // else: already on the correct persisted layer, or different map — no action
    }

    // Phase 2: expensive despawn outside lock
    if (needsDespawn)
        DespawnLayerClones(despawnMapId, despawnLayerId);

    // If we moved the player, rebuild visibility outside the lock
    if (needsReassign)
    {
        if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
        {
            if (player->IsInWorld())
            {
                if (Map* map = player->GetMap())
                    map->LoadLayerClonesInRange(player, MAX_VISIBILITY_DISTANCE);
                player->InvalidateLayerCache();
                player->UpdateObjectVisibility(true, true);
            }
        }
    }
}

void LayerManager::SavePersistentLayerAssignment(ObjectGuid const& playerGuid, uint32 mapId, uint32 layerId)
{
    if (!_layerPersistenceEnabled)
        return;

    CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_DC_LAYER_ASSIGNMENT);
    stmt->SetData(0, playerGuid.GetCounter());
    stmt->SetData(1, mapId);
    stmt->SetData(2, uint32(0)); // zone_id legacy column — map-wide layering
    stmt->SetData(3, layerId);
    trans->Append(stmt);
    CharacterDatabase.CommitTransaction(trans);
}

void LayerManager::EvaluateLayerRebalancing(uint32 mapId)
{
    if (!IsLayeringEnabled())
        return;

    std::vector<uint32> layersToMerge;
    
    {
        // Use shared lock for read-only evaluation — no mutation happens here
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto mapIt = _layers.find(mapId);
        if (mapIt == _layers.end())
            return;
        auto& mapLayers = mapIt->second;
        
        if (mapLayers.size() <= 1)
        {
            // Only 1 layer — no consolidation needed, reset destruction hysteresis
            std::lock_guard<std::mutex> hg(_hysteresisLock);
            auto hit = _hysteresisState.find(mapId);
            if (hit != _hysteresisState.end() && hit->second.destructionRequestMs != 0)
            {
                hit->second.destructionRequestMs = 0;
                LOG_DEBUG("map.partition", "Hysteresis: destruction cooldown reset for Map {} (single layer)", mapId);
            }
            return;
        }

        uint32 totalPlayers = 0;
        uint32 capacity = GetLayerCapacity(mapId);
        if (capacity == 0) capacity = 50; // Safety

        for (auto const& [layerId, players] : mapLayers)
        {
            totalPlayers += static_cast<uint32>(players.size());
        }

        // Simple consolidation logic: can we fit everyone into fewer layers?
        if (totalPlayers < capacity && mapLayers.size() > 1)
        {
            // Hysteresis: delay layer destruction to prevent oscillation
            uint32 cooldownMs = GetHysteresisDestructionCooldownMs();
            uint64 nowMs = GameTime::GetGameTimeMS().count();
            bool hysteresisReady = true;

            if (cooldownMs > 0)
            {
                std::lock_guard<std::mutex> hg(_hysteresisLock);
                auto& hs = _hysteresisState[mapId];
                if (hs.destructionRequestMs == 0)
                {
                    // First time condition met — start the cooldown timer
                    hs.destructionRequestMs = nowMs;
                    hysteresisReady = false;
                    LOG_DEBUG("map.partition", "Hysteresis: destruction cooldown started for Map {} ({}ms)", mapId, cooldownMs);
                }
                else if (nowMs < hs.destructionRequestMs + cooldownMs)
                {
                    // Still cooling down
                    hysteresisReady = false;
                    LOG_DEBUG("map.partition", "Hysteresis: destruction cooldown in progress for Map {} ({}ms remaining)",
                        mapId, (hs.destructionRequestMs + cooldownMs) - nowMs);
                }
                else
                {
                    // Cooldown elapsed — allow destruction and reset timer
                    hs.destructionRequestMs = 0;
                    LOG_DEBUG("map.partition", "Hysteresis: destruction cooldown elapsed for Map {}, consolidating", mapId);
                }
            }

            if (hysteresisReady)
            {
                // We can collapse to 1 layer
                for (auto const& [layerId, players] : mapLayers)
                {
                    if (layerId != 0)
                        layersToMerge.push_back(layerId);
                }
            }
        }
        else
        {
            // Condition no longer met — reset destruction hysteresis
            std::lock_guard<std::mutex> hg(_hysteresisLock);
            auto hit = _hysteresisState.find(mapId);
            if (hit != _hysteresisState.end() && hit->second.destructionRequestMs != 0)
            {
                hit->second.destructionRequestMs = 0;
                LOG_DEBUG("map.partition", "Hysteresis: destruction cooldown reset for Map {} (population rose)", mapId);
            }
        }
    }

    // Perform consolidation outside lock if needed
    for (uint32 sourceLayer : layersToMerge)
    {
        ConsolidateLayers(mapId, sourceLayer, 0); // Merge into default layer 0
        _rebalancingMetrics.layersConsolidated.fetch_add(1, std::memory_order_relaxed);
    }
    if (!layersToMerge.empty())
        _rebalancingMetrics.totalRebalances.fetch_add(1, std::memory_order_relaxed);
}

void LayerManager::ConsolidateLayers(uint32 mapId, uint32 sourceLayerId, uint32 targetLayerId)
{
    if (sourceLayerId == targetLayerId)
        return;

    std::vector<ObjectGuid::LowType> playersToMove;

    {
        std::shared_lock<std::shared_mutex> guard(_layerLock); 
        auto mapIt = _layers.find(mapId);
        if (mapIt == _layers.end()) return;
        auto layerIt = mapIt->second.find(sourceLayerId);
        if (layerIt == mapIt->second.end()) return;

        for (auto const& guidLow : layerIt->second)
            playersToMove.push_back(guidLow);
    }

    bool useSoftTransfers = IsSoftTransfersEnabled();
    uint32 migrated = 0;

    for (auto const& guidLow : playersToMove)
    {
        ObjectGuid playerGuid = ObjectGuid::Create<HighGuid::Player>(guidLow);

        if (useSoftTransfers)
        {
            // Queue for next loading screen instead of instant move
            std::lock_guard<std::mutex> stg(_softTransferLock);
            auto& entry = _pendingSoftTransfers[guidLow];
            entry.mapId = mapId;
            entry.sourceLayerId = sourceLayerId;
            entry.targetLayerId = targetLayerId;
            entry.queuedMs = GameTime::GetGameTimeMS().count();
            entry.reason = "rebalance";

            if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
            {
                if (WorldSession* session = player->GetSession())
                {
                    ChatHandler handler(session);
                    handler.PSendSysMessage("|cff00ffffYou will be moved from Layer {} to Layer {} on your next loading screen (rebalancing).|r",
                        sourceLayerId, targetLayerId);
                }
            }
            LOG_DEBUG("map.partition", "Soft transfer queued: player {} Map {} L{} -> L{}", guidLow, mapId, sourceLayerId, targetLayerId);
        }
        else
        {
            // Instant transfer (legacy behavior)
            AssignPlayerToLayer(mapId, playerGuid, targetLayerId);

            if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
            {
                NotifyLayerChange(player, sourceLayerId, targetLayerId, "rebalance");
                player->UpdateObjectVisibility(true, true);
            }
        }
        ++migrated;
    }

    if (migrated > 0)
    {
        LOG_INFO("map.partition", "Layer balance: map={} moved={} (max layers reached)", mapId, migrated);
        _rebalancingMetrics.playersMigrated.fetch_add(migrated, std::memory_order_relaxed);
    }
}

void LayerManager::BalanceLayersAtMax(uint32 mapId)
{
    if (!IsLayeringEnabled())
        return;

    uint32 layerMax = GetLayerMax();
    if (layerMax == 0)
        layerMax = 1;

    uint32 capacity = GetLayerCapacity(mapId);
    if (capacity == 0)
        capacity = 50;

    struct MovePlan
    {
        ObjectGuid::LowType guidLow = 0;
        uint32 sourceLayer = 0;
        uint32 targetLayer = 0;
    };

    std::vector<MovePlan> moves;
    {
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto mapIt = _layers.find(mapId);
        if (mapIt == _layers.end())
            return;

        auto const& mapLayers = mapIt->second;
        uint32 layerCount = static_cast<uint32>(mapLayers.size());
        if (layerCount < layerMax || layerCount <= 1)
            return;

        uint32 totalPlayers = 0;
        std::vector<std::pair<uint32, uint32>> counts; // layerId -> count
        counts.reserve(mapLayers.size());
        for (auto const& [layerId, players] : mapLayers)
        {
            uint32 count = static_cast<uint32>(players.size());
            totalPlayers += count;
            counts.emplace_back(layerId, count);
        }

        if (totalPlayers <= capacity * layerCount)
            return;

        uint32 maxMoves = _rebalancingConfig.migrationBatchSize;
        if (maxMoves == 0)
            maxMoves = 10;

        auto sortCounts = [&]()
        {
            std::sort(counts.begin(), counts.end(), [](auto const& a, auto const& b)
            {
                if (a.second == b.second)
                    return a.first < b.first;
                return a.second < b.second;
            });
        };

        sortCounts();

        while (moves.size() < maxMoves && counts.size() >= 2)
        {
            auto& lowest = counts.front();
            auto& highest = counts.back();
            if (highest.second <= lowest.second + 1)
                break;

            uint32 sourceLayer = highest.first;
            uint32 targetLayer = lowest.first;

            auto layerIt = mapLayers.find(sourceLayer);
            if (layerIt == mapLayers.end() || layerIt->second.empty())
                break;

            ObjectGuid::LowType guidLow = 0;
            for (auto const& candidateLow : layerIt->second)
            {
                ObjectGuid candidateGuid = ObjectGuid::Create<HighGuid::Player>(candidateLow);
                Player* candidate = ObjectAccessor::FindPlayer(candidateGuid);
                if (!candidate)
                    continue;
                if (candidate->GetGroup())
                    continue;
                guidLow = candidateLow;
                break;
            }

            if (guidLow == 0)
                break;

            moves.push_back({ guidLow, sourceLayer, targetLayer });

            --highest.second;
            ++lowest.second;
            sortCounts();
        }
    }

    if (moves.empty())
        return;

    uint32 migrated = 0;
    bool allowImmediate = true;
    if (Map* map = sMapMgr->FindBaseMap(mapId))
        allowImmediate = !(map->IsPartitioned() && map->UseParallelPartitions());
    bool useSoftTransfers = IsSoftTransfersEnabled() || !allowImmediate;
    uint64 nowMs = GameTime::GetGameTimeMS().count();

    for (auto const& move : moves)
    {
        ObjectGuid playerGuid = ObjectGuid::Create<HighGuid::Player>(move.guidLow);

        if (useSoftTransfers)
        {
            std::lock_guard<std::mutex> stg(_softTransferLock);
            if (_pendingSoftTransfers.find(move.guidLow) != _pendingSoftTransfers.end())
                continue;
            auto& entry = _pendingSoftTransfers[move.guidLow];
            entry.mapId = mapId;
            entry.sourceLayerId = move.sourceLayer;
            entry.targetLayerId = move.targetLayer;
            entry.queuedMs = nowMs;
            entry.reason = "balance";
        }
        else
        {
            AssignPlayerToLayer(mapId, playerGuid, move.targetLayer);
            if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
            {
                NotifyLayerChange(player, move.sourceLayer, move.targetLayer, "balance");
                if (player->IsInWorld())
                    player->UpdateObjectVisibility(true, true);
            }
        }

        ++migrated;
    }

    if (migrated > 0)
        _rebalancingMetrics.playersMigrated.fetch_add(migrated, std::memory_order_relaxed);
}

void LayerManager::RebalanceBotLayers(uint32 mapId)
{
    if (!IsLayeringEnabled())
        return;

    uint32 capacity = GetLayerCapacity(mapId);
    if (capacity == 0)
        capacity = 50;

    uint32 sourceLayer = 0;
    uint32 targetLayer = 0;
    uint32 sourceCount = 0;
    uint32 targetCount = 0;

    std::vector<ObjectGuid::LowType> sourcePlayers;
    {
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto mapIt = _layers.find(mapId);
        if (mapIt == _layers.end() || mapIt->second.size() <= 1)
            return;

        std::vector<std::pair<uint32, uint32>> counts;
        counts.reserve(mapIt->second.size());
        for (auto const& [layerId, players] : mapIt->second)
            counts.emplace_back(layerId, static_cast<uint32>(players.size()));

        std::sort(counts.begin(), counts.end(), [](auto const& a, auto const& b)
        {
            if (a.second == b.second)
                return a.first < b.first;
            return a.second < b.second;
        });

        sourceLayer = counts.back().first;
        sourceCount = counts.back().second;

        for (auto const& [layerId, count] : counts)
        {
            if (layerId != sourceLayer && count < capacity)
            {
                targetLayer = layerId;
                targetCount = count;
                break;
            }
        }

        if (!targetLayer || sourceCount <= capacity)
            return;

        auto sourceIt = mapIt->second.find(sourceLayer);
        if (sourceIt == mapIt->second.end())
            return;

        sourcePlayers.reserve(sourceIt->second.size());
        for (auto const& guidLow : sourceIt->second)
            sourcePlayers.push_back(guidLow);
    }

    uint32 maxMoves = _rebalancingConfig.migrationBatchSize;
    if (maxMoves == 0)
        maxMoves = 10;

    uint32 moved = 0;
    for (auto const& guidLow : sourcePlayers)
    {
        if (moved >= maxMoves || targetCount >= capacity)
            break;

        ObjectGuid playerGuid = ObjectGuid::Create<HighGuid::Player>(guidLow);
        Player* player = ObjectAccessor::FindPlayer(playerGuid);
        if (!player || !player->IsInWorld())
            continue;

        WorldSession* session = player->GetSession();
        if (!session || !session->IsBot())
            continue;

        if (player->GetGroup())
            continue;

        AssignPlayerToLayer(mapId, playerGuid, targetLayer);
        NotifyLayerChange(player, sourceLayer, targetLayer, "bot balance");
        player->UpdateObjectVisibility(true, true);

        ++moved;
        ++targetCount;
    }

    if (moved > 0)
        _rebalancingMetrics.playersMigrated.fetch_add(moved, std::memory_order_relaxed);

    if (IsRuntimeDiagnosticsEnabled())
    {
        LOG_INFO("map.partition", "Diag: Bot rebalance map={} L{}->L{} moved={} (sourceCount={} targetCount={})",
            mapId, sourceLayer, targetLayer, moved, sourceCount, targetCount);
    }
    else if (moved > 0)
    {
        LOG_INFO("map.partition", "Bot rebalance: map={} L{}->L{} moved={}",
            mapId, sourceLayer, targetLayer, moved);
    }
}

void LayerManager::PeriodicCacheSweep()
{
    uint64 nowMs = GameTime::GetGameTimeMS().count();

    // 1. Sweep party layer cache
    {
        std::lock_guard<std::mutex> guard(_partyLayerCacheLock);
        for (auto it = _partyTargetLayerCache.begin(); it != _partyTargetLayerCache.end();)
        {
            if (nowMs > it->second.expiresMs)
                it = _partyTargetLayerCache.erase(it);
            else
                ++it;
        }
    }
    
    // 2. Sweep switch cooldowns
    {
        std::lock_guard<std::mutex> guard(_cooldownLock);
        for (auto it = _layerSwitchCooldowns.begin(); it != _layerSwitchCooldowns.end();)
        {
            if (it->second.IsReady(nowMs))
                it = _layerSwitchCooldowns.erase(it);
            else
                ++it;
        }
    }
}

void LayerManager::ProcessPendingSoftTransfers()
{
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    uint32 timeoutMs = GetSoftTransferTimeoutMs();
    if (timeoutMs == 0) timeoutMs = 600000; // Safety: 10 min default

    std::vector<std::pair<ObjectGuid::LowType, SoftTransferEntry>> timedOut;

    {
        std::lock_guard<std::mutex> stg(_softTransferLock);
        for (auto it = _pendingSoftTransfers.begin(); it != _pendingSoftTransfers.end();)
        {
            if (nowMs >= it->second.queuedMs + timeoutMs)
            {
                timedOut.emplace_back(it->first, it->second);
                it = _pendingSoftTransfers.erase(it);
            }
            else
            {
                ++it;
            }
        }
    }

    // Force-apply timed-out soft transfers
    for (auto const& [guidLow, entry] : timedOut)
    {
        // Validate target layer still exists before applying
        {
            std::shared_lock<std::shared_mutex> guard(_layerLock);
            auto mapIt = _layers.find(entry.mapId);
            if (mapIt == _layers.end() || mapIt->second.find(entry.targetLayerId) == mapIt->second.end())
            {
                LOG_DEBUG("map.partition", "Soft transfer timeout skipped: target layer {} gone on Map {} for player {}",
                    entry.targetLayerId, entry.mapId, guidLow);
                continue;
            }
        }

        ObjectGuid playerGuid = ObjectGuid::Create<HighGuid::Player>(guidLow);
        AssignPlayerToLayer(entry.mapId, playerGuid, entry.targetLayerId);

        if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
        {
            NotifyLayerChange(player, entry.sourceLayerId, entry.targetLayerId, "rebalance (timeout)");
            player->UpdateObjectVisibility(true, true);
        }

        LOG_DEBUG("map.partition", "Soft transfer timeout: player {} Map {} L{} -> L{} (forced after {}ms)",
            guidLow, entry.mapId, entry.sourceLayerId, entry.targetLayerId, timeoutMs);
    }
}

void LayerManager::ProcessPendingLayerAssignments()
{
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    std::vector<std::pair<ObjectGuid::LowType, PendingLayerAssignment>> ready;

    {
        std::lock_guard<std::mutex> guard(_pendingLayerAssignmentLock);
        for (auto it = _pendingLayerAssignments.begin(); it != _pendingLayerAssignments.end();)
        {
            if (nowMs >= it->second.readyMs)
            {
                ready.emplace_back(it->first, it->second);
                it = _pendingLayerAssignments.erase(it);
            }
            else
                ++it;
        }
    }

    if (ready.empty())
        return;

    std::vector<std::pair<ObjectGuid::LowType, PendingLayerAssignment>> retryEntries;
    retryEntries.reserve(ready.size());

    for (auto const& [guidLow, entry] : ready)
    {
        ObjectGuid playerGuid = ObjectGuid::Create<HighGuid::Player>(guidLow);
        Player* player = ObjectAccessor::FindPlayer(playerGuid);
        if (!player || player->GetMapId() != entry.mapId)
            continue;

        if (SwitchPlayerToLayer(playerGuid, entry.layerId, "post-join"))
            continue;

        else
        {
            PendingLayerAssignment retry = entry;
            ++retry.retryCount;
            if (retry.retryCount >= PendingLayerAssignment::MAX_RETRIES)
            {
                LOG_WARN("map.partition", "PendingLayerAssignment for guid {} exceeded max retries ({}), removing",
                    guidLow, PendingLayerAssignment::MAX_RETRIES);
                continue;
            }

            retry.readyMs = nowMs + 1000;
            retryEntries.emplace_back(guidLow, retry);
        }
    }

    if (!retryEntries.empty())
    {
        std::lock_guard<std::mutex> guard(_pendingLayerAssignmentLock);
        for (auto const& [guidLow, retry] : retryEntries)
            _pendingLayerAssignments[guidLow] = retry;
    }
}

void LayerManager::ProcessSoftTransferForPlayer(ObjectGuid const& playerGuid)
{
    SoftTransferEntry entry;
    bool found = false;

    {
        std::lock_guard<std::mutex> stg(_softTransferLock);
        auto it = _pendingSoftTransfers.find(playerGuid.GetCounter());
        if (it != _pendingSoftTransfers.end())
        {
            entry = it->second;
            _pendingSoftTransfers.erase(it);
            found = true;
        }
    }

    if (!found)
        return;

    // Validate target layer still exists — it may have been removed between queueing
    // and processing.  If gone, skip and let AutoAssignPlayerToLayer pick a layer.
    {
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto mapIt = _layers.find(entry.mapId);
        if (mapIt == _layers.end() || mapIt->second.find(entry.targetLayerId) == mapIt->second.end())
        {
            LOG_DEBUG("map.partition", "Soft transfer skipped: target layer {} no longer exists on Map {} for player {}",
                entry.targetLayerId, entry.mapId, playerGuid.GetCounter());
            return; // AutoAssignPlayerToLayer will fire right after in Map::AddPlayerToMap
        }
    }

    // Apply the queued layer change now (player is on a loading screen)
    AssignPlayerToLayer(entry.mapId, playerGuid, entry.targetLayerId);

    if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
    {
        NotifyLayerChange(player, entry.sourceLayerId, entry.targetLayerId, entry.reason);
        if (player->IsInWorld())
        {
            if (Map* map = player->GetMap())
                map->LoadLayerClonesInRange(player, MAX_VISIBILITY_DISTANCE);
            player->InvalidateLayerCache();
            player->UpdateObjectVisibility(true, true);
        }
    }

    LOG_DEBUG("map.partition", "Soft transfer applied on loading screen: player {} Map {} L{} -> L{}",
        playerGuid.GetCounter(), entry.mapId, entry.sourceLayerId, entry.targetLayerId);
}

bool LayerManager::HasPendingSoftTransfer(ObjectGuid const& playerGuid) const
{
    std::lock_guard<std::mutex> stg(_softTransferLock);
    return _pendingSoftTransfers.count(playerGuid.GetCounter()) > 0;
}

uint32 LayerManager::GetPendingSoftTransferCount() const
{
    std::lock_guard<std::mutex> stg(_softTransferLock);
    return static_cast<uint32>(_pendingSoftTransfers.size());
}

void LayerManager::Update(uint32 mapId, uint32 diff)
{
    (void)diff;

    if (!IsLayeringEnabled())
        return;

    // 1. Periodic cleanup (throttled global 1s)
    uint64 now = GameTime::GetGameTimeMS().count();
    uint64 lastCleanup = _lastCleanupMs.load(std::memory_order_relaxed);
    if (now > lastCleanup + 1000)
    {
        _lastCleanupMs.store(now, std::memory_order_relaxed);
        PeriodicCacheSweep();
    }

    // 2. Soft transfer timeout processing (throttled: check every 5s globally)
    if (IsSoftTransfersEnabled())
    {
        uint64 lastSoftCheck = _lastSoftTransferCheckMs.load(std::memory_order_relaxed);
        if (now > lastSoftCheck + 5000)
        {
            _lastSoftTransferCheckMs.store(now, std::memory_order_relaxed);
            ProcessPendingSoftTransfers();
        }
    }

    // 3. Layer creation on sustained pressure (map-wide, not tied to map entry)
    // Use shared lock for the read-only evaluation, only escalate if creation is needed.
    uint32 createLayerId = 0;
    {
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto mapIt = _layers.find(mapId);
        if (mapIt != _layers.end() && !mapIt->second.empty())
        {
            uint32 capacity = GetLayerCapacity(mapId);
            if (capacity == 0)
                capacity = 50;

            uint32 layerMax = GetLayerMax();
            if (layerMax == 0)
                layerMax = 1;

            uint32 layerCount = static_cast<uint32>(mapIt->second.size());
            uint32 totalPlayers = 0;
            for (auto const& [_, players] : mapIt->second)
                totalPlayers += static_cast<uint32>(players.size());

            bool pressure = totalPlayers > capacity * layerCount;
            if (!pressure || layerCount >= layerMax)
            {
                std::lock_guard<std::mutex> hg(_hysteresisLock);
                auto hit = _hysteresisState.find(mapId);
                if (hit != _hysteresisState.end() && hit->second.creationRequestMs != 0)
                    hit->second.creationRequestMs = 0;
            }
            else
            {
                uint32 warmupMs = GetHysteresisCreationWarmupMs();
                bool hysteresisReady = true;
                if (warmupMs > 0)
                {
                    std::lock_guard<std::mutex> hg(_hysteresisLock);
                    auto& hs = _hysteresisState[mapId];
                    if (hs.creationRequestMs == 0)
                    {
                        hs.creationRequestMs = now;
                        hysteresisReady = false;
                    }
                    else if (now < hs.creationRequestMs + warmupMs)
                    {
                        hysteresisReady = false;
                    }
                    else
                    {
                        hs.creationRequestMs = 0;
                    }
                }

                if (hysteresisReady)
                {
                    uint32 maxId = 0;
                    for (auto const& [layerId, _] : mapIt->second)
                    {
                        if (layerId > maxId)
                            maxId = layerId;
                    }
                    createLayerId = maxId + 1;
                }
            }
        }
    }

    if (createLayerId != 0)
        CreateLayer(mapId, createLayerId, "auto-pressure");

    // 4. Balance bots across layers (helps fill new layers without relogs)
    RebalanceBotLayers(mapId);

    // 5. Balance load when max layers reached
    BalanceLayersAtMax(mapId);

    // 6. Rebalancing trigger (Blizzard-style: periodic per-map check)
    if (GetRebalancingConfig().enabled)
    {
        uint64 intervalMs = GetRebalancingConfig().checkIntervalMs;
        if (intervalMs == 0) intervalMs = 300000; // Safety: default 5min

        bool shouldRebalance = false;
        {
            std::lock_guard<std::mutex> guard(_rebalanceCheckLock);
            uint64& lastCheck = _lastRebalanceCheck[mapId];
            if (now >= lastCheck + intervalMs)
            {
                lastCheck = now;
                shouldRebalance = true;
            }
        }

        if (shouldRebalance)
            EvaluateLayerRebalancing(mapId);
    }
}

void LayerManager::ForceRemovePlayerFromAllLayers(ObjectGuid const& playerGuid)
{
    bool needsDespawn = false;
    uint32 despawnMapId = 0, despawnLayerId = 0;
    {
        std::unique_lock<std::shared_mutex> guard(_layerLock);
        auto it = _playerLayers.find(playerGuid.GetCounter());
        if (it != _playerLayers.end())
        {
            uint32 oldMapId = it->second.mapId;
            uint32 oldLayerId = it->second.layerId;

            auto& layer = _layers[oldMapId][oldLayerId];
            layer.erase(playerGuid.GetCounter());

            // Clean up the empty layer — defer despawn to outside lock
            if (CleanupEmptyLayers(oldMapId, oldLayerId))
            {
                needsDespawn = true;
                despawnMapId = oldMapId;
                despawnLayerId = oldLayerId;
            }

            _playerLayers.erase(it);

            // Erase atomic entry entirely to prevent unbounded map growth
            _atomicPlayerLayers.erase(playerGuid.GetCounter());

            LOG_DEBUG("map.partition", "Force removed player {} from all layers", playerGuid.ToString());

            if (IsRuntimeDiagnosticsEnabled())
            {
                LOG_INFO("map.partition", "Diag: ForceRemovePlayerFromAllLayers player={}", playerGuid.ToString());
            }
        }
    }

    // Phase 2: expensive despawn outside lock
    if (needsDespawn)
        DespawnLayerClones(despawnMapId, despawnLayerId);

    // Clean up layer switch cooldown to prevent unbounded growth
    {
        std::lock_guard<std::mutex> cooldownGuard(_cooldownLock);
        _layerSwitchCooldowns.erase(playerGuid.GetCounter());
    }

    // Clean up per-player caches to prevent unbounded growth on logout
    {
        std::lock_guard<std::mutex> guard(_partyLayerCacheLock);
        _partyTargetLayerCache.erase(playerGuid.GetCounter());
    }

    // Clean up pending soft transfers on logout
    {
        std::lock_guard<std::mutex> stg(_softTransferLock);
        _pendingSoftTransfers.erase(playerGuid.GetCounter());
    }

    // Clean up any stale pending layer assignments
    {
        std::lock_guard<std::mutex> plg(_pendingLayerAssignmentLock);
        _pendingLayerAssignments.erase(playerGuid.GetCounter());
    }
}

void LayerManager::GetPlayerAndNPCLayer(uint32 mapId, ObjectGuid const& playerGuid,
    ObjectGuid const& npcGuid, uint32& outPlayerLayer, uint32& outNpcLayer) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);

    outPlayerLayer = 0;
    outNpcLayer = 0;

    auto playerIt = _playerLayers.find(playerGuid.GetCounter());
    if (playerIt != _playerLayers.end() && playerIt->second.mapId == mapId)
        outPlayerLayer = playerIt->second.layerId;

    auto npcIt = _npcLayers.find(MakeLayerKey(mapId, npcGuid));
    if (npcIt != _npcLayers.end() && npcIt->second.mapId == mapId)
        outNpcLayer = npcIt->second.layerId;
}

void LayerManager::GetPlayerAndGOLayer(uint32 mapId, ObjectGuid const& playerGuid,
    ObjectGuid const& goGuid, uint32& outPlayerLayer, uint32& outGoLayer) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);

    outPlayerLayer = 0;
    outGoLayer = 0;

    auto playerIt = _playerLayers.find(playerGuid.GetCounter());
    if (playerIt != _playerLayers.end() && playerIt->second.mapId == mapId)
        outPlayerLayer = playerIt->second.layerId;

    auto goIt = _goLayers.find(MakeLayerKey(mapId, goGuid));
    if (goIt != _goLayers.end() && goIt->second.mapId == mapId)
        outGoLayer = goIt->second.layerId;
}

std::vector<uint32> LayerManager::GetLayerPlayerCounts(uint32 mapId) const
{
    std::vector<uint32> counts;

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end())
        return counts;

    // Collect counts ordered by layer ID
    std::map<uint32, uint32> orderedCounts;
    for (auto const& [layerId, players] : mapIt->second)
        orderedCounts[layerId] = static_cast<uint32>(players.size());

    counts.reserve(orderedCounts.size());
    for (auto const& [_, count] : orderedCounts)
        counts.push_back(count);

    return counts;
}

LayerRebalancingConfig const& LayerManager::GetRebalancingConfig() const
{
    return _rebalancingConfig;
}

RebalancingMetrics const& LayerManager::GetRebalancingMetrics() const
{
    return _rebalancingMetrics;
}

std::pair<uint32, uint32> LayerManager::GetLayersForTwoPlayers(
    uint32 mapId,
    ObjectGuid const& player1, ObjectGuid const& player2) const
{
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    ObjectGuid::LowType a = player1.GetCounter();
    ObjectGuid::LowType b = player2.GetCounter();
    if (a > b)
        std::swap(a, b);

    LayerPairCacheKey key{ mapId, a, b };
    // Thread-local cache avoids cross-thread contention and map corruption.
    thread_local LayerPairCacheKey tlKey{};
    thread_local LayerPairCacheEntry tlEntry{};
    thread_local bool tlValid = false;
    if (tlValid && key == tlKey && nowMs <= tlEntry.expiresMs)
        return { tlEntry.layer1, tlEntry.layer2 };

    std::shared_lock<std::shared_mutex> guard(_layerLock);

    uint32 layer1 = 0;
    uint32 layer2 = 0;

    auto it1 = _playerLayers.find(player1.GetCounter());
    if (it1 != _playerLayers.end() && it1->second.mapId == mapId)
        layer1 = it1->second.layerId;

    auto it2 = _playerLayers.find(player2.GetCounter());
    if (it2 != _playerLayers.end() && it2->second.mapId == mapId)
        layer2 = it2->second.layerId;

    tlKey = key;
    tlEntry = { layer1, layer2, nowMs + PartitionConst::LAYER_PAIR_CACHE_TTL_MS };
    tlValid = true;

    return { layer1, layer2 };
}