/*
* Phase 4A: Item Upgrade Mechanics Implementation
* 
* This file implements the core item upgrade mechanics:
* - Cost calculations with escalation
* - Stat scaling based on tier and level
* - Item level calculations
* - UI formatting for displays
* 
* Date: November 4, 2025
*/

#include "ItemUpgradeMechanics.h"
#include "ItemUpgradeManager.h"
#include "Item.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "WorldSession.h"
#include <cmath>

using namespace DarkChaos::ItemUpgrade;

// ========== UpgradeCostCalculator Implementation ==========

uint32 UpgradeCostCalculator::GetEssenceCost(uint8 tier_id, uint8 current_level)
{
    if (current_level >= 15)
        return 0; // Already maxed
    
    // Base costs per tier
    static const float tier_costs[] = {
        10.0f,    // Tier 1: Common
        25.0f,    // Tier 2: Uncommon
        50.0f,    // Tier 3: Rare
        100.0f,   // Tier 4: Epic
        200.0f    // Tier 5: Legendary
    };
    
    if (tier_id < 1 || tier_id > 5)
        return 0;
    
    float base_cost = tier_costs[tier_id - 1];
    float escalated_cost = base_cost * std::pow(1.1f, static_cast<float>(current_level));
    
    return static_cast<uint32>(std::ceil(escalated_cost));
}

uint32 UpgradeCostCalculator::GetTokenCost(uint8 tier_id, uint8 current_level)
{
    if (current_level >= 15)
        return 0; // Already maxed
    
    // Token costs are roughly 50% of essence costs
    static const float tier_costs[] = {
        5.0f,     // Tier 1: Common
        10.0f,    // Tier 2: Uncommon
        15.0f,    // Tier 3: Rare
        25.0f,    // Tier 4: Epic
        50.0f     // Tier 5: Legendary
    };
    
    if (tier_id < 1 || tier_id > 5)
        return 0;
    
    float base_cost = tier_costs[tier_id - 1];
    float escalated_cost = base_cost * std::pow(1.1f, static_cast<float>(current_level));
    
    return static_cast<uint32>(std::ceil(escalated_cost));
}

void UpgradeCostCalculator::GetCumulativeCost(uint8 tier_id, uint8 target_level,
                                              uint32& out_essence, uint32& out_tokens)
{
    out_tokens = 0;
    out_essence = 0;

    if (target_level > 15)
        target_level = 15;

    // Sum costs from level 0 to target_level - 1
    for (uint8 level = 0; level < target_level; ++level)
    {
        out_essence += GetEssenceCost(tier_id, level);
        out_tokens += GetTokenCost(tier_id, level);
    }
}

void UpgradeCostCalculator::GetRefundCost(uint8 tier_id, uint8 current_level,
                                          uint32& out_essence, uint32& out_tokens)
{
    // Calculate cumulative invested cost up to current_level and return 50%
    GetCumulativeCost(tier_id, current_level, out_essence, out_tokens);
    out_essence = out_essence / 2;
    out_tokens = out_tokens / 2;
}

// ========== StatScalingCalculator Implementation ==========

float StatScalingCalculator::GetStatMultiplier(uint8 upgrade_level)
{
    // Base formula: 1.0 + (level * 0.025)
    // Level 0: 1.0x (0% bonus)
    // Level 5: 1.125x (+12.5% bonus)
    // Level 10: 1.25x (+25% bonus)
    // Level 15: 1.375x (+37.5% bonus)
    return 1.0f + (upgrade_level * 0.025f);
}

float StatScalingCalculator::GetTierMultiplier(uint8 tier_id)
{
    // Tier-based adjustments to stat scaling
    static const float tier_multipliers[] = {
        0.9f,     // Tier 1: Common (reduces scaling)
        0.95f,    // Tier 2: Uncommon
        1.0f,     // Tier 3: Rare (no adjustment)
        1.15f,    // Tier 4: Epic (enhances scaling)
        1.25f     // Tier 5: Legendary (maximum scaling)
    };
    
    if (tier_id < 1 || tier_id > 5)
        return 1.0f;
    
    return tier_multipliers[tier_id - 1];
}

