# DarkChaos Item Upgrade System - Technical Overview

**Version:** 1.0  
**Date:** November 2025  
**System Status:** ✅ Production Ready  

---

## TABLE OF CONTENTS

1. [System Architecture](#system-architecture)
2. [Tier System Design](#tier-system-design)
3. [Currency & Economy](#currency--economy)
4. [Database Schema](#database-schema)
5. [C++ Component Architecture](#c-component-architecture)
6. [Stat Scaling Mechanics](#stat-scaling-mechanics)
7. [Gameobject Loot Integration](#gameobject-loot-integration)
8. [Heirloom Tier 3 System](#heirloom-tier-3-system)
9. [Client-Server Communication](#client-server-communication)
10. [API Reference](#api-reference)

---

## SYSTEM ARCHITECTURE

### Overview

The **DarkChaos Item Upgrade System** is a comprehensive item progression framework allowing players to enhance equipment through a tiered upgrade system. It integrates:

- **5 Upgrade Tiers** (Leveling → Heroic → Raid → Mythic → Artifact)
- **2 Currency Types** (Upgrade Tokens + Artifact Essence)
- **15 Upgrade Levels** per item (0 = base → 15 = maximum)
- **Dynamic Stat Scaling** (1.0x base → 1.5x/1.75x maximum)
- **Item Level Progression** (+2 to +30 iLvL per upgrade)
- **Account-Wide Heirlooms** (Bind-on-Account support)

### Core Principles

1. **Tier-Based Progression:** Items belong to specific tiers determining upgrade costs and stat multipliers
2. **Currency Economy:** Separate currencies for regular items (tokens) vs artifacts (essence)
3. **Stat Multiplier System:** Upgrades increase stat effectiveness, not replace base stats
4. **Database-Driven Configuration:** All costs/multipliers stored in database for easy tuning
5. **Server-Side Calculation:** Stats computed server-side, sent to client via addon protocol

---

## TIER SYSTEM DESIGN

### Tier Definitions

```cpp
enum UpgradeTier : uint8 {
    TIER_LEVELING = 1,   // Common items (quests, leveling content)
    TIER_HEROIC = 2,     // Uncommon items (heroic dungeons)
    TIER_RAID = 3,       // Rare items (heroic raids, mythic dungeons)
    TIER_MYTHIC = 4,     // Epic items (mythic raids, mythic+)
    TIER_ARTIFACT = 5,   // Legendary items (chaos artifacts)
    TIER_INVALID = 0
};
```

### Tier Characteristics

| Tier | Name | Item Level Range | Max Upgrade | Currency Type | Stat Multiplier Max | Typical Sources |
|------|------|------------------|-------------|---------------|---------------------|-----------------|
| 1 | Leveling | < 213 | 15 | Tokens | 1.5x | Quests, World |
| 2 | Heroic | 213-354 | 15 | Tokens | 1.5x | Heroic Dungeons |
| 3 | Raid | 355-369 | 15 | Tokens | 1.5x | Heroic Raids, Mythic Dungeons |
| 4 | Mythic | 370-384 | 15 | Tokens | 1.5x | Mythic Raids, Mythic+ |
| 5 | Artifact | ≥ 385 | 15 | Essence | 1.75x | Chaos Artifacts |

**Special:** Tier 6 (Heirloom) - Reserved for Bind-on-Account heirloom items (see [Heirloom System](#heirloom-tier-3-system))

### Tier Determination Logic

**Database Mapping (Primary):**
```sql
-- Items explicitly mapped to tiers
SELECT tier_id FROM dc_item_templates_upgrade 
WHERE item_id = ? AND season = ? AND is_active = 1;
```

**Fallback (Item Level Ranges):**
- Used when item not found in explicit mapping
- Based on `ItemTemplate::ItemLevel` field
- Automatic tier assignment for unmapped items

---

## CURRENCY & ECONOMY

### Currency Types

1. **Upgrade Token** (Item ID: TBD)
   - Used for Tiers 1-4 (regular items)
   - Obtained from: Dungeons, raids, daily quests, vendors
   - Cost scaling: 5-35 tokens per upgrade level (tier-dependent)

2. **Artifact Essence** (Item ID: TBD)
   - Used for Tier 5 (artifacts) and Tier 6 (heirlooms)
   - Obtained from: Artifact quests, world bosses, special events
   - Cost scaling: 75-281 essence per upgrade level (1.1x exponential)

### Cost Calculation

**Regular Items (Tiers 1-4):**
```
Base Cost by Tier:
- Tier 1: 5 tokens per level
- Tier 2: 10 tokens per level
- Tier 3: 15 tokens per level
- Tier 4: 20 tokens per level

Total Cost to Max (Level 0→15):
- Tier 1: 225 tokens
- Tier 2: 450 tokens
- Tier 3: 675 tokens
- Tier 4: 900 tokens
```

**Artifacts (Tier 5):**
```
Formula: 200 * (1.1 ^ current_level)
Cumulative Cost to Level 15: ~4,716 essence
```

**Heirlooms (Tier 6):**
```
Formula: 75 * (1.1 ^ current_level)
Cumulative Cost to Level 15: ~2,358 essence
```

### Currency Storage

**Method 1: Item-Based (Current)**
- Currency stored as inventory items
- Checked via `Player::GetItemCount(currency_item_id)`
- Consumed via `Player::DestroyItemCount(currency_item_id, amount)`

**Method 2: Currency System (Alternative)**
- Uses WoW 3.3.5a currency tab
- Stored in `character_currency` table
- Accessed via custom currency manager

---

## DATABASE SCHEMA

### Core Tables

#### 1. `dc_item_upgrade_costs`
Defines upgrade costs for each tier and level.

```sql
CREATE TABLE dc_item_upgrade_costs (
    tier_id TINYINT UNSIGNED NOT NULL,           -- 1-6 (tier)
    upgrade_level TINYINT UNSIGNED NOT NULL,     -- 0-15 (level)
    token_cost INT UNSIGNED NOT NULL DEFAULT 0,  -- Tokens needed
    essence_cost INT UNSIGNED NOT NULL DEFAULT 0,-- Essence needed
    ilvl_increase SMALLINT UNSIGNED NOT NULL DEFAULT 0,  -- iLvL bonus
    stat_increase_percent FLOAT NOT NULL DEFAULT 0.0,    -- Stat multiplier
    season INT UNSIGNED NOT NULL DEFAULT 1,      -- Season identifier
    PRIMARY KEY (tier_id, upgrade_level, season)
);
```

**Example Rows:**
```sql
-- Tier 1 (Leveling) costs
(1, 0, 0, 0, 0, 1.0, 1),    -- Base (no cost)
(1, 1, 5, 0, 2, 1.03, 1),   -- Level 1
(1, 15, 35, 0, 30, 1.5, 1), -- Level 15 (max)

-- Tier 5 (Artifact) costs
(5, 0, 0, 0, 0, 1.0, 1),    -- Base
(5, 1, 0, 200, 3, 1.05, 1), -- Level 1
(5, 15, 0, 627, 45, 1.75, 1), -- Level 15 (max)

-- Tier 6 (Heirloom) costs
(6, 0, 0, 0, 0, 1.05, 1),   -- Base (1.05x starting multiplier)
(6, 1, 0, 75, 2, 1.07, 1),  -- Level 1
(6, 15, 0, 281, 30, 1.35, 1), -- Level 15 (max)
```

#### 2. `dc_item_templates_upgrade`
Maps items to upgrade tiers (explicit assignment).

```sql
CREATE TABLE dc_item_templates_upgrade (
    item_id INT UNSIGNED NOT NULL,      -- Item entry ID
    tier_id TINYINT UNSIGNED NOT NULL,  -- Tier assignment
    season INT UNSIGNED NOT NULL DEFAULT 1,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (item_id, season)
);
```

**Example Rows:**
```sql
-- Heirloom items (Tier 6)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, season) VALUES
(191101, 6, 1), -- Heirloom Flamefury Blade
(191102, 6, 1), -- Heirloom Stormfury
(191133, 6, 1); -- Last heirloom item
-- Total: 33 heirloom items
```

#### 3. `dc_item_upgrades` (Character Database)
Tracks individual item upgrade states per player.

```sql
CREATE TABLE dc_item_upgrades (
    item_guid INT UNSIGNED NOT NULL,        -- Item instance GUID
    player_guid INT UNSIGNED NOT NULL,      -- Player GUID (owner)
    item_entry INT UNSIGNED NOT NULL,       -- Item template ID
    tier_id TINYINT UNSIGNED NOT NULL,      -- Item tier
    upgrade_level TINYINT UNSIGNED NOT NULL DEFAULT 0,  -- Current level
    essence_invested INT UNSIGNED NOT NULL DEFAULT 0,   -- Total essence spent
    tokens_invested INT UNSIGNED NOT NULL DEFAULT 0,    -- Total tokens spent
    base_item_level SMALLINT UNSIGNED NOT NULL,         -- Original iLvL
    upgraded_item_level SMALLINT UNSIGNED NOT NULL,     -- Current iLvL
    stat_multiplier FLOAT NOT NULL DEFAULT 1.0,         -- Current multiplier
    first_upgraded_at TIMESTAMP NULL,       -- First upgrade time
    last_upgraded_at TIMESTAMP NULL,        -- Last upgrade time
    season INT UNSIGNED NOT NULL DEFAULT 1, -- Season
    PRIMARY KEY (item_guid),
    INDEX idx_player_item (player_guid, item_entry)
);
```

#### 4. `dc_item_upgrade_log` (Optional)
Audit log for upgrade history.

```sql
CREATE TABLE dc_item_upgrade_log (
    log_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    item_guid INT UNSIGNED NOT NULL,
    player_guid INT UNSIGNED NOT NULL,
    action VARCHAR(32) NOT NULL,            -- 'upgrade', 'refund', 'reset'
    old_level TINYINT UNSIGNED NOT NULL,
    new_level TINYINT UNSIGNED NOT NULL,
    currency_spent INT UNSIGNED NOT NULL,
    currency_type TINYINT UNSIGNED NOT NULL, -- 1=tokens, 2=essence
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_item (item_guid),
    INDEX idx_player (player_guid)
);
```

---

## C++ COMPONENT ARCHITECTURE

### File Structure

```
src/server/scripts/DC/ItemUpgrades/
├── ItemUpgradeManager.h              # Core interface & structs
├── ItemUpgradeManager.cpp            # Core implementation (1068 lines)
├── ItemUpgradeMechanics.h            # Cost/stat calculation interface
├── ItemUpgradeMechanicsImpl.cpp      # Cost/stat implementation
├── ItemUpgradeStatApplication.cpp    # Stat update hooks
├── ItemUpgradeProgression.h          # Tier progression config
├── ItemUpgradeProgressionImpl.cpp    # Tier progression logic
├── ItemUpgradeAddonHandler.cpp       # Client communication
├── ItemUpgradeGMCommands.cpp         # GM/debug commands
├── ItemUpgradeMechanicsCommands.cpp  # Player commands
├── ItemUpgradeNPC_Vendor.cpp         # Currency vendor NPC
├── ItemUpgradeNPC_Curator.cpp        # Upgrade NPC interface
├── ItemUpgradeQuestRewardHook.cpp    # Quest reward integration
├── ItemUpgradeTokenHooks.cpp         # Currency drops/rewards
├── ItemUpgradeProcScaling.cpp        # Proc effect scaling
├── ItemUpgradeAdvanced.h             # Advanced features
├── ItemUpgradeAdvancedImpl.cpp       # Advanced implementation
├── ItemUpgradeSeasonal.h             # Seasonal system
├── ItemUpgradeSeasonalImpl.cpp       # Seasonal logic
├── ItemUpgradeTransmutation.h        # Transmutation features
├── ItemUpgradeTransmutationImpl.cpp  # Transmutation logic
├── ItemUpgradeTransmutationNPC.cpp   # Transmutation NPC
├── ItemUpgradeSynthesisImpl.cpp      # Synthesis mechanics
└── ItemUpgradeUIHelpers.h            # UI utility functions
```

**Total:** 24 C++ files (~10,000+ lines of code)

### Core Components

#### 1. UpgradeManager (Singleton)

**Purpose:** Central coordinator for all upgrade operations.

**Key Methods:**
```cpp
class UpgradeManager {
    // Initialization
    void LoadUpgradeData(uint32 season);
    
    // Item State
    ItemUpgradeState* GetItemUpgradeState(uint32 item_guid);
    bool TrackItem(uint32 item_guid, uint32 player_guid);
    
    // Upgrade Operations
    bool UpgradeItem(uint32 player_guid, uint32 item_guid);
    bool SetItemUpgradeLevel(uint32 item_guid, uint8 level);
    bool CanUpgradeItem(uint32 item_guid, uint32 player_guid);
    
    // Tier Functions
    uint8 GetItemTier(uint32 item_id);
    uint8 GetTierMaxLevel(uint8 tier_id);
    uint32 GetUpgradeCost(uint8 tier_id, uint8 upgrade_level);
    uint32 GetEssenceCost(uint8 tier_id, uint8 upgrade_level);
    
    // Currency Management
    uint32 GetCurrency(uint32 player_guid, CurrencyType type, uint32 season);
    bool RemoveCurrency(uint32 player_guid, CurrencyType type, uint32 amount);
    bool AddCurrency(uint32 player_guid, CurrencyType type, uint32 amount);
    
    // Stat Calculations
    float GetStatMultiplier(uint32 item_guid);
    uint16 GetUpgradedItemLevel(uint32 item_guid, uint16 base_ilvl);
};
```

**Access:**
```cpp
DarkChaos::ItemUpgrade::UpgradeManager* mgr = 
    DarkChaos::ItemUpgrade::GetUpgradeManager();
```

#### 2. UpgradeCostCalculator

**Purpose:** Calculate upgrade costs with exponential scaling.

**Key Methods:**
```cpp
class UpgradeCostCalculator {
    static uint32 GetEssenceCost(uint8 tier_id, uint8 current_level);
    static uint32 GetTokenCost(uint8 tier_id, uint8 current_level);
    static void GetCumulativeCost(uint8 tier_id, uint8 target_level,
                                  uint32& out_essence, uint32& out_tokens);
    static void GetRefundCost(uint8 tier_id, uint8 current_level,
                              uint32& out_essence, uint32& out_tokens);
};
```

**Implementation (Tier 5 Example):**
```cpp
uint32 UpgradeCostCalculator::GetEssenceCost(uint8 tier_id, uint8 current_level) {
    if (tier_id == TIER_ARTIFACT) {
        float base_cost = 200.0f;
        float escalated_cost = base_cost * std::pow(1.1f, current_level);
        return static_cast<uint32>(std::ceil(escalated_cost));
    }
    // ... other tiers
}
```

#### 3. StatScalingCalculator

**Purpose:** Calculate stat multipliers for upgraded items.

**Key Methods:**
```cpp
class StatScalingCalculator {
    static float GetStatMultiplier(uint8 tier_id, uint8 upgrade_level);
    static float GetStatIncreasePercent(uint8 tier_id, uint8 upgrade_level);
};
```

**Implementation:**
```cpp
float StatScalingCalculator::GetStatMultiplier(uint8 tier_id, uint8 upgrade_level) {
    // Query database for stat_increase_percent
    // Fallback formulas:
    if (tier_id == TIER_ARTIFACT) {
        return 1.0f + (upgrade_level * 0.05f); // 1.0 → 1.75 over 15 levels
    }
    return 1.0f + (upgrade_level * 0.033f); // 1.0 → 1.5 over 15 levels
}
```

#### 4. ItemLevelCalculator

**Purpose:** Calculate item level increases from upgrades.

**Key Methods:**
```cpp
class ItemLevelCalculator {
    static uint16 GetUpgradedItemLevel(uint16 base_ilvl, uint8 tier_id, 
                                       uint8 upgrade_level);
    static uint16 GetIlvlIncrease(uint8 tier_id, uint8 upgrade_level);
};
```

---

## STAT SCALING MECHANICS

### Stat Multiplier System

**Base Principle:** Upgrades multiply item stats by a scaling factor, preserving relative stat distributions.

**Formula:**
```
Upgraded Stat = Base Stat × Stat Multiplier

Stat Multiplier = 1.0 + (upgrade_level × tier_increment)

Where:
- Tier 1-4: tier_increment = 0.033 (1.0 → 1.5 over 15 levels)
- Tier 5:   tier_increment = 0.05  (1.0 → 1.75 over 15 levels)
- Tier 6:   tier_increment = 0.02  (1.05 → 1.35 over 15 levels)
```

### Stat Application

**Primary Stats (STR, AGI, INT, STA, SPI):**
- Tiers 1-5: Multiplied by stat_multiplier
- Tier 6 (Heirlooms): **NOT modified** (already scale with level via `heirloom_scaling_255.cpp`)

**Secondary Stats (Crit, Haste, Hit, Expertise, etc.):**
- Tiers 1-5: Multiplied by stat_multiplier
- Tier 6 (Heirlooms): **ADDED dynamically** (not in base item, applied by upgrade system)

### Heirloom Special Handling

**Critical Design:**

1. **Base Item:**
   - `stat_type1 = 4` (STR), `stat_value1 = 25`
   - `stat_type2 = 0`, `stat_value2 = 0` ← NO secondary stats
   - `stat_type3 = 0`, `stat_value3 = 0` ← NO tertiary stats

2. **Automatic Scaling (Primary Stats):**
   - Handled by `heirloom_scaling_255.cpp`
   - Scales STR/AGI/INT/STA/SPI from level 1 → 255
   - Formula: `stat_value * (player_level / base_level_scale)`

3. **Manual Upgrades (Secondary Stats):**
   - Level 0: No secondary stats (1.05x placeholder multiplier)
   - Level 1-15: Secondary stats added dynamically
   - Example at Level 15:
     - +150 Crit Rating (from 1.35x multiplier)
     - +120 Haste Rating (from 1.35x multiplier)
     - +100 Mastery Rating (from 1.35x multiplier)

**Implementation Note:**
```cpp
void ApplyUpgradedStats(Item* item, Player* player) {
    ItemUpgradeState* state = GetItemUpgradeState(item->GetGUID());
    if (!state) return;
    
    if (state->tier_id == TIER_HEIRLOOM) {
        // ONLY add secondary stats - DO NOT touch primary stats
        float multiplier = state->stat_multiplier; // 1.05 → 1.35
        
        // Add secondary stats based on WotLK balance
        uint32 crit_rating = CalculateSecondaryStat(item, STAT_CRIT, multiplier);
        uint32 haste_rating = CalculateSecondaryStat(item, STAT_HASTE, multiplier);
        
        player->ApplyStatMod(ITEM_MOD_CRIT_RATING, crit_rating, true);
        player->ApplyStatMod(ITEM_MOD_HASTE_RATING, haste_rating, true);
    } else {
        // Regular items: multiply ALL stats
        // ... existing logic
    }
}
```

### Item Level Scaling

**Per-Tier iLvL Increases:**

| Tier | iLvL per Level | Total at Max (15) |
|------|----------------|-------------------|
| 1 | +2 | +30 |
| 2 | +2.5 | +37.5 |
| 3 | +3 | +45 |
| 4 | +3 | +45 |
| 5 | +3 | +45 |
| 6 | +2 | +30 |

**Example:**
- Item: Heirloom Flamefury Blade (base iLvL 80)
- After 15 upgrades: 80 + 30 = **110 iLvL**

---

## GAMEOBJECT LOOT INTEGRATION

### Discovery System (Treasure Chests)

**Purpose:** Provide thematic world discovery for heirloom items.

**Implementation:**

#### 1. Gameobject Templates

```sql
-- Example: Weapon Rack (for sword)
INSERT INTO gameobject_template (entry, type, displayId, name, data0, data1, data2) VALUES
(191001, 3, 119, 'Ancient Weapon Rack', 191001, 0, 1);
--      ^    ^    ^    ^                  ^       ^  ^
--      |    |    |    |                  |       |  respawn time (300s)
--      |    |    |    display name       |       loot locked
--      |    |    display model           loot table ID
--      |    type (3 = GAMEOBJECT_TYPE_CHEST)
--      gameobject entry ID

-- Example: Armor Stand (for chest armor)
INSERT INTO gameobject_template (entry, type, displayId, name, data0, data1, data2) VALUES
(191010, 3, 134, 'Forgotten Armor Stand', 191010, 0, 1);

-- Example: Treasure Chest (generic fallback)
INSERT INTO gameobject_template (entry, type, displayId, name, data0, data1, data2) VALUES
(191024, 3, 142, 'Sealed Heirloom Chest', 191024, 0, 1);
```

**Display Models:**
- **119-120:** Weapon racks (swords, axes, polearms)
- **134-136:** Armor stands (chest, legs, shoulders, etc.)
- **142:** Treasure chest (generic container)

#### 2. Gameobject Spawns

```sql
-- Example: Spawn in Azshara Crater
INSERT INTO gameobject (guid, id, map, zoneId, areaId, position_x, position_y, position_z, orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, state) VALUES
(151001, 191001, 1, 16, 0, 3500.0, -4200.0, 150.0, 0.0, 0.0, 0.0, 0.0, 1.0, 300, 1);
--^      ^       ^  ^   ^  ^         ^         ^       ^    spawn time  ^  state (1=ready)
--|      |       |  |   |  |         |         |       orientation
--|      |       |  |   |  position X/Y/Z (world coordinates)
--|      |       |  |   area ID (0 = zone-wide)
--|      |       |  zone ID (16 = Azshara Crater)
--|      |       map ID (1 = Kalimdor)
--|      gameobject template ID
--spawn GUID (unique instance)
```

**Total:** 24 treasures spawned across Azshara Crater

#### 3. Loot Tables

```sql
-- Example: Loot table for weapon rack
INSERT INTO gameobject_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount) VALUES
(191001, 191101, 0, 100.0, 1, 1, 0, 1, 1);
--^      ^        ^  ^      ^  ^  ^  ^  ^
--|      |        |  |      |  |  |  |  max count (1)
--|      |        |  |      |  |  |  min count (1)
--|      |        |  |      |  |  loot group (0=default)
--|      |        |  |      |  loot mode (1=normal)
--|      |        |  |      quest required (1=yes)
--|      |        |  100% drop chance
--|      |        reference (0=none)
--|      item entry (191101 = Heirloom Flamefury Blade)
--loot table ID (matches gameobject_template.data0)

-- Total: 24 loot entries (one item per treasure)
```

#### 4. Quest Gating (One-Time Loot)

```sql
-- Quest template (hidden tracker)
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, MaxLevel, QuestFlags, SpecialFlags, Title) VALUES
(50000, 0, 1, 1, 255, 0x00008000, 0x01, 'Heirloom Discovery Tracker');
--^                                  ^          ^
--|                                  |          SpecialFlags (0x01 = AUTO_ACCEPT)
--|                                  QuestFlags (0x00008000 = QUEST_FLAGS_HIDDEN)
--quest ID

-- Quest objectives (24 items, one per treasure)
-- Not shown in quest log, auto-tracked when treasure looted
```

**Mechanism:**
1. Player interacts with treasure
2. Server checks: `QuestRequiredItemId = 50000` in loot table
3. If quest incomplete: Loot granted, quest marked complete
4. If quest complete: "You cannot loot this" message

**Result:** Each character can loot each treasure exactly once.

### Treasure Distribution

**Location:** Azshara Crater (Map 1, Zone 16)

**Spatial Design:**
- **Central Hub:** 6 treasures near quest hub
- **Outer Ring:** 12 treasures around crater perimeter
- **Hidden Spots:** 6 treasures in caves/elevated areas

**Spawn Timing:** 5-minute respawn (300 seconds)

---

## HEIRLOOM TIER 3 SYSTEM

### Concept Overview

**Tier 6 (Heirloom) is DISTINCT from Tier 3 (Raid):**
- Tier 3 = Raid items (existing system, TIER_RAID enum)
- Tier 6 = Heirloom items (new system, TIER_HEIRLOOM enum)

**Critical Change Required:**
```cpp
// ItemUpgradeManager.h
enum UpgradeTier : uint8 {
    TIER_LEVELING = 1,
    TIER_HEROIC = 2,
    TIER_RAID = 3,        // Existing
    TIER_MYTHIC = 4,
    TIER_ARTIFACT = 5,
    TIER_HEIRLOOM = 6,    // ← ADD THIS
    TIER_INVALID = 0
};
```

### Heirloom Item Design

**Total Items:** 33 (IDs 191101-191133)

**Weapons (9):**
- 191101-191103: Main-hand swords (3 stat variants)
- 191104: Dagger
- 191105: Staff
- 191106: Bow
- 191107: Wand
- 191108: Mace
- 191109: Polearm

**Armor (24):**
- 8 equipment slots × 3 stat variants each
- Slots: Head, Chest, Legs, Shoulders, Waist, Feet, Hands, Wrists
- Variants: STR-focused, INT-focused, AGI/SPI-focused

**Key Properties:**
```sql
-- Example: Heirloom Flamefury Blade
INSERT INTO item_template (entry, class, subclass, name, displayid, Quality, bonding, 
    stat_type1, stat_value1, 
    stat_type2, stat_value2,  -- ← MUST BE 0 (no secondary stats)
    stat_type3, stat_value3,  -- ← MUST BE 0
    dmg_min1, dmg_max1, Flags, Flags2, BagFamily, description) VALUES
(191101, 2, 7, 'Heirloom Flamefury Blade', 45001, 4, 1,
    4, 25,        -- STR: 25 (scales with level)
    0, 0,         -- No secondary stats (added by upgrades)
    0, 0,         -- No tertiary stats
    50, 80, 0x00000001, 0x00000002, 0, 
    'Primary stats scale with level. Upgrade for secondary stats.');
--  ^                ^               ^
--  Flags            Flags2          description explaining design
--  0x00000001       0x00000002      
--  (ITEM_FIELD_FLAG_SOULBOUND)      (ITEM_FLAGS_EXTRA_HEIRLOOM_V2)
```

### Heirloom Upgrade Progression

**Starting Multiplier:** 1.05x (slightly above base)

**Progression Table:**

| Level | Essence Cost | Cumulative Essence | Stat Multiplier | iLvL Bonus | Total iLvL |
|-------|--------------|-------------------|-----------------|------------|------------|
| 0 | 0 | 0 | 1.05x | 0 | 80 |
| 1 | 75 | 75 | 1.07x | +2 | 82 |
| 5 | 109 | 455 | 1.15x | +10 | 90 |
| 10 | 175 | 1,186 | 1.25x | +20 | 100 |
| 15 | 281 | 2,358 | 1.35x | +30 | 110 |

**Total Essence Required:** 2,358 (from Level 0 to Level 15)

**Scaling Formula:**
```
essence_cost(level) = 75 * (1.1 ^ level)
stat_multiplier(level) = 1.05 + (level × 0.02)
```

### Integration Steps

**1. Database (SQL):**
```sql
-- Add Tier 6 costs (16 rows, levels 0-15)
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, token_cost, essence_cost, ilvl_increase, stat_increase_percent, season) VALUES
(6, 0, 0, 0, 0, 1.05, 1),
(6, 1, 0, 75, 2, 1.07, 1),
-- ... (14 more rows)
(6, 15, 0, 281, 30, 1.35, 1);

-- Map heirloom items to Tier 6
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, season) VALUES
(191101, 6, 1), (191102, 6, 1), /* ... */ (191133, 6, 1);
```

**2. C++ Code:**
```cpp
// ItemUpgradeManager.h
enum UpgradeTier : uint8 {
    // ...
    TIER_HEIRLOOM = 6,  // ← ADD
};

// ItemUpgradeMechanicsImpl.cpp
uint32 UpgradeCostCalculator::GetEssenceCost(uint8 tier_id, uint8 current_level) {
    if (tier_id == TIER_HEIRLOOM) {
        float base_cost = 75.0f;
        return static_cast<uint32>(std::ceil(base_cost * std::pow(1.1f, current_level)));
    }
    // ... existing logic
}

float StatScalingCalculator::GetStatMultiplier(uint8 tier_id, uint8 upgrade_level) {
    if (tier_id == TIER_HEIRLOOM) {
        return 1.05f + (upgrade_level * 0.02f);  // 1.05 → 1.35
    }
    // ... existing logic
}

// ItemUpgradeStatApplication.cpp (CRITICAL)
void ApplyUpgradedStats(Item* item, Player* player) {
    ItemUpgradeState* state = GetItemUpgradeState(item->GetGUID());
    if (!state) return;
    
    if (state->tier_id == TIER_HEIRLOOM) {
        // ⚠️ ONLY ADD SECONDARY STATS
        // DO NOT MODIFY PRIMARY STATS (handled by heirloom_scaling_255.cpp)
        float multiplier = state->stat_multiplier;
        
        // Calculate secondary stats based on WotLK balance
        uint32 crit = CalculateCritRating(multiplier);
        uint32 haste = CalculateHasteRating(multiplier);
        
        player->ApplyStatMod(ITEM_MOD_CRIT_RATING, crit, true);
        player->ApplyStatMod(ITEM_MOD_HASTE_RATING, haste, true);
    } else {
        // Regular items: multiply ALL stats
        // ... existing logic
    }
}
```

**3. DBC Files:**
```
Item.csv: Add 33 entries (191101-191133)
ScalingStatDistribution.csv: Add 33 entries with PRIMARY stat scaling only
```

---

## CLIENT-SERVER COMMUNICATION

### Addon Protocol

**Communication Method:** Custom chat message protocol

**Message Format:**
```
DCUPGRADE_<COMMAND>:<PARAM1>:<PARAM2>:...:PARAMN
```

**Commands:**

1. **Request Item Info**
   ```
   Client → Server: "DCUPGRADE_INFO:<item_guid>"
   Server → Client: "DCUPGRADE_INFO:<tier>:<level>:<max_level>:<next_cost>:<stat_multiplier>"
   ```

2. **Request Upgrade**
   ```
   Client → Server: "DCUPGRADE_DO:<item_guid>:<target_level>"
   Server → Client: "DCUPGRADE_SUCCESS:<new_level>:<new_multiplier>:<new_ilvl>"
                or: "DCUPGRADE_ERROR:<error_message>"
   ```

3. **Query Currency**
   ```
   Client → Server: "DCUPGRADE_CURRENCY"
   Server → Client: "DCUPGRADE_CURRENCY:<tokens>:<essence>"
   ```

### Client Addon (Lua)

**Location:** `Custom/Client addons needed/DC-ItemUpgrade/`

**Key Features:**
- Item upgrade UI frame (mimics Retail WoW upgrade system)
- Tier-specific coloring (6 tier colors)
- Cost display (tokens/essence breakdown)
- Stat preview (before/after comparison)
- Currency tracking

**Integration:**
```lua
-- Example: Request upgrade info
SendChatMessage("DCUPGRADE_INFO:" .. itemGUID, "WHISPER", nil, playerName);

-- Example: Handle response
CHAT_MSG_SYSTEM handler:
if msg:match("^DCUPGRADE_INFO:") then
    local tier, level, maxLevel, nextCost, multiplier = 
        strsplit(":", msg:sub(16));
    -- Update UI frame
end
```

---

## API REFERENCE

### C++ API

#### Singleton Access
```cpp
DarkChaos::ItemUpgrade::UpgradeManager* mgr = 
    DarkChaos::ItemUpgrade::GetUpgradeManager();
```

#### Common Operations

**Get Item Upgrade State:**
```cpp
ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);
if (state) {
    uint8 level = state->upgrade_level;
    float multiplier = state->stat_multiplier;
    uint8 tier = state->tier_id;
}
```

**Upgrade Item:**
```cpp
bool success = mgr->UpgradeItem(player_guid, item_guid);
if (success) {
    // Item upgraded successfully
    // Stats automatically recalculated
}
```

**Check Upgrade Cost:**
```cpp
uint32 essence_needed = mgr->GetEssenceCost(tier_id, next_level);
uint32 tokens_needed = mgr->GetUpgradeCost(tier_id, next_level);
```

**Get Item Tier:**
```cpp
uint8 tier = mgr->GetItemTier(item_entry);
if (tier == TIER_HEIRLOOM) {
    // Special heirloom handling
}
```

**Force Stat Update:**
```cpp
DarkChaos::ItemUpgrade::ForcePlayerStatUpdate(player);
// Triggers full stat recalculation
```

### SQL Queries

**Get Item Upgrade State:**
```sql
SELECT upgrade_level, stat_multiplier, upgraded_item_level, tier_id
FROM dc_item_upgrades
WHERE item_guid = ? AND player_guid = ?;
```

**Get Upgrade Cost:**
```sql
SELECT token_cost, essence_cost, ilvl_increase, stat_increase_percent
FROM dc_item_upgrade_costs
WHERE tier_id = ? AND upgrade_level = ? AND season = ?;
```

**Get Total Essence Invested:**
```sql
SELECT SUM(essence_invested) AS total_essence
FROM dc_item_upgrades
WHERE player_guid = ?;
```

---

## IMPLEMENTATION CHECKLIST

### Phase 1: Heirloom Database Setup
- [ ] Execute `HEIRLOOM_TIER3_SYSTEM_WORLD.sql`
- [ ] Verify 33 items inserted
- [ ] Verify 24 treasures spawned
- [ ] Verify quest created (ID 50000)
- [ ] Add Tier 6 costs (16 rows) OR update tier_id from 3→6

### Phase 2: C++ Integration
- [ ] Add `TIER_HEIRLOOM = 6` to `ItemUpgradeManager.h`
- [ ] Implement Tier 6 cost calculation in `ItemUpgradeMechanicsImpl.cpp`
- [ ] Implement Tier 6 stat multiplier logic
- [ ] **CRITICAL:** Implement special stat application (secondary stats only)
- [ ] Update `ItemUpgradeAddonHandler.cpp` UI strings
- [ ] Compile: `./acore.sh compiler build`

### Phase 3: DBC Conversion
- [ ] Convert `Item.csv` → `Item.dbc`
- [ ] Convert `ScalingStatDistribution.csv` → `ScalingStatDistribution.dbc`
- [ ] Create client patch (.mpq)
- [ ] Deploy to client `Data/` folder

### Phase 4: Testing
- [ ] Travel to Azshara Crater
- [ ] Loot treasure → receive heirloom
- [ ] Verify item is Bind-on-Account
- [ ] Verify primary stats scale with level
- [ ] Verify NO secondary stats initially
- [ ] Upgrade item to Level 1
- [ ] Verify secondary stats appear
- [ ] Verify primary stats unchanged
- [ ] Upgrade to Level 15 (max)
- [ ] Verify 1.35x multiplier applied
- [ ] Test on ALT character (account-wide binding)

---

## TROUBLESHOOTING

### Common Issues

**1. Treasures Don't Spawn**
- Check: `SELECT * FROM gameobject WHERE guid BETWEEN 151001 AND 151024;`
- Solution: Re-execute gameobject spawn SQL

**2. Items Show "Unknown"**
- Cause: DBC files not updated in client
- Solution: Verify `Item.dbc` conversion, re-patch client

**3. Upgrades Don't Work**
- Check: Tier ID matches (SQL tier_id = C++ enum value)
- Check: Cost rows exist in `dc_item_upgrade_costs`
- Solution: Verify Tier 6 enum added, recompile

**4. Stats Don't Scale**
- Cause: Stat application logic not implemented
- Solution: Verify `ItemUpgradeStatApplication.cpp` has Tier 6 handling

**5. Primary Stats Broken**
- Cause: ItemUpgrade system touching primary stats (should NOT)
- Solution: Verify stat application SKIPS primary stats for tier_id=6

---

## PERFORMANCE CONSIDERATIONS

### Database Optimization

**Indexes:**
```sql
-- dc_item_upgrades
CREATE INDEX idx_player_item ON dc_item_upgrades(player_guid, item_entry);
CREATE INDEX idx_tier_level ON dc_item_upgrades(tier_id, upgrade_level);

-- dc_item_upgrade_costs
CREATE INDEX idx_tier_season ON dc_item_upgrade_costs(tier_id, season);

-- dc_item_upgrade_log
CREATE INDEX idx_timestamp ON dc_item_upgrade_log(timestamp);
```

**Query Optimization:**
- Cache upgrade costs in memory (loaded at server startup)
- Cache item tier mappings (avoid repeated DB queries)
- Use prepared statements for frequent operations

### Memory Usage

**UpgradeManager Caching:**
- Item upgrade states: ~200 bytes per tracked item
- Upgrade costs: ~50 rows × 24 bytes = 1.2 KB (all tiers/levels)
- Item tier mappings: ~1000 items × 8 bytes = 8 KB

**Total Memory Overhead:** < 1 MB for typical usage

---

## FUTURE ENHANCEMENTS

### Planned Features

1. **Transmutation System** (ItemUpgradeTransmutation*.cpp)
   - Convert items between tiers
   - Sacrifice multiple items for essence
   - Item synthesis/fusion

2. **Seasonal System** (ItemUpgradeSeasonal*.cpp)
   - Seasonal leaderboards
   - Season-specific upgrade paths
   - Legacy season rewards

3. **Advanced Progression** (ItemUpgradeAdvanced*.cpp)
   - Prestige levels beyond 15
   - Milestone bonuses
   - Set bonuses for fully upgraded sets

4. **Proc Scaling** (ItemUpgradeProcScaling.cpp)
   - Scale item proc effects with upgrade level
   - Dynamic proc chance/damage adjustments

### Customizable Secondary Stats (Advanced)

**Concept:** Players choose which secondary stats to add via upgrades.

**Design:** See `HEIRLOOM_CUSTOMIZABLE_SECONDARY_STATS_DESIGN.md`

**Implementation:**
- Separate upgrade tracks per stat type (Crit, Haste, Mastery, etc.)
- Player spends essence to level each stat independently
- Total secondary stat budget: 10 stats × 15 levels = 150 upgrade points
- UI complexity: Requires custom upgrade interface

**Status:** Design complete, implementation pending

---

## CONCLUSION

The **DarkChaos Item Upgrade System** provides a comprehensive, scalable framework for item progression in AzerothCore 3.3.5a. With 24 C++ files, robust database schema, and client addon integration, the system supports:

- ✅ 5 distinct upgrade tiers + heirloom tier
- ✅ 15 upgrade levels per item
- ✅ Exponential cost scaling
- ✅ Dynamic stat multipliers
- ✅ Thematic treasure discovery
- ✅ Account-wide heirloom binding
- ✅ WotLK-balanced secondary stats

**Total Development:** ~10,000+ lines of C++ code, extensive database schema, full client integration

**Production Status:** ✅ Core system functional, heirloom tier pending final integration

---

**Document Version:** 1.0  
**Last Updated:** November 2025  
**Maintained By:** DarkChaos Development Team

---

**END OF TECHNICAL OVERVIEW**
