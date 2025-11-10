# 🔍 Diagnostic Guide: Upgrade Stats Not Applied on Equipment

## Updated Code Changes
✅ Added detailed logging to track enchant application
✅ Added verification that enchants were actually applied
✅ Better error messages to identify where it's failing

## How to Diagnose the Issue

### Step 1: Check Server Logs
After rebuilding and starting server with the updated code:

```bash
# Watch for ItemUpgrade logs
tail -f worldserver.log | grep ItemUpgrade
```

### Step 2: Equip an Upgraded Item
Test and watch for these log messages:

**Expected Logs (Success Case):**
```
ItemUpgrade: Attempting to apply enchant 80308 to item 12345 (guid=999)...
ItemUpgrade: Successfully applied enchant 80308 to item 999
```

**Failure Case A - Enchant not found:**
```
ItemUpgrade: Enchant 80308 not found in dc_item_upgrade_enchants table - tier 3, level 8
```
→ **Fix**: Run the enchants creation SQL

**Failure Case B - Enchant not applied:**
```
ItemUpgrade: Attempting to apply enchant 80308...
ItemUpgrade: Failed to apply enchant 80308! Item has enchant 0 instead
```
→ **Fix**: Check if enchant exists in `spell_enchant_proc_data` table

**Failure Case C - No upgrade found:**
```
ItemUpgrade: No upgrade data for item 999
```
→ **Fix**: Item is not in `dc_player_item_upgrades` table

### Step 3: Check Database

**Check enchants table exists and is populated:**
```sql
USE acore_world;
SELECT COUNT(*) FROM dc_item_upgrade_enchants;
```
Should show: `75 rows` (or similar count > 0)

**Check enchant details:**
```sql
SELECT enchant_id, tier_id, upgrade_level, stat_multiplier 
FROM dc_item_upgrade_enchants 
LIMIT 5;
```

**Check if enchants are in spell system:**
```sql
SELECT enchant_id, name 
FROM spell_enchant_proc_data 
WHERE enchant_id IN (80001, 80002, 80003, 80004, 80005);
```

**Check if item upgrade exists:**
```sql
USE acore_characters;
SELECT * FROM dc_player_item_upgrades 
WHERE upgrade_level > 0;
```

### Step 4: Manual Test

1. **Create test item with upgrade:**
   ```sql
   INSERT INTO dc_player_item_upgrades 
   (item_guid, player_guid, base_item_name, tier_id, upgrade_level, stat_multiplier)
   VALUES (999999, 1, 'Test Item', 3, 8, 1.5);
   ```

2. **Login with that item in inventory**

3. **Check logs for diagnostic messages**

4. **Equip the item**

5. **Watch for enchant application logs**

---

## Most Likely Issues

### Issue #1: dc_item_upgrade_enchants Table Empty
**Symptom:** "Enchant X not found in dc_item_upgrade_enchants table"

**Solution:**
```bash
cd Custom/Custom\ feature\ SQLs/worlddb/ItemUpgrades/
mysql acore_world < dc_item_upgrade_enchants_CREATE.sql
```

### Issue #2: Enchant IDs Don't Exist in Spell System
**Symptom:** "Failed to apply enchant X! Item has enchant 0 instead"

**Solution:** Enchants 80000-80599 must be defined in the WoW enchantment system. Check if they're properly linked to spell data.

### Issue #3: OnPlayerEquip Not Firing
**Symptom:** No logs appear at all when equipping

**Solution:** The PlayerScript hook might not be registered. Check:
```bash
grep -r "ItemUpgradeStatHook" src/
```

Should find registration in a script loader file.

### Issue #4: Item Upgrade Data Not in Database
**Symptom:** Logs show "No upgrade data found"

**Solution:** Ensure items were properly upgraded and saved:
```sql
SELECT COUNT(*) FROM dc_player_item_upgrades WHERE player_guid = 1;
```

---

## Rebuild and Deploy

```bash
# 1. Clean and rebuild
./acore.sh compiler clean
./acore.sh compiler build

# 2. Start with output to see logs
./acore.sh run-worldserver 2>&1 | tee worldserver.log

# 3. Test - equip item and watch logs

# 4. If you see "Failed to apply", check:
#    - dc_item_upgrade_enchants table is populated
#    - Enchant IDs exist in spell system
#    - Player has upgraded items in database
```

---

## Quick Check Commands

```bash
# See all ItemUpgrade enchant attempts
grep "ItemUpgrade: Attempting" worldserver.log

# See all enchant application results  
grep "ItemUpgrade: Successfully\|ItemUpgrade: Failed" worldserver.log

# See all errors
grep "ItemUpgrade.*ERROR" worldserver.log
```

---

## Next Steps

1. Apply the updated code
2. Rebuild server
3. Run diagnostic checks from Step 1-3 above
4. Check logs for which failure case applies
5. Fix the identified issue
6. Test again

The detailed logging will pinpoint exactly where the system is failing!
