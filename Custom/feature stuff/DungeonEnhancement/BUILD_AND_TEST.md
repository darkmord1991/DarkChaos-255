# IMMEDIATE NEXT STEPS

## What Was Changed

The Mythic+ scaling system has been completely rewritten to properly integrate with AzerothCore's creature initialization system.

**Key Change:** Switched from `OnCreatureAddWorld()` hook (wrong - too late) to proper `OnBeforeCreatureSelectLevel()` and `OnCreatureSelectLevel()` hooks (correct - proper timing).

**Files Modified:**
- `src/server/scripts/DC/MythicPlus/mythic_plus_core_scripts.cpp` - Complete rewrite of scaling hooks

**Files Created:**
- `Custom/MYTHIC_SCALING_FIX.md` - Technical explanation
- `Custom/MYTHIC_TEST_CHECKLIST.md` - Testing procedures

## BUILD INSTRUCTIONS

### Option 1: Quick Build (Windows)
```powershell
# Open PowerShell in K:\Dark-Chaos\DarkChaos-255
.\acore.sh compiler build
```

### Option 2: VS Code Task
In VS Code:
1. Press `Ctrl+Shift+P`
2. Type "Tasks: Run Task"
3. Select "AzerothCore: Build (local)"

### Expected Build Time
- First build: ~30-60 minutes (full compilation)
- Incremental: ~2-5 minutes (only changed files)

### Build Success Indicators
```
[100%] Built target worldserver
Build succeeded.
```

## RESTART WORLDSERVER

After build completes:

1. **Stop worldserver** (if running)
   - Press Ctrl+C in worldserver terminal
   - Or kill process

2. **Start worldserver**
   ```powershell
   .\acore.sh run-worldserver
   ```

3. **Watch for startup messages:**
   ```
   Loading Mythic+ system...
   Loaded X Mythic+ dungeon profiles
   ```

   If you see these → System loaded correctly ✅
   If missing → Check troubleshooting below ❌

## QUICK TEST (2 Minutes)

Once in-game:

```
.gm on
.dc difficulty mythic
.go xyz 1688.99 1053.48 18.6775 189
.npc near 20
.npc info
```

**Expected Result:**
- Creature should be Level 80-82 (not 34!)
- HP should be 60,000-90,000 (not 2,901!)

**If this works:** ✅ Success! Scaling is fixed!
**If not:** ❌ See troubleshooting below

## TROUBLESHOOTING

### Issue: "Loaded 0 Mythic+ dungeon profiles"

**Cause:** Database table empty or missing

**Solution:**
```sql
-- Run these SQL files in order:
SOURCE K:/Dark-Chaos/DarkChaos-255/data/sql/custom/dc_mythic_dungeons_world.sql;
SOURCE K:/Dark-Chaos/DarkChaos-255/data/sql/custom/dc_mythic_fix_multipliers.sql;

-- Verify data exists:
SELECT * FROM world.dc_dungeon_mythic_profile WHERE map_id = 189;
```

Then restart worldserver.

### Issue: Creatures still Level 34

**Possible Causes:**

1. **Server not rebuilt**
   - Solution: Run build commands above

2. **Old worldserver still running**
   - Solution: Kill all worldserver processes, restart

3. **Hooks not firing**
   - Check worldserver.log for "Scaled creature" messages
   - If missing: Check AddSC function is called

4. **Database multipliers = 1.0**
   ```sql
   UPDATE world.dc_dungeon_mythic_profile 
   SET mythic_health_mult = 3.0, mythic_damage_mult = 2.0 
   WHERE expansion = 0;  -- Vanilla
   ```

### Issue: Compile Errors

**Common Errors:**

1. **"undefined reference to OnBeforeCreatureSelectLevel"**
   - Cause: AzerothCore version too old
   - Solution: Update to latest AzerothCore master

2. **"mythic.scaling log category not defined"**
   - Not an error - just a warning
   - Logs will use "server.loading" instead

3. **"MythicDifficultyScaling.h not found"**
   - Check file exists at: `src/server/scripts/DC/MythicPlus/MythicDifficultyScaling.h`
   - Check CMakeLists.txt includes the directory

## VERIFICATION

### Minimal Verification (30 seconds)
```
.gm on
.dc difficulty mythic
.go xyz 1688.99 1053.48 18.6775 189
.npc info
```
Look for Level 80-82 with high HP.

### Full Verification (5 minutes)
Follow `Custom/MYTHIC_TEST_CHECKLIST.md` for complete test suite.

## SUCCESS CRITERIA

✅ Worldserver starts without errors
✅ Log shows "Loaded X Mythic+ dungeon profiles"  
✅ Creatures in Mythic difficulty are Level 80-82
✅ Creatures have ~3x HP compared to Normal
✅ `.dc difficulty` commands work
✅ `.dc reload mythic` works without restart

## NEXT DEVELOPMENT STEPS

Once scaling works correctly:

1. **Keystone System** (M+2 to M+10)
   - Font of Power GameObject
   - Keystone items
   - Progressive scaling

2. **Death Budget Tracking**
   - Deaths per instance
   - Wipe detection
   - Score calculation

3. **Weekly Vault System**
   - Run tracking
   - Reward generation
   - Weekly reset

4. **Affix System**
   - Affix database
   - Rotation schedule
   - Effect implementation

See `Custom/MYTHIC_SCALING_FIX.md` for technical details on the implementation.

## SUPPORT

If issues persist after following troubleshooting:

1. Check `var/logs/worldserver.log` for error messages
2. Verify database connection works
3. Test with a fresh instance bind (`.instance unbind all`)
4. Compare your database profile with expected values in test checklist

## ROLLBACK (If Needed)

If new system causes problems:

```bash
git checkout HEAD -- src/server/scripts/DC/MythicPlus/mythic_plus_core_scripts.cpp
./acore.sh compiler build
```

This reverts to previous version (though it won't scale properly).

