# NPC SPAWNING STRATEGY & DAILY/WEEKLY QUEST SYSTEM
## Implementation Plan for DC-255 Server (REVISED v2.0)

**Date**: November 2, 2025  
**Version**: 2.0  
**Status**: Updated with Token System & Custom ID Ranges  
**Key Changes**: 
- NPC/Quest IDs start from 700000
- Token-based rewards (configurable, no prestige)
- Dungeon-fitting NPC models
- game_tele-based spawning coordinates
- CSV-based achievements/titles/DBCs

---

## SECTION 1: NPC SPAWNING OPTIONS

### Option A: Manual Creature System (TRADITIONAL)

**How It Works**:
- Create creature_template entries for each NPC (90001-90999)
- Create creature table entries for each spawn location
- Use standard NPC system

**Pros**:
- ✅ Uses AzerothCore standard system
- ✅ Can manage via database tools
- ✅ Integrates with creature AI system
- ✅ Can use custom AI if needed

**Cons**:
- ❌ Manual entry for each spawn
- ❌ Cannot dynamically add/remove
- ❌ Rigid system

**Estimated Work**: 1-2 hours (for all 53 NPCs)

---

### Option B: Automated Spawning (CUSTOM SCRIPT)

**How It Works**:
- C++ script reads from dungeon_quest_npc table
- Script spawns NPCs at server startup
- Dynamic, database-driven

**Pros**:
- ✅ Can add/remove NPCs via SQL
- ✅ Automatic spawning at startup
- ✅ Single script handles all NPCs
- ✅ Can be toggled via config

**Cons**:
- ❌ Requires custom C++ code
- ❌ More complex implementation
- ❌ Need to manage NPC deletion

**Estimated Work**: 2-3 hours (C++ spawning logic)

---

### Option C: Hybrid Approach (RECOMMENDED FOR DC-255) ⭐

**How It Works**:
1. Create creature_template entries manually (once, 53 entries)
2. Create creature spawns manually (once, 53 entries)
3. Use dungeon_quest_npc table ONLY for quest mapping
4. C++ script handles quest logic, not spawning

**Pros**:
- ✅ Uses standard creature system (compatible)
- ✅ NPCs spawn with server (no extra logic)
- ✅ Minimal C++ code
- ✅ Can manage NPCs with standard tools
- ✅ Quest logic isolated in C++ script
- ✅ Scales easily to 1000+ NPCs

**Cons**:
- ⚠️ Manual setup for each NPC (one-time)
- ⚠️ Cannot dynamically add without SQL

**Estimated Work**: 2 hours total (setup once, reuse forever)

---

## RECOMMENDATION: HYBRID APPROACH

**Why for DC-255?**
1. Your server already uses creature system
2. Integrates seamlessly with existing infrastructure
3. Minimal custom code needed
4. Maximum compatibility

**Implementation**:
```
Step 1: Create creature_template entries (DC_ prefixed)
        → 53 entries, one script/batch creates all
        
Step 2: Create creature spawns at dungeon entrances
        → 53 spawns, one SQL file with all locations
        
Step 3: Create dungeon_quest_npc mapping table
        → Links quest masters to quests
        → Managed by DC_ prefix SQL files
        
Step 4: Create C++ gossip script
        → Reads from dungeon_quest_npc
        → Handles quest acceptance & achievements
        → Single script file
```

---

## SECTION 2: HYBRID SPAWNING IMPLEMENTATION (game_tele based)

### Step 1: creature_template Entries with Dungeon-Fitting Models

**File**: `Custom\Custom feature SQLs\DC_DUNGEON_QUEST_CREATURES.sql`

**ID Range**: 700000-700052 (53 NPCs total)

**Model Selection by Dungeon Type**:
- **Dwarf/Gnome Dungeons**: Models for Blackrock Depths, Ironforge zones (Dwarf models: 1, 3, 9)
- **Human/Scarlet**: Scarlet Monastery (Human priest/warrior models: 4, 12)
- **Troll**: Zul'Farrak, Zul'Aman (Troll models: 8, 15)
- **Draenei/Blood Elf**: Black Temple, Karazhan (Draenei: 11, Blood Elf: 14)
- **Dwarf Giant**: Ulduar (Dwarf shaman/warrior with size variations)
- **Forsaken**: Pit of Saron, Halls of Reflection (Undead models: 10)
- **Night Elf**: Temple of Ahn'Qiraj, World Bosses (Night Elf models: 2, 7)

