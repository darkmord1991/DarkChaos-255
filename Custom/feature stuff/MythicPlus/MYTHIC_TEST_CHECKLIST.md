# Mythic+ Scaling Test Checklist

## Pre-Testing Setup

### 1. Database Verification
```sql
-- Check Scarlet Monastery profile exists
SELECT * FROM world.dc_dungeon_mythic_profile WHERE map_id = 189;

-- Should show:
-- heroic_level_normal: 60
-- heroic_level_elite: 61  
-- heroic_level_boss: 62
-- mythic_level_normal: 80
-- mythic_level_elite: 81
-- mythic_level_boss: 82
-- heroic_health_mult: 1.15
-- heroic_damage_mult: 1.10
-- mythic_health_mult: 3.0
-- mythic_damage_mult: 2.0
```

### 2. Rebuild Server
```bash
# In K:\Dark-Chaos\DarkChaos-255
./acore.sh compiler build
```

### 3. Restart Worldserver
Stop and restart the worldserver process.

## Test Cases

### Test 1: System Loading
**Expected in worldserver.log:**
```
Loading Mythic+ system...
Loaded X Mythic+ dungeon profiles
```

✅ Pass / ❌ Fail: ___________

### Test 2: Normal Difficulty (Baseline)
**Commands:**
```
.gm on
.dc difficulty normal
.go xyz 1688.99 1053.48 18.6775 189
.npc near 50
.npc info
```

**Expected Results:**
- Creatures at original levels (30-40)
- No multipliers applied
- Example: Scarlet Commander Mograine = Level 37, ~6,000 HP

✅ Pass / ❌ Fail: ___________

### Test 3: Heroic Difficulty (Level Scaling)
**Commands:**
```
.dc difficulty heroic
.instance unbind all
.go xyz 1688.99 1053.48 18.6775 189
.npc info
```

**Expected Results:**
- Normal mobs: Level 60
- Elite mobs: Level 61
- Boss mobs: Level 62
- HP multiplied by 1.15x
- Damage multiplied by 1.10x
- Example: Mograine = Level 62, ~9,000 HP

✅ Pass / ❌ Fail: ___________

### Test 4: Mythic Difficulty (Full Scaling)
**Commands:**
```
.dc difficulty mythic
.instance unbind all
.go xyz 1688.99 1053.48 18.6775 189
.npc info
```

**Expected Results:**
- Normal mobs: Level 80
- Elite mobs: Level 81
- Boss mobs: Level 82
- HP multiplied by 3.0x (Vanilla dungeon)
- Damage multiplied by 2.0x
- Example: Mograine = Level 82, ~60,000-90,000 HP

✅ Pass / ❌ Fail: ___________

**Server Log Check:**
Look for messages like:
```
Scaled creature [Scarlet Commander Mograine] (entry 3976) on map 189 (difficulty 2) to level 82 with 3.00x HP (20000 -> 60000), 2.00x Damage
```

✅ Pass / ❌ Fail: ___________

### Test 5: Dungeon Entrance Announcements
**Commands:**
```
.dc difficulty mythic
.go xyz 1688.99 1053.48 18.6775 189
```

**Expected Results:**
```
=== Dungeon Entered ===
Dungeon: Scarlet Monastery
Difficulty: Mythic
Scaling: +200% HP/+100% Damage (Vanilla/TBC)
```

✅ Pass / ❌ Fail: ___________

### Test 6: Hot Reload Command
**Commands:**
```sql
-- Change multipliers in database
UPDATE world.dc_dungeon_mythic_profile 
SET mythic_health_mult = 4.0 
WHERE map_id = 189;
```

**In-game:**
```
.dc reload mythic
```

**Expected:**
- Message: "Reloaded Mythic+ dungeon profiles from database."
- Re-enter dungeon, creatures should use new 4.0x multiplier

✅ Pass / ❌ Fail: ___________

### Test 7: WotLK Dungeon (Different Multipliers)
**Commands:**
```
.dc difficulty mythic
.go xyz 5678.8 651.9 643.9 576  # Utgarde Keep
.npc info
```

**Expected Results:**
- Creatures stay at original level 80 (mythic_level_* = 0)
- HP multiplied by 1.35x (WotLK multiplier)
- Damage multiplied by 1.20x

✅ Pass / ❌ Fail: ___________

### Test 8: Solo Player Support
**Commands (without group):**
```
.dc difficulty heroic
```

**Expected:**
- Command works (no "must be group leader" error)
- Difficulty changes successfully
- Dungeon scaling applies

✅ Pass / ❌ Fail: ___________

### Test 9: Difficulty Info Command
**Commands:**
```
.dc difficulty info
```

**Expected:**
```
Current Difficulty: Mythic (Level 2)
Dungeon: Scarlet Monastery (Map: 189)
Scaling: +200% HP, +100% Damage
Level Adjustment: 80-82
```

✅ Pass / ❌ Fail: ___________

## Debugging Failed Tests

### If creatures don't scale:

1. **Check server logs** for "Loading Mythic+" messages
   - Not found? → Database table missing or server not rebuilt

2. **Check `.dc reload mythic` works**
   - Error? → Database connection issue

3. **Check database values**
   ```sql
   SELECT * FROM dc_dungeon_mythic_profile WHERE map_id = 189;
   ```
   - Empty? → Run SQL migration scripts

4. **Check creature rank detection**
   - Add debug logging to `OnBeforeCreatureSelectLevel`
   - Verify rank constants match

5. **Verify hooks are firing**
   - Check for "Scaled creature" log messages
   - If missing → Hooks not registered (check AddSC call)

### Common Issues:

| Symptom | Cause | Solution |
|---------|-------|----------|
| No scaling at all | Server not rebuilt | Rebuild with `./acore.sh compiler build` |
| Logs show no "Loading Mythic+" | AddSC not called | Check CMakeLists.txt includes script |
| Level changes but HP doesn't | Multiplier = 1.0 | Run `dc_mythic_fix_multipliers.sql` |
| Wrong levels applied | Database values incorrect | Verify level columns with SELECT query |
| ".dc reload" doesn't work | Include missing | Check cs_dc_addons.cpp includes header |

## Performance Check

After testing, check server performance:
```
.server info
```

Expected:
- No significant lag increase
- Memory usage normal
- Hook overhead negligible (<1ms per creature spawn)

## Sign-Off

Tested by: ________________
Date: ________________
Server Version: ________________
All tests passed: ✅ / ❌

Notes:
_______________________________________
_______________________________________
_______________________________________
