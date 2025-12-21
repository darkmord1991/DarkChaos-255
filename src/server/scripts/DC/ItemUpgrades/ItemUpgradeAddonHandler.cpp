#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "ItemUpgradeMechanics.h"
#include "ItemUpgradeManager.h"
#include "ItemUpgradeSeasonResolver.h"
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

// Missing items log table
static constexpr const char* MISSING_ITEMS_TABLE = "dc_item_upgrade_missing_items";

// Log a missing/failed item to the database for analysis
static void LogMissingItem(Player* player, uint32 itemId, uint32 itemGuid,
                           const std::string& errorType, const std::string& errorDetail,
                           uint8 bag = 0, uint8 slot = 0)
{
    if (!player)
        return;

    // Get item name if template exists
    std::string itemName = "Unknown";
    if (ItemTemplate const* templ = sObjectMgr->GetItemTemplate(itemId))
        itemName = templ->Name1;

    // Escape strings for SQL
    std::string escapedName = itemName;
    std::string escapedDetail = errorDetail;

    // Replace single quotes with escaped quotes
    size_t pos = 0;
    while ((pos = escapedName.find("'", pos)) != std::string::npos) {
        escapedName.replace(pos, 1, "''");
        pos += 2;
    }
    pos = 0;
    while ((pos = escapedDetail.find("'", pos)) != std::string::npos) {
        escapedDetail.replace(pos, 1, "''");
        pos += 2;
    }

    CharacterDatabase.Execute(
        "INSERT INTO {} (player_guid, player_name, item_id, item_guid, item_name, "
        "error_type, error_detail, bag_slot, item_slot) "
        "VALUES ({}, '{}', {}, {}, '{}', '{}', '{}', {}, {})",
        MISSING_ITEMS_TABLE,
        player->GetGUID().GetCounter(),
        player->GetName(),
        itemId,
        itemGuid,
        escapedName,
        errorType,
        escapedDetail,
        bag,
        slot
    );

    LOG_DEBUG("scripts", "ItemUpgrade: Logged missing item {} ({}) for player {} - {} ({})",
        itemId, itemName, player->GetName(), errorType, errorDetail);
}

class ItemUpgradeAddonCommands : public CommandScript
{
public:
    ItemUpgradeAddonCommands() : CommandScript("ItemUpgradeAddonCommands") { }

