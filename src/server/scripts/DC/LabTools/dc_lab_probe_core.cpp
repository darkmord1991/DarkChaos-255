/*
 * Dark Chaos - Client lab probe relay: wire limits and the result book
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_lab_probe_core.h"
#include <algorithm>
#include <array>
#include <cctype>

namespace DCLabProbe
{
    namespace
    {
        constexpr std::array<std::string_view, 9> ReadOnlyCommands =
            { "ping", "state", "frame", "tooltip", "auras", "target", "cvars", "addons", "errors" };

        constexpr std::array<std::string_view, 6> RequestKeys =
            { "cmd", "name", "names", "unit", "link", "max" };

        std::string Upper(std::string_view text)
        {
            std::string result(text);
            std::transform(result.begin(), result.end(), result.begin(),
                [](unsigned char c) { return static_cast<char>(std::toupper(c)); });
            return result;
        }
    }

    bool IsRequestId(std::string_view id)
    {
        return id.size() == RequestIdLength
            && std::all_of(id.begin(), id.end(), [](char c)
                {
                    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
                });
    }

    bool IsReadOnlyCommand(std::string_view command)
    {
        return std::find(ReadOnlyCommands.begin(), ReadOnlyCommands.end(), command) != ReadOnlyCommands.end();
    }

    bool IsAllowedRequestKey(std::string_view key)
    {
        return std::find(RequestKeys.begin(), RequestKeys.end(), key) != RequestKeys.end();
    }

    bool IsSafeRequestString(std::string_view value)
    {
        if (value.empty() || value.size() > MaxRequestStringLength)
            return false;

        return std::all_of(value.begin(), value.end(), [](unsigned char c)
            {
                return std::isalnum(c) != 0 || c == '_' || c == ':' || c == '.' || c == '-';
            });
    }

    std::vector<std::string> ParseAccountList(std::string_view csv)
    {
        std::vector<std::string> accounts;
        std::size_t pos = 0;
        while (pos < csv.size())
        {
            std::size_t const end = csv.find_first_of(", \t;", pos);
            std::size_t const length = end == std::string_view::npos ? std::string_view::npos : end - pos;
            std::string_view const token = csv.substr(pos, length);
            if (!token.empty())
                accounts.push_back(Upper(token));

            if (end == std::string_view::npos)
                break;

            pos = end + 1;
        }

        return accounts;
    }

    bool IsListedAccount(std::vector<std::string> const& accounts, std::string_view account)
    {
        if (account.empty())
            return false;

        std::string const wanted = Upper(account);
        return std::find(accounts.begin(), accounts.end(), wanted) != accounts.end();
    }

    char const* ResultStateName(ResultState state)
    {
        switch (state)
        {
            case ResultState::Pending:
                return "pending";
            case ResultState::Complete:
                return "complete";
            case ResultState::Abandoned:
                return "abandoned";
            default:
                return "unknown";
        }
    }

    void ResultBook::Configure(uint64 ttlMs, std::size_t maxBodyBytes)
    {
        _ttlMs = std::max<uint64>(ttlMs, 1000);
        _maxBodyBytes = std::max<std::size_t>(maxBodyBytes, MaxChunkBytes);
    }

    void ResultBook::Expire(uint64 nowMs)
    {
        std::erase_if(_entries, [this, nowMs](Entry const& entry)
            {
                return nowMs >= entry.armedMs && nowMs - entry.armedMs > _ttlMs;
            });
    }

    ResultBook::Entry* ResultBook::Find(std::string_view id)
    {
        auto itr = std::find_if(_entries.begin(), _entries.end(),
            [id](Entry const& entry) { return entry.id == id; });
        return itr == _entries.end() ? nullptr : &*itr;
    }

    void ResultBook::Arm(std::string const& id, uint64 player, std::string const& playerName,
        std::string const& command, uint64 nowMs)
    {
        Expire(nowMs);
        std::erase_if(_entries, [&id](Entry const& entry) { return entry.id == id; });

        // Per player: drop the oldest still-pending request beyond the cap.
        std::size_t pending = 0;
        for (Entry const& entry : _entries)
            if (entry.player == player && !entry.abandoned && (entry.total == 0 || entry.chunks.size() < entry.total))
                ++pending;

        if (pending >= MaxPendingPerPlayer)
        {
            auto oldest = std::find_if(_entries.begin(), _entries.end(), [player](Entry const& entry)
                {
                    return entry.player == player && !entry.abandoned
                        && (entry.total == 0 || entry.chunks.size() < entry.total);
                });
            if (oldest != _entries.end())
                _entries.erase(oldest);
        }

        // Globally: drop the oldest entry of any kind.
        if (_entries.size() >= MaxEntries)
            _entries.erase(_entries.begin());

        Entry entry;
        entry.id = id;
        entry.player = player;
        entry.playerName = playerName;
        entry.command = command;
        entry.armedMs = nowMs;
        _entries.push_back(std::move(entry));
    }

    AcceptResult ResultBook::Accept(uint64 player, std::string const& id, uint32 index, uint32 total,
        std::string const& data, uint64 nowMs)
    {
        Expire(nowMs);
        Entry* entry = Find(id);
        if (!entry || entry->abandoned)
            return AcceptResult::UnknownRequest;

        // Only the client the request went to may answer it.
        if (entry->player != player)
            return AcceptResult::WrongPlayer;

        if (index < 1 || total < 1 || index > total || total > MaxChunks || data.size() > MaxChunkBytes)
            return AcceptResult::BadChunk;

        if (entry->total == 0)
            entry->total = total;
        else if (entry->total != total)
            return AcceptResult::BadChunk;

        if (entry->chunks.contains(index))
            return AcceptResult::Duplicate;

        if (entry->bytes + data.size() > _maxBodyBytes)
            return AcceptResult::TooLarge;

        entry->bytes += data.size();
        entry->chunks.emplace(index, data);
        return entry->chunks.size() == entry->total ? AcceptResult::Completed : AcceptResult::Accepted;
    }

    ResultStatus ResultBook::Describe(Entry const& entry, uint64 nowMs, bool withBody) const
    {
        ResultStatus status;
        status.received = static_cast<uint32>(entry.chunks.size());
        status.total = entry.total;
        status.ageMs = nowMs >= entry.armedMs ? nowMs - entry.armedMs : 0;
        status.player = entry.playerName;
        status.command = entry.command;

        if (entry.total != 0 && entry.chunks.size() == entry.total)
        {
            status.state = ResultState::Complete;
            if (withBody)
            {
                status.body.reserve(entry.bytes);
                for (auto const& [index, data] : entry.chunks)
                    status.body += data;
            }
        }
        else
            status.state = entry.abandoned ? ResultState::Abandoned : ResultState::Pending;

        return status;
    }

    ResultStatus ResultBook::Status(std::string const& id, uint64 nowMs)
    {
        Expire(nowMs);
        Entry const* entry = Find(id);
        if (!entry)
            return {};

        return Describe(*entry, nowMs, true);
    }

    void ResultBook::AbandonPlayer(uint64 player)
    {
        for (Entry& entry : _entries)
            if (entry.player == player && (entry.total == 0 || entry.chunks.size() < entry.total))
                entry.abandoned = true;
    }

    std::vector<std::pair<std::string, ResultStatus>> ResultBook::List(uint64 nowMs)
    {
        Expire(nowMs);
        std::vector<std::pair<std::string, ResultStatus>> result;
        result.reserve(_entries.size());
        for (auto itr = _entries.rbegin(); itr != _entries.rend(); ++itr)
            result.emplace_back(itr->id, Describe(*itr, nowMs, false));

        return result;
    }
}
