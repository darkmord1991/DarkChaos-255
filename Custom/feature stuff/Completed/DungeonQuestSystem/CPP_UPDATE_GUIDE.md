# C++ Script Update Guide

## Overview
This guide shows how to update the existing dungeon quest system C++ scripts to use the `dc_dungeon_quest_mapping` database table instead of hardcoded quest ID ranges.

## Files to Modify
1. `src/server/scripts/DC/DungeonQuests/DungeonQuestSystem.cpp`
2. `src/server/scripts/DC/DungeonQuests/npc_dungeon_quest_master.cpp` (minor updates)

---

## 1. DungeonQuestSystem.cpp Updates

### Current Issues (Hardcoded Ranges)
```cpp
// OLD CODE - Remove these hardcoded constants
#define QUEST_DAILY_MIN 700101
#define QUEST_DAILY_MAX 700104
#define QUEST_WEEKLY_MIN 700201
#define QUEST_WEEKLY_MAX 700204
#define QUEST_DUNGEON_MIN 700701
#define QUEST_DUNGEON_MAX 700999
```

### ✅ Solution 1: Replace Quest Type Detection
**OLD CODE**:
```cpp
bool IsDungeonQuest(uint32 questId)
{
    return questId >= QUEST_DUNGEON_MIN && questId <= QUEST_DUNGEON_MAX;
}

bool IsDailyQuest(uint32 questId)
{
    return questId >= QUEST_DAILY_MIN && questId <= QUEST_DAILY_MAX;
}

bool IsWeeklyQuest(uint32 questId)
{
    return questId >= QUEST_WEEKLY_MIN && questId <= QUEST_WEEKLY_MAX;
}
```

**NEW CODE**:
```cpp
bool IsDungeonQuest(uint32 questId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT 1 FROM dc_dungeon_quest_mapping WHERE quest_id = {}",
        questId
    );
    return result != nullptr;
}

bool IsDailyQuest(uint32 questId)
{
    // Check if quest is in daily rotation (implement daily tracking table)
    QueryResult result = WorldDatabase.Query(
        "SELECT 1 FROM dc_daily_quest_rotation WHERE quest_id = {} AND is_active = 1",
        questId
    );
    return result != nullptr;
}

bool IsWeeklyQuest(uint32 questId)
{
    // Check if quest is in weekly rotation (implement weekly tracking table)
    QueryResult result = WorldDatabase.Query(
        "SELECT 1 FROM dc_weekly_quest_rotation WHERE quest_id = {} AND is_active = 1",
        questId
    );
    return result != nullptr;
}
```

### ✅ Solution 2: Replace Map ID Lookup
**OLD CODE**:
```cpp
uint32 GetDungeonIdFromQuest(uint32 questId)
{
    // Hardcoded map IDs per quest range - TERRIBLE!
    if (questId >= 700701 && questId <= 700710) return 389;  // Ragefire
    if (questId >= 700711 && questId <= 700720) return 36;   // Deadmines
    if (questId >= 700721 && questId <= 700730) return 43;   // Wailing Caverns
    // ... 40+ more hardcoded ranges
    return 0;
}
```

**NEW CODE**:
```cpp
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
    
    return 0;  // Not a dungeon quest
}
```

### ✅ Solution 3: Update Token Reward Logic
**OLD CODE**:
```cpp
void HandleTokenRewards(Player* player, uint32 questId)
{
    uint32 tokenAmount = 0;
    
    // Hardcoded token amounts per quest range
    if (questId >= QUEST_DAILY_MIN && questId <= QUEST_DAILY_MAX)
        tokenAmount = 5;
    else if (questId >= QUEST_WEEKLY_MIN && questId <= QUEST_WEEKLY_MAX)
        tokenAmount = 20;
    else if (questId >= QUEST_DUNGEON_MIN && questId <= QUEST_DUNGEON_MAX)
        tokenAmount = 1;
        
    player->ModifyCurrency(CURRENCY_DUNGEON_TOKEN, tokenAmount);
}
```