    [[nodiscard]] std::vector<ChatCommandBuilder> GetCommands() const override
    {
        static const std::vector<ChatCommandBuilder> dcupgradeCommandTable =
        {
            ChatCommandBuilder("dcupgrade", HandleDCUpgradeCommand, 0, Console::No),
            ChatCommandBuilder("dcheirloom", HandleDCHeirloomCommand, 0, Console::No)
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

        // Check if system is enabled
        if (!sConfigMgr->GetOption<bool>("ItemUpgrade.Enable", true))
        {
            SendAddonResponse(player, "DCUPGRADE_ERROR:System disabled");
            return true;
        }

        // Get currency item IDs from config (support for canonical seasonal currency)
    uint32 essenceId = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();
    uint32 tokenId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();

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
            ss << "DCUPGRADE_INIT:" << tokens << ":" << essence << ":" << tokenId << ":" << essenceId;
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
                LogMissingItem(player, 0, 0, "SLOT_INVALID",
                    Acore::StringFormat("Query: Invalid slot translation extBag={}, extSlot={}", extBag, extSlot),
                    static_cast<uint8>(extBag), static_cast<uint8>(extSlot));
                SendAddonResponse(player, "DCUPGRADE_ERROR:Invalid item slot");
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                LogMissingItem(player, 0, 0, "ITEM_NOT_FOUND",
                    Acore::StringFormat("Query: No item at bag={}, slot={}", bag, slot),
                    bag, slot);
                SendAddonResponse(player, "DCUPGRADE_ERROR:Item not found");
                return true;
            }

            uint32 itemGUID = item->GetGUID().GetCounter();
            uint32 baseItemLevel = item->GetTemplate()->ItemLevel;
            uint32 currentEntry = item->GetEntry();
            uint32 baseEntry = currentEntry;

            // SPECIAL CASE: Heirloom Adventurer's Shirt (300365)
            // This item uses the heirloom stat package system, not the clone-based upgrade system
            constexpr uint32 HEIRLOOM_SHIRT_ENTRY = 300365;
            if (currentEntry == HEIRLOOM_SHIRT_ENTRY)
            {
                // Query heirloom upgrade state from dc_heirloom_upgrades table
                std::string heirloomSql = Acore::StringFormat(
                    "SELECT upgrade_level, package_id FROM dc_heirloom_upgrades WHERE item_guid = {}",
                    itemGUID
                );
                QueryResult heirloomResult = CharacterDatabase.Query(heirloomSql.c_str());

                uint32 upgradeLevel = 0;
                constexpr uint32 HEIRLOOM_MAX_LEVEL = 15;
                constexpr uint32 HEIRLOOM_TIER = 3;

                if (heirloomResult)
                {
                    Field* fields = heirloomResult->Fetch();
                    upgradeLevel = fields[0].Get<uint32>();
                    // packageId from fields[1] no longer used
                }

                float statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                    static_cast<uint8>(upgradeLevel), static_cast<uint8>(HEIRLOOM_TIER));

                // Build clone map with all 15 levels (heirloom doesn't use clones, but addon expects this format)
                std::ostringstream cloneMapStream;
                for (uint32 lvl = 0; lvl <= HEIRLOOM_MAX_LEVEL; ++lvl)
                {
                    if (lvl > 0)
                        cloneMapStream << ',';
                    cloneMapStream << lvl << '-' << HEIRLOOM_SHIRT_ENTRY;  // Same entry for all levels
                }

                // Send heirloom-specific response
                std::ostringstream ss;
                ss.setf(std::ios::fixed);
                ss << std::setprecision(3);
                ss << "DCUPGRADE_QUERY:" << itemGUID << ":" << upgradeLevel << ":" << HEIRLOOM_TIER
                   << ":" << baseItemLevel << ":" << baseItemLevel << ":" << statMultiplier
                   << ':' << HEIRLOOM_SHIRT_ENTRY << ':' << HEIRLOOM_SHIRT_ENTRY
                   << ':' << cloneMapStream.str();

                SendAddonResponse(player, ss.str());
                return true;
            }

            // NORMAL ITEMS: Check if current item is a clone - we need baseEntry for tier lookup
            std::string baseSql = Acore::StringFormat(
                    "SELECT base_item_id, upgrade_level FROM dc_item_upgrade_clones WHERE clone_item_id = {}",
                    currentEntry);
            uint32 cloneDetectedLevel = 0;
            if (QueryResult baseResult = WorldDatabase.Query(baseSql.c_str()))
            {
                baseEntry = (*baseResult)[0].Get<uint32>();
                cloneDetectedLevel = (*baseResult)[1].Get<uint32>();
            }

            std::string sql = Acore::StringFormat(
                "SELECT upgrade_level, tier_id, stat_multiplier "
                "FROM {} WHERE item_guid = {}",
                ITEM_UPGRADES_TABLE, itemGUID
            );
            QueryResult result = CharacterDatabase.Query(sql.c_str());

            uint32 upgradeLevel = 0;
            uint32 tier = 1;
            uint16 storedBaseIlvl = baseItemLevel;
            uint16 upgradedIlvl = baseItemLevel;
            float statMultiplier = 1.0f;

            // Get tier from database mapping using BASE ENTRY (not clone entry)
            if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
            {
                tier = mgr->GetItemTier(baseEntry);
                // Log if tier is invalid (item not in tier mapping and template not found)
                if (tier == 0)  // TIER_INVALID
                {
                    LogMissingItem(player, baseEntry, itemGUID, "TIER_INVALID",
                        Acore::StringFormat("Item not in tier mapping and template lookup failed. currentEntry={}", currentEntry),
                        bag, slot);
                    tier = 1;  // Default to leveling tier
                }
            }
            else
                tier = 1; // fallback if manager not available

