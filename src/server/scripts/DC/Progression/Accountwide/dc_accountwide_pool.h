/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Shared scaffolding for the account-wide progression pools
 * (achievements / reputation / friendlist).
 *
 * All three systems keep the same shape: an account-keyed in-memory pool that
 * is loaded once per account, asynchronously, on the first login of that
 * account, and a change hook that must not re-enter while the pool is being
 * applied to a character. This header owns that shape so the three systems
 * cannot drift apart again.
 *
 * Threading: every type here is world-thread only. The async loads route
 * through DCAddon::EnqueueQueryCallback(), whose continuations are invoked
 * from ProcessPendingQueryCallbacks() on the world thread.
 */

#ifndef DC_ACCOUNTWIDE_POOL_H
#define DC_ACCOUNTWIDE_POOL_H

#include "DatabaseEnv.h"
#include "ObjectAccessor.h"
#include "ObjectGuid.h"
#include "Player.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include "DC/AddonExtension/dc_addon_namespace.h"

#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace DCAccountWide
{
    /**
     * Set of player low GUIDs, used both for the re-entrancy guard and for the
     * "this session finished its login sync" marker.
     */
    class PlayerGuidSet
    {
    public:
        void Add(Player const* player)
        {
            if (ObjectGuid::LowType low = LowGuidOf(player))
                _guids.insert(low);
        }

        void Remove(Player const* player)
        {
            if (ObjectGuid::LowType low = LowGuidOf(player))
                _guids.erase(low);
        }

        [[nodiscard]] bool Has(Player const* player) const
        {
            ObjectGuid::LowType low = LowGuidOf(player);
            return low && _guids.find(low) != _guids.end();
        }

        void Clear() { _guids.clear(); }

        [[nodiscard]] std::size_t Size() const { return _guids.size(); }

    private:
        static ObjectGuid::LowType LowGuidOf(Player const* player)
        {
            return player ? player->GetGUID().GetCounter() : 0;
        }

        std::unordered_set<ObjectGuid::LowType> _guids;
    };

    /**
     * Re-entrancy guard. While a character is being synced, the system's own
     * change hook (OnPlayerAchievementComplete / OnPlayerReputationChange)
     * must not write the applied values back into the pool.
     */
    class SyncGuardRegistry
    {
    public:
        class Scope
        {
        public:
            Scope(SyncGuardRegistry& registry, Player const* player)
                : _registry(registry), _player(player)
            {
                _registry._active.Add(_player);
            }

            ~Scope() { _registry._active.Remove(_player); }

            Scope(Scope const&) = delete;
            Scope& operator=(Scope const&) = delete;

        private:
            SyncGuardRegistry& _registry;
            Player const* _player;
        };

        [[nodiscard]] bool IsSyncing(Player const* player) const
        {
            return _active.Has(player);
        }

    private:
        PlayerGuidSet _active;
    };

    /**
     * Batches row upserts into a handful of multi-row statements instead of one
     * Execute() per row. A completionist account carries well over a thousand
     * pooled achievements; issuing those one statement at a time on first login
     * was the single most expensive thing these systems did.
     *
     * Rows are pre-rendered by the caller ("(1, 2, 3)").
     */
    class BatchUpsert
    {
    public:
        // `onDuplicate` is the text after "ON DUPLICATE KEY UPDATE".
        BatchUpsert(char const* table, char const* columns, char const* onDuplicate,
                    std::size_t maxRowsPerStatement = 250)
            : _table(table),
              _columns(columns),
              _onDuplicate(onDuplicate),
              _maxRows(maxRowsPerStatement)
        {
        }

        void AddRow(std::string row)
        {
            _rows.push_back(std::move(row));

            if (_rows.size() >= _maxRows)
                Emit();
        }

        [[nodiscard]] bool Empty() const { return _rows.empty() && _statements.empty(); }

        // Renders any buffered rows and returns every statement produced.
        std::vector<std::string> Take()
        {
            Emit();
            return std::move(_statements);
        }

        // Convenience: run everything directly on the character database.
        void Execute()
        {
            for (std::string const& sql : Take())
                CharacterDatabase.Execute(sql);
        }

        // Convenience: append everything to an open transaction.
        void AppendTo(CharacterDatabaseTransaction trans)
        {
            for (std::string const& sql : Take())
                trans->Append(sql);
        }

    private:
        void Emit()
        {
            if (_rows.empty())
                return;

            std::string sql = Acore::StringFormat("INSERT INTO `{}` ({}) VALUES ", _table, _columns);

            for (std::size_t i = 0; i < _rows.size(); ++i)
            {
                if (i)
                    sql += ',';

                sql += _rows[i];
            }

            if (_onDuplicate && *_onDuplicate)
            {
                sql += " ON DUPLICATE KEY UPDATE ";
                sql += _onDuplicate;
            }

            _statements.push_back(std::move(sql));
            _rows.clear();
        }

        char const* _table;
        char const* _columns;
        char const* _onDuplicate;
        std::size_t _maxRows;
        std::vector<std::string> _rows;
        std::vector<std::string> _statements;
    };

    /**
     * Account-keyed pool cache with a non-blocking first load.
     *
     * A generation counter per account makes a stale in-flight load harmless:
     * if the account was evicted (logout) between issuing the query and its
     * continuation, the result is discarded and the load is re-issued, so a
     * fast relog can never apply a snapshot taken before the logout save.
     */
    template <typename PoolT>
    class PoolCache
    {
    public:
        using Pool = PoolT;

        [[nodiscard]] bool IsLoaded(uint32 accountId) const
        {
            return _loaded.find(accountId) != _loaded.end();
        }

        // Valid once IsLoaded(); default-constructs an empty pool otherwise.
        Pool& Get(uint32 accountId) { return _pools[accountId]; }

        void Adopt(uint32 accountId, Pool pool)
        {
            _pools[accountId] = std::move(pool);
            _loaded.insert(accountId);
        }

        void Clear(uint32 accountId)
        {
            _pools.erase(accountId);
            _loaded.erase(accountId);
            ++_generation[accountId];
        }

        void ClearAll()
        {
            for (auto const& [accountId, pool] : _pools)
                ++_generation[accountId];

            _pools.clear();
            _loaded.clear();
        }

        [[nodiscard]] std::size_t CachedAccounts() const { return _pools.size(); }

        /// Applies `fn(accountId, pool)` to every cached pool.
        template <typename Fn>
        void ForEachPool(Fn fn)
        {
            for (auto& [accountId, pool] : _pools)
                fn(accountId, pool);
        }

        /**
         * Drops cached pools for accounts that no longer have a session.
         *
         * WorldSession::LogoutPlayer() only fires OnPlayerLogout when it is not
         * redirecting, so logout-driven eviction alone leaks entries. This
         * sweep is the backstop and runs on a slow timer.
         */
        void EvictOfflineAccounts()
        {
            std::vector<uint32> stale;

            for (auto const& [accountId, pool] : _pools)
                if (!sWorldSessionMgr->FindSession(accountId))
                    stale.push_back(accountId);

            for (uint32 accountId : stale)
                Clear(accountId);
        }

        /**
         * Ensures the account's pool is cached, then runs `then(player)`.
         *
         * Runs `then` inline on a cache hit; otherwise issues `selectSql`
         * asynchronously and runs `then` from the world-thread continuation.
         * Never blocks the world thread.
         *
         * `parse(pool, result)` fills a pool from a (possibly null) result.
         */
        template <typename ParseFn, typename ThenFn>
        void EnsureLoaded(Player* player, std::string selectSql, ParseFn parse, ThenFn then)
        {
            if (!player || !player->GetSession())
                return;

            uint32 accountId = player->GetSession()->GetAccountId();

            if (IsLoaded(accountId))
            {
                then(player);
                return;
            }

            IssueLoad(player->GetGUID(), accountId, std::move(selectSql),
                      std::move(parse), std::move(then), _generation[accountId]);
        }

    private:
        template <typename ParseFn, typename ThenFn>
        void IssueLoad(ObjectGuid playerGuid, uint32 accountId, std::string selectSql,
                       ParseFn parse, ThenFn then, uint64 generation)
        {
            PoolCache* self = this;

            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(selectSql)
                .WithCallback([self, playerGuid, accountId, selectSql, parse, then, generation]
                              (QueryResult result) mutable
            {
                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                if (!player || !player->GetSession())
                    return;

                // The account was evicted while this query was in flight, so the
                // snapshot predates whatever caused the eviction. Discard and retry.
                if (self->_generation[accountId] != generation)
                {
                    self->IssueLoad(playerGuid, accountId, std::move(selectSql),
                                    std::move(parse), std::move(then),
                                    self->_generation[accountId]);
                    return;
                }

                // Another login for this account may have populated the pool while
                // the query was in flight; that copy is live, ours is not.
                if (!self->IsLoaded(accountId))
                {
                    Pool& pool = self->_pools[accountId];
                    pool.clear();
                    parse(pool, result);
                    self->_loaded.insert(accountId);
                }

                then(player);
            }));
        }

        std::unordered_map<uint32, Pool> _pools;
        std::unordered_set<uint32> _loaded;
        std::unordered_map<uint32, uint64> _generation;
    };

    /// Account id of a player, or 0.
    inline uint32 AccountIdOf(Player const* player)
    {
        return player && player->GetSession() ? player->GetSession()->GetAccountId() : 0;
    }

    /**
     * Slow timer used by every pool's WorldScript::OnUpdate to drive
     * EvictOfflineAccounts(). Five minutes is far below any memory concern and
     * far above any per-tick cost.
     */
    class EvictionTimer
    {
    public:
        static constexpr uint32 INTERVAL_MS = 5 * 60 * 1000;

        // Returns true once per interval.
        bool Tick(uint32 diff)
        {
            if (_elapsed + diff < INTERVAL_MS)
            {
                _elapsed += diff;
                return false;
            }

            _elapsed = 0;
            return true;
        }

    private:
        uint32 _elapsed = 0;
    };
}

#endif // DC_ACCOUNTWIDE_POOL_H
