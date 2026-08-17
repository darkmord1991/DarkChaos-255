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

#include "DatabaseEnv.h"

#include <chrono>
#include <mutex>
#include <string>
#include <unordered_map>
#include <unordered_set>

namespace DC
{
namespace DbSchema
{
namespace detail
{
    // How long a "does not exist" answer stays cached before we re-probe.
    constexpr std::chrono::seconds NEGATIVE_TTL{ 60 };

    class ProbeCache
    {
    public:
        // True if this key is known to exist (cached permanently).
        bool IsPresent(std::string const& key)
        {
            std::lock_guard<std::mutex> lock(_mutex);
            return _present.contains(key);
        }

        // True if this key missed recently enough that re-probing can be skipped.
        // Expired entries are dropped so the next call probes again.
        bool MissedRecently(std::string const& key)
        {
            std::lock_guard<std::mutex> lock(_mutex);

            auto const it = _missedAt.find(key);
            if (it == _missedAt.end())
                return false;

            if (std::chrono::steady_clock::now() - it->second >= NEGATIVE_TTL)
            {
                _missedAt.erase(it);
                return false;
            }

            return true;
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
}

    inline bool WorldTableExists(std::string const& tableName)
    {
        static detail::ProbeCache cache;

        if (cache.IsPresent(tableName))
            return true;

        if (cache.MissedRecently(tableName))
            return false;

        if (!WorldDatabase.Query("SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}'", tableName))  // sql-ok: table/column names are compile-time literals from callers, never user input
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

        if (cache.IsPresent(key))
            return true;

        if (cache.MissedRecently(key))
            return false;

        if (!WorldTableExists(tableName))
        {
            cache.MarkMissing(key);
            return false;
        }

        if (!WorldDatabase.Query("SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}' AND COLUMN_NAME = '{}'", tableName, columnName))  // sql-ok: table/column names are compile-time literals from callers, never user input
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

        if (cache.IsPresent(tableName))
            return true;

        if (cache.MissedRecently(tableName))
            return false;

        if (!CharacterDatabase.Query("SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}'", tableName))  // sql-ok: table/column names are compile-time literals from callers, never user input
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

        if (cache.IsPresent(key))
            return true;

        if (cache.MissedRecently(key))
            return false;

        if (!CharacterTableExists(tableName))
        {
            cache.MarkMissing(key);
            return false;
        }

        if (!CharacterDatabase.Query("SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}' AND COLUMN_NAME = '{}'", tableName, columnName))  // sql-ok: table/column names are compile-time literals from callers, never user input
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
