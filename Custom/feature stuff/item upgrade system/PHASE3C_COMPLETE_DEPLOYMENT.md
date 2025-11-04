# 🚀 Phase 3C Complete Deployment Guide

**Status:** ✅ ALL CODE READY & TESTED  
**Date:** November 4, 2025  
**Latest Commits:**
- `ff1bded2f` — Fix: Include ItemUpgradeManager.h header (build fix)
- `18f3667f5` — Feat: Add token balance display to NPC gossip menus (Phase 3C.2)

---

## 📋 What's Included in Phase 3C

### Core Features (Already Complete)
1. **Token Acquisition System** — Automatic token awards
   - Quest completion: 10-50 tokens (scaled by difficulty)
   - Creature kills: 5-50 tokens + essence for bosses
   - PvP kills: 15 tokens (scaled by level)
   - Achievements: 50 artifact essence (one-time only)
   - Battleground wins: 25 tokens (5 for losses)

2. **Weekly Cap System**
   - 500 upgrade tokens/week per player
   - Unlimited artifact essence
   - Weekly reset tracking

3. **Admin Commands**
   - `.upgrade token add <player> <amount> [type]` — Award tokens
   - `.upgrade token remove <player> <amount> [type]` — Remove tokens
   - `.upgrade token set <player> <amount> [type]` — Set exact amount
   - `.upgrade token info <player>` — Check balance

4. **Transaction Logging**
   - Full audit trail of all token awards/deductions
   - Event type tracking (quest, creature, pvp, achievement, etc.)
   - Reason documentation

5. **NPC Gossip Enhancement (Phase 3C.2)**
   - Token balance display in NPC menus
   - Essence balance display
   - Professional UI with colored text and icons

---

## 🛠️ Installation Steps

### Step 1: Backup Your Database
```bash
# CRITICAL: Always backup before executing SQL!
mysqldump -u root -p azerothcore_characters > backup_phase3c_$(date +%s).sql
```

### Step 2: Execute Phase 3C SQL Schema
Execute the following SQL file on your `azerothcore_characters` database:

**File:** `Custom/Custom feature SQLs/chardb/ItemUpgrades/dc_token_acquisition_schema.sql`

```bash
mysql -u root -p azerothcore_characters < \
  "Custom/Custom feature SQLs/chardb/ItemUpgrades/dc_token_acquisition_schema.sql"
```

**Expected Output:** No errors. Tables created successfully.

**Verify Installation:**
```sql
-- Run these queries to verify:
SHOW TABLES LIKE 'dc_token%';
-- Should show: dc_token_transaction_log, dc_token_event_config

DESCRIBE dc_player_upgrade_tokens;
-- Should show new columns: weekly_earned, week_reset_at, last_transaction_at
```

### Step 3: Rebuild Server on Remote Host
```bash
# SSH to your remote build server
ssh user@192.168.178.45

# Navigate to build directory
cd /home/wowcore/azerothcore/build

# Rebuild (pull latest code first if needed)
cd ..
git pull origin master

# Configure and build
mkdir -p build
cd build
cmake ..
make -j$(nproc)
```

**Expected Output:**
```
[ 99%] Built target scripts
[100%] Built target worldserver
[100%] Built target authserver
```

**If errors occur:**
- Check for compilation errors in output (should be none)
- Verify `ItemUpgradeManager.h` is included in all scripts
- Run `make clean` and rebuild if needed

### Step 4: Deploy Binaries
```bash
# Copy compiled binaries to production
cp /home/wowcore/azerothcore/build/bin/worldserver /path/to/production/bin/
cp /home/wowcore/azerothcore/build/bin/authserver /path/to/production/bin/

# Set proper permissions
chmod +x /path/to/production/bin/worldserver
chmod +x /path/to/production/bin/authserver
```

### Step 5: Restart Servers
```bash
# Stop current servers
killall worldserver authserver

# Wait a few seconds
sleep 3

# Start new servers
cd /path/to/production/bin/
./worldserver &
./authserver &

# Verify startup (check logs for token system registration)
tail -f /path/to/logs/world.log | grep -i token
```

**Look for these log messages:**
```
[ItemUpgrade] Token system initialized
[ItemUpgrade] Quest token hooks registered
[ItemUpgrade] Creature token hooks registered
[ItemUpgrade] PvP token hooks registered
[ItemUpgrade] Achievement token hooks registered
```

---

## 🎮 Testing Phase 3C

### Test 1: Check Token Balances
**In-game command:**
```
.upgrade token info <player_name>
```

**Expected:** Shows current token balance (should be 0 initially)

### Test 2: Test Quest Token Award
1. Have player complete any quest
2. Check console for: `[ItemUpgrade] Quest reward awarded to <player>`
3. Verify tokens increased: `.upgrade token info <player_name>`

**Expected:** Player received 10-50 tokens based on quest difficulty

### Test 3: Test Creature Kills
1. Kill any creature as player
2. Check for token award message
3. Check token balance

**Expected:** Player received tokens (amount varies by creature type)

### Test 4: Test Admin Commands
```bash
# Award 100 tokens
.upgrade token add playerName 100

# Check balance
.upgrade token info playerName

# Remove 50 tokens
.upgrade token remove playerName 50

# Set exact amount
.upgrade token set playerName 500

# Verify final balance
.upgrade token info playerName
```

**Expected:** All commands execute without errors

### Test 5: Test NPC Gossip Display
1. Talk to NPC 190001 (Vendor) or 190002 (Curator)
2. Check NPC gossip menu header

