#pragma once

#include "Player.h"

namespace DCFirstStart::LearnSpells
{
    void GrantClassSpells(Player* player, bool debug);
    void GrantClassSpellsOnLevelUp(Player* player, uint8 oldLevel, bool debug);

    // Teaches the trainer spells a character qualifies for up to its level (previous rank and talent
    // required). Runs at every login, so new ranks reach characters that are already past their level.
    void CatchUpClassSpells(Player* player, bool debug);

    // Unlearns the class spells above `level` that levelling back up teaches again (trainer spells
    // always; the spells GrantClassSpellsOnLevelUp teaches while it is enabled, up to its max level).
    // The highest rank left of each touched spell is made castable again. Returns the count unlearned.
    uint32 ForgetClassSpellsAbove(Player* player, uint8 level, bool debug);
}
