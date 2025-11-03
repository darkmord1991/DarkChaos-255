# DC-255 DUNGEON QUEST NPC SYSTEM - IMPLEMENTATION CHECKLIST v2.0
## Quick Start Guide

**Updated**: November 2, 2025  
**Key Focus**: Custom IDs (700000+), Token System, CSV-Based Config

---

## QUICK SUMMARY OF CHANGES

### From v1.0 to v2.0:
- ✅ **ID Ranges**: 90xxx → 700xxx (custom range for DC server)
- ✅ **Rewards**: Prestige Points → Configurable Tokens
- ✅ **Models**: Generic → Dungeon-Fitting (Dwarf for BRD, Blood Elf for Black Temple, etc.)
- ✅ **Spawning**: Manual coordinates → game_tele-based references
- ✅ **Config**: Hardcoded → CSV Files (achievements, titles, items)
- ✅ **Architecture**: Static → Dynamic loading at server startup

---

## PHASE 1: FOUNDATION (3-4 HOURS)

### Step 1.1: Create SQL Schema Files

**File**: `Custom\Custom feature SQLs\DC_DUNGEON_QUEST_SCHEMA.sql`

```sql
-- 13 core tables for quest tracking
-- Include token configuration tables
-- Include daily/weekly progress tables

-- Key tables:
CREATE TABLE dc_quest_reward_tokens (
  token_id INT PRIMARY KEY,
  token_name VARCHAR(255) UNIQUE,
  item_id INT NOT NULL
);

CREATE TABLE player_daily_quest_progress (
  player_guid INT,
  daily_quest_id INT,
  progress_count INT,
  PRIMARY KEY (player_guid, daily_quest_id)
);
```

✅ **Action**: Generate this file with 13+ table definitions

---

### Step 1.2: Create CSV Configuration Files

**Location**: `Custom\CSV DBC\`

#### File A: `dc_items_tokens.csv`
```csv
item_id,item_name,item_display_id,quality,sellprice,description
700001,Dungeon Explorer Token,12345,3,500,Earned from daily quests
700002,Expansion Specialist Token,12346,4,1000,Earned from weekly quests
700003,Legendary Quest Token,12347,5,2000,High-tier reward
700004,Challenge Master Token,12348,4,1500,From difficult quests
700005,Speed Runner Token,12349,3,750,From time-based quests
```

#### File B: `dc_achievements.csv`
```csv
achievement_id,achievement_name,category,points,reward_item_id,reward_title_id
700001,Dungeon Explorer,General,5,0,0
700050,The Completionist,General,50,0,0
700100,Expansion Master - Classic,Expansion,100,700051,1001
700101,Expansion Master - TBC,Expansion,100,700052,1002
700102,Expansion Master - WOTLK,Expansion,100,700053,1003
700200,Legendary Quester,Challenge,200,700054,1005
700300,Speed Demon,Challenge,75,0,0
700400,The Collector,Challenge,100,700055,1004
```

#### File C: `dc_titles.csv`
```csv
title_id,title_name,male_name,female_name
1000,Dungeon Master,Dungeon Master,Dungeon Master
1001,Master of Classic,Master of Classic,Master of Classic
1002,Master of Outlands,Master of Outlands,Master of Outlands
1003,Master of Northrend,Master of Northrend,Master of Northrend
1004,The Collector,the Collector,the Collector
1005,Legendary,Legendary,Legendary
```

#### File D: `dc_dungeons_game_tele_reference.csv`
```csv
npc_entry,dungeon_name,tier,game_tele_id,tele_x,tele_y,tele_z,map_id,model_id,npc_offset_x,npc_offset_y,notes
700000,Blackrock Depths,1,100,-7179.34,-921.212,165.821,0,1,10,0,"Dwarf model"
700001,Scarlet Monastery,1,814,2872.6,-764.398,160.332,0,4,-10,0,"Human priest"
700015,Black Temple,2,XXXX,X,X,X,530,14,10,0,"Blood Elf model"
700031,Ulduar,3,1406,9214.63,-1110.82,1216.12,571,9,15,0,"Dwarf shaman"
```

✅ **Action**: Create 4 CSV files in `Custom\CSV DBC\`

---

### Step 1.3: Implement TokenConfigManager

**File**: `src\server\scripts\DC\DungeonQuests\TokenConfigManager.h`

```cpp
#pragma once

struct TokenData {
    uint32 token_id;
    std::string token_name;
    uint32 item_id;
};

struct AchievementData {
    uint32 achievement_id;
    std::string name;
    uint32 reward_item_id;
    uint32 reward_title_id;
};

class TokenConfigManager {
public:
    static void LoadTokensFromCSV(const std::string& path);
    static void LoadAchievementsFromCSV(const std::string& path);
    static void LoadTitlesFromCSV(const std::string& path);
    
