# URGENT: Server Crash Fix - Deploy Now

## The Problem

**Server crashes at login with:**
```
Incorrect value '2025-11-08 18:42:06' for type 'l'. Value is raw ? 'false'
Table name 'dc_player_item_upgrades'. Field name 'first_upgraded_at'
Segmentation fault (core dumped)
```

**Root Cause:** Database schema mismatch - old table structure still exists

## One-Command Fix

```bash
# STOP SERVER FIRST
./acore.sh stop-worldserver

# WAIT 30 seconds for graceful shutdown

# DROP OLD TABLE
mysql -u root -p acore_world -e "DROP TABLE IF EXISTS dc_player_item_upgrades;"

# RECREATE WITH FIXED SCHEMA
mysql -u root -p acore_world < Custom/feature\ stuff/item\ upgrade\ system/dc_item_upgrade_schema.sql

# REBUILD
./acore.sh compiler clean
./acore.sh compiler build

# RESTART
./acore.sh run-worldserver

# TEST: Server should NOT crash on login
```

## What This Does

1. ✅ Removes old incompatible table
2. ✅ Creates new table with correct field names (`first_upgraded_at`, `last_upgraded_at`)
3. ✅ Rebuilds server with fixed C++ code
4. ✅ Eliminates segmentation faults

## Expected Result

- ✅ Server starts without crash
- ✅ Players can login normally
- ✅ Item upgrade system ready to use
- ✅ No console errors about first_upgraded_at

## Titles Issue

If titles aren't showing in character sheet:
- Client addon: DC-TitleFix is automatically loaded
- Server-side: Ensure world data is populated
- Manual test: `/who "Your Name"` should show title in game

## Files Changed

- `dc_item_upgrade_schema.sql` - Fixed table definition
- `ItemUpgradeManager.cpp` - Updated queries
- `ItemUpgradeAddonHandler.cpp` - Fixed INSERT statement
- `DC-TitleFix.lua` - Enhanced title handling

## Support

If still crashing after deploy:
1. Check world server logs: `tail -f var/log/world_*.log`
2. Look for "dc_player_item_upgrades" errors
3. Verify table exists: `SHOW TABLES LIKE 'dc_player%';`
4. Verify columns: `DESC dc_player_item_upgrades;`

---

**Time to deploy:** ~5 minutes
**Downtime:** ~2 minutes for recompile
**Risk:** Very low - fixes compatibility issue