float StatScalingCalculator::GetFinalMultiplier(uint8 upgrade_level, uint8 tier_id)
{
    float base_multiplier = GetStatMultiplier(upgrade_level);
    float tier_multiplier = GetTierMultiplier(tier_id);
    
    // Combined formula: (base - 1.0) * tier_mult + 1.0
    // This preserves 1.0 baseline while applying tier adjustments
    float final_multiplier = (base_multiplier - 1.0f) * tier_multiplier + 1.0f;
    
    return final_multiplier;
}

std::string StatScalingCalculator::GetStatBonusDisplay(uint8 upgrade_level, uint8 tier_id)
{
    float multiplier = GetFinalMultiplier(upgrade_level, tier_id);
    float bonus_percent = (multiplier - 1.0f) * 100.0f;
    
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(1) << bonus_percent << "%";
    return oss.str();
}

// ========== ItemLevelCalculator Implementation ==========

uint16 ItemLevelCalculator::GetItemLevelBonus(uint8 upgrade_level, uint8 tier_id)
{
    // Base ilvl bonus per level by tier
    static const float tier_ilvl_per_level[] = {
        1.0f,     // Tier 1: Common
        1.0f,     // Tier 2: Uncommon
        1.5f,     // Tier 3: Rare
        2.0f,     // Tier 4: Epic
        2.5f      // Tier 5: Legendary
    };
    
    if (tier_id < 1 || tier_id > 5)
        return 0;
    
    float bonus_per_level = tier_ilvl_per_level[tier_id - 1];
    float total_bonus = upgrade_level * bonus_per_level;
    
    return static_cast<uint16>(std::ceil(total_bonus));
}

uint16 ItemLevelCalculator::GetUpgradedItemLevel(uint16 base_ilvl, uint8 upgrade_level, uint8 tier_id)
{
    uint16 bonus = GetItemLevelBonus(upgrade_level, tier_id);
    return base_ilvl + bonus;
}

std::string ItemLevelCalculator::GetItemLevelDisplay(uint16 base_ilvl, uint16 current_ilvl)
{
    std::ostringstream oss;
    oss << current_ilvl;
    
    if (current_ilvl > base_ilvl)
    {
        uint16 bonus = current_ilvl - base_ilvl;
        oss << "|cff00ff00 +" << static_cast<int>(bonus) << "|r";
    }
    
    return oss.str();
}

// ========== UI Helper Implementation ==========

namespace DarkChaos { namespace ItemUpgrade { namespace UI {

std::string CreateUpgradeDisplay(const ItemUpgradeState& state, uint8 tier_id)
{
    std::ostringstream ss;

    float current_mult = StatScalingCalculator::GetFinalMultiplier(state.upgrade_level, tier_id);
    uint16 upgraded_ilvl = ItemLevelCalculator::GetUpgradedItemLevel(
        state.base_item_level, state.upgrade_level, tier_id);

    ss << "|cff00ff00Upgrade Level: " << static_cast<int>(state.upgrade_level) << "/15|r\n";
    ss << "|cffffffff Item Level: " << state.base_item_level << " -> " << upgraded_ilvl << "|r\n";
    ss << "|cffffff00Stat Bonus: " << std::fixed << std::setprecision(1) 
       << (current_mult - 1.0f) * 100 << "%|r\n";
    ss << "|cffccccccInvested: " << state.tokens_invested << " Tokens, "
       << state.essence_invested << " Essence|r\n";

    return ss.str();
}

}}} // namespace DarkChaos::ItemUpgrade::UI

// ========== ItemUpgradeState Database Persistence ==========

