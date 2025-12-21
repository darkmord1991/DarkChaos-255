/*
 * AzerothCore Command Script: .dcquests (dc_dungeonquests_commandscript)
 *
 * Purpose / Feature Overview:
 * - Provides admin debugging and management commands for DC Dungeon Quest System
 * - Allows admins to test, verify, and manage quest rewards, tokens, and achievements
 * - Supports player assistance features (quest list, status checking)
 *
 * Command names:
 * - .dcquests help                    - Show all available subcommands
 * - .dcquests list [type]             - List quests (type: daily, weekly, dungeon, all)
 * - .dcquests info <quest_id>         - Show quest details
 * - .dcquests give-token <player> <token_id> [count]  - Give tokens to player
 * - .dcquests reward <player> <quest_id>  - Test reward system
 * - .dcquests progress <player> [quest_id] - Check quest progress
 * - .dcquests reset <player> [quest_id]    - Reset quest for player
 * - .dcquests debug [on|off]          - Toggle debug mode
 * - .dcquests achievement <player> <ach_id> - Award achievement
 * - .dcquests title <player> <title_id>    - Award title
 *
 * Script names and integration:
 * - Class: dc_dungeonquests_commandscript (CommandScript)
 * - Registration: AddSC_dc_dungeonquests_commandscript() (call in Commands/cs_script_loader.cpp)
 * - DB: No ScriptName needed; CommandScripts are loaded globally via the loader.
 *
 * Notes:
 * - All commands require admin access (SEC_ADMINISTRATOR or SEC_GAMEMASTER)
 * - Debug mode logs all quest events to console
 * - Token IDs: 700001-700005 (Explorer, Specialist, Legendary, Challenge, SpeedRunner)
 * - Quest ID ranges: 700101-700104 (daily), 700201-700204 (weekly), 700701+ (dungeons)
 * - Achievement ID ranges: 700001-700403 (various achievements)
 * - Title ID ranges: 1000-1102 (various titles)
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "WorldDatabase.h"
#include "CharacterDatabase.h"
#include "Creature.h"
#include <string>
#include <sstream>

using namespace Acore::ChatCommands;

namespace DC_DungeonQuests
{
    // Debug flag for logging
    static bool DEBUG_MODE = false;

    // Token definitions
    enum TokenType
    {
        TOKEN_EXPLORER = 700001,
        TOKEN_SPECIALIST = 700002,
        TOKEN_LEGENDARY = 700003,
        TOKEN_CHALLENGE = 700004,
        TOKEN_SPEEDRUNNER = 700005
    };

    // Quest type ranges
    static constexpr uint32 DAILY_QUEST_MIN = 700101;
    static constexpr uint32 DAILY_QUEST_MAX = 700104;
    static constexpr uint32 WEEKLY_QUEST_MIN = 700201;
    static constexpr uint32 WEEKLY_QUEST_MAX = 700204;
    static constexpr uint32 DUNGEON_QUEST_MIN = 700701;
    static constexpr uint32 DUNGEON_QUEST_MAX = 700999;

    inline void DebugLog(std::string const& msg)
    {
        if (DEBUG_MODE)
            LOG_INFO("dc.dungeonquests", msg);
    }

    inline void SendCommandError(ChatHandler* handler, const std::string& msg)
    {
        if (handler)
            handler->SendErrorMessage(msg.c_str());
    }

    inline void SendCommandSuccess(ChatHandler* handler, const std::string& msg)
    {
        if (handler)
            handler->SendSysMessage(msg.c_str());
    }

    static std::string GetQuestType(uint32 questId)
    {
        if (questId >= DAILY_QUEST_MIN && questId <= DAILY_QUEST_MAX)
            return "Daily";
        else if (questId >= WEEKLY_QUEST_MIN && questId <= WEEKLY_QUEST_MAX)
            return "Weekly";
        else if (questId >= DUNGEON_QUEST_MIN && questId <= DUNGEON_QUEST_MAX)
            return "Dungeon";
        return "Unknown";
    }

    static bool HandleDCQuestsHelp(ChatHandler* handler, char const* /*args*/)
    {
        handler->SendSysMessage("DC Dungeon Quest System - Admin Commands");
        handler->SendSysMessage("============================================");
        handler->PSendSysMessage(".dcquests help                      - Show this help");
        handler->PSendSysMessage(".dcquests list [type]              - List quests (daily|weekly|dungeon|all)");
        handler->PSendSysMessage(".dcquests info <quest_id>          - Show quest details from DB");
        handler->PSendSysMessage(".dcquests give-token <player> <token_id> [count] - Give tokens");
        handler->PSendSysMessage(".dcquests reward <player> <quest_id> - Test reward system");
        handler->PSendSysMessage(".dcquests progress <player> [quest_id] - Check quest progress");
        handler->PSendSysMessage(".dcquests reset <player> [quest_id] - Reset quest for player");
        handler->PSendSysMessage(".dcquests debug [on|off]            - Toggle debug logging");
        handler->PSendSysMessage(".dcquests achievement <player> <ach_id> - Award achievement");
        handler->PSendSysMessage(".dcquests title <player> <title_id> - Award title");
        return true;
    }

    static bool HandleDCQuestsList(ChatHandler* handler, char const* args)
    {
        if (!handler)
            return false;

        std::string type = args && *args ? args : "all";

        // Query DC quest templates directly (IDs in our DC ranges)
        QueryResult result = WorldDatabase.Query(
            "SELECT `Id`, `Title` FROM `quest_template` WHERE `Id` BETWEEN {} AND {}",
            700101, 700999);

        if (!result)
        {
            SendCommandError(handler, "No quests found in database!");
            return false;
        }

        handler->SendSysMessage("DC Dungeon Quests:");
        handler->SendSysMessage("==================");

        int count = 0;
        do
        {
            Field* fields = result->Fetch();
            uint32 questId = fields[0].Get<uint32>();
            std::string questName = fields[1].Get<std::string>();

            if (type == "all" ||
                (type == "daily" && questId >= DAILY_QUEST_MIN && questId <= DAILY_QUEST_MAX) ||
                (type == "weekly" && questId >= WEEKLY_QUEST_MIN && questId <= WEEKLY_QUEST_MAX) ||
                (type == "dungeon" && questId >= DUNGEON_QUEST_MIN && questId <= DUNGEON_QUEST_MAX))
            {
                std::string questType = GetQuestType(questId);
                handler->PSendSysMessage("[%u] %s (%s)", questId, questName.c_str(), questType.c_str());
                ++count;
            }
        } while (result->NextRow());

        handler->PSendSysMessage("Total: %d quests", count);
        return true;
    }

    static bool HandleDCQuestsInfo(ChatHandler* handler, char const* args)
    {
        if (!handler || !args || !*args)
        {
            SendCommandError(handler, "Usage: .dcquests info <quest_id>");
            return false;
        }

        uint32 questId = std::stoul(args);

        // Fetch quest by id directly
        QueryResult result = WorldDatabase.Query(
            "SELECT `Id`, `Title`, `Description`, `Flags` FROM `quest_template` WHERE `Id` = {}",
            questId);

        if (!result)
        {
            handler->PSendSysMessage("Quest %u not found!", questId);
            return false;
        }

        Field* fields = result->Fetch();
        uint32 id = fields[0].Get<uint32>();
        std::string title = fields[1].Get<std::string>();
        std::string description = fields[2].Get<std::string>();
        uint16 flags = fields[3].Get<uint16>();

        handler->SendSysMessage("Quest Information:");
        handler->PSendSysMessage("  ID: %u", id);
        handler->PSendSysMessage("  Title: %s", title.c_str());
        handler->PSendSysMessage("  Description: %s", description.c_str());
        handler->PSendSysMessage("  Type: %s", GetQuestType(id).c_str());
        handler->PSendSysMessage("  Flags: 0x%04X", flags);

        // Check if daily/weekly
        if (flags & 0x0800) handler->SendSysMessage("  - DAILY quest (resets every 24h)");
        if (flags & 0x1000) handler->SendSysMessage("  - WEEKLY quest (resets every 7d)");

        DebugLog("Quest info requested for ID: " + std::to_string(questId));
        return true;
    }

    static bool HandleDCQuestsGiveToken(ChatHandler* handler, char const* args)
    {
        if (!handler || !args || !*args)
        {
            SendCommandError(handler, "Usage: .dcquests give-token <player_name> <token_id> [count]");
            return false;
        }

        char playerName[MAX_PLAYER_NAME + 1];
        uint32 tokenId = 0;
        uint32 count = 1;

        if (sscanf(args, "%s %u %u", playerName, &tokenId, &count) < 2)
        {
            SendCommandError(handler, "Usage: .dcquests give-token <player_name> <token_id> [count]");
            return false;
        }

        // Validate token ID
        if (tokenId < TOKEN_EXPLORER || tokenId > TOKEN_SPEEDRUNNER)
        {
            handler->PSendSysMessage("Invalid token ID! Valid range: %u-%u", uint32(TOKEN_EXPLORER), uint32(TOKEN_SPEEDRUNNER));
            return false;
        }

        Player* player = ObjectAccessor::FindPlayerByName(playerName);
        if (!player)
        {
            handler->PSendSysMessage("Player '%s' not found!", playerName);
            return false;
        }

        // Add items to player's inventory
        ItemPosCountVec dest;
        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, tokenId, count);
        if (msg != EQUIP_ERR_OK)
        {
            handler->PSendSysMessage("Cannot give tokens to %s: inventory full!", playerName);
            return false;
        }

        Item* item = player->StoreNewItem(dest, tokenId, true, Item::GenerateItemRandomPropertyId(tokenId));
        if (item)
        {
            player->SendNewItem(item, count, true, false);
            handler->PSendSysMessage("Given %u token(s) [ID: %u] to %s", count, tokenId, playerName);
            DebugLog("Tokens given to player: " + std::string(playerName) + " (ID: " + std::to_string(tokenId) + ")");
            return true;
        }

        return false;
    }

    static bool HandleDCQuestsReward(ChatHandler* handler, char const* args)
    {
        if (!handler || !args || !*args)
        {
            SendCommandError(handler, "Usage: .dcquests reward <player_name> <quest_id>");
            return false;
        }

        char playerName[MAX_PLAYER_NAME + 1];
        uint32 questId = 0;

        if (sscanf(args, "%s %u", playerName, &questId) != 2)
        {
            SendCommandError(handler, "Usage: .dcquests reward <player_name> <quest_id>");
            return false;
        }

        Player* player = ObjectAccessor::FindPlayerByName(playerName);
        if (!player)
        {
            handler->PSendSysMessage("Player '%s' not found!", playerName);
            return false;
        }

        // Verify quest exists
        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
        if (!quest)
        {
            handler->PSendSysMessage("Quest %u not found in database!", questId);
            return false;
        }

    // Query reward from DC reward tables with preference order:
    // 1) daily-specific table
    // 2) weekly-specific table
    // 3) fallback default table `dc_quest_reward_tokens`

    QueryResult resultDaily = WorldDatabase.Query(
        "SELECT token_item_id, token_amount, multiplier FROM dc_daily_quest_token_rewards WHERE quest_id = {}",
        questId);

    QueryResult resultWeekly;
    QueryResult resultDefault;

    Field* fields = nullptr;
    uint32 rewardTokenId = 0;
    uint32 rewardCount = 0;
    float rewardMultiplier = 1.0f;

    if (resultDaily)
    {
        fields = resultDaily->Fetch();
        rewardTokenId = fields[0].Get<uint32>();
        rewardCount = fields[1].Get<uint32>();
        rewardMultiplier = fields[2].Get<float>();
    }
    else
    {
        // Try weekly
        resultWeekly = WorldDatabase.Query(
            "SELECT token_item_id, token_amount, multiplier FROM dc_weekly_quest_token_rewards WHERE quest_id = {}",
            questId);

        if (resultWeekly)
        {
            fields = resultWeekly->Fetch();
            rewardTokenId = fields[0].Get<uint32>();
            rewardCount = fields[1].Get<uint32>();
            rewardMultiplier = fields[2].Get<float>();
        }
        else
        {
            // Fallback to default token configuration table
            resultDefault = WorldDatabase.Query(
                "SELECT token_item_id, token_amount, multiplier FROM dc_quest_reward_tokens LIMIT 1");

            if (resultDefault)
            {
                fields = resultDefault->Fetch();
                rewardTokenId = fields[0].Get<uint32>();
                rewardCount = fields[1].Get<uint32>();
                rewardMultiplier = fields[2].Get<float>();
            }
        }
    }

    if (!fields)
    {
        handler->PSendSysMessage("No reward configuration found for quest %u", questId);
        return false;
    }

        // Calculate final reward
        uint32 finalCount = static_cast<uint32>(rewardCount * rewardMultiplier);

        // Give tokens
        ItemPosCountVec dest;
        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, rewardTokenId, finalCount);
        if (msg == EQUIP_ERR_OK)
        {
            player->StoreNewItem(dest, rewardTokenId, true);
            handler->PSendSysMessage("Rewarded %u token(s) to %s for quest %u (%.1fx multiplier)",
                                    finalCount, playerName, questId, rewardMultiplier);
            DebugLog("Quest reward given - Player: " + std::string(playerName) + ", Quest: " + std::to_string(questId));
        }
        else
        {
            handler->PSendSysMessage("Cannot give reward - player inventory full!");
        }

        return true;
    }

    static bool HandleDCQuestsProgress(ChatHandler* handler, char const* args)
    {
        if (!handler || !args || !*args)
        {
            SendCommandError(handler, "Usage: .dcquests progress <player_name> [quest_id]");
            return false;
        }

        char playerName[MAX_PLAYER_NAME + 1];
        uint32 questId = 0;

        sscanf(args, "%s %u", playerName, &questId);

        Player* player = ObjectAccessor::FindPlayerByName(playerName);
        if (!player)
        {
            handler->PSendSysMessage("Player '%s' not found!", playerName);
            return false;
        }

        if (questId > 0)
        {
            // Check specific quest
            if (player->HasQuest(questId))
            {
                handler->PSendSysMessage("Player has active quest: %u", questId);
                if (player->GetQuestStatus(questId) == QUEST_STATUS_COMPLETE)
                    handler->SendSysMessage("Status: COMPLETED");
                else if (player->GetQuestStatus(questId) == QUEST_STATUS_INCOMPLETE)
                    handler->SendSysMessage("Status: IN PROGRESS");
            }
            else
            {
                handler->PSendSysMessage("Player does not have quest %u", questId);
            }
        }
        else
        {
            // Show all DC dungeon quests for player
            handler->PSendSysMessage("DC Dungeon Quests for %s:", playerName);
            handler->SendSysMessage("Daily Quests:");
            for (uint32 i = DAILY_QUEST_MIN; i <= DAILY_QUEST_MAX; ++i)
            {
                if (player->GetQuestStatus(i) != QUEST_STATUS_NONE)
                {
                    const char* status = player->GetQuestStatus(i) == QUEST_STATUS_COMPLETE ? "COMPLETED" : "IN PROGRESS";
                    handler->PSendSysMessage("  [%u] - %s", i, status);
                }
            }
            handler->SendSysMessage("Weekly Quests:");
            for (uint32 i = WEEKLY_QUEST_MIN; i <= WEEKLY_QUEST_MAX; ++i)
            {
                if (player->GetQuestStatus(i) != QUEST_STATUS_NONE)
                {
                    const char* status = player->GetQuestStatus(i) == QUEST_STATUS_COMPLETE ? "COMPLETED" : "IN PROGRESS";
                    handler->PSendSysMessage("  [%u] - %s", i, status);
                }
            }
        }

        DebugLog("Quest progress checked for player: " + std::string(playerName));
        return true;
    }

    static bool HandleDCQuestsReset(ChatHandler* handler, char const* args)
    {
        if (!handler || !args || !*args)
        {
            SendCommandError(handler, "Usage: .dcquests reset <player_name> [quest_id]");
            return false;
        }

        char playerName[MAX_PLAYER_NAME + 1];
        uint32 questId = 0;

        sscanf(args, "%s %u", playerName, &questId);

        Player* player = ObjectAccessor::FindPlayerByName(playerName);
        if (!player)
        {
            handler->PSendSysMessage("Player '%s' not found!", playerName);
            return false;
        }

        if (questId > 0)
        {
            // Reset specific quest
            player->SetQuestStatus(questId, QUEST_STATUS_NONE);
            handler->PSendSysMessage("Quest %u reset for player %s", questId, playerName);
            DebugLog("Quest reset - Player: " + std::string(playerName) + ", Quest: " + std::to_string(questId));
        }
        else
        {
            // Reset all DC dungeon quests
            for (uint32 i = DAILY_QUEST_MIN; i <= DAILY_QUEST_MAX; ++i)
                player->SetQuestStatus(i, QUEST_STATUS_NONE);
            for (uint32 i = WEEKLY_QUEST_MIN; i <= WEEKLY_QUEST_MAX; ++i)
                player->SetQuestStatus(i, QUEST_STATUS_NONE);
            handler->PSendSysMessage("All DC dungeon quests reset for player %s", playerName);
            DebugLog("All quests reset for player: " + std::string(playerName));
        }

        return true;
    }

    static bool HandleDCQuestsDebug(ChatHandler* handler, char const* args)
    {
        if (!handler)
            return false;

        if (!args || !*args)
        {
            // Toggle
            DEBUG_MODE = !DEBUG_MODE;
        }
        else
        {
            std::string mode = args;
            if (mode == "on")
                DEBUG_MODE = true;
            else if (mode == "off")
                DEBUG_MODE = false;
            else
            {
                SendCommandError(handler, "Usage: .dcquests debug [on|off]");
                return false;
            }
        }

        handler->PSendSysMessage("DC Dungeon Quest debug mode: %s", DEBUG_MODE ? "ENABLED" : "DISABLED");
        return true;
    }

    static bool HandleDCQuestsAchievement(ChatHandler* handler, char const* args)
    {
        if (!handler || !args || !*args)
        {
            SendCommandError(handler, "Usage: .dcquests achievement <player_name> <achievement_id>");
            return false;
        }

        char playerName[MAX_PLAYER_NAME + 1];
        uint32 achievementId = 0;

        if (sscanf(args, "%s %u", playerName, &achievementId) != 2)
        {
            SendCommandError(handler, "Usage: .dcquests achievement <player_name> <achievement_id>");
            return false;
        }

        Player* player = ObjectAccessor::FindPlayerByName(playerName);
        if (!player)
        {
            handler->PSendSysMessage("Player '%s' not found!", playerName);
            return false;
        }

    player->CompletedAchievement(sAchievementMgr->GetAchievement(achievementId));
        handler->PSendSysMessage("Achievement %u awarded to %s", achievementId, playerName);
        DebugLog("Achievement awarded - Player: " + std::string(playerName) + ", Achievement: " + std::to_string(achievementId));
        return true;
    }

    static bool HandleDCQuestsTitle(ChatHandler* handler, char const* args)
    {
        if (!handler || !args || !*args)
        {
            SendCommandError(handler, "Usage: .dcquests title <player_name> <title_id>");
            return false;
        }

        char playerName[MAX_PLAYER_NAME + 1];
        uint32 titleId = 0;

        if (sscanf(args, "%s %u", playerName, &titleId) != 2)
        {
            SendCommandError(handler, "Usage: .dcquests title <player_name> <title_id>");
            return false;
        }

        Player* player = ObjectAccessor::FindPlayerByName(playerName);
        if (!player)
        {
            handler->PSendSysMessage("Player '%s' not found!", playerName);
            return false;
        }

        CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(titleId);
        if (!titleEntry)
        {
            handler->PSendSysMessage("Title %u not found!", titleId);
            return false;
        }

        player->SetTitle(titleEntry);
        handler->PSendSysMessage("Title %u awarded to %s", titleId, playerName);
        DebugLog("Title awarded - Player: " + std::string(playerName) + ", Title: " + std::to_string(titleId));
        return true;
    }
}

