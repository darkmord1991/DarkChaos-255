# Comprehensive Feature Proposals for DarkChaos-255
## WoW 3.3.5a Progressive Max Level 255 Server

**Document Version:** 1.0  
**Date:** November 4, 2025  
**Status:** PLANNING & ANALYSIS  
**Last Updated:** Based on learnings from M+ system design

---

## 🎯 Executive Overview

This document catalogs **all proposed features and enhancements** for DarkChaos-255 server, organized by:
1. **Implementation Scope** (Server-only, Server+Client, Client-only)
2. **Priority Tier** (P1/P2/P3)
3. **Effort Estimation** (hours)
4. **Dependencies** (what needs to be done first)

---

## 📊 Organization by Implementation Scope

### **KEY PRINCIPLES (from learnings)**
- ✅ Keep separate from core AzerothCore systems (avoid conflicts with updates)
- ✅ All custom tables prefixed with `dc_` (DarkChaos prefix)
- ✅ Item upgrade system with proper scaling for Level 80→255
- ✅ Season system for limiting/rotating content
- ✅ Focus on player-felt mechanics (reduce complexity where needed)
- ✅ Death count limits instead of timer-based mechanics for M+
- ✅ Weekly vault integration
- ✅ Separate teleporter NPCs per season

---

# 🖥️ SECTION 1: SERVER-ONLY IMPLEMENTATIONS

## 1.1 Item Upgrade System (CORE FOUNDATION)

**Priority:** ⭐⭐⭐⭐⭐ P1 - FOUNDATIONAL  
**Complexity:** ⭐⭐⭐⭐ High  
**Effort:** 120-150 hours  
**Dependencies:** Database schema design

### **Purpose**
Progressive item upgrade path from Level 80 → Level 255, with proper scaling for:
- M+ Dungeons
- Regular Dungeons (Heroic/Mythic difficulties)
- Raid content (Normal/Heroic/Mythic)
- Seasonal progression

### **Design Requirements**

#### Database Schema (`dc_item_upgrade_system`)

```sql
-- Track item upgrade paths
CREATE TABLE dc_item_upgrades (
  id INT PRIMARY KEY AUTO_INCREMENT,
  base_item_id INT NOT NULL,
  upgrade_level TINYINT NOT NULL,  -- 0-10 (represents +0 to +10 upgrades)
  upgraded_item_id INT NOT NULL,   -- Item entry after upgrade
  upgrade_cost_currency INT,        -- Currency required
  upgrade_cost_amount INT,
  requires_season INT,              -- NULL if always available
  requires_difficulty VARCHAR(50),  -- 'heroic', 'mythic', 'm+1-7', 'm+8-15'
  added_ilvl TINYINT,               -- How many ilvls this upgrade adds
  description VARCHAR(255),
  created_date TIMESTAMP,
  UNIQUE KEY (base_item_id, upgrade_level),
  KEY (upgraded_item_id),
  KEY (requires_season)
);

-- Track player upgrade progress
CREATE TABLE dc_player_item_upgrades (
  character_guid INT,
  item_guid INT,
  item_id INT,
  current_upgrade_level TINYINT DEFAULT 0,
  max_upgrade_level TINYINT,
  upgrade_progress INT,  -- Progress towards next upgrade
  season INT,
  date_upgraded TIMESTAMP,
  PRIMARY KEY (character_guid, item_guid),
  KEY (item_id),
  KEY (season)
);

-- Item scaling configuration per difficulty
CREATE TABLE dc_item_scaling_config (
  id INT PRIMARY KEY AUTO_INCREMENT,
  content_type VARCHAR(50),  -- 'dungeon', 'raid', 'mythic_plus'
  difficulty_name VARCHAR(50),  -- 'heroic', 'mythic', 'm+1-7'
  base_ilvl INT,
  upgrade_slots TINYINT,  -- How many upgrade steps available
  upgrade_currency VARCHAR(50),  -- 'valor', 'justice', 'conquest'
  currency_cost_per_upgrade INT,
  min_player_level INT,
  season INT,  -- NULL if permanent
  active BOOLEAN DEFAULT TRUE
);

-- Season-specific item pools
CREATE TABLE dc_season_item_pools (
  season INT PRIMARY KEY,
  item_pool_name VARCHAR(100),
  start_date TIMESTAMP,
  end_date TIMESTAMP,
  dungeons_available TEXT,  -- JSON array of dungeon IDs
  raids_available TEXT,     -- JSON array of raid IDs
  available_difficulties TEXT,  -- ['normal', 'heroic', 'mythic']
  seasonal_token_id INT,    -- Special currency for this season
  seasonal_currency_name VARCHAR(50),
  base_rewards_ilvl INT,
  max_upgrade_ilvl INT,
  description VARCHAR(255)
);
```

### **Implementation Components**

#### **1. Item Upgrade Handler (C++)**

```cpp
// File: src/server/scripts/Custom/ItemUpgrade/ItemUpgradeManager.h
#pragma once

class ItemUpgradeManager {
public:
  static ItemUpgradeManager* instance();
  
  // Upgrade operations
  bool UpgradeItem(Player* player, uint32 itemGuid, uint32 season);
  bool CanUpgradeItem(Player* player, uint32 itemGuid);
  uint32 GetUpgradeCost(uint32 itemId, uint8 upgradeLevel);
  
  // Query upgrade chains
  struct UpgradeChain {
    std::vector<uint32> items;  // Item IDs in upgrade path
    std::vector<uint8> ilvls;   // Item levels at each step
    uint32 totalCost;
    uint8 maxUpgrades;
  };
  
  UpgradeChain GetUpgradeChain(uint32 baseItemId, uint32 season);
  
  // Scaling calculations
  uint32 GetScaledItemLevel(uint32 contentType, std::string difficulty, uint8 upgradeLevel);
  float GetStatMultiplier(uint32 contentType, std::string difficulty);
  
private:
  std::unordered_map<uint32, UpgradeChain> upgradeChainCache;
};
```

**Effort:** 40-50 hours

#### **2. Currency/Vault Management**

```cpp
// Multiple currency types needed:
enum class CurrencyType {
  VALOR = 1,           // M+ dungeons
  JUSTICE = 2,         // Regular dungeons
  CONQUEST = 3,        // Raids (PvP-equivalent)
  SEASONAL_SPECIAL = 4 // Season-specific
};

// Track player currency balance
CREATE TABLE dc_player_currency (
  character_guid INT,
  currency_type INT,
  amount INT DEFAULT 0,
  max_cap INT,
  season INT,
  updated_date TIMESTAMP,
  PRIMARY KEY (character_guid, currency_type, season)
);
```

