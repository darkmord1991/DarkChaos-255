/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "GameplayTestJson.h"
#include "StringFormat.h"
#include <charconv>
#include <cmath>
#include <limits>
#include <system_error>

namespace DC::GameplayTest
{
    namespace
    {
        constexpr uint32 MAX_DEPTH = 64;
        constexpr double MAX_EXACT_INTEGER = 9007199254740992.0; // 2^53

        class Parser
        {
        public:
            explicit Parser(std::string_view text) : _text(text) { }

            bool Run(JsonValue& out, std::string& error)
            {
                SkipWhitespace();
                if (!ParseValue(out, 0))
                {
                    error = Describe();
                    return false;
                }

                SkipWhitespace();
                if (_pos != _text.size())
                {
                    Fail("unexpected data after the top-level value");
                    error = Describe();
                    return false;
                }

                return true;
            }

        private:
            bool Fail(std::string reason)
            {
                if (_reason.empty())
                    _reason = std::move(reason);
                return false;
            }

            std::string Describe() const
            {
                uint32 line = 1;
                uint32 column = 1;
                for (std::size_t i = 0; i < _pos && i < _text.size(); ++i)
                {
                    if (_text[i] == '\n')
                    {
                        ++line;
                        column = 1;
                    }
                    else
                        ++column;
                }

                return Acore::StringFormat("line {}, column {}: {}", line, column, _reason);
            }

            void SkipWhitespace()
            {
                while (_pos < _text.size())
                {
                    char const c = _text[_pos];
                    if (c != ' ' && c != '\t' && c != '\n' && c != '\r')
                        break;
                    ++_pos;
                }
            }

            bool Consume(char expected)
            {
                if (_pos < _text.size() && _text[_pos] == expected)
                {
                    ++_pos;
                    return true;
                }
                return false;
            }

            bool ConsumeWord(std::string_view word)
            {
                if (_text.substr(_pos, word.size()) != word)
                    return false;
                _pos += word.size();
                return true;
            }

            bool ParseValue(JsonValue& out, uint32 depth)
            {
                if (depth > MAX_DEPTH)
                    return Fail("nesting is deeper than 64 levels");

                if (_pos >= _text.size())
                    return Fail("unexpected end of input");

                char const c = _text[_pos];
                switch (c)
                {
                    case '{':
                        return ParseObject(out, depth);
                    case '[':
                        return ParseArray(out, depth);
                    case '"':
                    {
                        std::string text;
                        if (!ParseString(text))
                            return false;
                        out = JsonValue(std::move(text));
                        return true;
                    }
                    case 't':
                        if (!ConsumeWord("true"))
                            return Fail("invalid literal");
                        out = JsonValue(true);
                        return true;
                    case 'f':
                        if (!ConsumeWord("false"))
                            return Fail("invalid literal");
                        out = JsonValue(false);
                        return true;
                    case 'n':
                        if (!ConsumeWord("null"))
                            return Fail("invalid literal");
                        out = JsonValue();
                        return true;
                    default:
                        if (c == '-' || (c >= '0' && c <= '9'))
                            return ParseNumber(out);
                        return Fail(Acore::StringFormat("unexpected character '{}'", c));
                }
            }

            bool ParseObject(JsonValue& out, uint32 depth)
            {
                ++_pos; // '{'
                out = JsonValue::MakeObject();
                SkipWhitespace();
                if (Consume('}'))
                    return true;

                while (true)
                {
                    SkipWhitespace();
                    if (_pos >= _text.size() || _text[_pos] != '"')
                        return Fail("expected a quoted object key");

                    std::string key;
                    if (!ParseString(key))
                        return false;

                    if (out.Has(key))
                        return Fail(Acore::StringFormat("duplicate key \"{}\"", key));

                    SkipWhitespace();
                    if (!Consume(':'))
                        return Fail("expected ':' after an object key");

                    SkipWhitespace();
                    JsonValue value;
                    if (!ParseValue(value, depth + 1))
                        return false;
                    out.Set(key, std::move(value));

                    SkipWhitespace();
                    if (Consume(','))
                        continue;
                    if (Consume('}'))
                        return true;
                    return Fail("expected ',' or '}' in an object");
                }
            }

