/*
* DarkChaos-255 Dungeon Quest System - Daily/Weekly Quest Reset
* Version: 2.0
* 
* Handles quest reset logic:
* - Daily quest reset at server reset time
* - Weekly quest reset on server reset (configurable day)
* - Progress tracking
* - Reset notifications
*/

#include "ScriptMgr.h"
#include "Player.h"
#include "QuestDef.h"
#include "WorldSession.h"
#include "ObjectMgr.h"
#include "DatabaseEnv.h"

class npc_dungeon_quest_daily_weekly : public PlayerScript
{
public:
    npc_dungeon_quest_daily_weekly() : PlayerScript("npc_dungeon_quest_daily_weekly") { }

    // Daily reset handler (called at server reset)
    void OnPlayerLogin(Player* player) override
    {
        CheckDailyQuestReset(player);
        CheckWeeklyQuestReset(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        // Save any pending progress
        SaveQuestProgress(player);
    }

private:
    void CheckDailyQuestReset(Player* player)
    {
        // Query player's daily quest progress (use UNIX_TIMESTAMP for consistency)
        QueryResult result = CharacterDatabase.Query("SELECT daily_quest_entry, completed_today, UNIX_TIMESTAMP(last_completed) FROM player_daily_quest_progress WHERE guid = {}", player->GetGUID().GetCounter());

        if (result)
        {
            do {
                Field* fields = result->Fetch();
                uint32 dailyQuestId = fields[0].Get<uint32>();
                bool completedToday = fields[1].Get<bool>();

                // If completed, check if it's a new day
                if (completedToday)
                {
                    time_t lastCompleted = time_t(fields[2].Get<uint32>());
                    time_t now = time(nullptr);

                    // If different days or enough time has passed, reset daily quest
                    tm* timeinfo = localtime(&now);
                    tm* lastTime = localtime(&lastCompleted);

                    if (lastTime->tm_mday != timeinfo->tm_mday || (now - lastCompleted) > (24 * 3600))
                        ResetDailyQuest(player, dailyQuestId);
                }
            } while (result->NextRow());
        }
    }

    void CheckWeeklyQuestReset(Player* player)
    {
        // Query player's weekly quest progress
        QueryResult result = CharacterDatabase.Query("SELECT weekly_quest_entry, completed_this_week, UNIX_TIMESTAMP(week_reset_date) FROM player_weekly_quest_progress WHERE guid = {}", player->GetGUID().GetCounter());

        if (result)
        {
            do {
                Field* fields = result->Fetch();
                uint32 weeklyQuestId = fields[0].Get<uint32>();
                bool completedThisWeek = fields[1].Get<bool>();
                time_t weekResetDate = time_t(fields[2].Get<uint32>());

                if (completedThisWeek)
                {
                    // Check if a week has passed
                    time_t now = time(nullptr);
                    if ((now - weekResetDate) > (7 * 24 * 3600))
                        ResetWeeklyQuest(player, weeklyQuestId);
                }
            } while (result->NextRow());
        }
    }

    void ResetDailyQuest(Player* player, uint32 questId)
    {
        // Update database: mark not completed
        CharacterDatabase.Execute("UPDATE player_daily_quest_progress SET completed_today = 0 WHERE guid = {} AND daily_quest_entry = {}", player->GetGUID().GetCounter(), questId);

        // Notify player
        ChatHandler(player->GetSession()).SendSysMessage("A daily dungeon quest is now available!");
    }

    void ResetWeeklyQuest(Player* player, uint32 questId)
    {
        // Update database: mark not completed
        CharacterDatabase.Execute("UPDATE player_weekly_quest_progress SET completed_this_week = 0 WHERE guid = {} AND weekly_quest_entry = {}", player->GetGUID().GetCounter(), questId);

        // Notify player
        ChatHandler(player->GetSession()).SendSysMessage("A weekly dungeon quest is now available!");
    }

    void SaveQuestProgress(Player* player)
    {
        // Update last activity timestamp in player_dungeon_completion_stats
        CharacterDatabase.Execute("UPDATE player_dungeon_completion_stats SET last_activity = FROM_UNIXTIME({}) WHERE guid = {}", uint32(time(nullptr)), player->GetGUID().GetCounter());
    }
};

// Quest event handler for reward distribution
// The quest-reward logic is handled by DungeonQuestSystem (PlayerScript) in DungeonQuestSystem.cpp.
// Keep this file focused on player login/logout and daily/weekly reset handling.
void AddSC_npc_dungeon_quest_daily_weekly()
{
    new npc_dungeon_quest_daily_weekly();
}

/*
* PREPARED STATEMENTS NEEDED:
* 
* CHAR_SEL_PLAYER_DAILY_QUEST_PROGRESS
* SELECT daily_quest_entry, completed_today, last_completed 
* FROM player_daily_quest_progress WHERE guid = ?
* 
* CHAR_SEL_PLAYER_WEEKLY_QUEST_PROGRESS
* SELECT weekly_quest_entry, completed_this_week, week_reset_date 
* FROM player_weekly_quest_progress WHERE guid = ?
* 
* CHAR_UPD_PLAYER_DAILY_QUEST_RESET
* UPDATE player_daily_quest_progress 
* SET completed_today = 0 WHERE guid = ? AND daily_quest_entry = ?
* 
* CHAR_UPD_PLAYER_WEEKLY_QUEST_RESET
* UPDATE player_weekly_quest_progress 
* SET completed_this_week = 0 WHERE guid = ? AND weekly_quest_entry = ?
* 
* CHAR_UPD_PLAYER_DUNGEON_STATS
* UPDATE player_dungeon_completion_stats 
* SET last_activity = FROM_UNIXTIME(?) WHERE guid = ?
* 
* WORLD_SEL_DAILY_QUEST_TOKEN_REWARD
* SELECT token_id, token_count FROM dc_daily_quest_token_rewards 
* WHERE daily_quest_entry = ? AND is_active = 1
* 
* WORLD_SEL_WEEKLY_QUEST_TOKEN_REWARD
* SELECT token_id, token_count FROM dc_weekly_quest_token_rewards 
* WHERE weekly_quest_entry = ? AND is_active = 1
* 
* CHAR_UPD_DAILY_QUEST_COMPLETION
* UPDATE player_daily_quest_progress 
* SET completed_today = 1, last_completed = FROM_UNIXTIME(?) 
* WHERE guid = ? AND daily_quest_entry = ?
* 
* CHAR_UPD_WEEKLY_QUEST_COMPLETION
* UPDATE player_weekly_quest_progress 
* SET completed_this_week = 1, last_completed = FROM_UNIXTIME(?), week_reset_date = FROM_UNIXTIME(?) 
* WHERE guid = ? AND weekly_quest_entry = ?
*/
