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
#include <string_view>
#include <unordered_map>

namespace DCAddon
{
namespace Utils
{
    // -------------------------------------------------------------------------
    // SQL string escaping
    // -------------------------------------------------------------------------
    // Delegates to the driver (mysql_real_escape_string via the connection),
    // which is the only escaper that is actually correct:
    //
    //   * it consults the connection's SQL mode, so it stays correct under
    //     NO_BACKSLASH_ESCAPES (where backslash is NOT an escape character and
    //     a hand-rolled backslash escaper produces injectable output);
    //   * it consults the connection's charset, so it cannot be walked past by
    //     a multi-byte sequence whose trailing byte is a quote.
    //
    // This used to be a hand-rolled byte-level switch that got both of those
    // wrong by construction. It was correct for utf8/latin1 with the default
    // SQL mode - i.e. correct for this server today - which is exactly the kind
    // of latent-until-it-isn't defect worth removing rather than documenting.
    //
    // Still prefer PreparedStatement over building escaped SQL by hand. Reach
    // for this only where a raw SQL fragment is genuinely being assembled.
    inline std::string EscapeSql(std::string const& input)
    {
        std::string escaped = input;
        CharacterDatabase.EscapeString(escaped);
        return escaped;
    }

    // -------------------------------------------------------------------------
    // Outbound JSON well-formedness check
    // -------------------------------------------------------------------------
    // Two JSON strategies coexist in this tree: the JsonValue DOM (well-formed
    // by construction) and hand-assembled string concatenation. The hand-built
    // paths are the ones that can emit a trailing comma or an unterminated
    // string, and when they do the client silently drops the frame - there is
    // no server-side symptom at all, which makes it expensive to diagnose.
    //
    // This is a strict *structural* validator used to turn that silent failure
    // into a log line. It is deliberately not a parser: it allocates nothing and
    // builds no DOM, so it is cheap enough to run over outbound payloads when
    // the operator turns it on.
    namespace detail
    {
        inline void SkipJsonWhitespace(std::string_view text, std::size_t& pos)
        {
            while (pos < text.size()
                && (text[pos] == ' ' || text[pos] == '\t'
                    || text[pos] == '\n' || text[pos] == '\r'))
                ++pos;
        }

        bool ScanJsonValue(std::string_view text, std::size_t& pos, uint32 depth);

        inline bool ScanJsonString(std::string_view text, std::size_t& pos)
        {
            if (pos >= text.size() || text[pos] != '"')
                return false;

            ++pos;
            while (pos < text.size())
            {
                char const c = text[pos];

                if (c == '"')
                {
                    ++pos;
                    return true;
                }

                if (c == '\\')
                {
                    ++pos;
                    if (pos >= text.size())
                        return false;   // trailing escape

                    char const esc = text[pos];
                    if (esc == 'u')
                    {
                        if (pos + 4 >= text.size())
                            return false;
                        for (std::size_t i = 1; i <= 4; ++i)
                        {
                            char const h = text[pos + i];
                            bool const isHex = (h >= '0' && h <= '9')
                                || (h >= 'a' && h <= 'f') || (h >= 'A' && h <= 'F');
                            if (!isHex)
                                return false;
                        }
                        pos += 5;
                        continue;
                    }

                    if (esc != '"' && esc != '\\' && esc != '/' && esc != 'b'
                        && esc != 'f' && esc != 'n' && esc != 'r' && esc != 't')
                        return false;   // invalid escape

                    ++pos;
                    continue;
                }

                // Raw control characters are not legal inside a JSON string.
                if (static_cast<unsigned char>(c) < 0x20)
                    return false;

                ++pos;
            }

            return false;   // unterminated string
        }

