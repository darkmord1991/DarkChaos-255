# Mythic+ Database Setup - Execution Order
**Date**: November 15, 2025

## ⚠️ CRITICAL: Execution Order

The SQL files **MUST** be executed in this exact order due to foreign key dependencies:

### Step 1: Create Season 1 (REQUIRED FIRST)
```sql
SOURCE k:/Dark-Chaos/DarkChaos-255/Custom/Custom feature SQLs/worlddb/Mythic+/00_CREATE_SEASON_1.sql;
```

**Why**: This creates the `dc_mplus_seasons` entry (season_id = 1) that is referenced by:
- `dc_mplus_featured_dungeons.season_id` (FK constraint)
- `dc_mplus_affix_schedule.season_id` (FK constraint)

**Creates**:
- Season 1: "Season 1: Wrath of Winter"
- Start: 2025-01-01
- End: 2026-01-01  
- 10 featured dungeons (WotLK)
- 12-week affix rotation
- Reward curve for M+2-M+20
- Status: ACTIVE

### Step 2: Create Missing Tables & Seed Data
```sql
SOURCE k:/Dark-Chaos/DarkChaos-255/Custom/Custom feature SQLs/worlddb/Mythic+/00_MISSING_TABLES_FIX.sql;
```

**Creates**:
- `dc_dungeon_entrances` (15 WotLK dungeon portals)
- `dc_mplus_featured_dungeons` (10 Season 1 dungeons)
- `dc_mplus_affix_schedule` (12-week rotation)
- `dc_mplus_final_bosses` (15 final boss entries)

**Seed Data**:
- 15 dungeon entrance coordinates (Northrend)
- 10 featured dungeons for Season 1
- 15 final boss creature entries
- 12 weeks of affix combinations

### Step 3: Spawn Statistics NPC
```sql
SOURCE k:/Dark-Chaos/DarkChaos-255/Custom/Custom feature SQLs/worlddb/Mythic+/npc_spawn_statistics.sql;
```

**Creates**:
- Archivist Serah (entry 100060)
- Location: Dalaran, Krasus' Landing
- Gossip menu with 3 views
- Creature template with model 30259

## Foreign Key Dependencies

### dc_mplus_featured_dungeons
```
season_id → dc_mplus_seasons.season_id (FK)
map_id → dc_dungeon_mythic_profile.map_id (FK)
```

### dc_mplus_affix_schedule
```
season_id → dc_mplus_seasons.season_id (FK)
```

### dc_mplus_final_bosses
```
map_id → dc_dungeon_mythic_profile.map_id (FK)
```

### dc_dungeon_entrances
```
dungeon_map → dc_dungeon_mythic_profile.map_id (FK)
```

## Error Prevention

### If Season 1 Not Created First:
```
SQL-Fehler (1452): Cannot add or update a child row: 
a foreign key constraint fails (`acore_world`.`dc_mplus_featured_dungeons`, 
CONSTRAINT `dc_mplus_featured_dungeons_ibfk_1` FOREIGN KEY (`season_id`) 
REFERENCES `dc_mplus_seasons` (`season_id`) ON DELETE CASCADE)
```

**Solution**: Always run `00_CREATE_SEASON_1.sql` first!

### If dc_dungeon_mythic_profile Missing:
```
SQL-Fehler (1452): Cannot add or update a child row: 
a foreign key constraint fails (`acore_world`.`dc_mplus_final_bosses`, 
CONSTRAINT `dc_mplus_final_bosses_ibfk_1` FOREIGN KEY (`map_id`) 
REFERENCES `dc_dungeon_mythic_profile` (`map_id`) ON DELETE CASCADE)
```

**Solution**: Run `dc_mythic_dungeons_world.sql` first (usually already in schema)

## Verification Queries

### Check Season 1 Exists
```sql
SELECT 
    season_id, 
    label, 
    FROM_UNIXTIME(start_ts) AS start_date,
    FROM_UNIXTIME(end_ts) AS end_date,
    is_active
FROM dc_mplus_seasons 
WHERE season_id = 1;
```

**Expected**: 1 row with "Season 1: Wrath of Winter", is_active = 1

### Check Featured Dungeons
```sql
SELECT 
    fd.season_id,
    fd.map_id,
    dmp.name AS dungeon_name,
    fd.sort_order
FROM dc_mplus_featured_dungeons fd
JOIN dc_dungeon_mythic_profile dmp ON fd.map_id = dmp.map_id
WHERE fd.season_id = 1
ORDER BY fd.sort_order;
```

