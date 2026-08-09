/*
 * DarkChaos-255 Account-Wide Friendlist
 *
 * Keeps one shared friend list per account and synchronizes it to characters
 * on login.
 *
 * Two rules keep the shared pool from eating itself:
 *
 *  - Validity is split. A friend whose character no longer exists is globally
 *    invalid and is pruned from the pool. A friend the *current* character
 *    merely cannot see (opposite faction, no cross-faction permission) is only
 *    skipped for that character - pruning it would delete the other faction's
 *    friends from the shared pool.
 *  - The pool is only ever overwritten from a character that finished its login
 *    sync. Otherwise a disconnect during the async pool load would write the
 *    character's un-synced list over the whole account.
 */

#include "AccountMgr.h"
#include "CharacterCache.h"
#include "Chat.h"
#include "Common.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectGuid.h"
#include "Player.h"
#include "RBAC.h"
#include "ScriptMgr.h"
#include "SocialMgr.h"
#include "StringFormat.h"
#include "Util.h"
#include "dc_accountwide_pool.h"

#include <string>
#include <unordered_map>
#include <vector>

namespace
{
    namespace ConfigKey
    {
        constexpr char const* ENABLE = "DCFriends.Accountwide.Enable";
        constexpr char const* SYNC_ON_LOGIN = "DCFriends.Accountwide.SyncOnLogin";
        constexpr char const* SAVE_ON_LOGOUT = "DCFriends.Accountwide.SaveOnLogout";
        constexpr char const* STRICT_SYNC = "DCFriends.Accountwide.StrictSync";
        constexpr char const* SAVE_INTERVAL = "DCFriends.Accountwide.SaveIntervalSeconds";
        constexpr char const* ANNOUNCE_SYNC = "DCFriends.Accountwide.AnnounceSync";
        constexpr char const* DEBUG = "DCFriends.Accountwide.Debug";
    }

    constexpr char const* TABLE_NAME = "dc_account_social_friends";
    constexpr std::size_t MAX_NOTE_LENGTH = 48;

    // friend low GUID -> note
    using FriendMap = std::unordered_map<uint32, std::string>;

    DCAccountWide::PoolCache<FriendMap> gPools;
    DCAccountWide::EvictionTimer gEvictionTimer;

    // Characters whose login sync completed; only these may overwrite the pool.
    DCAccountWide::PlayerGuidSet gSyncedPlayers;

