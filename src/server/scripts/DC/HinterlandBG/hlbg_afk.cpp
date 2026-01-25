// -----------------------------------------------------------------------------
// hlbg_afk.cpp
// -----------------------------------------------------------------------------
// Movement-based AFK tracker helper (NotePlayerMovement). Called by
// hlbg_movement_handler on player movement to reset AFK timers.
// -----------------------------------------------------------------------------
#include "OutdoorPvP/OutdoorPvPHL.h"
#include <cmath>

// Update last-move timestamps for AFK detection when player meaningfully moves.
void OutdoorPvPHL::NotePlayerMovement(Player* player)
{
    if (!player || player->GetZoneId() != OutdoorPvPHLBuffZones[0])
        return;
    // Update last move time on any movement that meaningfully changes position
    Position const& cur = player->GetPosition();
    Position& last = _playerLastPos[player->GetGUID()];
    float dx = last.GetPositionX() - cur.GetPositionX();
    float dy = last.GetPositionY() - cur.GetPositionY();
    float dz = last.GetPositionZ() - cur.GetPositionZ();
    float dist2d = std::sqrt(dx*dx + dy*dy);
    if (dist2d > 0.5f || std::fabs(dz) > 0.5f)
    {
        _playerLastMove[player->GetGUID()] = uint32(GameTime::GetGameTime().count());
        _playerWarnedBeforeTeleport[player->GetGUID()] = false; // reset warn once they move
        last = cur;
        // If previously flagged AFK due to inactivity, clear the edge flag so next AFK is a new infraction only when idle again
        _afkFlagged.erase(player->GetGUID().GetCounter());
    }
}
