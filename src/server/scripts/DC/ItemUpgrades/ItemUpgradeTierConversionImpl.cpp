/*
 * DarkChaos Item Upgrade System - Phase 5: Tier Conversion Implementation
 *
 * Implementation of tier conversion mechanics for upgrading/downgrading items.
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#include "ItemUpgradeTransmutation.h"
#include "ItemUpgradeManager.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include <cmath>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Tier Conversion Manager Implementation
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

                // Base cost scales with tier difference and upgrade level
                uint32 base_cost = config.downgrade_cost_multiplier * tier_difference * (upgrade_level + 1);

                // Essence cost (higher for higher tiers)
                out_essence = base_cost * (state->tier_id + 1);

                // Token cost (lower for downgrades)
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

                // Base cost scales exponentially with tier difference
                uint32 base_cost = config.upgrade_cost_multiplier * std::pow(2, tier_difference - 1) * (upgrade_level + 1);

                // Essence cost (very high for upgrades)
                out_essence = base_cost * (target_tier + 1) * 2;

                // Token cost (also high but less than essence)
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

                // Check currency
                uint32 current_essence = mgr->GetCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, 1);
                uint32 current_tokens = mgr->GetCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, 1);

                if (current_essence < essence_cost || current_tokens < token_cost)
                    return false;

                // Calculate success rate
                float success_rate = GetConversionSuccessRate(state->tier_id, target_tier, state->upgrade_level);
                float roll = frand(0.0f, 1.0f);
                bool success = (roll <= success_rate);

                try
                {
                    // Deduct costs
                    mgr->RemoveCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, essence_cost, 1);
                    mgr->RemoveCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, token_cost, 1);

                    if (success)
                    {
                        // Update item tier
                        state->tier_id = target_tier;

                        // Adjust upgrade level based on tier change
                        if (is_upgrade)
                        {
                            // Upgrading: reduce level proportionally
                            float level_multiplier = 0.7f; // Lose some progress when upgrading
                            state->upgrade_level = static_cast<uint8>(state->upgrade_level * level_multiplier);
                        }
                        else
                        {
                            // Downgrading: gain some levels
                            uint8 tier_difference = std::abs(state->tier_id - target_tier);
                            uint8 level_bonus = tier_difference * 2;
                            state->upgrade_level = std::min(static_cast<uint8>(MAX_UPGRADE_LEVEL),
                                                          static_cast<uint8>(state->upgrade_level + level_bonus));
                        }

                        // Recalculate stat multiplier
                        float max_mult = (target_tier == TIER_ARTIFACT) ? STAT_MULTIPLIER_MAX_ARTIFACT : STAT_MULTIPLIER_MAX_REGULAR;
                        state->stat_multiplier = 1.0f + (state->upgrade_level / 5.0f) * (max_mult - 1.0f);

                        // Save changes
                        mgr->SaveItemUpgrade(item_guid);

                        LOG_INFO("scripts", "ItemUpgrade: Successfully converted item {} from tier {} to tier {} for player {}",
                                item_guid, state->tier_id, target_tier, player_guid);
                    }
                    else
                    {
                        // Conversion failed - item might lose some upgrade progress
                        if (state->upgrade_level > 0)
                        {
                            uint8 level_loss = std::max(static_cast<uint8>(1), static_cast<uint8>(state->upgrade_level / 4));
                            state->upgrade_level = std::max(static_cast<uint8>(0),
                                                          static_cast<uint8>(state->upgrade_level - level_loss));

                            // Recalculate stat multiplier
                            float max_mult = (state->tier_id == TIER_ARTIFACT) ? STAT_MULTIPLIER_MAX_ARTIFACT : STAT_MULTIPLIER_MAX_REGULAR;
                            state->stat_multiplier = 1.0f + (state->upgrade_level / 5.0f) * (max_mult - 1.0f);

                            mgr->SaveItemUpgrade(item_guid);

                            LOG_INFO("scripts", "ItemUpgrade: Tier conversion failed for item {} - lost {} upgrade levels",
                                    item_guid, level_loss);
                        }
                    }

                    // Record conversion attempt
                    CharacterDatabase.Execute(
                        "INSERT INTO dc_tier_conversion_log "
                        "(player_guid, item_guid, from_tier, to_tier, upgrade_level, success, cost_essence, cost_tokens, timestamp) "
                        "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, UNIX_TIMESTAMP())",
                        player_guid, item_guid, state->tier_id, target_tier, state->upgrade_level,
                        success ? 1 : 0, essence_cost, token_cost);

                    return success;

                }
                catch (const std::exception& e)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Tier conversion failed for player {}: {}", player_guid, e.what());
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

                // Success rate decreases with tier difference
                float tier_penalty = tier_difference * (config.tier_difficulty_modifier / 100.0f);

                // Success rate increases with upgrade level (experience bonus)
                float level_bonus = upgrade_level * 0.02f; // 2% per upgrade level

                float final_rate = base_rate - tier_penalty + level_bonus;
                return std::max(0.1f, std::min(1.0f, final_rate)); // Clamp between 10% and 100%
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
                    // Check if conversion crosses quality boundaries inappropriately
                    bool from_high_quality = (state->tier_id >= TIER_RAID);
                    bool to_high_quality = (target_tier >= TIER_RAID);

                    if (from_high_quality != to_high_quality)
                    {
                        error_message = "Cannot convert across quality boundaries.";
                        return false;
                    }
                }

                // Check if item has minimum upgrade level for conversion
                if (state->upgrade_level < 3)
                {
                    error_message = "Item must be upgraded at least 3 levels before tier conversion.";
                    return false;
                }

                return true;
            }
        };

        // =====================================================================
        // Synthesis Manager Implementation
        // =====================================================================

        class SynthesisManagerImpl : public SynthesisManager
        {
        private:
            std::map<uint32, TransmutationRecipe> synthesis_recipes;

            struct SynthesisConfig
            {
                uint32 base_success_rate_percent;
                uint32 level_bonus_percent;
                uint32 catalyst_bonus_percent;
                uint32 max_input_items;
                bool require_same_tier;
                uint32 synthesis_cooldown_hours;

                SynthesisConfig() :
                    base_success_rate_percent(60), level_bonus_percent(2),
                    catalyst_bonus_percent(20), max_input_items(5),
                    require_same_tier(true), synthesis_cooldown_hours(24) {}
            } config;

        public:
            SynthesisManagerImpl()
            {
                LoadSynthesisRecipes();
            }

            void LoadSynthesisRecipes()
            {
                LOG_INFO("scripts", "ItemUpgrade: Loading synthesis recipes...");

                // Load synthesis recipes from database
                QueryResult result = WorldDatabase.Query(
                    "SELECT recipe_id, name, description, required_level, input_essence, input_tokens, "
                    "output_item_id, output_upgrade_level, output_tier_id, success_rate FROM dc_synthesis_recipes");

                if (result)
                {
                    uint32 count = 0;
                    do
                    {
                        Field* fields = result->Fetch();
                        TransmutationRecipe recipe;

                        recipe.recipe_id = fields[0].Get<uint32>();
                        recipe.name = fields[1].Get<std::string>();
                        recipe.description = fields[2].Get<std::string>();
                        recipe.type = TRANSMUTATION_SYNTHESIS;
                        recipe.required_level = fields[3].Get<uint32>();
                        recipe.input_essence = fields[4].Get<uint32>();
                        recipe.input_tokens = fields[5].Get<uint32>();
                        recipe.output_item_id = fields[6].Get<uint32>();
                        recipe.output_upgrade_level = fields[7].Get<uint8>();
                        recipe.output_tier_id = fields[8].Get<uint8>();
                        recipe.success_rate = fields[9].Get<float>();

                        synthesis_recipes[recipe.recipe_id] = recipe;
                        count++;
                    } while (result->NextRow());

                    LOG_INFO("scripts", "ItemUpgrade: Loaded {} synthesis recipes", count);
                }
            }

            std::vector<TransmutationRecipe> GetSynthesisRecipes(uint32 player_guid) const override
            {
                std::vector<TransmutationRecipe> available;

                // Get player level
                QueryResult level_result = CharacterDatabase.Query(
                    "SELECT level FROM characters WHERE guid = {}", player_guid);

                if (!level_result)
                    return available;

                uint8 player_level = level_result->Fetch()[0].Get<uint8>();

                for (const auto& [id, recipe] : synthesis_recipes)
                {
                    if (recipe.required_level <= player_level)
                    {
                        available.push_back(recipe);
                    }
                }

                return available;
            }

            bool CheckSynthesisRequirements(uint32 player_guid, uint32 recipe_id,
                                          std::vector<uint32>& required_items,
                                          std::string& error_message) const override
            {
                auto it = synthesis_recipes.find(recipe_id);
                if (it == synthesis_recipes.end())
                {
                    error_message = "Synthesis recipe not found.";
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
                    error_message = "Player level too low for this synthesis.";
                    return false;
                }

                // Check currency requirements
                UpgradeManager* mgr = GetUpgradeManager();
                if (recipe.input_essence > 0)
                {
                    uint32 essence = mgr->GetCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, 1);
                    if (essence < recipe.input_essence)
                    {
                        error_message = "Insufficient artifact essence.";
                        return false;
                    }
                }

                if (recipe.input_tokens > 0)
                {
                    uint32 tokens = mgr->GetCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, 1);
                    if (tokens < recipe.input_tokens)
                    {
                        error_message = "Insufficient upgrade tokens.";
                        return false;
                    }
                }

                // Check cooldown
                QueryResult cooldown_result = CharacterDatabase.Query(
                    "SELECT last_synthesis FROM dc_player_synthesis_cooldowns "
                    "WHERE player_guid = {}", player_guid);

                if (cooldown_result)
                {
                    time_t last_synthesis = cooldown_result->Fetch()[0].Get<time_t>();
                    time_t now = time(nullptr);
                    time_t cooldown_end = last_synthesis + (config.synthesis_cooldown_hours * 3600);

                    if (now < cooldown_end)
                    {
                        uint32 remaining_hours = (cooldown_end - now) / 3600;
                        error_message = "Synthesis on cooldown. " + std::to_string(remaining_hours) + " hours remaining.";
                        return false;
                    }
                }

                // Get required upgraded items
                required_items.clear();
                for (const auto& [item_guid, min_level] : recipe.input_upgrades)
                {
                    QueryResult upgrade_result = CharacterDatabase.Query(
                        "SELECT upgrade_level FROM dc_player_item_upgrades "
                        "WHERE item_guid = {} AND player_guid = {}", item_guid, player_guid);

                    if (!upgrade_result || upgrade_result->Fetch()[0].Get<uint8>() < min_level)
                    {
                        error_message = "Item upgrade level requirement not met.";
                        return false;
                    }

                    required_items.push_back(item_guid);
                }

                if (required_items.size() > config.max_input_items)
                {
                    error_message = "Too many input items required.";
                    return false;
                }

                return true;
            }

            bool PerformSynthesis(uint32 player_guid, uint32 recipe_id, uint32& result_item_guid) override
            {
                std::vector<uint32> required_items;
                std::string error_message;

                if (!CheckSynthesisRequirements(player_guid, recipe_id, required_items, error_message))
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Cannot perform synthesis {} for player {}: {}",
                             recipe_id, player_guid, error_message);
                    return false;
                }

                auto it = synthesis_recipes.find(recipe_id);
                if (it == synthesis_recipes.end())
                    return false;

                const TransmutationRecipe& recipe = it->second;

                // Calculate success rate
                float success_rate = GetSynthesisSuccessRate(recipe_id, player_guid);
                float roll = frand(0.0f, 1.0f);
                bool success = (roll <= success_rate);

                try
                {
                    UpgradeManager* mgr = GetUpgradeManager();

                    // Deduct currencies
                    if (recipe.input_essence > 0)
                        mgr->RemoveCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, recipe.input_essence, 1);
                    if (recipe.input_tokens > 0)
                        mgr->RemoveCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, recipe.input_tokens, 1);

                    if (success)
                    {
                        // Consume input items
                        for (uint32 item_guid : required_items)
                        {
                            // Mark items as consumed (could move to a special container or delete)
                            CharacterDatabase.Execute(
                                "UPDATE dc_player_item_upgrades SET consumed_in_synthesis = 1 "
                                "WHERE item_guid = {} AND player_guid = {}", item_guid, player_guid);
                        }

                        // Create result item (placeholder - would need item creation system integration)
                        result_item_guid = 0; // Would be set by item creation

                        LOG_INFO("scripts", "ItemUpgrade: Synthesis {} succeeded for player {}", recipe_id, player_guid);
                    }
                    else
                    {
                        // Synthesis failed - lose some input items
                        size_t items_to_lose = std::max(size_t(1), required_items.size() / 2);
                        for (size_t i = 0; i < items_to_lose; ++i)
                        {
                            uint32 item_guid = required_items[i];
                            CharacterDatabase.Execute(
                                "UPDATE dc_player_item_upgrades SET consumed_in_synthesis = 1 "
                                "WHERE item_guid = {} AND player_guid = {}", item_guid, player_guid);
                        }

                        LOG_INFO("scripts", "ItemUpgrade: Synthesis {} failed for player {} - lost {} items",
                                recipe_id, player_guid, items_to_lose);
                    }

                    // Update cooldown
                    CharacterDatabase.Execute(
                        "INSERT INTO dc_player_synthesis_cooldowns (player_guid, last_synthesis) "
                        "VALUES ({}, UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE last_synthesis = UNIX_TIMESTAMP()",
                        player_guid);

                    // Record synthesis attempt
                    CharacterDatabase.Execute(
                        "INSERT INTO dc_synthesis_log "
                        "(player_guid, recipe_id, success, input_items_consumed, cost_essence, cost_tokens, timestamp) "
                        "VALUES ({}, {}, {}, {}, {}, {}, UNIX_TIMESTAMP())",
                        player_guid, recipe_id, success ? 1 : 0, static_cast<uint32>(required_items.size()),
                        recipe.input_essence, recipe.input_tokens);

                    return success;

                }
                catch (const std::exception& e)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Synthesis failed for player {}: {}", player_guid, e.what());
                    return false;
                }
            }

            float GetSynthesisSuccessRate(uint32 recipe_id, uint32 player_guid) override
            {
                auto it = synthesis_recipes.find(recipe_id);
                if (it == synthesis_recipes.end())
                    return 0.0f;

                const TransmutationRecipe& recipe = it->second;
                float base_rate = config.base_success_rate_percent / 100.0f;

                // Get player level bonus
                QueryResult level_result = CharacterDatabase.Query(
                    "SELECT level FROM characters WHERE guid = {}", player_guid);

                if (level_result)
                {
                    uint8 player_level = level_result->Fetch()[0].Get<uint8>();
                    float level_bonus = (player_level - recipe.required_level) * (config.level_bonus_percent / 100.0f);
                    base_rate += level_bonus;
                }

                // Catalyst bonus (if applicable)
                if (recipe.requires_catalyst)
                {
                    base_rate += config.catalyst_bonus_percent / 100.0f;
                }

                return std::min(1.0f, base_rate);
            }

            void CalculateSynthesisCost(uint32 recipe_id, uint32& out_essence, uint32& out_tokens) override
            {
                auto it = synthesis_recipes.find(recipe_id);
                if (it == synthesis_recipes.end())
                {
                    out_essence = 0;
                    out_tokens = 0;
                    return;
                }

                const TransmutationRecipe& recipe = it->second;
                out_essence = recipe.input_essence;
                out_tokens = recipe.input_tokens;
            }
        };

        // =====================================================================
        // Singleton Implementations
        // =====================================================================

        static TierConversionManagerImpl* _tier_conversion_manager = nullptr;
        static SynthesisManagerImpl* _synthesis_manager = nullptr;

        TierConversionManager* GetTierConversionManager()
        {
            if (!_tier_conversion_manager)
                _tier_conversion_manager = new TierConversionManagerImpl();

            return _tier_conversion_manager;
        }

        SynthesisManager* GetSynthesisManager()
        {
            if (!_synthesis_manager)
                _synthesis_manager = new SynthesisManagerImpl();

            return _synthesis_manager;
        }

    } // namespace ItemUpgrade
} // namespace DarkChaos