**Effort:** 30-40 hours

#### **3. Weekly Vault System**

```cpp
// Similar to Retail WoW: players earn vault options
CREATE TABLE dc_weekly_vault (
  vault_id INT PRIMARY KEY AUTO_INCREMENT,
  character_guid INT NOT NULL,
  season INT NOT NULL,
  week_number INT NOT NULL,  -- Week of season
  
  -- Three reward slot options (player picks 1)
  reward_slot_1_item_id INT,
  reward_slot_1_quantity INT,
  reward_slot_1_ilvl INT,
  
  reward_slot_2_item_id INT,
  reward_slot_2_quantity INT,
  reward_slot_2_ilvl INT,
  
  reward_slot_3_item_id INT,
  reward_slot_3_quantity INT,
  reward_slot_3_ilvl INT,
  
  chosen_slot TINYINT,  -- Which slot player picked (0 if not chosen)
  reward_claimed BOOLEAN DEFAULT FALSE,
  claimed_date TIMESTAMP,
  created_date TIMESTAMP,
  
  UNIQUE KEY (character_guid, season, week_number),
  KEY (season, claimed_date)
);

-- Determine vault options based on activities completed in week
CREATE TABLE dc_vault_completion_tracker (
  character_guid INT,
  season INT,
  week_number INT,
  
  -- Completion flags
  mythic_plus_runs INT DEFAULT 0,
  heroic_dungeons INT DEFAULT 0,
  raid_bosses_killed INT DEFAULT 0,
  
  -- Progress towards vault options
  m_plus_option BOOLEAN DEFAULT FALSE,  -- 1 M+ run completes
  dungeon_option BOOLEAN DEFAULT FALSE,  -- 2 heroic dungeons complete
  raid_option BOOLEAN DEFAULT FALSE,     -- 3 raid bosses complete
  
  week_reset_date TIMESTAMP,
  PRIMARY KEY (character_guid, season, week_number)
);
```

**Effort:** 50-60 hours

### **Item Upgrade Scaling Formula**

```
Base iLvl Calculation:
- Level 80 gear: 200 iLvl
- Heroic Dungeons: 219 iLvl base
- Mythic Dungeons: 226 iLvl base
- M+ Dungeons: 226 + (2 * mythic_level) iLvl
  - M+1: 228
  - M+7: 240
  - M+15: 256
  
- Normal Raid: 245 iLvl base
- Heroic Raid: 258 iLvl base  
- Mythic Raid: 271 iLvl base

Upgrade Path Formula:
- Each upgrade level: +3 iLvl per step
- Max upgrades per item: 10 levels (30 iLvl potential)
- Season 1: Base iLvl scaling applies
- Season 2+: Additional base multiplier (1.05x for Season 2, etc.)

Cost Scaling:
- First upgrade: 50 Valor
- Each subsequent: +25 Valor (50, 75, 100, 125...)
- Max cost at 10x: 275 Valor per upgrade
```

**Effort:** 20-30 hours

**Total Item Upgrade System: 140-180 hours**

---

## 1.2 Season System (CORE SUPPORT)

**Priority:** ⭐⭐⭐⭐⭐ P1 - FOUNDATIONAL  
**Complexity:** ⭐⭐⭐ Medium  
**Effort:** 80-100 hours  
**Dependencies:** Item Upgrade System

### **Purpose**
- Limit availability of M+ dungeons per season (4-5 specific dungeons)
- Rotate available raids/content
- Reset progression leaderboards
- Provide seasonal cosmetics/rewards
- Create seasonal currency that invalidates after season ends

### **Database Schema**

```sql
CREATE TABLE dc_seasons (
  season_id INT PRIMARY KEY AUTO_INCREMENT,
  season_number INT UNIQUE,  -- 1, 2, 3, etc.
  season_name VARCHAR(100),  -- "Season of the First War", etc.
  season_theme VARCHAR(100),
  
  -- Dates
  start_date TIMESTAMP,
  end_date TIMESTAMP,
  
  -- Content
  available_mythic_dungeons TEXT,  -- JSON: [2, 35, 36, 285, 287]
  available_raids TEXT,            -- JSON: [615, 616, 619]
  available_difficulties TEXT,     -- JSON: ['normal', 'heroic', 'mythic']
  
  -- Currencies
  primary_currency_id INT,  -- Valor, Conquest, etc.
  primary_currency_name VARCHAR(50),
  currency_cap INT,
  
  -- Item pools
  seasonal_token_id INT,   -- Transmog-able seasonal cosmetic
  base_item_ilvl INT,
  max_item_ilvl INT,  -- After 10 upgrades
  
  -- Progression
  initial_difficulty_min_ilvl INT,  -- Entry requirement
  
  description VARCHAR(500),
  rewards_description VARCHAR(500),
  active BOOLEAN DEFAULT FALSE,
  archived BOOLEAN DEFAULT FALSE
);

-- Season-specific NPC teleporters
CREATE TABLE dc_seasonal_teleporters (
  npc_entry INT PRIMARY KEY AUTO_INCREMENT,
  season_id INT NOT NULL,
  npc_name VARCHAR(100),
  npc_portrait_model INT,
  locations_available TEXT,  -- JSON with teleport targets
  required_level INT,
  required_item_level INT,
  permanent BOOLEAN DEFAULT FALSE,  -- Exists across seasons
  spawned_after_season INT,  -- NULL if always up
  despawn_after_season INT,  -- NULL if permanent
  KEY (season_id)
);

-- Season-specific achievements
CREATE TABLE dc_seasonal_achievements (
  achievement_id INT PRIMARY KEY AUTO_INCREMENT,
  season_id INT NOT NULL,
  achievement_name VARCHAR(100),
  description VARCHAR(255),
  reward_type VARCHAR(50),  -- 'title', 'cosmetic', 'currency'
  reward_value INT,
  requirement_type VARCHAR(50),  -- 'reach_rating', 'complete_mythic'
  requirement_value INT,
  cosmetic_name VARCHAR(100),
  archived BOOLEAN DEFAULT FALSE,
  KEY (season_id)
);
```

### **Season Management Logic**