```sql
-- ============================================================================
-- DC DUNGEON QUEST NPCS - CREATURE TEMPLATES
-- ============================================================================

-- CLASSIC: Blackrock Depths Quest Master (Model: Dwarf Warrior)
INSERT INTO creature_template (entry, name, subname, IconName, gossip_menu_id, minlevel, maxlevel, exp, 
    unitflags, type, family, rank, displayid, BaseAttackTime, RangeAttackTime, unitflags2, dynamicflags, 
    lootid, pickpocketloot, skinloot, AIName, MovementType, InhabitType, speed_walk, speed_run, 
    scale, detection_range, CallForHelpRange, Courage, Regeneration) VALUES
(700000, 'Quest Master Ironforge', 'Blackrock Depths', 'questmarker', 0, 60, 60, 0,
    0, 7, 0, 0, 1, 1500, 1500, 0, 0,  -- Model 1 = Dwarf
    0, 0, 0, '', 0, 3, 1, 1.14286, 1, 20, 5, 1, 100000);

-- CLASSIC: Scarlet Monastery Quest Master (Model: Human Priest)
INSERT INTO creature_template (entry, name, subname, IconName, gossip_menu_id, minlevel, maxlevel, exp,
    unitflags, type, family, rank, displayid, BaseAttackTime, RangeAttackTime, unitflags2, dynamicflags,
    lootid, pickpocketloot, skinloot, AIName, MovementType, InhabitType, speed_walk, speed_run,
    scale, detection_range, CallForHelpRange, Courage, Regeneration) VALUES
(700001, 'Quest Master Scarlet', 'Scarlet Monastery', 'questmarker', 0, 60, 60, 0,
    0, 7, 0, 0, 4, 1500, 1500, 0, 0,  -- Model 4 = Human Priest
    0, 0, 0, '', 0, 3, 1, 1.14286, 1, 20, 5, 1, 100000);

-- TBC: Black Temple Quest Master (Model: Blood Elf Mage)
INSERT INTO creature_template (entry, name, subname, IconName, gossip_menu_id, minlevel, maxlevel, exp,
    unitflags, type, family, rank, displayid, BaseAttackTime, RangeAttackTime, unitflags2, dynamicflags,
    lootid, pickpocketloot, skinloot, AIName, MovementType, InhabitType, speed_walk, speed_run,
    scale, detection_range, CallForHelpRange, Courage, Regeneration) VALUES
(700015, 'Quest Master Tempestian', 'Black Temple', 'questmarker', 0, 70, 70, 0,
    0, 7, 0, 0, 14, 1500, 1500, 0, 0,  -- Model 14 = Blood Elf
    0, 0, 0, '', 0, 3, 1, 1.14286, 1, 20, 5, 1, 100000);

-- WOTLK: Ulduar Quest Master (Model: Dwarf Shaman)
INSERT INTO creature_template (entry, name, subname, IconName, gossip_menu_id, minlevel, maxlevel, exp,
    unitflags, type, family, rank, displayid, BaseAttackTime, RangeAttackTime, unitflags2, dynamicflags,
    lootid, pickpocketloot, skinloot, AIName, MovementType, InhabitType, speed_walk, speed_run,
    scale, detection_range, CallForHelpRange, Courage, Regeneration) VALUES
(700031, 'Quest Master Brann', 'Ulduar', 'questmarker', 0, 80, 80, 0,
    0, 7, 0, 0, 9, 1500, 1500, 0, 0,  -- Model 9 = Dwarf Shaman
    0, 0, 0, '', 0, 3, 1, 1.14286, 1, 20, 5, 1, 100000);

-- [REPEAT FOR ALL 53 NPCS - entries 700000-700052]
-- Generate from CSV file with dungeon -> model mapping
```

---

### Step 2: Creature Spawns from game_tele References

**File**: `Custom\Custom feature SQLs\DC_DUNGEON_QUEST_CREATURES.sql` (continuation)

**Method**: Use game_tele table as coordinate reference, spawn NPCs outside dungeon entrance

```sql
-- ============================================================================
-- DC DUNGEON QUEST NPCS - CREATURE SPAWNS (Using game_tele coordinates)
-- ============================================================================

-- TIER 1 SPAWNS

-- Blackrock Depths entrance (reference: game_tele entry 100)
-- Original: position_x: -7179.34, position_y: -921.212, position_z: 165.821, map: 0
-- Adjustment: Move 10 units forward from entrance
INSERT INTO creature (guid, id, map, spawnMask, position_x, position_y, position_z, orientation, spawntimesecs, 
    wander_distance, currentwaypoint, curhealth, curmana, MovementType, npcflag, unit_flags, dynamicflags, phase) VALUES
((SELECT MAX(guid)+1 FROM creature), 700000, 0, 1, -7169.34, -911.212, 166.5, 1.57, 300, 0, 0, 1, 0, 0, 3, 0, 0, 1);

-- Scarlet Monastery entrance (reference: game_tele entry 814)
-- Original: position_x: 2872.6, position_y: -764.398, position_z: 160.332, map: 0
-- Adjustment: Move 10 units left of entrance
INSERT INTO creature (guid, id, map, spawnMask, position_x, position_y, position_z, orientation, spawntimesecs,
    wander_distance, currentwaypoint, curhealth, curmana, MovementType, npcflag, unit_flags, dynamicflags, phase) VALUES
((SELECT MAX(guid)+1 FROM creature), 700001, 0, 1, 2862.6, -774.398, 160.5, 1.57, 300, 0, 0, 1, 0, 0, 3, 0, 0, 1);

-- Karazhan entrance (reference: game_tele entry 531)
-- Original: position_x: -11118.9, position_y: -2010.33, position_z: 47.0819, map: 0
-- Adjustment: Move 15 units from entrance
INSERT INTO creature (guid, id, map, spawnMask, position_x, position_y, position_z, orientation, spawntimesecs,
    wander_distance, currentwaypoint, curhealth, curmana, MovementType, npcflag, unit_flags, dynamicflags, phase) VALUES
((SELECT MAX(guid)+1 FROM creature), 700015, 0, 1, -11103.9, -2010.33, 48.0, 3.14, 300, 0, 0, 1, 0, 0, 3, 0, 0, 1);

-- Ulduar entrance (reference: game_tele entry 1406)
-- Original: position_x: 9214.63, position_y: -1110.82, position_z: 1216.12, map: 571
-- Adjustment: Move 15 units from entrance
INSERT INTO creature (guid, id, map, spawnMask, position_x, position_y, position_z, orientation, spawntimesecs,
    wander_distance, currentwaypoint, curhealth, curmana, MovementType, npcflag, unit_flags, dynamicflags, phase) VALUES
((SELECT MAX(guid)+1 FROM creature), 700031, 571, 1, 9229.63, -1110.82, 1217.0, 3.14, 300, 0, 0, 1, 0, 0, 3, 0, 0, 1);

-- [REPEAT FOR ALL 53 NPCs]
-- SCRIPT: Auto-generate from dc_dungeons_coordinates.csv with game_tele references
```

**Coordinate Mapping CSV** (`Custom\CSV DBC\dc_dungeons_game_tele_reference.csv`):
```csv
npc_entry,dungeon_name,game_tele_id,tele_x,tele_y,tele_z,map_id,npc_offset_x,npc_offset_y,model_id
700000,Blackrock Depths,100,-7179.34,-921.212,165.821,0,10,0,1
700001,Scarlet Monastery,814,2872.6,-764.398,160.332,0,-10,0,4
700002,Zul'Farrak,XXXX,X,X,X,1,10,0,8
700015,Black Temple,XXXX,X,X,X,530,10,0,14
700031,Ulduar,1406,9214.63,-1110.82,1216.12,571,15,0,9
```

