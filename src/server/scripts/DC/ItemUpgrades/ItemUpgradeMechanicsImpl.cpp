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
        "base_item_level, upgraded_item_level, stat_multiplier, last_upgraded_at, season "
        "FROM dc_player_item_upgrades WHERE item_guid = {}", item_guid);
    
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
    stat_multiplier = fields[7].Get<float>();
    last_upgraded_at = fields[8].Get<time_t>();
    season = fields[9].Get<uint32>();
    
    return true;
}

bool ItemUpgradeState::SaveToDatabase() const
{
    // Use INSERT ... ON DUPLICATE KEY UPDATE for upsert
    CharacterDatabase.Execute(
        "INSERT INTO dc_player_item_upgrades (item_guid, player_guid, upgrade_level, essence_invested, tokens_invested, "
        "base_item_level, upgraded_item_level, stat_multiplier, last_upgraded_at, season) "
        "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}) "
        "ON DUPLICATE KEY UPDATE "
        "upgrade_level = VALUES(upgrade_level), "
        "essence_invested = VALUES(essence_invested), "
        "tokens_invested = VALUES(tokens_invested), "
        "upgraded_item_level = VALUES(upgraded_item_level), "
        "stat_multiplier = VALUES(stat_multiplier), "
        "last_upgraded_at = VALUES(last_upgraded_at)",
        item_guid, player_guid, static_cast<uint32>(upgrade_level), essence_invested, tokens_invested,
        base_item_level, upgraded_item_level, stat_multiplier, last_upgraded_at, season);
    
    return true;
}

// Local helper functions (used by mechanics implementations)
[[maybe_unused]] static Item* Mechanics_GetItemByGuid(uint32 /*player_guid*/, uint32 /*item_guid*/)
{
    // Placeholder - mechanics layer does not access inventory directly
    return nullptr;
}

[[maybe_unused]] static uint8 Mechanics_GetItemTierByIlvl(uint16 item_level)
{
    if (item_level < 340)
        return TIER_LEVELING;
    else if (item_level < 355)
        return TIER_HEROIC;
    else if (item_level < 370)
        return TIER_RAID;
    else if (item_level < 385)
        return TIER_MYTHIC;
    else
        return TIER_ARTIFACT;
}

[[maybe_unused]] static uint32 Mechanics_GetCurrentSeason()
{
    return 1; // TODO: wire to seasons DB
}

// (Do not define a global GetUpgradeManager here; use DarkChaos::ItemUpgrade::GetUpgradeManager())

// Registration function to ensure this file is linked
void AddSC_ItemUpgradeMechanicsImpl()
{
    // This function exists solely to force the linker to include this compilation unit.
    // The static functions (StatScalingCalculator, ItemLevelCalculator) are used by other modules.
}
