# 🔧 C++ INTEGRATION GUIDE - Difficulty & Achievement System
**Code Updates for DungeonQuestSystem.cpp and Related Files**

---

## 📝 Overview

This guide provides **ready-to-use C++ code** to integrate the v4.0 extension features:
- ✅ Difficulty detection and multipliers
- ✅ Per-difficulty statistics tracking
- ✅ Achievement auto-completion (10800-10999)
- ✅ Streak tracking (daily/weekly)
- ✅ Perfect run detection

**Files to Update**:
1. `DungeonQuestSystem.cpp` (main updates)
2. `npc_dungeon_quest_daily_weekly.cpp` (streak tracking)
3. `dc_achievements.cpp` (optional - alternative approach)

---

## 🔨 File 1: DungeonQuestSystem.cpp

### Step 1: Add Difficulty Enum (After Line 30)

**Location**: After quest range constants

```cpp
// Quest ID ranges
constexpr uint32 QUEST_DAILY_MIN = 700101;
constexpr uint32 QUEST_DAILY_MAX = 700150;  // UPDATED
constexpr uint32 QUEST_WEEKLY_MIN = 700201;
constexpr uint32 QUEST_WEEKLY_MAX = 700224; // UPDATED
constexpr uint32 QUEST_DUNGEON_MIN = 700701;
constexpr uint32 QUEST_DUNGEON_MAX = 700999;

// NEW: Achievement ID range
constexpr uint32 ACHIEVEMENT_DUNGEON_MIN = 10800;
constexpr uint32 ACHIEVEMENT_DUNGEON_MAX = 10999;

// NEW: Difficulty enumeration
enum QuestDifficulty
{
    DIFFICULTY_NORMAL = 0,
    DIFFICULTY_HEROIC = 1,
    DIFFICULTY_MYTHIC = 2,
    DIFFICULTY_MYTHIC_PLUS = 3
};
```

### Step 2: Add New Helper Functions to DungeonQuestDB Class

**Location**: Inside `class DungeonQuestDB` (around line 50)

