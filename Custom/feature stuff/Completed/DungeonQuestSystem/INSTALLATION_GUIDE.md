# 🚀 DUNGEON QUEST SYSTEM v4.0 - COMPLETE INSTALLATION GUIDE

**DarkChaos-255 Server - Extended Dungeon Quest System**

---

## 📋 System Overview

This extension adds to your existing dungeon quest system:
- ✅ **98 New Achievements** (IDs 10800-10999) with 20 titles
- ✅ **66 New Quests** (50 daily + 24 weekly) expanding from 8 to 74 total
- ✅ **4-Tier Difficulty System** (Normal, Heroic, Mythic, Mythic+) - Infrastructure only
- ✅ **Token Reward Multipliers** (1.0x → 3.0x based on difficulty)
- ✅ **Streak Tracking** for daily/weekly quests
- ✅ **NPC Spawns** in 4 major cities

---

## 📁 File Inventory

### SQL Extension Files (Execute in Order):
1. `EXTENSION_01_difficulty_support.sql` - Difficulty infrastructure (4 tables)
2. `EXTENSION_02_expanded_quest_pool.sql` - Quest expansion (66 new quests)
3. `EXTENSION_03_dungeon_quest_achievements.sql` - Achievements + titles
4. `EXTENSION_04_npc_spawns.sql` - NPC spawns in major cities

### DBC Files:
5. `ACHIEVEMENT_CSV_ENTRIES.txt` - Achievement entries for Achievement.dbc
6. `Custom/CSV DBC/Achievement.csv` - **UPDATED** with 98 new entries

### Documentation:
7. `CPP_INTEGRATION_GUIDE.md` - C++ code for difficulty/achievements
8. `EXTENSION_v4.0_SUMMARY.md` - Complete system summary
9. `DUNGEON_QUEST_REFERENCE.md` - Quick reference for adjustments
10. `INTEGRATION_WITH_EXISTING_SYSTEM.md` - Integration strategy

---

## 🔧 PHASE 1: SQL DATABASE INSTALLATION

### Step 1.1: Backup Your Database

**CRITICAL**: Always backup before making changes!

```sql
-- MySQL backup command (run in command line)
mysqldump -u root -p acore_world > backup_world_pre_dungeon_v4.sql
mysqldump -u root -p acore_characters > backup_characters_pre_dungeon_v4.sql
```

### Step 1.2: Execute SQL Extensions

**Execute in this exact order:**

#### Extension 1: Difficulty Support
```bash
# Location: Custom/feature stuff/DungeonQuestSystem/
mysql -u root -p acore_world < EXTENSION_01_difficulty_support.sql
```

**What this does:**
- Creates `dc_difficulty_config` table (4 difficulties with multipliers)
- Creates `dc_quest_difficulty_mapping` table (quest → difficulty mapping)
- Creates `dc_character_difficulty_completions` table (per-player tracking)
- Creates `dc_character_difficulty_streaks` table (streak tracking)
- Adds `difficulty` column to existing `dc_dungeon_quest_mapping`
- Extends `dc_character_dungeon_statistics` for flexible stat tracking

**Expected Output:**
```
Query OK, 4 rows affected (Difficulty config inserted)
Query OK, 70 rows affected (Quest difficulty mappings)
```

#### Extension 2: Expanded Quest Pool
```bash
mysql -u root -p acore_world < EXTENSION_02_expanded_quest_pool.sql
```

**What this does:**
- Inserts 46 new daily quests (700105-700150)
- Inserts 20 new weekly quests (700205-700224)
- Maps all to difficulty tiers with token rewards
- Uses existing `dc_daily_quest_token_rewards` and `dc_weekly_quest_token_rewards` tables

**Expected Output:**
```
Query OK, 46 rows affected (Daily quest rewards)
Query OK, 24 rows affected (Weekly quest rewards)
Query OK, 70 rows affected (Difficulty mappings)
```

#### Extension 3: Achievements + Titles
```bash
mysql -u root -p acore_world < EXTENSION_03_dungeon_quest_achievements.sql
```

**What this does:**
- Inserts 98 achievements (IDs 10800-10999)
- Creates 20 titles (IDs 126-145)
- Uses existing category 10004 (DarkChaos Custom)

**Expected Output:**
```
Query OK, 98 rows affected (Achievement_dbc entries)
Query OK, 20 rows affected (CharTitles_dbc entries)
```

#### Extension 4: NPC Spawns
```bash
mysql -u root -p acore_world < EXTENSION_04_npc_spawns.sql
```

