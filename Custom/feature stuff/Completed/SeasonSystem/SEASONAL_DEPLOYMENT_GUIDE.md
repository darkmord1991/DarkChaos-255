# DC-Seasons Deployment Guide

## System Architecture Summary

**NEW DESIGN (November 22, 2025):**
- ✅ C++ Core: All reward logic, database operations, cap management (src/server/scripts/DC/Seasons/)
- ✅ Eluna Bridge: Minimal AIO communication only (Custom/Eluna scripts/DC_Seasons_AIO.lua)
- ✅ Client Addon: UI for notifications and progress tracking (Custom/Client addons needed/DC-Seasons/)

**OLD DESIGN (Deprecated):**
- ❌ SeasonalRewards.lua - Replaced by C++ SeasonalRewardSystem
- ❌ SeasonalCommands.lua - Replaced by C++ SeasonalRewardCommands
- ❌ SeasonalCaps.lua - Replaced by C++ cap management
- ❌ SeasonalIntegration.lua - Replaced by C++ PlayerScript hooks

## Phase 1: Database Setup

### 1.1 Import Schemas (chardb)

```sql
-- Player seasonal stats
CREATE TABLE IF NOT EXISTS dc_player_seasonal_stats (
    player_guid INT UNSIGNED PRIMARY KEY,
    season_id INT UNSIGNED NOT NULL,
    seasonal_tokens_earned INT UNSIGNED DEFAULT 0,
    seasonal_essence_earned INT UNSIGNED DEFAULT 0,
    weekly_tokens_earned INT UNSIGNED DEFAULT 0,
    weekly_essence_earned INT UNSIGNED DEFAULT 0,
    quests_completed INT UNSIGNED DEFAULT 0,
    creatures_killed INT UNSIGNED DEFAULT 0,
    dungeon_bosses_killed INT UNSIGNED DEFAULT 0,
    world_bosses_killed INT UNSIGNED DEFAULT 0,
    prestige_level INT UNSIGNED DEFAULT 0,
    last_weekly_reset INT UNSIGNED DEFAULT 0,
    last_updated INT UNSIGNED DEFAULT 0,
    INDEX idx_season (season_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player seasonal progression tracking';

-- Transaction log
CREATE TABLE IF NOT EXISTS dc_reward_transactions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    source VARCHAR(50) NOT NULL,
    source_id INT UNSIGNED DEFAULT 0,
    tokens_awarded INT UNSIGNED DEFAULT 0,
    essence_awarded INT UNSIGNED DEFAULT 0,
    timestamp INT UNSIGNED NOT NULL,
    INDEX idx_player (player_guid),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Seasonal reward transaction history';

-- Weekly snapshots
CREATE TABLE IF NOT EXISTS dc_player_weekly_cap_snapshot (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    week_timestamp INT UNSIGNED NOT NULL,
    tokens_earned INT UNSIGNED DEFAULT 0,
    essence_earned INT UNSIGNED DEFAULT 0,
    dungeons_completed INT UNSIGNED DEFAULT 0,
    INDEX idx_player_week (player_guid, week_timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Weekly earning snapshots for cap tracking';

-- Weekly chests
CREATE TABLE IF NOT EXISTS dc_player_seasonal_chests (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    week_timestamp INT UNSIGNED NOT NULL,
    slot1_tokens INT UNSIGNED DEFAULT 0,
    slot1_essence INT UNSIGNED DEFAULT 0,
    slot2_tokens INT UNSIGNED DEFAULT 0,
    slot2_essence INT UNSIGNED DEFAULT 0,
    slot3_tokens INT UNSIGNED DEFAULT 0,
    slot3_essence INT UNSIGNED DEFAULT 0,
    slots_unlocked TINYINT UNSIGNED DEFAULT 0,
    collected TINYINT(1) DEFAULT 0,
    INDEX idx_player_uncollected (player_guid, collected)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Weekly chest rewards (M+ vault style)';

-- Stats history
CREATE TABLE IF NOT EXISTS dc_player_seasonal_stats_history (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    seasonal_tokens_earned INT UNSIGNED DEFAULT 0,
    seasonal_essence_earned INT UNSIGNED DEFAULT 0,
    quests_completed INT UNSIGNED DEFAULT 0,
    creatures_killed INT UNSIGNED DEFAULT 0,
    dungeon_bosses_killed INT UNSIGNED DEFAULT 0,
    world_bosses_killed INT UNSIGNED DEFAULT 0,
    prestige_level INT UNSIGNED DEFAULT 0,
    archived_at INT UNSIGNED NOT NULL,
    INDEX idx_player_season (player_guid, season_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Archived seasonal stats from previous seasons';
```

### 1.2 Import Reward Definitions (worlddb)

