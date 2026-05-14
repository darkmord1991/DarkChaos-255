#ifndef DC_PHASED_DUELS_H
#define DC_PHASED_DUELS_H

#include "ObjectGuid.h"

#include <string>

class Player;

namespace DCPhasedDuels
{
std::string BuildActiveDuelListJson();
bool StartSpectating(Player* spectator, uint32 matchId, ObjectGuid targetGuid,
    std::string& error, std::string& opponentName, uint32& phaseId);
bool StopSpectating(Player* spectator, std::string const& reason = "");
bool IsSpectating(Player* spectator);
}

#endif