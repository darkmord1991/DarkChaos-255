/*
 * DarkChaos Item Upgrade System - Phase 5: Item Transmutation
 *
 * Item Transmutation allows players to convert upgraded items between tiers,
 * exchange currencies, and synthesize rare items from common upgrades.
 *
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#ifndef ITEM_UPGRADE_TRANSMUTATION_H
#define ITEM_UPGRADE_TRANSMUTATION_H

#include "ItemUpgradeManager.h"
#include <vector>
#include <map>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Transmutation Types and Configurations
        // =====================================================================

        /**
         * Transmutation recipe types
         */
        enum TransmutationType
        {
            TRANSMUTATION_TIER_DOWNGRADE = 1,    // Convert higher tier item to lower tier
            TRANSMUTATION_TIER_UPGRADE = 2,      // Convert lower tier item to higher tier (rare)
            TRANSMUTATION_CURRENCY_EXCHANGE = 3, // Exchange tokens for essence or vice versa
            TRANSMUTATION_SYNTHESIS = 4,         // Combine multiple items into one rare item
            TRANSMUTATION_REFINEMENT = 5         // Refine materials into higher quality
        };

        /**
         * Transmutation input item requirements
         */
        struct TransmutationInput
        {
            uint32 item_id;
            uint32 quantity;
            uint8 required_tier;
            uint8 required_upgrade_level;

            TransmutationInput() :
                item_id(0), quantity(0), required_tier(1), required_upgrade_level(0) {}
        };

        /**
         * Transmutation recipe configuration
         */
        struct TransmutationRecipe
        {
            uint32 recipe_id;
            TransmutationType type;
            std::string name;
            std::string description;
            uint32 required_level;              // Minimum player level
            uint8 required_tier;                // Minimum item tier requirement
            uint8 required_upgrade_level;       // Minimum upgrade level requirement
            uint32 cooldown_seconds;            // Cooldown between uses

            // Input requirements
            std::vector<TransmutationInput> input_items;  // Input items with tier/upgrade requirements
            std::map<uint32, uint8> input_upgrades;       // item_guid -> minimum upgrade level
            uint32 input_essence;
            uint32 input_tokens;

            // Output results
            uint32 output_item_id;
            uint8 output_upgrade_level;
            uint8 output_tier_id;
            uint32 output_essence;
            uint32 output_tokens;
            uint32 output_quantity;             // Quantity of output item

            // Success rates and costs
            float success_rate_base;            // Base success rate (0.0 to 1.0)
            uint32 failure_penalty_percent;     // Percentage of inputs lost on failure
            bool requires_catalyst;             // Special item required
            uint32 catalyst_item_id;
            uint32 catalyst_quantity;

            TransmutationRecipe() :
                recipe_id(0), type(TRANSMUTATION_TIER_DOWNGRADE), required_level(1),
                required_tier(1), required_upgrade_level(0), cooldown_seconds(3600),
                input_essence(0), input_tokens(0), output_item_id(0), output_upgrade_level(0), output_tier_id(1),
                output_essence(0), output_tokens(0), output_quantity(1),
                success_rate_base(1.0f), failure_penalty_percent(0), requires_catalyst(false),
                catalyst_item_id(0), catalyst_quantity(0) {}
        };

        /**
         * Transmutation session data
         */
        struct TransmutationSession
        {
            uint32 player_guid;
            uint32 recipe_id;
            time_t start_time;
            time_t end_time;
            bool completed;
            bool success;
            std::vector<uint32> consumed_items;  // Item GUIDs consumed

            TransmutationSession() :
                player_guid(0), recipe_id(0), start_time(0), end_time(0),
                completed(false), success(false) {}
        };

        // =====================================================================
        // Transmutation Manager Interface
        // =====================================================================

        /**
         * Manages item transmutation operations
         */
        class TransmutationManager
        {
        public:
            virtual ~TransmutationManager() = default;

            /**
             * Get all available recipes for a player
             */
            virtual std::vector<TransmutationRecipe> GetAvailableRecipes(uint32 player_guid) = 0;

            /**
             * Check if player can perform a specific transmutation
             */
            virtual bool CanPerformTransmutation(uint32 player_guid, uint32 recipe_id, std::string& error_message) = 0;

            /**
             * Start a transmutation process
             */
            virtual bool StartTransmutation(uint32 player_guid, uint32 recipe_id) = 0;

            /**
             * Check transmutation progress/results
             */
            virtual TransmutationSession GetTransmutationStatus(uint32 player_guid) = 0;

            /**
             * Cancel an ongoing transmutation
             */
            virtual bool CancelTransmutation(uint32 player_guid) = 0;

            /**
             * Get currency exchange rates
             */
            virtual void GetExchangeRates(uint32& tokens_to_essence_rate, uint32& essence_to_tokens_rate) = 0;

            /**
             * Perform currency exchange
             */
            virtual bool ExchangeCurrency(uint32 player_guid, bool tokens_to_essence, uint32 amount) = 0;

            /**
             * Get player's transmutation statistics
             */
            virtual std::map<std::string, uint32> GetPlayerStatistics(uint32 player_guid) = 0;
        };

        // =====================================================================
        // Tier Conversion System
        // =====================================================================

        /**
         * Manages tier conversion operations
         */
        class TierConversionManager
        {
        public:
            virtual ~TierConversionManager() = default;

            /**
             * Calculate downgrade cost (higher tier -> lower tier)
             */
            virtual bool CalculateDowngradeCost(uint32 item_guid, uint8 target_tier,
                                              uint32& out_essence, uint32& out_tokens) = 0;

            /**
             * Calculate upgrade cost (lower tier -> higher tier)
             */
            virtual bool CalculateUpgradeCost(uint32 item_guid, uint8 target_tier,
                                            uint32& out_essence, uint32& out_tokens) = 0;

            /**
             * Perform tier conversion
             */
            virtual bool ConvertItemTier(uint32 player_guid, uint32 item_guid, uint8 target_tier) = 0;

            /**
             * Get conversion success rate
             */
            virtual float GetConversionSuccessRate(uint8 from_tier, uint8 to_tier, uint8 upgrade_level) = 0;

            /**
             * Check if tier conversion is possible
             */
            virtual bool CanConvertTier(uint32 item_guid, uint8 target_tier, std::string& error_message) = 0;
        };

        // =====================================================================
        // Synthesis System
        // =====================================================================

        /**
         * Manages item synthesis operations
         */
        class SynthesisManager
        {
        public:
            virtual ~SynthesisManager() = default;

            /**
             * Initialize the synthesis manager
             */
            virtual bool Initialize() = 0;

            /**
             * Get available synthesis recipes
             */
            virtual std::vector<TransmutationRecipe> GetSynthesisRecipes(uint32 player_guid) const = 0;

            /**
             * Check if synthesis requirements are met
             */
            virtual bool CheckSynthesisRequirements(uint32 player_guid, uint32 recipe_id,
                                                  std::vector<uint32>& required_items,
                                                  std::string& error_message) const = 0;

            /**
             * Perform item synthesis
             */
            virtual bool PerformSynthesis(uint32 player_guid, uint32 recipe_id,
                                        std::vector<uint32>& consumed_items,
                                        bool& success, uint32& output_item_id,
                                        uint32& output_quantity) = 0;

            /**
             * Get synthesis success rate
             */
            virtual float GetSynthesisSuccessRate(uint32 recipe_id, uint32 player_guid) const = 0;

            /**
             * Check if recipe is on cooldown
             */
            virtual bool HasCooldown(uint32 player_guid, uint32 recipe_id) const = 0;

            /**
             * Get remaining cooldown time
             */
            virtual uint32 GetCooldownRemaining(uint32 player_guid, uint32 recipe_id) const = 0;

            /**
             * Calculate synthesis cost
             */
            virtual void CalculateSynthesisCost(uint32 recipe_id, uint32& out_essence, uint32& out_tokens) = 0;
        };

    } // namespace ItemUpgrade
} // namespace DarkChaos

// =====================================================================
// Global Access Functions
// =====================================================================

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        /**
         * Get the global transmutation manager instance
         */
        TransmutationManager* GetTransmutationManager();

        /**
         * Get the global synthesis manager instance
         */
        SynthesisManager* GetSynthesisManager();

        /**
         * Get the global tier conversion manager instance
         */
        TierConversionManager* GetTierConversionManager();
    }
}

#endif // ITEM_UPGRADE_TRANSMUTATION_H