            if (result)
            {
                Field* fields = result->Fetch();
                upgradeLevel = fields[0].Get<uint32>();
                // NOTE: Don't trust stored tier - we already calculated it above using baseEntry
                // tier = fields[1].Get<uint32>();  // DISABLED - calculated above

                // Note: base_item_level and upgraded_item_level are calculated in-memory, not stored
                // storedBaseIlvl remains baseItemLevel from template
                // upgradedIlvl will be calculated below

                // ALWAYS recalculate statMultiplier based on level and tier (don't trust database value)
                statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                    static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
            }
            else
            {
                // If no database record exists but clone mapping detected a level, use it
                if (cloneDetectedLevel > 0)
                    upgradeLevel = cloneDetectedLevel;

                storedBaseIlvl = baseItemLevel;
                upgradedIlvl = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                    storedBaseIlvl, static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
                statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                    static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
            }

            if (upgradedIlvl < storedBaseIlvl)
                upgradedIlvl = storedBaseIlvl;

            std::map<uint32, uint32> cloneEntries;
            cloneEntries[0] = baseEntry;

            std::string cloneSql = Acore::StringFormat(
                    "SELECT upgrade_level, clone_item_id FROM dc_item_upgrade_clones WHERE base_item_id = {} AND tier_id = {}",
                    baseEntry, tier);
            if (QueryResult cloneResult = WorldDatabase.Query(cloneSql.c_str()))
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
            else
            {
                // No clone entries found - log for analysis (item may need clone generation)
                LogMissingItem(player, baseEntry, itemGUID, "CLONE_MISSING",
                    Acore::StringFormat("No clone entries for base_item_id={} tier={}", baseEntry, tier),
                    bag, slot);
            }

            cloneEntries[upgradeLevel] = currentEntry;

            std::ostringstream mapStream;
            bool firstPair = true;
            for (auto const& pair : cloneEntries)
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
            for (auto const& [bag, slot] : batchQueries)
            {
                Item* item = player->GetItemByPos(bag, slot);
                if (!item)
                    continue;

                uint32 itemGUID = item->GetGUID().GetCounter();
                uint32 baseItemLevel = item->GetTemplate()->ItemLevel;
                uint32 currentEntry = item->GetEntry();
                uint32 baseEntry = currentEntry;

                // FIRST: Check if current item is a clone - we need baseEntry for tier lookup
                std::string baseSql = Acore::StringFormat(
                        "SELECT base_item_id, upgrade_level FROM dc_item_upgrade_clones WHERE clone_item_id = {}",
                        currentEntry);
                uint32 cloneDetectedLevel = 0;
                if (QueryResult baseResult = WorldDatabase.Query(baseSql.c_str()))
                {
                    baseEntry = (*baseResult)[0].Get<uint32>();
                    cloneDetectedLevel = (*baseResult)[1].Get<uint32>();
                }

                std::string sql = Acore::StringFormat(
                    "SELECT upgrade_level, tier_id, stat_multiplier "
                    "FROM {} WHERE item_guid = {}",
                    ITEM_UPGRADES_TABLE, itemGUID
                );
                QueryResult result = CharacterDatabase.Query(sql.c_str());

                uint32 upgradeLevel = 0;
                uint32 tier = 1;
                uint16 storedBaseIlvl = baseItemLevel;
                uint16 upgradedIlvl = baseItemLevel;
                float statMultiplier = 1.0f;

                // Get tier from database mapping using BASE ENTRY (not clone entry)
                if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
                    tier = mgr->GetItemTier(baseEntry);
                else
                    tier = 1; // fallback if manager not available

                if (result)
                {
                    Field* fields = result->Fetch();
                    upgradeLevel = fields[0].Get<uint32>();
                    // NOTE: tier already calculated above using baseEntry

                    statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                        static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
                }
                else
                {
                    // If no database record exists but clone mapping detected a level, use it
                    if (cloneDetectedLevel > 0)
                        upgradeLevel = cloneDetectedLevel;

                    storedBaseIlvl = baseItemLevel;
                    upgradedIlvl = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                        storedBaseIlvl, static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
                    statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                        static_cast<uint8>(upgradeLevel), static_cast<uint8>(tier));
                }

