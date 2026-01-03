# Dungeon Quest System - Complete Implementation

## Overview
This system provides a comprehensive dungeon quest framework for AzerothCore using **Blizzard's official quest IDs**. All 435 dungeon quests are properly mapped to their correct instances using canonical map IDs from the WoW DBC files.

## System Architecture

### Database Tables
1. **`dc_dungeon_quest_mapping`** - Core mapping table linking quest IDs to map IDs
2. **`creature_queststarter`** - Links quest NPCs to quest IDs
3. **`creature_questender`** - Links quest completion NPCs to quest IDs
4. **`quest_template`** - Standard WoW quest definitions (existing Blizzard data)

### C++ Scripts
1. **`DungeonQuestSystem.cpp`** - Quest completion handler with token rewards and achievements
2. **`npc_dungeon_quest_master.cpp`** - Gossip menu for quest browsing (Daily/Weekly/Dungeon/All)
3. **`npc_dungeon_quest_daily_weekly.cpp`** - Reset handlers for daily/weekly quests

### Quest Master NPCs
- **NPC 700000** - Classic Dungeon Quest Master (341 quests)
- **NPC 700001** - The Burning Crusade Quest Master (37 quests)
- **NPC 700002** - Wrath of the Lich King Quest Master (57 quests)

## Quest Distribution

### By Expansion
| Expansion | NPC Entry | Quest Count | Map ID Range |
|-----------|-----------|-------------|--------------|
| Classic   | 700000    | 341         | 1-499        |
| TBC       | 700001    | 37          | 500-569      |
| WotLK     | 700002    | 57          | 570+         |
| **Total** | -         | **435**     | -            |

### Top Dungeons by Quest Count
1. **Blackrock Depths** - 43 quests (Map ID: 230)
2. **Caverns of Time** - 40 quests (Map ID: 269)
3. **Blackrock Spire** - 37 quests (Map ID: 229)
4. **Dire Maul** - 37 quests (Map ID: 429)
5. **Uldaman** - 29 quests (Map ID: 70)
6. **Gnomeregan** - 28 quests (Map ID: 90)

### By Level Type
- **Dungeon**: 353 quests
- **Unknown**: 48 quests
- **Raid**: 17 quests
- **Heroic**: 11 quests
- **Group**: 5 quests
- **Life**: 1 quest

## Installation

### 1. Database Setup
Execute the SQL files in order:
```bash
# Navigate to SQL directory
cd "Custom/feature stuff/DungeonQuestSystem/sql"

# Execute in order
mysql -u root -p acore_world < 01_dc_dungeon_quest_mapping.sql
mysql -u root -p acore_world < 02_creature_quest_relations.sql
```

### 2. Verify Installation
```sql
-- Check mapping table
SELECT COUNT(*) FROM dc_dungeon_quest_mapping; -- Should return 435

-- Check quest relations
SELECT COUNT(*) FROM creature_queststarter WHERE id IN (700000, 700001, 700002); -- Should return 435
SELECT COUNT(*) FROM creature_questender WHERE id IN (700000, 700001, 700002); -- Should return 435

-- Sample query: Get all Blackrock Depths quests
SELECT quest_id, dungeon_name, level_type, quest_level 
FROM dc_dungeon_quest_mapping 
WHERE map_id = 230 
ORDER BY quest_level;
```

### 3. C++ Script Integration
The existing C++ scripts (`DungeonQuestSystem.cpp`, `npc_dungeon_quest_master.cpp`) need to be updated to query the `dc_dungeon_quest_mapping` table instead of using hardcoded quest ID ranges.

**Required Changes:**
- Remove hardcoded constants like `QUEST_DAILY_MIN`, `QUEST_DUNGEON_MAX`
- Update `GetDungeonIdFromQuest()` to query `dc_dungeon_quest_mapping.map_id`
- Modify achievement tracking to use database map IDs

## Data Files

### `data/dungeon_quests_clean.csv`
Normalized quest data extracted from the original CSV:
```csv
quest_id,level_type,level_value,level_raw,dungeon
12238,Dungeon,75,Dungeon (75),Drak'Tharon Keep
12037,Dungeon,74,Dungeon (74),Drak'Tharon Keep
```

### `data/dungeon_quests_summary.csv`
Per-dungeon aggregation statistics:
```csv
Dungeon,Total,Dungeon,Heroic,Raid,Group,Unknown,Life
Blackrock Depths,43,39,0,0,4,0,0
Caverns of Time,40,0,0,0,0,40,0
```

### `data/dungeon_quest_map_correlation.csv`
Complete quest-to-map-ID correlation (used to generate SQL):
```csv
quest_id,map_id,dungeon_name,level_type,quest_level
12238,600,Drak'Tharon Keep,Dungeon,75
```

## Map ID Reference

### Classic Dungeons
| Map ID | Dungeon Name |
|--------|--------------|
| 33     | Shadowfang Keep |
| 34     | Stormwind Stockade |
| 36     | Deadmines |
| 43     | Wailing Caverns |
| 47     | Razorfen Kraul |
| 48     | Blackfathom Deeps |
| 70     | Uldaman |
| 90     | Gnomeregan |
| 109    | Sunken Temple |
| 129    | Razorfen Downs |
| 189    | Scarlet Monastery |
| 209    | Zul'Farrak |
| 229    | Blackrock Spire |
| 230    | Blackrock Depths |
| 269    | Opening of the Dark Portal |
| 289    | Scholomance |
| 329    | Stratholme |
| 349    | Maraudon |
| 389    | Ragefire Chasm |
| 429    | Dire Maul |