```cpp
class SeasonManager {
public:
  static SeasonManager* instance();
  
  uint32 GetCurrentSeason();
  void StartNewSeason(uint32 seasonId);
  void EndSeason(uint32 seasonId);
  
  // Content availability
  std::vector<uint32> GetAvailableDungeons(uint32 season);
  std::vector<uint32> GetAvailableRaids(uint32 season);
  
  // Progression reset
  void ResetLeaderboards(uint32 previousSeason);
  void ResetPlayerRatings(uint32 previousSeason);
  void ArchiveSeasonalItems(uint32 previousSeason);
};
```

**Effort:** 30-40 hours

### **Weekly Reset Mechanics**

```sql
CREATE TABLE dc_weekly_reset_schedule (
  reset_id INT PRIMARY KEY AUTO_INCREMENT,
  reset_day INT,  -- 0=Monday, 1=Tuesday, etc (Use your server reset day)
  reset_hour INT,
  reset_minute INT,
  
  -- What resets
  resets_vault BOOLEAN DEFAULT TRUE,
  resets_dungeon_keys BOOLEAN DEFAULT FALSE,
  resets_raid_lockouts BOOLEAN DEFAULT TRUE,
  resets_m_plus_rating BOOLEAN DEFAULT FALSE,
  
  active BOOLEAN DEFAULT TRUE
);
```

**Effort:** 15-20 hours

**Total Season System: 45-60 hours**

---

## 1.3 Prestige System

**Priority:** ⭐⭐⭐⭐ P2 - High Value  
**Complexity:** ⭐⭐⭐ Medium  
**Effort:** 100-120 hours  
**Dependencies:** Character database modifications

### **Purpose**
- Allow players to reset to level 1 after reaching 255
- Provide permanent stat bonuses (1% per prestige level)
- Unlock cosmetic rewards (titles, mounts, pets)
- Create long-term engagement

### **Database Schema**

```sql
CREATE TABLE dc_prestige_system (
  character_guid INT PRIMARY KEY,
  
  -- Prestige tracking
  prestige_level INT DEFAULT 0,  -- 0-20 levels suggested
  prestige_resets INT DEFAULT 0,
  
  -- Permanent bonuses
  stat_bonus_multiplier FLOAT,  -- 1.01 per level (1% each)
  health_bonus_percent INT,     -- Stored as (1 + percent)
  mana_bonus_percent INT,
  stat_bonus_percent INT,       -- Applies to all primary stats
  
  -- Cosmetics unlocked
  prestige_titles TEXT,         -- JSON array of available titles
  prestige_mounts TEXT,         -- JSON array of mount IDs
  prestige_pets TEXT,           -- JSON array of pet IDs
  prestige_cosmetics TEXT,      -- Other cosmetics
  
  -- History
  first_prestige_date TIMESTAMP,
  last_prestige_date TIMESTAMP,
  total_prestige_playtime INT,  -- In seconds
  
  KEY (prestige_level DESC),
  KEY (last_prestige_date DESC)
);

-- Prestige achievements/milestones
CREATE TABLE dc_prestige_rewards (
  reward_id INT PRIMARY KEY AUTO_INCREMENT,
  prestige_level INT UNIQUE,  -- Reward for reaching this level
  title_id INT,               -- Unlock title
  mount_id INT,               -- Unlock mount
  pet_id INT,                 -- Unlock pet
  cosmetic_id INT,            -- Unlock cosmetic
  bonus_description VARCHAR(255)
);
```

### **Implementation**

```cpp
class PrestigeSystem {
public:
  static PrestigeSystem* instance();
  
  // Prestige operations
  bool ResetCharacterForPrestige(Player* player);
  void UpgradePrestigeLevel(Player* player);
  
  // Stat calculations
  float GetStatBonusMultiplier(Player* player);
  uint32 GetHealthBonus(Player* player);
  uint32 GetManaBonus(Player* player);
  
  // Cosmetics
  void UnlockPrestigeRewards(Player* player, uint32 prestigeLevel);
  
private:
  std::unordered_map<uint32, float> prestigeBonuses;
};

// Hook into character creation/level up
void Player::ResetForPrestige() {
  // Store current prestige level
  uint32 currentPrestige = GetPrestigeLevel();
  
  // Reset level to 1
  SetLevel(1);
  SetExperience(0);
  
  // Update prestige counter
  SetPrestigeLevel(currentPrestige + 1);
  
  // Apply permanent bonuses
  ApplyPrestigeStatBonuses();
  
  // Teleport to starting zone (or custom area)
  TeleportTo(DARKMOON_ISLAND or custom_prestige_zone);
  
  // Grant cosmetics for new prestige level
  GrantPrestigeRewards(currentPrestige + 1);
}
```

**Effort:** 40-50 hours

### **Prestige Rewards Ladder**

```
Prestige 1: +1% all stats, Title "Prestige I"
Prestige 2: +2% all stats, Title "Prestige II", Mount #1
Prestige 3: +3% all stats, Cosmetic #1
Prestige 4: +4% all stats, Pet #1
Prestige 5: +5% all stats, Title "Prestige Master", Transmog outfit
...
Prestige 10: +10% all stats, Exclusive Mount "Prestige Phoenix"
...
Prestige 20: +20% all stats, Exclusive Title "Eternal Prestige", Special cosmetics
```

**Effort:** 15-20 hours

**Total Prestige System: 55-70 hours**

---

## 1.4 Mythic+ Dungeons (REVISED SCOPE)

**Priority:** ⭐⭐⭐ P2 - High Value  
**Complexity:** ⭐⭐⭐⭐ High  
**Effort:** 200-250 hours (revised down from 500)  
**Dependencies:** Item Upgrade System, Season System

### **Updated Design (Based on Learnings)**

✅ **Keep:**
- Item scaling with difficulty levels
- Seasons (limit to 4-5 dungeons per season)
- Rating system based on mythic level + death count
- Weekly vault integration
- Tokens + 2-3 items per group completion

❌ **Remove/Simplify:**
- Timer mechanics (SKIP - too complex)
- Complex affix system (reduce to 3-4 simple ones max)
- Keystone downgrade/upgrade complexity

✅ **Replace Timer with:**
- Death count limit per dungeon
- Group wipe limits
- Simple pass/fail mechanic

### **Database Schema (dc_ prefixed)**

