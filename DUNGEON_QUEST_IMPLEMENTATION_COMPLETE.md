# 🎯 DUNGEON QUEST SYSTEM - COMPLETE IMPLEMENTATION GUIDE

**Status**: ✅ READY FOR IMPLEMENTATION  
**Last Updated**: November 3, 2025  
**Deliverables**: 3 CSV files + 1 SQL schema file  

---

## 📋 Quick Overview

This implementation package includes:

### ✅ **DBC Modifications (3 CSV Files)**
1. `ITEMS_DUNGEON_TOKENS.csv` - 5 token items (IDs 700001-700005)
2. `ACHIEVEMENTS_DUNGEON_QUESTS.csv` - 53 achievements (IDs 13500-13552)
3. `TITLES_DUNGEON_QUESTS.csv` - 53 titles (IDs 2000-2052)

### ✅ **Database Schema (1 SQL File)**
- **CHARACTER DB**: 4 new tables for quest tracking, NPC respawn, statistics
- **WORLD DB**: 7 new tables for dungeon mapping, phasing, quest definitions
- **Phased NPC System**: Combat-based despawn + manual respawn

### ✅ **Special Features**
- NPCs spawn ONLY when entering dungeon (phased appearance)
- NPCs despawn at first combat encounter
- Manual respawn command outside combat
- Cooldown system prevents spam respawning
- Daily/weekly quest resets per player
- Achievement tracking with titles

---

## 📂 File Locations

```
Custom/CSV DBC/
├── ITEMS_DUNGEON_TOKENS.csv          ← Token rewards
├── ACHIEVEMENTS_DUNGEON_QUESTS.csv   ← Quest achievements
└── TITLES_DUNGEON_QUESTS.csv         ← Achievement titles

Custom/Custom feature SQLs/
└── DUNGEON_QUEST_DATABASE_SCHEMA.sql ← Complete database setup
```

---

## 🚀 IMPLEMENTATION STEPS

### PHASE 1: DBC PREPARATION (2-3 hours)

#### Step 1.1: Export Current DBCs to CSV

Extract the three DBC files to CSV format using your DBC tools:

```bash
# Using AzerothCore's DBC extractor (location varies by setup)
# Typically in: apps/extractor/ or tools/

# Export Item.dbc
./dbc_extract Item.dbc -o Item.csv

# Export Achievement.dbc
./dbc_extract Achievement.dbc -o Achievement.csv

# Export CharTitles.dbc
./dbc_extract CharTitles.dbc -o CharTitles.csv
```

#### Step 1.2: Merge CSV Entries

**For Item.csv:**
```
1. Open exported Item.csv
2. Append 5 lines from ITEMS_DUNGEON_TOKENS.csv (lines 2-6)
3. Save as Item.csv
```

**For Achievement.csv:**
```
1. Open exported Achievement.csv
2. Append 53 lines from ACHIEVEMENTS_DUNGEON_QUESTS.csv (lines 2-54)
3. Save as Achievement.csv
```

**For CharTitles.csv:**
```
1. Open exported CharTitles.csv
2. Append 53 lines from TITLES_DUNGEON_QUESTS.csv (lines 2-54)
3. Save as CharTitles.csv
```

#### Step 1.3: Recompile DBCs

Convert modified CSV files back to binary DBC format:

```bash
./dbc_compile Item.csv -o Item.dbc
./dbc_compile Achievement.csv -o Achievement.dbc
./dbc_compile CharTitles.csv -o CharTitles.dbc
```

#### Step 1.4: Deploy DBCs

Copy updated DBC files to client data directory:

```bash
cp Item.dbc Custom/DBCs/Item.dbc
cp Achievement.dbc Custom/DBCs/Achievement.dbc
cp CharTitles.dbc Custom/DBCs/CharTitles.dbc
```

**Verify**: Client should now see new items/achievements/titles in game.

---

### PHASE 2: DATABASE SCHEMA SETUP (1 day)

#### Step 2.1: Backup Existing Data

```sql
-- CHARACTER DATABASE
BACKUP TABLE character_dungeon_progress;
BACKUP TABLE character_dungeon_quests_completed;
BACKUP TABLE character_dungeon_npc_respawn;
BACKUP TABLE character_dungeon_statistics;

-- WORLD DATABASE  
BACKUP TABLE dungeon_quest_mapping;
BACKUP TABLE dungeon_quest_npcs;
BACKUP TABLE creature_phase_visibility;
BACKUP TABLE dungeon_quest_definitions;
BACKUP TABLE dungeon_quest_rewards;
```