    static TokenData* GetToken(uint32 token_id);
    static AchievementData* GetAchievement(uint32 achievement_id);
    
private:
    static std::map<uint32, TokenData> token_cache;
    static std::map<uint32, AchievementData> achievement_cache;
};
```

✅ **Action**: Create TokenConfigManager.h header file

---

### Step 1.4: Implement CSV Loader Script

**File**: `src\server\scripts\DC\DungeonQuests\npc_quest_config_loader.cpp`

```cpp
#include "ScriptMgr.h"
#include "TokenConfigManager.h"

class ScriptedAI_ConfigLoader : public ScriptMgr {
public:
    void OnConfigLoad(bool reload) override {
        LOG_INFO("module", "DC: Loading CSV configurations...");
        
        TokenConfigManager::LoadTokensFromCSV("Custom/CSV DBC/dc_items_tokens.csv");
        TokenConfigManager::LoadAchievementsFromCSV("Custom/CSV DBC/dc_achievements.csv");
        
        LOG_INFO("module", "DC: CSV configurations loaded!");
    }
};

void AddSC_npc_quest_config_loader() {
    new ScriptedAI_ConfigLoader();
}
```

✅ **Action**: Create npc_quest_config_loader.cpp

---

## PHASE 2: NPC SPAWNING (1-2 HOURS)

### Step 2.1: Generate Creature Template Entries

**File**: `Custom\Custom feature SQLs\DC_DUNGEON_QUEST_CREATURES.sql`

```sql
-- ============================================================================
-- DC DUNGEON QUEST NPCS - CREATURE TEMPLATES (IDs 700000-700052)
-- ============================================================================

-- Tier 1: Blackrock Depths (Model: Dwarf Warrior = 1)
INSERT INTO creature_template (entry, name, subname, IconName, gossip_menu_id, minlevel, maxlevel, 
    exp, unitflags, type, family, rank, displayid, BaseAttackTime, RangeAttackTime, unitflags2, 
    dynamicflags, lootid, AIName, MovementType, InhabitType, speed_walk, speed_run, scale, 
    detection_range, npcflag) VALUES
(700000, 'Quest Master Ironforge', 'Blackrock Depths', 'questmarker', 0, 60, 60, 0,
    0, 7, 0, 0, 1, 1500, 1500, 0, 0, 0, '', 0, 3, 1, 1.14286, 1, 20, 3);

-- Tier 1: Scarlet Monastery (Model: Human Priest = 4)
INSERT INTO creature_template (entry, name, subname, IconName, gossip_menu_id, minlevel, maxlevel,
    exp, unitflags, type, family, rank, displayid, BaseAttackTime, RangeAttackTime, unitflags2,
    dynamicflags, lootid, AIName, MovementType, InhabitType, speed_walk, speed_run, scale,
    detection_range, npcflag) VALUES
(700001, 'Quest Master Scarlet', 'Scarlet Monastery', 'questmarker', 0, 60, 60, 0,
    0, 7, 0, 0, 4, 1500, 1500, 0, 0, 0, '', 0, 3, 1, 1.14286, 1, 20, 3);

-- [Repeat for all 53 NPCs with appropriate models]
```

**Model Mapping**:
- Model 1: Dwarf → BRD, Ironforge zones
- Model 4: Human Priest → Scarlet Monastery
- Model 8: Troll → Zul'Farrak, Zul'Aman
- Model 9: Dwarf Shaman → Ulduar
- Model 14: Blood Elf → Black Temple, Karazhan
- Model 10: Undead → ICC, Pit of Saron

✅ **Action**: Generate DC_DUNGEON_QUEST_CREATURES.sql with all 53 entries

---

### Step 2.2: Generate Creature Spawns from game_tele

```sql
-- ============================================================================
-- DC DUNGEON QUEST NPCS - CREATURE SPAWNS (Using game_tele coordinates)
-- ============================================================================

-- Blackrock Depths entrance (game_tele entry 100)
-- Base: x=-7179.34, y=-921.212, z=165.821
-- Adjusted: x=-7169.34 (moved 10 units closer to entrance)
INSERT INTO creature (guid, id, map, spawnMask, position_x, position_y, position_z, 
    orientation, spawntimesecs, wander_distance, MovementType, npcflag, phase) VALUES
(SELECT MAX(guid)+1 FROM creature, 700000, 0, 1, -7169.34, -911.212, 166.5, 
    1.57, 300, 0, 0, 3, 1);

-- Scarlet Monastery entrance (game_tele entry 814)
-- Base: x=2872.6, y=-764.398, z=160.332
-- Adjusted: x=2862.6 (moved 10 units to the left)
INSERT INTO creature (guid, id, map, spawnMask, position_x, position_y, position_z,
    orientation, spawntimesecs, wander_distance, MovementType, npcflag, phase) VALUES
