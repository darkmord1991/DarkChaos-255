/*
 * Dark Chaos - Client lab probe relay: wire limits and the result book
 * =====================================================================
 *
 * Pure logic (no Player, no session, no packets) so it can be checked on its
 * own. The script side lives in dc_lab_probe.cpp; the protocol is described
 * there.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#ifndef DC_LAB_PROBE_CORE_H
#define DC_LAB_PROBE_CORE_H

#include "Define.h"
#include <cstddef>
#include <map>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace DCLabProbe
{
    // DC addon protocol module and opcodes (module codes are free-form strings
    // in the router; this one is registered by dc_lab_probe.cpp, not by the
    // central table in dc_addon_protocol.cpp).
    constexpr char const* MODULE = "LABP";
    constexpr uint8 CMSG_ANSWER_CHUNK = 0x01;
    constexpr uint8 SMSG_REQUEST = 0x10;

    // Encoded request object ("req") sent to the client. With the envelope
    // ("DC\tLABP|16|J|" plus {"id":"..","req":..}, about 45 bytes) a request
    // stays below the 245 bytes at which the addon transport starts chunking.
    constexpr std::size_t MaxRequestBytes = 190;
    constexpr std::size_t RequestIdLength = 10;
    constexpr std::size_t MaxRequestStringLength = 96;
    constexpr std::size_t MaxRequestArrayItems = 32;

    // Answer chunks: 1-based index, at most MaxChunks of them, each carrying at
    // most MaxChunkBytes decoded bytes (the addon sends 135).
    constexpr uint32 MaxChunks = 128;
    constexpr std::size_t MaxChunkBytes = 192;

    constexpr uint32 MaxPendingPerPlayer = 8;
    constexpr std::size_t MaxEntries = 64;

    // Server-generated request ids: lowercase hex, fixed length.
    bool IsRequestId(std::string_view id);

    // First word of the request ("cmd"). Everything the addon answers is a
    // read of UI state; the list is mirrored by DC-LabProbe's own allowlist.
    bool IsReadOnlyCommand(std::string_view command);

    // Keys a request object may carry besides "cmd".
    bool IsAllowedRequestKey(std::string_view key);

    // Request string values: frame names, unit tokens, CVar names, hyperlinks
    // ("item:6948"), so letters, digits and _ : . - only.
    bool IsSafeRequestString(std::string_view value);

    // "DC.LabProbe.Accounts": comma/space separated account names,
    // compared case-insensitively. Empty list = nobody.
    std::vector<std::string> ParseAccountList(std::string_view csv);
    bool IsListedAccount(std::vector<std::string> const& accounts, std::string_view account);

    enum class ResultState
    {
        Unknown,
        Pending,
        Complete,
        Abandoned
    };

    char const* ResultStateName(ResultState state);

    struct ResultStatus
    {
        ResultState state = ResultState::Unknown;
        uint32 received = 0;
        uint32 total = 0;
        uint64 ageMs = 0;
        std::string player;
        std::string command;
        std::string body;
    };

    enum class AcceptResult
    {
        Accepted,
        Completed,
        UnknownRequest,
        WrongPlayer,
        BadChunk,
        Duplicate,
        TooLarge
    };

    // Requests the server sent and the answers that came back. One entry per
    // request id; an entry lives until `ttlMs` after it was armed, so a
    // finished result can be read repeatedly within that window.
    class ResultBook
    {
    public:
        void Configure(uint64 ttlMs, std::size_t maxBodyBytes);

        void Arm(std::string const& id, uint64 player, std::string const& playerName,
            std::string const& command, uint64 nowMs);

        AcceptResult Accept(uint64 player, std::string const& id, uint32 index, uint32 total,
            std::string const& data, uint64 nowMs);

        ResultStatus Status(std::string const& id, uint64 nowMs);

        // Logout: pending requests of that player can no longer be answered.
        void AbandonPlayer(uint64 player);

        // Every live entry, newest first, without bodies.
        std::vector<std::pair<std::string, ResultStatus>> List(uint64 nowMs);

        std::size_t Size() const { return _entries.size(); }

    private:
        struct Entry
        {
            std::string id;
            uint64 player = 0;
            std::string playerName;
            std::string command;
            uint64 armedMs = 0;
            uint32 total = 0;
            std::size_t bytes = 0;
            bool abandoned = false;
            std::map<uint32, std::string> chunks;
        };

        void Expire(uint64 nowMs);
        Entry* Find(std::string_view id);
        ResultStatus Describe(Entry const& entry, uint64 nowMs, bool withBody) const;

        std::vector<Entry> _entries;
        uint64 _ttlMs = 300000;
        std::size_t _maxBodyBytes = 16384;
    };
}

#endif
