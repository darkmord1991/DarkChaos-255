// -----------------------------------------------------------------------------
// HinterlandBG.h
// -----------------------------------------------------------------------------
// Tiny DC wrapper header for the Hinterland BG OutdoorPvP script.
// Purpose: avoid duplicate class declarations by including the canonical
//          OutdoorPvPHL header from src/server/scripts/OutdoorPvP/.
// Notes  : keep this file minimal; include it from all DC split .cpp files.
// -----------------------------------------------------------------------------
#ifndef DC_HINTERLANDBG_H
#define DC_HINTERLANDBG_H

#include "OutdoorPvP/OutdoorPvPHL.h" // canonical class definition

class Player;
enum TeamId;

// HLBG player stats integration (implementation in OutdoorPvPHL_Utils.cpp)
class HLBGPlayerStats
{
public:
	static void OnPlayerEnterBG(Player* player);
	static void OnPlayerKill(Player* killer, Player* victim);
	static void OnResourceCapture(Player* player, uint32 resourceAmount);
	static void OnPlayerWin(Player* player);
	static void OnTeamWin(TeamId winningTeam, uint32 zoneId);
};

#endif // DC_HINTERLANDBG_H
