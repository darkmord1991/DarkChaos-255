# Addon Communication Protocol Enhancement

**Priority:** B-Tier  
**Effort:** Medium (1.5 weeks)  
**Impact:** High  
**Target System:** `src/server/scripts/DC/` + Client Addons

---

## Overview

Enhanced addon communication protocol for all DC systems, providing real-time updates, efficient data transfer, and unified client-side handling.

---

## Current State

Currently, each DC system sends its own addon packets with varying formats. This proposal standardizes communication.

---

## Protocol Design

### Packet Structure

```cpp
// DCPacketProtocol.h
#pragma once

#include <nlohmann/json.hpp>

namespace DC
{

enum class PacketType : uint8
{
    // Data packets
    FULL_SYNC = 0x01,       // Complete data sync
    DELTA_UPDATE = 0x02,    // Incremental update
    NOTIFICATION = 0x03,    // User notification
    
    // Request/Response
    REQUEST = 0x10,
    RESPONSE = 0x11,
    ERROR = 0x12,
    
    // Real-time
    STREAM_START = 0x20,
    STREAM_DATA = 0x21,
    STREAM_END = 0x22,
    
    // Control
    ACK = 0xF0,
    PING = 0xF1,
    PONG = 0xF2
};

enum class DataChannel : uint8
{
    PROFILE = 0x01,
    MYTHIC_PLUS = 0x02,
    SEASONS = 0x03,
    ITEM_UPGRADE = 0x04,
    PRESTIGE = 0x05,
    HOTSPOTS = 0x06,
    AOE_LOOT = 0x07,
    DUNGEON_QUESTS = 0x08,
    CURRENCIES = 0x09,
    UNLOCKS = 0x0A,
    LEADERBOARDS = 0x0B,
    
    BROADCAST = 0xFF  // All channels
};

struct Packet
{
    uint32 sequenceId;
    PacketType type;
    DataChannel channel;
    uint32 timestamp;
    nlohmann::json payload;
    
    std::string Serialize() const
    {
        nlohmann::json wrapper;
        wrapper["seq"] = sequenceId;
        wrapper["type"] = static_cast<uint8>(type);
        wrapper["channel"] = static_cast<uint8>(channel);
        wrapper["ts"] = timestamp;
        wrapper["data"] = payload;
        return wrapper.dump();
    }
    
    static Packet Deserialize(const std::string& data)
    {
        auto wrapper = nlohmann::json::parse(data);
        return {
            .sequenceId = wrapper["seq"].get<uint32>(),
            .type = static_cast<PacketType>(wrapper["type"].get<uint8>()),
            .channel = static_cast<DataChannel>(wrapper["channel"].get<uint8>()),
            .timestamp = wrapper["ts"].get<uint32>(),
            .payload = wrapper["data"]
        };
    }
};

} // namespace DC
```

### Packet Manager

```cpp
// DCPacketManager.h
#pragma once

#include "DCPacketProtocol.h"

namespace DC
{

class PacketManager
{
public:
    static PacketManager* instance();
    
    // Send packets
    void SendPacket(Player* player, const Packet& packet);
    void SendToChannel(Player* player, DataChannel channel, const nlohmann::json& data);
    void BroadcastToChannel(DataChannel channel, const nlohmann::json& data);
    void SendNotification(Player* player, const std::string& title, 
        const std::string& message, const std::string& icon = "");
    
    // Batch sending
    void QueuePacket(ObjectGuid player, const Packet& packet);
    void FlushQueue(ObjectGuid player);
    
    // Delta tracking
    void TrackState(ObjectGuid player, DataChannel channel, const nlohmann::json& state);
    nlohmann::json GetDelta(ObjectGuid player, DataChannel channel, const nlohmann::json& newState);
    
    // Request handling
    using RequestHandler = std::function<nlohmann::json(Player*, const nlohmann::json&)>;
    void RegisterHandler(DataChannel channel, const std::string& action, RequestHandler handler);
    void HandleRequest(Player* player, const Packet& request);
    
    // Compression (for large payloads)
    std::string Compress(const std::string& data);
    std::string Decompress(const std::string& data);

private:
    PacketManager();
    
    uint32 GetNextSequenceId(ObjectGuid player);
    void SendRaw(Player* player, const std::string& prefix, const std::string& data);
    
    // State tracking for delta updates
    std::unordered_map<ObjectGuid, std::unordered_map<DataChannel, nlohmann::json>> _lastStates;
    
    // Packet queues
    std::unordered_map<ObjectGuid, std::vector<Packet>> _queues;
    
    // Request handlers
    std::unordered_map<DataChannel, std::unordered_map<std::string, RequestHandler>> _handlers;
    
    // Sequence tracking
    std::unordered_map<ObjectGuid, uint32> _sequences;
};

#define sPacketManager DC::PacketManager::instance()

} // namespace DC
```