```cpp
class DungeonQuestDB
{
public:
    // ... existing functions ...

    // NEW: Get difficulty from quest ID
    static QuestDifficulty GetQuestDifficulty(uint32 questId)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT difficulty FROM dc_quest_difficulty_mapping WHERE quest_id = {}", questId
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            std::string diff = fields[0].Get<std::string>();
            
            if (diff == "Heroic") return DIFFICULTY_HEROIC;
            if (diff == "Mythic") return DIFFICULTY_MYTHIC;
            if (diff == "Mythic+") return DIFFICULTY_MYTHIC_PLUS;
        }
        
        return DIFFICULTY_NORMAL;
    }
    
    // NEW: Get difficulty configuration
    static float GetDifficultyTokenMultiplier(QuestDifficulty difficulty)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT token_multiplier FROM dc_difficulty_config WHERE difficulty_id = {}", 
            static_cast<uint32>(difficulty) + 1
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<float>();
        }
        
        return 1.0f;
    }
    
    static float GetDifficultyGoldMultiplier(QuestDifficulty difficulty)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT gold_multiplier FROM dc_difficulty_config WHERE difficulty_id = {}", 
            static_cast<uint32>(difficulty) + 1
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<float>();
        }
        
        return 1.0f;
    }
    
    // NEW: Update difficulty-specific statistics
    static void UpdateDifficultyStatistics(Player* player, QuestDifficulty difficulty)
    {
        if (!player)
            return;
            
        std::string statName;
        switch (difficulty)
        {
            case DIFFICULTY_HEROIC:
                statName = "heroic_quests_completed";
                break;
            case DIFFICULTY_MYTHIC:
                statName = "mythic_quests_completed";
                break;
            case DIFFICULTY_MYTHIC_PLUS:
                statName = "mythic_plus_quests_completed";
                break;
            default:
                return; // Don't track Normal separately
        }
        
        UpdateStatistics(player, statName, 1);
        
        LOG_DEBUG("scripts", "DungeonQuest: Updated {} for player {}", 
                  statName, player->GetName());
    }
    
    // NEW: Get dungeon ID from quest ID
    static uint32 GetDungeonIdFromQuest(uint32 questId)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT dungeon_id FROM dc_quest_difficulty_mapping WHERE quest_id = {}", questId
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }
        
        return 0;
    }
    
    // NEW: Track difficulty completion
    static void TrackDifficultyCompletion(Player* player, uint32 dungeonId, QuestDifficulty difficulty, uint32 timeTaken = 0, bool died = false)
    {
        if (!player || dungeonId == 0)
            return;
        
        std::string difficultyStr = "Normal";
        switch (difficulty)
        {
            case DIFFICULTY_HEROIC: difficultyStr = "Heroic"; break;
            case DIFFICULTY_MYTHIC: difficultyStr = "Mythic"; break;
            case DIFFICULTY_MYTHIC_PLUS: difficultyStr = "Mythic+"; break;
            default: break;
        }
        
        // Update completion tracking
        CharacterDatabase.Execute(
            "INSERT INTO dc_character_difficulty_completions "
            "(guid, dungeon_id, difficulty, total_completions, best_time_seconds, fastest_completion_date, last_completion_date, total_deaths, perfect_runs) "
            "VALUES ({}, {}, '{}', 1, {}, NOW(), NOW(), {}, {}) "
            "ON DUPLICATE KEY UPDATE "
            "total_completions = total_completions + 1, "
            "best_time_seconds = IF({} > 0 AND ({} < best_time_seconds OR best_time_seconds = 0), {}, best_time_seconds), "
            "fastest_completion_date = IF({} > 0 AND ({} < best_time_seconds OR best_time_seconds = 0), NOW(), fastest_completion_date), "
            "last_completion_date = NOW(), "
            "total_deaths = total_deaths + {}, "
            "perfect_runs = perfect_runs + {}",
            player->GetGUID().GetCounter(),
            dungeonId,
            difficultyStr,
            timeTaken,
            died ? 1 : 0,
            died ? 0 : 1,
            timeTaken, timeTaken,
            timeTaken,
            timeTaken, timeTaken,
            died ? 1 : 0,
            (died || timeTaken == 0) ? 0 : 1
        );
    }
    
    // NEW: Update daily streak
    static void UpdateDailyStreak(Player* player)
    {
        if (!player)
            return;
            
        QueryResult result = CharacterDatabase.Query(
            "SELECT stat_value, last_update FROM dc_character_dungeon_statistics "
            "WHERE guid = {} AND stat_name = 'daily_streak_current'",
            player->GetGUID().GetCounter()
        );
        
        uint32 currentStreak = 0;
        time_t lastUpdate = 0;
        
        if (result)
        {
            Field* fields = result->Fetch();
            currentStreak = fields[0].Get<uint32>();
            lastUpdate = fields[1].Get<uint32>();
        }
        
        time_t now = time(nullptr);
        time_t timeDiff = now - lastUpdate;
        
        // If completed within 48 hours (allows for timezone/timing differences)
        if (timeDiff <= (48 * 3600))
        {
            // Continue streak
            currentStreak++;
            
            CharacterDatabase.Execute(
                "INSERT INTO dc_character_dungeon_statistics "
                "(guid, stat_name, stat_value, last_update) "
                "VALUES ({}, 'daily_streak_current', {}, NOW()) "
                "ON DUPLICATE KEY UPDATE stat_value = {}, last_update = NOW()",
                player->GetGUID().GetCounter(),
                currentStreak,
                currentStreak
            );
            
            // Update longest streak if needed
            QueryResult longestResult = CharacterDatabase.Query(
                "SELECT stat_value FROM dc_character_dungeon_statistics "
                "WHERE guid = {} AND stat_name = 'daily_streak_longest'",
                player->GetGUID().GetCounter()
            );
            
            uint32 longestStreak = 0;
            if (longestResult)
            {
                longestStreak = longestResult->Fetch()[0].Get<uint32>();
            }
            
            if (currentStreak > longestStreak)
            {
                CharacterDatabase.Execute(
                    "INSERT INTO dc_character_dungeon_statistics "
                    "(guid, stat_name, stat_value, last_update) "
                    "VALUES ({}, 'daily_streak_longest', {}, NOW()) "
                    "ON DUPLICATE KEY UPDATE stat_value = {}, last_update = NOW()",
                    player->GetGUID().GetCounter(),
                    currentStreak,
                    currentStreak
                );
            }
            
            LOG_INFO("scripts", "DungeonQuest: Player {} daily streak: {}", 
                     player->GetName(), currentStreak);
        }
        else if (timeDiff > (48 * 3600))
        {
            // Streak broken - reset to 1
            CharacterDatabase.Execute(
                "INSERT INTO dc_character_dungeon_statistics "
                "(guid, stat_name, stat_value, last_update) "
                "VALUES ({}, 'daily_streak_current', 1, NOW()) "
                "ON DUPLICATE KEY UPDATE stat_value = 1, last_update = NOW()",
                player->GetGUID().GetCounter()
            );
            
            LOG_INFO("scripts", "DungeonQuest: Player {} streak broken, reset to 1", 
                     player->GetName());
        }
    }
};
```

