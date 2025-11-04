/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "CommandScript.h"
#include "Chat.h"
#include "Player.h"
#include "Item.h"
#include <sstream>

// Forward declare ItemUpgradeManager functions we'll use
namespace DarkChaos { namespace ItemUpgrade { class UpgradeManager; UpgradeManager* sUpgradeManager(); } }

using Acore::ChatCommands::ChatCommandBuilder;
using Acore::ChatCommands::Console;

class ItemUpgradeCommand : public CommandScript
{
public:
    ItemUpgradeCommand() : CommandScript("ItemUpgradeCommand") { }

    [[nodiscard]] std::vector<Acore::ChatCommands::ChatCommandBuilder> GetCommands() const override
    {
        static const std::vector<Acore::ChatCommands::ChatCommandBuilder> upgradeSubCommands =
        {
            ChatCommandBuilder("status", HandleUpgradeStatus, 0, Console::Yes),
            ChatCommandBuilder("list", HandleUpgradeList, 0, Console::Yes),
            ChatCommandBuilder("info", HandleUpgradeInfo, 0, Console::Yes),
        };

        static const std::vector<Acore::ChatCommands::ChatCommandBuilder> commandTable =
        {
            ChatCommandBuilder("upgrade", upgradeSubCommands),
        };

        return commandTable;
    }

private:
    // Handler for .upgrade status
    static bool HandleUpgradeStatus(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
        {
            handler->SendSysMessage("Error: No player found.");
            return true;
        }

        handler->PSendSysMessage("=== Upgrade Token Status ===");
        handler->PSendSysMessage("This is a placeholder. Full implementation coming in Phase 3B.");
        handler->SendSysMessage("Equipped Items:");
        
        uint32 count = 0;
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;

            ItemTemplate const* proto = item->GetTemplate();
            handler->PSendSysMessage("  Slot %u: %s (iLvL: %u)", slot, proto->Name1, proto->ItemLevel);
            count++;
        }

        handler->PSendSysMessage("Total equipped items: %u", count);
        return true;
    }

    // Handler for .upgrade list
    static bool HandleUpgradeList(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
        {
            handler->SendSysMessage("Error: No player found.");
            return true;
        }

        handler->PSendSysMessage("=== Available Upgrades ===");
        
        uint32 upgradeCount = 0;
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;

            ItemTemplate const* proto = item->GetTemplate();
            // Simple tier calculation based on item level ranges
            uint32 ilvl = proto->ItemLevel;
            uint32 currentTier = 1;
            if (ilvl >= 60) currentTier = 2;
            if (ilvl >= 100) currentTier = 3;
            if (ilvl >= 150) currentTier = 4;
            if (ilvl >= 200) currentTier = 5;
            
            if (currentTier < 5)
            {
                handler->PSendSysMessage("  [Slot %u] %s (Tier %u -> Tier %u, iLvL: %u)", 
                    slot, proto->Name1, currentTier, currentTier + 1, ilvl);
                upgradeCount++;
            }
        }

        if (upgradeCount == 0)
            handler->SendSysMessage("No items available for upgrade.");
        else
            handler->PSendSysMessage("Total upgradeable items: %u", upgradeCount);

        return true;
    }

    // Handler for .upgrade info
    static bool HandleUpgradeInfo(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->SendSysMessage("Usage: .upgrade info <item_id>");
            return false;
        }

        uint32 itemId = 0;
        if (!Acore::StringTo<uint32>(args, itemId))
        {
            handler->SendSysMessage("Invalid item ID.");
            return false;
        }

    ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
        if (!itemTemplate)
        {
            handler->SendSysMessage("Item not found.");
            return false;
        }

        handler->PSendSysMessage("=== Item Info ===");
        handler->PSendSysMessage("Item: %s", itemTemplate->Name1);
        handler->PSendSysMessage("Item Level: %u", itemTemplate->ItemLevel);
        handler->PSendSysMessage("This is a placeholder. Full upgrade info coming in Phase 3B.");

        return true;
    }
};

void AddItemUpgradeCommandScript()
{
    new ItemUpgradeCommand();
}
