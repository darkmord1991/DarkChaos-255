// If AIO support isn't available in the build, provide a lightweight stub so
// this translation unit still compiles. Projects that integrate AIO should
// define HAS_AIO in their build and provide AIO.h and related headers.

#ifdef HAS_AIO

/*
 * HLBG Server AIO Integration
 * Location: src/server/scripts/DC/HinterlandBG/HLBG_AIO_Handlers.cpp
 *
 * Provides AIO handlers for client requests (queue status, server config, etc.)
 */

#include "AIO.h"
#include "Player.h"
#include "World.h"
#include "WorldSession.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "OutdoorPvP/OutdoorPvPHL.h"

class HLBGAIOHandlers
{
public:
	// Initialize all HLBG AIO handlers
	static void Initialize()
	{
		// Client request handlers
		AIO().AddHandlers("HLBG", {
			{ "RequestServerConfig", &HandleRequestServerConfig },
			{ "RequestSeasonInfo", &HandleRequestSeasonInfo },
			{ "RequestStats", &HandleRequestStats },
			{ "RequestHistory", &HandleRequestHistory },
			{ "RequestStatus", &HandleRequestStatus },
			{ "RequestQueueStatus", &HandleRequestQueueStatus }
		});

		LOG_INFO("server.loading", "HLBG AIO Handlers initialized (6 handlers registered)");
	}

private:
	// Get OutdoorPvPHL instance
	static OutdoorPvPHL* GetHL()
	{
		OutdoorPvP* opvp = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(ZONE_HINTERLANDS);
		return opvp ? dynamic_cast<OutdoorPvPHL*>(opvp) : nullptr;
	}

	// Handler: RequestQueueStatus
	// Client requests current queue status
	static void HandleRequestQueueStatus(Player* player, Aio* /*aio*/, AioPacket /*packet*/)
	{
		if (!player)
			return;

		OutdoorPvPHL* hl = GetHL();
		if (!hl)
		{
			LOG_WARN("hlbg.aio", "HandleRequestQueueStatus: OutdoorPvPHL instance not found");
			return;
		}

		// Use the existing SendQueueStatusAIO method
		hl->SendQueueStatusAIO(player);
	}

	// Handler: RequestServerConfig
	// Client requests server configuration for Info panel
	static void HandleRequestServerConfig(Player* player, Aio* /*aio*/, AioPacket /*packet*/)
	{
		if (!player)
			return;

		OutdoorPvPHL* hl = GetHL();
		if (!hl)
		{
			LOG_WARN("hlbg.aio", "HandleRequestServerConfig: OutdoorPvPHL instance not found");
			return;
		}

		// Use the existing SendConfigInfoAIO method
		hl->SendConfigInfoAIO(player);
	}

	// Handler: RequestSeasonInfo
	// Client requests current season information
	static void HandleRequestSeasonInfo(Player* /*player*/, Aio* /*aio*/, AioPacket /*packet*/)
	{
		// TODO: Implement season info response
		// For now, this is a placeholder
	}

	// Handler: RequestStats
	// Client requests statistics data
	static void HandleRequestStats(Player* /*player*/, Aio* /*aio*/, AioPacket /*packet*/)
	{
		// TODO: Implement stats response
		// This should query the database and send stats via AIO
	}

	// Handler: RequestHistory
	// Client requests battle history
	static void HandleRequestHistory(Player* /*player*/, Aio* /*aio*/, AioPacket /*packet*/)
	{
		// TODO: Implement history response
		// This should query the database and send history via AIO
	}

	// Handler: RequestStatus
	// Client requests current battle status
	static void HandleRequestStatus(Player* /*player*/, Aio* /*aio*/, AioPacket /*packet*/)
	{
		// TODO: Implement status response
		// This should send current battle state (resources, time, etc.)
	}

public:
	static void UpdateBattleResults(const std::string&, uint32, uint32, uint32, uint32, uint32, uint32) {}
	static void RecordManualReset(const std::string&) {}
};

// Add this to your server initialization (e.g., in World.cpp or similar)
void InitializeHLBGHandlers()
{
	HLBGAIOHandlers::Initialize();
}

#else // HAS_AIO

#include "Log.h"

// Provide minimal HLBGAIOHandlers class stub when AIO support is not present.
// This allows other translation units to call UpdateBattleResults / RecordManualReset
// without requiring AIO headers or full implementation.
#include <string>

class HLBGAIOHandlers
{
public:
	static void UpdateBattleResults(const std::string& /*winner*/, uint32 /*duration*/, uint32 /*affixId*/, uint32 /*allianceResources*/, uint32 /*hordeResources*/, uint32 /*alliancePlayers*/, uint32 /*hordePlayers*/) {}
	static void RecordManualReset(const std::string& /*gmName*/) {}
};

// AIO isn't available in this build. Provide a stub so linkage and calls
// to InitializeHLBGHandlers succeed without AIO support.
void InitializeHLBGHandlers()
{
	LOG_WARN("hlbg", "AIO support not enabled - HLBG AIO handlers not registered");
}

#endif // HAS_AIO
