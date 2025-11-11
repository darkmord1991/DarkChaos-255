#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "ItemUpgradeMechanics.h"
#include "ItemUpgradeManager.h"
#include <ctime>
#include <iomanip>
#include <sstream>
#include <limits>
#include <map>
#include <string>
#include "SharedDefines.h"

/*
 * DarkChaos Item Upgrade System - Addon Communication Handler
 *
 * This file handles communication between the client addon and server.
 * Commands: .dcupgrade (init/query/upgrade/batch)
 *
 * RENAMED FROM: ItemUpgradeCommands.cpp
 * REASON: Better clarity - distinguishes from GM admin commands
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 * Updated: November 8, 2025 (Renamed for better organization)
 */

using Acore::ChatCommands::ChatCommandBuilder;
using Acore::ChatCommands::Console;
using DarkChaos::ItemUpgrade::ITEM_UPGRADES_TABLE;
using DarkChaos::ItemUpgrade::ITEM_UPGRADE_LOG_TABLE;

class ItemUpgradeAddonCommands : public CommandScript
{
public:
    ItemUpgradeAddonCommands() : CommandScript("ItemUpgradeAddonCommands") { }

    [[nodiscard]] std::vector<ChatCommandBuilder> GetCommands() const override
    {
        static const std::vector<ChatCommandBuilder> dcupgradeCommandTable =
        {
            ChatCommandBuilder("dcupgrade", HandleDCUpgradeCommand, 0, Console::No),
        };
        return dcupgradeCommandTable;
    }

private:
    // Helper: send response to addon via SYSTEM chat; optionally echo to SAY when debug is enabled
    static void SendAddonResponse(Player* player, std::string const& msg)
    {
        if (!player)
            return;

        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());

