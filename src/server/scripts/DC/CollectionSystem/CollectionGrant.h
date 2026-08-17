/*
 * CollectionGrant.h - DarkChaos Collection Grant API
 *
 * The single supported way for other systems to hand a collectible (mount,
 * pet, toy, heirloom, title, appearance) to a player.
 *
 * Before this existed, the only working routes were indirect: an item that
 * teaches the spell (quest RewardItem / loot / achievement_reward + mail), or
 * hand-written INSERTs into dc_collection_items that forgot to teach the spell,
 * refresh the mount-speed bonus, or tell the addon. GrantCollectible() does all
 * of it in one call:
 *
 *   1. normalises the entry to the id dc_collection_items stores for that type
 *   2. validates it actually resolves to something usable
 *   3. writes the account-wide unlock row (idempotent)
 *   4. teaches the spell / applies the title on every online character of the
 *      account (offline characters pick it up from the login sync)
 *   5. refreshes mount-speed bonuses and transmog caches
 *   6. pushes SMSG_COLLECTIBLE_GRANTED so the DC-Collection UI updates live
 *
 * Entry id conventions (matching dc_collection_items.entry_id):
 *   MOUNT     - mount spell id      (a teaching item id is resolved to it)
 *   PET       - teaching item id    (a summon spell id is resolved to it)
 *   TOY       - item id
 *   HEIRLOOM  - item id
 *   TITLE     - CharTitles id or bit index (both accepted)
 *   TRANSMOG  - display id          (an item id is resolved to it)
 *
 * NOTE: include this header OR CollectionCore.h in a translation unit, never
 * both - they each declare their own DCCollection::CollectionType.
 */

#ifndef DC_COLLECTION_GRANT_H
#define DC_COLLECTION_GRANT_H

#include "DC/AddonExtension/dc_addon_collection.h"

#include <string>
#include <vector>

class Player;
class Quest;
struct AchievementEntry;

namespace DCCollection
{
    // =======================================================================
    // Results
    // =======================================================================

    enum class GrantResult : uint8
    {
        Granted = 0,        // newly unlocked
        AlreadyOwned,       // account already had it (not an error)
        InvalidEntry,       // entry does not resolve to a usable collectible
        InvalidType,        // unsupported CollectionType
        SystemDisabled,     // DCCollection.Enable = 0
        SchemaMissing,      // dc_collection_items absent / wrong shape
        NoAccount           // no account could be resolved for the player
    };

    char const* GrantResultToString(GrantResult result);

    /// True only when the account did not own the collectible before the call.
    inline bool WasNewlyGranted(GrantResult result) { return result == GrantResult::Granted; }

    /// True when the account owns it after the call, however it got there.
    inline bool OwnsAfterGrant(GrantResult result)
    {
        return result == GrantResult::Granted || result == GrantResult::AlreadyOwned;
    }

    // =======================================================================
    // Options
    // =======================================================================

    struct GrantOptions
    {
        /// Written to dc_collection_items.source_type. Sanitised to at most 16
        /// upper-case A-Z/0-9/_ characters. Conventional values: QUEST,
        /// ACHIEVEMENT, SHOP, LOOT, EVENT, GM, REWARD, LEARNED.
        std::string sourceType = "REWARD";

        /// Written to dc_collection_items.source_id (quest id, achievement id,
        /// shop id, ...). 0 stores NULL.
        uint32 sourceId = 0;

        /// Human-readable origin shown by the client toast, e.g.
        /// "Quest: The Ashen Verdict". Optional.
        std::string sourceText;

        /// Teach the spell / apply the title to online characters right away.
        /// Turn off for a silent back-fill that the login sync will apply.
        bool teach = true;

        /// Push SMSG_COLLECTIBLE_GRANTED to the account's online sessions.
        bool notify = true;

        /// Also print a chat line. Off by default - the toast covers it.
        bool announce = false;

