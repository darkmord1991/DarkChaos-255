/*
 * DarkChaos Item Upgrade - Client Communication Handler
 *
 * Handles communication between the client addon and server-side upgrade system.
 * Provides retail-like visual interface integration.
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "ItemUpgradeManager.h"
#include "Chat.h"
#include <sstream>

enum ItemUpgradeOpcodes
{
    CMSG_ITEM_UPGRADE_REQUEST_INFO    = 1001, // Request item upgrade info
    SMSG_ITEM_UPGRADE_INFO_RESPONSE   = 1002, // Send item upgrade info to client
    CMSG_ITEM_UPGRADE_PERFORM         = 1003, // Perform upgrade request
    SMSG_ITEM_UPGRADE_RESULT          = 1004, // Upgrade result
    CMSG_ITEM_UPGRADE_INVENTORY_SCAN  = 1005, // Request upgradable items scan
    SMSG_ITEM_UPGRADE_INVENTORY_LIST  = 1006, // Send list of upgradable items
    SMSG_ITEM_UPGRADE_OPEN_INTERFACE  = 1007, // Open upgrade interface (from NPC)
};

class ItemUpgradeCommunicationHandler : public ServerScript
{
public:
    ItemUpgradeCommunicationHandler() : ServerScript("ItemUpgradeCommunicationHandler") {}

    // Public function for NPCs to call
    static void OpenUpgradeInterface(Player* player)
    {
        if (!player)
            return;

        // Send packet to open the interface
        WorldPacket packet(SMSG_ITEM_UPGRADE_OPEN_INTERFACE, 4);
        packet << uint32(1); // Simple flag to indicate interface should open

        player->SendDirectMessage(&packet);
    }

    bool CanPacketReceive(WorldSession* session, WorldPacket& packet) override
    {
        if (!session)
            return true;

        Player* player = session->GetPlayer();
        if (!player)
            return true;

        uint16 opcode = packet.GetOpcode();

        switch (opcode)
        {
            case CMSG_ITEM_UPGRADE_REQUEST_INFO:
                HandleItemUpgradeInfoRequest(player, packet);
                return false; // Don't process further

            case CMSG_ITEM_UPGRADE_PERFORM:
                HandleItemUpgradePerform(player, packet);
                return false; // Don't process further

            case CMSG_ITEM_UPGRADE_INVENTORY_SCAN:
                HandleInventoryScanRequest(player, packet);
                return false; // Don't process further

            default:
                return true; // Allow other packets to be processed
        }
    }

private:
    void HandleItemUpgradeInfoRequest(Player* player, WorldPacket& packet)
    {
        uint32 itemGuid;
        packet >> itemGuid;

        if (itemGuid == 0)
        {
            SendErrorResponse(player, "Invalid item GUID");
            return;
        }

        // Get upgrade manager
        DarkChaos::ItemUpgrade::UpgradeManager* upgradeMgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!upgradeMgr)
        {
            SendErrorResponse(player, "Upgrade system not available");
            return;
        }

        // Get item upgrade state
        DarkChaos::ItemUpgrade::ItemUpgradeState* state = upgradeMgr->GetItemUpgradeState(itemGuid);
        if (!state)
        {
            SendErrorResponse(player, "Item not found in upgrade system");
            return;
        }

        // Get item info
        Item* item = player->GetItemByGuid(ObjectGuid::Create<HighGuid::Item>(itemGuid));
        if (!item)
        {
            SendErrorResponse(player, "Item not found in inventory");
            return;
        }

        // Send upgrade info response
        WorldPacket response(SMSG_ITEM_UPGRADE_INFO_RESPONSE, 200);
        response << uint32(itemGuid);
        response << uint8(state->tier_id);
        response << uint8(state->upgrade_level);
        response << uint32(state->essence_invested);
        response << uint32(state->tokens_invested);
        response << uint16(state->base_item_level);
        response << uint16(state->upgraded_item_level);
        response << float(state->stat_multiplier);
        response << uint32(state->season);

        // Send item link for client-side display
        std::ostringstream itemLinkStream;
        itemLinkStream << "|Hitem:" << item->GetEntry() << ":0:0:0:0:0:0:0:0:0|h[" << item->GetTemplate()->Name1 << "]|h";
        std::string itemLink = itemLinkStream.str();
        response << itemLink;

        player->SendDirectMessage(&response);
    }

    void HandleItemUpgradePerform(Player* player, WorldPacket& packet)
    {
        uint32 itemGuid;
        uint8 targetLevel;

        packet >> itemGuid >> targetLevel;

        if (itemGuid == 0 || targetLevel > 15 || targetLevel < 1)
        {
            SendErrorResponse(player, "Invalid upgrade parameters");
            return;
        }

        // Get upgrade manager
        DarkChaos::ItemUpgrade::UpgradeManager* upgradeMgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!upgradeMgr)
        {
            SendErrorResponse(player, "Upgrade system not available");
            return;
        }

        // Get current item state
        DarkChaos::ItemUpgrade::ItemUpgradeState* state = upgradeMgr->GetItemUpgradeState(itemGuid);
        if (!state)
        {
            SendErrorResponse(player, "Item not found in upgrade system");
            return;
        }

        if (targetLevel <= state->upgrade_level)
        {
            SendErrorResponse(player, "Target level must be higher than current level");
            return;
        }

        if (targetLevel > 15)
        {
            SendErrorResponse(player, "Maximum upgrade level is 15");
            return;
        }

        // Check if player owns the item
        Item* item = player->GetItemByGuid(ObjectGuid::Create<HighGuid::Item>(itemGuid));
        if (!item)
        {
            SendErrorResponse(player, "Item not found in your inventory");
            return;
        }

        // Calculate total cost for all levels being upgraded
        uint32 totalEssenceCost = 0;
        uint32 totalTokenCost = 0;

        for (uint8 level = state->upgrade_level + 1; level <= targetLevel; ++level)
        {
            uint32 essenceCost = upgradeMgr->GetEssenceCost(state->tier_id, level);
            uint32 tokenCost = upgradeMgr->GetUpgradeCost(state->tier_id, level);

            totalEssenceCost += essenceCost;
            totalTokenCost += tokenCost;
        }

        // Check if player has enough currency
        uint32 playerEssence = upgradeMgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE, state->season);
        uint32 playerTokens = upgradeMgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN, state->season);

        if (state->tier_id == DarkChaos::ItemUpgrade::TIER_ARTIFACT && playerEssence < totalEssenceCost)
        {
            SendErrorResponse(player, "Not enough Artifact Essence");
            return;
        }
        else if (state->tier_id != DarkChaos::ItemUpgrade::TIER_ARTIFACT && playerTokens < totalTokenCost)
        {
            SendErrorResponse(player, "Not enough Upgrade Tokens");
            return;
        }

        // Perform upgrades one level at a time
        bool success = true;
        uint8 finalLevel = state->upgrade_level;

        for (uint8 level = state->upgrade_level + 1; level <= targetLevel && success; ++level)
        {
            success = upgradeMgr->UpgradeItem(player->GetGUID().GetCounter(), itemGuid);
            if (success)
            {
                finalLevel = level;
            }
            else
            {
                break;
            }
        }

        if (success)
        {
            // Send success response
            WorldPacket response(SMSG_ITEM_UPGRADE_RESULT, 50);
            response << uint8(1); // Success
            response << uint32(itemGuid);
            response << uint8(finalLevel);
            response << uint32(totalEssenceCost);
            response << uint32(totalTokenCost);

            player->SendDirectMessage(&response);

            // Send confirmation message
            std::ostringstream msgStream;
            msgStream << "Successfully upgraded item to level " << (int)finalLevel << "/15!";
            if (totalEssenceCost > 0)
                msgStream << " (Cost: " << totalEssenceCost << " Essence)";
            if (totalTokenCost > 0)
                msgStream << " (Cost: " << totalTokenCost << " Tokens)";

            ChatHandler(player->GetSession()).SendSysMessage(msgStream.str().c_str());
        }
        else
        {
            SendErrorResponse(player, "Upgrade failed - insufficient currency or other error");
        }
    }

    void HandleInventoryScanRequest(Player* player, WorldPacket& /*packet*/)
    {
        // Get upgrade manager
        DarkChaos::ItemUpgrade::UpgradeManager* upgradeMgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!upgradeMgr)
        {
            SendErrorResponse(player, "Upgrade system not available");
            return;
        }

        // Scan player's inventory for upgradable items
        std::vector<std::pair<uint32, std::string>> upgradableItems;

        // Check equipped items
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (item && upgradeMgr->CanUpgradeItem(item->GetGUID().GetCounter(), player->GetGUID().GetCounter()))
            {
                std::ostringstream itemLinkStream;
                itemLinkStream << "|Hitem:" << item->GetEntry() << ":0:0:0:0:0:0:0:0:0|h[" << item->GetTemplate()->Name1 << "]|h";
                upgradableItems.push_back(std::make_pair(item->GetGUID().GetCounter(), itemLinkStream.str()));
            }
        }

        // Check bags
        for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
        {
            Bag* bagItem = player->GetBagByPos(bag);
            if (!bagItem)
                continue;

            for (uint32 slot = 0; slot < bagItem->GetBagSize(); ++slot)
            {
                Item* item = player->GetItemByPos(bag, slot);
                if (item && upgradeMgr->CanUpgradeItem(item->GetGUID().GetCounter(), player->GetGUID().GetCounter()))
                {
                    std::ostringstream itemLinkStream;
                    itemLinkStream << "|Hitem:" << item->GetEntry() << ":0:0:0:0:0:0:0:0:0|h[" << item->GetTemplate()->Name1 << "]|h";
                    upgradableItems.push_back(std::make_pair(item->GetGUID().GetCounter(), itemLinkStream.str()));
                }
            }
        }

        // Send inventory list response
        WorldPacket response(SMSG_ITEM_UPGRADE_INVENTORY_LIST, 1000);
        response << uint32(upgradableItems.size());

        for (auto& itemPair : upgradableItems)
        {
            response << uint32(itemPair.first); // item GUID
            response << itemPair.second; // item link
        }

        player->SendDirectMessage(&response);
    }

    void SendErrorResponse(Player* player, const std::string& errorMessage)
    {
        WorldPacket response(SMSG_ITEM_UPGRADE_RESULT, 100);
        response << uint8(0); // Failure
        response << errorMessage;

        player->SendDirectMessage(&response);

        // Also send chat message
        ChatHandler(player->GetSession()).SendSysMessage(errorMessage.c_str());
    }
};

// =====================================================================
// Script Registration
// =====================================================================

void AddSC_ItemUpgradeCommunication()
{
    new ItemUpgradeCommunicationHandler();
}