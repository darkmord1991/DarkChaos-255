# Database Consolidation Deployment Guide

**Date:** November 22, 2025  
**Status:** Ready for Production  
**Risk Level:** LOW (backward compatible via SQL views)

## Overview

This guide covers the deployment of the unified seasonal database consolidation. All changes are **backward compatible** - existing code continues to work through SQL views while new code uses the unified structure.

## Pre-Deployment Checklist

### Required Backups
```bash
# Backup world database
mysqldump -u root -p acore_world > acore_world_backup_pre_consolidation_$(date +%Y%m%d).sql

# Backup character database  
mysqldump -u root -p acore_characters > acore_characters_backup_pre_consolidation_$(date +%Y%m%d).sql
```

### Verify Current State
```sql
-- Check if tables exist
SELECT TABLE_NAME, TABLE_ROWS 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'acore_world'
  AND TABLE_NAME IN ('dc_seasons', 'dc_mplus_seasons', 'dc_weekly_vault', 'dc_player_seasonal_chests')
ORDER BY TABLE_NAME;

-- Check for active seasons
SELECT season_id, label, is_active FROM dc_mplus_seasons WHERE is_active = 1;
```

## Deployment Steps

### Step 1: Stop Server (Optional but Recommended)
```bash
# Stop worldserver to prevent writes during migration
./acore.sh stop worldserver
```

### Step 2: Run Consolidation Script
```bash
# Connect to database
mysql -u root -p acore_world < "Custom/Custom feature SQLs/worlddb/SeasonSystem/02_CONSOLIDATE_SEASONS_DATABASE.sql"
```

**Expected Output:**
```
========== CONSOLIDATION COMPLETE ==========
table_name: dc_seasons
total_seasons: 1 (or more)
mplus_seasons: 1
global_seasons: 0
active_seasons: 1

table_name: dc_player_weekly_rewards
total_records: 50 (varies by server)
mplus_records: 30
reward_records: 20
claimed_records: 15

views_status: Backward compatibility views created: dc_weekly_vault, dc_player_seasonal_chests
archive_status: Archived tables: *_archived_20251122
final_status: Migration complete! Old code will continue to work via views.
```

### Step 3: Verify Migration
```sql
-- Check unified table
SELECT 
  system_type,
  COUNT(*) AS records,
  SUM(reward_claimed) AS claimed
FROM dc_player_weekly_rewards
GROUP BY system_type;

-- Verify views work
SELECT COUNT(*) FROM dc_weekly_vault;
SELECT COUNT(*) FROM dc_player_seasonal_chests;

-- Check season migration
SELECT season_id, season_name, season_type, season_state 
FROM dc_seasons 
WHERE season_type = 'mythic_plus';
```

### Step 4: Rebuild Server (If Code Changed)
```bash
# If you updated C++ code to use unified table
./acore.sh compiler build
```

### Step 5: Start Server
```bash
./acore.sh start worldserver

# Monitor logs for any errors
tail -f var/logs/Server.log | grep -i "seasonal\|vault\|weekly"
```

### Step 6: In-Game Verification
```
# As admin in-game
.server info

# Test M+ vault
.mplus vault check

# Test seasonal rewards
.season info
.season chest

# Complete a M+ run and verify tracking
# Complete a quest with seasonal rewards
```

## What Changed

### Database Tables

#### Created
- **dc_player_weekly_rewards** - Unified weekly reward tracking
  - Replaces both `dc_weekly_vault` and `dc_player_seasonal_chests`
  - Supports multiple system types (mythic_plus, seasonal_rewards, pvp, hlbg)
  - Unified slot system (3 slots with tokens, essence, and item rewards)

#### Enhanced
- **dc_seasons** - Added columns:
  - `season_type` VARCHAR(50) - System type identifier
  - `custom_properties` JSON - System-specific configuration

#### Archived (Renamed)
- `dc_mplus_seasons` → `dc_mplus_seasons_archived_20251122`
- `dc_weekly_vault` → `dc_weekly_vault_archived_20251122`
- `dc_player_seasonal_chests` → `dc_player_seasonal_chests_archived_20251122`

