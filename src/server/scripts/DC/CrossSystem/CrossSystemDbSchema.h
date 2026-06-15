#pragma once

// Lightweight DB schema probes shared across all DC systems.
// Use these instead of writing local SHOW TABLES / information_schema checks.
//
// Canonical namespace: DC::DbSchema (alias: DarkChaos::CrossSystem::DbSchema)

#include "DatabaseEnv.h"

#include <string>

namespace DC
{
namespace DbSchema
{
    inline bool WorldTableExists(std::string const& tableName)
    {
        return WorldDatabase.Query("SHOW TABLES LIKE '{}'", tableName) != nullptr;
    }

    inline bool WorldColumnExists(std::string const& tableName, std::string const& columnName)
    {
        if (!WorldTableExists(tableName))
            return false;
        return WorldDatabase.Query("SHOW COLUMNS FROM `{}` LIKE '{}'", tableName, columnName) != nullptr;
    }

    inline bool CharacterTableExists(std::string const& tableName)
    {
        return CharacterDatabase.Query("SHOW TABLES LIKE '{}'", tableName) != nullptr;
    }

    inline bool CharacterColumnExists(std::string const& tableName, std::string const& columnName)
    {
        if (!CharacterTableExists(tableName))
            return false;
        return CharacterDatabase.Query("SHOW COLUMNS FROM `{}` LIKE '{}'", tableName, columnName) != nullptr;
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