class dc_dungeonquests_commandscript : public CommandScript
{
public:
    dc_dungeonquests_commandscript() : CommandScript("dc_dungeonquests_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable dcquestsSubTable =
        {
            { "help",         DC_DungeonQuests::HandleDCQuestsHelp,        SEC_ADMINISTRATOR, Console::No },
            { "list",         DC_DungeonQuests::HandleDCQuestsList,        SEC_ADMINISTRATOR, Console::No },
            { "info",         DC_DungeonQuests::HandleDCQuestsInfo,        SEC_ADMINISTRATOR, Console::No },
            { "give-token",   DC_DungeonQuests::HandleDCQuestsGiveToken,   SEC_ADMINISTRATOR, Console::No },
            { "reward",       DC_DungeonQuests::HandleDCQuestsReward,      SEC_ADMINISTRATOR, Console::No },
            { "progress",     DC_DungeonQuests::HandleDCQuestsProgress,    SEC_ADMINISTRATOR, Console::No },
            { "reset",        DC_DungeonQuests::HandleDCQuestsReset,       SEC_ADMINISTRATOR, Console::No },
            { "debug",        DC_DungeonQuests::HandleDCQuestsDebug,       SEC_ADMINISTRATOR, Console::No },
            { "achievement",  DC_DungeonQuests::HandleDCQuestsAchievement, SEC_ADMINISTRATOR, Console::No },
            { "title",        DC_DungeonQuests::HandleDCQuestsTitle,       SEC_ADMINISTRATOR, Console::No }
        };

        static ChatCommandTable commandTable =
        {
            { "dcquests", dcquestsSubTable }
        };

        return commandTable;
    }
};

void AddSC_dc_dungeonquests_commandscript()
{
    new dc_dungeonquests_commandscript();
}
