# 🔄 DUNGEON QUEST SYSTEM - INTEGRATION GUIDE
**Extending Existing DarkChaos-255 Dungeon Quest System**

---

## ⚠️ IMPORTANT: Avoid Duplication!

Your server **already has** a dungeon quest system in place:
- **Location**: `src/server/scripts/DC/DungeonQuests/`
- **Database**: `Custom/Custom feature SQLs/worlddb/DungeonQuest/`
- **Status**: Active with 4 daily + 4 weekly quests

**This guide shows how to EXTEND the existing system, not replace it.**

---

## 📊 Current System Inventory

### Existing Quest Ranges
| Type | Current Range | Count | Next Available |
|------|---------------|-------|----------------|
| **Daily** | 700101-700104 | 4 | 700105-700199 |
| **Weekly** | 700201-700204 | 4 | 700205-700299 |
| **Dungeon** | 700701-700999 | ~300 | 701000+ |

### Existing Achievement Ranges
| System | Range | Purpose |
|--------|-------|---------|
| DungeonQuest | 13500-13514 | Quest milestones |
| Zone Exploration | 10001-10004 | Custom zones |
| Hinterlands BG | 10200-10205 | PvP |
| Prestige | 10300-10309 | Prestige levels |
| Collections | 10400-10405 | Mounts/Pets/Titles |
| Server Firsts | 10500-10501 | First achievements |
| Challenge Modes | 10600-10604 | Hardcore/Iron Man |
| Level Milestones | 10700-10703 | Level 100/150/200/255 |

### Existing Tables (World DB)
```sql
dc_dungeon_quest_mapping           -- Dungeon configuration
dc_dungeon_quest_npcs              -- NPC spawn data
dc_daily_quest_token_rewards       -- Daily reward mapping
dc_weekly_quest_token_rewards      -- Weekly reward mapping
dc_quest_reward_tokens             -- Token definitions
dc_dungeon_quest_definitions       -- Quest objectives
dc_dungeon_quest_rewards           -- Reward configuration
dc_dungeon_quest_config            -- Global config
```

### Existing Tables (Character DB)
```sql
dc_character_dungeon_progress      -- Player progress
dc_player_daily_quest_progress     -- Daily tracking
dc_player_weekly_quest_progress    -- Weekly tracking
dc_character_dungeon_quests_completed  -- Completion history
dc_character_dungeon_statistics    -- Player stats
dc_character_dungeon_npc_respawn   -- NPC respawn status
```

### Existing C++ Scripts
```cpp
DungeonQuestSystem.cpp             -- Main quest handler
npc_dungeon_quest_daily_weekly.cpp -- Daily/weekly resets
npc_dungeon_quest_master.cpp       -- NPC gossip
dc_achievements.cpp                -- Achievement system
```

---

## 🎯 Extension Strategy

### Phase 1: Extend Database Schema

#### 1.1 Add Difficulty Support to Existing Table
```sql
-- Add difficulty column to existing mapping table
ALTER TABLE `dc_dungeon_quest_mapping` 
ADD COLUMN `difficulty` ENUM('Normal','Heroic','Mythic','Mythic+') 
NOT NULL DEFAULT 'Normal' AFTER `tier`;

-- Add difficulty tracking to player stats
ALTER TABLE `dc_character_dungeon_statistics`
ADD COLUMN `stat_name` VARCHAR(100) NOT NULL DEFAULT 'total_quests_completed' AFTER `guid`,
ADD COLUMN `stat_value` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `stat_name`,
ADD COLUMN `last_update` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `stat_value`,
ADD KEY `idx_stat_name` (`stat_name`);
```

#### 1.2 Create Difficulty Configuration Table
```sql
-- New table for difficulty multipliers
CREATE TABLE IF NOT EXISTS `dc_difficulty_config` (
  `difficulty_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `difficulty_name` ENUM('Normal','Heroic','Mythic','Mythic+') NOT NULL,
  `min_level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `token_multiplier` DECIMAL(3,2) NOT NULL DEFAULT 1.00,
  `gold_multiplier` DECIMAL(3,2) NOT NULL DEFAULT 1.00,
  `xp_multiplier` DECIMAL(3,2) NOT NULL DEFAULT 1.00,
  `min_group_size` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`difficulty_id`),
  UNIQUE KEY `uk_difficulty_name` (`difficulty_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `dc_difficulty_config` VALUES
