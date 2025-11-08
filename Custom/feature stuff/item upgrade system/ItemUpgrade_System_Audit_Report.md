# Item Upgrade System - Complete Audit Report

**Date:** November 8, 2025  
**Status:** System review for duplicates, database issues, and standardization

---

## 🔴 CRITICAL ISSUE: Duplicate Table Names!

The system uses **TWO DIFFERENT** table naming schemes:

### **Table Name Conflicts:**
1. `dc_item_upgrade_state` (used by AddonHandler, some old code)
2. `dc_player_item_upgrades` (used by Manager, most new code)

**These appear to be THE SAME table with different names!**

---

## 📊 Database Tables Analysis

### **REQUIRED TABLES** (actively used):

#### Core Tables:
- ✅ `dc_player_item_upgrades` - Main item upgrade tracking (PRIMARY)
- ❌ `dc_item_upgrade_state` - DUPLICATE of above - **NEEDS REMOVAL**
- ✅ `dc_item_upgrade_costs` - Cost per tier/level
- ✅ `dc_item_upgrade_enchants` - Enchantment mapping (NEW - hybrid system)
- ✅ `dc_item_proc_spells` - Proc spell tracking (NEW - hybrid system)

#### Currency & Tokens:
- ✅ `dc_player_upgrade_tokens` - Player currency tracking
- ✅ `dc_token_transaction_log` - Transaction audit log
- ✅ `dc_weekly_spending` - Weekly caps tracking

#### Progression:
- ✅ `dc_player_artifact_mastery` - Mastery points/rank
- ✅ `dc_player_tier_unlocks` - Tier unlock tracking
- ✅ `dc_player_tier_caps` - Per-tier level caps
- ✅ `dc_artifact_mastery_events` - Event logging

#### Transmutation/Synthesis:
- ✅ `dc_item_upgrade_synthesis_recipes` - Transmutation recipes
- ✅ `dc_item_upgrade_synthesis_inputs` - Recipe ingredients
- ✅ `dc_player_transmutation_cooldowns` - Per-recipe cooldowns
- ✅ `dc_item_upgrade_transmutation_sessions` - Active transmutations
- ✅ `dc_tier_conversion_log` - Tier change audit

#### Discovery & Artifacts:
- ✅ `dc_player_artifact_discoveries` - Discovered artifacts
- ✅ `dc_chaos_artifact_items` - Artifact definitions

#### Configuration:
- ✅ `dc_item_upgrade_tiers` - Tier definitions
- ✅ `dc_item_templates_upgrade` - Which items can upgrade
- ✅ `dc_season_history` - Season tracking

---

## 🔧 Required Fixes

### 1. **CRITICAL: Fix Table Name Inconsistency**

