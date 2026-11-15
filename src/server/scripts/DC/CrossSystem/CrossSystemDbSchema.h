#pragma once

// Lightweight DB schema probes shared across all DC systems.
// Use these instead of writing local SHOW TABLES / information_schema checks.
//
// Canonical namespace: DC::DbSchema (alias: DarkChaos::CrossSystem::DbSchema)
//
// Caching policy:
//   POSITIVE results are cached for the rest of the session. A table/column
//   that exists never disappears during server uptime.
//
//   NEGATIVE results are cached for NEGATIVE_TTL. Re-probing on *every* call
//   put an information_schema round-trip on hot request paths: a handler that
//   probes several optional columns paid one query per probe per request,
//   forever, for every column that legitimately does not exist (e.g.
//   mutually-exclusive column-name alternatives, where a miss is guaranteed by
//   construction).
//
//   The TTL is now belt-and-braces rather than transitional. It existed because
//   "a handful of DC systems" created schema from C++ at runtime, so a missing
//   table could appear mid-session. Those are gone -- there is no CREATE TABLE
//   or ALTER TABLE anywhere under DC/ (verified Aug 2026), and schema comes only
//   from the AzerothCore SQL update flow at startup. Negative results could
//   therefore be cached permanently like positive ones; the TTL is kept only so
//   that applying a migration to a running server is picked up without a
//   restart. Do not reintroduce runtime DDL to make use of it.
//
//   Only the FIRST probe of a key blocks its caller. When a negative result
//   expires, the caller still gets "missing" and the key is checked again in the
//   background (45 of the 174 probes in the DC tree look for something the live
//   database does not have, and each of them used to block a request once a
//   minute). A migration applied to a running server is therefore picked up one
//   call later than before: the call after the TTL starts the re-check, the next
//   one sees its result.

#include "DatabaseEnv.h"

#include <chrono>
#include <mutex>
#include <source_location>
#include <string>
#include <unordered_map>
#include <unordered_set>

namespace DCAddon
{
    // Defined in AddonExtension/dc_addon_protocol.cpp (dc_addon_namespace.h declares it with its default argument).
    // Thread-safe; the continuation runs on the world thread.
    void EnqueueQueryCallback(QueryCallback&& callback, std::source_location site);
}

namespace DC
{
namespace DbSchema
{
namespace detail
{
    // How long a "does not exist" answer stays cached before it is checked again.
    constexpr std::chrono::seconds NEGATIVE_TTL{ 60 };

    enum class ProbeState
    {
        Unknown,        // never probed: the caller probes now
        Present,        // exists (cached permanently)
        Missing,        // did not exist when last checked, and that answer is still fresh
        MissingExpired  // did not exist, and it is time to check again in the background
    };

    class ProbeCache
    {
    public:
        // What is known about the key. MissingExpired is reported once per NEGATIVE_TTL (the key is stamped
        // again here), so one background re-check runs per key at a time.
        ProbeState Lookup(std::string const& key)
        {
            std::lock_guard<std::mutex> lock(_mutex);

            if (_present.contains(key))
                return ProbeState::Present;

            auto const it = _missedAt.find(key);
            if (it == _missedAt.end())
                return ProbeState::Unknown;

            auto const now = std::chrono::steady_clock::now();
            if (now - it->second < NEGATIVE_TTL)
                return ProbeState::Missing;

            it->second = now;
            return ProbeState::MissingExpired;
        }

        void MarkPresent(std::string const& key)
        {
            std::lock_guard<std::mutex> lock(_mutex);
            _present.insert(key);
            _missedAt.erase(key);
        }

        void MarkMissing(std::string const& key)
        {
            std::lock_guard<std::mutex> lock(_mutex);
            _missedAt[key] = std::chrono::steady_clock::now();
        }

    private:
        std::mutex _mutex;
        std::unordered_set<std::string> _present;
        std::unordered_map<std::string, std::chrono::steady_clock::time_point> _missedAt;
    };

    // sql-ok: table/column names are compile-time literals from callers, never user input
    inline std::string TableProbeSql(std::string const& tableName)
    {
        return Acore::StringFormat(
            "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}'",
            tableName);
    }