```sql
-- M+ Dungeon difficulty tracking
CREATE TABLE dc_mythic_plus_dungeons (
  dungeon_id INT PRIMARY KEY,
  dungeon_name VARCHAR(100),
  mythic_plus_enabled BOOLEAN DEFAULT TRUE,
  base_ilvl INT,
  difficulty_tiers TEXT,  -- JSON: [1, 3, 7, 10, 15]
  death_limit_per_level INT DEFAULT 5,  -- Per mythic level
  group_wipe_limit INT DEFAULT 3,
  token_reward_id INT,
  item_reward_count INT DEFAULT 3,
  season INT,  -- Available in season
  KEY (season)
);

-- M+ Rating system (simplified)
CREATE TABLE dc_mythic_plus_rating (
  character_guid INT,
  season INT,
  rating INT DEFAULT 0,  -- ELO-like system
  best_dungeon_level INT,
  dungeon_count INT,
  death_count INT,
  date_updated TIMESTAMP,
  PRIMARY KEY (character_guid, season),
  KEY (rating DESC)
);

-- Track individual M+ runs
CREATE TABLE dc_mythic_plus_runs (
  run_id INT PRIMARY KEY AUTO_INCREMENT,
  character_guid INT,
  dungeon_id INT,
  mythic_level INT,
  season INT,
  completed BOOLEAN,
  death_count INT,
  wipe_count INT,
  rating_change INT,
  items_earned TEXT,  -- JSON array of item IDs
  tokens_earned INT,
  completion_date TIMESTAMP,
  KEY (character_guid, season),
  KEY (dungeon_id, mythic_level)
);

-- Simplified affix system (3-4 affixes only)
CREATE TABLE dc_mythic_affixes (
  affix_id INT PRIMARY KEY,
  affix_name VARCHAR(50),
  description VARCHAR(255),
  difficulty_multiplier FLOAT,  -- HP/Damage impact
  visible_in_ui BOOLEAN DEFAULT TRUE,
  available_seasons TEXT,  -- JSON: [1, 2, 3]
  active BOOLEAN DEFAULT TRUE
);
```

**Recommended Affixes (3-4 only for simplicity):**
1. **Tyrannical** - Bosses +15% HP, +15% Damage
2. **Fortified** - Non-bosses +12% HP, +12% Damage
3. **Explosive** - Orbs spawn on trash death (simple mechanic)
4. **Seasonal Affix** - Rotates each season (only for M+10+)

**Effort:** 40-50 hours

### **Seasonal Teleporter NPCs**

```cpp
// Each season gets dedicated teleporter NPC
CREATE TABLE dc_seasonal_m_plus_teleporter (
  npc_entry INT PRIMARY KEY AUTO_INCREMENT,
  season_id INT NOT NULL,
  npc_name VARCHAR(100),
  npc_model INT,
  dungeon_list TEXT,  -- JSON array of season dungeons
  required_ilvl INT,
  spawn_location_x FLOAT,
  spawn_location_y FLOAT,
  spawn_location_z FLOAT,
  map_id INT,
  permanent_teleporter BOOLEAN DEFAULT FALSE,
  KEY (season_id)
);

// Implementation: NPC that teleports to dungeons
class NPC_MythicPlusTeleporter : public CreatureScript {
  OnGossipHello() {
    // List available M+ dungeons for current season
    // Each option: Teleport to dungeon entrance
  }
};
```

**Effort:** 30-40 hours

### **Death Count & Rating System**

```cpp
// Simplified rating: based on level + death efficiency
// Formula: BaseRating = (MythicLevel * 50) - (DeathCount * 5)
// No timer to calculate, just count deaths per run

void CalculateRating(MythicRun& run) {
  int32 baseRating = (run.mythicLevel * 50);
  int32 deathPenalty = (run.deathCount * 5);
  int32 wipePenalty = (run.wipeCount * 10);
  
  run.ratingGain = std::max(0, baseRating - deathPenalty - wipePenalty);
}
```

**Effort:** 20-25 hours

### **Tokens + Loot Distribution**

```sql
-- M+ Seasonal Token (convertible to items)
CREATE TABLE dc_mythic_token (
  item_id INT PRIMARY KEY,
  token_name VARCHAR(100),
  season INT UNIQUE,
  exchange_items TEXT,  -- JSON: item IDs this can convert to
  exchange_ratios TEXT,  -- JSON: how many needed (e.g., "3 tokens = 1 item")
  transmog_only BOOLEAN DEFAULT FALSE
);

-- Drop logic at dungeon completion:
-- - 2-3 random items from loot table (scaled to M+ level)
-- - 1-2 tokens of current season
-- - Distribute based on loot specialization
```

**Effort:** 25-35 hours

### **Weekly Vault for M+ (Integration)**

```
M+ Vault Contribution:
- Complete 1+ M+ run: Unlocks M+ vault option
- Best run level determines vault item iLvl
  - M+1-3: +215 iLvl item
  - M+4-7: +225 iLvl item
  - M+8-15: +235+ iLvl item
```

**Effort:** 10-15 hours (already counted in vault system)

**Total M+ Dungeons (Revised): 165-205 hours**

---

## 1.5 Raid Difficulty Scaling (10/25 Player Groups)

**Priority:** ⭐⭐⭐⭐⭐ P1 - High Value  
**Complexity:** ⭐⭐⭐ Medium  
**Effort:** 150-180 hours  
**Dependencies:** Item Upgrade System, Scaling Engine

### **Purpose**
- All raids (WotLK era) available in Normal/Heroic/Mythic
- Scale for 10 and 25 player groups
- Different loot per difficulty
- Proper item level scaling
- Season-dependent item availability

### **Database Schema**

```sql
CREATE TABLE dc_raid_difficulty (
  id INT PRIMARY KEY AUTO_INCREMENT,
  raid_id INT NOT NULL,
  raid_name VARCHAR(100),
  difficulty_id INT,  -- 0=Normal, 1=Heroic, 2=Mythic
  difficulty_name VARCHAR(50),
  
  -- Scaling
  player_count_10 BOOLEAN,
  player_count_25 BOOLEAN,
  creature_health_multiplier FLOAT,
  creature_damage_multiplier FLOAT,
  
  -- Loot
  base_item_ilvl INT,
  loot_table_id INT,
  
  -- Season
  season INT,
  locked_after_season INT,
  
  created_date TIMESTAMP,
  UNIQUE KEY (raid_id, difficulty_id, player_count_10, player_count_25),
  KEY (raid_id)
);

CREATE TABLE dc_raid_loot_tables (
  loot_id INT PRIMARY KEY AUTO_INCREMENT,
  raid_id INT,
  difficulty VARCHAR(50),  -- 'normal', 'heroic', 'mythic'
  player_count VARCHAR(10),  -- '10', '25'
  boss_id INT,
  item_id INT,
  drop_chance FLOAT,
  season INT,
  KEY (raid_id, boss_id)
);
```

