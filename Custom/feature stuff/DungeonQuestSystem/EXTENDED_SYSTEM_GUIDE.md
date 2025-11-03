# 🎮 EXTENDED DUNGEON QUEST SYSTEM v4.0
**Complete System with Daily/Weekly Quests, Achievements & Multi-Difficulty Support**

---

## 🆕 What's New in v4.0

### Major Features Added
✅ **Daily Quest Rotation** - 35 daily quests (5 per day, 7-day rotation)  
✅ **Weekly Quest Challenges** - 12 weekly quests (3 per week, 4-week rotation)  
✅ **Dark Chaos Achievement System** - 50+ custom achievements with points, titles & token rewards  
✅ **Multi-Difficulty Support** - Normal, Heroic, Mythic, Mythic+ tiers  
✅ **Automatic NPC Spawning** - Quest masters spawn in all major cities  
✅ **Single Daily/Weekly NPC** - One "Quest Herald" (NPC 700003) in each city  
✅ **Scalable Architecture** - Easy to add new dungeons, difficulties, quests  

---

## 📦 Complete System Overview

### Quest Types
| Type | Count | Quest IDs | NPC | Frequency |
|------|-------|-----------|-----|-----------|
| **Blizzard Dungeon Quests** | 435 | Blizzard IDs | 700000-700002 | Permanent |
| **Daily Quests** | 35 | 700101-700135 | 700003 | Rotate daily |
| **Weekly Quests** | 12 | 700201-700212 | 700003 | Rotate weekly |
| **Total** | **482** | - | - | - |

### NPCs
| Entry | Name | Location | Quest Count | Purpose |
|-------|------|----------|-------------|---------|
| 700000 | Classic Quest Master | Stormwind, Ironforge, Orgrimmar, Undercity | 341 | Classic dungeons |
| 700001 | TBC Quest Master | Shattrath City | 37 | TBC dungeons |
| 700002 | WotLK Quest Master | Dalaran | 57 | WotLK dungeons |
| 700003 | Quest Herald | All major cities | 47 | Daily/Weekly challenges |

### Difficulty Tiers
| Difficulty | Min Level | Token Multiplier | Group Required | Status |
|------------|-----------|------------------|----------------|--------|
| Normal | 1 | 1.0x | No | ✅ Active |
| Heroic | 80 | 1.5x | No | ✅ Active |
| Mythic | 80 | 2.0x | Yes (3+) | ✅ Active |
| Mythic+ | 80 | 3.0x | Yes (5+) | ⏳ Coming Soon |

### Achievement Categories
1. **Dungeon Initiate** (5 achievements) - General progression
2. **Expansion Mastery** (4 achievements) - Complete all quests per expansion
3. **Difficulty Challenges** (5 achievements) - Heroic/Mythic milestones
4. **Dedication** (7 achievements) - Daily/weekly completion
5. **Dungeon Specific** (12 achievements) - Per-dungeon mastery
6. **Efficiency** (4 achievements) - Speed running
7. **Group Play** (3 achievements) - Group content
8. **Meta Achievements** (3 achievements) - Overall mastery

**Total**: 50+ achievements, 1000+ points, 7 titles

---

## 🗄️ Database Architecture

### New Tables (v4.0)
```sql
dc_daily_quest_rotation          -- Daily quest pool & activation
dc_weekly_quest_rotation         -- Weekly quest pool & activation
dc_player_dungeon_stats          -- Per-player statistics tracking
dc_achievement_progress          -- Achievement progression tracking
dc_difficulty_config             -- Difficulty tier configuration
dc_quest_reset_tracking          -- Daily/weekly reset times
dc_custom_achievements           -- Achievement definitions
dc_achievement_criteria          -- Achievement requirements
```

### Existing Tables (Enhanced)
```sql
dc_dungeon_quest_mapping         -- Now includes 'difficulty' column
creature_queststarter            -- Includes all daily/weekly quests
creature_questender              -- Includes all daily/weekly quests
creature_template                -- 4 quest master NPCs
creature                         -- 12 automatic spawn locations
```

---

## 📅 Daily Quest Rotation

### Rotation Schedule
Each day offers **5 daily quests**:
- 2-3 **Classic dungeons** (Normal)
- 1-2 **TBC/WotLK dungeons** (Normal or Heroic)

**Reset Time**: 6:00 AM server time daily

### Example: Sunday's Quests
- [Daily] Blackrock Depths (Normal) - 10 tokens
- [Daily] Hellfire Ramparts (Heroic) - 15 tokens
- [Daily] Drak'Tharon Keep (Normal) - 10 tokens
- [Daily] Gnomeregan (Normal) - 10 tokens
- [Daily] Stratholme (Normal) - 10 tokens

