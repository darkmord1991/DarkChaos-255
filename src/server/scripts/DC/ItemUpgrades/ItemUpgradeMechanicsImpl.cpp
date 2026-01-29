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
#include "DC/CrossSystem/SeasonResolver.h"
#include "ScriptMgr.h"
#include "Item.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "WorldSession.h"
#include "StringFormat.h"
#include "Config.h"
#include "../Seasons/SeasonalSystem.h"
#include <cmath>

namespace
{
    // Ensure literal braces survive fmt formatting when inserting dynamic strings.
    void EscapeFmtBraces(std::string& text)
    {
        size_t pos = 0;
        while ((pos = text.find('{', pos)) != std::string::npos)
        {
            text.insert(pos, "{");
            pos += 2;
        }

        pos = 0;
        while ((pos = text.find('}', pos)) != std::string::npos)
        {
            text.insert(pos, "}");
            pos += 2;
        }
    }

    uint8 ResolveMaxUpgradeLevel(uint8 tier_id)
    {
        if (auto* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
        {
            uint8 maxLevel = mgr->GetTierMaxLevel(tier_id);
            if (maxLevel > 0)
                return maxLevel;
        }

        // Safe fallback for legacy mechanics helpers.
        return 15;
    }
}

using namespace DarkChaos::ItemUpgrade;

// ========== UpgradeCostCalculator Implementation ==========

uint32 UpgradeCostCalculator::GetEssenceCost(uint8 tier_id, uint8 current_level)
{
    // Artifact (Tier 5) items use essence currency for upgrades
    // Implementation enabled: Essence costs calculated based on tier and level

    uint8 maxLevel = ResolveMaxUpgradeLevel(tier_id);
    if (current_level >= maxLevel)
        return 0; // Already maxed

    // Base costs per tier
    static const float tier_costs[] = {
        10.0f,    // Tier 1: Common (not used - tokens only)
        25.0f,    // Tier 2: Uncommon (not used - tokens only)
        75.0f,    // Tier 3: Heirloom (HEIRLOOM - essence only)
        100.0f,   // Tier 4: Epic (not used - tokens only)
        200.0f    // Tier 5: Legendary (ARTIFACT - essence only)
    };

    if (tier_id < 1 || tier_id > 5)
        return 0;

    float base_cost = tier_costs[tier_id - 1];
    float escalated_cost = base_cost * std::pow(1.1f, static_cast<float>(current_level));

    return static_cast<uint32>(std::ceil(escalated_cost));
}

uint32 UpgradeCostCalculator::GetTokenCost(uint8 tier_id, uint8 current_level)
{
    uint8 maxLevel = ResolveMaxUpgradeLevel(tier_id);
    if (current_level >= maxLevel)
        return 0; // Already maxed

    // Token costs are roughly 50% of essence costs
    static const float tier_costs[] = {
        5.0f,     // Tier 1: Common
        10.0f,    // Tier 2: Uncommon
        0.0f,     // Tier 3: Heirloom (essence only, no tokens)
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

    uint8 maxLevel = ResolveMaxUpgradeLevel(tier_id);
    if (target_level > maxLevel)
        target_level = maxLevel;

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
    //
    // Note: For Heirlooms (Tier 3), use GetStatMultiplierHeirloom() instead
    // This function only affects secondary stats added via enchants
    return 1.0f + (upgrade_level * 0.025f);
}

float StatScalingCalculator::GetStatMultiplierHeirloom(uint8 upgrade_level)
{
    // Heirloom-specific formula: 1.05 + (level * 0.02)
    // Level 0: 1.05x (+5% bonus)
    // Level 5: 1.15x (+15% bonus)
    // Level 10: 1.25x (+25% bonus)
    // Level 15: 1.35x (+35% bonus)
    //
    // IMPORTANT: This ONLY affects secondary stats (Crit/Haste/Hit/Expertise/ArmorPen)
    // Note: Mastery stat does not exist in WotLK 3.3.5a (was added in Cataclysm 4.0.1)
    // Primary stats (STR/AGI/INT/STA/SPI) are handled by heirloom_scaling_255.cpp
    return 1.05f + (upgrade_level * 0.02f);
}

float StatScalingCalculator::GetTierMultiplier(uint8 tier_id)
{
    // Tier-based adjustments to stat scaling
    static const float tier_multipliers[] = {
        0.9f,     // Tier 1: Common (reduces scaling)
        0.95f,    // Tier 2: Uncommon
        1.0f,     // Tier 3: Heirloom (no adjustment - has own multiplier)
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
    oss << "|cff00ff00+" << static_cast<int>(std::round(bonus_percent)) << "%|r";
    return oss.str();
}

// ========== ItemLevelCalculator Implementation ==========

uint16 ItemLevelCalculator::GetItemLevelBonus(uint8 upgrade_level, uint8 tier_id)
{
    // Base ilvl bonus per level by tier
    static const float tier_ilvl_per_level[] = {
        1.0f,     // Tier 1: Common
        1.0f,     // Tier 2: Uncommon
        0.0f,     // Tier 3: Heirloom (item level scales with player level)
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

    uint8 maxLevel = ResolveMaxUpgradeLevel(tier_id);

    float current_mult = StatScalingCalculator::GetFinalMultiplier(state.upgrade_level, tier_id);
    uint16 upgraded_ilvl = ItemLevelCalculator::GetUpgradedItemLevel(
        state.base_item_level, state.upgrade_level, tier_id);

    ss << "|cff00ff00Upgrade Level: " << static_cast<int>(state.upgrade_level) << "/" << static_cast<int>(maxLevel) << "|r\n";
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
        "SELECT item_guid, player_guid, base_item_name, tier_id, upgrade_level, tokens_invested, essence_invested, "
        "stat_multiplier, first_upgraded_at, last_upgraded_at, season "
        "FROM {} WHERE item_guid = {}", ITEM_UPGRADES_TABLE, item_guid);

    if (!result)
        return false;

    Field* fields = result->Fetch();
    this->item_guid = fields[0].Get<uint32>();
    this->player_guid = fields[1].Get<uint32>();
    this->base_item_name = fields[2].Get<std::string>();
    this->tier_id = fields[3].Get<uint8>();
    this->upgrade_level = fields[4].Get<uint8>();
    this->tokens_invested = fields[5].Get<uint32>();
    this->essence_invested = fields[6].Get<uint32>();
    this->stat_multiplier = fields[7].Get<float>();
    this->first_upgraded_at = fields[8].Get<time_t>();
    this->last_upgraded_at = fields[9].Get<time_t>();
    this->season = fields[10].Get<uint32>();

    return true;
}

bool ItemUpgradeState::SaveToDatabase() const
{
    std::string baseName = base_item_name;
    CharacterDatabase.EscapeString(baseName);
    EscapeFmtBraces(baseName);

    // Use INSERT ... ON DUPLICATE KEY UPDATE for upsert
    CharacterDatabase.Execute(
        "INSERT INTO {} (item_guid, player_guid, base_item_name, tier_id, upgrade_level, essence_invested, tokens_invested, "
        "stat_multiplier, first_upgraded_at, last_upgraded_at, season) "
        "VALUES ({}, {}, '{}', {}, {}, {}, {}, {}, {}, {}, {}) "
        "ON DUPLICATE KEY UPDATE "
        "base_item_name = VALUES(base_item_name), "
        "upgrade_level = VALUES(upgrade_level), "
        "essence_invested = VALUES(essence_invested), "
        "tokens_invested = VALUES(tokens_invested), "
        "stat_multiplier = VALUES(stat_multiplier), "
        "last_upgraded_at = VALUES(last_upgraded_at)",
        ITEM_UPGRADES_TABLE,
        item_guid, player_guid, baseName, static_cast<uint32>(tier_id), static_cast<uint32>(upgrade_level), essence_invested, tokens_invested,
        stat_multiplier, static_cast<uint32>(first_upgraded_at), static_cast<uint32>(last_upgraded_at), season);

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
    if (item_level < 213)
        return TIER_LEVELING;
    else if (item_level <= 226)
        return TIER_HEROIC;
    else
        return TIER_HEIRLOOM;  // Heirlooms or high-level items
}

[[maybe_unused]] static uint32 Mechanics_GetCurrentSeason()
{
    // Wire to generic seasonal system if available
    if (DarkChaos::Seasonal::GetSeasonalManager())
    {
        auto* activeSeason = DarkChaos::Seasonal::GetSeasonalManager()->GetActiveSeason();
        if (activeSeason)
            return activeSeason->season_id;
    }

    // Fallback to config or default
    return sConfigMgr->GetOption<uint32>("DarkChaos.ActiveSeasonID", 1);
}

// (Do not define a global GetUpgradeManager here; use DarkChaos::ItemUpgrade::GetUpgradeManager())

namespace
{
    class ItemUpgradeInitWorldScript : public WorldScript
    {
    public:
        ItemUpgradeInitWorldScript() : WorldScript("ItemUpgradeInitWorldScript") {}

        void OnStartup() override
        {
            uint32 season = DarkChaos::ItemUpgrade::GetCurrentSeasonId();
            if (UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
                mgr->LoadUpgradeData(season);
        }
    };
}

// Registration function to ensure this file is linked
void AddSC_ItemUpgradeMechanicsImpl()
{
    // This function exists solely to force the linker to include this compilation unit.
    // The static functions (StatScalingCalculator, ItemLevelCalculator) are used by other modules.

    new ItemUpgradeInitWorldScript();
}
