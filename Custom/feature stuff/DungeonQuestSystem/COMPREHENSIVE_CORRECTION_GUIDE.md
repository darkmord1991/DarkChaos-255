# 🔧 DUNGEON QUEST NPC SYSTEM v2.0 - COMPREHENSIVE CORRECTION GUIDE

## ✅ Now I Understand Everything

You have:
1. **CSV/DBC files for client/server modding** (Spell, Achievement, Title, etc. - for game data)
2. **Custom quest system using standard AC quest linking** (no custom mapping needed)
3. **AzerothCore base** with regular merges from upstream

---

## 🎯 CORRECTIONS NEEDED

### 1. ALL TABLES MUST HAVE `dc_` PREFIX ✅

**Current Issues:**
- ❌ `dungeon_quest_npc` → ✅ `dc_dungeon_quest_npc`
- ❌ `dungeon_quest_mapping` → ✅ `dc_dungeon_quest_mapping`
- ❌ `player_dungeon_quest_progress` → ✅ `dc_player_dungeon_quest_progress`
- ❌ `player_dungeon_achievements` → ✅ `dc_player_dungeon_achievements`
- ❌ `expansion_stats` → ✅ `dc_expansion_stats`
- ❌ `player_dungeon_completion_stats` → ✅ `dc_player_dungeon_completion_stats`
- ❌ `player_daily_quest_progress` → ✅ `dc_player_daily_quest_progress`
- ❌ `player_weekly_quest_progress` → ✅ `dc_player_weekly_quest_progress`
- ❌ `custom_dungeon_quests` → ✅ `dc_custom_dungeon_quests`
- ✅ `dc_quest_reward_tokens` (already correct)
- ✅ `dc_daily_quest_token_rewards` (already correct)
- ✅ `dc_weekly_quest_token_rewards` (already correct)

**Action:** Rename all tables in SQL files with `dc_` prefix.

---

## 2. HOW QUEST LINKING ACTUALLY WORKS IN AZEROTHCORE

The standard AC method is **MUCH simpler** than custom tracking!

### Standard AzerothCore Quest Linking (NO Custom Tables Needed!)

**How quests are linked to NPCs in AC:**

1. **quest_template** table has standard columns (already exist in AC):
   - `ID` - Quest ID
   - Other quest data...

2. **creature_questrelation** table (standard AC) links NPCs to quest starters:
   ```sql
   CREATE TABLE creature_questrelation (
       id INT UNSIGNED NOT NULL,       -- NPC entry
       quest INT UNSIGNED NOT NULL,    -- Quest ID
       PRIMARY KEY (id, quest)
   ) ENGINE=INNODB;
   ```

3. **creature_involvedrelation** table (standard AC) links NPCs to quest finishers:
   ```sql
   CREATE TABLE creature_involvedrelation (
       id INT UNSIGNED NOT NULL,       -- NPC entry
       quest INT UNSIGNED NOT NULL,    -- Quest ID
       PRIMARY KEY (id, quest)
   ) ENGINE=INNODB;
   ```

### How It Works:

```
NPC 700001 talks to Player
   ↓
Server checks: SELECT * FROM creature_questrelation WHERE id = 700001
   ↓
Returns: Quest 700701, 700702, 700703
   ↓
NPC shows in gossip menu: "Start Quest X"
   ↓
Player clicks → Quest starts

Player completes quest objectives
   ↓
NPC shows in gossip menu: "Complete Quest X"
   ↓
Server checks: SELECT * FROM creature_involvedrelation WHERE id = 700001
   ↓
NPC can complete the quest
   ↓
Player gets rewards (handled by C++ script or gossip)
```

### Example SQL (For Both Start AND Complete):

```sql
-- NPC 700001 STARTS quests
INSERT INTO creature_questrelation VALUES
(700001, 700701),  -- Quest giver
(700001, 700702),
(700001, 700703);

-- NPC 700001 COMPLETES quests (SAME NPC!)
INSERT INTO creature_involvedrelation VALUES
(700001, 700701),  -- Quest completer
(700001, 700702),
(700001, 700703);
```

