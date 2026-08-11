/*
 * CollectionGrant.cpp - DarkChaos Collection Grant API
 *
 * Implementation of the one supported entry point for handing a collectible to
 * a player. See CollectionGrant.h for the contract.
 */

#include "CollectionGrant.h"

#include "Chat.h"
#include "Config.h"
#include "DBCStores.h"
#include "DatabaseEnv.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"

#include <algorithm>
#include <cctype>

namespace DCCollection
{
    // =======================================================================
    // Defined in dc_addon_collection.cpp (same namespace, single definition).
    // Declared here rather than in a shared header because that file is the
    // schema-tolerance layer: it knows whether collection_type is an enum or a
    // tinyint on this deployment, and every write has to go through it.
    // =======================================================================
    std::string GetItemsCollectionTypeValueExpr(CollectionType type);
    std::string BuildItemsCollectionTypeWhereClause(std::string const& columnName, CollectionType type);
    void UpdateMountSpeedBonus(Player* player);
    CharTitlesEntry const* ResolveTitleEntryByAnyKey(uint32 titleKey);
    uint32 FindCompanionSpellIdForItem(uint32 itemId);
    uint32 FindCompanionItemIdForSpell(uint32 spellId);
    uint32 ResolveCompanionSummonSpellFromSpell(uint32 spellId);

    namespace
    {
        // The addon module gate. Spelled out instead of reusing the Config
        // namespace in dc_addon_collection.cpp, which is file-local there.
        constexpr char const* CONFIG_ENABLED = "DCCollection.Enable";

        // dc_collection_items.source_type is VARCHAR(16).
        constexpr size_t SOURCE_TYPE_MAX_LEN = 16;

        bool IsMountSpellId(uint32 spellId)
        {
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (!spellInfo)
                return false;

            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                if (spellInfo->Effects[i].Effect != SPELL_EFFECT_APPLY_AURA)
                    continue;

                if (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED ||
                    spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOD_INCREASE_MOUNTED_FLIGHT_SPEED)
                {
                    return true;
                }
            }

            return false;
        }