### Step 3: Update HandleTokenRewards Function

**Location**: Find `void HandleTokenRewards(...)` function (around line 200)

**Replace the entire function with**:

```cpp
void HandleTokenRewards(Player* player, uint32 questId, bool isDailyQuest, bool isWeeklyQuest)
{
    uint32 tokenAmount = 0;
    uint32 tokenItemId = DungeonQuestDB::GetTokenItemId();

    if (tokenItemId == 0)
    {
        LOG_DEBUG("scripts", "DungeonQuest: No token item configured, skipping token rewards");
        return;
    }

    // Get base token amount from database
    if (isDailyQuest)
    {
        tokenAmount = DungeonQuestDB::GetDailyQuestTokenReward(questId);
    }
    else if (isWeeklyQuest)
    {
        tokenAmount = DungeonQuestDB::GetWeeklyQuestTokenReward(questId);
    }

    if (tokenAmount == 0)
    {
        LOG_DEBUG("scripts", "DungeonQuest: No token reward configured for quest {}", questId);
        return;
    }

    // NEW: Get difficulty and apply multiplier
    QuestDifficulty difficulty = DungeonQuestDB::GetQuestDifficulty(questId);
    float multiplier = DungeonQuestDB::GetDifficultyTokenMultiplier(difficulty);
    
    // Calculate final token amount
    uint32 finalTokenAmount = static_cast<uint32>(tokenAmount * multiplier);
    
    LOG_INFO("scripts", "DungeonQuest: Quest {} base={} tokens, difficulty multiplier={:.2f}, final={} tokens", 
             questId, tokenAmount, multiplier, finalTokenAmount);

    // Award tokens to player
    if (finalTokenAmount > 0)
    {
        if (player->AddItem(tokenItemId, finalTokenAmount))
        {
            // Build difficulty message
            std::string difficultyText = "";
            if (difficulty == DIFFICULTY_HEROIC)
                difficultyText = " |cFFFFD700(Heroic +50% bonus)|r";
            else if (difficulty == DIFFICULTY_MYTHIC)
                difficultyText = " |cFFFF4500(Mythic +100% bonus)|r";
            else if (difficulty == DIFFICULTY_MYTHIC_PLUS)
                difficultyText = " |cFFDC143C(Mythic+ +200% bonus)|r";
            
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFF00FF00You have been awarded %u Dungeon Tokens!|r%s", 
                finalTokenAmount, 
                difficultyText.c_str()
            );
            
            LOG_INFO("scripts", "DungeonQuest: Awarded {} tokens (item {}) to player {}", 
                     finalTokenAmount, tokenItemId, player->GetName());
        }
        else
        {
            LOG_ERROR("scripts", "DungeonQuest: Failed to add token item {} to player {}", 
                     tokenItemId, player->GetName());
        }
    }
    
    // NEW: Track difficulty completion
    uint32 dungeonId = DungeonQuestDB::GetDungeonIdFromQuest(questId);
    if (dungeonId > 0)
    {
        DungeonQuestDB::TrackDifficultyCompletion(player, dungeonId, difficulty);
    }
    
    // NEW: Update difficulty statistics
    DungeonQuestDB::UpdateDifficultyStatistics(player, difficulty);
    
    // NEW: Update daily streak for daily quests
    if (isDailyQuest)
    {
        DungeonQuestDB::UpdateDailyStreak(player);
    }
}
```

### Step 4: Update CheckAchievements Function

**Location**: Find `void CheckAchievements(...)` function (around line 280)

**Add after existing achievement checks**:

