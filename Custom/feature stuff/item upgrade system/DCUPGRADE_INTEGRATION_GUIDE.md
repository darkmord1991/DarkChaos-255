# DC-ItemUpgrade System Integration Guide

## Summary of Changes Made

### 1. ✅ TOC File Updated
**File:** `DC-ItemUpgrade.toc`
- Added `DC_CurrencyDisplay.lua` to file load order
- This enables the currency display to load when the addon starts
- Players will now see their upgrade tokens on the character sheet

### 2. ✅ Currency Display UI Created
**File:** `DC_CurrencyDisplay.lua` (NEW)
- Displays upgrade tokens and essence on the character sheet
- Updates every 10 seconds automatically
- Shows as visual currency overlay like gold/honor
- Positioned in top-right corner of character frame
- Includes tooltip explaining token purpose

### 3. ⏳ Upgrade Costs Table (Ready to Execute)
**File:** `Custom/setup_upgrade_costs.sql`
- Contains 75 upgrade cost entries (5 tiers × 15 levels)
- Tier 1 (cheap): 5-75 tokens per upgrade
- Tier 5 (expensive): 50-750 tokens per upgrade
- **STATUS: Created but NOT YET EXECUTED on database**

---

## How to Execute the SQL

### Option A: Using PowerShell (Windows - Recommended)
```powershell
# From workspace root directory
.\execute_sql_in_docker.ps1 -SqlFile "Custom/setup_upgrade_costs.sql" -Database "acore_world"
```

### Option B: Using Bash (Linux/Mac/WSL)
```bash
# From workspace root directory
chmod +x execute_sql_in_docker.sh
./execute_sql_in_docker.sh "Custom/setup_upgrade_costs.sql" "acore_world"
```

### Option C: Manual Docker Command
```bash
# Execute SQL via Docker directly
docker exec -i ac-database mysql -uroot -p"password" acore_world < Custom/setup_upgrade_costs.sql
```

### Option D: Manual Verification
After running the SQL, verify it was successful:
```bash
docker exec ac-database mysql -uroot -p"password" acore_world -e "SELECT COUNT(*) as 'Total Cost Entries' FROM dc_item_upgrade_costs;"
```

Expected output: `75`

---

## What This Accomplishes

### Client-Side
✅ **Currency Display on Character Sheet**
- Players open character sheet and see tokens/essence amounts
- Updates automatically every 10 seconds
- Shows on-demand when addon sends `.dcupgrade init` command
- Formatted as gold/essence currency display

### Server-Side
✅ **Command Handler** (ItemUpgradeCommands.cpp)
- `.dcupgrade init` - Returns player's current tokens/essence
- `.dcupgrade query <item_slot>` - Returns item upgrade state
- `.dcupgrade perform <item_slot> <upgrade_level>` - Performs upgrade

✅ **Database Integration**
- Queries real player data from `dc_item_upgrade_currency` table
- Tracks upgrade state in `dc_item_upgrade_state` table
- Uses cost table to validate and deduct currency

---

## Current System Status

| Component | Status | Notes |
|-----------|--------|-------|
| Command Handler | ✅ WORKING | Returns real DB values |
| Addon Events | ✅ WORKING | Listens to CHAT_MSG_SYSTEM |
| Character Sheet Display | ✅ READY | TOC updated, file created |
| Upgrade Costs Table | ⏳ PENDING | SQL created, needs execution |
| Token Acquisition | ❌ NOT IMPLEMENTED | Need Quests/Vendor/PvP system |
| Item Stat Scaling | ❌ NOT IMPLEMENTED | Requires C++ item stat changes |

---

## Testing Checklist

After executing the SQL:

1. **[ ] Verify SQL Execution**
   ```bash
   docker exec ac-database mysql -uroot -p"password" acore_world -e "SELECT * FROM dc_item_upgrade_costs LIMIT 5;"
   ```

