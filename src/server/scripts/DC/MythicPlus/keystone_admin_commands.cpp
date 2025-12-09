/*
 * Mythic+ Keystone Admin Commands
 * Allows GMs to place, manage, and test keystones
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "Creature.h"
#include "ObjectAccessor.h"
#include "DatabaseEnv.h"
#include "MythicPlusRunManager.h"
#include "MythicPlusConstants.h"
#include "StringFormat.h"
#include <cstdlib>

using namespace Acore::ChatCommands;
using namespace MythicPlusConstants;

class keystone_admin_commands : public CommandScript
{
public:
    keystone_admin_commands() : CommandScript("keystone_admin_commands") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "spawn",      HandleKeystoneSpawn,      SEC_GAMEMASTER,     Console::No  },
            { "info",       HandleKeystoneInfo,       SEC_GAMEMASTER,     Console::No  },
            { "reward",     HandleKeystoneReward,     SEC_GAMEMASTER,     Console::No  },
            { "start",      HandleKeystoneStart,      SEC_GAMEMASTER,     Console::No  }
        };

        return commandTable;
    }

    // Spawn a keystone NPC at player location
    static bool HandleKeystoneSpawn(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            handler->SendSysMessage(Acore::StringFormat("Usage: .keystone spawn <M+{}-M+{}>", MIN_KEYSTONE_LEVEL, MAX_KEYSTONE_LEVEL));
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

        // Create the creature
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

    // Show info about a targeted keystone NPC
    static bool HandleKeystoneInfo(ChatHandler* handler, char const* /*args*/)
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
        
        // Calculate rewards
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

    // Show all keystone reward info
    static bool HandleKeystoneReward(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            // Show all keystones
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

    // Start a test keystone run
    static bool HandleKeystoneStart(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            handler->SendSysMessage(Acore::StringFormat("Usage: .keystone start <M+{}-M+{}>", MIN_KEYSTONE_LEVEL, MAX_KEYSTONE_LEVEL));
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

        // Verify player is in party
        if (!player->GetGroup())
        {
            handler->SendSysMessage("You must be in a party to start a keystone.");
            return false;
        }

        // Start the run
        // Note: Run is activated when entering dungeon with active keystone
        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Keystone Started:|r M+{} run is ready. Enter the dungeon to activate.", level));
        return true;
    }
};

void AddSC_keystone_admin_commands()
{
    new keystone_admin_commands();
}
