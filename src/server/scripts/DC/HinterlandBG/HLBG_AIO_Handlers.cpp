// If AIO support isn't available in the build, provide a lightweight stub so
// this translation unit still compiles. Projects that integrate AIO should
// define HAS_AIO in their build and provide AIO.h and related headers.

#ifdef HAS_AIO

/*
 * HLBG Server AIO Integration
 * Location: src/server/scripts/DC/HinterlandBG/HL_ScoreboardNPC.cpp
 *
 * Add these handlers to your existing HL_ScoreboardNPC.cpp file
 */

#include "AIO.h"
#include "Player.h"
#include "World.h"
#include "WorldSession.h"
#include "DatabaseEnv.h"
#include "Log.h"

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
			{ "RequestStatus", &HandleRequestStatus }
		});

		LOG_INFO("server.loading", "HLBG AIO Handlers initialized");
	}

private:
	// Handler implementations (omitted here for brevity in the #ifdef block)
	// Full implementations live in the Custom copy. For builds with AIO
	// enabled, include and use that implementation instead.
	static void HandleRequestServerConfig(Player*, Aio*, AioPacket) {}
	static void HandleRequestSeasonInfo(Player*, Aio*, AioPacket) {}
	static void HandleRequestStats(Player*, Aio*, AioPacket) {}
	static void HandleRequestHistory(Player*, Aio*, AioPacket) {}
	static void HandleRequestStatus(Player*, Aio*, AioPacket) {}

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
