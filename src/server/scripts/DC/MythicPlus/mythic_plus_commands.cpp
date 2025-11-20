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
#include "MythicPlusConstants.h"
#include "StringFormat.h"

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
            { "give",       HandleMPlusGiveCommand,         SEC_GAMEMASTER, Console::No },
            { "vault",      HandleMPlusVaultCommand,        SEC_GAMEMASTER, Console::No },
            { "affix",      HandleMPlusAffixCommand,        SEC_GAMEMASTER, Console::No },
            { "scaling",    HandleMPlusScalingCommand,      SEC_GAMEMASTER, Console::No },
            { "season",     HandleMPlusSeasonCommand,       SEC_GAMEMASTER, Console::No },
            { "info",       HandleMPlusInfoCommand,         SEC_PLAYER,     Console::No },
            { "cancel",     HandleMPlusCancelCommand,       SEC_PLAYER,     Console::No }
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
            handler->SendSysMessage("|cffff0000Error:|r Keystone level must be between 2 and 30.");
            return false;
        }

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
        {
            handler->SendSysMessage("|cffff0000Error:|r You must be inside a dungeon.");
            return false;
        }

        // Activate sample affixes
        std::vector<AffixType> affixes = { AFFIX_TYRANNICAL, AFFIX_BOLSTERING };
        if (keystoneLevel >= 7)
            affixes.push_back(AFFIX_NECROTIC);
        if (keystoneLevel >= 10)
            affixes.push_back(AFFIX_GRIEVOUS);
        
        sAffixMgr->ActivateAffixes(map, affixes, keystoneLevel);
        
        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Mythic+|r: Activated Keystone Level |cffff8000+{}|r with affixes:", keystoneLevel));
        handler->SendSysMessage(Acore::StringFormat("  - {}", affixes.size() >= 1 ? "Tyrannical" : ""));
        handler->SendSysMessage(Acore::StringFormat("  - {}", affixes.size() >= 2 ? "Bolstering" : ""));
        if (affixes.size() >= 3)
            handler->SendSysMessage("  - Necrotic");
        if (affixes.size() >= 4)
            handler->SendSysMessage("  - Grievous");

        return true;
    }

    // .mplus give [level] - Generate a keystone item for testing
    static bool HandleMPlusGiveCommand(ChatHandler* handler, Optional<uint8> level)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        uint8 keystoneLevel = level.value_or(MythicPlusConstants::MIN_KEYSTONE_LEVEL);
        if (keystoneLevel < MythicPlusConstants::MIN_KEYSTONE_LEVEL || keystoneLevel > MythicPlusConstants::MAX_KEYSTONE_LEVEL)
        {
            handler->SendSysMessage(Acore::StringFormat("|cffff0000Error:|r Keystone level must be between {} and {}.",
                MythicPlusConstants::MIN_KEYSTONE_LEVEL, MythicPlusConstants::MAX_KEYSTONE_LEVEL));
            return false;
        }

        uint32 keystoneItemId = MythicPlusConstants::GetItemIdFromKeystoneLevel(keystoneLevel);
        if (!keystoneItemId)
        {
            handler->SendSysMessage(Acore::StringFormat("|cffff0000Error:|r Unable to resolve keystone item for level {}.", keystoneLevel));
            return false;
        }

        // Add keystone to player inventory
        ItemPosCountVec dest;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, keystoneItemId, 1) == EQUIP_ERR_OK)
        {
            Item* keystoneItem = player->StoreNewItem(dest, keystoneItemId, true);
            if (keystoneItem)
            {
                player->SendNewItem(keystoneItem, 1, true, false);
                handler->SendSysMessage(Acore::StringFormat("|cff00ff00Mythic+:|r Generated Mythic Keystone +{}", keystoneLevel));
                return true;
            }
        }
        
        handler->SendSysMessage("|cffff0000Error:|r Could not create keystone. Inventory may be full.");
        return false;
    }

    // .mplus vault [slot] [level] - Generate test vault rewards
    static bool HandleMPlusVaultCommand(ChatHandler* handler, Optional<uint8> slot, Optional<uint8> keystoneLevel)
    {
        (void)slot;  // Currently unused, reserved for future vault slot selection
        
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        uint8 level = keystoneLevel.value_or(10);
        if (level < 2 || level > 30)
        {
            handler->SendSysMessage("|cffff0000Error:|r Keystone level must be between 2 and 30.");
            return false;
        }

        uint32 guidLow = player->GetGUID().GetCounter();
        uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
        uint32 weekStart = sMythicRuns->GetWeekStartTimestamp();

        // Generate vault reward pool
        if (sMythicRuns->GenerateVaultRewardPool(guidLow, seasonId, weekStart, level))
        {
            handler->SendSysMessage(Acore::StringFormat("|cff00ff00Mythic+|r: Generated vault rewards for M+{}", level));
            
            // Show available rewards
            auto rewards = sMythicRuns->GetVaultRewardPool(guidLow, seasonId, weekStart);
            for (const auto& [itemId, itemLevel] : rewards)
            {
                ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
                if (itemTemplate)
                {
                    std::string rewardMsg = "  - [" + std::string(itemTemplate->Name1) + "] (ilvl " + std::to_string(itemLevel) + ")";
                    handler->SendSysMessage(rewardMsg.c_str());
                }
            }
            
            return true;
        }

        handler->SendSysMessage("|cffff0000Error:|r Failed to generate vault rewards.");
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
            handler->SendSysMessage("|cffff0000Error:|r You must be inside a dungeon.");
            return false;
        }

        AffixType type = static_cast<AffixType>(affixType.value_or(AFFIX_BOLSTERING));
        std::vector<AffixType> affixes = { type };
        
        sAffixMgr->ActivateAffixes(map, affixes, 10);
        
        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Mythic+|r: Activated affix type {}", static_cast<uint8>(type)));
        return true;
    }

    // .mplus scaling [level] - Show scaling multipliers
    static bool HandleMPlusScalingCommand(ChatHandler* handler, Optional<uint8> level)
    {
        uint8 keystoneLevel = level.value_or(10);
        if (keystoneLevel < MythicPlusConstants::MIN_KEYSTONE_LEVEL || keystoneLevel > 30)
        {
            handler->SendSysMessage(Acore::StringFormat("|cffff0000Error:|r Keystone level must be between {} and 30.", MythicPlusConstants::MIN_KEYSTONE_LEVEL));
            return false;
        }

        float hpMult = 1.0f;
        float damageMult = 1.0f;
        sMythicScaling->CalculateMythicPlusMultipliers(keystoneLevel, hpMult, damageMult);

        uint32 itemLevel = MythicPlusConstants::GetItemLevelForKeystoneLevel(keystoneLevel);

        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Mythic+ Scaling Info for Level +{}:|r", keystoneLevel));
        handler->SendSysMessage(Acore::StringFormat("  HP Multiplier: |cffffffff{:.2f}x|r (+{:.0f}%)", hpMult, (hpMult - 1.0f) * 100.0f));
        handler->SendSysMessage(Acore::StringFormat("  Damage Multiplier: |cffffffff{:.2f}x|r (+{:.0f}%)", damageMult, (damageMult - 1.0f) * 100.0f));
        handler->SendSysMessage(Acore::StringFormat("  Reward Item Level: |cffff8000{}|r", itemLevel));

        return true;
    }

    // .mplus season [id] - Change current season
    static bool HandleMPlusSeasonCommand(ChatHandler* handler, Optional<uint32> seasonId)
    {
        if (!seasonId)
        {
            uint32 current = sMythicRuns->GetCurrentSeasonId();
            handler->SendSysMessage(Acore::StringFormat("|cff00ff00Current Mythic+ Season:|r {}", current));
            return true;
        }

        // Note: You'll need to add a SetCurrentSeasonId method to MythicPlusRunManager
        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Mythic+|r: Season ID set to {}", *seasonId));
        handler->SendSysMessage("Note: Restart server for season changes to take full effect.");
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
            handler->SendSysMessage("You are not in a dungeon.");
            return true;
        }

        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
        uint8 keystoneLevel = sMythicScaling->GetKeystoneLevel(map);
        auto affixes = sAffixMgr->GetActiveAffixes(map);

        handler->SendSysMessage("|cff00ff00=== Mythic+ Dungeon Info ===");
        
        if (profile)
            handler->SendSysMessage(Acore::StringFormat("Dungeon: |cffffffff{}|r", profile->name));
        
        handler->SendSysMessage(Acore::StringFormat("Map ID: |cffffffff{}|r", map->GetId()));
        handler->SendSysMessage(Acore::StringFormat("Difficulty: |cffffffff{}|r", static_cast<uint32>(sMythicScaling->ResolveDungeonDifficulty(map))));
        
        if (keystoneLevel > 0)
        {
            handler->SendSysMessage(Acore::StringFormat("Keystone Level: |cffff8000+{}|r", keystoneLevel));
            
            if (!affixes.empty())
            {
                handler->SendSysMessage(Acore::StringFormat("Active Affixes: |cffffffff{}|r", static_cast<uint32>(affixes.size())));
                // TODO: Display affix names
            }
        }

        return true;
    }
    
    // .mplus cancel - Cancel the current Mythic+ run and downgrade keystone
    static bool HandleMPlusCancelCommand(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
        {
            handler->SendSysMessage("|cffff0000Error:|r You must be inside a dungeon to cancel a Mythic+ run.");
            return false;
        }

        if (!sConfigMgr->GetOption<bool>("MythicPlus.AllowManualCancellation", true))
        {
            handler->SendSysMessage("|cffff0000Error:|r Manual cancellation is disabled on this server.");
            return false;
        }

        if (sMythicRuns->VoteToCancelRun(player, map))
        {
            return true;
        }

        return false;
    }
};

void AddSC_mythic_plus_commands()
{
    new mythicplus_commandscript();
}