---

### Step 3: Grant Quest Giver Flags

```sql
-- Enable quest giver flags on creature_template
UPDATE creature_template SET npcflag = npcflag | 2 WHERE entry >= 90001 AND entry <= 90999;

-- Alternative: specific flag updates
UPDATE creature_template SET npcflag = 3 WHERE entry = 90001;  -- gossip + quest giver
```

---

## SECTION 3: DAILY QUEST SYSTEM (Token-Based Rewards)

### Token Configuration System

**File**: `Custom\Custom feature SQLs\DC_DUNGEON_QUEST_CONFIG.sql`

```sql
-- ============================================================================
-- TOKEN CONFIGURATION FOR DAILY/WEEKLY REWARDS
-- ============================================================================

CREATE TABLE `dc_quest_reward_tokens` (
  `token_id` INT PRIMARY KEY,
  `token_name` VARCHAR(255) NOT NULL UNIQUE,
  `description` VARCHAR(500),
  `item_id` INT NOT NULL,  -- Item ID from item_template (e.g., 700001, 700002, etc.)
  `is_active` TINYINT(1) DEFAULT 1,
  `created_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dc_quest_reward_tokens (token_id, token_name, description, item_id, is_active) VALUES
(1, 'Dungeon Explorer Token', 'Earned from daily dungeon quests', 700001, 1),
(2, 'Expansion Specialist Token', 'Earned from weekly expansion quests', 700002, 1),
(3, 'Legendary Quest Token', 'High-tier reward token', 700003, 1),
(4, 'Challenge Master Token', 'Earned from difficult quests', 700004, 1),
(5, 'Speed Runner Token', 'Earned from time-based challenges', 700005, 1);

