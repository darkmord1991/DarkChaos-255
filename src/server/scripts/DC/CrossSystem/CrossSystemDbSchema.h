#pragma once

// Lightweight DB schema probes shared across all DC systems.
// Use these instead of writing local SHOW TABLES / information_schema checks.
//
// Canonical namespace: DC::DbSchema (alias: DarkChaos::CrossSystem::DbSchema)
//
// Caching policy: POSITIVE results only. A table/column that exists never
// disappears during server uptime, so a positive probe can be cached for the
// rest of the session. Some DC tables are created lazily at runtime, however,
// so a NEGATIVE result must never be cached -- a missing table/column
// re-probes on every call until it shows up.

#include "DatabaseEnv.h"

#include <mutex>
#include <string>
#include <unordered_set>

namespace DC
{
namespace DbSchema
{
    inline bool WorldTableExists(std::string const& tableName)
    {
        static std::mutex mutex;
        static std::unordered_set<std::string> knownTables;

        {
            std::lock_guard<std::mutex> lock(mutex);
            if (knownTables.contains(tableName))
                return true;
        }

        if (!WorldDatabase.Query("SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}'", tableName))
            return false;

        std::lock_guard<std::mutex> lock(mutex);
        knownTables.insert(tableName);
        return true;
    }

    inline bool WorldColumnExists(std::string const& tableName, std::string const& columnName)
    {
        static std::mutex mutex;
        static std::unordered_set<std::string> knownColumns;

        std::string const key = tableName + "." + columnName;

        {
            std::lock_guard<std::mutex> lock(mutex);
            if (knownColumns.contains(key))
                return true;
        }

        if (!WorldTableExists(tableName))
            return false;

        if (!WorldDatabase.Query("SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}' AND COLUMN_NAME = '{}'", tableName, columnName))
            return false;

        std::lock_guard<std::mutex> lock(mutex);
        knownColumns.insert(key);
        return true;
    }

    inline bool CharacterTableExists(std::string const& tableName)
    {
        static std::mutex mutex;
        static std::unordered_set<std::string> knownTables;

        {
            std::lock_guard<std::mutex> lock(mutex);
            if (knownTables.contains(tableName))
                return true;
        }

        if (!CharacterDatabase.Query("SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}'", tableName))
            return false;

        std::lock_guard<std::mutex> lock(mutex);
        knownTables.insert(tableName);
        return true;
    }

    inline bool CharacterColumnExists(std::string const& tableName, std::string const& columnName)
    {
        static std::mutex mutex;
        static std::unordered_set<std::string> knownColumns;

        std::string const key = tableName + "." + columnName;

        {
            std::lock_guard<std::mutex> lock(mutex);
            if (knownColumns.contains(key))
                return true;
        }

        if (!CharacterTableExists(tableName))
            return false;

        if (!CharacterDatabase.Query("SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}' AND COLUMN_NAME = '{}'", tableName, columnName))
            return false;

        std::lock_guard<std::mutex> lock(mutex);
        knownColumns.insert(key);
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
