/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * .worldboss command - inspect and (GM) clear per-character world-boss loot
 * lockouts managed by CrossSystemWorldBossMgr (Giant Isles: Oondasta / Thok /
 * Nalak).
 */

#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldSession.h"
#include "DC/CrossSystem/CrossSystemWorldBossMgr.h"

using namespace Acore::ChatCommands;
using namespace DarkChaos::CrossSystem;

class dc_worldboss_commandscript : public CommandScript
{
public:
    dc_worldboss_commandscript() : CommandScript("dc_worldboss_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable worldbossCommandTable =
        {
            { "locks",     HandleWorldBossLocksCommand,     SEC_PLAYER,      Console::No  },
            { "clearlock", HandleWorldBossClearLockCommand, SEC_GAMEMASTER,  Console::Yes }
        };

        static ChatCommandTable commandTable =
        {
            { "worldboss", worldbossCommandTable }
        };

        return commandTable;
    }

    // .worldboss locks - list the calling character's active world-boss loot lockouts.
    static bool HandleWorldBossLocksCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        bool any = false;
        for (WorldBossInfo const* info : sWorldBossMgr->GetAllBosses())
        {
            uint32 const remaining = sWorldBossMgr->GetLockoutRemaining(player, info->creatureEntry);
            if (remaining == 0)
                continue;

            if (!any)
                handler->SendSysMessage("Active world boss loot lockouts:");
            any = true;
            handler->PSendSysMessage("  {} - available again in {}", info->displayName,
                                     WorldBossMgr::FormatDuration(remaining));
        }

        if (!any)
            handler->SendSysMessage("You have no active world boss loot lockouts.");

        return true;
    }

    // .worldboss clearlock [entry] - clear the selected player's lockout for one boss
    // (or all registered bosses if no entry is given).
    static bool HandleWorldBossClearLockCommand(ChatHandler* handler, Optional<uint32> entryArg)
    {
        Player* target = handler->getSelectedPlayerOrSelf();
        if (!target)
        {
            handler->SendSysMessage("No target player selected.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        if (entryArg)
        {
            if (!sWorldBossMgr->GetBossInfo(*entryArg))
            {
                handler->PSendSysMessage("Entry {} is not a registered world boss.", *entryArg);
                handler->SetSentErrorMessage(true);
                return false;
            }

            sWorldBossMgr->ClearPlayerLockout(target, *entryArg);
            handler->PSendSysMessage("Cleared world boss lockout (entry {}) for {}.", *entryArg, target->GetName());
        }
        else
        {
            for (WorldBossInfo const* info : sWorldBossMgr->GetAllBosses())
                sWorldBossMgr->ClearPlayerLockout(target, info->creatureEntry);

            handler->PSendSysMessage("Cleared all world boss lockouts for {}.", target->GetName());
        }

        return true;
    }
};

void AddSC_dc_worldboss_commandscript()
{
    new dc_worldboss_commandscript();
}