```cpp
void CheckAchievements(Player* player, uint32 questId, bool isDailyQuest, bool isWeeklyQuest, bool isDungeonQuest)
{
    if (!player)
        return;

    // ... KEEP EXISTING ACHIEVEMENT CHECKS (13500-13514) ...
    
    // ========================================================================
    // NEW: EXPANDED ACHIEVEMENT SYSTEM (10800-10999)
    // ========================================================================
    
    // Quest Milestone Achievements (10800-10807)
    uint32 totalQuests = DungeonQuestDB::GetTotalQuestCompletions(player);
    
    if (totalQuests == 1)
        AwardAchievement(player, 10800, "First Steps");
    else if (totalQuests == 10)
        AwardAchievement(player, 10801, "Quest Explorer");
    else if (totalQuests == 25)
        AwardAchievement(player, 10802, "Quest Veteran");
    else if (totalQuests == 50)
        AwardAchievement(player, 10803, "Quest Master");
    else if (totalQuests == 100)
        AwardAchievement(player, 10804, "Dungeon Enthusiast");
    else if (totalQuests == 250)
        AwardAchievement(player, 10805, "Dungeon Legend");
    else if (totalQuests == 500)
        AwardAchievement(player, 10806, "Dungeon Hero");
    else if (totalQuests == 1000)
        AwardAchievement(player, 10807, "Dungeon Overlord");
    
    // Difficulty Achievements (10820-10842)
    QuestDifficulty difficulty = DungeonQuestDB::GetQuestDifficulty(questId);
    
    if (difficulty == DIFFICULTY_HEROIC)
    {
        uint32 heroicCount = DungeonQuestDB::GetStatisticValue(player, "heroic_quests_completed");
        
        if (heroicCount == 10)
            AwardAchievement(player, 10820, "Heroic Initiate");
        else if (heroicCount == 25)
            AwardAchievement(player, 10821, "Heroic Veteran");
        else if (heroicCount == 50)
            AwardAchievement(player, 10822, "Heroic Champion");
        else if (heroicCount == 100)
            AwardAchievement(player, 10823, "Heroic Conqueror");
        else if (heroicCount == 250)
            AwardAchievement(player, 10824, "Heroic Legend");
    }
    else if (difficulty == DIFFICULTY_MYTHIC)
    {
        uint32 mythicCount = DungeonQuestDB::GetStatisticValue(player, "mythic_quests_completed");
        
        if (mythicCount == 10)
            AwardAchievement(player, 10830, "Mythic Initiate");
        else if (mythicCount == 25)
            AwardAchievement(player, 10831, "Mythic Veteran");
        else if (mythicCount == 50)
            AwardAchievement(player, 10832, "Mythic Champion");
        else if (mythicCount == 100)
            AwardAchievement(player, 10833, "Mythic Conqueror");
        else if (mythicCount == 250)
            AwardAchievement(player, 10834, "Mythic Legend");
    }
    else if (difficulty == DIFFICULTY_MYTHIC_PLUS)
    {
        uint32 mythicPlusCount = DungeonQuestDB::GetStatisticValue(player, "mythic_plus_quests_completed");
        
        if (mythicPlusCount == 5)
            AwardAchievement(player, 10840, "Mythic+ Pioneer");
        else if (mythicPlusCount == 25)
            AwardAchievement(player, 10841, "Mythic+ Master");
        else if (mythicPlusCount == 100)
            AwardAchievement(player, 10842, "Mythic+ God");
    }
    
    // Daily Quest Achievements (10850-10866)
    if (isDailyQuest)
    {
        uint32 dailyCount = DungeonQuestDB::GetStatisticValue(player, "daily_quests_completed");
        
        if (dailyCount == 10)
            AwardAchievement(player, 10850, "Daily Dedication");
        else if (dailyCount == 25)
            AwardAchievement(player, 10851, "Daily Devotion");
        else if (dailyCount == 50)
            AwardAchievement(player, 10852, "Daily Champion");
        else if (dailyCount == 100)
            AwardAchievement(player, 10853, "Daily Legend");
        else if (dailyCount == 250)
            AwardAchievement(player, 10854, "Daily Master");
        else if (dailyCount == 500)
            AwardAchievement(player, 10855, "Daily Overlord");
        
        // Daily Streak Achievements (10860-10866)
        uint32 currentStreak = DungeonQuestDB::GetStatisticValue(player, "daily_streak_current");
        
        if (currentStreak == 3)
            AwardAchievement(player, 10860, "3-Day Streak");
        else if (currentStreak == 7)
            AwardAchievement(player, 10861, "7-Day Streak");
        else if (currentStreak == 14)
            AwardAchievement(player, 10862, "14-Day Streak");
        else if (currentStreak == 30)
            AwardAchievement(player, 10863, "30-Day Streak");
        else if (currentStreak == 60)
            AwardAchievement(player, 10864, "60-Day Streak");
        else if (currentStreak == 90)
            AwardAchievement(player, 10865, "90-Day Streak");
        else if (currentStreak == 365)
            AwardAchievement(player, 10866, "Year of Dedication");
    }
    
    // Weekly Quest Achievements (10870-10874)
    if (isWeeklyQuest)
    {
        uint32 weeklyCount = DungeonQuestDB::GetStatisticValue(player, "weekly_quests_completed");
        
        if (weeklyCount == 5)
            AwardAchievement(player, 10870, "Weekly Warrior");
        else if (weeklyCount == 10)
            AwardAchievement(player, 10871, "Weekly Champion");
        else if (weeklyCount == 25)
            AwardAchievement(player, 10872, "Weekly Legend");
        else if (weeklyCount == 50)
            AwardAchievement(player, 10873, "Weekly Master");
        else if (weeklyCount == 100)
            AwardAchievement(player, 10874, "Weekly Overlord");
    }
    
    LOG_DEBUG("scripts", "DungeonQuest: Completed achievement checks for player {} quest {}", 
              player->GetName(), questId);
}
```