        /// Mount teaching items carry the mount spell in one of their five
        /// on-use/on-learn spell slots (slot 0 is usually the generic
        /// "Learning" spell), so pick the first slot that is a mount.
        uint32 FindMountSpellForItem(uint32 itemId)
        {
            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
            if (!proto)
                return 0;

            for (uint8 i = 0; i < MAX_ITEM_PROTO_SPELLS; ++i)
            {
                uint32 spellId = proto->Spells[i].SpellId;
                if (!spellId)
                    continue;

                if (IsMountSpellId(spellId))
                    return spellId;

                // Some teaching items point at a learn-spell wrapper instead of
                // the mount itself.
                if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId))
                {
                    for (uint8 eff = 0; eff < MAX_SPELL_EFFECTS; ++eff)
                    {
                        if (spellInfo->Effects[eff].Effect != SPELL_EFFECT_LEARN_SPELL)
                            continue;

                        uint32 learned = spellInfo->Effects[eff].TriggerSpell;
                        if (learned && IsMountSpellId(learned))
                            return learned;
                    }
                }
            }

            return 0;
        }

        std::string SanitizeSourceType(std::string const& raw)
        {
            std::string out;
            out.reserve(std::min(raw.size(), SOURCE_TYPE_MAX_LEN));

            for (char c : raw)
            {
                if (out.size() >= SOURCE_TYPE_MAX_LEN)
                    break;

                unsigned char const uc = static_cast<unsigned char>(c);
                if (std::isalnum(uc))
                    out.push_back(static_cast<char>(std::toupper(uc)));
                else if (c == '_' || c == '-' || c == ' ')
                    out.push_back('_');
                // anything else (quotes, backslashes) is dropped, which also
                // keeps the value safe to interpolate into the statement below
            }

            if (out.empty())
                out = "REWARD";

            return out;
        }

        /// The account's online character, if any. WotLK allows a single
        /// session per account, so this is at most one player.
        Player* FindOnlinePlayerForAccount(uint32 accountId)
        {
            if (!accountId)
                return nullptr;

            WorldSession* session = sWorldSessionMgr->FindSession(accountId);
            if (!session)
                return nullptr;

            Player* player = session->GetPlayer();
            if (!player || !player->IsInWorld())
                return nullptr;

            return player;
        }

        bool TeachSpellIfPossible(Player* player, uint32 spellId)
        {
            if (!player || !spellId)
                return false;

            if (player->HasSpell(spellId))
                return false;

            if (!player->IsSpellFitByClassAndRace(spellId))
                return false;

            // Silent: the collection toast is the player-facing notification.
            player->addSpell(spellId, SPEC_MASK_ALL, true, false, false);
            return true;
        }

        /// The spell a collectible teaches, or 0 for types that have none.
        uint32 ResolveTeachableSpell(CollectionType type, uint32 entryId)
        {
            switch (type)
            {
                case CollectionType::MOUNT:
                    return entryId;

                case CollectionType::PET:
                    // Normalised pet entries are teaching item ids; legacy rows
                    // may still hold the summon spell directly.
                    if (sObjectMgr->GetItemTemplate(entryId))
                        return FindCompanionSpellIdForItem(entryId);
                    return ResolveCompanionSummonSpellFromSpell(entryId);

                default:
                    return 0;
            }
        }
    }

    // =======================================================================
    // Type / result naming
    // =======================================================================

    char const* GrantResultToString(GrantResult result)
    {
        switch (result)
        {
            case GrantResult::Granted:        return "granted";
            case GrantResult::AlreadyOwned:   return "already owned";
            case GrantResult::InvalidEntry:   return "invalid entry";
            case GrantResult::InvalidType:    return "invalid collection type";
            case GrantResult::SystemDisabled: return "collection system disabled";
            case GrantResult::SchemaMissing:  return "dc_collection_items missing or malformed";
            case GrantResult::NoAccount:      return "no account";
            default:                          return "unknown";
        }
    }

    char const* CollectionTypeToName(CollectionType type)
    {
        switch (type)
        {
            case CollectionType::MOUNT:    return "mount";
            case CollectionType::PET:      return "pet";
            case CollectionType::TOY:      return "toy";
            case CollectionType::HEIRLOOM: return "heirloom";
            case CollectionType::TITLE:    return "title";
            case CollectionType::TRANSMOG: return "transmog";
            case CollectionType::ITEM_SET: return "itemset";
            default:                       return "unknown";
        }
    }

    bool ParseCollectionType(std::string const& token, CollectionType& out)
    {
        std::string lowered = token;
        std::transform(lowered.begin(), lowered.end(), lowered.begin(),
            [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

        if (lowered == "mount" || lowered == "mounts" || lowered == "1")
            out = CollectionType::MOUNT;
        else if (lowered == "pet" || lowered == "pets" || lowered == "companion" || lowered == "2")
            out = CollectionType::PET;
        else if (lowered == "toy" || lowered == "toys" || lowered == "3")
            out = CollectionType::TOY;
        else if (lowered == "heirloom" || lowered == "heirlooms" || lowered == "4")
            out = CollectionType::HEIRLOOM;
        else if (lowered == "title" || lowered == "titles" || lowered == "5")
            out = CollectionType::TITLE;
        else if (lowered == "transmog" || lowered == "appearance" || lowered == "6")
            out = CollectionType::TRANSMOG;
        else
            return false;

        return true;
    }

    // =======================================================================
    // Entry resolution
    // =======================================================================

    uint32 NormalizeCollectibleEntry(CollectionType type, uint32 entryId)
    {
        if (!entryId)
            return 0;

        switch (type)
        {
            case CollectionType::MOUNT:
                // Already a mount spell?
                if (IsMountSpellId(entryId))
                    return entryId;

                // A teaching item id: resolve to the spell it grants.
                if (uint32 spellId = FindMountSpellForItem(entryId))
                    return spellId;

                // An item that teaches no mount is not one.
                if (sObjectMgr->GetItemTemplate(entryId))
                    return 0;

                // Custom/downported mounts whose spell is not in the resident
                // store yet still belong in the collection. A spell that IS
                // loaded and is not a mount is rejected.
                return sSpellMgr->GetSpellInfo(entryId) ? 0 : entryId;

            case CollectionType::PET:
                // The teaching item id is already the stored form. Whether it
                // really teaches a companion is ValidateCollectibleEntry's job,
                // so callers that skip validation still get their row.
                if (sObjectMgr->GetItemTemplate(entryId))
                    return entryId;

                // A spell id: prefer the teaching item, fall back to the spell
                // (the login sync accepts both).
                if (uint32 summonSpellId = ResolveCompanionSummonSpellFromSpell(entryId))
                {
                    if (uint32 itemId = FindCompanionItemIdForSpell(summonSpellId))
                        return itemId;

                    return summonSpellId;
                }

                return 0;

            case CollectionType::TOY:
            case CollectionType::HEIRLOOM:
                return sObjectMgr->GetItemTemplate(entryId) ? entryId : 0;

            case CollectionType::TITLE:
                if (CharTitlesEntry const* titleEntry = ResolveTitleEntryByAnyKey(entryId))
                    return titleEntry->ID;
                return 0;

            case CollectionType::TRANSMOG:
                // Stored by display id; accept an item id and resolve it.
                if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entryId))
                    return proto->DisplayInfoID;

                return FindAnyVariant(entryId) ? entryId : 0;

            default:
                return 0;
        }
    }

    bool ValidateCollectibleEntry(CollectionType type, uint32 entryId)
    {
        if (!entryId)
            return false;

        switch (type)
        {
            case CollectionType::MOUNT:
                // A mount spell, or an id the resident store has never heard of
                // (custom content whose spell loads later). Item ids and known
                // non-mount spells are rejected.
                return IsMountSpellId(entryId) ||
                       (!sObjectMgr->GetItemTemplate(entryId) && !sSpellMgr->GetSpellInfo(entryId));

            case CollectionType::PET:
                if (sObjectMgr->GetItemTemplate(entryId))
                    return FindCompanionSpellIdForItem(entryId) != 0;

                return ResolveCompanionSummonSpellFromSpell(entryId) != 0;

            case CollectionType::TOY:
            case CollectionType::HEIRLOOM:
                return sObjectMgr->GetItemTemplate(entryId) != nullptr;

            case CollectionType::TITLE:
                return ResolveTitleEntryByAnyKey(entryId) != nullptr;

            case CollectionType::TRANSMOG:
                return FindAnyVariant(entryId) != nullptr;

            default:
                return false;
        }
    }

    bool ApplyCollectibleToCharacter(Player* player, CollectionType type, uint32 entryId)
    {
        if (!player || !entryId)
            return false;

        if (type == CollectionType::TITLE)
        {
            CharTitlesEntry const* titleEntry = ResolveTitleEntryByAnyKey(entryId);
            if (!titleEntry || player->HasTitle(titleEntry))
                return false;

            player->SetTitle(titleEntry, false);
            return true;
        }

        return TeachSpellIfPossible(player, ResolveTeachableSpell(type, entryId));
    }

    // =======================================================================
    // Grant
    // =======================================================================

    namespace
    {
        GrantResult DoGrant(uint32 accountId, Player* known, CollectionType type,
            uint32 rawEntryId, GrantOptions const& options)
        {
            if (!sConfigMgr->GetOption<bool>(CONFIG_ENABLED, true))
                return GrantResult::SystemDisabled;

            if (!accountId)
                return GrantResult::NoAccount;

            switch (type)
            {
                case CollectionType::MOUNT:
                case CollectionType::PET:
                case CollectionType::TOY:
                case CollectionType::HEIRLOOM:
                case CollectionType::TITLE:
                case CollectionType::TRANSMOG:
                    break;
                default:
                    return GrantResult::InvalidType;
            }

            uint32 const entryId = NormalizeCollectibleEntry(type, rawEntryId);
            if (!entryId)
            {
                LOG_WARN("module.dc", "DC-Collection: grant of {} {} for account {} rejected - entry does not resolve.",
                    CollectionTypeToName(type), rawEntryId, accountId);
                return GrantResult::InvalidEntry;
            }

            if (!options.skipValidation && !ValidateCollectibleEntry(type, entryId))
            {
                LOG_WARN("module.dc", "DC-Collection: grant of {} {} (normalised {}) for account {} rejected - failed validation.",
                    CollectionTypeToName(type), rawEntryId, entryId, accountId);
                return GrantResult::InvalidEntry;
            }

            std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
            if (itemsEntryCol.empty())
                return GrantResult::SchemaMissing;

            bool const alreadyOwned = HasCollectionItem(accountId, type, entryId);
            std::string const sourceType = SanitizeSourceType(options.sourceType);

            if (!alreadyOwned)
            {
                std::string const sourceId = options.sourceId ? std::to_string(options.sourceId) : "NULL";

                CharacterDatabase.Execute(
                    "INSERT INTO dc_collection_items "
                    "(account_id, collection_type, {}, source_type, source_id, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, '{}', {}, 1, NOW()) "
                    "ON DUPLICATE KEY UPDATE unlocked = 1, acquired_date = NOW()",
                    itemsEntryCol, accountId, GetItemsCollectionTypeValueExpr(type), entryId,
                    sourceType, sourceId);
            }

            // The account has at most one session; prefer the caller's player so
            // a grant issued from that character's own hook stays on it.
            Player* target = known;
            if (!target)
                target = FindOnlinePlayerForAccount(accountId);

            if (target)
            {
                if (options.teach)
                    ApplyCollectibleToCharacter(target, type, entryId);

                if (type == CollectionType::MOUNT)
                    UpdateMountSpeedBonus(target);

                if (!alreadyOwned)
                {
                    if (options.notify)
                        SendCollectibleGranted(target, type, entryId, sourceType, options.sourceText);

                    if (options.announce && target->GetSession())
                    {
                        ChatHandler(target->GetSession()).PSendSysMessage(
                            "|cff00ff00New {} added to your collection.|r{}",
                            CollectionTypeToName(type),
                            options.sourceText.empty() ? "" : Acore::StringFormat(" ({})", options.sourceText));
                    }
                }
            }

            if (type == CollectionType::TRANSMOG && !alreadyOwned)
                InvalidateAccountUnlockedTransmogAppearances(accountId);

            if (!alreadyOwned)
            {
                LOG_INFO("module.dc", "DC-Collection: granted {} {} to account {} (source {}/{}).",
                    CollectionTypeToName(type), entryId, accountId, sourceType, options.sourceId);
            }

            return alreadyOwned ? GrantResult::AlreadyOwned : GrantResult::Granted;
        }
    }

    GrantResult GrantCollectible(Player* player, CollectionType type, uint32 entryId,
        GrantOptions const& options)
    {
        if (!player)
            return GrantResult::NoAccount;

        return DoGrant(GetAccountId(player), player, type, entryId, options);
    }

    GrantResult GrantCollectibleToAccount(uint32 accountId, CollectionType type, uint32 entryId,
        GrantOptions const& options)
    {
        return DoGrant(accountId, nullptr, type, entryId, options);
    }

    GrantResult GrantMount(Player* player, uint32 mountEntry, GrantOptions const& options)
    {
        return GrantCollectible(player, CollectionType::MOUNT, mountEntry, options);
    }

    GrantResult GrantPet(Player* player, uint32 petEntry, GrantOptions const& options)
    {
        return GrantCollectible(player, CollectionType::PET, petEntry, options);
    }

    // =======================================================================
    // Revoke
    // =======================================================================

    bool RevokeCollectible(uint32 accountId, CollectionType type, uint32 entryId, bool unlearn)
    {
        if (!accountId || !entryId)
            return false;

        std::string const& itemsEntryCol = GetCharEntryColumn("dc_collection_items");
        if (itemsEntryCol.empty())
            return false;

        uint32 normalized = NormalizeCollectibleEntry(type, entryId);
        if (!normalized)
            normalized = entryId;  // let a GM clear a row whose entry no longer resolves

        if (!HasCollectionItem(accountId, type, normalized))
            return false;

        // Titles were historically stored by id or by bit index; clear both.
        std::string entryFilter = Acore::StringFormat("{} = {}", itemsEntryCol, normalized);
        if (type == CollectionType::TITLE)
        {
            if (CharTitlesEntry const* titleEntry = ResolveTitleEntryByAnyKey(normalized))
            {
                uint32 const altEntry = (titleEntry->ID == normalized) ? titleEntry->bit_index : titleEntry->ID;
                if (altEntry && altEntry != normalized)
                    entryFilter = Acore::StringFormat("{} IN ({}, {})", itemsEntryCol, normalized, altEntry);
            }
        }

        CharacterDatabase.Execute(
            "DELETE FROM dc_collection_items WHERE account_id = {} AND {} AND {}",
            accountId, BuildItemsCollectionTypeWhereClause("collection_type", type), entryFilter);

        if (type == CollectionType::TRANSMOG)
            InvalidateAccountUnlockedTransmogAppearances(accountId);

        if (unlearn)
        {
            if (Player* player = FindOnlinePlayerForAccount(accountId))
            {
                if (type == CollectionType::TITLE)
                {
                    if (CharTitlesEntry const* titleEntry = ResolveTitleEntryByAnyKey(normalized))
                        if (player->HasTitle(titleEntry))
                            player->SetTitle(titleEntry, true);
                }
                else if (uint32 spellId = ResolveTeachableSpell(type, normalized))
                {
                    if (player->HasSpell(spellId))
                        player->removeSpell(spellId, SPEC_MASK_ALL, false);
                }

                if (type == CollectionType::MOUNT)
                    UpdateMountSpeedBonus(player);
            }
        }

        LOG_INFO("module.dc", "DC-Collection: revoked {} {} from account {}.",
            CollectionTypeToName(type), normalized, accountId);

        return true;
    }

}  // namespace DCCollection
