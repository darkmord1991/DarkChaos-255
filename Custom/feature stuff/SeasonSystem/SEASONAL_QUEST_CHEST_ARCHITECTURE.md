# Seasonal Quest & Chest Reward System - Architecture Document

**Version:** 1.0  
**Status:** Design Phase → Implementation  
**Created:** November 15, 2025  
**Last Updated:** November 15, 2025  

---

## 📋 Executive Summary

This document consolidates the DarkChaos-255 seasonal system with quest/chest-based rewards following WoW retail patterns (Ascension, Remix, Cataclysm timewalking). The system integrates:

- **Seasonal Framework** (existing `SeasonalSystem.cpp/h`)
- **Quest Reward Hooks** (existing `ItemUpgradeTokenHooks.cpp`)
- **Boss/Rare Kill Rewards** (new)
- **Chest-Based Loot** (new - future phase)
- **Database-Driven Scaling** (new)

**Goal:** Single, maintainable addon-style solution that works seamlessly in the background with minimal manual intervention, supporting Mythic+ and PvP seasons in future phases.

---

## 🏗️ Architecture Overview

### System Layers

```
┌─────────────────────────────────────────────────────────────┐
│  PLAYER ENGAGEMENT LAYER                                    │
│  • Quest Completion Hooks                                   │
│  • Boss/Rare Kill Detection                                 │
│  • Chest Item Claiming                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│  SEASONAL INTEGRATION LAYER                                 │
│  • Season Event Callbacks (START, END, RESET)               │
│  • Player Season Transitions                                │
│  • Reward Multiplier Application                            │
│  • Season-Specific Loot Tables                              │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│  REWARD CALCULATION ENGINE                                  │
│  • Token Amount Calculator                                  │
│  • Item Level Scaler                                        │
│  • Difficulty Multipliers                                   │
│  • Weekly/Daily Caps                                        │
│  • Chest Pool Selector                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│  DATA PERSISTENCE LAYER                                     │
│  • dc_seasonal_quest_rewards (World DB)                     │
│  • dc_seasonal_chest_rewards (World DB)                     │
│  • dc_player_seasonal_stats (Char DB)                       │
│  • dc_reward_transactions (Char DB)                         │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| `SeasonalRewardManager` | Central manager for quest/chest rewards | `src/server/scripts/DC/SeasonSystem/` |
| `SeasonalQuestRewards` | PlayerScript hook for quest completion | `src/server/scripts/DC/SeasonSystem/` |
| `SeasonalBossRewards` | UnitScript hook for creature kills | `src/server/scripts/DC/SeasonSystem/` |
| Database Schema | Configuration and transaction tracking | `Custom/Custom feature SQLs/` |
| Commands | Admin interface for setup/testing | `src/server/scripts/DC/SeasonSystem/` |

---

## 📊 Database Design

### World Database Tables

#### 1. `dc_seasonal_quest_rewards` - Quest Reward Configuration

```sql
CREATE TABLE `dc_seasonal_quest_rewards` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `quest_id` INT UNSIGNED NOT NULL,
  `reward_type` TINYINT NOT NULL,           -- 1=Token, 2=Essence, 3=Both
  `base_token_amount` INT UNSIGNED,         -- Base tokens for this quest
  `base_essence_amount` INT UNSIGNED,       -- Base essence (if applicable)
  `min_level` TINYINT UNSIGNED,             -- Quest minimum level
  `quest_difficulty` TINYINT,               -- Difficulty tier (0-5)
  `seasonal_multiplier` FLOAT DEFAULT 1.0,  -- Per-season override
  `is_daily` BOOLEAN DEFAULT FALSE,         -- Daily quest flag
  `is_weekly` BOOLEAN DEFAULT FALSE,        -- Weekly quest flag
  `is_repeatable` BOOLEAN DEFAULT FALSE,    -- Repeatable quest flag
  `enabled` BOOLEAN DEFAULT TRUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_quest` (`season_id`, `quest_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_quest_id` (`quest_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Quest reward configuration per season';