**What this does:**
- Spawns NPC 700003 (Quest Herald) in:
  * Stormwind (Trade District)
  * Orgrimmar (Valley of Strength)
  * Dalaran (Runeweaver Square)
  * Shattrath (Terrace of Light)

**Expected Output:**
```
Query OK, 4 rows affected (Creature spawns)
```

### Step 1.3: Verify SQL Installation

Run this query to check everything:

```sql
-- Check tables exist
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME LIKE 'dc_%' 
ORDER BY TABLE_NAME;

-- Expected output: 11 tables
-- dc_character_difficulty_completions
-- dc_character_difficulty_streaks
-- dc_character_dungeon_progress
-- dc_character_dungeon_statistics
-- dc_daily_quest_token_rewards
-- dc_difficulty_config
-- dc_dungeon_quest_mapping
-- dc_player_daily_quest_progress
-- dc_player_weekly_quest_progress
-- dc_quest_difficulty_mapping
-- dc_quest_reward_tokens
-- dc_weekly_quest_token_rewards

-- Check quest counts
SELECT 
    'Daily Quests' AS type, COUNT(*) AS count 
FROM dc_daily_quest_token_rewards
UNION ALL
SELECT 
    'Weekly Quests' AS type, COUNT(*) AS count 
FROM dc_weekly_quest_token_rewards
UNION ALL
SELECT 
    'Difficulty Configs' AS type, COUNT(*) AS count 
FROM dc_difficulty_config
UNION ALL
SELECT 
    'Achievements' AS type, COUNT(*) AS count 
FROM achievement_dbc 
WHERE entry BETWEEN 10800 AND 10999;

-- Expected output:
-- Daily Quests: 50
-- Weekly Quests: 24
-- Difficulty Configs: 4
-- Achievements: 98

-- Check NPC spawns
SELECT 
    guid,
    id1,
    CASE
        WHEN map = 0 AND zoneId = 1519 THEN 'Stormwind'
        WHEN map = 1 AND zoneId = 1637 THEN 'Orgrimmar'
        WHEN map = 571 AND zoneId = 4395 THEN 'Dalaran'
        WHEN map = 530 AND zoneId = 3703 THEN 'Shattrath'
    END AS city
FROM creature
WHERE id1 = 700003;

-- Expected output: 4 rows (one per city)
```

---

## 🎨 PHASE 2: DBC FILE GENERATION

### Step 2.1: Verify Achievement.csv Updated

The achievements were automatically appended to `Custom/CSV DBC/Achievement.csv` during implementation.

**Verify:**
```powershell
cd "C:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255\Custom\CSV DBC"
Get-Content Achievement.csv | Select-String "^\"10[89][0-9]{2}\""
```

**Expected Output:** Should show 98 achievement lines (10800-10999)

### Step 2.2: Rebuild Achievement.dbc

**Use your DBC building tool** to convert Achievement.csv → Achievement.dbc

Example using common DBC tools:
```bash
# If using csv2dbc or similar
csv2dbc.exe Achievement.csv Achievement.dbc

# Or use your server's DBC build process
./build_dbcs.sh
```

### Step 2.3: Copy DBC to Server

```bash
# Copy to your server's DBC folder
cp Achievement.dbc /path/to/server/dbc/
# Or on Windows:
copy Achievement.dbc "C:\AzerothCore\dbc\"
```

### Step 2.4: Client DBC Patching

**For players to see achievements in-game:**

1. Copy `Achievement.dbc` to client DBC folder:
   ```
   World of Warcraft/Data/enUS/DBFilesClient/Achievement.dbc
   ```

2. Create MPQ patch (recommended for distribution):
   ```bash
   # Using MPQEditor or similar
   # Add Achievement.dbc to patch-Z.MPQ
   # Place in WoW/Data/ folder
   ```

---

## ⚙️ PHASE 3: C++ CODE INTEGRATION (Optional - For Difficulty Filtering)

**⚠️ NOTE:** Difficulty infrastructure is in place but NOT active yet per your request.
Run this phase only when ready to activate difficulty multipliers and achievement tracking.

### Step 3.1: Update DungeonQuestSystem.cpp

Location: `src/server/scripts/DC/DungeonQuests/DungeonQuestSystem.cpp`

**Follow:** `CPP_INTEGRATION_GUIDE.md` for detailed code snippets

**Key changes:**
1. Add difficulty enum and constants (lines 30-45)
2. Add helper functions to DungeonQuestDB class (lines 50-200)
3. Update HandleTokenRewards function (lines 200-280)
4. Update CheckAchievements function (lines 280-400)

