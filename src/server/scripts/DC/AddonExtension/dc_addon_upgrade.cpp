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
#include "DC/CrossSystem/SeasonResolver.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "Chat.h"
#include "Spell.h"
#include "SpellMgr.h"
#include "ObjectMgr.h"
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

    namespace
    {
        enum UpgradeErrorCode : uint32
        {
            UPGRADE_ERR_NONE = 0,
            UPGRADE_ERR_ITEM_NOT_FOUND = 1,
            UPGRADE_ERR_MAX_LEVEL = 2,
            UPGRADE_ERR_NOT_ENOUGH_TOKENS = 3,
            UPGRADE_ERR_NOT_ENOUGH_ESSENCE = 4,
            UPGRADE_ERR_NOT_UPGRADEABLE = 5,
            UPGRADE_ERR_IN_COMBAT = 6
        };

        inline bool TryGetJsonUInt(const ParsedMessage& msg, const char* key, uint32& out)
        {
            if (!IsJsonMessage(msg))
                return false;

            JsonValue data = GetJsonData(msg);
            if (!data.IsObject() || !data.HasKey(key))
                return false;

            const JsonValue& val = data[key];
            if (!val.IsNumber())
                return false;

            out = val.AsUInt32();
            return true;
        }

        inline void CacheContext(Player* player)
        {
            if (player)
                DarkChaos::ItemUpgrade::CachePlayerMapContext(player);
        }

        inline void AuditUpgradeUiTransport(Player* player)
        {
            if (!player)
                return;

            SessionCapabilityState capabilityState;
            if (!TryGetSessionCapabilityState(player, capabilityState))
                return;

            TransportPolicyRequest request;
            request.featureName = "item-upgrade-ui";
            request.forceAddon = true;
            request.forceAddonReason = "addon-ui-request";
            ResolveTransportPolicy(player, request);
        }

        inline void SendUpgradeResult(Player* player, const std::string& requestId, bool success,
            uint32 itemGuid, uint32 newLevel, uint32 /*legacyEntry*/, uint32 errorCode,
            const std::string& errorMsg, uint32 tier = 0, uint32 maxUpgrade = 0,
            uint32 tokenCost = 0, uint32 essenceCost = 0, uint32 serverBag = 0,
            uint32 serverSlot = 0)
        {
            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADE_RESULT)
                .SetRequestId(requestId)
                .Set("success", success)
                .Set("itemId", itemGuid)
                .Set("newLevel", newLevel)
                .Set("errorCode", errorCode)
                .Set("errorMsg", errorMsg)
                .Set("tier", tier)
                .Set("maxUpgrade", maxUpgrade)
                .Set("tokenCost", tokenCost)
                .Set("essenceCost", essenceCost)
                .Set("serverBag", serverBag)
                .Set("serverSlot", serverSlot)
                .Send(player);
        }
    }

    // Send currency update to client
    // Uses unified GetPlayerTokens/GetPlayerEssence which read physical item counts
    void SendCurrencyUpdate(Player* player)
    {
        if (!player)
            return;

        CacheContext(player);
        // Use DB-backed currency (single source of truth)
        uint32 tokens = 0;
        uint32 essence = 0;
        if (auto* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
        {
            uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();
            uint32 playerGuid = player->GetGUID().GetCounter();
            tokens = mgr->GetCurrency(playerGuid, DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN, season);
            essence = mgr->GetCurrency(playerGuid, DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE, season);
        }
        uint32 tokenId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
        uint32 essenceId = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();

        JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_CURRENCY_UPDATE)
            .Set("tokens", static_cast<uint32>(tokens))
            .Set("essence", static_cast<uint32>(essence))
            .Set("tokenId", static_cast<uint32>(tokenId))
            .Set("essenceId", static_cast<uint32>(essenceId))
            .Send(player);
    }

    void SendTierConfig(Player* player, std::string const& requestId = std::string())
    {
        if (!player)
            return;

        CacheContext(player);

        DarkChaos::ItemUpgrade::UpgradeManager* mgr =
            DarkChaos::ItemUpgrade::GetUpgradeManager();

        JsonValue tiers;
        tiers.SetArray(static_cast<size_t>(DarkChaos::ItemUpgrade::NUM_TIERS));

        uint32 revision = 2166136261u;
        auto mixRevision = [&](uint32 value)
        {
            revision ^= value;
            revision *= 16777619u;
        };

        uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();

        if (mgr)
        {
            for (uint8 tierId = 1; tierId <= DarkChaos::ItemUpgrade::NUM_TIERS; ++tierId)
            {
                DarkChaos::ItemUpgrade::TierDefinition const* def =
                    mgr->GetTierDefinition(tierId);
                if (!def)
                    continue;

                uint32 upgradeCostPerLevel = mgr->GetUpgradeCost(
                    tierId, 1);
                if (upgradeCostPerLevel == 0)
                    upgradeCostPerLevel = mgr->GetEssenceCost(tierId, 1);

                JsonValue row;
                row.SetObject();
                row.Set("tierId", JsonValue(static_cast<uint32>(tierId)));
                row.Set("season", JsonValue(season));
                row.Set("sortOrder", JsonValue(static_cast<uint32>(tierId) * 10u));
                row.Set("flags", JsonValue(0u));
                row.Set("minItemLevel", JsonValue(static_cast<uint32>(def->min_ilvl)));
                row.Set("maxItemLevel", JsonValue(static_cast<uint32>(def->max_ilvl)));
                row.Set("maxUpgradeLevel", JsonValue(static_cast<uint32>(def->max_upgrade_level)));
                row.Set("statMultiplierMax", JsonValue(static_cast<double>(def->stat_multiplier_max)));
                row.Set("upgradeCostPerLevel", JsonValue(upgradeCostPerLevel));
                row.Set("isArtifact", JsonValue(def->is_artifact));
                row.Set("enabled", JsonValue(1u));
                tiers.Push(std::move(row));

                mixRevision(static_cast<uint32>(tierId));
                mixRevision(static_cast<uint32>(def->max_upgrade_level));
                mixRevision(static_cast<uint32>(def->min_ilvl));
                mixRevision(static_cast<uint32>(def->max_ilvl));
                mixRevision(static_cast<uint32>(
                    (def->stat_multiplier_max * 10000.0f) + 0.5f));
            }
        }

        JsonMessage response(Module::UPGRADE, Opcode::Upgrade::SMSG_TIER_CONFIG);
        if (!requestId.empty())
            response.SetRequestId(requestId);

        response
            .Set("source", "server")
            .Set("revision", revision)
            .Set("tiers", std::move(tiers))
            .Send(player);
    }

    static void HandleGetTierConfig(Player* player, const ParsedMessage& msg)
    {
        AuditUpgradeUiTransport(player);
        CacheContext(player);
        SendTierConfig(player, msg.GetRequestId());
    }

    // Handler: Get item upgrade info
    static void HandleGetItemInfo(Player* player, const ParsedMessage& msg)
    {
        AuditUpgradeUiTransport(player);
        CacheContext(player);
        uint32 extBag = 0;
        uint32 extSlot = 0;

        if (!TryGetJsonUInt(msg, "bag", extBag))
        {
            extBag = msg.GetUInt32(0);
        }
        if (!TryGetJsonUInt(msg, "slot", extSlot))
        {
            extSlot = msg.GetUInt32(1);
        }

        uint8 bag = 0, slot = 0;
        if (!DarkChaos::ItemUpgrade::UI::TranslateAddonBagSlot(extBag, extSlot, bag, slot))
        {
            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_ITEM_INFO)
                .SetRequestId(msg.GetRequestId())
                .Set("success", false)
                .Set("serverBag", extBag)
                .Set("serverSlot", extSlot)
                .Set("errorMsg", "Invalid slot")
                .Send(player);
            return;
        }

        Item* item = player->GetItemByPos(bag, slot);
        if (!item)
        {
            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_ITEM_INFO)
                .SetRequestId(msg.GetRequestId())
                .Set("success", false)
                .Set("serverBag", extBag)
                .Set("serverSlot", extSlot)
                .Set("errorMsg", "Item not found")
                .Send(player);
            return;
        }

        uint32 itemGUID = item->GetGUID().GetCounter();
        uint32 baseItemLevel = item->GetTemplate()->ItemLevel;
        uint32 baseEntry = item->GetEntry();
        DarkChaos::ItemUpgrade::UpgradeManager* mgr =
            DarkChaos::ItemUpgrade::GetUpgradeManager();

        // Special Case: Heirloom items (any is_artifact tier)
        if (IsHeirloomEntry(baseEntry))
        {
             QueryResult heirloomResult = CharacterDatabase.Query(
                "SELECT upgrade_level FROM dc_heirloom_upgrades WHERE item_guid = {}",
                itemGUID);

            uint32 upgradeLevel = 0;
            if (heirloomResult)
                upgradeLevel = (*heirloomResult)[0].Get<uint32>();

            uint8 hlTier = mgr ? static_cast<uint8>(mgr->GetItemTier(baseEntry)) : 3u;
            float statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                static_cast<uint8>(upgradeLevel), hlTier);

            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_ITEM_INFO)
                .SetRequestId(msg.GetRequestId())
                .Set("success", true)
                .Set("itemID", itemGUID)
                .Set("itemEntry", baseEntry)
                .Set("serverBag", extBag)
                .Set("serverSlot", extSlot)
                .Set("currentUpgrade", upgradeLevel)
                .Set("maxUpgrade", GetHeirloomMaxLevel(baseEntry))
                .Set("tier", static_cast<uint32>(hlTier))
                .Set("tokenCost", 0u)
                .Set("essenceCost", 0u)
                .Set("baseIlvl", baseItemLevel)
                .Set("upgradedIlvl", baseItemLevel)
                .Set("statMultiplier", statMultiplier)
                .Send(player);
            return;
        }

        uint32 upgradeLevel = 0;
        uint8 tier = DarkChaos::ItemUpgrade::TIER_LEVELING;

        DarkChaos::ItemUpgrade::ItemUpgradeState* state =
            mgr ? mgr->GetItemUpgradeState(itemGUID) : nullptr;

        if (state)
        {
            upgradeLevel = state->upgrade_level;

            if (state->base_item_level != 0)
                baseItemLevel = state->base_item_level;

            if (state->tier_id != 0 &&
                state->tier_id != DarkChaos::ItemUpgrade::TIER_INVALID)
            {
                tier = state->tier_id;
            }
        }

        if (mgr)
        {
            uint8 mappedTier = mgr->GetItemTier(baseEntry);
            if (mappedTier != 0 &&
                mappedTier != DarkChaos::ItemUpgrade::TIER_INVALID)
            {
                tier = mappedTier;
            }
        }

        // Fallback or override from table if mgr fails (redundant but safe)
        if (tier == 0 || tier == DarkChaos::ItemUpgrade::TIER_INVALID)
        {
             QueryResult tierLookup = WorldDatabase.Query(
                "SELECT tier_id FROM dc_item_upgrade_item_overrides WHERE item_id = {} AND season = 1 AND is_active = 1",
                baseEntry);
             if (tierLookup)
                 tier = (*tierLookup)[0].Get<uint8>();
             else
                 tier = DarkChaos::ItemUpgrade::TIER_LEVELING;
        }

        // Calculate stat multiplier and ilvl
        float statMultiplier = DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                    static_cast<uint8>(upgradeLevel), tier);

        if (state && state->stat_multiplier > 0.0f)
            statMultiplier = state->stat_multiplier;

        uint16 upgradedIlvl = DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                    static_cast<uint16>(baseItemLevel), static_cast<uint8>(upgradeLevel), tier);

        if (state && state->upgraded_item_level != 0)
            upgradedIlvl = state->upgraded_item_level;

        // Get tier max level
        uint32 maxLevel = 15;
        QueryResult tierResult = WorldDatabase.Query(
            "SELECT max_upgrade_level FROM dc_item_upgrade_tiers WHERE tier_id = {} AND season = 1",
            tier);
        if (tierResult)
            maxLevel = (*tierResult)[0].Get<uint32>();

        uint32 nextTokenCost = 0;
        uint32 nextEssenceCost = 0;
        if (upgradeLevel < maxLevel)
        {
            if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
            {
                uint8 nextLevel = static_cast<uint8>(upgradeLevel + 1);
                if (nextLevel > maxLevel)
                    nextLevel = static_cast<uint8>(maxLevel);

                nextTokenCost = mgr->GetUpgradeCost(static_cast<uint8>(tier), nextLevel);
                nextEssenceCost = mgr->GetEssenceCost(static_cast<uint8>(tier), nextLevel);
            }
        }

        // Send response
        JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_ITEM_INFO)
            .SetRequestId(msg.GetRequestId())
            .Set("success", true)
            .Set("itemID", itemGUID)
            .Set("itemEntry", baseEntry)
            .Set("serverBag", extBag)
            .Set("serverSlot", extSlot)
            .Set("currentUpgrade", upgradeLevel)
            .Set("maxUpgrade", maxLevel)
            .Set("tier", tier)
            .Set("tokenCost", nextTokenCost)
            .Set("essenceCost", nextEssenceCost)
            .Set("baseIlvl", baseItemLevel)
            .Set("upgradedIlvl", upgradedIlvl)
            .Set("statMultiplier", statMultiplier)
            .Send(player);
    }

    // Handler: Get upgrade costs
    static void HandleGetCosts(Player* player, const ParsedMessage& msg)
    {
        AuditUpgradeUiTransport(player);
        CacheContext(player);
        uint32 tier = 0;
        uint32 fromLevel = 0;
        uint32 toLevel = 0;

        if (!TryGetJsonUInt(msg, "tier", tier))
            tier = msg.GetUInt32(0);
        if (!TryGetJsonUInt(msg, "fromLevel", fromLevel))
            fromLevel = msg.GetUInt32(1);
        if (!TryGetJsonUInt(msg, "toLevel", toLevel))
            toLevel = msg.GetUInt32(2);

        if (tier < 1 || tier > 3 || fromLevel >= toLevel)
        {
            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_COST_INFO)
                .SetRequestId(msg.GetRequestId())
                .Set("success", false)
                .Set("errorMsg", "Invalid parameters")
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

        JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_COST_INFO)
            .SetRequestId(msg.GetRequestId())
            .Set("success", true)
            .Set("tier", tier)
            .Set("fromLevel", fromLevel)
            .Set("toLevel", toLevel)
            .Set("tokens", tokens)
            .Set("essence", essence)
            .Send(player);
    }

    // Handler: List upgradeable items in inventory
    static void HandleListUpgradeable(Player* player, const ParsedMessage& msg)
    {
        AuditUpgradeUiTransport(player);
        CacheContext(player);
        // Scan player inventory for upgradeable items
        std::vector<std::string> items;

        auto CheckItem = [&](Item* item, uint8 bag, uint8 slot) {
             if (!item) return;

             uint32 entry = item->GetEntry();

             // All upgradeable items (regular and heirloom) resolved via UpgradeManager.
             // Heirloom items carry their actual tier_id; the client routes them to the
             // heirloom UI based on DC.HEIRLOOM_TIERS.
             if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
             {
                 uint32 tier = mgr->GetItemTier(entry);
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

        // Send list as JSON array (strings: bag:slot:guid:entry:tier)
        JsonValue arr;
        arr.SetArray();
        for (auto const& it : items)
            arr.Push(JsonValue(it));

        JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_UPGRADEABLE_LIST)
            .SetRequestId(msg.GetRequestId())
            .Set("count", static_cast<uint32>(items.size()))
            .Set("items", arr)
            .Send(player);
    }

    // Handler: Perform upgrade (Unified Native Logic)
    static void HandleDoUpgrade(Player* player, const ParsedMessage& msg)
    {
        AuditUpgradeUiTransport(player);
        CacheContext(player);
        uint32 extBag = 0;
        uint32 extSlot = 0;
        uint32 targetLevel = 0;

        if (!TryGetJsonUInt(msg, "bag", extBag))
            extBag = msg.GetUInt32(0);
        if (!TryGetJsonUInt(msg, "slot", extSlot))
            extSlot = msg.GetUInt32(1);
        if (!TryGetJsonUInt(msg, "targetLevel", targetLevel))
            targetLevel = msg.GetUInt32(2);

        uint8 bag = 0, slot = 0;
           if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
        {
               LOG_WARN("dc.addon.upgrade", "Upgrade failed: invalid slot (extBag={}, extSlot={}) for player {}",
                  extBag, extSlot, player->GetName());
               SendUpgradeResult(player, msg.GetRequestId(), false, 0, 0, 0, UPGRADE_ERR_ITEM_NOT_FOUND, "Invalid slot");
             return;
        }

        Item* item = player->GetItemByPos(bag, slot);
        if (!item)
        {
            LOG_WARN("dc.addon.upgrade", "Upgrade failed: item not found at bag={}, slot={} for player {}",
                bag, slot, player->GetName());
            SendUpgradeResult(player, msg.GetRequestId(), false, 0, 0, 0, UPGRADE_ERR_ITEM_NOT_FOUND, "Item not found");
            return;
        }

           if (IsHeirloomEntry(item->GetEntry()))
        {
               SendUpgradeResult(player, msg.GetRequestId(), false, item->GetGUID().GetCounter(), 0, 0, UPGRADE_ERR_NOT_UPGRADEABLE, "Use Heirloom Upgrade for this item");
             return;
        }

        uint32 itemGUID = item->GetGUID().GetCounter();
        uint32 currentEntry = item->GetEntry();
       uint32 baseEntry = currentEntry;

        uint32 tier = 1;
        DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (mgr)
           tier = mgr->GetItemTier(currentEntry);

        // Disallow heirloom (is_artifact) tiers in standard item upgrade flow
        {
            DarkChaos::ItemUpgrade::TierDefinition const* tierDef =
                mgr ? mgr->GetTierDefinition(static_cast<uint8>(tier)) : nullptr;
            if (tierDef && tierDef->is_artifact)
            {
                SendUpgradeResult(player, msg.GetRequestId(), false, itemGUID, 0, currentEntry, UPGRADE_ERR_NOT_UPGRADEABLE,
                    "Heirloom items must be upgraded via the Heirloom interface");
                return;
            }
        }

        uint32 currentLevel = 0;
        DarkChaos::ItemUpgrade::ItemUpgradeState* upgradeState = mgr
            ? mgr->GetItemUpgradeState(itemGUID)
            : nullptr;
        if (upgradeState && upgradeState->has_persisted_state)
            currentLevel = upgradeState->upgrade_level;

        uint32 maxLevel = 15;
        QueryResult tierResult = WorldDatabase.Query(
            "SELECT max_upgrade_level FROM dc_item_upgrade_tiers WHERE tier_id = {} AND season = 1",
            tier);
        if (tierResult)
            maxLevel = (*tierResult)[0].Get<uint32>();

        if (targetLevel > maxLevel)
        {
            SendUpgradeResult(player, msg.GetRequestId(), false, itemGUID, currentLevel, currentEntry,
                UPGRADE_ERR_MAX_LEVEL, "Target level exceeds max upgrade");
            return;
        }

           if (targetLevel <= currentLevel)
        {
               SendUpgradeResult(player, msg.GetRequestId(), false, itemGUID, currentLevel, currentEntry, UPGRADE_ERR_MAX_LEVEL, "Target level must be higher");
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
               SendUpgradeResult(player, msg.GetRequestId(), false, itemGUID, currentLevel, currentEntry, UPGRADE_ERR_NOT_ENOUGH_TOKENS, "Not enough Tokens");
             return;
        }
           if (player->GetItemCount(essenceId) < essenceNeeded)
        {
               SendUpgradeResult(player, msg.GetRequestId(), false, itemGUID, currentLevel, currentEntry, UPGRADE_ERR_NOT_ENOUGH_ESSENCE, "Not enough Essence");
             return;
        }

        if (!mgr || !upgradeState)
        {
            LOG_ERROR("dc.addon.upgrade", "Upgrade failed: upgrade manager unavailable for player {} item {}",
                player->GetName(), itemGUID);
            SendUpgradeResult(player, msg.GetRequestId(), false, itemGUID, currentLevel, currentEntry,
                UPGRADE_ERR_NOT_UPGRADEABLE, "Upgrade manager unavailable");
            return;
        }

        ItemTemplate const* baseTemplate = item->GetTemplate();
        if (baseEntry != currentEntry)
            baseTemplate = sObjectMgr->GetItemTemplate(baseEntry);

        if (!baseTemplate)
        {
            LOG_ERROR("dc.addon.upgrade", "Upgrade failed: missing base template {} for player {} item {}",
                baseEntry, player->GetName(), itemGUID);
            SendUpgradeResult(player, msg.GetRequestId(), false, itemGUID, currentLevel, currentEntry,
                UPGRADE_ERR_NOT_UPGRADEABLE, "Base item template not found");
            return;
        }

        uint32 nextTokenCost = 0;
        uint32 nextEssenceCost = 0;
        if (targetLevel < maxLevel)
        {
            uint8 nextLevel = static_cast<uint8>(targetLevel + 1);
            if (nextLevel > maxLevel)
                nextLevel = static_cast<uint8>(maxLevel);

            nextTokenCost = mgr->GetUpgradeCost(static_cast<uint8>(tier), nextLevel);
            nextEssenceCost = mgr->GetEssenceCost(static_cast<uint8>(tier), nextLevel);
        }

        // Consume currency
        if (tokensNeeded > 0) player->DestroyItemCount(tokenId, tokensNeeded, true);
        if (essenceNeeded > 0) player->DestroyItemCount(essenceId, essenceNeeded, true);

        auto loadInvestedCostsThroughLevel = [&](uint32 throughLevel, uint32& outTokens, uint32& outEssence)
        {
            outTokens = 0;
            outEssence = 0;
            if (throughLevel == 0)
                return;

            QueryResult investedResult = WorldDatabase.Query(
                "SELECT COALESCE(SUM(token_cost), 0), COALESCE(SUM(essence_cost), 0) FROM dc_item_upgrade_costs "
                "WHERE tier_id = {} AND season = 1 AND upgrade_level <= {}",
                tier, throughLevel);
            if (!investedResult)
                return;

            if (!(*investedResult)[0].IsNull())
                outTokens = (*investedResult)[0].Get<uint32>();
            if (!(*investedResult)[1].IsNull())
                outEssence = (*investedResult)[1].Get<uint32>();
        };

        uint32 investedTokens = upgradeState->tokens_invested;
        uint32 investedEssence = upgradeState->essence_invested;
        if (!upgradeState->has_persisted_state && currentLevel > 0 &&
            investedTokens == 0 && investedEssence == 0)
        {
            loadInvestedCostsThroughLevel(currentLevel, investedTokens,
                investedEssence);
        }

        time_t const now = time(nullptr);
        upgradeState->player_guid = player->GetGUID().GetCounter();
        upgradeState->item_guid = itemGUID;
        upgradeState->item_entry = baseEntry;
        upgradeState->base_item_name = !baseTemplate->Name1.empty()
            ? baseTemplate->Name1
            : (std::string("Item ") + std::to_string(baseEntry));
        upgradeState->tier_id = static_cast<uint8>(tier);
        upgradeState->upgrade_level = static_cast<uint8>(targetLevel);
        upgradeState->tokens_invested = investedTokens + tokensNeeded;
        upgradeState->essence_invested = investedEssence + essenceNeeded;
        upgradeState->season = 1;
        upgradeState->base_item_level = baseTemplate->ItemLevel;
        upgradeState->upgraded_item_level =
            DarkChaos::ItemUpgrade::ItemLevelCalculator::GetUpgradedItemLevel(
                static_cast<uint16>(baseTemplate->ItemLevel),
                static_cast<uint8>(targetLevel), static_cast<uint8>(tier));
        upgradeState->stat_multiplier =
            DarkChaos::ItemUpgrade::StatScalingCalculator::GetFinalMultiplier(
                static_cast<uint8>(targetLevel), static_cast<uint8>(tier));
        if (upgradeState->first_upgraded_at == 0 && targetLevel > 0)
            upgradeState->first_upgraded_at = now;
        upgradeState->last_upgraded_at = now;

        mgr->SaveItemUpgrade(itemGUID);
        DarkChaos::ItemUpgrade::ForcePlayerStatUpdate(player);

        SendUpgradeResult(player, msg.GetRequestId(), true, itemGUID,
            targetLevel, item->GetEntry(), UPGRADE_ERR_NONE, "", tier,
            maxLevel, nextTokenCost, nextEssenceCost, item->GetBagSlot(),
            item->GetSlot());
        SendCurrencyUpdate(player);
    }

    // Handler: Package selection (migrated from itemupgrade_communication.lua)
    static void HandlePackageSelect(Player* player, const ParsedMessage& msg)
    {
        AuditUpgradeUiTransport(player);
        CacheContext(player);
        uint32 packageId = 0;
        if (!TryGetJsonUInt(msg, "packageId", packageId))
            packageId = msg.GetUInt32(0);
        uint32 playerGuid = player->GetGUID().GetCounter();

        // Validate package ID (1-12)
        if (packageId < 1 || packageId > 12)
        {
            LOG_WARN("dc.addon.upgrade", "Invalid package ID {} (dataCount={}) from player {}",
                packageId, msg.GetDataCount(), player->GetName());
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
        JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_PACKAGE_SELECTED)
            .SetRequestId(msg.GetRequestId())
            .Set("success", true)
            .Set("packageId", packageId)
            .Send(player);
    }

    // HEIRLOOM HANDLERS

    static void HandleHeirloomQuery(Player* player, const ParsedMessage& msg)
    {
        AuditUpgradeUiTransport(player);
        CacheContext(player);
        uint32 extBag = 0;
        uint32 extSlot = 0;

        if (!TryGetJsonUInt(msg, "bag", extBag))
            extBag = msg.GetUInt32(0);
        if (!TryGetJsonUInt(msg, "slot", extSlot))
            extSlot = msg.GetUInt32(1);

        uint8 bag, slot;
           if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
           {
               JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_INFO)
                  .SetRequestId(msg.GetRequestId())
                  .Set("success", false)
                  .Set("errorMsg", "Invalid slot")
                  .Send(player);
               return;
           }

        Item* item = player->GetItemByPos(bag, slot);
           if (!item || !IsHeirloomEntry(item->GetEntry()))
           {
               JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_INFO)
                  .SetRequestId(msg.GetRequestId())
                  .Set("success", false)
                  .Set("errorMsg", "Invalid Heirloom")
                  .Send(player);
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

           JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_INFO)
               .SetRequestId(msg.GetRequestId())
               .Set("success", true)
               .Set("itemGuid", itemGuid)
               .Set("level", level)
               .Set("packageId", package)
               .Set("maxLevel", GetHeirloomMaxLevel(item->GetEntry()))
               .Set("maxPackage", HEIRLOOM_MAX_PACKAGE_ID)
               .Send(player);
    }

    static void HandleGetPackages(Player* player, const ParsedMessage& /*msg*/)
    {
        AuditUpgradeUiTransport(player);
        CacheContext(player);
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
        AuditUpgradeUiTransport(player);
        CacheContext(player);
         uint32 extBag = 0;
         uint32 extSlot = 0;
         uint32 targetLevel = 0;
         uint32 packageId = 0;

         if (!TryGetJsonUInt(msg, "bag", extBag))
             extBag = msg.GetUInt32(0);
         if (!TryGetJsonUInt(msg, "slot", extSlot))
             extSlot = msg.GetUInt32(1);
         if (!TryGetJsonUInt(msg, "targetLevel", targetLevel))
             targetLevel = msg.GetUInt32(2);
         if (!TryGetJsonUInt(msg, "packageId", packageId))
             packageId = msg.GetUInt32(3);

        uint8 bag, slot;
           if (!TranslateAddonBagSlot(extBag, extSlot, bag, slot))
           {
               JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT)
                  .SetRequestId(msg.GetRequestId())
                  .Set("success", false)
                  .Set("errorMsg", "Invalid slot")
                  .Send(player);
               return;
           }

        Item* item = player->GetItemByPos(bag, slot);
           if (!item || !IsHeirloomEntry(item->GetEntry()))
           {
               JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT)
                  .SetRequestId(msg.GetRequestId())
                  .Set("success", false)
                  .Set("errorMsg", "Invalid Heirloom")
                  .Send(player);
               return;
           }

        // Resolve per-item tier and max level from the DB tier definition
        uint8 itemTier = 0;
        uint32 heirloomMaxLevel = HEIRLOOM_MAX_LEVEL;
        if (DarkChaos::ItemUpgrade::UpgradeManager* hMgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
        {
            itemTier = static_cast<uint8>(hMgr->GetItemTier(item->GetEntry()));
            uint8 tMax = hMgr->GetTierMaxLevel(itemTier);
            if (tMax > 0)
                heirloomMaxLevel = tMax;
        }

        // Validate inputs
           if (packageId < 1 || packageId > HEIRLOOM_MAX_PACKAGE_ID)
           {
               JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT)
                  .SetRequestId(msg.GetRequestId())
                  .Set("success", false)
                  .Set("errorMsg", "Invalid Package")
                  .Send(player);
               return;
           }
           if (targetLevel > heirloomMaxLevel)
           {
               JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT)
                  .SetRequestId(msg.GetRequestId())
                  .Set("success", false)
                  .Set("errorMsg", "Level too high")
                  .Send(player);
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
              JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT)
                .SetRequestId(msg.GetRequestId())
                .Set("success", false)
                .Set("errorMsg", "Already higher level")
                .Send(player);
              return;
          }

        // Calculate Cost
        QueryResult costRes = WorldDatabase.Query("SELECT SUM(token_cost), SUM(essence_cost) FROM dc_heirloom_upgrade_costs WHERE tier_id = {} AND upgrade_level BETWEEN {} AND {}", itemTier, currentLevel + 1, targetLevel);

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
               JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT)
                  .SetRequestId(msg.GetRequestId())
                  .Set("success", false)
                  .Set("errorMsg", "Not enough Tokens")
                  .Send(player);
               return;
           }
           if (player->GetItemCount(essenceId) < essenceNeeded)
           {
               JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT)
                  .SetRequestId(msg.GetRequestId())
                  .Set("success", false)
                  .Set("errorMsg", "Not enough Essence")
                  .Send(player);
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

        // Update DB (timestamps use column defaults)
        CharacterDatabase.Execute("REPLACE INTO dc_heirloom_upgrades (player_guid, item_guid, item_entry, upgrade_level, package_id, enchant_id) VALUES ({}, {}, {}, {}, {}, {})",
            player->GetGUID().GetCounter(), itemGuid, item->GetEntry(), targetLevel, packageId, enchantId);

        // Log
        CharacterDatabase.Execute("INSERT INTO dc_heirloom_upgrade_log (player_guid, item_guid, item_entry, from_level, to_level, from_package, to_package, enchant_id, token_cost, essence_cost) VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {})",
            player->GetGUID().GetCounter(), itemGuid, item->GetEntry(), currentLevel, targetLevel, currentPackage, packageId, enchantId, tokensNeeded, essenceNeeded);

        // Success
        JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_HEIRLOOM_RESULT)
            .SetRequestId(msg.GetRequestId())
            .Set("success", true)
            .Set("itemGuid", itemGuid)
            .Set("newLevel", targetLevel)
            .Set("packageId", packageId)
            .Set("enchantId", enchantId)
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
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_GET_TIER_CONFIG, HandleGetTierConfig);

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
        SendTierConfig(player);

        CacheContext(player);
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
