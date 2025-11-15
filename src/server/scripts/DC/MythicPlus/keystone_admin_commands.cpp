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

using namespace Acore::ChatCommands;

class keystone_admin_commands : public CommandScript
{
public:
    keystone_admin_commands() : CommandScript("keystone_admin_commands") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable keystoneCommandTable =
        {
            { "spawn",      HandleKeystoneSpawn,      SEC_GAMEMASTER,     Console::No  },
            { "info",       HandleKeystoneInfo,       SEC_GAMEMASTER,     Console::No  },
            { "reward",     HandleKeystoneReward,     SEC_GAMEMASTER,     Console::No  },
            { "start",      HandleKeystoneStart,      SEC_GAMEMASTER,     Console::No  },
        };

        static std::vector<ChatCommand> commandTable =
        {
            { "keystone",   keystoneCommandTable,     SEC_GAMEMASTER, "Mythic+ Keystone commands" },
        };

        return commandTable;
    }

    // Spawn a keystone NPC at player location
    static bool HandleKeystoneSpawn(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            handler->SendSysMessage("Usage: .keystone spawn <M+2-M+10>");
            return false;
        }

        uint8 level = atoi(args);
        if (level < 2 || level > 10)
        {
            handler->SendSysMessage("Invalid keystone level. Must be between 2 and 10.");
            return false;
        }

        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Entry format: 100000 + (level * 100)
        uint32 entry = 100000 + (level * 100);

        // Create the creature
        Creature* creature = player->SummonCreature(entry, 
            player->GetX(), player->GetY(), player->GetZ(), 0,
            TEMPSUMMON_CORPSE_DESPAWN, 0);

        if (!creature)
        {
            handler->SendSysMessage("|cffff0000Error:|r Failed to spawn keystone NPC.");
            return false;
        }

        handler->PSendSysMessage("|cff00ff00Keystone Spawn:|r Created M+%d keystone NPC at your location.", level);
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
        uint32 itemLevel = 226;
        if (level >= 2 && level <= 10)
            itemLevel = 232 + ((level - 2) * 2);
        
        uint32 baseTokens = 10 + std::max(0, static_cast<int32>((itemLevel - 190) / 10));

        handler->PSendSysMessage("|cffff8000Keystone Information:|r");
        handler->PSendSysMessage("  Level: M+%d", level);
        handler->PSendSysMessage("  Entry: %u", entry);
        handler->PSendSysMessage("  Item Level: %u", itemLevel);
        handler->PSendSysMessage("  Base Tokens: %u", baseTokens);
        handler->PSendSysMessage("  Difficulty Name: %s", creature->GetName().c_str());
        
        return true;
    }

    // Show all keystone reward info
    static bool HandleKeystoneReward(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            // Show all keystones
            handler->SendSysMessage("|cffff8000Mythic+ Keystone Rewards (M+2 to M+10):|r");
            handler->SendSysMessage("Level | Item Level | Base Tokens");
            handler->SendSysMessage("------|------------|------------");
            
            for (uint8 level = 2; level <= 10; ++level)
            {
                uint32 ilvl = 232 + ((level - 2) * 2);
                uint32 tokens = 10 + ((ilvl - 190) / 10);
                handler->PSendSysMessage("M+%-2u | %-10u | %u", level, ilvl, tokens);
            }
            return true;
        }

        uint8 level = atoi(args);
        if (level < 2 || level > 10)
        {
            handler->SendSysMessage("Invalid keystone level. Must be between 2 and 10.");
            return false;
        }

        uint32 ilvl = 232 + ((level - 2) * 2);
        uint32 tokens = 10 + ((ilvl - 190) / 10);

        handler->PSendSysMessage("|cffff8000Keystone M+%d Rewards:|r", level);
        handler->PSendSysMessage("  Item Level: %u", ilvl);
        handler->PSendSysMessage("  Base Tokens: %u", tokens);
        handler->PSendSysMessage("  Entry: %u", 100000 + (level * 100));
        
        return true;
    }

    // Start a test keystone run
    static bool HandleKeystoneStart(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            handler->SendSysMessage("Usage: .keystone start <M+2-M+10>");
            return false;
        }

        uint8 level = atoi(args);
        if (level < 2 || level > 10)
        {
            handler->SendSysMessage("Invalid keystone level. Must be between 2 and 10.");
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
        if (sMythicRuns->StartRun(player, level))
        {
            handler->PSendSysMessage("|cff00ff00Keystone Started:|r M+%d run initiated.", level);
            return true;
        }
        else
        {
            handler->SendSysMessage("|cffff0000Error:|r Failed to start keystone run.");
            return false;
        }
    }
};

void AddSC_keystone_admin_commands()
{
    new keystone_admin_commands();
}
