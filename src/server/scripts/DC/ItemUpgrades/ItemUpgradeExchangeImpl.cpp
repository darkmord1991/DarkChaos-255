/*
 * DarkChaos Item Upgrade System - Currency Exchange Implementation
 *
 * Implementation of currency exchange between Upgrade Tokens and Artifact Essence.
 * Synthesis system removed (Jan 2026).
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 * Updated: January 2026 - Renamed from Transmutation, removed synthesis
 */

#include "ItemUpgradeExchange.h"
#include "ItemUpgradeManager.h"
#include "DC/CrossSystem/SeasonResolver.h"
#include "../CrossSystem/CrossSystemUtilities.h"
#include "Player.h"
#include "Item.h"
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
                uint32 currency_exchange_fee_percent;
                uint32 synthesis_base_cost_essence;
                uint32 synthesis_base_cost_tokens;
                bool allow_partial_refunds;
                uint32 max_concurrent_transmutations;

                TransmutationConfig() :
                    base_cooldown_seconds(3600), tier_downgrade_success_rate(0.95f),
                    tier_upgrade_success_rate(0.75f), currency_exchange_fee_percent(5),
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
            // Currency exchange uses hardcoded rates (see GetExchangeRates)

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

                const TransmutationRecipe& recipe = it->second;

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

                const TransmutationRecipe& recipe = it->second;

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
                catch (const std::exception& e)
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

                const TransmutationSession& session = it->second;
                if (session.completed)
                    return false;

                auto recipe_it = recipes.find(session.recipe_id);
                if (recipe_it == recipes.end())
                    return false;

                const TransmutationRecipe& recipe = recipe_it->second;

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
                catch (const std::exception& e)
                {
                    LOG_ERROR("scripts.dc", "ItemUpgrade: Failed to cancel transmutation for player {}: {}", player_guid, e.what());
                    return false;
                }
            }

            void GetExchangeRates(uint32& tokens_to_essence_rate, uint32& essence_to_tokens_rate) override
            {
                // Base exchange rate: 1 essence = 2 tokens
                tokens_to_essence_rate = 2;
                essence_to_tokens_rate = 1;
            }

            bool ExchangeCurrency(uint32 player_guid, bool tokens_to_essence, uint32 amount) override
            {
                if (amount == 0)
                {
                    LOG_ERROR("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - amount is 0 for player {}", player_guid);
                    return false;
                }

                // Find the player
                Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(player_guid));
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
                LOG_DEBUG("scripts.dc", "ItemUpgrade: ExchangeCurrency - player {} amount {} tokens_to_essence {}",
                          player_guid, amount, tokens_to_essence);

                try
                {
                    uint32 exchange_rate, fee_amount, final_amount;

                    if (tokens_to_essence)
                    {
                        // Tokens to Essence: 2 tokens = 1 essence
                        exchange_rate = 2;
                        uint32 required_tokens = amount * exchange_rate;
                        fee_amount = required_tokens * config.currency_exchange_fee_percent / 100;
                        final_amount = amount;

                        uint32 total_needed = required_tokens + fee_amount;
                        uint32 current_tokens = mgr->GetCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, season);

                        LOG_DEBUG("scripts.dc", "ItemUpgrade: Tokens->Essence: current {} required {} fee {} total_needed {}",
                                  current_tokens, required_tokens, fee_amount, total_needed);

                        if (current_tokens < total_needed)
                        {
                            LOG_WARN("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - insufficient tokens ({} < {}) for player {}",
                                     current_tokens, total_needed, player_guid);
                            return false;
                        }

                        // Update DB-backed currency only
                        mgr->RemoveCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, total_needed, season);
                        mgr->AddCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, final_amount, season);
                    }
                    else
                    {
                        // Essence to Tokens: 1 essence = 1 token
                        exchange_rate = 1;
                        uint32 required_essence = amount * exchange_rate;
                        fee_amount = required_essence * config.currency_exchange_fee_percent / 100;
                        final_amount = amount;

                        uint32 total_needed = required_essence + fee_amount;
                        uint32 current_essence = mgr->GetCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, season);

                        LOG_DEBUG("scripts.dc", "ItemUpgrade: Essence->Tokens: current {} required {} fee {} total_needed {}",
                                  current_essence, required_essence, fee_amount, total_needed);

                        if (current_essence < total_needed)
                        {
                            LOG_WARN("scripts.dc", "ItemUpgrade: ExchangeCurrency failed - insufficient essence ({} < {}) for player {}",
                                     current_essence, total_needed, player_guid);
                            return false;
                        }

                        // Update DB-backed currency only
                        mgr->RemoveCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, total_needed, season);
                        mgr->AddCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, final_amount, season);
                    }

                    LOG_INFO("scripts.dc", "ItemUpgrade: Player {} exchanged {} {} for {} {} (fee: {})",
                            player_guid, amount, tokens_to_essence ? "tokens" : "essence",
                            final_amount, tokens_to_essence ? "essence" : "tokens", fee_amount);

                    return true;
                }
                catch (const std::exception& e)
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

                const TransmutationRecipe& recipe = recipe_it->second;

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
                catch (const std::exception& e)
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

                        float max_mult = (target_tier == TIER_HEIRLOOM) ? STAT_MULTIPLIER_MAX_HEIRLOOM : STAT_MULTIPLIER_MAX_REGULAR;
                        state->stat_multiplier = 1.0f + (state->upgrade_level / 5.0f) * (max_mult - 1.0f);
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

                            float max_mult = (state->tier_id == TIER_HEIRLOOM) ? STAT_MULTIPLIER_MAX_HEIRLOOM : STAT_MULTIPLIER_MAX_REGULAR;
                            state->stat_multiplier = 1.0f + (state->upgrade_level / 5.0f) * (max_mult - 1.0f);
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
                catch (const std::exception& e)
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