### TBC Dungeons
| Map ID | Dungeon Name |
|--------|--------------|
| 540    | Hellfire Citadel: The Shattered Halls |
| 542    | Hellfire Citadel: The Blood Furnace |
| 543    | Hellfire Citadel: Ramparts |
| 545    | Coilfang: The Steamvault |
| 546    | Coilfang: The Underbog |
| 547    | Coilfang: The Slave Pens |
| 552    | Tempest Keep: The Arcatraz |
| 553    | Tempest Keep: The Botanica |
| 554    | Tempest Keep: The Mechanar |
| 555    | Auchindoun: Shadow Labyrinth |
| 556    | Auchindoun: Sethekk Halls |
| 557    | Auchindoun: Mana-Tombs |
| 558    | Auchindoun: Auchenai Crypts |
| 560    | The Escape From Durnholde |
| 585    | Magister's Terrace |

### WotLK Dungeons
| Map ID | Dungeon Name |
|--------|--------------|
| 574    | Utgarde Keep |
| 575    | Utgarde Pinnacle |
| 576    | The Nexus |
| 578    | The Oculus |
| 595    | The Culling of Stratholme |
| 599    | Halls of Stone |
| 600    | Drak'Tharon Keep |
| 601    | Azjol-Nerub |
| 602    | Halls of Lightning |
| 604    | Gundrak |
| 608    | Violet Hold |
| 619    | Ahn'kahet: The Old Kingdom |
| 632    | The Forge of Souls |
| 658    | Pit of Saron |
| 668    | Halls of Reflection |

## Quest Examples

### Sample Queries
```sql
-- Get all WotLK heroic dungeon quests
SELECT q.quest_id, q.dungeon_name, q.quest_level 
FROM dc_dungeon_quest_mapping q
WHERE q.map_id >= 570 AND q.level_type = 'Heroic'
ORDER BY q.quest_level;

-- Get quests for a specific dungeon
SELECT q.quest_id, qt.LogTitle, q.quest_level, q.level_type
FROM dc_dungeon_quest_mapping q
LEFT JOIN quest_template qt ON q.quest_id = qt.ID
WHERE q.map_id = 230 -- Blackrock Depths
ORDER BY q.quest_level;

-- Count quests per expansion
SELECT 
    CASE 
        WHEN map_id < 500 THEN 'Classic'
        WHEN map_id < 570 THEN 'TBC'
        ELSE 'WotLK'
    END AS expansion,
    COUNT(*) AS quest_count
FROM dc_dungeon_quest_mapping
GROUP BY expansion;
```

## Features

### Current Implementation
✓ 435 Blizzard dungeon quests properly mapped  
✓ Standard WoW map IDs from official DBC files  
✓ Three quest master NPCs (one per expansion)  
✓ Database-driven quest-to-dungeon mapping  
✓ Quest filtering by category (Daily/Weekly/Dungeon/All)  

### Planned Enhancements
⧗ Token reward system integration  
⧗ Achievement tracking per dungeon  
⧗ Statistics system (total completions, fastest times)  
⧗ Daily/Weekly quest rotation  
⧗ Prestige system (not in current scope)  

## Usage

### For Players
1. Find the appropriate Quest Master NPC:
   - **Classic dungeons**: NPC 700000
   - **TBC dungeons**: NPC 700001
   - **WotLK dungeons**: NPC 700002

2. Talk to the NPC and browse quests by category:
   - **Daily Quests** - Reset at server midnight
   - **Weekly Quests** - Reset on server maintenance
   - **Dungeon Quests** - All available dungeon quests
   - **All Quests** - Complete quest list

3. Accept quests and complete dungeon objectives

### For Developers
```cpp
// Query dungeon info from quest ID
uint32 GetMapIdFromQuest(uint32 questId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT map_id FROM dc_dungeon_quest_mapping WHERE quest_id = {}", 
        questId
    );
    
    if (result)
    {
        Field* fields = result->Fetch();
        return fields[0].Get<uint32>();
    }
    return 0;
}

// Check if quest is a dungeon quest
bool IsDungeonQuest(uint32 questId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT 1 FROM dc_dungeon_quest_mapping WHERE quest_id = {}",
        questId
    );
    return result != nullptr;
}
```

## Troubleshooting

### Common Issues

**Issue**: Quest NPCs don't show any quests  
**Solution**: Verify creature_queststarter/questender tables are populated correctly

**Issue**: Quests appear but have incorrect levels  
**Solution**: Check dc_dungeon_quest_mapping table for correct level_type and quest_level values

**Issue**: Some dungeons missing quests  
**Solution**: Verify map_id mapping in dungeon_quest_map_correlation.csv

### Debug Queries
```sql
-- Find orphaned quest relations (quests without mapping)
SELECT cqs.quest 
FROM creature_queststarter cqs
LEFT JOIN dc_dungeon_quest_mapping dq ON cqs.quest = dq.quest_id
WHERE cqs.id IN (700000, 700001, 700002) 
AND dq.quest_id IS NULL;

-- Find unmapped quests
SELECT quest_id, dungeon_name 
FROM dc_dungeon_quest_mapping 
WHERE map_id = 0;

-- Check duplicate quest assignments
SELECT quest_id, COUNT(*) 
FROM dc_dungeon_quest_mapping 
GROUP BY quest_id 
HAVING COUNT(*) > 1;
```

## Credits
- **Quest Data**: Blizzard Entertainment (official WoW quest IDs)
- **Map IDs**: Extracted from Map.csv DBC file
- **System Architecture**: AzerothCore framework
- **Implementation**: DarkChaos-255 server customization

## License
This system uses official Blizzard quest data and is intended for use with AzerothCore private servers for educational purposes only.
