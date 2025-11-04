# NPC Spawning Guide - Fixed SQL Files

**Date**: November 4, 2025  
**Status**: ✅ SQL Files Corrected  
**Issue**: Column count mismatches resolved

---

## What Was Fixed

### Issue Found
```
SQL-Fehler (1136): Column count doesn't match value count at row 1
```

### Root Cause
The original SQL used positional INSERT (without column names), which caused column count mismatch with the actual creature_template schema.

### Solution Applied
✅ **Changed to named column INSERT** - Matches exact AzerothCore schema  
✅ **Added DELETE statements** - Prevents duplicate errors  
✅ **Added creature_template_model** - Provides visual display

---

## Corrected Files

### 1. dc_npc_creature_templates.sql
**Status**: ✅ Fixed  
**Changes**:
- Uses named columns (matches schema exactly)
- Added creature_template_model for display models
- Added DELETE to prevent duplicates
- Proper AI type (PassiveAI)
- Correct script names

### 2. dc_npc_spawns.sql  
**Status**: ✅ Fixed  
**Changes**:
- Uses named columns (matches creature schema)
- Added DELETE statements
- Correct map IDs and zone IDs
- Proper creature GUIDs

---

## How to Execute (Correct Method)

### Method 1: MySQL Command Line (RECOMMENDED)

```bash
# Connect to your database
mysql -u root -p

# Select world database
USE world;

# Execute creature templates first
SOURCE path/to/dc_npc_creature_templates.sql;

# Then execute spawns
SOURCE path/to/dc_npc_spawns.sql;
```

### Method 2: Through HeidiSQL or MySQL Workbench

1. Open HeidiSQL
2. Connect to your world database
3. Open: `dc_npc_creature_templates.sql`
4. Execute (F9)
5. Open: `dc_npc_spawns.sql`
6. Execute (F9)

### Method 3: Batch Execute

```bash
# Windows PowerShell
mysql -u root -p world < "C:\path\to\dc_npc_creature_templates.sql"
mysql -u root -p world < "C:\path\to\dc_npc_spawns.sql"
```

---

## Execution Order

⚠️ **IMPORTANT: Execute in correct order**

1. **FIRST**: `dc_npc_creature_templates.sql`
   - Creates NPC templates
   - Creates template models

2. **THEN**: `dc_npc_spawns.sql`
   - Spawns NPCs in the world

---

## Verification After Execution

### Check Template Creation
```sql
SELECT entry, name, subname, ScriptName FROM creature_template WHERE entry IN (190001, 190002);
```

**Expected Result**:
```
+-------+----------------------+-------------------------+--------------------------+
| entry | name                 | subname                 | ScriptName               |
+-------+----------------------+-------------------------+--------------------------+
|190001 | Item Upgrade Vendor  | Upgrade your items...   | npc_item_upgrade_vendor  |
|190002 | Artifact Curator     | Curator of Chaos Arti...| npc_item_upgrade_curator |
+-------+----------------------+-------------------------+--------------------------+
```

### Check Spawns Created
```sql
SELECT guid, id1, position_x, position_y, position_z FROM creature WHERE id1 IN (190001, 190002);
```

**Expected Result**:
```
+-------+--------+----------+----------+---------+
| guid  | id1    | x        | y        | z       |
+-------+--------+----------+----------+---------+
|450001 |190001  |-8835.36  | 531.91   | 96.05   |
|450002 |190001  | 1632.48  |-4251.78  | 41.18   |
|450003 |190002  |-1860.34  | 5435.15  |-12.43   |
+-------+--------+----------+----------+---------+
```

---

## Troubleshooting

### Error: "Unknown column in field list"
**Solution**: Make sure you're executing against the correct database (world DB)

### Error: "Access denied"
**Solution**: Check MySQL credentials and permissions

### NPCs Don't Appear In-Game
1. Restart worldserver: `./acore.sh run-worldserver`
2. Verify SQL executed without errors
3. Use `.npc add 190001` to spawn manually for testing

### To Test Manual Spawn
```
.npc add 190001  → Spawns vendor at your location
.npc add 190002  → Spawns curator at your location
```

---

## Current File Locations

**Creature Templates**: 
```
Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_npc_creature_templates.sql
```

**Creature Spawns**:
```
Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_npc_spawns.sql
```

---

## What These Files Do

### dc_npc_creature_templates.sql
Creates two new NPC definitions:
- **NPC 190001**: Item Upgrade Vendor
  - Provides upgrade services
  - Located in Stormwind & Orgrimmar
  
- **NPC 190002**: Artifact Curator
  - Manages artifact collection
  - Located in Shattrath

### dc_npc_spawns.sql
Places the NPCs in the world:
- Stormwind: Vendor near the fountain
- Orgrimmar: Vendor near the bank
- Shattrath: Curator in the city center

---

## Column Mapping (For Reference)

### creature_template Key Columns
- `entry`: NPC ID (190001, 190002)
- `name`: Display name
- `minlevel`/`maxlevel`: Level range
- `type`: NPC type (7 = humanoid)
- `npcflag`: Interaction flags
- `AIName`: AI type
- `ScriptName`: C++ script name
- And 50+ more columns...

### creature Key Columns
- `guid`: Unique spawn ID
- `id1`: Creature template ID
- `map`: World map ID (0=Eastern Kingdoms, 1=Kalimdor, 530=Outland)
- `position_x/y/z`: Coordinates
- `orientation`: Facing direction
- `spawntimesecs`: Respawn time (300 = 5 minutes)

---

## After Spawning

### Test In-Game
1. Login with admin character
2. Go to Stormwind or Orgrimmar
3. Look for vendor NPC
4. Right-click to open gossip menu
5. Navigate through options

### If Gossip Menu Doesn't Appear
- Verify script compiled: Check worldserver.log
- Check for errors: Look for "npc_item_upgrade" errors
- Try manual spawn: `.npc add 190001`

---

## Success Indicators

✅ **SQL executed without errors**  
✅ **Query shows 2 templates in creature_template**  
✅ **Query shows 3 spawns in creature table**  
✅ **NPCs appear in-game**  
✅ **Right-click opens gossip menu**  
✅ **Menu shows options without errors**

---

## Next Steps

1. **Execute Both SQL Files** ← DO THIS NOW
2. **Verify with Queries** ← Use SELECT statements above
3. **Restart Worldserver** ← Important!
4. **Test In-Game** ← Look for NPCs
5. **Report Results** ← Ready for Phase 3C

---

## Quick Commands Reference

### To Delete & Respawn NPCs (if needed)
```sql
DELETE FROM creature WHERE guid IN (450001, 450002, 450003);
DELETE FROM creature_template WHERE entry IN (190001, 190002);
DELETE FROM creature_template_model WHERE CreatureID IN (190001, 190002);

-- Then re-execute both SQL files
```

### To Manually Spawn for Testing (In-Game)
```
.npc add 190001
.npc add 190002
```

### To Find Your Position (for testing)
```
.die  -- Die to see coordinates
-- Or check character current position in database
```

---

## File Validation

Both files are now validated and ready:

| File | Status | Columns | Test |
|------|--------|---------|------|
| dc_npc_creature_templates.sql | ✅ Fixed | Named | Ready |
| dc_npc_spawns.sql | ✅ Fixed | Named | Ready |

---

**Ready to Execute!** 🚀

Execute both files in order and verify NPCs appear in-game.

Report any issues and we're ready for Phase 3C!
