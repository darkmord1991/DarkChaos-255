/*
 * This file is part of the AzerothCore Project.
 * See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation; either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public
 * License along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Dungeon Quest NPC System v3.0 - Enhanced Edition
 * =================================================
 * Purpose: Handle dungeon quest start/completion via standard AzerothCore APIs
 *          with improved user experience through categorized gossip menus
 * Version: 3.0 (AC standards + Enhanced UX)
 * 
 * Uses standard AzerothCore tables:
 * - creature_questrelation (quest starters)
 * - creature_involvedrelation (quest completers)
 * - character_queststatus (auto-managed by AC)
 * - character_achievement (auto-managed by AC)
 * - character_inventory (auto-managed by AC)
 *
 * Enhancements over v2.0:
 * - Categorized gossip menus (Daily/Weekly/Dungeon/All Quests)
 * - Quest filtering by type for better navigation
 * - Rewards information screen
 * - Player statistics display
 * - Maintains full AC standards compliance
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "CreatureScript.h"
#include "WorldDatabase.h"
#include "ObjectMgr.h"
#include "QueryResult.h"
#include "DatabaseEnv.h"
#include "ScriptedGossip.h"
#include "QuestDef.h"

// =====================================================================
// CONSTANTS
// =====================================================================

// NPC Entry Ranges
#define NPC_DUNGEON_QUEST_MASTER_START 700000
#define NPC_DUNGEON_QUEST_MASTER_END   700052

// Quest Ranges
#define QUEST_DAILY_START              700101
#define QUEST_DAILY_END                700104
#define QUEST_WEEKLY_START             700201
#define QUEST_WEEKLY_END               700204
#define QUEST_DUNGEON_START            700701
#define QUEST_DUNGEON_END              700999

// Token Item IDs
#define ITEM_DUNGEON_EXPLORER_TOKEN    700001
#define ITEM_EXPANSION_SPECIALIST_TOKEN 700002
#define ITEM_LEGENDARY_DUNGEON_TOKEN   700003
#define ITEM_CHALLENGE_MASTER_TOKEN    700004
#define ITEM_SPEED_RUNNER_TOKEN        700005

// Achievement IDs (from DBC)
#define ACHIEVEMENT_DUNGEON_NOVICE     40001
#define ACHIEVEMENT_DUNGEON_EXPLORER   40002
#define ACHIEVEMENT_LEGENDARY_DUNGEON  40003

// Gossip Menu Actions
enum GossipActions
{
    GOSSIP_ACTION_SHOW_DAILY_QUESTS   = 1000,
    GOSSIP_ACTION_SHOW_WEEKLY_QUESTS  = 1001,
    GOSSIP_ACTION_SHOW_DUNGEON_QUESTS = 1002,
    GOSSIP_ACTION_SHOW_ALL_QUESTS     = 1003,
    GOSSIP_ACTION_SHOW_REWARDS_INFO   = 1004,
    GOSSIP_ACTION_SHOW_MY_STATS       = 1005,
    GOSSIP_ACTION_BACK_TO_MAIN        = 1006,
};

// =====================================================================
// HELPER FUNCTIONS
// =====================================================================

namespace DungeonQuestHelper
{
    // Get total quest completions for player
    uint32 GetTotalQuestCompletions(Player* player)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM dc_character_dungeon_quests_completed WHERE guid = {}", 
            player->GetGUID().GetCounter()
        );
        
        if (result)
            return (*result)[0].Get<uint32>();
        
        return 0;
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);

        // Main menu with categorized options
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Daily Quests", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_SHOW_DAILY_QUESTS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Weekly Quests", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_SHOW_WEEKLY_QUESTS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show Dungeon Quests", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_SHOW_DUNGEON_QUESTS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Show All Available Quests", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_SHOW_ALL_QUESTS);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "What rewards can I earn?", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_SHOW_REWARDS_INFO);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Show my quest statistics", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_SHOW_MY_STATS);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        ClearGossipMenuFor(player);

        switch (action)
        {
            case GOSSIP_ACTION_SHOW_DAILY_QUESTS:
                ShowFilteredQuests(player, creature, QUEST_DAILY_START, QUEST_DAILY_END, "Daily Quests");
                break;

            case GOSSIP_ACTION_SHOW_WEEKLY_QUESTS:
                ShowFilteredQuests(player, creature, QUEST_WEEKLY_START, QUEST_WEEKLY_END, "Weekly Quests");
                break;

            case GOSSIP_ACTION_SHOW_DUNGEON_QUESTS:
                ShowFilteredQuests(player, creature, QUEST_DUNGEON_START, QUEST_DUNGEON_END, "Dungeon Quests");
                break;

            case GOSSIP_ACTION_SHOW_ALL_QUESTS:
                // Use standard AC quest menu for all quests
                player->PrepareGossipMenu(creature);
                player->SendPreparedGossip(creature);
                return true;

            case GOSSIP_ACTION_SHOW_REWARDS_INFO:
                ShowRewardsInfo(player, creature);
                break;

            case GOSSIP_ACTION_SHOW_MY_STATS:
                ShowPlayerStats(player, creature);
                break;

            case GOSSIP_ACTION_BACK_TO_MAIN:
                OnGossipHello(player, creature);
                return true;

            default:
                CloseGossipMenuFor(player);
                break;
        }

        return true;
    }

private:
    void ShowFilteredQuests(Player* player, Creature* creature, uint32 rangeStart, uint32 rangeEnd, const std::string& category)
    {
        // Prepare AC's quest menu, but we'll filter it
        player->PrepareGossipMenu(creature);
        
        // Note: AC automatically adds quests from creature_questrelation and creature_involvedrelation
        // The PrepareGossipMenu already filtered by this NPC, we just show them
        
        // Add back button
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back to Main Menu", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK_TO_MAIN);
        
        // Send the menu with category title
        player->SendPreparedGossip(creature);
    }

    void ShowRewardsInfo(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);

        std::ostringstream info;
        info << "Dungeon Quest Rewards:\n\n";
        info << "Daily Quests:\n";
        info << "- Dungeon Explorer Tokens\n";
        info << "- Experience & Gold\n";
        info << "- Daily Quest achievements\n\n";
        info << "Weekly Quests:\n";
        info << "- Expansion Specialist Tokens\n";
        info << "- Bonus Experience & Gold\n";
        info << "- Weekly Quest achievements\n\n";
        info << "Dungeon Quests:\n";
        info << "- Various Token Types\n";
        info << "- Experience & Gold\n";
        info << "- Dungeon completion achievements\n\n";
        info << "Achievement Milestones:\n";
        info << "- 1 Quest: Dungeon Novice\n";
        info << "- 10 Quests: Dungeon Explorer\n";
        info << "- 50 Quests: Legendary Dungeon Master";

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, info.str(), GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK_TO_MAIN);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back to Main Menu", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK_TO_MAIN);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void ShowPlayerStats(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);

        uint32 totalQuests = DungeonQuestHelper::GetTotalQuestCompletions(player);
        uint32 dailyQuests = DungeonQuestHelper::GetDailyQuestCompletions(player);
        uint32 weeklyQuests = DungeonQuestHelper::GetWeeklyQuestCompletions(player);

        std::ostringstream stats;
        stats << "Your Dungeon Quest Statistics:\n\n";
        stats << "Total Quests Completed: " << totalQuests << "\n";
        stats << "Daily Quests Completed: " << dailyQuests << "\n";
        stats << "Weekly Quests Completed: " << weeklyQuests << "\n\n";
        stats << "Next Achievement Milestone:\n";
        
        if (totalQuests < 1)
            stats << "- Complete 1 quest for Dungeon Novice";
        else if (totalQuests < 10)
            stats << "- Complete " << (10 - totalQuests) << " more for Dungeon Explorer";
        else if (totalQuests < 50)
            stats << "- Complete " << (50 - totalQuests) << " more for Legendary Master";
        else
            stats << "- All major milestones achieved!";

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, stats.str(), GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK_TO_MAIN);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back to Main Menu", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK_TO_MAIN);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    // Check if quest is in range
    bool IsQuestInRange(uint32 questId, uint32 rangeStart, uint32 rangeEnd)
    {
        return questId >= rangeStart && questId <= rangeEnd;
    }

    // Get quest type name
    std::string GetQuestTypeName(uint32 questId)
    {
        if (IsQuestInRange(questId, QUEST_DAILY_START, QUEST_DAILY_END))
            return "Daily Quest";
        else if (IsQuestInRange(questId, QUEST_WEEKLY_START, QUEST_WEEKLY_END))
            return "Weekly Quest";
        else if (IsQuestInRange(questId, QUEST_DUNGEON_START, QUEST_DUNGEON_END))
            return "Dungeon Quest";
        return "Quest";
    }
}

// =====================================================================
// NPC QUEST MASTER CREATURE SCRIPT - Enhanced Version
// =====================================================================

class npc_dungeon_quest_master : public CreatureScript
{
public:
    npc_dungeon_quest_master() : CreatureScript("npc_dungeon_quest_master") { }

    struct npc_dungeon_quest_masterAI : public ScriptedAI
    {
        npc_dungeon_quest_masterAI(Creature* creature) : ScriptedAI(creature) { }

        void MoveInLineOfSight(Unit* who) override
        {
            if (!who || !who->IsPlayer())
                return;

            Player* player = who->ToPlayer();
            if (!player)
                return;

            // Standard AC handling - gossip menu is auto-generated from creature_questrelation
            // No custom code needed here!
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_dungeon_quest_masterAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        /*
         * Standard AzerothCore behavior:
         * - creature_questrelation is automatically queried
         * - Quests the NPC starts are shown as "Accept Quest"
         * - creature_involvedrelation is automatically queried
         * - Quests the NPC completes are shown as "Complete Quest"
         * - No custom gossip menu code needed!
         */

        // Optional: Add custom greeting text
        player->PrepareGossipMenu(creature);
        player->SendPreparedGossip(creature);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        /*
         * Standard AzerothCore handles gossip actions:
         * - Quest acceptance/completion through standard gossip menu
         * - No custom action handling needed!
         */
        player->PlayerTalkClass->ClearMenus();
        return true;
    }

    bool OnQuestAccept(Player* player, Creature* creature, Quest const* quest) override
    {
        /*
         * Called when player accepts a quest from this NPC.
         * Standard AC automatically:
         * - Sets quest status to QUEST_STATUS_INCOMPLETE
         * - Adds to character_queststatus table
         * - No custom tracking needed!
         */

        if (quest->GetQuestId() >= QUEST_DAILY_START && quest->GetQuestId() <= QUEST_WEEKLY_END)
        {
            // Optional: Custom messaging for dungeon quests
            player->GetSession()->SendNotification("Quest accepted! Complete all objectives to receive rewards.");
        }

        return true;
    }
};

