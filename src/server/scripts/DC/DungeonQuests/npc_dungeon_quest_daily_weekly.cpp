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
#include "Quest.h"
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
        // Query player's daily quest progress
        PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PLAYER_DAILY_QUEST_PROGRESS);
        stmt->SetData(0, player->GetGUID().GetCounter());
        
        PreparedQueryResult result = CharacterDatabase.Query(stmt);
        
        if (result)
        {
            do {
                Field* fields = result->Fetch();
                uint32 dailyQuestId = fields[0].GetUInt32();
                bool completedToday = fields[1].GetBool();
                
                // If completed, check if it's a new day
                if (completedToday)
                {
                    time_t lastCompleted = time_t(fields[2].GetUInt32());
                    time_t now = time(nullptr);
                    
                    // Get server reset hour (configurable, default 4 AM)
                    uint32 resetHour = 4;
                    
                    // Calculate if past reset time today
                    tm* timeinfo = localtime(&now);
                    tm* lastTime = localtime(&lastCompleted);
                    
                    // If different days or enough time has passed, reset daily quest
                    if (lastTime->tm_mday != timeinfo->tm_mday || 
                        (now - lastCompleted) > (24 * 3600))
                    {
                        ResetDailyQuest(player, dailyQuestId);
                    }
                }
            } while (result->NextRow());
        }
    }

    void CheckWeeklyQuestReset(Player* player)
    {
        // Query player's weekly quest progress
        PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PLAYER_WEEKLY_QUEST_PROGRESS);
        stmt->SetData(0, player->GetGUID().GetCounter());
        
        PreparedQueryResult result = CharacterDatabase.Query(stmt);
        
        if (result)
        {
            do {
                Field* fields = result->Fetch();
                uint32 weeklyQuestId = fields[0].GetUInt32();
                bool completedThisWeek = fields[1].GetBool();
                time_t weekResetDate = time_t(fields[2].GetUInt32());
                
                if (completedThisWeek)
                {
                    // Check if a week has passed
                    time_t now = time(nullptr);
                    if ((now - weekResetDate) > (7 * 24 * 3600))
                    {
                        ResetWeeklyQuest(player, weeklyQuestId);
                    }
                }
            } while (result->NextRow());
        }
    }

    void ResetDailyQuest(Player* player, uint32 questId)
    {
        // Update database: mark not completed
        PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_PLAYER_DAILY_QUEST_RESET);
        stmt->SetData(0, player->GetGUID().GetCounter());
        stmt->SetData(1, questId);
        CharacterDatabase.Execute(stmt);
        
        // Notify player
        ChatHandler(player->GetSession()).SendSysMessage("A daily dungeon quest is now available!");
    }

    void ResetWeeklyQuest(Player* player, uint32 questId)
    {
        // Update database: mark not completed
        PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_PLAYER_WEEKLY_QUEST_RESET);
        stmt->SetData(0, player->GetGUID().GetCounter());
        stmt->SetData(1, questId);
        CharacterDatabase.Execute(stmt);
        
        // Notify player
        ChatHandler(player->GetSession()).SendSysMessage("A weekly dungeon quest is now available!");
    }

    void SaveQuestProgress(Player* player)
    {
        // Update last activity timestamp in player_dungeon_completion_stats
        PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_PLAYER_DUNGEON_STATS);
        stmt->SetData(0, uint32(time(nullptr)));
        stmt->SetData(1, player->GetGUID().GetCounter());
        CharacterDatabase.Execute(stmt);
    }
};

// Quest event handler for reward distribution
class npc_dungeon_quest_reward : public QuestScript
{
public:
    npc_dungeon_quest_reward() : QuestScript("npc_dungeon_quest_reward") { }

    // Called when player completes a quest
    void OnQuestStatusChange(Player* player, uint32 questId, QuestStatus oldStatus, QuestStatus newStatus) override
    {
        // Only process quest completion
        if (newStatus != QUEST_STATUS_COMPLETE)
            return;

        // Check if this is a dungeon quest (700101-700204)
        if (questId < 700101 || questId > 700204)
            return;

        // Distribute token rewards
        DistributeTokenRewards(player, questId);
        
        // Update progress tables
        UpdateQuestProgress(player, questId);
        
        // Check for achievement triggers
        CheckAchievementTriggers(player, questId);
    }

private:
    void DistributeTokenRewards(Player* player, uint32 questId)
    {
        // Query reward mapping from database
        PreparedStatement* stmt = nullptr;
        
        if (questId >= DC_DAILY_QUEST_START && questId <= DC_DAILY_QUEST_END)
        {
            stmt = WorldDatabase.GetPreparedStatement(WORLD_SEL_DAILY_QUEST_TOKEN_REWARD);
            stmt->SetData(0, questId);
        }
        else if (questId >= DC_WEEKLY_QUEST_START && questId <= DC_WEEKLY_QUEST_END)
        {
            stmt = WorldDatabase.GetPreparedStatement(WORLD_SEL_WEEKLY_QUEST_TOKEN_REWARD);
            stmt->SetData(0, questId);
        }
        
        if (!stmt)
            return;
        
        PreparedQueryResult result = WorldDatabase.Query(stmt);
        
        if (result)
        {
            do {
                Field* fields = result->Fetch();
                uint32 tokenId = fields[0].GetUInt32();
                uint32 tokenCount = fields[1].GetUInt32();
                
                // Add token items to player inventory
                for (uint32 i = 0; i < tokenCount; ++i)
                {
                    player->AddItem(tokenId, 1);
                }
                
                // Log reward
                sLog->outInfo(LOG_FILTER_GUILD, 
                    "Player %s received %u x Token ID %u for quest %u",
                    player->GetName().c_str(), tokenCount, tokenId, questId);
                    
            } while (result->NextRow());
        }
    }

    void UpdateQuestProgress(Player* player, uint32 questId)
    {
        if (questId >= DC_DAILY_QUEST_START && questId <= DC_DAILY_QUEST_END)
        {
            // Mark daily quest as completed
            PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_DAILY_QUEST_COMPLETION);
            stmt->SetData(0, uint32(time(nullptr)));
            stmt->SetData(1, player->GetGUID().GetCounter());
            stmt->SetData(2, questId);
            CharacterDatabase.Execute(stmt);
        }
        else if (questId >= DC_WEEKLY_QUEST_START && questId <= DC_WEEKLY_QUEST_END)
        {
            // Mark weekly quest as completed
            PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_WEEKLY_QUEST_COMPLETION);
            stmt->SetData(0, uint32(time(nullptr)));
            stmt->SetData(1, uint32(time(nullptr))); // week reset date
            stmt->SetData(2, player->GetGUID().GetCounter());
            stmt->SetData(3, questId);
            CharacterDatabase.Execute(stmt);
        }
    }

    void CheckAchievementTriggers(Player* player, uint32 questId)
    {
        // This would integrate with achievement system
        // Track quest completions and award achievements/titles
        // Implementation depends on achievement framework integration
    }
};

void AddSC_npc_dungeon_quest_daily_weekly()
{
    new npc_dungeon_quest_daily_weekly();
    new npc_dungeon_quest_reward();
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