    // sql-ok: table/column names are compile-time literals from callers, never user input
    inline std::string ColumnProbeSql(std::string const& tableName, std::string const& columnName)
    {
        return Acore::StringFormat(
            "SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}' "
            "AND COLUMN_NAME = '{}'",
            tableName, columnName);
    }

    // Background re-check of a key that was missing: it becomes present when the probe finds it. The caches
    // are function statics, so the reference outlives every queued continuation.
    inline void RecheckMissing(ProbeCache& cache, std::string const& key, QueryCallback&& probe)
    {
        DCAddon::EnqueueQueryCallback(probe.WithCallback([&cache, key](QueryResult result)
        {
            if (result)
                cache.MarkPresent(key);
        }), std::source_location::current());
    }
}

    inline bool WorldTableExists(std::string const& tableName)
    {
        static detail::ProbeCache cache;

        switch (cache.Lookup(tableName))
        {
            case detail::ProbeState::Present:
                return true;
            case detail::ProbeState::Missing:
                return false;
            case detail::ProbeState::MissingExpired:
                detail::RecheckMissing(cache, tableName, WorldDatabase.AsyncQuery(detail::TableProbeSql(tableName)));
                return false;
            default:
                break;
        }

        if (!WorldDatabase.Query(detail::TableProbeSql(tableName)))
        {
            cache.MarkMissing(tableName);
            return false;
        }

        cache.MarkPresent(tableName);
        return true;
    }

    inline bool WorldColumnExists(std::string const& tableName, std::string const& columnName)
    {
        static detail::ProbeCache cache;

        std::string const key = tableName + "." + columnName;

        switch (cache.Lookup(key))
        {
            case detail::ProbeState::Present:
                return true;
            case detail::ProbeState::Missing:
                return false;
            case detail::ProbeState::MissingExpired:
                detail::RecheckMissing(cache, key,
                    WorldDatabase.AsyncQuery(detail::ColumnProbeSql(tableName, columnName)));
                return false;
            default:
                break;
        }

        if (!WorldTableExists(tableName))
        {
            cache.MarkMissing(key);
            return false;
        }

        if (!WorldDatabase.Query(detail::ColumnProbeSql(tableName, columnName)))
        {
            cache.MarkMissing(key);
            return false;
        }

        cache.MarkPresent(key);
        return true;
    }

    inline bool CharacterTableExists(std::string const& tableName)
    {
        static detail::ProbeCache cache;

        switch (cache.Lookup(tableName))
        {
            case detail::ProbeState::Present:
                return true;
            case detail::ProbeState::Missing:
                return false;
            case detail::ProbeState::MissingExpired:
                detail::RecheckMissing(cache, tableName,
                    CharacterDatabase.AsyncQuery(detail::TableProbeSql(tableName)));
                return false;
            default:
                break;
        }

        if (!CharacterDatabase.Query(detail::TableProbeSql(tableName)))
        {
            cache.MarkMissing(tableName);
            return false;
        }

        cache.MarkPresent(tableName);
        return true;
    }

    inline bool CharacterColumnExists(std::string const& tableName, std::string const& columnName)
    {
        static detail::ProbeCache cache;

        std::string const key = tableName + "." + columnName;

        switch (cache.Lookup(key))
        {
            case detail::ProbeState::Present:
                return true;
            case detail::ProbeState::Missing:
                return false;
            case detail::ProbeState::MissingExpired:
                detail::RecheckMissing(cache, key,
                    CharacterDatabase.AsyncQuery(detail::ColumnProbeSql(tableName, columnName)));
                return false;
            default:
                break;
        }

        if (!CharacterTableExists(tableName))
        {
            cache.MarkMissing(key);
            return false;
        }

        if (!CharacterDatabase.Query(detail::ColumnProbeSql(tableName, columnName)))
        {
            cache.MarkMissing(key);
            return false;
        }

        cache.MarkPresent(key);
        return true;
    }
}
}

// Canonical namespace alias
namespace DarkChaos
{
namespace CrossSystem
{
    namespace DbSchema = ::DC::DbSchema;
}
}
