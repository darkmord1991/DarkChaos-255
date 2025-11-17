# 🔍 Item Upgrade System - Deep Investigation Report
**Date:** November 17, 2025  
**Investigator:** GitHub Copilot  
**Scope:** Complete system architecture analysis

---

## 📊 EXECUTIVE SUMMARY

### Current System State
- **Active Tiers:** 3 (Tier 1, Tier 2, Tier 3 - Heirlooms)
- **Database Tables:** 13 character DB + 8+ world DB tables
- **Code Implementation:** Supports 6 tiers (1-6) but only 3 are actively used
- **Major Issues Found:** 4 critical inconsistencies

---

## 🎯 YOUR QUESTIONS ANSWERED

### Q1: "We only use tier 1-2 for regular upgrades and tier 3 for heirlooms - why are there additional hardcoded ones?"

**ANSWER:** Historical feature creep and incomplete cleanup.

**What You're Actually Using:**
```
✅ TIER 1 (TIER_LEVELING = 1)
   - Purpose: Regular quest/dungeon items
   - Max Level: 60 upgrades
   - Stat Multiplier: 1.0x → 2.35x (+135%)
   - Currency: Upgrade Tokens

✅ TIER 2 (TIER_HEROIC = 2)
   - Purpose: Heroic dungeon items  
   - Max Level: 15 upgrades
   - Stat Multiplier: 1.35x → 1.6125x (+61.25%)
   - Currency: Upgrade Tokens

✅ TIER 3 (TIER_HEIRLOOM = 6 in code, but uses ID 3 in DB!)
   - Purpose: Bind-on-Account heirlooms (191101-191133)
   - Max Level: 15 upgrades
   - Stat Multiplier: 1.05x → 1.35x (SECONDARY STATS ONLY)
   - Currency: Artifact Essence
   - Special: Primary stats scale with character level automatically
```

**What's Hardcoded But NOT Used:**
```
❌ TIER_RAID = 3 (enum value) - UNUSED
   - Never implemented
   - No items assigned
   - No costs defined

❌ TIER_MYTHIC = 4 (enum value) - UNUSED
   - Never implemented  
   - No items assigned
   - No costs defined

❌ TIER_ARTIFACT = 5 (enum value) - PARTIALLY IMPLEMENTED
   - Code exists but no items use it
   - Was intended for "Chaos Artifacts" system
   - Tables exist but empty
```

**Root Cause:**
The header file [`ItemUpgradeManager.h`](ItemUpgradeManager.h ) defines 6 tier enums (lines 27-35) but only 3 are actually implemented in SQL and used in practice. The extra tiers were likely planned features that were never completed.

---

### Q2: "Why does mastery exist in WotLK 3.3.5a code?"

**ANSWER:** The word "mastery" in your code is NOT referring to the Cataclysm mastery stat. It's a custom "Artifact Mastery" progression system (renamed from "Prestige").

**Evidence:**

**File:** [`ItemUpgradeProgressionImpl.cpp`](ItemUpgradeProgressionImpl.cpp ) (Lines 8, 31-37)
```cpp
// Line 8 comment:
"Artifact Mastery system (renamed from Prestige to avoid conflict with DarkChaos Prestige System)"

// Line 34-37:
class ArtifactMasteryManagerImpl : public ArtifactMasteryManager
{
    std::map<uint32, PlayerArtifactMasteryInfo> mastery_cache;
    // ^ This is CUSTOM progression, not WoW stat
```

**Database Table:**
```sql
dc_player_artifact_mastery
├─ total_mastery_points (experience-like points)
├─ mastery_rank (1-10 progression tier)
├─ mastery_points_this_rank (progress toward next tier)
└─ mastery_title (e.g., "Novice", "Expert", "Master")
```

**What It Actually Does:**
- Players earn "Artifact Mastery Points" by upgrading items
- Points increase "Mastery Rank" (1-10)
- Each rank unlocks cosmetic titles
- **NOT RELATED** to WoW's Mastery rating stat (which doesn't exist in 3.3.5a)

**Actual Secondary Stats Modified:**
According to [`ItemUpgradeMechanicsImpl.cpp:145`](ItemUpgradeMechanicsImpl.cpp:145 ):
```cpp
// IMPORTANT: This ONLY affects secondary stats (Crit/Haste/Mastery)
//            ^^^ This comment is WRONG - "Mastery" shouldn't be here
```