**Result:** Single NPC handles both quest start and completion! ✅

---

## 3. WHY YOU DON'T NEED CUSTOM TRACKING TABLES

Your custom tables like `dc_dungeon_quest_mapping` are **REDUNDANT** because:

1. ✅ `creature_questrelation` already exists in AC (quest starters)
2. ✅ `creature_involvedrelation` already exists in AC (quest finishers)
3. ✅ Both are automatically used by AC's gossip system
4. ✅ C++ scripts can directly query these standard tables

### What to do with custom tracking tables:

**Option A: Delete them** - You don't need them!
- Use standard AC tables instead
- Simpler, cleaner, compatible

**Option B: Keep them** - For admin purposes only
- For tracking "which NPCs handle which quests"
- But this is already handled by the standard tables
- Redundant information

**Recommendation:** DELETE the custom tracking tables and use AC's standard system.

---

## 4. DAILY/WEEKLY QUEST TRACKING (How Completion Works)

### Standard AC Approach:

Instead of custom daily/weekly tracking, use:

1. **character_queststatus** (standard AC):
   ```
   Fields:
   - guid              (character ID)
   - quest             (quest ID)
   - status            (0=none, 1=incomplete, 2=complete, 3=rewarded)
   - timer             (quest expiration time)
   - mobcount1-4       (objective counts)
   - itemcount1-6      (item objective counts)
   - explored          (exploration status)
   - reward            (reward status)
   ```

2. **For daily/weekly:** Quest flags in quest_template:
   ```sql
   quest_template.Flags:
   - 0x0800  = QUEST_FLAGS_DAILY
   - 0x1000  = QUEST_FLAGS_WEEKLY
   ```

3. **Server automatically handles resets** based on flags!

### How Daily/Weekly Resets Work:

```
Daily Quest (Flag 0x0800):
- Quest auto-resets at daily reset time (default: 06:00)
- Tracked in character_queststatus
- Server automatically marks as REWARDED

Weekly Quest (Flag 0x1000):
- Quest auto-resets at weekly reset (default: Tuesday 06:00)
- Tracked in character_queststatus
- Server automatically marks as REWARDED
```

### Example SQL:

```sql
-- Quest is DAILY (resets every 24 hours)
INSERT INTO quest_template (ID, Flags, ...) 
VALUES (700101, 0x0800 | other_flags, ...);

-- Quest is WEEKLY (resets every 7 days)
INSERT INTO quest_template (ID, Flags, ...)
VALUES (700201, 0x1000 | other_flags, ...);

-- No custom tables needed! AC handles everything!
```

**Key Point:** Set the FLAGS in quest_template, server does the rest! ✅

---

## 5. ACHIEVEMENTS TRACKING (Integration with CSV/DBC)

### Achievement.csv → C++ Data Integration

Your `dc_achievements.csv` should map to:
- Achievement IDs (40-49 range for custom)
- Achievement criteria
- Linked to dungeon quests

### How it works:

1. **Extract Achievement.csv** from client DBC files
2. **Add custom entries** for dungeon achievements:
   ```csv
   ID,Name,Category,Icon,...
   40001,"Dungeon Novice",92,1234,...
   40002,"Dungeon Explorer",92,1234,...
   ```

3. **In C++ script:** Award achievement when quest completes:
   ```cpp
   if (player->CompleteQuest(700701))
   {
       player->CompletedAchievement(40001);  // Custom achievement
   }
   ```

4. **No custom tracking table needed** - AC handles achievements in:
   - `character_achievement` (character DB)
   - `achievement_dbc` (DBC file)

---

## 6. TOKENS TRACKING (Integration with CSV/DBC)

### Items.csv → Token Integration

Your `dc_items_tokens.csv` with token IDs (700001-700005):

