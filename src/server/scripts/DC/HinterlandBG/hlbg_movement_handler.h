// -----------------------------------------------------------------------------
// hlbg_movement_handler.h
// -----------------------------------------------------------------------------
// MovementHandlerScript hook that forwards player movement events to the
// battleground-owned AFK tracker.
// -----------------------------------------------------------------------------
#pragma once

#include "ScriptDefines/MovementHandlerScript.h"
#include "BattlegroundHLBG.h"

class HLMovementHandlerScript : public MovementHandlerScript
{
public:
    HLMovementHandlerScript()
        : MovementHandlerScript("HLMovementHandlerScript", { MOVEMENTHOOK_ON_PLAYER_MOVE }) {}

    void OnPlayerMove(Player* player, MovementInfo /*movementInfo*/, uint32 /*opcode*/) override
    {
        if (!player)
            return;

        if (Battleground* battleground = player->GetBattleground())
        {
            if (battleground->GetBgTypeID(true) == BATTLEGROUND_HLBG)
            {
                if (auto* hlbg = dynamic_cast<BattlegroundHLBG*>(battleground))
                    hlbg->NotePlayerMovement(player);
            }
        }
    }
};
