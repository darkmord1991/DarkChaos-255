/*
 * DarkChaos-255 Account-Wide Achievements
 *
 * Keeps completed achievements at the account level and synchronizes them
 * across characters on login.
 *
 * Replayed achievements are applied silently and without re-granting the
 * reward mail/item (see AchievementMgr::ReplayScope), so an account earns each
 * achievement reward exactly once no matter how many alts it has.
 */

#include "AchievementMgr.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "Log.h"
#include "Player.h"
#include "RBAC.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "dc_accountwide_pool.h"

#include <algorithm>
#include <limits>
#include <unordered_map>

namespace
{
    namespace ConfigKey
    {
        constexpr char const* ENABLE = "DCAchievements.Accountwide.Enable";
        constexpr char const* SYNC_ON_LOGIN = "DCAchievements.Accountwide.SyncOnLogin";
        constexpr char const* SHARE_REALM_FIRST = "DCAchievements.Accountwide.ShareRealmFirst";
        constexpr char const* GRANT_REWARDS = "DCAchievements.Accountwide.GrantRewards";
        constexpr char const* ANNOUNCE_SYNC = "DCAchievements.Accountwide.AnnounceSync";
        constexpr char const* DEBUG = "DCAchievements.Accountwide.Debug";
    }

    constexpr char const* TABLE_NAME = "dc_account_achievement_pools";

    // achievementId -> completion date (unix seconds, account-earliest)
    using AchievementPool = std::unordered_map<uint32, uint32>;

    DCAccountWide::PoolCache<AchievementPool> gPools;
    DCAccountWide::SyncGuardRegistry gSyncGuard;
    DCAccountWide::EvictionTimer gEvictionTimer;

    bool IsEnabled()
    {
        return sConfigMgr->GetOption<bool>(ConfigKey::ENABLE, true);
    }

    bool IsSyncOnLoginEnabled()
    {
        return sConfigMgr->GetOption<bool>(ConfigKey::SYNC_ON_LOGIN, true);
    }

    bool IsShareRealmFirstEnabled()
    {
        return sConfigMgr->GetOption<bool>(ConfigKey::SHARE_REALM_FIRST, false);
    }

    bool IsGrantRewardsEnabled()
    {
        return sConfigMgr->GetOption<bool>(ConfigKey::GRANT_REWARDS, false);
    }

    bool IsAnnounceSyncEnabled()
    {
        return sConfigMgr->GetOption<bool>(ConfigKey::ANNOUNCE_SYNC, false);
    }

    bool IsDebugEnabled()
    {
        return sConfigMgr->GetOption<bool>(ConfigKey::DEBUG, false);
    }

    /**
     * Config snapshot taken once per sync.
     *
     * ShouldTrackAchievement() runs once per achievement per pass, and a
     * completionist account carries well over a thousand of them; re-reading
     * the config store inside that loop was pure overhead.
     */
    struct SyncSettings
    {
        bool shareRealmFirst = false;
        bool grantRewards = false;
        bool announce = false;
        bool debug = false;

        static SyncSettings Read()
        {
            SyncSettings settings;
            settings.shareRealmFirst = IsShareRealmFirstEnabled();
            settings.grantRewards = IsGrantRewardsEnabled();
            settings.announce = IsAnnounceSyncEnabled();
            settings.debug = IsDebugEnabled();
            return settings;
        }
    };

    /**
     * Whether an achievement may be shared across the account.
     *
     * This predicate reads live config and live DBC state, so it must never
     * drive a DELETE: flipping ShareRealmFirst off, or booting with a stale
     * Achievement.dbc, would otherwise erase pooled rows permanently. Rows that
     * fail the check are simply skipped and stay on disk until they qualify
     * again.
     */
    bool ShouldTrackAchievement(AchievementEntry const* achievement, SyncSettings const& settings)
    {
        if (!achievement)
            return false;

        if (achievement->flags & ACHIEVEMENT_FLAG_COUNTER)
            return false;

        if (!settings.shareRealmFirst &&
            (achievement->flags & (ACHIEVEMENT_FLAG_REALM_FIRST_REACH | ACHIEVEMENT_FLAG_REALM_FIRST_KILL)))
        {
            return false;
        }

        return true;
    }

    uint32 NormalizeCompletionDate(time_t date)
    {
        if (date <= 0)
            return static_cast<uint32>(GameTime::GetGameTime().count());

        time_t const maxDate = static_cast<time_t>(std::numeric_limits<uint32>::max());
        if (date > maxDate)
            return std::numeric_limits<uint32>::max();

        return static_cast<uint32>(date);
    }

