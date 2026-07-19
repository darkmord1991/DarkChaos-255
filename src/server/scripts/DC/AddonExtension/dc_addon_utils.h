/*
 * DarkChaos AddonExtension — Shared Leaf Utilities
 * ================================================
 *
 * Small, reusable helpers shared across the DC addon handler files.
 *
 * This header is the *leaf-utility* sibling of dc_addon_namespace.h: the
 * namespace header owns the protocol MACHINERY (Module/Opcode registries,
 * JsonValue, Message/MessageRouter, async DB, transport negotiation), while
 * this header owns the small stand-alone HELPERS that were previously
 * copy-pasted across individual handler files. It is the addon-layer analog of
 * DCUtils / CrossSystem/CrossSystemUtilities.h for the general C++ scripts.
 *
 * Header-only by design (inline functions with function-local statics), mirroring
 * CrossSystem/CrossSystemDbSchema.h — include it directly from any handler TU; no
 * loader or CMake wiring is required.
 *
 * Copyright (C) 2025 DarkChaos Development Team
 */

#ifndef DC_ADDON_UTILS_H
#define DC_ADDON_UTILS_H

#include "Define.h"
#include "DatabaseEnv.h"
#include "SharedDefines.h"

#include <charconv>
#include <iomanip>
#include <mutex>
#include <sstream>
#include <string>
#include <unordered_map>

namespace DCAddon
{
namespace Utils
{
    // -------------------------------------------------------------------------
    // SQL string escaping
    // -------------------------------------------------------------------------
    // Canonical backslash escaping (matches mysql_real_escape_string in the
    // default, NO_BACKSLASH_ESCAPES-off mode): escapes the full dangerous set
    // (NUL, \n, \r, \t, backslash, single/double quote, Ctrl-Z), which is
    // strictly safer than bare single-quote doubling.
    //
    // Prefer the driver's CharacterDatabase.EscapeString() / WorldDatabase.EscapeString()
    // when a DB handle is convenient; use this only where an escaped raw SQL
    // fragment is being built by hand.
    inline std::string EscapeSql(std::string const& input)
    {
        std::string escaped;
        escaped.reserve(input.size() + 8);

        for (unsigned char c : input)
        {
            switch (c)
            {
                case '\0':   escaped += "\\0";  break;
                case '\n':   escaped += "\\n";  break;
                case '\r':   escaped += "\\r";  break;
                case '\t':   escaped += "\\t";  break;
                case '\\':   escaped += "\\\\"; break;
                case '\'':   escaped += "\\'";  break;
                case '"':    escaped += "\\\""; break;
                case '\x1A': escaped += "\\Z";  break;
                default:     escaped.push_back(static_cast<char>(c)); break;
            }
        }

        return escaped;
    }

    // -------------------------------------------------------------------------
    // JSON number / key emitters (DOM-free fast path)
    // -------------------------------------------------------------------------
    // Free-function siblings of JsonValue's internal encoder, for handlers that
    // build JSON by string-append instead of constructing a JsonValue DOM.
    inline void AppendUnsignedJsonNumber(std::string& out, uint32 value)
    {
        char buffer[16];
        auto [ptr, ec] = std::to_chars(buffer, buffer + sizeof(buffer), value);
        if (ec != std::errc())
        {
            out += std::to_string(value);
            return;
        }

        out.append(buffer, static_cast<std::size_t>(ptr - buffer));
    }

    inline void AppendSignedJsonNumber(std::string& out, int32 value)
    {
        char buffer[16];
        auto [ptr, ec] = std::to_chars(buffer, buffer + sizeof(buffer), value);
        if (ec != std::errc())
        {
            out += std::to_string(value);
            return;
        }

        out.append(buffer, static_cast<std::size_t>(ptr - buffer));
    }

    inline void AppendFloatingJsonNumber(std::string& out, double value)
    {
        std::ostringstream stream;
        stream << std::setprecision(15) << value;
        out += stream.str();
    }

    inline void AppendJsonKey(std::string& out, char const* key)
    {
        out.push_back('"');
        out += key;
        out += "\":";
    }

    // -------------------------------------------------------------------------
    // Class -> role CAPABILITY (static, class-based)
    // -------------------------------------------------------------------------
    // These answer "can a character of this class ever fill this role", NOT
    // "what role is this player in right now". For the player's CURRENT spec
    // role use DarkChaos::CrossSystem::VaultUtils::GetPlayerRoleMask (talent-tree
    // based) or Player::HasTankSpec()/HasHealSpec() — do not conflate the two.
    inline bool ClassCanTank(uint8 classId)
    {
        return classId == CLASS_WARRIOR || classId == CLASS_PALADIN
            || classId == CLASS_DEATH_KNIGHT || classId == CLASS_DRUID;
    }

    inline bool ClassCanHeal(uint8 classId)
    {
        return classId == CLASS_PRIEST || classId == CLASS_PALADIN
            || classId == CLASS_SHAMAN || classId == CLASS_DRUID;
    }

    inline bool ClassCanDps(uint8 /*classId*/)
    {
        return true; // every class can DPS
    }

    // -------------------------------------------------------------------------
    // Dungeon map-id -> display name
    // -------------------------------------------------------------------------
    // Authoritative source: world.dc_dungeon_setup (map_id PK) — the 50-row
    // superset covering every expansion, verified name-parity with
    // dc_mplus_dungeons for the 16 Mythic+ dungeons. dc_dungeon_setup is static
    // world content, so it is loaded once per process and served from cache
    // thereafter. Returns "" on miss (caller supplies its own fallback text).
    inline std::string GetDungeonNameByMapId(uint32 mapId)
    {
        static std::mutex mutex;
        static std::unordered_map<uint32, std::string> cache;
        static bool loaded = false;

        std::lock_guard<std::mutex> lock(mutex);

        if (!loaded)
        {
            if (QueryResult result = WorldDatabase.Query("SELECT map_id, dungeon_name FROM dc_dungeon_setup"))
            {
                do
                {
                    Field* fields = result->Fetch();
                    cache[fields[0].Get<uint32>()] = fields[1].Get<std::string>();
                } while (result->NextRow());
            }

            loaded = true;
        }

        auto it = cache.find(mapId);
        return it != cache.end() ? it->second : std::string();
    }
}
}

#endif // DC_ADDON_UTILS_H
