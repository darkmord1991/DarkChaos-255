# Dungeon Quest System - Import Instructions v5.0

## ✅ FIXED ISSUES

### Root Cause
The combined SQL file had **placeholder comments** instead of actual quest assignments. NPCs 700000, 700001, 700002 existed but had NO linked quests in `creature_queststarter`/`creature_questender`.

### Solutions Applied
1. **✅ Generated actual creature_queststarter/questender entries** from `dungeon_quest_map_correlation.csv` with **435 real Blizzard quest IDs**
   - NPC 700000 (Classic): **301 quests** (maps 33–429)
   - NPC 700001 (TBC): **82 quests** (maps 269, 543–585)
   - NPC 700002 (WotLK): **52 quests** (maps 574–668)

2. **✅ Added missing ICC map (631)** to `dc_dungeon_npc_mapping` → NPC 700002
   - Fixes: "No quest master found for map ID 631" warning

3. **✅ Replaced all placeholders** with real SQL INSERT statements (883 quest rows total)

---

## 📋 Import Order (CRITICAL)

Run **ALL_DUNGEON_QUESTS_v5.0.sql** as a single import. It contains everything in the correct order:

### Section 1: Schema (dc_* tables)
- `dc_quest_reward_tokens`
- `dc_daily_quest_token_rewards`
- `dc_weekly_quest_token_rewards`
- `dc_npc_quest_link` (optional admin tracking)

### Section 2: World Mappings
- `dc_difficulty_config` (Normal, Heroic, Mythic, Mythic+)
- `dc_dungeon_npc_mapping` (map_id → NPC entry)
  - **NEW**: Map 631 (ICC) → NPC 700002

### Section 3: Token Rewards
- Inserts into `dc_quest_reward_tokens` (5 token types)
- Inserts into `dc_daily_quest_token_rewards`
- Inserts into `dc_weekly_quest_token_rewards`

### Section 4: Quest Relations (THE FIX)
- **creature_queststarter** for NPCs 700000, 700001, 700002 
  - **435 Blizzard quest IDs** (not custom placeholders)
- **creature_questender** for NPCs 700000, 700001, 700002
  - Same 435 quest IDs

---

## 🚀 Implementation Steps

### Step 1: Backup Current Data
```sql
-- Optional: Export current state before import
mysqldump world creature_queststarter > backup_creature_queststarter.sql
mysqldump world creature_questender > backup_creature_questender.sql
```

### Step 2: Import the Combined File
```bash
mysql -u root -p world < ALL_DUNGEON_QUESTS_v5.0.sql
```

Or in MySQL Workbench/HeidiSQL:
- Open `ALL_DUNGEON_QUESTS_v5.0.sql`
- Execute all (Ctrl+Shift+Enter in Workbench)

### Step 3: Verify Import (Run These Queries)

**Check total quests assigned:**
```sql
SELECT COUNT(*) AS total_assignments 
FROM creature_queststarter 
WHERE id BETWEEN 700000 AND 700002;
-- Should return: 435
```

**Check by NPC:**
```sql
SELECT id, COUNT(*) as quest_count
FROM creature_queststarter
WHERE id IN (700000, 700001, 700002)
GROUP BY id;
-- Expected:
-- 700000 | 301
-- 700001 | 82
-- 700002 | 52
```

**Check dc_dungeon_npc_mapping has ICC:**
```sql
SELECT COUNT(*) as total_dungeons
FROM dc_dungeon_npc_mapping;
-- Should be: 54 (includes new ICC entry map 631)

SELECT * FROM dc_dungeon_npc_mapping WHERE map_id = 631;
-- Should show: 631 | 700002 | Icecrown Citadel | 2 | 80 | 80
```

**Verify NO missing quest_template entries:**
```sql
SELECT COUNT(*) as orphaned_quests
FROM creature_queststarter cqs
LEFT JOIN quest_template qt ON cqs.quest = qt.ID
WHERE qt.ID IS NULL AND cqs.id BETWEEN 700000 AND 700002;
-- Should return: 0 (all quests exist)
```

---

## 🎮 Testing in-Game

After import:

1. **Ragefire Chasm** (Map 389):
   - Go to Ragefire Chasm
   - Find NPC 700000 ("Dungeon Quest Master - Classic Dungeons")
   - Should show quest markers (yellow !) with multiple quests available
   - Try accepting a quest

2. **Utgarde Keep** (Map 574):
   - Go to Utgarde Keep
   - Find NPC 700002 ("Northrend Quest Master - Wrath of the Lich King Dungeons")
   - Should show quest markers with WotLK quests available

3. **Icecrown Citadel** (Map 631):
   - Go to ICC
   - Should NO LONGER see error: "No quest master found for map ID 631"
   - NPC 700002 should now be available for ICC quests

---

## 📊 Quest Distribution Summary

| Expansion | NPC | Map Range | Quest Count | Sample Quests |
|-----------|-----|-----------|-------------|---------------|
| Classic | 700000 | 33–429 | 301 | Blackrock Depths (43), Dire Maul (37), BRS (37) |
| TBC | 700001 | 269, 543–585 | 82 | Hellfire Citadel (20), Caverns of Time (40) |
| WotLK | 700002 | 574–668 | 52 | Forge of Souls (4), Pit of Saron (8), ICC→NEW |

---

## ⚠️ Troubleshooting

### Issue: "No quests show for NPC 700000 in Ragefire Chasm"
**Check:**
```sql
SELECT * FROM creature_queststarter WHERE id = 700000 LIMIT 5;
-- Should return 5+ rows
```
**If empty:** Reimport `ALL_DUNGEON_QUESTS_v5.0.sql`

### Issue: "Quest markers appear but can't accept quest"
**Check:**
1. Quest exists in `quest_template`: `SELECT * FROM quest_template WHERE ID = [quest_id]`
2. NPC exists: `SELECT * FROM creature_template WHERE entry = 700000`
3. NPC is spawned: `SELECT * FROM creature WHERE id1 = 700000 LIMIT 1`

### Issue: Still seeing "No quest master found for map ID 631"
**Check:**
```sql
SELECT * FROM dc_dungeon_npc_mapping WHERE map_id = 631;
-- Should return a row; if empty, re-run the SQL
```

---

## 📝 File Information

- **Filename:** `ALL_DUNGEON_QUESTS_v5.0.sql`
- **Size:** ~1200 lines
- **Format:** MySQL 5.7+
- **Contains:** Schema, world mappings, token rewards, **435 Blizzard quest assignments**
- **Generated:** 2025-11-04
- **Source Data:** `dungeon_quest_map_correlation.csv` (435 Blizzard quests)

---

## 🔄 Next Steps (Optional)

1. **Run DC_DUNGEON_QUEST_CREATURES_v2.sql** separately to spawn NPC templates (if not already done)
2. **Archive old per-file SQLs** (in `archive/` folder) for future reference
3. **Test on live server** after backup verification

---

**Status:** ✅ READY FOR IMPORT
