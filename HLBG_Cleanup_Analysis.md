# HLBG Addon and Database Cleanup Analysis

## Current Status Analysis (October 5, 2025)

Based on my analysis of the addon versions and database tables, here are my recommendations for cleanup and consolidation:

## 📂 **Addon Version Analysis**

### Current Versions:
1. **HinterlandAffixHUD** (Main) - 61 files, last updated 2025-10-04 14:35
2. **HinterlandAffixHUD_Test** - 58 files, last updated 2025-10-05 12:39 ✅ **ACTIVE**
3. **HinterlandAffixHUD_Emergency** - 6 files, last updated 2025-10-04 14:21
4. **HinterlandAffixHUD_Minimal** - 8 files, last updated 2025-10-04 14:21

### **Recommendations:**

#### ✅ **KEEP: HinterlandAffixHUD_Test**
- **Purpose:** Production-ready enhanced version with all new features
- **Status:** Contains latest enhancements (Modern HUD, Telemetry, Enhanced Settings, etc.)
- **Action:** Rename to `HinterlandAffixHUD` and make it the main production version

#### ❌ **REMOVE: HinterlandAffixHUD (Main)**
- **Purpose:** Legacy version with outdated code
- **Status:** Superseded by Test version enhancements
- **Issues:** Contains duplicate/conflicting files, backup folders, outdated architecture
- **Action:** Archive and remove - all functionality moved to Test version

#### ❌ **REMOVE: HinterlandAffixHUD_Emergency**
- **Purpose:** Minimal emergency fallback
- **Status:** Obsolete - modern addon is stable and reliable
- **Issues:** Limited functionality, no longer needed with robust Test version
- **Action:** Remove entirely - ssh-sync-and-build handles testing needs

#### ❌ **REMOVE: HinterlandAffixHUD_Minimal**
- **Purpose:** Lightweight version for performance testing
- **Status:** Obsolete - telemetry in main addon provides better performance monitoring
- **Issues:** Lacks essential features, redundant with main addon's performance optimizations
- **Action:** Remove entirely - main addon now has performance monitoring built-in

---

## 🗄️ **Database Tables Analysis**

### From the screenshots showing table row counts:
- `hlbg_affixes`: 16 rows ✅ **KEEP**
- `hlbg_battle_history`: 0 rows ✅ **KEEP** (new table, not used yet)
- `hlbg_config`: 2 rows ✅ **KEEP**
- `hlbg_player_stats`: 0 rows ✅ **KEEP** (new table, not used yet)
- `hlbg_seasons`: 0 rows ✅ **KEEP** (new table, not used yet)
- `hlbg_statistics`: 3 rows ✅ **KEEP**
- `hlbg_weather`: 4 rows ❓ **EVALUATE**
- `hlbg_winner_history`: 29 rows ⚠️ **MIGRATE TO hlbg_battle_history**

### **Database Recommendations:**

#### ✅ **KEEP (Core Tables)**
- `hlbg_affixes` - Actively used by server code for affix definitions
- `hlbg_config` - Configuration settings
- `hlbg_statistics` - Global statistics tracking
- `hlbg_battle_history` - New enhanced history table (replaces hlbg_winner_history)
- `hlbg_player_stats` - Individual player tracking (new)
- `hlbg_seasons` - Season management (new)

#### ❓ **EVALUATE: hlbg_weather**
- **Current Usage:** Unknown - need to check if weather system is active
- **Recommendation:** Check server code usage and either integrate or remove

#### ⚠️ **MIGRATE: hlbg_winner_history → hlbg_battle_history**
- **Issue:** Server code still uses `hlbg_winner_history` (29 rows of data)
- **Action Required:** 
  1. Migrate existing data from `hlbg_winner_history` to `hlbg_battle_history`
  2. Update server code to use new table structure
  3. Drop `hlbg_winner_history` after migration

---

## 🔧 **Recommended Cleanup Actions**