    DCAccountWide::BatchUpsert MakeUpsert()
    {
        return DCAccountWide::BatchUpsert(
            TABLE_NAME,
            "`account_id`, `achievement_id`, `completed_at`",
            "`completed_at` = IF(`completed_at` = 0, VALUES(`completed_at`), "
            "LEAST(`completed_at`, VALUES(`completed_at`))), `updated_at` = NOW()");
    }

    void ParsePool(AchievementPool& pool, QueryResult const& result)
    {
        if (!result)
            return;

        do
        {
            Field* fields = result->Fetch();
            pool[fields[0].Get<uint32>()] = fields[1].Get<uint32>();
        } while (result->NextRow());
    }

    std::string SelectSql(uint32 accountId)
    {
        return Acore::StringFormat(
            "SELECT `achievement_id`, `completed_at` FROM `{}` WHERE `account_id` = {}",
            TABLE_NAME, accountId);
    }

    /// Pools everything this character has completed. Never touches the character.
    void MergeCharacterIntoPool(Player* player, uint32 accountId, SyncSettings const& settings,
                                uint32& mergedCount)
    {
        AchievementMgr* achievementMgr = player ? player->GetAchievementMgr() : nullptr;
        if (!achievementMgr)
            return;

        AchievementPool& pool = gPools.Get(accountId);
        DCAccountWide::BatchUpsert upsert = MakeUpsert();

        for (auto const& [achievementIdRaw, completedData] : achievementMgr->GetCompletedAchievements())
        {
            uint32 achievementId = static_cast<uint32>(achievementIdRaw);

            if (!ShouldTrackAchievement(sAchievementStore.LookupEntry(achievementId), settings))
                continue;

            uint32 date = NormalizeCompletionDate(completedData.date);

            auto poolIt = pool.find(achievementId);
            if (poolIt != pool.end() && poolIt->second != 0 && poolIt->second <= date)
                continue;

            pool[achievementId] = date;
            upsert.AddRow(Acore::StringFormat("({}, {}, {})", accountId, achievementId, date));
            ++mergedCount;

            if (settings.debug)
            {
                LOG_INFO("module.dc",
                    "[DCAchievements] Pooled achievement {} for account {} (date={})",
                    achievementId, accountId, date);
            }
        }

        upsert.Execute();
    }

    /**
     * Replays the account pool onto this character.
     *
     * Skipped entirely for GMs and for accounts that cannot earn achievements:
     * AchievementMgr::CompletedAchievement() bails out on those with both a
     * LOG_INFO and a chat message per call, so a GM with a large pool would eat
     * one of each per pooled achievement on every login.
     */
    void ApplyPoolToCharacter(Player* player, uint32 accountId, SyncSettings const& settings,
                              uint32& appliedCount, uint32& skippedCount)
    {
        if (!player || !player->GetSession())
            return;

        AchievementPool& pool = gPools.Get(accountId);
        if (pool.empty())
            return;

        AchievementMgr* achievementMgr = player->GetAchievementMgr();
        if (!achievementMgr)
            return;

        if (player->IsGameMaster() ||
            player->GetSession()->HasPermission(rbac::RBAC_PERM_CANNOT_EARN_ACHIEVEMENTS))
        {
            skippedCount = static_cast<uint32>(pool.size());

            if (settings.debug)
            {
                LOG_INFO("module.dc",
                    "[DCAchievements] Skipped applying {} pooled achievements to {} "
                    "(GM mode or achievements disabled for this account)",
                    skippedCount, player->GetName());
            }

            return;
        }

        DCAccountWide::SyncGuardRegistry::Scope guard(gSyncGuard, player);

        // Silent + no reward mail unless the realm explicitly opts back in.
        AchievementMgr::ReplayScope replay(achievementMgr, !settings.grantRewards);

        for (auto const& [achievementId, date] : pool)
        {
            AchievementEntry const* achievement = sAchievementStore.LookupEntry(achievementId);

            if (!ShouldTrackAchievement(achievement, settings))
            {
                ++skippedCount;
                continue;
            }

            if (player->HasAchieved(achievementId))
                continue;

            player->CompletedAchievement(achievement);

            // Another script may veto the completion via
            // OnPlayerBeforeAchievementComplete; don't count or date those.
            if (!player->HasAchieved(achievementId))
            {
                ++skippedCount;
                continue;
            }

            // Carry the account's original completion date onto the alt.
            if (date != 0)
                achievementMgr->SetCompletedAchievementDate(achievementId, static_cast<time_t>(date));

            ++appliedCount;

            if (settings.debug)
            {
                LOG_INFO("module.dc",
                    "[DCAchievements] Applied pooled achievement {} to {}",
                    achievementId, player->GetName());
            }
        }
    }