                if (upgradedIlvl < storedBaseIlvl)
                    upgradedIlvl = storedBaseIlvl;

                std::map<uint32, uint32> cloneEntries;
                cloneEntries[0] = baseEntry;

                std::string cloneSql = Acore::StringFormat(
                        "SELECT upgrade_level, clone_item_id FROM dc_item_upgrade_clones WHERE base_item_id = {} AND tier_id = {}",
                        baseEntry, tier);
                if (QueryResult cloneResult = WorldDatabase.Query(cloneSql.c_str()))
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
                for (auto const& pair : cloneEntries)
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
                LogMissingItem(player, 0, 0, "SLOT_INVALID",
                    Acore::StringFormat("Perform: Invalid slot translation extBag={}, extSlot={}", extBag, extSlot),
                    static_cast<uint8>(extBag), static_cast<uint8>(extSlot));
                SendAddonResponse(player, "DCUPGRADE_ERROR:Invalid item slot");
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                LogMissingItem(player, 0, 0, "ITEM_NOT_FOUND",
                    Acore::StringFormat("Perform: No item at bag={}, slot={}", bag, slot),
                    bag, slot);
                SendAddonResponse(player, "DCUPGRADE_ERROR:Item not found");
                return true;
            }

            uint32 itemGUID = item->GetGUID().GetCounter();
            uint32 playerGuid = player->GetGUID().GetCounter();
            uint32 baseItemLevel = item->GetTemplate()->ItemLevel;
            std::string baseItemNameRaw = item->GetTemplate()->Name1;

            // FIRST: Determine base entry - we need it for tier lookup
            uint32 currentEntry = item->GetEntry();
            uint32 baseEntry = currentEntry;

            std::string baseLookupSql = Acore::StringFormat(
                "SELECT base_item_id FROM dc_item_upgrade_clones WHERE clone_item_id = {}",
                currentEntry);
            if (QueryResult baseResult = WorldDatabase.Query(baseLookupSql.c_str()))
                baseEntry = (*baseResult)[0].Get<uint32>();

            // Get current upgrade state
            std::string stateSql = Acore::StringFormat(
                "SELECT upgrade_level, tier_id FROM {} WHERE item_guid = {}",
                ITEM_UPGRADES_TABLE, itemGUID
            );
            QueryResult stateResult = CharacterDatabase.Query(stateSql.c_str());

            uint32 currentLevel = 0;
            uint32 tier = 1;

            uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();

            // Get tier from database mapping using BASE ENTRY (not clone entry)
            if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
                tier = mgr->GetItemTier(baseEntry);
            else
                tier = 1; // fallback if manager not available

            if (stateResult)
            {
                currentLevel = (*stateResult)[0].Get<uint32>();
                // NOTE: tier already calculated above using baseEntry
            }

            // Check tier-specific max level from database
            uint32 tierMaxLevel = 15; // default fallback
            std::string tierSql = Acore::StringFormat(
                "SELECT max_upgrade_level FROM dc_item_upgrade_tiers WHERE tier_id = {} AND season = {}",
                tier, season
            );
            QueryResult tierResult = WorldDatabase.Query(tierSql.c_str());
            if (tierResult)
            {
                tierMaxLevel = (*tierResult)[0].Get<uint32>();
            }

            if (targetLevel > tierMaxLevel)
            {
                std::ostringstream ss;
                ss << "DCUPGRADE_ERROR:Max level for this tier is " << tierMaxLevel;
                SendAddonResponse(player, ss.str());
                return true;
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
            std::string costSql = Acore::StringFormat(
                "SELECT SUM(token_cost) AS total_tokens, SUM(essence_cost) AS total_essence "
                "FROM dc_item_upgrade_costs WHERE tier_id = {} AND season = {} AND upgrade_level BETWEEN {} AND {}",
                tier, season, nextLevel, targetLevel
            );
            QueryResult costResult = WorldDatabase.Query(costSql.c_str());

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

            // Only check essence if it's actually needed (essence cost > 0)
            if (essenceNeeded > 0 && currentEssence < essenceNeeded)
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

            // baseEntry was already determined at the start of the perform handler

            // Get clone entry for target level
            std::string cloneSql = Acore::StringFormat("SELECT clone_item_id FROM dc_item_upgrade_clones WHERE base_item_id = {} AND tier_id = {} AND upgrade_level = {}", baseEntry, tier, targetLevel);
            QueryResult cloneResult = WorldDatabase.Query(cloneSql.c_str());
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

            std::string logSql = Acore::StringFormat(
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
            CharacterDatabase.Execute(logSql.c_str());

            // Send success response via SYSTEM chat
            std::ostringstream successMsg;
            successMsg << "DCUPGRADE_SUCCESS:" << newItemGUID << ":" << targetLevel;
            SendAddonResponse(player, successMsg.str());

            return true;
        }

        return false;
    }

    /*
     * HandleDCHeirloomCommand - Heirloom Stat Package Upgrade Handler
     *
     * This handler manages heirloom-specific upgrades that apply stat packages
     * to item 300365 (Heirloom Adventurer's Shirt).
     *
     * Subcommands:
     * - query <bag> <slot>: Get current heirloom upgrade state and available packages
     * - upgrade <bag> <slot> <level> <packageId>: Apply stat package enchantment
     * - packages: List all available stat packages
     *
     * Enchantment ID Formula: 900000 + (packageId * 100) + level
     * Example: Package 1 (Fury) Level 15 = 900000 + (1 * 100) + 15 = 900115
     *
     * Date: 2025
     */
    static bool HandleDCHeirloomCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Check if system is enabled
        if (!sConfigMgr->GetOption<bool>("ItemUpgrade.Enable", true))
        {
            SendAddonResponse(player, "DCHEIRLOOM_ERROR:System disabled");
            return true;
        }

        // Constants for heirloom upgrades
        constexpr uint32 HEIRLOOM_SHIRT_ENTRY = 300365;
        constexpr uint32 MAX_PACKAGE_ID = 12;
        constexpr uint32 MAX_UPGRADE_LEVEL = 15;
        constexpr uint32 ENCHANT_BASE_ID = 900000;

        // Parse arguments
        std::string argStr = args ? args : "";
        std::string::size_type spacePos = argStr.find(' ');
        std::string subcommand = spacePos != std::string::npos ? argStr.substr(0, spacePos) : argStr;

        if (subcommand.empty())
        {
            SendAddonResponse(player, "DCHEIRLOOM_ERROR:No command specified");
            return true;
        }

        auto TranslateAddonBagSlot = [](uint32 extBag, uint32 extSlot, uint8& bagOut, uint8& slotOut) -> bool
        {
            if (extSlot > std::numeric_limits<uint8>::max())
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
        };

        // PACKAGES: List all available stat packages
        if (subcommand == "packages")
        {
            // Send package list to addon
            // Format: DCHEIRLOOM_PACKAGES:count:id1|name1|stats1:id2|name2|stats2:...
            std::ostringstream ss;
            ss << "DCHEIRLOOM_PACKAGES:12";
            ss << ":1|Fury|Crit,Haste";
            ss << ":2|Precision|Hit,Expertise";
            ss << ":3|Devastation|Crit,ArmorPen";
            ss << ":4|Swiftblade|Haste,ArmorPen";
            ss << ":5|Spellfire|Crit,Haste,SpellPower";
            ss << ":6|Arcane|Hit,Haste,SpellPower";
            ss << ":7|Bulwark|Dodge,Parry,Block";
            ss << ":8|Fortress|Defense,Block,Stamina";
            ss << ":9|Survivor|Dodge,Stamina";
            ss << ":10|Gladiator|Resilience,Crit";
            ss << ":11|Warlord|Resilience,Stamina";
            ss << ":12|Balanced|Crit,Hit,Haste";
            SendAddonResponse(player, ss.str());
            return true;
        }

        // QUERY: Get heirloom item state and current package
        else if (subcommand == "query")
        {
            std::string remainingArgs = spacePos != std::string::npos ? argStr.substr(spacePos + 1) : "";
            std::istringstream iss(remainingArgs);
            uint32 extBag, extSlot;

            if (!(iss >> extBag >> extSlot))
            {
                SendAddonResponse(player, "DCHEIRLOOM_ERROR:Invalid parameters");
                return true;
            }

            uint8 bag = 0;
            uint8 slot = 0;
            if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
            {
                LogMissingItem(player, 0, 0, "SLOT_INVALID",
                    Acore::StringFormat("Heirloom Query: Invalid slot extBag={}, extSlot={}", extBag, extSlot),
                    static_cast<uint8>(extBag), static_cast<uint8>(extSlot));
                SendAddonResponse(player, "DCHEIRLOOM_ERROR:Invalid item slot");
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                LogMissingItem(player, 0, 0, "ITEM_NOT_FOUND",
                    Acore::StringFormat("Heirloom Query: No item bag={}, slot={}", bag, slot),
                    bag, slot);
                SendAddonResponse(player, "DCHEIRLOOM_ERROR:Item not found");
                return true;
            }

            // Verify it's the heirloom shirt
            if (item->GetEntry() != HEIRLOOM_SHIRT_ENTRY)
            {
                SendAddonResponse(player, "DCHEIRLOOM_ERROR:Not a valid heirloom item");
                return true;
            }

            uint32 itemGUID = item->GetGUID().GetCounter();

            // Query current state from database
            std::string sql = Acore::StringFormat(
                "SELECT upgrade_level, package_id FROM dc_heirloom_upgrades WHERE item_guid = {}",
                itemGUID
            );
            QueryResult result = CharacterDatabase.Query(sql.c_str());

            uint32 currentLevel = 0;
            uint32 currentPackageId = 0;

            if (result)
            {
                Field* fields = result->Fetch();
                currentLevel = fields[0].Get<uint32>();
                currentPackageId = fields[1].Get<uint32>();
            }

            // Response format: DCHEIRLOOM_QUERY:itemGUID:level:packageId:maxLevel:maxPackages
            std::ostringstream ss;
            ss << "DCHEIRLOOM_QUERY:" << itemGUID << ":" << currentLevel << ":" << currentPackageId
               << ":" << MAX_UPGRADE_LEVEL << ":" << MAX_PACKAGE_ID;
            SendAddonResponse(player, ss.str());
            return true;
        }

        // UPGRADE: Apply stat package to heirloom item
        else if (subcommand == "upgrade")
        {
            std::string remainingArgs = spacePos != std::string::npos ? argStr.substr(spacePos + 1) : "";
            std::istringstream iss(remainingArgs);
            uint32 extBag, extSlot, targetLevel, packageId;

            if (!(iss >> extBag >> extSlot >> targetLevel >> packageId))
            {
                SendAddonResponse(player, "DCHEIRLOOM_ERROR:Invalid parameters (usage: upgrade bag slot level packageId)");
                return true;
            }

            // Validate package ID
            if (packageId < 1 || packageId > MAX_PACKAGE_ID)
            {
                std::ostringstream ss;
                ss << "DCHEIRLOOM_ERROR:Invalid package ID (must be 1-" << MAX_PACKAGE_ID << ")";
                SendAddonResponse(player, ss.str());
                return true;
            }

            // Validate target level
            if (targetLevel < 1 || targetLevel > MAX_UPGRADE_LEVEL)
            {
                std::ostringstream ss;
                ss << "DCHEIRLOOM_ERROR:Invalid level (must be 1-" << MAX_UPGRADE_LEVEL << ")";
                SendAddonResponse(player, ss.str());
                return true;
            }

            uint8 bag = 0;
            uint8 slot = 0;
            if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
            {
                LogMissingItem(player, 0, 0, "SLOT_INVALID",
                    Acore::StringFormat("Heirloom Upgrade: Invalid slot extBag={}, extSlot={}", extBag, extSlot),
                    static_cast<uint8>(extBag), static_cast<uint8>(extSlot));
                SendAddonResponse(player, "DCHEIRLOOM_ERROR:Invalid item slot");
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                LogMissingItem(player, 0, 0, "ITEM_NOT_FOUND",
                    Acore::StringFormat("Heirloom Upgrade: No item bag={}, slot={}", bag, slot),
                    bag, slot);
                SendAddonResponse(player, "DCHEIRLOOM_ERROR:Item not found");
                return true;
            }

            // Verify it's the heirloom shirt
            if (item->GetEntry() != HEIRLOOM_SHIRT_ENTRY)
            {
                SendAddonResponse(player, "DCHEIRLOOM_ERROR:Not a valid heirloom item");
                return true;
            }

            uint32 itemGUID = item->GetGUID().GetCounter();
            uint32 playerGuid = player->GetGUID().GetCounter();

            // Get current state
            std::string stateSql = Acore::StringFormat(
                "SELECT upgrade_level, package_id FROM dc_heirloom_upgrades WHERE item_guid = {}",
                itemGUID
            );
            QueryResult stateResult = CharacterDatabase.Query(stateSql.c_str());

            uint32 currentLevel = 0;
            uint32 currentPackageId = 0;

            if (stateResult)
            {
                Field* fields = stateResult->Fetch();
                currentLevel = fields[0].Get<uint32>();
                currentPackageId = fields[1].Get<uint32>();

                // Check if already at target level with same package
                if (currentLevel == targetLevel && currentPackageId == packageId)
                {
                    SendAddonResponse(player, "DCHEIRLOOM_ERROR:Already at this level with this package");
                    return true;
                }

                // If package is different and level > 0, that's a package change
                if (currentPackageId != 0 && currentPackageId != packageId && currentLevel > 0)
                {
                    // Allow package change - will apply new enchantment
                    LOG_INFO("scripts", "DCHeirloom: Player {} changing package from {} to {} on item {}",
                        player->GetName(), currentPackageId, packageId, itemGUID);
                }
            }

            // Calculate upgrade cost from database
            std::string costSql = Acore::StringFormat(
                "SELECT SUM(token_cost), SUM(essence_cost) FROM dc_heirloom_upgrade_costs WHERE upgrade_level BETWEEN {} AND {}",
                currentLevel + 1, targetLevel
            );
            QueryResult costResult = WorldDatabase.Query(costSql.c_str());

            uint32 tokensNeeded = 0;
            uint32 essenceNeeded = 0;

            if (costResult)
            {
                Field* costFields = costResult->Fetch();
                if (!costFields[0].IsNull())
                    tokensNeeded = costFields[0].Get<uint32>();
                if (!costFields[1].IsNull())
                    essenceNeeded = costFields[1].Get<uint32>();
            }

            // Get currency item IDs from config (support for canonical seasonal currency)
            uint32 tokenId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
            uint32 essenceId = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();

            // Check if player has enough currency
            uint32 currentTokens = player->GetItemCount(tokenId);
            uint32 currentEssence = player->GetItemCount(essenceId);

            if (currentTokens < tokensNeeded)
            {
                std::ostringstream ss;
                ss << "DCHEIRLOOM_ERROR:Need " << tokensNeeded << " tokens, have " << currentTokens;
                SendAddonResponse(player, ss.str());
                return true;
            }

            if (essenceNeeded > 0 && currentEssence < essenceNeeded)
            {
                std::ostringstream ss;
                ss << "DCHEIRLOOM_ERROR:Need " << essenceNeeded << " essence, have " << currentEssence;
                SendAddonResponse(player, ss.str());
                return true;
            }

            // Deduct currency
            if (tokensNeeded > 0)
                player->DestroyItemCount(tokenId, tokensNeeded, true);
            if (essenceNeeded > 0)
                player->DestroyItemCount(essenceId, essenceNeeded, true);

            // Calculate enchantment ID: 900000 + (packageId * 100) + level
            uint32 enchantId = ENCHANT_BASE_ID + (packageId * 100) + targetLevel;

            // Apply enchantment to item (using PERM_ENCHANTMENT_SLOT)
            // IMPORTANT: Setting the enchant field alone does NOT apply stats if the item is already equipped.
            // Mirror Spell::EffectEnchantItem behavior: remove old enchant effects, set, then apply new.
            player->ApplyEnchantment(item, PERM_ENCHANTMENT_SLOT, false);
            item->SetEnchantment(PERM_ENCHANTMENT_SLOT, enchantId, 0, 0, player->GetGUID());

            // Debug Logging for Enchant Stats
            if (SpellItemEnchantmentEntry const* enchant = sSpellItemEnchantmentStore.LookupEntry(enchantId))
            {
                LOG_INFO("scripts", "ItemUpgrade: Applying Enchant ID {} to Item {}. Stats: [{}, {}], [{}, {}], [{}, {}]",
                    enchantId, item->GetEntry(),
                    enchant->type[0], enchant->amount[0],
                    enchant->type[1], enchant->amount[1],
                    enchant->type[2], enchant->amount[2]);
            }
            else
            {
                LOG_ERROR("scripts", "ItemUpgrade: Enchant ID {} NOT FOUND in DBC!", enchantId);
            }

            player->ApplyEnchantment(item, PERM_ENCHANTMENT_SLOT, true);

            // Nudge a recalculation so changes are reflected immediately.
            player->UpdateAllStats();
            player->UpdateAllRatings();

            // Mark item as changed and save
            item->SetState(ITEM_CHANGED, player);

            // Update database
            uint64 now = static_cast<uint64>(std::time(nullptr));

            if (stateResult)
            {
                // Update existing record
                std::string updateSql = Acore::StringFormat(
                    "UPDATE dc_heirloom_upgrades SET upgrade_level = {}, package_id = {}, enchant_id = {}, "
                    "last_upgraded_at = FROM_UNIXTIME({}) WHERE item_guid = {}",
                    targetLevel, packageId, enchantId, now, itemGUID
                );
                CharacterDatabase.Execute(updateSql.c_str());
            }
            else
            {
                // Insert new record
                std::string insertSql = Acore::StringFormat(
                    "INSERT INTO dc_heirloom_upgrades (player_guid, item_guid, item_entry, upgrade_level, package_id, "
                    "enchant_id, first_upgraded_at, last_upgraded_at) VALUES ({}, {}, {}, {}, {}, {}, FROM_UNIXTIME({}), FROM_UNIXTIME({}))",
                    playerGuid, itemGUID, HEIRLOOM_SHIRT_ENTRY, targetLevel, packageId, enchantId, now, now
                );
                CharacterDatabase.Execute(insertSql.c_str());
            }

            // Log the upgrade
            std::string logSql = Acore::StringFormat(
                "INSERT INTO dc_heirloom_upgrade_log (player_guid, item_guid, item_entry, from_level, to_level, "
                "from_package, to_package, enchant_id, token_cost, essence_cost, timestamp) "
                "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, FROM_UNIXTIME({}))",
                playerGuid, itemGUID, HEIRLOOM_SHIRT_ENTRY, currentLevel, targetLevel,
                currentPackageId, packageId, enchantId, tokensNeeded, essenceNeeded, now
            );
            CharacterDatabase.Execute(logSql.c_str());

            LOG_INFO("scripts", "DCHeirloom: Player {} upgraded heirloom {} to level {} with package {} (enchant {})",
                player->GetName(), itemGUID, targetLevel, packageId, enchantId);

            // Send success response
            std::ostringstream successMsg;
            successMsg << "DCHEIRLOOM_SUCCESS:" << itemGUID << ":" << targetLevel << ":" << packageId << ":" << enchantId;
            SendAddonResponse(player, successMsg.str());

            return true;
        }

        SendAddonResponse(player, "DCHEIRLOOM_ERROR:Unknown subcommand");
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