### **Phase 1: Addon Consolidation**
```powershell
# 1. Backup current main addon
Move-Item "HinterlandAffixHUD" "HinterlandAffixHUD_OLD_BACKUP"

# 2. Promote Test version to main
Move-Item "HinterlandAffixHUD_Test" "HinterlandAffixHUD"

# 3. Remove obsolete versions
Remove-Item "HinterlandAffixHUD_Emergency" -Recurse -Force
Remove-Item "HinterlandAffixHUD_Minimal" -Recurse -Force

# 4. Clean up backup after verification
# Remove-Item "HinterlandAffixHUD_OLD_BACKUP" -Recurse -Force
```

### **Phase 2: Database Migration** (Requires Server Code Updates)

#### Step 1: Data Migration Script
```sql
-- Migrate data from hlbg_winner_history to hlbg_battle_history
INSERT INTO hlbg_battle_history (
    battle_start, battle_end, duration_seconds, winner_faction, 
    alliance_resources, horde_resources, affix_id, map_id
)
SELECT 
    occurred_at,
    occurred_at + INTERVAL duration_seconds SECOND,
    duration_seconds,
    CASE 
        WHEN winner_tid = 0 THEN 'Alliance'
        WHEN winner_tid = 1 THEN 'Horde' 
        ELSE 'Draw'
    END,
    score_alliance,
    score_horde,
    affix,
    map_id
FROM hlbg_winner_history;
```

#### Step 2: Update Server Code
- Update `OutdoorPvPHL_Admin.cpp` and `HL_ScoreboardNPC.cpp` 
- Replace `hlbg_winner_history` references with `hlbg_battle_history`
- Use new enhanced table structure

#### Step 3: Drop Old Table (After Migration)
```sql
DROP TABLE hlbg_winner_history;
```

### **Phase 3: Weather System Evaluation**
```sql
-- Check if weather system is referenced in server code
-- If not used, can be removed:
-- DROP TABLE hlbg_weather;
```

---

## 📋 **Testing Strategy**

### **SSH-Sync-and-Build Testing**
Since you mentioned using ssh-sync-and-build for testing, the specialized test versions are no longer needed:

1. **Development Testing:** Use the main enhanced addon with debug mode enabled
2. **Performance Testing:** Use built-in telemetry system (`HLBG_Telemetry.lua`)
3. **Emergency Fallback:** Main addon is now robust enough for production use
4. **Minimal Testing:** Performance monitoring shows real resource usage

### **Verification Steps**
1. Test addon loading after consolidation
2. Verify HUD visibility and functionality
3. Test all enhanced features (settings, scoreboard, telemetry)
4. Verify database connectivity (test with existing tables)
5. Plan database migration during maintenance window

---

## 🎯 **Benefits of Cleanup**

### **Addon Benefits:**
- **Simplified Maintenance:** One production-ready addon instead of 4 versions
- **Reduced Confusion:** Clear single source of truth
- **Better Performance:** Optimized code without legacy baggage
- **Enhanced Features:** Modern HUD, telemetry, settings, scoreboard

### **Database Benefits:**
- **Modern Schema:** Enhanced tracking and statistics
- **Better Performance:** Optimized indexes and structure
- **Comprehensive Data:** Individual player stats, detailed battle history
- **Future-Proof:** Extensible design for new features

### **Development Benefits:**
- **Cleaner Repository:** Less clutter, easier navigation
- **Faster Builds:** Fewer files to sync and compile
- **Easier Testing:** Built-in performance monitoring and debugging
- **Better Documentation:** Consolidated, up-to-date documentation

---

## ⚠️ **Important Notes**

1. **Database Migration:** Must be done during maintenance window to avoid data loss
2. **Server Code Updates:** Required for database table changes
3. **Player Communication:** Notify users about addon updates
4. **Backup Strategy:** Keep backups until migration is fully verified
5. **Testing Period:** Allow time for thorough testing before going live

**Ready for implementation once you confirm the approach!**