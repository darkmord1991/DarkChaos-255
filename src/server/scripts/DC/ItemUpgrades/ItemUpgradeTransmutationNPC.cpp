/*
 * DarkChaos Item Upgrade System - Phase 5: Transmutation NPC
 *
 * NPC interface for the transmutation system allowing players to convert
 * item tiers, exchange currencies, and perform synthesis.
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#include "ItemUpgradeTransmutation.h"
#include "ItemUpgradeManager.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "GossipDef.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include <sstream>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        class ItemUpgradeTransmutationNPC : public CreatureScript
        {
        public:
            ItemUpgradeTransmutationNPC() : CreatureScript("ItemUpgradeTransmutationNPC") { }

            bool OnGossipHello(Player* player, Creature* creature) override
            {
                ClearGossipMenuFor(player);

                std::ostringstream oss;
                oss << "|cffffd700===== Transmutation Master =====|r\n\n";
                oss << "|cff00ff00Welcome, " << player->GetName() << "!|r\n";
                oss << "I can help you transform your upgraded items.\n\n";
                oss << "|cff00ff00Available Services:|r\n";

                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Tier Conversion", GOSSIP_SENDER_MAIN, 1);
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Currency Exchange", GOSSIP_SENDER_MAIN, 2);
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Item Synthesis", GOSSIP_SENDER_MAIN, 3);
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Transmutation Status", GOSSIP_SENDER_MAIN, 4);
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Help & Information", GOSSIP_SENDER_MAIN, 5);

                player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
                SendGossipMenuFor(player, 1, creature->GetGUID());

                return true;
            }

            bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
            {
                ClearGossipMenuFor(player);

                switch (action)
                {
                    case 1: // Tier Conversion
                        ShowTierConversionMenu(player, creature);
                        break;
                    case 2: // Currency Exchange
                        ShowCurrencyExchangeMenu(player, creature);
                        break;
                    case 3: // Item Synthesis
                        ShowSynthesisMenu(player, creature);
                        break;
                    case 4: // Transmutation Status
                        ShowTransmutationStatus(player, creature);
                        break;
                    case 5: // Help & Information
                        ShowHelpInformation(player, creature);
                        break;
                    default:
                        OnGossipHello(player, creature);
                        break;
                }

                return true;
            }

            void ShowTierConversionMenu(Player* player, Creature* creature)
            {
                std::ostringstream oss;
                oss << "|cffffd700===== Tier Conversion =====|r\n\n";
                oss << "|cff00ff00Tier Conversion allows you to change an item's tier:|r\n";
                oss << "• |cff00ff00Downgrade|r: Higher tier → Lower tier (safer, cheaper)\n";
                oss << "• |cffff8000Upgrade|r: Lower tier → Higher tier (risky, expensive)\n\n";
                oss << "|cff00ff00Requirements:|r\n";
                oss << "• Item must be upgraded at least 3 levels\n";
                oss << "• Sufficient currency for conversion\n";
                oss << "• Success rate varies by tier difference\n\n";

                // Show available upgradeable items
                UpgradeManager* mgr = GetUpgradeManager();
                bool has_items = false;

                for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
                {
                    Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                    if (!item)
                        continue;

                    ItemUpgradeState* state = mgr->GetItemUpgradeState(item->GetGUID().GetCounter());
                    if (state && state->upgrade_level >= 3)
                    {
                        ItemTemplate const* proto = item->GetTemplate();
                        std::string item_name = proto ? proto->Name1 : "Unknown Item";

                        std::ostringstream item_display;
                        item_display << "[EQUIPPED] " << item_name << " (Tier " << static_cast<int>(state->tier_id)
                                   << ", Level " << static_cast<int>(state->upgrade_level) << ")";

                        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, item_display.str(),
                                       GOSSIP_SENDER_MAIN, 1000 + item->GetGUID().GetCounter());
                        has_items = true;
                    }
                }

                if (!has_items)
                {
                    oss << "|cffff0000No eligible items found.|r\n";
                    oss << "You need items upgraded at least 3 levels.\n";
                }

                player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
                AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 0);
                SendGossipMenuFor(player, 1, creature->GetGUID());
            }

            void ShowCurrencyExchangeMenu(Player* player, Creature* creature)
            {
                TransmutationManager* transMgr = GetTransmutationManager();
                uint32 tokens_to_essence_rate, essence_to_tokens_rate;
                transMgr->GetExchangeRates(tokens_to_essence_rate, essence_to_tokens_rate);

                UpgradeManager* mgr = GetUpgradeManager();
                uint32 current_essence = mgr->GetCurrency(player->GetGUID().GetCounter(), CURRENCY_ARTIFACT_ESSENCE, 1);
                uint32 current_tokens = mgr->GetCurrency(player->GetGUID().GetCounter(), CURRENCY_UPGRADE_TOKEN, 1);

                std::ostringstream oss;
                oss << "|cffffd700===== Currency Exchange =====|r\n\n";
                oss << "|cff00ff00Current Balances:|r\n";
                oss << "  Artifact Essence: " << current_essence << "\n";
                oss << "  Upgrade Tokens: " << current_tokens << "\n\n";

                oss << "|cff00ff00Exchange Rates:|r\n";
                oss << "  " << tokens_to_essence_rate << " Tokens → 1 Essence (favorable)\n";
                oss << "  1 Essence → " << essence_to_tokens_rate << " Token (unfavorable)\n\n";

                oss << "|cff00ff00Exchange Options:|r\n";

                // Show exchange options if player has currency
                if (current_tokens >= tokens_to_essence_rate)
                {
                    AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG,
                                   "Exchange Tokens → Essence", GOSSIP_SENDER_MAIN, 2001);
                }

                if (current_essence >= 1)
                {
                    AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG,
                                   "Exchange Essence → Tokens", GOSSIP_SENDER_MAIN, 2002);
                }

                if (current_tokens < tokens_to_essence_rate && current_essence < 1)
                {
                    oss << "|cffff0000Insufficient currency for exchange.|r\n";
                }

                player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
                AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 0);
                SendGossipMenuFor(player, 1, creature->GetGUID());
            }

            void ShowSynthesisMenu(Player* player, Creature* creature)
            {
                std::ostringstream oss;
                oss << "|cffffd700===== Item Synthesis =====|r\n\n";
                oss << "|cff00ff00Synthesis allows you to combine multiple upgraded items|r\n";
                oss << "|cff00ff00into rare or unique items with special properties.|r\n\n";

                oss << "|cff00ff00Requirements:|r\n";
                oss << "• Multiple upgraded items of same tier\n";
                oss << "• Sufficient currency for synthesis\n";
                oss << "• Synthesis catalyst (if required)\n\n";

                SynthesisManager* synthMgr = GetSynthesisManager();
                auto recipes = synthMgr->GetSynthesisRecipes(player->GetGUID().GetCounter());

                if (recipes.empty())
                {
                    oss << "|cffff0000No synthesis recipes available.|r\n";
                    oss << "You may not meet the level requirements.\n";
                }
                else
                {
                    oss << "|cff00ff00Available Recipes:|r\n";
                    for (size_t i = 0; i < recipes.size() && i < 10; ++i)
                    {
                        const auto& recipe = recipes[i];
                        std::ostringstream recipe_display;
                        recipe_display << recipe.name << " (Level " << recipe.required_level << ")";

                        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, recipe_display.str(),
                                       GOSSIP_SENDER_MAIN, 3000 + recipe.recipe_id);
                    }
                }

                player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
                AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 0);
                SendGossipMenuFor(player, 1, creature->GetGUID());
            }

            void ShowTransmutationStatus(Player* player, Creature* creature)
            {
                TransmutationManager* transMgr = GetTransmutationManager();
                TransmutationSession session = transMgr->GetTransmutationStatus(player->GetGUID().GetCounter());

                std::ostringstream oss;
                oss << "|cffffd700===== Transmutation Status =====|r\n\n";

                if (session.completed)
                {
                    oss << "|cff00ff00Last Transmutation Result:|r\n";
                    oss << "  Recipe ID: " << session.recipe_id << "\n";
                    oss << "  Status: " << (session.success ? "|cff00ff00SUCCESS|r" : "|cffff0000FAILED|r") << "\n";
                    oss << "  Completed: " << std::ctime(&session.end_time);
                }
                else if (session.player_guid != 0)
                {
                    time_t now = time(nullptr);
                    time_t remaining = session.end_time - now;

                    oss << "|cff00ff00Active Transmutation:|r\n";
                    oss << "  Recipe ID: " << session.recipe_id << "\n";
                    oss << "  Time Remaining: " << (remaining > 0 ? std::to_string(remaining) : "0") << " seconds\n";
                    oss << "  Started: " << std::ctime(&session.start_time);

                    AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Cancel Transmutation",
                                   GOSSIP_SENDER_MAIN, 4001);
                }
                else
                {
                    oss << "|cffff0000No active transmutations.|r\n";
                }

                // Show statistics
                auto stats = transMgr->GetPlayerStatistics(player->GetGUID().GetCounter());
                if (!stats.empty())
                {
                    oss << "\n|cff00ff00Your Statistics:|r\n";
                    oss << "  Total Transmutations: " << stats["total_transmutations"] << "\n";
                    oss << "  Successful: " << stats["successful_transmutations"] << "\n";
                    oss << "  Failed: " << stats["failed_transmutations"] << "\n";

                    if (stats["total_transmutations"] > 0)
                    {
                        float success_rate = (static_cast<float>(stats["successful_transmutations"]) /
                                            stats["total_transmutations"]) * 100.0f;
                        oss << "  Success Rate: " << std::fixed << std::setprecision(1) << success_rate << "%\n";
                    }
                }

                player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
                AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 0);
                SendGossipMenuFor(player, 1, creature->GetGUID());
            }

            void ShowHelpInformation(Player* player, Creature* creature)
            {
                std::ostringstream oss;
                oss << "|cffffd700===== Transmutation Help =====|r\n\n";

                oss << "|cff00ff00Tier Conversion:|r\n";
                oss << "• Change item tier up or down\n";
                oss << "• Downgrades are safer but cost resources\n";
                oss << "• Upgrades are risky but gain power\n";
                oss << "• Success rate depends on tier difference\n\n";

                oss << "|cff00ff00Currency Exchange:|r\n";
                oss << "• Convert between Tokens and Essence\n";
                oss << "• Exchange rates include fees\n";
                oss << "• Useful for balancing currencies\n\n";

                oss << "|cff00ff00Item Synthesis:|r\n";
                oss << "• Combine multiple items into rare ones\n";
                oss << "• Requires specific item combinations\n";
                oss << "• Can create unique items\n\n";

                oss << "|cff00ff00Risks & Rewards:|r\n";
                oss << "• Failed conversions may lose progress\n";
                oss << "• Synthesis can destroy input items\n";
                oss << "• Success rates improve with level\n\n";

                oss << "|cffff0000Warning:|r\n";
                oss << "Transmutation cannot be undone!\n";
                oss << "Make sure you understand the risks.\n";

                player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
                AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 0);
                SendGossipMenuFor(player, 1, creature->GetGUID());
            }

            bool OnGossipSelectCode(Player* player, Creature* creature, uint32 sender,
                                  uint32 action, const char* code) override
            {
                ClearGossipMenuFor(player);

                // Handle item-specific actions
                if (action >= 1000 && action < 2000)
                {
                    uint32 item_guid = action - 1000;
                    ShowItemTierConversionOptions(player, creature, item_guid);
                }
                else if (action >= 2000 && action < 3000)
                {
                    // Currency exchange actions
                    HandleCurrencyExchange(player, creature, action - 2000);
                }
                else if (action >= 3000 && action < 4000)
                {
                    uint32 recipe_id = action - 3000;
                    ShowSynthesisRecipeDetails(player, creature, recipe_id);
                }
                else if (action >= 4000 && action < 5000)
                {
                    // Status actions
                    HandleStatusAction(player, creature, action - 4000);
                }

                return true;
            }

        private:
            void ShowItemTierConversionOptions(Player* player, Creature* creature, uint32 item_guid)
            {
                UpgradeManager* mgr = GetUpgradeManager();
                ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);

                if (!state)
                {
                    SendErrorMessage(player, "Item not found.");
                    return;
                }

                TierConversionManager* tierMgr = GetTierConversionManager();

                std::ostringstream oss;
                oss << "|cffffd700===== Tier Conversion Options =====|r\n\n";

                // Show current item info
                oss << "|cff00ff00Current Item:|r\n";
                oss << "  Tier: " << static_cast<int>(state->tier_id) << "\n";
                oss << "  Upgrade Level: " << static_cast<int>(state->upgrade_level) << "\n";
                oss << "  Success Rate Base: " << std::fixed << std::setprecision(1)
                    << (tierMgr->GetConversionSuccessRate(state->tier_id, state->tier_id, state->upgrade_level) * 100) << "%\n\n";

                // Show downgrade options
                if (state->tier_id > 1)
                {
                    oss << "|cff00ff00Downgrade Options:|r\n";
                    for (uint8 target_tier = state->tier_id - 1; target_tier >= 1 && target_tier >= state->tier_id - 2; --target_tier)
                    {
                        uint32 essence_cost, token_cost;
                        if (tierMgr->CalculateDowngradeCost(item_guid, target_tier, essence_cost, token_cost))
                        {
                            float success_rate = tierMgr->GetConversionSuccessRate(state->tier_id, target_tier, state->upgrade_level);

                            std::ostringstream option_text;
                            option_text << "Downgrade to Tier " << static_cast<int>(target_tier)
                                       << " (" << essence_cost << " Ess, " << token_cost << " Tok, "
                                       << std::fixed << std::setprecision(1) << (success_rate * 100) << "% success)";

                            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, option_text.str(),
                                           GOSSIP_SENDER_MAIN, 5000 + (target_tier * 100) + item_guid);
                        }
                    }
                }

                // Show upgrade options
                if (state->tier_id < 5)
                {
                    oss << "\n|cffff8000Upgrade Options (RISKY):|r\n";
                    for (uint8 target_tier = state->tier_id + 1; target_tier <= state->tier_id + 2 && target_tier <= 5; ++target_tier)
                    {
                        uint32 essence_cost, token_cost;
                        if (tierMgr->CalculateUpgradeCost(item_guid, target_tier, essence_cost, token_cost))
                        {
                            float success_rate = tierMgr->GetConversionSuccessRate(state->tier_id, target_tier, state->upgrade_level);

                            std::ostringstream option_text;
                            option_text << "Upgrade to Tier " << static_cast<int>(target_tier)
                                       << " (" << essence_cost << " Ess, " << token_cost << " Tok, "
                                       << std::fixed << std::setprecision(1) << (success_rate * 100) << "% success)";

                            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, option_text.str(),
                                           GOSSIP_SENDER_MAIN, 6000 + (target_tier * 100) + item_guid);
                        }
                    }
                }

                player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
                AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 1);
                SendGossipMenuFor(player, 1, creature->GetGUID());
            }

            void HandleCurrencyExchange(Player* player, Creature* creature, uint32 exchange_type)
            {
                TransmutationManager* transMgr = GetTransmutationManager();
                bool success = false;

                if (exchange_type == 1) // Tokens to Essence
                {
                    success = transMgr->ExchangeCurrency(player->GetGUID().GetCounter(), true, 1);
                    if (success)
                        ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Currency exchange successful!|r");
                    else
                        ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Currency exchange failed.|r");
                }
                else if (exchange_type == 2) // Essence to Tokens
                {
                    success = transMgr->ExchangeCurrency(player->GetGUID().GetCounter(), false, 1);
                    if (success)
                        ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Currency exchange successful!|r");
                    else
                        ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Currency exchange failed.|r");
                }

                // Return to exchange menu
                ShowCurrencyExchangeMenu(player, creature);
            }

            void ShowSynthesisRecipeDetails(Player* player, Creature* creature, uint32 recipe_id)
            {
                SynthesisManager* synthMgr = GetSynthesisManager();
                auto recipes = synthMgr->GetSynthesisRecipes(player->GetGUID().GetCounter());

                TransmutationRecipe* selected_recipe = nullptr;
                for (auto& recipe : recipes)
                {
                    if (recipe.recipe_id == recipe_id)
                    {
                        selected_recipe = &recipe;
                        break;
                    }
                }

                if (!selected_recipe)
                {
                    SendErrorMessage(player, "Recipe not found.");
                    return;
                }

                std::ostringstream oss;
                oss << "|cffffd700===== " << selected_recipe->name << " =====|r\n\n";
                oss << "|cff00ff00" << selected_recipe->description << "|r\n\n";

                oss << "|cff00ff00Requirements:|r\n";
                if (selected_recipe->input_essence > 0)
                    oss << "  Essence: " << selected_recipe->input_essence << "\n";
                if (selected_recipe->input_tokens > 0)
                    oss << "  Tokens: " << selected_recipe->input_tokens << "\n";

                oss << "\n|cff00ff00Success Rate: " << std::fixed << std::setprecision(1)
                    << (synthMgr->GetSynthesisSuccessRate(recipe_id, player->GetGUID().GetCounter()) * 100) << "%|r\n\n";

                // Check if requirements are met
                std::vector<uint32> required_items;
                std::string error_message;
                bool can_perform = synthMgr->CheckSynthesisRequirements(player->GetGUID().GetCounter(),
                                                                       recipe_id, required_items, error_message);

                if (can_perform)
                {
                    oss << "|cff00ff00You can perform this synthesis!|r\n";
                    AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "PERFORM SYNTHESIS",
                                   GOSSIP_SENDER_MAIN, 7000 + recipe_id);
                }
                else
                {
                    oss << "|cffff0000Cannot perform synthesis:|r\n";
                    oss << error_message << "\n";
                }

                player->PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, 0, oss.str().c_str(), 0, 0, "", true);
                AddGossipItemFor(player, GOSSIP_ICON_TALK, "Back", GOSSIP_SENDER_MAIN, 3);
                SendGossipMenuFor(player, 1, creature->GetGUID());
            }

            void HandleStatusAction(Player* player, Creature* creature, uint32 action_type)
            {
                if (action_type == 1) // Cancel transmutation
                {
                    TransmutationManager* transMgr = GetTransmutationManager();
                    bool success = transMgr->CancelTransmutation(player->GetGUID().GetCounter());

                    if (success)
                        ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Transmutation cancelled.|r");
                    else
                        ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Failed to cancel transmutation.|r");
                }

                // Return to status menu
                ShowTransmutationStatus(player, creature);
            }

            void SendErrorMessage(Player* player, const char* message)
            {
                if (player && message)
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("%s", "|cffff0000[Transmutation Error]|r ");
                    ChatHandler(player->GetSession()).SendSysMessage(message);
                }
            }
        };

        // =====================================================================
        // Registration
        // =====================================================================

        void AddSC_ItemUpgradeTransmutation()
        {
            new ItemUpgradeTransmutationNPC();
        }

    } // namespace ItemUpgrade
} // namespace DarkChaos