(SELECT MAX(guid)+1 FROM creature, 700001, 0, 1, 2862.6, -774.398, 160.5,
    1.57, 300, 0, 0, 3, 1);

-- [Repeat for all 53 NPCs using game_tele coordinates as base]
```

**Workflow**:
1. Query game_tele table for dungeon coordinates
2. Use CSV (dc_dungeons_game_tele_reference.csv) to map offsets
3. Adjust manually for proper positioning
4. Verify in-game

✅ **Action**: Generate creature spawn statements (Append to DC_DUNGEON_QUEST_CREATURES.sql)

---

## PHASE 3: QUEST MAPPING (1 HOUR)

### Step 3.1: Create Quest Master Entries

**File**: `Custom\Custom feature SQLs\DC_DUNGEON_QUEST_NPCS_TIER1.sql`

```sql
-- ============================================================================
-- TIER 1: QUEST MAPPINGS (11 dungeons, 480+ quests)
-- ============================================================================

-- BRD (15 quests)
INSERT INTO dungeon_quest_npc (npc_entry, dungeon_name, tier, quest_count) VALUES
(700000, 'Blackrock Depths', 1, 15);

INSERT INTO dungeon_quest_mapping (npc_entry, quest_id, quest_name) VALUES
(700000, 700701, 'Quest 1 in BRD'),
(700000, 700702, 'Quest 2 in BRD'),
...
(700000, 700715, 'Quest 15 in BRD');

-- Scarlet Monastery (12 quests)
INSERT INTO dungeon_quest_npc (npc_entry, dungeon_name, tier, quest_count) VALUES
(700001, 'Scarlet Monastery', 1, 12);

INSERT INTO dungeon_quest_mapping (npc_entry, quest_id, quest_name) VALUES
(700001, 700716, 'Quest 1 in SM'),
...
(700001, 700727, 'Quest 12 in SM');
```

✅ **Action**: Create DC_DUNGEON_QUEST_NPCS_TIER1.sql (480+ quest mappings)

---

## PHASE 4: DAILY/WEEKLY QUESTS (1-2 HOURS)

### Step 4.1: Create Daily Quest System

**File**: `Custom\Custom feature SQLs\DC_DUNGEON_QUEST_DAILY_WEEKLY.sql`

```sql
-- ============================================================================
-- DAILY QUESTS (Reset at midnight)
-- ============================================================================

-- Daily Quest 1: Explorer's Challenge (Quest ID: 700101)
INSERT INTO quest_template (id, method, level, minlevel, maxlevel, type, Flags, name, 
    description, objectives, details, endtext) VALUES
(700101, 2, 0, 1, 255, 0, 0, 'Explorer\'s Challenge',
    'Visit 3 different Tier-1 dungeon quest masters',
    'Visit 3 different quest masters',
    'Explore the dungeons and find the quest masters.',
    'Excellent! You\'ve visited the quest masters.');

-- Daily Reward Mapping
INSERT INTO dc_daily_quest_token_rewards (daily_quest_id, token_id_1, token_count_1, gold_reward, xp_reward) VALUES
(700101, 1, 1, 1000, 10000);  -- 1x Explorer Token, 1000 gold, 10k XP

-- Daily Quest 2: Focused Exploration (Quest ID: 700102)
INSERT INTO quest_template (id, method, level, minlevel, maxlevel, type, Flags, name,
    description, objectives, details, endtext) VALUES
(700102, 2, 0, 1, 255, 0, 0, 'Focused Exploration',
    'Complete 5 quests from the SAME dungeon',
    'Focus on one dungeon',
    'Choose a dungeon and complete all available quests from that location.',
    'Excellent! You\'ve mastered that dungeon!');

