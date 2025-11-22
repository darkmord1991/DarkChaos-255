# Mythic+ Scaling Diagnostic Guide

## Your Current Issue

**Symptoms:**
- Set difficulty to Mythic ✅
- Unbound instance ✅
- Entered Scarlet Monastery ✅
- Creature shows Level 31 with 1107 HP ❌ (Should be Level 80-82 with 60,000+ HP)

## Critical Checks (In Order)

### 1. Was the Server Rebuilt?

**Check:** Did you run the build command after editing `mythic_plus_core_scripts.cpp`?

**Command to verify:**
```powershell
# Check if mythic_plus_core_scripts.cpp was compiled recently
Get-ChildItem K:\Dark-Chaos\DarkChaos-255\var\build -Recurse -Filter "*mythic*.o" | Select-Object Name, LastWriteTime
```

**Expected:** Files should show today's date (2025-11-14)

**If NOT rebuilt:** Run this NOW:
```powershell
cd K:\Dark-Chaos\DarkChaos-255
.\acore.sh compiler build
```

---

### 2. Check Worldserver Startup Logs

**Location:** `K:\Dark-Chaos\DarkChaos-255\var\logs\worldserver.log`

**Search for (PowerShell):**
```powershell
Get-Content K:\Dark-Chaos\DarkChaos-255\var\logs\worldserver.log | Select-String "Loading Mythic|Loaded.*Mythic|MythicPlus"
```

**Expected Output:**
```
>> Loading Mythic+ system...
Loaded X Mythic+ dungeon profiles
```

**If NOT FOUND:**
- ❌ System never loaded → Server not rebuilt OR AddSC not called
- ❌ Go back to step 1 and rebuild

**If you see "Loaded 0 Mythic+ dungeon profiles":**
- ❌ Database table empty
- ❌ Go to step 3

---

### 3. Verify Database Has Profiles

**SQL Query:**
```sql
USE world;
SELECT COUNT(*) as profile_count FROM dc_dungeon_mythic_profile;
SELECT * FROM dc_dungeon_mythic_profile WHERE map_id = 189;
```

**Expected:**
- `profile_count` should be > 0 (ideally 15-30 dungeons)
- Scarlet Monastery (189) should exist with:
  - `mythic_enabled` = 1
  - `mythic_level_normal` = 80
  - `mythic_level_elite` = 81
  - `mythic_level_boss` = 82
  - `mythic_health_mult` = 3.0
  - `mythic_damage_mult` = 2.0

**If table is empty or wrong values:**
```sql
-- Run the SQL migration files in this order:
SOURCE K:/Dark-Chaos/DarkChaos-255/data/sql/custom/dc_mythic_dungeons_world.sql;
SOURCE K:/Dark-Chaos/DarkChaos-255/data/sql/custom/dc_mythic_add_level_columns.sql;
SOURCE K:/Dark-Chaos/DarkChaos-255/data/sql/custom/dc_mythic_fix_multipliers.sql;
```

Then **restart worldserver**.

---

### 4. Check if Hooks Are Firing

**Search worldserver.log for creature scaling:**
```powershell
Get-Content K:\Dark-Chaos\DarkChaos-255\var\logs\worldserver.log -Tail 1000 | Select-String "Scaled creature"
```

**Expected (when entering Mythic dungeon):**
```
Scaled creature [Scarlet Defender] (entry 4283) on map 189 (difficulty 2) to level 80 with 3.00x HP (1107 -> 3321), 2.00x Damage
```

**If NOT FOUND:**
- ❌ Hooks aren't firing at all
- ❌ Either server not rebuilt OR hooks not registered in CMakeLists.txt

---

### 5. Verify Script Registration

**Check CMakeLists.txt:**
```powershell
Get-Content K:\Dark-Chaos\DarkChaos-255\src\server\scripts\DC\CMakeLists.txt | Select-String -Pattern "mythic"
```

**Expected:**
```cmake
MythicPlus/mythic_plus_core_scripts.cpp
MythicPlus/MythicDifficultyScaling.cpp
```

**If NOT FOUND:** The scripts aren't being compiled!

**Add to CMakeLists.txt:**
```cmake
# Mythic+ System
MythicPlus/mythic_plus_core_scripts.cpp
MythicPlus/MythicDifficultyScaling.cpp
```

Then rebuild.

---

### 6. Test Reload Command

**In-game:**
```
.dc reload mythic
```

**Expected:**
```
Reloaded Mythic+ dungeon profiles from database.
```

**If error:** Header not included in cs_dc_addons.cpp

**If works but scaling still doesn't:** Server using old binary (not restarted after rebuild)