```sql
-- Quest rewards
CREATE TABLE IF NOT EXISTS dc_seasonal_quest_rewards (
    quest_id INT UNSIGNED PRIMARY KEY,
    season_id INT UNSIGNED NOT NULL,
    token_reward INT UNSIGNED DEFAULT 0,
    essence_reward INT UNSIGNED DEFAULT 0,
    INDEX idx_season (season_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Quest reward definitions per season';

-- Creature rewards
CREATE TABLE IF NOT EXISTS dc_seasonal_creature_rewards (
    creature_entry INT UNSIGNED PRIMARY KEY,
    season_id INT UNSIGNED NOT NULL,
    token_reward INT UNSIGNED DEFAULT 0,
    essence_reward INT UNSIGNED DEFAULT 0,
    is_dungeon_boss TINYINT(1) DEFAULT 0,
    is_world_boss TINYINT(1) DEFAULT 0,
    INDEX idx_season (season_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Creature kill reward definitions per season';
```

### 1.3 Import Season 1 Data

Use existing file: `01_POPULATE_SEASON_1_REWARDS.sql`
- 62 creatures with rewards
- 11 quests with rewards
- Dungeon bosses, world bosses, regular mobs

## Phase 2: Server Configuration

### 2.1 Update darkchaos-custom.conf

Add/Update SECTION 10:

```ini
###################################################################################################
# SECTION 10: SEASONAL REWARD SYSTEM
###################################################################################################

# Enable/disable the seasonal reward system
SeasonalRewards.Enable = 1

# Active season ID
SeasonalRewards.ActiveSeasonID = 1

# Item IDs for rewards (must be valid items in item_template)
SeasonalRewards.TokenItemID = 49426
SeasonalRewards.EssenceItemID = 47241

# Weekly caps (0 = unlimited, recommended for initial testing)
SeasonalRewards.MaxTokensPerWeek = 0
SeasonalRewards.MaxEssencePerWeek = 0

# Global multipliers for reward scaling
SeasonalRewards.QuestMultiplier = 1.0
SeasonalRewards.CreatureMultiplier = 1.0
SeasonalRewards.WorldBossBonus = 1.5
SeasonalRewards.EventBossBonus = 1.25

# System features
SeasonalRewards.LogTransactions = 1
SeasonalRewards.AchievementTracking = 1

# Weekly reset timing (Day: 0=Sunday, 1=Monday, 2=Tuesday, etc.)
# Hour: 24-hour format (15 = 3:00 PM server time)
SeasonalRewards.WeeklyResetDay = 2
SeasonalRewards.WeeklyResetHour = 15
```

### 2.2 Deploy Eluna Bridge

Copy `Custom/Eluna scripts/DC_Seasons_AIO.lua` to `lua_scripts/DC_Seasons_AIO.lua`

**IMPORTANT:** Delete old Eluna scripts if they exist:
- ❌ `lua_scripts/SeasonalRewards.lua` (deprecated)
- ❌ `lua_scripts/SeasonalCommands.lua` (deprecated)
- ❌ `lua_scripts/SeasonalCaps.lua` (deprecated)
- ❌ `lua_scripts/SeasonalIntegration.lua` (deprecated)

Only `DC_Seasons_AIO.lua` should exist.

## Phase 3: C++ Compilation

### 3.1 Verify Source Files

Check these files exist in `src/server/scripts/DC/Seasons/`:
- ✅ SeasonalRewardSystem.h
- ✅ SeasonalRewardSystem.cpp
- ✅ SeasonalRewardScripts.cpp
- ✅ SeasonalRewardCommands.cpp

### 3.2 Verify CMakeLists.txt

Check `src/server/scripts/DC/CMakeLists.txt` contains:

```cmake
# DC Seasonal Reward System - C++ Core Implementation
set(SCRIPTS_DC_SeasonalRewards
    Seasons/SeasonalRewardSystem.h
    Seasons/SeasonalRewardSystem.cpp
    Seasons/SeasonalRewardScripts.cpp
    Seasons/SeasonalRewardCommands.cpp
)
```

And this section adds it:
```cmake
set(SCRIPTS_DC_ItemUpgrade
    ${SCRIPTS_DC_ItemUpgrade_Phase3}
    ${SCRIPTS_DC_ItemUpgrade_Phase4A}
    ${SCRIPTS_DC_ItemUpgrade_Phase4B}
    ${SCRIPTS_DC_ItemUpgrade_Phase4C}
    ${SCRIPTS_DC_ItemUpgrade_Phase4D}
    ${SCRIPTS_DC_ItemUpgrade_Phase4E}
    ${SCRIPTS_DC_ItemUpgrade_Phase4F}
    ${SCRIPTS_DC_SeasonalSystem}
    ${SCRIPTS_DC_SeasonalRewards}
)
```

### 3.3 Verify Script Loader