### Implementation

```cpp
// DCPacketManager.cpp
#include "DCPacketManager.h"
#include "Player.h"

namespace DC
{

void PacketManager::SendPacket(Player* player, const Packet& packet)
{
    std::string serialized = packet.Serialize();
    
    // Compress if large
    if (serialized.length() > 500)
    {
        std::string compressed = Compress(serialized);
        if (compressed.length() < serialized.length())
        {
            serialized = "Z" + compressed;  // Z prefix indicates compression
        }
    }
    
    // Split into chunks if needed (addon message limit ~255 bytes)
    const size_t chunkSize = 240;
    
    if (serialized.length() <= chunkSize)
    {
        SendRaw(player, "DCPKT", serialized);
    }
    else
    {
        // Multi-part message
        uint32 totalParts = (serialized.length() + chunkSize - 1) / chunkSize;
        
        for (uint32 i = 0; i < totalParts; ++i)
        {
            std::string chunk = serialized.substr(i * chunkSize, chunkSize);
            std::string prefix = Acore::StringFormat("DCPKT%u/%u:", i + 1, totalParts);
            SendRaw(player, prefix, chunk);
        }
    }
}

void PacketManager::SendToChannel(Player* player, DataChannel channel, 
    const nlohmann::json& data)
{
    Packet packet = {
        .sequenceId = GetNextSequenceId(player->GetGUID()),
        .type = PacketType::FULL_SYNC,
        .channel = channel,
        .timestamp = static_cast<uint32>(GameTime::GetGameTime().count()),
        .payload = data
    };
    
    // Check if we can send delta instead
    auto delta = GetDelta(player->GetGUID(), channel, data);
    if (!delta.empty() && delta.size() < data.size())
    {
        packet.type = PacketType::DELTA_UPDATE;
        packet.payload = delta;
    }
    
    SendPacket(player, packet);
    
    // Track new state
    TrackState(player->GetGUID(), channel, data);
}

nlohmann::json PacketManager::GetDelta(ObjectGuid player, DataChannel channel, 
    const nlohmann::json& newState)
{
    auto playerIt = _lastStates.find(player);
    if (playerIt == _lastStates.end())
        return {};
    
    auto channelIt = playerIt->second.find(channel);
    if (channelIt == playerIt->second.end())
        return {};
    
    const auto& oldState = channelIt->second;
    nlohmann::json delta;
    
    // Calculate differences
    for (auto& [key, value] : newState.items())
    {
        if (!oldState.contains(key) || oldState[key] != value)
        {
            delta[key] = value;
        }
    }
    
    // Track deletions
    nlohmann::json deletions = nlohmann::json::array();
    for (auto& [key, value] : oldState.items())
    {
        if (!newState.contains(key))
        {
            deletions.push_back(key);
        }
    }
    
    if (!deletions.empty())
        delta["_deleted"] = deletions;
    
    return delta;
}

void PacketManager::SendNotification(Player* player, const std::string& title,
    const std::string& message, const std::string& icon)
{
    Packet packet = {
        .sequenceId = GetNextSequenceId(player->GetGUID()),
        .type = PacketType::NOTIFICATION,
        .channel = DataChannel::BROADCAST,
        .timestamp = static_cast<uint32>(GameTime::GetGameTime().count()),
        .payload = {
            {"title", title},
            {"message", message},
            {"icon", icon}
        }
    };
    
    SendPacket(player, packet);
}

void PacketManager::RegisterHandler(DataChannel channel, const std::string& action,
    RequestHandler handler)
{
    _handlers[channel][action] = handler;
}

void PacketManager::HandleRequest(Player* player, const Packet& request)
{
    std::string action = request.payload.value("action", "");
    
    auto channelIt = _handlers.find(request.channel);
    if (channelIt == _handlers.end())
    {
        SendError(player, request, "Unknown channel");
        return;
    }
    
    auto handlerIt = channelIt->second.find(action);
    if (handlerIt == channelIt->second.end())
    {
        SendError(player, request, "Unknown action");
        return;
    }
    
    try
    {
        auto response = handlerIt->second(player, request.payload);
        
        Packet responsePacket = {
            .sequenceId = GetNextSequenceId(player->GetGUID()),
            .type = PacketType::RESPONSE,
            .channel = request.channel,
            .timestamp = static_cast<uint32>(GameTime::GetGameTime().count()),
            .payload = {
                {"request_seq", request.sequenceId},
                {"data", response}
            }
        };
        
        SendPacket(player, responsePacket);
    }
    catch (const std::exception& e)
    {
        SendError(player, request, e.what());
    }
}

} // namespace DC
```