        inline bool ScanJsonNumber(std::string_view text, std::size_t& pos)
        {
            std::size_t const start = pos;

            if (pos < text.size() && text[pos] == '-')
                ++pos;

            while (pos < text.size() && text[pos] >= '0' && text[pos] <= '9')
                ++pos;

            if (pos < text.size() && text[pos] == '.')
            {
                ++pos;
                while (pos < text.size() && text[pos] >= '0' && text[pos] <= '9')
                    ++pos;
            }

            if (pos < text.size() && (text[pos] == 'e' || text[pos] == 'E'))
            {
                ++pos;
                if (pos < text.size() && (text[pos] == '+' || text[pos] == '-'))
                    ++pos;
                while (pos < text.size() && text[pos] >= '0' && text[pos] <= '9')
                    ++pos;
            }

            return pos > start;
        }

        inline bool ScanJsonLiteral(std::string_view text, std::size_t& pos,
            std::string_view literal)
        {
            if (text.substr(pos, literal.size()) != literal)
                return false;

            pos += literal.size();
            return true;
        }

        inline bool ScanJsonValue(std::string_view text, std::size_t& pos, uint32 depth)
        {
            // Bound recursion: a deeply nested payload must not blow the stack.
            constexpr uint32 MAX_DEPTH = 64;
            if (depth > MAX_DEPTH)
                return false;

            SkipJsonWhitespace(text, pos);
            if (pos >= text.size())
                return false;

            char const c = text[pos];

            if (c == '{')
            {
                ++pos;
                SkipJsonWhitespace(text, pos);

                if (pos < text.size() && text[pos] == '}')
                {
                    ++pos;
                    return true;
                }

                for (;;)
                {
                    SkipJsonWhitespace(text, pos);
                    if (!ScanJsonString(text, pos))
                        return false;   // key must be a string

                    SkipJsonWhitespace(text, pos);
                    if (pos >= text.size() || text[pos] != ':')
                        return false;
                    ++pos;

                    if (!ScanJsonValue(text, pos, depth + 1))
                        return false;

                    SkipJsonWhitespace(text, pos);
                    if (pos >= text.size())
                        return false;

                    if (text[pos] == ',')
                    {
                        ++pos;
                        continue;       // a trailing comma then fails on '}'
                    }

                    if (text[pos] == '}')
                    {
                        ++pos;
                        return true;
                    }

                    return false;
                }
            }

            if (c == '[')
            {
                ++pos;
                SkipJsonWhitespace(text, pos);

                if (pos < text.size() && text[pos] == ']')
                {
                    ++pos;
                    return true;
                }

                for (;;)
                {
                    if (!ScanJsonValue(text, pos, depth + 1))
                        return false;

                    SkipJsonWhitespace(text, pos);
                    if (pos >= text.size())
                        return false;

                    if (text[pos] == ',')
                    {
                        ++pos;
                        continue;
                    }

                    if (text[pos] == ']')
                    {
                        ++pos;
                        return true;
                    }

                    return false;
                }
            }

            if (c == '"')
                return ScanJsonString(text, pos);

            if (c == 't')
                return ScanJsonLiteral(text, pos, "true");

            if (c == 'f')
                return ScanJsonLiteral(text, pos, "false");

            if (c == 'n')
                return ScanJsonLiteral(text, pos, "null");

            return ScanJsonNumber(text, pos);
        }
    }

    // True if `text` is exactly one well-formed JSON value, with nothing but
    // whitespace after it.
    inline bool IsWellFormedJson(std::string_view text)
    {
        std::size_t pos = 0;

        if (!detail::ScanJsonValue(text, pos, 0))
            return false;

        detail::SkipJsonWhitespace(text, pos);
        return pos == text.size();
    }

    // True if `text` looks like it was meant to be JSON (starts with an object
    // or array). Used to decide whether validating it is meaningful, since most
    // protocol fields are plain scalars.
    inline bool LooksLikeJson(std::string_view text)
    {
        std::size_t pos = 0;
        detail::SkipJsonWhitespace(text, pos);
        return pos < text.size() && (text[pos] == '{' || text[pos] == '[');
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