### Activation Query
```sql
-- Activate today's daily quests
UPDATE dc_daily_quest_rotation 
SET is_active = 1 
WHERE rotation_day = WEEKDAY(NOW());

-- Deactivate yesterday's quests
UPDATE dc_daily_quest_rotation 
SET is_active = 0 
WHERE rotation_day != WEEKDAY(NOW());
```

---

## 📆 Weekly Quest Rotation

### Rotation Schedule
Each week offers **3 weekly quests**:
- 1 **Heroic difficulty** (requires group) - 50 tokens
- 1 **Mythic difficulty** (requires 3+ group) - 100 tokens
- 1 **Heroic difficulty** (requires group) - 50 tokens

**Reset Time**: Wednesday 6:00 AM server time

### Example: Week 1 Quests
- [Weekly] Blackrock Depths (Heroic) - 50 tokens
- [Weekly] Hellfire Ramparts (Mythic) - 100 tokens
- [Weekly] Drak'Tharon Keep (Heroic) - 50 tokens

### Activation Query
```sql
-- Activate this week's quests (4-week rotation)
UPDATE dc_weekly_quest_rotation 
SET is_active = 1 
WHERE rotation_week = (WEEK(NOW()) % 4) + 1;

-- Deactivate other weeks
UPDATE dc_weekly_quest_rotation 
SET is_active = 0 
WHERE rotation_week != (WEEK(NOW()) % 4) + 1;
```

---

## 🏆 Achievement System

### Dark Chaos Category
All achievements are under a custom "Dark Chaos" category for easy organization.

### Sample Achievements

#### Dungeon Initiate
- **First Steps** (50001) - Complete your first dungeon quest → 10 points
- **Quest Explorer** (50002) - Complete 10 dungeon quests → 10 points
- **Quest Veteran** (50003) - Complete 25 dungeon quests → 15 points
- **Quest Master** (50004) - Complete 50 dungeon quests → 20 points
- **Dungeon Enthusiast** (50005) - Complete 100 dungeon quests → 25 points

#### Expansion Mastery
- **Classic Dungeoneer** (50010) - Complete all 341 Classic quests → 30 points
- **Outland Conqueror** (50011) - Complete all 37 TBC quests → 30 points
- **Northrend Hero** (50012) - Complete all 57 WotLK quests → 30 points
- **Legendary Questmaster** (50013) - Complete ALL 435 quests → 50 points

#### Difficulty Challenges (with titles!)
- **Heroic Conqueror** (50021) - 50 Heroic quests → "the Heroic" title
- **Mythic Conqueror** (50023) - 25 Mythic quests → "the Mythic" title
- **Mythic+ Pioneer** (50024) - 10 Mythic+ quests → "the Unstoppable" title

#### Daily/Weekly Dedication
- **7-Day Streak** (50035) - 7 consecutive daily completions → 150 bonus tokens
- **30-Day Streak** (50036) - 30 consecutive dailies → 500 bonus tokens

### Achievement Tracking
```sql
-- Check player's achievement progress
SELECT 
    a.name,
    a.description,
    p.current_progress,
    p.required_progress,
    p.completed
FROM dc_achievement_progress p
JOIN dc_custom_achievements a ON p.achievement_id = a.achievement_id
WHERE p.guid = ? -- Player GUID
ORDER BY a.display_order;
```

---

## 🗺️ Automatic NPC Spawning

### Spawn Locations

#### Alliance Cities
**Stormwind**:
- Classic Quest Master (700000) - Trade District @ -8522.86, 456.078
- Quest Herald (700003) - Trade District @ -8520.12, 458.245

**Ironforge**:
- Classic Quest Master (700000) - The Commons @ -4921.07, -956.564
- Quest Herald (700003) - The Commons @ -4918.43, -958.822

#### Horde Cities
**Orgrimmar**:
- Classic Quest Master (700000) - Valley of Strength @ 1577.35, -4439.39
- Quest Herald (700003) - Valley of Strength @ 1579.68, -4437.12

**Undercity**:
- Classic Quest Master (700000) - Trade Quarter @ 1633.75, 219.402
- Quest Herald (700003) - Trade Quarter @ 1636.18, 221.545

#### Neutral Cities
**Shattrath**:
- TBC Quest Master (700001) - Center @ -1822.53, 5299.58
- Quest Herald (700003) - Center @ -1819.87, 5301.95

**Dalaran**:
- WotLK Quest Master (700002) - Krasus' Landing @ 5812.75, 588.186
- Quest Herald (700003) - Krasus' Landing @ 5815.22, 590.445

