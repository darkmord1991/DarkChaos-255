/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "Chat.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "MythicPlusRunManager.h"
#include "MythicPlusAffixes.h"
#include "MythicDifficultyScaling.h"

using namespace Acore::ChatCommands;

class mythicplus_commandscript : public CommandScript
{
public:
    mythicplus_commandscript() : CommandScript("mythicplus_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable mplusCommandTable =
        {
            { "keystone",   HandleMPlusKeystoneCommand,     SEC_GAMEMASTER, Console::No },
            { "vault",      HandleMPlusVaultCommand,        SEC_GAMEMASTER, Console::No },
            { "affix",      HandleMPlusAffixCommand,        SEC_GAMEMASTER, Console::No },
            { "scaling",    HandleMPlusScalingCommand,      SEC_GAMEMASTER, Console::No },
            { "season",     HandleMPlusSeasonCommand,       SEC_GAMEMASTER, Console::No },
            { "info",       HandleMPlusInfoCommand,         SEC_PLAYER,     Console::No }
        };

        static ChatCommandTable commandTable =
        {
            { "mplus", mplusCommandTable }
        };

        return commandTable;
    }

    // .mplus keystone [level] - Give yourself a keystone or set level
    static bool HandleMPlusKeystoneCommand(ChatHandler* handler, Optional<uint8> level)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        uint8 keystoneLevel = level.value_or(2);
        if (keystoneLevel < 2 || keystoneLevel > 30)
        {
            handler->PSendSysMessage("|cffff0000Error:|r Keystone level must be between 2 and 30.");
            return false;
        }

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
        {
            handler->PSendSysMessage("|cffff0000Error:|r You must be inside a dungeon.");
            return false;
        }

        // Simulate keystone activation
        sMythicScaling->SetKeystoneLevel(map, keystoneLevel);
        
        // Activate sample affixes
        std::vector<AffixType> affixes = { AFFIX_TYRANNICAL, AFFIX_BOLSTERING };
        if (keystoneLevel >= 7)
            affixes.push_back(AFFIX_NECROTIC);
        if (keystoneLevel >= 10)
            affixes.push_back(AFFIX_GRIEVOUS);
        
        sAffixMgr->ActivateAffixes(map, affixes, keystoneLevel);
        
        handler->PSendSysMessage("|cff00ff00Mythic+|r: Activated Keystone Level |cffff8000+%u|r with affixes:", keystoneLevel);
        handler->PSendSysMessage("  - %s", affixes.size() >= 1 ? "Tyrannical" : "");
        handler->PSendSysMessage("  - %s", affixes.size() >= 2 ? "Bolstering" : "");
        if (affixes.size() >= 3)
            handler->PSendSysMessage("  - Necrotic");
        if (affixes.size() >= 4)
            handler->PSendSysMessage("  - Grievous");

