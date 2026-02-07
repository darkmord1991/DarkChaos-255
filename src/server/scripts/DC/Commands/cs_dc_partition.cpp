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
#include <map>

#include <string>

using namespace Acore::ChatCommands;

bool HandleDcPartitionSubcommand(ChatHandler* handler, std::vector<std::string_view> const& args, std::vector<std::string_view>::iterator& it)
{
    ++it;
    if (it == args.end())
    {
        handler->PSendSysMessage("Usage: .dc partition status | config | diag [on|off]");
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

    if (sub2Norm == "config")
    {
        handler->SendSysMessage("|cff00ff00=== Partition System Configuration ===|r");
        
        // Core Settings
        handler->PSendSysMessage("MapPartitions.Enabled: {}", sPartitionMgr->IsEnabled() ? "|cff00ff00TRUE|r" : "|cffff0000FALSE|r");
        handler->PSendSysMessage("MapPartitions.Maps: |cff00ffff{}|r", sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_MAPS));
        handler->PSendSysMessage("MapPartitions.DefaultCount: |cff00ffff{}|r", sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_DEFAULT_COUNT));
        handler->PSendSysMessage("MapPartitions.BorderOverlap: |cff00ffff{:.1f}|r yards", sPartitionMgr->GetBorderOverlap());
        handler->PSendSysMessage("MapPartitions.StoreOnly: {}", sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_STORE_ONLY) ? "|cff00ff00TRUE|r" : "|cffff0000FALSE|r");
        
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

    handler->PSendSysMessage("Usage: .dc partition status | config | diag [on|off]");
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
        if (!player)
            return true;

        uint32 mapId = player->GetMapId();
        uint32 zoneId = 0;
        if (Map* map = player->GetMap())
            zoneId = map->GetZoneId(player->GetPhaseMask(), player->GetPositionX(), player->GetPositionY(), player->GetPositionZ());
        else
            zoneId = player->GetZoneId();
        uint32 layerId = sLayerMgr->GetPlayerLayer(mapId, player->GetGUID());
        uint32 layerCount = sLayerMgr->GetLayerCount(mapId);

        uint8 locale = handler->GetSessionDbLocaleIndex();
        MapEntry const* mapEntry = sMapStore.LookupEntry(mapId);
        AreaTableEntry const* areaEntry = sAreaTableStore.LookupEntry(zoneId);
        char const* mapName = mapEntry ? mapEntry->name[locale] : "(unknown)";
        char const* zoneName = areaEntry ? areaEntry->area_name[locale] : "(unknown)";
        handler->PSendSysMessage("Map: {} ({}) | Zone: {} ({})", mapId, mapName, zoneId, zoneName);
        handler->PSendSysMessage("Your Layer: |cff00ff00{}|r | Layer Count: {}", layerId, layerCount);

        // Show capacity info so the user understands why there are N layers
        uint32 capacity = sLayerMgr->GetLayerCapacity(mapId);
        uint32 globalCapacity = sLayerMgr->GetLayerCapacity();
        if (capacity != globalCapacity)
            handler->PSendSysMessage("Layer Capacity: {} players/layer (map override; global: {})", capacity, globalCapacity);
        else
            handler->PSendSysMessage("Layer Capacity: {} players/layer", capacity);

        std::map<uint32, uint32> playerCounts;
        sLayerMgr->GetLayerPlayerCountsByLayer(mapId, playerCounts);
        uint32 totalMapPlayers = 0;
        for (auto const& [_, count] : playerCounts)
            totalMapPlayers += count;
        if (!playerCounts.empty())
        {
            handler->SendSysMessage("\n|cff00ffffPlayer Counts by Layer:|r");
            for (auto const& [layer, count] : playerCounts)
                handler->PSendSysMessage("  L{}: {} players{}", layer, count, (layer == layerId ? " |cff00ff00<-- YOU|r" : ""));
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
        if (sLayerMgr->HasPendingSoftTransfer(player->GetGUID()))
        {
            handler->SendSysMessage("\n|cffff8800You have a pending soft transfer! It will apply on your next loading screen.|r");
        }

        if (sLayerMgr->IsNPCLayeringEnabled())
        {
            LayerManager::LayerCountByZone npcCounts;
            sLayerMgr->GetNPCLayerCountsByZone(mapId, npcCounts);
            auto zoneIt = npcCounts.find(zoneId);
            if (zoneIt != npcCounts.end())
            {
                handler->SendSysMessage("\n|cff00ffffNPC Counts by Layer (your zone):|r");
                for (auto const& [layer, count] : zoneIt->second)
                    handler->PSendSysMessage("  L{}: {} NPCs", layer, count);
                handler->SendSysMessage("|cff888888Note: counts reflect loaded objects only.|r");
            }
        }

        if (sLayerMgr->IsGOLayeringEnabled())
        {
            LayerManager::LayerCountByZone goCounts;
            sLayerMgr->GetGOLayerCountsByZone(mapId, goCounts);
            auto zoneIt = goCounts.find(zoneId);
            if (zoneIt != goCounts.end())
            {
                handler->SendSysMessage("\n|cff00ffffGO Counts by Layer (your zone):|r");
                for (auto const& [layer, count] : zoneIt->second)
                    handler->PSendSysMessage("  L{}: {} GOs", layer, count);
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