            bool ParseArray(JsonValue& out, uint32 depth)
            {
                ++_pos; // '['
                out = JsonValue::MakeArray();
                SkipWhitespace();
                if (Consume(']'))
                    return true;

                while (true)
                {
                    SkipWhitespace();
                    JsonValue value;
                    if (!ParseValue(value, depth + 1))
                        return false;
                    out.Push(std::move(value));

                    SkipWhitespace();
                    if (Consume(','))
                        continue;
                    if (Consume(']'))
                        return true;
                    return Fail("expected ',' or ']' in an array");
                }
            }

            static void AppendUtf8(std::string& out, uint32 cp)
            {
                if (cp < 0x80)
                    out.push_back(char(cp));
                else if (cp < 0x800)
                {
                    out.push_back(char(0xC0 | (cp >> 6)));
                    out.push_back(char(0x80 | (cp & 0x3F)));
                }
                else if (cp < 0x10000)
                {
                    out.push_back(char(0xE0 | (cp >> 12)));
                    out.push_back(char(0x80 | ((cp >> 6) & 0x3F)));
                    out.push_back(char(0x80 | (cp & 0x3F)));
                }
                else
                {
                    out.push_back(char(0xF0 | (cp >> 18)));
                    out.push_back(char(0x80 | ((cp >> 12) & 0x3F)));
                    out.push_back(char(0x80 | ((cp >> 6) & 0x3F)));
                    out.push_back(char(0x80 | (cp & 0x3F)));
                }
            }

            bool ParseHex4(uint32& out)
            {
                if (_pos + 4 > _text.size())
                    return Fail("truncated \\u escape");

                out = 0;
                for (uint32 i = 0; i < 4; ++i)
                {
                    char const c = _text[_pos++];
                    out <<= 4;
                    if (c >= '0' && c <= '9')
                        out |= uint32(c - '0');
                    else if (c >= 'a' && c <= 'f')
                        out |= uint32(c - 'a' + 10);
                    else if (c >= 'A' && c <= 'F')
                        out |= uint32(c - 'A' + 10);
                    else
                        return Fail("invalid hex digit in a \\u escape");
                }
                return true;
            }

            bool ParseString(std::string& out)
            {
                ++_pos; // opening quote
                while (true)
                {
                    if (_pos >= _text.size())
                        return Fail("unterminated string");

                    char const c = _text[_pos++];
                    if (c == '"')
                        return true;

                    if (static_cast<unsigned char>(c) < 0x20)
                        return Fail("control character inside a string (escape it)");

                    if (c != '\\')
                    {
                        out.push_back(c);
                        continue;
                    }

                    if (_pos >= _text.size())
                        return Fail("unterminated escape");

                    char const esc = _text[_pos++];
                    switch (esc)
                    {
                        case '"': out.push_back('"'); break;
                        case '\\': out.push_back('\\'); break;
                        case '/': out.push_back('/'); break;
                        case 'b': out.push_back('\b'); break;
                        case 'f': out.push_back('\f'); break;
                        case 'n': out.push_back('\n'); break;
                        case 'r': out.push_back('\r'); break;
                        case 't': out.push_back('\t'); break;
                        case 'u':
                        {
                            uint32 cp = 0;
                            if (!ParseHex4(cp))
                                return false;
                            if (cp >= 0xD800 && cp <= 0xDBFF)
                            {
                                uint32 low = 0;
                                if (!ConsumeWord("\\u") || !ParseHex4(low) || low < 0xDC00 || low > 0xDFFF)
                                    return Fail("unpaired UTF-16 surrogate");
                                cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
                            }
                            else if (cp >= 0xDC00 && cp <= 0xDFFF)
                                return Fail("unpaired UTF-16 surrogate");
                            AppendUtf8(out, cp);
                            break;
                        }
                        default:
                            return Fail(Acore::StringFormat("invalid escape '\\{}'", esc));
                    }
                }
            }

            static bool IsDigit(char c)
            {
                return c >= '0' && c <= '9';
            }

