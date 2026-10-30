/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Admin commands for the Path of Chaos.
 *
 *   .path reload                     re-read dc_path_categories and dc_path_tasks
 *   .path status [player]            the account's progress and balance
 *   .path complete <task> [player]   finish a task; its reward is still claimed in game
 *   .path points <amount> [player]   add Shop Points
 *   .path reset [player]             wipe the account's progress and balance
 *
 * The book lives in memory, and the account behind a character is only loaded while it is
 * online, so everything but reload needs the target online.
 */

#include "Chat.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldSession.h"
#include "DC/Progression/Path/DCPath.h"

#include <algorithm>

using namespace Acore::ChatCommands;

namespace
{
    Player* ResolveOnlineTarget(ChatHandler* handler, Optional<PlayerIdentifier> const& target)
    {
        Optional<PlayerIdentifier> identifier = target;
        if (!identifier)
            identifier = PlayerIdentifier::FromTargetOrSelf(handler);

        Player* player = identifier ? identifier->GetConnectedPlayer() : nullptr;
        if (!player || !player->GetSession())
        {
            handler->SendSysMessage("The target must be online. Select a player or pass a character name.");
            handler->SetSentErrorMessage(true);
            return nullptr;
        }

        return player;
    }
}

class DCPathCommandScript : public CommandScript
{
public:
    DCPathCommandScript() : CommandScript("DCPathCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable pathTable =
        {
            { "reload",   HandleReloadCommand,   SEC_ADMINISTRATOR, Console::Yes },
            { "status",   HandleStatusCommand,   SEC_GAMEMASTER,    Console::Yes },
            { "complete", HandleCompleteCommand, SEC_ADMINISTRATOR, Console::Yes },
            { "points",   HandlePointsCommand,   SEC_ADMINISTRATOR, Console::Yes },
            { "reset",    HandleResetCommand,    SEC_ADMINISTRATOR, Console::Yes }
        };

        static ChatCommandTable commandTable =
        {
            { "path", pathTable }
        };

        return commandTable;
    }

    static bool HandleReloadCommand(ChatHandler* handler)
    {
        uint32 const tasks = sPathMgr->LoadCatalog();
        handler->PSendSysMessage("Path of Chaos: {} tasks loaded. Online clients see the change at their next login.",
            tasks);
        return true;
    }

    static bool HandleStatusCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ResolveOnlineTarget(handler, target);
        if (!player)
            return false;

        DarkChaos::Path::AccountSnapshot const snapshot = sPathMgr->GetSnapshot(player->GetSession()->GetAccountId());
        if (!snapshot.loaded)
        {
            handler->SendSysMessage("That account has not finished loading.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        using namespace DarkChaos::Path;

        auto const countFlag = [&snapshot](uint8 flag)
        {
            return uint32(std::count_if(snapshot.tasks.begin(), snapshot.tasks.end(),
                [flag](ProgressEntry const& entry) { return (entry.flags & flag) != 0; }));
        };

        handler->PSendSysMessage("Path of Chaos, {}: {} tasks complete, {} claimed, {} Shop Points "
            "({} earned in total).", player->GetName(), countFlag(TASK_FLAG_COMPLETED), countFlag(TASK_FLAG_CLAIMED),
            snapshot.points, snapshot.earned);
        return true;
    }

    static bool HandleCompleteCommand(ChatHandler* handler, uint32 taskId, Optional<PlayerIdentifier> target)
    {
        Player* player = ResolveOnlineTarget(handler, target);
        if (!player)
            return false;

        if (!sPathMgr->ForceComplete(player, taskId))
        {
            handler->PSendSysMessage("Task {} does not exist, or the account has not finished loading.", taskId);
            handler->SetSentErrorMessage(true);
            return false;
        }

        handler->PSendSysMessage("Task {} is complete for {}.", taskId, player->GetName());
        return true;
    }

    static bool HandlePointsCommand(ChatHandler* handler, uint32 amount, Optional<PlayerIdentifier> target)
    {
        Player* player = ResolveOnlineTarget(handler, target);
        if (!player)
            return false;

        sPathMgr->GrantPoints(player, amount);
        handler->PSendSysMessage("{} now has {} Shop Points.", player->GetName(),
            sPathMgr->GetPoints(player->GetSession()->GetAccountId()));
        return true;
    }

    static bool HandleResetCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ResolveOnlineTarget(handler, target);
        if (!player)
            return false;

        sPathMgr->ResetAccount(player);
        handler->PSendSysMessage("Path of Chaos progress and Shop Points reset for the account of {}.",
            player->GetName());
        return true;
    }
};

void AddSC_dc_path_commandscript()
{
    new DCPathCommandScript();
}
