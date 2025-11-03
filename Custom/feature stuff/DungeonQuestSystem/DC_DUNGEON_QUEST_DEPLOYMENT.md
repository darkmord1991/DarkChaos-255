#!/usr/bin/env markdown
# DC DUNGEON QUEST SYSTEM v2.0 - DEPLOYMENT GUIDE
# Complete Integration for DarkChaos-255

---

## 📋 QUICK OVERVIEW

**Status:** ✅ PRODUCTION READY  
**Files:** 4 SQL files (in `Custom/Custom feature SQLs/worlddb/`)  
**C++ Script:** 1 file (to be placed in `src/server/scripts/Custom/DC/`)  
**Deployment Time:** 30 minutes database + 1 hour testing  
**Database Schema:** Uses existing `creature_queststarter` and `creature_questender` tables  

---

## 📁 FILES INCLUDED

### SQL Files (Import in this order)

Located: `Custom/Custom feature SQLs/worlddb/`

1. **DC_DUNGEON_QUEST_SCHEMA_v2.sql** (Import FIRST)
   - Creates 4 custom tables with `dc_` prefix
   - dc_quest_reward_tokens
   - dc_daily_quest_token_rewards
   - dc_weekly_quest_token_rewards
   - dc_npc_quest_link (optional reference)

2. **DC_DUNGEON_QUEST_CREATURES_v2.sql** (Import SECOND)
   - Creates 53 quest master NPCs
   - Adds creature spawns (Orgrimmar, Shattrath, Dalaran)
   - Uses **creature_queststarter** for quest starters (NOT creature_questrelation)
   - Uses **creature_questender** for quest completers (NOT creature_involvedrelation)

3. **DC_DUNGEON_QUEST_TEMPLATES_v2.sql** (Import THIRD)
   - Creates quest templates
   - 4 daily quests (700101-700104) with 0x0800 flag
   - 4 weekly quests (700201-700204) with 0x1000 flag
   - 8+ sample dungeon quests

4. **DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql** (Import FOURTH)
   - Configures token rewards
   - Sets up daily/weekly mappings
   - Includes multiplier system

### C++ Script

Located: `src/server/scripts/Custom/DC/`

- **npc_dungeon_quest_master_v2.cpp**
  - Quest acceptance/completion handlers
  - Token reward logic
  - Achievement tracking

---

## 🚀 DEPLOYMENT STEPS

### STEP 1: Backup Your Database

```bash
mysqldump -u root -p world > backup_dc_$(date +%Y%m%d_%H%M%S).sql
```

**Verify:** Backup file created successfully and has reasonable size (50+ MB typical)

---

### STEP 2: Import SQL Files (IN ORDER)

Each file builds on the previous one.

#### Step 2A: Import Schema

```bash
mysql -u root -p world < Custom/Custom\ feature\ SQLs/worlddb/DC_DUNGEON_QUEST_SCHEMA_v2.sql
```

**Verify schema created:**
```sql
SHOW TABLES LIKE 'dc_%';
-- Expected: 4 tables (dc_quest_reward_tokens, dc_daily_quest_token_rewards, dc_weekly_quest_token_rewards, dc_npc_quest_link)
```

#### Step 2B: Import Creatures & Quest Linking

```bash
mysql -u root -p world < Custom/Custom\ feature\ SQLs/worlddb/DC_DUNGEON_QUEST_CREATURES_v2.sql
```

**Verify NPCs created:**
```sql
SELECT COUNT(*) FROM creature_template WHERE entry >= 700000 AND entry <= 700052;
-- Expected: 53
```

**Verify quest starters set up:**
```sql
SELECT COUNT(*) FROM creature_queststarter WHERE id >= 700000;
-- Expected: 8+ entries
```

**Verify quest enders set up:**
```sql
SELECT COUNT(*) FROM creature_questender WHERE id >= 700000;
-- Expected: 8+ entries
```

#### Step 2C: Import Quest Templates

```bash
mysql -u root -p world < Custom/Custom\ feature\ SQLs/worlddb/DC_DUNGEON_QUEST_TEMPLATES_v2.sql
```

**Verify quests created:**
```sql
SELECT COUNT(*) FROM quest_template WHERE ID >= 700101 AND ID <= 700708;
-- Expected: 16+ entries
```

