#pragma once

#include "Player.h"

namespace DCCustomLogin::LearnSpells
{
    void GrantClassSpells(Player* player, bool debug);
    void GrantClassSpellsOnLevelUp(Player* player, uint8 oldLevel, bool debug);
}