---

## 🔨 File 2: npc_dungeon_quest_daily_weekly.cpp

### Update CheckDailyQuestReset Function

**Location**: Find `void CheckDailyQuestReset(Player* player)` (around line 30)

**Add streak tracking** at the end of the function:

```cpp
void CheckDailyQuestReset(Player* player)
{
    // ... KEEP EXISTING RESET LOGIC ...
    
    // NEW: Check and update daily streak
    QueryResult result = CharacterDatabase.Query(
        "SELECT UNIX_TIMESTAMP(last_update) FROM dc_character_dungeon_statistics "
        "WHERE guid = {} AND stat_name = 'daily_streak_current'",
        player->GetGUID().GetCounter()
    );
    
    if (result)
    {
        time_t lastUpdate = result->Fetch()[0].Get<uint64>();
        time_t now = time(nullptr);
        time_t timeDiff = now - lastUpdate;
        
        // If more than 48 hours since last daily, streak is broken
        if (timeDiff > (48 * 3600))
        {
            CharacterDatabase.Execute(
                "UPDATE dc_character_dungeon_statistics "
                "SET stat_value = 0, last_update = NOW() "
                "WHERE guid = {} AND stat_name = 'daily_streak_current'",
                player->GetGUID().GetCounter()
            );
            
            LOG_INFO("scripts", "DungeonQuest: Daily streak broken for player {} ({}h since last)", 
                     player->GetName(), timeDiff / 3600);
        }
    }
}
```

---

## 🧪 Testing Commands

### Test Difficulty Detection
```cpp
// Add to your test function
QuestDifficulty diff = DungeonQuestDB::GetQuestDifficulty(700205);
LOG_INFO("scripts", "Quest 700205 difficulty: {}", static_cast<uint32>(diff));
```

### Test Multipliers
```cpp
float tokenMult = DungeonQuestDB::GetDifficultyTokenMultiplier(DIFFICULTY_HEROIC);
LOG_INFO("scripts", "Heroic token multiplier: {:.2f}", tokenMult);
```

### Test Achievement Award
```cpp
// Award test achievement
AwardAchievement(player, 10800, "First Steps");
```

---

## ✅ Verification Checklist

After implementing changes, verify:

- [ ] Code compiles without errors
- [ ] Server starts successfully
- [ ] Quest completion works
- [ ] Token rewards show difficulty bonus
- [ ] Achievements auto-complete at milestones
- [ ] Daily streak tracking works
- [ ] Difficulty statistics update correctly
- [ ] No crashes or errors in logs

---

## 📊 Debug Logging

Add these lines for debugging:

```cpp
// In HandleTokenRewards
LOG_DEBUG("scripts", "Quest {} difficulty: {}, multiplier: {:.2f}", 
          questId, static_cast<uint32>(difficulty), multiplier);

// In CheckAchievements
LOG_DEBUG("scripts", "Total quests: {}, Heroic: {}, Mythic: {}", 
          totalQuests, heroicCount, mythicCount);

// In UpdateDailyStreak
LOG_DEBUG("scripts", "Current streak: {}, Last update: {} hours ago", 
          currentStreak, timeDiff / 3600);
```

---

## 🎯 Next Steps

1. **Compile and Test**: Build server with changes
2. **Test Quest Completion**: Complete a daily/weekly quest
3. **Verify Multipliers**: Check if Heroic gives 50% bonus
4. **Test Achievements**: Complete quests to trigger achievements
5. **Monitor Logs**: Watch for any errors or warnings
6. **Adjust as Needed**: Fine-tune multipliers and thresholds

---

**Ready to integrate!** Copy the code sections into your files and compile. 🚀
