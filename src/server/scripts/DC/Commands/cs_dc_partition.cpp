/*
 * DC map partitioning commands.
 *
 * Subcommands:
 *  .dc partition status
 *  .dc partition config
 *  .dc partition diag [on|off|status]
 */
#include "Chat.h"
#include "Group.h"
#include "Map.h"
#include "Metric.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "SocialMgr.h"
#include "DBCStores.h"
#include "Maps/Partitioning/PartitionManager.h"
#include "Maps/Partitioning/LayerManager.h"
#include <cctype>
#include <filesystem>
#include <map>
#include <sstream>
#include <unordered_map>

#include <string>

using namespace Acore::ChatCommands;

namespace
{
    std::unordered_map<uint32, uint32> ParseUintOverrides(std::string_view overrides)
    {
        std::unordered_map<uint32, uint32> result;
        if (overrides.empty())
            return result;

        std::string copy(overrides.begin(), overrides.end());
        std::istringstream stream(copy);
        std::string token;
        while (std::getline(stream, token, ','))
        {
            auto start = token.find_first_not_of(" \t");
            auto end = token.find_last_not_of(" \t");
            if (start == std::string::npos)
                continue;
            token = token.substr(start, end - start + 1);

            auto colonPos = token.find(':');
            if (colonPos == std::string::npos || colonPos == 0 || colonPos == token.size() - 1)
                continue;

            try
            {
                uint32 mapId = static_cast<uint32>(std::stoul(token.substr(0, colonPos)));
                uint32 value = static_cast<uint32>(std::stoul(token.substr(colonPos + 1)));
                if (value == 0)
                    continue;
                result[mapId] = value;
            }
            catch (std::exception const&)
            {
                continue;
            }
        }

        return result;
    }

    std::vector<uint32> ParseMapIdList(std::string_view mapList)
    {
        std::vector<uint32> mapIds;
        if (mapList.empty())
            return mapIds;

        std::string copy(mapList.begin(), mapList.end());
        std::istringstream stream(copy);
        std::string token;
        while (std::getline(stream, token, ','))
        {
            std::string trimmed;
            trimmed.reserve(token.size());
            for (char c : token)
            {
                if (c != ' ' && c != '\t' && c != '\n' && c != '\r')
                    trimmed.push_back(c);
            }
            if (trimmed.empty())
                continue;

            try
            {
                mapIds.push_back(static_cast<uint32>(std::stoul(trimmed)));
            }
            catch (std::exception const&)
            {
                continue;
            }
        }

        std::sort(mapIds.begin(), mapIds.end());
        mapIds.erase(std::unique(mapIds.begin(), mapIds.end()), mapIds.end());
        return mapIds;
    }

    std::unordered_map<uint32, uint32> CollectMapTileCounts(std::filesystem::path const& mapsPath)
    {
        std::unordered_map<uint32, uint32> counts;
        if (!std::filesystem::exists(mapsPath))
            return counts;

        for (auto const& entry : std::filesystem::directory_iterator(mapsPath))
        {
            if (!entry.is_regular_file())
                continue;

            auto name = entry.path().filename().string();
            if (name.size() < 5 || name.compare(name.size() - 4, 4, ".map") != 0)
                continue;

            size_t mapIdDigits = name.size() - 4;
            if (mapIdDigits == 0)
                continue;

            bool allDigits = true;
            for (char c : name)
            {
                if (!std::isdigit(static_cast<unsigned char>(c)))
                {
                    allDigits = false;
                    break;
                }
            }
            if (!allDigits)
                continue;

            uint32 mapId = 0;
            try
            {
                mapId = static_cast<uint32>(std::stoul(name.substr(0, mapIdDigits)));
            }
            catch (std::exception const&)
            {
                continue;
            }

            ++counts[mapId];
        }

        return counts;
    }
}