**WotLK 3.3.5a Actually Has:**
- ✅ Crit Rating
- ✅ Haste Rating  
- ✅ Hit Rating
- ✅ Expertise
- ✅ Armor Penetration
- ✅ Dodge/Parry
- ❌ Mastery (added in Cataclysm 4.0.1)

**Recommendation:** Fix the misleading comment to remove "Mastery" reference or clarify it's artifact progression, not a stat.

---

## 🗄️ DATABASE ARCHITECTURE ANALYSIS

### Table Inventory

#### **Character Database (13 tables):**
```
✅ ACTIVELY USED (3):
1. dc_player_item_upgrades       - Main upgrade tracking
2. dc_player_upgrade_tokens       - Currency balances  
3. dc_token_transaction_log       - Audit trail

⚠️ PROGRESSION FEATURES (4):
4. dc_weekly_spending             - Weekly caps (if enabled)
5. dc_player_artifact_mastery     - Mastery progression
6. dc_player_tier_unlocks         - Tier gating (if enabled)
7. dc_player_tier_caps            - Custom caps (if enabled)

📦 ADVANCED FEATURES (6):
8. dc_player_artifact_discoveries - Artifact hunting (unused?)
9. dc_tier_conversion_log         - Tier migration history
10. dc_item_upgrade_transmutation_sessions - Crafting system
11. dc_player_transmutation_cooldowns      - Cooldown tracking
12. dc_artifact_mastery_events    - Progression logging
13. dc_season_history             - Seasonal tracking
```

#### **World Database (8+ tables):**
```
✅ CORE TABLES (5):
1. dc_item_upgrade_tiers          - Tier definitions (3 rows active)
2. dc_item_upgrade_enchants       - Stat multipliers (75 rows)
3. dc_item_templates_upgrade      - Which items can upgrade
4. dc_item_proc_spells            - Proc spell mapping
5. dc_item_upgrade_clones         - Item swap system (for tiered items)

📦 ADVANCED FEATURES (3+):
6. dc_item_upgrade_synthesis_recipes - Crafting recipes
7. dc_item_upgrade_synthesis_inputs  - Recipe materials
8. dc_chaos_artifact_items           - Artifact definitions (empty?)
```

### Critical Inconsistency #1: Tier ID Mismatch

**The Problem:**
```
C++ Code (ItemUpgradeManager.h):
  TIER_HEIRLOOM = 6  ← Enum value

SQL Database (HEIRLOOM_TIER3_SYSTEM_WORLD.sql):
  INSERT INTO dc_item_upgrade_costs (tier_id, ...) VALUES (3, ...) ← Uses ID 3!
  
Database Schema (ItemUpgrade_Schema_WORLD.sql):
  (1, 'Tier 1 - Basic Upgrade', ...)
  (2, 'Tier 2 - Advanced Upgrade', ...)
  (3, 'Tier 3 - Premium Upgrade', ...)  ← Heirlooms stored as tier 3
  (4, 'Tier 4 - Expert Upgrade', ...)   ← Reserved/unused
  (5, 'Tier 5 - Legendary Upgrade', ...) ← Reserved/unused
```

**Impact:** Moderate - System works because SQL always uses `tier_id` directly, but creates confusion when reading code vs database.

**Recommendation:** 
- Option A: Change C++ enum to match DB (`TIER_HEIRLOOM = 3`)
- Option B: Change DB to use tier_id=6 for heirlooms
- Option C: Document the discrepancy clearly

---

### Critical Inconsistency #2: Multiple Cost Table Schemas

**File 1:** [`ItemUpgrade_Schema_WORLD.sql`](ItemUpgrade_Schema_WORLD.sql )
```sql
-- NO dc_item_upgrade_costs table defined!
-- Only has dc_item_upgrade_enchants
```

**File 2:** [`HEIRLOOM_TIER3_SYSTEM_WORLD.sql`](HEIRLOOM_TIER3_SYSTEM_WORLD.sql ) (Lines 457-481)
```sql
INSERT INTO dc_item_upgrade_costs 
  (tier_id, upgrade_level, token_cost, essence_cost, ilvl_bonus, stat_multiplier, season)
VALUES
  (3, 0, 0, 0, 0, 1.05, 1),
  (3, 1, 0, 75, 2, 1.07, 1),
  ...
  (3, 15, 0, 281, 30, 1.35, 1);
```

