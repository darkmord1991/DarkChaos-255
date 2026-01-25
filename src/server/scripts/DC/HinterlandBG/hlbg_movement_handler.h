// -----------------------------------------------------------------------------
// hlbg_movement_handler.h
// -----------------------------------------------------------------------------
// MovementHandlerScript hook that forwards player movement events to the
// OutdoorPvPHL AFK tracker (NotePlayerMovement) when in the Hinterlands zone.
// -----------------------------------------------------------------------------
#pragma once

#include "ScriptDefines/MovementHandlerScript.h"
#include "hlbg.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"

class HLMovementHandlerScript : public MovementHandlerScript
{
public:
    HLMovementHandlerScript()
        : MovementHandlerScript("HLMovementHandlerScript", { MOVEMENTHOOK_ON_PLAYER_MOVE }) {}

    void OnPlayerMove(Player* player, MovementInfo /*movementInfo*/, uint32 /*opcode*/) override
    {
        if (!player)
            return;
        OutdoorPvP* opvp = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
        if (!opvp)
            return;
        if (auto* hl = dynamic_cast<OutdoorPvPHL*>(opvp))
            hl->NotePlayerMovement(player);
    }
};