**Files using `dc_item_upgrade_state` (WRONG):**
- `ItemUpgradeAddonHandler.cpp` (lines 169, 260, 363)
- ~~`ItemUpgradeCommands.cpp`~~ (file doesn't exist - grep found old code)

**Solution:** Change all `dc_item_upgrade_state` → `dc_player_item_upgrades`

### 2. **Remove Unused/Old Code**

**Potential unused systems:**
- `ItemUpgradeMechanicsCommands.cpp` - Debug commands (keep if useful)
- `ItemUpgradeSynthesisImpl.cpp` - Seems unused (no registration found)

### 3. **Add Loading Banner**

Like Dungeon Quest System, add comprehensive startup message showing:
- System version
- Features loaded
- Module count

---

## 📦 File Count & Organization

### Current Structure: **24 files** (after optimization)

**Core System (5 files):**
1. ItemUpgradeManager.cpp/h - Central manager
2. ItemUpgradeMechanicsImpl.cpp - Stat calculations
3. ItemUpgradeMechanics.h - Mechanics interface
4. ItemUpgradeUIHelpers.h - UI utilities
5. ItemUpgradeStatApplication.cpp - Enchantment application

**Commands (2 files):**
6. ItemUpgradeGMCommands.cpp - `.upgrade` commands
7. ItemUpgradeAddonHandler.cpp - `.dcupgrade` commands

**NPCs (3 files):**
8. ItemUpgradeNPC_Vendor.cpp - Token vendor
9. ItemUpgradeNPC_Curator.cpp - Artifact curator
10. ItemUpgradeNPC_Upgrader.cpp - Upgrade NPC

**Features (8 files):**
11. ItemUpgradeProgressionImpl.cpp/h - Mastery system
12. ItemUpgradeSeasonalImpl.cpp/h - Season support
13. ItemUpgradeAdvancedImpl.cpp/h - Advanced features
14. ItemUpgradeTransmutationImpl.cpp/h - Transmutation
15. ItemUpgradeTransmutationNPC.cpp - Transmutation NPC

**Hooks & Systems (4 files):**
16. ItemUpgradeTokenHooks.cpp - Currency hooks
17. ItemUpgradeProcScaling.cpp - Proc scaling (NEW v2.0)
18. ItemUpgradeCommunication.cpp/h - Inter-system comm

**Unused/Questionable (2 files):**
19. ItemUpgradeMechanicsCommands.cpp - Debug commands?
20. ItemUpgradeSynthesisImpl.cpp - Not registered?

---

## 🎯 Recommendations

### Immediate Actions:
1. ✅ Fix `dc_item_upgrade_state` → `dc_player_item_upgrades` in AddonHandler
2. ✅ Add loading banner to dc_script_loader.cpp
3. ✅ Verify `ItemUpgradeSynthesisImpl.cpp` usage
4. ✅ Document all database tables with CREATE statements
5. ✅ Add version tracking

### Medium Priority:
- Create single database schema SQL file
- Add migration script for table rename
- Consolidate documentation
- Add system status command (`.upgrade status`)

### Low Priority:
- Remove debug commands if unused
- Optimize table indices
- Add database cleanup scripts
- Implement proper versioning

---

## 📝 Proposed Loading Banner

```cpp
LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
LOG_INFO("scripts", ">> Loading DarkChaos Item Upgrade System v2.0");
LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
LOG_INFO("scripts", ">>   Core Features:");
LOG_INFO("scripts", ">>     • Hybrid Stat Scaling (Enchantment-based)");
LOG_INFO("scripts", ">>     • UnitScript Proc Scaling");
LOG_INFO("scripts", ">>     • 5 Tiers × 15 Levels = 75 upgrade paths");
LOG_INFO("scripts", ">>     • Mastery & Progression System");
LOG_INFO("scripts", ">>     • Transmutation & Tier Conversion");
LOG_INFO("scripts", ">>   Modules: 18 active, 24 total files");
LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
```

---

## 🗄️ Complete Database Schema Summary

### Character Database Tables (19 tables):
```
dc_player_item_upgrades          - Item upgrade states
dc_player_upgrade_tokens         - Player currency
dc_token_transaction_log         - Audit log
dc_weekly_spending               - Weekly caps
dc_player_artifact_mastery       - Mastery progression
dc_player_tier_unlocks           - Tier unlocks
dc_player_tier_caps              - Level caps
dc_artifact_mastery_events       - Event history
dc_player_transmutation_cooldowns - Cooldowns
dc_item_upgrade_transmutation_sessions - Active sessions
dc_tier_conversion_log           - Conversion audit
dc_player_artifact_discoveries   - Discoveries
dc_season_history                - Season data
```

### World Database Tables (10 tables):
```
dc_item_upgrade_costs            - Cost definitions
dc_item_upgrade_tiers            - Tier definitions
dc_item_templates_upgrade        - Upgradeable items
dc_chaos_artifact_items          - Artifact catalog
dc_item_upgrade_synthesis_recipes - Recipes
dc_item_upgrade_synthesis_inputs  - Recipe ingredients
dc_item_upgrade_enchants         - Enchant mapping (NEW)
dc_item_proc_spells              - Proc tracking (NEW)
```

### Deprecated/Remove:
```
dc_item_upgrade_state            - DUPLICATE - remove!
```

---

## ✅ Action Checklist

### Phase 1: Critical Fixes
- [ ] Fix table name in ItemUpgradeAddonHandler.cpp
- [ ] Add loading banner
- [ ] Test table consistency
- [ ] Verify all registrations

### Phase 2: Cleanup
- [ ] Remove/document unused files
- [ ] Create complete schema SQL
- [ ] Update documentation
- [ ] Add version constants

### Phase 3: Polish
- [ ] Optimize queries
- [ ] Add status commands
- [ ] Create migration guide
- [ ] Performance testing

---

**Next Steps:** Fix the table name inconsistency first, then add the loading banner.

