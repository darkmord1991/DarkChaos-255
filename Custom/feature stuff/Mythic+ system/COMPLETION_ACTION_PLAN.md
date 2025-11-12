# Mythic+ System - Completion Action Plan

**Purpose:** Step-by-step guide to complete the Mythic+ system  
**Current Status:** 60% Complete (Core mechanics work, persistence layer missing)  
**Target:** Functional MVP in 130-180 hours

---

## 🎯 Goal: Minimum Viable Product (MVP)

**MVP Definition:**
- Players can run M+ dungeons with keystones
- Affixes apply correctly
- Deaths are tracked and affect rewards
- Vault unlocks based on completion (1/4/8)
- Tokens are awarded on completion
- Data persists between sessions

**What MVP Excludes:**
- Seasonal rotation (use Season 1 indefinitely)
- Rating/Leaderboards (nice-to-have)
- Achievements (nice-to-have)
- Weekly automated resets (manual for now)

---

## 📅 Phase 1: Database Foundation (Week 1-2)

**Goal:** Create persistent storage for all M+ data  
**Effort:** 40-60 hours  
**Priority:** ⭐⭐⭐⭐⭐ CRITICAL

### Task 1.1: Create World Database Tables (15-20 hours)

**File:** `data/sql/custom/world/2025_11_12_00_dc_mythic_tables_world.sql`

