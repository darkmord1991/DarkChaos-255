/*
 * DC map partitioning commands.
 *
 * Subcommands:
 *  .dc partition status
 *  .dc partition config
 *  .dc partition layer <layerId>
 *  .dc partition join <player>
 *  .dc partition diag [on|off|status]
 */
#include "Chat.h"
#include "Map.h"
#include "Metric.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "SocialMgr.h"
#include "Maps/Partitioning/PartitionManager.h"

using namespace Acore::ChatCommands;

bool HandleDcPartitionSubcommand(ChatHandler* handler, std::vector<std::string_view> const& args, std::vector<std::string_view>::iterator& it)
{
    ++it;
    if (it == args.end())
    {
        handler->PSendSysMessage("Usage: .dc partition status | config | layer <id> | join <player> | diag [on|off]");
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

    if (sub2Norm == "join")
    {
        ++it;
        if (it == args.end())
        {
            handler->PSendSysMessage("Usage: .dc partition join <playername>");
            handler->SetSentErrorMessage(true);
            return false;
        }

        if (!sPartitionMgr->IsLayeringEnabled())
        {
            handler->PSendSysMessage("|cffff0000Layering is not enabled. Check config.|r");
            return false;
        }

        Player* player = handler->GetSession()->GetPlayer();
        std::string targetName((*it).data(), (*it).size());
        
        // Find target player
        Player* target = ObjectAccessor::FindPlayerByName(targetName);
        if (!target)
        {
            handler->PSendSysMessage("|cffff0000Player '{}' not found or not online.|r", targetName);
            return false;
        }
        
        // Check if same player
        if (target->GetGUID() == player->GetGUID())
        {
            handler->PSendSysMessage("|cffff0000You cannot join yourself.|r");
            return false;
        }
        
        // Check if same map/zone
        if (target->GetMapId() != player->GetMapId() || target->GetZoneId() != player->GetZoneId())
        {
            handler->PSendSysMessage("|cffff0000Player '{}' is not in the same zone.|r", targetName);
            return false;
        }
        
        // Check friend or guild relationship
        bool isFriend = player->GetSocial() && player->GetSocial()->HasFriend(target->GetGUID());
        bool isGuildMate = player->GetGuildId() != 0 && player->GetGuildId() == target->GetGuildId();
        bool isGroupMate = player->GetGroup() && player->GetGroup() == target->GetGroup();
        
        if (!isFriend && !isGuildMate && !isGroupMate)
        {
            handler->PSendSysMessage("|cffff0000You can only join friends, guildmates, or group members.|r");
            return false;
        }
        
        // Check if can switch (combat, death, cooldown)
        if (!sPartitionMgr->CanSwitchLayer(player->GetGUID()))
        {
            uint32 cooldownMs = sPartitionMgr->GetLayerSwitchCooldownMs(player->GetGUID());
            if (cooldownMs > 0)
            {
                uint32 cooldownSec = (cooldownMs + 999) / 1000;  // Round up
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
        
        // Get target's layer
        uint32 targetLayer = sPartitionMgr->GetPlayerLayer(target->GetMapId(), target->GetZoneId(), target->GetGUID());
        uint32 currentLayer = sPartitionMgr->GetPlayerLayer(player->GetMapId(), player->GetZoneId(), player->GetGUID());
        
        if (targetLayer == currentLayer)
        {
            handler->PSendSysMessage("|cff00ff00You are already on the same layer as {}.|r", target->GetName());
            return true;
        }
        
        // Perform the switch
        std::string reason = "join command: " + std::string(target->GetName());
        if (sPartitionMgr->SwitchPlayerToLayer(player->GetGUID(), targetLayer, reason))
        {
            handler->PSendSysMessage("|cff00ff00Joined {}'s layer (Layer {}).|r", target->GetName(), targetLayer);
            return true;
        }
        else
        {
            handler->PSendSysMessage("|cffff0000Failed to switch layers.|r");
            return false;
        }
    }

    if (sub2Norm == "layer")
    {
        ++it;
        if (it == args.end())
        {
            handler->PSendSysMessage("Usage: .dc partition layer <layerId>");
            handler->SetSentErrorMessage(true);
            return false;
        }

        if (!sPartitionMgr->IsLayeringEnabled())
        {
            handler->PSendSysMessage("|cffff0000Layering is not enabled. check config.|r");
            return false;
        }

        std::string layerArg((*it).data(), (*it).size());
        uint32 layerId = 0;
        try { layerId = std::stoul(layerArg); } catch(...) { layerId = 0; }

        Player* player = handler->GetSession()->GetPlayer();
        uint32 mapId = player->GetMapId();
        uint32 zoneId = player->GetZoneId();

        sPartitionMgr->AssignPlayerToLayer(mapId, zoneId, player->GetGUID(), layerId);
        handler->PSendSysMessage("Moved to Layer |cff00ff00{}|r.", layerId);
        return true;
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
            sPartitionMgr->SetRuntimeDiagnosticsEnabled(true);
            handler->SendSysMessage("Partition diagnostics enabled.");
            return true;
        }
        if (norm == "off" || norm == "disable" || norm == "disabled")
        {
            sPartitionMgr->SetRuntimeDiagnosticsEnabled(false);
            handler->SendSysMessage("Partition diagnostics disabled.");
            return true;
        }

        uint64 remainingMs = sPartitionMgr->GetRuntimeDiagnosticsRemainingMs();
        handler->PSendSysMessage("Partition diagnostics: {}", sPartitionMgr->IsRuntimeDiagnosticsEnabled() ? "|cff00ff00ON|r" : "|cffff0000OFF|r");
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
        std::string excludedZones = sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_EXCLUDE_ZONES);
        if (!excludedZones.empty())
            handler->PSendSysMessage("MapPartitions.ExcludeZones: |cff00ffff{}|r", excludedZones);
        else
            handler->PSendSysMessage("MapPartitions.ExcludeZones: |cff888888(none)|r");
        
        handler->SendSysMessage("");  // Blank line separator
        
        // Layering Settings
        handler->PSendSysMessage("MapPartitions.Layers.Enabled: {}", sPartitionMgr->IsLayeringEnabled() ? "|cff00ff00TRUE|r" : "|cffff0000FALSE|r");
        handler->PSendSysMessage("MapPartitions.Layers.Capacity: |cff00ffff{}|r players/layer", sPartitionMgr->GetLayerCapacity());
        handler->PSendSysMessage("MapPartitions.Layers.Max: |cff00ffff{}|r layers/zone", sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_MAX));
        
        handler->SendSysMessage("");  // Blank line separator
        handler->SendSysMessage("|cff888888Tip: Use '.dc partition status' to see runtime stats|r");
        return true;
    }

    if (sub2Norm == "status")
    {
        handler->SendSysMessage("|cff00ff00=== Partition System Status ===|r");

        // System Status
        handler->PSendSysMessage("Enabled: {}", sPartitionMgr->IsEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r");
        handler->PSendSysMessage("Layering: {}", sPartitionMgr->IsLayeringEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r");
        handler->PSendSysMessage("NPC Layering: {}", sPartitionMgr->IsNPCLayeringEnabled() ? "|cff00ff00YES|r" : "|cffff0000NO|r");
        handler->PSendSysMessage("Border Overlap: {:.1f}", sPartitionMgr->GetBorderOverlap());
        handler->PSendSysMessage("Layer Capacity: {}", sPartitionMgr->GetLayerCapacity());

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

            uint32 partitionId = sPartitionMgr->GetPartitionIdForPosition(mapId, x, y);
            uint32 boundaryCount = sPartitionMgr->GetBoundaryCount(mapId, partitionId);
            handler->PSendSysMessage("Partition: |cff00ff00{}|r | Boundary Objects: {}", partitionId, boundaryCount);

            // Layer Info
            if (sPartitionMgr->IsLayeringEnabled())
            {
                uint32 layerId = sPartitionMgr->GetPlayerLayer(mapId, zoneId, player->GetGUID());
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

    handler->PSendSysMessage("Usage: .dc partition status | config | layer <id> | join <player> | diag [on|off]");
    handler->SetSentErrorMessage(true);
    return false;
}
