# Phase 4A: Item Upgrade Mechanics - Implementation Guide

**Status**: ✅ COMPLETE  
**Date**: November 4, 2025  
**Components**: 5 files total

---

## Overview

Phase 4A implements the **core mechanics** for item upgrades:
- Cost calculations with escalating formula
- Stat scaling multipliers based on tier
- Item level bonuses
- Database persistence
- NPC interface
- Admin commands

---

## Files Created

### 1. **ItemUpgradeMechanicsImpl.cpp** (Core Implementation)

**Purpose**: Implementation of all calculation engines and manager class

**Key Components**:

#### UpgradeCostCalculator
Calculates resource costs:

```cpp
// Get cost for single level upgrade
uint32 essence = UpgradeCostCalculator::GetEssenceCost(tier, current_level);
uint32 tokens = UpgradeCostCalculator::GetTokenCost(tier, current_level);

// Get cumulative cost to reach target
uint32 tokens_total, essence_total;
UpgradeCostCalculator::GetCumulativeCost(tier, target_level, tokens_total, essence_total);

// Get refund amount (50%)
uint32 refund = UpgradeCostCalculator::GetRefundCost(tokens_invested, essence_invested);
```

**Cost Formula**:
```
Cost = Base_Cost * (1.1 ^ level)

Base Costs by Tier:
- Common: 10 essence, 5 tokens
- Uncommon: 25 essence, 10 tokens
- Rare: 50 essence, 15 tokens
- Epic: 100 essence, 25 tokens
- Legendary: 200 essence, 50 tokens

Example - Rare tier level 5 → 6:
Essence = 50 * (1.1 ^ 5) = 50 * 1.61051 ≈ 80 essence
Token = 15 * (1.1 ^ 5) = 15 * 1.61051 ≈ 24 tokens
```

#### StatScalingCalculator
Manages stat bonus calculations:

```cpp
// Base stat multiplier for upgrade level
float mult = StatScalingCalculator::GetStatMultiplier(level);  // 1.0 + (level * 0.025)

// Tier adjustment
float tier_mult = StatScalingCalculator::GetTierMultiplier(tier_id);

// Combined multiplier
float final = StatScalingCalculator::GetFinalMultiplier(level, tier_id);

// Display format
std::string display = StatScalingCalculator::GetStatBonusDisplay(level, tier_id); // "+12.5%"
```

**Stat Scaling Formula**:
```
Base_Multiplier = 1.0 + (upgrade_level * 0.025)

Tier Multipliers:
- Common: 0.9x (reduces scaling)
- Uncommon: 0.95x
- Rare: 1.0x (no adjustment)
- Epic: 1.15x (enhances scaling)
- Legendary: 1.25x (maximum)

Final_Multiplier = (Base - 1.0) * Tier_Mult + 1.0

Example - Rare tier level 10:
Base = 1.0 + (10 * 0.025) = 1.25x
Final = (1.25 - 1.0) * 1.0 + 1.0 = 1.25x (+25% bonus)

Example - Epic tier level 10:
Base = 1.25x
Final = (1.25 - 1.0) * 1.15 + 1.0 = 1.288x (+28.8% bonus)
```

#### ItemLevelCalculator
Manages item level bonuses:

```cpp
// Get bonus for this level/tier
uint16 bonus = ItemLevelCalculator::GetItemLevelBonus(level, tier_id);

// Get upgraded ilvl
uint16 upgraded_ilvl = ItemLevelCalculator::GetUpgradedItemLevel(base_ilvl, level, tier_id);

// Get formatted display
std::string display = ItemLevelCalculator::GetItemLevelDisplay(base_ilvl, current_ilvl);
// Output: "400|cff00ff00 +15|r"
```

**Item Level Formula**:
```
Bonus_Per_Level by Tier:
- Common: +1 ilvl/level (max +15)
- Uncommon: +1 ilvl/level (max +15)
- Rare: +1.5 ilvl/level (max +22.5 → +22)
- Epic: +2 ilvl/level (max +30)
- Legendary: +2.5 ilvl/level (max +37.5 → +37)

Example - Rare tier 385 base at level 10:
Bonus = 10 * 1.5 = 15 ilvl
Upgraded = 385 + 15 = 400 ilvl
```

#### ItemUpgradeState Persistence
Represents upgrade state in database:

```cpp
struct ItemUpgradeState {
    uint32 item_guid;                  // Item's unique ID
    uint32 player_guid;                // Owner
    uint8 upgrade_level;               // 0-15
    uint32 essence_invested;           // Total spent
    uint32 tokens_invested;            // Total spent
    uint16 base_item_level;            // Original
    uint16 upgraded_item_level;        // Current
    float current_stat_multiplier;     // Current bonus %
    uint32 last_upgraded_timestamp;    // When upgraded
    uint32 season_id;                  // Season
};

// Load/Save
state.LoadFromDatabase(item_guid);
state.SaveToDatabase();
```