#### Step 2.2: Apply Schema to Databases

**On CHARACTER database (acore_characters):**
```bash
mysql -h localhost -u root -p acore_characters < DUNGEON_QUEST_DATABASE_SCHEMA.sql
```

**On WORLD database (acore_world):**
```bash
mysql -h localhost -u root -p acore_world < DUNGEON_QUEST_DATABASE_SCHEMA.sql
```

#### Step 2.3: Verify Tables Created

```sql
-- Check CHARACTER DB tables
USE acore_characters;
SHOW TABLES LIKE 'character_dungeon%';
-- Should show 4 tables: character_dungeon_progress, character_dungeon_quests_completed, 
--                      character_dungeon_npc_respawn, character_dungeon_statistics

-- Check WORLD DB tables
USE acore_world;
SHOW TABLES LIKE 'dungeon_quest%';
-- Should show 7 tables: dungeon_quest_mapping, dungeon_quest_npcs, dungeon_quest_definitions,
--                      dungeon_quest_rewards, dungeon_quest_config, dungeon_instance_resets,
--                      creature_phase_visibility
```

#### Step 2.4: Configure Dungeon Mappings

Edit `dungeon_quest_mapping` to add all 53 dungeons:

```sql
INSERT INTO dungeon_quest_mapping 
  (dungeon_name, map_id, phase_id, npc_entry, min_level, max_level, difficulty, tier, token_type)
VALUES
  -- Add all dungeons (1-53)
  -- Phase IDs: 100-152 (reserved for phased NPCs)
  -- NPC entries: 700001-700053 (reserved)
  -- Token types: 700001-700005
;
```

---

### PHASE 3: C++ CORE IMPLEMENTATION (2-3 weeks)

#### Step 3.1: Create Phasing System Core

**File**: `src/server/scripts/DC/phase_dungeon_quest_system.cpp` (350 lines)

Core features:
- Load phase mappings from database on startup
- Update player phase on dungeon entry
- Reset player phase on dungeon exit
- Handle combat-based despawn logic

#### Step 3.2: Create Quest NPC Script

**File**: `src/server/scripts/DC/npc_dungeon_quest_master.cpp` (150 lines)

Features:
- Gossip menu for quest selection
- Daily/weekly quest availability
- Visibility checks based on player level
- NPC despawn on first combat
- Manual respawn command: `.dungeon respawn`

#### Step 3.3: Combat Hook Implementation

Add to NPC script:

```cpp
void OnCombatStart(Unit* who) override
{
    if (is_despawn_on_combat_enabled)
    {
        // Record despawn in database
        // character_dungeon_npc_respawn.is_despawned = 1
        
        // Set respawn cooldown
        // respawn_cooldown_until = NOW() + respawn_cooldown_sec
        
        // Despawn creature
        me->DespawnOrUnsummon();
    }
}
```

#### Step 3.4: Register Commands

Add to command handler:

```
Command: .dungeon respawn
Usage: Respawn the quest NPC outside combat
Cooldown: Per dungeon_npc_respawn.respawn_cooldown_sec
Requirements: Must be in dungeon, not in combat
```

---

### PHASE 4: INSTANCE MODIFICATIONS (1 week)

Modify 53 dungeon instance scripts to handle phasing:

#### Step 4.1: Instance Entry Hook

```cpp
void OnPlayerEnter(Player* player) override
{
    // Get dungeon_id from map_id lookup
    uint32 dungeonId = GetDungeonIdFromMapId(player->GetMapId());
    
    // Get phase_id from dungeon_quest_mapping
    uint32 phaseId = GetPhaseIdForDungeon(dungeonId);
    
    // Set player phase
    player->SetPhaseMask(phaseId, false);
    player->UpdateVisibility();
    
    // Record in database
    // dungeon_instance_resets table
}
```

#### Step 4.2: Instance Exit Hook

```cpp
void OnPlayerLeave(Player* player) override
{
    // Reset to world phase (phase 1)
    player->SetPhaseMask(1, false);
    player->UpdateVisibility();
}
```

---