(1, 'Normal', 1, 1.00, 1.00, 1.00, 1, 1),
(2, 'Heroic', 80, 1.50, 1.50, 1.25, 1, 1),
(3, 'Mythic', 80, 2.00, 2.00, 1.50, 3, 1),
(4, 'Mythic+', 80, 3.00, 3.00, 2.00, 5, 0); -- Coming soon
```

### Phase 2: Expand Quest Pool

#### 2.1 Add More Daily Quests (700105-700135)
Use the existing `dc_daily_quest_token_rewards` table:

```sql
-- Add 31 more daily quests (5 per day × 7 days rotation = 35 total)
INSERT INTO `dc_daily_quest_token_rewards` 
(`quest_id`, `token_item_id`, `token_count`, `bonus_multiplier`)
VALUES
-- Day 1 continuation (quests 700105-700107)
(700105, 700001, 1, 1.0),  -- Stratholme
(700106, 700001, 1, 1.0),  -- Scholomance
(700107, 700001, 1, 1.0),  -- Dire Maul

-- Day 2 (quests 700108-700112)
(700108, 700001, 1, 1.0),  -- Blackrock Spire
(700109, 700001, 1, 1.0),  -- Zul'Farrak
-- ... continue for all 35 daily quests
```

#### 2.2 Add More Weekly Quests (700205-700212)
Use the existing `dc_weekly_quest_token_rewards` table:

```sql
-- Add 8 more weekly quests (3 per week × 4 weeks rotation = 12 total)
INSERT INTO `dc_weekly_quest_token_rewards`
(`quest_id`, `token_item_id`, `token_count`, `bonus_multiplier`)
VALUES
-- Week 1 continuation (quest 700205)
(700205, 700002, 3, 1.0),  -- Heroic BRD Weekly

-- Week 2 (quests 700206-700208)
(700206, 700002, 3, 1.0),  -- Heroic Hellfire Ramparts
(700207, 700003, 5, 1.0),  -- Mythic challenge
(700208, 700002, 3, 1.0),  -- Heroic alternate
-- ... continue for all 12 weekly quests
```

### Phase 3: Extend Achievement System

#### 3.1 Use Next Available Achievement Range
Since DC achievements use 10001-10703, we'll use **10800-10899** for dungeon-specific achievements:

```sql
-- Add to existing dc_achievements.sql
INSERT INTO `achievement` VALUES
-- Dungeon Initiate (10800-10804)
(10800, 81, 10004, 'First Steps', 'Complete your first dungeon quest', 10, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL),
(10801, 81, 10004, 'Quest Explorer', 'Complete 10 dungeon quests', 10, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL),
(10802, 81, 10004, 'Quest Veteran', 'Complete 25 dungeon quests', 15, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL),
(10803, 81, 10004, 'Quest Master', 'Complete 50 dungeon quests', 20, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL),
(10804, 81, 10004, 'Dungeon Enthusiast', 'Complete 100 dungeon quests', 25, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL),

-- Difficulty Challenges (10820-10824)
(10820, 81, 10004, 'Heroic Initiate', 'Complete 10 Heroic quests', 15, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL),
(10821, 81, 10004, 'Heroic Conqueror', 'Complete 50 Heroic quests', 30, 1, 0, 126, 0, 0, 0, 0, 0, 0, 'the Heroic'),
(10822, 81, 10004, 'Mythic Initiate', 'Complete 10 Mythic quests', 20, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL),
(10823, 81, 10004, 'Mythic Conqueror', 'Complete 25 Mythic quests', 40, 1, 0, 127, 0, 0, 0, 0, 0, 0, 'the Mythic'),
(10824, 81, 10004, 'Mythic+ Pioneer', 'Complete 10 Mythic+ quests', 50, 1, 0, 128, 0, 0, 0, 0, 0, 0, 'the Unstoppable'),

-- Daily/Weekly Dedication (10830-10836)
(10830, 81, 10004, '7-Day Streak', '7 consecutive daily completions', 15, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL),
(10831, 81, 10004, '30-Day Streak', '30 consecutive daily completions', 30, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL),
(10832, 81, 10004, 'Weekly Warrior', 'Complete 5 weekly quests', 15, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL),
(10833, 81, 10004, 'Weekly Champion', 'Complete 10 weekly quests', 20, 1, 0, -1, 0, 0, 0, 0, 0, 0, NULL);
```

**Note**: Achievement category ID **10004** already exists in `dc_achievement_categories.sql` as "DarkChaos Custom".

### Phase 4: Update C++ Scripts

#### 4.1 Update `DungeonQuestSystem.cpp`

**Add difficulty detection**:
```cpp
// Add after line 30 (after quest range constants)
enum QuestDifficulty
{
    DIFFICULTY_NORMAL = 0,
    DIFFICULTY_HEROIC = 1,
    DIFFICULTY_MYTHIC = 2,
    DIFFICULTY_MYTHIC_PLUS = 3
};

