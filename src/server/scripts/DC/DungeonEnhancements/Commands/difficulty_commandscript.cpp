/*
 * ============================================================================
 * Dungeon/Raid Difficulty Command
 * ============================================================================
 * Purpose: Show current dungeon/raid difficulty
 * Commands: .difficulty
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "Map.h"
#include "CommandScript.h"

using namespace Acore::ChatCommands;

// Forward declarations for difficulty labels
namespace
{
    std::string GetDungeonDifficultyLabel(Difficulty difficulty)
    {
        switch (difficulty)
        {
            case DUNGEON_DIFFICULTY_NORMAL:
                return "Normal";
            case DUNGEON_DIFFICULTY_HEROIC:
                return "Heroic";
            case DUNGEON_DIFFICULTY_EPIC:
                return "Mythic";
            case DUNGEON_DIFFICULTY_MYTHIC:
                return "Mythic";
            case DUNGEON_DIFFICULTY_MYTHIC_PLUS:
                return "Mythic+";
            default:
                return "Unknown";
        }
    }

    std::string GetRaidDifficultyLabel(Difficulty difficulty)
    {
        switch (difficulty)
        {
            case RAID_DIFFICULTY_10MAN_NORMAL:
                return "10-Man Normal";
            case RAID_DIFFICULTY_25MAN_NORMAL:
                return "25-Man Normal";
            case RAID_DIFFICULTY_10MAN_HEROIC:
                return "10-Man Heroic";
            case RAID_DIFFICULTY_25MAN_HEROIC:
                return "25-Man Heroic";
            case RAID_DIFFICULTY_10MAN_MYTHIC:
                return "10-Man Mythic";
            case RAID_DIFFICULTY_25MAN_MYTHIC:
                return "25-Man Mythic";
            default:
                return "Unknown";
        }
    }
}

class difficulty_commandscript : public CommandScript
{
public:
    difficulty_commandscript() : CommandScript("difficulty_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "difficulty", HandleDifficultyCommand, SEC_PLAYER, Console::No },
        };

        return commandTable;
    }

    // ========================================================================
    // .difficulty - Show current dungeon/raid difficulty
    // ========================================================================
    static bool HandleDifficultyCommand(ChatHandler* handler, std::string_view /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        Map* map = player->GetMap();
        if (!map)
        {
            handler->PSendSysMessage("|cFFFF0000Error: Could not get map information.|r");
            return false;
        }

        // Check if player is in a dungeon or raid
        if (!map->IsDungeon() && !map->IsRaid())
        {
            handler->PSendSysMessage("|cFFFF0000You are not in a dungeon or raid instance.|r");
            return false;
        }

        // Get map name
        const char* mapName = map->GetMapName();
        if (!mapName)
            mapName = "Unknown";

        // Get difficulty
        Difficulty difficulty = map->GetDifficulty();

        // Display information
        handler->PSendSysMessage("|cFF00FF00=== Instance Difficulty ===|r");
        handler->PSendSysMessage("Map: |cFFFFAA00%s|r", mapName);

        if (map->IsRaid())
        {
            handler->PSendSysMessage("Type: |cFF0088FFRaid|r");
            handler->PSendSysMessage("Difficulty: |cFFFFAA00%s|r", GetRaidDifficultyLabel(difficulty).c_str());
        }
        else
        {
            handler->PSendSysMessage("Type: |cFF0088FFDungeon|r");
            handler->PSendSysMessage("Difficulty: |cFFFFAA00%s|r", GetDungeonDifficultyLabel(difficulty).c_str());
        }

        // Additional info for non-standard difficulties
        if (map->IsDungeon() && difficulty >= DUNGEON_DIFFICULTY_MYTHIC)
        {
            // Try to get keystone level if available
            handler->PSendSysMessage("|cFF88FF00Tip: Use .mythicplus info for Mythic+ details|r");
        }

        return true;
    }
};

// Register the command script
void AddSC_difficulty_commandscript()
{
    new difficulty_commandscript();
}
