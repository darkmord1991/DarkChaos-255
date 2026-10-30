#pragma once

#include "Define.h"

class Player;

namespace DCWorldforged
{
    // Makes every worldforged pickup this character has looted lootable again: a prestige fresh start hands
    // the climb back. Claims are player settings, so the reset saves with the character's next SaveToDB, and
    // the pickups show again at the next visibility update. Returns how many pickups it released.
    uint32 ResetClaims(Player* player);
}