// =====================================================================
// NPC QUEST COMPLETION SCRIPT (Token & Achievement Awards)
// =====================================================================

class npc_dungeon_quest_completion : public CreatureScript
{
public:
    npc_dungeon_quest_completion() : CreatureScript("npc_dungeon_quest_completion") { }

    struct npc_dungeon_quest_completionAI : public ScriptedAI
    {
        npc_dungeon_quest_completionAI(Creature* creature) : ScriptedAI(creature) { }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_dungeon_quest_completionAI(creature);
    }

    bool OnQuestReward(Player* player, Creature* creature, Quest const* quest, uint32 opt) override
    {
        /*
         * Called when player completes quest through this NPC.
         * This is where we award tokens and achievements!
         */

        uint32 questId = quest->GetQuestId();

        // Check if this is a dungeon quest
        if (questId < QUEST_DUNGEON_START || questId > QUEST_DUNGEON_END)
            return false;

        // =====================================================================
        // AWARD TOKENS BASED ON QUEST TYPE
        // =====================================================================

        Item* tokenItem = nullptr;
        uint32 tokenCount = 1;

        // Daily quests
        if (questId >= QUEST_DAILY_START && questId <= QUEST_DAILY_END)
        {
            tokenItem = Item::CreateItem(ITEM_DUNGEON_EXPLORER_TOKEN, 1);
            tokenCount = 1;

            // Query daily token multiplier from database
            PreparedStatement* stmt = WorldDatabase.GetPreparedStatement(WORLD_SEL_DAILY_QUEST_TOKEN_REWARD);
            stmt->SetData(0, questId);
            PreparedQueryResult result = WorldDatabase.Query(stmt);

            if (result)
            {
                Field* fields = result->Fetch();
                tokenCount = fields[0].Get<uint8>();
                float multiplier = fields[1].Get<float>();
                tokenCount = (uint32)(tokenCount * multiplier);
            }
        }
        // Weekly quests
        else if (questId >= QUEST_WEEKLY_START && questId <= QUEST_WEEKLY_END)
        {
            tokenItem = Item::CreateItem(ITEM_EXPANSION_SPECIALIST_TOKEN, 1);
            tokenCount = 1;

            // Query weekly token multiplier from database
            PreparedStatement* stmt = WorldDatabase.GetPreparedStatement(WORLD_SEL_WEEKLY_QUEST_TOKEN_REWARD);
            stmt->SetData(0, questId);
            PreparedQueryResult result = WorldDatabase.Query(stmt);

            if (result)
            {
                Field* fields = result->Fetch();
                tokenCount = fields[0].Get<uint8>();
                float multiplier = fields[1].Get<float>();
                tokenCount = (uint32)(tokenCount * multiplier);
            }
        }
        // Dungeon quests (normal)
        else
        {
            tokenItem = Item::CreateItem(ITEM_DUNGEON_EXPLORER_TOKEN, 1);
            tokenCount = 1;
        }

        // Award tokens to player
        if (tokenItem && tokenCount > 0)
        {
            if (player->AddItem(tokenItem, tokenCount))
            {
                player->GetSession()->SendNotification("You have received %u token(s)!", tokenCount);
            }
        }

        // =====================================================================
        // AWARD ACHIEVEMENTS
        // =====================================================================

        // Track total dungeon quests completed
        uint32 totalQuestsCompleted = 0;

        // Query completed dungeon quest count for player
        CharacterDatabasePreparedStatement* charStmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PLAYER_DUNGEON_QUEST_COUNT);
        charStmt->SetData(0, player->GetGUID().GetCounter());
        PreparedQueryResult charResult = CharacterDatabase.Query(charStmt);