### Step 3.2: Update npc_dungeon_quest_daily_weekly.cpp

Location: `src/server/scripts/DC/DungeonQuests/npc_dungeon_quest_daily_weekly.cpp`

**Add streak tracking** to CheckDailyQuestReset function (see guide lines 10-40)

### Step 3.3: Compile Server

```bash
cd /path/to/azerothcore/build
cmake --build . --config RelWithDebInfo --target all
```

**Expected Output:**
```
[100%] Built target worldserver
Build succeeded
```

### Step 3.4: Restart Server

```bash
./acore.sh run-worldserver
```

**Check logs for:**
```
DungeonQuest: Difficulty system initialized
DungeonQuest: Achievement tracking enabled
```

---

## ✅ PHASE 4: TESTING & VERIFICATION

### Test 1: NPC Visibility

**In-game:**
1. Log in to test character
2. Go to Stormwind Trade District (Alliance) OR Orgrimmar Valley of Strength (Horde)
3. Look for "Quest Herald" NPC near the bank
4. Right-click to open gossip

**Expected:** NPC visible, gossip menu shows daily/weekly quest options

### Test 2: Quest Availability

**SQL Check:**
```sql
-- Check which quests are available today (Monday = 1, Sunday = 7)
SELECT 
    q.quest_id,
    q.quest_name,
    q.tokens_reward,
    d.difficulty,
    d.token_multiplier
FROM dc_daily_quest_token_rewards q
JOIN dc_quest_difficulty_mapping d ON q.quest_id = d.quest_id
WHERE DAYOFWEEK(NOW()) = 1 -- Monday
ORDER BY q.quest_id;
```

**Expected:** 5 quests for Monday (700101-700105)

### Test 3: Quest Completion & Tokens

**In-game test:**
1. Accept daily quest from Quest Herald
2. Complete quest objectives
3. Turn in quest
4. Check token rewards

**Expected (if C++ active):**
- Normal: Base tokens (e.g., 5 tokens)
- Heroic: Base × 1.5 (e.g., 7 tokens)
- Mythic: Base × 2.0 (e.g., 10 tokens)
- Mythic+: Base × 3.0 (e.g., 15 tokens)

### Test 4: Achievement Unlocks

**SQL Check:**
```sql
-- Check if achievement 10800 (First Steps) was awarded
SELECT 
    a.guid,
    c.name AS character_name,
    a.achievement,
    FROM_UNIXTIME(a.date) AS unlock_date
FROM character_achievement a
JOIN characters c ON a.guid = c.guid
WHERE a.achievement = 10800;
```

**In-game:** Complete 1 quest, should unlock "First Steps" achievement

### Test 5: Streak Tracking

**SQL Check:**
```sql
-- Check daily streak for player
SELECT 
    stat_name,
    stat_value,
    last_update
FROM dc_character_dungeon_statistics
WHERE guid = <PLAYER_GUID>
  AND stat_name LIKE '%streak%';
```

**Expected:** `daily_streak_current` increments each day quests completed

---

## 📊 PHASE 5: MONITORING & ADJUSTMENT

### Monitor Quest Distribution

```sql
-- Daily quest completion heatmap
SELECT 
    DAYOFWEEK(FROM_UNIXTIME(completion_time)) AS day_of_week,
    COUNT(*) AS completions
FROM dc_player_daily_quest_progress
GROUP BY day_of_week
ORDER BY day_of_week;

-- Most popular quests
SELECT 
    quest_id,
    COUNT(*) AS completion_count
FROM dc_player_daily_quest_progress
GROUP BY quest_id
ORDER BY completion_count DESC
LIMIT 10;
```

### Adjust Token Rewards

**If quests too easy/hard:**

```sql
-- Increase daily quest tokens by 50%
UPDATE dc_daily_quest_token_rewards 
SET tokens_reward = tokens_reward * 1.5 
WHERE quest_id BETWEEN 700101 AND 700150;

-- Adjust difficulty multipliers
UPDATE dc_difficulty_config 
SET token_multiplier = 2.5 
WHERE difficulty_id = 3; -- Mythic
```

### Disable/Enable Quests

```sql
-- Temporarily disable a quest
UPDATE dc_quest_difficulty_mapping 
SET enabled = 0 
WHERE quest_id = 700105;

-- Re-enable
UPDATE dc_quest_difficulty_mapping 
SET enabled = 1 
WHERE quest_id = 700105;
```

---

## 🔍 TROUBLESHOOTING

### Issue: NPCs Not Spawning

