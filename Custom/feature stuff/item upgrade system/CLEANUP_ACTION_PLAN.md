# 🧹 DC-ItemUpgrade: CLEANUP & FIX ACTION PLAN

**Status:** Ready for immediate execution  
**Estimated Time:** 45 minutes  
**Risk Level:** LOW (simple fixes, no data loss)

---

## PHASE 1: FIX CRITICAL BUGS (5 minutes)

### Fix 1.1: Column Name Mismatch - ItemUpgradeCommands.cpp

**File:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommands.cpp`  
**Line:** 169  
**Issue:** Query selects `upgrade_tokens` & `artifact_essence` but table has `token_cost` & `essence_cost`

**Change:**
```cpp
// Line 169 - BEFORE:
QueryResult costResult = WorldDatabase.Query(
    "SELECT upgrade_tokens, artifact_essence FROM dc_item_upgrade_costs WHERE tier = %u AND upgrade_level = %u",
    tier, targetLevel
);

// AFTER:
QueryResult costResult = WorldDatabase.Query(
    "SELECT token_cost, essence_cost FROM dc_item_upgrade_costs WHERE tier = %u AND upgrade_level = %u",
    tier, targetLevel
);
```

### Fix 1.2: Hardcoded Item IDs - ItemUpgradeProgressionImpl.cpp

**File:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeProgressionImpl.cpp`  
**Lines:** 599-600  
**Issue:** Uses test item IDs (900001, 900002) instead of config (100998, 100999)

**Change:**
```cpp
// Lines 599-600 - BEFORE:
uint32 essenceId = 900001;
uint32 tokenId = 900002;

// AFTER:
uint32 essenceId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.EssenceId", 100998);
uint32 tokenId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.TokenId", 100999);
```

---

## PHASE 2: ARCHIVE OLD FILES (15 minutes)

### Step 2.1: Create Archive Directory
```powershell
mkdir "Custom\ARCHIVE\ItemUpgrade_OldImplementations"
```

### Step 2.2: Move Conflicting SQL Files
These files conflict with the simple schema and should be archived:

```powershell
# Move Phase 4A (complex) schema
move "Custom\Custom feature SQLs\chardb\ItemUpgrades\dc_item_upgrade_phase4a.sql" `
     "Custom\ARCHIVE\ItemUpgrade_OldImplementations\dc_item_upgrade_phase4a.sql"

# Move advanced world schema
move "Custom\Custom feature SQLs\worlddb\ItemUpgrades\dc_item_upgrade_schema.sql" `
     "Custom\ARCHIVE\ItemUpgrade_OldImplementations\dc_item_upgrade_schema.sql"

# Move transmutation schemas (character)
move "Custom\Custom feature SQLs\chardb\ItemUpgrades\item_upgrade_transmutation_characters_schema.sql" `
     "Custom\ARCHIVE\ItemUpgrade_OldImplementations\item_upgrade_transmutation_characters_schema.sql"

# Move transmutation schemas (world)
move "Custom\Custom feature SQLs\worlddb\ItemUpgrades\item_upgrade_transmutation_schema.sql" `
     "Custom\ARCHIVE\ItemUpgrade_OldImplementations\item_upgrade_transmutation_schema.sql"

# Move other optional files
move "Custom\Custom feature SQLs\worlddb\ItemUpgrades\add_synthesis_recipes_table.sql" `
     "Custom\ARCHIVE\ItemUpgrade_OldImplementations\add_synthesis_recipes_table.sql"

move "Custom\Custom feature SQLs\worlddb\ItemUpgrades\dc_tier_configuration.sql" `
     "Custom\ARCHIVE\ItemUpgrade_OldImplementations\dc_tier_configuration.sql"

move "Custom\Custom feature SQLs\worlddb\ItemUpgrades\dc_npc_creature_templates.sql" `
     "Custom\ARCHIVE\ItemUpgrade_OldImplementations\dc_npc_creature_templates.sql"