**NEW CODE**:
```cpp
void HandleTokenRewards(Player* player, uint32 questId)
{
    // Get quest info from database
    QueryResult result = WorldDatabase.Query(
        "SELECT level_type, quest_level FROM dc_dungeon_quest_mapping WHERE quest_id = {}",
        questId
    );
    
    if (!result)
        return;  // Not a dungeon quest
        
    Field* fields = result->Fetch();
    std::string levelType = fields[0].Get<std::string>();
    uint32 questLevel = fields[1].Get<uint32>();
    
    // Calculate token reward based on level type
    uint32 tokenAmount = 1;  // Base reward
    
    if (levelType == "Heroic")
        tokenAmount = 3;
    else if (levelType == "Raid")
        tokenAmount = 5;
    else if (levelType == "Dungeon" && questLevel >= 80)
        tokenAmount = 2;  // WotLK dungeons
        
    // Check for daily/weekly bonus
    if (IsDailyQuest(questId))
        tokenAmount += 5;
    else if (IsWeeklyQuest(questId))
        tokenAmount += 20;
        
    player->ModifyCurrency(CURRENCY_DUNGEON_TOKEN, tokenAmount);
}
```

### ✅ Solution 4: Update Achievement Tracking
**OLD CODE**:
```cpp
void CheckAchievements(Player* player, uint32 questId)
{
    // Hardcoded achievement checks per dungeon
    uint32 dungeonId = GetDungeonIdFromQuest(questId);
    
    // Increment completion counter
    CharacterDatabase.Execute(
        "INSERT INTO dc_dungeon_quest_stats (guid, dungeon_id, completions) "
        "VALUES ({}, {}, 1) ON DUPLICATE KEY UPDATE completions = completions + 1",
        player->GetGUID().GetCounter(), dungeonId
    );
    
    // Check if player has completed all quests for this dungeon
    // ... hardcoded logic
}
```

**NEW CODE**:
```cpp
void CheckAchievements(Player* player, uint32 questId)
{
    // Get map ID from database
    uint32 mapId = GetMapIdFromQuest(questId);
    if (mapId == 0)
        return;
    
    // Increment completion counter
    CharacterDatabase.Execute(
        "INSERT INTO dc_dungeon_quest_stats (guid, map_id, completions) "
        "VALUES ({}, {}, 1) ON DUPLICATE KEY UPDATE completions = completions + 1",
        player->GetGUID().GetCounter(), mapId
    );
    
    // Get total quests for this dungeon
    QueryResult totalQuests = WorldDatabase.Query(
        "SELECT COUNT(*) FROM dc_dungeon_quest_mapping WHERE map_id = {}",
        mapId
    );
    
    if (!totalQuests)
        return;
        
    uint32 totalDungeonQuests = totalQuests->Fetch()[0].Get<uint32>();
    
    // Get player's completed quests for this dungeon
    QueryResult completedQuests = CharacterDatabase.Query(
        "SELECT COUNT(DISTINCT cq.quest) "
        "FROM character_queststatus_rewarded cq "
        "INNER JOIN dc_dungeon_quest_mapping dq ON cq.quest = dq.quest_id "
        "WHERE cq.guid = {} AND dq.map_id = {}",
        player->GetGUID().GetCounter(), mapId
    );
    
    if (!completedQuests)
        return;
        
    uint32 playerCompletedQuests = completedQuests->Fetch()[0].Get<uint32>();
    
    // Award achievement if all quests completed
    if (playerCompletedQuests >= totalDungeonQuests)
    {
        // Get dungeon name for achievement notification
        QueryResult dungeonInfo = WorldDatabase.Query(
            "SELECT dungeon_name FROM dc_dungeon_quest_mapping WHERE map_id = {} LIMIT 1",
            mapId
        );
        
        if (dungeonInfo)
        {
            std::string dungeonName = dungeonInfo->Fetch()[0].Get<std::string>();
            
            // Award custom achievement (implement achievement ID mapping)
            uint32 achievementId = GetDungeonAchievementId(mapId);
            if (achievementId > 0)
            {
                player->CompletedAchievement(sAchievementStore.LookupEntry(achievementId));
            }
            
            // Send notification
            ChatHandler(player->GetSession()).PSendSysMessage(
                "Congratulations! You have completed all quests in {}!",
                dungeonName
            );
        }
    }
}
```

