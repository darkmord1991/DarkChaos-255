/*
 * DarkChaos Item Upgrade - Proc Scaling System
 *
 * Header for proc scaling functionality.
 *
 * Author: DarkChaos Development Team
 * Date: December 17, 2025
 */

#pragma once

#include "Define.h"
#include <string>

class Player;

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // Returns a formatted string describing the player's currently scaled procs
        std::string GetPlayerProcScalingInfo(Player* player);

    } // namespace ItemUpgrade
} // namespace DarkChaos