        /// Skip the "does this entry resolve to anything" check. Only for
        /// callers that already validated (the login importer, migrations).
        bool skipValidation = false;
    };

    // =======================================================================
    // Grant / revoke
    // =======================================================================

    /// Grant to the player's account. The player need not be the one who
    /// earned it - every online character on the account is updated.
    GrantResult GrantCollectible(Player* player, CollectionType type, uint32 entryId,
        GrantOptions const& options = GrantOptions());

    /// Grant to an account with no Player in hand (offline rewards, console
    /// commands, mail-less achievement payouts). Online characters of the
    /// account are still taught and notified.
    GrantResult GrantCollectibleToAccount(uint32 accountId, CollectionType type, uint32 entryId,
        GrantOptions const& options = GrantOptions());

    /// Convenience wrappers. Accept either the spell id or the teaching item id.
    GrantResult GrantMount(Player* player, uint32 mountEntry, GrantOptions const& options = GrantOptions());
    GrantResult GrantPet(Player* player, uint32 petEntry, GrantOptions const& options = GrantOptions());

    /// Remove an unlock. Also unlearns the spell / removes the title from the
    /// account's online characters when unlearn is true.
    bool RevokeCollectible(uint32 accountId, CollectionType type, uint32 entryId, bool unlearn = true);

    // =======================================================================
    // Resolution helpers (exported for commands, validation tools and the
    // data-driven reward loader)
    // =======================================================================

    /// Maps whatever id a caller has to the id dc_collection_items stores for
    /// that type. Returns 0 when nothing sensible resolves.
    uint32 NormalizeCollectibleEntry(CollectionType type, uint32 entryId);

    /// Checks that an already-normalised entry resolves to a usable
    /// spell/item/title/appearance.
    bool ValidateCollectibleEntry(CollectionType type, uint32 entryId);

    /// Teaches/applies an already-owned collectible to one character without
    /// touching the DB. Returns true when something actually changed.
    bool ApplyCollectibleToCharacter(Player* player, CollectionType type, uint32 entryId);

    /// "mount"/"pet"/"toy"/"heirloom"/"title"/"transmog", or a numeric 1-6.
    bool ParseCollectionType(std::string const& token, CollectionType& out);
    char const* CollectionTypeToName(CollectionType type);

    // =======================================================================
    // Client notifications (implemented in dc_addon_collection.cpp next to the
    // other SMSG senders)
    // =======================================================================

    struct GrantedCollectible
    {
        CollectionType type = CollectionType::MOUNT;
        uint32 entryId = 0;
    };

    /// Single-item push. Also fires the wishlist-satisfied notification.
    void SendCollectibleGranted(Player* player, CollectionType type, uint32 entryId,
        std::string const& sourceType, std::string const& sourceText);

    /// Batched push - one message for many items, so a burst (account-wide
    /// back-fill, bulk GM grant) costs one packet and one client refresh
    /// instead of N.
    void SendCollectiblesGranted(Player* player, std::vector<GrantedCollectible> const& items,
        std::string const& sourceType, std::string const& sourceText);

    /// Tells the client the login-time account-wide sync finished, so it can
    /// refresh the collection UI instead of asking the player to relog.
    void SendCollectionSyncComplete(Player* player, uint32 spellsTaught, uint32 titlesApplied);

    // =======================================================================
    // Data-driven rewards (CollectionRewards.cpp, table dc_collection_rewards)
    // =======================================================================

    /// (Re)reads dc_collection_rewards. Returns the number of usable rows.
    uint32 ReloadCollectionRewards();
    bool CollectionRewardsTablePresent();

    /// Called from the quest / achievement hooks. Safe to call for sources
    /// that have no configured reward.
    void GrantQuestCollectibles(Player* player, Quest const* quest);
    void GrantAchievementCollectibles(Player* player, AchievementEntry const* achievement);
}

#endif // DC_COLLECTION_GRANT_H
