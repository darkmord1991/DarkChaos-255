// HLBG_Queue_AIO_Extension.cpp
// Add these handlers to HLBG_AIO_Handlers.cpp or merge into existing AIO handler class

#ifdef HAS_AIO

#include "AIO.h"
#include "Player.h"
#include "WorldSession.h"
#include "Chat.h"
#include "Log.h"
#include "HinterlandBG.h"  // Adjust include path as needed
#include <sstream>

// Forward declaration or include the main OutdoorPvPHL class
// Assuming there's a global accessor like:
// OutdoorPvPHL* GetHinterlandBG();

namespace HLBGQueueHandlers
{
    // Helper: Get Hinterland BG instance
    static OutdoorPvPHL* GetHinterlandBG()
    {
        // Implementation depends on your codebase structure
        // Example implementations:
        // return sOutdoorPvPMgr->GetOutdoorPvPToZoneId(ZoneId::HINTERLANDS);
        // OR: return dynamic_cast<OutdoorPvPHL*>(sOutdoorPvPMgr->GetScript("outdoor_pvp_hl"));
        
        // Placeholder - replace with actual accessor:
        return nullptr;  // TODO: Implement GetHinterlandBG() accessor
    }

    // Handler: RequestQueueStatus
    // Client -> Server: Request current queue status
    // Server -> Client: QUEUE_STATUS packet with position, total, state
    static void HandleRequestQueueStatus(Player* player, Aio* aio, AioPacket packet)
    {
        if (!player)
            return;

        auto pvp = GetHinterlandBG();
        if (!pvp)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Hinterland BG system not available");
            return;
        }

        bool inQueue = pvp->IsPlayerInQueue(player);
        uint32 queueSize = pvp->GetQueuedPlayerCount();
        uint32 position = 0;
        
        // Get player's position in queue if they're queued
        if (inQueue)
        {
            // Assuming there's a method to get queue position
            // position = pvp->GetPlayerQueuePosition(player);
            // If not available, iterate through queue to find position:
            auto queuedPlayers = pvp->GetQueuedPlayers();  // May need to add this accessor
            uint32 idx = 1;
            for (const auto& entry : queuedPlayers)
            {
                if (entry.playerGuid == player->GetGUID())
                {
                    position = idx;
                    break;
                }
                idx++;
            }
        }

        // Get battle state as string
        std::string stateStr = "UNKNOWN";
        switch (pvp->GetBattleState())
        {
            case BG_STATE_CLEANUP:    stateStr = "WAITING"; break;
            case BG_STATE_WARMUP:     stateStr = "WARMUP"; break;
            case BG_STATE_IN_PROGRESS: stateStr = "IN_PROGRESS"; break;
            case BG_STATE_ENDING:     stateStr = "ENDING"; break;
            default: stateStr = "UNKNOWN"; break;
        }

        // Build response packet
        std::ostringstream response;
        response << "QUEUE_STATUS|"
                 << "IN_QUEUE=" << (inQueue ? "1" : "0") << "|"
                 << "POSITION=" << position << "|"
                 << "TOTAL=" << queueSize << "|"
                 << "STATE=" << stateStr;

        // Send via AIO
        aio->PushString(player, "HLBG", response.str());

        LOG_DEBUG("hlbg.queue", "Sent queue status to player {}: inQueue={}, position={}/{}, state={}",
                  player->GetName(), inQueue, position, queueSize, stateStr);
    }

    // Handler: JoinQueue
    // Client -> Server: Player wants to join the queue
    static void HandleJoinQueue(Player* player, Aio* aio, AioPacket packet)
    {
        if (!player)
            return;

        auto pvp = GetHinterlandBG();
        if (!pvp)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Hinterland BG system not available");
            return;
        }

        // Add player to queue (handles duplicate check internally)
        pvp->AddPlayerToQueue(player);

        // Automatically send updated queue status back to client
        HandleRequestQueueStatus(player, aio, packet);

        LOG_INFO("hlbg.queue", "Player {} joined HLBG queue via AIO", player->GetName());
    }

    // Handler: LeaveQueue
    // Client -> Server: Player wants to leave the queue
    static void HandleLeaveQueue(Player* player, Aio* aio, AioPacket packet)
    {
        if (!player)
            return;

        auto pvp = GetHinterlandBG();
        if (!pvp)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Hinterland BG system not available");
            return;
        }

        // Remove player from queue
        pvp->RemovePlayerFromQueue(player);

        // Automatically send updated queue status back to client
        HandleRequestQueueStatus(player, aio, packet);

        LOG_INFO("hlbg.queue", "Player {} left HLBG queue via AIO", player->GetName());
    }

    // Initialize queue handlers (call this from existing HLBGAIOHandlers::Initialize)
    static void RegisterHandlers()
    {
        AIO().AddHandlers("HLBG", {
            { "RequestQueueStatus", &HandleRequestQueueStatus },
            { "JoinQueue", &HandleJoinQueue },
            { "LeaveQueue", &HandleLeaveQueue }
        });

        LOG_INFO("server.loading", "HLBG Queue AIO Handlers registered");
    }
}

// To integrate: Add this line to your existing HLBGAIOHandlers::Initialize() method:
// HLBGQueueHandlers::RegisterHandlers();

#endif // HAS_AIO