```

**Example Rows:**
```sql
-- Season 1, Normal quest
INSERT INTO dc_seasonal_quest_rewards VALUES 
(NULL, 1, 12345, 1, 15, 0, 60, 2, 1.0, 0, 0, 0, 1, NOW());

-- Season 1, Daily quest (quest ID 20000-29999 range)
INSERT INTO dc_seasonal_quest_rewards VALUES 
(NULL, 1, 25000, 1, 50, 25, 60, 3, 1.0, 1, 0, 1, 1, NOW());

-- Season 1, Weekly quest (quest ID 30000-39999 range)
INSERT INTO dc_seasonal_quest_rewards VALUES 
(NULL, 1, 35000, 3, 100, 50, 60, 4, 1.0, 0, 1, 0, 1, NOW());
```

#### 2. `dc_seasonal_creature_rewards` - Boss/Rare Kill Configuration

```sql
CREATE TABLE `dc_seasonal_creature_rewards` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `creature_id` INT UNSIGNED NOT NULL,
  `reward_type` TINYINT NOT NULL,           -- 1=Token, 2=Essence, 3=Both
  `base_token_amount` INT UNSIGNED,         -- Base tokens for kill
  `base_essence_amount` INT UNSIGNED,       -- Base essence
  `creature_rank` TINYINT,                  -- Boss rank (0=normal, 1=rare, 2=boss, 3=raid)
  `content_type` TINYINT,                   -- 1=Dungeon, 2=Raid, 3=World
  `difficulty_level` TINYINT,               -- Content difficulty
  `seasonal_multiplier` FLOAT DEFAULT 1.0,  -- Per-season override
  `minimum_players` TINYINT DEFAULT 1,      -- Min group size for reward
  `enabled` BOOLEAN DEFAULT TRUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_creature` (`season_id`, `creature_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_creature_id` (`creature_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Boss/rare creature reward configuration per season';
```

**Example Rows:**
```sql
-- Season 1, Dungeon Boss
INSERT INTO dc_seasonal_creature_rewards VALUES 
(NULL, 1, 1234, 3, 50, 10, 2, 1, 2, 1.0, 1, 1, NOW());

-- Season 1, Mythic Raid Boss
INSERT INTO dc_seasonal_creature_rewards VALUES 
(NULL, 1, 5678, 3, 200, 50, 3, 2, 3, 1.0, 20, 1, NOW());

-- Season 1, World Boss
INSERT INTO dc_seasonal_creature_rewards VALUES 
(NULL, 1, 9999, 3, 500, 100, 3, 3, 3, 1.0, 1, 1, NOW());
```

#### 3. `dc_seasonal_chest_rewards` - Chest Loot Configuration

```sql
CREATE TABLE `dc_seasonal_chest_rewards` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `chest_tier` TINYINT NOT NULL,             -- 1=Bronze, 2=Silver, 3=Gold, 4=Legendary
  `item_id` INT UNSIGNED NOT NULL,           -- Item to drop
  `min_drop_ilvl` SMALLINT UNSIGNED,         -- Minimum item level
  `max_drop_ilvl` SMALLINT UNSIGNED,         -- Maximum item level
  `drop_chance` FLOAT NOT NULL,              -- 0.0-1.0 probability
  `weight` INT UNSIGNED DEFAULT 1,           -- Selection weight in loot table
  `armor_class` TINYINT,                     -- Armor type filter (1=Cloth, 2=Leather, 3=Mail, 4=Plate)
  `slot` TINYINT,                            -- Equip slot filter (optional)
  `class_restrictions` VARCHAR(255),         -- Comma-separated class IDs (1,2,3...)
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_season_tier` (`season_id`, `chest_tier`),
  KEY `idx_item_id` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Chest loot pool configuration';
```

