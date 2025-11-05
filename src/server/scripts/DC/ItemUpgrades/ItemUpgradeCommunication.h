/*
 * DarkChaos Item Upgrade - Client Communication Handler Header
 *
 * Handles communication between the client addon and server-side upgrade system.
 * Provides retail-like visual interface integration.
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#ifndef ITEM_UPGRADE_COMMUNICATION_H
#define ITEM_UPGRADE_COMMUNICATION_H

#include "Player.h"

class ItemUpgradeCommunicationHandler
{
public:
    // Public function for NPCs to call to open the upgrade interface
    static void OpenUpgradeInterface(Player* player);
};

#endif // ITEM_UPGRADE_COMMUNICATION_H