**File 3:** Documentation mentions different schemas
```sql
-- Phase 4A version (conflicting):
dc_item_upgrade_costs (
  tier_id PRIMARY KEY,  ← No upgrade_level!
  base_essence_cost FLOAT,
  escalation_rate FLOAT,
  ...
)

-- Actual version (correct):
dc_item_upgrade_costs (
  tier_id, upgrade_level, ← Composite key
  token_cost, essence_cost,
  ilvl_bonus, stat_multiplier,
  season
)
```

**Impact:** HIGH - If wrong schema is installed, all upgrade cost queries will fail.

**Recommendation:** Create ONE canonical `dc_item_upgrade_costs_CREATE.sql` with the correct schema and remove conflicting documentation.

---

### Critical Inconsistency #3: Tier Max Levels

**Code Says:**
```cpp
// ItemUpgradeManager.h:44
static const uint8 MAX_UPGRADE_LEVEL = 15;

// But Tier 1 actually has 60 levels!
```

**Database Says:**
```sql
-- dc_item_upgrade_enchants has:
Tier 1: 60 enchants (80001-80060)  ← 60 levels!
Tier 2: 15 enchants (80101-80115)  ← 15 levels
Tier 3: 16 entries (0-15)          ← 16 levels (0 is base)
```

**C++ Implementation:**
```cpp
// ItemUpgradeManager.cpp lines 610-615
case TIER_LEVELING: return 5;   ← WRONG! Should be 60
case TIER_HEROIC: return 8;     ← WRONG! Should be 15
case TIER_HEIRLOOM: return 10;  ← WRONG! Should be 15
```

**Impact:** CRITICAL - Players cannot upgrade beyond hardcoded limits even though costs and enchants exist!

**Recommendation:** Fix `GetTierMaxLevel()` to return correct values:
```cpp
case TIER_LEVELING: return 60;
case TIER_HEROIC: return 15;  
case TIER_HEIRLOOM: return 15;
```

---

### Critical Inconsistency #4: Stat Scaling for Heirlooms

**Documentation Says:**
```sql
-- HEIRLOOM_TIER3_SYSTEM_WORLD.sql comments (lines 450-454):
"Upgrades ADD secondary stats to heirloom items (not scale primary stats)."
"Primary stats scale with character level automatically."
"stat_multiplier controls SECONDARY stat scaling only (1.05x → 1.35x)."
```

**But Code Says:**
```cpp
// ItemUpgradeMechanicsImpl.cpp:145
"This ONLY affects secondary stats (Crit/Haste/Mastery)"
//                                              ^^^^^^^ WRONG STAT!
```

**WotLK 3.3.5a Actually Has:**
- Strength, Agility, Stamina, Intellect, Spirit (Primary)
- Crit, Haste, Hit, Expertise, Armor Pen (Secondary - NO MASTERY!)

**Impact:** Moderate - Code works but documentation is misleading.

**Recommendation:** Update comment to:
```cpp
// This ONLY affects secondary stats (Crit/Haste/Hit/Expertise/ArmorPen)
```

---

## 🏗️ ARCHITECTURE RECOMMENDATIONS

### Immediate Actions (High Priority)

1. **Fix Tier Max Levels** ⚠️ CRITICAL
   ```cpp
   // File: ItemUpgradeManager.cpp
   // Function: GetTierMaxLevel()
   
   case TIER_LEVELING: return 60;  // Fix: was 5
   case TIER_HEROIC: return 15;    // Fix: was 8
   case TIER_HEIRLOOM: return 15;  // Fix: was 10
   ```

2. **Remove Unused Tier Enums** 🗑️
   ```cpp
   // File: ItemUpgradeManager.h
   
   // DELETE these unused enums:
   // TIER_RAID = 3,
   // TIER_MYTHIC = 4,
   // TIER_ARTIFACT = 5,
   
   // Keep only:
   TIER_LEVELING = 1,
   TIER_HEROIC = 2,
   TIER_HEIRLOOM = 3,  // Change from 6 to 3 to match DB
   ```