---

## Quick Diagnostic Flow Chart

```
Did you rebuild server after code changes?
├─ NO → Run: .\acore.sh compiler build
│        Then restart worldserver
│
└─ YES → Check worldserver.log for "Loading Mythic+"
   ├─ NOT FOUND → Scripts not being loaded
   │              Check CMakeLists.txt includes scripts
   │              Rebuild server
   │
   └─ FOUND → Check "Loaded X profiles"
      ├─ "Loaded 0" → Database empty
      │               Run SQL migration scripts
      │               Restart worldserver
      │
      └─ "Loaded 15+" → Check for "Scaled creature" logs
         ├─ NOT FOUND → Hooks not firing
         │              Possible causes:
         │              1. Wrong instance (still bound to old one)
         │              2. Difficulty not actually set
         │              3. Code error preventing hook execution
         │
         └─ FOUND → Scaling IS working!
            Check .npc info again
            If still level 31, you're looking at different creature
```

---

## Most Likely Issue Based on Your Log

You said:
- "Difficulty set to Mythic" ✅
- "instances unbound: 1" ✅
- Entered map 189 ✅
- Creature shows Level 31 ❌

**Most likely cause:**
1. ⚠️ **Server not rebuilt** - Still running old code with `OnCreatureAddWorld()` hook
2. ⚠️ **Database profiles not loaded** - Check log for "Loaded 0 profiles"

---

## Immediate Actions (Do These NOW)

### Step 1: Check if server was rebuilt
```powershell
# Check compilation timestamp
Get-ChildItem K:\Dark-Chaos\DarkChaos-255\var\build\src\server\scripts\DC\MythicPlus -ErrorAction SilentlyContinue | Select-Object Name, LastWriteTime
```

If files don't exist or are old (not today):
```powershell
cd K:\Dark-Chaos\DarkChaos-255
.\acore.sh compiler build
```

**Wait for build to complete (2-5 minutes for incremental build)**

### Step 2: Restart worldserver
Stop and restart the worldserver process completely.

### Step 3: Check startup logs
```powershell
Get-Content K:\Dark-Chaos\DarkChaos-255\var\logs\worldserver.log -Tail 200 | Select-String "Loading Mythic|Loaded.*Mythic"
```

Should see:
```
>> Loading Mythic+ system...
Loaded 15 Mythic+ dungeon profiles
```

### Step 4: Test in-game
```
.gm on
.dc difficulty mythic
.instance unbind all
.go xyz 1688.99 1053.48 18.6775 189
.npc near 5
.npc info
```

**Creature should now be Level 80-82 with high HP!**

---

## If Still Not Working After Steps 1-4

**Enable debug logging:**

1. Edit `MythicDifficultyScaling.cpp` line 20 - change:
   ```cpp
   LOG_INFO("server.loading", ">> Loading Mythic+ system...");
   ```
   to:
   ```cpp
   LOG_INFO("server.loading", ">> Loading Mythic+ system... [DEBUG MODE]");
   LOG_INFO("server.loading", ">> Database table: dc_dungeon_mythic_profile");
   ```

2. Edit `mythic_plus_core_scripts.cpp` line 34 - add at start of `OnBeforeCreatureSelectLevel`:
   ```cpp
   LOG_INFO("mythic.scaling", "DEBUG: OnBeforeCreatureSelectLevel called for creature {} level {}", 
            creature->GetEntry(), level);
   ```

3. Rebuild and restart

4. Check logs - you should see these DEBUG messages

5. If DEBUG messages appear → Hooks ARE firing, investigate logic
   If DEBUG messages don't appear → Hooks NOT firing, check registration

---

## Contact Support With This Info

If you need further help, provide:

1. **Build timestamp:**
   ```powershell
   Get-ChildItem K:\Dark-Chaos\DarkChaos-255\var\build\src\server\scripts\DC\MythicPlus\*.o | Select-Object Name, LastWriteTime
   ```

2. **Startup log excerpt:**
   ```powershell
   Get-Content K:\Dark-Chaos\DarkChaos-255\var\logs\worldserver.log -Tail 200 | Select-String "Loading Mythic|Loaded.*Mythic"
   ```

3. **Database profile count:**
   ```sql
   SELECT COUNT(*) FROM world.dc_dungeon_mythic_profile;
   SELECT * FROM world.dc_dungeon_mythic_profile WHERE map_id = 189;
   ```

4. **CMakeLists.txt content:**
   ```powershell
   Get-Content K:\Dark-Chaos\DarkChaos-255\src\server\scripts\DC\CMakeLists.txt
   ```

This will help identify the exact point of failure.
