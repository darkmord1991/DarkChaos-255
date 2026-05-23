// -----------------------------------------------------------------------------
// hlbg.h
// -----------------------------------------------------------------------------
// Shared HLBG declarations that survive the OutdoorPvP removal.
// -----------------------------------------------------------------------------
#ifndef DC_HINTERLANDBG_H
#define DC_HINTERLANDBG_H

#include "SharedDefines.h"

class Player;

// HLBG player stats integration (implementation in hlbg_utils.cpp)
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
