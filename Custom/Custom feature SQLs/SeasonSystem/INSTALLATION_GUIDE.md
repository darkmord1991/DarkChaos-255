# Season System - Phase 1 Installation Guide

## Prerequisites

- AzerothCore-based server (DarkChaos-255)
- Eluna scripting engine enabled
- MySQL/MariaDB database access
- DBC editing tools (optional, for achievements/titles)

---

## Installation Steps

### Step 1: Database Setup

#### 1.1 Execute Schema Files (If Not Already Done)
```bash
# Connect to MySQL
mysql -u root -p

# For worlddb (reward configurations)
USE acore_world;
SOURCE Custom/Custom feature SQLs/worlddb/SeasonSystem/dc_seasonal_rewards.sql;

# For chardb (player stats tracking)
USE acore_characters;
SOURCE Custom/Custom feature SQLs/chardb/SeasonSystem/dc_seasonal_player_stats.sql;
```

#### 1.2 Populate Season 1 Rewards
```bash
# Still in MySQL
USE acore_world;
SOURCE Custom/Custom feature SQLs/worlddb/SeasonSystem/01_POPULATE_SEASON_1_REWARDS.sql;
```

#### 1.3 Verify Data Population
```sql
-- Check quest rewards
SELECT COUNT(*) AS quest_count FROM dc_seasonal_quest_rewards WHERE season_id = 1 AND enabled = TRUE;
-- Expected: 11

-- Check creature rewards
SELECT COUNT(*) AS creature_count FROM dc_seasonal_creature_rewards WHERE season_id = 1 AND enabled = TRUE;
-- Expected: 62

-- Breakdown by type
SELECT 
  CASE creature_rank
    WHEN 0 THEN 'Normal'
    WHEN 1 THEN 'Rare'
    WHEN 2 THEN 'Boss'
    WHEN 3 THEN 'World Boss'
  END AS rank,
  COUNT(*) AS count
FROM dc_seasonal_creature_rewards 
WHERE season_id = 1 AND enabled = TRUE
GROUP BY creature_rank;
```

**Expected Results:**
```
World Boss: 7
Boss: 55 (dungeon + raid + event)
```

---

### Step 2: Install Eluna Script

#### 2.1 Copy Script File
```bash
# Option A: Direct copy (if using standard Eluna directory)
cp "Custom/Eluna scripts/SeasonalRewards.lua" "lua_scripts/SeasonalRewards.lua"

# Option B: Symlink (for development, keeps changes synced)
ln -s "$(pwd)/Custom/Eluna scripts/SeasonalRewards.lua" "lua_scripts/SeasonalRewards.lua"
```

#### 2.2 Configure Custom Token Items (Optional)

**If you want custom items instead of placeholders:**

1. Create custom items in `item_template`:
```sql
-- Example: Seasonal Token
INSERT INTO item_template (entry, class, subclass, name, displayid, Quality, Flags, BuyPrice, SellPrice, ItemLevel, RequiredLevel, description)
VALUES 
(990001, 12, 0, 'Seasonal Token', 44602, 3, 0, 0, 0, 1, 1, 'Currency earned during Season 1. Used to purchase seasonal rewards.'),
(990002, 12, 0, 'Seasonal Essence', 44603, 4, 0, 0, 0, 1, 1, 'Rare currency earned from challenging content.');
```

2. Update Eluna script:
```lua
-- Edit lua_scripts/SeasonalRewards.lua
SeasonalRewards.Config = {
    TOKEN_ITEM_ID = 990001,      -- Your custom token ID
    ESSENCE_ITEM_ID = 990002,    -- Your custom essence ID
    -- ... rest of config
}
```

**If using placeholders (Emblem of Frost/Triumph):**
- No changes needed, script defaults to:
  - `TOKEN_ITEM_ID = 49426` (Emblem of Frost)
  - `ESSENCE_ITEM_ID = 47241` (Emblem of Triumph)

#### 2.3 Restart Worldserver
```bash
# Stop worldserver
./acore.sh worldserver stop

# Start worldserver
./acore.sh worldserver start

# Or if running directly:
killall worldserver
./worldserver
```

#### 2.4 Verify Script Loaded
**Check server console output:**
```
[SeasonalRewards] Initializing Seasonal Reward System...
[SeasonalRewards] Loading quest rewards cache...
[SeasonalRewards] Loaded 11 quest reward configs
[SeasonalRewards] Loading creature rewards cache...
[SeasonalRewards] Loaded 62 creature reward configs
[SeasonalRewards] Seasonal Reward System initialized successfully!
[SeasonalRewards] Active Season: 1
[SeasonalRewards] Quest Rewards: ENABLED | Creature Rewards: ENABLED
```

---

### Step 3: Import DBC Entries (Optional - For Achievements/Titles)

#### 3.1 Prepare CSV Files

**Option A: Append to existing Achievement.csv**
```bash
cd "Custom/CSV DBC"
cat SEASONAL_ACHIEVEMENTS.csv >> Achievement.csv
```

