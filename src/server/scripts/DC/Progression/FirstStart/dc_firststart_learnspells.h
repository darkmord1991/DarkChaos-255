#pragma once

#include "Player.h"

namespace DCFirstStart::LearnSpells
{
    void GrantClassSpells(Player* player, bool debug);
    void GrantClassSpellsOnLevelUp(Player* player, uint8 oldLevel, bool debug);
}