```csv
ID,Name,Quality,Class,SubClass,...
700001,"Dungeon Explorer Token",1,15,0,...
700002,"Expansion Specialist Token",1,15,0,...
700003,"Legendary Dungeon Token",3,15,0,...
```

### How it works:

1. **Extract item_template.csv** from WDB
2. **Add custom token entries** to `dc_items_tokens.csv`
3. **In quest_template_addon:** Award tokens:
   ```sql
   UPDATE quest_template_addon 
   SET RewardMailTemplateId = 123  -- Mail with tokens
   WHERE ID IN (700701, 700702, ...);
   ```

4. **In C++ script:** Award tokens on completion:
   ```cpp
   player->AddItem(700001, 1);  // Give token
   sTokenConfig->AddTokenCount(player, 1);  // Track total
   ```

**No custom tracking needed** - Items are tracked in:
- `character_inventory` (character DB)
- Custom counter table (if needed for stats)

---

## 7. SIMPLIFIED DATA FLOW

### Before (Over-complicated):
```
NPC → Custom Quest Mapping Table
    → Custom Progress Tracking
    → Custom Daily/Weekly Reset
    → Custom Achievement Tracking
    → Custom Token Tracking
```

### After (AzerothCore Standard):
```
NPC (700001)
   ↓
creature_questrelation (start) + creature_involvedrelation (end)
   ↓
quest_template (with DAILY/WEEKLY flags)
   ↓
character_queststatus (auto-tracked by AC)
   ↓
C++ script (awards tokens/achievements)
   ↓
character_achievement (auto-tracked by AC)
   ↓
character_inventory (auto-tracked by AC)
```

**Much simpler! ✅**

---

## 8. WHAT TABLES YOU ACTUALLY NEED

### Keep These (Essential):
- ✅ `dc_quest_reward_tokens` - Token definitions
- ✅ `dc_daily_quest_token_rewards` - Daily token amounts  
- ✅ `dc_weekly_quest_token_rewards` - Weekly token amounts

### Delete These (Already handled by AC):
- ❌ `dc_dungeon_quest_mapping` - Use creature_questrelation
- ❌ `dc_player_dungeon_quest_progress` - Use character_queststatus
- ❌ `dc_dungeon_quest_npc` - Use creature_template + creature
- ❌ `dc_player_daily_quest_progress` - Use character_queststatus + flags
- ❌ `dc_player_weekly_quest_progress` - Use character_queststatus + flags
- ❌ `dc_player_dungeon_achievements` - Use character_achievement
- ❌ `dc_player_dungeon_completion_stats` - Track in C++ script only
- ❌ `dc_expansion_stats` - Not needed for quest system
- ❌ `dc_custom_dungeon_quests` - Use quest_template

### New Custom Tables (Needed):
- ➕ `dc_npc_quest_link` (Optional, for admin reference only)

---

## 9. FINAL SCHEMA (CORRECTED)

### Create File: `DC_DUNGEON_QUEST_SCHEMA_CORRECTED.sql`

```sql
-- Core token definitions
CREATE TABLE `dc_quest_reward_tokens` (
    `id` INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    `token_item_id` INT UNSIGNED NOT NULL UNIQUE,
    `token_name` VARCHAR(255) NOT NULL,
    `token_type` ENUM('explorer', 'specialist', 'legendary', 'challenge', 'speedrunner') NOT NULL,
    `description` TEXT,
    `rarity` INT UNSIGNED DEFAULT 1,
    UNIQUE KEY `token_item_id` (`token_item_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4;