INSERT INTO dc_daily_quest_token_rewards (daily_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(700102, 1, 2, 2, 1, 2000, 25000);  -- 2x Explorer + 1x Specialist Token

-- [Continue for daily 3 & 4, then weekly 1-4]
```

✅ **Action**: Create DC_DUNGEON_QUEST_DAILY_WEEKLY.sql with 8 quest definitions

---

### Step 4.2: Implement Daily/Weekly Tracking

**File**: `src\server\scripts\DC\DungeonQuests\npc_dungeon_quest_daily_weekly.cpp`

```cpp
#include "ScriptMgr.h"
#include "TokenConfigManager.h"

class PlayerScript_DungeonQuestDaily : public PlayerScript {
public:
    PlayerScript_DungeonQuestDaily() : PlayerScript("PlayerScript_DungeonQuestDaily") { }

    void OnLogin(Player* player) override {
        // Check if daily reset needed (past midnight)
        // Check if weekly reset needed (past Monday)
        // Reset quest progress
    }

    void OnQuestComplete(Player* player, Quest const* quest) override {
        uint32 questId = quest->GetQuestId();
        
        // If dungeon quest (700000+ range)
        if (questId >= 700000 && questId <= 700999) {
            // Track completion
            // Check for daily/weekly milestone
            // Award tokens if reached
            
            TokenData* token = TokenConfigManager::GetToken(1);
            if (token) {
                player->AddItem(token->item_id, 1);
            }
        }
    }
};
```

✅ **Action**: Create npc_dungeon_quest_daily_weekly.cpp

---

## PHASE 5: GOSSIP & QUEST GIVER (1-2 HOURS)

### Step 5.1: Implement Main Quest Giver Script

**File**: `src\server\scripts\DC\DungeonQuests\npc_dungeon_quest_master.cpp`

```cpp
#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "ScriptedGossip.h"
#include "TokenConfigManager.h"

class npc_dungeon_quest_master : public CreatureScript {
public:
    npc_dungeon_quest_master() : CreatureScript("npc_dungeon_quest_master") { }

    bool OnGossipHello(Player* player, Creature* creature) override {
        // Load quests for this NPC's dungeon
        // Display quest menu with token rewards
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override {
        // Accept quest
        // Track progress
        return true;
    }
};

void AddSC_npc_dungeon_quest_master() {
    new npc_dungeon_quest_master();
}
```

✅ **Action**: Create npc_dungeon_quest_master.cpp

---

## DEPLOYMENT CHECKLIST

### Pre-Deployment
- [ ] All CSV files created in `Custom\CSV DBC\`
- [ ] All SQL files created in `Custom\Custom feature SQLs\`
- [ ] All C++ scripts created in `src\server\scripts\DC\DungeonQuests\`
- [ ] CMakeLists.txt configured for DC scripts
- [ ] TokenConfigManager compiles without errors
- [ ] Code reviewed for syntax errors

### Deployment
- [ ] Backup database
- [ ] Deploy DC_DUNGEON_QUEST_SCHEMA.sql
- [ ] Deploy DC_DUNGEON_QUEST_CONFIG.sql
- [ ] Deploy DC_DUNGEON_QUEST_CREATURES.sql
- [ ] Deploy DC_DUNGEON_QUEST_NPCS_TIER1.sql
- [ ] Deploy DC_DUNGEON_QUEST_DAILY_WEEKLY.sql
- [ ] Compile C++ code
- [ ] Restart server

### Post-Deployment Testing
- [ ] 53 NPCs spawn at correct locations ✅
- [ ] NPC models match dungeon themes ✅
- [ ] CSV files loaded successfully (check logs) ✅
- [ ] Daily quest resets at midnight ✅
- [ ] Weekly quest resets on Monday ✅
- [ ] Tokens awarded on quest completion ✅
- [ ] Achievement unlock triggers ✅
- [ ] Titles awarded correctly ✅

---

## KEY ID RANGES SUMMARY

| Component | Range | Count |
|-----------|-------|-------|
| NPC Entries | 700000-700052 | 53 |
| Daily Quests | 700101-700104 | 4 |
| Weekly Quests | 700201-700204 | 4 |
| Dungeon Quests | 700701-700999 | 630+ |
| Token Items | 700001-700005 | 5 |
| Achievements | 700001-700400 | 50+ |
| Titles | 1000-1015 | 10-15 |

---

## QUICK REFERENCE: TOKEN CONFIGURATION

All tokens are configurable via:
- `Custom\CSV DBC\dc_items_tokens.csv` → Item definitions
- `Custom\SQL\DC_DUNGEON_QUEST_CONFIG.sql` → Reward mappings
- `Custom\SQL\DC_DUNGEON_QUEST_DAILY_WEEKLY.sql` → Quest assignments

**To change rewards**: Edit CSV file and reload server (TokenConfigManager will refresh)

---

## TROUBLESHOOTING

### Issue: NPCs not spawning
**Solution**: Check game_tele coordinates, verify map IDs, ensure creature_template entries created

### Issue: Tokens not awarded
**Solution**: Verify TokenConfigManager loading CSV, check quest ID ranges, inspect daily_quest_token_rewards table

### Issue: CSV not loading
**Solution**: Check file paths, verify CSV format, check server logs for errors, ensure encoding is UTF-8

### Issue: Daily quest not resetting
**Solution**: Verify reset logic in PlayerScript_DungeonQuestDaily, check last_reset_date tracking

---

**Status**: Ready for Implementation  
**Total Development Time**: 9-12 hours  
**Deployment Risk**: LOW  
**Complexity**: MEDIUM

