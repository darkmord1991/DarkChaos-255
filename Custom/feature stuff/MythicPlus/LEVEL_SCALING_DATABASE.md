# Mythic+ Level Scaling Configuration - Database Columns

## Overview

Added configurable level scaling columns to the `dc_dungeon_mythic_profile` table. This allows you to control exactly what level creatures become for each difficulty, per dungeon.

---

## New Database Columns

| Column Name | Type | Description | Example |
|-------------|------|-------------|---------|
| `heroic_level_normal` | TINYINT | Level for normal mobs in Heroic | 60 (Vanilla), 0 (keep original) |
| `heroic_level_elite` | TINYINT | Level for elite mobs in Heroic | 61 (Vanilla), 0 (keep original) |
| `heroic_level_boss` | TINYINT | Level for bosses in Heroic | 62 (Vanilla), 0 (keep original) |
| `mythic_level_normal` | TINYINT | Level for normal mobs in Mythic | 80 |
| `mythic_level_elite` | TINYINT | Level for elite mobs in Mythic | 81 |
| `mythic_level_boss` | TINYINT | Level for bosses in Mythic | 82 |

**Note:** Setting any column to `0` means "keep original level"

---

## Default Configuration

### Vanilla Dungeons
- **Heroic:** 60 (normal) / 61 (elite) / 62 (boss)
- **Mythic:** 80 (normal) / 81 (elite) / 82 (boss)

### TBC Dungeons
- **Heroic:** 0 (keep original ~70)
- **Mythic:** 80 (normal) / 81 (elite) / 82 (boss)

### WotLK Dungeons
- **Heroic:** 0 (keep original ~80)
- **Mythic:** 0 (keep original ~80)

---

## Installation Instructions

### For New Installations
The `dc_mythic_dungeons_world.sql` file already includes the new columns - just import it normally.

### For Existing Databases
Run this SQL file to add columns and populate with default values:

```bash
SOURCE K:/Dark-Chaos/DarkChaos-255/Custom/Custom feature SQLs/worlddb/dc_mythic_add_level_columns.sql
```

This will:
1. Add the 6 new columns to your existing table
2. Populate Vanilla dungeons with 60-62 (Heroic) and 80-82 (Mythic)
3. Populate TBC dungeons with 0 (Heroic) and 80-82 (Mythic)
4. Populate WotLK dungeons with 0 (both difficulties)

---

## New Reload Command

Added `.dc reload mythic` command to reload dungeon profiles without restarting the server.

### Usage
```
.dc reload mythic
```

**Aliases:**
- `.dc reload mythic`
- `.dc reload mythicplus`
- `.dc reload m+`

**Note:** This reloads the configuration from the database. Creatures already spawned in active instances will keep their old scaling. New creatures will use the updated values.

---

## Example: Customizing a Dungeon

Let's say you want Scarlet Monastery (map_id 189) to have different scaling:

```sql
UPDATE dc_dungeon_mythic_profile 
SET 
    heroic_level_normal = 65,  -- Make Heroic harder
    heroic_level_elite = 66,
    heroic_level_boss = 67,
    mythic_level_normal = 82,  -- Make everything boss-level in Mythic
    mythic_level_elite = 82,
    mythic_level_boss = 83,    -- Super boss!
    base_health_mult = 4.0,    -- Even more HP
    base_damage_mult = 2.5     -- More damage too
WHERE map_id = 189;
```

Then reload in-game:
```
.dc reload mythic
```

---

## How It Works

### Level Calculation Logic

1. **Normal Difficulty:** Always keeps original creature level (no changes)

2. **Heroic Difficulty:** Checks database values:
   - If `heroic_level_boss` > 0 AND creature is boss → use that level
   - Else if `heroic_level_elite` > 0 AND creature is elite → use that level
   - Else if `heroic_level_normal` > 0 → use that level
   - Else → keep original level (0 = keep original)

3. **Mythic Difficulty:** Same logic but uses `mythic_level_*` columns

### Multipliers Still Apply

The level columns only control **creature level**. HP and Damage multipliers are separate:
- Heroic: Always +15% HP, +10% Damage
- Mythic: Uses `base_health_mult` and `base_damage_mult` from database

---

## Testing Your Changes

### 1. Update Database
```sql
SOURCE K:/Dark-Chaos/DarkChaos-255/Custom/Custom feature SQLs/worlddb/dc_mythic_add_level_columns.sql
```

### 2. Rebuild Server
```bash
cd K:/Dark-Chaos/DarkChaos-255
./acore.sh compiler build
```

### 3. Test In-Game
```
.gm on
.dc difficulty mythic
.tele scarletmonastery
# Enter dungeon
.npc info
# Check creature level and HP
```

### 4. Make Changes and Reload
```sql
UPDATE dc_dungeon_mythic_profile SET mythic_level_normal = 81 WHERE map_id = 189;
```

Then in-game:
```
.dc reload mythic
# Reset instance
.instance unbind all
# Re-enter to see new scaling
```

---

## Query Examples

### View Current Scaling for All Dungeons
```sql
SELECT 
    map_id, 
    name,
    heroic_level_normal AS h_normal,
    heroic_level_elite AS h_elite,
    heroic_level_boss AS h_boss,
    mythic_level_normal AS m_normal,
    mythic_level_elite AS m_elite,
    mythic_level_boss AS m_boss,
    base_health_mult AS m_hp,
    base_damage_mult AS m_dmg
FROM dc_dungeon_mythic_profile
ORDER BY map_id;
```

### Find Dungeons Using Original Levels in Mythic
```sql
SELECT map_id, name 
FROM dc_dungeon_mythic_profile 
WHERE mythic_level_normal = 0;
```

### Update All Vanilla Dungeons at Once
```sql
UPDATE dc_dungeon_mythic_profile 
SET 
    heroic_level_normal = 60,
    mythic_level_normal = 80
WHERE map_id < 530;  -- Vanilla map IDs
```

---

## Benefits of This System

1. **Per-Dungeon Control:** Each dungeon can have unique scaling
2. **Database-Driven:** No code recompilation needed for level changes
3. **Hot Reload:** Use `.dc reload mythic` to test changes instantly
4. **Flexible:** Set to 0 to preserve original levels, or specify exact values
5. **Progression-Friendly:** Can make some dungeons harder than others

---

## Files Modified

- `dc_mythic_dungeons_world.sql` - Table schema updated
- `dc_mythic_add_level_columns.sql` - Migration script for existing DBs
- `MythicDifficultyScaling.h` - Added level columns to DungeonProfile struct
- `MythicDifficultyScaling.cpp` - Updated loading and calculation logic
- `cs_dc_addons.cpp` - Added `.dc reload mythic` command

---

**Last Updated:** November 14, 2025
**Status:** ✅ READY - Apply SQL migration and rebuild server
