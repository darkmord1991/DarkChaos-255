/*
 * Dark Chaos - Item Upgrade Addon Module Handler
 * ===============================================
 *
 * Handles DC|UPG|... messages for item upgrade system.
 * Bridges between new unified protocol and existing ItemUpgradeAddonHandler.
 *
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "dc_addon_transmutation.h"
#include "ScriptMgr.h"
#include "DC/ItemUpgrades/ItemUpgradeSeasonResolver.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "Chat.h"
#include "Spell.h"
#include "SpellMgr.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "DC/ItemUpgrades/ItemUpgradeMechanics.h"
#include "DC/ItemUpgrades/ItemUpgradeUIHelpers.h"
#include <mutex>

namespace DCAddon
{
namespace Upgrade
{
    using namespace DarkChaos::ItemUpgrade::UI;
    static std::map<uint32, uint32> s_PlayerPackageSelections;
    static std::mutex s_PackageSelectionsMutex;  // Thread safety for package selections

    // Send currency update to client
    // Uses unified GetPlayerTokens/GetPlayerEssence which read physical item counts
    void SendCurrencyUpdate(Player* player)
    {
        if (!player)
            return;

        // Use unified currency helpers (reads physical item counts)
        uint32 tokens = DarkChaos::ItemUpgrade::GetPlayerTokens(player);
        uint32 essence = DarkChaos::ItemUpgrade::GetPlayerEssence(player);
        uint32 tokenId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
        uint32 essenceId = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();

        JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_CURRENCY_UPDATE)
            .Set("tokens", static_cast<uint32>(tokens))
            .Set("essence", static_cast<uint32>(essence))
            .Set("tokenId", static_cast<uint32>(tokenId))
            .Set("essenceId", static_cast<uint32>(essenceId))
            .Send(player);
    }

    // Handler: Get item upgrade info
    static void HandleGetItemInfo(Player* player, const ParsedMessage& msg)
    {
        uint32 extBag = msg.GetUInt32(0);
        uint32 extSlot = msg.GetUInt32(1);

        uint8 bag = 0, slot = 0;
        if (!DarkChaos::ItemUpgrade::UI::TranslateAddonBagSlot(extBag, extSlot, bag, slot))
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

        // Special Case: Heirloom Shirt
        if (currentEntry == DarkChaos::ItemUpgrade::UI::HEIRLOOM_SHIRT_ENTRY)
        {
             QueryResult heirloomResult = CharacterDatabase.Query(
                "SELECT upgrade_level FROM dc_heirloom_upgrades WHERE item_guid = {}",
                itemGUID);

            uint32 upgradeLevel = 0;
            if (heirloomResult)
                upgradeLevel = (*heirloomResult)[0].Get<uint32>();

            float statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                static_cast<uint8>(upgradeLevel), static_cast<uint8>(DarkChaos::ItemUpgrade::UI::HEIRLOOM_TIER));

            // Heirloom doesn't use clones, but client expects clone map
            std::string cloneMap;
            for (uint32 i = 0; i <= DarkChaos::ItemUpgrade::UI::HEIRLOOM_MAX_LEVEL; ++i)
            {
                if (i > 0) cloneMap += ",";
                cloneMap += std::to_string(i) + "-" + std::to_string(DarkChaos::ItemUpgrade::UI::HEIRLOOM_SHIRT_ENTRY);
            }

            Message(Module::UPGRADE, Opcode::Upgrade::SMSG_ITEM_INFO)
                .Add(1)
                .Add(itemGUID)
                .Add(upgradeLevel)
                .Add(DarkChaos::ItemUpgrade::UI::HEIRLOOM_TIER)
                .Add(DarkChaos::ItemUpgrade::UI::HEIRLOOM_MAX_LEVEL)
                .Add(baseItemLevel) // base ilvl
                .Add(baseItemLevel) // upgraded ilvl (heirlooms don't change ilvl usually, just stats)
                .Add(statMultiplier)
                .Add(DarkChaos::ItemUpgrade::UI::HEIRLOOM_SHIRT_ENTRY)
                .Add(DarkChaos::ItemUpgrade::UI::HEIRLOOM_SHIRT_ENTRY)
                .Add(cloneMap)
                .Send(player);
            return;
        }

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
            "SELECT upgrade_level FROM dc_item_upgrades WHERE item_guid = {}",
            itemGUID);

        uint32 upgradeLevel = 0;
        uint32 tier = 1;

        // Get tier from database
        if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
            tier = mgr->GetItemTier(baseEntry);
        // Fallback or override from table if mgr fails (redundant but safe)
        if (tier == 0)
        {
             QueryResult tierLookup = WorldDatabase.Query(
                "SELECT tier_id FROM dc_item_templates_upgrade WHERE item_id = {} AND season = 1 AND is_active = 1",
                baseEntry);
             if (tierLookup)
                 tier = (*tierLookup)[0].Get<uint32>();
             else
                 tier = 1;
        }

        if (result)
        {
            upgradeLevel = (*result)[0].Get<uint32>();
        }
        else if (cloneDetectedLevel > 0)
        {
            upgradeLevel = cloneDetectedLevel;
        }

        // Calculate stat multiplier and ilvl
        float statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                    static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));

        uint16 upgradedIlvl = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                    static_cast<uint16>(baseItemLevel), static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));

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
        std::map<uint32, uint32> clones;
        if (cloneResult)
        {
            do
            {
                uint32 level = (*cloneResult)[0].Get<uint32>();
                uint32 entry = (*cloneResult)[1].Get<uint32>();
                clones[level] = entry;
            } while (cloneResult->NextRow());
        }
        // Ensure current is in map
        clones[upgradeLevel] = currentEntry;

        std::ostringstream ss;
        bool first = true;
        for (auto const& pair : clones)
        {
            if (first) first = false;
            else ss << ",";
            ss << pair.first << "-" << pair.second;
        }
        if (ss.str().length() > 2) // more than just base
             cloneMap = ss.str();

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

        auto CheckItem = [&](Item* item, uint8 bag, uint8 slot) {
             if (!item) return;

             uint32 entry = item->GetEntry();
             uint32 baseEntry = entry;

             // Check for Heirloom
             if (entry == HEIRLOOM_SHIRT_ENTRY)
             {
                 std::ostringstream ss;
                 // Format: bag:slot:guid:entry:tier
                 // Use pseudo-tier 3 for heirlooms
                 uint8 addonBag = (bag == INVENTORY_SLOT_BAG_0) ? 0 : (bag - INVENTORY_SLOT_BAG_START + 1);
                 ss << (int)addonBag << ":" << (int)slot << ":" << item->GetGUID().GetCounter()
                    << ":" << entry << ":" << HEIRLOOM_TIER;
                 items.push_back(ss.str());
                 return;
             }

             QueryResult baseResult = WorldDatabase.Query(
                 "SELECT base_item_id FROM dc_item_upgrade_clones WHERE clone_item_id = {}",
                 entry);
             if (baseResult)
                 baseEntry = (*baseResult)[0].Get<uint32>();

             if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
             {
                 uint32 tier = mgr->GetItemTier(baseEntry);
                 if (tier > 0)
                 {
                     std::ostringstream ss;
                     uint8 addonBag = (bag == INVENTORY_SLOT_BAG_0) ? 0 : (bag - INVENTORY_SLOT_BAG_START + 1);
                     ss << (int)addonBag << ":" << (int)slot << ":" << item->GetGUID().GetCounter()
                        << ":" << entry << ":" << tier;
                     items.push_back(ss.str());
                 }
             }
        };

        // Scan equipped items
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            CheckItem(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot), INVENTORY_SLOT_BAG_0, slot);

        // Scan bags
        for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
        {
            Bag* bagPtr = player->GetBagByPos(bag);
            if (!bagPtr) continue;
            for (uint8 slot = 0; slot < bagPtr->GetBagSize(); ++slot)
                CheckItem(bagPtr->GetItemByPos(slot), bag, slot);
        }

        // Scan backpack
        for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
            CheckItem(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot), INVENTORY_SLOT_BAG_0, slot);

        // Send list (chunked if needed, but 2560 chars limit is usually enough for ~50 items)
        std::string itemList;
        for (size_t i = 0; i < items.size(); ++i)
        {
            if (i > 0) itemList += ";";
            itemList += items[i];
        }

        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADEABLE_LIST)
            .Add(static_cast<uint32>(items.size()))
            .Add(itemList)
            .Send(player);
    }

    // Handler: Perform upgrade (Unified Native Logic)
    static void HandleDoUpgrade(Player* player, const ParsedMessage& msg)
    {
        uint32 extBag = msg.GetUInt32(0);
        uint32 extSlot = msg.GetUInt32(1);
        uint32 targetLevel = msg.GetUInt32(2);

        uint8 bag = 0, slot = 0;
        if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADE_RESULT).Add(0).Add("Invalid slot").Send(player);
             return;
        }

        Item* item = player->GetItemByPos(bag, slot);
        if (!item)
        {
            Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADE_RESULT).Add(0).Add("Item not found").Send(player);
            return;
        }

        if (item->GetEntry() == HEIRLOOM_SHIRT_ENTRY)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADE_RESULT).Add(0).Add("Use Heirloom Upgrade for this item").Send(player);
             return;
        }

        uint32 itemGUID = item->GetGUID().GetCounter();
        uint32 currentEntry = item->GetEntry();
        uint32 baseEntry = currentEntry;

        QueryResult baseResult = WorldDatabase.Query(
             "SELECT base_item_id FROM dc_item_upgrade_clones WHERE clone_item_id = {}", currentEntry);
        if (baseResult)
             baseEntry = (*baseResult)[0].Get<uint32>();

        uint32 tier = 1;
        if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
             tier = mgr->GetItemTier(baseEntry);

        QueryResult stateResult = CharacterDatabase.Query(
             "SELECT upgrade_level FROM dc_item_upgrades WHERE item_guid = {}", itemGUID);

        uint32 currentLevel = 0;
        if (stateResult)
             currentLevel = (*stateResult)[0].Get<uint32>();
        else if (baseResult)
        {
             // Check if it's a pre-dropped clone
             QueryResult cloneLevelCheck = WorldDatabase.Query("SELECT upgrade_level FROM dc_item_upgrade_clones WHERE clone_item_id = {}", currentEntry);
             if (cloneLevelCheck)
                 currentLevel = (*cloneLevelCheck)[0].Get<uint32>();
        }

        if (targetLevel <= currentLevel)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADE_RESULT).Add(0).Add("Target level must be higher").Send(player);
             return;
        }

        // Costs
        QueryResult costResult = WorldDatabase.Query(
            "SELECT SUM(token_cost), SUM(essence_cost) FROM dc_item_upgrade_costs "
            "WHERE tier_id = {} AND upgrade_level BETWEEN {} AND {}",
            tier, currentLevel + 1, targetLevel);

        uint32 tokensNeeded = 0;
        uint32 essenceNeeded = 0;
        if (costResult)
        {
             if (!(*costResult)[0].IsNull()) tokensNeeded = (*costResult)[0].Get<uint32>();
             if (!(*costResult)[1].IsNull()) essenceNeeded = (*costResult)[1].Get<uint32>();
        }

        // Check currency
        uint32 tokenId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
        uint32 essenceId = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();

        if (player->GetItemCount(tokenId) < tokensNeeded)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADE_RESULT).Add(0).Add("Not enough Tokens").Send(player);
             return;
        }
        if (player->GetItemCount(essenceId) < essenceNeeded)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADE_RESULT).Add(0).Add("Not enough Essence").Send(player);
             return;
        }

        // Get target clone
        QueryResult targetCloneRes = WorldDatabase.Query(
              "SELECT clone_item_id FROM dc_item_upgrade_clones WHERE base_item_id = {} AND tier_id = {} AND upgrade_level = {}",
              baseEntry, tier, targetLevel);

        if (!targetCloneRes)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADE_RESULT).Add(0).Add("Target clone not found").Send(player);
             return;
        }

        uint32 targetEntry = (*targetCloneRes)[0].Get<uint32>();

        // Consume currency
        if (tokensNeeded > 0) player->DestroyItemCount(tokenId, tokensNeeded, true);
        if (essenceNeeded > 0) player->DestroyItemCount(essenceId, essenceNeeded, true);

        // Perform Swap
        player->DestroyItem(bag, slot, true);

        ItemPosCountVec dest;
        Item* newItem = nullptr;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, targetEntry, 1) == EQUIP_ERR_OK)
            newItem = player->StoreNewItem(dest, targetEntry, true);

         if (newItem)
        {
            uint32 newGuid = newItem->GetGUID().GetCounter();
            DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
            if (mgr)
            {
                 DarkChaos::ItemUpgrade::ItemUpgradeState* state = mgr->GetItemUpgradeState(newGuid);
                 if (state)
                 {
                      state->player_guid = player->GetGUID().GetCounter();
                      state->item_guid = newGuid;
                      state->item_entry = targetEntry;
                      state->tier_id = tier;
                      state->upgrade_level = targetLevel;
                      state->tokens_invested += tokensNeeded;
                      state->essence_invested += essenceNeeded;
                      state->season = 1; // Default season 1
                      state->last_upgraded_at = time(nullptr);
                      // Recalc stats for storage
                      state->stat_multiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                          static_cast<uint8>(targetLevel), static_cast<uint8>(tier));
                      state->upgraded_item_level = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                          static_cast<uint16>(newItem->GetTemplate()->ItemLevel), static_cast<uint8>(targetLevel), static_cast<uint8>(tier));

                      mgr->SaveItemUpgrade(newGuid);
                 }
            }
            // Send success
            Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADE_RESULT).Add(1).Add(newGuid).Add(targetLevel).Send(player);
            SendCurrencyUpdate(player);
        }
        else
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADE_RESULT).Add(0).Add("Inventory full").Send(player);
        }
    }

    // Handler: Package selection (migrated from itemupgrade_communication.lua)
    static void HandlePackageSelect(Player* player, const ParsedMessage& msg)
    {
        uint32 packageId = msg.GetUInt32(0);
        uint32 playerGuid = player->GetGUID().GetCounter();

        // Validate package ID (1-12)
        if (packageId < 1 || packageId > 12)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Invalid package ID.|r");
            return;
        }

        // Store selection
        {
            std::lock_guard<std::mutex> lock(s_PackageSelectionsMutex);
            s_PlayerPackageSelections[playerGuid] = packageId;
        }

        LOG_DEBUG("dc.addon.upgrade", "Player {} selected heirloom package {}",
            player->GetName(), packageId);

        // Send confirmation
        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_PACKAGE_SELECTED)
            .Add(packageId)
            .Send(player);
    }

    // HEIRLOOM HANDLERS

    static void HandleHeirloomQuery(Player* player, const ParsedMessage& msg)
    {
        uint32 extBag = msg.GetUInt32(0);
        uint32 extSlot = msg.GetUInt32(1);

        uint8 bag, slot;
        if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
             return;

        Item* item = player->GetItemByPos(bag, slot);
        if (!item || item->GetEntry() != HEIRLOOM_SHIRT_ENTRY)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_INFO).Add(0).Add("Invalid Heirloom").Send(player);
             return;
        }

        uint32 itemGuid = item->GetGUID().GetCounter();
        QueryResult result = CharacterDatabase.Query("SELECT upgrade_level, package_id FROM dc_heirloom_upgrades WHERE item_guid = {}", itemGuid);

        uint32 level = 0;
        uint32 package = 0;
        if (result)
        {
             level = (*result)[0].Get<uint32>();
             package = (*result)[1].Get<uint32>();
        }

        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_INFO)
             .Add(1)
             .Add(itemGuid)
             .Add(level)
             .Add(package)
             .Add(HEIRLOOM_MAX_LEVEL)
             .Add(HEIRLOOM_MAX_PACKAGE_ID)
             .Send(player);
    }

    static void HandleGetPackages(Player* player, const ParsedMessage& /*msg*/)
    {
         // DCHEIRLOOM_PACKAGES format equivalent
         // ID|Name|Description
         std::vector<std::string> pkgs = {
             "1|Fury|Crit,Haste",
             "2|Precision|Hit,Expertise",
             "3|Devastation|Crit,ArmorPen",
             "4|Swiftblade|Haste,ArmorPen",
             "5|Spellfire|Crit,Haste,SpellPower",
             "6|Arcane|Hit,Haste,SpellPower",
             "7|Bulwark|Dodge,Parry,Block",
             "8|Fortress|Defense,Block,Stamina",
             "9|Survivor|Dodge,Stamina",
             "10|Gladiator|Resilience,Crit",
             "11|Warlord|Resilience,Stamina",
             "12|Balanced|Crit,Hit,Haste"
         };

         Message m(Module::UPGRADE, Opcode::Upgrade::SMSG_PACKAGE_LIST);
         m.Add(static_cast<uint32>(pkgs.size()));
         for (auto const& p : pkgs) m.Add(p);
         m.Send(player);
    }

    static void HandleHeirloomUpgrade(Player* player, const ParsedMessage& msg)
    {
         uint32 extBag = msg.GetUInt32(0);
         uint32 extSlot = msg.GetUInt32(1);
         uint32 targetLevel = msg.GetUInt32(2);
         uint32 packageId = msg.GetUInt32(3);

        uint8 bag, slot;
        if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT).Add(0).Add("Invalid slot").Send(player);
             return;
        }

        Item* item = player->GetItemByPos(bag, slot);
        if (!item || item->GetEntry() != HEIRLOOM_SHIRT_ENTRY)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT).Add(0).Add("Invalid Heirloom").Send(player);
             return;
        }

        // Validate inputs
        if (packageId < 1 || packageId > HEIRLOOM_MAX_PACKAGE_ID)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT).Add(0).Add("Invalid Package").Send(player);
             return;
        }
        if (targetLevel > HEIRLOOM_MAX_LEVEL)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT).Add(0).Add("Level too high").Send(player);
             return;
        }

        uint32 itemGuid = item->GetGUID().GetCounter();
        QueryResult result = CharacterDatabase.Query("SELECT upgrade_level, package_id FROM dc_heirloom_upgrades WHERE item_guid = {}", itemGuid);

        uint32 currentLevel = 0;
        uint32 currentPackage = 0;
        if (result)
        {
             currentLevel = (*result)[0].Get<uint32>();
             currentPackage = (*result)[1].Get<uint32>();
        }

        if (targetLevel < currentLevel && packageId == currentPackage)
        {
              Message(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT).Add(0).Add("Already higher level").Send(player);
              return;
        }

        // Calculate Cost
        QueryResult costRes = WorldDatabase.Query("SELECT SUM(token_cost), SUM(essence_cost) FROM dc_heirloom_upgrade_costs WHERE upgrade_level BETWEEN {} AND {}", currentLevel + 1, targetLevel);

        uint32 tokensNeeded = 0;
        uint32 essenceNeeded = 0;
        if (costRes)
        {
             if (!(*costRes)[0].IsNull()) tokensNeeded = (*costRes)[0].Get<uint32>();
             if (!(*costRes)[1].IsNull()) essenceNeeded = (*costRes)[1].Get<uint32>();
        }

        // Check Currency
        uint32 tokenId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
        uint32 essenceId = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();

        if (player->GetItemCount(tokenId) < tokensNeeded)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT).Add(0).Add("Not enough Tokens").Send(player);
             return;
        }
        if (player->GetItemCount(essenceId) < essenceNeeded)
        {
             Message(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT).Add(0).Add("Not enough Essence").Send(player);
             return;
        }

        // Perform
        if (tokensNeeded > 0) player->DestroyItemCount(tokenId, tokensNeeded, true);
        if (essenceNeeded > 0) player->DestroyItemCount(essenceId, essenceNeeded, true);

        // Apply Enchantment
        // ID: 900000 + (packageId * 100) + level
        uint32 enchantId = HEIRLOOM_ENCHANT_BASE_ID + (packageId * 100) + targetLevel;

        player->ApplyEnchantment(item, PERM_ENCHANTMENT_SLOT, false);
        item->SetEnchantment(PERM_ENCHANTMENT_SLOT, enchantId, 0, 0, player->GetGUID());
        player->ApplyEnchantment(item, PERM_ENCHANTMENT_SLOT, true);

        // Update DB
        CharacterDatabase.Execute("REPLACE INTO dc_heirloom_upgrades (player_guid, item_guid, item_entry, upgrade_level, package_id, enchant_id, last_upgraded_at) VALUES ({}, {}, {}, {}, {}, {}, UNIX_TIMESTAMP())",
            player->GetGUID().GetCounter(), itemGuid, HEIRLOOM_SHIRT_ENTRY, targetLevel, packageId, enchantId);

        // Log
        CharacterDatabase.Execute("INSERT INTO dc_heirloom_upgrade_log (player_guid, item_guid, from_level, to_level, from_package, to_package, cost_token, cost_essence, timestamp) VALUES ({}, {}, {}, {}, {}, {}, {}, {}, UNIX_TIMESTAMP())",
             player->GetGUID().GetCounter(), itemGuid, currentLevel, targetLevel, currentPackage, packageId, tokensNeeded, essenceNeeded);

        // Success
        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT)
            .Add(1)
            .Add(itemGuid)
            .Add(targetLevel)
            .Add(packageId)
            .Add(enchantId)
            .Send(player);

        SendCurrencyUpdate(player);
    }

    // Get player's selected package (exported for other systems)
    uint32 GetPlayerSelectedPackage(Player* player)
    {
        if (!player)
            return 0;

        uint32 playerGuid = player->GetGUID().GetCounter();
        std::lock_guard<std::mutex> lock(s_PackageSelectionsMutex);
        auto it = s_PlayerPackageSelections.find(playerGuid);
        return (it != s_PlayerPackageSelections.end()) ? it->second : 0;
    }

    // Clear player package selection on logout
    void OnPlayerLogout(Player* player)
    {
        if (!player)
            return;

        uint32 playerGuid = player->GetGUID().GetCounter();
        std::lock_guard<std::mutex> lock(s_PackageSelectionsMutex);
        s_PlayerPackageSelections.erase(playerGuid);
    }

    // Register all handlers
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_GET_ITEM_INFO, HandleGetItemInfo);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_GET_COSTS, HandleGetCosts);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_LIST_UPGRADEABLE, HandleListUpgradeable);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_DO_UPGRADE, HandleDoUpgrade);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_PACKAGE_SELECT, HandlePackageSelect);

        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_HEIRLOOM_QUERY, HandleHeirloomQuery);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_GET_PACKAGES, HandleGetPackages);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_HEIRLOOM_UPGRADE, HandleHeirloomUpgrade);

        LOG_INFO("dc.addon", "Item Upgrade module handlers registered (native implementation)");
    }

    // Player login hook - send currency update and initialize package selection
    void OnPlayerLogin(Player* player)
    {
        if (!MessageRouter::Instance().IsModuleEnabled(Module::UPGRADE))
            return;

        // Initialize package selection to 0 (none)
        uint32 playerGuid = player->GetGUID().GetCounter();
        {
            std::lock_guard<std::mutex> lock(s_PackageSelectionsMutex);
            s_PlayerPackageSelections[playerGuid] = 0;
        }

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

    void OnPlayerLogout(Player* player) override
    {
        DCAddon::Upgrade::OnPlayerLogout(player);
    }
};

void AddSC_dc_addon_upgrade()
{
    DCAddon::Upgrade::RegisterHandlers();
    new DCAddonUpgradeScript();
}