bool ItemUpgradeState::LoadFromDatabase(uint32 item_guid)
{
    QueryResult result = CharacterDatabase.Query(
        "SELECT item_guid, player_guid, upgrade_level, essence_invested, tokens_invested, "
        "base_item_level, upgraded_item_level, current_stat_multiplier, last_upgraded_timestamp, season_id "
        "FROM item_upgrades WHERE item_guid = {}", item_guid);
    
    if (!result)
        return false;
    
    Field* fields = result->Fetch();
    item_guid = fields[0].Get<uint32>();
    player_guid = fields[1].Get<uint32>();
    upgrade_level = fields[2].Get<uint8>();
    essence_invested = fields[3].Get<uint32>();
    tokens_invested = fields[4].Get<uint32>();
    base_item_level = fields[5].Get<uint16>();
    upgraded_item_level = fields[6].Get<uint16>();
    current_stat_multiplier = fields[7].Get<float>();
    last_upgraded_timestamp = fields[8].Get<uint32>();
    season_id = fields[9].Get<uint32>();
    
    return true;
}

bool ItemUpgradeState::SaveToDatabase() const
{
    // Use INSERT ... ON DUPLICATE KEY UPDATE for upsert
    CharacterDatabase.Execute(
        "INSERT INTO item_upgrades (item_guid, player_guid, upgrade_level, essence_invested, tokens_invested, "
        "base_item_level, upgraded_item_level, current_stat_multiplier, last_upgraded_timestamp, season_id) "
        "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}) "
        "ON DUPLICATE KEY UPDATE "
        "upgrade_level = VALUES(upgrade_level), "
        "essence_invested = VALUES(essence_invested), "
        "tokens_invested = VALUES(tokens_invested), "
        "upgraded_item_level = VALUES(upgraded_item_level), "
        "current_stat_multiplier = VALUES(current_stat_multiplier), "
        "last_upgraded_timestamp = VALUES(last_upgraded_timestamp)",
        item_guid, player_guid, static_cast<uint32>(upgrade_level), essence_invested, tokens_invested,
        base_item_level, upgraded_item_level, current_stat_multiplier, last_upgraded_timestamp, season_id);
    
    return true;
}

// ========== UpgradeManager Core Implementation ==========

class ItemUpgradeManagerImpl : public UpgradeManager
{
public:
    ItemUpgradeManagerImpl() = default;
    
    bool PerformItemUpgrade(uint32 player_guid, uint32 item_guid, uint32 essence_cost, uint32 token_cost) override
    {
        // Load item state
        ItemUpgradeState state;
        state.item_guid = item_guid;
        
        if (!state.LoadFromDatabase(item_guid))
        {
            // New item - initialize state
            Item* item = GetItemByGuid(player_guid, item_guid);
            if (!item)
                return false;
            
            ItemTemplate const* proto = item->GetTemplate();
            state.item_guid = item_guid;
            state.player_guid = player_guid;
            state.upgrade_level = 0;
            state.essence_invested = 0;
            state.tokens_invested = 0;
            state.base_item_level = proto->ItemLevel;
            state.upgraded_item_level = proto->ItemLevel;
            state.current_stat_multiplier = 1.0f;
            state.season_id = GetCurrentSeason();
        }
        
        // Perform upgrade
        uint8 next_level = state.upgrade_level + 1;
        if (next_level > 15)
            return false; // Already maxed
        
        uint8 tier_id = GetItemTier(state.base_item_level);
        
        // Deduct resources (assumed already validated by caller)
        // This just records the investment
        state.essence_invested += essence_cost;
        state.tokens_invested += token_cost;
        state.upgrade_level = next_level;
        
        // Recalculate stat multiplier and ilvl
        state.current_stat_multiplier = StatScalingCalculator::GetFinalMultiplier(next_level, tier_id);
        state.upgraded_item_level = ItemLevelCalculator::GetUpgradedItemLevel(
            state.base_item_level, next_level, tier_id);
        
        state.last_upgraded_timestamp = static_cast<uint32>(time(nullptr));
        
        // Save to database
        return state.SaveToDatabase();
    }
    
