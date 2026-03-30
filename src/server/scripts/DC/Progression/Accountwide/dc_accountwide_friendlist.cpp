/*
 * DarkChaos-255 Account-Wide Friendlist
 *
 * Keeps one shared friend list per account and synchronizes it to
 * characters on login.
 */

#include "AccountMgr.h"
#include "CharacterCache.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectGuid.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SocialMgr.h"
#include "World.h"

#include <algorithm>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace
{
    namespace Config
    {
        constexpr char const* ENABLE = "DCFriends.Accountwide.Enable";
        constexpr char const* SYNC_ON_LOGIN =
            "DCFriends.Accountwide.SyncOnLogin";
        constexpr char const* SAVE_ON_LOGOUT =
            "DCFriends.Accountwide.SaveOnLogout";
        constexpr char const* STRICT_SYNC =
            "DCFriends.Accountwide.StrictSync";
        constexpr char const* ANNOUNCE_SYNC =
            "DCFriends.Accountwide.AnnounceSync";
        constexpr char const* DEBUG = "DCFriends.Accountwide.Debug";
    }

    constexpr char const* TABLE_NAME = "dc_account_social_friends";
    constexpr size_t MAX_NOTE_LENGTH = 48;

    struct FriendEntry
    {
        uint32 friendLowGuid = 0;
        std::string note;
    };

    using FriendMap = std::unordered_map<uint32, std::string>;

    std::unordered_map<uint32, FriendMap> gAccountFriendCache;
    std::unordered_set<uint32> gLoadedAccounts;

    bool IsEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::ENABLE, true);
    }

    bool IsSyncOnLoginEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::SYNC_ON_LOGIN, true);
    }

    bool IsSaveOnLogoutEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::SAVE_ON_LOGOUT, true);
    }

    bool IsStrictSyncEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::STRICT_SYNC, true);
    }

    bool IsAnnounceSyncEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::ANNOUNCE_SYNC, false);
    }

    bool IsDebugEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::DEBUG, false);
    }

    std::string NormalizeNote(std::string note)
    {
        if (note.size() > MAX_NOTE_LENGTH)
            note.resize(MAX_NOTE_LENGTH);

        return note;
    }

    void EnsureFriendPoolTableExists()
    {
        CharacterDatabase.DirectExecute(
            "CREATE TABLE IF NOT EXISTS `dc_account_social_friends` ("
            "`account_id` INT UNSIGNED NOT NULL,"
            "`friend_guid` INT UNSIGNED NOT NULL,"
            "`note` VARCHAR(48) NOT NULL DEFAULT '',"
            "`updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP "
            "ON UPDATE CURRENT_TIMESTAMP,"
            "PRIMARY KEY (`account_id`, `friend_guid`),"
            "KEY `idx_friend_guid` (`friend_guid`)"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 "
            "COLLATE=utf8mb4_unicode_ci "
            "COMMENT='DarkChaos: Account-wide friendlist entries'");
    }

    bool IsFriendValidForPlayer(Player* player, uint32 friendLowGuid)
    {
        if (!player || !player->GetSession() || !friendLowGuid)
            return false;

        if (friendLowGuid == player->GetGUID().GetCounter())
            return false;

        ObjectGuid friendGuid =
            ObjectGuid::Create<HighGuid::Player>(friendLowGuid);
        CharacterCacheEntry const* cache =
            sCharacterCache->GetCharacterCacheByGuid(friendGuid);
        if (!cache)
            return false;

        if (AccountMgr::IsPlayerAccount(player->GetSession()->GetSecurity()) &&
            !sWorld->getBoolConfig(CONFIG_ALLOW_TWO_SIDE_ADD_FRIEND))
        {
            TeamId friendTeam = Player::TeamIdForRace(cache->Race);
            if (friendTeam != player->GetTeamId())
                return false;
        }

        return true;
    }

    std::vector<FriendEntry> LoadCharacterFriends(uint32 characterLowGuid)
    {
        std::vector<FriendEntry> entries;

        QueryResult result = CharacterDatabase.Query(
            "SELECT `friend`, `note` FROM `character_social` "
            "WHERE `guid` = {} AND (`flags` & {}) != 0",
            characterLowGuid,
            static_cast<uint32>(SOCIAL_FLAG_FRIEND));

        if (!result)
            return entries;

        do
        {
            Field* fields = result->Fetch();

            FriendEntry entry;
            entry.friendLowGuid = fields[0].Get<uint32>();
            entry.note = NormalizeNote(fields[1].Get<std::string>());

            if (!entry.friendLowGuid)
                continue;

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    FriendMap ToFriendMap(std::vector<FriendEntry> const& entries)
    {
        FriendMap out;
        for (FriendEntry const& entry : entries)
        {
            if (!entry.friendLowGuid)
                continue;

            out[entry.friendLowGuid] = entry.note;

            if (out.size() >= SOCIALMGR_FRIEND_LIMIT)
                break;
        }

        return out;
    }

    void SavePoolToDatabase(uint32 accountId, FriendMap const& pool)
    {
        auto trans = CharacterDatabase.BeginTransaction();

        trans->Append(
            "DELETE FROM `{}` WHERE `account_id` = {}",
            TABLE_NAME,
            accountId);

        uint32 written = 0;
        for (auto const& [friendLowGuid, noteRaw] : pool)
        {
            if (!friendLowGuid || written >= SOCIALMGR_FRIEND_LIMIT)
                continue;

            std::string note = NormalizeNote(noteRaw);
            CharacterDatabase.EscapeString(note);

            trans->Append(
                "INSERT INTO `{}` (`account_id`, `friend_guid`, `note`) "
                "VALUES ({}, {}, '{}')",
                TABLE_NAME,
                accountId,
                friendLowGuid,
                note);

            ++written;
        }

        CharacterDatabase.CommitTransaction(trans);
    }

    FriendMap& GetAccountPool(uint32 accountId)
    {
        FriendMap& pool = gAccountFriendCache[accountId];

        if (gLoadedAccounts.find(accountId) != gLoadedAccounts.end())
            return pool;

        gLoadedAccounts.insert(accountId);

        QueryResult result = CharacterDatabase.Query(
            "SELECT `friend_guid`, `note` FROM `{}` WHERE `account_id` = {}",
            TABLE_NAME,
            accountId);

        if (!result)
            return pool;

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

        return pool;
    }

    void ClearAccountCache(uint32 accountId)
    {
        gAccountFriendCache.erase(accountId);
        gLoadedAccounts.erase(accountId);
    }

    FriendMap BuildSanitizedCharacterMap(Player* player)
    {
        FriendMap sanitized;
        if (!player)
            return sanitized;

        auto entries = LoadCharacterFriends(player->GetGUID().GetCounter());
        for (FriendEntry const& entry : entries)
        {
            if (!IsFriendValidForPlayer(player, entry.friendLowGuid))
                continue;

            sanitized[entry.friendLowGuid] = NormalizeNote(entry.note);

            if (sanitized.size() >= SOCIALMGR_FRIEND_LIMIT)
                break;
        }

        return sanitized;
    }

    void SavePoolFromCharacter(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = player->GetSession()->GetAccountId();
        FriendMap sanitized = BuildSanitizedCharacterMap(player);

        SavePoolToDatabase(accountId, sanitized);
        gAccountFriendCache[accountId] = std::move(sanitized);
        gLoadedAccounts.insert(accountId);

        if (IsDebugEnabled())
        {
            LOG_INFO(
                "module.dc",
                "[DCFriends] Saved account-wide friend pool for account {} "
                "from {} ({} friends)",
                accountId,
                player->GetName(),
                gAccountFriendCache[accountId].size());
        }
    }

    void SyncPoolToCharacter(Player* player)
    {
        if (!player || !player->GetSession() || !player->GetSocial())
            return;

        uint32 accountId = player->GetSession()->GetAccountId();
        FriendMap& pool = GetAccountPool(accountId);
        FriendMap characterMap =
            ToFriendMap(LoadCharacterFriends(player->GetGUID().GetCounter()));

        uint32 seeded = 0;
        uint32 added = 0;
        uint32 updated = 0;
        uint32 removed = 0;
        uint32 pruned = 0;

        if (pool.empty() && !characterMap.empty())
        {
            FriendMap sanitized = BuildSanitizedCharacterMap(player);
            pool = sanitized;
            SavePoolToDatabase(accountId, pool);
            seeded = static_cast<uint32>(pool.size());
        }
        else
        {
            std::vector<uint32> pruneKeys;
            for (auto const& [friendLowGuid, note] : pool)
            {
                (void)note;
                if (!IsFriendValidForPlayer(player, friendLowGuid))
                    pruneKeys.push_back(friendLowGuid);
            }

            for (uint32 friendLowGuid : pruneKeys)
            {
                pool.erase(friendLowGuid);
                ++pruned;
            }

            if (IsStrictSyncEnabled())
            {
                for (auto const& [friendLowGuid, charNote] : characterMap)
                {
                    (void)charNote;

                    if (pool.find(friendLowGuid) != pool.end())
                        continue;

                    ObjectGuid friendGuid =
                        ObjectGuid::Create<HighGuid::Player>(friendLowGuid);
                    player->GetSocial()->RemoveFromSocialList(
                        friendGuid,
                        SOCIAL_FLAG_FRIEND);
                    ++removed;
                }

                if (removed > 0)
                {
                    characterMap = ToFriendMap(
                        LoadCharacterFriends(player->GetGUID().GetCounter()));
                }
            }

            for (auto const& [friendLowGuid, poolNoteRaw] : pool)
            {
                ObjectGuid friendGuid =
                    ObjectGuid::Create<HighGuid::Player>(friendLowGuid);
                std::string poolNote = NormalizeNote(poolNoteRaw);

                auto it = characterMap.find(friendLowGuid);
                if (it == characterMap.end())
                {
                    if (player->GetSocial()->AddToSocialList(
                            friendGuid, SOCIAL_FLAG_FRIEND))
                    {
                        player->GetSocial()->SetFriendNote(friendGuid, poolNote);
                        ++added;
                    }

                    continue;
                }

                if (NormalizeNote(it->second) != poolNote)
                {
                    player->GetSocial()->SetFriendNote(friendGuid, poolNote);
                    ++updated;
                }
            }

            if (pruned > 0)
                SavePoolToDatabase(accountId, pool);
        }

        if (added > 0 || updated > 0 || removed > 0)
            player->GetSocial()->SendSocialList(player, SOCIAL_FLAG_FRIEND);

        if (IsAnnounceSyncEnabled() &&
            (seeded > 0 || added > 0 || updated > 0 || removed > 0 ||
             pruned > 0))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ccff[Friends]|r Account-wide sync: seeded {}, added {}, "
                "updated {}, removed {}, pruned {}.",
                seeded,
                added,
                updated,
                removed,
                pruned);
        }

        if (IsDebugEnabled() &&
            (seeded > 0 || added > 0 || updated > 0 || removed > 0 ||
             pruned > 0))
        {
            LOG_INFO(
                "module.dc",
                "[DCFriends] Sync for {} (account {}): seeded {}, added {}, "
                "updated {}, removed {}, pruned {}",
                player->GetName(),
                accountId,
                seeded,
                added,
                updated,
                removed,
                pruned);
        }
    }

    class DCAccountWideFriendlistPlayerScript : public PlayerScript
    {
    public:
        DCAccountWideFriendlistPlayerScript()
            : PlayerScript("DCAccountWideFriendlistPlayerScript")
        {
        }

        void OnPlayerLogin(Player* player) override
        {
            if (!IsEnabled() || !IsSyncOnLoginEnabled())
                return;

            EnsureFriendPoolTableExists();
            SyncPoolToCharacter(player);
        }

        void OnPlayerBeforeLogout(Player* player) override
        {
            if (!IsEnabled() || !IsSaveOnLogoutEnabled())
                return;

            EnsureFriendPoolTableExists();
            SavePoolFromCharacter(player);
        }

        void OnPlayerDelete(ObjectGuid guid, uint32 /*accountId*/) override
        {
            if (!IsEnabled())
                return;

            uint32 lowGuid = guid.GetCounter();
            if (!lowGuid)
                return;

            EnsureFriendPoolTableExists();
            CharacterDatabase.Execute(
                "DELETE FROM `{}` WHERE `friend_guid` = {}",
                TABLE_NAME,
                lowGuid);

            if (IsDebugEnabled())
            {
                LOG_INFO(
                    "module.dc",
                    "[DCFriends] Removed deleted character {} from all pools",
                    lowGuid);
            }
        }
    };

    class DCAccountWideFriendlistWorldScript : public WorldScript
    {
    public:
        DCAccountWideFriendlistWorldScript()
            : WorldScript("DCAccountWideFriendlistWorldScript")
        {
        }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            if (!IsEnabled())
                return;

            EnsureFriendPoolTableExists();

            LOG_INFO(
                "module.dc",
                "[DCFriends] Account-wide friendlist enabled "
                "(SyncOnLogin={}, SaveOnLogout={}, StrictSync={})",
                IsSyncOnLoginEnabled() ? 1 : 0,
                IsSaveOnLogoutEnabled() ? 1 : 0,
                IsStrictSyncEnabled() ? 1 : 0);
        }

        void OnStartup() override
        {
            if (IsEnabled())
                EnsureFriendPoolTableExists();
        }
    };
}

void AddSC_dc_accountwide_friendlist()
{
    new DCAccountWideFriendlistPlayerScript();
    new DCAccountWideFriendlistWorldScript();
}