// Registration file for Hinterland OutdoorPvP scripts
#include "../../../../OutdoorPvP/OutdoorPvPHL.h"
#include "ScriptMgr.h"

// Register the OutdoorPvP Hinterland instance and movement script
void AddSC_outdoorpvp_hl_dc()
{
    new OutdoorPvP_hinterland();
    // Movement script registration (constructed object registers itself)
    new OutdoorPvPHL_PlayerMoveScript();
}
