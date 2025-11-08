/*
* Phase 4A: Item Upgrade Mechanics - Upgrade Interface NPC Script
* 
* This script provides the NPC interface for:
* - Viewing upgradeable items
* - Viewing upgrade costs
* - Performing upgrades
* - Viewing upgrade statistics
* 
* Date: November 4, 2025
*/

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "Chat.h"
#include "GossipDef.h"
#include "ItemUpgradeManager.h"
#include "ItemUpgradeMechanics.h"
#include "ItemUpgradeCommunication.h"
#include <sstream>
#include <iomanip>

class ItemUpgradeNPC_Upgrader : public CreatureScript
{
public:
    ItemUpgradeNPC_Upgrader() : CreatureScript("npc_item_upgrade_upgrader") { }
    
    struct UpgradeSession
    {
        uint32 player_guid;
        uint32 selected_item_guid;
        uint8 target_upgrade_level;
        uint32 essence_cost;
        uint32 token_cost;
        uint64 session_timestamp;
    };
    
    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        // Open the retail-like upgrade interface directly
        ItemUpgradeCommunicationHandler::OpenUpgradeInterface(player);

        // Still show a basic gossip menu for additional options
        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "View Upgradeable Items (Legacy)", GOSSIP_SENDER_MAIN, 10);
        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "View My Upgrade Statistics", GOSSIP_SENDER_MAIN, 20);
        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "How does item upgrading work?", GOSSIP_SENDER_MAIN, 30);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Nevermind", GOSSIP_SENDER_MAIN, 100);

        SendGossipMenuFor(player, 1, creature);
        return true;
    }
    
    bool OnGossipSelect(Player* player, Creature* creature, [[maybe_unused]] uint32 sender, uint32 action) override
    {
        if (!player || !creature)
            return false;
        
        ClearGossipMenuFor(player);
        
        switch (action)
        {
            case 10:
                ShowUpgradableItems(player, creature);
                break;
            case 20:
                ShowUpgradeStatistics(player, creature);
                break;
            case 30:
                ShowHelpInformation(player, creature);
                break;
            case 100:
                OnGossipHello(player, creature);
                return true;
            default:
                // Item selection (1000+)
                if (action >= 1000 && action < 2000)
                {
                    ShowItemUpgradeUI(player, creature, action - 1000);
                }
                // Perform upgrade (2000+)
                else if (action >= 2000)
                {
                    PerformUpgrade(player, creature, action - 2000);
                }
                break;
        }
        
        return true;
    }
    
