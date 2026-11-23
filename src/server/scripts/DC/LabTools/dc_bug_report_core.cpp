/*
 * Dark Chaos - In-game bug reports: validation, rate limit and spool writer
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_bug_report_core.h"
#include <algorithm>
#include <array>
#include <charconv>
#include <cstdio>
#include <filesystem>
#include <system_error>

namespace DCBugReport
{
    namespace
    {
        constexpr std::array<std::string_view, 7> Categories =
            { "bug", "quest", "item", "creature", "spell", "ui", "other" };

        constexpr uint64 WindowSeconds = 24 * 60 * 60;

        bool IsBlank(char c)
        {
            return c == ' ' || c == '\n' || c == '\t';
        }

        bool IsContinuationByte(char c)
        {
            return (static_cast<unsigned char>(c) & 0xC0) == 0x80;
        }
    }

    std::string CleanText(std::string_view text, std::size_t maxBytes, bool multiline)
    {
        std::string out;
        out.reserve(std::min(text.size(), maxBytes + 4));
        for (std::size_t i = 0; i < text.size(); ++i)
        {
            unsigned char const c = static_cast<unsigned char>(text[i]);
            if (c == '\r')
            {
                if (i + 1 < text.size() && text[i + 1] == '\n')
                    continue;

                out.push_back(multiline ? '\n' : ' ');
            }
            else if (c == '\n')
                out.push_back(multiline ? '\n' : ' ');
            else if (c == '\t')
                out.push_back(multiline ? '\t' : ' ');
            else if (c < 0x20 || c == 0x7F)
                continue;
            else
                out.push_back(static_cast<char>(c));
        }

        std::size_t begin = 0;
        while (begin < out.size() && IsBlank(out[begin]))
            ++begin;

        std::size_t end = out.size();
        while (end > begin && IsBlank(out[end - 1]))
            --end;

        out = out.substr(begin, end - begin);
        if (out.size() > maxBytes)
        {
            std::size_t cut = maxBytes;
            while (cut > 0 && IsContinuationByte(out[cut]))
                --cut;

            out.resize(cut);
        }

        return out;
    }

    bool IsValidCategory(std::string_view category)
    {
        return std::find(Categories.begin(), Categories.end(), category) != Categories.end();
    }

    uint32 RateLimiter::Check(uint32 accountId, uint64 nowSeconds, uint32 cooldownSeconds, uint32 maxPerDay) const
    {
        auto const itr = _accounts.find(accountId);
        if (itr == _accounts.end())
            return 0;

        State const& state = itr->second;
        if (cooldownSeconds && state.last && nowSeconds < state.last + cooldownSeconds)
            return static_cast<uint32>(state.last + cooldownSeconds - nowSeconds);

        if (maxPerDay && nowSeconds < state.windowStart + WindowSeconds && state.windowCount >= maxPerDay)
            return static_cast<uint32>(state.windowStart + WindowSeconds - nowSeconds);

        return 0;
    }

    void RateLimiter::Record(uint32 accountId, uint64 nowSeconds)
    {
        State& state = _accounts[accountId];
        if (state.windowCount == 0 || nowSeconds >= state.windowStart + WindowSeconds)
        {
            state.windowStart = nowSeconds;
            state.windowCount = 0;
        }

        state.last = nowSeconds;
        ++state.windowCount;
    }

    std::string MakeReportId(uint64 unixSeconds, uint32 counter, uint32 random)
    {
        auto hex = [](uint64 value, std::size_t minDigits)
        {
            char buffer[24];
            auto const [ptr, ec] = std::to_chars(buffer, buffer + sizeof(buffer), value, 16);
            std::string digits(buffer, ec == std::errc() ? ptr : buffer);
            if (digits.size() < minDigits)
                digits.insert(0, minDigits - digits.size(), '0');
            return digits;
        };

        return hex(unixSeconds, 1) + "-" + hex(counter, 1) + "-" + hex(random & 0xFFFF, 4);
    }

    bool AppendSpoolLine(std::string const& path, std::string const& line, uint64 maxSpoolBytes, std::string& error)
    {
        if (path.empty())
        {
            error = "no spool file configured";
            return false;
        }

        if (line.find('\n') != std::string::npos)
        {
            error = "a spool line must not contain a line break";
            return false;
        }

        std::string record = line;
        record.push_back('\n');

        std::error_code ec;
        uintmax_t const current = std::filesystem::exists(path, ec) ? std::filesystem::file_size(path, ec) : 0;
        if (ec)
        {
            error = "cannot stat spool file: " + ec.message();
            return false;
        }

        if (maxSpoolBytes && current + record.size() > maxSpoolBytes)
        {
            error = "spool full";
            return false;
        }

        // "ab": O_APPEND on POSIX, FILE_APPEND_DATA on Windows; the whole
        // record goes out in one fwrite and is flushed before the close.
        std::FILE* file = std::fopen(path.c_str(), "ab");
        if (!file)
        {
            error = "cannot open spool file";
            return false;
        }

        std::size_t const written = std::fwrite(record.data(), 1, record.size(), file);
        bool const flushed = std::fflush(file) == 0;
        bool const closed = std::fclose(file) == 0;
        if (written != record.size() || !flushed || !closed)
        {
            error = "short write to spool file";
            return false;
        }

        return true;
    }
}
