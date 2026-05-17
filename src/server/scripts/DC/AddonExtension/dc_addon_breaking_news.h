#ifndef DC_ADDON_BREAKING_NEWS_H
#define DC_ADDON_BREAKING_NEWS_H

#include <cstdint>
#include <string>
#include <vector>

class WorldSession;

namespace DCAddon
{
    struct SessionCapabilityState;
}

namespace DCBreakingNews
{
    struct Snapshot
    {
        bool enabled = false;
        std::string title;
        std::string body;
        std::string format = "simplehtml";
        uint32 revision = 0;
        uint32 updatedAt = 0;
    };

    struct TransportDecision
    {
        bool willSend = false;
        bool hasCapabilityState = false;
        bool capabilityFromPersistedFallback = false;
        bool featureEnabled = false;
        bool snapshotReady = false;
        bool versionCompatible = false;
        uint32 clientCapabilities = 0;
        uint32 negotiatedCapabilities = 0;
        std::string capabilitySource = "none";
        std::string reason = "unknown";
        std::string snapshotError;
        uint64 characterGuid = 0;
        std::string characterName;
        Snapshot snapshot;
    };

    struct DeliveryLogEntry
    {
        uint64 id = 0;
        uint32 accountId = 0;
        uint64 characterGuid = 0;
        std::string characterName;
        std::string source = "unknown";
        bool sent = false;
        std::string reason = "unknown";
        bool hasCapabilityState = false;
        bool capabilityFromPersistedFallback = false;
        bool featureEnabled = false;
        bool snapshotReady = false;
        bool versionCompatible = false;
        uint32 clientCapabilities = 0;
        uint32 negotiatedCapabilities = 0;
        uint32 revision = 0;
        uint32 updatedAt = 0;
        uint32 bodyBytes = 0;
        uint64 eventUnix = 0;
    };

    Snapshot GetSnapshot();
    bool Reload(bool force, std::string* errorMessage = nullptr);
    TransportDecision EvaluateTransportDecision(WorldSession* session);
    TransportDecision EvaluateTransportDecision(
        DCAddon::SessionCapabilityState const* capabilityState);
    bool GetRecentDeliveryLog(uint32 accountId, uint32 limit,
        std::vector<DeliveryLogEntry>& out);
    bool SendToSession(WorldSession* session,
        char const* source = "runtime");
}

void AddSC_dc_addon_breaking_news();

#endif // DC_ADDON_BREAKING_NEWS_H