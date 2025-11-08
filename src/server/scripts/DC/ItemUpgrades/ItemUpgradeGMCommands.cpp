/*
 * DarkChaos Item Upgrade System - GM Commands
 *
 * This file implements GM administrative commands for the item upgrade system.
 * Commands: .upgrade token (add/remove/set), .upgrade status, .upgrade list
 *
 * RENAMED FROM: ItemUpgradeCommand.cpp
 * REASON: Better clarity - distinguishes from addon handler commands
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 * Updated: November 8, 2025 (Renamed for better organization)
 */

#include "CommandScript.h"
#include "Chat.h"
#include "Player.h"
#include "Item.h"
#include <sstream>
#include "ItemUpgradeManager.h"

using Acore::ChatCommands::ChatCommandBuilder;
using Acore::ChatCommands::Console;

class ItemUpgradeGMCommand : public CommandScript
{
public:
    ItemUpgradeGMCommand() : CommandScript("ItemUpgradeGMCommand") { }

    [[nodiscard]] std::vector<Acore::ChatCommands::ChatCommandBuilder> GetCommands() const override
    {
        static const std::vector<Acore::ChatCommands::ChatCommandBuilder> tokenSubCommands =
        {
            ChatCommandBuilder("add", HandleTokenAdd, 3, Console::Yes),
            ChatCommandBuilder("remove", HandleTokenRemove, 3, Console::Yes),
            ChatCommandBuilder("set", HandleTokenSet, 3, Console::Yes),
            ChatCommandBuilder("info", HandleTokenInfo, 1, Console::Yes),
        };

        static const std::vector<Acore::ChatCommands::ChatCommandBuilder> upgradeSubCommands =
        {
            ChatCommandBuilder("status", HandleUpgradeStatus, 0, Console::Yes),
            ChatCommandBuilder("list", HandleUpgradeList, 0, Console::Yes),
            ChatCommandBuilder("info", HandleUpgradeInfo, 0, Console::Yes),
            ChatCommandBuilder("token", tokenSubCommands),
        };

        static const std::vector<Acore::ChatCommands::ChatCommandBuilder> commandTable =
        {
            ChatCommandBuilder("upgrade", upgradeSubCommands),
        };

        return commandTable;
    }

private:
    // Handler for .upgrade token add
    static bool HandleTokenAdd(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->SendSysMessage("Usage: .upgrade token add <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        char* playerName = strtok((char*)args, " ");
        char* amountStr = strtok(nullptr, " ");
        char* tokenType = strtok(nullptr, " ");

        if (!playerName || !amountStr)
        {
            handler->SendSysMessage("Usage: .upgrade token add <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        uint32 amount = 0;
        if (!Acore::StringTo<uint32>(amountStr, amount) || amount == 0)
        {
            handler->SendSysMessage("Invalid amount.");
            return false;
        }

        // Determine token type (default: upgrade_token)
        uint8 currency = 1;  // 1 = upgrade_token, 2 = artifact_essence
        if (tokenType && std::string(tokenType) == "artifact_essence")
            currency = 2;

        // Get player (by name or GUID)
        Player* target = ObjectAccessor::FindPlayerByName(playerName);
        if (!target)
        {
            handler->SendSysMessage("Player not found.");
            return false;
        }

        // Award tokens
    DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (mgr)
        {
            mgr->AddCurrency(target->GetGUID().GetCounter(), (DarkChaos::ItemUpgrade::CurrencyType)currency, amount);
            handler->PSendSysMessage("Added %u %s to player %s", amount, 
                currency == 1 ? "Upgrade Tokens" : "Artifact Essence", target->GetName().c_str());
            
            // Send notification to player
            ChatHandler playerHandler(target->GetSession());
            playerHandler.PSendSysMessage("|cff00ff00You received %u %s from GM.|r", amount,
                currency == 1 ? "Upgrade Tokens" : "Artifact Essence");
        }
        else
            handler->SendSysMessage("Error: Upgrade Manager not initialized.");

        return true;
    }

    // Handler for .upgrade token remove
    static bool HandleTokenRemove(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->SendSysMessage("Usage: .upgrade token remove <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        char* playerName = strtok((char*)args, " ");
        char* amountStr = strtok(nullptr, " ");
        char* tokenType = strtok(nullptr, " ");

        if (!playerName || !amountStr)
        {
            handler->SendSysMessage("Usage: .upgrade token remove <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        uint32 amount = 0;
        if (!Acore::StringTo<uint32>(amountStr, amount) || amount == 0)
        {
            handler->SendSysMessage("Invalid amount.");
            return false;
        }

        uint8 currency = 1;
        if (tokenType && std::string(tokenType) == "artifact_essence")
            currency = 2;

        Player* target = ObjectAccessor::FindPlayerByName(playerName);
        if (!target)
        {
            handler->SendSysMessage("Player not found.");
            return false;
        }

    DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (mgr)
        {
            if (mgr->RemoveCurrency(target->GetGUID().GetCounter(), (DarkChaos::ItemUpgrade::CurrencyType)currency, amount))
            {
                handler->PSendSysMessage("Removed %u %s from player %s", amount,
                    currency == 1 ? "Upgrade Tokens" : "Artifact Essence", target->GetName().c_str());
                ChatHandler targetHandler(target->GetSession());
                targetHandler.PSendSysMessage("|cffff0000%u %s was removed by GM.|r", amount,
                    currency == 1 ? "Upgrade Tokens" : "Artifact Essence");
            }
            else
                handler->SendSysMessage("Player does not have enough tokens.");
        }
        else
            handler->SendSysMessage("Error: Upgrade Manager not initialized.");

        return true;
    }

    // Handler for .upgrade token set
    static bool HandleTokenSet(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->SendSysMessage("Usage: .upgrade token set <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        char* playerName = strtok((char*)args, " ");
        char* amountStr = strtok(nullptr, " ");
        char* tokenType = strtok(nullptr, " ");

        if (!playerName || !amountStr)
        {
            handler->SendSysMessage("Usage: .upgrade token set <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        uint32 amount = 0;
        if (!Acore::StringTo<uint32>(amountStr, amount))
        {
            handler->SendSysMessage("Invalid amount.");
            return false;
        }

        uint8 currency = 1;
        if (tokenType && std::string(tokenType) == "artifact_essence")
            currency = 2;

        Player* target = ObjectAccessor::FindPlayerByName(playerName);
        if (!target)
        {
            handler->SendSysMessage("Player not found.");
            return false;
        }

        // Query current amount, then adjust
    DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (mgr)
        {
            uint32 current = mgr->GetCurrency(target->GetGUID().GetCounter(), (DarkChaos::ItemUpgrade::CurrencyType)currency);
            if (amount > current)
                mgr->AddCurrency(target->GetGUID().GetCounter(), (DarkChaos::ItemUpgrade::CurrencyType)currency, amount - current);
            else if (amount < current)
                mgr->RemoveCurrency(target->GetGUID().GetCounter(), (DarkChaos::ItemUpgrade::CurrencyType)currency, current - amount);

            handler->PSendSysMessage("Set %s to %u for player %s", 
                currency == 1 ? "Upgrade Tokens" : "Artifact Essence", amount, target->GetName().c_str());
        }
        else
            handler->SendSysMessage("Error: Upgrade Manager not initialized.");

        return true;
    }

    // Handler for .upgrade token info
    static bool HandleTokenInfo(ChatHandler* handler, char const* args)
    {
        Player* player = nullptr;

        if (args && *args)
        {
            player = ObjectAccessor::FindPlayerByName(args);
            if (!player)
            {
                handler->SendSysMessage("Player not found.");
                return false;
            }
        }
        else
        {
            player = handler->GetSession()->GetPlayer();
            if (!player)
            {
                handler->SendSysMessage("No player specified and not in-game.");
                return false;
            }
        }

    DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!mgr)
        {
            handler->SendSysMessage("Error: Upgrade Manager not initialized.");
            return true;
        }

        uint32 tokens = mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN);
        uint32 essence = mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE);

        handler->PSendSysMessage("=== Token Info for %s ===", player->GetName().c_str());
        handler->PSendSysMessage("Upgrade Tokens: %u", tokens);
        handler->PSendSysMessage("Artifact Essence: %u", essence);

        return true;
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

void AddItemUpgradeGMCommandScript()
{
    new ItemUpgradeGMCommand();
}

// Legacy function name for backwards compatibility
void AddItemUpgradeCommandScript()
{
    AddItemUpgradeGMCommandScript();
}
