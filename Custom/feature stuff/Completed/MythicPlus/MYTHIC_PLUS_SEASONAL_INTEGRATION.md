# Mythic+ & Seasonal Reward System Integration
## Complete Integration Guide & Technical Analysis

**Date**: November 2025  
**Status**: Ready for Implementation  
**Scope**: M+ vault rewards, prestige-aware token calculations, chest system, challenge modes  

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Question 1: M+ Reward Integration](#question-1-mythic-reward-integration)
3. [Question 2: Chest System Integration with Quests](#question-2-chest-system-integration-with-quests)
4. [Question 3: Token Calculation with Prestige](#question-3-token-calculation-with-prestige-mechanics)
5. [Question 4: Challenge Mode Support](#question-4-challenge-mode-support)
6. [Combined Implementation Strategy](#combined-implementation-strategy)
7. [Database Schema Extensions](#database-schema-extensions)
8. [Code Architecture](#code-architecture)

---

## Executive Summary

This document provides **detailed technical answers** to your four integration questions:

### **Q1: Mythic+ Integration** ✅
**Answer**: M+ vault rewards integrate via **seasonal multiplier layering** onto existing vault token calculations.

**Key Formula**:
```
Seasonal_M+_Tokens = Base_M+_Tokens × Season_Multiplier × Difficulty_Multiplier × (1 + Prestige_Bonus)
```

### **Q2: Chest Integration with Quests** ✅
**Answer**: Auto-inject chests via **PlayerScript hook** on quest completion, with tier/ilvl scaling from quest reward level.

**Flow**: `OnQuestComplete() → Calculate_Chest_Tier() → Drop_Scaled_Chest() → Link_to_Seasonal_Rewards()`

### **Q3: Prestige with Token Cap** ✅
**Answer**: **Prestige INCREASES weekly cap** (soft/hard) and provides **additive token bonus per rank**.

**Token Formula with Prestige**:
```
tokens_per_rank = base_prestige_points_per_level × (1 + prestige_bonus_multiplier)
prestige_weekly_cap_increase = prestige_rank × prestige_cap_bonus_per_rank
final_cap = 500 base + prestige_cap_increase
```

### **Q4: Challenge Modes** ✅
**Answer**: Challenge modes use **separate exponential scaling** (1.8x base + 0.15x per level) with unified seasonal config.

**CM Formula**:
```
CM_HP/Damage_Multiplier = 1.8 × (1.15 ^ keystone_level)
CM_Rewards = Base_CM_Rewards × CM_Difficulty_Multiplier × Season_Multiplier
```

---

## Question 1: Mythic+ Reward Integration

### Current M+ Vault System (Existing Code Analysis)

#### 1.1 Vault Token Calculation (Current)

From `vault_rewards.cpp`:
```cpp
// EXISTING FORMULA
tokens = 10 + max(0, (item_level - 190) / 10)

// ITEM LEVEL CALCULATION
// M+2 = 200, M+7 = 216, M+10 = 228, M+15 = 248, then +3/level
item_level = 200 + (keystone_level - 2) * 3  // Up to M+7
item_level = 216 + (keystone_level - 7) * 4  // M+8 to M+10 (4/level)
item_level = 228 + (keystone_level - 10) * 2 // M+11 to M+15 (2/level)
item_level = 248 + (keystone_level - 15) * 3 // Beyond M+15 (3/level)
```

**Example Token Calculations (Current)**:
- M+2: ilvl 200 → tokens = 10 + (200-190)/10 = **11 tokens**
- M+7: ilvl 216 → tokens = 10 + (216-190)/10 = **12.6 → 12 tokens**
- M+10: ilvl 228 → tokens = 10 + (228-190)/10 = **13.8 → 13 tokens**
- M+15: ilvl 248 → tokens = 10 + (248-190)/10 = **15.8 → 15 tokens**
- M+20: ilvl 263 → tokens = 10 + (263-190)/10 = **17.3 → 17 tokens**

#### 1.2 Vault Rewards Structure

From `npc_mythic_plus_great_vault.cpp`:
```cpp
// 3 VAULT SLOTS
Slot 1: Available after 1 keystone run
Slot 2: Available after 4 keystone runs
Slot 3: Available after 8 keystone runs

// Per run → generates reward pool
// Token quantity determined by keystone level
// Can be claimed once per week
```

#### 1.3 M+ Scaling Multipliers (Existing)

From `MythicDifficultyScaling.cpp`:
```cpp
RETAIL_SCALING[] = {
    1.00f,  // M+0
    1.05f,  // M+1
    1.10f,  // M+2
    1.15f,  // M+3
    1.20f,  // M+4
    1.25f,  // M+5
    1.30f,  // M+6
    1.40f,  // M+7
    1.50f,  // M+8
    1.60f,  // M+9
    1.70f,  // M+10
    1.80f,  // M+11
    1.90f,  // M+12
    2.10f,  // M+13
    2.40f,  // M+14
    2.96f   // M+15
    // Beyond M+15: 1.10x multiplicative per level
};
```

### 1.4 Seasonal Integration Strategy

#### Proposed Architecture

**Layer 1: Base M+ Calculation** (Existing)
```cpp
base_tokens = 10 + (ilvl - 190) / 10
```

**Layer 2: Seasonal Multiplier** (NEW)
```cpp
// From dc_seasonal_reward_multipliers table
season_multiplier = GetSeasonMultiplier(season_id, "mythic_plus")
// Example: Season 1 = 1.0x, Season 2 = 1.15x
```

**Layer 3: Difficulty Multiplier** (NEW)
```cpp
// M+ difficulty scaling already built-in via ilvl
// But we can apply additional difficulty modifier
difficulty_multiplier = GetDifficultyMultiplier(keystone_level)
// Example: M+2-5 = 1.0x, M+6-10 = 1.1x, M+11-15 = 1.2x, M+16+ = 1.3x
```

**Layer 4: Prestige Bonus** (NEW)
```cpp
prestige_rank = GetPlayerPrestigeRank(player_guid)
prestige_bonus = 1.0 + (prestige_rank * PRESTIGE_BONUS_PER_RANK)
// Example: Rank 0 = 1.0x, Rank 5 = 1.25x, Rank 10 = 1.50x
```

**Final M+ Token Calculation**:
```cpp
final_tokens = base_tokens × season_multiplier × difficulty_multiplier × prestige_bonus

// EXAMPLE:
// Base: M+15 = 15 tokens
// Season multiplier (Season 2): 1.15x
// Difficulty (M+15): 1.2x
// Prestige (Rank 10): 1.50x
// Final: 15 × 1.15 × 1.2 × 1.50 = 31.05 tokens (→ 31 tokens)
```

#### Configuration
```ini
# M+ Seasonal Integration (new season.conf)
MythicPlus.SeasonMultiplier.Season1=1.0
MythicPlus.SeasonMultiplier.Season2=1.15
MythicPlus.SeasonMultiplier.Season3=1.20

MythicPlus.DifficultyMultiplier.M2_5=1.0
MythicPlus.DifficultyMultiplier.M6_10=1.1
MythicPlus.DifficultyMultiplier.M11_15=1.2
MythicPlus.DifficultyMultiplier.M16plus=1.3

MythicPlus.PrestigeBonusPerRank=0.05  # +5% per prestige rank
```

#### Implementation Hook

**File**: `src/server/scripts/DC/MythicPlus/vault_rewards_seasonal.cpp`

```cpp
// HOOK INTO EXISTING VAULT REWARD CALCULATION
uint32 CalculateVaultTokens_Seasonal(Player* player, uint8 keystone_level)
{
    // Step 1: Get base M+ tokens
    uint16 ilvl = GetItemLevelForKeystoneLevel(keystone_level);
    uint32 base_tokens = 10 + max(0, (ilvl - 190) / 10);
    
    // Step 2: Get season multiplier
    uint32 season_id = GetActiveSeasonId();
    float season_multiplier = GetSeasonMultiplier(season_id, "mythic_plus");
    
    // Step 3: Get difficulty multiplier
    float difficulty_multiplier = GetDifficultyMultiplier(keystone_level);
    
    // Step 4: Get prestige bonus
    uint8 prestige_rank = GetPlayerPrestigeRank(player->GetGUID());
    float prestige_bonus = 1.0f + (prestige_rank * PRESTIGE_BONUS_PER_RANK);
    
    // Step 5: Calculate final tokens
    float final_tokens = base_tokens * season_multiplier * difficulty_multiplier * prestige_bonus;
    
    // Step 6: Apply weekly cap
    uint32 weekly_cap = GetPrestigeAwareWeeklyCap(prestige_rank);
    uint32 earned_this_week = GetPlayerTokensEarnedThisWeek(player->GetGUID());
    
    if (earned_this_week + final_tokens > weekly_cap)
        final_tokens = weekly_cap - earned_this_week;
    
    return static_cast<uint32>(final_tokens);
}
```

#### Database Integration

**Extend `dc_seasonal_reward_multipliers`**:
```sql
ALTER TABLE dc_seasonal_reward_multipliers ADD COLUMN (
    mythic_plus_multiplier FLOAT DEFAULT 1.0,
    mythic_plus_difficulty_bonus FLOAT DEFAULT 0.0,
    mythic_plus_prestige_bonus FLOAT DEFAULT 0.05
);

-- Example: Season 2 M+ bonuses
INSERT INTO dc_seasonal_reward_multipliers VALUES
(2, 'mythic_plus', 1.15, 1.0, 0.05);
```

---

## Question 2: Chest System Integration with Quests

### Current Quest Reward System

From seasonal quest architecture:
- Quests award: gold, XP, items, reputations
- Each quest has base reward level
- Rewards scale by player level and quest level

### 2.1 Proposed Chest Injection System

#### Architecture Overview

```
Quest Completion
        ↓
    PlayerScript Hook: OnQuestComplete()
        ↓
    Check dc_seasonal_quest_rewards
        ↓
    Calculate Chest Tier (based on quest reward level)
        ↓
    Determine Item Level (from quest level + scaling)
        ↓
    Generate Chest Object
        ↓
    Add Loot to Chest
        ↓
    Send to Player Inventory/Drop
```

#### 2.2 Chest Tier Mapping

**From Quest Reward Level to Chest Tier**:

```
Quest Reward Ilvl Range → Chest Tier → Chest Contents
─────────────────────────────────────────────────────
<213                  → T0 (Bronze)  → Common items, low tokens
213-230               → T1 (Silver)  → Uncommon items, med tokens
231-248               → T2 (Gold)    → Rare items, high tokens
249-265               → T3 (Platinum)→ Epic items, epic tokens
266-280               → T4 (Diamond) → Legendary items, max tokens
```

#### 2.3 Database Schema for Chests

**New Table: `dc_quest_chest_config`**
```sql
CREATE TABLE dc_quest_chest_config (
    config_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    quest_id INT UNSIGNED UNIQUE,
    tier TINYINT UNSIGNED,              -- T0-T4
    base_ilvl SMALLINT UNSIGNED,        -- Base item level
    chest_entry_id INT UNSIGNED,        -- Game object ID
    guaranteed_items INT UNSIGNED,      -- Min items in chest
    max_items INT UNSIGNED,             -- Max items in chest
    token_count_min INT UNSIGNED,       -- Min tokens
    token_count_max INT UNSIGNED,       -- Max tokens
    season_id INT UNSIGNED,
    is_active BOOLEAN DEFAULT TRUE,
    created_timestamp INT UNSIGNED,
    updated_timestamp INT UNSIGNED,
    INDEX idx_quest (quest_id),
    INDEX idx_season (season_id)
);

-- Example data:
INSERT INTO dc_quest_chest_config VALUES
(NULL, 1234, 1, 230, 190100, 2, 4, 10, 15, 1, TRUE, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());
--      ^     quest  tier  ilvl  chest_goid  min_items  max_items  min_tokens  max_tokens  season
```

#### 2.4 Chest Loot Table

**New Table: `dc_chest_loot_table`**
```sql
CREATE TABLE dc_chest_loot_table (
    loot_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    chest_tier TINYINT UNSIGNED,       -- T0-T4
    item_id INT UNSIGNED,
    drop_chance FLOAT,                  -- 0.0-1.0
    min_count INT UNSIGNED,
    max_count INT UNSIGNED,
    item_quality TINYINT UNSIGNED,      -- Rarity
    ilvl_offset INT SIGNED,             -- -5 to +10
    season_id INT UNSIGNED,
    INDEX idx_tier (chest_tier),
    INDEX idx_season (season_id)
);

-- Example:
INSERT INTO dc_chest_loot_table VALUES
(NULL, 1, 168314, 0.50, 1, 2, 3, 0, 1);  -- 50% chance for Common item, 1-2 quantity
(NULL, 1, 101000, 0.40, 5, 10, 0, 0, 1); -- 40% chance for 5-10 tokens
(NULL, 1, 168315, 0.30, 1, 1, 4, 5, 1);  -- 30% chance for Rare item, +5 ilvl
```

#### 2.5 Implementation: PlayerScript Hook

**File**: `src/server/scripts/DC/Seasonal/SeasonalQuestChestInjector.cpp`

```cpp
class SeasonalQuestChestInjector : public PlayerScript
{
public:
    SeasonalQuestChestInjector() : PlayerScript("SeasonalQuestChestInjector") {}
    
    void OnQuestComplete(Player* player, Quest const* quest) override
    {
        if (!sSeasonalMgr->IsChestEnabledForQuest(quest->GetQuestId()))
            return;
        
        // Step 1: Get chest config for this quest
        ChestConfig* config = sSeasonalMgr->GetQuestChestConfig(quest->GetQuestId());
        if (!config)
            return;
        
        // Step 2: Calculate item level based on player and quest level
        uint16 chest_ilvl = CalculateChestItemLevel(player, quest, config);
        
        // Step 3: Determine if chest drops or goes to inventory
        if (player->GetFreeBagSlots() >= 1)
        {
            // Add directly to inventory
            GenerateChestLoot(player, config, chest_ilvl);
        }
        else
        {
            // Drop on ground
            DropChestAtPlayer(player, config, chest_ilvl);
        }
        
        // Step 4: Log to audit trail
        LogChestDrop(player, quest, config, chest_ilvl);
    }
    
private:
    uint16 CalculateChestItemLevel(Player* player, Quest const* quest, ChestConfig* config)
    {
        // Base from quest reward level
        uint16 base_ilvl = config->base_ilvl;
        
        // Adjust for player level
        uint8 level_diff = player->GetLevel() - 70; // Max level: 70
        if (level_diff > 0)
            base_ilvl += (level_diff * 2); // +2 ilvl per level above 70
        
        // Apply season multiplier
        uint32 season_id = sSeasonalMgr->GetActiveSeasonId();
        float season_ilvl_multiplier = sSeasonalMgr->GetSeasonMultiplier(season_id, "quest_ilvl");
        base_ilvl = static_cast<uint16>(base_ilvl * season_ilvl_multiplier);
        
        // Apply prestige bonus
        uint8 prestige_rank = sPrestigeMgr->GetPlayerPrestigeRank(player->GetGUID());
        base_ilvl += (prestige_rank * 2); // +2 ilvl per prestige rank
        
        return base_ilvl;
    }
    
    void GenerateChestLoot(Player* player, ChestConfig* config, uint16 chest_ilvl)
    {
        // Get loot table for this chest tier
        auto loot_entries = sSeasonalMgr->GetChestLootTable(config->tier);
        
        for (const auto& loot : loot_entries)
        {
            if (rand_chance(loot.drop_chance))
            {
                // Adjust ilvl if item
                ItemTemplate const* proto = sObjectMgr->GetItemTemplate(loot.item_id);
                if (proto && (proto->Class == ITEM_CLASS_ARMOR || proto->Class == ITEM_CLASS_WEAPON))
                {
                    // Modify item level temporarily
                    // (This would need custom item handling)
                }
                
                // Generate count
                uint32 count = urand(loot.min_count, loot.max_count);
                player->AddItem(loot.item_id, count);
            }
        }
    }
    
    void DropChestAtPlayer(Player* player, ChestConfig* config, uint16 chest_ilvl)
    {
        // Create temporary container at player location
        // ...implementation details...
    }
    
    void LogChestDrop(Player* player, Quest const* quest, ChestConfig* config, uint16 chest_ilvl)
    {
        // Insert into dc_reward_transactions for audit trail
        QueryBuilder q;
        q.Insert("dc_reward_transactions")
         .Set("player_guid", player->GetGUID())
         .Set("reward_type", "quest_chest")
         .Set("quest_id", quest->GetQuestId())
         .Set("tier", config->tier)
         .Set("ilvl", chest_ilvl)
         .Set("timestamp", time(nullptr))
         .Execute();
    }
};

void AddSCSeasonalQuestChestInjector(ScriptMgr* scriptMgr)
{
    scriptMgr->RegisterPlayerScript(new SeasonalQuestChestInjector());
}
```

#### 2.6 Chest Item Level Calculation

```cpp
CHEST_ILVL = Base_Quest_Ilvl × Season_Multiplier + (Prestige_Rank × 2)

// EXAMPLE:
// Quest ilvl: 248
// Season multiplier: 1.1x (Season 2)
// Prestige rank: 5
// Final: (248 × 1.1) + (5 × 2) = 272.8 + 10 = 282.8 → 282 ilvl
```

#### 2.7 Configuration

```ini
# Quest Chest Settings (season.conf)
Seasonal.Quests.EnableChestDrops=1
Seasonal.Quests.ChestDropOnComplete=1
Seasonal.Quests.ChestDropRate=1.0
Seasonal.Quests.ChestIlvlBonus=0.0
Seasonal.Quests.ChestPrestigeBonus=2           # +2 ilvl per prestige rank
Seasonal.Quests.ChestQualityScaling=1           # Scale item quality with tier

# Per-tier settings
Seasonal.Quests.Tier0.TokenMin=5
Seasonal.Quests.Tier0.TokenMax=10
Seasonal.Quests.Tier1.TokenMin=10
Seasonal.Quests.Tier1.TokenMax=15
```

---

## Question 3: Token Calculation with Prestige Mechanics

### 3.1 Current Token System (Phase 3 - No Prestige)

From the item upgrade system:
```cpp
// BASE TOKEN CALCULATION (NO PRESTIGE)
Tokens_Per_Level = Tier_Base + (Level × Tier_Scaling)

// EXAMPLES (Tier-specific base amounts):
Token_Common = 5 + (level × 0.5)     // Level 1: 5.5 tokens
Token_Uncommon = 10 + (level × 1.0)  // Level 1: 11 tokens
Token_Rare = 15 + (level × 1.5)      // Level 1: 16.5 tokens
Token_Epic = 25 + (level × 2.5)      // Level 1: 27.5 tokens
Token_Legendary = 50 + (level × 5.0) // Level 1: 55 tokens
```

### 3.2 Prestige System Details (From Phase 4B Architecture)

From `ItemUpgradeProgression.h`:

**Prestige Points per Upgrade**:
```cpp
Common:    5 points/level  × 10 levels   = 50 points  (0-49 prestige)
Uncommon:  10 points/level × 12 levels   = 120 points (50-169 prestige)
Rare:      15 points/level × 15 levels   = 225 points (170-394 prestige)
Epic:      25 points/level × 15 levels   = 375 points (395-769 prestige)
Legendary: 50 points/level × 15 levels   = 750 points (770-1519 prestige)
Bonus:     500 points per fully upgraded item
```

**Prestige Rank Progression**:
```
Prestige Rank = Total_Points / 1000
Rank 0:   0-999 points   (Novice Upgrader)
Rank 1:   1000-1999 points  (Novice Upgrader)
Rank 2:   2000-2999 points  (Novice Upgrader)
...
Rank 5:   5000-5999 points  (Skilled Upgrader)
...
Rank 10:  10000-10999 points (Master Upgrader)
...
Rank 50:  50000+ points   (Supreme Artifact Master)
```

### 3.3 Prestige-Aware Token Calculation

#### New Token Formula with Prestige

```cpp
// PRESTIGE AFFECTS TOKEN EARNINGS IN THREE WAYS:

// 1. BASE TOKEN BONUS (additive per rank)
prestige_token_bonus = player_prestige_rank × PRESTIGE_TOKENS_PER_RANK
// Example: Rank 5 × 1 token/rank = 5 bonus tokens

// 2. TOKEN MULTIPLIER BONUS (multiplicative)
prestige_multiplier = 1.0 + (player_prestige_rank × PRESTIGE_MULTIPLIER_PER_RANK)
// Example: 1.0 + (5 × 0.05) = 1.25x (25% bonus)

// 3. WEEKLY CAP INCREASE
prestige_weekly_cap_bonus = player_prestige_rank × PRESTIGE_CAP_INCREASE_PER_RANK
// Example: 500 base + (5 × 50) = 750 cap

// FINAL FORMULA:
final_tokens = (base_tokens × prestige_multiplier) + prestige_token_bonus

// Capped at weekly limit:
weekly_earned = GetPlayerTokensEarnedThisWeek(player_guid)
final_tokens = min(final_tokens, prestige_aware_weekly_cap - weekly_earned)
```

#### 3.4 Token Calculation Examples

**Example 1: M+ Rewards (M+10)**
```
Base M+ tokens: 13
Player prestige rank: 5
Season multiplier: 1.1x

Calculation:
- Prestige token bonus: 5 × 1 = 5 tokens
- Prestige multiplier: 1.0 + (5 × 0.05) = 1.25x
- Season multiplier: 1.1x
- Final: (13 × 1.25 × 1.1) + 5 = 17.8 + 5 = 22.8 → 22 tokens
```

**Example 2: Quest Rewards**
```
Base quest tokens: 10
Player prestige rank: 10
Season multiplier: 1.15x

Calculation:
- Prestige token bonus: 10 × 1 = 10 tokens
- Prestige multiplier: 1.0 + (10 × 0.05) = 1.50x
- Season multiplier: 1.15x
- Final: (10 × 1.50 × 1.15) + 10 = 17.25 + 10 = 27.25 → 27 tokens
```

**Example 3: Daily Quests (Repeatable)**
```
Base daily tokens: 5
Player prestige rank: 3
Season multiplier: 1.0x (neutral)

Calculation:
- Prestige token bonus: 3 × 1 = 3 tokens
- Prestige multiplier: 1.0 + (3 × 0.05) = 1.15x
- Season multiplier: 1.0x
- Final: (5 × 1.15 × 1.0) + 3 = 5.75 + 3 = 8.75 → 8 tokens
```

### 3.5 Weekly Cap with Prestige

#### Cap Calculation

```cpp
// BASE WEEKLY CAP (from seasonal system)
base_weekly_cap = 500 tokens

// PRESTIGE CAP INCREASE
prestige_cap_increase = player_prestige_rank × PRESTIGE_CAP_PER_RANK
// Default: 50 tokens per rank
// Example: Rank 5 = 500 + (5 × 50) = 750 cap

// SEASON CAP OVERRIDE
season_weekly_cap_override = GetSeasonWeeklyCap(season_id)
// Some seasons may have higher/lower caps

// FINAL CAP
final_weekly_cap = max(base_weekly_cap + prestige_cap_increase, season_override)

// SOFT CAP WARNING
soft_cap = final_weekly_cap × 0.80  // 80% of cap
// When player reaches soft cap, show warning
```

#### Cap Examples

```
Prestige Rank 0:  500 tokens/week (base)
Prestige Rank 1:  550 tokens/week
Prestige Rank 5:  750 tokens/week
Prestige Rank 10: 1000 tokens/week
Prestige Rank 20: 1500 tokens/week
Prestige Rank 50: 3000 tokens/week
```

#### Soft/Hard Cap Enforcement

```cpp
// Check if can claim reward
bool CanClaimTokenReward(Player* player, uint32 token_amount)
{
    uint8 prestige_rank = GetPlayerPrestigeRank(player->GetGUID());
    uint32 weekly_cap = GetPrestigeAwareWeeklyCap(prestige_rank);
    uint32 earned_this_week = GetPlayerTokensEarnedThisWeek(player->GetGUID());
    
    if (earned_this_week >= weekly_cap)
        return false;  // Hard cap reached
    
    return true;  // Can claim
}

// Get capped amount
uint32 GetCappedTokenAmount(Player* player, uint32 token_amount)
{
    uint8 prestige_rank = GetPlayerPrestigeRank(player->GetGUID());
    uint32 weekly_cap = GetPrestigeAwareWeeklyCap(prestige_rank);
    uint32 earned_this_week = GetPlayerTokensEarnedThisWeek(player->GetGUID());
    
    uint32 remaining = weekly_cap - earned_this_week;
    return min(token_amount, remaining);
}
```

### 3.6 Configuration

```ini
# Token & Prestige Settings (season.conf)

# Token Distribution
Tokens.BaseWeeklyCap=500
Tokens.SoftCapPercent=80           # Warning at 80%
Tokens.HardCapPercent=100          # Block at 100%

# Prestige Bonuses
Prestige.TokensPerRank=1.0         # Additive: +1 token per rank
Prestige.MultiiplierPerRank=0.05   # Multiplicative: +5% per rank
Prestige.CapIncreasePerRank=50     # +50 weekly cap per rank

# Season Overrides
Season1.WeeklyCap=500
Season2.WeeklyCap=600
Season3.WeeklyCap=700
```

### 3.7 Database Schema

**Extend `player_prestige` table**:
```sql
ALTER TABLE player_prestige ADD COLUMN (
    total_tokens_earned INT UNSIGNED DEFAULT 0,
    total_tokens_spent INT UNSIGNED DEFAULT 0,
    tokens_this_week INT UNSIGNED DEFAULT 0,
    weekly_cap_override INT UNSIGNED DEFAULT 0,
    last_cap_reset_timestamp INT UNSIGNED
);

-- Track weekly earnings
CREATE TABLE player_weekly_token_tracker (
    player_guid INT UNSIGNED,
    week_start INT UNSIGNED,
    tokens_earned INT UNSIGNED,
    tokens_spent INT UNSIGNED,
    weekly_cap INT UNSIGNED,
    is_soft_capped BOOLEAN DEFAULT FALSE,
    is_hard_capped BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (player_guid, week_start),
    FOREIGN KEY (player_guid) REFERENCES characters(guid)
);
```

---

## Question 4: Challenge Mode Support

### 4.1 Challenge Mode System (Current)

From existing code analysis:
```cpp
// CHALLENGE MODE SCALING (different from M+)
CM_HP_Multiplier = 1.8 × (1.15 ^ keystone_level)
CM_Damage_Multiplier = 1.8 × (1.15 ^ keystone_level)

// EXAMPLES:
// M+5 in CM: 1.8 × (1.15^5) = 1.8 × 2.011 = 3.62x HP, 3.62x Damage
// M+10 in CM: 1.8 × (1.15^10) = 1.8 × 4.046 = 7.28x HP, 7.28x Damage
```

### 4.2 Challenge Mode Reward Integration

#### Architecture

```
Challenge Mode Completion
        ↓
    Determine CM Tier (based on completion time)
        ↓
    Calculate Base CM Rewards
        ↓
    Apply CM Difficulty Multiplier (exponential)
        ↓
    Apply Season Multiplier
        ↓
    Apply Prestige Bonus
        ↓
    Award Tokens/Chest
```

#### 4.3 CM Reward Calculation

```cpp
// CHALLENGE MODE TOKEN FORMULA

// Base rewards by tier
CM_BASE_REWARD = {
    BRONZE:   20 tokens,
    SILVER:   35 tokens,
    GOLD:     50 tokens,
    PLAT:     75 tokens,
    DIAMOND:  100 tokens
};

// Difficulty multiplier (exponential like M+ but different curve)
CM_DIFFICULTY_MULTIPLIER = 1.8 × (1.15 ^ keystone_level)
// Normalized to 1.0 at M+0, gives unique progression

// Final calculation
CM_TOKENS = (BASE_CM_REWARD × CM_DIFFICULTY_MULTIPLIER) × SEASON_MULTIPLIER × PRESTIGE_MULTIPLIER

// EXAMPLE:
// Base CM reward (Silver): 35 tokens
// Difficulty (M+5): 1.8 × (1.15^5) = 3.62x
// Season multiplier: 1.1x
// Prestige (Rank 5): 1.25x
// Final: 35 × 3.62 × 1.1 × 1.25 = 173 tokens
```

#### 4.4 Challenge Mode Chest System

```sql
-- Challenge Mode Specific Chest Config
CREATE TABLE dc_challenge_mode_chest_config (
    config_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    dungeon_id INT UNSIGNED,
    completion_tier ENUM('BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND'),
    base_ilvl SMALLINT UNSIGNED,
    min_items INT UNSIGNED,
    max_items INT UNSIGNED,
    token_count_min INT UNSIGNED,
    token_count_max INT UNSIGNED,
    season_id INT UNSIGNED,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_dungeon (dungeon_id),
    INDEX idx_season (season_id)
);

-- Example: Siege of Boralus Challenge Mode
INSERT INTO dc_challenge_mode_chest_config VALUES
(NULL, 1481, 'GOLD', 265, 3, 5, 50, 70, 1, TRUE);
```

#### 4.5 Challenge Mode Difficulty Tiers

```
Completion Time Tier → Reward Multiplier
────────────────────────────────────────
BRONZE (Completion)   → 1.0x (20 tokens, 265 ilvl)
SILVER (Time+20)      → 1.75x (35 tokens, 272 ilvl)
GOLD (Time+10)        → 2.5x (50 tokens, 279 ilvl)
PLATINUM (Time exact) → 3.75x (75 tokens, 286 ilvl)
DIAMOND (Time-10)     → 5.0x (100 tokens, 293 ilvl)
```

#### 4.6 Season-Wide Challenge Mode Configuration

```ini
# Challenge Mode Settings (season.conf)
ChallengeModes.EnableSeasonalRewards=1
ChallengeModes.SeasonMultiplier=1.0
ChallengeModes.DifficultyScaling=1.15    # Exponential base
ChallengeModes.MiniumLevel=1.8           # Base minimum multiplier
ChallengeModes.PrestigeBonusEnabled=1
ChallengeModes.PrestigeBonusPerRank=0.05
ChallengeModes.ChestDropRate=1.0
ChallengeModes.TokenCap=50               # Weekly token cap for CM only
```

#### 4.7 Integration with Seasonal System

```cpp
// In SeasonalRewardManager, add CM handler

uint32 CalculateChallengeModeTierRewards(
    Player* player,
    uint32 dungeon_id,
    uint32 completion_time_ms,
    uint8& out_tier)
{
    // Step 1: Determine tier from completion time
    ChallengeModeConfig* config = GetChallengeModeDungeonConfig(dungeon_id);
    uint8 tier = DetermineCMTier(completion_time_ms, config->time_limits);
    out_tier = tier;
    
    // Step 2: Get base reward for this tier
    uint32 base_tokens = GetCMBaseReward(tier);
    
    // Step 3: Get difficulty multiplier (keystone level)
    uint8 highest_keystone = GetPlayerHighestKeystone(player->GetGUID());
    float difficulty_multiplier = 1.8f * pow(1.15f, highest_keystone);
    
    // Step 4: Get season multiplier
    uint32 season_id = GetActiveSeasonId();
    float season_multiplier = GetSeasonMultiplier(season_id, "challenge_modes");
    
    // Step 5: Get prestige bonus
    uint8 prestige_rank = GetPlayerPrestigeRank(player->GetGUID());
    float prestige_multiplier = 1.0f + (prestige_rank * PRESTIGE_BONUS_PER_RANK);
    
    // Step 6: Calculate final tokens
    uint32 final_tokens = base_tokens * difficulty_multiplier * season_multiplier * prestige_multiplier;
    
    // Step 7: Apply weekly CM cap
    uint32 cm_weekly_cap = GetCMWeeklyCap();
    uint32 earned_this_week = GetPlayerCMTokensEarnedThisWeek(player->GetGUID());
    
    if (earned_this_week + final_tokens > cm_weekly_cap)
        final_tokens = cm_weekly_cap - earned_this_week;
    
    return final_tokens;
}
```

#### 4.8 Challenge Mode Rewards Database

```sql
-- CM Specific reward tracking
CREATE TABLE player_cm_reward_tracker (
    player_guid INT UNSIGNED,
    dungeon_id INT UNSIGNED,
    season_id INT UNSIGNED,
    best_tier ENUM('BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND'),
    tokens_earned INT UNSIGNED DEFAULT 0,
    completion_count INT UNSIGNED DEFAULT 0,
    last_completion_timestamp INT UNSIGNED,
    PRIMARY KEY (player_guid, dungeon_id, season_id),
    FOREIGN KEY (player_guid) REFERENCES characters(guid),
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
);

-- Audit log
CREATE TABLE challenge_mode_completions (
    completion_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    player_guid INT UNSIGNED,
    dungeon_id INT UNSIGNED,
    tier ENUM('BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND'),
    completion_time_ms INT UNSIGNED,
    tokens_awarded INT UNSIGNED,
    chest_dropped BOOLEAN,
    chest_ilvl SMALLINT UNSIGNED,
    season_id INT UNSIGNED,
    timestamp INT UNSIGNED,
    INDEX idx_player (player_guid),
    INDEX idx_season (season_id),
    FOREIGN KEY (player_guid) REFERENCES characters(guid)
);
```

---

## Combined Implementation Strategy

### Integration Flow Diagram

```
UNIFIED SEASONAL REWARD SYSTEM
│
├─ M+ Vault Rewards
│  ├─ Base token calculation (existing)
│  ├─ × Season multiplier
│  ├─ × Difficulty multiplier
│  └─ × (1 + Prestige bonus)
│
├─ Quest Chest Drops
│  ├─ Quest completion hook
│  ├─ → Tier determination
│  ├─ → Item level scaling
│  ├─ → Loot table generation
│  └─ → Chest injection
│
├─ Token Cap System
│  ├─ Base cap (500)
│  ├─ + Prestige increase (50/rank)
│  ├─ Weekly tracking
│  └─ Soft/hard cap enforcement
│
└─ Challenge Mode Rewards
   ├─ Completion tier determination
   ├─ Base CM rewards
   ├─ × Difficulty multiplier
   ├─ × Season multiplier
   ├─ × Prestige multiplier
   └─ → Separate weekly cap
```

### Implementation Phases

**Phase 1: Foundation (Week 1-2)**
- Create database schema
- Create configuration system
- Create base multiplier calculations

**Phase 2: M+ Integration (Week 2-3)**
- Hook into vault_rewards.cpp
- Implement seasonal multipliers
- Implement prestige bonuses
- Test with M+ runs

**Phase 3: Quest System (Week 3-4)**
- Create chest generator
- Implement PlayerScript hook
- Generate loot tables
- Test with quest completions

**Phase 4: Cap & Prestige (Week 4-5)**
- Implement weekly tracker
- Implement cap enforcement
- Add prestige bonuses
- Test with multiple players

**Phase 5: Challenge Modes (Week 5-6)**
- Create CM reward calculator
- Hook into CM completion
- Implement tier system
- Test with dungeons

**Phase 6: Admin & Monitoring (Week 6-7)**
- Create admin commands
- Create leaderboards
- Create audit logs
- Create debug information

---

## Database Schema Extensions

### Summary of New Tables

```sql
-- Seasonal Configuration
dc_seasonal_quest_rewards          (quest tier/ilvl mapping)
dc_seasonal_creature_rewards       (creature tier/loot)
dc_seasonal_chest_rewards          (chest contents)
dc_seasonal_reward_multipliers     (season-wide multipliers)

-- Quest Chest System
dc_quest_chest_config              (quest→chest mapping)
dc_chest_loot_table                (chest contents)

-- Token & Cap Tracking
dc_reward_transactions             (audit log)
player_weekly_token_tracker        (weekly cap enforcement)
player_seasonal_stats              (player season data)

-- Challenge Mode
dc_challenge_mode_chest_config     (CM reward tiers)
player_cm_reward_tracker           (CM completion tracking)
challenge_mode_completions         (CM audit log)

-- Prestige System
player_prestige                    (rank/points)
player_tier_caps                   (tier unlocking)
player_progression_stats           (statistics)
```

### Key Schema Modifications

```sql
-- Extend dc_seasonal_reward_multipliers for M+
ALTER TABLE dc_seasonal_reward_multipliers ADD COLUMN (
    mythic_plus_multiplier FLOAT DEFAULT 1.0,
    mythic_plus_difficulty_bonus FLOAT DEFAULT 0.0,
    mythic_plus_prestige_bonus FLOAT DEFAULT 0.05,
    challenge_mode_multiplier FLOAT DEFAULT 1.0,
    quest_chest_multiplier FLOAT DEFAULT 1.0
);

-- Create unified cap tracker
CREATE TABLE seasonal_resource_caps (
    season_id INT UNSIGNED,
    player_guid INT UNSIGNED,
    resource_type ENUM('tokens', 'essence'),
    weekly_cap INT UNSIGNED,
    amount_earned INT UNSIGNED,
    amount_spent INT UNSIGNED,
    soft_cap_reached BOOLEAN DEFAULT FALSE,
    hard_cap_reached BOOLEAN DEFAULT FALSE,
    week_start INT UNSIGNED,
    PRIMARY KEY (season_id, player_guid, resource_type, week_start),
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
);
```

---

## Code Architecture

### File Structure

```
src/server/scripts/DC/Seasonal/
├─ SeasonalRewardManager.h          (Main manager)
├─ SeasonalRewardManager.cpp        (Implementation)
├─ SeasonalQuestChestInjector.cpp   (Quest hook)
├─ MythicPlusSeasonalIntegration.cpp (M+ hook)
├─ ChallengeModeSeasonalIntegration.cpp (CM hook)
├─ SeasonalTokenCalculator.h        (Token formulas)
├─ SeasonalTokenCalculator.cpp      (Token calculation)
├─ PrestigeAwareCapManager.h        (Cap system)
├─ PrestigeAwareCapManager.cpp      (Cap enforcement)
└─ SeasonalAuditLog.cpp             (Logging)

src/server/scripts/DC/ItemUpgrades/
├─ ItemUpgradeSeasonal.h            (Headers - exists)
├─ ItemUpgradeProgressionImpl.cpp    (Prestige system)
├─ ItemUpgradeSeasonalImpl.cpp       (Season management)

Database/
├─ world/
│  └─ dc_seasonal_extended.sql      (New tables)
│  └─ dc_challenge_modes.sql        (CM tables)
└─ characters/
   └─ dc_prestige_extended.sql      (Cap tracking)
```

### Key Classes

```cpp
// Main coordinator
class SeasonalRewardManager
{
public:
    // M+ Integration
    uint32 CalculateVaultTokens_Seasonal(Player*, uint8 keystoneLevel);
    
    // Quest Integration
    void OnQuestComplete(Player*, Quest*);
    void GenerateQuestChest(Player*, Quest*);
    
    // Challenge Mode Integration
    uint32 CalculateCMReward(Player*, uint32 dungeon, uint8& tier);
    void OnCMComplete(Player*, uint32 dungeon, uint32 timeMs);
    
    // Token Cap Management
    bool CanClaimTokens(Player*, uint32 amount);
    uint32 GetRemainingTokenCap(Player*);
    void TrackTokenClaim(Player*, uint32 amount);
    
    // Configuration
    float GetSeasonMultiplier(uint32 seasonId, string rewardType);
    uint32 GetPrestigeAwareWeeklyCap(uint8 prestigeRank);
};

// Token calculation with prestige
class SeasonalTokenCalculator
{
public:
    uint32 CalculateTokensWithPrestige(
        Player* player,
        uint32 baseTokens,
        uint8 source // 0=M+, 1=Quest, 2=CM, etc.
    );
    
    uint32 ApplyPrestigeMultiplier(uint32 baseTokens, uint8 prestigeRank);
    uint32 ApplySeasonMultiplier(uint32 baseTokens, uint32 seasonId);
    uint32 ApplyWeeklyCap(Player* player, uint32 tokens);
};

// Cap enforcement
class PrestigeAwareCapManager
{
public:
    bool CanClaimReward(Player*, uint32 tokenAmount);
    uint32 GetWeeklyCap(uint8 prestigeRank);
    uint32 GetRemainingCapacity(Player*);
    void TrackClaim(Player*, uint32 amount);
    void ResetWeeklyCaps(); // Called Sunday 00:00
};
```

---

## Summary Table

| System | Integration Point | Multipliers | Weekly Cap | Prestige Impact |
|--------|------------------|-------------|-----------|-----------------|
| **M+ Vault** | vault_rewards.cpp | Season × Difficulty × Prestige | Base 500 | +50/rank |
| **Quest Chests** | PlayerScript::OnQuestComplete | Season × Difficulty | Shared 500 | +50/rank |
| **Challenge Modes** | CM completion event | Season × CM-Difficulty × Prestige | Separate 50 | +5/rank |
| **Weekly Cap** | PrestigeAwareCapManager | Base 500 + (Rank × 50) | Per resource | Direct multiplier |

---

## Next Steps

1. **Create database migrations** for all new tables
2. **Implement SeasonalRewardManager** base class
3. **Hook into M+ vault system** with seasonal multipliers
4. **Create quest chest injection** via PlayerScript
5. **Implement prestige-aware cap system** with enforcement
6. **Add Challenge Mode integration** with unique scaling
7. **Create admin commands** for testing and monitoring
8. **Run comprehensive testing** with all combinations
9. **Create player documentation** and balance notes
10. **Deploy and monitor** for first season

---

**End of Document**
