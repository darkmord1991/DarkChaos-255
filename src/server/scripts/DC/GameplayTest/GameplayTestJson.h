/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Gameplay test harness: a small strict JSON value, parser and writer.
 *
 * The DC addon layer has a lenient parser (DCAddon::JsonParser) that turns any
 * malformed input into null without saying where. Scenario files are written by
 * hand, so this one refuses anything malformed or duplicated and reports the
 * line and column, and keeps object keys in file order so reports read in the
 * same order as the scenario.
 */

#ifndef DC_GAMEPLAY_TEST_JSON_H
#define DC_GAMEPLAY_TEST_JSON_H

#include "Define.h"
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace DC::GameplayTest
{
    class JsonValue
    {
    public:
        enum class Type : uint8
        {
            Null,
            Bool,
            Number,
            String,
            Array,
            Object
        };

        using Member = std::pair<std::string, JsonValue>;

        JsonValue() = default;
        JsonValue(bool value) : _type(Type::Bool), _bool(value) { }
        JsonValue(double value) : _type(Type::Number), _number(value) { }
        JsonValue(int32 value) : _type(Type::Number), _number(double(value)) { }
        JsonValue(uint32 value) : _type(Type::Number), _number(double(value)) { }
        JsonValue(int64 value) : _type(Type::Number), _number(double(value)) { }
        JsonValue(uint64 value) : _type(Type::Number), _number(double(value)) { }
        JsonValue(std::string value) : _type(Type::String), _string(std::move(value)) { }
        JsonValue(char const* value) : _type(Type::String), _string(value) { }

        static JsonValue MakeArray();
        static JsonValue MakeObject();

        [[nodiscard]] Type GetType() const { return _type; }
        [[nodiscard]] bool IsNull() const { return _type == Type::Null; }
        [[nodiscard]] bool IsBool() const { return _type == Type::Bool; }
        [[nodiscard]] bool IsNumber() const { return _type == Type::Number; }
        [[nodiscard]] bool IsString() const { return _type == Type::String; }
        [[nodiscard]] bool IsArray() const { return _type == Type::Array; }
        [[nodiscard]] bool IsObject() const { return _type == Type::Object; }

        [[nodiscard]] bool AsBool() const { return _bool; }
        [[nodiscard]] double AsNumber() const { return _number; }
        [[nodiscard]] std::string const& AsString() const { return _string; }
        [[nodiscard]] std::vector<JsonValue> const& Items() const { return _array; }
        [[nodiscard]] std::vector<Member> const& Members() const { return _object; }

        // Object lookup; nullptr when this is not an object or the key is absent.
        [[nodiscard]] JsonValue const* Find(std::string_view key) const;
        [[nodiscard]] bool Has(std::string_view key) const { return Find(key) != nullptr; }

        // Typed object lookups with a fallback for absent or mistyped keys.
        [[nodiscard]] std::string GetString(std::string_view key, std::string const& fallback = {}) const;
        [[nodiscard]] double GetNumber(std::string_view key, double fallback = 0.0) const;
        [[nodiscard]] uint32 GetUInt(std::string_view key, uint32 fallback = 0) const;
        [[nodiscard]] int32 GetInt(std::string_view key, int32 fallback = 0) const;
        [[nodiscard]] bool GetBool(std::string_view key, bool fallback = false) const;

        // Building. Set replaces an existing key, keeping its position.
        void Set(std::string const& key, JsonValue value);
        void Push(JsonValue value);

        [[nodiscard]] std::string Dump(bool pretty = true) const;

    private:
        void DumpTo(std::string& out, bool pretty, uint32 depth) const;

        Type _type = Type::Null;
        bool _bool = false;
        double _number = 0.0;
        std::string _string;
        std::vector<JsonValue> _array;
        std::vector<Member> _object;
    };

    // Strict RFC 8259 parsing (no comments, no trailing commas, no duplicate keys).
    // On failure returns false and fills `error` with "line L, column C: reason".
    bool ParseJson(std::string_view text, JsonValue& out, std::string& error);
}

#endif // DC_GAMEPLAY_TEST_JSON_H