Check `src/server/scripts/DC/dc_script_loader.cpp` contains:

```cpp
void AddSC_SeasonalRewardScripts(); // location: scripts\DC\Seasons\SeasonalRewardScripts.cpp
void AddSC_SeasonalRewardCommands(); // location: scripts\DC\Seasons\SeasonalRewardCommands.cpp
```

And in `AddDCScripts()`:
```cpp
// Seasonal Reward System
LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
LOG_INFO("scripts", ">> DC Seasonal Reward System (C++ Core)");
// ... (see full log output in file)
AddSC_SeasonalRewardScripts();
AddSC_SeasonalRewardCommands();
```

### 3.4 Compile

```powershell
# Clean build (recommended for C++ changes)
./acore.sh compiler clean

# Build
./acore.sh compiler build
```

Expected compile time: 5-10 minutes (incremental if no clean)

## Phase 4: Client Addon Deployment

### 4.1 Copy Addon to Client

Copy entire folder:
```
Custom/Client addons needed/DC-Seasons/
```

To:
```
<WoW Install>/Interface/AddOns/DC-Seasons/
```

Folder should contain:
- DC-Seasons.toc
- DC-Seasons.lua
- README.md

### 4.2 Verify TOC File

Check `DC-Seasons.toc` has correct interface version for WotLK 3.3.5a:

```
## Interface: 30300
## Title: DC-Seasons
## Notes: DarkChaos Seasonal Reward System UI
```

## Phase 5: Testing

### 5.1 Restart Worldserver

```powershell
# Stop worldserver if running
./acore.sh worldserver stop

# Start worldserver
./acore.sh worldserver start

# Or use restarter
./acore.sh run-worldserver
```

### 5.2 Check Server Logs

Look for these lines in worldserver console:

```
>> ═══════════════════════════════════════════════════════════
>> DC Seasonal Reward System (C++ Core)
>> ═══════════════════════════════════════════════════════════
>>   Core Features:
>>     • Token & Essence Rewards (Quest/Creature/Boss)
>>     • Weekly Cap System (Configurable Limits)
>>     • Weekly Chest Rewards (3-Slot M+ Vault)
>>     • Achievement Auto-Tracking
>>     • AIO Client Communication (Eluna Bridge)
>>     • Admin Commands (.season)
>> ───────────────────────────────────────────────────────────
>>   ✓ Seasonal reward hooks and player scripts loaded
>>   ✓ Seasonal admin commands loaded (.season)
>> ═══════════════════════════════════════════════════════════
>> Seasonal Reward System: All modules loaded successfully
>> Client Addon: DC-Seasons (Interface/AddOns/DC-Seasons/)
>> Eluna Bridge: Custom/Eluna scripts/DC_Seasons_AIO.lua
>> ═══════════════════════════════════════════════════════════

[DC-Seasons AIO] Loaded successfully! Communication bridge active.
[DC-Seasons AIO] Core logic handled by C++ (src/server/scripts/DC/Seasons/)
[DC-Seasons AIO] AIO initialized, ready for client communication

[SeasonalRewards] Configuration loaded:
  Active Season: 1
  Token Item: 49426, Essence Item: 47241
  Weekly Caps: unlimited tokens, unlimited essence
[SeasonalRewards] Loaded XX quest rewards
[SeasonalRewards] Loaded XX creature rewards
[SeasonalRewards] System initialized successfully!
```

### 5.3 Test Admin Commands (In-Game)

Login with GM account (level 3+):

```
.season info
```
Expected output:
```
=== Seasonal Reward System Info ===
Enabled: Yes
Active Season: 1
Token Item: 49426, Essence Item: 47241
Weekly Caps: 999999 tokens, 999999 essence
Multipliers: Quest=1.00, Creature=1.00, WorldBoss=1.50, Event=1.25
Weekly Reset: Day 2 (0=Sun), Hour 15
```

```
.season stats
```
Expected output:
```
=== Seasonal Stats for YourCharacter ===
Season ID: 1
Total Earned: 0 tokens, 0 essence
Weekly Earned: 0 tokens, 0 essence
Activities: 0 quests, 0 creatures, 0 dungeon bosses, 0 world bosses
Prestige Level: 0
```

### 5.4 Test Reward System

Complete a quest from Season 1 rewards (e.g., Quest ID 700101):

Expected behavior:
1. Quest completes normally
2. Chat message appears: `[Seasonal Reward] Earned XXX tokens and XXX essence from Quest!`
3. Items appear in inventory
4. `.season stats` shows updated counters

Kill a creature from Season 1 rewards:

Expected behavior:
1. Loot creature normally
2. Chat message appears: `[Seasonal Reward] Earned XXX tokens from Creature!`
3. Items appear in inventory
4. `.season stats` shows updated creature kills

### 5.5 Test Client Addon