CREATE TABLE `dc_daily_quest_token_rewards` (
  `daily_quest_id` INT PRIMARY KEY,
  `token_id_1` INT,
  `token_count_1` INT DEFAULT 1,
  `token_id_2` INT,
  `token_count_2` INT DEFAULT 0,
  `gold_reward` INT DEFAULT 0,
  `xp_reward` INT DEFAULT 0,
  FOREIGN KEY (`token_id_1`) REFERENCES `dc_quest_reward_tokens`(`token_id`),
  FOREIGN KEY (`token_id_2`) REFERENCES `dc_quest_reward_tokens`(`token_id`)
);
```

### Daily Quest Tiers (Token-Based)

#### **Daily Tier 1: Explorer (Easy) - Repeats at Midnight**

**Quest 1: "Explorer's Challenge"** (Quest ID: 700101)
```
Objective: Visit 3 different Tier-1 dungeon quest masters
Token Rewards: 1x Dungeon Explorer Token (configurable)
Gold: 1,000 gold (configurable)
XP: 10,000 (configurable)
Achievement Credit: Yes (counts toward totals)
Repeatable: Daily (resets at midnight server time)
Difficulty: Easy (just visit NPCs)
```

#### **Daily Tier 2: Specialist (Medium) - Repeats Daily**

**Quest 2: "Focused Exploration"** (Quest ID: 700102)
```
Objective: Complete 5 quests from the SAME dungeon today
Token Rewards: 2x Dungeon Explorer Token + 1x Expansion Specialist Token
Gold: 2,000 gold
XP: 25,000
Achievement Credit: Yes
Repeatable: Daily
Challenge: Must focus on one dungeon
```

**Quest 3: "Quick Runner"** (Quest ID: 700103)
```
Objective: Complete 10 different quests (any dungeons)
Token Rewards: 3x Dungeon Explorer Token
Gold: 3,000 gold
XP: 50,000
Bonus Effect: 25% XP buff for 1 hour after completion (from quest reward)
Achievement Credit: Yes
Repeatable: Daily
Difficulty: Hard (time-gated)
```

#### **Daily Tier 3: Challenge (Hard) - Repeats Daily**

**Quest 4: "Dungeon Master's Gauntlet"** (Quest ID: 700104)
```
Objective: Complete 20 different quests in 24 hours (any dungeons)
Token Rewards: 5x Dungeon Explorer Token + 2x Challenge Master Token
Gold: 5,000 gold
XP: 100,000
Special Reward: +50% XP buff for 2 hours
Achievement Credit: Yes (special achievement)
Repeatable: Daily
Difficulty: Very Hard
Time Limit: Strict 24-hour window
```

**Configuration Example**:
```sql
INSERT INTO dc_daily_quest_token_rewards (daily_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(1, 1, 1, NULL, 0, 1000, 10000),   -- Explorer's Challenge
(2, 1, 2, 2, 1, 2000, 25000),      -- Focused Exploration
(3, 1, 3, NULL, 0, 3000, 50000),   -- Quick Runner
(4, 1, 5, 4, 2, 5000, 100000);     -- Dungeon Master's Gauntlet
```

## SECTION 4: WEEKLY QUEST SYSTEM (Token-Based)

### Weekly Quests (Reset Mondays at Midnight)

#### **Weekly Tier 1: Specialist (Medium)**

**Quest 1: "Expansion Specialist"** (Quest ID: 700201)
```
Objective: Complete ALL Tier-1 quests from ONE expansion
  - Classic: All BRD, Scarlet, Zul'Farrak (35+ quests)
  - TBC: All Black Temple, Karazhan, SSC (40+ quests)
  - WOTLK: All Ulduar, Trial, ICC (45+ quests)
Token Rewards: 10x Expansion Specialist Token + 5x Legendary Quest Token
Gold: 5,000 gold
XP: 100,000
Title: "Specialist of [Expansion]" (read from CSV achievements)
Achievement Credit: Yes (expansion mastery)
Repeatable: Weekly (once per expansion)
Duration: 7 days
Difficulty: Heroic
```

**Rotating Variations**:
- Weekly 1a: "Classic Specialist"
- Weekly 1b: "Outland Specialist"
- Weekly 1c: "Northrend Specialist"

#### **Weekly Tier 2: Speed Runner (Hard)**

**Quest 2: "Speed Runner's Trial"** (Quest ID: 700202)
```
Objective: Complete 25 dungeon quests in 7 days
Token Rewards: 8x Speed Runner Token + 3x Challenge Master Token
Gold: 4,000 gold
XP: 75,000
Achievement Credit: Yes (speed runner milestone)
Repeatable: Weekly
Duration: 7 days (Monday-Sunday)
Difficulty: Hard (pacing required)
```

#### **Weekly Tier 3: Devotion (Medium)**

**Quest 3: "Devoted Runner"** (Quest ID: 700203)
```
Objective: Complete ALL quests from any single dungeon
Token Rewards: 6x Expansion Specialist Token
Gold: 3,000 gold
XP: 50,000
Achievement Credit: Yes (counts as "all quests" achievement)
Repeatable: Weekly (can do different dungeon each week)
Duration: 7 days
Rotation: Quest changes each week (Monday shows different dungeon)
```

**Rotating Schedule** (loops through all 53 dungeons):
```
Week 1: Blackrock Depths (all 15 quests)
Week 2: Scarlet Monastery (all 12 quests)
Week 3: Zul'Farrak (all 9 quests)
Week 4: Black Temple (all 18 quests)
Week 5: Ulduar (all 20 quests)
... rotates through all 53 dungeons
```

#### **Weekly Elite: "The Collector" (Very Hard)**

**Quest 4: "The Collector's Obsession"** (Quest ID: 700204)
```
Objective: Complete 50 dungeon quests (any combination)
Token Rewards: 15x Legendary Quest Token + 10x Challenge Master Token
Gold: 10,000 gold
XP: 150,000
Special Reward: 
  - First completion ever: Unique Mount (from CSV achievements)
  - Subsequent weeks: Achievement points
Title: "The Collector" (from CSV)
Achievement Credit: Yes (major milestone)
Repeatable: Weekly
Duration: 7 days
Difficulty: Very Challenging
Hidden: Until player completes 100 total quests
```

**Configuration Example**:
```sql
INSERT INTO dc_weekly_quest_token_rewards (weekly_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(1, 2, 10, 3, 5, 5000, 100000),   -- Expansion Specialist
(2, 5, 8, 4, 3, 4000, 75000),     -- Speed Runner's Trial
(3, 2, 6, NULL, 0, 3000, 50000),  -- Devoted Runner
(4, 3, 15, 4, 10, 10000, 150000); -- The Collector's Obsession
```

---

## SECTION 5: DATABASE SCHEMA FOR DAILY/WEEKLY & TOKEN CONFIGURATION

```sql
-- ============================================================================
-- DAILY QUEST TRACKING
-- ============================================================================

CREATE TABLE `dc_daily_quest_definitions` (
  `daily_quest_id` INT UNSIGNED PRIMARY KEY,
  `quest_id` INT UNSIGNED NOT NULL,
  `quest_name` VARCHAR(255) NOT NULL,
  `tier` TINYINT DEFAULT 1,
  `required_count` INT,
  `prestige_reward` INT,
  `gold_reward` INT,
  `xp_reward` INT,
  `is_active` TINYINT(1) DEFAULT 1,
  UNIQUE KEY (`quest_name`)
);

CREATE TABLE `player_daily_quest_progress` (
  `player_guid` INT UNSIGNED NOT NULL,
  `daily_quest_id` INT UNSIGNED NOT NULL,
  `progress_count` INT DEFAULT 0,
  `completed_today` TINYINT(1) DEFAULT 0,
  `last_reset_date` DATE DEFAULT CURRENT_DATE,
  `reward_claimed` TINYINT(1) DEFAULT 0,
  PRIMARY KEY (`player_guid`, `daily_quest_id`),
  FOREIGN KEY (`player_guid`) REFERENCES `characters`(`guid`)
);

-- ============================================================================
-- WEEKLY QUEST TRACKING
-- ============================================================================

CREATE TABLE `dc_weekly_quest_definitions` (
  `weekly_quest_id` INT UNSIGNED PRIMARY KEY,
  `quest_id` INT UNSIGNED NOT NULL,
  `quest_name` VARCHAR(255) NOT NULL,
  `tier` TINYINT DEFAULT 1,
  `required_count` INT,
  `prestige_reward` INT,
  `gold_reward` INT,
  `xp_reward` INT,
  `title_reward` VARCHAR(255),
  `is_active` TINYINT(1) DEFAULT 1,
  `is_rotating` TINYINT(1) DEFAULT 0,
  `rotation_week` TINYINT DEFAULT 0,
  UNIQUE KEY (`quest_name`)
);

CREATE TABLE `player_weekly_quest_progress` (
  `player_guid` INT UNSIGNED NOT NULL,
  `weekly_quest_id` INT UNSIGNED NOT NULL,
  `progress_count` INT DEFAULT 0,
  `completed_this_week` TINYINT(1) DEFAULT 0,
  `last_reset_date` DATE DEFAULT CURRENT_DATE,
  `reward_claimed` TINYINT(1) DEFAULT 0,
  PRIMARY KEY (`player_guid`, `weekly_quest_id`),
  FOREIGN KEY (`player_guid`) REFERENCES `characters`(`guid`)
);
```

---

## SECTION 5B: CSV-BASED ACHIEVEMENTS & TITLES SYSTEM

Instead of hardcoding achievements, read from CSV files:

**File**: `Custom\CSV DBC\dc_achievements.csv`
```csv
achievement_id,achievement_name,description,category,points,reward_item_id,reward_title
700001,Dungeon Explorer,Complete your first dungeon quest,General,5,0,
700050,The Completionist,Complete all quests from 5 dungeons,General,50,0,
700100,Expansion Master - Classic,Complete all Classic dungeon quests,Expansion,100,700050,Master of Classic
700101,Expansion Master - TBC,Complete all TBC dungeon quests,Expansion,100,700051,Master of Outlands
700102,Expansion Master - WOTLK,Complete all WOTLK dungeon quests,Expansion,100,700052,Master of Northrend
700200,Legendary Quester,Complete 500 dungeon quests,Challenge,200,700053,Legendary
700300,Speed Demon,Complete 25 quests in one week,Challenge,75,0,
700400,The Collector,Complete 50 quests in one week,Challenge,100,700054,The Collector
```

**File**: `Custom\CSV DBC\dc_titles.csv`
```csv
title_id,title_name,male_name,female_name,category
1000,Dungeon Master,Dungeon Master,Dungeon Master,Prestige
1001,Master of Classic,Master of Classic,Master of Classic,Expansion
1002,Master of Outlands,Master of Outlands,Master of Outlands,Expansion
1003,Master of Northrend,Master of Northrend,Master of Northrend,Expansion
1004,The Collector,the Collector,the Collector,Achievement
1005,Legendary,Legendary,Legendary,Achievement
```

**File**: `Custom\CSV DBC\dc_items_tokens.csv` (Token Item Definitions)
```csv
item_id,item_name,item_display_id,item_class,item_subclass,quality,sellprice,buyprice,description
700001,Dungeon Explorer Token,12345,15,0,3,500,0,Earned from daily dungeon quests
700002,Expansion Specialist Token,12346,15,0,4,1000,0,Earned from weekly expansion quests
700003,Legendary Quest Token,12347,15,0,5,2000,0,High-tier reward token
700004,Challenge Master Token,12348,15,0,4,1500,0,Earned from difficult quest challenges
700005,Speed Runner Token,12349,15,0,3,750,0,Earned from time-based challenges
```

**C++ Implementation** (Read CSV at startup):
```cpp
class TokenConfigManager
{
public:
    static void LoadTokensFromCSV(std::string csv_path)
    {
        // Read dc_quest_reward_tokens.csv
        // Populate token_map with token_id -> TokenData
        // Cache in memory for fast access
    }
    
    static void LoadAchievementsFromCSV(std::string csv_path)
    {
        // Read dc_achievements.csv
        // Populate achievement_map with achievement_id -> AchievementData
        // Cache titles and rewards
    }
    
    static TokenData* GetToken(uint32 token_id)
    {
        return token_map[token_id];  // O(1) lookup
    }
};
```

---

## SECTION 6: FILE ORGANIZATION (DC-255 STANDARD) - UPDATED

### Folder Structure

```
Custom/
├── Custom feature SQLs/
│   ├── DC_DUNGEON_QUEST_SCHEMA.sql
│   │   └── Creates all 13 base tables + token/config tables
│   │
│   ├── DC_DUNGEON_QUEST_CONFIG.sql (NEW)
│   │   ├── Token configuration
│   │   ├── Daily/weekly reward mappings
│   │   └── NPC model & game_tele mappings
│   │
│   ├── DC_DUNGEON_QUEST_CREATURES.sql
│   │   ├── creature_template entries (53 NPCs, IDs 700000-700052)
│   │   ├── creature spawns with game_tele references
│   │   ├── Dungeon-fitting models per NPC
│   │   └── npcflag updates
│   │
│   ├── DC_DUNGEON_QUEST_NPCS_TIER1.sql
│   │   ├── 11 Tier-1 NPC entries
│   │   └── 480+ quest mappings (IDs 700101-700600)
│   │
│   ├── DC_DUNGEON_QUEST_NPCS_TIER2.sql
│   │   ├── 16 Tier-2 NPC entries
│   │   └── ~150 quest mappings
│   │
│   ├── DC_DUNGEON_QUEST_NPCS_TIER3.sql
│   │   ├── 26 Tier-3 NPC entries
│   │   └── ~80 quest mappings
│   │
│   ├── DC_DUNGEON_QUEST_ACHIEVEMENTS.sql (DEPRECATED - USE CSV)
│   │   └── Legacy file for reference only
│   │   └── Achievements now loaded from dc_achievements.csv
│   │
│   └── DC_DUNGEON_QUEST_DAILY_WEEKLY.sql
│       ├── Daily quest definitions (IDs 700101-700104)
│       ├── Weekly quest definitions (IDs 700201-700204)
│       └── Initial progress table population
│
├── CSV DBC/ (NEW - CSV-Based Configuration)
│   ├── dc_dungeons_game_tele_reference.csv
│   │   ├── Dungeon coordinates from game_tele
│   │   ├── NPC model assignments
│   │   └── Spawn offsets for positioning
│   │
│   ├── dc_achievements.csv
│   │   └── All achievement definitions (read by C++ at startup)
│   │
│   ├── dc_titles.csv
│   │   └── All title definitions
│   │
│   ├── dc_items_tokens.csv
│   │   └── Token item definitions
│   │
│   ├── dungeons_dc.csv
│   │   └── All 54 dungeons (name, id, zone, expansion)
│   │
│   ├── quests_dc.csv
│   │   └── Quest info (id, name, level, rewards)
│   │
│   ├── creature_names_dc.csv
│   │   └── Creature entries (id, name, subname)
│   │
│   └── zones_dc.csv
│       └── Zone/map reference
│
└── modules/  
    └── DungeonQuests/
        ├── CMakeLists.txt
        └── DungeonQuests.cpp (module loader)

src/server/scripts/DC/
└── DungeonQuests/
    ├── CMakeLists.txt
    ├── npc_dungeon_quest_master.cpp
    ├── npc_dungeon_quest_daily_weekly.cpp
    ├── npc_quest_config_loader.cpp (NEW - Loads CSV files)
    └── dc_dungeon_quest_loader.cpp
```

---

## SECTION 7: SQL FILES CONTENT BREAKDOWN (UPDATED)

### File 1: DC_DUNGEON_QUEST_SCHEMA.sql
**Creates**: 13 base tables + token/config tables
- dungeon_quest_npc
- dungeon_quest_mapping
- dungeon_quest_achievements (DEPRECATED - use CSV)
- player_dungeon_quest_progress
- player_dungeon_achievements (DEPRECATED - use CSV)
- dc_quest_reward_tokens (NEW)
- dc_daily_quest_token_rewards (NEW)
- dc_weekly_quest_token_rewards (NEW)
- player_daily_quest_progress
- player_weekly_quest_progress
- And 4 more tracking tables

**Size**: ~15-20 KB

---

### File 2: DC_DUNGEON_QUEST_CONFIG.sql (NEW)
**Creates**: Configuration & mapping tables
- dc_quest_reward_tokens (token definitions)
- dc_daily_quest_token_rewards (daily quest -> token mappings)
- dc_weekly_quest_token_rewards (weekly quest -> token mappings)
- dc_npc_model_mappings (NPC entry -> model ID + game_tele reference)

**Size**: ~5-8 KB

---

### File 3: DC_DUNGEON_QUEST_CREATURES.sql
**Creates**: creature_template & creature entries
- 53 creature_template entries (IDs 700000-700052)
  - Each with appropriate dungeon-fitting model
  - Gossip + quest giver flags
  - Proper scaling and display
- 53 creature spawns
  - Coordinates from game_tele references (adjusted manually)
  - Proper map/zone assignments
  - Phase assignments

**Size**: ~20-30 KB

**Example Models**:
```sql
Model 1 = Dwarf (Blackrock Depths, etc.)
Model 4 = Human Priest (Scarlet Monastery, etc.)
Model 8 = Troll (Zul'Farrak, Zul'Aman)
Model 9 = Dwarf Shaman (Ulduar)
Model 14 = Blood Elf (Black Temple, Karazhan)
Model 10 = Undead (ICC, Pit of Saron)
```

---

### File 4: DC_DUNGEON_QUEST_NPCS_TIER1.sql
**Creates**: Tier 1 dungeon entries
- 11 dungeon_quest_npc entries (IDs 700000-700010)
- 480+ dungeon_quest_mapping entries
  - Quest IDs: 700101-700600
  - References to quest_template
  - Reward flags and multipliers

**Size**: ~25-35 KB

---

### File 5: DC_DUNGEON_QUEST_NPCS_TIER2.sql
**Creates**: Tier 2 dungeon entries
- 16 dungeon_quest_npc entries (IDs 700011-700026)
- ~150 dungeon_quest_mapping entries

**Size**: ~15-20 KB

---

### File 6: DC_DUNGEON_QUEST_NPCS_TIER3.sql
**Creates**: Tier 3 dungeon entries
- 26 dungeon_quest_npc entries (IDs 700027-700052)
- ~80 dungeon_quest_mapping entries

**Size**: ~10-15 KB

---

### File 7: DC_DUNGEON_QUEST_DAILY_WEEKLY.sql
**Creates**: Daily/Weekly quests (IDs 700101-700104 for daily, 700201-700204 for weekly)
- 4 daily quest definitions
- 4 weekly quest definitions
- Token reward mappings (from dc_daily_quest_token_rewards)

**Size**: ~10-15 KB

---

### Files 8-13: CSV Reference Files (Custom\CSV DBC\)

**dc_dungeons_game_tele_reference.csv**
```csv
npc_entry,dungeon_name,tier,game_tele_id,tele_x,tele_y,tele_z,map_id,model_id,npc_offset_x,npc_offset_y,manual_adjust_note
700000,Blackrock Depths,1,100,-7179.34,-921.212,165.821,0,1,10,0,Check entrance
700001,Scarlet Monastery,1,814,2872.6,-764.398,160.332,0,4,-10,0,Left side of door
...
```

**dc_achievements.csv**
```csv
achievement_id,achievement_name,description,category,points,reward_item_id,reward_title_id,reward_mount_id
700001,Dungeon Explorer,Complete your first dungeon quest,General,5,0,0,0
...
```

**dc_titles.csv**
```csv
title_id,title_name,male_name,female_name
1000,Master of Outlands,Master of Outlands,Master of Outlands
...
```

**dc_items_tokens.csv**
```csv
item_id,item_name,item_display_id,quality,sellprice,description
700001,Dungeon Explorer Token,12345,3,500,Earned from daily quests
...
```

---

## SECTION 8: CSV/DBC FILES NEEDED (UPDATED)

### Which Files Need to Be Created?

**Check `Custom\CSV DBC\` for**:

- [ ] **dc_dungeons_game_tele_reference.csv** (NEW - CRITICAL)
  - Maps each dungeon to game_tele entry
  - Provides base coordinates for NPC spawning
  - Specifies NPC model per dungeon type
  - Includes manual adjustment notes
  - **IF MISSING**: Must create by querying game_tele table

- [ ] **dc_achievements.csv** (NEW - CRITICAL)
  - Achievement definitions (replaces SQL hardcoding)
  - Read at server startup by C++ script
  - Includes reward item IDs and titles
  - **IF MISSING**: Must create with 50+ achievement definitions

- [ ] **dc_titles.csv** (NEW - CRITICAL)
  - Title definitions for achievement rewards
  - Male/female names per title
  - **IF MISSING**: Must create with 10-15 titles

- [ ] **dc_items_tokens.csv** (NEW - CRITICAL)
  - Token item definitions
  - Item display IDs, quality, sell prices
  - **IF MISSING**: Must create 5 token entries

- [ ] **dungeons_dc.csv** (REFERENCE)
  - List of all 54 dungeons
  - Zone IDs, map IDs, expansion
  - **IF EXISTS**: Verify content and format
  - **IF MISSING**: Can generate from quest_template + manual mapping

- [ ] **quests_dc.csv** (REFERENCE)
  - Quest reference information
  - **IF EXISTS**: Verify 630+ quests included
  - **IF MISSING**: Can extract from quest_template

- [ ] **creature_names_dc.csv** (REFERENCE)
  - NPC/creature name reference
  - **IF MISSING**: Generate from creature_template

- [ ] **zones_dc.csv** (REFERENCE)
  - Zone/map reference data
  - **IF MISSING**: Generate from area_table

---

## SECTION 9: C++ SCRIPT STRUCTURE (UPDATED)

### File 1: npc_dungeon_quest_master.cpp

**Location**: `src\server\scripts\DC\DungeonQuests\npc_dungeon_quest_master.cpp`

**Purpose**: Main quest giver script with gossip handling

**Key Features**:
- Load quests from dungeon_quest_mapping
- Handle quest acceptance
- Award tokens on quest completion
- Check daily/weekly quest progress
- Integrate with TokenConfigManager
- No prestige logic (tokens only)

```cpp
#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "ScriptedGossip.h"
#include "TokenConfigManager.h"

class npc_dungeon_quest_master : public CreatureScript
{
public:
    npc_dungeon_quest_master() : CreatureScript("npc_dungeon_quest_master") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Load quests for this NPC/dungeon
        // Display quest menu
        // Show token rewards
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        // Accept quest
        // Track in daily/weekly progress
        // Award token (if milestone reached)
    }
};
```

---

### File 2: npc_quest_config_loader.cpp (NEW)

**Location**: `src\server\scripts\DC\DungeonQuests\npc_quest_config_loader.cpp`

**Purpose**: Load CSV files at startup

```cpp
#include "ScriptMgr.h"
#include "TokenConfigManager.h"

class ScriptedAI_Config : public ScriptMgr
{
public:
    void OnConfigLoad(bool reload) override
    {
        if (reload)
        {
            LOG_INFO("module", "DC DungeonQuests: Reloading CSV configurations...");
        }
        else
        {
            LOG_INFO("module", "DC DungeonQuests: Loading CSV configurations...");
        }
        
        // Load tokens from CSV
        TokenConfigManager::LoadTokensFromCSV("Custom/CSV DBC/dc_items_tokens.csv");
        
        // Load achievements from CSV
        TokenConfigManager::LoadAchievementsFromCSV("Custom/CSV DBC/dc_achievements.csv");
        
        // Load titles from CSV
        TokenConfigManager::LoadTitlesFromCSV("Custom/CSV DBC/dc_titles.csv");
        
        // Load dungeon/game_tele mappings
        TokenConfigManager::LoadGameTeleReferences("Custom/CSV DBC/dc_dungeons_game_tele_reference.csv");
        
        LOG_INFO("module", "DC DungeonQuests: All configurations loaded successfully!");
    }
};
```

---

### File 3: npc_dungeon_quest_daily_weekly.cpp

**Location**: `src\server\scripts\DC\DungeonQuests\npc_dungeon_quest_daily_weekly.cpp`

**Purpose**: Daily/weekly quest tracking and reset

```cpp
class PlayerScript_DungeonQuestDaily : public PlayerScript
{
public:
    PlayerScript_DungeonQuestDaily() : PlayerScript("PlayerScript_DungeonQuestDaily") { }

    void OnLogin(Player* player) override
    {
        // Check daily reset (midnight)
        // Reset daily quest progress
        // Check weekly reset (Monday)
        // Reset weekly quest progress
    }

    void OnQuestComplete(Player* player, Quest const* quest) override
    {
        uint32 questId = quest->GetQuestId();
        
        // If quest is a dungeon quest (700101-700999)
        if (questId >= 700101 && questId <= 700999)
        {
            // Track completion
            // Update daily/weekly progress
            // Check for milestone completions
            // Award tokens if milestone reached
            
            // Get token rewards from TokenConfigManager
            // Add to player inventory
        }
    }
};
```

---

### File 4: TokenConfigManager.h (NEW)

**Purpose**: Manage token and configuration loading from CSV

```cpp
#pragma once

struct TokenData
{
    uint32 token_id;
    std::string token_name;
    uint32 item_id;
    uint32 quantity;
};

struct AchievementData
{
    uint32 achievement_id;
    std::string achievement_name;
    uint32 reward_item_id;
    uint32 reward_title_id;
    uint32 reward_mount_id;
};

class TokenConfigManager
{
public:
    static void LoadTokensFromCSV(const std::string& path);
    static void LoadAchievementsFromCSV(const std::string& path);
    static void LoadTitlesFromCSV(const std::string& path);
    static void LoadGameTeleReferences(const std::string& path);
    
    static TokenData* GetToken(uint32 token_id);
    static AchievementData* GetAchievement(uint32 achievement_id);
    static std::string GetTitle(uint32 title_id, bool isMale);
    
private:
    static std::map<uint32, TokenData> token_cache;
    static std::map<uint32, AchievementData> achievement_cache;
    static std::map<uint32, std::string> title_cache;
};
```

---

## SECTION 10: IMPLEMENTATION SEQUENCE (UPDATED)

### Phase 1: Configuration & Setup (3-4 hours)

```
Step 1: Create DC_DUNGEON_QUEST_SCHEMA.sql + DC_DUNGEON_QUEST_CONFIG.sql
        └─ Deploy to database
        └─ Verify all token/reward tables created

Step 2: Create CSV files (dc_achievements.csv, dc_titles.csv, dc_items_tokens.csv)
        ├─ Define 50+ achievements
        ├─ Define 10-15 titles
        ├─ Define 5 tokens
        └─ Place in Custom\CSV DBC\

Step 3: Create dc_dungeons_game_tele_reference.csv
        ├─ Query game_tele table for dungeon coordinates
        ├─ Map dungeon-fitting models
        ├─ Calculate spawn offsets
        └─ Place in Custom\CSV DBC\

Step 4: Implement TokenConfigManager C++ class
        ├─ CSV loading functions
        ├─ Caching system
        └─ Compile & test
```

---

### Phase 2: NPC Spawning (1-2 hours)

```
Step 1: Create DC_DUNGEON_QUEST_CREATURES.sql
        ├─ 53 creature_template entries (700000-700052)
        ├─ Dungeon-fitting models
        ├─ 53 creature spawns from game_tele coordinates
        └─ Deploy to database

Step 2: Test in-game
        ├─ Verify 53 NPCs spawn at dungeons
        ├─ Check models are correct
        ├─ Verify positioning looks natural
        └─ Manually adjust coordinates if needed
```

---

### Phase 3: Quest Mapping (1 hour)

```
Step 1: Create DC_DUNGEON_QUEST_NPCS_TIER1.sql
        ├─ 11 dungeon_quest_npc entries
        ├─ 480+ dungeon_quest_mapping entries
        └─ Deploy to database

Step 2: Test quest menu
        ├─ Verify quests appear in NPC gossip
        ├─ Check quest rewards are correct
        └─ Verify quest IDs in 700000+ range
```

---

### Phase 4: Daily/Weekly System (2-3 hours)

```
Step 1: Create DC_DUNGEON_QUEST_DAILY_WEEKLY.sql
        ├─ 4 daily quest definitions
        ├─ 4 weekly quest definitions
        └─ Deploy to database

Step 2: Implement C++ scripts
        ├─ npc_quest_config_loader.cpp
        ├─ npc_dungeon_quest_master.cpp
        ├─ npc_dungeon_quest_daily_weekly.cpp
        └─ TokenConfigManager implementation

Step 3: Test daily/weekly mechanics
        ├─ Quest resets at correct times
        ├─ Token rewards awarded correctly
        ├─ Progress tracking accurate
        └─ CSV loading working properly
```

---

### Phase 5: Full Testing (2-3 hours)

```
Step 1: Compile all C++ code
Step 2: Deploy all SQL files (in order)
Step 3: Restart server with CSV loading
Step 4: In-game testing
        ├─ Visit all NPC locations
        ├─ Accept daily quests
        ├─ Accept weekly quests
        ├─ Complete quests and verify tokens
        ├─ Check reset mechanics
        └─ Verify achievements unlock
```

---

## SECTION 11: QUICK REFERENCE - ID RANGES

| Component | Start ID | End ID | Count | Type |
|-----------|----------|--------|-------|------|
| NPCs (creature_template) | 700000 | 700052 | 53 | Creatures |
| Daily Quests | 700101 | 700104 | 4 | Quests |
| Weekly Quests | 700201 | 700204 | 4 | Quests |
| Dungeon Quests (Tier 1-3) | 700701 | 700999 | 630+ | Quests |
| Tokens (Items) | 700001 | 700005 | 5 | Items |
| Achievements | 700001 | 700400 | 50+ | Achievements |
| Titles | 1000 | 1015 | 10-15 | Titles |
| Game_Tele Reference | 100+ | 2000+ | Auto | Reference |

---

## SECTION 12: SUMMARY TABLE (UPDATED)

---

## NEXT STEPS

1. ✅ Review this document for approval
2. ✅ Generate DC_DUNGEON_QUEST_CREATURES.sql with all 53 NPCs
3. ✅ Generate DC_DUNGEON_QUEST_NPCS_*.sql files with quest mappings
4. ✅ Create C++ script templates
5. ✅ Deploy Phase 1 to test server
6. ✅ Validate NPC spawning
7. ✅ Deploy Phase 2 (quests & achievements)
8. ✅ Implement daily/weekly scripts
9. ✅ Full testing & validation
10. ✅ Live deployment

---

## SECTION 13: TESTING CHECKLIST (UPDATED)

### CSV Loading Tests

- [ ] TokenConfigManager loads dc_items_tokens.csv
- [ ] TokenConfigManager loads dc_achievements.csv
- [ ] TokenConfigManager loads dc_titles.csv
- [ ] Game_tele references load correctly
- [ ] Cache hit rate > 99.9%
- [ ] No CSV parsing errors in logs

### Functional Testing

- [ ] 53 NPCs spawn at correct locations
- [ ] NPC models match dungeon themes
- [ ] Quest menu shows correct quests
- [ ] Quest acceptance works properly
- [ ] Tokens awarded on milestone completion
- [ ] Token inventory shows correct item IDs
- [ ] Daily quest resets at midnight
- [ ] Weekly quest resets on Monday
- [ ] Progress tracking accurate
- [ ] Achievement unlock triggers from CSV
- [ ] Titles awarded from CSV

### Performance Testing

- [ ] No server lag with all NPCs active
- [ ] CSV loading takes < 1 second
- [ ] Database queries optimized (< 5ms per query)
- [ ] No memory leaks in scripts
- [ ] CPU usage < 0.5% while idle
- [ ] Cache memory footprint < 50 MB

---

## SECTION 14: KEY CHANGES FROM v1.0 → v2.0

| Aspect | v1.0 | v2.0 | Change |
|--------|------|------|--------|
| **NPC ID Range** | 90001-90053 | 700000-700052 | Custom range |
| **Quest ID Range** | 90101-90999 | 700101-700999 | Custom range |
| **Reward System** | Prestige Points | Configurable Tokens | Flexible rewards |
| **Achievement Storage** | SQL Inserts | CSV Files | Dynamic loading |
| **Title Storage** | Hardcoded | CSV Files | Configurable |
| **NPC Models** | Generic | Dungeon-Fitting | Thematic |
| **Spawn Location** | Manual | game_tele-based | Reference-based |
| **Config Loading** | Static | CSV + Dynamic | Runtime loading |
| **Prestige Integration** | Yes | No | Removed |
| **Token Config** | None | Full System | New |

---

## NEXT STEPS

1. ✅ Review v2.0 document for approval
2. ✅ Create CSV files (achievements, titles, tokens)
3. ✅ Create dc_dungeons_game_tele_reference.csv
4. ✅ Generate DC_DUNGEON_QUEST_CREATURES.sql with models
5. ✅ Implement TokenConfigManager class
6. ✅ Implement CSV loading scripts
7. ✅ Deploy Phase 1 to test server
8. ✅ Validate NPC spawning & models
9. ✅ Deploy Phase 2 (quests & tokens)
10. ✅ Full testing & validation
11. ✅ Live deployment

---

**Status**: Updated for v2.0 (Custom IDs, Token System, CSV-Based Config)  
**Recommendation**: Hybrid Approach (use standard creature system + game_tele references)  
**Risk Level**: LOW (standard systems, minimal custom code)  
**Complexity**: MEDIUM (multiple SQL files, 3-4 C++ scripts, CSV integration)  
**Token System**: FULLY CONFIGURABLE (no hardcoding, all values in CSV/SQL)