---

## 2. npc_dungeon_quest_master.cpp Updates

### Minor Update: Quest Filtering
The existing code uses `creature_queststarter` table which is already populated correctly. Only minor optimization needed:

**CURRENT CODE (No changes needed)**:
```cpp
bool OnGossipHello(Player* player, Creature* creature) override
{
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Daily Quests", GOSSIP_SENDER_MAIN, 1);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Weekly Quests", GOSSIP_SENDER_MAIN, 2);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Dungeon Quests", GOSSIP_SENDER_MAIN, 3);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show All Quests", GOSSIP_SENDER_MAIN, 4);
    SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    return true;
}
```

**OPTIONAL ENHANCEMENT** (Add quest counts):
```cpp
bool OnGossipHello(Player* player, Creature* creature) override
{
    uint32 npcEntry = creature->GetEntry();
    
    // Get total quest count for this NPC
    QueryResult totalQuests = WorldDatabase.Query(
        "SELECT COUNT(*) FROM dc_dungeon_quest_mapping WHERE npc_entry = {}",
        npcEntry
    );
    
    uint32 questCount = totalQuests ? totalQuests->Fetch()[0].Get<uint32>() : 0;
    
    // Show menu with quest counts
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
        Acore::StringFormat("Show Daily Quests ({})", GetDailyQuestCount(npcEntry)),
        GOSSIP_SENDER_MAIN, 1);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT,
        Acore::StringFormat("Show Weekly Quests ({})", GetWeeklyQuestCount(npcEntry)),
        GOSSIP_SENDER_MAIN, 2);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT,
        Acore::StringFormat("Show Dungeon Quests ({})", questCount),
        GOSSIP_SENDER_MAIN, 3);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show All Quests", GOSSIP_SENDER_MAIN, 4);
    
    SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    return true;
}
```

---

## 3. Additional Helper Functions

Add these utility functions to `DungeonQuestSystem.cpp`:

```cpp
/**
 * Get all quests for a specific map ID
 */
std::vector<uint32> GetQuestsForMap(uint32 mapId)
{
    std::vector<uint32> quests;
    
    QueryResult result = WorldDatabase.Query(
        "SELECT quest_id FROM dc_dungeon_quest_mapping WHERE map_id = {}",
        mapId
    );
    
    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            quests.push_back(fields[0].Get<uint32>());
        } while (result->NextRow());
    }
    
    return quests;
}

/**
 * Get all quests for an NPC
 */
std::vector<uint32> GetQuestsForNPC(uint32 npcEntry)
{
    std::vector<uint32> quests;
    
    QueryResult result = WorldDatabase.Query(
        "SELECT quest_id FROM dc_dungeon_quest_mapping WHERE npc_entry = {}",
        npcEntry
    );
    
    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            quests.push_back(fields[0].Get<uint32>());
        } while (result->NextRow());
    }
    
    return quests;
}

/**
 * Get quest level type (Dungeon/Heroic/Raid/Group)
 */
std::string GetQuestLevelType(uint32 questId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT level_type FROM dc_dungeon_quest_mapping WHERE quest_id = {}",
        questId
    );
    
    if (result)
        return result->Fetch()[0].Get<std::string>();
    
    return "Unknown";
}

/**
 * Get recommended quest level
 */
uint32 GetQuestLevel(uint32 questId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT quest_level FROM dc_dungeon_quest_mapping WHERE quest_id = {}",
        questId
    );
    
    if (result)
        return result->Fetch()[0].Get<uint32>();
    
    return 0;
}

/**
 * Get dungeon name for a quest
 */
std::string GetDungeonNameFromQuest(uint32 questId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT dungeon_name FROM dc_dungeon_quest_mapping WHERE quest_id = {}",
        questId
    );
    
    if (result)
        return result->Fetch()[0].Get<std::string>();
    
    return "Unknown Dungeon";
}
```