---

### Client-Side Protocol Handler

```lua
-- DCProtocol.lua
local Protocol = {}

-- State
Protocol.sequences = {}
Protocol.lastStates = {}
Protocol.handlers = {}
Protocol.pendingChunks = {}

-- Packet types
local PacketType = {
    FULL_SYNC = 0x01,
    DELTA_UPDATE = 0x02,
    NOTIFICATION = 0x03,
    REQUEST = 0x10,
    RESPONSE = 0x11,
    ERROR = 0x12,
}

-- Data channels
local DataChannel = {
    PROFILE = 0x01,
    MYTHIC_PLUS = 0x02,
    SEASONS = 0x03,
    ITEM_UPGRADE = 0x04,
    PRESTIGE = 0x05,
    HOTSPOTS = 0x06,
    AOE_LOOT = 0x07,
    DUNGEON_QUESTS = 0x08,
    CURRENCIES = 0x09,
    UNLOCKS = 0x0A,
    LEADERBOARDS = 0x0B,
    BROADCAST = 0xFF,
}

Protocol.PacketType = PacketType
Protocol.DataChannel = DataChannel

-- Register packet handler
function Protocol:OnPacket(channel, handler)
    self.handlers[channel] = self.handlers[channel] or {}
    table.insert(self.handlers[channel], handler)
end

-- Parse incoming packet
function Protocol:HandleRaw(prefix, data)
    -- Check for multi-part
    local part, total = prefix:match("DCPKT(%d+)/(%d+):")
    if part then
        return self:HandleChunk(tonumber(part), tonumber(total), data)
    end
    
    -- Check for compression
    if data:sub(1, 1) == "Z" then
        data = LibCompress:Decompress(data:sub(2))
    end
    
    -- Parse JSON
    local ok, packet = pcall(function()
        return json.decode(data)
    end)
    
    if not ok then
        print("DC Protocol: Failed to parse packet")
        return
    end
    
    self:ProcessPacket(packet)
end

function Protocol:HandleChunk(part, total, data)
    local key = "chunk_" .. total
    self.pendingChunks[key] = self.pendingChunks[key] or {}
    self.pendingChunks[key][part] = data
    
    -- Check if complete
    local complete = true
    local fullData = ""
    for i = 1, total do
        if not self.pendingChunks[key][i] then
            complete = false
            break
        end
        fullData = fullData .. self.pendingChunks[key][i]
    end
    
    if complete then
        self.pendingChunks[key] = nil
        self:HandleRaw("DCPKT", fullData)
    end
end

function Protocol:ProcessPacket(packet)
    local ptype = packet.type
    local channel = packet.channel
    local data = packet.data
    
    -- Handle based on type
    if ptype == PacketType.FULL_SYNC then
        self:ApplyFullSync(channel, data)
    elseif ptype == PacketType.DELTA_UPDATE then
        self:ApplyDelta(channel, data)
    elseif ptype == PacketType.NOTIFICATION then
        self:ShowNotification(data)
    elseif ptype == PacketType.RESPONSE then
        self:HandleResponse(packet)
    elseif ptype == PacketType.ERROR then
        self:HandleError(packet)
    end
    
    -- Notify handlers
    self:NotifyHandlers(channel, self.lastStates[channel] or {})
end

function Protocol:ApplyFullSync(channel, data)
    self.lastStates[channel] = data
end

function Protocol:ApplyDelta(channel, delta)
    local state = self.lastStates[channel] or {}
    
    -- Apply changes
    for key, value in pairs(delta) do
        if key ~= "_deleted" then
            state[key] = value
        end
    end
    
    -- Remove deletions
    if delta._deleted then
        for _, key in ipairs(delta._deleted) do
            state[key] = nil
        end
    end
    
    self.lastStates[channel] = state
end

function Protocol:NotifyHandlers(channel, data)
    local handlers = self.handlers[channel] or {}
    for _, handler in ipairs(handlers) do
        pcall(handler, data, channel)
    end
    
    -- Also notify broadcast handlers
    if channel ~= DataChannel.BROADCAST then
        local broadcastHandlers = self.handlers[DataChannel.BROADCAST] or {}
        for _, handler in ipairs(broadcastHandlers) do
            pcall(handler, data, channel)
        end
    end
end

function Protocol:ShowNotification(data)
    -- Use DC notification system
    if DCNotification then
        DCNotification:Show(data.title, data.message, data.icon)
    else
        print("|cFFFFD700" .. (data.title or "Notification") .. "|r: " .. (data.message or ""))
    end
end

-- Send request to server
function Protocol:Request(channel, action, data, callback)
    local seq = (self.sequences[channel] or 0) + 1
    self.sequences[channel] = seq
    
    local packet = {
        seq = seq,
        type = PacketType.REQUEST,
        channel = channel,
        ts = GetTime(),
        data = {
            action = action,
            params = data
        }
    }
    
    -- Store callback
    self.pendingRequests = self.pendingRequests or {}
    self.pendingRequests[seq] = callback
    
    -- Send via AIO
    AIO:Send("DCREQ", json.encode(packet))
end

function Protocol:HandleResponse(packet)
    local requestSeq = packet.data.request_seq
    local callback = self.pendingRequests and self.pendingRequests[requestSeq]
    
    if callback then
        callback(true, packet.data.data)
        self.pendingRequests[requestSeq] = nil
    end
end

function Protocol:HandleError(packet)
    local requestSeq = packet.data.request_seq
    local callback = self.pendingRequests and self.pendingRequests[requestSeq]
    
    if callback then
        callback(false, packet.data.error)
        self.pendingRequests[requestSeq] = nil
    end
end

-- Get current state
function Protocol:GetState(channel)
    return self.lastStates[channel]
end

-- Register with AIO
AIO.AddAddon(Protocol)

-- Global access
DCProtocol = Protocol
```