3. **Create Canonical Cost Table Schema** 📄
   - Single authoritative `dc_item_upgrade_costs_CREATE.sql`
   - Columns: `tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_bonus`, `stat_multiplier`, `season`
   - Delete conflicting schemas from documentation

4. **Fix Misleading Comments** 📝
   - Remove "Mastery" references from stat scaling comments
   - Clarify "Artifact Mastery" is progression, not WoW stat
   - Update secondary stat list to WotLK-accurate stats

### Medium Priority

5. **Consolidate Database Documentation**
   - Too many conflicting SQL files in `Custom/feature stuff/item upgrade system/`
   - Create single `DATABASE_SCHEMA_REFERENCE.md`
   - Archive old design documents

6. **Clean Up Character DB Tables**
   - 13 tables is excessive for current feature set
   - Evaluate if advanced features (synthesis, transmutation) are used
   - Consider merging or removing unused tables

7. **Standardize Table Prefixes**
   - All tables use `dc_` prefix ✅
   - But some are in characters DB, some in world DB
   - Document which tables go where

### Low Priority

8. **Add Missing Tier 1 Costs**
   - Database has 60 enchants for Tier 1
   - But no rows in `dc_item_upgrade_costs` for tier_id=1
   - Need to populate levels 16-60 costs

9. **Remove "Season" Columns If Unused**
   - Many tables have `season` column
   - If seasonal system isn't implemented, remove to simplify

10. **Consolidate Tier Definition Tables**
    - Both `dc_item_upgrade_tiers` and `dc_item_upgrade_enchants` exist
    - Consider merging or clarifying purpose

---

## 📋 QUICK ACTION CHECKLIST

```
[ ] Fix GetTierMaxLevel() function (returns 5/8/10 instead of 60/15/15)
[ ] Change TIER_HEIRLOOM enum from 6 to 3
[ ] Remove TIER_RAID, TIER_MYTHIC, TIER_ARTIFACT enums
[ ] Fix "Mastery" comments in ItemUpgradeMechanicsImpl.cpp
[ ] Create canonical dc_item_upgrade_costs schema SQL file
[ ] Document tier ID mapping (enum vs database)
[ ] Add Tier 1 upgrade costs for levels 16-60
[ ] Consolidate database documentation
[ ] Evaluate unused character DB tables
[ ] Update system architecture diagram
```

---

## 🎯 SIMPLIFIED SYSTEM SUMMARY

### What Your System Actually Does

**Tier 1 (Regular Items):**
- 60 upgrade levels
- Uses Upgrade Tokens
- Stat multiplier: 1.0x → 2.35x
- For: Quest rewards, dungeon drops (blue/epic quality)

**Tier 2 (Heroic Items):**
- 15 upgrade levels  
- Uses Upgrade Tokens
- Stat multiplier: 1.35x → 1.6125x
- For: Heroic dungeon gear (ilvl 213-226)

**Tier 3 (Heirlooms):**
- 15 upgrade levels
- Uses Artifact Essence (NOT tokens)
- Stat multiplier: 1.05x → 1.35x (SECONDARY STATS ONLY)
- For: Bind-on-Account items (191101-191133)
- Special: Primary stats auto-scale with character level

### What Your System DOESN'T Do

❌ Mythic+ upgrades (Tier 4) - Not implemented  
❌ Raid upgrade track (Tier 3 enum) - Not implemented  
❌ Chaos Artifacts (Tier 5) - Partially implemented but unused  
❌ Modify Mastery stat - Doesn't exist in WotLK  
❌ Seasonal resets - Tables exist but feature unused  
❌ Item synthesis/transmutation - Tables exist but feature unused

---

## 💾 DATABASE SCHEMA SUMMARY

### Required Tables (Actually Used)

**Characters DB:**
```
dc_player_item_upgrades      - Main upgrade data
dc_player_upgrade_tokens     - Currency balances
dc_token_transaction_log     - Audit log
```

**World DB:**
```
dc_item_upgrade_tiers        - 3 tier definitions
dc_item_upgrade_enchants     - 75 stat multipliers
dc_item_upgrade_costs        - Cost matrix (missing Tier 1!)
dc_item_templates_upgrade    - Eligible items
dc_item_proc_spells          - Proc mappings
```