**Expected:** Should show:
```
=== Item Upgrade Vendor ===
Upgrade Tokens: [amount]
Artifact Essence: [amount]
```

### Test 6: Test Weekly Cap
```bash
# Repeatedly award tokens to test cap
.upgrade token add playerName 100  (now at 100)
.upgrade token add playerName 100  (now at 200)
.upgrade token add playerName 100  (now at 300)
.upgrade token add playerName 100  (now at 400)
.upgrade token add playerName 100  (now at 500)
.upgrade token add playerName 100  (should stay at 500 - capped)
```

**Expected:** Player stops earning tokens at 500/week

---

## 📊 Database Tables Reference

### dc_token_transaction_log
- **Purpose:** Audit trail of all token transactions
- **Columns:**
  - `id` — Unique transaction ID
  - `player_guid` — Player GUID
  - `event_type` — Quest, Creature, PvP, Achievement, Battleground, Admin
  - `token_change` — Amount changed (+ or -)
  - `essence_change` — Essence amount changed
  - `reason` — Human-readable reason
  - `source_id` — Quest ID, creature ID, etc.
  - `timestamp` — When it happened
  - `season` — Season number

### dc_token_event_config
- **Purpose:** Configure token rewards per event type
- **Columns:**
  - `event_type` — Quest, Creature, PvP, Achievement, Battleground
  - `event_source_id` — Specific source (quest ID, creature ID, etc.)
  - `token_reward` — Base tokens awarded
  - `essence_reward` — Base essence awarded
  - `scaling_factor` — Difficulty/level multiplier
  - `is_active` — Can this event award tokens?
  - `is_repeatable` — Can be earned multiple times?

### dc_player_upgrade_tokens (Modified)
**New Columns:**
- `weekly_earned` — Tokens earned this week
- `week_reset_at` — Last weekly reset timestamp
- `last_transaction_at` — Last transaction timestamp

---

## 🆘 Troubleshooting

### Issue: Build Error "incomplete type 'UpgradeManager'"
**Solution:** Ensure all files include `ItemUpgradeManager.h`
```cpp
#include "ItemUpgradeManager.h"  // Must be included, not just forward declared
```

### Issue: Tokens Not Awarding on Quest Completion
**Check:**
1. Is `dc_token_event_config` table populated?
   ```sql
   SELECT * FROM dc_token_event_config WHERE event_type = 'quest';
   ```
   Should show at least one row with `is_active = 1`

2. Check server log for errors:
   ```
   tail -f world.log | grep -i "token\|error"
   ```

3. Verify player exists in database:
   ```sql
   SELECT guid, name FROM characters WHERE name = 'PlayerName';
   ```

### Issue: Weekly Cap Not Working
**Check:**
1. `dc_player_upgrade_tokens` has `weekly_earned` column
2. Server logic checks `IsAtWeeklyTokenCap()` before awarding
3. Weekly reset timestamp is being updated

### Issue: NPC Gossip Shows 0 Tokens
**Check:**
1. `ItemUpgradeManager.h` is included in NPC files
2. Manager instance `sUpgradeManager()` is initialized
3. Player has tokens in database:
   ```sql
   SELECT player_guid, amount FROM dc_player_upgrade_tokens WHERE player_guid = <guid>;
   ```

---

## 📈 Performance Notes

- **Token Logging:** Creates one database row per token award
- **Transaction Queries:** Indexed on `player_guid` and `timestamp` for fast lookups
- **Weekly Cap Checks:** Cached in memory, minimal database queries
- **NPC Gossip:** Queries run only when menu opens (no performance impact)

---

## 🎯 Next Steps (Optional Enhancements)

### Phase 3C.3: DBC Integration
- Update `CurrencyTypes.dbc` to add custom currencies
- Update `Item.dbc` to link items to currency costs
- Update `ItemExtendedCost.dbc` for upgrade costs
- **Benefit:** Client-side currency display in tooltips

**Time to implement:** 1-2 hours  
**Difficulty:** Medium (requires DBC editing tools)

### Phase 4: Upgrade Spending
- Implement `.upgrade item <item_id>` command
- Spend tokens to upgrade item stats
- Store upgrade levels in database
- Apply stat modifications on item equip

**Time to implement:** 2-3 hours  
**Difficulty:** High (integration with item system)

---

## 📝 Success Criteria

✅ **Phase 3C Deployment Complete When:**
1. SQL schema executes without errors
2. Server rebuilds with 0 compilation errors
3. Tokens award automatically when players complete quests
4. Weekly cap enforces at 500 tokens
5. Admin commands work without errors
6. NPC gossip displays token balances
7. Transaction logging records all awards

---

## 🔗 Related Files

- **Code:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommand.cpp`
- **Hooks:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeTokenHooks.cpp`
- **NPC Vendor:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeNPC_Vendor.cpp`
- **NPC Curator:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeNPC_Curator.cpp`
- **Schema:** `Custom/Custom feature SQLs/chardb/ItemUpgrades/dc_token_acquisition_schema.sql`
- **Manager:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.h`

---

## 💬 Questions?

Refer to:
1. `PHASE3C_FINAL_SUMMARY.md` — Production checklist
2. `PHASE3C_QUICK_START.md` — Admin command reference
3. `PHASE3C_TOKEN_SYSTEM_DESIGN.md` — Architecture details
4. `PHASE3C_EXTENSION_DBC_GOSSIP_GUIDE.md` — Future enhancements

**All code is tested, compiled, and ready to deploy!** 🚀
