/*
 * ============================================================================
 * Dungeon Enhancement System - GM Commands
 * ============================================================================
 * Purpose: Debug and testing commands for Mythic+ system
 * Commands: .mythicplus <subcommand>
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "Map.h"
#include "CommandScript.h"
#include "../Core/DungeonEnhancementManager.h"
#include "../Core/DungeonEnhancementConstants.h"
#include "../Core/MythicRunTracker.h"
#include "../Core/MythicDifficultyScaling.h"

using namespace DungeonEnhancement;
using namespace Acore::ChatCommands;

class mythicplus_commandscript : public CommandScript
{
public:
    mythicplus_commandscript() : CommandScript("mythicplus_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable mythicplusCommandTable =
        {
            { "info",       HandleMythicPlusInfoCommand,       SEC_PLAYER,         Console::No  },
            { "keystone",   HandleMythicPlusKeystoneCommand,   SEC_GAMEMASTER,     Console::No  },
            { "setlevel",   HandleMythicPlusSetLevelCommand,   SEC_GAMEMASTER,     Console::No  },
            { "resetvault", HandleMythicPlusResetVaultCommand, SEC_GAMEMASTER,     Console::No  },
            { "affixes",    HandleMythicPlusAffixesCommand,    SEC_PLAYER,         Console::No  },
            { "forcestart", HandleMythicPlusForceStartCommand, SEC_ADMINISTRATOR,  Console::No  },
            { "rating",     HandleMythicPlusRatingCommand,     SEC_PLAYER,         Console::No  },
            { "season",     HandleMythicPlusSeasonCommand,     SEC_GAMEMASTER,     Console::No  },
            { "debug",      HandleMythicPlusDebugCommand,      SEC_ADMINISTRATOR,  Console::No  },
        };

        static ChatCommandTable commandTable =
        {
            { "mythicplus", mythicplusCommandTable },
            { "m+",         mythicplusCommandTable },
        };

        return commandTable;
    }

    // ========================================================================
    // .mythicplus info - Show player's M+ status
    // ========================================================================
    static bool HandleMythicPlusInfoCommand(ChatHandler* handler, std::string_view /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!sDungeonEnhancementMgr->IsEnabled())
        {
            handler->PSendSysMessage("|cFFFF0000Dungeon Enhancement System is disabled.|r");
            return true;
        }

        handler->PSendSysMessage("|cFF00FF00=== Mythic+ Status ===|r");

        // Current season
        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        if (season)
        {
            handler->PSendSysMessage("Season: |cFFFFAA00%u - %s|r", season->seasonId, season->seasonName.c_str());
            handler->PSendSysMessage("Active: %s", season->isActive ? "|cFF00FF00Yes|r" : "|cFFFF0000No|r");
        }
        else
        {
            handler->PSendSysMessage("Season: |cFFFF0000No active season|r");
        }

        // Keystone
        if (sDungeonEnhancementMgr->PlayerHasKeystone(player))
        {
            uint8 level = sDungeonEnhancementMgr->GetPlayerKeystoneLevel(player);
            handler->PSendSysMessage("Keystone: |cFF00FF00Mythic+%u|r", level);
        }
        else
        {
            handler->PSendSysMessage("Keystone: |cFF888888None|r");
        }

        // Vault progress
        uint8 vaultProgress = sDungeonEnhancementMgr->GetPlayerVaultProgress(player);
        handler->PSendSysMessage("Vault Progress: |cFFFFAA00%u/8|r dungeons this week", vaultProgress);

        // Rating
        uint32 rating = season ? sDungeonEnhancementMgr->GetPlayerRating(player, season->seasonId) : 0;
        handler->PSendSysMessage("Seasonal Rating: |cFFFFAA00%u|r", rating);

        // Current run (if in instance)
        Map* map = player->GetMap();
        if (map && map->IsDungeon())
        {
            uint32 instanceId = map->GetInstanceId();
            if (MythicRunTracker::IsRunActive(instanceId))
            {
                MythicRunData* runData = MythicRunTracker::GetRunData(instanceId);
                if (runData)
                {
                    handler->PSendSysMessage(" ");
                    handler->PSendSysMessage("|cFFFFAA00Active Run (M+%u):|r", runData->keystoneLevel);
                    handler->PSendSysMessage("Deaths: %u/%u", runData->totalDeaths, MAX_DEATHS_BEFORE_PENALTY);
                    handler->PSendSysMessage("Bosses Killed: %u/%u", runData->bossesKilled, runData->requiredBosses);
                    
                    uint32 elapsed = MythicRunTracker::GetElapsedTime(instanceId);
                    handler->PSendSysMessage("Time Elapsed: %um %us", elapsed / 60, elapsed % 60);
                }
            }
        }

        return true;
    }

    // ========================================================================
    // .mythicplus keystone <level> - Give/modify keystone
    // ========================================================================
    static bool HandleMythicPlusKeystoneCommand(ChatHandler* handler, std::string_view args)
    {
        Player* player = handler->getSelectedPlayer();
        if (!player)
            player = handler->GetSession()->GetPlayer();

        if (!player)
        {
            handler->SendSysMessage("No player selected.");
            return false;
        }

        if (args.empty())
        {
            handler->PSendSysMessage("Usage: .mythicplus keystone <level>");
            handler->PSendSysMessage("Levels: 2-10 (no M+1), or 0 to remove keystone");
            return false;
        }

        int32 level = atoi(args.data());

        // Remove keystone
        if (level == 0)
        {
            sDungeonEnhancementMgr->RemovePlayerKeystone(player);
            handler->PSendSysMessage("Removed keystone from %s", player->GetName().c_str());
            return true;
        }

        // Validate level
        if (level < MYTHIC_PLUS_MIN_LEVEL || level > MYTHIC_PLUS_MAX_LEVEL)
        {
            handler->PSendSysMessage("|cFFFF0000Invalid keystone level. Must be 2-10.|r");
            return false;
        }

        // Give keystone
        sDungeonEnhancementMgr->GivePlayerKeystone(player, static_cast<uint8>(level));
        handler->PSendSysMessage("Gave M+%d keystone to %s", level, player->GetName().c_str());

        return true;
    }

    // ========================================================================
    // .mythicplus setlevel <level> - Set current instance keystone level
    // ========================================================================
    static bool HandleMythicPlusSetLevelCommand(ChatHandler* handler, std::string_view args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
        {
            handler->SendSysMessage("You must be inside a dungeon.");
            return false;
        }

        if (args.empty())
        {
            handler->PSendSysMessage("Usage: .mythicplus setlevel <level>");
            return false;
        }

        int32 level = atoi(args.data());
        if (level < 0 || level > MYTHIC_PLUS_MAX_LEVEL)
        {
            handler->PSendSysMessage("|cFFFF0000Invalid level. Must be 0-10.|r");
            return false;
        }

        MythicDifficultyScaling::SetMapKeystoneLevel(map, static_cast<uint8>(level));
        handler->PSendSysMessage("Set instance keystone level to M+%d", level);

        return true;
    }

    // ========================================================================
    // .mythicplus resetvault - Reset player's vault progress
    // ========================================================================
    static bool HandleMythicPlusResetVaultCommand(ChatHandler* handler, std::string_view /*args*/)
    {
        Player* player = handler->getSelectedPlayer();
        if (!player)
            player = handler->GetSession()->GetPlayer();

        if (!player)
        {
            handler->SendSysMessage("No player selected.");
            return false;
        }

        // Reset vault progress
        sDungeonEnhancementMgr->ResetWeeklyVaultProgress();
        handler->PSendSysMessage("Reset vault progress for %s", player->GetName().c_str());

        return true;
    }

    // ========================================================================
    // .mythicplus affixes - Show current week's affixes
    // ========================================================================
    static bool HandleMythicPlusAffixesCommand(ChatHandler* handler, std::string_view /*args*/)
    {
        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        if (!season)
        {
            handler->PSendSysMessage("|cFFFF0000No active season.|r");
            return true;
        }

        AffixRotation* rotation = sDungeonEnhancementMgr->GetCurrentAffixRotation();
        if (!rotation)
        {
            handler->PSendSysMessage("|cFFFF0000No affix rotation active.|r");
            return true;
        }

        handler->PSendSysMessage("|cFF00FF00=== Current Affixes (Season %u, Week %u) ===|r",
                                 season->seasonId, rotation->weekNumber);

        // Tier 1 (M+2)
        if (rotation->tier1AffixId > 0)
        {
            AffixData* affix = sDungeonEnhancementMgr->GetAffixById(rotation->tier1AffixId);
            if (affix)
            {
                handler->PSendSysMessage("|cFFFFAA00[M+2+]|r %s (%s)", 
                                         affix->affixName.c_str(), affix->affixType.c_str());
                handler->PSendSysMessage("  %s", affix->affixDescription.c_str());
            }
        }

        // Tier 2 (M+4)
        if (rotation->tier2AffixId > 0)
        {
            AffixData* affix = sDungeonEnhancementMgr->GetAffixById(rotation->tier2AffixId);
            if (affix)
            {
                handler->PSendSysMessage("|cFFFFAA00[M+4+]|r %s (%s)", 
                                         affix->affixName.c_str(), affix->affixType.c_str());
                handler->PSendSysMessage("  %s", affix->affixDescription.c_str());
            }
        }

        // Tier 3 (M+7)
        if (rotation->tier3AffixId > 0)
        {
            AffixData* affix = sDungeonEnhancementMgr->GetAffixById(rotation->tier3AffixId);
            if (affix)
            {
                handler->PSendSysMessage("|cFFFFAA00[M+7+]|r %s (%s)", 
                                         affix->affixName.c_str(), affix->affixType.c_str());
                handler->PSendSysMessage("  %s", affix->affixDescription.c_str());
            }
        }

        return true;
    }

    // ========================================================================
    // .mythicplus forcestart <level> - Force start M+ run (admin only)
    // ========================================================================
    static bool HandleMythicPlusForceStartCommand(ChatHandler* handler, std::string_view args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
        {
            handler->SendSysMessage("You must be inside a dungeon.");
            return false;
        }

        if (args.empty())
        {
            handler->PSendSysMessage("Usage: .mythicplus forcestart <level>");
            return false;
        }

        int32 level = atoi(args.data());
        if (level < MYTHIC_PLUS_MIN_LEVEL || level > MYTHIC_PLUS_MAX_LEVEL)
        {
            handler->PSendSysMessage("|cFFFF0000Invalid level. Must be 2-10.|r");
            return false;
        }

        // Start run
        MythicRunTracker::StartRun(map, static_cast<uint8>(level), player);
        handler->PSendSysMessage("Force-started M+%d run", level);

        return true;
    }

    // ========================================================================
    // .mythicplus rating - Show detailed rating info
    // ========================================================================
    static bool HandleMythicPlusRatingCommand(ChatHandler* handler, std::string_view /*args*/)
    {
        Player* player = handler->getSelectedPlayer();
        if (!player)
            player = handler->GetSession()->GetPlayer();

        if (!player)
        {
            handler->SendSysMessage("No player selected.");
            return false;
        }

        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        uint32 rating = season ? sDungeonEnhancementMgr->GetPlayerRating(player, season->seasonId) : 0;

        handler->PSendSysMessage("|cFF00FF00=== Mythic+ Rating for %s ===|r", player->GetName().c_str());
        handler->PSendSysMessage("Current Rating: |cFFFFAA00%u|r", rating);

        // Determine rank
        std::string rank = "Unranked";
        if (rating >= 2000)
            rank = "Mythic";
        else if (rating >= 1500)
            rank = "Heroic";
        else if (rating >= 1000)
            rank = "Advanced";
        else if (rating >= 500)
            rank = "Novice";

        handler->PSendSysMessage("Rank: |cFFFFAA00%s|r", rank.c_str());

        return true;
    }

    // ========================================================================
    // .mythicplus season <start|end|info> - Manage seasons
    // ========================================================================
    static bool HandleMythicPlusSeasonCommand(ChatHandler* handler, std::string_view args)
    {
        if (args.empty())
        {
            handler->PSendSysMessage("Usage: .mythicplus season <start|end|info>");
            return false;
        }

        std::string subcommand(args.begin(), args.end());

        if (subcommand == "info")
        {
            SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
            if (!season)
            {
                handler->PSendSysMessage("|cFFFF0000No active season.|r");
                return true;
            }

            handler->PSendSysMessage("|cFF00FF00=== Season %u ===|r", season->seasonId);
            handler->PSendSysMessage("Name: %s", season->seasonName.c_str());
            handler->PSendSysMessage("Active: %s", season->isActive ? "Yes" : "No");
            handler->PSendSysMessage("Max Keystone Level: %u", season->maxKeystoneLevel);
            handler->PSendSysMessage("Vault Enabled: %s", season->vaultEnabled ? "Yes" : "No");
        }
        else if (subcommand == "start")
        {
            // TODO: Implement season start
            handler->PSendSysMessage("Season start not yet implemented.");
        }
        else if (subcommand == "end")
        {
            sDungeonEnhancementMgr->EndCurrentSeason();
            handler->PSendSysMessage("Ended current season.");
        }
        else
        {
            handler->PSendSysMessage("Unknown subcommand. Use: start, end, or info");
            return false;
        }

        return true;
    }

    // ========================================================================
    // .mythicplus debug - Show debug information
    // ========================================================================
    static bool HandleMythicPlusDebugCommand(ChatHandler* handler, std::string_view /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        handler->PSendSysMessage("|cFF00FF00=== Mythic+ Debug Info ===|r");

        // System status
        handler->PSendSysMessage("System Enabled: %s", 
                                 sDungeonEnhancementMgr->IsEnabled() ? "Yes" : "No");

        // Cache status
        handler->PSendSysMessage("Cached Seasons: %zu", 
                                 sDungeonEnhancementMgr->GetSeasonalDungeons(1).size());

        // Current map info
        Map* map = player->GetMap();
        if (map && map->IsDungeon())
        {
            uint16 mapId = map->GetId();
            uint32 instanceId = map->GetInstanceId();
            
            handler->PSendSysMessage("Current Map: %u (Instance %u)", mapId, instanceId);
            handler->PSendSysMessage("M+ Enabled: %s", 
                                     sDungeonEnhancementMgr->IsDungeonMythicPlusEnabled(mapId) ? "Yes" : "No");
            
            uint8 keystoneLevel = MythicDifficultyScaling::GetMapKeystoneLevel(map);
            handler->PSendSysMessage("Instance Keystone Level: %u", keystoneLevel);
            
            if (MythicRunTracker::IsRunActive(instanceId))
            {
                MythicRunData* runData = MythicRunTracker::GetRunData(instanceId);
                if (runData)
                {
                    handler->PSendSysMessage("Active Run: M+%u", runData->keystoneLevel);
                    handler->PSendSysMessage("Participants: %zu", runData->participantGUIDs.size());
                }
            }
        }

        return true;
    }
};

void AddSC_mythicplus_commandscript()
{
    new mythicplus_commandscript();
}