-- Daily quest token rewards
CREATE TABLE `dc_daily_quest_token_rewards` (
    `quest_id` INT UNSIGNED PRIMARY KEY,
    `token_id` INT UNSIGNED NOT NULL,
    `token_count` INT UNSIGNED NOT NULL DEFAULT 1,
    `bonus_multiplier` FLOAT DEFAULT 1.0,
    FOREIGN KEY (`token_id`) REFERENCES `dc_quest_reward_tokens`(`token_item_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4;

-- Weekly quest token rewards
CREATE TABLE `dc_weekly_quest_token_rewards` (
    `quest_id` INT UNSIGNED PRIMARY KEY,
    `token_id` INT UNSIGNED NOT NULL,
    `token_count` INT UNSIGNED NOT NULL DEFAULT 1,
    `bonus_multiplier` FLOAT DEFAULT 1.0,
    FOREIGN KEY (`token_id`) REFERENCES `dc_quest_reward_tokens`(`token_item_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4;

-- Optional: Admin reference only (not required)
CREATE TABLE `dc_npc_quest_link` (
    `npc_entry` INT UNSIGNED NOT NULL,
    `quest_id` INT UNSIGNED NOT NULL,
    `is_starter` TINYINT(1) DEFAULT 1,
    `is_ender` TINYINT(1) DEFAULT 1,
    PRIMARY KEY (`npc_entry`, `quest_id`),
    KEY `quest_idx` (`quest_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COMMENT="Optional tracking - standard AC tables are authoritative";

-- Standard AC tables link quests to NPCs:
-- creature_questrelation (quest starters)
-- creature_involvedrelation (quest completers)
```

---

## 10. ACHIEVEMENT CSV → DBC WORKFLOW

### Step 1: Extract Client DBC
```bash
# Use WoWDBC extractor
./dbc_extractor.exe
# Output: Achievement.csv, ItemTemplate.csv, Spell.csv, etc.
```

### Step 2: Modify CSV for Custom Data
```csv
# dc_achievements_custom_extract.csv
ID,Name_Lang,Category,Icon,Reward,...
40001,"Dungeon Novice",92,1234,100,...
40002,"Dungeon Explorer",92,1234,200,...
```

### Step 3: Recompile to DBC
```bash
./dbc_recompiler.exe dc_achievements_custom_extract.csv
# Output: Achievement.dbc (for client)
```

### Step 4: Link in C++ Script
```cpp
if (player->CompleteQuest(700701))
{
    player->CompletedAchievement(40001);  // From custom DBC
}
```

**Your CSV files are for DBC extraction/compilation, not server config!** ✅

---

## 11. ACTION PLAN

### Phase 1: Rewrite SQL Files
1. Rename all tables with `dc_` prefix
2. Remove custom tracking tables (unnecessary)
3. Keep only essential token tables
4. Add references to standard AC tables in comments
5. Use standard `creature_questrelation` and `creature_involvedrelation`

### Phase 2: Rewrite C++ Scripts
1. Use standard AC quest APIs
2. Query `creature_questrelation` (not custom tables)
3. Handle daily/weekly via quest_template flags (not custom code)
4. Award achievements via standard AC API
5. Award tokens via standard item API

### Phase 3: Update Configuration
1. CSV files remain for DBC extraction (don't change)
2. Remove server config CSV files (dc_achievements.csv, etc.)
3. Keep token CSV for reference

### Phase 4: Testing
1. Verify quest start/complete via standard AC system
2. Verify daily/weekly resets work automatically
3. Verify achievements award correctly
4. Verify tokens awarded and trackable

---

## ✅ SUMMARY

| Issue | Solution |
|-------|----------|
| Tables without `dc_` prefix | Rename all tables with `dc_` |
| Custom quest mapping | Use standard `creature_questrelation` |
| Custom progress tracking | Use standard `character_queststatus` |
| Custom daily/weekly resets | Use quest_template flags + AC auto-reset |
| Custom achievement tracking | Use standard `character_achievement` |
| CSV/DBC confusion | CSV files are for WDB extraction, not config |
| Quest completion tracking | Standard AC handles automatically |

**Result:** Simpler, cleaner, more compatible with AzerothCore! ✅

---

**Next Step:** Shall I regenerate all SQL files with these corrections?