---

## 4. Database Schema Updates (Optional)

### Add Daily/Weekly Rotation Tables
```sql
-- Track active daily quests
CREATE TABLE `dc_daily_quest_rotation` (
  `quest_id` INT UNSIGNED NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 0,
  `last_reset` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`quest_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Track active weekly quests
CREATE TABLE `dc_weekly_quest_rotation` (
  `quest_id` INT UNSIGNED NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 0,
  `last_reset` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`quest_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Update stats table to use map_id instead of dungeon_id
ALTER TABLE `dc_dungeon_quest_stats` 
  CHANGE COLUMN `dungeon_id` `map_id` SMALLINT UNSIGNED NOT NULL;
```

---

## 5. Testing Checklist

After making C++ changes:

### Compilation
- [ ] Code compiles without errors
- [ ] No warnings about deprecated constants
- [ ] All database queries use prepared statements (safe from SQL injection)

### Runtime Testing
- [ ] Accept quest from NPC 700000 (Classic)
- [ ] Complete quest and verify token reward
- [ ] Check achievement progress
- [ ] Verify quest shows in gossip menu
- [ ] Test with TBC quest (NPC 700001)
- [ ] Test with WotLK quest (NPC 700002)

### Database Verification
```sql
-- Check that quest type detection works
SELECT quest_id, dungeon_name, level_type 
FROM dc_dungeon_quest_mapping 
WHERE quest_id IN (12238, 6981, 24510);

-- Verify map ID lookup
SELECT map_id FROM dc_dungeon_quest_mapping WHERE quest_id = 12238;
-- Expected: 600 (Drak'Tharon Keep)

-- Test achievement query
SELECT COUNT(*) FROM dc_dungeon_quest_mapping WHERE map_id = 230;
-- Expected: 43 (Blackrock Depths total quests)
```

---

## 6. Performance Considerations

### Caching (Recommended)
Since map IDs don't change, implement caching:

```cpp
// In DungeonQuestSystem.h
class DungeonQuestSystem
{
private:
    std::unordered_map<uint32, uint32> _questToMapCache;  // quest_id -> map_id
    std::unordered_map<uint32, std::string> _questLevelTypeCache;  // quest_id -> level_type
    
public:
    void LoadQuestMappings()
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT quest_id, map_id, level_type FROM dc_dungeon_quest_mapping"
        );
        
        if (!result)
            return;
            
        do
        {
            Field* fields = result->Fetch();
            uint32 questId = fields[0].Get<uint32>();
            uint32 mapId = fields[1].Get<uint32>();
            std::string levelType = fields[2].Get<std::string>();
            
            _questToMapCache[questId] = mapId;
            _questLevelTypeCache[questId] = levelType;
            
        } while (result->NextRow());
        
        LOG_INFO("server.loading", "Loaded {} dungeon quest mappings", _questToMapCache.size());
    }
    
    uint32 GetMapIdFromQuestCached(uint32 questId)
    {
        auto it = _questToMapCache.find(questId);
        return (it != _questToMapCache.end()) ? it->second : 0;
    }
};
```

Call `LoadQuestMappings()` in `sWorld->SetInitialWorldSettings()` during server startup.

---

## Summary

### Changes Required
1. **Remove hardcoded constants** (QUEST_DAILY_MIN, etc.)
2. **Replace `GetDungeonIdFromQuest()`** with database query
3. **Update `IsDungeonQuest()`** to check `dc_dungeon_quest_mapping`
4. **Modify token reward logic** to use level_type from database
5. **Update achievement tracking** to use map_id instead of hardcoded ranges

### Benefits
- ✅ No more hardcoded quest ID ranges
- ✅ Easy to add new quests (just insert into database)
- ✅ Proper use of Blizzard quest IDs
- ✅ Achievement tracking works for all dungeons automatically
- ✅ Token rewards scale with quest difficulty

### Estimated Time
- **Code changes**: 2-3 hours
- **Testing**: 1-2 hours
- **Total**: 4-5 hours
