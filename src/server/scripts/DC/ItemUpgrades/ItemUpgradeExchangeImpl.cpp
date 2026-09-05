/*
 * DarkChaos Item Upgrade System - Currency Exchange Implementation
 *
 * Implementation of currency exchange between Upgrade Tokens, Artifact
 * Essence and Emberwood Sap.
 * Synthesis system removed (Jan 2026).
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 * Updated: January 2026 - Renamed from Transmutation, removed synthesis
 */

#include "ItemUpgradeExchange.h"
#include "ItemUpgradeMechanics.h"
#include "ItemUpgradeManager.h"
#include "DC/CrossSystem/SeasonResolver.h"
#include "DC/CrossSystem/CrossSystemUtilities.h"
#include "Player.h"
#include "Item.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "World.h"
#include "ObjectAccessor.h"
#include <sstream>
#include <algorithm>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Transmutation Manager Implementation
        // =====================================================================

        class TransmutationManagerImpl : public TransmutationManager
        {
        private:
            std::map<uint32, TransmutationRecipe> recipes;
            std::map<uint32, TransmutationSession> active_sessions;

            // Configuration
            struct TransmutationConfig
            {
                uint32 base_cooldown_seconds;
                float tier_downgrade_success_rate;
                float tier_upgrade_success_rate;
                uint32 synthesis_base_cost_essence;
                uint32 synthesis_base_cost_tokens;
                bool allow_partial_refunds;
                uint32 max_concurrent_transmutations;

                TransmutationConfig() :
                    base_cooldown_seconds(3600), tier_downgrade_success_rate(0.95f),
                    tier_upgrade_success_rate(0.75f),
                    synthesis_base_cost_essence(100), synthesis_base_cost_tokens(50),
                    allow_partial_refunds(true), max_concurrent_transmutations(3) {}
            } config;

        public:
            TransmutationManagerImpl()
            {
                // NOTE: Synthesis recipes removed (Jan 2026)
                // This manager now handles currency exchange only
                LOG_INFO("scripts.dc", "ItemUpgrade: Currency Exchange system initialized");
            }

            // LoadTransmutationData removed - synthesis recipes no longer used
            // Currency exchange rates come from GetExchangeRateTable()

            std::vector<TransmutationRecipe> GetAvailableRecipes([[maybe_unused]] uint32 player_guid) override
            {
                // Synthesis recipes removed - return empty list
                // Currency exchange doesn't use recipes
                return {};
            }

            bool CanPerformTransmutation(uint32 player_guid, uint32 recipe_id, std::string& error_message) override
            {
                auto it = recipes.find(recipe_id);
                if (it == recipes.end())
                {
                    error_message = "Recipe not found.";
                    return false;
                }

                TransmutationRecipe const& recipe = it->second;

                // Check player level
                QueryResult level_result = CharacterDatabase.Query(
                    "SELECT level FROM characters WHERE guid = {}", player_guid);

                if (!level_result)
                {
                    error_message = "Player data not found.";
                    return false;
                }

                uint8 player_level = level_result->Fetch()[0].Get<uint8>();
                if (player_level < recipe.required_level)
                {
                    error_message = "Player level too low for this recipe.";
                    return false;
                }

                // Check cooldown
                QueryResult cooldown_result = CharacterDatabase.Query(
                    "SELECT last_used FROM dc_player_transmutation_cooldowns "
                    "WHERE player_guid = {} AND recipe_id = {}", player_guid, recipe_id);

                if (cooldown_result)
                {
                    time_t last_used = cooldown_result->Fetch()[0].Get<time_t>();
                    time_t now = time(nullptr);
                    time_t cooldown_end = last_used + recipe.cooldown_seconds;

                    if (now < cooldown_end)
                    {
                        uint32 remaining_seconds = cooldown_end - now;
                        error_message = "Recipe on cooldown. " + std::to_string(remaining_seconds) + " seconds remaining.";
                        return false;
                    }
                }

                // Check currency requirements
                UpgradeManager* mgr = GetUpgradeManager();
                uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();
                if (recipe.input_essence > 0)
                {
                    uint32 essence = mgr->GetCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, season);
                    if (essence < recipe.input_essence)
                    {
                        error_message = "Insufficient artifact essence.";
                        return false;
                    }
                }

                if (recipe.input_tokens > 0)
                {
                    uint32 tokens = mgr->GetCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, season);
                    if (tokens < recipe.input_tokens)
                    {
                        error_message = "Insufficient upgrade tokens.";
                        return false;
                    }
                }

                // Check item requirements
                for (auto const& input : recipe.input_items)
                {
                    QueryResult item_result = CharacterDatabase.Query(
                        "SELECT COUNT(*) FROM item_instance ii "
                        "JOIN inventory i ON ii.guid = i.item "
                        "WHERE i.guid = {} AND ii.itemEntry = {}", player_guid, input.item_id);

                    if (!item_result || item_result->Fetch()[0].Get<uint32>() < input.quantity)
                    {
                        error_message = "Missing required items.";
                        return false;
                    }
                }

                // Check upgrade requirements
                for (auto const& [item_guid, min_level] : recipe.input_upgrades)
                {
                    QueryResult upgrade_result = CharacterDatabase.Query(
                        "SELECT upgrade_level FROM {} "
                        "WHERE item_guid = {} AND player_guid = {}", ITEM_UPGRADES_TABLE, item_guid, player_guid);

                    if (!upgrade_result || upgrade_result->Fetch()[0].Get<uint8>() < min_level)
                    {
                        error_message = "Item upgrade level requirement not met.";
                        return false;
                    }
                }

                // Check catalyst if required
                if (recipe.requires_catalyst)
                {
                    QueryResult catalyst_result = CharacterDatabase.Query(
                        "SELECT COUNT(*) FROM item_instance ii "
                        "JOIN inventory i ON ii.guid = i.item "
                        "WHERE i.guid = {} AND ii.itemEntry = {}", player_guid, recipe.catalyst_item_id);

                    if (!catalyst_result || catalyst_result->Fetch()[0].Get<uint32>() < 1)
                    {
                        error_message = "Required catalyst item not found.";
                        return false;
                    }
                }

                return true;
            }

            bool StartTransmutation(uint32 player_guid, uint32 recipe_id) override
            {
                std::string error_message;
                if (!CanPerformTransmutation(player_guid, recipe_id, error_message))
                {
                    LOG_ERROR("scripts.dc", "ItemUpgrade: Cannot start transmutation {} for player {}: {}",
                             recipe_id, player_guid, error_message);
                    return false;
                }

                auto it = recipes.find(recipe_id);
                if (it == recipes.end())
                    return false;

                TransmutationRecipe const& recipe = it->second;

                try
                {
                    // Deduct currencies
                    UpgradeManager* mgr = GetUpgradeManager();
                    uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();
                    if (recipe.input_essence > 0)
                        mgr->RemoveCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, recipe.input_essence, season);
                    if (recipe.input_tokens > 0)
                        mgr->RemoveCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, recipe.input_tokens, season);

                    // Sync inventory using centralized utility (full sync, no player available)
                    DarkChaos::CrossSystem::CurrencyUtils::SyncInventoryToDB(
                        player_guid, season, nullptr, CURRENCY_UPGRADE_TOKEN, 0, true);

                    // Create transmutation session
                    TransmutationSession session;
                    session.player_guid = player_guid;
                    session.recipe_id = recipe_id;
                    session.start_time = time(nullptr);
                    session.end_time = session.start_time + 30; // 30 second process time
                    session.completed = false;
                    session.success = false;

                    // Store session
                    active_sessions[player_guid] = session;

                    // Update cooldown
                    CharacterDatabase.Execute(
                        "INSERT INTO dc_player_transmutation_cooldowns (player_guid, recipe_id, last_used) "
                        "VALUES ({}, {}, {}) ON DUPLICATE KEY UPDATE last_used = {}",
                        player_guid, recipe_id, session.start_time, session.start_time);

                    LOG_INFO("scripts.dc", "ItemUpgrade: Started transmutation {} for player {}", recipe_id, player_guid);
                    return true;

                }
                catch (std::exception const& e)
                {
                    LOG_ERROR("scripts.dc", "ItemUpgrade: Failed to start transmutation {} for player {}: {}",
                             recipe_id, player_guid, e.what());
                    return false;
                }
            }

            TransmutationSession GetTransmutationStatus(uint32 player_guid) override
            {
                auto it = active_sessions.find(player_guid);
                if (it == active_sessions.end())
                {
                    // Check if there's a completed session in database
                    QueryResult result = CharacterDatabase.Query(
                        "SELECT recipe_id, start_time, end_time, success FROM dc_item_upgrade_transmutation_sessions "
                        "WHERE player_guid = {} AND completed = 1 ORDER BY end_time DESC LIMIT 1", player_guid);

                    if (result)
                    {
                        TransmutationSession session;
                        session.player_guid = player_guid;
                        session.recipe_id = result->Fetch()[0].Get<uint32>();
                        session.start_time = result->Fetch()[1].Get<time_t>();
                        session.end_time = result->Fetch()[2].Get<time_t>();
                        session.completed = true;
                        session.success = result->Fetch()[3].Get<bool>();
                        return session;
                    }

                    return TransmutationSession(); // Empty session
                }

                TransmutationSession session = it->second;
                time_t now = time(nullptr);

                if (now >= session.end_time && !session.completed)
                {
                    // Complete the transmutation
                    CompleteTransmutation(player_guid);
                    session = active_sessions[player_guid];
                }

                return session;
            }

            bool CancelTransmutation(uint32 player_guid) override
            {
                auto it = active_sessions.find(player_guid);
                if (it == active_sessions.end())
                    return false;

                TransmutationSession const& session = it->second;
                if (session.completed)
                    return false;

                auto recipe_it = recipes.find(session.recipe_id);
                if (recipe_it == recipes.end())
                    return false;

                TransmutationRecipe const& recipe = recipe_it->second;

                try
                {
                    // Refund partial costs
                    UpgradeManager* mgr = GetUpgradeManager();
                    uint32 season = GetCurrentSeasonId();
                    if (config.allow_partial_refunds)
                    {
                        uint32 refund_essence = recipe.input_essence * 0.5f;
                        uint32 refund_tokens = recipe.input_tokens * 0.5f;

                        if (refund_essence > 0)
                            mgr->AddCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, refund_essence, season);
                        if (refund_tokens > 0)
                            mgr->AddCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, refund_tokens, season);

                        // Sync inventory using centralized utility (full sync, no player available)
                        DarkChaos::CrossSystem::CurrencyUtils::SyncInventoryToDB(
                            player_guid, season, nullptr, CURRENCY_UPGRADE_TOKEN, 0, true);
                    }

                    // Remove session
                    active_sessions.erase(it);

                    LOG_INFO("scripts.dc", "ItemUpgrade: Cancelled transmutation {} for player {}", session.recipe_id, player_guid);
                    return true;

                }
                catch (std::exception const& e)
                {
                    LOG_ERROR("scripts.dc", "ItemUpgrade: Failed to cancel transmutation for player {}: {}", player_guid, e.what());
                    return false;
                }
            }

            std::vector<CurrencyExchangeRate> GetExchangeRateTable() override
            {
                // Emberwood Sap is a ZONE currency: it is earned on the Hyjal
                // Frontier and pays for T4/T5. Converting *into* sap therefore
                // buys endgame upgrade progress with content the player did not
                // do, and the inbound rates are deliberately punitive to keep
                // the Frontier the cheapest way to get sap. Converting *out of*
                // sap is a surplus drain and pays a fair rate.
                //
                // Round trips are lossy on purpose: 10 essence buys 1 sap, and
                // that sap sells back for 2 essence.
                uint32 const tokensPerSap = sConfigMgr->GetOption<uint32>("ItemUpgrade.Exchange.TokensPerSap", 20);
                uint32 const essencePerSap = sConfigMgr->GetOption<uint32>("ItemUpgrade.Exchange.EssencePerSap", 10);
                uint32 const sapPayout = sConfigMgr->GetOption<uint32>("ItemUpgrade.Exchange.SapPayout", 2);

                std::vector<CurrencyExchangeRate> rates;
                rates.reserve(6);

                // Unchanged legacy pair: 2 tokens buy 1 essence, 1 essence sells
                // back for 1 token.
                rates.emplace_back(CURRENCY_UPGRADE_TOKEN, CURRENCY_ARTIFACT_ESSENCE, 2, 1);
                rates.emplace_back(CURRENCY_ARTIFACT_ESSENCE, CURRENCY_UPGRADE_TOKEN, 1, 1);

                // Into sap -- punitive.
                if (tokensPerSap > 0)
                    rates.emplace_back(CURRENCY_UPGRADE_TOKEN, CURRENCY_FRONTIER_SAP, tokensPerSap, 1);
                if (essencePerSap > 0)
                    rates.emplace_back(CURRENCY_ARTIFACT_ESSENCE, CURRENCY_FRONTIER_SAP, essencePerSap, 1);

                // Out of sap -- surplus drain.
                if (sapPayout > 0)
                {
                    rates.emplace_back(CURRENCY_FRONTIER_SAP, CURRENCY_ARTIFACT_ESSENCE, 1, sapPayout);
                    rates.emplace_back(CURRENCY_FRONTIER_SAP, CURRENCY_UPGRADE_TOKEN, 1, sapPayout);
                }

                return rates;
            }

            bool ExchangeCurrency(uint32 player_guid, CurrencyType from, CurrencyType to,
                uint32 source_amount) override
            {
                // source_amount is client input. Cap it well below the point
                // where trades * to_units could wrap a uint32; a balance this
                // large is not reachable through play anyway.
                constexpr uint32 MAX_EXCHANGE_SOURCE_AMOUNT = 10000000;

                if (source_amount == 0 || source_amount > MAX_EXCHANGE_SOURCE_AMOUNT)
                {
                    LOG_WARN("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - amount {} out of range for player {}",
                             source_amount, player_guid);
                    return false;
                }

                if (from == to)
                {
                    LOG_WARN("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - same currency {} for player {}",
                             static_cast<uint32>(from), player_guid);
                    return false;
                }

                // Look the pair up in the table rather than branching on it, so
                // the rates the UI was shown and the rates charged cannot drift.
                CurrencyExchangeRate rate;
                bool found = false;
                for (auto const& row : GetExchangeRateTable())
                {
                    if (row.from == from && row.to == to)
                    {
                        rate = row;
                        found = true;
                        break;
                    }
                }

                if (!found || rate.from_units == 0 || rate.to_units == 0)
                {
                    LOG_WARN("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - unsupported pair {}->{} for player {}",
                             static_cast<uint32>(from), static_cast<uint32>(to), player_guid);
                    return false;
                }

                // Find the player
                Player* player = FindPlayerWithContext(player_guid);
                if (!player)
                {
                    LOG_ERROR("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - player {} not found", player_guid);
                    return false;
                }

                // Use DB-backed currency (single source of truth)
                UpgradeManager* mgr = GetUpgradeManager();
                if (!mgr)
                {
                    LOG_ERROR("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - UpgradeManager not available for player {}", player_guid);
                    return false;
                }

                uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();

                try
                {
                    // Whole trades only. The remainder below one full trade is
                    // never spent -- charging for a partial trade that yields
                    // nothing is how currency quietly disappears.
                    uint32 trades = source_amount / rate.from_units;
                    if (trades == 0)
                    {
                        LOG_WARN("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - {} is below one trade ({}) for player {}",
                                 source_amount, rate.from_units, player_guid);
                        return false;
                    }

                    uint32 spend_amount = trades * rate.from_units;
                    uint32 receive_amount = trades * rate.to_units;

                    uint32 current = mgr->GetCurrency(player_guid, from, season);

                    LOG_DEBUG("scripts.dc", "ItemUpgrade: Exchange {}->{}: current {} spend {} receive {}",
                              static_cast<uint32>(from), static_cast<uint32>(to),
                              current, spend_amount, receive_amount);

                    if (current < spend_amount)
                    {
                        LOG_WARN("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - insufficient currency {} ({} < {}) for player {}",
                                 static_cast<uint32>(from), current, spend_amount, player_guid);
                        return false;
                    }

                    // The currencies ARE inventory items (UpgradeManager::Add/
                    // RemoveCurrency operate on item counts), so a full bag makes
                    // the grant fail. Check space BEFORE spending: removing first
                    // and failing to grant would destroy the player's currency.
                    // Conservative on purpose -- freeing the source stack might
                    // have made room, but refusing a trade beats deleting one.
                    uint32 targetItemId = GetCurrencyItemId(to);
                    ItemPosCountVec dest;
                    InventoryResult storeResult = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest,
                        targetItemId, receive_amount);
                    if (storeResult != EQUIP_ERR_OK)
                    {
                        player->SendEquipError(storeResult, nullptr, nullptr, targetItemId);
                        LOG_WARN("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - no room for {} of item {} for player {}",
                                 receive_amount, targetItemId, player_guid);
                        return false;
                    }

                    if (!mgr->RemoveCurrency(player_guid, from, spend_amount, season))
                    {
                        LOG_WARN("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - could not spend {} of currency {} for player {}",
                                 spend_amount, static_cast<uint32>(from), player_guid);
                        return false;
                    }

                    if (!mgr->AddCurrency(player_guid, to, receive_amount, season))
                    {
                        // The space check above should have prevented this. Give
                        // the source currency back rather than leaving the player
                        // having paid for nothing.
                        mgr->AddCurrency(player_guid, from, spend_amount, season);
                        LOG_ERROR("scripts.dc", "ItemUpgrade: ExchangeCurrency could not grant {} of currency {} to player {}; refunded {} of currency {}",
                                  receive_amount, static_cast<uint32>(to), player_guid,
                                  spend_amount, static_cast<uint32>(from));
                        return false;
                    }

                    LOG_INFO("scripts.dc", "ItemUpgrade: Player {} exchanged {} of currency {} for {} of currency {}",
                            player_guid, spend_amount, static_cast<uint32>(from),
                            receive_amount, static_cast<uint32>(to));

                    return true;
                }
                catch (std::exception const& e)
                {
                    LOG_ERROR("scripts.dc", "ItemUpgrade: ExchangeCurrency failed for player {}: {}", player_guid, e.what());
                    return false;
                }
            }

            std::map<std::string, uint32> GetPlayerStatistics(uint32 player_guid) override
            {
                std::map<std::string, uint32> stats;

                QueryResult result = CharacterDatabase.Query(
                    "SELECT COUNT(*), SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END), "
                    "SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) FROM dc_item_upgrade_transmutation_sessions "
                    "WHERE player_guid = {}", player_guid);

                if (result)
                {
                    stats["total_transmutations"] = result->Fetch()[0].Get<uint32>();
                    stats["successful_transmutations"] = result->Fetch()[1].Get<uint32>();
                    stats["failed_transmutations"] = result->Fetch()[2].Get<uint32>();
                }

                return stats;
            }

            void CompleteTransmutation(uint32 player_guid)
            {
                auto it = active_sessions.find(player_guid);
                if (it == active_sessions.end())
                    return;

                TransmutationSession& session = it->second;
                auto recipe_it = recipes.find(session.recipe_id);
                if (recipe_it == recipes.end())
                    return;

                TransmutationRecipe const& recipe = recipe_it->second;

                // Determine success
                float success_roll = frand(0.0f, 1.0f);
                session.success = (success_roll <= recipe.success_rate_base);
                session.completed = true;
                session.end_time = time(nullptr);

                try
                {
                    if (session.success)
                    {
                        // Grant rewards
                        UpgradeManager* mgr = GetUpgradeManager();
                        uint32 season = GetCurrentSeasonId();
                        if (recipe.output_essence > 0)
                            mgr->AddCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, recipe.output_essence, season);
                        if (recipe.output_tokens > 0)
                            mgr->AddCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, recipe.output_tokens, season);

                        // Sync inventory using centralized utility (full sync, no player available)
                        DarkChaos::CrossSystem::CurrencyUtils::SyncInventoryToDB(
                            player_guid, season, nullptr, CURRENCY_UPGRADE_TOKEN, 0, true);

                        // Create output item if specified
                        if (recipe.output_item_id > 0)
                        {
                            // This would need integration with item creation system
                            LOG_INFO("scripts.dc", "ItemUpgrade: Transmutation success - would create item {}", recipe.output_item_id);
                        }
                    }
                    else
                    {
                        // Apply failure penalty
                        if (recipe.failure_penalty_percent > 0)
                        {
                            LOG_INFO("scripts.dc", "ItemUpgrade: Transmutation failed with {}% penalty", recipe.failure_penalty_percent);
                        }
                    }

                    // Save to database
                    CharacterDatabase.Execute(
                        "INSERT INTO dc_item_upgrade_transmutation_sessions "
                        "(player_guid, recipe_id, start_time, end_time, success, completed) "
                        "VALUES ({}, {}, {}, {}, {}, 1)",
                        player_guid, session.recipe_id, session.start_time,
                        session.end_time, session.success ? 1 : 0);

                    LOG_INFO("scripts.dc", "ItemUpgrade: Completed transmutation {} for player {} - {}",
                            session.recipe_id, player_guid, session.success ? "SUCCESS" : "FAILED");

                }
                catch (std::exception const& e)
                {
                    LOG_ERROR("scripts.dc", "ItemUpgrade: Failed to complete transmutation for player {}: {}", player_guid, e.what());
                }
            }
        };

        // =====================================================================
        // Tier Conversion Manager Implementation (Consolidated)
        // =====================================================================

        class TierConversionManagerImpl : public TierConversionManager
        {
        private:
            struct TierConversionConfig
            {
                float downgrade_success_base_rate;
                float upgrade_success_base_rate;
                uint32 downgrade_cost_multiplier;
                uint32 upgrade_cost_multiplier;
                uint32 tier_difficulty_modifier;
                bool allow_cross_quality_conversion;
                uint32 max_tier_difference;

                TierConversionConfig() :
                    downgrade_success_base_rate(0.95f), upgrade_success_base_rate(0.70f),
                    downgrade_cost_multiplier(50), upgrade_cost_multiplier(200),
                    tier_difficulty_modifier(25), allow_cross_quality_conversion(false),
                    max_tier_difference(2) {}
            } config;

        public:
            bool CalculateDowngradeCost(uint32 item_guid, uint8 target_tier,
                                      uint32& out_essence, uint32& out_tokens) override
            {
                UpgradeManager* mgr = GetUpgradeManager();
                ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);

                if (!state || state->tier_id <= target_tier)
                    return false;

                uint8 tier_difference = state->tier_id - target_tier;
                uint8 upgrade_level = state->upgrade_level;

                uint32 base_cost = config.downgrade_cost_multiplier * tier_difference * (upgrade_level + 1);
                out_essence = base_cost * (state->tier_id + 1);
                out_tokens = base_cost / 2;

                return true;
            }

            bool CalculateUpgradeCost(uint32 item_guid, uint8 target_tier,
                                    uint32& out_essence, uint32& out_tokens) override
            {
                UpgradeManager* mgr = GetUpgradeManager();
                ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);

                if (!state || state->tier_id >= target_tier)
                    return false;

                uint8 tier_difference = target_tier - state->tier_id;
                uint8 upgrade_level = state->upgrade_level;

                uint32 base_cost = config.upgrade_cost_multiplier * std::pow(2, tier_difference - 1) * (upgrade_level + 1);
                out_essence = base_cost * (target_tier + 1) * 2;
                out_tokens = base_cost * target_tier;

                return true;
            }

            bool ConvertItemTier(uint32 player_guid, uint32 item_guid, uint8 target_tier) override
            {
                UpgradeManager* mgr = GetUpgradeManager();
                ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);

                if (!state)
                    return false;

                std::string error_message;
                if (!CanConvertTier(item_guid, target_tier, error_message))
                    return false;

                bool is_upgrade = (target_tier > state->tier_id);
                uint32 essence_cost, token_cost;

                if (is_upgrade)
                    CalculateUpgradeCost(item_guid, target_tier, essence_cost, token_cost);
                else
                    CalculateDowngradeCost(item_guid, target_tier, essence_cost, token_cost);

                uint32 season = state->season ? state->season : GetCurrentSeasonId();
                uint32 current_essence = mgr->GetCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, season);
                uint32 current_tokens = mgr->GetCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, season);

                if (current_essence < essence_cost || current_tokens < token_cost)
                    return false;

                float success_rate = GetConversionSuccessRate(state->tier_id, target_tier, state->upgrade_level);
                float roll = frand(0.0f, 1.0f);
                bool success = (roll <= success_rate);

                try
                {
                    mgr->RemoveCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, essence_cost, season);
                    mgr->RemoveCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, token_cost, season);

                    // Sync inventory using centralized utility (full sync, no player available)
                    DarkChaos::CrossSystem::CurrencyUtils::SyncInventoryToDB(
                        player_guid, season, nullptr, CURRENCY_UPGRADE_TOKEN, 0, true);

                    uint8 original_tier = state->tier_id;
                    if (success)
                    {
                        state->tier_id = target_tier;

                        if (is_upgrade)
                        {
                            float level_multiplier = 0.7f;
                            state->upgrade_level = static_cast<uint8>(state->upgrade_level * level_multiplier);
                        }
                        else
                        {
                            uint8 tier_difference = std::abs(state->tier_id - target_tier);
                            uint8 level_bonus = tier_difference * 2;
                            state->upgrade_level = std::min(static_cast<uint8>(MAX_UPGRADE_LEVEL),
                                                          static_cast<uint8>(state->upgrade_level + level_bonus));
                        }

                        state->stat_multiplier = StatScalingCalculator::GetFinalMultiplier(
                            state->upgrade_level, target_tier);
                        mgr->SaveItemUpgrade(item_guid);

                        LOG_INFO("scripts.dc", "ItemUpgrade: Successfully converted item {} from tier {} to tier {} for player {}",
                                item_guid, original_tier, target_tier, player_guid);
                    }
                    else
                    {
                        if (state->upgrade_level > 0)
                        {
                            uint8 level_loss = std::max(static_cast<uint8>(1), static_cast<uint8>(state->upgrade_level / 4));
                            state->upgrade_level = std::max(static_cast<uint8>(0),
                                                          static_cast<uint8>(state->upgrade_level - level_loss));

                            state->stat_multiplier = StatScalingCalculator::GetFinalMultiplier(
                                state->upgrade_level, state->tier_id);
                            mgr->SaveItemUpgrade(item_guid);

                            LOG_INFO("scripts.dc", "ItemUpgrade: Tier conversion failed for item {} - lost {} upgrade levels",
                                    item_guid, level_loss);
                        }
                    }

                    CharacterDatabase.Execute(
                        "INSERT INTO dc_tier_conversion_log "
                        "(player_guid, item_guid, from_tier, to_tier, upgrade_level, success, cost_essence, cost_tokens, timestamp) "
                        "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, UNIX_TIMESTAMP())",
                        player_guid, item_guid, original_tier, target_tier, state->upgrade_level,
                        success ? 1 : 0, essence_cost, token_cost);

                    return success;
                }
                catch (std::exception const& e)
                {
                    LOG_ERROR("scripts.dc", "ItemUpgrade: Tier conversion failed for player {}: {}", player_guid, e.what());
                    return false;
                }
            }

            float GetConversionSuccessRate(uint8 from_tier, uint8 to_tier, uint8 upgrade_level) override
            {
                if (from_tier == to_tier)
                    return 1.0f;

                bool is_upgrade = (to_tier > from_tier);
                uint8 tier_difference = std::abs(to_tier - from_tier);

                float base_rate = is_upgrade ? config.upgrade_success_base_rate : config.downgrade_success_base_rate;
                float tier_penalty = tier_difference * (config.tier_difficulty_modifier / 100.0f);
                float level_bonus = upgrade_level * 0.02f;

                float final_rate = base_rate - tier_penalty + level_bonus;
                return std::max(0.1f, std::min(1.0f, final_rate));
            }

            bool CanConvertTier(uint32 item_guid, uint8 target_tier, std::string& error_message) override
            {
                UpgradeManager* mgr = GetUpgradeManager();
                ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);

                if (!state)
                {
                    error_message = "Item not found in upgrade system.";
                    return false;
                }

                if (state->tier_id == target_tier)
                {
                    error_message = "Item is already at target tier.";
                    return false;
                }

                uint8 tier_difference = std::abs(state->tier_id - target_tier);
                if (tier_difference > config.max_tier_difference)
                {
                    error_message = "Tier difference too large.";
                    return false;
                }

                if (!config.allow_cross_quality_conversion)
                {
                    bool from_high_quality = (state->tier_id >= TIER_HEIRLOOM);
                    bool to_high_quality = (target_tier >= TIER_HEIRLOOM);

                    if (from_high_quality != to_high_quality)
                    {
                        error_message = "Cannot convert across quality boundaries.";
                        return false;
                    }
                }

                if (state->upgrade_level < 3)
                {
                    error_message = "Item must be upgraded at least 3 levels before tier conversion.";
                    return false;
                }

                return true;
            }
        };

        // =====================================================================
        // Singleton Implementations
        // =====================================================================

        static TransmutationManagerImpl* _transmutation_manager = nullptr;
        static TierConversionManagerImpl* _tier_conversion_manager = nullptr;

        TransmutationManager* GetTransmutationManager()
        {
            if (!_transmutation_manager)
                _transmutation_manager = new TransmutationManagerImpl();

            return _transmutation_manager;
        }

        TierConversionManager* GetTierConversionManager()
        {
            if (!_tier_conversion_manager)
                _tier_conversion_manager = new TierConversionManagerImpl();

            return _tier_conversion_manager;
        }

    } // namespace ItemUpgrade
} // namespace DarkChaos