    bool IsEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::ENABLE, true); }
    bool IsSyncOnLoginEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::SYNC_ON_LOGIN, true); }
    bool IsSaveOnLogoutEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::SAVE_ON_LOGOUT, true); }
    bool IsStrictSyncEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::STRICT_SYNC, true); }
    bool IsAnnounceSyncEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::ANNOUNCE_SYNC, false); }
    bool IsDebugEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::DEBUG, false); }

    uint32 GetSaveIntervalSeconds()
    {
        return sConfigMgr->GetOption<uint32>(ConfigKey::SAVE_INTERVAL, 300);
    }

    // Cached for OnPlayerUpdate, which runs once per player per world tick and
    // must not hit the config store. Refreshed from OnAfterConfigLoad.
    uint32 gSaveIntervalMs = 300 * IN_MILLISECONDS;

    /**
     * Truncates to the client/DB limit on a character boundary.
     *
     * A plain resize() cuts multi-byte notes mid-sequence, which produces
     * invalid UTF-8; MySQL then rejects the row on a utf8mb4 column and the
     * friend silently vanishes from the pool.
     */
    std::string NormalizeNote(std::string note)
    {
        utf8truncate(note, MAX_NOTE_LENGTH);
        return note;
    }

    /// The friend's character no longer exists - safe to drop from the pool.
    bool IsGloballyValidFriend(uint32 friendLowGuid)
    {
        if (!friendLowGuid)
            return false;

        ObjectGuid friendGuid = ObjectGuid::Create<HighGuid::Player>(friendLowGuid);
        return sCharacterCache->GetCharacterCacheByGuid(friendGuid) != nullptr;
    }

    /// Whether this particular character may hold that friend. Character-scoped:
    /// a false here must never remove the entry from the shared pool.
    bool IsVisibleToCharacter(Player* player, uint32 friendLowGuid)
    {
        if (!player || !player->GetSession() || !friendLowGuid)
            return false;

        if (friendLowGuid == player->GetGUID().GetCounter())
            return false;

        ObjectGuid friendGuid = ObjectGuid::Create<HighGuid::Player>(friendLowGuid);
        CharacterCacheEntry const* cache = sCharacterCache->GetCharacterCacheByGuid(friendGuid);
        if (!cache)
            return false;

        if (AccountMgr::IsPlayerAccount(player->GetSession()->GetSecurity()) &&
            player->GetTeamId() != Player::TeamIdForRace(cache->Race) &&
            !player->GetSession()->HasPermission(rbac::RBAC_PERM_TWO_SIDE_ADD_FRIEND))
        {
            return false;
        }

        return true;
    }

    /**
     * This character's current friends.
     *
     * The core keeps the full social list (friends + notes) in memory from
     * character load onward, so no character_social query is needed.
     */
    FriendMap LoadCharacterFriends(Player* player)
    {
        FriendMap friends;

        PlayerSocial const* social = player ? player->GetSocial() : nullptr;
        if (!social)
            return friends;

        for (auto const& [friendGuid, info] : social->GetSocialMap())
        {
            if (!(info.Flags & SOCIAL_FLAG_FRIEND))
                continue;

            uint32 lowGuid = friendGuid.GetCounter();
            if (!lowGuid)
                continue;

            friends[lowGuid] = NormalizeNote(info.Note);

            if (friends.size() >= SOCIALMGR_FRIEND_LIMIT)
                break;
        }

        return friends;
    }

    void SavePoolToDatabase(uint32 accountId, FriendMap const& pool)
    {
        auto trans = CharacterDatabase.BeginTransaction();

        trans->Append("DELETE FROM `{}` WHERE `account_id` = {}", TABLE_NAME, accountId);

        DCAccountWide::BatchUpsert upsert(TABLE_NAME, "`account_id`, `friend_guid`, `note`", "");

        uint32 written = 0;
        for (auto const& [friendLowGuid, noteRaw] : pool)
        {
            if (!friendLowGuid || written >= SOCIALMGR_FRIEND_LIMIT)
                continue;

            std::string note = NormalizeNote(noteRaw);
            CharacterDatabase.EscapeString(note);

            upsert.AddRow(Acore::StringFormat("({}, {}, '{}')", accountId, friendLowGuid, note));
            ++written;
        }

        upsert.AppendTo(trans);
        CharacterDatabase.CommitTransaction(trans);
    }

    void ParsePool(FriendMap& pool, QueryResult const& result)
    {
        if (!result)
            return;

        do
        {
            Field* fields = result->Fetch();

            uint32 friendLowGuid = fields[0].Get<uint32>();
            if (!friendLowGuid)
                continue;

            pool[friendLowGuid] = NormalizeNote(fields[1].Get<std::string>());

            if (pool.size() >= SOCIALMGR_FRIEND_LIMIT)
                break;
        } while (result->NextRow());
    }

    std::string SelectSql(uint32 accountId)
    {
        return Acore::StringFormat(
            "SELECT `friend_guid`, `note` FROM `{}` WHERE `account_id` = {}", TABLE_NAME, accountId);
    }

    /**
     * Folds this character's friends into the pool without dropping anything
     * that belongs to other characters on the account.
     *
     * Returns how many pool entries it added or updated.
     */
    uint32 MergeCharacterIntoPool(Player* player, FriendMap& pool)
    {
        uint32 changed = 0;

        for (auto const& [friendLowGuid, note] : LoadCharacterFriends(player))
        {
            if (!IsGloballyValidFriend(friendLowGuid))
                continue;

            auto it = pool.find(friendLowGuid);
            if (it == pool.end())
            {
                if (pool.size() >= SOCIALMGR_FRIEND_LIMIT)
                    continue;

                pool[friendLowGuid] = note;
                ++changed;
                continue;
            }

            // A note the character edited this session wins over the stored one.
            if (it->second != note && !note.empty())
            {
                it->second = note;
                ++changed;
            }
        }

        return changed;
    }

    void SavePoolFromCharacter(Player* player)
    {
        uint32 accountId = DCAccountWide::AccountIdOf(player);
        if (!accountId)
            return;

        // Only a character that finished its login sync knows the full account
        // list. Merging (rather than replacing) additionally means a character
        // that never synced cannot erase the other characters' friends.
        if (!gSyncedPlayers.Has(player))
        {
            if (IsDebugEnabled())
            {
                LOG_INFO("module.dc",
                    "[DCFriends] Skipped pool save from {} (login sync never completed)",
                    player->GetName());
            }

            return;
        }

        FriendMap& pool = gPools.Get(accountId);

        FriendMap merged = pool;
        uint32 changed = MergeCharacterIntoPool(player, merged);

        // Friends this character dropped this session must leave the pool too,
        // but only the ones it could actually see.
        FriendMap characterFriends = LoadCharacterFriends(player);
        std::vector<uint32> removed;

        // At the client cap, AddToSocialList() refuses further entries, so a
        // pooled friend can be absent from this character without ever having
        // been dropped. Removing then would delete another character's friend.
        bool atFriendCap = characterFriends.size() >= SOCIALMGR_FRIEND_LIMIT;

        for (auto const& [friendLowGuid, note] : merged)
        {
            (void)note;

            if (atFriendCap)
                break;

            if (characterFriends.find(friendLowGuid) != characterFriends.end())
                continue;

            if (!IsVisibleToCharacter(player, friendLowGuid))
                continue; // other faction / not this character's to remove

            removed.push_back(friendLowGuid);
        }

        for (uint32 friendLowGuid : removed)
        {
            merged.erase(friendLowGuid);
            ++changed;
        }

        if (!changed)
            return;

        SavePoolToDatabase(accountId, merged);
        pool = std::move(merged);

        if (IsDebugEnabled())
        {
            LOG_INFO("module.dc",
                "[DCFriends] Saved account-wide friend pool for account {} from {} ({} friends)",
                accountId, player->GetName(), pool.size());
        }
    }

    void SyncPoolToCharacter(Player* player)
    {
        uint32 accountId = DCAccountWide::AccountIdOf(player);
        if (!accountId || !player->GetSocial())
            return;

        FriendMap& pool = gPools.Get(accountId);
        FriendMap characterMap = LoadCharacterFriends(player);

        bool strictSync = IsStrictSyncEnabled();
        bool debug = IsDebugEnabled();

        uint32 seeded = 0;
        uint32 added = 0;
        uint32 updated = 0;
        uint32 removed = 0;
        uint32 pruned = 0;

        // Prune only entries that are invalid for everyone.
        std::vector<uint32> pruneKeys;
        for (auto const& [friendLowGuid, note] : pool)
        {
            (void)note;

            if (!IsGloballyValidFriend(friendLowGuid))
                pruneKeys.push_back(friendLowGuid);
        }

        for (uint32 friendLowGuid : pruneKeys)
        {
            pool.erase(friendLowGuid);
            ++pruned;
        }

        if (pool.empty() && !characterMap.empty())
        {
            // First character of the account to sync: seed the pool from it.
            MergeCharacterIntoPool(player, pool);
            seeded = static_cast<uint32>(pool.size());
        }
        else
        {
            if (strictSync)
            {
                // Anything not in the pool was removed on another character;
                // propagating that removal is the whole point of strict sync.
                // Friends added on this character since its last pool save are
                // covered by the periodic save (DCFriends.Accountwide.
                // SaveIntervalSeconds), which bounds the crash-loss window.
                for (auto const& [friendLowGuid, charNote] : characterMap)
                {
                    (void)charNote;

                    if (pool.find(friendLowGuid) != pool.end())
                        continue;

                    player->GetSocial()->RemoveFromSocialList(
                        ObjectGuid::Create<HighGuid::Player>(friendLowGuid), SOCIAL_FLAG_FRIEND);
                    ++removed;
                }

                if (removed > 0)
                    characterMap = LoadCharacterFriends(player);
            }
            else
            {
                seeded += MergeCharacterIntoPool(player, pool);
            }
        }

        for (auto const& [friendLowGuid, poolNote] : pool)
        {
            // Skip, do not prune: this character simply cannot hold that friend.
            if (!IsVisibleToCharacter(player, friendLowGuid))
                continue;

            ObjectGuid friendGuid = ObjectGuid::Create<HighGuid::Player>(friendLowGuid);

            auto it = characterMap.find(friendLowGuid);
            if (it == characterMap.end())
            {
                if (player->GetSocial()->AddToSocialList(friendGuid, SOCIAL_FLAG_FRIEND))
                {
                    player->GetSocial()->SetFriendNote(friendGuid, poolNote);
                    ++added;
                }

                continue;
            }

            if (it->second != poolNote)
            {
                player->GetSocial()->SetFriendNote(friendGuid, poolNote);
                ++updated;
            }
        }

        if (seeded > 0 || pruned > 0)
            SavePoolToDatabase(accountId, pool);

        if (added > 0 || updated > 0 || removed > 0)
            player->GetSocial()->SendSocialList(player, SOCIAL_FLAG_FRIEND);

        gSyncedPlayers.Add(player);

        if (IsAnnounceSyncEnabled() && (seeded || added || updated || removed || pruned))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ccff[Friends]|r Account-wide sync: seeded {}, added {}, updated {}, "
                "removed {}, pruned {}.",
                seeded, added, updated, removed, pruned);
        }

        if (debug && (seeded || added || updated || removed || pruned))
        {
            LOG_INFO("module.dc",
                "[DCFriends] Sync for {} (account {}): seeded {}, added {}, updated {}, "
                "removed {}, pruned {}",
                player->GetName(), accountId, seeded, added, updated, removed, pruned);
        }
    }

    class DCAccountWideFriendlistPlayerScript : public PlayerScript
    {
    public:
        DCAccountWideFriendlistPlayerScript() : PlayerScript("DCAccountWideFriendlistPlayerScript") { }

        void OnPlayerLogin(Player* player) override
        {
            if (!IsEnabled() || !IsSyncOnLoginEnabled() || !DCAccountWide::AccountIdOf(player))
                return;

            uint32 accountId = player->GetSession()->GetAccountId();

            gPools.EnsureLoaded(player, SelectSql(accountId), ParsePool, SyncPoolToCharacter);
        }

        /**
         * The core exposes no hook for adding or removing a friend, so the pool
         * is refreshed on a slow per-player timer as well as at logout. Without
         * it a crash loses everything added since login - and with StrictSync on,
         * the next login would then delete those friends from the character too.
         */
        void OnPlayerUpdate(Player* player, uint32 diff) override
        {
            if (!gSaveIntervalMs || !player)
                return;

            uint32& elapsed = _saveTimers[player->GetGUID().GetCounter()];
            elapsed += diff;

            if (elapsed < gSaveIntervalMs)
                return;

            elapsed = 0;

            if (IsEnabled() && gSyncedPlayers.Has(player))
                SavePoolFromCharacter(player);
        }

        void OnPlayerBeforeLogout(Player* player) override
        {
            if (!IsEnabled() || !IsSaveOnLogoutEnabled())
                return;

            SavePoolFromCharacter(player);
        }

        void OnPlayerLogout(Player* player) override
        {
            if (!player)
                return;

            _saveTimers.erase(player->GetGUID().GetCounter());
            gSyncedPlayers.Remove(player);

            if (uint32 accountId = DCAccountWide::AccountIdOf(player))
                gPools.Clear(accountId);
        }

        void OnPlayerDelete(ObjectGuid guid, uint32 /*accountId*/) override
        {
            if (!IsEnabled())
                return;

            uint32 lowGuid = guid.GetCounter();
            if (!lowGuid)
                return;

            CharacterDatabase.Execute("DELETE FROM `{}` WHERE `friend_guid` = {}", TABLE_NAME, lowGuid);

            // Drop the deleted character from any pool still cached in memory,
            // otherwise an online account would write it straight back.
            gPools.ForEachPool([lowGuid](uint32 /*accountId*/, FriendMap& pool)
            {
                pool.erase(lowGuid);
            });

            if (IsDebugEnabled())
            {
                LOG_INFO("module.dc", "[DCFriends] Removed deleted character {} from all pools", lowGuid);
            }
        }

    private:
        std::unordered_map<uint32, uint32> _saveTimers;
    };

    class DCAccountWideFriendlistWorldScript : public WorldScript
    {
    public:
        DCAccountWideFriendlistWorldScript() : WorldScript("DCAccountWideFriendlistWorldScript") { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            gSaveIntervalMs = GetSaveIntervalSeconds() * IN_MILLISECONDS;

            if (!IsEnabled())
                return;

            LOG_INFO("module.dc",
                "[DCFriends] Account-wide friendlist enabled "
                "(SyncOnLogin={}, SaveOnLogout={}, StrictSync={}, SaveInterval={}s)",
                IsSyncOnLoginEnabled() ? 1 : 0,
                IsSaveOnLogoutEnabled() ? 1 : 0,
                IsStrictSyncEnabled() ? 1 : 0,
                GetSaveIntervalSeconds());
        }

        void OnUpdate(uint32 diff) override
        {
            if (gEvictionTimer.Tick(diff))
                gPools.EvictOfflineAccounts();
        }
    };
}

namespace DCAccountWideFriends
{
    void ClearCache(uint32 accountId) { gPools.Clear(accountId); }
    std::size_t CachedAccounts() { return gPools.CachedAccounts(); }
    bool IsAccountCached(uint32 accountId) { return gPools.IsLoaded(accountId); }
    std::size_t PoolSize(uint32 accountId)
    {
        return gPools.IsLoaded(accountId) ? gPools.Get(accountId).size() : 0;
    }
    void ForceSync(Player* player) { SyncPoolToCharacter(player); }
    char const* TableName() { return TABLE_NAME; }
}

void AddSC_dc_accountwide_friendlist()
{
    new DCAccountWideFriendlistPlayerScript();
    new DCAccountWideFriendlistWorldScript();
}