// Add new helper function
class DungeonQuestDB
{
    // ... existing functions ...
    
    // NEW: Get difficulty from quest ID
    static QuestDifficulty GetQuestDifficulty(uint32 questId)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT difficulty FROM dc_dungeon_quest_mapping WHERE quest_id = {}", questId
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            std::string diff = fields[0].Get<std::string>();
            
            if (diff == "Heroic") return DIFFICULTY_HEROIC;
            if (diff == "Mythic") return DIFFICULTY_MYTHIC;
            if (diff == "Mythic+") return DIFFICULTY_MYTHIC_PLUS;
        }
        
        return DIFFICULTY_NORMAL;
    }
    
    // NEW: Get difficulty multiplier
    static float GetDifficultyTokenMultiplier(QuestDifficulty difficulty)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT token_multiplier FROM dc_difficulty_config WHERE difficulty_id = {}", difficulty + 1
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<float>();
        }
        
        return 1.0f;
    }
    
    // NEW: Update difficulty-specific statistics
    static void UpdateDifficultyStatistics(Player* player, QuestDifficulty difficulty)
    {
        std::string statName = "heroic_quests_completed";
        switch (difficulty)
        {
            case DIFFICULTY_HEROIC: statName = "heroic_quests_completed"; break;
            case DIFFICULTY_MYTHIC: statName = "mythic_quests_completed"; break;
            case DIFFICULTY_MYTHIC_PLUS: statName = "mythic_plus_quests_completed"; break;
            default: return; // Don't track normal separately
        }
        
        UpdateStatistics(player, statName, 1);
    }
};
```

**Update token rewards to use difficulty multipliers** (modify `HandleTokenRewards` function):
```cpp
void HandleTokenRewards(Player* player, uint32 questId, bool isDailyQuest, bool isWeeklyQuest)
{
    uint32 tokenAmount = 0;
    uint32 tokenItemId = DungeonQuestDB::GetTokenItemId();

    if (tokenItemId == 0)
    {
        LOG_DEBUG("scripts", "DungeonQuest: No token item configured");
        return;
    }

    if (isDailyQuest)
    {
        tokenAmount = DungeonQuestDB::GetDailyQuestTokenReward(questId);
    }
    else if (isWeeklyQuest)
    {
        tokenAmount = DungeonQuestDB::GetWeeklyQuestTokenReward(questId);
    }

    // NEW: Apply difficulty multiplier
    QuestDifficulty difficulty = DungeonQuestDB::GetQuestDifficulty(questId);
    float multiplier = DungeonQuestDB::GetDifficultyTokenMultiplier(difficulty);
    tokenAmount = static_cast<uint32>(tokenAmount * multiplier);

    if (tokenAmount > 0)
    {
        if (player->AddItem(tokenItemId, tokenAmount))
        {
            std::string difficultyText = "";
            if (difficulty == DIFFICULTY_HEROIC) difficultyText = " (Heroic bonus)";
            else if (difficulty == DIFFICULTY_MYTHIC) difficultyText = " (Mythic bonus)";
            else if (difficulty == DIFFICULTY_MYTHIC_PLUS) difficultyText = " (Mythic+ bonus)";
            
            ChatHandler(player->GetSession()).PSendSysMessage(
                "You have been awarded %u Dungeon Tokens!%s", 
                tokenAmount, 
                difficultyText.c_str()
            );
        }
    }
    
    // NEW: Track difficulty statistics
    DungeonQuestDB::UpdateDifficultyStatistics(player, difficulty);
}
```

**Update achievement checking** (modify `CheckAchievements` function):
```cpp
void CheckAchievements(Player* player, uint32 questId, bool isDailyQuest, bool isWeeklyQuest, bool isDungeonQuest)
{
    if (!player) return;

    // ... existing achievement checks for 13500-13514 ...
    
    // NEW: Difficulty-based achievements (10820-10824)
    QuestDifficulty difficulty = DungeonQuestDB::GetQuestDifficulty(questId);
    
    if (difficulty == DIFFICULTY_HEROIC)
    {
        uint32 heroicCount = DungeonQuestDB::GetStatisticValue(player, "heroic_quests_completed");
        
        if (heroicCount == 10)
            AwardAchievement(player, 10820, "Heroic Initiate");
        else if (heroicCount == 50)
            AwardAchievement(player, 10821, "Heroic Conqueror");
    }
    else if (difficulty == DIFFICULTY_MYTHIC)
    {
        uint32 mythicCount = DungeonQuestDB::GetStatisticValue(player, "mythic_quests_completed");
        
        if (mythicCount == 10)
            AwardAchievement(player, 10822, "Mythic Initiate");
        else if (mythicCount == 25)
            AwardAchievement(player, 10823, "Mythic Conqueror");
    }
    else if (difficulty == DIFFICULTY_MYTHIC_PLUS)
    {
        uint32 mythicPlusCount = DungeonQuestDB::GetStatisticValue(player, "mythic_plus_quests_completed");
        
        if (mythicPlusCount == 10)
            AwardAchievement(player, 10824, "Mythic+ Pioneer");
    }
    
    // NEW: Daily streak achievement (10830)
    if (isDailyQuest)
    {
        uint32 currentStreak = DungeonQuestDB::GetStatisticValue(player, "daily_streak_current");
        
        if (currentStreak == 7)
            AwardAchievement(player, 10830, "7-Day Streak");
        else if (currentStreak == 30)
            AwardAchievement(player, 10831, "30-Day Streak");
    }
    
    // NEW: Weekly milestones (10832-10833)
    if (isWeeklyQuest)
    {
        uint32 weeklyCount = DungeonQuestDB::GetStatisticValue(player, "weekly_quests_completed");
        
        if (weeklyCount == 5)
            AwardAchievement(player, 10832, "Weekly Warrior");
        else if (weeklyCount == 10)
            AwardAchievement(player, 10833, "Weekly Champion");
    }
}
```

#### 4.2 Update `npc_dungeon_quest_daily_weekly.cpp`

**Add daily streak tracking**:
```cpp
void CheckDailyQuestReset(Player* player)
{
    QueryResult result = CharacterDatabase.Query(
        "SELECT daily_quest_entry, completed_today, UNIX_TIMESTAMP(last_completed) "
        "FROM dc_player_daily_quest_progress WHERE guid = {}", 
        player->GetGUID().GetCounter()
    );

    if (result)
    {
        do {
            Field* fields = result->Fetch();
            uint32 dailyQuestId = fields[0].Get<uint32>();
            bool completedToday = fields[1].Get<bool>();

            if (completedToday)
            {
                time_t lastCompleted = time_t(fields[2].Get<uint32>());
                time_t now = time(nullptr);

                tm* timeinfo = localtime(&now);
                tm* lastTime = localtime(&lastCompleted);

                // Check if it's a new day
                if (lastTime->tm_mday != timeinfo->tm_mday || (now - lastCompleted) > (24 * 3600))
                {
                    ResetDailyQuest(player, dailyQuestId);
                    
                    // NEW: Update daily streak
                    if ((now - lastCompleted) <= (48 * 3600)) // Within 48 hours = streak continues
                    {
                        CharacterDatabase.Execute(
                            "UPDATE dc_character_dungeon_statistics "
                            "SET stat_value = stat_value + 1 "
                            "WHERE guid = {} AND stat_name = 'daily_streak_current'",
                            player->GetGUID().GetCounter()
                        );
                    }
                    else // Streak broken
                    {
                        CharacterDatabase.Execute(
                            "UPDATE dc_character_dungeon_statistics "
                            "SET stat_value = 0 "
                            "WHERE guid = {} AND stat_name = 'daily_streak_current'",
                            player->GetGUID().GetCounter()
                        );
                    }
                }
            }
        } while (result->NextRow());
    }
}
```

---

## 📝 Step-by-Step Integration

### Step 1: Backup Everything
```bash
# Backup databases
mysqldump -u root -p acore_world > backup_world_$(date +%Y%m%d).sql
mysqldump -u root -p acore_characters > backup_characters_$(date +%Y%m%d).sql

