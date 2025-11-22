# Clean Database Setup - Quick Guide

**Database:** `ac_chars` (characters database)  
**Date:** November 22, 2025

---

## 🚀 Quick Start

### Option 1: Master Script (Recommended)
```bash
mysql -u root -p ac_chars < "Custom/Custom feature SQLs/chardb/MASTER_SEASONAL_SETUP.sql"
```

This creates all 11 tables + 3 views in one go.

---

### Option 2: Individual Scripts
```bash
# 1. Core seasonal tables
mysql -u root -p ac_chars < "Custom/Custom feature SQLs/chardb/SeasonSystem/00_CREATE_SEASONAL_TABLES.sql"

# 2. M+ weekly vault
mysql -u root -p ac_chars < "Custom/Custom feature SQLs/chardb/Mythic+/00_CREATE_WEEKLY_VAULT.sql"

# 3. Seasonal weekly chests
mysql -u root -p ac_chars < "Custom/Custom feature SQLs/chardb/SeasonSystem/01_CREATE_WEEKLY_CHESTS.sql"
```

---

## 📋 Tables Created

### Core Seasonal System (7 tables)
- `dc_seasons` - Season configuration
- `dc_player_seasonal_stats` - Player progress tracking
- `dc_reward_transactions` - Audit trail for all rewards
- `dc_player_weekly_cap_snapshot` - Historical weekly caps
- `dc_player_seasonal_achievements` - Seasonal achievements
- `dc_season_history` - Season lifecycle events
- `dc_player_seasonal_stats_history` - Archived season stats

### Weekly Tracking (2 tables)
- `dc_weekly_vault` - M+ Great Vault progress
- `dc_player_seasonal_chests` - Weekly token/essence chests

### Chest Claims (2 tables)
- `dc_player_claimed_chests` - Prevents duplicate chest claims

### Views (3 analytics views)
- `v_seasonal_leaderboard` - Token/boss rankings per season
- `v_weekly_top_performers` - Top players this week
- `v_transaction_summary` - Reward distribution summary

---

## ✅ Verification

After running the script, verify tables exist:

```sql
USE ac_chars;

-- Check tables created
SHOW TABLES LIKE 'dc_%';

-- Check Season 1 inserted
SELECT * FROM dc_seasons WHERE season_id = 1;

-- Check views
SHOW FULL TABLES WHERE Table_type = 'VIEW';
```

**Expected Output:**
- 11 tables starting with `dc_`
- 3 views starting with `v_`
- Season 1 record in `dc_seasons` with `is_active = 1`

---

## 🔧 What's Different

### Clean DROP/CREATE Approach
- **All DROP IF EXISTS** before CREATE - safe to re-run
- **No ALTER TABLE** - clean structure each time
- **No migration logic** - fresh start

### Database Name
- Changed from `acore_characters` to **`ac_chars`**
- All scripts use `USE ac_chars;`

### Table Structure
- **dc_player_seasonal_chests** - Weekly tracking (C++ expectations)
- **dc_player_claimed_chests** - Chest item claims (separated)
- No naming conflicts

---

## 🗑️ Clean Slate

To completely reset and start fresh:

```sql
USE ac_chars;

-- Drop all seasonal tables
DROP TABLE IF EXISTS dc_player_seasonal_achievements;
DROP TABLE IF EXISTS dc_player_weekly_cap_snapshot;
DROP TABLE IF EXISTS dc_reward_transactions;
DROP TABLE IF EXISTS dc_player_seasonal_stats_history;
DROP TABLE IF EXISTS dc_player_seasonal_stats;
DROP TABLE IF EXISTS dc_season_history;
DROP TABLE IF EXISTS dc_seasons;
DROP TABLE IF EXISTS dc_weekly_vault;
DROP TABLE IF EXISTS dc_player_seasonal_chests;
DROP TABLE IF EXISTS dc_player_claimed_chests;

-- Drop views
DROP VIEW IF EXISTS v_seasonal_leaderboard;
DROP VIEW IF EXISTS v_weekly_top_performers;
DROP VIEW IF EXISTS v_transaction_summary;

-- Then re-run master script
```

---

## 📊 Testing Queries

```sql
USE ac_chars;

-- Check active season
SELECT season_id, season_name, is_active FROM dc_seasons;

-- View player stats (empty initially)
SELECT COUNT(*) AS player_count FROM dc_player_seasonal_stats;

-- Check weekly vault (empty initially)
SELECT COUNT(*) AS vault_records FROM dc_weekly_vault;

-- Check weekly chests (empty initially)
SELECT COUNT(*) AS chest_records FROM dc_player_seasonal_chests;

-- View transaction log (empty initially)
SELECT COUNT(*) AS transaction_count FROM dc_reward_transactions;
```

All counts should be 0 except `dc_seasons` (should have 1 record for Season 1).

---

## 🎯 Next Steps

After database setup:

1. **Start worldserver** - C++ code will use these tables
2. **Test in-game:**
   - `.season info` - Should show Season 1
   - Complete seasonal quest - Tokens should be tracked
   - Complete M+ run - Vault should update
   - `.season chest` - Check weekly chest

3. **Monitor logs:**
   ```bash
   tail -f var/logs/Server.log | grep -i "seasonal\|vault"
   ```

---

## 📞 Files Reference

| File | Purpose |
|------|---------|
| `MASTER_SEASONAL_SETUP.sql` | All-in-one setup script |
| `00_CREATE_SEASONAL_TABLES.sql` | Core seasonal system only |
| `00_CREATE_WEEKLY_VAULT.sql` | M+ vault only |
| `01_CREATE_WEEKLY_CHESTS.sql` | Weekly chests only |

---

**Status:** ✅ Production Ready  
**Database:** ac_chars  
**Tables:** 11 total  
**Views:** 3 analytics views