**Option B: Manually merge (recommended for conflict avoidance)**
1. Open `Achievement.csv` in Excel/LibreOffice
2. Copy rows from `SEASONAL_ACHIEVEMENTS.csv`
3. Paste at end of `Achievement.csv`
4. Save

**Repeat for CharTitles.csv:**
```bash
cat SEASONAL_TITLES.csv >> CharTitles.csv
```

#### 3.2 Convert CSV to DBC

**Using WoW DBC Editor:**
1. Open WoW DBC Editor
2. File → Open → Select `Achievement.csv`
3. File → Save As → Select DBC format
4. Save as `Achievement.dbc`
5. Repeat for `CharTitles.dbc`

**Using Command-Line Tool (if available):**
```bash
# Example command (adjust for your toolchain)
python dbc_converter.py Achievement.csv --output Achievement.dbc
python dbc_converter.py CharTitles.csv --output CharTitles.dbc
```

#### 3.3 Deploy DBC Files
```bash
# Copy to server DBC directory
cp Achievement.dbc /path/to/azerothcore/data/dbc/
cp CharTitles.dbc /path/to/azerothcore/data/dbc/

# Restart worldserver
./acore.sh worldserver restart
```

#### 3.4 Verify Achievements In-Game
1. Log in to game
2. Open Achievement panel (default: Y key)
3. Search for "Seasonal Novice" (ID 11000)
4. Verify achievement appears with correct description

**Troubleshooting:**
- If achievements don't appear, delete client cache folder (`Cache/`)
- Verify DBC files are in correct server directory
- Check server console for DBC loading errors

---

### Step 4: Create Seasonal Vendor (Optional)

#### 4.1 Create NPC Template
```sql
-- Insert creature template
DELETE FROM creature_template WHERE entry = 120345;
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, name, subname, minlevel, maxlevel, faction, npcflag, speed_walk, speed_run, scale, rank, dmgschool, BaseAttackTime, RangeAttackTime, unit_class, unit_flags, unit_flags2, dynamicflags, family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier, ManaModifier, ArmorModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, spell_school_immune_mask, flags_extra, ScriptName, VerifiedBuild)
VALUES 
(120345, 0, 0, 0, 'Seasonal Quartermaster', 'Token Vendor', 80, 80, 35, 128, 1.0, 1.14286, 1.0, 0, 0, 2000, 2000, 1, 0, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 'npc_mythic_token_vendor', 0);

-- Set model (use existing NPC model or custom)
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability)
VALUES (120345, 0, 30259, 1.0, 1);  -- Blood Elf female model
```

#### 4.2 Spawn Vendor
```sql
-- Example spawn location: Dalaran (Krasus' Landing)
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, currentwaypoint, curhealth, curmana, MovementType, npcflag, unit_flags, dynamicflags, ScriptName, VerifiedBuild)
VALUES 
(999999, 120345, 571, 4395, 4395, 1, 1, 5807.75, 588.06, 660.14, 1.57, 300, 0, 0, 12600, 0, 0, 128, 0, 0, '', 0);
```

**Alternative Spawn Locations:**
- Stormwind: `-8866.56, 673.18, 97.90` (Trade District)
- Orgrimmar: `1631.07, -4440.22, 15.43` (Valley of Strength)
- Mythic+ Hub: Use coordinates from `dc_mythic_dungeons_world.sql`

#### 4.3 Configure Vendor Items
```sql
-- Create example vendor entries
-- Adjust item IDs to your seasonal reward items

DELETE FROM npc_vendor WHERE entry = 120345;
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, VerifiedBuild)
VALUES
-- Seasonal Chests (adjust item IDs)
(120345, 0, 50001, 0, 0, 0, 0),  -- Bronze Chest - 100 tokens
(120345, 1, 50002, 0, 0, 0, 0),  -- Silver Chest - 250 tokens
(120345, 2, 50003, 0, 0, 0, 0),  -- Gold Chest - 500 tokens

-- Seasonal Mounts (example)
(120345, 10, 50010, 0, 0, 0, 0), -- Seasonal Mount - 1000 tokens

-- Seasonal Pets (example)
(120345, 20, 50020, 0, 0, 0, 0); -- Seasonal Pet - 500 tokens
```

**Note:** You'll need to create the actual chest/mount/pet items in `item_template` table.

---

### Step 5: Testing & Verification

#### 5.1 Test Quest Rewards
```
1. Log in to game
2. Accept daily dungeon quest (ID 700101-700104)
3. Complete dungeon
4. Turn in quest
5. Check inventory for tokens/essence
6. Verify chat message appears
```

**Expected Output:**
```
[Seasonal Reward] You earned 50 Tokens and 25 Essence from [Quest Name]!
```

**Verify Database:**
```sql
SELECT * FROM dc_reward_transactions 
WHERE player_guid = <your_guid> AND source_type = 'quest'
ORDER BY transaction_timestamp DESC LIMIT 5;
```

