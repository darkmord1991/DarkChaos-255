/*
 * DarkChaos-255 Account-Wide Reputation Pools
 *
 * Keeps reputation progress at the account level and synchronizes it across
 * characters on login.
 */

#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Log.h"
#include "Player.h"
#include "ReputationMgr.h"
#include "ScriptMgr.h"

#include <algorithm>
#include <unordered_map>
#include <unordered_set>

namespace
{
    namespace Config
    {
        constexpr char const* ENABLE = "DCReputation.Accountwide.Enable";
        constexpr char const* SYNC_ON_LOGIN =
            "DCReputation.Accountwide.SyncOnLogin";
        constexpr char const* HIGHEST_WINS =
            "DCReputation.Accountwide.HighestWins";
        constexpr char const* ANNOUNCE_SYNC =
            "DCReputation.Accountwide.AnnounceSync";
        constexpr char const* DEBUG = "DCReputation.Accountwide.Debug";
    }

    constexpr char const* TABLE_NAME = "dc_account_reputation_pools";

    using ReputationPool = std::unordered_map<uint32, int32>;

    std::unordered_map<uint32, ReputationPool> gAccountReputationCache;
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

    bool IsHighestWinsEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::HIGHEST_WINS, true);
    }

    bool IsAnnounceSyncEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::ANNOUNCE_SYNC, false);
    }

    bool IsDebugEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::DEBUG, false);
    }

    int32 ClampStanding(int32 standing)
    {
        return std::clamp(
            standing,
            ReputationMgr::Reputation_Bottom,
            ReputationMgr::Reputation_Cap);
    }

    bool ShouldTrackFaction(FactionEntry const* factionEntry)
    {
        return factionEntry && factionEntry->CanHaveReputation() &&
            factionEntry->reputationListID >= 0;
    }

    void EnsurePoolTableExists()
    {
        CharacterDatabase.DirectExecute(
            "CREATE TABLE IF NOT EXISTS `dc_account_reputation_pools` ("
            "`account_id` INT UNSIGNED NOT NULL,"
            "`faction_id` INT UNSIGNED NOT NULL,"
            "`standing` INT NOT NULL DEFAULT 0,"
            "`updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP "
            "ON UPDATE CURRENT_TIMESTAMP,"
            "PRIMARY KEY (`account_id`, `faction_id`),"
            "KEY `idx_faction` (`faction_id`)"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 "
            "COLLATE=utf8mb4_unicode_ci "
            "COMMENT='DarkChaos: Account-wide reputation pools'");
    }

    void ClearAccountCache(uint32 accountId)
    {
        gAccountReputationCache.erase(accountId);
        gLoadedAccounts.erase(accountId);
    }

    ReputationPool& GetAccountPool(uint32 accountId)
    {
        ReputationPool& pool = gAccountReputationCache[accountId];

        if (gLoadedAccounts.find(accountId) != gLoadedAccounts.end())
            return pool;

        gLoadedAccounts.insert(accountId);

        QueryResult result = CharacterDatabase.Query(
            "SELECT `faction_id`, `standing` FROM `{}` "
            "WHERE `account_id` = {}",
            TABLE_NAME, accountId);

        if (!result)
            return pool;

        do
        {
            Field* fields = result->Fetch();
            uint32 factionId = fields[0].Get<uint32>();
            int32 standing = ClampStanding(fields[1].Get<int32>());
            pool[factionId] = standing;
        } while (result->NextRow());

        return pool;
    }

    void SavePoolStanding(uint32 accountId, uint32 factionId, int32 standing)
    {
        CharacterDatabase.Execute(
            "INSERT INTO `{}` (`account_id`, `faction_id`, `standing`) "
            "VALUES ({}, {}, {}) "
            "ON DUPLICATE KEY UPDATE `standing` = {}, `updated_at` = NOW()",
            TABLE_NAME, accountId, factionId, standing, standing);
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
        bool highestWins,
        bool overwriteExisting,
        bool debug,
        uint32& mergedCount)
    {
        if (!player)
            return;

        ReputationMgr const& reputationMgr = player->GetReputationMgr();
        ReputationPool& pool = GetAccountPool(accountId);

        for (auto const& [repListId, factionState] : reputationMgr.GetStateList())
        {
            (void)repListId;

            FactionEntry const* factionEntry =
                sFactionStore.LookupEntry(factionState.ID);
            if (!ShouldTrackFaction(factionEntry))
                continue;

            int32 currentStanding =
                ClampStanding(reputationMgr.GetReputation(factionEntry));
            int32 baseStanding =
                ClampStanding(reputationMgr.GetBaseReputation(factionEntry));

            // Keep only changed standings in the pool table.
            if (currentStanding == baseStanding)
                continue;

            auto poolIt = pool.find(factionEntry->ID);
            if (poolIt == pool.end())
            {
                pool[factionEntry->ID] = currentStanding;
                SavePoolStanding(accountId, factionEntry->ID, currentStanding);
                ++mergedCount;
                continue;
            }

            if (!overwriteExisting)
                continue;

            int32 targetStanding = highestWins
                ? std::max(poolIt->second, currentStanding)
                : currentStanding;

            if (targetStanding == poolIt->second)
                continue;

            poolIt->second = targetStanding;
            SavePoolStanding(accountId, factionEntry->ID, targetStanding);
            ++mergedCount;

            if (debug)
            {
                LOG_INFO(
                    "module.dc",
                    "[DCReputation] Merged faction {} for account {} to {}",
                    factionEntry->ID,
                    accountId,
                    targetStanding);
            }
        }
    }

    void ApplyPoolToCharacter(
        Player* player,
        uint32 accountId,
        bool debug,
        uint32& appliedCount)
    {
        if (!player)
            return;

        ReputationPool& pool = GetAccountPool(accountId);
        if (pool.empty())
            return;

        ScopedSyncGuard guard(player);

        for (auto const& [factionId, pooledStanding] : pool)
        {
            FactionEntry const* factionEntry = sFactionStore.LookupEntry(factionId);
            if (!ShouldTrackFaction(factionEntry))
                continue;

            int32 currentStanding =
                ClampStanding(player->GetReputationMgr().GetReputation(factionEntry));
            if (currentStanding == pooledStanding)
                continue;

            player->SetReputation(factionId, static_cast<float>(pooledStanding));
            ++appliedCount;

            if (debug)
            {
                LOG_INFO(
                    "module.dc",
                    "[DCReputation] Applied pooled faction {} for {}: {} -> {}",
                    factionId,
                    player->GetName(),
                    currentStanding,
                    pooledStanding);
            }
        }
    }

    class DCAccountWideReputationPlayerScript : public PlayerScript
    {
    public:
        DCAccountWideReputationPlayerScript()
            : PlayerScript("DCAccountWideReputationPlayerScript")
        {
        }

        void OnPlayerLogin(Player* player) override
        {
            if (!IsEnabled() || !IsSyncOnLoginEnabled() || !player ||
                !player->GetSession())
                return;

            EnsurePoolTableExists();

            uint32 accountId = player->GetSession()->GetAccountId();
            bool highestWins = IsHighestWinsEnabled();
            bool debug = IsDebugEnabled();

            uint32 mergedCount = 0;
            uint32 appliedCount = 0;

            ReputationPool& pool = GetAccountPool(accountId);

            if (highestWins)
            {
                MergeCharacterIntoPool(
                    player,
                    accountId,
                    true,
                    true,
                    debug,
                    mergedCount);

                ApplyPoolToCharacter(player, accountId, debug, appliedCount);
            }
            else
            {
                // Strict pool mode: apply stored standings first, then only seed
                // missing entries without overwriting existing account values.
                ApplyPoolToCharacter(player, accountId, debug, appliedCount);

                MergeCharacterIntoPool(
                    player,
                    accountId,
                    false,
                    pool.empty(),
                    debug,
                    mergedCount);
            }

            if (IsAnnounceSyncEnabled() && (mergedCount > 0 || appliedCount > 0))
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ccff[Reputation]|r Account-wide sync complete: {} "
                    "pooled, {} applied.",
                    mergedCount,
                    appliedCount);
            }
        }

        bool OnPlayerReputationChange(
            Player* player,
            uint32 factionId,
            int32& standing,
            bool /*incremental*/) override
        {
            if (!IsEnabled() || !player || !player->GetSession())
                return true;

            if (IsSyncInProgress(player))
                return true;

            FactionEntry const* factionEntry = sFactionStore.LookupEntry(factionId);
            if (!ShouldTrackFaction(factionEntry))
                return true;

            EnsurePoolTableExists();

            standing = ClampStanding(standing);

            uint32 accountId = player->GetSession()->GetAccountId();
            bool highestWins = IsHighestWinsEnabled();
            bool debug = IsDebugEnabled();

            ReputationPool& pool = GetAccountPool(accountId);
            auto poolIt = pool.find(factionId);

            int32 pooledStanding = standing;
            if (highestWins && poolIt != pool.end())
                pooledStanding = std::max(poolIt->second, standing);

            if (poolIt != pool.end() && poolIt->second == pooledStanding)
                return true;

            pool[factionId] = pooledStanding;
            SavePoolStanding(accountId, factionId, pooledStanding);

            if (debug)
            {
                LOG_INFO(
                    "module.dc",
                    "[DCReputation] Stored pooled faction {} for account {} = {}",
                    factionId,
                    accountId,
                    pooledStanding);
            }

            return true;
        }

        void OnPlayerLogout(Player* player) override
        {
            if (!player || !player->GetSession())
                return;

            ClearAccountCache(player->GetSession()->GetAccountId());
        }
    };

    class DCAccountWideReputationWorldScript : public WorldScript
    {
    public:
        DCAccountWideReputationWorldScript()
            : WorldScript("DCAccountWideReputationWorldScript")
        {
        }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            if (!IsEnabled())
                return;

            EnsurePoolTableExists();

            LOG_INFO(
                "module.dc",
                "[DCReputation] Account-wide reputation pools enabled "
                "(SyncOnLogin={}, HighestWins={})",
                IsSyncOnLoginEnabled() ? 1 : 0,
                IsHighestWinsEnabled() ? 1 : 0);
        }

        void OnStartup() override
        {
            if (IsEnabled())
                EnsurePoolTableExists();
        }
    };
}

void AddSC_dc_accountwide_reputation()
{
    new DCAccountWideReputationPlayerScript();
    new DCAccountWideReputationWorldScript();
}