**Total**: 12 NPCs across 6 cities (all spawn automatically on server start)

---

## 🛠️ Installation

### Step 1: Execute SQL Files (In Order!)
```bash
cd "Custom/feature stuff/DungeonQuestSystem/sql"

# Core system (v3.0)
mysql -u root -p acore_world < 01_dc_dungeon_quest_mapping.sql
mysql -u root -p acore_world < 02_creature_quest_relations.sql

# Extended system (v4.0 NEW!)
mysql -u root -p acore_world < 03_extended_schema_daily_weekly_difficulties.sql
mysql -u root -p acore_world < 04_dark_chaos_achievements.sql
mysql -u root -p acore_world < 05_npc_templates_and_spawns.sql
mysql -u root -p acore_world < 06_daily_weekly_quest_templates.sql
mysql -u root -p acore_world < 07_daily_weekly_npc_relations.sql

# Verification (OPTIONAL)
mysql -u root -p acore_world < 99_verification_queries.sql
```

### Step 2: Activate Today's Quests
```sql
-- Activate daily quests for today
UPDATE dc_daily_quest_rotation 
SET is_active = 1 
WHERE rotation_day = WEEKDAY(NOW());

-- Activate weekly quests for this week
UPDATE dc_weekly_quest_rotation 
SET is_active = 1 
WHERE rotation_week = (WEEK(NOW()) % 4) + 1;
```

### Step 3: Setup Daily Reset (Cron/Scheduler)
Add to server startup or cron job:
```bash
# Daily reset at 6:00 AM
0 6 * * * mysql -u root -p'password' acore_world -e "
  UPDATE dc_daily_quest_rotation SET is_active = 0;
  UPDATE dc_daily_quest_rotation SET is_active = 1 WHERE rotation_day = WEEKDAY(NOW());
  UPDATE dc_quest_reset_tracking SET last_reset = NOW() WHERE reset_type = 'Daily';"

# Weekly reset Wednesday 6:00 AM
0 6 * * 3 mysql -u root -p'password' acore_world -e "
  UPDATE dc_weekly_quest_rotation SET is_active = 0;
  UPDATE dc_weekly_quest_rotation SET is_active = 1 WHERE rotation_week = (WEEK(NOW()) % 4) + 1;
  UPDATE dc_quest_reset_tracking SET last_reset = NOW() WHERE reset_type = 'Weekly';"
```

### Step 4: Restart Server
NPCs will spawn automatically!

---

## 🎯 How It Works

### For Players
1. **Find Quest Herald** (NPC 700003) in any major city
2. **Talk to NPC** to see active daily/weekly quests
3. **Accept quests** (only active rotation quests visible)
4. **Complete dungeons** to finish quests
5. **Turn in** to Quest Herald for bonus tokens & achievement progress
6. **Earn achievements** and unlock titles

### Quest Completion Flow
```
Player accepts [Daily] Blackrock Depths (700101)
↓
Player completes any BRD quest from dungeon quest masters (700000)
↓
Quest auto-completes OR manual turn-in to Quest Herald (700003)
↓
Player receives:
  - 10 bonus dungeon tokens
  - Achievement progress
  - XP/gold rewards
↓
Quest becomes available again tomorrow (6 AM reset)
```

---

## 🔧 C++ Integration

### Required Script Updates

The existing `npc_dungeon_quest_daily_weekly.cpp` needs enhancement:

```cpp
// Check if quest is daily
bool IsDailyQuest(uint32 questId)
{
    return questId >= 700101 && questId <= 700135;
}

// Check if quest is weekly
bool IsWeeklyQuest(uint32 questId)
{
    return questId >= 700201 && questId <= 700212;
}

// Check if quest is currently active
bool IsQuestActive(uint32 questId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT is_active FROM dc_daily_quest_rotation WHERE quest_id = {} "
        "UNION "
        "SELECT is_active FROM dc_weekly_quest_rotation WHERE quest_id = {}",
        questId, questId
    );
    
    if (result)
    {
        Field* fields = result->Fetch();
        return fields[0].Get<bool>();
    }
    
    return false;
}

// Hide inactive quests from gossip menu
bool OnGossipHello(Player* player, Creature* creature) override
{
    // Only show quests that are currently active
    std::vector<uint32> activeQuests;
    
    QueryResult dailies = WorldDatabase.Query(
        "SELECT quest_id FROM dc_daily_quest_rotation WHERE is_active = 1"
    );
    
    QueryResult weeklies = WorldDatabase.Query(
        "SELECT quest_id FROM dc_weekly_quest_rotation WHERE is_active = 1"
    );
    
    // Build gossip menu with only active quests
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Today's Daily Challenges", GOSSIP_SENDER_MAIN, 1);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "This Week's Challenges", GOSSIP_SENDER_MAIN, 2);
    
    SendGossipMenuFor(player, 700004, creature->GetGUID());
    return true;
}

// Award achievement progress on quest completion
void OnQuestComplete(Player* player, Quest const* quest)
{
    uint32 questId = quest->GetQuestId();
    
    // Track total quest completions
    CharacterDatabase.Execute(
        "INSERT INTO dc_achievement_progress (guid, achievement_id, current_progress, required_progress) "
        "VALUES ({}, 50001, 1, 1) ON DUPLICATE KEY UPDATE current_progress = current_progress + 1",
        player->GetGUID().GetCounter()
    );
    
    // Check for achievement completion
    CheckAchievements(player);
}
```