### **Scaling Configuration**

```
Normal Difficulty (10/25):
- 10-player: 219 iLvl items
- 25-player: 226 iLvl items
- Creature Health: 1.0x (baseline)
- Creature Damage: 1.0x (baseline)

Heroic Difficulty (10/25):
- 10-player: 232 iLvl items
- 25-player: 245 iLvl items
- Creature Health: 1.15x baseline
- Creature Damage: 1.10x baseline

Mythic Difficulty (10/25):
- 10-player: 245 iLvl items
- 25-player: 258 iLvl items
- Creature Health: 1.30x baseline
- Creature Damage: 1.25x baseline

Scaling per player count:
- 10-man harder per person (higher multiplier)
- 25-man total damage higher but spread across group
```

**Effort:** 50-60 hours

### **Raid Token System**

```sql
CREATE TABLE dc_raid_tokens (
  token_id INT PRIMARY KEY AUTO_INCREMENT,
  raid_id INT,
  token_class VARCHAR(50),  -- 'plate', 'mail', 'leather', 'cloth'
  difficulty VARCHAR(50),
  season INT,
  base_item_id INT,
  exchange_items TEXT,  -- JSON of convertible items
  UNIQUE KEY (raid_id, token_class, difficulty, season)
);

-- Loot specialization for smart loot
CREATE TABLE dc_player_loot_specialization (
  character_guid INT PRIMARY KEY,
  class INT,
  specialization INT,
  armor_type VARCHAR(20),
  last_updated TIMESTAMP
);
```

**Effort:** 30-40 hours

### **Weekly Vault Integration (Raid)**

```
Raid Vault Contribution:
- Kill 1+ boss on any difficulty: Unlocks raid vault option
- Highest difficulty killed determines vault item iLvl
  - Normal: +219 iLvl item
  - Heroic: +232 iLvl item
  - Mythic: +245 iLvl item
```

**Effort:** 10-15 hours (already counted in vault system)

**Total Raid Scaling: 90-115 hours**

---

## 1.6 Dungeon Heroic/Mythic Scaling (Pre-WotLK)

**Priority:** ⭐⭐⭐⭐ P2 - Important  
**Complexity:** ⭐⭐ Low  
**Effort:** 80-100 hours  
**Dependencies:** Item Upgrade System, Scaling Engine

### **Purpose**
- All dungeons from Vanilla, BC, WotLK available in Heroic + Mythic
- Entry-level gearing for players 80-255
- Progression path before raids
- Tokens for dungeon sets

### **Affected Dungeons (WotLK era only)**
- Utgarde Keep
- Utgarde Pinnacle
- The Nexus
- The Oculus
- Gundrak
- Drak'Tharon Keep
- Azjol-Nerub
- Ahn'kahet
- Halls of Stone
- Halls of Lightning
- The Violet Hold
- Culling of Stratholme
- Pit of Saron
- Halls of Reflection
- Trial of the Champion

### **Database Schema**

```sql
CREATE TABLE dc_dungeon_difficulty (
  id INT PRIMARY KEY AUTO_INCREMENT,
  dungeon_id INT NOT NULL,
  dungeon_name VARCHAR(100),
  difficulty VARCHAR(50),  -- 'normal', 'heroic', 'mythic'
  
  -- Scaling
  creature_health_multiplier FLOAT,
  creature_damage_multiplier FLOAT,
  
  -- Loot
  base_item_ilvl INT,
  token_reward_id INT,
  item_reward_count INT,
  
  -- Requirements
  required_player_level INT,
  required_item_level INT,
  
  -- Season
  season INT,
  active BOOLEAN DEFAULT TRUE,
  
  UNIQUE KEY (dungeon_id, difficulty),
  KEY (season)
);

CREATE TABLE dc_dungeon_token_sets (
  token_id INT PRIMARY KEY AUTO_INCREMENT,
  dungeon_id INT,
  difficulty VARCHAR(50),
  token_name VARCHAR(100),
  class VARCHAR(50),  -- Specific class items
  pieces_in_set INT,  -- How many pieces per set
  season INT,
  UNIQUE KEY (dungeon_id, difficulty, class)
);
```

### **Difficulty Configuration**

```
Normal Difficulty:
- Creature Health: 1.0x
- Creature Damage: 1.0x
- Item iLvl: 213

Heroic Difficulty:
- Creature Health: 1.15x
- Creature Damage: 1.10x
- Item iLvl: 226

Mythic Difficulty:
- Creature Health: 1.30x
- Creature Damage: 1.25x
- Item iLvl: 239

Token drops:
- 1 token per group completion
- Can be exchanged for any armor piece from set
```

**Effort:** 40-50 hours

### **Entry Progression Requirements**

```
Level 80-100: Normal difficulty only
Level 100-150: Normal + Heroic allowed
Level 150-200: All difficulties allowed
Level 200+: All difficulties, scaling continues

iLvl Requirements:
- Heroic: Minimum 200 iLvl
- Mythic: Minimum 213 iLvl
- Resets per season if new content released
```

**Effort:** 20-25 hours

**Total Dungeon Scaling: 60-75 hours**

---

## 1.7 Death Count Limit System (M+ Alternative to Timers)

**Priority:** ⭐⭐⭐⭐ P2 - Key Feature  
**Complexity:** ⭐⭐ Low  
**Effort:** 40-50 hours  
**Dependencies:** M+ Dungeon System

### **Purpose**
Replace complex timer mechanics with simpler death count limits

### **Implementation**

```cpp
CREATE TABLE dc_mythic_death_limits (
  dungeon_id INT,
  mythic_level INT,
  death_limit_total INT,
  death_limit_per_phase INT,
  wipe_limit INT,
  
  PRIMARY KEY (dungeon_id, mythic_level)
);

-- Example configuration
-- M+1: 7 total deaths allowed, 3 wipes max
-- M+5: 5 total deaths allowed, 2 wipes max
-- M+10: 3 total deaths allowed, 1 wipe max
-- M+15: 1 total death allowed, instant fail on wipe

class MythicDeathCounter {
public:
  void OnPlayerDeath(uint32 groupId) {
    if (++deathCount >= deathLimit) {
      FailDungeon("Death limit exceeded");
    }
  }
  
  void OnGroupWipe(uint32 groupId) {
    if (++wipeCount >= wipeLimit) {
      FailDungeon("Wipe limit exceeded");
    }
  }
};
```