        // Optional debug echo to SAY (visible in world) controlled by config
        bool debugToSay = sConfigMgr->GetOption<bool>("ItemUpgrade.DebugToSay", false);
        if (debugToSay)
            player->Say(msg, LANG_UNIVERSAL);
    }
    static bool HandleDCUpgradeCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Get currency item IDs from config
    uint32 essenceId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.EssenceId", 109998); // updated default per configuration note
    uint32 tokenId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.TokenId", 100999);

        // Parse arguments
        std::string argStr = args ? args : "";
        std::string::size_type spacePos = argStr.find(' ');
        std::string subcommand = spacePos != std::string::npos ? argStr.substr(0, spacePos) : argStr;

        if (subcommand.empty())
        {
            SendAddonResponse(player, "DCUPGRADE_ERROR:No command specified");
            return true;
        }

        auto TranslateAddonBagSlot = [](uint32 extBag, uint32 extSlot, uint8& bagOut, uint8& slotOut) -> bool
        {
            if (extSlot > std::numeric_limits<uint8>::max())
                return false;

            // Direct values already in server representation (e.g. manual commands)
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
        };

        // INIT: Get player's current currency (item count)
        if (subcommand == "init")
        {
            uint32 tokens = player->GetItemCount(tokenId);
            uint32 essence = player->GetItemCount(essenceId);

            // Send response via SYSTEM chat (addon listens to CHAT_MSG_SYSTEM)
            std::ostringstream ss;
            ss << "DCUPGRADE_INIT:" << tokens << ":" << essence;
            SendAddonResponse(player, ss.str());
            return true;
        }

        // QUERY: Get item upgrade info
        else if (subcommand == "query")
        {
            std::string remainingArgs = spacePos != std::string::npos ? argStr.substr(spacePos + 1) : "";
            std::istringstream iss(remainingArgs);
            uint32 extBag, extSlot;

            if (!(iss >> extBag >> extSlot))
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Invalid parameters");
                return true;
            }

            uint8 bag = 0;
            uint8 slot = 0;
            if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Invalid item slot");
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Item not found");
                return true;
            }

            uint32 itemGUID = item->GetGUID().GetCounter();
            uint32 baseItemLevel = item->GetTemplate()->ItemLevel;

            QueryResult result = CharacterDatabase.Query(
                "SELECT upgrade_level, tier_id, stat_multiplier "
                "FROM {} WHERE item_guid = {}",
                ITEM_UPGRADES_TABLE, itemGUID
            );

            uint32 upgradeLevel = 0;
            uint32 tier = 1;
            uint16 storedBaseIlvl = baseItemLevel;
            uint16 upgradedIlvl = baseItemLevel;
            float statMultiplier = 1.0f;

            if (result)
            {
                Field* fields = result->Fetch();
                upgradeLevel = fields[0].Get<uint32>();
                // NOTE: Don't trust stored tier - recalculate it based on current item level
                // tier = fields[1].Get<uint32>();  // DISABLED - calculate instead
                
                // Get tier from database mapping instead of item level ranges
                if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
                    tier = mgr->GetItemTier(item->GetEntry());
                else
                    tier = 1; // fallback if manager not available
                
                // Note: base_item_level and upgraded_item_level are calculated in-memory, not stored
                // storedBaseIlvl remains baseItemLevel from template
                // upgradedIlvl will be calculated below

                // ALWAYS recalculate statMultiplier based on level and tier (don't trust database value)
                statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                    static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
            }
            else
            {
                // Get tier from database mapping instead of item level ranges
                if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
                    tier = mgr->GetItemTier(item->GetEntry());
                else
                    tier = 1; // fallback if manager not available

                storedBaseIlvl = baseItemLevel;
                upgradedIlvl = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                    storedBaseIlvl, static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
                statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                    static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
            }

            if (upgradedIlvl < storedBaseIlvl)
                upgradedIlvl = storedBaseIlvl;

            uint32 currentEntry = item->GetEntry();
            uint32 baseEntry = currentEntry;

            // Always check if current item is a clone (not just when upgradeLevel > 0)
            if (QueryResult baseResult = WorldDatabase.Query(
                    "SELECT base_item_id, upgrade_level FROM dc_item_upgrade_clones WHERE clone_item_id = {}",
                    currentEntry))
            {
                baseEntry = (*baseResult)[0].Get<uint32>();
                uint32 detectedLevel = (*baseResult)[1].Get<uint32>();
                
                // If no database record exists, use the detected level from clone mapping
                if (upgradeLevel == 0 && detectedLevel > 0)
                {
                    upgradeLevel = detectedLevel;
                    statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                        static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
                }
            }

            std::map<uint32, uint32> cloneEntries;
            cloneEntries[0] = baseEntry;

            if (QueryResult cloneResult = WorldDatabase.Query(
                    "SELECT upgrade_level, clone_item_id FROM dc_item_upgrade_clones WHERE base_item_id = {} AND tier_id = {}",
                    baseEntry, tier))
            {
                do
                {
                    Field* cloneFields = cloneResult->Fetch();
                    uint32 level = cloneFields[0].Get<uint32>();
                    uint32 entry = cloneFields[1].Get<uint32>();
                    cloneEntries[level] = entry;
                }
                while (cloneResult->NextRow());
            }

            cloneEntries[upgradeLevel] = currentEntry;

            std::ostringstream mapStream;
            bool firstPair = true;
            for (const auto& pair : cloneEntries)
            {
                if (firstPair)
                    firstPair = false;
                else
                    mapStream << ',';
                mapStream << pair.first << '-' << pair.second;
            }

            std::string cloneMap = mapStream.str();
            if (cloneMap.empty())
                cloneMap = "0-" + std::to_string(baseEntry);

            // Send response via SYSTEM chat (now includes upgraded ilvl, stat multiplier, and clone data)
            std::ostringstream ss;
            ss.setf(std::ios::fixed);
            ss << std::setprecision(3);
            ss << "DCUPGRADE_QUERY:" << itemGUID << ":" << upgradeLevel << ":" << tier << ":" << storedBaseIlvl
               << ":" << upgradedIlvl << ":" << statMultiplier << ':' << baseEntry << ':' << currentEntry
               << ':' << cloneMap;

            SendAddonResponse(player, ss.str());
            return true;
        }

        // BATCH: Handle multiple queries in one command
        else if (subcommand == "batch")
        {
            std::string remainingArgs = spacePos != std::string::npos ? argStr.substr(spacePos + 1) : "";
            if (remainingArgs.empty())
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:No batch data provided");
                return true;
            }

            // Parse batch format: "bag1:slot1 bag2:slot2 bag3:slot3 ..."
            std::istringstream iss(remainingArgs);
            std::string pair;
            std::vector<std::pair<uint32, uint32>> batchQueries;

            while (iss >> pair)
            {
                std::string::size_type colonPos = pair.find(':');
                if (colonPos == std::string::npos)
                    continue;

                uint32 extBag = std::stoul(pair.substr(0, colonPos));
                uint32 extSlot = std::stoul(pair.substr(colonPos + 1));

                uint8 bag = 0;
                uint8 slot = 0;
                if (TranslateAddonBagSlot(extBag, extSlot, bag, slot))
                {
                    batchQueries.emplace_back(bag, slot);
                }
            }

            if (batchQueries.empty())
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:No valid batch queries");
                return true;
            }

            // Process each query in the batch
            for (const auto& [bag, slot] : batchQueries)
            {
                Item* item = player->GetItemByPos(bag, slot);
                if (!item)
                    continue;

                uint32 itemGUID = item->GetGUID().GetCounter();
                uint32 baseItemLevel = item->GetTemplate()->ItemLevel;

                QueryResult result = CharacterDatabase.Query(
                    "SELECT upgrade_level, tier_id, stat_multiplier "
                    "FROM {} WHERE item_guid = {}",
                    ITEM_UPGRADES_TABLE, itemGUID
                );

                uint32 upgradeLevel = 0;
                uint32 tier = 1;
                uint16 storedBaseIlvl = baseItemLevel;
                uint16 upgradedIlvl = baseItemLevel;
                float statMultiplier = 1.0f;

                if (result)
                {
                    Field* fields = result->Fetch();
                    upgradeLevel = fields[0].Get<uint32>();
                    tier = fields[1].Get<uint32>();

                    statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                        static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
                }
                else
                {
                    // Get tier from database mapping instead of item level ranges
                    if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
                        tier = mgr->GetItemTier(item->GetEntry());
                    else
                        tier = 1; // fallback if manager not available

                    storedBaseIlvl = baseItemLevel;
                    upgradedIlvl = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                        storedBaseIlvl, static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
                    statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                        static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
                }

                if (upgradedIlvl < storedBaseIlvl)
                    upgradedIlvl = storedBaseIlvl;

                uint32 currentEntry = item->GetEntry();
                uint32 baseEntry = currentEntry;

                if (upgradeLevel > 0)
                {
                    if (QueryResult baseResult = WorldDatabase.Query(
                            "SELECT base_item_id FROM dc_item_upgrade_clones WHERE clone_item_id = {}",
                            currentEntry))
                    {
                        baseEntry = (*baseResult)[0].Get<uint32>();
                    }
                }

                std::map<uint32, uint32> cloneEntries;
                cloneEntries[0] = baseEntry;

                if (QueryResult cloneResult = WorldDatabase.Query(
                        "SELECT upgrade_level, clone_item_id FROM dc_item_upgrade_clones WHERE base_item_id = {} AND tier_id = {}",
                        baseEntry, tier))
                {
                    do
                    {
                        Field* cloneFields = cloneResult->Fetch();
                        uint32 level = cloneFields[0].Get<uint32>();
                        uint32 entry = cloneFields[1].Get<uint32>();
                        cloneEntries[level] = entry;
                    }
                    while (cloneResult->NextRow());
                }

                cloneEntries[upgradeLevel] = currentEntry;

                std::ostringstream mapStream;
                bool firstPair = true;
                for (const auto& pair : cloneEntries)
                {
                    if (firstPair)
                        firstPair = false;
                    else
                        mapStream << ',';
                    mapStream << pair.first << '-' << pair.second;
                }

                std::string cloneMap = mapStream.str();
                if (cloneMap.empty())
                    cloneMap = "0-" + std::to_string(baseEntry);

                // Send individual response for each item in batch (includes clone data)
                std::ostringstream ss;
                ss.setf(std::ios::fixed);
                ss << std::setprecision(3);
                ss << "DCUPGRADE_QUERY:" << itemGUID << ":" << upgradeLevel << ":" << tier << ":" << storedBaseIlvl
                   << ":" << upgradedIlvl << ":" << statMultiplier << ':' << baseEntry << ':' << currentEntry
                   << ':' << cloneMap;

                SendAddonResponse(player, ss.str());
            }

            return true;
        }
        else if (subcommand == "perform")
        {
            std::string remainingArgs = spacePos != std::string::npos ? argStr.substr(spacePos + 1) : "";
            std::istringstream iss(remainingArgs);
            uint32 extBag, extSlot, targetLevel;

            if (!(iss >> extBag >> extSlot >> targetLevel))
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Invalid parameters");
                return true;
            }

            uint8 bag = 0;
            uint8 slot = 0;
            if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Invalid item slot");
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Item not found");
                return true;
            }

            if (targetLevel > 15)
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Max level is 15");
                return true;
            }

            uint32 itemGUID = item->GetGUID().GetCounter();
            uint32 playerGuid = player->GetGUID().GetCounter();
            uint32 baseItemLevel = item->GetTemplate()->ItemLevel;
            std::string baseItemNameRaw = item->GetTemplate()->Name1;

            // Get current upgrade state
            QueryResult stateResult = CharacterDatabase.Query(
                "SELECT upgrade_level, tier_id FROM {} WHERE item_guid = {}",
                ITEM_UPGRADES_TABLE, itemGUID
            );

            uint32 currentLevel = 0;
            uint32 tier = 1;

            if (stateResult)
            {
                currentLevel = (*stateResult)[0].Get<uint32>();
                // NOTE: Don't trust stored tier - recalculate it based on current item level
                // tier = (*stateResult)[1].Get<uint32>();  // DISABLED - calculate instead
                
                // Get tier from database mapping instead of item level ranges
                if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
                    tier = mgr->GetItemTier(item->GetEntry());
                else
                    tier = 1; // fallback if manager not available
            }
            else
            {
                // Get tier from database mapping instead of item level ranges
                if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
                    tier = mgr->GetItemTier(item->GetEntry());
                else
                    tier = 1; // fallback if manager not available
            }

            if (targetLevel <= currentLevel)
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Must upgrade to higher level");
                return true;
            }

            // Determine aggregated upgrade cost for all levels between current and target
            if (targetLevel <= currentLevel)
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Target level must exceed current level");
                return true;
            }

            float oldStatMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                static_cast<uint8>(currentLevel), static_cast<uint8>(tier));
            uint16 oldIlvl = baseItemLevel;
            if (currentLevel > 0)
                oldIlvl = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                    baseItemLevel, static_cast<uint8>(currentLevel), static_cast<uint8>(tier));

            uint32 nextLevel = currentLevel + 1;
            QueryResult costResult = WorldDatabase.Query(
                "SELECT SUM(token_cost) AS total_tokens, SUM(essence_cost) AS total_essence "
                "FROM dc_item_upgrade_costs WHERE tier_id = {} AND upgrade_level BETWEEN {} AND {}",
                tier, nextLevel, targetLevel
            );

            uint32 tokensNeeded = 0;
            uint32 essenceNeeded = 0;

            if (!costResult)
            {
                std::ostringstream ss;
                ss << "DCUPGRADE_ERROR:Cost data missing for tier " << tier << " levels " << nextLevel << "-" << targetLevel;
                SendAddonResponse(player, ss.str());
                return true;
            }

            Field* costFields = costResult->Fetch();
            if (!costFields || (costFields[0].IsNull() && costFields[1].IsNull()))
            {
                std::ostringstream ss;
                ss << "DCUPGRADE_ERROR:No cost configured for tier " << tier << " levels " << nextLevel << "-" << targetLevel;
                SendAddonResponse(player, ss.str());
                return true;
            }

            if (!costFields[0].IsNull())
                tokensNeeded = costFields[0].Get<uint32>();
            if (!costFields[1].IsNull())
                essenceNeeded = costFields[1].Get<uint32>();

            // Check inventory for currency items (using item-based system)
            uint32 currentTokens = player->GetItemCount(tokenId);
            uint32 currentEssence = player->GetItemCount(essenceId);

            if (currentTokens < tokensNeeded)
            {
                std::ostringstream ss;
                ss << "DCUPGRADE_ERROR:Need " << tokensNeeded << " tokens, have " << currentTokens;
                SendAddonResponse(player, ss.str());
                return true;
            }

            if (currentEssence < essenceNeeded)
            {
                std::ostringstream ss;
                ss << "DCUPGRADE_ERROR:Need " << essenceNeeded << " essence, have " << currentEssence;
                SendAddonResponse(player, ss.str());
                return true;
            }

            // Deduct currency items from inventory
            if (tokensNeeded > 0)
                player->DestroyItemCount(tokenId, tokensNeeded, true);
            if (essenceNeeded > 0)
                player->DestroyItemCount(essenceId, essenceNeeded, true);

            // Determine base entry
            uint32 currentEntry = item->GetEntry();
            uint32 baseEntry = currentEntry;
            if (currentLevel > 0)
            {
                QueryResult baseResult = WorldDatabase.Query("SELECT base_item_id FROM dc_item_upgrade_clones WHERE clone_item_id = {}", currentEntry);
                if (baseResult)
                    baseEntry = (*baseResult)[0].Get<uint32>();
            }

            // Get clone entry for target level
            QueryResult cloneResult = WorldDatabase.Query("SELECT clone_item_id FROM dc_item_upgrade_clones WHERE base_item_id = {} AND tier_id = {} AND upgrade_level = {}", baseEntry, tier, targetLevel);
            if (!cloneResult)
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Clone item not found");
                return true;
            }
            uint32 cloneEntry = (*cloneResult)[0].Get<uint32>();

            // Replace item with clone
            player->DestroyItem(bag, slot, true);

            // Check if the original item was equipped
            bool wasEquipped = (bag == INVENTORY_SLOT_BAG_0 && slot <= EQUIPMENT_SLOT_TABARD);

            ItemPosCountVec dest;
            uint8 msg;

            if (wasEquipped)
            {
                // Try to place the upgraded item in the same equipment slot
                msg = player->CanStoreNewItem(INVENTORY_SLOT_BAG_0, slot, dest, cloneEntry, 1);
                if (msg != EQUIP_ERR_OK)
                {
                    // Cannot equip in same slot, try to find any equipment slot
                    msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, cloneEntry, 1);
                    if (msg != EQUIP_ERR_OK)
                    {
                        SendAddonResponse(player, "DCUPGRADE_ERROR:Cannot store upgraded item");
                        return true;
                    }
                }
            }
            else
            {
                // Item was in inventory, store upgraded version in inventory
                msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, cloneEntry, 1);
                if (msg != EQUIP_ERR_OK)
                {
                    SendAddonResponse(player, "DCUPGRADE_ERROR:Cannot store upgraded item");
                    return true;
                }
            }

            Item* newItem = player->StoreNewItem(dest, cloneEntry, true);
            if (!newItem)
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Failed to create upgraded item");
                return true;
            }
            uint32 newItemGUID = newItem->GetGUID().GetCounter();

            // Compute upgraded stats for persistence
            float statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                static_cast<uint8>(targetLevel), static_cast<uint8>(tier));
            uint16 newIlvl = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                baseItemLevel, static_cast<uint8>(targetLevel), static_cast<uint8>(tier));
            if (targetLevel == 0)
                newIlvl = baseItemLevel;

            uint64 now = static_cast<uint64>(std::time(nullptr));
            uint32 season = 1; // TODO: make configurable

            if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
            {
                DarkChaos::ItemUpgrade::ItemUpgradeState* state = mgr->GetItemUpgradeState(newItemGUID);
                if (state)
                {
                    state->player_guid = playerGuid;
                    state->item_guid = newItemGUID;
                    state->item_entry = cloneEntry;
                    state->base_item_name = baseItemNameRaw;
                    state->tier_id = static_cast<uint8>(tier);
                    state->upgrade_level = static_cast<uint8>(targetLevel);
                    state->tokens_invested += tokensNeeded;
                    state->essence_invested += essenceNeeded;
                    state->stat_multiplier = statMultiplier;
                    state->base_item_level = static_cast<uint16>(baseItemLevel);
                    state->upgraded_item_level = newIlvl;
                    if (state->first_upgraded_at == 0)
                        state->first_upgraded_at = static_cast<time_t>(now);
                    state->last_upgraded_at = static_cast<time_t>(now);
                    state->season = season;

                    mgr->SaveItemUpgrade(newItemGUID);
                }
            }

            CharacterDatabase.Execute(
                "INSERT INTO {} (player_guid, item_guid, item_id, upgrade_from, upgrade_to, essence_cost, token_cost, "
                "base_ilvl, old_ilvl, new_ilvl, old_stat_multiplier, new_stat_multiplier, timestamp, season_id) "
                "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {:.6f}, {:.6f}, {}, {})",
                ITEM_UPGRADE_LOG_TABLE,
                playerGuid, newItemGUID, cloneEntry,
                currentLevel, targetLevel, essenceNeeded, tokensNeeded,
                baseItemLevel, oldIlvl, newIlvl,
                static_cast<double>(oldStatMultiplier), static_cast<double>(statMultiplier),
                static_cast<uint32>(now), season
            );

            // Send success response via SYSTEM chat
            std::ostringstream successMsg;
            successMsg << "DCUPGRADE_SUCCESS:" << newItemGUID << ":" << targetLevel;
            SendAddonResponse(player, successMsg.str());

            return true;
        }

        return false;
    }
};

void AddSC_ItemUpgradeAddonHandler()
{
    try
    {
        new ItemUpgradeAddonCommands();
        LOG_INFO("scripts", "ItemUpgrade: Addon handler registered successfully");
    }
    catch (const std::exception& e)
    {
        LOG_ERROR("scripts", "ItemUpgrade: Exception registering addon handler: {}", e.what());
        // Don't throw - system can work without addon handler
    }
    catch (...)
    {
        LOG_ERROR("scripts", "ItemUpgrade: Unknown error registering addon handler");
        // Don't throw - system can work without addon handler
    }
}

// Legacy function name for backwards compatibility
void AddSC_ItemUpgradeCommands()
{
    AddSC_ItemUpgradeAddonHandler();
}