            // The grammar is checked here; the conversion uses from_chars where the
            // standard library has it for double (never strtod: it follows the
            // process locale). The fallback is exact for up to 15 significant digits.
            bool ParseNumber(JsonValue& out)
            {
                std::size_t const start = _pos;
                Consume('-');
                if (_pos >= _text.size() || !IsDigit(_text[_pos]))
                    return Fail("expected a digit");

                if (_text[_pos] == '0')
                {
                    ++_pos;
                    if (_pos < _text.size() && IsDigit(_text[_pos]))
                        return Fail("leading zeros are not allowed");
                }
                else
                    while (_pos < _text.size() && IsDigit(_text[_pos]))
                        ++_pos;

                if (Consume('.'))
                {
                    if (_pos >= _text.size() || !IsDigit(_text[_pos]))
                        return Fail("expected a digit after the decimal point");
                    while (_pos < _text.size() && IsDigit(_text[_pos]))
                        ++_pos;
                }

                if (_pos < _text.size() && (_text[_pos] == 'e' || _text[_pos] == 'E'))
                {
                    ++_pos;
                    if (!Consume('-'))
                        Consume('+');
                    if (_pos >= _text.size() || !IsDigit(_text[_pos]))
                        return Fail("expected a digit in the exponent");
                    while (_pos < _text.size() && IsDigit(_text[_pos]))
                        ++_pos;
                }

                std::string_view const token = _text.substr(start, _pos - start);
                double value = 0.0;
#if defined(__cpp_lib_to_chars) && __cpp_lib_to_chars >= 201611L
                auto const [end, ec] = std::from_chars(token.data(), token.data() + token.size(), value);
                if (ec != std::errc() || end != token.data() + token.size())
                    return Fail("number out of range");
#else
                value = ConvertNumber(token);
#endif
                if (!std::isfinite(value))
                    return Fail("number out of range");

                out = JsonValue(value);
                return true;
            }

            [[maybe_unused]] static double ConvertNumber(std::string_view token)
            {
                bool const negative = !token.empty() && token.front() == '-';
                uint64 mantissa = 0;
                int32 exponent = 0;
                uint32 digits = 0;
                std::size_t i = negative ? 1 : 0;
                bool fraction = false;
                for (; i < token.size() && token[i] != 'e' && token[i] != 'E'; ++i)
                {
                    if (token[i] == '.')
                    {
                        fraction = true;
                        continue;
                    }

                    if (digits < 18)
                    {
                        mantissa = mantissa * 10 + uint64(token[i] - '0');
                        if (mantissa)
                            ++digits;
                        if (fraction)
                            --exponent;
                    }
                    else if (!fraction)
                        ++exponent;
                }

                if (i < token.size())
                {
                    ++i;
                    bool const negativeExponent = i < token.size() && token[i] == '-';
                    if (i < token.size() && (token[i] == '-' || token[i] == '+'))
                        ++i;
                    int32 written = 0;
                    for (; i < token.size(); ++i)
                        if (written < 10000)
                            written = written * 10 + (token[i] - '0');
                    exponent += negativeExponent ? -written : written;
                }

                double value = double(mantissa);
                if (exponent < 0)
                    value /= std::pow(10.0, -exponent);
                else if (exponent > 0)
                    value *= std::pow(10.0, exponent);
                return negative ? -value : value;
            }

            std::string_view _text;
            std::size_t _pos = 0;
            std::string _reason;
        };

        void AppendEscaped(std::string& out, std::string const& text)
        {
            out.push_back('"');
            for (char c : text)
            {
                switch (c)
                {
                    case '"': out += "\\\""; break;
                    case '\\': out += "\\\\"; break;
                    case '\n': out += "\\n"; break;
                    case '\r': out += "\\r"; break;
                    case '\t': out += "\\t"; break;
                    case '\b': out += "\\b"; break;
                    case '\f': out += "\\f"; break;
                    default:
                        if (static_cast<unsigned char>(c) < 0x20)
                            out += Acore::StringFormat("\\u{:04x}", uint32(static_cast<unsigned char>(c)));
                        else
                            out.push_back(c);
                        break;
                }
            }
            out.push_back('"');
        }

        void AppendIndent(std::string& out, uint32 depth)
        {
            out.append(std::size_t(depth) * 2, ' ');
        }
    }

    JsonValue JsonValue::MakeArray()
    {
        JsonValue value;
        value._type = Type::Array;
        return value;
    }

    JsonValue JsonValue::MakeObject()
    {
        JsonValue value;
        value._type = Type::Object;
        return value;
    }

    JsonValue const* JsonValue::Find(std::string_view key) const
    {
        if (_type != Type::Object)
            return nullptr;

        for (Member const& member : _object)
            if (member.first == key)
                return &member.second;

        return nullptr;
    }

    std::string JsonValue::GetString(std::string_view key, std::string const& fallback) const
    {
        JsonValue const* value = Find(key);
        return value && value->IsString() ? value->AsString() : fallback;
    }

