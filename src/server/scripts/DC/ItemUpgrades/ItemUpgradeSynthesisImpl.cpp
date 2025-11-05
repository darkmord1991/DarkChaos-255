/*
 * DarkChaos Item Upgrade System - Phase 5: Synthesis Manager
 *
 * Handles item synthesis recipes, requirements validation, and synthesis
 * execution for combining multiple upgraded items into rare items.
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#include "ItemUpgradeTransmutation.h"
#include "ItemUpgradeManager.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "Item.h"
#include "ObjectMgr.h"
#include <algorithm>
#include <random>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        class SynthesisManagerImpl : public SynthesisManager
        {
        public:
            SynthesisManagerImpl() = default;
            ~SynthesisManagerImpl() override = default;

            bool Initialize() override
            {
                return LoadSynthesisRecipes();
            }

            bool LoadSynthesisRecipes()
            {
                synthesis_recipes_.clear();

                QueryResult result = WorldDatabase.Query(
                    "SELECT recipe_id, name, description, required_level, "
                    "input_essence, input_tokens, output_item_id, output_quantity, "
                    "success_rate_base, cooldown_seconds, required_tier, "
                    "required_upgrade_level, catalyst_item_id, catalyst_quantity "
                    "FROM dc_item_upgrade_synthesis_recipes WHERE active = 1");

                if (!result)
                {
                    // LOG_ERROR("scripts", "ItemUpgrade: No synthesis recipes found in database.");
                    return false;
                }

                do
                {
                    Field* fields = result->Fetch();
                    TransmutationRecipe recipe;

                    recipe.recipe_id = fields[0].Get<uint32>();
                    recipe.name = fields[1].Get<std::string>();
                    recipe.description = fields[2].Get<std::string>();
                    recipe.required_level = fields[3].Get<uint32>();
                    recipe.input_essence = fields[4].Get<uint32>();
                    recipe.input_tokens = fields[5].Get<uint32>();
                    recipe.output_item_id = fields[6].Get<uint32>();
                    recipe.output_quantity = fields[7].Get<uint32>();
                    recipe.success_rate_base = fields[8].Get<float>() / 100.0f; // Convert from percentage
                    recipe.cooldown_seconds = fields[9].Get<uint32>();
                    recipe.required_tier = fields[10].Get<uint8>();
                    recipe.required_upgrade_level = fields[11].Get<uint8>();
                    recipe.catalyst_item_id = fields[12].Get<uint32>();
                    recipe.catalyst_quantity = fields[13].Get<uint32>();

                    // Load input requirements
                    LoadSynthesisInputs(recipe.recipe_id, recipe.input_items);

                    synthesis_recipes_[recipe.recipe_id] = recipe;

                } while (result->NextRow());

                // LOG_INFO("scripts", "ItemUpgrade: Loaded {} synthesis recipes.", synthesis_recipes_.size());
                return true;
            }

            std::vector<TransmutationRecipe> GetSynthesisRecipes(uint32 player_guid) const override
            {
                std::vector<TransmutationRecipe> available_recipes;

                Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(player_guid));
                if (!player)
                    return available_recipes;

                uint32 player_level = player->GetLevel();

                for (const auto& pair : synthesis_recipes_)
                {
                    const TransmutationRecipe& recipe = pair.second;

                    // Check level requirement
                    if (player_level < recipe.required_level)
                        continue;

                    // Check if player has required items (basic check)
                    if (CheckBasicRequirements(player, recipe))
                        available_recipes.push_back(recipe);
                }

                return available_recipes;
            }

            bool CheckSynthesisRequirements(uint32 player_guid, uint32 recipe_id,
                                          std::vector<uint32>& required_items,
                                          std::string& error_message) const override
            {
                Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(player_guid));
                if (!player)
                {
                    error_message = "Player not found.";
                    return false;
                }

                auto recipe_it = synthesis_recipes_.find(recipe_id);
                if (recipe_it == synthesis_recipes_.end())
                {
                    error_message = "Recipe not found.";
                    return false;
                }

                const TransmutationRecipe& recipe = recipe_it->second;

                // Check player level
                if (player->GetLevel() < recipe.required_level)
                {
                    error_message = "Player level too low.";
                    return false;
                }

                // Check currency requirements
                UpgradeManager* mgr = GetUpgradeManager();
                uint32 current_essence = mgr->GetCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, 1);
                uint32 current_tokens = mgr->GetCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, 1);

                if (current_essence < recipe.input_essence)
                {
                    error_message = "Insufficient artifact essence.";
                    return false;
                }

                if (current_tokens < recipe.input_tokens)
                {
                    error_message = "Insufficient upgrade tokens.";
                    return false;
                }

                // Check catalyst item if required
                if (recipe.catalyst_item_id != 0)
                {
                    if (player->GetItemCount(recipe.catalyst_item_id) < recipe.catalyst_quantity)
                    {
                        error_message = "Missing required catalyst item.";
                        return false;
                    }
                }

                // Check input items
                required_items.clear();
                for (const auto& input : recipe.input_items)
                {
                    uint32 count = CountMatchingItems(player, input);
                    if (count < input.quantity)
                    {
                        error_message = "Insufficient input items.";
                        return false;
                    }
                    required_items.push_back(input.item_id);
                }

                // Check cooldown
                if (HasCooldown(player_guid, recipe_id))
                {
                    error_message = "Recipe is on cooldown.";
                    return false;
                }

                return true;
            }

            bool PerformSynthesis(uint32 player_guid, uint32 recipe_id,
                                std::vector<uint32>& consumed_items,
                                bool& success, uint32& output_item_id,
                                uint32& output_quantity) override
            {
                Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(player_guid));
                if (!player)
                    return false;

                auto recipe_it = synthesis_recipes_.find(recipe_id);
                if (recipe_it == synthesis_recipes_.end())
                    return false;

                const TransmutationRecipe& recipe = recipe_it->second;

                // Validate requirements again
                std::vector<uint32> required_items;
                std::string error_message;
                if (!CheckSynthesisRequirements(player_guid, recipe_id, required_items, error_message))
                    return false;

                // Calculate success rate
                float success_rate = GetSynthesisSuccessRate(recipe_id, player_guid);
                success = (urand(0, 10000) / 10000.0f) <= success_rate;

                // Start transaction
                CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();

                try
                {
                    UpgradeManager* mgr = GetUpgradeManager();

                    // Consume currencies
                    if (recipe.input_essence > 0)
                    {
                        if (!mgr->RemoveCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, recipe.input_essence, 1))
                            throw std::runtime_error("Failed to consume essence");
                    }

                    if (recipe.input_tokens > 0)
                    {
                        if (!mgr->RemoveCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, recipe.input_tokens, 1))
                            throw std::runtime_error("Failed to consume tokens");
                    }

                    // Consume catalyst if required
                    if (recipe.catalyst_item_id != 0)
                    {
                        player->DestroyItemCount(recipe.catalyst_item_id, recipe.catalyst_quantity, true);
                    }

                    // Consume input items
                    consumed_items.clear();
                    for (const auto& input : recipe.input_items)
                    {
                        if (!ConsumeItemsForSynthesis(player, input, consumed_items))
                            throw std::runtime_error("Failed to consume input items");
                    }

                    if (success)
                    {
                        // Give output item
                        ItemPosCountVec dest;
                        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, recipe.output_item_id, recipe.output_quantity);
                        if (msg != EQUIP_ERR_OK)
                            throw std::runtime_error("No space for output item");

                        Item* new_item = player->StoreNewItem(dest, recipe.output_item_id, true, 0);
                        if (!new_item)
                            throw std::runtime_error("Failed to create output item");

                        output_item_id = recipe.output_item_id;
                        output_quantity = recipe.output_quantity;
                    }
                    else
                    {
                        // On failure, some input items might be lost based on recipe
                        // For now, we'll keep the consumed items lost
                        output_item_id = 0;
                        output_quantity = 0;
                    }

                    // Set cooldown
                    SetCooldown(player_guid, recipe_id, trans);

                    // Log the synthesis
                    LogSynthesisAttempt(player_guid, recipe_id, success, trans);

                    CharacterDatabase.CommitTransaction(trans);

                    return true;

                }
                catch (const std::exception& e)
                {
                    // LOG_ERROR("scripts", "ItemUpgrade: Synthesis failed: {}", e.what());
                    return false;
                }
            }

            float GetSynthesisSuccessRate(uint32 recipe_id, uint32 player_guid) const override
            {
                auto recipe_it = synthesis_recipes_.find(recipe_id);
                if (recipe_it == synthesis_recipes_.end())
                    return 0.0f;

                const TransmutationRecipe& recipe = recipe_it->second;
                float base_rate = recipe.success_rate_base;

                Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(player_guid));
                if (!player)
                    return base_rate;

                // Apply level bonus (1% per 5 levels above requirement)
                uint32 level_diff = player->GetLevel() - recipe.required_level;
                float level_bonus = (level_diff / 5) * 0.01f;

                // Apply tier bonus (2% per tier above requirement)
                UpgradeManager* mgr = GetUpgradeManager();
                uint8 player_tier = mgr->GetPlayerHighestTier(player_guid);
                uint32 tier_diff = (player_tier > recipe.required_tier) ? (player_tier - recipe.required_tier) : 0;
                float tier_bonus = tier_diff * 0.02f;

                float final_rate = base_rate + level_bonus + tier_bonus;
                return std::min(final_rate, 1.0f);
            }

            bool HasCooldown(uint32 player_guid, uint32 recipe_id) const override
            {
                QueryResult result = CharacterDatabase.Query(
                    "SELECT cooldown_end FROM dc_item_upgrade_synthesis_cooldowns "
                    "WHERE player_guid = {} AND recipe_id = {} AND cooldown_end > UNIX_TIMESTAMP()",
                    player_guid, recipe_id);

                return result != nullptr;
            }

            uint32 GetCooldownRemaining(uint32 player_guid, uint32 recipe_id) const override
            {
                QueryResult result = CharacterDatabase.Query(
                    "SELECT cooldown_end - UNIX_TIMESTAMP() FROM dc_item_upgrade_synthesis_cooldowns "
                    "WHERE player_guid = {} AND recipe_id = {} AND cooldown_end > UNIX_TIMESTAMP()",
                    player_guid, recipe_id);

                if (result)
                {
                    Field* fields = result->Fetch();
                    return fields[0].Get<uint32>();
                }

                return 0;
            }

            void CalculateSynthesisCost(uint32 recipe_id, uint32& out_essence, uint32& out_tokens) override
            {
                auto recipe_it = synthesis_recipes_.find(recipe_id);
                if (recipe_it == synthesis_recipes_.end())
                {
                    out_essence = 0;
                    out_tokens = 0;
                    return;
                }

                const TransmutationRecipe& recipe = recipe_it->second;
                out_essence = recipe.input_essence;
                out_tokens = recipe.input_tokens;
            }

        private:
            void LoadSynthesisInputs(uint32 recipe_id, std::vector<TransmutationInput>& inputs)
            {
                QueryResult result = WorldDatabase.Query(
                    "SELECT item_id, quantity, required_tier, required_upgrade_level "
                    "FROM dc_item_upgrade_synthesis_inputs WHERE recipe_id = {}",
                    recipe_id);

                if (!result)
                    return;

                do
                {
                    Field* fields = result->Fetch();
                    TransmutationInput input;

                    input.item_id = fields[0].Get<uint32>();
                    input.quantity = fields[1].Get<uint32>();
                    input.required_tier = fields[2].Get<uint8>();
                    input.required_upgrade_level = fields[3].Get<uint8>();

                    inputs.push_back(input);

                } while (result->NextRow());
            }

            bool CheckBasicRequirements(Player* player, const TransmutationRecipe& recipe) const
            {
                // Quick check for basic requirements without detailed validation
                UpgradeManager* mgr = GetUpgradeManager();

                // Check currencies
                if (mgr->GetCurrency(player->GetGUID().GetCounter(), CURRENCY_ARTIFACT_ESSENCE, 1) < recipe.input_essence)
                    return false;

                if (mgr->GetCurrency(player->GetGUID().GetCounter(), CURRENCY_UPGRADE_TOKEN, 1) < recipe.input_tokens)
                    return false;

                // Check catalyst
                if (recipe.catalyst_item_id != 0 &&
                    player->GetItemCount(recipe.catalyst_item_id) < recipe.catalyst_quantity)
                    return false;

                // Check input items (basic count check)
                for (const auto& input : recipe.input_items)
                {
                    if (CountMatchingItems(player, input) < input.quantity)
                        return false;
                }

                return true;
            }

            uint32 CountMatchingItems(Player* player, const TransmutationInput& input) const
            {
                uint32 count = 0;

                // Count items in main inventory
                for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
                {
                    Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                    if (!item || item->GetEntry() != input.item_id)
                        continue;

                    // Check if item meets tier/upgrade requirements
                    UpgradeManager* mgr = GetUpgradeManager();
                    ItemUpgradeState* state = mgr->GetItemUpgradeState(item->GetGUID().GetCounter());

                    if (state &&
                        state->tier_id >= input.required_tier &&
                        state->upgrade_level >= input.required_upgrade_level)
                    {
                        count += item->GetCount();
                    }
                }

                // Count items in bags
                for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
                {
                    if (Bag* pBag = player->GetBagByPos(bag))
                    {
                        for (uint32 slot = 0; slot < pBag->GetBagSize(); ++slot)
                        {
                            Item* item = player->GetItemByPos(bag, slot);
                            if (!item || item->GetEntry() != input.item_id)
                                continue;

                            // Check if item meets tier/upgrade requirements
                            UpgradeManager* mgr = GetUpgradeManager();
                            ItemUpgradeState* state = mgr->GetItemUpgradeState(item->GetGUID().GetCounter());

                            if (state &&
                                state->tier_id >= input.required_tier &&
                                state->upgrade_level >= input.required_upgrade_level)
                            {
                                count += item->GetCount();
                            }
                        }
                    }
                }

                return count;
            }

            bool ConsumeItemsForSynthesis(Player* player, const TransmutationInput& input,
                                        std::vector<uint32>& consumed_items)
            {
                uint32 remaining = input.quantity;

                // Consume from main inventory
                for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END && remaining > 0; ++slot)
                {
                    Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                    if (!item || item->GetEntry() != input.item_id)
                        continue;

                    // Check if item meets requirements
                    UpgradeManager* mgr = GetUpgradeManager();
                    ItemUpgradeState* state = mgr->GetItemUpgradeState(item->GetGUID().GetCounter());

                    if (!state ||
                        state->tier_id < input.required_tier ||
                        state->upgrade_level < input.required_upgrade_level)
                        continue;

                    uint32 item_count = item->GetCount();
                    uint32 consume_count = std::min(remaining, item_count);

                    player->DestroyItemCount(item->GetEntry(), consume_count, true, false);

                    consumed_items.push_back(item->GetGUID().GetCounter());
                    remaining -= consume_count;
                }

                // Consume from bags
                for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END && remaining > 0; ++bag)
                {
                    if (Bag* pBag = player->GetBagByPos(bag))
                    {
                        for (uint32 slot = 0; slot < pBag->GetBagSize() && remaining > 0; ++slot)
                        {
                            Item* item = player->GetItemByPos(bag, slot);
                            if (!item || item->GetEntry() != input.item_id)
                                continue;

                            // Check if item meets requirements
                            UpgradeManager* mgr = GetUpgradeManager();
                            ItemUpgradeState* state = mgr->GetItemUpgradeState(item->GetGUID().GetCounter());

                            if (!state ||
                                state->tier_id < input.required_tier ||
                                state->upgrade_level < input.required_upgrade_level)
                                continue;

                            uint32 item_count = item->GetCount();
                            uint32 consume_count = std::min(remaining, item_count);

                            player->DestroyItemCount(item->GetEntry(), consume_count, true, false);

                            consumed_items.push_back(item->GetGUID().GetCounter());
                            remaining -= consume_count;
                        }
                    }
                }

                return remaining == 0;
            }

            void SetCooldown(uint32 player_guid, uint32 recipe_id, CharacterDatabaseTransaction& trans)
            {
                auto recipe_it = synthesis_recipes_.find(recipe_id);
                if (recipe_it == synthesis_recipes_.end())
                    return;

                uint32 cooldown_end = time(nullptr) + recipe_it->second.cooldown_seconds;

                trans->Append(
                    "INSERT INTO dc_item_upgrade_synthesis_cooldowns (player_guid, recipe_id, cooldown_end) "
                    "VALUES ({}, {}, {}) ON DUPLICATE KEY UPDATE cooldown_end = VALUES(cooldown_end)",
                    player_guid, recipe_id, cooldown_end);
            }

            void LogSynthesisAttempt(uint32 player_guid, uint32 recipe_id, bool success,
                                   CharacterDatabaseTransaction& trans)
            {
                trans->Append(
                    "INSERT INTO dc_item_upgrade_synthesis_log (player_guid, recipe_id, success, attempt_time) "
                    "VALUES ({}, {}, {}, UNIX_TIMESTAMP())",
                    player_guid, recipe_id, success ? 1 : 0);
            }

        private:
            std::unordered_map<uint32, TransmutationRecipe> synthesis_recipes_;
        };

        // =====================================================================
        // Global Access
        // =====================================================================

        SynthesisManager* GetSynthesisManager()
        {
            static SynthesisManagerImpl instance;
            return &instance;
        }

    } // namespace ItemUpgrade
} // namespace DarkChaos