---

### System Integration Example

```cpp
// MythicPlusPackets.cpp
#include "DCPacketManager.h"
#include "MythicPlusRunManager.h"

void MythicPlusRunManager::SendRunState(Player* player)
{
    auto state = GetRunState(player->GetGUID());
    if (!state)
        return;
    
    nlohmann::json data;
    data["dungeon_id"] = state->dungeonId;
    data["dungeon_name"] = state->dungeonName;
    data["key_level"] = state->keystoneLevel;
    data["time_remaining"] = state->GetRemainingTime();
    data["par_time"] = state->parTime;
    data["deaths"] = state->deaths;
    data["deaths_penalty"] = state->deaths * 5;  // 5 seconds per death
    data["percent_complete"] = state->GetCompletionPercent();
    
    // Affix info
    data["affixes"] = nlohmann::json::array();
    for (const auto& affix : state->activeAffixes)
    {
        data["affixes"].push_back({
            {"id", affix.id},
            {"name", affix.name},
            {"icon", affix.iconSpellId}
        });
    }
    
    // Boss progress
    data["bosses"] = nlohmann::json::array();
    for (const auto& boss : state->bosses)
    {
        data["bosses"].push_back({
            {"entry", boss.entry},
            {"name", boss.name},
            {"killed", boss.killed}
        });
    }
    
    sPacketManager->SendToChannel(player, DC::DataChannel::MYTHIC_PLUS, data);
}

void MythicPlusRunManager::RegisterPacketHandlers()
{
    sPacketManager->RegisterHandler(DC::DataChannel::MYTHIC_PLUS, "get_history",
        [this](Player* player, const nlohmann::json& params) -> nlohmann::json
        {
            uint32 limit = params.value("limit", 10);
            auto history = GetRunHistory(player->GetGUID().GetCounter(), limit);
            
            nlohmann::json response = nlohmann::json::array();
            for (const auto& run : history)
            {
                response.push_back({
                    {"dungeon", run.dungeonName},
                    {"level", run.keystoneLevel},
                    {"time", run.completionTime},
                    {"in_time", run.inTime},
                    {"rating", run.ratingGained},
                    {"date", run.timestamp}
                });
            }
            
            return response;
        });
    
    sPacketManager->RegisterHandler(DC::DataChannel::MYTHIC_PLUS, "get_best",
        [this](Player* player, const nlohmann::json& params) -> nlohmann::json
        {
            auto best = GetBestRuns(player->GetGUID().GetCounter());
            
            nlohmann::json response;
            for (const auto& [dungeonId, run] : best)
            {
                response[std::to_string(dungeonId)] = {
                    {"level", run.keystoneLevel},
                    {"time", run.completionTime},
                    {"in_time", run.inTime}
                };
            }
            
            return response;
        });
}
```