private:
    void PerformUpgrade(Player* player, Creature* creature, uint32 item_guid)
    {
        ClearGossipMenuFor(player);
        
        if (!player)
        {
            SendErrorMessage(player, "Invalid player!");
            return;
        }
        
        DarkChaos::ItemUpgrade::UpgradeManager* manager = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!manager)
        {
            SendErrorMessage(player, "Upgrade system not available.");
            return;
        }
        
        // Find the item by GUID
        Item* item = FindItemByGuid(player, item_guid);
        if (!item)
        {
            SendErrorMessage(player, "Item not found in your inventory!");
            ShowUpgradableItems(player, creature);
            return;
        }
        
        ItemTemplate const* proto = item->GetTemplate();
        if (!proto)
        {
            SendErrorMessage(player, "Item template not found!");
            return;
        }
        
        // Get current upgrade cost
        uint32 next_essence, next_tokens;
        if (!manager->GetNextUpgradeCost(item_guid, next_essence, next_tokens))
        {
            SendErrorMessage(player, "Item is already fully upgraded!");
            ShowUpgradableItems(player, creature);
            return;
        }
        
        // Check player currency
        uint32 player_essence = GetPlayerUpgradeEssence(player->GetGUID().GetCounter());
        uint32 player_tokens = GetPlayerUpgradeTokens(player->GetGUID().GetCounter());
        
        if (player_essence < next_essence)
        {
            SendErrorMessage(player, "Not enough Artifact Essence!");
            return;
        }
        
        if (player_tokens < next_tokens)
        {
            SendErrorMessage(player, "Not enough Upgrade Tokens!");
            return;
        }
        
        // Perform the upgrade
        if (!manager->UpgradeItem(player->GetGUID().GetCounter(), item_guid))
        {
            SendErrorMessage(player, "Upgrade failed! Please try again later.");
            return;
        }
        
        // Deduct currency
        if (!manager->RemoveCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE, next_essence))
        {
            SendErrorMessage(player, "Failed to deduct Essence!");
            return;
        }
        
        if (!manager->RemoveCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN, next_tokens))
        {
            SendErrorMessage(player, "Failed to deduct Tokens!");
            return;
        }
        
        // Success message
        std::ostringstream success_msg;
        success_msg << "|cff00ff00✓ " << proto->Name1 << " upgraded successfully!|r\n";
        success_msg << "  Deducted: " << next_essence << " Essence, " << next_tokens << " Tokens\n";
        success_msg << "  Your new essence: " << (player_essence - next_essence) << "\n";
        success_msg << "  Your new tokens: " << (player_tokens - next_tokens);
        
        ChatHandler(player->GetSession()).SendSysMessage(success_msg.str().c_str());
        
        // CRITICAL: Force player stat update to apply upgraded stats immediately
        DarkChaos::ItemUpgrade::ForcePlayerStatUpdate(player);
        
        // Show the item again with updated state
        ShowItemUpgradeUI(player, creature, item_guid);
    }
    
    void ShowUpgradableItems(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        
        std::ostringstream oss;
        oss << "|cffffd700===== Upgradeable Items =====|r\n";
        
        uint32 item_count = 0;
    DarkChaos::ItemUpgrade::UpgradeManager* manager = DarkChaos::ItemUpgrade::GetUpgradeManager();
        
        // Iterate through equipment slots
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;
            
            if (manager && manager->CanUpgradeItem(item->GetGUID().GetCounter(), player->GetGUID().GetCounter()))
            {
                ItemTemplate const* proto = item->GetTemplate();
                std::string item_name = proto ? proto->Name1 : "Unknown Item";
                
                // Mark equipped items with [EQUIPPED] tag
                item_name = "|cff00ff00[EQUIPPED]|r " + item_name;
                
                uint32 item_guid = item->GetGUID().GetCounter();
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, item_name, GOSSIP_SENDER_MAIN, 1000 + item_guid);
                item_count++;
            }
        }
        
        // Iterate through backpack
        for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;
            
            if (manager && manager->CanUpgradeItem(item->GetGUID().GetCounter(), player->GetGUID().GetCounter()))
            {
                ItemTemplate const* proto = item->GetTemplate();
                std::string item_name = proto ? proto->Name1 : "Unknown Item";
                
                // Mark backpack items with [BACKPACK] tag
                item_name = "|cffffff00[BACKPACK]|r " + item_name;
                
                uint32 item_guid = item->GetGUID().GetCounter();
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, item_name, GOSSIP_SENDER_MAIN, 1000 + item_guid);
                item_count++;
            }
        }
        
        // Iterate through bags
        for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
        {
            Bag* bag_item = player->GetBagByPos(bag);
            if (!bag_item)
                continue;
            
            for (uint32 slot = 0; slot < bag_item->GetBagSize(); ++slot)
            {
                Item* item = player->GetItemByPos(bag, slot);
                if (!item)
                    continue;
                
                if (manager && manager->CanUpgradeItem(item->GetGUID().GetCounter(), player->GetGUID().GetCounter()))
                {
                    ItemTemplate const* proto = item->GetTemplate();
                    std::string item_name = proto ? proto->Name1 : "Unknown Item";
                    
                    // Mark bag items with [BAG X] tag where X is the bag number
                    std::ostringstream bag_label;
                    bag_label << "|cffff8000[BAG " << (bag - INVENTORY_SLOT_BAG_START + 1) << "]|r ";
                    item_name = bag_label.str() + item_name;
                    
                    uint32 item_guid = item->GetGUID().GetCounter();
                    AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, item_name, GOSSIP_SENDER_MAIN, 1000 + item_guid);
                    item_count++;
                }
            }
        }
        
        if (item_count == 0)
        {
            oss << "|cffff0000No upgradeable items found.|r\n";
            oss << "You need items of Uncommon quality or higher.\n";
        }
        else
        {
            oss << "|cff00ff00Found " << item_count << " upgradeable item(s)|r\n";
            oss << "|cff00ff00[EQUIPPED]|r Equipment\n";
            oss << "|cffffff00[BACKPACK]|r Inventory\n";
            oss << "|cffff8000[BAG X]|r In Bags\n";
        }
        
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 100);
        SendGossipMenuFor(player, 1, creature->GetGUID());
        player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
    }
    
    void ShowItemUpgradeUI(Player* player, Creature* creature, uint32 item_guid)
    {
        ClearGossipMenuFor(player);
        
    DarkChaos::ItemUpgrade::UpgradeManager* manager = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!manager)
        {
            SendErrorMessage(player, "Upgrade system not available.");
            return;
        }
        
        // Find the item by GUID
        Item* item = FindItemByGuid(player, item_guid);
        if (!item)
        {
            SendErrorMessage(player, "Item not found in your inventory.");
            return;
        }
        
        ItemTemplate const* proto = item->GetTemplate();
        if (!proto)
            return;
        
        std::ostringstream oss;
        oss << "|cffffd700===== " << proto->Name1 << " =====|r\n\n";
        
        // Get upgrade display info
        std::string upgrade_info = manager->GetUpgradeDisplay(item_guid);
        oss << upgrade_info << "\n";
        
        // Add upgrade button if not maxed
        uint32 next_essence, next_tokens;
        if (manager->GetNextUpgradeCost(item_guid, next_essence, next_tokens))
        {
            uint32 player_essence = GetPlayerUpgradeEssence(player->GetGUID().GetCounter());
            uint32 player_tokens = GetPlayerUpgradeTokens(player->GetGUID().GetCounter());
            
            bool can_afford = (player_essence >= next_essence && player_tokens >= next_tokens);
            
            if (can_afford)
            {
                oss << "\n|cff00ff00✓ You can afford this upgrade!|r\n";
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, 
                    "PERFORM UPGRADE", GOSSIP_SENDER_MAIN, 2000 + item_guid);
            }
            else
            {
                oss << "\n|cffff0000✗ You cannot afford this upgrade.|r\n";
                if (player_essence < next_essence)
                    oss << "  Missing " << (next_essence - player_essence) << " Essence\n";
                if (player_tokens < next_tokens)
                    oss << "  Missing " << (next_tokens - player_tokens) << " Tokens\n";
            }
        }
        
        // Store UI content in gossip
        player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
        
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 10);
        SendGossipMenuFor(player, 1, creature->GetGUID());
    }
    
    void ShowUpgradeStatistics(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        
        uint32 player_guid = player->GetGUID().GetCounter();
        
        std::ostringstream oss;
        oss << "|cffffd700===== Your Upgrade Statistics =====|r\n\n";
        
        // Get current currency balances
        uint32 current_essence = GetPlayerUpgradeEssence(player_guid);
        uint32 current_tokens = GetPlayerUpgradeTokens(player_guid);
        
        oss << "|cff00ff00Current Currency:|r\n";
        oss << "  Essence: " << current_essence << "\n";
        oss << "  Tokens: " << current_tokens << "\n\n";
        
        // Get weekly spending
        QueryResult weekly_result = CharacterDatabase.Query(
            "SELECT essence_spent, tokens_spent FROM dc_weekly_spending "
            "WHERE player_guid = {} AND week_start >= UNIX_TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY))",
            player_guid);
        uint32 weekly_essence_spent = 0;
        uint32 weekly_tokens_spent = 0;
        if (weekly_result)
        {
            do
            {
                weekly_essence_spent += weekly_result->Fetch()[0].Get<uint32>();
                weekly_tokens_spent += weekly_result->Fetch()[1].Get<uint32>();
            } while (weekly_result->NextRow());
        }
        
        oss << "|cff00ff00Weekly Spending:|r\n";
        oss << "  Essence: " << weekly_essence_spent << "\n";
        oss << "  Tokens: " << weekly_tokens_spent << "\n\n";
        
        // Get total spending (all time)
        QueryResult total_result = CharacterDatabase.Query(
            "SELECT COALESCE(SUM(essence_spent), 0), COALESCE(SUM(tokens_spent), 0) FROM dc_weekly_spending "
            "WHERE player_guid = {}",
            player_guid);
        uint32 total_essence_spent = 0;
        uint32 total_tokens_spent = 0;
        if (total_result)
        {
            total_essence_spent = total_result->Fetch()[0].Get<uint32>();
            total_tokens_spent = total_result->Fetch()[1].Get<uint32>();
        }
        
        oss << "|cff00ff00Total Spent (All Time):|r\n";
        oss << "  Essence: " << total_essence_spent << "\n";
        oss << "  Tokens: " << total_tokens_spent << "\n\n";
        
        // Query item upgrade statistics
        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(DISTINCT item_guid), SUM(essence_invested), SUM(tokens_invested), "
            "AVG(stat_multiplier), "
            "SUM(CASE WHEN upgrade_level = 15 THEN 1 ELSE 0 END), "
            "MAX(last_upgraded_at) "
            "FROM dc_player_item_upgrades WHERE player_guid = {}", player_guid);
        
        if (result)
        {
            Field* fields = result->Fetch();
            uint32 items_upgraded = fields[0].Get<uint32>();
            uint32 items_essence_invested = fields[1].Get<uint32>();
            uint32 items_tokens_invested = fields[2].Get<uint32>();
            float avg_stat_mult = fields[3].Get<float>();
            uint32 fully_upgraded = fields[4].Get<uint32>();
            uint32 last_upgrade = fields[5].Get<uint32>();
            
            oss << "|cff00ff00Item Upgrade Progress:|r\n";
            oss << "  Items Upgraded: " << items_upgraded << "\n";
            oss << "  Fully Upgraded: " << fully_upgraded << "\n";
            oss << "  Essence Invested: " << items_essence_invested << "\n";
            oss << "  Tokens Invested: " << items_tokens_invested << "\n";
            oss << std::fixed << std::setprecision(2);
            oss << "  Average Stat Bonus: " << (avg_stat_mult - 1.0f) * 100.0f << "%\n";
            
            if (last_upgrade > 0)
            {
                time_t last_time = last_upgrade;
                char* time_str = ctime(&last_time);
                if (time_str)
                {
                    // Remove trailing newline from ctime
                    size_t len = strlen(time_str);
                    if (len > 0 && time_str[len-1] == '\n')
                        time_str[len-1] = '\0';
                    oss << "  Last Upgrade: " << time_str << "\n";
                }
            }
        }
        else
        {
            oss << "|cffff0000No upgrades yet. Get started by selecting an item!|r\n";
        }
        
        player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
        
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 100);
        SendGossipMenuFor(player, 1, creature->GetGUID());
    }
    
    void ShowHelpInformation(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        
        std::ostringstream oss;
        oss << "|cffffd700===== Item Upgrade System Help =====|r\n\n";
        
        oss << "|cff00ff00What is Item Upgrading?|r\n";
        oss << "Item Upgrading allows you to increase the power of your equipment using\n";
        oss << "Upgrade Tokens and Essence currency. Each upgrade increases your item's\n";
        oss << "stats and item level.\n\n";
        
        oss << "|cff00ff00Upgrade Costs:|r\n";
        oss << "• Common items: Lowest cost, 10 levels max\n";
        oss << "• Uncommon: Low cost, 12 levels max\n";
        oss << "• Rare: Medium cost, 15 levels max\n";
        oss << "• Epic: High cost, 15 levels max\n";
        oss << "• Legendary: Highest cost, 15 levels max\n\n";
        
        oss << "|cff00ff00Stat Scaling:|r\n";
        oss << "• Base: +2.5% stats per upgrade level\n";
        oss << "• Common items get -10% reduction\n";
        oss << "• Legendary items get +25% bonus\n\n";
        
        oss << "|cff00ff00Item Level Bonus:|r\n";
        oss << "• Common: +1 ilvl per level\n";
        oss << "• Rare: +1.5 ilvl per level\n";
        oss << "• Epic: +2 ilvl per level\n";
        oss << "• Legendary: +2.5 ilvl per level\n\n";
        
        oss << "|cff00ff00Costs Escalate:|r\n";
        oss << "• Each level costs 10% more than previous\n";
        oss << "• Later upgrades are more expensive\n";
        oss << "• Plan your upgrades carefully!\n\n";
        
        oss << "|cff00ff00Pro Tip:|r\n";
        oss << "Save your high-cost currencies for Epic and Legendary items!\n";
        
        player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
        
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 100);
        SendGossipMenuFor(player, 1, creature->GetGUID());
    }
    
    Item* FindItemByGuid(Player* player, uint32 item_guid)
    {
        if (!player || item_guid == 0)
            return nullptr;
        
        // Check equipment slots first
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (item && item->GetGUID().GetCounter() == item_guid)
                return item;
        }
        
        // Check backpack
        for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (item && item->GetGUID().GetCounter() == item_guid)
                return item;
        }
        
        // Check bags
        for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
        {
            Bag* bag_item = player->GetBagByPos(bag);
            if (bag_item)
            {
                for (uint32 slot = 0; slot < bag_item->GetBagSize(); ++slot)
                {
                    Item* item = player->GetItemByPos(bag, slot);
                    if (item && item->GetGUID().GetCounter() == item_guid)
                        return item;
                }
            }
        }
        
        // Check bank slots
        for (uint8 slot = BANK_SLOT_ITEM_START; slot < BANK_SLOT_ITEM_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (item && item->GetGUID().GetCounter() == item_guid)
                return item;
        }
        
        // Check bank bags
        for (uint8 bag = BANK_SLOT_BAG_START; bag < BANK_SLOT_BAG_END; ++bag)
        {
            Bag* bag_item = player->GetBagByPos(bag);
            if (bag_item)
            {
                for (uint32 slot = 0; slot < bag_item->GetBagSize(); ++slot)
                {
                    Item* item = player->GetItemByPos(bag, slot);
                    if (item && item->GetGUID().GetCounter() == item_guid)
                        return item;
                }
            }
        }
        
        return nullptr;
    }
    
    uint32 GetPlayerUpgradeTokens(uint32 player_guid)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT amount FROM dc_player_upgrade_tokens WHERE player_guid = {} AND currency_type = 'upgrade_token'", player_guid);
        return result ? result->Fetch()[0].Get<uint32>() : 0;
    }
    
    uint32 GetPlayerUpgradeEssence(uint32 player_guid)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT amount FROM dc_player_upgrade_tokens WHERE player_guid = {} AND currency_type = 'artifact_essence'", player_guid);
        return result ? result->Fetch()[0].Get<uint32>() : 0;
    }
    
    void SendErrorMessage(Player* player, const char* message)
    {
        if (player && message)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("%s", "|cffff0000[Upgrade Error]|r ");
            ChatHandler(player->GetSession()).SendSysMessage(message);
        }
    }
};

// Registration
void AddSC_ItemUpgradeMechanics()
{
    new ItemUpgradeNPC_Upgrader();
}
