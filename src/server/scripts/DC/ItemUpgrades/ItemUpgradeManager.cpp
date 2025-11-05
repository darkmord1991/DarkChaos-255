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
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "Log.h"
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
            std::map<uint32, uint8> item_to_tier;                 // item_id -> tier_id
            std::map<uint32, ChaosArtifact> artifacts;            // artifact_id -> artifact
            std::map<uint32, ItemUpgradeState> item_states;       // item_guid -> state

        public:
            UpgradeManagerImpl() = default;
            virtual ~UpgradeManagerImpl() = default;

            // ====================================================================
            // Core Upgrade Functions
            // ====================================================================

            bool UpgradeItem(uint32 player_guid, uint32 item_guid) override
            {
                // Get current item upgrade state
                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Item {} not found for upgrade", item_guid);
                    return false;
                }

                // Check if item can be upgraded
                if (!state->CanUpgrade())
                {
                    LOG_INFO("scripts", "ItemUpgrade: Item {} already at max level", item_guid);
                    return false;
                }

                uint8 next_level = state->upgrade_level + 1;

                // Get upgrade cost
                uint32 token_cost = GetUpgradeCost(state->tier_id, next_level);
                uint32 essence_cost = GetEssenceCost(state->tier_id, next_level);

                // Check currency
                if (state->tier_id == TIER_ARTIFACT)
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
                if (state->tier_id == TIER_ARTIFACT)
                {
                    RemoveCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, essence_cost, state->season);
                    state->essence_invested += essence_cost;
                }
                else
                {
                    RemoveCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, token_cost, state->season);
                    state->tokens_invested += token_cost;
                }

                // Update item state
                state->upgrade_level = next_level;
                state->last_upgraded_at = time(nullptr);
                if (state->first_upgraded_at == 0)
                    state->first_upgraded_at = state->last_upgraded_at;

                // Calculate new stat multiplier
                float max_mult = (state->tier_id == TIER_ARTIFACT) ? STAT_MULTIPLIER_MAX_ARTIFACT : STAT_MULTIPLIER_MAX_REGULAR;
                state->stat_multiplier = 1.0f + (next_level / 5.0f) * (max_mult - 1.0f);

                // Save to database
                SaveItemUpgrade(item_guid);

                // Award artifact mastery points for Phase 4B progression system
                uint32 mastery_points = 0;
                switch (state->tier_id)
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

                std::ostringstream mastery_oss;
                mastery_oss << "INSERT INTO dc_player_artifact_mastery (player_guid, mastery_points, season) "
                           << "VALUES (" << player_guid << ", " << mastery_points << ", " << state->season << ") "
                           << "ON DUPLICATE KEY UPDATE mastery_points = mastery_points + " << mastery_points;

                CharacterDatabase.Execute(mastery_oss.str().c_str());

                LOG_INFO("scripts", "ItemUpgrade: Player {} upgraded item {} to level {} and earned {} mastery points", 
                        player_guid, item_guid, next_level, mastery_points);

                return true;
            }

            bool AddCurrency(uint32 player_guid, CurrencyType currency, uint32 amount, uint32 season) override
            {
                if (amount == 0)
                    return true;

                // Build currency type string
                std::string currency_str = (currency == CURRENCY_UPGRADE_TOKEN) ? "upgrade_token" : "artifact_essence";

                // Insert or update
                std::ostringstream oss;
                oss << "INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season) "
                    << "VALUES (" << player_guid << ", '" << currency_str << "', " << amount << ", " << season << ") "
                    << "ON DUPLICATE KEY UPDATE amount = amount + " << amount;

                CharacterDatabase.Execute(oss.str().c_str());
                LOG_DEBUG("scripts", "ItemUpgrade: Added {} {} to player {}", amount, currency_str, player_guid);

                return true;
            }

            bool RemoveCurrency(uint32 player_guid, CurrencyType currency, uint32 amount, uint32 season) override
            {
                uint32 current = GetCurrency(player_guid, currency, season);
                if (current < amount)
                    return false;

                std::string currency_str = (currency == CURRENCY_UPGRADE_TOKEN) ? "upgrade_token" : "artifact_essence";

                std::ostringstream oss;
                oss << "UPDATE dc_player_upgrade_tokens SET amount = amount - " << amount 
                    << " WHERE player_guid = " << player_guid 
                    << " AND currency_type = '" << currency_str << "' AND season = " << season;

                CharacterDatabase.Execute(oss.str().c_str());

                // Record weekly spending for Phase 4B progression system
                std::string spending_column = (currency == CURRENCY_UPGRADE_TOKEN) ? "tokens_spent" : "essence_spent";
                std::ostringstream spend_oss;
                spend_oss << "INSERT INTO dc_weekly_spending (player_guid, week_start, " << spending_column << ") "
                          << "VALUES (" << player_guid << ", UNIX_TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)), " << amount << ") "
                          << "ON DUPLICATE KEY UPDATE " << spending_column << " = " << spending_column << " + " << amount;

                CharacterDatabase.Execute(spend_oss.str().c_str());

                return true;
            }

            uint32 GetCurrency(uint32 player_guid, CurrencyType currency, uint32 season) override
            {
                std::string currency_str = (currency == CURRENCY_UPGRADE_TOKEN) ? "upgrade_token" : "artifact_essence";

                std::ostringstream oss;
                oss << "SELECT amount FROM dc_player_upgrade_tokens WHERE player_guid = " << player_guid 
                    << " AND currency_type = '" << currency_str << "' AND season = " << season;

                QueryResult result = CharacterDatabase.Query(oss.str().c_str());
                if (!result)
                    return 0;

                return result->Fetch()[0].Get<uint32>();
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
                std::ostringstream oss;
                oss << "SELECT item_guid, player_guid, tier_id, upgrade_level, tokens_invested, essence_invested, "
                    << "stat_multiplier, first_upgraded_at, last_upgraded_at, season "
                    << "FROM dc_player_item_upgrades WHERE item_guid = " << item_guid;

                QueryResult result = CharacterDatabase.Query(oss.str().c_str());
                if (!result)
                {
                    LOG_DEBUG("scripts", "ItemUpgrade: Item {} not in upgrade database - creating default state", item_guid);
                    
                    // NEW: Create default state for items not in database yet
                    // This allows newly equipped items to be upgradeable without manual SQL initialization
                    ItemUpgradeState default_state;
                    default_state.item_guid = item_guid;
                    default_state.player_guid = 0; // Will be set when first upgraded or by CanUpgradeItem
                    default_state.tier_id = 1;     // Default to Tier 1 (Leveling)
                    default_state.upgrade_level = 0;
                    default_state.tokens_invested = 0;
                    default_state.essence_invested = 0;
                    default_state.stat_multiplier = 1.0f;
                    default_state.first_upgraded_at = 0;
                    default_state.last_upgraded_at = 0;
                    default_state.season = 1;
                    
                    // Cache the default state
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

                // Cache and return
                item_states[item_guid] = state;
                return &item_states[item_guid];
            }

            bool SetItemUpgradeLevel(uint32 item_guid, uint8 level) override
            {
                if (level > MAX_UPGRADE_LEVEL)
                    return false;

                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state)
                    return false;

                state->upgrade_level = level;
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

                // Get iLvL increase per upgrade using database values
                uint16 total_ilvl_increase = 0;
                for (uint8 i = 1; i <= state->upgrade_level; ++i)
                {
                    total_ilvl_increase += GetIlvlIncrease(state->tier_id, i);
                }

                return base_ilvl + total_ilvl_increase;
            }

            bool GetNextUpgradeCost(uint32 item_guid, uint32& out_essence, uint32& out_tokens) override
            {
                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state)
                    return false;

                uint8 tier = state->tier_id;
                // Use current upgrade level to compute next level cost
                out_essence = UpgradeCostCalculator::GetEssenceCost(tier, state->upgrade_level);
                out_tokens = UpgradeCostCalculator::GetTokenCost(tier, state->upgrade_level);
                return true;
            }

            std::string GetUpgradeDisplay(uint32 item_guid) override
            {
                ItemUpgradeState* state = GetItemUpgradeState(item_guid);
                if (!state)
                {
                    std::ostringstream oss;
                    oss << "|cffffd700===== Item Upgrade Status =====|r\n";
                    oss << "Upgrade Level: 0/15 (New)\n";
                    oss << "Stat Bonus: +0%\n";
                    oss << "Total Investment: 0 Essence, 0 Tokens\n";
                    return oss.str();
                }

                uint8 tier = state->tier_id;
                // Build display using mechanics helpers
                std::ostringstream oss;
                oss << "|cffffd700===== Item Upgrade Status =====|r\n";
                oss << "Upgrade Level: " << static_cast<int>(state->upgrade_level) << "/15\n";
                oss << "Stat Bonus: " << StatScalingCalculator::GetStatBonusDisplay(state->upgrade_level, tier) << "\n";
                oss << "Item Level: " << ItemLevelCalculator::GetItemLevelDisplay(state->base_item_level, state->upgraded_item_level) << "\n";
                oss << "Total Investment: " << state->essence_invested << " Essence, " << state->tokens_invested << " Tokens\n";

                if (state->upgrade_level < MAX_UPGRADE_LEVEL)
                {
                    uint32 next_ess = UpgradeCostCalculator::GetEssenceCost(tier, state->upgrade_level);
                    uint32 next_tok = UpgradeCostCalculator::GetTokenCost(tier, state->upgrade_level);
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

                return state->upgrade_level < MAX_UPGRADE_LEVEL;
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
                if (upgrade_level > MAX_UPGRADE_LEVEL || upgrade_level == 0)
                    return 0;

                uint8 key = (tier_id << 4) | upgrade_level;
                auto it = upgrade_costs.find(key);
                if (it != upgrade_costs.end())
                    return it->second.token_cost;

                return 0;
            }

            uint32 GetEssenceCost(uint8 tier_id, uint8 upgrade_level) override
            {
                if (upgrade_level > MAX_UPGRADE_LEVEL || upgrade_level == 0)
                    return 0;

                uint8 key = (tier_id << 4) | upgrade_level;
                auto it = upgrade_costs.find(key);
                if (it != upgrade_costs.end())
                    return it->second.essence_cost;

                return 0;
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
                std::ostringstream oss;
                oss << "INSERT IGNORE INTO dc_player_artifact_discoveries (player_guid, artifact_id) "
                    << "VALUES (" << player_guid << ", " << artifact_id << ")";

                CharacterDatabase.Execute(oss.str().c_str());
                return true;
            }

            // ====================================================================
            // Database Functions
            // ====================================================================

            void LoadUpgradeData(uint32 season) override
            {
                LOG_INFO("scripts", "ItemUpgrade: Loading upgrade data for season {}", season);

                // Load tier definitions
                std::ostringstream oss1;
                oss1 << "SELECT tier_id, tier_name, min_ilvl, max_ilvl, max_upgrade_level, stat_multiplier_max, "
                     << "upgrade_cost_per_level, source_content, is_artifact FROM dc_item_upgrade_tiers WHERE season = " << season;

                QueryResult result = WorldDatabase.Query(oss1.str().c_str());
                if (result)
                {
                    LOG_INFO("scripts", "ItemUpgrade: Loaded {} tier definitions", result->GetRowCount());
                }

                // Load upgrade costs
                std::ostringstream oss2;
                oss2 << "SELECT tier_id, upgrade_level, token_cost, essence_cost, ilvl_increase, stat_increase_percent FROM dc_item_upgrade_costs WHERE season = " << season;

                result = WorldDatabase.Query(oss2.str().c_str());
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
                std::ostringstream oss3;
                oss3 << "SELECT item_id, tier_id FROM dc_item_templates_upgrade WHERE season = " << season << " AND is_active = 1";

                result = WorldDatabase.Query(oss3.str().c_str());
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
                std::ostringstream oss4;
                oss4 << "SELECT artifact_id, artifact_name, item_id, cosmetic_variant, rarity, location_name, location_type, essence_cost, is_active FROM dc_chaos_artifact_items WHERE season = " << season << " AND is_active = 1";

                result = WorldDatabase.Query(oss4.str().c_str());
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

                std::ostringstream oss;
                oss << "INSERT INTO dc_player_item_upgrades (item_guid, player_guid, tier_id, upgrade_level, "
                    << "tokens_invested, essence_invested, stat_multiplier, first_upgraded_at, last_upgraded_at, season) "
                    << "VALUES (" << state->item_guid << ", " << state->player_guid << ", " << (int)state->tier_id 
                    << ", " << (int)state->upgrade_level << ", " << state->tokens_invested 
                    << ", " << state->essence_invested << ", " << state->stat_multiplier 
                    << ", " << state->first_upgraded_at << ", " << state->last_upgraded_at << ", " << state->season << ") "
                    << "ON DUPLICATE KEY UPDATE "
                    << "upgrade_level = " << (int)state->upgrade_level
                    << ", tokens_invested = " << state->tokens_invested
                    << ", essence_invested = " << state->essence_invested
                    << ", stat_multiplier = " << state->stat_multiplier
                    << ", last_upgraded_at = " << state->last_upgraded_at;

                CharacterDatabase.Execute(oss.str().c_str());
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