# Backup C++ scripts
cp -r src/server/scripts/DC/DungeonQuests src/server/scripts/DC/DungeonQuests_backup
```

### Step 2: Apply Database Extensions
```bash
cd "Custom/Custom feature SQLs/worlddb/DungeonQuest"

# Execute in order:
mysql -u root -p acore_world < EXTENSION_01_difficulty_support.sql
mysql -u root -p acore_world < EXTENSION_02_expanded_daily_quests.sql
mysql -u root -p acore_world < EXTENSION_03_expanded_weekly_quests.sql

cd "../Achievements"
mysql -u root -p acore_world < EXTENSION_04_dungeon_achievements.sql
```

### Step 3: Update C++ Scripts
1. Open `DungeonQuestSystem.cpp`
2. Add difficulty detection code
3. Update `HandleTokenRewards` function
4. Update `CheckAchievements` function
5. Open `npc_dungeon_quest_daily_weekly.cpp`
6. Add daily streak tracking code

### Step 4: Recompile Server
```bash
cd build
cmake ..
make -j$(nproc)
```

### Step 5: Test
1. Restart server
2. Check quest availability: `.quest lookup 700105`
3. Test difficulty multipliers: Complete heroic daily quest
4. Check achievement: `.achievement lookup 10820`
5. Verify streak tracking: Complete dailies on consecutive days

---

## ✅ Verification Checklist

- [ ] Existing daily quests (700101-700104) still work
- [ ] New daily quests (700105-700135) appear correctly
- [ ] Existing weekly quests (700201-700204) still work
- [ ] New weekly quests (700205-700212) appear correctly
- [ ] Token rewards apply difficulty multipliers
- [ ] Achievements (10800-10899) unlock properly
- [ ] Daily streaks track correctly
- [ ] Weekly resets function as expected
- [ ] No duplicate NPCs spawned
- [ ] Existing character data preserved

---

## 📚 Reference

### File Locations
```
src/server/scripts/DC/DungeonQuests/
├── DungeonQuestSystem.cpp          ← UPDATE THIS
├── npc_dungeon_quest_daily_weekly.cpp  ← UPDATE THIS
├── npc_dungeon_quest_master.cpp    ← No changes needed
├── DungeonQuestMasterFollower.cpp
├── DungeonQuestPhasing.cpp
└── TokenConfigManager.h