bool HandleDcPartitionSubcommand(ChatHandler* handler, std::vector<std::string_view> const& args, std::vector<std::string_view>::iterator& it)
{
    ++it;
    if (it == args.end())
    {
        handler->PSendSysMessage("Usage: .dc partition status | config | diag [on|off] | tiles");
        handler->SetSentErrorMessage(true);
        return false;
    }

    std::string_view sub2 = *it;
    std::string sub2Norm;
    sub2Norm.reserve(sub2.size());
    for (char c : sub2)
    {
        if (c == '-' || c == '_' || c == ' ') continue;
        sub2Norm.push_back(std::tolower(static_cast<unsigned char>(c)));
    }

    if (sub2Norm == "diag")
    {
        ++it;
        std::string arg = (it != args.end()) ? std::string((*it).data(), (*it).size()) : "status";
        std::string norm;
        norm.reserve(arg.size());
        for (char c : arg)
            if (c != '-' && c != '_' && c != ' ') norm.push_back(std::tolower(static_cast<unsigned char>(c)));

        if (norm == "on" || norm == "enable" || norm == "enabled")
        {
            sLayerMgr->SetRuntimeDiagnosticsEnabled(true);
            handler->SendSysMessage("Partition diagnostics enabled.");
            return true;
        }
        if (norm == "off" || norm == "disable" || norm == "disabled")
        {
            sLayerMgr->SetRuntimeDiagnosticsEnabled(false);
            handler->SendSysMessage("Partition diagnostics disabled.");
            return true;
        }

        uint64 remainingMs = sLayerMgr->GetRuntimeDiagnosticsRemainingMs();
        handler->PSendSysMessage("Partition diagnostics: {}", sLayerMgr->IsRuntimeDiagnosticsEnabled() ? "|cff00ff00ON|r" : "|cffff0000OFF|r");
        handler->PSendSysMessage("Diagnostics window remaining: {} ms", remainingMs);
        handler->PSendSysMessage("Metrics enabled: {}", sMetric->IsEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r");
        if (!sMetric->IsEnabled())
            handler->PSendSysMessage("Enable Metric.Enable=1 and Metric.InfluxDB.Connection in worldserver.conf to see output.");
        return true;
    }

    if (sub2Norm == "tiles")
    {
        std::string_view mapsConfig = sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_MAPS);
        if (mapsConfig.empty())
        {
            handler->SendSysMessage("MapPartitions.Maps is empty. No maps configured for partitioning.");
            return true;
        }

        std::filesystem::path mapsPath = std::filesystem::path(sWorld->GetDataPath()) / "maps";
        auto tileCounts = CollectMapTileCounts(mapsPath);

        bool tileBased = sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_ENABLED);
        uint32 defaultCount = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_DEFAULT_COUNT);
        uint32 tilesPerPartitionDefault = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_TILES_PER_PARTITION);
        uint32 minPartitions = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_MIN_PARTITIONS);
        uint32 maxPartitions = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_MAX_PARTITIONS);
        if (minPartitions == 0)
            minPartitions = 1;
        if (maxPartitions == 0)
            maxPartitions = 1;

        auto tilesPerPartitionOverrides = ParseUintOverrides(
            sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_TILES_PER_PARTITION_OVERRIDES));
        auto partitionOverrides = ParseUintOverrides(
            sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_PARTITION_OVERRIDES));

        handler->SendSysMessage("|cff00ff00=== Map Tile Counts ===|r");
        handler->PSendSysMessage("Data path: {}", mapsPath.string());

        uint8 locale = handler->GetSession() ? handler->GetSessionDbLocaleIndex() : LOCALE_enUS;
        auto mapIds = ParseMapIdList(mapsConfig);
        for (uint32 mapId : mapIds)
        {
            auto it = tileCounts.find(mapId);
            uint32 tileCount = (it != tileCounts.end()) ? it->second : 0;

            std::string mode = "default";
            uint32 partitionCount = defaultCount;
            uint32 tilesPerPartition = tilesPerPartitionDefault;

            if (auto pit = partitionOverrides.find(mapId); pit != partitionOverrides.end())
            {
                partitionCount = pit->second;
                mode = "override";
            }
            else if (tileBased && tilesPerPartitionDefault > 0 && tileCount > 0)
            {
                if (auto tit = tilesPerPartitionOverrides.find(mapId); tit != tilesPerPartitionOverrides.end())
                    tilesPerPartition = tit->second;
                if (tilesPerPartition > 0)
                {
                    partitionCount = (tileCount + tilesPerPartition - 1) / tilesPerPartition;
                    mode = "tile-based";
                }
            }

            if (partitionCount < minPartitions)
                partitionCount = minPartitions;
            if (partitionCount > maxPartitions)
                partitionCount = maxPartitions;

            MapEntry const* mapEntry = sMapStore.LookupEntry(mapId);
            char const* mapName = mapEntry ? mapEntry->name[locale] : "(unknown)";

            handler->PSendSysMessage("Map {} ({}) | tiles={} | partitions={} | mode={}",
                mapId, mapName, tileCount, partitionCount, mode);
        }

        handler->SendSysMessage("|cff888888Note: tile counts are derived from data/maps/*.map files.|r");
        return true;
    }

    if (sub2Norm == "config")
    {
        handler->SendSysMessage("|cff00ff00=== Partition System Configuration ===|r");
        
        // Core Settings
        handler->PSendSysMessage("MapPartitions.Enabled: {}", sPartitionMgr->IsEnabled() ? "|cff00ff00TRUE|r" : "|cffff0000FALSE|r");
        handler->PSendSysMessage("MapPartitions.Maps: |cff00ffff{}|r", sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_MAPS));
        handler->PSendSysMessage("MapPartitions.DefaultCount: |cff00ffff{}|r", sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_DEFAULT_COUNT));
        handler->PSendSysMessage("MapPartitions.BorderOverlap: |cff00ffff{:.1f}|r yards", sPartitionMgr->GetBorderOverlap());
        handler->PSendSysMessage("MapPartitions.StoreOnly: {}", sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_STORE_ONLY) ? "|cff00ff00TRUE|r" : "|cffff0000FALSE|r");

        handler->PSendSysMessage("MapPartitions.TileBased.Enabled: {}",
            sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_ENABLED) ? "|cff00ff00TRUE|r" : "|cffff0000FALSE|r");
        handler->PSendSysMessage("MapPartitions.TileBased.TilesPerPartition: |cff00ffff{}|r",
            sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_TILES_PER_PARTITION));
        handler->PSendSysMessage("MapPartitions.TileBased.MinPartitions: |cff00ffff{}|r",
            sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_MIN_PARTITIONS));
        handler->PSendSysMessage("MapPartitions.TileBased.MaxPartitions: |cff00ffff{}|r",
            sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_MAX_PARTITIONS));

        std::string_view tilesOverrides = sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_TILES_PER_PARTITION_OVERRIDES);
        if (!tilesOverrides.empty())
            handler->PSendSysMessage("MapPartitions.TileBased.TilesPerPartitionOverrides: |cff00ffff{}|r", tilesOverrides);
        else
            handler->PSendSysMessage("MapPartitions.TileBased.TilesPerPartitionOverrides: |cff888888(none)|r");

        std::string_view countOverrides = sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_PARTITION_OVERRIDES);
        if (!countOverrides.empty())
            handler->PSendSysMessage("MapPartitions.TileBased.PartitionOverrides: |cff00ffff{}|r", countOverrides);
        else
            handler->PSendSysMessage("MapPartitions.TileBased.PartitionOverrides: |cff888888(none)|r");
        
        // Zone Exclusions  
        std::string_view excludedZones = sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_EXCLUDE_ZONES);
        if (!excludedZones.empty())
            handler->PSendSysMessage("MapPartitions.ExcludeZones: |cff00ffff{}|r", excludedZones);
        else
            handler->PSendSysMessage("MapPartitions.ExcludeZones: |cff888888(none)|r");
        
        handler->SendSysMessage("");  // Blank line separator
        
        // Layering Settings
        handler->PSendSysMessage("MapPartitions.Layers.Enabled: {}", sLayerMgr->IsLayeringEnabled() ? "|cff00ff00TRUE|r" : "|cffff0000FALSE|r");
        handler->PSendSysMessage("MapPartitions.Layers.Capacity: |cff00ffff{}|r players/layer (global)", sLayerMgr->GetLayerCapacity());
        handler->PSendSysMessage("MapPartitions.Layers.Max: |cff00ffff{}|r layers/map", sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_MAX));

        // Per-map overrides
        std::string_view overrides = sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_LAYER_CAPACITY_OVERRIDES);
        if (!overrides.empty())
            handler->PSendSysMessage("MapPartitions.Layers.CapacityOverrides: |cff00ffff{}|r", overrides);
        else
            handler->PSendSysMessage("MapPartitions.Layers.CapacityOverrides: |cff888888(none — using global)|r");

        // Hysteresis
        handler->PSendSysMessage("Hysteresis.CreationWarmupMs: |cff00ffff{}|r", sLayerMgr->GetHysteresisCreationWarmupMs());
        handler->PSendSysMessage("Hysteresis.DestructionCooldownMs: |cff00ffff{}|r", sLayerMgr->GetHysteresisDestructionCooldownMs());

        // Soft transfers
        handler->PSendSysMessage("SoftTransfers.Enabled: {}", sLayerMgr->IsSoftTransfersEnabled() ? "|cff00ff00TRUE|r" : "|cffff0000FALSE|r");
        handler->PSendSysMessage("SoftTransfers.TimeoutMs: |cff00ffff{}|r", sLayerMgr->GetSoftTransferTimeoutMs());
        
        handler->SendSysMessage("");  // Blank line separator
        handler->SendSysMessage("|cff888888Tip: Use '.dc partition status' to see runtime stats|r");
        return true;
    }

    if (sub2Norm == "status")
    {
        handler->SendSysMessage("|cff00ff00=== Partition System Status ===|r");

        // System Status
        handler->PSendSysMessage("Enabled: {}", sPartitionMgr->IsEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r");
        handler->PSendSysMessage("Layering: {}", sLayerMgr->IsLayeringEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r");
        handler->PSendSysMessage("NPC Layering: {}", sLayerMgr->IsNPCLayeringEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r");
        handler->PSendSysMessage("Border Overlap: {:.1f}", sPartitionMgr->GetBorderOverlap());
        handler->PSendSysMessage("Layer Capacity: {} (global)", sLayerMgr->GetLayerCapacity());
        handler->PSendSysMessage("Soft Transfers: {} (pending: {})",
            sLayerMgr->IsSoftTransfersEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r",
            sLayerMgr->GetPendingSoftTransferCount());

        if (!sPartitionMgr->IsEnabled())
        {
            handler->SendSysMessage("|cffff0000Partition system disabled. Enable MapPartitions.Enabled in config.|r");
            return true;
        }

        if (handler->GetSession() && handler->GetSession()->GetPlayer())
        {
            Player* player = handler->GetSession()->GetPlayer();
            uint32 mapId = player->GetMapId();
            uint32 zoneId = player->GetZoneId();
            float x = player->GetPositionX();
            float y = player->GetPositionY();

            // Current Position
            handler->SendSysMessage("\n|cff00ffffYour Location:|r");
            handler->PSendSysMessage("Map: {} | Zone: {} | Pos: ({:.0f}, {:.0f})", mapId, zoneId, x, y);
            handler->PSendSysMessage("Map Partitioned: {}", sPartitionMgr->IsMapPartitioned(mapId) ? "|cff00ff00Yes|r" : "No");

            uint32 partitionId = sPartitionMgr->GetPartitionIdForPosition(mapId, x, y, zoneId, player->GetGUID());
            uint32 boundaryCount = sPartitionMgr->GetBoundaryCount(mapId, partitionId);
            handler->PSendSysMessage("Partition: |cff00ff00{}|r | Boundary Objects: {}", partitionId, boundaryCount);

            // Layer Info
            if (sLayerMgr->IsLayeringEnabled())
            {
                uint32 layerId = sLayerMgr->GetPlayerLayer(mapId, player->GetGUID());
                handler->PSendSysMessage("Your Layer: |cff00ff00{}|r", layerId);
            }

            // All Partition Stats
            uint32 partitionCount = sPartitionMgr->GetPartitionCount(mapId);
            if (partitionCount > 0)
            {
                handler->PSendSysMessage("\n|cff00ffffPartition Stats (Map {}, {} partitions):|r", mapId, partitionCount);

                uint32 totalPlayers = 0, totalCreatures = 0, totalBoundary = 0;
                for (uint32 pid = 1; pid <= partitionCount; ++pid)
                {
                    PartitionManager::PartitionStats stats;
                    if (sPartitionMgr->GetPartitionStats(mapId, pid, stats))
                    {
                        bool isCurrent = (pid == partitionId);
                        handler->PSendSysMessage("  P{}: players={}, creatures={}, boundary={}{}",
                            pid, stats.players, stats.creatures, stats.boundaryObjects,
                            isCurrent ? " |cff00ff00<-- YOU|r" : "");
                        totalPlayers += stats.players;
                        totalCreatures += stats.creatures;
                        totalBoundary += stats.boundaryObjects;
                    }
                }
                handler->PSendSysMessage("  Total: players={}, creatures={}, boundary={}",
                    totalPlayers, totalCreatures, totalBoundary);
            }

            // NPC layer counts by zone
            if (sLayerMgr->IsNPCLayeringEnabled())
            {
                LayerManager::LayerCountByZone npcCounts;
                sLayerMgr->GetNPCLayerCountsByZone(mapId, npcCounts);
                if (!npcCounts.empty())
                {
                    handler->SendSysMessage("\n|cff00ffffNPC Layer Counts by Zone:|r");
                    for (auto const& [zone, layerCounts] : npcCounts)
                    {
                        std::string line;
                        for (auto const& [layerId, count] : layerCounts)
                        {
                            if (!line.empty())
                                line += " ";
                            line += "L" + std::to_string(layerId) + "=" + std::to_string(count);
                        }
                        handler->PSendSysMessage("  Zone {}: {}", zone, line.empty() ? "(none)" : line);
                    }
                }
            }

            // Grid Layout
            PartitionManager::PartitionGridLayout const* layout = sPartitionMgr->GetCachedLayout(mapId);
            if (layout && layout->count > 1)
            {
                handler->PSendSysMessage("\n|cff00ffffGrid:|r {}x{} ({} partitions)",
                    layout->cols, layout->rows, layout->count);

                uint32 col = (partitionId - 1) % layout->cols;
                uint32 row = (partitionId - 1) / layout->cols;
                handler->PSendSysMessage("Your Cell: col={}, row={}", col, row);

                // Adjacent partitions
                std::string adjList;
                if (col > 0) adjList += std::to_string(partitionId - 1) + " ";
                if (col < layout->cols - 1) adjList += std::to_string(partitionId + 1) + " ";
                if (row > 0) adjList += std::to_string(partitionId - layout->cols) + " ";
                if (row < layout->rows - 1) adjList += std::to_string(partitionId + layout->cols);
                if (!adjList.empty())
                    handler->PSendSysMessage("Adjacent: [{}]", adjList);
            }
        }
        return true;
    }

    handler->PSendSysMessage("Usage: .dc partition status | config | diag [on|off] | tiles");
    handler->SetSentErrorMessage(true);
    return false;
}

bool HandleDcLayerSubcommand(ChatHandler* handler, std::vector<std::string_view> const& args, std::vector<std::string_view>::iterator& it)
{
    ++it;

    // Default to "status" if no subcommand given (e.g. ".dc layer")
    std::string sub2Norm = "status";
    std::string_view sub2;
    if (it != args.end())
    {
        sub2 = *it;
        sub2Norm.clear();
        sub2Norm.reserve(sub2.size());
        for (char c : sub2)
        {
            if (c == '-' || c == '_' || c == ' ') continue;
            sub2Norm.push_back(std::tolower(static_cast<unsigned char>(c)));
        }
    }

    if (sub2Norm == "status")
    {
        handler->SendSysMessage("|cff00ff00=== Layer Status ===|r");
        handler->PSendSysMessage("Layering: {}", sLayerMgr->IsLayeringEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r");
        handler->PSendSysMessage("NPC Layering: {}", sLayerMgr->IsNPCLayeringEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r");
        handler->PSendSysMessage("GO Layering: {}", sLayerMgr->IsGOLayeringEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r");

        if (!sLayerMgr->IsLayeringEnabled())
            return true;

        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        uint32 mapId = 0;
        uint32 zoneId = 0;
        uint32 layerId = 0;
        bool hasPlayerContext = player != nullptr;

        if (hasPlayerContext)
        {
            mapId = player->GetMapId();
            if (Map* map = player->GetMap())
                zoneId = map->GetZoneId(player->GetPhaseMask(), player->GetPositionX(), player->GetPositionY(), player->GetPositionZ());
            else
                zoneId = player->GetZoneId();
            layerId = sLayerMgr->GetPlayerLayer(mapId, player->GetGUID());
        }
        else
        {
            auto next = it;
            ++next;
            if (next == args.end())
            {
                handler->PSendSysMessage("Usage (console): .dc layer status <mapId> [zoneId]");
                handler->SetSentErrorMessage(true);
                return false;
            }

            try { mapId = static_cast<uint32>(std::stoul(std::string((*next).data(), (*next).size()))); }
            catch (...) { mapId = 0; }

            ++next;
            if (next != args.end())
            {
                try { zoneId = static_cast<uint32>(std::stoul(std::string((*next).data(), (*next).size()))); }
                catch (...) { zoneId = 0; }
            }

            if (mapId == 0)
            {
                handler->PSendSysMessage("|cffff0000Invalid mapId. Usage (console): .dc layer status <mapId> [zoneId]|r");
                handler->SetSentErrorMessage(true);
                return false;
            }
        }

        uint32 layerCount = sLayerMgr->GetLayerCount(mapId);

        uint8 locale = handler->GetSessionDbLocaleIndex();
        MapEntry const* mapEntry = sMapStore.LookupEntry(mapId);
        AreaTableEntry const* areaEntry = sAreaTableStore.LookupEntry(zoneId);
        char const* mapName = mapEntry ? mapEntry->name[locale] : "(unknown)";
        char const* zoneName = areaEntry ? areaEntry->area_name[locale] : "(unknown)";
        handler->PSendSysMessage("Map: {} ({}) | Zone: {} ({})", mapId, mapName, zoneId, zoneName);
        if (hasPlayerContext)
            handler->PSendSysMessage("Your Layer: |cff00ff00{}|r | Layer Count: {}", layerId, layerCount);
        else
            handler->PSendSysMessage("Layer Count: {}", layerCount);

        // Show capacity info so the user understands why there are N layers
        uint32 capacity = sLayerMgr->GetLayerCapacity(mapId);
        uint32 globalCapacity = sLayerMgr->GetLayerCapacity();
        if (capacity != globalCapacity)
            handler->PSendSysMessage("Layer Capacity: {} players/layer (map override; global: {})", capacity, globalCapacity);
        else
            handler->PSendSysMessage("Layer Capacity: {} players/layer", capacity);

        std::map<uint32, uint32> playerCounts;
        sLayerMgr->GetLayerPlayerCountsByLayer(mapId, playerCounts);

        std::vector<uint32> layerIds = sLayerMgr->GetLayerIds(mapId);
        if (layerIds.empty() && !playerCounts.empty())
        {
            layerIds.reserve(playerCounts.size());
            for (auto const& [layerId, _] : playerCounts)
                layerIds.push_back(layerId);
        }
        if (layerIds.empty() && layerCount > 0)
        {
            layerIds.reserve(layerCount);
            for (uint32 i = 0; i < layerCount; ++i)
                layerIds.push_back(i);
        }
        uint32 totalMapPlayers = 0;
        for (auto const& [_, count] : playerCounts)
            totalMapPlayers += count;
        handler->SendSysMessage("\n|cff00ffffPlayer Counts by Layer:|r");
        for (uint32 layer : layerIds)
        {
            uint32 count = 0;
            auto itCount = playerCounts.find(layer);
            if (itCount != playerCounts.end())
                count = itCount->second;
            handler->PSendSysMessage("  L{}: {} players{}", layer, count,
                (hasPlayerContext && layer == layerId ? " |cff00ff00<-- YOU|r" : ""));
        }

        // Explain threshold for next layer
        if (capacity > 0 && layerCount <= 1)
        {
            uint32 warmupMs = sLayerMgr->GetHysteresisCreationWarmupMs();
            if (warmupMs > 0)
                handler->PSendSysMessage("\n|cff888888Next layer created when >{} players on this map for {}s (current: {}).|r",
                    capacity, warmupMs / 1000, totalMapPlayers);
            else
                handler->PSendSysMessage("\n|cff888888Next layer created when >{} players on this map (current: {}).|r",
                    capacity, totalMapPlayers);
        }

        // Pending soft transfer
        if (hasPlayerContext && sLayerMgr->HasPendingSoftTransfer(player->GetGUID()))
        {
            handler->SendSysMessage("\n|cffff8800You have a pending soft transfer! It will apply on your next loading screen.|r");
        }

        if (sLayerMgr->IsNPCLayeringEnabled())
        {
            LayerManager::LayerCountByZone npcCounts;
            sLayerMgr->GetNPCLayerCountsByZone(mapId, npcCounts);

            std::map<uint32, uint32> mapWideNpcCounts;
            for (uint32 layer : layerIds)
                mapWideNpcCounts[layer] = 0;
            for (auto const& [_, layerCounts] : npcCounts)
                for (auto const& [layer, count] : layerCounts)
                    mapWideNpcCounts[layer] += count;

            handler->SendSysMessage("\n|cff00ffffNPC Counts by Layer (map-wide, loaded):|r");
            for (uint32 layer : layerIds)
                handler->PSendSysMessage("  L{}: {} NPCs", layer, mapWideNpcCounts[layer]);
            handler->SendSysMessage("|cff888888Note: counts reflect loaded objects only.|r");

            auto zoneIt = npcCounts.find(zoneId);
            if (zoneId != 0)
            {
                handler->SendSysMessage("\n|cff00ffffNPC Counts by Layer (your zone):|r");
                for (uint32 layer : layerIds)
                {
                    uint32 count = 0;
                    if (zoneIt != npcCounts.end())
                    {
                        auto itLayer = zoneIt->second.find(layer);
                        if (itLayer != zoneIt->second.end())
                            count = itLayer->second;
                    }
                    handler->PSendSysMessage("  L{}: {} NPCs", layer, count);
                }
                handler->SendSysMessage("|cff888888Note: counts reflect loaded objects only.|r");
            }
        }

        if (sLayerMgr->IsGOLayeringEnabled())
        {
            LayerManager::LayerCountByZone goCounts;
            sLayerMgr->GetGOLayerCountsByZone(mapId, goCounts);

            std::map<uint32, uint32> mapWideGoCounts;
            for (uint32 layer : layerIds)
                mapWideGoCounts[layer] = 0;
            for (auto const& [_, layerCounts] : goCounts)
                for (auto const& [layer, count] : layerCounts)
                    mapWideGoCounts[layer] += count;

            handler->SendSysMessage("\n|cff00ffffGO Counts by Layer (map-wide, loaded):|r");
            for (uint32 layer : layerIds)
                handler->PSendSysMessage("  L{}: {} GOs", layer, mapWideGoCounts[layer]);
            handler->SendSysMessage("|cff888888Note: counts reflect loaded objects only.|r");

            auto zoneIt = goCounts.find(zoneId);
            if (zoneId != 0)
            {
                handler->SendSysMessage("\n|cff00ffffGO Counts by Layer (your zone):|r");
                for (uint32 layer : layerIds)
                {
                    uint32 count = 0;
                    if (zoneIt != goCounts.end())
                    {
                        auto itLayer = zoneIt->second.find(layer);
                        if (itLayer != zoneIt->second.end())
                            count = itLayer->second;
                    }
                    handler->PSendSysMessage("  L{}: {} GOs", layer, count);
                }
                handler->SendSysMessage("|cff888888Note: counts reflect loaded objects only.|r");
            }
        }
        return true;
    }

    if (sub2Norm == "join")
    {
        ++it;
        if (it == args.end())
        {
            handler->PSendSysMessage("Usage: .dc layer join <playername>");
            handler->SetSentErrorMessage(true);
            return false;
        }

        if (!sLayerMgr->IsLayeringEnabled())
        {
            handler->PSendSysMessage("|cffff0000Layering is not enabled. Check config.|r");
            return false;
        }

        Player* player = handler->GetSession()->GetPlayer();
        if (Group* group = player->GetGroup())
        {
            if (!group->IsLeader(player->GetGUID()))
            {
                handler->PSendSysMessage("|cffff0000Only the group leader can use .dc layer join while in a group.|r");
                return false;
            }
        }
        std::string targetName((*it).data(), (*it).size());

        Player* target = ObjectAccessor::FindPlayerByName(targetName);
        if (!target)
        {
            handler->PSendSysMessage("|cffff0000Player '{}' not found or not online.|r", targetName);
            return false;
        }

        if (target->GetGUID() == player->GetGUID())
        {
            handler->PSendSysMessage("|cffff0000You cannot join yourself.|r");
            return false;
        }

        if (target->GetMapId() != player->GetMapId())
        {
            handler->PSendSysMessage("|cffff0000Player '{}' is not on the same map.|r", targetName);
            return false;
        }

        bool isFriend = player->GetSocial() && player->GetSocial()->HasFriend(target->GetGUID());
        bool isGuildMate = player->GetGuildId() != 0 && player->GetGuildId() == target->GetGuildId();
        bool isGroupMate = player->GetGroup() && player->GetGroup() == target->GetGroup();

        if (!isFriend && !isGuildMate && !isGroupMate)
        {
            handler->PSendSysMessage("|cffff0000You can only join friends, guildmates, or group members.|r");
            return false;
        }

        if (!sLayerMgr->CanSwitchLayer(player->GetGUID()))
        {
            uint32 cooldownMs = sLayerMgr->GetLayerSwitchCooldownMs(player->GetGUID());
            if (cooldownMs > 0)
            {
                uint32 cooldownSec = (cooldownMs + 999) / 1000;
                handler->PSendSysMessage("|cffff0000Layer switch on cooldown. {} seconds remaining.|r", cooldownSec);
            }
            else if (player->IsInCombat())
            {
                handler->PSendSysMessage("|cffff0000Cannot switch layers while in combat.|r");
            }
            else if (player->isDead())
            {
                handler->PSendSysMessage("|cffff0000Cannot switch layers while dead.|r");
            }
            else
            {
                handler->PSendSysMessage("|cffff0000Cannot switch layers at this time.|r");
            }
            return false;
        }

        uint32 targetLayer = sLayerMgr->GetPlayerLayer(target->GetMapId(), target->GetGUID());
        uint32 currentLayer = sLayerMgr->GetPlayerLayer(player->GetMapId(), player->GetGUID());

        if (targetLayer == currentLayer)
        {
            handler->PSendSysMessage("|cff00ff00You are already on the same layer as {}.|r", target->GetName());
            return true;
        }

        std::string reason = "join command: " + std::string(target->GetName());
        if (sLayerMgr->SwitchPlayerToLayer(player->GetGUID(), targetLayer, reason))
        {
            handler->PSendSysMessage("|cff00ff00Joined {}'s layer (Layer {}).|r", target->GetName(), targetLayer);
            return true;
        }

        handler->PSendSysMessage("|cffff0000Failed to switch layers.|r");
        return false;
    }

    if (!sLayerMgr->IsLayeringEnabled())
    {
        handler->PSendSysMessage("|cffff0000Layering is not enabled. check config.|r");
        return false;
    }

    std::string layerArg(sub2.data(), sub2.size());
    uint32 layerId = 0;
    try { layerId = std::stoul(layerArg); } catch(...) { layerId = 0; }

    Player* player = handler->GetSession()->GetPlayer();
    if (Group* group = player->GetGroup())
    {
        if (!group->IsLeader(player->GetGUID()))
        {
            handler->PSendSysMessage("|cffff0000Only the group leader can change layers with .dc layer <id>.|r");
            return false;
        }
    }

    uint32 currentLayer = sLayerMgr->GetPlayerLayer(player->GetMapId(), player->GetGUID());
    if (currentLayer == layerId)
    {
        handler->PSendSysMessage("|cff00ff00You are already on Layer {}.|r", layerId);
        return true;
    }

    std::string reason = "command: .dc layer " + layerArg;

    // Create the layer on demand for testing if it does not exist.
    bool layerExists = false;
    for (uint32 existingId : sLayerMgr->GetLayerIds(player->GetMapId()))
    {
        if (existingId == layerId)
        {
            layerExists = true;
            break;
        }
    }

    if (!layerExists)
    {
        if (!sLayerMgr->CreateLayer(player->GetMapId(), layerId, reason))
        {
            uint32 mapLayerCount = sLayerMgr->GetLayerCount(player->GetMapId());
            uint32 layerMax = sLayerMgr->GetLayerMax();
            uint32 capacity = sLayerMgr->GetLayerCapacity();
            handler->PSendSysMessage("|cffff0000Layer {} does not exist and could not be created.|r", layerId);
            handler->PSendSysMessage("|cff888888This map has {} layer(s). Max is {}. Capacity is {} players/layer.|r",
                mapLayerCount, layerMax, capacity);
            handler->PSendSysMessage("|cff888888Use '.dc layer status' to see current layers.|r");
            return false;
        }
        handler->PSendSysMessage("|cff00ff00Created Layer {} on this map.|r", layerId);
    }

    if (!sLayerMgr->SwitchPlayerToLayer(player->GetGUID(), layerId, reason))
    {
        // SwitchPlayerToLayer checks combat, death, cooldown, and layer existence
        if (!sLayerMgr->CanSwitchLayer(player->GetGUID()))
        {
            uint32 cooldownMs = sLayerMgr->GetLayerSwitchCooldownMs(player->GetGUID());
            if (cooldownMs > 0)
                handler->PSendSysMessage("|cffff0000Layer switch on cooldown. {} seconds remaining.|r", (cooldownMs + 999) / 1000);
            else if (player->IsInCombat())
                handler->PSendSysMessage("|cffff0000Cannot switch layers while in combat.|r");
            else if (player->isDead())
                handler->PSendSysMessage("|cffff0000Cannot switch layers while dead.|r");
            else
                handler->PSendSysMessage("|cffff0000Cannot switch layers at this time.|r");
        }
        else
        {
            uint32 mapLayerCount = sLayerMgr->GetLayerCount(player->GetMapId());
            uint32 capacity = sLayerMgr->GetLayerCapacity();
            handler->PSendSysMessage("|cffff0000Layer {} does not exist on this map.|r", layerId);
            handler->PSendSysMessage("|cff888888This map has {} layer(s). Capacity is {} players/layer.", mapLayerCount, capacity);
            handler->PSendSysMessage("|cff888888Use '.dc layer status' to see current layers.|r");
        }
        return false;
    }

    handler->PSendSysMessage("Moved to Layer |cff00ff00{}|r.", layerId);
    return true;
}