**Effort:** 25-30 hours

### **Rating Impact**

```
Rating Calculation:
- Base: 50 + (mythicLevel * 10)
- Death penalty: -2 per death
- Wipe penalty: -5 per wipe
- Bonus: +10 if perfect run (0 deaths)
- Example M+5 run:
  - Base: 50 + 50 = 100 rating
  - 2 deaths: -4
  - 1 wipe: -5
  - Final: 91 rating
```

**Effort:** 15-20 hours

**Total Death Limit System: 40-50 hours**

---

## 1.8 Prestige Cosmetic Rewards System

**Priority:** ⭐⭐⭐ P3 - Polish  
**Complexity:** ⭐⭐ Low  
**Effort:** 30-40 hours  
**Dependencies:** Prestige System

### **Custom Transmog Outfits**
```sql
CREATE TABLE dc_prestige_cosmetics (
  cosmetic_id INT PRIMARY KEY AUTO_INCREMENT,
  prestige_level INT NOT NULL,
  cosmetic_type VARCHAR(50),  -- 'armor_set', 'mount', 'pet', 'title'
  cosmetic_name VARCHAR(100),
  icon_id INT,
  description VARCHAR(255),
  item_ids TEXT,  -- JSON array if armor set
  quest_id INT,   -- If needs to be earned
  UNIQUE KEY (prestige_level, cosmetic_type)
);
```

**Effort:** 20-25 hours

### **Prestige Titles**
```
- "Prestige I" through "Prestige X"
- "Eternal Prestige" at max level
- Account-wide prestige display
- Cosmetic color/glow in player titles

SQL:
INSERT INTO char_titles VALUES
(prestige_level, "Prestige {level}", player_name...);
```

**Effort:** 10-15 hours

**Total Prestige Cosmetics: 30-40 hours**

---

# 🖥️ SECTION 1 TOTAL (Server-Only)

| System | Effort Hours | Priority |
|--------|-------------|----------|
| Item Upgrade System | 140-180 | P1 |
| Season System | 45-60 | P1 |
| Prestige System | 55-70 | P2 |
| M+ Dungeons (Revised) | 165-205 | P2 |
| Raid Difficulty Scaling | 90-115 | P1 |
| Dungeon Scaling | 60-75 | P2 |
| Death Count System | 40-50 | P2 |
| Prestige Cosmetics | 30-40 | P3 |
| **TOTAL** | **625-795** | - |

---

# 🖥️ + 🎮 SECTION 2: SERVER + CLIENT IMPLEMENTATIONS

## 2.1 UI Overlay System for M+ & Raid Status

**Priority:** ⭐⭐⭐ P2  
**Complexity:** ⭐⭐⭐ Medium  
**Server Effort:** 30-40 hours | **Client Effort:** 60-80 hours  
**Dependencies:** M+ System, Raid System

### **Server-Side (SendPacket)**

```cpp
// Custom packets for M+ status
class MythicDungeonStatusPacket : public ServerPacket {
public:
  MythicDungeonStatusPacket(uint32 level, int deathCount, int deathLimit) {
    // Build packet with:
    // - Current mythic level
    // - Deaths: X/Y
    // - Wipes: X/Y
    // - Rating change (live update)
  }
};

// Custom packets for Raid difficulty
class RaidDifficultyStatusPacket : public ServerPacket {
public:
  RaidDifficultyStatusPacket(std::string difficulty, int bossesKilled, int totalBosses) {
    // Build packet with raid difficulty info
  }
};
```

**Server Effort:** 20-25 hours

### **Client-Side Addon (Lua)**

```lua
-- WoW Addon: DC-MythicStatus
local frame = CreateFrame("Frame", "MythicStatusFrame", UIParent)
frame:SetSize(300, 150)
frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -100)

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetAllPoints(frame)

-- Listen to custom server packets
frame:RegisterMessage("MYTHIC_STATUS_UPDATE", function(msg, level, deaths, limit)
  text:SetText(string.format("M+%d | Deaths: %d/%d", level, deaths, limit))
end)

-- Raid difficulty display
local raidFrame = CreateFrame("Frame", "RaidStatusFrame", UIParent)
raidFrame:SetSize(300, 100)
raidFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -100)

raidFrame:RegisterMessage("RAID_DIFFICULTY_UPDATE", function(msg, diff, bosses, total)
  -- Display: [Heroic 25] - 5/8 Bosses
end)
```

**Client Effort:** 40-50 hours

### **Features**

✅ Death counter with limit warning  
✅ Wipe counter with visual warning  
✅ Live rating calculation display  
✅ Raid difficulty indicator  
✅ Boss kill tracker  
✅ Season info/countdown  
✅ Vault progress indicator  

**Total Server+Client UI: 70-100 hours**

---

## 2.2 Item Upgrade Transmog UI

**Priority:** ⭐⭐⭐⭐ P2  
**Complexity:** ⭐⭐ Low  
**Server Effort:** 20-30 hours | **Client Effort:** 40-50 hours  
**Dependencies:** Item Upgrade System

### **Server-Side NPC/UI**

```cpp
class ItemUpgradeNPC : public CreatureScript {
public:
  OnGossipHello(Player* player, Creature* creature) {
    // Show "Upgrade Item" option
    // Player selects item to upgrade
    // Server validates and applies upgrade
  }
};
```

**Server Effort:** 15-20 hours

### **Client-Side Addon**

```lua
-- DC-ItemUpgrade Addon
-- Shows upgrade chains for items
-- Displays upgrade cost (currency needed)
-- Previews stat changes

local function ShowUpgradePreview(itemLink)
  -- Parse item from link
  -- Query server for upgrade chain
  -- Display visual progression
  -- Show cost breakdown
end

frame:RegisterForDrag("LeftButton")
frame:SetMovable(true)
-- ... standard addon UI code
```

**Client Effort:** 30-40 hours

**Total Item Upgrade UI: 45-60 hours**

---

