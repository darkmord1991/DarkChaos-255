/*
 * DarkChaos: per-character XP rate - cross-file surface.
 *
 * DC's own bonus XP sources (prestige alt bonus, hotspot buff, prestige talent
 * XP effects) ask IsBonusXPOptedOut before adding their share, so the opt-out
 * works whatever order the OnPlayerGiveXP hooks run in. Implemented in
 * dc_xp_rate.cpp.
 */

#ifndef DC_XP_RATE_H
#define DC_XP_RATE_H

class Player;

namespace DCXPRate
{
    /// True when this (real, non-bot) character turned DC bonus XP off with
    /// `.dc xp bonus off`. Reads the character's own settings: call it from
    /// the player's map thread (XP hooks do).
    bool IsBonusXPOptedOut(Player* player);
}

#endif // DC_XP_RATE_H