Custom/Custom feature SQLs/worlddb/DungeonQuest/
├── DC_DUNGEON_QUEST_SCHEMA_v2.sql  ← Already has base tables
├── DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql  ← Extend this
├── EXTENSION_01_difficulty_support.sql  ← NEW FILE
├── EXTENSION_02_expanded_daily_quests.sql  ← NEW FILE
└── EXTENSION_03_expanded_weekly_quests.sql  ← NEW FILE

Custom/Custom feature SQLs/worlddb/Achievements/
├── dc_achievement_categories.sql   ← Category 10004 exists
├── dc_achievements.sql             ← Add 10800-10899 here
└── EXTENSION_04_dungeon_achievements.sql  ← NEW FILE
```

### Achievement ID Allocation
- **10001-10004**: Zone exploration
- **10200-10205**: Hinterlands BG
- **10300-10309**: Prestige system
- **10400-10405**: Collections
- **10500-10501**: Server firsts
- **10600-10604**: Challenge modes
- **10700-10703**: Level milestones
- **10800-10899**: ⭐ **DUNGEON QUESTS (NEW!)**
- **13500-13514**: Quest milestones (existing)

### Quest ID Allocation
- **700101-700104**: Daily quests (existing)
- **700105-700135**: Daily quests (NEW - 31 quests)
- **700201-700204**: Weekly quests (existing)
- **700205-700212**: Weekly quests (NEW - 8 quests)
- **700701-700999**: Dungeon quests (existing pool)

---

## 🎉 Benefits of This Approach

✅ **No Duplicate Tables** - Uses existing infrastructure  
✅ **Consistent Numbering** - Achievement IDs fit existing schema  
✅ **Minimal Code Changes** - Extends, doesn't replace  
✅ **Backward Compatible** - Existing quests/achievements preserved  
✅ **Scalable** - Easy to add more quests/achievements later  
✅ **Maintains Standards** - Follows DarkChaos-255 conventions  

**Total New Files**: 4 SQL extensions + 2 C++ script updates  
**Total Integration Time**: ~2 hours  

---

*Integration Guide - DarkChaos-255 Dungeon Quest System v4.0*
