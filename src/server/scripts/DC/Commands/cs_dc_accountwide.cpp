/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Admin commands for the account-wide progression pools.
 *
 *   .accountwide status  [player]                      pool + cache state
 *   .accountwide sync    [player]                      force a re-sync now
 *   .accountwide reset   <what> [player]               wipe the account's pools
 *   .accountwide cleanup [what]                        purge rows of deleted accounts
 *
 * <what> is one of: achievements | reputation | friends | all
 */

#include "Chat.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldSession.h"
#include "DC/Progression/Accountwide/dc_accountwide_api.h"

#include <string>

using namespace Acore::ChatCommands;

namespace
{
    using namespace DCAccountWideMaintenance;

    /// Parses the pool selector. Returns 0 when unrecognised.
    uint8 ParsePoolMask(std::string const& what)
    {
        if (what.empty() || what == "all")
            return POOL_ALL;

        if (what == "achievements" || what == "achievement" || what == "ach")
            return POOL_ACHIEVEMENTS;

        if (what == "reputation" || what == "rep")
            return POOL_REPUTATION;

        if (what == "friends" || what == "friend" || what == "friendlist")
            return POOL_FRIENDS;

        return 0;
    }

    /// Resolves the command target: the named player, or the issuer's selection,
    /// or the issuer. Only online players can be targeted - the pools are keyed
    /// by account and cached per session.
    Player* ResolveTarget(ChatHandler* handler, Optional<PlayerIdentifier> const& target)
    {
        if (target)
            return target->GetConnectedPlayer();

        if (Player* selected = handler->getSelectedPlayerOrSelf())
            return selected;

        return handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
    }
}

class DCAccountWideCommandScript : public CommandScript
{
public:
    DCAccountWideCommandScript() : CommandScript("DCAccountWideCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable accountWideTable =
        {
            { "status",  HandleStatusCommand,  SEC_GAMEMASTER,    Console::No  },
            { "sync",    HandleSyncCommand,    SEC_ADMINISTRATOR, Console::No  },
            { "reset",   HandleResetCommand,   SEC_ADMINISTRATOR, Console::No  },
            { "cleanup", HandleCleanupCommand, SEC_ADMINISTRATOR, Console::Yes }
        };

        static ChatCommandTable commandTable =
        {
            { "accountwide", accountWideTable }
        };

        return commandTable;
    }

    static bool HandleStatusCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ResolveTarget(handler, target);
        if (!player || !player->GetSession())
        {
            handler->SendSysMessage("No online target. Account-wide pools are only cached for online players.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        uint32 accountId = player->GetSession()->GetAccountId();

        handler->PSendSysMessage("=== Account-wide pools for {} (account {}) ===",
            player->GetName(), accountId);

        handler->PSendSysMessage("Achievements: {} pooled  (cached: {})",
            DCAccountWideAchievements::PoolSize(accountId),
            DCAccountWideAchievements::IsAccountCached(accountId) ? "yes" : "no");

        handler->PSendSysMessage("Reputation:   {} pooled  (cached: {})",
            DCAccountWideReputation::PoolSize(accountId),
            DCAccountWideReputation::IsAccountCached(accountId) ? "yes" : "no");

        handler->PSendSysMessage("Friends:      {} pooled  (cached: {})",
            DCAccountWideFriends::PoolSize(accountId),
            DCAccountWideFriends::IsAccountCached(accountId) ? "yes" : "no");

        handler->PSendSysMessage("Realm-wide cached accounts: {} / {} / {}",
            DCAccountWideAchievements::CachedAccounts(),
            DCAccountWideReputation::CachedAccounts(),
            DCAccountWideFriends::CachedAccounts());

        return true;
    }

    static bool HandleSyncCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ResolveTarget(handler, target);
        if (!player || !player->GetSession())
        {
            handler->SendSysMessage("No online target.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        uint32 accountId = player->GetSession()->GetAccountId();

        // Only pools already cached can be synced inline; an uncached pool would
        // need a blocking load, which never happens on the world thread. A pool
        // is cached from login onward, so this is only hit right at login.
        bool any = false;

        if (DCAccountWideAchievements::IsAccountCached(accountId))
        {
            DCAccountWideAchievements::ForceSync(player);
            any = true;
        }

        if (DCAccountWideReputation::IsAccountCached(accountId))
        {
            DCAccountWideReputation::ForceSync(player);
            any = true;
        }

        if (DCAccountWideFriends::IsAccountCached(accountId))
        {
            DCAccountWideFriends::ForceSync(player);
            any = true;
        }

        if (!any)
        {
            handler->PSendSysMessage("No pool is cached for account {} yet; the login load is still in flight.",
                accountId);
            return true;
        }

        handler->PSendSysMessage("Account-wide sync run for {} (account {}).",
            player->GetName(), accountId);

        return true;
    }

    static bool HandleResetCommand(ChatHandler* handler, std::string what, Optional<PlayerIdentifier> target)
    {
        uint8 mask = ParsePoolMask(what);
        if (!mask)
        {
            handler->SendSysMessage("Usage: .accountwide reset <achievements|reputation|friends|all> [player]");
            handler->SetSentErrorMessage(true);
            return false;
        }

        Player* player = ResolveTarget(handler, target);
        if (!player || !player->GetSession())
        {
            handler->SendSysMessage("No online target.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        uint32 accountId = player->GetSession()->GetAccountId();
        DCAccountWideMaintenance::PurgeAccount(accountId, mask);

        handler->PSendSysMessage(
            "Cleared account-wide pools ({}) for account {}. "
            "The character keeps everything it already earned; the pool refills on the next login sync.",
            what.empty() ? "all" : what, accountId);

        return true;
    }

    static bool HandleCleanupCommand(ChatHandler* handler, Optional<std::string> what)
    {
        uint8 mask = ParsePoolMask(what ? *what : std::string());
        if (!mask)
        {
            handler->SendSysMessage("Usage: .accountwide cleanup [achievements|reputation|friends|all]");
            handler->SetSentErrorMessage(true);
            return false;
        }

        DCAccountWideMaintenance::PurgeOrphans(mask);

        handler->SendSysMessage(
            "Orphan purge started. Rows belonging to deleted accounts are removed asynchronously; "
            "see the module.dc log for the result.");

        return true;
    }
};

void AddSC_dc_accountwide_commandscript()
{
    new DCAccountWideCommandScript();
}
