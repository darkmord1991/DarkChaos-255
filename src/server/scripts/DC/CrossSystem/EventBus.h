/*
 * DarkChaos Cross-System Event Bus
 *
 * Provides a publish-subscribe event system for cross-system communication.
 * Systems register as handlers for specific event types and receive
 * notifications when those events occur.
 *
 * Features:
 * - Type-safe event data
 * - Priority-based handler ordering
 * - Synchronous and asynchronous event dispatch
 * - Event filtering by system, content type, etc.
 * - Event history for debugging
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#pragma once

#include "DC/CrossSystem/CrossSystemCore.h"
#include <functional>
#include <memory>
#include <mutex>
#include <queue>
#include <unordered_map>
#include <vector>

namespace DarkChaos
{
namespace CrossSystem
{
    // =========================================================================
    // Event Subscription
    // =========================================================================

    struct EventSubscription
    {
        uint64 id = 0;
        SystemId subscriberSystem = SystemId::None;
        EventType eventType = EventType::None;
        IEventHandler* handler = nullptr;
        uint8 priority = 100;       // Lower = earlier
        bool enabled = true;

        // Optional filters
        std::optional<ContentType> contentTypeFilter;
        std::optional<ContentDifficulty> difficultyFilter;
        std::optional<uint32> mapIdFilter;

        bool Matches(const EventData& event) const;
    };

    // =========================================================================
    // Event History Entry
    // =========================================================================

    struct EventHistoryEntry
    {
        uint64 eventId = 0;
        EventType type = EventType::None;
        ObjectGuid playerGuid;
        uint32 mapId = 0;
        uint64 timestamp = 0;
        SystemId sourceSystem = SystemId::None;
        uint32 handlerCount = 0;
        uint64 processingTimeUs = 0;
        std::string summary;
    };

    // =========================================================================
    // Event Bus Class
    // =========================================================================

    class EventBus
    {
    public:
        static EventBus* instance();

        // =====================================================================
        // Subscription Management
        // =====================================================================

        // Subscribe a handler to receive specific events
        uint64 Subscribe(IEventHandler* handler, EventType eventType, uint8 priority = 100);

        // Subscribe to multiple event types
        void SubscribeMultiple(IEventHandler* handler, const std::vector<EventType>& eventTypes, uint8 priority = 100);

        // Subscribe handler to all events it declares interest in
        void SubscribeHandler(IEventHandler* handler);

        // Unsubscribe from specific event
        void Unsubscribe(uint64 subscriptionId);

        // Unsubscribe all subscriptions for a handler
        void UnsubscribeHandler(IEventHandler* handler);

        // Unsubscribe all subscriptions for a system
        void UnsubscribeSystem(SystemId system);

        // Enable/disable subscriptions
        void SetSubscriptionEnabled(uint64 subscriptionId, bool enabled);
        void SetSystemEnabled(SystemId system, bool enabled);

        // =====================================================================
        // Event Publishing
        // =====================================================================

        // Publish an event synchronously (blocks until all handlers complete)
        void Publish(const EventData& event, SystemId sourceSystem = SystemId::None);

        // Publish with specific event type (convenience for simple events)
        void PublishSimple(EventType type, ObjectGuid playerGuid, uint32 mapId = 0,
                          uint32 instanceId = 0, SystemId sourceSystem = SystemId::None);

        // Queue event for async processing (processed on next update tick)
        void PublishAsync(std::unique_ptr<EventData> event, SystemId sourceSystem = SystemId::None);

        // Process queued async events (call from update loop)
        void ProcessAsyncEvents(uint32 maxEvents = 100);

        // =====================================================================
        // Typed Event Publishers
        // =====================================================================

        void PublishCreatureKill(Player* player, Creature* creature, bool isBoss = false,
                                 uint8 keystoneLevel = 0, uint32 partySize = 1);

        void PublishDungeonComplete(const DungeonCompleteEvent& event);

        void PublishQuestComplete(Player* player, uint32 questId, bool isDaily = false, bool isWeekly = false);

        void PublishItemUpgrade(Player* player, uint32 itemGuid, uint32 itemEntry,
                               uint8 fromLevel, uint8 toLevel, uint8 tierId,
                               uint32 tokensCost, uint32 essenceCost);

        void PublishPrestige(Player* player, uint8 fromPrestige, uint8 toPrestige,
                            uint8 fromLevel, bool keptGear);

        void PublishVaultClaim(Player* player, uint32 seasonId, uint8 slotClaimed,
                              uint32 itemId, uint32 tokens, uint32 essence);

        // =====================================================================
        // Event History
        // =====================================================================

        void EnableHistory(bool enable) { historyEnabled_ = enable; }
        bool IsHistoryEnabled() const { return historyEnabled_; }

        void SetHistoryMaxSize(uint32 maxSize) { historyMaxSize_ = maxSize; }
        uint32 GetHistoryMaxSize() const { return historyMaxSize_; }

        const std::vector<EventHistoryEntry>& GetHistory() const { return eventHistory_; }
        std::vector<EventHistoryEntry> GetHistoryForPlayer(ObjectGuid guid) const;
        std::vector<EventHistoryEntry> GetHistoryForEventType(EventType type) const;
        void ClearHistory();

        // =====================================================================
        // Statistics
        // =====================================================================

        struct Statistics
        {
            uint64 totalEventsPublished = 0;
            uint64 totalEventsProcessed = 0;
            uint64 totalHandlersInvoked = 0;
            uint64 asyncEventsQueued = 0;
            uint64 asyncEventsProcessed = 0;
            uint64 asyncEventsDropped = 0;  // Events dropped due to queue overflow
            uint64 errors = 0;
            std::unordered_map<EventType, uint64> eventCounts;
            std::unordered_map<SystemId, uint64> systemHandlerCounts;
        };

        const Statistics& GetStatistics() const { return stats_; }
        void ResetStatistics();

        // =====================================================================
        // Debugging
        // =====================================================================

        void SetVerboseLogging(bool enable) { verboseLogging_ = enable; }
        bool IsVerboseLogging() const { return verboseLogging_; }

        // Get human-readable summary
        std::string GetDebugInfo() const;
        std::string GetSubscriptionSummary() const;

    private:
        EventBus() = default;

        // Get sorted handlers for an event type
        std::vector<EventSubscription*> GetHandlersForEvent(EventType type);

        // Add to history
        void RecordHistory(const EventData& event, SystemId source, uint32 handlerCount, uint64 processingTimeUs);

        // Subscription storage (eventType -> subscriptions)
        std::unordered_map<EventType, std::vector<EventSubscription>> subscriptions_;
        uint64 nextSubscriptionId_ = 1;

        // Async event queue
        std::queue<std::pair<std::unique_ptr<EventData>, SystemId>> asyncQueue_;

        // History
        std::vector<EventHistoryEntry> eventHistory_;
        bool historyEnabled_ = false;
        uint32 historyMaxSize_ = 1000;
        uint64 nextEventId_ = 1;

        // Statistics
        Statistics stats_;

        // Logging
        bool verboseLogging_ = false;

        mutable std::mutex mutex_;
    };

    // Convenience inline
    inline EventBus* GetEventBus()
    {
        return EventBus::instance();
    }

} // namespace CrossSystem
} // namespace DarkChaos
