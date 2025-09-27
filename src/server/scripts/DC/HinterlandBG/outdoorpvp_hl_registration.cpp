// Registration file for Hinterland OutdoorPvP scripts (DC module wrapper)
#include "OutdoorPvP/OutdoorPvPHL.h"
#include "ScriptMgr.h"

// Forward existing registration function implemented in OutdoorPvPHL.cpp
extern void AddSC_outdoorpvp_hl();

// Small DC-specific AddSC wrapper so the DC scripts module picks up the registration.
void AddSC_outdoorpvp_hl_dc()
{
    // Call the original registration (will create the OutdoorPvPHL instance and register movement script)
    AddSC_outdoorpvp_hl();
}