**Expected**: 10 rows (Utgarde Keep through Ahn'kahet)

### Check Affix Schedule
```sql
SELECT 
    season_id,
    week_number,
    affix1,
    affix2
FROM dc_mplus_affix_schedule
WHERE season_id = 1
ORDER BY week_number;
```

**Expected**: 12 rows (weeks 0-11)

### Check Final Bosses
```sql
SELECT 
    fb.map_id,
    dmp.name AS dungeon_name,
    fb.boss_entry,
    ct.name AS boss_name
FROM dc_mplus_final_bosses fb
JOIN dc_dungeon_mythic_profile dmp ON fb.map_id = dmp.map_id
LEFT JOIN creature_template ct ON fb.boss_entry = ct.entry
ORDER BY fb.map_id;
```

**Expected**: 15 rows (all WotLK dungeon final bosses)

### Check Dungeon Entrances
```sql
SELECT 
    de.dungeon_map,
    dmp.name AS dungeon_name,
    de.entrance_map,
    de.entrance_x,
    de.entrance_y,
    de.entrance_z
FROM dc_dungeon_entrances de
JOIN dc_dungeon_mythic_profile dmp ON de.dungeon_map = dmp.map_id
ORDER BY de.dungeon_map;
```

**Expected**: 15 rows (all entrance coordinates)

### Check Statistics NPC
```sql
SELECT 
    entry,
    name,
    subname,
    modelid1,
    gossip_menu_id,
    ScriptName
FROM creature_template
WHERE entry = 100060;
```

**Expected**: 1 row (Archivist Serah with model 30259)

### Check NPC Spawn
```sql
SELECT 
    guid,
    id1,
    map,
    position_x,
    position_y,
    position_z,
    orientation
FROM creature
WHERE id1 = 100060;
```

**Expected**: 1 row (GUID 9000060 in Dalaran, map 571)

## Rollback (If Needed)

```sql
-- Remove Season 1 (cascades to featured_dungeons and affix_schedule)
DELETE FROM dc_mplus_seasons WHERE season_id = 1;

-- Remove entrance data
DELETE FROM dc_dungeon_entrances WHERE dungeon_map IN (574,575,576,578,595,599,600,601,602,604,608,619,632,658,668);

-- Remove final boss data
DELETE FROM dc_mplus_final_bosses WHERE map_id IN (574,575,576,578,595,599,600,601,602,604,608,619,632,658,668);

-- Remove Statistics NPC
DELETE FROM creature WHERE id1 = 100060;
DELETE FROM creature_template WHERE entry = 100060;
DELETE FROM gossip_menu WHERE MenuID = 100060;
DELETE FROM npc_text WHERE ID = 100060;
```

## Table Row Counts (After Setup)

| Table | Rows Added | Total Expected |
|-------|-----------|----------------|
| dc_mplus_seasons | 1 | 1 |
| dc_mplus_featured_dungeons | 10 | 10 |
| dc_mplus_affix_schedule | 12 | 12 |
| dc_mplus_final_bosses | 15 | 15 |
| dc_dungeon_entrances | 15 | 15 |
| creature_template (100060) | 1 | 1 |
| creature (100060 spawn) | 1 | 1 |
| gossip_menu (100060) | 1 | 1 |
| npc_text (100060) | 1 | 1 |

## MySQL 8.0 Deprecation Fixes

All `VALUES()` functions in `ON DUPLICATE KEY UPDATE` have been replaced with column references to avoid deprecation warnings:

- ❌ `ON DUPLICATE KEY UPDATE entrance_x=VALUES(entrance_x)`
- ✅ `ON DUPLICATE KEY UPDATE entrance_map=entrance_map`

## Model ID Fix

Changed Statistics NPC model from **25921** (invalid) to **30259** (valid human female model).

## Season 1 Details

**Featured Dungeons** (10 WotLK):
1. Utgarde Keep (574)
2. Utgarde Pinnacle (575)
3. The Nexus (576)
4. The Oculus (578)
5. Halls of Stone (599)
6. Drak'Tharon Keep (600)
7. Azjol-Nerub (601)
8. Halls of Lightning (602)
9. Violet Hold (608)
10. Ahn'kahet: The Old Kingdom (619)

**Affix Rotation**:
- Weeks 0-3: Tyrannical-Lite (1) + Bolstering-Lite (4)
- Weeks 4-7: Brutal Aura (2) + Fortified-Lite (3)
- Weeks 8-11: Tyrannical-Lite (1) + Fortified-Lite (3)

**Reward Curve**: M+2 (219 ilvl, 25 tokens) → M+20 (273 ilvl, 115 tokens)

---
**Last Updated**: November 15, 2025  
**Status**: Ready for execution