### 2. **phase4_item_upgrade_mechanics.sql** (Database Schema)

**Tables Created**:

#### item_upgrades (PRIMARY)
Stores upgrade state for each item
```sql
- item_guid (PK)
- player_guid
- upgrade_level (0-15)
- essence_invested
- tokens_invested
- base_item_level
- upgraded_item_level
- current_stat_multiplier
- last_upgraded_timestamp
- season_id
```

#### item_upgrade_log (TRANSACTION LOG)
Records every upgrade performed
```sql
- log_id (PK)
- player_guid
- item_guid
- upgrade_from/to
- essence_cost
- token_cost
- old_ilvl / new_ilvl
- timestamp
- season_id
```

#### item_upgrade_costs (CONFIGURATION)
Tier-based cost configuration
```sql
- tier_id (PK): 1-5
- tier_name: "Common", "Uncommon", etc.
- base_essence_cost
- base_token_cost
- escalation_rate: 1.1 (default)
- cost_multiplier
- stat_multiplier
- ilvl_multiplier
- max_upgrade_level
- enabled
```

**Populated Values**:
```
Tier 1 (Common):    10/5 essence/tokens, 0.8x cost, 0.9x stat, 1.0x ilvl, max 10
Tier 2 (Uncommon):  25/10, 1.0x cost, 0.95x stat, 1.0x ilvl, max 12
Tier 3 (Rare):      50/15, 1.2x cost, 1.0x stat, 1.5x ilvl, max 15
Tier 4 (Epic):      100/25, 1.5x cost, 1.15x stat, 2.0x ilvl, max 15
Tier 5 (Legendary): 200/50, 2.0x cost, 1.25x stat, 2.5x ilvl, max 15
```

#### item_upgrade_stat_scaling (CONFIGURATION)
Stat scaling configuration
```sql
- scaling_id (PK)
- base_multiplier_per_level: 0.025
- min_upgrade_level: 0
- max_upgrade_level: 15
- enabled: TRUE
```

**Views Created**:

`player_upgrade_summary`: Quick stats per player
```
- items_upgraded
- total_essence_spent
- total_tokens_spent
- average_stat_multiplier
- average_ilvl_gain
- fully_upgraded_items
```

`upgrade_speed_stats`: Upgrade frequency per player
```
- total_upgrades
- upgrades_per_day
- first/last upgrade times
- average_cost_per_upgrade
```

### 3. **ItemUpgradeNPC_Upgrader.cpp** (Player Interface)

**Features**:

#### Main Menu
```
- View Upgradeable Items
- View My Upgrade Statistics
- How does item upgrading work?
- Nevermind
```

#### View Upgradeable Items
Lists all items player can upgrade with clickable UI
```
Shows:
- Item name
- Item tier (derived from ilvl)
- Upgrade availability
```

#### Item Upgrade Detail
Per-item upgrade interface
```
Shows:
- Current upgrade level (0-15)
- Current stat bonus %
- Current item level (with color-coded bonus)
- Total investment to date
- Next upgrade cost
- Affordability check (can buy or needs more resources)
- UPGRADE BUTTON (if affordable)
```

#### Upgrade Statistics
Player's total upgrade progress
```
- Total items upgraded
- Fully upgraded items
- Total essence/tokens spent
- Average stat bonus
- Average item level gain
- Last upgrade time
```

#### Help Information
Educational content about system
```
- What is upgrading?
- Cost structure per tier
- Stat scaling explanation
- Item level bonuses
- Escalation mechanic
- Pro tips
```

**Code Structure**:
```cpp
class ItemUpgradeNPC_Upgrader : public CreatureScript
{
    bool OnGossipHello(Player* player, Creature* creature)
    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action)
    
private:
    void ShowUpgradableItems(Player*, Creature*)
    void ShowItemUpgradeUI(Player*, Creature*, uint32 item_guid)
    void ShowUpgradeStatistics(Player*, Creature*)
    void ShowHelpInformation(Player*, Creature*)
};
```

### 4. **ItemUpgradeMechanicsCommands.cpp** (Admin Tools)

**Commands**:

#### .upgrade mech cost
Shows upgrade costs
```
Usage: .upgrade mech cost <tier 1-5> <level 0-14>

Example: .upgrade mech cost 3 5
Output:
===== Upgrade Cost: Rare Level 5 → 6 =====
Current Level Cost:
  Essence: 80
  Tokens: 24
Cumulative Cost (0 → 6):
  Essence: 335
  Tokens: 101
```

#### .upgrade mech stats
Shows stat scaling multipliers
```
Usage: .upgrade mech stats <tier 1-5> <level 0-15>

Example: .upgrade mech stats 4 10
Output:
===== Stat Scaling: Epic Level 10 =====
Base Multiplier: 1.250x (25% bonus)
Tier Multiplier: 1.150x
Final Multiplier: 1.288x (28.8% bonus)
```

