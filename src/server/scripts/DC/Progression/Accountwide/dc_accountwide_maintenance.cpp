/*
 * DarkChaos-255 Account-Wide Pool Maintenance
 *
 * Owns the lifecycle concerns none of the three pools can own on their own:
 * deleting an account's pooled rows when the account goes away, and sweeping
 * rows left behind by accounts that were deleted while the realm was down.
 */

#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "dc_accountwide_api.h"
#include "dc_accountwide_pool.h"

#include <algorithm>
#include <memory>
#include <set>
#include <string>
#include <vector>

namespace
{
    constexpr char const* CONFIG_PURGE_ORPHANS_ON_STARTUP =
        "DCAccountwide.PurgeOrphansOnStartup";

    // Bounded so a large realm never builds a single oversized statement.
    constexpr std::size_t ID_CHUNK = 500;

    struct PoolTable
    {
        uint8 flag;
        char const* name;
        void (*clearCache)(uint32);
    };

    std::vector<PoolTable> const& PoolTables()
    {
        static std::vector<PoolTable> const tables = {
            { DCAccountWideMaintenance::POOL_ACHIEVEMENTS,
              DCAccountWideAchievements::TableName(), &DCAccountWideAchievements::ClearCache },
            { DCAccountWideMaintenance::POOL_REPUTATION,
              DCAccountWideReputation::TableName(), &DCAccountWideReputation::ClearCache },
            { DCAccountWideMaintenance::POOL_FRIENDS,
              DCAccountWideFriends::TableName(), &DCAccountWideFriends::ClearCache }
        };

        return tables;
    }

    std::string JoinIds(std::vector<uint32> const& ids, std::size_t begin, std::size_t end)
    {
        std::string out;

        for (std::size_t i = begin; i < end; ++i)
        {
            if (i > begin)
                out += ',';

            out += std::to_string(ids[i]);
        }

        return out;
    }

    void DeleteOrphanRows(std::vector<uint32> const& orphans, uint8 mask)
    {
        if (orphans.empty())
            return;

        auto trans = CharacterDatabase.BeginTransaction();

        for (PoolTable const& table : PoolTables())
        {
            if (!(mask & table.flag))
                continue;

            for (std::size_t begin = 0; begin < orphans.size(); begin += ID_CHUNK)
            {
                std::size_t end = std::min(begin + ID_CHUNK, orphans.size());

                trans->Append(Acore::StringFormat(
                    "DELETE FROM `{}` WHERE `account_id` IN ({})",
                    table.name, JoinIds(orphans, begin, end)));
            }
        }

        CharacterDatabase.CommitTransaction(trans);

        LOG_INFO("module.dc", "[DCAccountwide] Purged pooled rows for {} deleted account(s)",
            orphans.size());
    }

    /// Step 3: whatever acore_auth did not confirm is an orphan.
    void ResolveOrphans(std::vector<uint32> candidates, uint8 mask)
    {
        if (candidates.empty())
            return;

        auto known = std::make_shared<std::set<uint32>>();
        auto remaining = std::make_shared<std::size_t>(
            (candidates.size() + ID_CHUNK - 1) / ID_CHUNK);
        auto all = std::make_shared<std::vector<uint32>>(std::move(candidates));

        for (std::size_t begin = 0; begin < all->size(); begin += ID_CHUNK)
        {
            std::size_t end = std::min(begin + ID_CHUNK, all->size());

            DCAddon::EnqueueQueryCallback(LoginDatabase.AsyncQuery(Acore::StringFormat(
                "SELECT `id` FROM `account` WHERE `id` IN ({})", JoinIds(*all, begin, end)))
                .WithCallback([known, remaining, all, mask](QueryResult result)
            {
                if (result)
                {
                    do
                    {
                        known->insert(result->Fetch()[0].Get<uint32>());
                    } while (result->NextRow());
                }

                if (--(*remaining) != 0)
                    return;

                std::vector<uint32> orphans;
                for (uint32 accountId : *all)
                    if (known->find(accountId) == known->end())
                        orphans.push_back(accountId);

                DeleteOrphanRows(orphans, mask);
            }));
        }
    }

    /// Step 2: collect every account id that still has pooled rows.
    void CollectCandidates(uint8 mask)
    {
        std::string unionSql;

        for (PoolTable const& table : PoolTables())
        {
            if (!(mask & table.flag))
                continue;

            if (!unionSql.empty())
                unionSql += " UNION ";

            unionSql += Acore::StringFormat("SELECT DISTINCT `account_id` FROM `{}`", table.name);
        }

        if (unionSql.empty())
            return;

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(unionSql)
            .WithCallback([mask](QueryResult result)
        {
            if (!result)
                return;

            std::vector<uint32> candidates;
            do
            {
                candidates.push_back(result->Fetch()[0].Get<uint32>());
            } while (result->NextRow());

            ResolveOrphans(std::move(candidates), mask);
        }));
    }

    class DCAccountWideAccountScript : public AccountScript
    {
    public:
        DCAccountWideAccountScript() : AccountScript("DCAccountWideAccountScript") { }

        void OnBeforeAccountDelete(uint32 accountId) override
        {
            DCAccountWideMaintenance::PurgeAccount(accountId, DCAccountWideMaintenance::POOL_ALL);
        }
    };

    class DCAccountWideMaintenanceWorldScript : public WorldScript
    {
    public:
        DCAccountWideMaintenanceWorldScript() : WorldScript("DCAccountWideMaintenanceWorldScript") { }

        void OnStartup() override
        {
            if (!sConfigMgr->GetOption<bool>(CONFIG_PURGE_ORPHANS_ON_STARTUP, true))
                return;

            DCAccountWideMaintenance::PurgeOrphans(DCAccountWideMaintenance::POOL_ALL);
        }
    };
}

namespace DCAccountWideMaintenance
{
    void PurgeAccount(uint32 accountId, uint8 mask)
    {
        if (!accountId || !mask)
            return;

        auto trans = CharacterDatabase.BeginTransaction();

        for (PoolTable const& table : PoolTables())
        {
            if (!(mask & table.flag))
                continue;

            trans->Append(Acore::StringFormat(
                "DELETE FROM `{}` WHERE `account_id` = {}", table.name, accountId));

            table.clearCache(accountId);
        }

        CharacterDatabase.CommitTransaction(trans);

        LOG_INFO("module.dc", "[DCAccountwide] Purged pooled rows for account {} (mask {})",
            accountId, uint32(mask));
    }

    void PurgeOrphans(uint8 mask)
    {
        if (!mask)
            return;

        // Sanity probe first. A null/zero result here means acore_auth is
        // unreachable or empty, and treating that as "no account exists" would
        // wipe every pool on the realm.
        DCAddon::EnqueueQueryCallback(
            LoginDatabase.AsyncQuery("SELECT COUNT(*) FROM `account`")
            .WithCallback([mask](QueryResult result)
        {
            if (!result || result->Fetch()[0].Get<uint64>() == 0)
            {
                LOG_WARN("module.dc",
                    "[DCAccountwide] Orphan purge aborted: the account table is "
                    "unreadable or empty");
                return;
            }

            CollectCandidates(mask);
        }));
    }
}

void AddSC_dc_accountwide_maintenance()
{
    new DCAccountWideAccountScript();
    new DCAccountWideMaintenanceWorldScript();
}
