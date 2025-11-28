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

}  // namespace HLBG
}  // namespace DCAddon

// Register the HLBG addon handler
void AddSC_dc_addon_hlbg()
{
    DCAddon::HLBG::RegisterHandlers();
}
