// -----------------------------------------------------------------------------
// outdoorpvp_hl_registration.cpp
// -----------------------------------------------------------------------------
// DC wrapper for registering the Hinterland OutdoorPvP script with the server.
// Forwards to the canonical AddSC_outdoorpvp_hl() function.
// -----------------------------------------------------------------------------
#include "OutdoorPvP/OutdoorPvPHL.h"
#include "ScriptMgr.h"

// Forward existing registration function implemented in OutdoorPvPHL.cpp
extern void AddSC_outdoorpvp_hl();

// Small DC-specific AddSC wrapper so the DC scripts module picks up the registration.
//
// Reason: the original `AddSC_outdoorpvp_hl()` symbol is defined in
// `OutdoorPvPHL.cpp`. To avoid duplicate symbol/linkage issues when the DC
// aggregation layer includes multiple script translation units, this wrapper
// function forwards to the original registration function. No runtime logic
// changes are performed here; this is purely a build/registration convenience.
void AddSC_outdoorpvp_hl_dc()
{
    // Forward to the original registration which registers the OutdoorPvPHL
    // instance and the player-movement script used for AFK tracking.
    AddSC_outdoorpvp_hl();
}
