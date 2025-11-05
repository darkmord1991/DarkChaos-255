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
        
    AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "View Upgradeable Items", GOSSIP_SENDER_MAIN, 10);
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
        
        // Find the item in player's equipment
        Item* item = nullptr;
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* test_item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (test_item && test_item->GetGUID().GetCounter() == item_guid)
            {
                item = test_item;
                break;
            }
        }
        
        if (!item)
        {
            SendErrorMessage(player, "Item not found in your equipment!");
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
        
        // Iterate through player's items
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;
            
            if (manager && manager->CanUpgradeItem(item->GetGUID().GetCounter(), player->GetGUID().GetCounter()))
            {
                ItemTemplate const* proto = item->GetTemplate();
                std::string item_name = proto ? proto->Name1 : "Unknown Item";
                
                uint32 item_guid = item->GetGUID().GetCounter();
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, item_name, GOSSIP_SENDER_MAIN, 1000 + item_guid);
                item_count++;
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
            oss << "Click on an item to see upgrade details.\n";
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
        
        // Get item details
        Item* item = nullptr;
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* test_item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (test_item && test_item->GetGUID().GetCounter() == item_guid)
            {
                item = test_item;
                break;
            }
        }
        
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
        
        // Query from database
        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(DISTINCT item_guid), SUM(essence_invested), SUM(tokens_invested), "
            "AVG(stat_multiplier), "
            "SUM(CASE WHEN upgrade_level = 15 THEN 1 ELSE 0 END), "
            "MAX(UNIX_TIMESTAMP(last_upgraded_at)) "
            "FROM dc_player_item_upgrades WHERE player_guid = {}", player_guid);
        
        if (result)
        {
            Field* fields = result->Fetch();
            uint32 items_upgraded = fields[0].Get<uint32>();
            uint32 total_essence = fields[1].Get<uint32>();
            uint32 total_tokens = fields[2].Get<uint32>();
            float avg_stat_mult = fields[3].Get<float>();
            uint32 fully_upgraded = fields[4].Get<uint32>();
            uint32 last_upgrade = fields[5].Get<uint32>();
            
            oss << "|cff00ff00Items Upgraded:|r " << items_upgraded << "\n";
            oss << "|cff00ff00Fully Upgraded:|r " << fully_upgraded << "\n";
            oss << "|cff00ff00Total Essence Spent:|r " << total_essence << "\n";
            oss << "|cff00ff00Total Tokens Spent:|r " << total_tokens << "\n";
            oss << std::fixed << std::setprecision(2);
            oss << "|cff00ff00Average Stat Bonus:|r " << (avg_stat_mult - 1.0f) * 100.0f << "%\n";
            
            if (last_upgrade > 0)
            {
                time_t last_time = last_upgrade;
                oss << "|cff00ff00Last Upgrade:|r " << ctime(&last_time);
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
    
    uint32 GetPlayerUpgradeEssence(uint32 player_guid)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT amount FROM dc_player_upgrade_tokens WHERE player_guid = {} AND currency_type = 'artifact_essence'", player_guid);
        return result ? result->Fetch()[0].Get<uint32>() : 0;
    }
    
    uint32 GetPlayerUpgradeTokens(uint32 player_guid)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT amount FROM dc_player_upgrade_tokens WHERE player_guid = {} AND currency_type = 'upgrade_token'", player_guid);
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