### Optional Tables (Advanced Features)

**If You Use Weekly Caps:**
```
dc_weekly_spending           - Spending tracker
```

**If You Use Artifact Mastery Progression:**
```
dc_player_artifact_mastery   - Progression points
dc_artifact_mastery_events   - Event log
```

**If You Use Tier Gating:**
```
dc_player_tier_unlocks       - Unlock status
dc_player_tier_caps          - Custom limits
```

**If You Use Crafting System:**
```
dc_item_upgrade_synthesis_recipes      - Recipe definitions
dc_item_upgrade_synthesis_inputs       - Required materials
dc_item_upgrade_transmutation_sessions - Active crafts
dc_player_transmutation_cooldowns      - Cooldown tracking
```

---

## 🔧 RECOMMENDED FIXES

### File: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.h`

**Change Lines 27-35:**
```cpp
// BEFORE:
enum UpgradeTier : uint8
{
    TIER_LEVELING = 1,
    TIER_HEROIC = 2,
    TIER_RAID = 3,        // ← Remove
    TIER_MYTHIC = 4,      // ← Remove
    TIER_ARTIFACT = 5,    // ← Remove
    TIER_HEIRLOOM = 6,    // ← Wrong ID!
    TIER_INVALID = 0
};

// AFTER:
enum UpgradeTier : uint8
{
    TIER_LEVELING = 1,    // Regular items (60 levels)
    TIER_HEROIC = 2,      // Heroic items (15 levels)
    TIER_HEIRLOOM = 3,    // Heirlooms (15 levels, secondary stats only)
    TIER_INVALID = 0
};
```

### File: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.cpp`

**Change Lines 610-615:**
```cpp
// BEFORE:
case TIER_LEVELING: return 5;
case TIER_HEROIC: return 8;
case TIER_HEIRLOOM: return 10;

// AFTER:
case TIER_LEVELING: return 60;
case TIER_HEROIC: return 15;
case TIER_HEIRLOOM: return 15;
```

### File: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeMechanicsImpl.cpp`

**Change Line 145:**
```cpp
// BEFORE:
// IMPORTANT: This ONLY affects secondary stats (Crit/Haste/Mastery)

// AFTER:
// IMPORTANT: This ONLY affects secondary stats (Crit/Haste/Hit/Expertise/ArmorPen)
// Note: "Mastery" stat does not exist in WotLK 3.3.5a (added in Cataclysm)
```

### New File: `Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_item_upgrade_costs_CREATE.sql`

```sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- DC ITEM UPGRADE COSTS - CANONICAL SCHEMA
-- Single authoritative cost table for all 3 tiers
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_costs` (
  `tier_id` TINYINT UNSIGNED NOT NULL,
  `upgrade_level` TINYINT UNSIGNED NOT NULL,
  `token_cost` INT UNSIGNED DEFAULT 0,
  `essence_cost` INT UNSIGNED DEFAULT 0,
  `ilvl_bonus` SMALLINT UNSIGNED DEFAULT 0,
  `stat_multiplier` FLOAT NOT NULL DEFAULT 1.0,
  `season` INT UNSIGNED DEFAULT 1,
  PRIMARY KEY (`tier_id`, `upgrade_level`, `season`),
  KEY `idx_tier` (`tier_id`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Upgrade cost matrix for all tiers and levels';

-- TODO: Insert Tier 1 costs (60 rows for levels 1-60)
-- TODO: Insert Tier 2 costs (15 rows for levels 1-15)
-- Tier 3 costs already exist in HEIRLOOM_TIER3_SYSTEM_WORLD.sql
```

---

## ✅ CONCLUSION

Your system is **functional but over-engineered**. You're using 3 tiers but have code/tables for 6+ tiers. The core upgrade mechanics work, but there's significant technical debt from incomplete features and inconsistent documentation.

**Recommended Path Forward:**
1. Apply the 4 critical fixes listed above (1-2 hours work)
2. Remove unused tables to simplify maintenance
3. Consolidate documentation into single reference
4. Consider if advanced features (synthesis, mastery progression) are worth keeping

**System Grade:** C+ (Works but needs cleanup)

---

**End of Investigation Report**
