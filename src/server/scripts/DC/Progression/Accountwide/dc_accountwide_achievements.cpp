/*
 * DarkChaos-255 Account-Wide Achievements
 *
 * Keeps completed achievements at the account level and synchronizes them
 * across characters on login.
 */

#include "AchievementMgr.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"

#include <algorithm>
#include <limits>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace
{
    namespace Config
    {
        constexpr char const* ENABLE = "DCAchievements.Accountwide.Enable";
        constexpr char const* SYNC_ON_LOGIN =
            "DCAchievements.Accountwide.SyncOnLogin";
        constexpr char const* SHARE_REALM_FIRST =
            "DCAchievements.Accountwide.ShareRealmFirst";
        constexpr char const* ANNOUNCE_SYNC =
            "DCAchievements.Accountwide.AnnounceSync";
        constexpr char const* DEBUG = "DCAchievements.Accountwide.Debug";
    }

    constexpr char const* TABLE_NAME = "dc_account_achievement_pools";

    using AchievementPool = std::unordered_map<uint32, uint32>;

    std::unordered_map<uint32, AchievementPool> gAccountAchievementCache;
    std::unordered_set<uint32> gLoadedAccounts;
    std::unordered_set<uint32> gSyncingPlayers;

    bool IsEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::ENABLE, true);
    }

    bool IsSyncOnLoginEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::SYNC_ON_LOGIN, true);
    }

    bool IsShareRealmFirstEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::SHARE_REALM_FIRST, false);
    }

    bool IsAnnounceSyncEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::ANNOUNCE_SYNC, false);
    }

    bool IsDebugEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::DEBUG, false);
    }

    bool ShouldTrackAchievement(AchievementEntry const* achievement)
    {
        if (!achievement)
            return false;

        if (achievement->flags & ACHIEVEMENT_FLAG_COUNTER)
            return false;

        if (!IsShareRealmFirstEnabled() &&
            (achievement->flags &
             (ACHIEVEMENT_FLAG_REALM_FIRST_REACH |
              ACHIEVEMENT_FLAG_REALM_FIRST_KILL)))
        {
            return false;
        }

        return true;
    }

    uint32 NormalizeCompletionDate(time_t date)
    {
        if (date <= 0)
            return static_cast<uint32>(GameTime::GetGameTime().count());

        time_t const maxDate =
            static_cast<time_t>(std::numeric_limits<uint32>::max());

        if (date > maxDate)
            return std::numeric_limits<uint32>::max();

        return static_cast<uint32>(date);
    }

    void EnsurePoolTableExists()
    {
        CharacterDatabase.DirectExecute(
            "CREATE TABLE IF NOT EXISTS `dc_account_achievement_pools` ("
            "`account_id` INT UNSIGNED NOT NULL,"
            "`achievement_id` INT UNSIGNED NOT NULL,"
            "`completed_at` INT UNSIGNED NOT NULL DEFAULT 0,"
            "`updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP "
            "ON UPDATE CURRENT_TIMESTAMP,"
            "PRIMARY KEY (`account_id`, `achievement_id`),"
            "KEY `idx_achievement_id` (`achievement_id`)"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 "
            "COLLATE=utf8mb4_unicode_ci "
            "COMMENT='DarkChaos: Account-wide completed achievements'");
    }

    void SavePoolAchievement(uint32 accountId, uint32 achievementId, uint32 date)
    {
        CharacterDatabase.Execute(
            "INSERT INTO `{}` (`account_id`, `achievement_id`, `completed_at`) "
            "VALUES ({}, {}, {}) "
            "ON DUPLICATE KEY UPDATE "
            "`completed_at` = IF(`completed_at` = 0, VALUES(`completed_at`), "
            "LEAST(`completed_at`, VALUES(`completed_at`))), "
            "`updated_at` = NOW()",
            TABLE_NAME,
            accountId,
            achievementId,
            date);
    }

    void DeletePoolAchievement(uint32 accountId, uint32 achievementId)
    {
        CharacterDatabase.Execute(
            "DELETE FROM `{}` WHERE `account_id` = {} "
            "AND `achievement_id` = {}",
            TABLE_NAME,
            accountId,
            achievementId);
    }

    AchievementPool& GetAccountPool(uint32 accountId)
    {
        AchievementPool& pool = gAccountAchievementCache[accountId];

        if (gLoadedAccounts.find(accountId) != gLoadedAccounts.end())
            return pool;

        gLoadedAccounts.insert(accountId);

        QueryResult result = CharacterDatabase.Query(
            "SELECT `achievement_id`, `completed_at` FROM `{}` "
            "WHERE `account_id` = {}",
            TABLE_NAME,
            accountId);

        if (!result)
            return pool;

        do
        {
            Field* fields = result->Fetch();
            uint32 achievementId = fields[0].Get<uint32>();
            uint32 date = fields[1].Get<uint32>();

            AchievementEntry const* achievement =
                sAchievementStore.LookupEntry(achievementId);

            if (!ShouldTrackAchievement(achievement))
                continue;

            pool[achievementId] = date;
        } while (result->NextRow());

        return pool;
    }

    void ClearAccountCache(uint32 accountId)
    {
        gAccountAchievementCache.erase(accountId);
        gLoadedAccounts.erase(accountId);
    }

    class ScopedSyncGuard
    {
    public:
        explicit ScopedSyncGuard(Player* player)
        {
            if (player)
                _guid = player->GetGUID().GetCounter();

            if (_guid != 0)
                gSyncingPlayers.insert(_guid);
        }

        ~ScopedSyncGuard()
        {
            if (_guid != 0)
                gSyncingPlayers.erase(_guid);
        }

    private:
        uint32 _guid = 0;
    };

    bool IsSyncInProgress(Player* player)
    {
        if (!player)
            return false;

        return gSyncingPlayers.find(player->GetGUID().GetCounter()) !=
            gSyncingPlayers.end();
    }

    void MergeCharacterIntoPool(
        Player* player,
        uint32 accountId,
        bool debug,
        uint32& mergedCount)
    {
        if (!player)
            return;

        AchievementMgr* achievementMgr = player->GetAchievementMgr();
        if (!achievementMgr)
            return;

        AchievementPool& pool = GetAccountPool(accountId);
        CompletedAchievementMap const& completed =
            achievementMgr->GetCompletedAchievements();

        for (auto const& [achievementIdRaw, completedData] : completed)
        {
            uint32 achievementId = static_cast<uint32>(achievementIdRaw);

            AchievementEntry const* achievement =
                sAchievementStore.LookupEntry(achievementId);

            if (!ShouldTrackAchievement(achievement))
                continue;

            uint32 date = NormalizeCompletionDate(completedData.date);

            auto poolIt = pool.find(achievementId);
            if (poolIt == pool.end())
            {
                pool[achievementId] = date;
                SavePoolAchievement(accountId, achievementId, date);
                ++mergedCount;
                continue;
            }

            uint32 existingDate = poolIt->second;
            if (existingDate != 0 && existingDate <= date)
                continue;

            poolIt->second = date;
            SavePoolAchievement(accountId, achievementId, date);
            ++mergedCount;

            if (debug)
            {
                LOG_INFO(
                    "module.dc",
                    "[DCAchievements] Updated pooled achievement {} "
                    "for account {} (date={})",
                    achievementId,
                    accountId,
                    date);
            }
        }
    }

    void ApplyPoolToCharacter(
        Player* player,
        uint32 accountId,
        bool debug,
        uint32& appliedCount,
        uint32& prunedCount)
    {
        if (!player)
            return;

        AchievementPool& pool = GetAccountPool(accountId);
        if (pool.empty())
            return;

        ScopedSyncGuard guard(player);

        std::vector<uint32> pruneIds;

        for (auto const& [achievementId, date] : pool)
        {
            (void)date;

            AchievementEntry const* achievement =
                sAchievementStore.LookupEntry(achievementId);

            if (!ShouldTrackAchievement(achievement))
            {
                pruneIds.push_back(achievementId);
                continue;
            }

            if (player->HasAchieved(achievementId))
                continue;

            player->CompletedAchievement(achievement);
            ++appliedCount;

            if (debug)
            {
                LOG_INFO(
                    "module.dc",
                    "[DCAchievements] Applied pooled achievement {} to {}",
                    achievementId,
                    player->GetName());
            }
        }

        for (uint32 achievementId : pruneIds)
        {
            pool.erase(achievementId);
            DeletePoolAchievement(accountId, achievementId);
            ++prunedCount;
        }
    }

    class DCAccountWideAchievementsPlayerScript : public PlayerScript
    {
    public:
        DCAccountWideAchievementsPlayerScript()
            : PlayerScript("DCAccountWideAchievementsPlayerScript")
        {
        }

        void OnPlayerLogin(Player* player) override
        {
            if (!IsEnabled() || !IsSyncOnLoginEnabled() || !player ||
                !player->GetSession())
            {
                return;
            }

            EnsurePoolTableExists();

            uint32 accountId = player->GetSession()->GetAccountId();
            bool debug = IsDebugEnabled();

            uint32 mergedCount = 0;
            uint32 appliedCount = 0;
            uint32 prunedCount = 0;

            MergeCharacterIntoPool(player, accountId, debug, mergedCount);
            ApplyPoolToCharacter(
                player,
                accountId,
                debug,
                appliedCount,
                prunedCount);

            if (appliedCount > 0)
                MergeCharacterIntoPool(player, accountId, debug, mergedCount);

            if (IsAnnounceSyncEnabled() &&
                (mergedCount > 0 || appliedCount > 0 || prunedCount > 0))
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ccff[Achievements]|r Account-wide sync: "
                    "pooled {}, applied {}, pruned {}.",
                    mergedCount,
                    appliedCount,
                    prunedCount);
            }
        }

        void OnPlayerAchievementComplete(
            Player* player,
            AchievementEntry const* achievement) override
        {
            if (!IsEnabled() || !player || !player->GetSession() ||
                !achievement)
            {
                return;
            }

            if (IsSyncInProgress(player))
                return;

            if (!ShouldTrackAchievement(achievement))
                return;

            EnsurePoolTableExists();

            uint32 accountId = player->GetSession()->GetAccountId();
            AchievementPool& pool = GetAccountPool(accountId);

            uint32 nowDate =
                static_cast<uint32>(GameTime::GetGameTime().count());
            uint32 poolDate = nowDate;

            auto poolIt = pool.find(achievement->ID);
            if (poolIt != pool.end() && poolIt->second != 0)
                poolDate = std::min(poolIt->second, nowDate);

            if (poolIt != pool.end() && poolIt->second == poolDate)
                return;

            pool[achievement->ID] = poolDate;
            SavePoolAchievement(accountId, achievement->ID, poolDate);

            if (IsDebugEnabled())
            {
                LOG_INFO(
                    "module.dc",
                    "[DCAchievements] Stored pooled achievement {} "
                    "for account {}",
                    achievement->ID,
                    accountId);
            }
        }

        void OnPlayerLogout(Player* player) override
        {
            if (!player || !player->GetSession())
                return;

            ClearAccountCache(player->GetSession()->GetAccountId());
        }
    };

    class DCAccountWideAchievementsWorldScript : public WorldScript
    {
    public:
        DCAccountWideAchievementsWorldScript()
            : WorldScript("DCAccountWideAchievementsWorldScript")
        {
        }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            if (!IsEnabled())
                return;

            EnsurePoolTableExists();

            LOG_INFO(
                "module.dc",
                "[DCAchievements] Account-wide achievements enabled "
                "(SyncOnLogin={}, ShareRealmFirst={})",
                IsSyncOnLoginEnabled() ? 1 : 0,
                IsShareRealmFirstEnabled() ? 1 : 0);
        }

        void OnStartup() override
        {
            if (IsEnabled())
                EnsurePoolTableExists();
        }
    };
}

void AddSC_dc_accountwide_achievements()
{
    new DCAccountWideAchievementsPlayerScript();
    new DCAccountWideAchievementsWorldScript();
}