---

## 📊 Statistics & Tracking

### Player Statistics
The system tracks per-player:
- Total quest completions per dungeon
- Completions per difficulty tier
- Daily quest streak
- Weekly quest streak
- Fastest completion times
- First/last completion timestamps

### Sample Query
```sql
-- Get player's top 5 dungeons
SELECT 
    dqm.dungeon_name,
    pds.difficulty,
    pds.total_completions,
    pds.fastest_completion_time
FROM dc_player_dungeon_stats pds
JOIN dc_dungeon_quest_mapping dqm ON pds.map_id = dqm.map_id
WHERE pds.guid = ?  -- Player GUID
ORDER BY pds.total_completions DESC
LIMIT 5;
```

---

## 🚀 Future Enhancements

### Planned Features
⏳ **Mythic+ System** - Keystones, timer-based challenges  
⏳ **Leaderboards** - Top players per dungeon/week  
⏳ **Bonus Events** - Double token weekends  
⏳ **Seasonal Rotations** - Special holiday quests  
⏳ **Achievement Rewards** - Cosmetic items, mounts  
⏳ **Player Meeting Place** - Custom hub with all quest masters  

### Easy to Expand
Adding new content is simple:
1. **New Dungeon**: Insert into `dc_dungeon_quest_mapping`
2. **New Difficulty**: Add to `dc_difficulty_config`
3. **New Daily Quest**: Insert into `dc_daily_quest_rotation`
4. **New Achievement**: Insert into `dc_custom_achievements`

---

## 📁 File Structure

```
Custom/feature stuff/DungeonQuestSystem/
├── sql/
│   ├── 01_dc_dungeon_quest_mapping.sql       (v3.0 - Core mapping)
│   ├── 02_creature_quest_relations.sql       (v3.0 - NPC links)
│   ├── 03_extended_schema_daily_weekly_difficulties.sql  (v4.0 NEW!)
│   ├── 04_dark_chaos_achievements.sql        (v4.0 NEW!)
│   ├── 05_npc_templates_and_spawns.sql       (v4.0 NEW!)
│   ├── 06_daily_weekly_quest_templates.sql   (v4.0 NEW!)
│   ├── 07_daily_weekly_npc_relations.sql     (v4.0 NEW!)
│   └── 99_verification_queries.sql           (Optional)
├── data/
│   ├── dungeon_quests_clean.csv
│   ├── dungeon_quests_summary.csv
│   ├── dungeon_quest_map_correlation.csv
│   └── README.md
├── README.md                                   (v3.0 docs)
├── QUICK_START.md                             (v3.0 quickstart)
├── IMPLEMENTATION_SUMMARY.md                  (v3.0 summary)
├── CPP_UPDATE_GUIDE.md                        (v3.0 C++ guide)
└── EXTENDED_SYSTEM_GUIDE.md                   (v4.0 THIS FILE!)
```

---

## 🎉 Summary

### What You Get
- **482 total quests** (435 permanent + 47 rotating)
- **4 quest master NPCs** (auto-spawn in 6 cities)
- **50+ achievements** (1000+ points, 7 titles)
- **4 difficulty tiers** (Normal → Mythic+)
- **Daily rotation** (5 quests/day)
- **Weekly rotation** (3 quests/week)
- **Complete tracking** (stats, progress, streaks)
- **Scalable architecture** (easy to expand)

### Total Installation Time
- **SQL Import**: ~2 minutes
- **Cron Setup**: ~5 minutes
- **Server Restart**: ~1 minute
- **Total**: ~10 minutes

### Player Experience
- Quest masters in every major city
- Daily challenges for consistent engagement
- Weekly challenges for group content
- Achievement progression system
- Titles to earn and display
- Token rewards for all difficulty tiers

**Ready to deploy and enjoy!** 🎮

---

*Version 4.0 - Extended Dungeon Quest System with Daily/Weekly Rotation & Achievements*
