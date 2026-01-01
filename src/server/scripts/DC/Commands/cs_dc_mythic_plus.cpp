/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Consolidated Mythic+ Commands - includes keystone admin commands
 */

#include "Chat.h"
#include "Player.h"
#include "Creature.h"
#include "ScriptMgr.h"
#include "../MythicPlus/MythicPlusRunManager.h"
#include "../MythicPlus/MythicPlusAffixes.h"
#include "../MythicPlus/MythicDifficultyScaling.h"
#include "../MythicPlus/MythicPlusConstants.h"
#include "StringFormat.h"
#include <cstdlib>

using namespace Acore::ChatCommands;
using namespace MythicPlusConstants;

class mythicplus_commandscript : public CommandScript
{
public:
    mythicplus_commandscript() : CommandScript("mythicplus_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable vaultCommandTable =
        {
            { "generate",   HandleMPlusVaultGenerateCommand, SEC_GAMEMASTER, Console::No },
            { "addrun",     HandleMPlusVaultAddRunCommand,   SEC_GAMEMASTER, Console::No },
            { "reset",      HandleMPlusVaultResetCommand,    SEC_GAMEMASTER, Console::No },
            { "",           HandleMPlusVaultGenerateCommand, SEC_GAMEMASTER, Console::No }
        };

        // Keystone admin commands (merged from keystone_admin_commands.cpp)
        static ChatCommandTable ksCommandTable =
        {
            { "spawn",      HandleKsSpawnCommand,      SEC_GAMEMASTER, Console::No },
            { "npcinfo",    HandleKsNpcInfoCommand,    SEC_GAMEMASTER, Console::No },
            { "reward",     HandleKsRewardCommand,     SEC_GAMEMASTER, Console::No },
            { "start",      HandleKsStartCommand,      SEC_GAMEMASTER, Console::No }
        };

        static ChatCommandTable mplusCommandTable =
        {
            { "keystone",   HandleMPlusKeystoneCommand,     SEC_GAMEMASTER, Console::No },
            { "give",       HandleMPlusGiveCommand,         SEC_GAMEMASTER, Console::No },
            { "vault",      vaultCommandTable },
            { "ks",         ksCommandTable },
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

    // ============================================================
    // Keystone Admin Commands (merged from keystone_admin_commands.cpp)
    // ============================================================

    // .mplus ks spawn <level> - Spawn a keystone NPC at player location
    static bool HandleKsSpawnCommand(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            handler->SendSysMessage(Acore::StringFormat("Usage: .mplus ks spawn <M+{}-M+{}>", MIN_KEYSTONE_LEVEL, MAX_KEYSTONE_LEVEL));
            return false;
        }

        uint8 level = static_cast<uint8>(std::strtoul(args, nullptr, 10));
        if (level < MIN_KEYSTONE_LEVEL || level > MAX_KEYSTONE_LEVEL)
        {
            handler->SendSysMessage(Acore::StringFormat("Invalid keystone level. Must be between {} and {}.", MIN_KEYSTONE_LEVEL, MAX_KEYSTONE_LEVEL));
            return false;
        }

        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Entry format: 100000 + (level * 100)
        uint32 entry = 100000 + (level * 100);

        Creature* creature = player->SummonCreature(entry,
            player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(), 0,
            TEMPSUMMON_CORPSE_DESPAWN, 0);

        if (!creature)
        {
            handler->SendSysMessage("|cffff0000Error:|r Failed to spawn keystone NPC.");
            return false;
        }

        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Keystone Spawn:|r Created M+{} keystone NPC at your location.", level));
        return true;
    }

    // .mplus ks npcinfo - Show info about a targeted keystone NPC
    static bool HandleKsNpcInfoCommand(ChatHandler* handler, char const* /*args*/)
    {
        Unit* target = handler->getSelectedUnit();
        if (!target || !target->IsCreature())
        {
            handler->SendSysMessage("Please target a creature.");
            return false;
        }

        Creature* creature = target->ToCreature();
        uint32 entry = creature->GetEntry();

        if (entry < 100200 || entry > 101000 || ((entry - 100000) % 100 != 0))
        {
            handler->SendSysMessage("This creature is not a keystone NPC.");
            return false;
        }

        uint8 level = (entry - 100000) / 100;
        uint32 itemLevel = GetItemLevelForKeystoneLevel(level);
        uint32 baseTokens = GetTokenRewardForKeystoneLevel(level);

        handler->SendSysMessage("|cffff8000Keystone Information:|r");
        handler->SendSysMessage(Acore::StringFormat("  Level: M+{}", level));
        handler->SendSysMessage(Acore::StringFormat("  Entry: {}", entry));
        handler->SendSysMessage(Acore::StringFormat("  Item Level: {}", itemLevel));
        handler->SendSysMessage(Acore::StringFormat("  Base Tokens: {}", baseTokens));
        handler->SendSysMessage(("  Difficulty Name: " + creature->GetName()).c_str());

        return true;
    }

    // .mplus ks reward [level] - Show all keystone reward info
    static bool HandleKsRewardCommand(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            handler->SendSysMessage(Acore::StringFormat("|cffff8000Mythic+ Keystone Rewards (M+{} to M+{}):|r", MIN_KEYSTONE_LEVEL, MAX_KEYSTONE_LEVEL));
            handler->SendSysMessage("Level | Item Level | Base Tokens");
            handler->SendSysMessage("------|------------|------------");

            for (uint8 level = MIN_KEYSTONE_LEVEL; level <= MAX_KEYSTONE_LEVEL; ++level)
            {
                uint32 ilvl = GetItemLevelForKeystoneLevel(level);
                uint32 tokens = GetTokenRewardForKeystoneLevel(level);
                handler->SendSysMessage(Acore::StringFormat("M+{:<2} | {:<10} | {}", level, ilvl, tokens));
            }
            return true;
        }

        uint8 level = static_cast<uint8>(std::strtoul(args, nullptr, 10));
        if (level < MIN_KEYSTONE_LEVEL || level > MAX_KEYSTONE_LEVEL)
        {
            handler->SendSysMessage(Acore::StringFormat("Invalid keystone level. Must be between {} and {}.", MIN_KEYSTONE_LEVEL, MAX_KEYSTONE_LEVEL));
            return false;
        }

        uint32 ilvl = GetItemLevelForKeystoneLevel(level);
        uint32 tokens = GetTokenRewardForKeystoneLevel(level);

        handler->SendSysMessage(Acore::StringFormat("|cffff8000Keystone M+{} Rewards:|r", level));
        handler->SendSysMessage(Acore::StringFormat("  Item Level: {}", ilvl));
        handler->SendSysMessage(Acore::StringFormat("  Base Tokens: {}", tokens));
        handler->SendSysMessage(Acore::StringFormat("  Entry: {}", 100000 + (level * 100)));

        return true;
    }

