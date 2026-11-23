/*
 * Dark Chaos - In-game bug reports: validation, rate limit and spool writer
 * ==========================================================================
 *
 * Pure logic (no Player, no session) so it can be checked on its own. The
 * script side is dc_bug_report.cpp; the relay that turns spool lines into
 * GitHub issues is apps/bugreport_relay/dc_bugreport_relay.py.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#ifndef DC_BUG_REPORT_CORE_H
#define DC_BUG_REPORT_CORE_H

#include "Define.h"
#include <cstddef>
#include <string>
#include <string_view>
#include <unordered_map>

namespace DCBugReport
{
    constexpr char const* MODULE = "BUGR";
    constexpr uint8 CMSG_SUBMIT = 0x01;
    constexpr uint8 SMSG_RESULT = 0x10;

    // Spool line format version (read by the relay).
    constexpr uint32 SpoolVersion = 1;

    constexpr std::size_t MinTitleBytes = 3;
    constexpr std::size_t MaxTitleBytes = 120;
    constexpr std::size_t MinBodyBytes = 10;
    constexpr std::size_t MaxBodyBytes = 4000;
    constexpr std::size_t MaxClientFieldBytes = 96;
    constexpr std::size_t MaxAddons = 64;
    constexpr std::size_t MaxAddonFieldBytes = 48;
    constexpr std::size_t MaxErrors = 5;
    constexpr std::size_t MaxErrorBytes = 700;

    // Control bytes go (\r\n and \r become \n when `multiline`, otherwise
    // every line break becomes a space), leading/trailing blanks are trimmed
    // and the result is cut to `maxBytes` without splitting a UTF-8 sequence.
    std::string CleanText(std::string_view text, std::size_t maxBytes, bool multiline);

    // bug quest item creature spell ui other
    bool IsValidCategory(std::string_view category);

    // Per-account cooldown plus a rolling 24 h cap, in memory (a restart
    // resets it). Check() answers 0 when a report may be stored now, else the
    // seconds to wait; Record() books a stored report.
    class RateLimiter
    {
    public:
        uint32 Check(uint32 accountId, uint64 nowSeconds, uint32 cooldownSeconds, uint32 maxPerDay) const;
        void Record(uint32 accountId, uint64 nowSeconds);

    private:
        struct State
        {
            uint64 last = 0;
            uint64 windowStart = 0;
            uint32 windowCount = 0;
        };

        std::unordered_map<uint32, State> _accounts;
    };

    // "<unix seconds hex>-<counter hex>-<random hex>": unique per server run
    // and sortable by time; the relay uses it as the idempotency key.
    std::string MakeReportId(uint64 unixSeconds, uint32 counter, uint32 random);

    // Appends `line` plus '\n' to the spool with one write call. A file that
    // would grow past `maxSpoolBytes` is refused ("spool full"). The relay
    // only reads lines that end in '\n', so a write cut short by a crash is
    // never half-read.
    bool AppendSpoolLine(std::string const& path, std::string const& line, uint64 maxSpoolBytes, std::string& error);
}

#endif
