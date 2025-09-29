// DC/HinterlandBG wrapper header for OutdoorPvPHL
// Use the canonical OutdoorPvP header to keep a single source of truth for the class.
#ifndef DC_HINTERLANDBG_OUTDOORPVPHL_WRAPPER_H
#define DC_HINTERLANDBG_OUTDOORPVPHL_WRAPPER_H

#include "OutdoorPvP/OutdoorPvPHL.h"

#endif // DC_HINTERLANDBG_OUTDOORPVPHL_WRAPPER_H
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