**Check:**
```sql
SELECT * FROM creature WHERE id1 = 700003;
```

**If empty:**
```bash
# Re-run EXTENSION_04_npc_spawns.sql
mysql -u root -p acore_world < EXTENSION_04_npc_spawns.sql
```

**In-game:**
```
.npc add 700003
```

### Issue: Achievements Not Showing

**Check DBC loaded:**
```sql
SELECT * FROM achievement_dbc WHERE entry = 10800;
```

**If empty:**
- Rebuild Achievement.dbc from CSV
- Copy to server dbc folder
- Restart server

**Client-side:**
- Copy Achievement.dbc to client DBC folder
- Restart WoW client

### Issue: No Token Rewards

**Check token item exists:**
```sql
SELECT * FROM item_template WHERE entry = (
    SELECT token_item_id FROM dc_quest_reward_tokens LIMIT 1
);
```

**Check C++ active:**
```bash
# Search server logs
grep "DungeonQuest: Awarded" worldserver.log
```

**If no logs:** C++ code not integrated yet (Phase 3 needed)

### Issue: Difficulty Not Showing

**Expected:** Difficulty infrastructure exists but NOT filtering yet

**To activate:**
- Complete Phase 3 (C++ Integration)
- Modify C++ code to query `dc_quest_difficulty_mapping`
- Recompile and restart

---

## 📝 POST-INSTALLATION CHECKLIST

- [ ] SQL extensions 1-4 executed successfully
- [ ] 98 achievements added to Achievement.csv
- [ ] Achievement.dbc rebuilt and deployed
- [ ] NPC 700003 spawns in 4 cities
- [ ] Daily quests rotate correctly (check Monday-Sunday)
- [ ] Weekly quests rotate correctly (check 4-week cycle)
- [ ] Token rewards awarded on quest completion
- [ ] Achievements unlock at milestones
- [ ] Streak tracking increments daily
- [ ] C++ code integrated (if activating difficulty)
- [ ] Server logs show no errors
- [ ] In-game testing completed

---

## 🎯 WHAT'S NEXT?

### Immediate Use (Ready Now):
✅ 74 total quests (50 daily + 24 weekly) available
✅ NPC in 4 major cities for easy access
✅ 98 achievements tracking progress
✅ Difficulty infrastructure in place

### Future Activation:
⏳ **Difficulty Filtering:** Complete Phase 3 (C++ Integration)
⏳ **Mythic+ Quests:** Change `enabled=1` in dc_difficulty_config
⏳ **Custom Rewards:** Adjust token amounts and multipliers
⏳ **New Dungeons:** Add entries to mapping tables

### Customization:
📖 **Reference Guide:** `DUNGEON_QUEST_REFERENCE.md`
📖 **Summary:** `EXTENSION_v4.0_SUMMARY.md`
📖 **Integration:** `INTEGRATION_WITH_EXISTING_SYSTEM.md`

---

## 📞 SUPPORT & DOCUMENTATION

**Files Created:**
- `EXTENSION_01_difficulty_support.sql` - Difficulty tables
- `EXTENSION_02_expanded_quest_pool.sql` - Quest expansion
- `EXTENSION_03_dungeon_quest_achievements.sql` - Achievements
- `EXTENSION_04_npc_spawns.sql` - NPC spawns
- `CPP_INTEGRATION_GUIDE.md` - C++ code snippets
- `ACHIEVEMENT_CSV_ENTRIES.txt` - CSV entries
- `EXTENSION_v4.0_SUMMARY.md` - Complete summary
- `DUNGEON_QUEST_REFERENCE.md` - Quick reference
- `INTEGRATION_WITH_EXISTING_SYSTEM.md` - Integration guide
- **THIS FILE** - Installation guide

**Need Help?**
- Check `DUNGEON_QUEST_REFERENCE.md` for quick adjustments
- Review `CPP_INTEGRATION_GUIDE.md` for code examples
- Use diagnostic queries in `EXTENSION_v4.0_SUMMARY.md`

---

## 🎊 INSTALLATION COMPLETE!

Your DarkChaos-255 server now has:
- **74 Dungeon Quests** (up from 8)
- **98 Achievements** (10800-10999)
- **20 Titles** (126-145)
- **4-Tier Difficulty System** (infrastructure ready)
- **Token Multipliers** (1.0x - 3.0x)
- **Streak Tracking** (daily/weekly)
- **4 City NPC Spawns** (Stormwind, Orgrimmar, Dalaran, Shattrath)

**Enjoy your enhanced dungeon quest system!** 🚀
