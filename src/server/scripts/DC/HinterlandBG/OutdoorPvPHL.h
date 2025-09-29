// OutdoorPvPHL.h

#ifndef OUTDOOR_PVP_HL_H
#define OUTDOOR_PVP_HL_H

#include "OutdoorPvP.h"

class OutdoorPvPHL : public OutdoorPvP
{
public:
    OutdoorPvPHL();
    virtual ~OutdoorPvPHL();

    // Match definitions in OutdoorPvPHL_Rewards.cpp
    void HandleRewards(TeamId winner);
    void HandleBuffs(TeamId winner);
    void HandleWinMessage(TeamId winner);

    // Other existing methods and members
};

#endif // OUTDOOR_PVP_HL_H