**Verify daily quest flags:**
```sql
SELECT ID, Flags FROM quest_template WHERE ID >= 700101 AND ID <= 700104;
-- All should have Flags = 0x0800 (2048)
```

#### Step 2D: Import Token Rewards

```bash
mysql -u root -p world < Custom/Custom\ feature\ SQLs/worlddb/DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql
```

**Verify tokens:**
```sql
SELECT COUNT(*) FROM dc_quest_reward_tokens;
-- Expected: 5
```

---

### STEP 3: Copy C++ Script

Location where C++ script should go:

```bash
src/server/scripts/Custom/DC/npc_dungeon_quest_master_v2.cpp
```

**Action:** Copy the script to that location

---

### STEP 4: Build AzerothCore

```bash
./acore.sh compiler build
```

**Expected Output:**
- No errors related to DC scripts
- Compilation completes successfully
- "Dungeon Quest NPC System v2.0" should appear in logs

---

### STEP 5: Start World Server

```bash
./acore.sh run-worldserver
```

**Expected Logs:**
```
Loading Dungeon Quest NPC System v2.0...
Loaded custom quest masters: 53
Quest system initialized successfully
```

---

## ✅ VERIFICATION CHECKLIST

### Database Verification

- [ ] 4 dc_* tables exist in database
- [ ] 53 quest master NPCs created (entries 700000-700052)
- [ ] creature_queststarter has entries linking NPCs to quests
- [ ] creature_questender has entries linking NPCs to quest completion
- [ ] 16+ quest templates created (IDs 700101-700708)
- [ ] Daily quests have flag 0x0800
- [ ] Weekly quests have flag 0x1000
- [ ] 5 token types defined in dc_quest_reward_tokens
- [ ] Daily/weekly token mappings configured

### In-Game Verification

- [ ] Log into game world
- [ ] Navigate to Orgrimmar (quest master 700000)
- [ ] NPC is visible and clickable
- [ ] Can see quest giver icon on NPC
- [ ] Can accept a daily quest (700101-700104)
- [ ] Can accept a weekly quest (700201-700204)
- [ ] Can complete quest
- [ ] Receive token reward upon completion
- [ ] Achievement updates

### Daily/Weekly Reset Testing

- [ ] Accept a daily quest
- [ ] Set server time to next day (admin command or wait)
- [ ] Verify quest resets and can be accepted again
- [ ] Accept a weekly quest
- [ ] Verify weekly quest resets after 7 days

---

## 🔧 CUSTOMIZATION

### Adding More Quests

Edit `DC_DUNGEON_QUEST_TEMPLATES_v2.sql`:

```sql
INSERT INTO quest_template (ID, QuestLevel, MinLevel, LogTitle, QuestDescription, Flags, ...) 
VALUES (700709, 80, 70, 'New Dungeon Quest', 'Quest text here', 0, ...);
```

For daily quests: Set `Flags = 0x0800`  
For weekly quests: Set `Flags = 0x1000`  

### Changing Token Rewards

Edit `DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql`:

```sql
UPDATE dc_daily_quest_token_rewards 
SET token_count = 2, bonus_multiplier = 1.5 
WHERE quest_id = 700101;
```

### Adding New Quest Masters

Edit `DC_DUNGEON_QUEST_CREATURES_v2.sql`:

```sql
-- Add to creature_template
INSERT INTO creature_template (...) VALUES (700053, ...);

-- Add spawns
INSERT INTO creature (...) VALUES (...);

-- Link quests
INSERT INTO creature_queststarter VALUES (700053, 700701);
INSERT INTO creature_questender VALUES (700053, 700701);
```

---

## 🐛 TROUBLESHOOTING

### Problem: "Table doesn't exist" error during import

**Solution:** Ensure files are imported in order (1→2→3→4)

### Problem: "Unknown column" error

**Solution:** Verify your AzerothCore version supports the column names. Check with:
```sql
DESC quest_template;
```

### Problem: NPC doesn't appear in game

**Solution:** 
1. Verify NPC in database: `SELECT * FROM creature WHERE id = 700000;`
2. Check map/coordinates are valid
3. Restart worldserver after database changes

### Problem: "Quest not found" error