move "Custom\Custom feature SQLs\worlddb\ItemUpgrades\dc_npc_spawns.sql" `
     "Custom\ARCHIVE\ItemUpgrade_OldImplementations\dc_npc_spawns.sql"
```

### Step 2.3: Create Archive README
**File:** `Custom/ARCHIVE/ItemUpgrade_OldImplementations/README.md`

```markdown
# Archived ItemUpgrade Files

These files are **NOT USED** in the current simple item-based system.

## Why Archived?

The DarkChaos ItemUpgrade system has multiple implementations:

### **ACTIVE SYSTEM** (Used)
- ItemUpgradeCommands.cpp - Simple item-based currency
- setup_upgrade_costs.sql - 75 cost entries
- dc_item_upgrade_addon_schema.sql - Simple state tracking

### **ARCHIVED SYSTEM** (Legacy/Advanced - Not Used)
All files in this folder are:
- Complex multi-tier systems with synthesis/transmutation
- Unused advanced features
- Causing schema conflicts
- Archived for reference only

## If You Need Advanced Features

To revert to Phase 4A (advanced) system:
1. Delete current schema files
2. Restore files from this archive
3. Update C++ code to match new schema
4. Update ItemUpgradeCommands.cpp column names
5. Test thoroughly

## Notes

- Phase 4A was designed for professional servers with complex crafting
- Simple system (ACTIVE) is better for gameplay clarity
- Never restore Phase 4A without DBA review
- Keep this archive as reference/backup

Date Archived: November 7, 2025
```

---

## PHASE 3: CREATE CONSOLIDATED SETUP (15 minutes)

### Step 3.1: Create Master Setup File

**File:** `Custom/ITEMUPGRADE_FINAL_SETUP.sql`