Login to game, type:
```
/seasonal
```

Expected behavior:
- Progress tracker frame appears
- Shows weekly token/essence progress bars
- Shows quest/boss counters
- Frame is draggable

Complete a quest/kill creature:
- Reward popup should appear (gold/cyan notification)
- Fades after 3 seconds
- Progress tracker updates

### 5.6 Test Weekly Cap (Optional)

Enable caps in config:
```ini
SeasonalRewards.MaxTokensPerWeek = 1000
SeasonalRewards.MaxEssencePerWeek = 500
```

Reload config:
```
.season reload
```

Award yourself tokens:
```
.season award <yourname> 900 0
.season award <yourname> 200 0
```

Expected behavior:
- First award: 900 tokens received
- Second award: 100 tokens received (capped at 1000 total)
- Chat message: `Weekly cap reached! Rewards reduced from 200 to 100.`

### 5.7 Test Weekly Reset (Optional)

Method 1: Wait for Tuesday 3 PM server time
Method 2: Change reset day/hour in config to current time

Expected behavior:
- On login after reset: Chat message about new week
- `.season stats` shows `Weekly Earned: 0 tokens, 0 essence`
- Previous week archived in `dc_player_weekly_cap_snapshot`

## Phase 6: DBC Integration (Optional)

### 6.1 Import Achievements

Use existing file: `SEASONAL_ACHIEVEMENTS.csv`
- 30 achievements (IDs 11000-11092)
- Token milestones, essence milestones, collectors, legends, meta

Merge into `Achievement.dbc` and deploy to client.

### 6.2 Import Titles

Use existing file: `SEASONAL_TITLES.csv`
- 9 titles (IDs 240-248)
- "the Seasonal", "Season X Champion", etc.

Merge into `CharTitles.dbc` and deploy to client.

## Troubleshooting

### Issue: Commands don't work
**Solution:** Check GM security level (need level 3 for most commands)

### Issue: No rewards on quest completion
**Solution:** 
1. Check quest ID exists in `dc_seasonal_quest_rewards`
2. Verify `SeasonalRewards.Enable = 1` in config
3. Check worldserver logs for errors

### Issue: C++ compilation fails
**Solution:**
1. Verify all 4 files exist in `Seasons/` directory
2. Check CMakeLists.txt includes new files
3. Run `./acore.sh compiler clean` then rebuild

### Issue: Eluna script not loading
**Solution:**
1. Check file exists: `lua_scripts/DC_Seasons_AIO.lua`
2. Delete old seasonal Lua scripts
3. Restart worldserver
4. Check for Lua syntax errors in worldserver log

### Issue: Client addon not appearing
**Solution:**
1. Verify folder name: `Interface/AddOns/DC-Seasons/`
2. Check TOC file: `Interface: 30300`
3. Enable "Load out of date addons" in addon menu
4. Type `/reload` in-game

### Issue: Weekly cap not working
**Solution:**
1. Verify cap values in config (0 = unlimited)
2. Check `.season info` shows correct caps
3. Reload config: `.season reload`

### Issue: Achievements not granted
**Solution:**
1. Verify `SeasonalRewards.AchievementTracking = 1`
2. Check achievement IDs 11000-11092 exist in Achievement.dbc
3. Check player stats: `.season stats` shows token threshold met

## Migration from Old System

If you previously deployed the Eluna-only implementation:

### Step 1: Delete Old Eluna Scripts
```powershell
Remove-Item "lua_scripts/SeasonalRewards.lua" -ErrorAction SilentlyContinue
Remove-Item "lua_scripts/SeasonalCommands.lua" -ErrorAction SilentlyContinue
Remove-Item "lua_scripts/SeasonalCaps.lua" -ErrorAction SilentlyContinue
Remove-Item "lua_scripts/SeasonalIntegration.lua" -ErrorAction SilentlyContinue
```

### Step 2: Database Migration
No migration needed - table schemas are compatible!

### Step 3: Deploy New System
Follow Phase 1-5 above.

### Step 4: Verify
```
.season info
.season stats
```

All existing player data will be preserved.

## Support

For issues, check:
1. `VALIDATION_REPORT.md` - Complete system validation
2. `Custom/Client addons needed/DC-Seasons/README.md` - Client addon docs
3. This deployment guide

## Version History

- **v1.0.0 (Nov 22, 2025)** - C++ core implementation
  - Replaced Eluna logic with C++ for performance
  - Minimal Eluna bridge for AIO only
  - Complete admin command system
  - Weekly cap enforcement
  - Achievement auto-tracking
  - Client UI (DC-Seasons addon)

- **v0.9.0 (Nov 20, 2025)** - Eluna implementation (deprecated)
  - Pure Eluna implementation
  - Phase 1-2 features
  - 450+ lines of Lua code