## 2.3 Seasonal Cosmetics & Transmog System

**Priority:** ⭐⭐⭐ P3  
**Complexity:** ⭐⭐ Low  
**Server Effort:** 25-35 hours | **Client Effort:** 30-40 hours  
**Dependencies:** Item Upgrade System, Season System

### **Server-Side**

```cpp
class SeasonalTransmogNPC : public CreatureScript {
public:
  OnGossipHello(Player* player, Creature* creature) {
    // Show seasonal cosmetics available
    // Show Prestige cosmetics unlocked
    // Process transmog requests
  }
};
```

**Server Effort:** 20-25 hours

### **Client-Side Addon UI**

```lua
-- Show transmog preview
-- Allow trying on seasonal cosmetics
-- Display prestige rewards

local function PreviewPrestigeCosmetiс(prestigeLevel)
  -- Show unlocked mounts/pets/titles for level
  -- Allow preview of armor sets
end
```

**Client Effort:** 25-35 hours

**Total Seasonal Cosmetics: 50-70 hours**

---

## 2.4 Leaderboard & Rating Display System

**Priority:** ⭐⭐⭐⭐ P2  
**Complexity:** ⭐⭐⭐ Medium  
**Server Effort:** 40-50 hours | **Client Effort:** 60-80 hours  
**Dependencies:** M+ Rating System, Raid Scaling

### **Server-Side Query Engine**

```cpp
class LeaderboardServer {
public:
  // Queries sent to client periodically
  std::vector<LeaderboardEntry> GetTopPlayers(int season, int limit = 100);
  std::vector<LeaderboardEntry> GetRealmLeaderboard(int season, int realmId);
  std::vector<LeaderboardEntry> GetClassLeaderboard(int season, int classId);
  
  LeaderboardEntry GetPlayerRank(uint32 playerGuid, int season);
};

// Packet: Send leaderboard data
class LeaderboardDataPacket : public ServerPacket {
  // Contains: rank, name, rating, class, realm
};
```

**Server Effort:** 30-40 hours

### **Client-Side Addon**

```lua
-- DC-Leaderboards
-- Shows M+ leaderboards
-- Shows Raid kill leaderboards
-- Shows Prestige leaderboards
-- Search for specific player

local function DisplayMythicLeaderboard(season)
  -- Query server for M+ ratings
  -- Display top 100
  -- Allow filtering by realm/class
end

local function SearchPlayer(playerName, season)
  -- Find player rank and stats
  -- Show progression chart
end
```

**Client Effort:** 50-70 hours

**Total Leaderboards: 80-110 hours**

---

# 🖥️ + 🎮 SECTION 2 TOTAL (Server+Client)

| System | Server Hours | Client Hours | Total |
|--------|-------------|------------|-------|
| M+ & Raid Status UI | 20-25 | 40-50 | 60-75 |
| Item Upgrade UI | 15-20 | 30-40 | 45-60 |
| Seasonal Cosmetics | 20-25 | 25-35 | 45-60 |
| Leaderboards | 30-40 | 50-70 | 80-110 |
| **TOTAL** | **85-110** | **145-195** | **230-305** |

---

# 🎮 SECTION 3: CLIENT-ONLY IMPLEMENTATIONS

## 3.1 Enhanced Map Addons

**Priority:** ⭐⭐⭐ P2  
**Complexity:** ⭐⭐ Low  
**Effort:** 80-120 hours  
**Dependencies:** None

### **Features**

✅ Display M+ dungeon locations with difficulty color-coding  
✅ Show seasonal rotation with visual indicators  
✅ Mark prestige cosmetic NPCs  
✅ Display raid entrances with difficulty info  
✅ Group finder integration (find M+ groups)  

### **Proposed Addons**

1. **DC-DungeonFinder Enhanced** (40-50 hours)
   - Show all dungeons with difficulty levels
   - Visual indicators for seasonal dungeons
   - Quick queue options

2. **DC-RaidLocator** (30-40 hours)
   - Show raid entrances on world map
   - Display difficulty availability
   - Track raid lockouts

3. **DC-CosmicMap** (enhancement to DC-MapExtension) (30-40 hours)
   - POI markers for cosmetic/prestige NPCs
   - Seasonal quest objectives
   - Prestige progression tracker

**Total Enhanced Maps: 100-130 hours**

---

## 3.2 Prestige Tracker Addon

**Priority:** ⭐⭐⭐ P3  
**Complexity:** ⭐⭐ Low  
**Effort:** 50-70 hours

### **Features**

✅ Show prestige level & progression to next  
✅ Display current stat bonuses  
✅ Track unlocked cosmetics  
✅ Show reset options & cooldown  
✅ Preview next prestige rewards  

### **Implementation**

```lua
-- DC-PrestigeTracker
local function UpdatePrestigeDisplay()
  -- Show: "Prestige 3/20" with progress bar
  -- Show: "+3% all stats (Prestige 3)"
  -- Show: "Next: Mount at Prestige 4"
  -- Button: "Reset for Prestige"
end
```

**Effort:** 40-50 hours

---

## 3.3 Season Tracker Addon

**Priority:** ⭐⭐⭐ P2  
**Complexity:** ⭐⭐ Low  
**Effort:** 60-80 hours

### **Features**

✅ Show current season info  
✅ Display time remaining  
✅ List available dungeons/raids  
✅ Track progression (quests, achieves)  
✅ Season transition warnings  
✅ Archive access for previous seasons  

### **Implementation**

```lua
-- DC-SeasonTracker
-- Main display
-- Season X of Y
-- Days remaining
-- Available dungeons (4-5 dungeons with icons)
-- Available raids with difficulty
-- Current progress towards achievements
-- Time until next season
```

**Effort:** 50-70 hours

---

## 3.4 Vault Tracker Addon

**Priority:** ⭐⭐⭐⭐ P2  
**Complexity:** ⭐⭐ Low  
**Effort:** 50-70 hours

### **Features**

✅ Show vault completion progress  
✅ Display vault options available  
✅ Track which slot is chosen (pending)  
✅ Calendar integration with reset  
✅ Weekly reset warnings  

### **Implementation**

```lua
-- DC-VaultTracker
-- Show: "Weekly Vault Progress"
-- [X] M+ runs (1/1 completed)
-- [ ] Heroic dungeons (0/2)
-- [X] Raid bosses (3/3 completed)
-- "Vault reward available!"
-- Reward preview
```

