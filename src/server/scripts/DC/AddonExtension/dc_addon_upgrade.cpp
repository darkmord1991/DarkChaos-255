/*
 * Dark Chaos - Item Upgrade Addon Module Handler
 * ===============================================
 * 
 * Handles DC|UPG|... messages for item upgrade system.
 * Bridges between new unified protocol and existing ItemUpgradeAddonHandler.
 * 
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "DCAddonNamespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "Chat.h"
#include "ItemUpgradeMechanics.h"
#include "ItemUpgradeManager.h"

namespace DCAddon
{
namespace Upgrade
{
    // Currency item IDs (cached from config)
    static uint32 s_TokenId = 300311;
    static uint32 s_EssenceId = 300312;
    
    // Load config
    static void LoadConfig()
    {
        s_TokenId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.TokenId", 300311);
        s_EssenceId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.EssenceId", 300312);
    }
    
    // Translate addon bag/slot to server format
    static bool TranslateAddonBagSlot(uint32 extBag, uint32 extSlot, uint8& bagOut, uint8& slotOut)
    {
        if (extSlot > 255)
            return false;

        if (extBag == INVENTORY_SLOT_BAG_0 ||
            (extBag >= INVENTORY_SLOT_BAG_START && extBag < INVENTORY_SLOT_BAG_END) ||
            (extBag >= BANK_SLOT_BAG_START && extBag < BANK_SLOT_BAG_END))
        {
            bagOut = static_cast<uint8>(extBag);
            slotOut = static_cast<uint8>(extSlot);
            return true;
        }

        if (extBag == 0)
        {
            uint32 const backpackSlots = INVENTORY_SLOT_ITEM_END - INVENTORY_SLOT_ITEM_START;
            if (extSlot >= backpackSlots)
                return false;
            bagOut = INVENTORY_SLOT_BAG_0;
            slotOut = static_cast<uint8>(INVENTORY_SLOT_ITEM_START + extSlot);
            return true;
        }

        if (extBag >= 1 && extBag <= 4)
        {
            bagOut = static_cast<uint8>(INVENTORY_SLOT_BAG_START + (extBag - 1));
            slotOut = static_cast<uint8>(extSlot);
            return true;
        }

        if (extBag >= 5 && extBag <= 11)
        {
            bagOut = static_cast<uint8>(BANK_SLOT_BAG_START + (extBag - 5));
            slotOut = static_cast<uint8>(extSlot);
            return true;
        }

        return false;
    }
    
    // Send currency update to client
    static void SendCurrencyUpdate(Player* player)
    {
        uint32 tokens = player->GetItemCount(s_TokenId);
        uint32 essence = player->GetItemCount(s_EssenceId);
        
        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_CURRENCY_UPDATE)
            .Add(tokens)
            .Add(essence)
            .Add(s_TokenId)
            .Add(s_EssenceId)
            .Send(player);
    }
    
    // Handler: Get item upgrade info
    static void HandleGetItemInfo(Player* player, const ParsedMessage& msg)
    {
        uint32 extBag = msg.GetUInt32(0);
        uint32 extSlot = msg.GetUInt32(1);
        
        uint8 bag = 0, slot = 0;
        if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
        {
            Message(Module::UPGRADE, Opcode::Upgrade::SMSG_ITEM_INFO)
                .Add(0)  // error
                .Add("Invalid slot")
                .Send(player);
            return;
        }
        
        Item* item = player->GetItemByPos(bag, slot);
        if (!item)
        {
            Message(Module::UPGRADE, Opcode::Upgrade::SMSG_ITEM_INFO)
                .Add(0)
                .Add("Item not found")
                .Send(player);
            return;
        }
        
        uint32 itemGUID = item->GetGUID().GetCounter();
        uint32 baseItemLevel = item->GetTemplate()->ItemLevel;
        uint32 currentEntry = item->GetEntry();
        uint32 baseEntry = currentEntry;
        
        // Check if clone
        QueryResult baseResult = WorldDatabase.Query(
            "SELECT base_item_id, upgrade_level FROM dc_item_upgrade_clones WHERE clone_item_id = {}",
            currentEntry);
        
        uint32 cloneDetectedLevel = 0;
        if (baseResult)
        {
            baseEntry = (*baseResult)[0].Get<uint32>();
            cloneDetectedLevel = (*baseResult)[1].Get<uint32>();
        }
        
        // Get upgrade state
        QueryResult result = CharacterDatabase.Query(
            "SELECT upgrade_level, tier_id FROM dc_item_upgrades WHERE item_guid = {}",
            itemGUID);
        
        uint32 upgradeLevel = 0;
        uint32 tier = 1;
        
        if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
            tier = mgr->GetItemTier(baseEntry);
        
        if (result)
        {
            upgradeLevel = (*result)[0].Get<uint32>();
        }
        else if (cloneDetectedLevel > 0)
        {
            upgradeLevel = cloneDetectedLevel;
        }
        
        float statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
            static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
        
        uint16 upgradedIlvl = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
            baseItemLevel, static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
        
        // Get tier max level
        uint32 maxLevel = 15;
        QueryResult tierResult = WorldDatabase.Query(
            "SELECT max_upgrade_level FROM dc_item_upgrade_tiers WHERE tier_id = {} AND season = 1",
            tier);
        if (tierResult)
            maxLevel = (*tierResult)[0].Get<uint32>();
        
        // Build clone map
        std::string cloneMap;
        QueryResult cloneResult = WorldDatabase.Query(
            "SELECT upgrade_level, clone_item_id FROM dc_item_upgrade_clones WHERE base_item_id = {} AND tier_id = {}",
            baseEntry, tier);
        
        cloneMap = "0-" + std::to_string(baseEntry);
        if (cloneResult)
        {
            do
            {
                uint32 level = (*cloneResult)[0].Get<uint32>();
                uint32 entry = (*cloneResult)[1].Get<uint32>();
                cloneMap += "," + std::to_string(level) + "-" + std::to_string(entry);
            } while (cloneResult->NextRow());
        }
        
        // Send response
        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_ITEM_INFO)
            .Add(1)  // success
            .Add(itemGUID)
            .Add(upgradeLevel)
            .Add(tier)
            .Add(maxLevel)
            .Add(baseItemLevel)
            .Add(upgradedIlvl)
            .Add(statMultiplier)
            .Add(baseEntry)
            .Add(currentEntry)
            .Add(cloneMap)
            .Send(player);
    }
    
    // Handler: Get upgrade costs
    static void HandleGetCosts(Player* player, const ParsedMessage& msg)
    {
        uint32 tier = msg.GetUInt32(0);
        uint32 fromLevel = msg.GetUInt32(1);
        uint32 toLevel = msg.GetUInt32(2);
        
        if (tier < 1 || tier > 3 || fromLevel >= toLevel)
        {
            Message(Module::UPGRADE, Opcode::Upgrade::SMSG_COST_INFO)
                .Add(0)  // error
                .Add("Invalid parameters")
                .Send(player);
            return;
        }
        
        QueryResult result = WorldDatabase.Query(
            "SELECT SUM(token_cost), SUM(essence_cost) FROM dc_item_upgrade_costs "
            "WHERE tier_id = {} AND upgrade_level BETWEEN {} AND {}",
            tier, fromLevel + 1, toLevel);
        
        uint32 tokens = 0, essence = 0;
        if (result)
        {
            if (!(*result)[0].IsNull())
                tokens = (*result)[0].Get<uint32>();
            if (!(*result)[1].IsNull())
                essence = (*result)[1].Get<uint32>();
        }
        
        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_COST_INFO)
            .Add(1)  // success
            .Add(tier)
            .Add(fromLevel)
            .Add(toLevel)
            .Add(tokens)
            .Add(essence)
            .Send(player);
    }
    
    // Handler: List upgradeable items in inventory
    static void HandleListUpgradeable(Player* player, const ParsedMessage& /*msg*/)
    {
        // Scan player inventory for upgradeable items
        std::vector<std::string> items;
        
        // Scan equipped items
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;
            
            uint32 entry = item->GetEntry();
            uint32 baseEntry = entry;
            
            // Check if this entry or its base is upgradeable
            QueryResult baseResult = WorldDatabase.Query(
                "SELECT base_item_id FROM dc_item_upgrade_clones WHERE clone_item_id = {}",
                entry);
            if (baseResult)
                baseEntry = (*baseResult)[0].Get<uint32>();
            
            // Check if item has upgrade path
            QueryResult tierResult = WorldDatabase.Query(
                "SELECT tier_id FROM dc_item_upgrade_tier_items WHERE item_id = {}",
                baseEntry);
            
            if (tierResult)
            {
                // Format: bag:slot:guid:entry:tier
                std::ostringstream ss;
                ss << "0:" << (int)slot << ":" << item->GetGUID().GetCounter() 
                   << ":" << entry << ":" << (*tierResult)[0].Get<uint32>();
                items.push_back(ss.str());
            }
        }
        
        // Scan bags
        for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
        {
            Bag* bagPtr = player->GetBagByPos(bag);
            if (!bagPtr)
                continue;
            
            for (uint8 slot = 0; slot < bagPtr->GetBagSize(); ++slot)
            {
                Item* item = bagPtr->GetItemByPos(slot);
                if (!item)
                    continue;
                
                uint32 entry = item->GetEntry();
                uint32 baseEntry = entry;
                
                QueryResult baseResult = WorldDatabase.Query(
                    "SELECT base_item_id FROM dc_item_upgrade_clones WHERE clone_item_id = {}",
                    entry);
                if (baseResult)
                    baseEntry = (*baseResult)[0].Get<uint32>();
                
                QueryResult tierResult = WorldDatabase.Query(
                    "SELECT tier_id FROM dc_item_upgrade_tier_items WHERE item_id = {}",
                    baseEntry);
                
                if (tierResult)
                {
                    std::ostringstream ss;
                    uint8 addonBag = bag - INVENTORY_SLOT_BAG_START + 1;
                    ss << (int)addonBag << ":" << (int)slot << ":" << item->GetGUID().GetCounter()
                       << ":" << entry << ":" << (*tierResult)[0].Get<uint32>();
                    items.push_back(ss.str());
                }
            }
        }
        
        // Send list (may need chunking for large inventories)
        std::string itemList;
        for (size_t i = 0; i < items.size(); ++i)
        {
            if (i > 0) itemList += ";";
            itemList += items[i];
        }
        
        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADEABLE_LIST)
            .Add(items.size())
            .Add(itemList)
            .Send(player);
    }
    
    // Handler: Perform upgrade (bridge to existing system)
    static void HandleDoUpgrade(Player* player, const ParsedMessage& msg)
    {
        uint32 extBag = msg.GetUInt32(0);
        uint32 extSlot = msg.GetUInt32(1);
        uint32 targetLevel = msg.GetUInt32(2);
        
        // This bridges to the existing .dcupgrade perform command
        // We'll construct the command and execute it through the existing handler
        
        std::ostringstream cmd;
        cmd << "dcupgrade perform " << extBag << " " << extSlot << " " << targetLevel;
        
        // Execute through chat handler
        ChatHandler(player->GetSession()).HandleSentence(cmd.str().c_str());
        
        // The existing handler sends DCUPGRADE_SUCCESS/ERROR via CHAT_MSG_SYSTEM
        // For now, we let that continue - in future could intercept and convert
    }
    
    // Register all handlers
    void RegisterHandlers()
    {
        LoadConfig();
        
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_GET_ITEM_INFO, HandleGetItemInfo);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_GET_COSTS, HandleGetCosts);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_LIST_UPGRADEABLE, HandleListUpgradeable);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_DO_UPGRADE, HandleDoUpgrade);
        
        LOG_INFO("dc.addon", "Item Upgrade module handlers registered");
    }
    
    // Player login hook - send currency update
    void OnPlayerLogin(Player* player)
    {
        if (!MessageRouter::Instance().IsModuleEnabled(Module::UPGRADE))
            return;
        
        SendCurrencyUpdate(player);
    }

}  // namespace Upgrade
}  // namespace DCAddon

// Script class for player hooks
class DCAddonUpgradeScript : public PlayerScript
{
public:
    DCAddonUpgradeScript() : PlayerScript("DCAddonUpgradeScript") {}
    
    void OnPlayerLogin(Player* player) override
    {
        DCAddon::Upgrade::OnPlayerLogin(player);
    }
};

void AddSC_dc_addon_upgrade()
{
    DCAddon::Upgrade::RegisterHandlers();
    new DCAddonUpgradeScript();
}
