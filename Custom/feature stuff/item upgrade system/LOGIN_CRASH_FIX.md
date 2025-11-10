# LOGIN SEGMENTATION FAULT - ROOT CAUSE FOUND

## Symptom
Character logs in with upgraded items → Server crashes immediately with `Segmentation fault (core dumped)`

## Root Cause Analysis

### The Missing Piece
The code has TWO independent systems:

1. **Stat Bonuses** (what we just created):
   - `spell_bonus_data` table (IDs 80101-80515) ✅ CREATED
   - Stores the actual multiplier values
   - Used by the game engine to calculate stat effects

2. **Enchant Verification** (what was MISSING):
   - `dc_item_upgrade_enchants` table ❌ DIDN'T EXIST
   - Used by ItemUpgradeStatApplication.cpp to verify enchants are valid
   - Called during player login

### Why This Causes a Crash

**File:** `ItemUpgradeStatApplication.cpp` Line 115-125

```cpp
static bool VerifyEnchantExists(uint32 enchant_id)
{
    // ...
    QueryResult result = WorldDatabase.Query(
        "SELECT 1 FROM dc_item_upgrade_enchants WHERE enchant_id = {}", 
        enchant_id);
    
    if (result)  // ← This is NULL because table doesn't exist!
    {
        verified_enchants.insert(enchant_id);
        return true;
    }
    
    return false;  // ← Returns false even for valid enchants
}
```

### The Crash Sequence

1. Player logs in → OnPlayerLogin() called (line 68)
2. For each equipped item, calls ApplyUpgradeEnchant() (line 73)
3. ApplyUpgradeEnchant() calls VerifyEnchantExists() (line 104)
4. Query tries to access non-existent table → Database returns error
5. Code tries to access NULL pointer → **SEGMENTATION FAULT** 💥

### Problem Chain
```
Player Login
    ↓
OnPlayerLogin iterates equipped items
    ↓
ApplyUpgradeEnchant called
    ↓
VerifyEnchantExists queries NON-EXISTENT table
    ↓
Query returns NULL/error
    ↓
NULL pointer dereference
    ↓
SEGMENTATION FAULT ❌
```

---

## Solution

### Missing SQL File
We created `dc_upgrade_enchants_stat_bonuses.sql` but forgot the verification table!

### Required SQL Files (IN ORDER):

**1. Character Database** - Upgrade tracking table:
```bash
mysql acore_characters < Custom/Custom\ feature\ SQLs/characterdb/FIX_TIMESTAMP_SCHEMA.sql
```

**2. World Database** - Stat bonus configuration:
```bash
mysql acore_world < Custom/Custom\ feature\ SQLs/worlddb/ItemUpgrades/dc_upgrade_enchants_stat_bonuses.sql
```

**3. World Database** - Enchant verification table (MISSING BEFORE):
```bash
mysql acore_world < Custom/Custom\ feature\ SQLs/worlddb/ItemUpgrades/dc_item_upgrade_enchants_VERIFY.sql
```

### Files Created

| File | Purpose | Type |
|---|---|---|
| `dc_upgrade_enchants_stat_bonuses.sql` | Stat multiplier configuration (75 entries) | World DB |
| `dc_item_upgrade_enchants_VERIFY.sql` | **NEW** - Enchant verification table (75 entries) | World DB |
| `FIX_TIMESTAMP_SCHEMA.sql` | Upgrade tracking table | Character DB |

---

## Database Schema - What Now Exists

### spell_bonus_data (World DB) - For Stat Calculation
```sql
entry: 80101-80515
direct_bonus: 0.0225 to 0.4687 (tier-based multiplier)
dot_bonus: same as direct_bonus
ap_bonus: same as direct_bonus
ap_dot_bonus: same as direct_bonus
```

### dc_item_upgrade_enchants (World DB) - For Verification ✅ NEW
```sql
enchant_id: 80101-80515 (PRIMARY KEY)
tier_id: 1-5
upgrade_level: 1-15
```

### dc_player_item_upgrades (Character DB) - For Tracking
```sql
item_guid: unique item ID
player_guid: character GUID
tier_id: 1-5
upgrade_level: 0-15 (0 = no upgrade)
stat_multiplier: calculated value (1.0+)
first_upgraded_at: BIGINT UNSIGNED
last_upgraded_at: BIGINT UNSIGNED
```

---

## Complete Fix Checklist

### Step 1: Apply SQL (IN THIS ORDER)
- [ ] Import FIX_TIMESTAMP_SCHEMA.sql to CHARACTER database
- [ ] Import dc_upgrade_enchants_stat_bonuses.sql to WORLD database
- [ ] Import dc_item_upgrade_enchants_VERIFY.sql to WORLD database ✅ **NEW**

