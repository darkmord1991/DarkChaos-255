# URGENT: Server Crash Fix - Deploy Now

## Problem
Server crashes at login with segmentation fault:
```
Incorrect value '2025-11-08 18:42:06' for type 'l'
crash at login
```

## Quick Fix (5 minutes)

### Step 1: Stop Server
```bash
./acore.sh stop-worldserver
# Wait 30 seconds for graceful shutdown
```

### Step 2: Drop Old Table
```sql
USE acore_world;
DROP TABLE IF EXISTS dc_player_item_upgrades;
```

### Step 3: Recreate Table with Fix
```sql
USE acore_world;
SOURCE /path/to/Custom/feature\ stuff/item\ upgrade\ system/dc_item_upgrade_schema.sql;
```

### Step 4: Recompile C++ Code
```bash
cd /path/to/repo
./acore.sh compiler clean
./acore.sh compiler build
# This takes ~10-30 minutes depending on your system
```

### Step 5: Start Server
```bash
./acore.sh run-worldserver
```

### Step 6: Test Login
- Create test character
- Try to log in
- **Should NOT crash**
- Character should load successfully

---

## What Was Fixed

| Issue | Fix |
|-------|-----|
| Schema field names didn't match C++ | Updated schema to use `first_upgraded_at`, `last_upgraded_at` |
| TIMESTAMP type vs INT UNSIGNED | Changed to INT UNSIGNED (AzerothCore standard) |
| C++ code using wrong field names | Updated all SELECT/INSERT queries |
| Missing variable in C++ | Added `baseItemName` assignment |

---

## Verification

After server starts:

```bash
# Check logs for errors
tail -f /path/to/logs/world_latest.log | grep -i "itemupgrade\|upgrade\|error"

# Should NOT see:
# - Incorrect value
# - first_upgraded_at error
# - Segmentation fault
```

---

## If Still Crashing

1. Check world server logs for exact error
2. Verify database table was created:
   ```sql
   DESC dc_player_item_upgrades;
   ```
3. Verify column names match (should show `first_upgraded_at`, `last_upgraded_at`)
4. Check C++ compilation completed without errors
5. Ensure server is using newly compiled binaries

---

## Files Changed

✅ `Custom/feature stuff/item upgrade system/dc_item_upgrade_schema.sql`
✅ `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.cpp`
✅ `src/server/scripts/DC/ItemUpgrades/ItemUpgradeAddonHandler.cpp`

All changes are **backward compatible** - no addon changes needed.

---

## Expected Result

✅ Server starts without crashes
✅ Players can log in
✅ Item upgrade system ready to use
✅ Character data persists correctly