**Example Rows:**
```sql
-- Season 1, Gold Chest, Warrior Plate Helm
INSERT INTO dc_seasonal_chest_rewards VALUES 
(NULL, 1, 3, 40000, 230, 245, 0.5, 100, 4, 1, '1', NOW());

-- Season 1, Legendary Chest, Mythic Weapon (all classes)
INSERT INTO dc_seasonal_chest_rewards VALUES 
(NULL, 1, 4, 50000, 258, 258, 1.0, 200, NULL, NULL, NULL, NOW());
```

### Character Database Tables

#### 1. `dc_player_seasonal_stats` - Player Seasonal Tracking

```sql
CREATE TABLE `dc_player_seasonal_stats` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `total_tokens_earned` BIGINT DEFAULT 0,   -- Total tokens this season
  `total_essence_earned` BIGINT DEFAULT 0,  -- Total essence this season
  `quests_completed` INT UNSIGNED DEFAULT 0,
  `bosses_killed` INT UNSIGNED DEFAULT 0,
  `chests_claimed` INT UNSIGNED DEFAULT 0,
  `weekly_tokens_earned` INT UNSIGNED DEFAULT 0,
  `weekly_reset_at` BIGINT,                 -- Unix timestamp of weekly reset
  `last_activity_at` BIGINT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_season` (`player_guid`, `season_id`),
  KEY `idx_season_id` (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player statistics per season';
```

#### 2. `dc_reward_transactions` - Transaction Audit Log

```sql
CREATE TABLE `dc_reward_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `transaction_type` ENUM('quest', 'creature', 'chest', 'manual') NOT NULL,
  `source_id` INT UNSIGNED,                 -- Quest ID or Creature ID
  `source_name` VARCHAR(255),               -- Human-readable source name
  `reward_type` TINYINT,                    -- 1=Token, 2=Essence, 3=Both
  `token_amount` INT UNSIGNED,
  `essence_amount` INT UNSIGNED,
  `multiplier_applied` FLOAT DEFAULT 1.0,
  `transaction_at` BIGINT NOT NULL,         -- Unix timestamp
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`, `season_id`),
  KEY `idx_transaction_at` (`transaction_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Audit trail for all reward transactions';
```

---

## 🔄 Integration with Existing Systems

### SeasonalSystem Integration

The `SeasonalRewardManager` will register with `SeasonalManager` using the existing callback pattern:

```cpp
// Registration in SeasonalRewardManager constructor
SystemRegistration reg;
reg.system_name = "seasonal_rewards";
reg.system_version = "1.0";
reg.priority = 95;  // High priority for reward updates

reg.on_season_event = [this](uint32 season_id, SeasonEventType event_type) {
    OnSeasonEvent(season_id, event_type);
};

reg.on_player_season_change = [this](uint32 player_guid, uint32 old_season_id, uint32 new_season_id) {
    OnPlayerSeasonChange(player_guid, old_season_id, new_season_id);
};

GetSeasonalManager()->RegisterSystem(reg);
```

### Callbacks Triggered

| Event | Action |
|-------|--------|
| `SEASON_EVENT_START` | Load quest/creature rewards from DB, apply multipliers |
| `SEASON_EVENT_END` | Archive player stats, prepare season end notifications |
| `SEASON_EVENT_RESET` | Reset weekly caps, clear transient data |
| Player Season Change | Migrate stats, validate carryover amounts |

### ItemUpgradeTokenHooks Reuse

Instead of duplicating token logic, reuse and centralize in `SeasonalRewardManager`:

**Before (scattered):**
- `ItemUpgradeTokenHooks.cpp` → Direct token addition
- `npc_dungeon_quest_master.cpp` → Quest rewards via NPC

**After (consolidated):**
- `SeasonalRewardManager` → Central hub
- ItemUpgradeTokenHooks still active (for backward compat)
- SeasonalQuestRewards → Extends/overrides with seasonal logic

---

## 💾 Reward Calculation Engine

### Token Amount Calculation

```
Final Token Amount = Base Amount × Difficulty Multiplier × Season Multiplier × Weekly Cap Check

Where:
- Base Amount: From dc_seasonal_quest_rewards.base_token_amount
- Difficulty Multiplier: 1.0x (quest level = player level), scales up for harder content
- Season Multiplier: From dc_seasonal_quest_rewards.seasonal_multiplier (e.g., Season 2 = 1.15x)
- Weekly Cap: Min(calculated amount, remaining weekly cap)
```

### Difficulty Tiers (For Quests)

| Player Level vs Quest | Multiplier | Name |
|----------------------|-----------|------|
| > Quest Level + 10 | 0.0x | Trivial (0 reward) |
| Quest Level + 0 to +10 | 1.0x | Easy |
| Quest Level - 1 to 0 | 1.2x | Normal |
| Quest Level - 2 to -1 | 1.5x | Hard |
| Quest Level - 3+ | 2.0x | Legendary |

### Creature Kill Rewards

| Creature Rank | Content Type | Tokens | Essence | Notes |
|--------------|--------------|--------|---------|-------|
| Normal | Dungeon | 5 | — | Low-value trash |
| Rare | Dungeon | 15 | 3 | Quest objectives |
| Boss | Dungeon | 50 | 10 | Dungeon completion |
| Rare | Raid | 25 | 5 | Raid trash |
| Boss | Raid | 100 | 20 | Raid boss |
| Boss | World | 500 | 100 | World boss (rare event) |

### Weekly/Daily Caps

- **Weekly Token Cap:** 500 tokens (checked on Sunday reset)
- **Daily Token Cap:** None (unlimited if under weekly)
- **Essence:** Uncapped
- **Weekly Reset:** Sunday 00:00 server time

---

## 🎮 Player Flow

### Quest Completion

```
1. Player completes quest
   ↓
2. OnPlayerCompleteQuest() hook fires
   ↓
3. Query dc_seasonal_quest_rewards for this quest_id + current season_id
   ↓
4. If found:
   - Calculate difficulty multiplier (player level vs quest level)
   - Fetch season multiplier from SeasonalManager
   - Calculate: tokens = base × difficulty × season_mult
   - Check weekly cap
   - Cap tokens if needed
   ↓
5. Award tokens (via ItemUpgradeManager or direct currency)
   ↓
6. Log transaction to dc_reward_transactions
   ↓
7. Update dc_player_seasonal_stats.quests_completed ++
   ↓
8. Send notification: "+15 Upgrade Tokens (Quest: Defeat the Dragons)"
   ↓
9. Return
```

### Boss Kill Flow

```
1. Player kills creature with rank > 0 (Rare/Boss/Raid)
   ↓
2. OnUnitDeath() hook fires
   ↓
3. Query dc_seasonal_creature_rewards for this creature_id + season_id
   ↓
4. If found:
   - Fetch reward config
   - Apply season multiplier
   - Calculate tokens and essence
   ↓
5. Award to all group members (split equally or per-person)
   ↓
6. Log transaction for each player
   ↓
7. Update dc_player_seasonal_stats.bosses_killed ++
   ↓
8. Return
```

---

## 📁 File Structure

```
src/server/scripts/DC/SeasonSystem/
├── SeasonalRewardManager.h
├── SeasonalRewardManager.cpp
├── SeasonalQuestRewards.cpp              (PlayerScript)
├── SeasonalBossRewards.cpp               (UnitScript)
├── SeasonalRewardCommands.cpp            (Admin commands)
├── SeasonalRewardLoader.cpp              (Script registration)
└── CMakeLists.txt (update with new files)

Custom/Custom feature SQLs/
├── worlddb/
│   └── dc_seasonal_rewards.sql
│       ├── dc_seasonal_quest_rewards
│       ├── dc_seasonal_creature_rewards
│       └── dc_seasonal_chest_rewards
└── chardb/
    └── dc_seasonal_player_stats.sql
        ├── dc_player_seasonal_stats
        └── dc_reward_transactions
```

---

## ⚙️ Configuration & Expansion

### Adding Quest Rewards for a New Season

```sql
-- For Season 2 (Starting Jan 1, 2026)
INSERT INTO dc_seasonal_quest_rewards (season_id, quest_id, reward_type, base_token_amount, base_essence_amount, seasonal_multiplier)
VALUES
(2, 12345, 1, 15, 0, 1.15),        -- +15% tokens in Season 2
(2, 25000, 3, 50, 25, 1.15),       -- Daily quest
(2, 35000, 3, 100, 50, 1.15);      -- Weekly quest
```

### Adding Creature Rewards

```sql
-- Mythic Raid Boss in Season 2
INSERT INTO dc_seasonal_creature_rewards (season_id, creature_id, reward_type, base_token_amount, base_essence_amount, creature_rank, content_type, seasonal_multiplier)
VALUES
(2, 5678, 3, 230, 60, 3, 2, 1.15);  -- 230 tokens, 60 essence, +15% season multiplier
```

### Season Setup Workflow

1. **Create Season** via `SeasonalManager`:
   ```cpp
   SeasonDefinition season;
   season.season_id = 2;
   season.season_name = "Season 2: Rise of the Titans";
   season.start_timestamp = time(nullptr);
   season.end_timestamp = time(nullptr) + 86400*90;  // 90 days
   GetSeasonalManager()->CreateSeason(season);
   ```

2. **Populate Reward Tables** with SQL inserts

3. **Start Season**:
   ```cpp
   GetSeasonalManager()->StartSeason(2);
   // Triggers SEASON_EVENT_START → loads quest/creature rewards
   ```

4. **Monitor** via commands:
   ```
   .season rewards info 2              // Show all rewards for season 2
   .season rewards player <name>       // Show player's seasonal stats
   ```

---

## 🧪 Testing Strategy

### Unit Tests

- Reward calculation with various difficulty levels
- Weekly cap enforcement
- Season multiplier application
- Database transaction logging

### Integration Tests

- Player completes quest → tokens awarded ✓
- Player kills boss → tokens + essence ✓
- Weekly reset clears cap ✓
- Season change migrates stats ✓

### Load Tests

- 1000+ players earning rewards simultaneously
- Large transaction log queries performance
- Concurrent chest claiming

---

## 🚀 Implementation Roadmap

### Phase 1: Foundation (Current)
- ✅ Analyze existing systems
- **→ Create SeasonalRewardManager**
- **→ Implement database schema**
- **→ Add quest completion hook**

### Phase 2: Boss Rewards
- Implement creature kill hook
- Add raid/dungeon tracking
- Test with various content types

### Phase 3: Chest System
- Create chest item script
- Implement loot table selection
- Add chest claiming UI

### Phase 4: Mythic+ Integration
- Extend for M+ season-specific rewards
- Keystone level scaling
- Affix bonus rewards

### Phase 5: PvP Seasons
- Rating-based reward scaling
- Seasonal PvP titles/mounts
- Bracket-specific loot tables

---

## 📝 Notes & Considerations

### Backward Compatibility

- ItemUpgradeTokenHooks continues to work
- Old quest reward hooks still functional
- Seasonal system layers on top without breaking changes

### Performance Optimization

- Cache active season data in memory
- Pre-load reward configs on season start
- Use prepared statements for all DB queries
- Implement weekly stats archiving (old data cleanup)

### Future Extensibility

- Add "Seasonal Events" (bonus multipliers on weekends)
- Cross-system synergies (HLBG rating → reward boost)
- Guild-wide multipliers
- Community-wide challenge milestones

---

## 📚 Related Documentation

- `Custom/feature stuff/SeasonSystem/seasonsystem evaluation.txt` - Original evaluation
- `src/server/scripts/DC/Seasons/SeasonalSystem.h` - Core seasonal API
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeTokenHooks.cpp` - Token system
- `src/server/scripts/DC/Seasons/HLBGSeasonalParticipant.cpp` - Integration example

---

**End of Document**