2. **[ ] Test Currency Display**
   - Open character sheet
   - Should see "Upgrade Tokens: 0 | Essence: 0" (or current amounts)
   - Open Item Upgrade addon
   - Click refresh button
   - Currency amounts should update

3. **[ ] Test Commands** (as GM with tokens)
   ```
   .upgrade token add <player_name> 1000
   /dcupgrade init
   ```
   Should return: `DCUPGRADE_INIT:1000:X`

4. **[ ] Test Upgrade Flow**
   - Have item in inventory
   - Open Item Upgrade addon
   - Select upgrade
   - Check currency display updates

---

## Next Implementation Steps

### High Priority: Token Acquisition System
Choose implementation path:

**Option 1: Quest Rewards** ⭐ Recommended (Most RPG-like)
- Create daily quest: "Collect upgrade materials"
- Reward: 100 tokens + 50 essence
- Can create weekly quests for larger rewards
- Encourages engagement

**Option 2: Vendor NPC** (Easiest to implement)
- Create NPC that sells tokens
- Exchange rate: 1 gold = 0.1 tokens (configurable)
- Players farm gold to buy tokens
- Economic sink for gold

**Option 3: PvP/BG Rewards** (Competitive incentive)
- Arena wins grant 25-50 tokens
- Battleground wins grant 10-20 tokens
- Encourages PvP participation
- Progression via combat

---

## How the System Works

### Player Perspective
1. Open character sheet → See "Upgrade Tokens: 500"
2. Open Item Upgrade addon → Select item to upgrade
3. Addon shows cost: "50 tokens"
4. Click upgrade → Tokens deducted, item improved
5. Relog → Item stats persist (once C++ scaling added)

### Technical Flow
1. **Addon opens** → Sends `.dcupgrade init` command
2. **Server receives** → ItemUpgradeCommands.cpp handler processes
3. **Handler queries** → CharacterDatabase for player's tokens
4. **Server responds** → PSendSysMessage("DCUPGRADE_INIT:500:250")
5. **Addon receives** → CHAT_MSG_SYSTEM event fires
6. **Addon parses** → Extracts tokens/essence values
7. **Display updates** → Character sheet shows new amounts

### Database Schema
```
dc_item_upgrade_currency
├── player_guid (PK)
├── currency_type (1=Tokens, 2=Essence)
└── amount

dc_item_upgrade_state
├── item_guid (PK)
├── player_guid
├── upgrade_level (1-15)
├── tier (1-5)
└── tokens_invested

dc_item_upgrade_costs
├── tier (1-5)
├── upgrade_level (1-15)
├── upgrade_tokens
└── artifact_essence
```

---

## Files Modified This Session

| File | Change | Status |
|------|--------|--------|
| DC-ItemUpgrade.toc | Added DC_CurrencyDisplay.lua | ✅ DONE |
| DC_CurrencyDisplay.lua | Created new UI file | ✅ DONE |
| setup_upgrade_costs.sql | Created cost table SQL | ✅ CREATED, ⏳ NEEDS EXECUTION |
| execute_sql_in_docker.ps1 | Created helper script | ✅ DONE |
| execute_sql_in_docker.sh | Created helper script | ✅ DONE |

---

## Immediate Next Actions

1. **Execute SQL:** Run `execute_sql_in_docker.ps1` to populate upgrade costs
2. **Verify:** Check that 75 rows were inserted
3. **Test:** Create test currency with `.upgrade token add` command
4. **Display Check:** Verify tokens show on character sheet
5. **Choose Token Source:** Decide between Quests/Vendor/PvP
6. **Implement:** Add token acquisition system

---

## Support Notes

- All Docker commands assume `ac-database` container is running
- Default MySQL password is "password" (change via DOCKER_DB_ROOT_PASSWORD env var)
- SQL file is idempotent (safe to run multiple times - will replace existing data)
- Currency display updates every 10 seconds, or when addon window opens