### PHASE 5: TESTING (1-2 weeks)

#### Test Case 1: NPC Visibility
```
✓ Enter dungeon → NPC visible
✓ Leave dungeon → NPC invisible
✓ Different dungeons → Different NPCs visible
```

#### Test Case 2: Quest Acceptance
```
✓ Talk to NPC → Gossip menu appears
✓ Accept quest → Quest tracking starts
✓ Level requirement enforced
```

#### Test Case 3: Combat Despawn
```
✓ Enter combat with NPC → NPC despawns
✓ NPC stays gone until respawn
✓ Despawn logged in database
```

#### Test Case 4: Manual Respawn
```
✓ Use `.dungeon respawn` command → NPC reappears
✓ Cooldown enforced between respawns
✓ Cannot respawn in combat
✓ Cooldown logged in database
```

#### Test Case 5: Daily/Weekly Resets
```
✓ Daily quests reset at configured hour
✓ Weekly quests reset on configured day
✓ Progress tracked per character
✓ Rewards can only be claimed once per cycle
```

#### Test Case 6: Achievements
```
✓ Completing quests unlocks achievements
✓ Achievements appear in achievement panel
✓ Titles become selectable after achievement
✓ Items appear in inventory/mail
```

#### Test Case 7: Performance
```
✓ Phase lookups <1ms
✓ No memory leaks
✓ 100+ concurrent players supported
✓ Database queries cached
```

---

## 🗄️ DATABASE STRUCTURE SUMMARY

### CHARACTER DATABASE

| Table | Purpose | Key Fields |
|-------|---------|-----------|
| `character_dungeon_progress` | Track quest status per player | guid, dungeon_id, quest_id, status |
| `character_dungeon_quests_completed` | Historical completion log | guid, dungeon_id, completion_time |
| `character_dungeon_npc_respawn` | Track NPC despawn/respawn | guid, npc_entry, is_despawned |
| `character_dungeon_statistics` | Overall player statistics | guid, total_quests_completed |

### WORLD DATABASE

| Table | Purpose | Key Fields |
|-------|---------|-----------|
| `dungeon_quest_mapping` | Dungeon configuration | dungeon_id, map_id, phase_id, npc_entry |
| `dungeon_quest_npcs` | NPC spawn data | npc_entry, dungeon_id, phase_mask, despawn_on_combat |
| `dungeon_quest_definitions` | Quest objectives | quest_id, dungeon_id, quest_type, objective_type |
| `dungeon_quest_rewards` | Reward configuration | achievement_id, token_count, gold_count |
| `creature_phase_visibility` | Phase visibility mapping | creature_guid, phase_id |
| `dungeon_quest_config` | Global settings | config_key, config_value |
| `dungeon_instance_resets` | Reset tracking | guid, dungeon_id, reset_date |

---

## 🎮 PLAYER COMMANDS

```
.dungeon respawn
  - Respawn the quest NPC outside combat
  - Cooldown: 5 minutes (configurable)
  - Requires: In dungeon, not in combat

.dungeon status
  - Show quest progress and NPC status
  - Display current cooldowns

.dungeon reset
  - Force reset of dungeon progress (admin only)
```

---

## 📊 ACHIEVEMENTS OVERVIEW

**IDs: 13500-13552** (53 achievements)

### Dungeon-Specific (1-53)
- One achievement per dungeon
- Complete all daily quests in that dungeon
- Unlock corresponding title

### Cross-Dungeon (54+)
- **13508**: Veteran (50 quests across dungeons)
- **13509**: Master (100 quests across dungeons)
- **13510**: Challenge Seeker (10 challenge objectives)
- **13511**: Speedrunner (Complete speedrun quest)
- **13512**: Rare Collector (Defeat all rares)
- **13513**: Token Accumulator (100 tokens)
- **13514**: Dungeon Daily (30 consecutive days)
- **13515**: Legendary Achiever (Get legendary item)

---

## 🎖️ TITLES OVERVIEW

**IDs: 2000-2052** (53 titles)

Each dungeon unlocks a unique prestige title:

```
Dungeon            → Title Pattern
Blackrock Depths   → "%s, Depths Explorer"
Stratholme         → "%s, Stratholme's Bane"
Molten Core        → "%s, Flame's Purifier"
Black Temple       → "%s, Shadow Slayer"
Ulduar             → "%s, Titan's Foe"
... (48 more)
```

