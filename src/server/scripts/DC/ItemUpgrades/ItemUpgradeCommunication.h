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
#include "ScriptMgr.h"

class ItemUpgradeCommunicationHandler : public ServerScript
{
public:
    ItemUpgradeCommunicationHandler() : ServerScript("ItemUpgradeCommunicationHandler") {}

    // Public function for NPCs to call to open the upgrade interface
    static void OpenUpgradeInterface(Player* player);

    bool CanPacketReceive(WorldSession* session, WorldPacket& packet) override;

private:
    void HandleItemUpgradeInfoRequest(Player* player, WorldPacket& packet);
    void HandleItemUpgradePerform(Player* player, WorldPacket& packet);
    void HandleInventoryScanRequest(Player* player, WorldPacket& packet);
    void SendErrorResponse(Player* player, const std::string& errorMessage);
};

#endif // ITEM_UPGRADE_COMMUNICATION_H