#### Views Created (Backward Compatibility)
- **dc_weekly_vault** (view) - M+ code continues to work
- **dc_player_seasonal_chests** (view) - Seasonal reward code continues to work

### Code Compatibility

**✅ No code changes required immediately**
- Existing M+ queries to `dc_weekly_vault` work via view
- Existing reward queries to `dc_player_seasonal_chests` work via view
- All INSERT/UPDATE/DELETE operations work through views

**⚠️ Views have limitations:**
- `DELETE` operations on views may not work as expected
- Complex joins might be slower
- Recommended to update code to use `dc_player_weekly_rewards` directly

## Testing Checklist

### M+ System
- [ ] Complete a M+ run, verify tracking in dc_player_weekly_rewards
- [ ] Open Great Vault, verify slots appear correctly
- [ ] Claim M+ reward from vault
- [ ] Verify reward_claimed flag updated in database
- [ ] Check next week's vault resets properly

### Seasonal Rewards
- [ ] Complete quest with seasonal rewards
- [ ] Verify tokens/essence tracked in dc_player_weekly_rewards
- [ ] Generate weekly chest via `.season chest generate`
- [ ] Collect weekly chest via `.season chest`
- [ ] Verify chest collected flag in database

### Season Transitions
- [ ] Change active season via `.season set 2`
- [ ] Verify all systems recognize Season 2
- [ ] Check player stats archived for Season 1
- [ ] Verify new Season 2 records created

### Database Integrity
```sql
-- Check for orphaned records
SELECT r.id, r.character_guid, r.season_id
FROM dc_player_weekly_rewards r
LEFT JOIN dc_seasons s ON r.season_id = s.season_id
WHERE s.season_id IS NULL;

-- Verify foreign keys
SELECT 
  CONSTRAINT_NAME,
  TABLE_NAME,
  REFERENCED_TABLE_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'acore_world'
  AND REFERENCED_TABLE_NAME = 'dc_seasons';

-- Check view definitions
SHOW CREATE VIEW dc_weekly_vault;
SHOW CREATE VIEW dc_player_seasonal_chests;
```

## Rollback Procedure

If issues occur, rollback is safe and simple:

```bash
# Connect to database
mysql -u root -p acore_world < "Custom/Custom feature SQLs/worlddb/SeasonSystem/03_ROLLBACK_CONSOLIDATION.sql"

# Restart server
./acore.sh restart worldserver
```

**Rollback performs:**
1. Drops compatibility views
2. Restores archived tables to original names
3. Restores original foreign key constraints
4. Optionally drops `dc_player_weekly_rewards` (commented by default)

**⚠️ Warning:** Rollback will LOSE any data created after consolidation!

## Performance Impact

### Expected Improvements
- **Fewer table scans** - One table vs two for weekly rewards
- **Simplified queries** - No need to JOIN vault + chests
- **Better indexing** - Unified indexes on season_id, week_start, system_type

### Monitoring Queries
```sql
-- Check table sizes
SELECT 
  TABLE_NAME,
  TABLE_ROWS,
  ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_mb,
  ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_mb
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_world'
  AND TABLE_NAME IN ('dc_player_weekly_rewards', 
                     'dc_weekly_vault_archived_20251122',
                     'dc_player_seasonal_chests_archived_20251122');

-- Monitor query performance
EXPLAIN SELECT * FROM dc_player_weekly_rewards 
WHERE character_guid = 1 AND season_id = 1 AND system_type = 'mythic_plus';
```

## Common Issues & Solutions

### Issue 1: Foreign Key Constraint Fails
**Symptoms:** Error during migration about foreign key constraint

**Solution:**
```sql
-- Temporarily disable foreign key checks
SET FOREIGN_KEY_CHECKS=0;

-- Re-run migration script
SOURCE Custom/Custom feature SQLs/worlddb/SeasonSystem/02_CONSOLIDATE_SEASONS_DATABASE.sql;

-- Re-enable checks
SET FOREIGN_KEY_CHECKS=1;
```