```sql
-- ============================================================================
-- Mythic+ System - World Database Tables
-- ============================================================================

-- Seasons configuration
CREATE TABLE IF NOT EXISTS `dc_mythic_seasons` (
  `season_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_name` VARCHAR(100) NOT NULL,
  `season_short_name` VARCHAR(20) NOT NULL,
  `start_timestamp` INT UNSIGNED NOT NULL,
  `end_timestamp` INT UNSIGNED NOT NULL,
  `is_active` TINYINT(1) DEFAULT 0,
  `max_keystone_level` TINYINT UNSIGNED DEFAULT 10,
  `vault_enabled` TINYINT(1) DEFAULT 1,
  `affix_rotation_weeks` TINYINT UNSIGNED DEFAULT 12,
  PRIMARY KEY (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Mythic+ seasons configuration';

-- Dungeon configuration per season
CREATE TABLE IF NOT EXISTS `dc_mythic_dungeons_config` (
  `config_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `map_id` SMALLINT UNSIGNED NOT NULL,
  `dungeon_name` VARCHAR(100) NOT NULL,
  `expansion` VARCHAR(20) NOT NULL DEFAULT 'WotLK',
  `is_active` TINYINT(1) DEFAULT 1,
  `mythic0_hp_multiplier` FLOAT DEFAULT 1.8,
  `mythic0_damage_multiplier` FLOAT DEFAULT 1.8,
  `mythic_plus_hp_base` FLOAT DEFAULT 2.0,
  `mythic_plus_damage_base` FLOAT DEFAULT 2.0,
  `mythic_plus_scaling_per_level` FLOAT DEFAULT 0.15,
  `boss_count` TINYINT UNSIGNED DEFAULT 4,
  `required_kills_for_completion` TINYINT UNSIGNED DEFAULT 4,
  `base_token_reward` SMALLINT UNSIGNED DEFAULT 50,
  `token_scaling_per_level` SMALLINT UNSIGNED DEFAULT 10,
  `font_of_power_gameobject_id` INT UNSIGNED DEFAULT 0,
  PRIMARY KEY (`config_id`),
  UNIQUE KEY `idx_season_map` (`season_id`, `map_id`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Mythic+ dungeon configurations';

-- Affix definitions
CREATE TABLE IF NOT EXISTS `dc_mythic_affixes` (
  `affix_id` INT UNSIGNED NOT NULL,
  `affix_name` VARCHAR(50) NOT NULL,
  `affix_description` VARCHAR(255) NOT NULL,
  `affix_type` VARCHAR(20) NOT NULL DEFAULT 'boss',
  `min_keystone_level` TINYINT UNSIGNED DEFAULT 2,
  `is_active` TINYINT(1) DEFAULT 1,
  `spell_id` INT UNSIGNED DEFAULT 0,
  `hp_modifier_percent` FLOAT DEFAULT 0.0,
  `damage_modifier_percent` FLOAT DEFAULT 0.0,
  `special_mechanic` VARCHAR(100) DEFAULT '',
  PRIMARY KEY (`affix_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Mythic+ affix definitions';

-- Affix rotation schedule
CREATE TABLE IF NOT EXISTS `dc_mythic_affix_rotation` (
  `rotation_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `week_number` TINYINT UNSIGNED NOT NULL,
  `tier1_affix_id` INT UNSIGNED NOT NULL,
  `tier2_affix_id` INT UNSIGNED DEFAULT 0,
  `tier3_affix_id` INT UNSIGNED DEFAULT 0,
  `start_timestamp` INT UNSIGNED NOT NULL,
  `end_timestamp` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`rotation_id`),
  UNIQUE KEY `idx_season_week` (`season_id`, `week_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Weekly affix rotation schedule';

-- Vault reward tiers
CREATE TABLE IF NOT EXISTS `dc_mythic_vault_rewards` (
  `reward_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `keystone_level` TINYINT UNSIGNED NOT NULL,
  `slot_number` TINYINT UNSIGNED NOT NULL,
  `token_reward_min` SMALLINT UNSIGNED DEFAULT 0,
  `token_reward_max` SMALLINT UNSIGNED DEFAULT 0,
  `item_level_reward` SMALLINT UNSIGNED DEFAULT 0,
  PRIMARY KEY (`reward_id`),
  UNIQUE KEY `idx_season_level_slot` (`season_id`, `keystone_level`, `slot_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Vault reward tiers';
```

**Checklist:**
- [ ] Create file in `data/sql/custom/world/`
- [ ] Add all 5 tables
- [ ] Test SQL syntax
- [ ] Apply to test server
- [ ] Verify tables created

---

### Task 1.2: Create Character Database Tables (15-20 hours)

**File:** `data/sql/custom/characters/2025_11_12_00_dc_mythic_tables_characters.sql`

```sql
-- ============================================================================
-- Mythic+ System - Characters Database Tables
-- ============================================================================

-- Player keystones
CREATE TABLE IF NOT EXISTS `dc_mythic_keystones` (
  `guid` INT UNSIGNED NOT NULL,
  `keystone_item_entry` INT UNSIGNED NOT NULL,
  `dungeon_map_id` SMALLINT UNSIGNED NOT NULL,
  `keystone_level` TINYINT UNSIGNED NOT NULL,
  `affixes` VARCHAR(100) DEFAULT '',
  `created_timestamp` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`guid`),
  KEY `idx_keystone_level` (`keystone_level`),
  KEY `idx_dungeon` (`dungeon_map_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player Mythic+ keystones';

-- Player rating per season
CREATE TABLE IF NOT EXISTS `dc_mythic_player_rating` (
  `guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `rating` INT UNSIGNED DEFAULT 0,
  `best_run_keystone_level` TINYINT UNSIGNED DEFAULT 0,
  `total_runs` INT UNSIGNED DEFAULT 0,
  `dungeons_completed` TINYINT UNSIGNED DEFAULT 0,
  `updated_timestamp` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`guid`, `season_id`),
  KEY `idx_rating` (`season_id`, `rating` DESC),
  KEY `idx_updated` (`updated_timestamp` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player M+ ratings';

-- Vault progress tracking
CREATE TABLE IF NOT EXISTS `dc_mythic_vault_progress` (
  `guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `week_number` SMALLINT UNSIGNED NOT NULL,
  `dungeons_completed` TINYINT UNSIGNED DEFAULT 0,
  `highest_keystone_level` TINYINT UNSIGNED DEFAULT 0,
  `slot1_unlocked` TINYINT(1) DEFAULT 0,
  `slot2_unlocked` TINYINT(1) DEFAULT 0,
  `slot3_unlocked` TINYINT(1) DEFAULT 0,
  `slot1_claimed` TINYINT(1) DEFAULT 0,
  `slot2_claimed` TINYINT(1) DEFAULT 0,
  `slot3_claimed` TINYINT(1) DEFAULT 0,
  `reset_timestamp` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`guid`, `season_id`, `week_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Weekly vault progress';

-- Run history
CREATE TABLE IF NOT EXISTS `dc_mythic_run_history` (
  `run_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `dungeon_map_id` SMALLINT UNSIGNED NOT NULL,
  `keystone_level` TINYINT UNSIGNED NOT NULL,
  `affixes` VARCHAR(100) DEFAULT '',
  `completion_timestamp` INT UNSIGNED NOT NULL,
  `total_deaths` TINYINT UNSIGNED DEFAULT 0,
  `elapsed_time_seconds` INT UNSIGNED DEFAULT 0,
  `rating_gained` SMALLINT DEFAULT 0,
  `tokens_awarded` SMALLINT UNSIGNED DEFAULT 0,
  `upgrade_result` TINYINT DEFAULT 0 COMMENT '-1=destroyed, 0=same, 1=+1, 2=+2',
  `completed_successfully` TINYINT(1) DEFAULT 0,
  PRIMARY KEY (`run_id`),
  KEY `idx_player_season` (`guid`, `season_id`),
  KEY `idx_completion` (`completion_timestamp` DESC),
  KEY `idx_dungeon` (`dungeon_map_id`, `keystone_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='M+ run history';

-- Achievement progress
CREATE TABLE IF NOT EXISTS `dc_mythic_achievement_progress` (
  `guid` INT UNSIGNED NOT NULL,
  `achievement_id` INT UNSIGNED NOT NULL,
  `progress` INT UNSIGNED DEFAULT 0,
  `completed` TINYINT(1) DEFAULT 0,
  `completion_timestamp` INT UNSIGNED DEFAULT 0,
  PRIMARY KEY (`guid`, `achievement_id`),
  KEY `idx_completed` (`completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='M+ achievement progress';
```

**Checklist:**
- [ ] Create file in `data/sql/custom/characters/`
- [ ] Add all 5 tables
- [ ] Test SQL syntax
- [ ] Apply to test server
- [ ] Verify tables created

---

### Task 1.3: Populate Initial Data (10-20 hours)

**File:** `data/sql/custom/world/2025_11_12_01_dc_mythic_initial_data.sql`

```sql
-- ============================================================================
-- Mythic+ System - Initial Data Population
-- ============================================================================

-- Season 1 Configuration
INSERT INTO `dc_mythic_seasons` 
  (`season_id`, `season_name`, `season_short_name`, `start_timestamp`, `end_timestamp`, 
   `is_active`, `max_keystone_level`, `vault_enabled`, `affix_rotation_weeks`)
VALUES
  (1, 'Season 1: The Frozen Wastes', 'S1', UNIX_TIMESTAMP('2025-11-12'), UNIX_TIMESTAMP('2026-02-12'), 
   1, 10, 1, 12);

-- WotLK Dungeons for Season 1 (8 dungeons)
INSERT INTO `dc_mythic_dungeons_config`
  (`season_id`, `map_id`, `dungeon_name`, `expansion`, `is_active`, `boss_count`, 
   `required_kills_for_completion`, `base_token_reward`, `font_of_power_gameobject_id`)
VALUES
  (1, 575, 'Utgarde Pinnacle', 'WotLK', 1, 4, 4, 50, 700001),
  (1, 602, 'Halls of Lightning', 'WotLK', 1, 4, 4, 50, 700002),
  (1, 604, 'Gundrak', 'WotLK', 1, 4, 4, 50, 700003),
  (1, 599, 'Halls of Stone', 'WotLK', 1, 4, 4, 50, 700004),
  (1, 542, 'The Blood Furnace', 'TBC', 1, 3, 3, 50, 700005),
  (1, 547, 'The Slave Pens', 'TBC', 1, 3, 3, 50, 700006),
  (1, 90, 'Gnomeregan', 'Classic', 1, 5, 5, 50, 700007),
  (1, 230, 'Blackrock Depths', 'Classic', 1, 6, 6, 50, 700008);

-- Affix Definitions
INSERT INTO `dc_mythic_affixes`
  (`affix_id`, `affix_name`, `affix_description`, `affix_type`, `min_keystone_level`, 
   `hp_modifier_percent`, `damage_modifier_percent`, `special_mechanic`)
VALUES
  (1, 'Tyrannical', 'Bosses have 40% more health and deal 15% more damage', 'boss', 2, 40.0, 15.0, ''),
  (2, 'Fortified', 'Non-boss enemies have 20% more health and deal 30% more damage', 'trash', 2, 20.0, 30.0, ''),
  (3, 'Bolstering', 'When non-boss enemies die, they empower nearby allies', 'trash', 4, 20.0, 20.0, 'stacking_buff'),
  (4, 'Raging', 'Non-boss enemies enrage at 30% health, dealing 50% more damage', 'trash', 4, 0.0, 50.0, 'enrage_at_30_percent'),
  (5, 'Sanguine', 'When slain, non-boss enemies leave behind pools of blood', 'trash', 7, 0.0, 0.0, 'blood_pools'),
  (6, 'Necrotic', 'Enemies apply stacking healing reduction on melee attacks', 'debuff', 7, 0.0, 0.0, 'healing_reduction'),
  (7, 'Volcanic', 'Volcanic plumes erupt periodically from the ground', 'environmental', 7, 0.0, 0.0, 'volcanic_plumes'),
  (8, 'Grievous', 'Players below 90% health suffer grievous wounds', 'debuff', 7, 0.0, 0.0, 'grievous_dot');

-- Affix Rotation for Season 1 (12 weeks)
INSERT INTO `dc_mythic_affix_rotation`
  (`season_id`, `week_number`, `tier1_affix_id`, `tier2_affix_id`, `tier3_affix_id`, 
   `start_timestamp`, `end_timestamp`)
VALUES
  (1, 1, 1, 3, 5, UNIX_TIMESTAMP('2025-11-12'), UNIX_TIMESTAMP('2025-11-19')),
  (1, 2, 2, 4, 6, UNIX_TIMESTAMP('2025-11-19'), UNIX_TIMESTAMP('2025-11-26')),
  (1, 3, 1, 3, 7, UNIX_TIMESTAMP('2025-11-26'), UNIX_TIMESTAMP('2025-12-03')),
  (1, 4, 2, 4, 8, UNIX_TIMESTAMP('2025-12-03'), UNIX_TIMESTAMP('2025-12-10')),
  (1, 5, 1, 3, 6, UNIX_TIMESTAMP('2025-12-10'), UNIX_TIMESTAMP('2025-12-17')),
  (1, 6, 2, 4, 5, UNIX_TIMESTAMP('2025-12-17'), UNIX_TIMESTAMP('2025-12-24')),
  (1, 7, 1, 3, 8, UNIX_TIMESTAMP('2025-12-24'), UNIX_TIMESTAMP('2025-12-31')),
  (1, 8, 2, 4, 7, UNIX_TIMESTAMP('2025-12-31'), UNIX_TIMESTAMP('2026-01-07')),
  (1, 9, 1, 3, 5, UNIX_TIMESTAMP('2026-01-07'), UNIX_TIMESTAMP('2026-01-14')),
  (1, 10, 2, 4, 6, UNIX_TIMESTAMP('2026-01-14'), UNIX_TIMESTAMP('2026-01-21')),
  (1, 11, 1, 3, 7, UNIX_TIMESTAMP('2026-01-21'), UNIX_TIMESTAMP('2026-01-28')),
  (1, 12, 2, 4, 8, UNIX_TIMESTAMP('2026-01-28'), UNIX_TIMESTAMP('2026-02-04'));

-- Vault Reward Tiers (Tokens per slot per keystone level)
INSERT INTO `dc_mythic_vault_rewards`
  (`season_id`, `keystone_level`, `slot_number`, `token_reward_min`, `token_reward_max`, `item_level_reward`)
VALUES
  -- Slot 1 rewards (1 dungeon)
  (1, 2, 1, 50, 75, 219),
  (1, 5, 1, 100, 150, 226),
  (1, 10, 1, 200, 300, 239),
  -- Slot 2 rewards (4 dungeons)
  (1, 2, 2, 100, 150, 219),
  (1, 5, 2, 200, 300, 226),
  (1, 10, 2, 400, 600, 239),
  -- Slot 3 rewards (8 dungeons)
  (1, 2, 3, 150, 225, 226),
  (1, 5, 3, 300, 450, 232),
  (1, 10, 3, 600, 900, 245);
```

**Checklist:**
- [ ] Create initial data file
- [ ] Populate Season 1
- [ ] Add 8 dungeons
- [ ] Add 8 affixes
- [ ] Add 12-week rotation
- [ ] Add vault rewards
- [ ] Apply to test server
- [ ] Verify data exists

---

### Task 1.4: Update Manager to Load from Database (5-10 hours)

**File to modify:** `src/server/scripts/DC/DungeonEnhancement/Core/DungeonEnhancementManager.cpp`

**Add methods:**
```cpp
void DungeonEnhancementManager::LoadSeasonData()
{
    QueryResult result = WorldDatabase.Query("SELECT * FROM dc_mythic_seasons WHERE is_active = 1");
    if (result)
    {
        Field* fields = result->Fetch();
        // Parse and cache season data
    }
}

void DungeonEnhancementManager::LoadDungeonConfigs()
{
    QueryResult result = WorldDatabase.Query(
        "SELECT * FROM dc_mythic_dungeons_config WHERE is_active = 1"
    );
    // Parse and cache configs
}

void DungeonEnhancementManager::LoadAffixData()
{
    QueryResult result = WorldDatabase.Query("SELECT * FROM dc_mythic_affixes WHERE is_active = 1");
    // Parse and cache affixes
}

void DungeonEnhancementManager::LoadAffixRotations()
{
    QueryResult result = WorldDatabase.Query(
        "SELECT * FROM dc_mythic_affix_rotation WHERE season_id = ? ORDER BY week_number",
        _currentSeason->seasonId
    );
    // Parse and cache rotations
}
```

**Checklist:**
- [ ] Implement LoadSeasonData()
- [ ] Implement LoadDungeonConfigs()
- [ ] Implement LoadAffixData()
- [ ] Implement LoadAffixRotations()
- [ ] Call from Initialize()
- [ ] Test loading on server start
- [ ] Verify caching works

---

## 📅 Phase 2: Complete Vault System (Week 3-4)

**Goal:** Players can unlock and claim vault rewards  
**Effort:** 50-70 hours  
**Priority:** ⭐⭐⭐⭐⭐ CRITICAL

### Task 2.1: Vault Progress Tracking (20-30 hours)

**File to enhance:** `go_mythic_plus_great_vault.cpp`

**Add logic:**
```cpp
bool OnGossipHello(Player* player, GameObject* /*go*/) override
{
    // 1. Load player's vault progress
    uint32 guid = player->GetGUID().GetCounter();
    uint32 seasonId = sDungeonEnhancementMgr->GetCurrentSeason()->seasonId;
    uint32 weekNumber = GetCurrentWeekNumber();
    
    QueryResult result = CharacterDatabase.Query(
        "SELECT dungeons_completed, highest_keystone_level, "
        "slot1_unlocked, slot2_unlocked, slot3_unlocked, "
        "slot1_claimed, slot2_claimed, slot3_claimed "
        "FROM dc_mythic_vault_progress "
        "WHERE guid = %u AND season_id = %u AND week_number = %u",
        guid, seasonId, weekNumber
    );
    
    VaultProgressData progress;
    if (result)
    {
        // Parse existing progress
    }
    else
    {
        // No progress yet
        progress.dungeonsCompleted = 0;
    }
    
    // 2. Display vault status
    player->ADD_GOSSIP_ITEM(
        GOSSIP_ICON_CHAT,
        StringFormat("Dungeons Completed: %u/8", progress.dungeonsCompleted),
        SENDER_MAIN,
        GOSSIP_ACTION_VAULT_INFO
    );
    
    // 3. Show unlocked slots
    if (progress.slot1_unlocked && !progress.slot1_claimed)
    {
        player->ADD_GOSSIP_ITEM(
            GOSSIP_ICON_VENDOR,
            "Claim Slot 1 Reward (1 dungeon)",
            SENDER_MAIN,
            GOSSIP_ACTION_CLAIM_SLOT_1
        );
    }
    
    // Similar for slot 2 and 3
    
    player->SEND_GOSSIP_MENU(1, go->GetGUID());
    return true;
}
```

**Checklist:**
- [ ] Load vault progress from database
- [ ] Display completion status
- [ ] Show unlocked slots
- [ ] Allow claiming unclaimed slots
- [ ] Prevent double-claiming
- [ ] Test with 1/4/8 completions

---

### Task 2.2: Update Progress on Completion (15-20 hours)

**File to modify:** `MythicRunTracker.cpp`

**Add to AwardCompletionRewards():**
```cpp
void MythicRunTracker::AwardCompletionRewards(Map* map, int8 upgradeLevel)
{
    // ... existing token/loot code ...
    
    // Update vault progress for each participant
    for (auto guid : GetParticipants(instanceId))
    {
        Player* player = GetPlayerByGUID(guid);
        if (!player)
            continue;
            
        UpdateVaultProgress(player, keystoneLevel);
    }
}

void MythicRunTracker::UpdateVaultProgress(Player* player, uint8 keystoneLevel)
{
    uint32 guid = player->GetGUID().GetCounter();
    uint32 seasonId = sDungeonEnhancementMgr->GetCurrentSeason()->seasonId;
    uint32 weekNumber = GetCurrentWeekNumber();
    
    // Increment dungeons completed
    CharacterDatabase.Execute(
        "INSERT INTO dc_mythic_vault_progress "
        "(guid, season_id, week_number, dungeons_completed, highest_keystone_level, reset_timestamp) "
        "VALUES (%u, %u, %u, 1, %u, UNIX_TIMESTAMP()) "
        "ON DUPLICATE KEY UPDATE "
        "dungeons_completed = dungeons_completed + 1, "
        "highest_keystone_level = GREATEST(highest_keystone_level, %u)",
        guid, seasonId, weekNumber, keystoneLevel, keystoneLevel
    );
    
    // Check for slot unlocks
    QueryResult result = CharacterDatabase.Query(
        "SELECT dungeons_completed FROM dc_mythic_vault_progress "
        "WHERE guid = %u AND season_id = %u AND week_number = %u",
        guid, seasonId, weekNumber
    );
    
    if (result)
    {
        uint8 completed = result->Fetch()[0].Get<uint8>();
        
        // Unlock slots based on completion
        if (completed >= 1)
        {
            CharacterDatabase.Execute(
                "UPDATE dc_mythic_vault_progress SET slot1_unlocked = 1 "
                "WHERE guid = %u AND season_id = %u AND week_number = %u",
                guid, seasonId, weekNumber
            );
        }
        
        if (completed >= 4)
        {
            CharacterDatabase.Execute(
                "UPDATE dc_mythic_vault_progress SET slot2_unlocked = 1 "
                "WHERE guid = %u AND season_id = %u AND week_number = %u",
                guid, seasonId, weekNumber
            );
        }
        
        if (completed >= 8)
        {
            CharacterDatabase.Execute(
                "UPDATE dc_mythic_vault_progress SET slot3_unlocked = 1 "
                "WHERE guid = %u AND season_id = %u AND week_number = %u",
                guid, seasonId, weekNumber
            );
        }
        
        // Notify player
        player->GetSession()->SendAreaTriggerMessage(
            "Vault Progress: %u/8 dungeons completed this week!", completed
        );
    }
}
```

**Checklist:**
- [ ] Update progress on completion
- [ ] Track highest keystone level
- [ ] Unlock slot 1 at 1 dungeon
- [ ] Unlock slot 2 at 4 dungeons
- [ ] Unlock slot 3 at 8 dungeons
- [ ] Notify player of unlocks

---

### Task 2.3: Reward Calculation & Distribution (15-20 hours)

**Add to go_mythic_plus_great_vault.cpp:**

```cpp
bool OnGossipSelect(Player* player, GameObject* go, uint32 sender, uint32 action) override
{
    if (action == GOSSIP_ACTION_CLAIM_SLOT_1 || 
        action == GOSSIP_ACTION_CLAIM_SLOT_2 || 
        action == GOSSIP_ACTION_CLAIM_SLOT_3)
    {
        uint8 slotNumber = (action == GOSSIP_ACTION_CLAIM_SLOT_1) ? 1 :
                          (action == GOSSIP_ACTION_CLAIM_SLOT_2) ? 2 : 3;
        
        ClaimVaultReward(player, slotNumber);
    }
    
    player->CLOSE_GOSSIP_MENU();
    return true;
}

void ClaimVaultReward(Player* player, uint8 slotNumber)
{
    uint32 guid = player->GetGUID().GetCounter();
    uint32 seasonId = sDungeonEnhancementMgr->GetCurrentSeason()->seasonId;
    uint32 weekNumber = GetCurrentWeekNumber();
    
    // Load vault progress
    QueryResult progress = CharacterDatabase.Query(
        "SELECT highest_keystone_level, slot%u_claimed "
        "FROM dc_mythic_vault_progress "
        "WHERE guid = %u AND season_id = %u AND week_number = %u",
        slotNumber, guid, seasonId, weekNumber
    );
    
    if (!progress)
    {
        player->GetSession()->SendNotification("No vault progress found!");
        return;
    }
    
    uint8 highestLevel = progress->Fetch()[0].Get<uint8>();
    bool claimed = progress->Fetch()[1].Get<bool>();
    
    if (claimed)
    {
        player->GetSession()->SendNotification("You already claimed this slot!");
        return;
    }
    
    // Get reward tier
    QueryResult reward = WorldDatabase.Query(
        "SELECT token_reward_min, token_reward_max, item_level_reward "
        "FROM dc_mythic_vault_rewards "
        "WHERE season_id = %u AND keystone_level <= %u AND slot_number = %u "
        "ORDER BY keystone_level DESC LIMIT 1",
        seasonId, highestLevel, slotNumber
    );
    
    if (!reward)
    {
        player->GetSession()->SendNotification("No rewards configured!");
        return;
    }
    
    uint16 tokenMin = reward->Fetch()[0].Get<uint16>();
    uint16 tokenMax = reward->Fetch()[1].Get<uint16>();
    uint16 itemLevel = reward->Fetch()[2].Get<uint16>();
    
    // Random token amount
    uint16 tokenAmount = urand(tokenMin, tokenMax);
    
    // Award tokens
    sDungeonEnhancementMgr->AwardDungeonTokens(player, tokenAmount);
    
    // Mark as claimed
    CharacterDatabase.Execute(
        "UPDATE dc_mythic_vault_progress SET slot%u_claimed = 1 "
        "WHERE guid = %u AND season_id = %u AND week_number = %u",
        slotNumber, guid, seasonId, weekNumber
    );
    
    // Notify
    player->GetSession()->SendNotification(
        "Vault Reward: %u Mythic Dungeon Tokens (iLvl %u tier)",
        tokenAmount, itemLevel
    );
    
    LOG_INFO(LogCategory::VAULT, "Player %s claimed vault slot %u: %u tokens",
        player->GetName().c_str(), slotNumber, tokenAmount);
}
```

**Checklist:**
- [ ] Calculate reward based on highest keystone
- [ ] Award tokens from reward table
- [ ] Mark slot as claimed
- [ ] Prevent double claiming
- [ ] Notify player
- [ ] Log reward claims

---

## 📅 Phase 3: Token Distribution System (Week 5-6)

**Goal:** Players receive tokens on M+ completion  
**Effort:** 40-50 hours  
**Priority:** ⭐⭐⭐⭐ HIGH

### Task 3.1: Token Award Calculation (15-20 hours)

**Enhance MythicRunTracker::AwardCompletionRewards():**

```cpp
void MythicRunTracker::AwardCompletionRewards(Map* map, int8 upgradeLevel)
{
    MythicRunData* runData = GetRunData(map->GetInstanceId());
    if (!runData)
        return;
    
    uint8 keystoneLevel = runData->keystoneLevel;
    uint8 totalDeaths = runData->totalDeaths;
    uint16 mapId = runData->mapId;
    
    // Get token reward configuration
    DungeonConfig* config = sDungeonEnhancementMgr->GetDungeonConfig(mapId);
    if (!config)
        return;
    
    // Calculate base tokens
    uint16 baseTokens = config->baseTokenReward;
    uint16 scalingTokens = (keystoneLevel - 2) * config->tokenScalingPerLevel;
    uint16 totalTokens = baseTokens + scalingTokens;
    
    // Apply death penalty
    if (totalDeaths >= MAX_DEATHS_BEFORE_PENALTY)
    {
        totalTokens = static_cast<uint16>(totalTokens * DEATH_PENALTY_TOKEN_MULTIPLIER);
    }
    
    // Award to all participants
    for (auto guid : runData->participantGUIDs)
    {
        Player* player = GetPlayerByGUID(guid);
        if (!player)
            continue;
        
        sDungeonEnhancementMgr->AwardDungeonTokens(player, totalTokens);
        
        // Notify
        player->GetSession()->SendAreaTriggerMessage(
            "Mythic+ Complete! Earned %u Mythic Dungeon Tokens (M+%u)",
            totalTokens, keystoneLevel
        );
        
        // Update vault progress
        UpdateVaultProgress(player, keystoneLevel);
        
        // Log
        LOG_INFO(LogCategory::MYTHIC_PLUS, 
            "Player %s earned %u tokens from M+%u (deaths: %u)",
            player->GetName().c_str(), totalTokens, keystoneLevel, totalDeaths);
    }
}
```

**Checklist:**
- [ ] Calculate base tokens
- [ ] Add keystone level scaling
- [ ] Apply death penalty (15+)
- [ ] Award to all participants
- [ ] Notify players
- [ ] Log token awards

---

### Task 3.2: Implement Token Vendor NPC (20-25 hours)

**Create file:** `NPCs/npc_mythic_token_vendor.cpp`

```cpp
class npc_mythic_token_vendor : public CreatureScript
{
public:
    npc_mythic_token_vendor() : CreatureScript("npc_mythic_token_vendor") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Show token balance
        uint32 tokens = GetPlayerTokenCount(player);
        
        player->ADD_GOSSIP_ITEM(
            GOSSIP_ICON_CHAT,
            StringFormat("Your Tokens: %u", tokens),
            SENDER_MAIN,
            GOSSIP_ACTION_VENDOR_INFO
        );
        
        // Show vendor options
        player->ADD_GOSSIP_ITEM(
            GOSSIP_ICON_VENDOR,
            "Browse Mythic Dungeon Gear",
            SENDER_MAIN,
            GOSSIP_ACTION_VENDOR_BROWSE
        );
        
        player->ADD_GOSSIP_ITEM(
            GOSSIP_ICON_TALK,
            "About Token Exchange",
            SENDER_MAIN,
            GOSSIP_ACTION_INFO
        );
        
        player->SEND_GOSSIP_MENU(1, creature->GetGUID());
        return true;
    }
    
    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        if (action == GOSSIP_ACTION_VENDOR_BROWSE)
        {
            // Open vendor window with token-based items
            player->GetSession()->SendListInventory(creature->GetGUID());
        }
        else if (action == GOSSIP_ACTION_INFO)
        {
            // Show info about tokens
            player->ADD_GOSSIP_ITEM(
                GOSSIP_ICON_CHAT,
                "Tokens are earned by completing Mythic+ dungeons.",
                SENDER_MAIN,
                GOSSIP_ACTION_BACK
            );
            player->ADD_GOSSIP_ITEM(
                GOSSIP_ICON_CHAT,
                "Higher keystone levels award more tokens.",
                SENDER_MAIN,
                GOSSIP_ACTION_BACK
            );
            player->ADD_GOSSIP_ITEM(
                GOSSIP_ICON_CHAT,
                "Exchange tokens for powerful gear here!",
                SENDER_MAIN,
                GOSSIP_ACTION_BACK
            );
            player->ADD_GOSSIP_ITEM(
                GOSSIP_ICON_CHAT,
                "<< Back",
                SENDER_MAIN,
                GOSSIP_ACTION_BACK
            );
            player->SEND_GOSSIP_MENU(2, creature->GetGUID());
        }
        
        player->CLOSE_GOSSIP_MENU();
        return true;
    }
    
private:
    uint32 GetPlayerTokenCount(Player* player)
    {
        // Count tokens in inventory
        uint32 count = player->GetItemCount(ITEM_MYTHIC_DUNGEON_TOKEN);
        return count;
    }
};
```

**Also needed:**
- Create vendor loot table entries
- Configure token item (100020)
- Add gear items for exchange
- Set pricing (e.g., 500 tokens for chest piece)

**Checklist:**
- [ ] Create NPC script
- [ ] Implement gossip menu
- [ ] Show token balance
- [ ] Create vendor loot table
- [ ] Add gear items
- [ ] Set token prices
- [ ] Test token exchange

---

### Task 3.3: Loot Scaling (5-10 hours)

**Optional for MVP** - Can use static loot tables initially

If implementing:
- Scale item level based on keystone
- M+2: 219 iLvl
- M+5: 226 iLvl
- M+10: 239 iLvl

---

## ✅ Phase 4: Testing & Validation (Week 7)

**Goal:** Verify all systems work end-to-end  
**Effort:** 20-30 hours

### Test Cases

1. **Keystone Creation** ✅
   - [ ] Request keystone from Keystone Master
   - [ ] Verify keystone in inventory
   - [ ] Check correct level assigned

2. **Dungeon Teleport** ✅
   - [ ] Use Teleporter NPC
   - [ ] Select dungeon
   - [ ] Verify teleportation

3. **Font Activation** ✅
   - [ ] Enter dungeon
   - [ ] Find Font of Power
   - [ ] Activate keystone
   - [ ] Verify affixes apply

4. **Run Tracking** ✅
   - [ ] Complete bosses
   - [ ] Track deaths
   - [ ] Verify death counter
   - [ ] Check boss kill tracking

5. **Completion Rewards** ✅
   - [ ] Complete all bosses
   - [ ] Verify tokens awarded
   - [ ] Check upgrade calculation
   - [ ] Test death penalty (15+)

6. **Vault Progress** ✅
   - [ ] Complete 1 dungeon → Slot 1 unlocked
   - [ ] Complete 4 dungeons → Slot 2 unlocked
   - [ ] Complete 8 dungeons → Slot 3 unlocked

7. **Vault Rewards** ✅
   - [ ] Claim slot 1
   - [ ] Claim slot 2
   - [ ] Claim slot 3
   - [ ] Verify tokens awarded
   - [ ] Test double-claim prevention

8. **Token Vendor** ✅
   - [ ] Check token balance
   - [ ] Browse gear
   - [ ] Exchange tokens for item
   - [ ] Verify deduction

---

## 🎉 MVP Success Criteria

When these all work, you have a functional MVP:

- [x] Database tables exist and load correctly
- [x] Players can request and receive keystones
- [x] Dungeons can be activated with keystones
- [x] Affixes apply to creatures correctly
- [x] Deaths and boss kills are tracked
- [x] Tokens are awarded on completion
- [x] Vault progress tracks 1/4/8 completions
- [x] Vault rewards can be claimed
- [x] Token vendor exchanges tokens for gear
- [x] All data persists between sessions

---

## 📊 Time Investment Summary

| Phase | Effort | Components |
|-------|--------|------------|
| Phase 1: Database | 40-60 hours | Tables, data, integration |
| Phase 2: Vault | 50-70 hours | Progress, rewards, claims |
| Phase 3: Tokens | 40-50 hours | Calculation, distribution, vendor |
| Phase 4: Testing | 20-30 hours | End-to-end validation |
| **TOTAL MVP** | **150-210 hours** | Functional M+ system |

---

## 🚀 Post-MVP Enhancements

After MVP is complete and tested:

1. **Season Management** (80-100 hours)
   - Automated season transitions
   - Dungeon rotation
   - Seasonal rewards

2. **Rating & Leaderboards** (60-80 hours)
   - Rating calculation
   - Leaderboard display
   - Competitive rankings

3. **Achievements** (40-50 hours)
   - 22 achievement implementations
   - Progress tracking
   - Rewards

4. **Weekly Reset Automation** (30-40 hours)
   - Automated vault reset
   - Affix rotation
   - Cleanup

5. **Titles** (15-20 hours)
   - Title unlocks
   - Display integration

---

## ✅ Final Checklist

### Must Have for MVP
- [ ] All database tables created
- [ ] Initial data populated
- [ ] Manager loads from database
- [ ] Vault progress tracking works
- [ ] Vault rewards can be claimed
- [ ] Tokens awarded on completion
- [ ] Token vendor functional
- [ ] End-to-end testing complete

### Nice to Have (Post-MVP)
- [ ] Seasonal rotation
- [ ] Rating system
- [ ] Leaderboards
- [ ] Achievements
- [ ] Automated resets
- [ ] Titles

---

**Document Status:** ✅ READY TO IMPLEMENT  
**Next Action:** Start with Phase 1, Task 1.1 (Create World Database Tables)