    bool CanUpgradeItem(uint32 item_guid, uint32 player_guid) override
    {
        Item* item = GetItemByGuid(player_guid, item_guid);
        if (!item)
            return false;
        
        ItemTemplate const* proto = item->GetTemplate();
        if (!proto)
            return false;
        
        // Check if item is upgradeable (quality checks, etc.)
        uint8 quality = proto->Quality;
        if (quality < ITEM_QUALITY_UNCOMMON || quality > ITEM_QUALITY_LEGENDARY)
            return false;
        
        // Check current upgrade level
        ItemUpgradeState state;
        state.item_guid = item_guid;
        
        if (state.LoadFromDatabase(item_guid))
        {
            if (state.upgrade_level >= 15)
                return false; // Already maxed
        }
        
        return true;
    }
    
    bool GetNextUpgradeCost(uint32 item_guid, uint32& out_essence, uint32& out_tokens) override
    {
        Item* item = nullptr;
        // In real implementation, would look up from inventory
        if (!item)
            return false;
        
        ItemUpgradeState state;
        state.item_guid = item_guid;
        
        if (!state.LoadFromDatabase(item_guid))
            state.upgrade_level = 0;
        
        uint8 tier_id = GetItemTier(state.base_item_level);
        
        out_essence = UpgradeCostCalculator::GetEssenceCost(tier_id, state.upgrade_level);
        out_tokens = UpgradeCostCalculator::GetTokenCost(tier_id, state.upgrade_level);
        
        return true;
    }
    
    std::string GetUpgradeDisplay(uint32 item_guid) override
    {
        ItemUpgradeState state;
        state.item_guid = item_guid;
        
        std::ostringstream oss;
        
        if (state.LoadFromDatabase(item_guid))
        {
            uint8 tier_id = GetItemTier(state.base_item_level);
            uint32 next_essence, next_tokens;
            
            oss << "|cffffd700===== Item Upgrade Status =====|r\n";
            oss << "Upgrade Level: " << static_cast<int>(state.upgrade_level) << "/15\n";
            oss << "Stat Bonus: " << StatScalingCalculator::GetStatBonusDisplay(state.upgrade_level, tier_id) << "\n";
            oss << "Item Level: " << ItemLevelCalculator::GetItemLevelDisplay(
                state.base_item_level, state.upgraded_item_level) << "\n";
            oss << "Total Investment: " << state.essence_invested << " Essence, " 
                << state.tokens_invested << " Tokens\n";
            
            if (state.upgrade_level < 15)
            {
                next_essence = UpgradeCostCalculator::GetEssenceCost(tier_id, state.upgrade_level);
                next_tokens = UpgradeCostCalculator::GetTokenCost(tier_id, state.upgrade_level);
                oss << "\n|cff00ff00Next Upgrade Cost:|r\n";
                oss << "Essence: " << next_essence << "\n";
                oss << "Tokens: " << next_tokens << "\n";
            }
            else
            {
                oss << "\n|cffff0000This item is fully upgraded!|r\n";
            }
        }
        else
        {
            oss << "|cffffd700===== Item Upgrade Status =====|r\n";
            oss << "Upgrade Level: 0/15 (New)\n";
            oss << "Stat Bonus: +0%\n";
            oss << "Total Investment: 0 Essence, 0 Tokens\n";
            oss << "\n|cff00ff00Next Upgrade Cost:|r\n";
            oss << "Essence: [Not yet determined]\n";
            oss << "Tokens: [Not yet determined]\n";
        }
        
        return oss.str();
    }

private:
    Item* GetItemByGuid(uint32 player_guid, uint32 item_guid)
    {
        // Placeholder - would integrate with actual inventory system
        return nullptr;
    }
    
    uint8 GetItemTier(uint16 item_level)
    {
        // Determine tier from item level
        if (item_level < 340)
            return 1; // Common
        else if (item_level < 355)
            return 2; // Uncommon
        else if (item_level < 370)
            return 3; // Rare
        else if (item_level < 385)
            return 4; // Epic
        else
            return 5; // Legendary
    }
    
    uint32 GetCurrentSeason()
    {
        // Placeholder - would query seasons table
        return 1;
    }
};

// ========== Global Manager Instance ==========

static ItemUpgradeManagerImpl sUpgradeManager;

UpgradeManager* GetUpgradeManager()
{
    return &sUpgradeManager;
}
