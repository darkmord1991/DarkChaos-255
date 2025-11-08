#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "ItemUpgradeMechanics.h"
#include <ctime>
#include <iomanip>
#include <sstream>
#include <limits>
#include "SharedDefines.h"

/*
 * DarkChaos Item Upgrade System - Addon Communication Handler
 *
 * This file handles communication between the client addon and server.
 * Commands: .dcupgrade (init/query/upgrade/inventory)
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
                "FROM dc_player_item_upgrades WHERE item_guid = {}",
                itemGUID
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
                // Note: base_item_level and upgraded_item_level are calculated in-memory, not stored
                // storedBaseIlvl remains baseItemLevel from template
                // upgradedIlvl will be calculated below
                
                // ALWAYS recalculate statMultiplier based on level and tier (don't trust database value)
                statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                    static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
            }
            else
            {
                // Calculate tier based on item level
                if (baseItemLevel >= 450) tier = 5;
                else if (baseItemLevel >= 400) tier = 4;
                else if (baseItemLevel >= 350) tier = 3;
                else if (baseItemLevel >= 300) tier = 2;
                else tier = 1;

                storedBaseIlvl = baseItemLevel;
                upgradedIlvl = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                    storedBaseIlvl, static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
                statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                    static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
            }

            if (upgradedIlvl < storedBaseIlvl)
                upgradedIlvl = storedBaseIlvl;

            // Send response via SYSTEM chat (now includes upgraded ilvl and stat multiplier)
            std::ostringstream ss;
            ss.setf(std::ios::fixed);
            ss << std::setprecision(3);
            ss << "DCUPGRADE_QUERY:" << itemGUID << ":" << upgradeLevel << ":" << tier << ":" << storedBaseIlvl
               << ":" << upgradedIlvl << ":" << statMultiplier;
            
            SendAddonResponse(player, ss.str());
            return true;
        }

        // PERFORM: Perform upgrade
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
            std::string baseItemName = item->GetTemplate()->Name1;

            // Get current upgrade state
            QueryResult stateResult = CharacterDatabase.Query(
                "SELECT upgrade_level, tier_id FROM dc_player_item_upgrades WHERE item_guid = {}",
                itemGUID
            );

            uint32 currentLevel = 0;
            uint32 tier = 1;

            if (stateResult)
            {
                currentLevel = (*stateResult)[0].Get<uint32>();
                tier = (*stateResult)[1].Get<uint32>();
            }
            else
            {
                if (baseItemLevel >= 450) tier = 5;
                else if (baseItemLevel >= 400) tier = 4;
                else if (baseItemLevel >= 350) tier = 3;
                else if (baseItemLevel >= 300) tier = 2;
                else tier = 1;
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

            // Compute upgraded stats for persistence
            uint16 upgradedItemLevel = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                static_cast<uint16>(baseItemLevel), static_cast<uint8>(targetLevel), static_cast<uint8>(tier));
            float statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                static_cast<uint8>(targetLevel), static_cast<uint8>(tier));

            uint32 now = static_cast<uint32>(std::time(nullptr));
            uint32 season = 1; // TODO: make configurable

            // Update item state (include all non-nullable columns)
            CharacterDatabase.Execute(
                "INSERT INTO dc_player_item_upgrades "
                "(item_guid, player_guid, base_item_name, tier_id, upgrade_level, tokens_invested, essence_invested, "
                "stat_multiplier, first_upgraded_at, last_upgraded_at, season) "
                "VALUES ({}, {}, '{}', {}, {}, {}, {}, {}, {}, {}, {}) "
                "ON DUPLICATE KEY UPDATE "
                " upgrade_level = VALUES(upgrade_level),"
                " tier_id = VALUES(tier_id),"
                " tokens_invested = tokens_invested + VALUES(tokens_invested),"
                " essence_invested = essence_invested + VALUES(essence_invested),"
                " stat_multiplier = VALUES(stat_multiplier),"
                " last_upgraded_at = {}",
                itemGUID, playerGuid, baseItemName, tier, targetLevel, tokensNeeded, essenceNeeded,
                statMultiplier, static_cast<uint32>(now), static_cast<uint32>(now), season, static_cast<uint32>(now)
            );

            // Send success response via SYSTEM chat
            std::ostringstream successMsg;
            successMsg << "DCUPGRADE_SUCCESS:" << itemGUID << ":" << targetLevel;
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