**Solution:**
1. Verify quest template exists: `SELECT * FROM quest_template WHERE ID = 700101;`
2. Verify quest linking: `SELECT * FROM creature_queststarter WHERE quest = 700101;`
3. Check quest flags are correct

### Problem: Tokens not awarded

**Solution:**
1. Verify C++ script is in correct location
2. Check server compiled successfully
3. Verify reward in `dc_daily_quest_token_rewards`
4. Check worldserver logs for errors

### Problem: Daily quests not resetting

**Solution:**
1. Verify quest has flag 0x0800: `SELECT Flags FROM quest_template WHERE ID = 700101;`
2. Check character's quest log for quest status
3. Wait 24 hours or restart server after setting correct server time

---

## 📊 TABLE REFERENCE

### quest_template Flags

```
0x0800 = 2048   = QUEST_FLAGS_DAILY      (Resets every 24 hours)
0x1000 = 4096   = QUEST_FLAGS_WEEKLY     (Resets every 7 days)
0x0000 = 0      = Normal quest           (No reset)
```

### DC Custom Tables

```sql
dc_quest_reward_tokens
  - token_item_id (PRIMARY KEY)
  - token_name (VARCHAR)
  - token_type (ENUM)

dc_daily_quest_token_rewards
  - quest_id (FOREIGN KEY to quest_template.ID)
  - token_item_id (FOREIGN KEY to dc_quest_reward_tokens)
  - token_count (TINYINT)
  - bonus_multiplier (FLOAT)

dc_weekly_quest_token_rewards
  - quest_id
  - token_item_id
  - token_count
  - bonus_multiplier

dc_npc_quest_link
  - npc_entry
  - quest_id
  - quest_type (ENUM 'daily', 'weekly', 'normal')
```

---

## 📝 DATABASE SCHEMA REFERENCE

Your DC system uses these STANDARD AzerothCore/Trinity tables:

- **creature_queststarter** - Links NPC entries to quest IDs (who STARTS the quest)
- **creature_questender** - Links NPC entries to quest IDs (who COMPLETES/ENDS the quest)
- **creature_template** - NPC definitions
- **creature** - NPC spawns
- **quest_template** - Quest definitions
- **quest_template_addon** - Additional quest settings
- **quest_request_items** - Quest request dialogue
- **quest_offer_reward** - Quest reward dialogue
- **character_queststatus** - Player quest progress (auto-managed)

NO custom modifications to these tables!

---

## 🎯 QUICK REFERENCE

### Daily Quest IDs
- 700101, 700102, 700103, 700104

### Weekly Quest IDs
- 700201, 700202, 700203, 700204

### Sample Dungeon Quest IDs
- 700701-700708

### Token Types
- 700001 = Explorer Token
- 700002 = Specialist Token
- 700003 = Legendary Token
- 700004 = Challenge Token
- 700005 = Speedrunner Token

### Quest Master NPCs
- 700000 = Classic Dungeons
- 700001 = Outland Dungeons
- 700002 = Northrend Dungeons
- 700003-700052 = Individual dungeon masters

---

## 📞 SUPPORT

### If Quest Won't Start
1. Check creature_queststarter table
2. Verify quest_template exists
3. Check NPC npcflag includes QUEST_GIVER (3)

### If Quest Won't Complete
1. Check creature_questender table
2. Verify objectives in quest_template
3. Check server logs for quest completion errors

### If Tokens Not Awarded
1. Verify C++ script compiled
2. Check dc_daily_quest_token_rewards table
3. Check item ID exists in item_template
4. Review server logs

### If Daily/Weekly Reset Broken
1. Verify quest flags (0x0800, 0x1000)
2. Check server time is correct
3. Verify character_queststatus cleared on reset
4. Check worldserver log for reset events

---

## ✨ DEPLOYMENT COMPLETE!

When all steps are done:

1. ✅ All 4 SQL files imported in order
2. ✅ C++ script copied to correct location  
3. ✅ AzerothCore rebuilt
4. ✅ Worldserver started successfully
5. ✅ Verification checklist passed

**Your system is ready for production!**

---

**Version:** 2.0  
**Updated:** November 2, 2025  
**Tables Used:** creature_queststarter / creature_questender (DarkChaos standards)  
**Status:** PRODUCTION READY