    double JsonValue::GetNumber(std::string_view key, double fallback) const
    {
        JsonValue const* value = Find(key);
        return value && value->IsNumber() ? value->AsNumber() : fallback;
    }

    uint32 JsonValue::GetUInt(std::string_view key, uint32 fallback) const
    {
        JsonValue const* value = Find(key);
        if (!value || !value->IsNumber() || value->AsNumber() < 0.0)
            return fallback;

        double const number = value->AsNumber();
        if (number > double(std::numeric_limits<uint32>::max()))
            return std::numeric_limits<uint32>::max();
        return uint32(number);
    }

    int32 JsonValue::GetInt(std::string_view key, int32 fallback) const
    {
        JsonValue const* value = Find(key);
        if (!value || !value->IsNumber())
            return fallback;

        double const number = value->AsNumber();
        if (number > double(std::numeric_limits<int32>::max()))
            return std::numeric_limits<int32>::max();
        if (number < double(std::numeric_limits<int32>::min()))
            return std::numeric_limits<int32>::min();
        return int32(number);
    }

    bool JsonValue::GetBool(std::string_view key, bool fallback) const
    {
        JsonValue const* value = Find(key);
        return value && value->IsBool() ? value->AsBool() : fallback;
    }

    void JsonValue::Set(std::string const& key, JsonValue value)
    {
        if (_type != Type::Object)
            return;

        for (Member& member : _object)
        {
            if (member.first == key)
            {
                member.second = std::move(value);
                return;
            }
        }

        _object.emplace_back(key, std::move(value));
    }

    void JsonValue::Push(JsonValue value)
    {
        if (_type == Type::Array)
            _array.push_back(std::move(value));
    }

    std::string JsonValue::Dump(bool pretty) const
    {
        std::string out;
        DumpTo(out, pretty, 0);
        if (pretty)
            out.push_back('\n');
        return out;
    }

    void JsonValue::DumpTo(std::string& out, bool pretty, uint32 depth) const
    {
        switch (_type)
        {
            case Type::Null:
                out += "null";
                return;
            case Type::Bool:
                out += _bool ? "true" : "false";
                return;
            case Type::Number:
            {
                if (!std::isfinite(_number))
                {
                    out += "null";
                    return;
                }

                double integral = 0.0;
                if (std::modf(_number, &integral) == 0.0 && std::fabs(integral) <= MAX_EXACT_INTEGER)
                    out += Acore::StringFormat("{}", int64(integral));
                else
                    out += Acore::StringFormat("{}", _number);
                return;
            }
            case Type::String:
                AppendEscaped(out, _string);
                return;
            case Type::Array:
            {
                if (_array.empty())
                {
                    out += "[]";
                    return;
                }

                out.push_back('[');
                for (std::size_t i = 0; i < _array.size(); ++i)
                {
                    if (i)
                        out.push_back(',');
                    if (pretty)
                    {
                        out.push_back('\n');
                        AppendIndent(out, depth + 1);
                    }
                    _array[i].DumpTo(out, pretty, depth + 1);
                }
                if (pretty)
                {
                    out.push_back('\n');
                    AppendIndent(out, depth);
                }
                out.push_back(']');
                return;
            }
            case Type::Object:
            {
                if (_object.empty())
                {
                    out += "{}";
                    return;
                }

                out.push_back('{');
                for (std::size_t i = 0; i < _object.size(); ++i)
                {
                    if (i)
                        out.push_back(',');
                    if (pretty)
                    {
                        out.push_back('\n');
                        AppendIndent(out, depth + 1);
                    }
                    AppendEscaped(out, _object[i].first);
                    out += pretty ? ": " : ":";
                    _object[i].second.DumpTo(out, pretty, depth + 1);
                }
                if (pretty)
                {
                    out.push_back('\n');
                    AppendIndent(out, depth);
                }
                out.push_back('}');
                return;
            }
        }
    }

    bool ParseJson(std::string_view text, JsonValue& out, std::string& error)
    {
        // A UTF-8 byte order mark is what Windows editors write; accept it.
        if (text.size() >= 3 && static_cast<unsigned char>(text[0]) == 0xEF &&
            static_cast<unsigned char>(text[1]) == 0xBB && static_cast<unsigned char>(text[2]) == 0xBF)
            text.remove_prefix(3);

        Parser parser(text);
        return parser.Run(out, error);
    }
}