---

### Addon Usage Example

```lua
-- MythicPlusUI.lua using new protocol
local MythicUI = AIO.AddAddon()

function MythicUI:Init()
    -- Register for M+ data updates
    DCProtocol:OnPacket(DCProtocol.DataChannel.MYTHIC_PLUS, function(data)
        self:UpdateDisplay(data)
    end)
    
    -- Request initial data
    self:RequestHistory()
end

function MythicUI:UpdateDisplay(data)
    if not data then return end
    
    -- Update timer
    if data.time_remaining then
        local minutes = math.floor(data.time_remaining / 60)
        local seconds = data.time_remaining % 60
        self.timerText:SetText(string.format("%d:%02d", minutes, seconds))
        
        -- Color based on remaining time
        local ratio = data.time_remaining / data.par_time
        if ratio > 0.5 then
            self.timerText:SetTextColor(0, 1, 0)  -- Green
        elseif ratio > 0.2 then
            self.timerText:SetTextColor(1, 1, 0)  -- Yellow
        else
            self.timerText:SetTextColor(1, 0, 0)  -- Red
        end
    end
    
    -- Update progress
    if data.percent_complete then
        self.progressBar:SetValue(data.percent_complete)
    end
    
    -- Update deaths
    if data.deaths then
        self.deathsText:SetText(string.format("Deaths: %d (-%ds)", 
            data.deaths, data.deaths_penalty))
    end
    
    -- Update affixes
    if data.affixes then
        for i, affix in ipairs(data.affixes) do
            local icon = self.affixIcons[i]
            if icon then
                icon:SetTexture(GetSpellTexture(affix.icon))
                icon:Show()
            end
        end
    end
end

function MythicUI:RequestHistory()
    DCProtocol:Request(
        DCProtocol.DataChannel.MYTHIC_PLUS,
        "get_history",
        { limit = 20 },
        function(success, data)
            if success then
                self:PopulateHistory(data)
            else
                print("Failed to get M+ history: " .. tostring(data))
            end
        end
    )
end

function MythicUI:PopulateHistory(runs)
    for i, run in ipairs(runs) do
        local row = self.historyRows[i]
        if row then
            row.dungeonText:SetText(run.dungeon)
            row.levelText:SetText("+" .. run.level)
            
            local minutes = math.floor(run.time / 60)
            local seconds = run.time % 60
            row.timeText:SetText(string.format("%d:%02d", minutes, seconds))
            
            if run.in_time then
                row.timeText:SetTextColor(0, 1, 0)
            else
                row.timeText:SetTextColor(1, 0, 0)
            end
            
            row.ratingText:SetText("+" .. run.rating)
            row:Show()
        end
    end
end
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Protocol Design | 2 days | Packet structure, types |
| Server Implementation | 3 days | PacketManager, handlers |
| Client Library | 3 days | Lua protocol handler |
| System Migration | 3 days | Update all DC systems |
| Testing | 2 days | End-to-end validation |
| **Total** | **~1.5 weeks** | |

---

## Benefits

1. **Standardized Format** - All systems use same protocol
2. **Delta Updates** - Reduced bandwidth usage
3. **Request/Response** - Clean API for data queries
4. **Compression** - Large payloads handled efficiently
5. **Multi-Part Messages** - No size limitations
6. **Error Handling** - Proper error propagation
