# Phase 4: Item Spending System - Complete Implementation Guide

**Status**: Architecture & Header Files Complete ✅  
**Phase 4A**: Item Upgrade Mechanics - COMPLETE  
**Phase 4B**: Upgrade Progression System - COMPLETE  
**Phase 4C**: Seasonal Reset & Balance - COMPLETE  
**Phase 4D**: Advanced Features - COMPLETE  

**Date**: November 4, 2025  
**Author**: DarkChaos Development Team

---

## Table of Contents

1. [Phase 4A: Item Upgrade Mechanics](#phase-4a-item-upgrade-mechanics)
2. [Phase 4B: Upgrade Progression System](#phase-4b-upgrade-progression-system)
3. [Phase 4C: Seasonal Reset & Balance](#phase-4c-seasonal-reset--balance)
4. [Phase 4D: Advanced Features](#phase-4d-advanced-features)
5. [Database Schema](#database-schema)
6. [Implementation Roadmap](#implementation-roadmap)
7. [API Reference](#api-reference)

---

## Phase 4A: Item Upgrade Mechanics

### Overview
Phase 4A implements the core mechanics for upgrading items using tokens and essence earned in Phase 3.

### Core Components

#### 1. ItemUpgradeState Structure
Represents the upgrade state of a single item:

```cpp
struct ItemUpgradeState {
    uint32 item_guid;                  // Unique item identifier
    uint32 player_guid;                // Owner
    uint8 upgrade_level;               // 0-15 (0 = base, 15 = max)
    uint32 essence_invested;           // Total essence spent
    uint32 tokens_invested;            // Total tokens spent
    uint16 base_item_level;            // Original ilvl
    uint16 upgraded_item_level;        // Current ilvl
    float current_stat_multiplier;     // Stat scaling (1.0 = 0%, 1.25 = +25%)
    uint32 last_upgraded_timestamp;    // Last upgrade time
    uint32 season_id;                  // Season when upgraded
};
```

#### 2. UpgradeCostCalculator
Calculates costs based on item tier and level:

**Essence Costs** (per tier):
- Common: 10 → 11 → 12.1 → ... (10% escalation)
- Uncommon: 25 → 27.5 → 30.25 → ...
- Rare: 50 → 55 → 60.5 → ...
- Epic: 100 → 110 → 121 → ...
- Legendary: 200 → 220 → 242 → ...

**Token Costs** (per tier):
- Common: 5 → 5.5 → 6.05 → ...
- Uncommon: 10 → 11 → 12.1 → ...
- Rare: 15 → 16.5 → 18.15 → ...
- Epic: 25 → 27.5 → 30.25 → ...
- Legendary: 50 → 55 → 60.5 → ...

**Formula**:
```
Cost_at_level = Base_Cost * (1.1 ^ current_level)
```

#### 3. StatScalingCalculator
Calculates stat multipliers:

**Base Multiplier**:
```
Multiplier = 1.0 + (upgrade_level * 0.025)
```
- Level 0: 1.0x (0% bonus)
- Level 5: 1.125x (+12.5% bonus)
- Level 10: 1.25x (+25% bonus)
- Level 15: 1.375x (+37.5% bonus)

**Tier Adjustments**:
- Common: 0.9x (reduces scaling)
- Uncommon: 0.95x
- Rare: 1.0x (no adjustment)
- Epic: 1.15x (enhances scaling)
- Legendary: 1.25x (maximum scaling)

**Combined Formula**:
```
Final_Multiplier = (Base_Multiplier - 1.0) * Tier_Multiplier + 1.0
```

#### 4. ItemLevelCalculator
Calculates item level bonuses:

**Bonus per Level** (by tier):
- Common/Uncommon: +1 ilvl/level (max +15)
- Rare: +1.5 ilvl/level (max +22.5 → rounds to +22)
- Epic: +2 ilvl/level (max +30)
- Legendary: +2.5 ilvl/level (max +37.5 → rounds to +37)

**Example**:
- Base item: 385 ilvl, Rare tier, level 10 upgrade
- Bonus: 10 * 1.5 = 15 ilvl
- Final: 385 + 15 = 400 ilvl

### Upgrade Mechanics Flow

1. **Player interacts with NPC** → Shows UI with current item stats
2. **Cost calculation** → Displays next upgrade cost
3. **Validation** → Check player has resources & item can be upgraded
4. **Upgrade execution**:
   - Deduct tokens & essence
   - Increment upgrade level
   - Recalculate stats & ilvl
   - Update database
5. **Feedback** → Show new stats & progression

### Database Tables (Phase 4A)

```sql
CREATE TABLE item_upgrades (
    item_guid INT UNSIGNED PRIMARY KEY,
    player_guid INT UNSIGNED,
    upgrade_level TINYINT UNSIGNED DEFAULT 0,
    essence_invested INT UNSIGNED DEFAULT 0,
    tokens_invested INT UNSIGNED DEFAULT 0,
    base_item_level SMALLINT UNSIGNED,
    upgraded_item_level SMALLINT UNSIGNED,
    current_stat_multiplier FLOAT DEFAULT 1.0,
    last_upgraded_timestamp INT UNSIGNED,
    season_id INT UNSIGNED DEFAULT 1,
    FOREIGN KEY (player_guid) REFERENCES characters(guid)
);
```

---

## Phase 4B: Upgrade Progression System

### Overview
Manages tier-based progression, level caps, cost scaling, and prestige tracking.

### Core Components

#### 1. TierProgressionConfig
Configuration for each item tier:

```cpp
struct TierProgressionConfig {
    uint8 tier_id;                     // 1-5
    uint8 max_upgrade_level;           // Max level for tier
    float cost_multiplier;             // Cost adjustment
    float stat_multiplier;             // Stat bonus adjustment
    float ilvl_multiplier;             // Ilvl bonus adjustment
    uint32 prestige_points_per_level;  // Points awarded
    bool requires_unlocking;           // Must unlock?
    uint32 unlock_cost_tokens;         // Unlock cost
    uint32 unlock_cost_essence;
    std::string tier_name;
};
```

**Default Configuration**:

| Tier | Name | Max Level | Prestige/Lvl | Cost Multi | Stat Multi | Ilvl Multi |
|------|------|-----------|--------------|-----------|-----------|-----------|
| 1 | Common | 10 | 5 | 0.8x | 0.9x | 1.0x |
| 2 | Uncommon | 12 | 10 | 1.0x | 0.95x | 1.0x |
| 3 | Rare | 15 | 15 | 1.2x | 1.0x | 1.5x |
| 4 | Epic | 15 | 25 | 1.5x | 1.15x | 2.0x |
| 5 | Legendary | 15 | 50 | 2.0x | 1.25x | 2.5x |

#### 2. LevelCapManager
Controls maximum upgrade levels per player:

```cpp
// Example progression gates:
bool CanUpgradeToLevel(player_guid, target_level, tier_id) {
    // Level 0-5: Always available
    // Level 6-10: Requires previous tier at max
    // Level 11-15: Requires prestige rank 10+
}
```

**Tier Unlocking**:
- Common: Automatically unlocked
- Uncommon: Unlock at prestige rank 1 (or manually purchase)
- Rare: Unlock at prestige rank 5
- Epic: Unlock at prestige rank 10
- Legendary: Unlock at prestige rank 20

#### 3. CostScalingConfig
Dynamic cost adjustments:

```cpp
struct CostScalingConfig {
    float base_escalation_rate;        // 1.1 (10% per level)
    float tier_multipliers[6];         // Per-tier adjustments
    uint32 softcap_weekly_essence;     // 1000 (warning)
    uint32 hardcap_weekly_essence;     // 2000 (blocking)
    uint32 softcap_weekly_tokens;      // 500
    uint32 hardcap_weekly_tokens;      // 1000
    bool enable_weekly_caps;
    uint32 cap_reset_day;              // 0 = Sunday
};
```

**Weekly Caps**:
- Soft cap: Shows warning, allows continuation
- Hard cap: Blocks upgrades until next week

#### 4. PrestigeManager
Tracks prestige progression:

```cpp
struct PlayerPrestigeInfo {
    uint32 player_guid;
    uint32 total_prestige_points;      // Total earned
    uint8 prestige_rank;               // 0+ (cumulative)
    uint32 prestige_points_this_rank;  // Progress to next
    uint32 items_fully_upgraded;       // Fully maxed items
    uint32 total_upgrades_applied;     // Total upgrades
    uint64 last_upgrade_timestamp;
    std::string prestige_title;        // Dynamic title
};

// Prestige Titles:
// 0-4: Novice Upgrader
// 5-9: Skilled Upgrader
// 10-19: Master Upgrader
// 20-49: Grand Master
// 50-99: Artifact Lord
// 100+: Supreme Artifact Master
```

**Prestige Points Earned**:
- Per upgrade: Tier * 10 points
  - Common: 5 points/level
  - Uncommon: 10 points/level
  - Rare: 15 points/level
  - Epic: 25 points/level
  - Legendary: 50 points/level

- Per fully upgraded item (all 15 levels): 500 bonus points

- Seasonal achievements: 100-1000 points

**Prestige Rank Progression**:
- Each rank requires 1000 points
- Rank 0→1: 1000 points
- Rank 1→2: 2000 total (1000 more)
- etc.

#### 5. ProgressionStatistics
Tracks player statistics:

```cpp
struct ProgressionStatistics {
    uint32 player_guid;
    uint32 total_items_upgraded;       // Items with ≥1 upgrade
    uint32 total_upgrades;             // Total upgrades applied
    uint32 fully_upgraded_items;       // Items at max level
    uint32 items_per_tier[6];          // Count per tier
    uint32 total_essence_spent;
    uint32 total_tokens_spent;
    float average_ilvl_gain;           // Avg ilvl increase per item
    float average_stat_bonus;          // Avg stat multiplier
    uint64 days_active;                // Days since first upgrade
    uint64 last_activity;
};
```

### Database Tables (Phase 4B)

```sql
CREATE TABLE player_prestige (
    player_guid INT UNSIGNED PRIMARY KEY,
    total_prestige_points INT UNSIGNED DEFAULT 0,
    prestige_rank TINYINT UNSIGNED DEFAULT 0,
    prestige_points_this_rank INT UNSIGNED DEFAULT 0,
    items_fully_upgraded INT UNSIGNED DEFAULT 0,
    total_upgrades_applied INT UNSIGNED DEFAULT 0,
    last_upgrade_timestamp INT UNSIGNED,
    FOREIGN KEY (player_guid) REFERENCES characters(guid)
);

CREATE TABLE player_tier_caps (
    player_guid INT UNSIGNED,
    tier_id TINYINT UNSIGNED,
    max_level TINYINT UNSIGNED DEFAULT 0,
    is_unlocked BOOLEAN DEFAULT FALSE,
    unlock_timestamp INT UNSIGNED,
    PRIMARY KEY (player_guid, tier_id),
    FOREIGN KEY (player_guid) REFERENCES characters(guid)
);

CREATE TABLE player_progression_stats (
    player_guid INT UNSIGNED PRIMARY KEY,
    total_items_upgraded INT UNSIGNED DEFAULT 0,
    total_upgrades INT UNSIGNED DEFAULT 0,
    fully_upgraded_items INT UNSIGNED DEFAULT 0,
    total_essence_spent INT UNSIGNED DEFAULT 0,
    total_tokens_spent INT UNSIGNED DEFAULT 0,
    average_ilvl_gain FLOAT DEFAULT 0.0,
    first_upgrade_timestamp INT UNSIGNED,
    last_upgrade_timestamp INT UNSIGNED,
    FOREIGN KEY (player_guid) REFERENCES characters(guid)
);
```

---

## Phase 4C: Seasonal Reset & Balance

### Overview
Manages seasonal progression, resets, and dynamic balance adjustments.

### Core Components

#### 1. Season Structure
```cpp
struct Season {
    uint32 season_id;                  // Unique ID
    std::string season_name;           // e.g. "Season 1: Awakening"
    uint64 start_timestamp;            // When season starts
    uint64 end_timestamp;              // When season ends (0 = ongoing)
    bool is_active;                    // Currently active?
    uint32 max_upgrade_level;          // Max level in season
    float cost_multiplier;             // Cost adjustment
    float reward_multiplier;           // Prestige multiplier
    std::string theme;                 // Theme description
    uint32 milestone_essence_cap;      // Total essence available
    uint32 milestone_token_cap;        // Total tokens available
};
```

**Example Season**:
```
Season 1: Awakening
- Duration: 90 days
- Max Level: 15
- Cost Multiplier: 1.0x
- Theme: "The beginning of artifact mastery"
- Essence Cap: 50,000
- Token Cap: 25,000
```

#### 2. SeasonPlayerData
Tracks player data per season:

```cpp
struct SeasonPlayerData {
    uint32 player_guid;
    uint32 season_id;
    uint32 essence_earned;
    uint32 tokens_earned;
    uint32 essence_spent;
    uint32 tokens_spent;
    uint32 items_upgraded;
    uint32 upgrades_applied;
    uint32 prestige_earned;
    uint8 rank_this_season;            // Leaderboard rank
    uint64 first_upgrade_timestamp;
    uint64 last_upgrade_timestamp;
    std::map<uint32, uint8> item_max_levels;
};
```

#### 3. SeasonResetConfig
Controls reset behavior:

```cpp
struct SeasonResetConfig {
    bool carry_over_prestige;          // Default: TRUE
    bool reset_item_upgrades;          // Default: FALSE
    bool reset_currencies;             // Default: FALSE
    uint32 prestige_carryover_percent; // Default: 100%
    uint32 token_carryover_percent;    // Default: 10%
    uint32 essence_carryover_percent;  // Default: 5%
    bool award_season_rewards;         // Default: TRUE
    bool preserve_statistics;          // Default: TRUE
};
```

**Season Transition Example**:
```
Season 1 End:
- Player had: 10,000 tokens, 5,000 essence, 50 prestige rank
- Carryover: 50 prestige rank (100%)
- Reset to Season 2 with: 1,000 tokens (10%), 250 essence (5%), Prestige rank 50 maintained
```

#### 4. BalanceAdjustment
Dynamic balance changes:

```cpp
struct BalanceAdjustment {
    uint32 adjustment_id;
    uint64 timestamp;
    std::string description;           // What changed?
    std::string change_details;        // Details
    uint32 season_id;
    float impact_multiplier;           // 0.5x = 50% cost, 2.0x = 200% cost
    bool is_active;
};

// Examples:
// "Double essence rewards during weekends" → Multiplier 2.0x
// "50% token cost reduction" → Multiplier 0.5x
// "Rare tier balance adjustment" → Multiplier 1.1x
```

#### 5. UpgradeHistoryEntry
Records all upgrade events:

```cpp
struct UpgradeHistoryEntry {
    uint32 player_guid;
    uint32 item_guid;
    uint32 item_id;
    uint8 season_id;
    uint8 upgrade_from;                // Previous level
    uint8 upgrade_to;                  // New level
    uint32 essence_cost;               // Actual cost paid
    uint32 token_cost;
    uint64 timestamp;
    uint16 old_ilvl;
    uint16 new_ilvl;
};
```

#### 6. LeaderboardManager
Season leaderboards:

**Leaderboard Types**:
1. **Upgrade Count**: Most upgrades this season
2. **Prestige Points**: Most prestige earned
3. **Efficiency**: Upgrades per essence spent
4. **Items Upgraded**: Most items upgraded
5. **Speed Run**: First to reach certain milestones

```sql
SELECT RANK() OVER (ORDER BY upgrades DESC) as rank,
       player_guid, player_name, upgrades, prestige, items
FROM season_leaderboard
WHERE season_id = 1
LIMIT 25;
```

### Database Tables (Phase 4C)

```sql
CREATE TABLE seasons (
    season_id INT UNSIGNED PRIMARY KEY,
    season_name VARCHAR(100),
    start_timestamp INT UNSIGNED,
    end_timestamp INT UNSIGNED,
    is_active BOOLEAN DEFAULT FALSE,
    max_upgrade_level TINYINT UNSIGNED DEFAULT 15,
    cost_multiplier FLOAT DEFAULT 1.0,
    reward_multiplier FLOAT DEFAULT 1.0,
    theme VARCHAR(255),
    milestone_essence_cap INT UNSIGNED DEFAULT 50000,
    milestone_token_cap INT UNSIGNED DEFAULT 25000
);

CREATE TABLE season_player_data (
    player_guid INT UNSIGNED,
    season_id INT UNSIGNED,
    essence_earned INT UNSIGNED DEFAULT 0,
    tokens_earned INT UNSIGNED DEFAULT 0,
    essence_spent INT UNSIGNED DEFAULT 0,
    tokens_spent INT UNSIGNED DEFAULT 0,
    items_upgraded INT UNSIGNED DEFAULT 0,
    upgrades_applied INT UNSIGNED DEFAULT 0,
    prestige_earned INT UNSIGNED DEFAULT 0,
    rank_this_season INT UNSIGNED,
    first_upgrade_timestamp INT UNSIGNED,
    last_upgrade_timestamp INT UNSIGNED,
    PRIMARY KEY (player_guid, season_id),
    FOREIGN KEY (player_guid) REFERENCES characters(guid),
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
);

CREATE TABLE upgrade_history (
    history_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    player_guid INT UNSIGNED,
    item_guid INT UNSIGNED,
    item_id INT UNSIGNED,
    season_id INT UNSIGNED,
    upgrade_from TINYINT UNSIGNED,
    upgrade_to TINYINT UNSIGNED,
    essence_cost INT UNSIGNED,
    token_cost INT UNSIGNED,
    timestamp INT UNSIGNED,
    old_ilvl SMALLINT UNSIGNED,
    new_ilvl SMALLINT UNSIGNED,
    INDEX idx_player (player_guid),
    INDEX idx_season (season_id),
    FOREIGN KEY (player_guid) REFERENCES characters(guid),
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
);

CREATE TABLE balance_adjustments (
    adjustment_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    timestamp INT UNSIGNED,
    description VARCHAR(255),
    change_details TEXT,
    season_id INT UNSIGNED,
    impact_multiplier FLOAT DEFAULT 1.0,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
);
```

---

## Phase 4D: Advanced Features

### Overview
Advanced mechanics for optimization, trading, achievements, and guild progression.

### 1. Spec-Based Optimization

**StatLoadout Structure**:
```cpp
struct StatLoadout {
    uint32 loadout_id;
    uint32 player_guid;
    uint8 spec_id;                     // 0=Spec1, 1=Spec2, 2=Spec3
    std::string loadout_name;          // Custom name
    std::map<uint32, uint8> item_upgrades;  // Item GUID → Level
    std::map<std::string, int> stat_weights;  // Stat → Weight (for optimization)
    uint32 created_timestamp;
    uint32 last_used_timestamp;
    bool is_active;
};
```

**Stat Weights Example** (DPS Spec):
```
{
    "Strength": 100,
    "Attack Power": 80,
    "Critical Strike": 60,
    "Haste": 50,
    "Armor": -10  // Negative = reduce
}
```

**Auto-Optimize Algorithm**:
1. For each item slot
2. Calculate total stat bonus based on loadout weights
3. Recommend upgrade priority
4. Allow manual override

### 2. Transmog Integration

**Transmog Preset**:
```cpp
struct UpgradeTransmogPreset {
    uint32 preset_id;
    uint32 player_guid;
    std::string preset_name;           // "Raid Set", "PvP Gear", etc.
    std::map<uint32, uint32> item_display_map;  // Slot → Display Item ID
    std::map<uint32, uint8> item_upgrades;      // Item → Upgrade Level
    bool preserve_on_transmog;         // Keep upgrades when transmog?
    uint32 created_timestamp;
};
```

**Workflow**:
1. Player saves current gear as transmog preset
2. Applies transmog to display certain items
3. Upgrades are preserved on transmogged items (configurable)
4. Can revert to saved preset

### 3. Achievement System

**Custom Achievements**:

| ID | Name | Requirement | Reward |
|----|------|-------------|--------|
| 1 | First Upgrade | Upgrade any item to level 1 | 50 prestige |
| 2 | Novice Upgrader | Reach prestige rank 1 | 100 prestige |
| 3 | Master Upgrader | Reach prestige rank 10 | 500 prestige |
| 4 | Legendary Collector | Upgrade 5 legendary items | 1000 prestige |
| 5 | Efficiency Expert | Spend 1000 essence on 20 upgrades | 250 prestige |
| 6 | Weekly Champion | Win weekly leaderboard | 500 prestige + 1000 tokens |
| 7 | All-Star | Upgrade items from all tiers | 300 prestige |
| 8 | Speed Runner | Reach prestige rank 5 in 7 days | 200 prestige |
| 9 | Prestige Legend | Reach prestige rank 50 | 5000 prestige |

### 4. Item Trading

**Trading Configuration**:
```cpp
struct TradingConfig {
    bool allow_upgrade_trading;        // TRUE
    bool preserve_upgrades_on_trade;   // TRUE
    uint32 trade_tax_percent;          // 10%
    uint32 min_level_to_trade;         // 3
    bool require_same_ilvl;            // FALSE
    uint32 cooldown_minutes;           // 60
};
```

**Trade Example**:
```
Player A: Has upgraded helmet (level 10)
Player B: Has non-upgraded helmet (level 0)

Trade:
- Player A gives helmet to Player B
- Upgrade level 10 transfers (if preserve_upgrades_on_trade = TRUE)
- Player B's helmet is now level 10 with bonuses
- Tax: 10% of investment refunded/withheld (server adjusts resources)
```

### 5. Respec System

**Respec Options**:

| Type | Cost (Tokens/Essence) | Daily Limit | Details |
|------|-----|-----|---------|
| Single Item | 100 / 50 | Unlimited | Downgrade one item |
| Partial (3 items) | 250 / 150 | 3 | Downgrade multiple items |
| Full Respec | 1000 / 500 | 1 | Reset all items to base |

**Refund**: 50% of invested resources returned

**Example**:
```
Item was upgraded to level 8 (cost: 300 tokens, 150 essence)
Respec cost: 100 tokens, 50 essence
Refund: 150 tokens, 75 essence
Result: -50 tokens, -25 essence net

Full respec all items:
- Cost: 1000 tokens, 500 essence
- Refund: 50% of total investment
```

### 6. Guild Progression

**Guild Statistics**:
```cpp
struct GuildUpgradeStats {
    uint32 guild_id;
    std::string guild_name;
    uint32 total_members;
    uint32 members_with_upgrades;      // % of guild actively upgrading
    uint32 total_guild_upgrades;       // Total upgrades by members
    uint32 total_items_upgraded;       // Total items upgraded
    float average_ilvl_increase;       // Avg ilvl gain
    uint32 total_essence_invested;     // Total by guild
    uint32 total_tokens_invested;
    uint64 last_updated;
};
```

**Guild Tiers**:

| Tier | Total Upgrades | Bonus |
|------|-----|---------|
| 1 | 0-100 | None |
| 2 | 101-500 | +5% prestige gain for members |
| 3 | 501-1000 | +10% prestige, +5% token drop |
| 4 | 1001-5000 | +15% prestige, +10% token drop, +5% essence drop |
| 5 | 5001+ | +20% prestige, +15% token, +10% essence, weekly bonus |

### Database Tables (Phase 4D)

```sql
CREATE TABLE stat_loadouts (
    loadout_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    player_guid INT UNSIGNED,
    spec_id TINYINT UNSIGNED,
    loadout_name VARCHAR(100),
    item_weights JSON,                 -- Stat weights
    created_timestamp INT UNSIGNED,
    last_used_timestamp INT UNSIGNED,
    is_active BOOLEAN DEFAULT FALSE,
    INDEX idx_player (player_guid),
    FOREIGN KEY (player_guid) REFERENCES characters(guid)
);

CREATE TABLE transmog_presets (
    preset_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    player_guid INT UNSIGNED,
    preset_name VARCHAR(100),
    item_display_map JSON,
    preserve_upgrades BOOLEAN DEFAULT TRUE,
    created_timestamp INT UNSIGNED,
    INDEX idx_player (player_guid),
    FOREIGN KEY (player_guid) REFERENCES characters(guid)
);

CREATE TABLE achievements (
    achievement_id INT UNSIGNED PRIMARY KEY,
    name VARCHAR(100),
    description TEXT,
    reward_prestige INT UNSIGNED DEFAULT 0,
    reward_tokens INT UNSIGNED DEFAULT 0,
    is_hidden BOOLEAN DEFAULT FALSE,
    unlock_type VARCHAR(50),
    unlock_requirement INT UNSIGNED
);

CREATE TABLE player_achievements (
    player_guid INT UNSIGNED,
    achievement_id INT UNSIGNED,
    earned_timestamp INT UNSIGNED,
    PRIMARY KEY (player_guid, achievement_id),
    FOREIGN KEY (player_guid) REFERENCES characters(guid),
    FOREIGN KEY (achievement_id) REFERENCES achievements(achievement_id)
);

CREATE TABLE trade_records (
    trade_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    player_from INT UNSIGNED,
    player_to INT UNSIGNED,
    item_from_guid INT UNSIGNED,
    item_to_guid INT UNSIGNED,
    upgrade_level_transferred TINYINT UNSIGNED,
    timestamp INT UNSIGNED,
    was_taxed BOOLEAN DEFAULT FALSE,
    tax_amount INT UNSIGNED DEFAULT 0,
    FOREIGN KEY (player_from) REFERENCES characters(guid),
    FOREIGN KEY (player_to) REFERENCES characters(guid)
);

CREATE TABLE guild_upgrade_stats (
    guild_id INT UNSIGNED PRIMARY KEY,
    total_guild_upgrades INT UNSIGNED DEFAULT 0,
    total_items_upgraded INT UNSIGNED DEFAULT 0,
    average_ilvl_increase FLOAT DEFAULT 0.0,
    total_essence_invested INT UNSIGNED DEFAULT 0,
    total_tokens_invested INT UNSIGNED DEFAULT 0,
    guild_tier TINYINT UNSIGNED DEFAULT 1,
    last_updated INT UNSIGNED
);
```

---

## Database Schema

### Core Tables Summary

**item_upgrades**: Item upgrade states  
**player_prestige**: Prestige tracking  
**player_tier_caps**: Tier unlocks per player  
**player_progression_stats**: Overall statistics  
**seasons**: Season definitions  
**season_player_data**: Per-season player data  
**upgrade_history**: Complete upgrade log  
**balance_adjustments**: Seasonal balance changes  
**stat_loadouts**: Spec optimization presets  
**transmog_presets**: Transmog loadouts  
**achievements**: Achievement definitions  
**player_achievements**: Player achievement progress  
**trade_records**: Item trades  
**guild_upgrade_stats**: Guild-wide statistics  

---

## Implementation Roadmap

### Phase 4 Next Steps (Not Yet Implemented)

**4.1**: Create ItemUpgradeMechanicsImpl.cpp
- Implement UpgradeCostCalculator
- Implement StatScalingCalculator
- Implement ItemLevelCalculator
- Implement core upgrade logic

**4.2**: Create ItemUpgradeProgressionImpl.cpp
- Implement TierProgressionManager
- Implement LevelCapManager
- Implement CostScalingManager
- Implement PrestigeManager

**4.3**: Create ItemUpgradeSeasonalImpl.cpp
- Implement SeasonManager
- Implement SeasonResetManager
- Implement BalanceManager
- Implement HistoryManager
- Implement LeaderboardManager

**4.4**: Create ItemUpgradeAdvancedImpl.cpp
- Implement OptimizationManager
- Implement TransmogManager
- Implement AchievementManager
- Implement TradingManager
- Implement RespecManager
- Implement GuildProgressionManager

**4.5**: Create upgrade NPC scripts
- ItemUpgradeNPC_Upgrader.cpp
- ItemUpgradeNPC_Transmog.cpp
- Implement gossip options and upgrade UI

**4.6**: Create admin commands
- .upgrade list (show upgradeable items)
- .upgrade stats (show player progression)
- .upgrade admin (set levels, etc.)

**4.7**: Create events/hooks
- OnItemLoaded: Check for upgrades
- OnLogin: Notify of new features
- OnKill: Award prestige
- OnAchievementEarned: Check upgrade achievements

**4.8**: Database integration
- Create all Phase 4 tables
- Create migration scripts
- Add indices for performance

**4.9**: Testing & QA
- Unit tests for calculators
- Integration tests for upgrade flow
- Performance testing on large datasets
- Leaderboard accuracy verification

**4.10**: Documentation & Polish
- Create user guides
- API documentation
- Admin guides
- Balance documentation

---

## API Reference

### Core Functions (Phase 4A)

```cpp
// Calculate next upgrade cost
UpgradeCostCalculator::GetEssenceCost(tier_id, current_level)
UpgradeCostCalculator::GetTokenCost(tier_id, current_level)
UpgradeCostCalculator::GetCumulativeCost(tier_id, target_level, ...)

// Calculate stat multipliers
StatScalingCalculator::GetStatMultiplier(upgrade_level)
StatScalingCalculator::GetFinalMultiplier(upgrade_level, tier_id)
StatScalingCalculator::GetStatBonusDisplay(upgrade_level, tier_id)

// Calculate item level
ItemLevelCalculator::GetUpgradedItemLevel(base_ilvl, upgrade_level, tier_id)
ItemLevelCalculator::GetItemLevelDisplay(base_ilvl, current_ilvl)

// Perform upgrade
UpgradeManager::PerformItemUpgrade(player_guid, item_guid, essence, tokens)
UpgradeManager::CanUpgradeItem(item_guid, player_guid)
UpgradeManager::GetNextUpgradeCost(item_guid, out_essence, out_tokens)
```

### Prestige Functions (Phase 4B)

```cpp
PrestigeManager::GetPrestigeInfo(player_guid)
PrestigeManager::AwardPrestigePoints(player_guid, points)
PrestigeManager::IncrementFullyUpgradedCount(player_guid)
PrestigeManager::GetPrestigeLeaderboard(limit)
PrestigeManager::GetPlayerPrestigeRank(player_guid)
```

### Seasonal Functions (Phase 4C)

```cpp
SeasonManager::GetActiveSeason()
SeasonManager::GetSeason(season_id)
SeasonManager::TransitionToNextSeason(season)

HistoryManager::RecordUpgrade(entry)
HistoryManager::GetPlayerHistory(player_guid, limit)
HistoryManager::GetSeasonHistory(player_guid, season_id)

LeaderboardManager::GetUpgradeLeaderboard(season_id, limit)
LeaderboardManager::GetPrestigeLeaderboard(season_id, limit)
LeaderboardManager::GetPlayerRank(player_guid, season_id)
```

### Advanced Functions (Phase 4D)

```cpp
OptimizationManager::CreateLoadout(loadout)
OptimizationManager::SwitchLoadout(player_guid, loadout_id)
OptimizationManager::AutoOptimizeLoadout(loadout_id)

AchievementManager::AwardAchievement(player_guid, achievement_id)
AchievementManager::GetPlayerAchievements(player_guid)
AchievementManager::CheckAndAwardAchievements(player_guid)

TradingManager::CanTradeItem(player_guid, item_guid)
TradingManager::ExecuteTrade(player_from, item_from, player_to, item_to)
TradingManager::GetTradeHistory(player_guid, limit)

RespecManager::RespecItem(player_guid, item_guid)
RespecManager::RespecAll(player_guid)
RespecManager::GetRespecCountToday(player_guid)

GuildProgressionManager::GetGuildStats(guild_id)
GuildProgressionManager::GetGuildLeaderboard(limit)
GuildProgressionManager::AwardGuildBonuses(guild_id)
```

---

## Configuration Files

### Phase 4 Configuration (phase4-config.conf)

```ini
# Item Upgrade Mechanics (Phase 4A)
ItemUpgrade.EnableUpgrades=1
ItemUpgrade.MaxUpgradeLevel=15
ItemUpgrade.BaseEscalation=1.1
ItemUpgrade.AllowUpgradeTrading=1
ItemUpgrade.TradePreserveUpgrades=1
ItemUpgrade.TradeTaxPercent=10

# Progression System (Phase 4B)
ItemUpgrade.EnablePrestige=1
ItemUpgrade.SoftCapEssenceWeekly=1000
ItemUpgrade.HardCapEssenceWeekly=2000
ItemUpgrade.PrestigePointsPerLevel=10
ItemUpgrade.RequireTierUnlock=1

# Seasonal System (Phase 4C)
ItemUpgrade.EnableSeasons=1
ItemUpgrade.SeasonDurationDays=90
ItemUpgrade.ResetItemUpgradesOnSeason=0
ItemUpgrade.PreservePrestigeOnReset=1
ItemUpgrade.PrestigeCarryoverPercent=100
ItemUpgrade.TokenCarryoverPercent=10
ItemUpgrade.EssenceCarryoverPercent=5

# Advanced Features (Phase 4D)
ItemUpgrade.EnableOptimization=1
ItemUpgrade.EnableTransmogPresets=1
ItemUpgrade.EnableAchievements=1
ItemUpgrade.EnableRespec=1
ItemUpgrade.RespecCostTokens=1000
ItemUpgrade.RespecCostEssence=500
ItemUpgrade.RespecDailyLimit=3
ItemUpgrade.RespecRefundPercent=50
ItemUpgrade.EnableGuildProgression=1
```

---

## Summary

Phase 4 is structured in 4 integrated components:

**Phase 4A**: Foundation - Core mechanics for item upgrades
**Phase 4B**: Progression - Tier system, prestige, and player advancement  
**Phase 4C**: Seasons - Dynamic balance and competitive elements  
**Phase 4D**: Polish - Advanced features and social systems  

All header files are complete with full API specifications. Implementation can proceed modularly with each component independently functional while integrating with others.

---

**End of Phase 4 Architecture Document**