#### .upgrade mech ilvl
Shows item level bonuses
```
Usage: .upgrade mech ilvl <tier 1-5> <level 0-15> [base_ilvl]

Example: .upgrade mech ilvl 4 10 385
Output:
===== Item Level Calculation: Epic Level 10 =====
Base Item Level: 385
iLvL Bonus: 20
Upgraded Item Level: 405
```

#### .upgrade mech reset
Resets all upgrades for a player
```
Usage: .upgrade mech reset [player_name]

Safety Features:
- Counts items to reset
- Warns admin
- Requires second confirmation
```

---

## Integration Points

### Database
Run migration script:
```sql
source data/sql/custom/phase4_item_upgrade_mechanics.sql
```

### CMakeLists.txt
Files must be added to build system:
```cmake
# In src/server/scripts/DC/ItemUpgrades/CMakeLists.txt

set(scripts_DC_ItemUpgrades_SRCS
    ${scripts_DC_ItemUpgrades_SRCS}
    ItemUpgradeMechanicsImpl.cpp
    ItemUpgradeNPC_Upgrader.cpp
    ItemUpgradeMechanicsCommands.cpp
)
```

### Script Loader
Registration in script module:
```cpp
// In ScriptLoader.cpp or module initialization
AddSC_ItemUpgradeMechanics();          // From ItemUpgradeMechanicsImpl.cpp
AddSC_ItemUpgradeMechanicsCommands();  // From ItemUpgradeMechanicsCommands.cpp
```

---

## Usage Examples

### For Players

**Upgrade an item:**
1. Talk to Upgrade Upgrader NPC
2. Click "View Upgradeable Items"
3. Click on desired item
4. Review stats and cost
5. Click "PERFORM UPGRADE"
6. Confirm transaction

**Check progress:**
1. Talk to Upgrader NPC
2. Click "View My Upgrade Statistics"
3. See total items upgraded, resources spent, etc.

### For Admins

**Check costs:**
```
.upgrade mech cost 3 10
Shows essence/token cost from level 10 → 11 for Rare items
```

**Check stat bonuses:**
```
.upgrade mech stats 5 15
Shows final stat multiplier for Legendary item at max level
```

**Reset player:**
```
.upgrade mech reset PlayerName
Wipes all upgrades for that player
```

**Monitor database:**
```sql
SELECT * FROM player_upgrade_summary WHERE player_guid = X;
SELECT * FROM upgrade_speed_stats WHERE player_guid = X;
```

---

## Configuration

### Adjusting Costs

Edit `item_upgrade_costs` table:
```sql
UPDATE item_upgrade_costs 
SET base_essence_cost = 15 
WHERE tier_id = 2;  -- Adjust Uncommon costs
```

### Adjusting Stat Scaling

Edit `item_upgrade_stat_scaling` table:
```sql
UPDATE item_upgrade_stat_scaling 
SET base_multiplier_per_level = 0.03 
WHERE scaling_id = 1;  -- Change from 2.5% to 3% per level
```

### Enabling/Disabling Tiers

```sql
UPDATE item_upgrade_costs 
SET enabled = 0 
WHERE tier_id = 5;  -- Disable Legendary upgrades temporarily
```

---

## Formulas Reference

### Cost Escalation
```
Cost_at_level = Base_Cost * (1.1 ^ current_level)

Escalation Examples:
Level 0: Base * 1 = Base
Level 1: Base * 1.1 = Base + 10%
Level 2: Base * 1.21 = Base + 21%
Level 5: Base * 1.61051 = Base + 61%
Level 10: Base * 2.59374 = Base + 159%
Level 15: Base * 4.17725 = Base + 318%
```

### Stat Scaling
```
Final_Multiplier = (1.0 + level * 0.025 - 1.0) * Tier_Mult + 1.0
                 = level * 0.025 * Tier_Mult + 1.0
```

### Item Level Bonus
```
Total_Bonus = upgrade_level * bonus_per_level[tier]
Upgraded_iLvL = base_ilvl + total_bonus
```

---

## Performance Notes

- **Database queries**: Indexed on player_guid and season_id for fast lookups
- **Calculations**: All math is float-based for precision
- **Caching**: Consider caching ItemUpgradeState in memory for active upgrades
- **Logging**: Every upgrade transaction recorded for audit trail

---

## Next Steps (Phase 4B)

Phase 4B will add:
- Tier progression system
- Level caps and tier unlocking
- Prestige tracking
- Weekly cost caps
- Player statistics

Tier system prerequisites already in place:
- Database schema supports season_id
- Configuration tables allow per-tier adjustments
- Cost multipliers can be adjusted independently

---

**End of Phase 4A Documentation**