#### 5.2 Test World Boss Kill
```
1. Form raid group (or solo if GM)
2. Locate Azuregos in Azshara
3. Kill Azuregos
4. Verify all group members receive reward split
```

**Expected Output (solo):**
```
[Seasonal Reward] You earned 150 Tokens and 75 Essence from Azuregos!
```

**Expected Output (10-player group):**
```
[Seasonal Reward] You earned 15 Tokens and 7 Essence from Azuregos!
```

#### 5.3 Test Dungeon Boss Kill
```
1. Enter any WotLK heroic dungeon
2. Kill first boss
3. Verify 10 tokens awarded (no essence)
```

#### 5.4 Test Cache Refresh
```
1. Note server start time
2. Wait 5 minutes
3. Check server console for: "[SeasonalRewards] Cache expired, refreshing..."
4. Modify a reward value in database
5. Wait 5 minutes
6. Kill same creature and verify new reward value applied
```

---

## Post-Installation Configuration

### Adjust Reward Values
```sql
-- Example: Increase world boss rewards by 20%
UPDATE dc_seasonal_creature_rewards
SET base_token_amount = base_token_amount * 1.2,
    base_essence_amount = base_essence_amount * 1.2
WHERE creature_rank = 3 AND season_id = 1;

-- Wait 5 minutes for cache refresh, or restart worldserver
```

### Enable/Disable Specific Rewards
```sql
-- Disable event boss rewards outside of event
UPDATE dc_seasonal_creature_rewards
SET enabled = FALSE
WHERE creature_id IN (25740, 23872, 23682) AND season_id = 1;

-- Re-enable during event
UPDATE dc_seasonal_creature_rewards
SET enabled = TRUE
WHERE creature_id IN (25740, 23872, 23682) AND season_id = 1;
```

### Adjust Group Split Behavior
```lua
-- Edit lua_scripts/SeasonalRewards.lua
SeasonalRewards.Config = {
    -- Disable group splitting (all players get full reward)
    GROUP_SPLIT_ENABLED = false,
    
    -- Increase reward range
    MAX_REWARD_DISTANCE = 200,  -- 200 yards instead of 100
    
    -- ... rest of config
}
```

---

## Rollback Instructions (If Needed)

### Remove Eluna Script
```bash
rm lua_scripts/SeasonalRewards.lua
./acore.sh worldserver restart
```

### Disable Rewards Without Deleting Data
```sql
-- Disable all quest rewards
UPDATE dc_seasonal_quest_rewards SET enabled = FALSE WHERE season_id = 1;

-- Disable all creature rewards
UPDATE dc_seasonal_creature_rewards SET enabled = FALSE WHERE season_id = 1;

-- Restart worldserver or wait 5 minutes for cache refresh
```

### Complete Removal (Irreversible)
```sql
-- Delete Season 1 data
DELETE FROM dc_seasonal_quest_rewards WHERE season_id = 1;
DELETE FROM dc_seasonal_creature_rewards WHERE season_id = 1;
DELETE FROM dc_player_seasonal_stats WHERE season_id = 1;
DELETE FROM dc_reward_transactions WHERE season_id = 1;

-- Drop tables entirely
DROP TABLE IF EXISTS dc_seasonal_quest_rewards;
DROP TABLE IF EXISTS dc_seasonal_creature_rewards;
DROP TABLE IF EXISTS dc_player_seasonal_stats;
DROP TABLE IF EXISTS dc_reward_transactions;
```

---

## Support & Resources

### Documentation Files
- `PHASE_1_IMPLEMENTATION_SUMMARY.md` - Complete feature overview
- `QUICK_REFERENCE.md` - Reward values and achievement list
- `SEASON_SYSTEM_DESIGN.md` - Original 5-phase design document

### Database Queries
- See `QUICK_REFERENCE.md` for common admin queries

### Troubleshooting
- Enable debug mode in `SeasonalRewards.lua`: `DEBUG_MODE = true`
- Check server console for `[SeasonalRewards]` messages
- Verify SQL execution with `SHOW WARNINGS;` after each script

### Community Resources
- AzerothCore Discord: https://discord.gg/gkt4y2x
- Eluna Documentation: https://github.com/ElunaLuaEngine/Eluna

---

## Next Steps (Phase 2)

After successful Phase 1 deployment and 2+ weeks of testing:

1. **Client Integration:** Create AIO addon for visual reward notifications
2. **Weekly Caps:** Implement cap enforcement with reset snapshots
3. **Chest System:** Design loot tables and chest opening script
4. **Bonus Multipliers:** Add weekend/holiday bonuses
5. **Admin Tools:** In-game commands for season management

---

**Installation Complete!**

Run verification tests above to confirm all components operational. Monitor player feedback and token economy balance for 2 weeks before proceeding to Phase 2.

**Questions?** Check `PHASE_1_IMPLEMENTATION_SUMMARY.md` or open a support ticket.
