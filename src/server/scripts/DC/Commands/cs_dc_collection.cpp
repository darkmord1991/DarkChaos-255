/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Admin commands for the account-wide collection (DC-Collection).
 *
 *   .collection grant  <type> <entry> [player]   unlock a collectible
 *   .collection revoke <type> <entry> [player]   remove an unlock
 *   .collection check  <type> <entry> [player]   report ownership + resolution
 *   .collection reload                           re-read dc_collection_rewards
 *
 * <type> is mount | pet | toy | heirloom | title | transmog (or 1-6).
 * <entry> may be the spell id, the teaching item id, the title id or the
 * appearance id - it is normalised the same way a real reward would be.
 *
 * The target may be offline: the unlock is account-wide, and an offline
 * character picks the spell up from the login sync.
 */

#include "CharacterCache.h"
#include "Chat.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldSession.h"
#include "../CollectionSystem/CollectionGrant.h"

#include <string>

using namespace Acore::ChatCommands;

namespace
{
    using namespace DCCollection;

    struct ResolvedTarget
    {
        uint32 accountId = 0;
        Player* player = nullptr;
        std::string name;
    };

    /// Resolves the command target: the named player (online or not), or the
    /// issuer's selection, or the issuer. Console callers must name a player.
    bool ResolveTarget(ChatHandler* handler, Optional<PlayerIdentifier> const& target, ResolvedTarget& out)
    {
        Optional<PlayerIdentifier> identifier = target;
        if (!identifier)
            identifier = PlayerIdentifier::FromTargetOrSelf(handler);

        if (!identifier)
        {
            handler->SendSysMessage("No target. Select a player or pass a character name.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        out.player = identifier->GetConnectedPlayer();
        out.name = identifier->GetName();
        out.accountId = (out.player && out.player->GetSession())
            ? out.player->GetSession()->GetAccountId()
            : sCharacterCache->GetCharacterAccountIdByGuid(identifier->GetGUID());

        if (!out.accountId)
        {
            handler->PSendSysMessage("Could not resolve an account for {}.", out.name);
            handler->SetSentErrorMessage(true);
            return false;
        }

        return true;
    }

    bool ParseTypeOrReport(ChatHandler* handler, std::string const& token, CollectionType& type)
    {
        if (ParseCollectionType(token, type))
            return true;

        handler->PSendSysMessage("Unknown collection type '{}'. Use mount, pet, toy, heirloom, title or transmog.", token);
        handler->SetSentErrorMessage(true);
        return false;
    }
}

class DCCollectionCommandScript : public CommandScript
{
public:
    DCCollectionCommandScript() : CommandScript("DCCollectionCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable collectionTable =
        {
            { "grant",  HandleGrantCommand,  SEC_ADMINISTRATOR, Console::Yes },
            { "revoke", HandleRevokeCommand, SEC_ADMINISTRATOR, Console::Yes },
            { "check",  HandleCheckCommand,  SEC_GAMEMASTER,    Console::Yes },
            { "reload", HandleReloadCommand, SEC_ADMINISTRATOR, Console::Yes }
        };

        static ChatCommandTable commandTable =
        {
            { "collection", collectionTable }
        };

        return commandTable;
    }

    static bool HandleGrantCommand(ChatHandler* handler, std::string typeToken, uint32 entryId,
        Optional<PlayerIdentifier> target)
    {
        CollectionType type = CollectionType::MOUNT;
        if (!ParseTypeOrReport(handler, typeToken, type))
            return false;

        ResolvedTarget resolved;
        if (!ResolveTarget(handler, target, resolved))
            return false;

        GrantOptions options;
        options.sourceType = "GM";
        options.sourceText = "Granted by a Game Master";
        options.announce = true;

        GrantResult const result = resolved.player
            ? GrantCollectible(resolved.player, type, entryId, options)
            : GrantCollectibleToAccount(resolved.accountId, type, entryId, options);

        switch (result)
        {
            case GrantResult::Granted:
                handler->PSendSysMessage("Granted {} {} to {} (account {}).",
                    CollectionTypeToName(type), entryId, resolved.name, resolved.accountId);
                return true;

            case GrantResult::AlreadyOwned:
                handler->PSendSysMessage("{} already owns that {} - nothing to do.",
                    resolved.name, CollectionTypeToName(type));
                return true;

            default:
                handler->PSendSysMessage("Could not grant {} {}: {}.",
                    CollectionTypeToName(type), entryId, GrantResultToString(result));
                handler->SetSentErrorMessage(true);
                return false;
        }
    }

    static bool HandleRevokeCommand(ChatHandler* handler, std::string typeToken, uint32 entryId,
        Optional<PlayerIdentifier> target)
    {
        CollectionType type = CollectionType::MOUNT;
        if (!ParseTypeOrReport(handler, typeToken, type))
            return false;

        ResolvedTarget resolved;
        if (!ResolveTarget(handler, target, resolved))
            return false;

        if (!RevokeCollectible(resolved.accountId, type, entryId))
        {
            handler->PSendSysMessage("{} does not own {} {}.",
                resolved.name, CollectionTypeToName(type), entryId);
            handler->SetSentErrorMessage(true);
            return false;
        }

        handler->PSendSysMessage("Revoked {} {} from {} (account {}).",
            CollectionTypeToName(type), entryId, resolved.name, resolved.accountId);
        return true;
    }

    static bool HandleCheckCommand(ChatHandler* handler, std::string typeToken, uint32 entryId,
        Optional<PlayerIdentifier> target)
    {
        CollectionType type = CollectionType::MOUNT;
        if (!ParseTypeOrReport(handler, typeToken, type))
            return false;

        ResolvedTarget resolved;
        if (!ResolveTarget(handler, target, resolved))
            return false;

        uint32 const normalized = NormalizeCollectibleEntry(type, entryId);
        if (!normalized)
        {
            handler->PSendSysMessage("{} {} does not resolve to a usable collectible.",
                CollectionTypeToName(type), entryId);
            return true;
        }

        if (normalized != entryId)
            handler->PSendSysMessage("{} {} normalises to entry {}.",
                CollectionTypeToName(type), entryId, normalized);

        handler->PSendSysMessage("Validation: {}.",
            ValidateCollectibleEntry(type, normalized) ? "ok" : "FAILED");

        handler->PSendSysMessage("{} (account {}): {}.",
            resolved.name, resolved.accountId,
            HasCollectionItem(resolved.accountId, type, normalized) ? "owned" : "not owned");

        return true;
    }

    static bool HandleReloadCommand(ChatHandler* handler)
    {
        // Reload first: the table may have been created since startup.
        uint32 const loaded = ReloadCollectionRewards();

        if (!CollectionRewardsTablePresent())
        {
            handler->SendSysMessage("dc_collection_rewards is not present in the world database.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        handler->PSendSysMessage("Reloaded dc_collection_rewards: {} usable rows.", loaded);
        return true;
    }
};

void AddSC_dc_collection_commands()
{
    new DCCollectionCommandScript();
}