Master achievement title: **"Ultimate Dungeon Master %s"**

---

## 💰 REWARDS SUMMARY

### Tokens (Item IDs 700001-700005)
- Used for trading at vendors
- Non-tradeable between players
- Quest drop rate: 5-15 per daily quest
- Can be saved for special exchanges

### Gold
- 1,500-4,000 gold per daily quest
- Scales by dungeon difficulty
- 2,000-8,000 gold per weekly quest

### Items
- Dungeon-specific drops from quest completion
- Cosmetic prestige items
- Equipment upgrades (scaling by tier)

### Achievements & Titles
- 53 dungeon-specific achievements
- 53 corresponding prestige titles
- 8 cross-dungeon meta achievements

---

## ⚙️ CONFIGURATION

Edit `dungeon_quest_config` table to customize:

```sql
UPDATE dungeon_quest_config 
SET config_value = '1' 
WHERE config_key = 'SYSTEM_ENABLED';

UPDATE dungeon_quest_config 
SET config_value = '300' 
WHERE config_key = 'RESPAWN_COOLDOWN_DEFAULT';

UPDATE dungeon_quest_config 
SET config_value = '6' 
WHERE config_key = 'DAILY_RESET_HOUR';
```

---

## 🔍 TROUBLESHOOTING

### Issue: NPC Not Visible in Dungeon
- Check `dungeon_quest_npcs.is_visible_on_entry` = 1
- Verify player phase matches `phase_mask`
- Check `dungeon_quest_mapping.enabled` = 1

### Issue: Quest Not Accepting
- Verify player level in range (min_level to max_level)
- Check `dungeon_quest_definitions.enabled` = 1
- Check quest type matches current cycle (daily/weekly)

### Issue: Respawn Command Not Working
- Verify `character_dungeon_npc_respawn.respawn_cooldown_until` has passed
- Ensure player is not in combat
- Check `dungeon_quest_npcs.respawn_enabled` = 1

### Issue: Achievements Not Triggering
- Verify `character_dungeon_quests_completed` records inserted
- Check `dungeon_quest_definitions.achievement_link` is set
- Ensure achievement criteria met (quest completion count)

---

## 📋 PRE-DEPLOYMENT CHECKLIST

- [ ] All 3 DBC files compiled and deployed
- [ ] Database schema created on both DBs
- [ ] All 53 dungeons added to `dungeon_quest_mapping`
- [ ] NPC entries configured in `dungeon_quest_npcs` (53+ rows)
- [ ] Phase IDs assigned (100-152)
- [ ] C++ core code compiled without errors
- [ ] Instance scripts modified for all 53 dungeons
- [ ] Commands registered and tested
- [ ] Database queries optimized with indexes
- [ ] Performance tested with 100+ concurrent players
- [ ] All 7 test categories passed
- [ ] Admin commands working (respawn, reset, status)
- [ ] Achievement/title unlocks verified
- [ ] Backup procedure documented
- [ ] Rollback procedure tested

---

## 🎉 SUCCESS CRITERIA

When fully implemented, players should experience:

✅ **Immersive Quest NPCs**: NPCs appear only in their dungeons  
✅ **Dynamic Combat**: NPCs disappear when combat starts  
✅ **Manual Control**: Manual respawn commands available  
✅ **Persistent Tracking**: Progress saved across sessions  
✅ **Rewarding System**: Tokens, gold, items, achievements, titles  
✅ **Daily/Weekly Resets**: Automatic quest resets  
✅ **Prestige Titles**: Exclusive titles for dedicated players  
✅ **Performance**: Zero lag, smooth experience  

---

## 📞 SUPPORT RESOURCES

**SQL Schema**: `DUNGEON_QUEST_DATABASE_SCHEMA.sql`  
**DBC Additions**: `ITEMS_DUNGEON_TOKENS.csv`, `ACHIEVEMENTS_DUNGEON_QUESTS.csv`, `TITLES_DUNGEON_QUESTS.csv`  
**Implementation Details**: `PHASED_NPC_IMPLEMENTATION_ANALYSIS.md`  
**Advanced Features**: See instance script modifications guide  

---

**Status**: ✅ Ready for implementation  
**Next Step**: Begin PHASE 1 DBC preparation  

Good luck! 🚀
