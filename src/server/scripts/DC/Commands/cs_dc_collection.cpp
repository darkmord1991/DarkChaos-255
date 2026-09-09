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
 * <entry> also accepts shift-clicked links, which is how a GM actually has the
 * thing in front of them when a player links a mount in chat:
 *
 *   .collection grant [Witherhide Cliffstomper]        DC-Collection link
 *   .collection grant mount [Witherhide Cliffstomper]  same, type spelled out
 *   .collection grant pet [Mini Diablo]                a plain item link
 *
 * A DC-Collection link carries its own type, so the <type> token is optional
 * in front of one. Without link support the command received the raw hyperlink
 * text and reported "not valid for type unsigned int".
 *
 * The target may be offline: the unlock is account-wide, and an offline
 * character picks the spell up from the login sync.
 */

#include "CharacterCache.h"
#include "Chat.h"
#include "ItemTemplate.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringConvert.h"
#include "WorldSession.h"
#include "DC/CollectionSystem/CollectionGrant.h"

#include <string>
#include <string_view>

using namespace Acore::ChatCommands;

namespace
{
    using namespace DCCollection;

    using DcLink = Hyperlink<Acore::Hyperlinks::LinkTags::dc>;
    using ItemLink = Hyperlink<Acore::Hyperlinks::LinkTags::item>;

    // A DC-Collection link names its own type, so it can stand where <type>
    // goes; anything else there is the usual mount/pet/... token.
    using CollectibleTypeArg = Variant<DcLink, std::string>;

    // <entry> is an id, a DC-Collection link, or an item link off the bags.
    using CollectibleEntryArg = Variant<DcLink, ItemLink, uint32>;

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

    /// Reads a DC-Collection link body ("mount:1:300948:i300618:Name") into a
    /// type and the entry id the addon sent. Fields are positional: kind, link
    /// format version, entry id; the rest is display data the command ignores.
    /// That id is what the addon keys its definitions by - a mount spell id, a
    /// pet teaching item id - which is exactly what the grant API normalises.
    bool ParseCollectibleLink(ChatHandler* handler, std::string_view data, CollectionType& type, uint32& entryId)
    {
        auto nextField = [](std::string_view& rest)
        {
            std::string_view::size_type const pos = rest.find(':');
            if (pos == std::string_view::npos)
            {
                std::string_view const all = rest;
                rest = {};
                return all;
            }

            std::string_view const field = rest.substr(0, pos);
            rest = rest.substr(pos + 1);
            return field;
        };

        std::string_view rest = data;
        std::string const kind(nextField(rest));
        nextField(rest); // link format version
        std::string_view const entryField = nextField(rest);

        if (!ParseCollectionType(kind, type) || (type != CollectionType::MOUNT && type != CollectionType::PET))
        {
            handler->PSendSysMessage("That is a '{}' link - only mount and pet links carry a collectible id.", kind);
            handler->SetSentErrorMessage(true);
            return false;
        }

        Optional<uint32> const parsed = Acore::StringTo<uint32>(entryField);
        if (!parsed || !*parsed)
        {
            handler->SendSysMessage("Could not read an entry id out of that link.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        entryId = *parsed;
        return true;
    }

    /// Resolves the <type> / <entry> pair from whichever of the accepted forms
    /// the GM typed. Reports and returns false on anything unusable.
    bool ResolveCollectible(ChatHandler* handler, CollectibleTypeArg const& typeOrLink,
        Optional<CollectibleEntryArg> const& entryArg, CollectionType& type, uint32& entryId)
    {
        // Form: the link stands alone and carries both halves.
        if (typeOrLink.holds_alternative<DcLink>())
        {
            if (!ParseCollectibleLink(handler, *typeOrLink.get<DcLink>(), type, entryId))
                return false;

            if (entryArg)
                handler->SendSysMessage("Note: the link already names an entry, so the extra id was ignored.");

            return true;
        }

        if (!ParseTypeOrReport(handler, typeOrLink.get<std::string>(), type))
            return false;

        if (!entryArg)
        {
            handler->SendSysMessage("Missing entry. Pass an id, or shift-click the mount/pet link into the command.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        CollectibleEntryArg const& entry = *entryArg;

        // Form: "<type> <link>" - the link wins, because it cannot be mistyped.
        if (entry.holds_alternative<DcLink>())
        {
            CollectionType linkType = type;
            if (!ParseCollectibleLink(handler, *entry.get<DcLink>(), linkType, entryId))
                return false;

            if (linkType != type)
            {
                handler->PSendSysMessage("That link is a {} link, not a {} - using {}.",
                    CollectionTypeToName(linkType), CollectionTypeToName(type), CollectionTypeToName(linkType));
                type = linkType;
            }

            return true;
        }

        // Form: "<type> <item link>" - the teaching item, straight off the bags.
        if (entry.holds_alternative<ItemLink>())
        {
            entryId = entry.get<ItemLink>()->Item->ItemId;
            return true;
        }

        entryId = entry.get<uint32>();
        return true;
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

    static bool HandleGrantCommand(ChatHandler* handler, CollectibleTypeArg typeOrLink,
        Optional<CollectibleEntryArg> entryArg, Optional<PlayerIdentifier> target)
    {
        CollectionType type = CollectionType::MOUNT;
        uint32 entryId = 0;
        if (!ResolveCollectible(handler, typeOrLink, entryArg, type, entryId))
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

    static bool HandleRevokeCommand(ChatHandler* handler, CollectibleTypeArg typeOrLink,
        Optional<CollectibleEntryArg> entryArg, Optional<PlayerIdentifier> target)
    {
        CollectionType type = CollectionType::MOUNT;
        uint32 entryId = 0;
        if (!ResolveCollectible(handler, typeOrLink, entryArg, type, entryId))
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

    static bool HandleCheckCommand(ChatHandler* handler, CollectibleTypeArg typeOrLink,
        Optional<CollectibleEntryArg> entryArg, Optional<PlayerIdentifier> target)
    {
        CollectionType type = CollectionType::MOUNT;
        uint32 entryId = 0;
        if (!ResolveCollectible(handler, typeOrLink, entryArg, type, entryId))
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
