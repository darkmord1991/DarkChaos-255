/*
 * DarkChaos Item Upgrade System - C++ Implementation
 * 
 * Core implementation of the item upgrade manager.
 * Handles upgrade logic, token economy, and state persistence.
 * 
 * Author: DarkChaos Development Team
 * Date: November 4, 2025
 */

#include "ItemUpgradeManager.h"
#include "ItemUpgradeMechanics.h"
#include "ItemUpgradeAdvanced.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "ObjectGuid.h"
#include "ObjectMgr.h"
#include <sstream>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Upgrade Manager Implementation
        // =====================================================================
        
        class UpgradeManagerImpl : public UpgradeManager
        {
        private:
            // Cache maps for fast lookup
            std::map<uint8, UpgradeCost> upgrade_costs;           // tier_id+level -> cost
            std::map<uint8, TierDefinition> tier_definitions;     // tier_id -> definition
            std::map<uint32, uint8> item_to_tier;                 // item_id -> tier_id
            std::map<uint32, ChaosArtifact> artifacts;            // artifact_id -> artifact
            std::map<uint32, ItemUpgradeState> item_states;       // item_guid -> state

            void EnsureStateMetadata(ItemUpgradeState& state, uint32 owner_hint = 0)
            {
                if (state.item_guid == 0)
                    return;

                if (owner_hint != 0 && state.player_guid == 0)
                    state.player_guid = owner_hint;

                bool needsOwner = state.player_guid == 0;
                bool needsTier = state.tier_id == 0 || state.tier_id == TIER_INVALID;
                bool needsBase = state.base_item_level == 0;

                if (needsOwner || needsTier || needsBase)
                {
                    QueryResult itemInfo = CharacterDatabase.Query(
                        "SELECT owner_guid, itemEntry FROM item_instance WHERE guid = {}",
                        state.item_guid);

                    if (itemInfo)
                    {
                        Field* infoFields = itemInfo->Fetch();

                        if (needsOwner)
                            state.player_guid = infoFields[0].Get<uint32>();

                        uint32 itemEntry = infoFields[1].Get<uint32>();

                        if (needsTier)
                        {
                            uint8 mappedTier = GetItemTier(itemEntry);
                            if (mappedTier == TIER_INVALID)
                                mappedTier = TIER_LEVELING;
                            state.tier_id = mappedTier;
                        }

                        if (needsBase)
                        {
                            if (const ItemTemplate* itemTemplate = sObjectMgr->GetItemTemplate(itemEntry))
                                state.base_item_level = itemTemplate->ItemLevel;
                        }
                    }
                }

                if ((state.tier_id == 0 || state.tier_id == TIER_INVALID || state.base_item_level == 0) && state.player_guid != 0)
                {
                    if (Player* owner = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(state.player_guid)))
                    {
                        if (Item* ownedItem = owner->GetItemByGuid(ObjectGuid::Create<HighGuid::Item>(state.item_guid)))
                        {
                            if (state.tier_id == 0 || state.tier_id == TIER_INVALID)
                            {
                                uint8 mappedTier = GetItemTier(ownedItem->GetEntry());
                                if (mappedTier == TIER_INVALID)
                                    mappedTier = TIER_LEVELING;
                                state.tier_id = mappedTier;
                            }

                            if (state.base_item_level == 0)
                            {
                                if (const ItemTemplate* itemTemplate = ownedItem->GetTemplate())
                                    state.base_item_level = itemTemplate->ItemLevel;
                            }
                        }
                    }
                }

                if (state.tier_id == 0 || state.tier_id == TIER_INVALID)
                    state.tier_id = TIER_LEVELING;

                if (state.base_item_level != 0)
                {
                    uint16 upgraded = state.base_item_level;
                    if (state.upgrade_level > 0)
                    {
                        upgraded = state.base_item_level;
                        for (uint8 level = 1; level <= state.upgrade_level; ++level)
                            upgraded += GetIlvlIncrease(state.tier_id, level);
                    }

                    state.upgraded_item_level = upgraded;
                }

                float max_mult = STAT_MULTIPLIER_MAX_REGULAR;
                if (const TierDefinition* def = GetTierDefinition(state.tier_id))
                    max_mult = def->stat_multiplier_max;
                else if (state.tier_id == TIER_ARTIFACT)
                    max_mult = STAT_MULTIPLIER_MAX_ARTIFACT;

                if (state.upgrade_level > 0)
                {
                    uint8 max_level = GetTierMaxLevel(state.tier_id);
                    float progress = max_level > 0 ? static_cast<float>(state.upgrade_level) / static_cast<float>(max_level) : 0.0f;
                    if (progress > 1.0f)
                        progress = 1.0f;
                    state.stat_multiplier = 1.0f + progress * (max_mult - 1.0f);
                }
                else
                {
                    state.stat_multiplier = 1.0f;
                }
            }

        public:
            UpgradeManagerImpl() = default;
            virtual ~UpgradeManagerImpl() = default;

            // ====================================================================
            // Core Upgrade Functions
            // ====================================================================

            bool UpgradeItem(uint32 player_guid, uint32 item_guid) override
            {
                if (player_guid == 0 || item_guid == 0)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Invalid parameters - player_guid: {}, item_guid: {}", player_guid, item_guid);
                    return false;
                }

                try
                {
                    // Get current item upgrade state
                    ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                    if (!state)
                    {
                        LOG_ERROR("scripts", "ItemUpgrade: Item {} not found for upgrade", item_guid);
                        return false;
                    }

                    EnsureStateMetadata(*state, player_guid);

                    uint8 tier = state->tier_id;
                    uint8 max_level = GetTierMaxLevel(tier);
                    if (state->upgrade_level >= max_level)
                    {
                        LOG_INFO("scripts", "ItemUpgrade: Item {} already at max level {}", item_guid, max_level);
                        return false;
                    }

                    uint8 next_level = state->upgrade_level + 1;
                    if (next_level > max_level)
                        next_level = max_level;

                    // Get upgrade cost
                    uint32 token_cost = GetUpgradeCost(tier, next_level);
                    uint32 essence_cost = GetEssenceCost(tier, next_level);

                    // Check currency
                    if (tier == TIER_ARTIFACT)
                    {
                        // Artifacts use essence
                        uint32 essence = GetCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, state->season);
                        if (essence < essence_cost)
                        {
                            LOG_DEBUG("scripts", "ItemUpgrade: Player {} insufficient essence (need {}, have {})", 
                                     player_guid, essence_cost, essence);
                            return false;
                        }
                    }
                    else
                    {
                        // Regular items use upgrade tokens
                        uint32 tokens = GetCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, state->season);
                        if (tokens < token_cost)
                        {
                            LOG_DEBUG("scripts", "ItemUpgrade: Player {} insufficient tokens (need {}, have {})", 
                                     player_guid, token_cost, tokens);
                            return false;
                        }
                    }

                    // Perform upgrade
                    if (tier == TIER_ARTIFACT)
                    {
                        if (!RemoveCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, essence_cost, state->season))
                            return false;
                        state->essence_invested += essence_cost;
                    }
                    else
                    {
                        if (!RemoveCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, token_cost, state->season))
                            return false;
                        state->tokens_invested += token_cost;
                    }

                    // Update item state
                    state->upgrade_level = next_level;
                    state->last_upgraded_at = time(nullptr);
                    if (state->first_upgraded_at == 0)
                        state->first_upgraded_at = state->last_upgraded_at;

                    // Calculate new stat multiplier
                    float max_mult = STAT_MULTIPLIER_MAX_REGULAR;
                    if (const TierDefinition* def = GetTierDefinition(tier))
                        max_mult = def->stat_multiplier_max;
                    else if (tier == TIER_ARTIFACT)
                        max_mult = STAT_MULTIPLIER_MAX_ARTIFACT;

                    float progress = max_level > 0 ? static_cast<float>(next_level) / static_cast<float>(max_level) : 0.0f;
                    if (progress > 1.0f)
                        progress = 1.0f;

                    state->stat_multiplier = 1.0f + progress * (max_mult - 1.0f);

                    if (state->base_item_level == 0)
                        EnsureStateMetadata(*state, player_guid);

                    if (state->base_item_level != 0)
                    {
                        uint16 upgraded = state->base_item_level;
                        for (uint8 level = 1; level <= state->upgrade_level; ++level)
                            upgraded += GetIlvlIncrease(state->tier_id, level);
                        state->upgraded_item_level = upgraded;
                    }

                    // Save to database
                    SaveItemUpgrade(item_guid);

                    // Award artifact mastery points for Phase 4B progression system
                    uint32 mastery_points = 0;
                    switch (tier)
                    {
                        case TIER_LEVELING: mastery_points = 1; break;
                        case TIER_HEROIC: mastery_points = 2; break;
                        case TIER_RAID: mastery_points = 3; break;
                        case TIER_MYTHIC: mastery_points = 5; break;
                        case TIER_ARTIFACT: mastery_points = 10; break;
                        default: mastery_points = 1; break;
                    }

                    // Award bonus points for reaching certain upgrade milestones
                    if (next_level % 5 == 0)
                        mastery_points *= 2; // Double points at levels 5, 10, 15

                    CharacterDatabase.Execute(
                        "INSERT INTO dc_player_artifact_mastery (player_guid, mastery_points, season) "
                        "VALUES ({}, {}, {}) "
                        "ON DUPLICATE KEY UPDATE mastery_points = mastery_points + {}",
                        player_guid, mastery_points, state->season, mastery_points);

                    LOG_INFO("scripts", "ItemUpgrade: Player {} upgraded item {} to level {} and earned {} mastery points", 
                            player_guid, item_guid, next_level, mastery_points);

                    return true;
                }
                catch (const std::exception& e)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Failed to upgrade item {} for player {}: {}", item_guid, player_guid, e.what());
                    return false;
                }
            }

            bool AddCurrency(uint32 player_guid, CurrencyType currency, uint32 amount, uint32 season) override
            {
                if (amount == 0)
                    return true;

                if (player_guid == 0)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Invalid player_guid {} in AddCurrency", player_guid);
                    return false;
                }

                // Build currency type string
                std::string currency_str = (currency == CURRENCY_UPGRADE_TOKEN) ? "upgrade_token" : "artifact_essence";

                try
                {
                    // Insert or update using parameterized query
                    CharacterDatabase.Execute(
                        "INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season) "
                        "VALUES ({}, '{}', {}, {}) "
                        "ON DUPLICATE KEY UPDATE amount = amount + {}",
                        player_guid, currency_str, amount, season, amount);

                    LOG_DEBUG("scripts", "ItemUpgrade: Added {} {} to player {}", amount, currency_str, player_guid);
                    return true;
                }
                catch (const std::exception& e)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Failed to add currency for player {}: {}", player_guid, e.what());
                    return false;
                }
            }

            bool RemoveCurrency(uint32 player_guid, CurrencyType currency, uint32 amount, uint32 season) override
            {
                if (player_guid == 0)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Invalid player_guid {} in RemoveCurrency", player_guid);
                    return false;
                }

                if (amount == 0)
                    return true;

                uint32 current = GetCurrency(player_guid, currency, season);
                if (current < amount)
                {
                    LOG_WARN("scripts", "ItemUpgrade: Player {} has insufficient {} (has {}, needs {})",
                             player_guid, (currency == CURRENCY_UPGRADE_TOKEN) ? "tokens" : "essence", current, amount);
                    return false;
                }

                std::string currency_str = (currency == CURRENCY_UPGRADE_TOKEN) ? "upgrade_token" : "artifact_essence";

                try
                {
                    CharacterDatabase.Execute(
                        "UPDATE dc_player_upgrade_tokens SET amount = amount - {} "
                        "WHERE player_guid = {} AND currency_type = '{}' AND season = {}",
                        amount, player_guid, currency_str, season);

                    // Record weekly spending for Phase 4B progression system
                    std::string spending_column = (currency == CURRENCY_UPGRADE_TOKEN) ? "tokens_spent" : "essence_spent";
                    CharacterDatabase.Execute(
                        "INSERT INTO dc_weekly_spending (player_guid, week_start, {}) "
                        "VALUES ({}, UNIX_TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)), {}) "
                        "ON DUPLICATE KEY UPDATE {} = {} + {}",
                        spending_column, player_guid, amount, spending_column, spending_column, amount);

                    return true;
                }
                catch (const std::exception& e)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Failed to remove currency for player {}: {}", player_guid, e.what());
                    return false;
                }
            }

            uint32 GetCurrency(uint32 player_guid, CurrencyType currency, uint32 season) override
            {
                if (player_guid == 0)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Invalid player_guid {} in GetCurrency", player_guid);
                    return 0;
                }

                std::string currency_str = (currency == CURRENCY_UPGRADE_TOKEN) ? "upgrade_token" : "artifact_essence";

                try
                {
                    QueryResult result = CharacterDatabase.Query(
                        "SELECT amount FROM dc_player_upgrade_tokens WHERE player_guid = {} "
                        "AND currency_type = '{}' AND season = {}",
                        player_guid, currency_str, season);

                    if (!result)
                        return 0;

                    return result->Fetch()[0].Get<uint32>();
                }
                catch (const std::exception& e)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Failed to get currency for player {}: {}", player_guid, e.what());
                    return 0;
                }
            }

            // ====================================================================
            // Item State Functions
            // ====================================================================

            ItemUpgradeState* GetItemUpgradeState(uint32 item_guid) override
            {
                // Check cache first
                auto it = item_states.find(item_guid);
                if (it != item_states.end())
                    return &it->second;

                // Load from database
                QueryResult result = CharacterDatabase.Query(
                    "SELECT item_guid, player_guid, tier_id, upgrade_level, tokens_invested, essence_invested, "
                    "stat_multiplier, first_upgraded_at, last_upgraded_at, season "
                    "FROM dc_player_item_upgrades WHERE item_guid = {}",
                    item_guid);
                if (!result)
                {
                    LOG_DEBUG("scripts", "ItemUpgrade: Item {} not in upgrade database - creating default state", item_guid);

                    ItemUpgradeState default_state;
                    default_state.item_guid = item_guid;
                    EnsureStateMetadata(default_state);
                    if (default_state.tier_id == 0 || default_state.tier_id == TIER_INVALID)
                        default_state.tier_id = TIER_LEVELING;

                    item_states[item_guid] = default_state;
                    return &item_states[item_guid];
                }

                ItemUpgradeState state;
                Field* fields = result->Fetch();
                state.item_guid = fields[0].Get<uint32>();
                state.player_guid = fields[1].Get<uint32>();
                state.tier_id = fields[2].Get<uint8>();
                state.upgrade_level = fields[3].Get<uint8>();
                state.tokens_invested = fields[4].Get<uint32>();
                state.essence_invested = fields[5].Get<uint32>();
                state.stat_multiplier = fields[6].Get<float>();
                state.first_upgraded_at = fields[7].Get<time_t>();
                state.last_upgraded_at = fields[8].Get<time_t>();
                state.season = fields[9].Get<uint32>();

                EnsureStateMetadata(state, state.player_guid);

                // Cache and return
                item_states[item_guid] = state;
                return &item_states[item_guid];
            }

            bool SetItemUpgradeLevel(uint32 item_guid, uint8 level) override
            {
                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state)
                    return false;

                EnsureStateMetadata(*state, state->player_guid);

                uint8 max_level = GetTierMaxLevel(state->tier_id);
                if (level > max_level)
                    return false;

                state->upgrade_level = level;

                float max_mult = STAT_MULTIPLIER_MAX_REGULAR;
                if (const TierDefinition* def = GetTierDefinition(state->tier_id))
                    max_mult = def->stat_multiplier_max;
                else if (state->tier_id == TIER_ARTIFACT)
                    max_mult = STAT_MULTIPLIER_MAX_ARTIFACT;

                float progress = max_level > 0 ? static_cast<float>(level) / static_cast<float>(max_level) : 0.0f;
                if (progress > 1.0f)
                    progress = 1.0f;

                state->stat_multiplier = 1.0f + progress * (max_mult - 1.0f);

                if (state->base_item_level != 0)
                {
                    uint16 upgraded = state->base_item_level;
                    for (uint8 i = 1; i <= state->upgrade_level; ++i)
                        upgraded += GetIlvlIncrease(state->tier_id, i);
                    state->upgraded_item_level = upgraded;
                }

                SaveItemUpgrade(item_guid);
                return true;
            }

            float GetStatMultiplier(uint32 item_guid) override
            {
                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state)
                    return 1.0f;

                return state->stat_multiplier;
            }

            uint16 GetIlvlIncrease(uint8 tier_id, uint8 upgrade_level) 
            {
                if (upgrade_level > MAX_UPGRADE_LEVEL || upgrade_level == 0)
                    return 0;

                uint8 key = (tier_id << 4) | upgrade_level;
                auto it = upgrade_costs.find(key);
                if (it != upgrade_costs.end())
                    return it->second.ilvl_increase;

                // Fallback to hardcoded values if database not loaded
                switch (tier_id)
                {
                    case TIER_LEVELING: return 5;
                    case TIER_HEROIC: return 8;
                    case TIER_RAID: return 15;
                    case TIER_MYTHIC: return 8;
                    case TIER_ARTIFACT: return 12;
                    default: return 5;
                }
            }

            uint16 GetUpgradedItemLevel(uint32 item_guid, uint16 base_ilvl) override
            {
                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state || state->upgrade_level == 0)
                    return base_ilvl;

                EnsureStateMetadata(*state, state->player_guid);
                if (state->base_item_level == 0)
                    state->base_item_level = base_ilvl;

                // Get iLvL increase per upgrade using database values
                uint16 total_ilvl_increase = 0;
                for (uint8 i = 1; i <= state->upgrade_level; ++i)
                {
                    total_ilvl_increase += GetIlvlIncrease(state->tier_id, i);
                }
                uint16 baseLevel = state->base_item_level != 0 ? state->base_item_level : base_ilvl;
                uint16 upgradedLevel = baseLevel + total_ilvl_increase;
                state->upgraded_item_level = upgradedLevel;
                return upgradedLevel;
            }

            bool GetNextUpgradeCost(uint32 item_guid, uint32& out_essence, uint32& out_tokens) override
            {
                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state)
                    return false;

                EnsureStateMetadata(*state, state->player_guid);

                uint8 tier = state->tier_id;
                uint8 max_level = GetTierMaxLevel(tier);

                if (state->upgrade_level >= max_level)
                {
                    out_essence = 0;
                    out_tokens = 0;
                    return false;
                }

                uint8 next_level = state->upgrade_level + 1;
                out_essence = GetEssenceCost(tier, next_level);
                out_tokens = GetUpgradeCost(tier, next_level);
                return true;
            }

            std::string GetUpgradeDisplay(uint32 item_guid) override
            {
                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state)
                {
                    std::ostringstream oss;
                    oss << "|cffffd700===== Item Upgrade Status =====|r\n";
                    uint8 default_max = GetTierMaxLevel(TIER_LEVELING);
                    oss << "Upgrade Level: 0/" << static_cast<int>(default_max) << " (New)\n";
                    oss << "Stat Bonus: +0%\n";
                    oss << "Total Investment: 0 Essence, 0 Tokens\n";
                    return oss.str();
                }

                EnsureStateMetadata(*state, state->player_guid);

                uint8 tier = state->tier_id;
                uint8 max_level = GetTierMaxLevel(tier);
                // Build display using mechanics helpers
                std::ostringstream oss;
                oss << "|cffffd700===== Item Upgrade Status =====|r\n";
                oss << "Upgrade Level: " << static_cast<int>(state->upgrade_level) << "/" << static_cast<int>(max_level) << "\n";
                oss << "Stat Bonus: " << StatScalingCalculator::GetStatBonusDisplay(state->upgrade_level, tier) << "\n";
                oss << "Item Level: " << ItemLevelCalculator::GetItemLevelDisplay(state->base_item_level, state->upgraded_item_level) << "\n";
                oss << "Total Investment: " << state->essence_invested << " Essence, " << state->tokens_invested << " Tokens\n";

                if (state->upgrade_level < max_level)
                {
                    uint32 next_ess = GetEssenceCost(tier, state->upgrade_level + 1);
                    uint32 next_tok = GetUpgradeCost(tier, state->upgrade_level + 1);
                    oss << "\n|cff00ff00Next Upgrade Cost:|r\n";
                    oss << "Essence: " << next_ess << "\n";
                    oss << "Tokens: " << next_tok << "\n";
                }
                else
                {
                    oss << "\n|cffff0000This item is fully upgraded!|r\n";
                }

                return oss.str();
            }

            bool CanUpgradeItem(uint32 item_guid, uint32 player_guid) override
            {
                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state)
                    return false; // This should never happen now with default state creation

                EnsureStateMetadata(*state, player_guid);

                // NEW: If this is a newly seen item (player_guid not set), assign ownership
                if (state->player_guid == 0)
                {
                    state->player_guid = player_guid;
                    LOG_DEBUG("scripts", "ItemUpgrade: Assigned item {} to player {}", item_guid, player_guid);
                }

                // Ensure the item belongs to the player
                if (state->player_guid != player_guid)
                {
                    LOG_WARN("scripts", "ItemUpgrade: Item {} belongs to player {}, not {}", 
                             item_guid, state->player_guid, player_guid);
                    return false;
                }

                return state->upgrade_level < GetTierMaxLevel(state->tier_id);
            }

            // ====================================================================
            // Tier Functions
            // ====================================================================

            uint8 GetItemTier(uint32 item_id) override
            {
                auto it = item_to_tier.find(item_id);
                if (it != item_to_tier.end())
                    return it->second;

                return TIER_INVALID;
            }

            uint32 GetUpgradeCost(uint8 tier_id, uint8 upgrade_level) override
            {
                uint8 max_level = GetTierMaxLevel(tier_id);
                if (upgrade_level > max_level || upgrade_level == 0)
                    return 0;

                uint8 key = (tier_id << 4) | upgrade_level;
                auto it = upgrade_costs.find(key);
                if (it != upgrade_costs.end())
                    return it->second.token_cost;

                return 0;
            }

            uint32 GetEssenceCost(uint8 tier_id, uint8 upgrade_level) override
            {
                uint8 max_level = GetTierMaxLevel(tier_id);
                if (upgrade_level > max_level || upgrade_level == 0)
                    return 0;

                uint8 key = (tier_id << 4) | upgrade_level;
                auto it = upgrade_costs.find(key);
                if (it != upgrade_costs.end())
                    return it->second.essence_cost;

                return 0;
            }

            uint8 GetPlayerHighestTier(uint32 player_guid) override
            {
                if (player_guid == 0)
                    return TIER_LEVELING;

                try
                {
                    // Query for the highest tier among player's upgraded items
                    QueryResult result = CharacterDatabase.Query(
                        "SELECT MAX(tier_id) FROM dc_player_item_upgrades WHERE player_guid = {}",
                        player_guid);

                    if (result && result->GetRowCount() > 0)
                    {
                        uint8 highest_tier = result->Fetch()[0].Get<uint8>();
                        return highest_tier > 0 ? highest_tier : TIER_LEVELING;
                    }

                    // If no upgraded items found, return default tier
                    return TIER_LEVELING;
                }
                catch (const std::exception& e)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Failed to get highest tier for player {}: {}", player_guid, e.what());
                    return TIER_LEVELING;
                }
            }

            uint8 GetTierMaxLevel(uint8 tier_id) override
            {
                auto it = tier_definitions.find(tier_id);
                if (it != tier_definitions.end())
                    return it->second.max_upgrade_level;

                return MAX_UPGRADE_LEVEL;
            }

            const TierDefinition* GetTierDefinition(uint8 tier_id) override
            {
                auto it = tier_definitions.find(tier_id);
                if (it != tier_definitions.end())
                    return &it->second;

                return nullptr;
            }

            // ====================================================================
            // Artifact Functions
            // ====================================================================

            ChaosArtifact* GetArtifact(uint32 artifact_id) override
            {
                auto it = artifacts.find(artifact_id);
                if (it != artifacts.end())
                    return &it->second;

                return nullptr;
            }

            std::vector<ChaosArtifact*> GetArtifactsByLocation(const std::string& location) override
            {
                std::vector<ChaosArtifact*> result;
                for (auto& [id, artifact] : artifacts)
                {
                    if (artifact.location_name == location)
                        result.push_back(&artifact);
                }
                return result;
            }

            bool DiscoverArtifact(uint32 player_guid, uint32 artifact_id) override
            {
                CharacterDatabase.Execute(
                    "INSERT IGNORE INTO dc_player_artifact_discoveries (player_guid, artifact_id) "
                    "VALUES ({}, {})",
                    player_guid, artifact_id);

                return true;
            }

            // ====================================================================
            // Database Functions
            // ====================================================================

            void LoadUpgradeData(uint32 season) override
            {
                LOG_INFO("scripts", "ItemUpgrade: Loading upgrade data for season {}", season);

                tier_definitions.clear();
                upgrade_costs.clear();
                item_to_tier.clear();
                artifacts.clear();

                // Load tier definitions
                QueryResult result = WorldDatabase.Query(
                    "SELECT tier_id, tier_name, min_ilvl, max_ilvl, max_upgrade_level, stat_multiplier_max, "
                    "upgrade_cost_per_level, source_content, is_artifact FROM dc_item_upgrade_tiers WHERE season = {}",
                    season);
                if (result)
                {
                    uint32 count = 0;
                    do
                    {
                        Field* fields = result->Fetch();
                        uint8 tier_id = fields[0].Get<uint8>();
                        uint8 max_upgrade_level = fields[4].Get<uint8>();
                        float stat_multiplier_max = fields[5].Get<float>();
                        bool is_artifact = fields[8].Get<bool>();

                        TierDefinition def;
                        def.tier_id = tier_id;
                        def.max_upgrade_level = max_upgrade_level;
                        def.stat_multiplier_max = stat_multiplier_max;
                        def.is_artifact = is_artifact;

                        tier_definitions[tier_id] = def;
                        count++;
                    } while (result->NextRow());

                    LOG_INFO("scripts", "ItemUpgrade: Loaded {} tier definitions", count);
                }

                // Load upgrade costs
                result = WorldDatabase.Query(
                    "SELECT tier_id, upgrade_level, token_cost, essence_cost, ilvl_increase, stat_increase_percent FROM dc_item_upgrade_costs WHERE season = {}",
                    season);
                if (result)
                {
                    uint32 count = 0;
                    do
                    {
                        Field* fields = result->Fetch();
                        uint8 tier_id = fields[0].Get<uint8>();
                        uint8 upgrade_level = fields[1].Get<uint8>();
                        uint32 token_cost = fields[2].Get<uint32>();
                        uint32 essence_cost = fields[3].Get<uint32>();
                        uint16 ilvl_increase = fields[4].Get<uint16>();
                        float stat_increase = fields[5].Get<float>();

                        // Store in upgrade_costs map
                        uint8 key = (tier_id << 4) | upgrade_level;
                        upgrade_costs[key] = UpgradeCost{tier_id, upgrade_level, token_cost, essence_cost, ilvl_increase, stat_increase, season};

                        count++;
                    } while (result->NextRow());

                    LOG_INFO("scripts", "ItemUpgrade: Loaded {} upgrade cost entries", count);
                }

                // Load item to tier mappings
                result = WorldDatabase.Query(
                    "SELECT item_id, tier_id FROM dc_item_templates_upgrade WHERE season = {} AND is_active = 1",
                    season);
                if (result)
                {
                    uint32 count = 0;
                    do
                    {
                        Field* fields = result->Fetch();
                        uint32 item_id = fields[0].Get<uint32>();
                        uint8 tier_id = fields[1].Get<uint8>();

                        item_to_tier[item_id] = tier_id;
                        count++;
                    } while (result->NextRow());

                    LOG_INFO("scripts", "ItemUpgrade: Loaded {} item-to-tier mappings", count);
                }

                // Load artifacts
                result = WorldDatabase.Query(
                    "SELECT artifact_id, artifact_name, item_id, cosmetic_variant, rarity, location_name, location_type, essence_cost, is_active FROM dc_chaos_artifact_items WHERE season = {} AND is_active = 1",
                    season);
                if (result)
                {
                    uint32 count = 0;
                    do
                    {
                        Field* fields = result->Fetch();
                        uint32 artifact_id = fields[0].Get<uint32>();
                        std::string artifact_name = fields[1].Get<std::string>();
                        uint32 item_id = fields[2].Get<uint32>();
                        uint8 cosmetic_variant = fields[3].Get<uint8>();
                        uint8 rarity = fields[4].Get<uint8>();
                        std::string location_name = fields[5].Get<std::string>();
                        std::string location_type = fields[6].Get<std::string>();
                        uint32 essence_cost = fields[7].Get<uint32>();
                        bool is_active = fields[8].Get<bool>();

                        ChaosArtifact artifact;
                        artifact.artifact_id = artifact_id;
                        artifact.artifact_name = artifact_name;
                        artifact.item_id = item_id;
                        artifact.cosmetic_variant = cosmetic_variant;
                        artifact.rarity = rarity;
                        artifact.location_name = location_name;
                        artifact.location_type = location_type;
                        artifact.essence_cost = essence_cost;
                        artifact.is_active = is_active;
                        artifact.season = season;

                        artifacts[artifact_id] = artifact;
                        count++;
                    } while (result->NextRow());

                    LOG_INFO("scripts", "ItemUpgrade: Loaded {} chaos artifacts", count);
                }

                LOG_INFO("scripts", "ItemUpgrade: Data loading complete for season {}", season);
            }

            void SaveItemUpgrade(uint32 item_guid) override
            {
                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state)
                    return;

                CharacterDatabase.Execute(
                    "INSERT INTO dc_player_item_upgrades (item_guid, player_guid, tier_id, upgrade_level, "
                    "tokens_invested, essence_invested, stat_multiplier, first_upgraded_at, last_upgraded_at, season) "
                    "VALUES ({}, {}, {}, {}, {}, {}, {}, FROM_UNIXTIME({}), FROM_UNIXTIME({}), {}) "
                    "ON DUPLICATE KEY UPDATE "
                    "upgrade_level = {}, tokens_invested = {}, essence_invested = {}, "
                    "stat_multiplier = {}, last_upgraded_at = FROM_UNIXTIME({})",
                    state->item_guid, state->player_guid, static_cast<uint32>(state->tier_id),
                    static_cast<uint32>(state->upgrade_level), state->tokens_invested,
                    state->essence_invested, state->stat_multiplier,
                    state->first_upgraded_at, state->last_upgraded_at, state->season,
                    static_cast<uint32>(state->upgrade_level), state->tokens_invested,
                    state->essence_invested, state->stat_multiplier, state->last_upgraded_at);
            }

            void SavePlayerCurrency(uint32 player_guid, uint32 season) override
            {
                // Currency is already auto-saved by AddCurrency/RemoveCurrency
                // This function is here for manual flush if needed
                LOG_DEBUG("scripts", "ItemUpgrade: Currency flush for player {} season {}", player_guid, season);
            }
        };

        // =====================================================================
        // Singleton Implementation
        // =====================================================================

        static UpgradeManagerImpl* _upgrade_manager = nullptr;

        UpgradeManager* sUpgradeManager()
        {
            if (!_upgrade_manager)
                _upgrade_manager = new UpgradeManagerImpl();

            return _upgrade_manager;
        }

        // Backwards-compatible wrapper to match header declaration
        UpgradeManager* GetUpgradeManager()
        {
            return sUpgradeManager();
        }

    } // namespace ItemUpgrade
} // namespace DarkChaos