    // .mplus ks start <level> - Start a test keystone run
    static bool HandleKsStartCommand(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            handler->SendSysMessage(Acore::StringFormat("Usage: .mplus ks start <M+{}-M+{}>", MIN_KEYSTONE_LEVEL, MAX_KEYSTONE_LEVEL));
            return false;
        }

        uint8 level = static_cast<uint8>(std::strtoul(args, nullptr, 10));
        if (level < MIN_KEYSTONE_LEVEL || level > MAX_KEYSTONE_LEVEL)
        {
            handler->SendSysMessage(Acore::StringFormat("Invalid keystone level. Must be between {} and {}.", MIN_KEYSTONE_LEVEL, MAX_KEYSTONE_LEVEL));
            return false;
        }

        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!player->GetGroup())
        {
            handler->SendSysMessage("You must be in a party to start a keystone.");
            return false;
        }

        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Keystone Started:|r M+{} run is ready. Enter the dungeon to activate.", level));
        return true;
    }

    // ============================================================
    // Original Mythic+ Commands
    // ============================================================

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

    // .mplus vault generate [level] - Generate test vault rewards
    static bool HandleMPlusVaultGenerateCommand(ChatHandler* handler, Optional<uint8> keystoneLevel)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        (void)keystoneLevel;

        uint32 guidLow = player->GetGUID().GetCounter();
        uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
        uint32 weekStart = sMythicRuns->GetWeekStartTimestamp();

        // Generate vault reward pool
        if (sMythicRuns->GenerateVaultRewardPool(guidLow, seasonId, weekStart))
        {
            handler->SendSysMessage("|cff00ff00Mythic+|r: Generated weekly vault reward pool.");

            // Show available rewards
            auto rewards = sMythicRuns->GetVaultRewardPool(guidLow, seasonId, weekStart);
            for (auto const& [slotIndex, itemId, itemLevel] : rewards)
            {
                ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
                if (itemTemplate)
                {
                    std::string rewardMsg = "  - Slot " + std::to_string(slotIndex) + ": [" + std::string(itemTemplate->Name1) + "] (ilvl " + std::to_string(itemLevel) + ")";
                    handler->SendSysMessage(rewardMsg.c_str());
                }
            }

            return true;
        }

        handler->SendSysMessage("|cffff0000Error:|r Failed to generate vault rewards.");
        return false;
    }

    // .mplus vault addrun [level] [success] - Simulate a run completion
    static bool HandleMPlusVaultAddRunCommand(ChatHandler* handler, Optional<uint8> keystoneLevel, Optional<bool> success)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        uint8 level = keystoneLevel.value_or(10);
        bool isSuccess = success.value_or(true);

        sMythicRuns->SimulateRun(player, level, isSuccess);
        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Mythic+|r: Simulated run completion (Level {}, Success: {})", level, isSuccess));
        return true;
    }

    // .mplus vault reset - Reset weekly vault progress
    static bool HandleMPlusVaultResetCommand(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        sMythicRuns->ResetWeeklyVaultProgress(player);
        handler->SendSysMessage("|cff00ff00Mythic+|r: Weekly vault progress reset.");
        return true;
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

void AddSC_dc_mythic_plus_commandscript()
{
    new mythicplus_commandscript();
}