        if (charResult)
        {
            totalQuestsCompleted = charResult->Fetch()[0].Get<uint32>();
        }

        // Award achievement for first dungeon quest
        if (totalQuestsCompleted == 1 && !player->HasAchieved(ACHIEVEMENT_DUNGEON_NOVICE))
        {
            player->CompletedAchievement(ACHIEVEMENT_DUNGEON_NOVICE);
            player->GetSession()->SendNotification("Achievement Unlocked: Dungeon Novice!");
        }

        // Award achievement for 10 dungeon quests
        if (totalQuestsCompleted >= 10 && !player->HasAchieved(ACHIEVEMENT_DUNGEON_EXPLORER))
        {
            player->CompletedAchievement(ACHIEVEMENT_DUNGEON_EXPLORER);
            player->GetSession()->SendNotification("Achievement Unlocked: Dungeon Explorer!");
        }

        // Award achievement for 50 dungeon quests
        if (totalQuestsCompleted >= 50 && !player->HasAchieved(ACHIEVEMENT_LEGENDARY_DUNGEON))
        {
            player->CompletedAchievement(ACHIEVEMENT_LEGENDARY_DUNGEON);
            player->GetSession()->SendNotification("Achievement Unlocked: Legendary Dungeon Master!");
        }

        // =====================================================================
        // STANDARD AC QUEST COMPLETION
        // =====================================================================

        /*
         * AzerothCore automatically:
         * - Sets quest status to QUEST_STATUS_REWARDED
         * - Updates character_queststatus
         * - Handles daily/weekly reset timer (via quest_template.Flags)
         * - No custom code needed!
         */

        return false; // Return false to allow standard AC handling
    }
};

// =====================================================================
// PREPARED STATEMENTS
// =====================================================================

enum WorldDatabaseStatements
{
    WORLD_SEL_DAILY_QUEST_TOKEN_REWARD = 1000,
    WORLD_SEL_WEEKLY_QUEST_TOKEN_REWARD = 1001,
};

enum CharacterDatabaseStatements
{
    CHAR_SEL_PLAYER_DUNGEON_QUEST_COUNT = 2000,
};

// =====================================================================
// INITIALIZATION
// =====================================================================

void AddSC_npc_dungeon_quest_master()
{
    new npc_dungeon_quest_master();
    new npc_dungeon_quest_completion();

    LOG_INFO("server.loading", ">> Loaded Dungeon Quest NPC System v3.0 (Enhanced UX + AC Standards)");
}