```sql
-- ============================================================================
-- DarkChaos ItemUpgrade System - CONSOLIDATED SETUP
-- ============================================================================
-- This file contains ALL database changes needed for the item-based upgrade system.
-- Execute this file ONCE to set up the complete system.
--
-- System: Simple item-based currency (uses WoW inventory items)
-- Currency Items: 100998 (Artifact Essence), 100999 (Upgrade Token)
-- Configuration: ItemUpgrade.Currency.EssenceId=100998, ItemUpgrade.Currency.TokenId=100999
--
-- Date: November 7, 2025
-- ============================================================================

-- ============================================================================
-- CHARACTERS DATABASE SCHEMA
-- ============================================================================
-- Run the following on: acore_characters

-- Table: dc_item_upgrade_state
-- Purpose: Tracks current upgrade level and investment for each item
-- Primary Key: item_guid (unique per item instance)
-- Foreign Key: player_guid → characters(guid)
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_state` (
    `item_guid` INT UNSIGNED NOT NULL COMMENT 'From item_instance.guid',
    `player_guid` INT UNSIGNED NOT NULL,
    `tier_id` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Leveling, 2=Heroic, 3=Raid, 4=Mythic, 5=Artifact',
    `upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0-15, 0=base, 15=max',
    `tokens_invested` INT UNSIGNED NOT NULL DEFAULT 0,
    `essence_invested` INT UNSIGNED NOT NULL DEFAULT 0,
    `base_item_level` SMALLINT UNSIGNED NOT NULL,
    `upgraded_item_level` SMALLINT UNSIGNED NOT NULL,
    `stat_multiplier` FLOAT NOT NULL DEFAULT 1.0 COMMENT '1.0=base, 1.5=+50% stats, etc',
    `first_upgraded_at` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp',
    `last_upgraded_at` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp',
    `season` INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`item_guid`),
    INDEX `idx_player` (`player_guid`),
    INDEX `idx_tier_level` (`tier_id`, `upgrade_level`),
    INDEX `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Item upgrade states for each item';

-- ============================================================================
-- WORLD DATABASE SCHEMA
-- ============================================================================
-- Run the following on: acore_world

-- Table: dc_item_upgrade_costs
-- Purpose: Defines cost (tokens + essence) for each tier/level combination
-- Primary Key: (tier_id, upgrade_level, season)
-- Data: 75 entries (5 tiers × 15 levels)
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_costs` (
    `tier_id` TINYINT UNSIGNED NOT NULL COMMENT 'Item tier (1-5)',
    `upgrade_level` TINYINT UNSIGNED NOT NULL COMMENT 'Target level (1-15)',
    `upgrade_tokens` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Upgrade Token cost (item 100999)',
    `artifact_essence` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Artifact Essence cost (item 100998)',
    `ilvl_increase` SMALLINT UNSIGNED NOT NULL DEFAULT 3 COMMENT 'iLevel increase per upgrade',
    `stat_increase_percent` FLOAT NOT NULL DEFAULT 2.0 COMMENT 'Stat % increase per level',
    `season` INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`tier_id`, `upgrade_level`, `season`),
    KEY `idx_tier_level` (`tier_id`, `upgrade_level`),
    KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Upgrade cost configuration per tier and level';

-- Clear existing costs (if re-running setup)
DELETE FROM `dc_item_upgrade_costs` WHERE 1=1;

-- TIER 1 (iLvL 0-299): Budget friendly
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, upgrade_tokens, artifact_essence) VALUES
(1, 1, 5, 2), (1, 2, 10, 4), (1, 3, 15, 6), (1, 4, 20, 8), (1, 5, 25, 10),
(1, 6, 30, 12), (1, 7, 35, 14), (1, 8, 40, 16), (1, 9, 45, 18), (1, 10, 50, 20),
(1, 11, 55, 22), (1, 12, 60, 24), (1, 13, 65, 26), (1, 14, 70, 28), (1, 15, 75, 30);

-- TIER 2 (iLvL 300-349): Moderate
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, upgrade_tokens, artifact_essence) VALUES
(2, 1, 10, 5), (2, 2, 20, 10), (2, 3, 30, 15), (2, 4, 40, 20), (2, 5, 50, 25),
(2, 6, 60, 30), (2, 7, 70, 35), (2, 8, 80, 40), (2, 9, 90, 45), (2, 10, 100, 50),
(2, 11, 110, 55), (2, 12, 120, 60), (2, 13, 130, 65), (2, 14, 140, 70), (2, 15, 150, 75);

-- TIER 3 (iLvL 350-399): Standard
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, upgrade_tokens, artifact_essence) VALUES
(3, 1, 15, 8), (3, 2, 30, 16), (3, 3, 45, 24), (3, 4, 60, 32), (3, 5, 75, 40),
(3, 6, 90, 48), (3, 7, 105, 56), (3, 8, 120, 64), (3, 9, 135, 72), (3, 10, 150, 80),
(3, 11, 165, 88), (3, 12, 180, 96), (3, 13, 195, 104), (3, 14, 210, 112), (3, 15, 225, 120);

-- TIER 4 (iLvL 400-449): Advanced
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, upgrade_tokens, artifact_essence) VALUES
(4, 1, 25, 15), (4, 2, 50, 30), (4, 3, 75, 45), (4, 4, 100, 60), (4, 5, 125, 75),
(4, 6, 150, 90), (4, 7, 175, 105), (4, 8, 200, 120), (4, 9, 225, 135), (4, 10, 250, 150),
(4, 11, 275, 165), (4, 12, 300, 180), (4, 13, 325, 195), (4, 14, 350, 210), (4, 15, 375, 225);

-- TIER 5 (iLvL 450+): Premium/Artifact
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, upgrade_tokens, artifact_essence) VALUES
(5, 1, 50, 30), (5, 2, 100, 60), (5, 3, 150, 90), (5, 4, 200, 120), (5, 5, 250, 150),
(5, 6, 300, 180), (5, 7, 350, 210), (5, 8, 400, 240), (5, 9, 450, 270), (5, 10, 500, 300),
(5, 11, 550, 330), (5, 12, 600, 360), (5, 13, 650, 390), (5, 14, 700, 420), (5, 15, 750, 450);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Run these queries to verify setup:
-- 
-- SELECT COUNT(*) as 'State Entries' FROM acore_characters.dc_item_upgrade_state;
-- SELECT COUNT(*) as 'Cost Entries' FROM acore_world.dc_item_upgrade_costs;
-- SELECT DISTINCT tier_id FROM acore_world.dc_item_upgrade_costs ORDER BY tier_id;
--
-- Expected Results:
-- - State Entries: 0 (empty until players upgrade items)
-- - Cost Entries: 75 (5 tiers × 15 levels)
-- - Distinct tiers: 1, 2, 3, 4, 5

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
-- System is ready! Items 100998 & 100999 are now the currency.
-- Use command: /dcupgrade init (to check balance)
```

---

## PHASE 4: DOCUMENT & VERIFY (10 minutes)

### Step 4.1: Create System Summary Document

**File:** `Custom/ITEMUPGRADE_SYSTEM_STATUS.md`

```markdown
# DC-ItemUpgrade System - CURRENT STATUS

**Date Updated:** November 7, 2025  
**System Status:** ✅ ACTIVE & UNIFIED  
**Implementation:** Simple Item-Based Currency

## System Overview

The DarkChaos ItemUpgrade system allows players to upgrade items using two types of currency:
- **Upgrade Tokens** (Item ID: 100999) - Primary currency
- **Artifact Essence** (Item ID: 100998) - Legendary tier currency

Both items are stored in player inventory and work like standard WoW currency items (Badges, Emblems).

## Active Files

### C++ Code
- ✅ `src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommands.cpp` - Main command handler
- ✅ `src/server/scripts/DC/ItemUpgrades/ItemUpgradeProgressionImpl.cpp` - Progression tracking

### Database
- ✅ `Custom/ITEMUPGRADE_FINAL_SETUP.sql` - Complete schema + data
- ✅ Character DB: `dc_item_upgrade_state` table
- ✅ World DB: `dc_item_upgrade_costs` table

### Configuration
- ✅ `acore.conf` entries:
  ```ini
  ItemUpgrade.Currency.EssenceId = 100998
  ItemUpgrade.Currency.TokenId = 100999
  ```

## Archived (Legacy) Files

The following files are NOT USED and have been archived:
- ❌ `dc_item_upgrade_phase4a.sql` - Advanced schema (not used)
- ❌ `dc_item_upgrade_schema.sql` (world) - Complex configuration (not used)
- ❌ `item_upgrade_transmutation_*.sql` - Synthesis features (not used)

See: `Custom/ARCHIVE/ItemUpgrade_OldImplementations/` for these files.

## Commands

```
/dcupgrade init
├─ Returns: DCUPGRADE_INIT:tokens:essence
├─ Example: DCUPGRADE_INIT:500:250
└─ Shows current inventory items

/dcupgrade query <bag> <slot>
├─ Returns: DCUPGRADE_QUERY:item_guid:level:tier:ilvl
├─ Example: DCUPGRADE_QUERY:123456:5:3:350
└─ Shows item upgrade state

/dcupgrade perform <bag> <slot> <level>
├─ Returns: DCUPGRADE_SUCCESS:item_guid:new_level
├─ Example: .perform 0 5 10
└─ Upgrades item (deducts items from inventory)
```

## Testing

```powershell
# Give test items
.additem 100999 500      # 500 Upgrade Tokens
.additem 100998 250      # 250 Artifact Essence

# Check balance
/dcupgrade init
# Should show: DCUPGRADE_INIT:500:250

# Look in bags
# Should see items stacked in inventory
```

## Next Steps

- [ ] Execute `ITEMUPGRADE_FINAL_SETUP.sql`
- [ ] Rebuild C++ (acore.sh compiler build)
- [ ] Test commands with items
- [ ] Monitor for errors
- [ ] Implement token acquisition (quests/vendor/PvP)

## Support

For issues, check:
1. Table structures exist: `SHOW TABLES LIKE 'dc_item_upgrade%'`
2. Costs populated: `SELECT COUNT(*) FROM dc_item_upgrade_costs;`
3. Items exist: `SELECT entry FROM item_template WHERE entry IN (100998, 100999);`
4. Config set: Check `acore.conf` for ItemUpgrade settings
```

---

## EXECUTION CHECKLIST

### Before Changes
- [ ] Backup database (`mysqldump`)
- [ ] Backup `Custom/` folder
- [ ] Read this entire plan
- [ ] Review audit report

### Phase 1: Fix Code (5 min)
- [ ] Fix ItemUpgradeCommands.cpp line 169 (column names)
- [ ] Fix ItemUpgradeProgressionImpl.cpp lines 599-600 (hardcoded IDs)

### Phase 2: Archive Files (15 min)
- [ ] Create `Custom/ARCHIVE/ItemUpgrade_OldImplementations/`
- [ ] Move 5+ conflicting SQL files to archive
- [ ] Create archive README.md

### Phase 3: Consolidate Setup (15 min)
- [ ] Create `Custom/ITEMUPGRADE_FINAL_SETUP.sql`
- [ ] Verify all 75 INSERT statements included
- [ ] Verify both CREATE TABLE statements included

### Phase 4: Document (10 min)
- [ ] Create `Custom/ITEMUPGRADE_SYSTEM_STATUS.md`
- [ ] Create system summary

### After Changes
- [ ] Recompile C++ (`acore.sh compiler build`)
- [ ] Execute setup SQL on both databases
- [ ] Verify table structures match
- [ ] Test `/dcupgrade init` command
- [ ] Monitor server.log for errors

---

## ROLLBACK PLAN (If Needed)

If something goes wrong:

1. **Restore C++ code:**
   ```powershell
   git checkout HEAD -- src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommands.cpp
   git checkout HEAD -- src/server/scripts/DC/ItemUpgrades/ItemUpgradeProgressionImpl.cpp
   ```

2. **Restore database:**
   ```powershell
   mysql acore_characters < backup_characters.sql
   mysql acore_world < backup_world.sql
   ```

3. **Restore file structure:**
   ```powershell
   Copy-Item -Recurse "Custom/ARCHIVE/ItemUpgrade_OldImplementations/*" -Destination "Custom/Custom feature SQLs/"
   ```

4. **Recompile:**
   ```powershell
   ./acore.sh compiler clean
   ./acore.sh compiler build
   ```

---

## TIME ESTIMATE

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Fix code bugs | 5 min | Ready |
| 2 | Archive files | 15 min | Ready |
| 3 | Create setup | 15 min | Ready |
| 4 | Documentation | 10 min | Ready |
| **Total** | **All** | **45 min** | **Ready** |

---

## SUCCESS CRITERIA

✅ System is considered "fixed" when:
1. Both C++ files compile without errors
2. SQL setup script executes cleanly (no errors)
3. `/dcupgrade init` returns correct format
4. `/dcupgrade query` finds item data
5. `/dcupgrade perform` can deduct items from inventory
6. No orphaned/unused code remains
7. Documentation is current

---

## WHO SHOULD DO THIS?

This cleanup is suitable for:
- ✅ Server administrators with database access
- ✅ Developers familiar with SQL
- ✅ Anyone comfortable editing C++ code

This cleanup should NOT be done by:
- ❌ Non-technical players
- ❌ People unfamiliar with SQL
- ❌ People without database backups

---

**Ready to proceed? Execute steps 1-4 above in order.**

