/*
 * Dark Chaos - Hinterland BG Addon Module Handler
 *
 * This module handles the Hinterland BG addon communication.
 * Note: HLBG primarily uses AIO for communication, but this handler
 * provides additional lightweight messaging for specific use cases.
 *
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "Config.h"
#include "Log.h"
#include "DCAddonNamespace.h"

namespace DCAddon
{
namespace HLBG
{
    // BG Status values
    enum HLBGStatus : uint8
    {
        STATUS_NONE   = 0,
        STATUS_QUEUED = 1,
        STATUS_PREP   = 2, // Preparation countdown
        STATUS_ACTIVE = 3,
        STATUS_ENDED  = 4,
    };

    // Configuration
    static bool s_enabled = true;

    void LoadConfig()
    {
        s_enabled = sConfigMgr->GetOption<bool>("DC.Addon.HLBG.Enable", true);
    }

    // Send status update to player
    void SendStatus(Player* player, HLBGStatus status, uint32 mapId, uint32 timeRemaining)
    {
        Message msg(Module::HINTERLAND, Opcode::HLBG::SMSG_STATUS);
        msg.Add(static_cast<uint8>(status));
        msg.Add(mapId);
        msg.Add(timeRemaining);
        msg.Send(player);
    }

    // Send resource update
    void SendResources(Player* player, uint32 allianceRes, uint32 hordeRes,
                       uint32 allianceBases, uint32 hordeBases)
    {
        Message msg(Module::HINTERLAND, Opcode::HLBG::SMSG_RESOURCES);
        msg.Add(allianceRes);
        msg.Add(hordeRes);
        msg.Add(allianceBases);
        msg.Add(hordeBases);
        msg.Send(player);
    }

    // Send queue update
    void SendQueueUpdate(Player* player, uint8 queueStatus, uint32 position, uint32 estimatedTime)
    {
        Message msg(Module::HINTERLAND, Opcode::HLBG::SMSG_QUEUE_UPDATE);
        msg.Add(queueStatus);
        msg.Add(position);
        msg.Add(estimatedTime);
        msg.Send(player);
    }

    // Send timer sync
    void SendTimerSync(Player* player, uint32 elapsedMs, uint32 maxMs)
    {
        Message msg(Module::HINTERLAND, Opcode::HLBG::SMSG_TIMER_SYNC);
        msg.Add(elapsedMs);
        msg.Add(maxMs);
        msg.Send(player);
    }

    // Send team scores
    void SendTeamScore(Player* player, uint32 allianceScore, uint32 hordeScore,
                       uint32 allianceKills, uint32 hordeKills)
    {
        Message msg(Module::HINTERLAND, Opcode::HLBG::SMSG_TEAM_SCORE);
        msg.Add(allianceScore);
        msg.Add(hordeScore);
        msg.Add(allianceKills);
        msg.Add(hordeKills);
        msg.Send(player);
    }

    // Send affix information (for seasonal BG events)
    void SendAffixInfo(Player* player, uint32 affixId1, uint32 affixId2, uint32 affixId3, uint32 seasonId)
    {
        Message msg(Module::HINTERLAND, Opcode::HLBG::SMSG_AFFIX_INFO);
        msg.Add(affixId1);
        msg.Add(affixId2);
        msg.Add(affixId3);
        msg.Add(seasonId);
        msg.Send(player);
    }

    // Send match end notification
    void SendMatchEnd(Player* player, bool victory, uint32 personalScore, uint32 honorGained,
                      uint32 reputationGained, uint32 tokensGained)
    {
        Message msg(Module::HINTERLAND, Opcode::HLBG::SMSG_MATCH_END);
        msg.Add(victory);
        msg.Add(personalScore);
        msg.Add(honorGained);
        msg.Add(reputationGained);
        msg.Add(tokensGained);
        msg.Send(player);
    }

    // Handler implementations
    static void HandleRequestStatus(Player* player, const ParsedMessage& /*msg*/)
    {
        // Check if player is in HLBG map or queued
        uint32 mapId = player->GetMapId();

        // Hinterlands map ID check (adjust as needed for your implementation)
        if (mapId == 47) // Hinterlands zone
        {
            // TODO: Get actual BG instance data from your HLBG system
            SendStatus(player, STATUS_ACTIVE, mapId, 0);
        }
        else
        {
            // Check if queued for HLBG
            // TODO: Query your BG queue system
            SendStatus(player, STATUS_NONE, 0, 0);
        }
    }

    static void HandleRequestResources(Player* player, const ParsedMessage& /*msg*/)
    {
        // TODO: Get actual resource data from your HLBG system
        // For now send placeholder values
        SendResources(player, 0, 0, 0, 0);
    }

    static void HandleRequestObjective(Player* /*player*/, const ParsedMessage& /*msg*/)
    {
        // TODO: Query objective status from HLBG system
        // This is typically handled by AIO, but can supplement it
    }

    static void HandleQuickQueue(Player* player, const ParsedMessage& /*msg*/)
    {
        // Execute the queue command
        ChatHandler handler(player->GetSession());
        handler.ParseCommands(".hlbg queue");

        SendQueueUpdate(player, 1, 0, 0); // Queued status
    }

    static void HandleLeaveQueue(Player* player, const ParsedMessage& /*msg*/)
    {
        // Execute the leave queue command
        ChatHandler handler(player->GetSession());
        handler.ParseCommands(".hlbg leave");

        SendQueueUpdate(player, 0, 0, 0); // Not queued status
    }

    static void HandleRequestStats(Player* player, const ParsedMessage& msg)
    {
        // Get optional season parameter
        uint32 seasonId = msg.GetUInt32(0);

        // TODO: Query player HLBG stats from database
        // For now, this supplements the AIO-based stats system

        Message response(Module::HINTERLAND, Opcode::HLBG::SMSG_STATS);
        response.Add(0);  // Total matches
        response.Add(0);  // Wins
        response.Add(0);  // Losses
        response.Add(0);  // Kills
        response.Add(0);  // Deaths
        response.Add(0);  // Objectives captured
        response.Add(seasonId);
        response.Send(player);
    }

    // Register handlers with the router
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(Module::HINTERLAND, Opcode::HLBG::CMSG_REQUEST_STATUS, HandleRequestStatus);
        DC_REGISTER_HANDLER(Module::HINTERLAND, Opcode::HLBG::CMSG_REQUEST_RESOURCES, HandleRequestResources);
        DC_REGISTER_HANDLER(Module::HINTERLAND, Opcode::HLBG::CMSG_REQUEST_OBJECTIVE, HandleRequestObjective);
        DC_REGISTER_HANDLER(Module::HINTERLAND, Opcode::HLBG::CMSG_QUICK_QUEUE, HandleQuickQueue);
        DC_REGISTER_HANDLER(Module::HINTERLAND, Opcode::HLBG::CMSG_LEAVE_QUEUE, HandleLeaveQueue);
        DC_REGISTER_HANDLER(Module::HINTERLAND, Opcode::HLBG::CMSG_REQUEST_STATS, HandleRequestStats);

        LOG_INFO("dc.addon", "HLBG module handlers registered");
    }
    
    // ========================================================================
    // JSON HANDLERS - For complex data that benefits from structured format
    // ========================================================================
    
    // Send full BG status as JSON (combines status + resources + timer)
    void SendJsonStatus(Player* player, HLBGStatus status, uint32 allianceRes, uint32 hordeRes,
                        uint32 allianceBases, uint32 hordeBases, uint32 elapsedMs, uint32 maxMs,
                        const std::string& affixName, uint32 seasonId)
    {
        JsonMessage(Module::HINTERLAND, Opcode::HLBG::SMSG_STATUS)
            .Set("status", static_cast<int32>(status))
            .Set("alliance", static_cast<int32>(allianceRes))
            .Set("horde", static_cast<int32>(hordeRes))
            .Set("allianceBases", static_cast<int32>(allianceBases))
            .Set("hordeBases", static_cast<int32>(hordeBases))
            .Set("elapsed", static_cast<int32>(elapsedMs))
            .Set("duration", static_cast<int32>(maxMs))
            .Set("affix", affixName)
            .Set("season", static_cast<int32>(seasonId))
            .Send(player);
    }
    
    // Send live resources update as JSON
    void SendJsonResources(Player* player, uint32 allianceRes, uint32 hordeRes,
                           uint32 allianceBases, uint32 hordeBases, 
                           uint32 allianceKills, uint32 hordeKills)
    {
        JsonMessage(Module::HINTERLAND, Opcode::HLBG::SMSG_RESOURCES)
            .Set("A", static_cast<int32>(allianceRes))
            .Set("H", static_cast<int32>(hordeRes))
            .Set("aBases", static_cast<int32>(allianceBases))
            .Set("hBases", static_cast<int32>(hordeBases))
            .Set("aKills", static_cast<int32>(allianceKills))
            .Set("hKills", static_cast<int32>(hordeKills))
            .Send(player);
    }
    
    // Send objective state as JSON
    void SendJsonObjective(Player* player, uint32 objectiveId, const std::string& objectiveName,
                           uint32 allianceProgress, uint32 hordeProgress, uint32 maxProgress,
                           const std::string& currentHolder)
    {
        JsonMessage(Module::HINTERLAND, Opcode::HLBG::SMSG_OBJECTIVE)
            .Set("id", static_cast<int32>(objectiveId))
            .Set("name", objectiveName)
            .Set("allianceProgress", static_cast<int32>(allianceProgress))
            .Set("hordeProgress", static_cast<int32>(hordeProgress))
            .Set("maxProgress", static_cast<int32>(maxProgress))
            .Set("holder", currentHolder)
            .Send(player);
    }
    
    // Send queue update as JSON
    void SendJsonQueueUpdate(Player* player, uint8 queueStatus, uint32 position, 
                             uint32 estimatedTime, uint32 playersInQueue, uint32 minPlayers)
    {
        JsonMessage(Module::HINTERLAND, Opcode::HLBG::SMSG_QUEUE_UPDATE)
            .Set("status", static_cast<int32>(queueStatus))
            .Set("position", static_cast<int32>(position))
            .Set("eta", static_cast<int32>(estimatedTime))
            .Set("inQueue", static_cast<int32>(playersInQueue))
            .Set("minPlayers", static_cast<int32>(minPlayers))
            .Send(player);
    }
    
    // Send timer sync as JSON
    void SendJsonTimerSync(Player* player, uint32 elapsedMs, uint32 maxMs, bool isWarmup)
    {
        JsonMessage(Module::HINTERLAND, Opcode::HLBG::SMSG_TIMER_SYNC)
            .Set("elapsed", static_cast<int32>(elapsedMs))
            .Set("max", static_cast<int32>(maxMs))
            .Set("warmup", isWarmup)
            .Send(player);
    }
    
    // Send team scores as JSON
    void SendJsonTeamScore(Player* player, uint32 allianceScore, uint32 hordeScore,
                           uint32 allianceKills, uint32 hordeKills,
                           uint32 allianceDeaths, uint32 hordeDeaths)
    {
        JsonMessage(Module::HINTERLAND, Opcode::HLBG::SMSG_TEAM_SCORE)
            .Set("aScore", static_cast<int32>(allianceScore))
            .Set("hScore", static_cast<int32>(hordeScore))
            .Set("aKills", static_cast<int32>(allianceKills))
            .Set("hKills", static_cast<int32>(hordeKills))
            .Set("aDeaths", static_cast<int32>(allianceDeaths))
            .Set("hDeaths", static_cast<int32>(hordeDeaths))
            .Send(player);
    }
    
    // Send player stats as JSON
    void SendJsonStats(Player* player, uint32 seasonId, uint32 totalMatches, uint32 wins,
                       uint32 losses, uint32 draws, uint32 kills, uint32 deaths,
                       uint32 objectivesCaptured, uint32 avgDuration)
    {
        JsonMessage(Module::HINTERLAND, Opcode::HLBG::SMSG_STATS)
            .Set("season", static_cast<int32>(seasonId))
            .Set("matches", static_cast<int32>(totalMatches))
            .Set("wins", static_cast<int32>(wins))
            .Set("losses", static_cast<int32>(losses))
            .Set("draws", static_cast<int32>(draws))
            .Set("kills", static_cast<int32>(kills))
            .Set("deaths", static_cast<int32>(deaths))
            .Set("objectives", static_cast<int32>(objectivesCaptured))
            .Set("avgDuration", static_cast<int32>(avgDuration))
            .Send(player);
    }
    
    // Send affix information as JSON
    void SendJsonAffixInfo(Player* player, uint32 affixId, const std::string& affixName,
                           const std::string& affixDesc, uint32 seasonId, const std::string& seasonName)
    {
        JsonMessage(Module::HINTERLAND, Opcode::HLBG::SMSG_AFFIX_INFO)
            .Set("affixId", static_cast<int32>(affixId))
            .Set("affixName", affixName)
            .Set("affixDesc", affixDesc)
            .Set("season", static_cast<int32>(seasonId))
            .Set("seasonName", seasonName)
            .Send(player);
    }
    
    // Send match end notification as JSON
    void SendJsonMatchEnd(Player* player, bool victory, const std::string& winner,
                          uint32 allianceScore, uint32 hordeScore,
                          uint32 personalScore, uint32 personalKills, uint32 personalDeaths,
                          uint32 honorGained, uint32 reputationGained, uint32 tokensGained,
                          uint32 matchDuration, const std::string& winReason)
    {
        JsonMessage(Module::HINTERLAND, Opcode::HLBG::SMSG_MATCH_END)
            .Set("victory", victory)
            .Set("winner", winner)
            .Set("aScore", static_cast<int32>(allianceScore))
            .Set("hScore", static_cast<int32>(hordeScore))
            .Set("score", static_cast<int32>(personalScore))
            .Set("kills", static_cast<int32>(personalKills))
            .Set("deaths", static_cast<int32>(personalDeaths))
            .Set("honor", static_cast<int32>(honorGained))
            .Set("rep", static_cast<int32>(reputationGained))
            .Set("tokens", static_cast<int32>(tokensGained))
            .Set("duration", static_cast<int32>(matchDuration))
            .Set("reason", winReason)
            .Send(player);
    }
    
    // Broadcast JSON status to all players in BG
    void BroadcastJsonStatus(const std::vector<Player*>& players, HLBGStatus status,
                             uint32 allianceRes, uint32 hordeRes, uint32 allianceBases, 
                             uint32 hordeBases, uint32 elapsedMs, uint32 maxMs,
                             const std::string& affixName, uint32 seasonId)
    {
        for (Player* player : players)
        {
            if (player)
            {
                SendJsonStatus(player, status, allianceRes, hordeRes, allianceBases,
                               hordeBases, elapsedMs, maxMs, affixName, seasonId);
            }
        }
    }

}  // namespace HLBG
}  // namespace DCAddon

// Register the HLBG addon handler
void AddSC_dc_addon_hlbg()
{
    DCAddon::HLBG::RegisterHandlers();
}
