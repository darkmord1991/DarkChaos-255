# 🔴 CRITICAL: Server Rebuild Required

## Why Scaling Doesn't Work

Your database is **perfect** (50 profiles, Scarlet Monastery configured correctly).

The problem: **The server is still running OLD code** that uses the broken `OnCreatureAddWorld()` hook.

The NEW code with proper `OnBeforeCreatureSelectLevel()` and `OnCreatureSelectLevel()` hooks has NOT been compiled yet.

## Fix: Rebuild Now

### Step 1: Open PowerShell in project root
```powershell
cd K:\Dark-Chaos\DarkChaos-255
```

### Step 2: Rebuild the server
```powershell
.\acore.sh compiler build
```

**Expected output:**
```
Scanning dependencies...
Building CXX object...
[100%] Built target worldserver
```

**Build time:** 2-5 minutes (incremental build)

### Step 3: Stop worldserver completely
```powershell
# Kill any running worldserver processes
Get-Process worldserver -ErrorAction SilentlyContinue | Stop-Process -Force
```

### Step 4: Start worldserver fresh
```powershell
.\acore.sh run-worldserver
```

### Step 5: Watch for startup message
In the worldserver console, you should see:
```
>> Loading Mythic+ system...
Loaded 50 Mythic+ dungeon profiles
```

**If you see this → System loaded correctly!**

### Step 6: Test in-game
```
.gm on
.dc difficulty mythic
.instance unbind all
.go xyz 1688.99 1053.48 18.6775 189
.npc near 5
.npc info
```

**Expected result:**
- Creature Level: 80-82 (not 31!)
- HP: 60,000-90,000 (not 1,107!)

## Verification Checklist

After rebuild and restart:

✅ Worldserver console shows "Loading Mythic+ system..."
✅ Shows "Loaded 50 Mythic+ dungeon profiles"
✅ Creatures in Mythic difficulty show level 80-82
✅ Creatures have 3x HP compared to Normal
✅ Server log shows "Scaled creature..." messages

## What Changed in the Code

**OLD (Broken):**
```cpp
void OnCreatureAddWorld(Creature* creature) override
{
    // This fires AFTER creature is fully initialized
    // Stats already calculated - too late to scale!
    sMythicScaling->ScaleCreature(creature, map);
}
```

**NEW (Fixed):**
```cpp
void OnBeforeCreatureSelectLevel(..., uint8& level) override
{
    // This fires BEFORE stats calculation
    // Modify level from 31 → 80
    // AzerothCore then calculates stats for level 80
    level = newLevel;
}

void OnCreatureSelectLevel(..., Creature* creature) override
{
    // This fires AFTER stats are calculated
    // Multiply the already-calculated stats
    creature->SetMaxHealth(baseHP * 3.0f);
    creature->SetBaseWeaponDamage(..., baseDamage * 2.0f);
}
```

This properly integrates with AzerothCore's `Creature::SelectLevel()` function.

## Common Mistakes

❌ **Not rebuilding** - Most common issue!
❌ **Not restarting worldserver** - Old binary still in memory
❌ **Restarting too quickly** - Build still in progress
❌ **Wrong terminal** - Make sure you're in K:\Dark-Chaos\DarkChaos-255

## Expected Timeline

1. Run build command → **0 seconds**
2. Wait for build → **2-5 minutes**
3. Stop worldserver → **5 seconds**
4. Start worldserver → **30 seconds**
5. Test in-game → **1 minute**

**Total time:** ~8 minutes

## If Still Not Working After Rebuild

Check these in order:

1. **Worldserver console:** Did you see "Loaded 50 Mythic+ dungeon profiles"?
   - NO → Server didn't load scripts, check CMakeLists.txt
   - YES → Continue to #2

2. **In-game:** Does `.dc reload mythic` work?
   - NO → Header not included properly
   - YES → Continue to #3

3. **Server logs:** Do you see "Scaled creature..." messages?
   - NO → Hooks not firing, add debug logging
   - YES → Scaling IS working, check .npc info again

4. **Still broken?** Run diagnostics:
   ```powershell
   # Check build timestamp
   Get-ChildItem K:\Dark-Chaos\DarkChaos-255\var\build\src\server\scripts\DC\MythicPlus -ErrorAction SilentlyContinue | Select-Object Name, LastWriteTime
   ```
   
   Files should show **today's date** (2025-11-14)

## Contact Points

If rebuild succeeds but scaling still doesn't work, provide:

1. Screenshot of worldserver startup showing "Loaded X profiles"
2. Screenshot of `.npc info` output in Mythic dungeon
3. Output of: `SELECT * FROM world.dc_dungeon_mythic_profile WHERE map_id = 189;`
4. Last 20 lines of worldserver console

---

**Start rebuild NOW - that's the issue! 🔨**