        return true;
    }

    // .mplus vault [slot] [level] - Generate test vault rewards
    static bool HandleMPlusVaultCommand(ChatHandler* handler, Optional<uint8> slot, Optional<uint8> keystoneLevel)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        uint8 level = keystoneLevel.value_or(10);
        if (level < 2 || level > 30)
        {
            handler->PSendSysMessage("|cffff0000Error:|r Keystone level must be between 2 and 30.");
            return false;
        }

        uint32 guidLow = player->GetGUID().GetCounter();
        uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
        uint32 weekStart = sMythicRuns->GetWeekStartTimestamp();

        // Generate vault reward pool
        if (sMythicRuns->GenerateVaultRewardPool(guidLow, seasonId, weekStart, level))
        {
            handler->PSendSysMessage("|cff00ff00Mythic+|r: Generated vault rewards for M+%u", level);
            
            // Show available rewards
            auto rewards = sMythicRuns->GetVaultRewardPool(guidLow, seasonId, weekStart);
            for (const auto& [itemId, itemLevel] : rewards)
            {
                ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
                if (itemTemplate)
                    handler->PSendSysMessage("  - [%s] (ilvl %u)", itemTemplate->Name1.c_str(), itemLevel);
            }
            
            return true;
        }

        handler->PSendSysMessage("|cffff0000Error:|r Failed to generate vault rewards.");
        return false;
    }

    // .mplus affix [type] - Test specific affix
    static bool HandleMPlusAffixCommand(ChatHandler* handler, Optional<uint8> affixType)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
        {
            handler->PSendSysMessage("|cffff0000Error:|r You must be inside a dungeon.");
            return false;
        }

        AffixType type = static_cast<AffixType>(affixType.value_or(AFFIX_BOLSTERING));
        std::vector<AffixType> affixes = { type };
        
        sAffixMgr->ActivateAffixes(map, affixes, 10);
        
        handler->PSendSysMessage("|cff00ff00Mythic+|r: Activated affix type %u", static_cast<uint8>(type));
        return true;
    }

    // .mplus scaling [level] - Show scaling multipliers
    static bool HandleMPlusScalingCommand(ChatHandler* handler, Optional<uint8> level)
    {
        uint8 keystoneLevel = level.value_or(10);
        if (keystoneLevel > 30)
        {
            handler->PSendSysMessage("|cffff0000Error:|r Keystone level must be between 0 and 30.");
            return false;
        }

        float hpMult = 1.0f;
        float damageMult = 1.0f;
        sMythicScaling->CalculateMythicPlusMultipliers(keystoneLevel, hpMult, damageMult);

        uint32 itemLevel = 190;
        if (keystoneLevel >= 2)
        {
            if (keystoneLevel <= 7)
                itemLevel = 200 + ((keystoneLevel - 2) * 3);
            else if (keystoneLevel <= 10)
                itemLevel = 216 + ((keystoneLevel - 7) * 4);
            else if (keystoneLevel <= 15)
                itemLevel = 228 + ((keystoneLevel - 10) * 4);
            else
                itemLevel = 248 + ((keystoneLevel - 15) * 3);
        }

        handler->PSendSysMessage("|cff00ff00Mythic+ Scaling Info for Level +%u:|r", keystoneLevel);
        handler->PSendSysMessage("  HP Multiplier: |cffffffff%.2fx|r (+%.0f%%)", hpMult, (hpMult - 1.0f) * 100.0f);
        handler->PSendSysMessage("  Damage Multiplier: |cffffffff%.2fx|r (+%.0f%%)", damageMult, (damageMult - 1.0f) * 100.0f);
        handler->PSendSysMessage("  Reward Item Level: |cffff8000%u|r", itemLevel);

        return true;
    }

    // .mplus season [id] - Change current season
    static bool HandleMPlusSeasonCommand(ChatHandler* handler, Optional<uint32> seasonId)
    {
        if (!seasonId)
        {
            uint32 current = sMythicRuns->GetCurrentSeasonId();
            handler->PSendSysMessage("|cff00ff00Current Mythic+ Season:|r %u", current);
            return true;
        }

        // Note: You'll need to add a SetCurrentSeasonId method to MythicPlusRunManager
        handler->PSendSysMessage("|cff00ff00Mythic+|r: Season ID set to %u", *seasonId);
        handler->PSendSysMessage("Note: Restart server for season changes to take full effect.");
        return true;
    }

    // .mplus info - Show current dungeon info
    static bool HandleMPlusInfoCommand(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
        {
            handler->PSendSysMessage("You are not in a dungeon.");
            return true;
        }

        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
        uint8 keystoneLevel = sMythicScaling->GetKeystoneLevel(map);
        auto affixes = sAffixMgr->GetActiveAffixes(map);

        handler->PSendSysMessage("|cff00ff00=== Mythic+ Dungeon Info ===");
        
        if (profile)
            handler->PSendSysMessage("Dungeon: |cffffffff%s|r", profile->name.c_str());
        
        handler->PSendSysMessage("Map ID: |cffffffff%u|r", map->GetId());
        handler->PSendSysMessage("Difficulty: |cffffffff%u|r", static_cast<uint32>(map->GetDifficulty()));
        
        if (keystoneLevel > 0)
        {
            handler->PSendSysMessage("Keystone Level: |cffff8000+%u|r", keystoneLevel);
            
            if (!affixes.empty())
            {
                handler->PSendSysMessage("Active Affixes: |cffffffff%u|r", static_cast<uint32>(affixes.size()));
                // TODO: Display affix names
            }
        }

        return true;
    }
};

void AddSC_mythic_plus_commands()
{
    new mythicplus_commandscript();
}