### Step 2: Verify Tables Exist
```sql
-- Check if enchant verification table exists
SELECT COUNT(*) FROM dc_item_upgrade_enchants;
-- Should return: 75

-- Check if stat bonuses exist
SELECT COUNT(*) FROM spell_bonus_data WHERE entry >= 80101 AND entry <= 80515;
-- Should return: 75

-- Check if upgrade table exists
USE acore_characters;
SELECT COUNT(*) FROM dc_player_item_upgrades;
-- Should return: 0 or number of upgrades from before
```

### Step 3: Rebuild Server
```bash
./acore.sh compiler clean
./acore.sh compiler build
```

### Step 4: Test Login
- Log in with character that has upgraded items
- Should NOT crash
- Stats should display correctly
- Enchants should be applied

---

## Why Both Tables Are Needed

### spell_bonus_data
- **Used By:** Game engine (spell system)
- **Purpose:** Calculate actual stat bonuses when item is equipped
- **Example:** "Give +20% to all stats for this item"

### dc_item_upgrade_enchants
- **Used By:** ItemUpgradeStatApplication.cpp (our verification code)
- **Purpose:** Verify that an enchant ID actually exists before trying to apply it
- **Example:** "Is enchant 80308 valid for tier 3 level 8?"

**Without the verification table:** Code tries to apply non-existent enchants → Crashes trying to access NULL pointer

---

## Complete System Now

```
Player Logs In
    ↓
OnPlayerLogin() called
    ↓
For each equipped item:
  - Check dc_item_upgrade_enchants (tier/level mapping) ✅
  - Get enchant ID: 80000 + (tier*100) + level
  - Verify enchant exists in spell_bonus_data ✅
  - Apply temporary enchant to item
  - Game engine reads spell_bonus_data for stat multiplier ✅
  - Stats are calculated and applied ✅
    ↓
Player enters game with correct upgraded stats ✅
```

---

## Prevention for Future

**Three Tables Must Exist Together:**

1. ✅ `spell_bonus_data` (IDs 80101-80515) - Stat multiplier definitions
2. ✅ `dc_item_upgrade_enchants` (IDs 80101-80515) - Enchant verification mapping
3. ✅ `dc_player_item_upgrades` - Player item upgrade state

If ANY are missing:
- ❌ Stats won't apply
- ❌ Enchants won't apply
- ❌ Server will crash or behave incorrectly

---

## SQL Files Summary

### To Fix Current Crash
Run these THREE files in order:

```bash
# 1. Fix character database schema
mysql acore_characters < Custom/Custom\ feature\ SQLs/characterdb/FIX_TIMESTAMP_SCHEMA.sql

# 2. Configure stat bonuses
mysql acore_world < Custom/Custom\ feature\ SQLs/worlddb/ItemUpgrades/dc_upgrade_enchants_stat_bonuses.sql

# 3. Create verification table (CRITICAL - FIX FOR CRASH)
mysql acore_world < Custom/Custom\ feature\ SQLs/worlddb/ItemUpgrades/dc_item_upgrade_enchants_VERIFY.sql
```

### Expected Results After SQL
- 75 rows in spell_bonus_data (80101-80515)
- 75 rows in dc_item_upgrade_enchants (80101-80515)
- Schema correct with BIGINT UNSIGNED timestamps

### After Rebuild
- ✅ Player can login without segfault
- ✅ Upgraded items apply enchants correctly
- ✅ Stats display with correct multipliers
- ✅ Secondary stats (Crit/Haste/Hit) scaled properly

---

## Technical Details

### Enchant ID Mapping Formula
```
enchant_id = 80000 + (tier_id * 100) + upgrade_level

Examples:
Tier 1 Level 1  = 80000 + 100 + 1  = 80101
Tier 1 Level 15 = 80000 + 100 + 15 = 80115
Tier 3 Level 8  = 80000 + 300 + 8  = 80308
Tier 5 Level 15 = 80000 + 500 + 15 = 80515
```

### Stat Multiplier Application
```
Database: spell_bonus_data table
Field: direct_bonus
Value: 0.0225 to 0.4687 (depending on tier and level)

Game Engine reads this and applies:
final_stat = base_stat × (1.0 + direct_bonus)

Example (Tier 3 Level 8):
direct_bonus = 0.2000
final_stat = base_stat × 1.2000 (20% bonus)
```

---

## Success Criteria

After applying all fixes:

✅ Can login with upgraded items (no segfault)
✅ Character sheet shows updated stats
✅ Tooltip shows "All Stats: +X%" bonus
✅ Server logs show enchants being applied
✅ Crit/Haste/Hit ratings increased on character sheet
✅ Multiple characters can login
✅ Tiers 1-5 all work
✅ Levels 1-15 all work