    void RunLoginSync(Player* player)
    {
        uint32 accountId = DCAccountWide::AccountIdOf(player);
        if (!accountId)
            return;

        SyncSettings settings = SyncSettings::Read();

        uint32 mergedCount = 0;
        uint32 appliedCount = 0;
        uint32 skippedCount = 0;

        MergeCharacterIntoPool(player, accountId, settings, mergedCount);
        ApplyPoolToCharacter(player, accountId, settings, appliedCount, skippedCount);

        // Applying can cascade into meta achievements the pool does not know
        // about yet; those completions were swallowed by the re-entrancy guard.
        if (appliedCount > 0)
            MergeCharacterIntoPool(player, accountId, settings, mergedCount);

        if (settings.announce && (mergedCount > 0 || appliedCount > 0))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ccff[Achievements]|r Account-wide sync: pooled {}, applied {}.",
                mergedCount, appliedCount);
        }
    }

    class DCAccountWideAchievementsPlayerScript : public PlayerScript
    {
    public:
        DCAccountWideAchievementsPlayerScript() : PlayerScript("DCAccountWideAchievementsPlayerScript") { }

        void OnPlayerLogin(Player* player) override
        {
            if (!IsEnabled() || !IsSyncOnLoginEnabled() || !DCAccountWide::AccountIdOf(player))
                return;

            uint32 accountId = player->GetSession()->GetAccountId();

            // Loaded asynchronously so login never blocks the world thread.
            gPools.EnsureLoaded(player, SelectSql(accountId), ParsePool, RunLoginSync);
        }

        void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement) override
        {
            if (!IsEnabled() || !achievement || gSyncGuard.IsSyncing(player))
                return;

            uint32 accountId = DCAccountWide::AccountIdOf(player);
            if (!accountId)
                return;

            // Never issue a blocking load from a gameplay hook. If the pool is
            // not cached (SyncOnLogin off, or the login load is still in
            // flight) the achievement is picked up by the next merge pass.
            if (!gPools.IsLoaded(accountId))
                return;

            SyncSettings settings = SyncSettings::Read();
            if (!ShouldTrackAchievement(achievement, settings))
                return;

            AchievementPool& pool = gPools.Get(accountId);

            uint32 nowDate = static_cast<uint32>(GameTime::GetGameTime().count());
            uint32 poolDate = nowDate;

            auto poolIt = pool.find(achievement->ID);
            if (poolIt != pool.end() && poolIt->second != 0)
                poolDate = std::min(poolIt->second, nowDate);

            if (poolIt != pool.end() && poolIt->second == poolDate)
                return;

            pool[achievement->ID] = poolDate;

            DCAccountWide::BatchUpsert upsert = MakeUpsert();
            upsert.AddRow(Acore::StringFormat("({}, {}, {})", accountId, achievement->ID, poolDate));
            upsert.Execute();

            if (settings.debug)
            {
                LOG_INFO("module.dc", "[DCAchievements] Stored pooled achievement {} for account {}",
                    achievement->ID, accountId);
            }
        }

        void OnPlayerLogout(Player* player) override
        {
            if (uint32 accountId = DCAccountWide::AccountIdOf(player))
                gPools.Clear(accountId);
        }
    };

    class DCAccountWideAchievementsWorldScript : public WorldScript
    {
    public:
        DCAccountWideAchievementsWorldScript() : WorldScript("DCAccountWideAchievementsWorldScript") { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            if (!IsEnabled())
                return;

            LOG_INFO("module.dc",
                "[DCAchievements] Account-wide achievements enabled "
                "(SyncOnLogin={}, ShareRealmFirst={}, GrantRewards={})",
                IsSyncOnLoginEnabled() ? 1 : 0,
                IsShareRealmFirstEnabled() ? 1 : 0,
                IsGrantRewardsEnabled() ? 1 : 0);
        }

        void OnUpdate(uint32 diff) override
        {
            // WorldSession::LogoutPlayer() skips OnPlayerLogout when redirecting,
            // so logout-driven eviction alone leaks cached pools.
            if (gEvictionTimer.Tick(diff))
                gPools.EvictOfflineAccounts();
        }
    };
}

namespace DCAccountWideAchievements
{
    void ClearCache(uint32 accountId) { gPools.Clear(accountId); }
    std::size_t CachedAccounts() { return gPools.CachedAccounts(); }
    bool IsAccountCached(uint32 accountId) { return gPools.IsLoaded(accountId); }
    std::size_t PoolSize(uint32 accountId)
    {
        return gPools.IsLoaded(accountId) ? gPools.Get(accountId).size() : 0;
    }
    void ForceSync(Player* player) { RunLoginSync(player); }
    char const* TableName() { return TABLE_NAME; }
}

void AddSC_dc_accountwide_achievements()
{
    new DCAccountWideAchievementsPlayerScript();
    new DCAccountWideAchievementsWorldScript();
}