### Issue 2: View Already Exists
**Symptoms:** Error "View already exists"

**Solution:**
```sql
-- Drop existing views manually
DROP VIEW IF EXISTS dc_weekly_vault;
DROP VIEW IF EXISTS dc_player_seasonal_chests;

-- Re-run migration
```

### Issue 3: Season ID Mismatch
**Symptoms:** Players showing wrong season after migration

**Solution:**
```sql
-- Check season consistency
SELECT DISTINCT season_id, system_type FROM dc_player_weekly_rewards;

-- Update to current active season if needed
UPDATE dc_player_weekly_rewards 
SET season_id = (SELECT season_id FROM dc_seasons WHERE season_state = 1 LIMIT 1)
WHERE season_id = 0 OR season_id IS NULL;
```

### Issue 4: Archived Tables Not Found
**Symptoms:** Rollback fails because archived tables don't exist

**Solution:**
```sql
-- Check if original tables still exist
SHOW TABLES LIKE '%vault%';
SHOW TABLES LIKE '%seasonal_chest%';
SHOW TABLES LIKE '%mplus_season%';

-- If originals exist, consolidation never ran
-- If archived exist, migration succeeded
-- If neither exist, restore from backup
```

## Maintenance

### Weekly Cleanup (Automated)
Add to server crontab:
```bash
# Clean old weekly reward records (keep 8 weeks)
0 0 * * 2 mysql -u root -p"password" acore_world -e "DELETE FROM dc_player_weekly_rewards WHERE week_start < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 8 WEEK))" >> /var/log/weekly_cleanup.log 2>&1
```

### Manual Cleanup
```sql
-- Remove records older than 90 days
DELETE FROM dc_player_weekly_rewards 
WHERE week_start < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 90 DAY));

-- Optimize table
OPTIMIZE TABLE dc_player_weekly_rewards;

-- Update statistics
ANALYZE TABLE dc_player_weekly_rewards;
```

## Post-Deployment Monitoring

### Key Metrics
Monitor these for 1 week post-deployment:

```sql
-- Daily record growth
SELECT 
  FROM_UNIXTIME(week_start, '%Y-%m-%d') AS week_date,
  system_type,
  COUNT(*) AS records
FROM dc_player_weekly_rewards
WHERE week_start >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 7 DAY))
GROUP BY week_date, system_type
ORDER BY week_date DESC;

-- Claim rate
SELECT 
  system_type,
  COUNT(*) AS total_rewards,
  SUM(reward_claimed) AS claimed,
  ROUND(100 * SUM(reward_claimed) / COUNT(*), 2) AS claim_rate_pct
FROM dc_player_weekly_rewards
WHERE week_start >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 WEEK))
GROUP BY system_type;

-- Error log check
SELECT * FROM acore_world.log_error 
WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 1 DAY)
  AND message LIKE '%weekly%reward%'
ORDER BY timestamp DESC;
```

## Success Criteria

✅ **Migration Successful If:**
1. All data migrated from old tables to `dc_player_weekly_rewards`
2. Views return same data as original tables (for existing records)
3. M+ vault opens and displays slots correctly
4. Seasonal chest collection works
5. New records created in unified table
6. No foreign key constraint errors in logs
7. Season transitions work across all systems
8. Performance metrics stable or improved

## Support

If issues persist after following this guide:

1. **Restore from backup:**
   ```bash
   mysql -u root -p acore_world < acore_world_backup_pre_consolidation_YYYYMMDD.sql
   ```

2. **Contact development team** with:
   - Server log excerpt showing error
   - Output of verification queries
   - Steps performed before error
   - Database version: `SELECT VERSION();`

3. **Document issue** in SEASONAL_CONFLICT_ANALYSIS.md

---

**Deployment Status:** Ready for production  
**Testing:** Passed on development server  
**Rollback:** Available via 03_ROLLBACK_CONSOLIDATION.sql  
**Risk:** LOW (backward compatible)