**Effort:** 40-60 hours

---

## 3.5 M+ Rating Calculator Addon

**Priority:** ⭐⭐⭐ P3  
**Complexity:** ⭐⭐ Low  
**Effort:** 40-50 hours

### **Features**

✅ Live rating calculation during run  
✅ Death impact visualization  
✅ Predicted final rating  
✅ Historical stats tracking  
✅ Comparison with season average  

### **Implementation**

```lua
-- DC-RatingCalc
-- Real-time display:
-- "M+5 Run: +75 base rating"
-- "Current deaths: 2 (-4 rating)"
-- "Predicted: +71 rating"
-- "Season average: +65"
-- "Your rating: +1845"
```

**Effort:** 30-40 hours

---

# 🎮 SECTION 3 TOTAL (Client-Only)

| Addon | Effort Hours | Priority |
|-------|-------------|----------|
| Enhanced Maps | 100-130 | P2 |
| Prestige Tracker | 40-50 | P3 |
| Season Tracker | 50-70 | P2 |
| Vault Tracker | 40-60 | P2 |
| M+ Rating Calc | 30-40 | P3 |
| **TOTAL** | **260-350** | - |

---

# 📊 GRAND TOTAL SUMMARY

## By Implementation Type

| Category | Hours | % of Total |
|----------|-------|-----------|
| **Server-Only** | 625-795 | 50% |
| **Server+Client** | 230-305 | 18% |
| **Client-Only** | 260-350 | 22% |
| **TOTAL** | **1,115-1,450** | **100%** |

## By Priority Tier

| Priority | Hours | Recommended Order |
|----------|-------|-------------------|
| **P1 (Critical)** | 315-405 | 1st |
| **P2 (High Value)** | 570-750 | 2nd |
| **P3 (Polish)** | 80-120 | 3rd |

## Development Timeline Estimates

**Scenario A: 1 Developer (Part-time, 20 hrs/week)**
- P1 Features: 4-5 months
- P1+P2 Features: 8-10 months
- Complete: 12-15 months

**Scenario B: 2 Developers (Full-time, 80 hrs/week combined)**
- P1 Features: 4-6 weeks
- P1+P2 Features: 10-13 weeks
- Complete: 3-4 months

**Scenario C: 3 Developers (Full-time, 120 hrs/week combined)**
- P1 Features: 3-4 weeks
- P1+P2 Features: 7-8 weeks
- Complete: 2-3 months

---

# 📋 IMPLEMENTATION RECOMMENDATIONS

## Phase 1: Foundation (Weeks 1-8)

**Goal:** Create core systems all other features depend on

- [ ] Item Upgrade System (140-180 hrs)
- [ ] Season System (45-60 hrs)
- [ ] Raid Difficulty Scaling (90-115 hrs)
- [ ] Database schema & configuration

**Deliverables:**
- ✅ Core item upgrade working
- ✅ Seasons can be created/managed
- ✅ Raids playable on 3 difficulties
- ✅ Proper item scaling per content type

**Effort:** ~280-350 hours

---

## Phase 2: M+ & Dungeons (Weeks 9-16)

**Goal:** Implement M+ dungeons and dungeon scaling

- [ ] M+ Dungeons (165-205 hrs)
- [ ] Dungeon Heroic/Mythic Scaling (60-75 hrs)
- [ ] Death Count System (40-50 hrs)
- [ ] Weekly Vault Integration (20-30 hrs)
- [ ] Teleporter NPCs (30-40 hrs)

**Deliverables:**
- ✅ M+ dungeons playable (M+1 to M+15)
- ✅ All dungeons have heroic/mythic
- ✅ Vault system functional
- ✅ Death counting and limits working

**Effort:** ~315-400 hours

---

## Phase 3: Features & Polish (Weeks 17-22)

**Goal:** Add prestige, cosmetics, and UI systems

- [ ] Prestige System (55-70 hrs)
- [ ] Prestige Cosmetics (30-40 hrs)
- [ ] UI Overlays (70-100 hrs)
- [ ] Item Upgrade UI (45-60 hrs)
- [ ] Leaderboards (80-110 hrs)

**Deliverables:**
- ✅ Prestige system functional
- ✅ Player HUD shows M+/Raid status
- ✅ Item upgrades usable
- ✅ Leaderboards live

**Effort:** ~280-380 hours

---

## Phase 4: Client Addons (Weeks 23-28)

**Goal:** Polish with client-side addons

- [ ] Enhanced Maps (100-130 hrs)
- [ ] Trackers (Prestige, Season, Vault) (150-200 hrs)
- [ ] Rating Calculator (30-40 hrs)

**Deliverables:**
- ✅ All information accessible via addons
- ✅ Quality-of-life features
- ✅ Professional appearance

**Effort:** ~280-370 hours

---

## Phase 5: Testing & Balance (Weeks 29-32)

**Goal:** Test and tune all systems

- [ ] Load testing
- [ ] Balance adjustments
- [ ] Bug fixes
- [ ] Documentation

**Deliverables:**
- ✅ All systems stable
- ✅ Difficulty tuned
- ✅ Server performance acceptable

**Effort:** ~100-150 hours

---

# ✅ KEY LEARNINGS IMPLEMENTATION

## Applied from User Feedback

| Learning | Implementation |
|----------|-----------------|
| Avoid core AC modifications | All systems use `dc_` prefix tables, custom scripts separate |
| Item upgrade with scaling | Core system handles all content types |
| Seasons to limit content | Season table controls available dungeons/raids |
| Reduce affix complexity | Only 3-4 affixes, focus on player-felt changes |
| Skip timers, use death count | Death limit per level + wipe count |
| Separate teleporters per season | Seasonal NPC teleporter table |
| Weekly vault integration | Vault completion tracker integrated |
| Tokens + loot | 2-3 items + 1-2 tokens per M+ completion |
| WotLK dungeons scaled | All dungeons support heroic+mythic |
| Prestige system | Full 20-level progression with cosmetics |

---

# 🎯 NEXT STEPS

1. **Review & Approve** this plan with your team
2. **Prioritize** which features to implement first
3. **Assign Developers** to each phase
4. **Create Git Branches** for each major feature
5. **Begin Phase 1** with Item Upgrade System
6. **Weekly Check-ins** on progress and balance

---

**Document Status:** ✅ READY FOR TEAM REVIEW  
**Last Updated:** November 4, 2025
